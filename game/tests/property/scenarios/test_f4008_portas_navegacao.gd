extends TestCase
## F4-008 (D4-03): portas na navegação da sandbox. Cada vão é fechado na navmesh; só o NavigationLink3D
## NavLink_<door_id> o atravessa. Os testes desligam links, então a cena é carregada uma vez e todos os links são
## religados em after_each. Autor: Level Designer (F4-008).
## map_get_path devolve, para um destino inalcançável, o caminho até o ponto alcançável mais próximo. Por isso
## "não alcança" aqui quer dizer: o fim do caminho fica longe do destino, e nenhum trecho cruza o vão.

const LEVEL_PATH: String = "res://content/levels/sandbox.tscn"
const SYNC_FRAMES: int = 2
const MAX_SYNC_FRAMES: int = 60
const DOOR_IDS: Array[StringName] = [&"door_sala_corredor", &"door_sala_cozinha", &"door_cozinha_corredor", &"door_corredor_hall", &"door_hall_quintal"]
const UNREACHED_M: float = 0.5
const TARGET_TOL_M: float = 0.3
const SIDE_OFFSET_M: float = 1.0
const GAP_SLACK_M: float = 0.05
const DEFAULT_DOOR_W_M: float = 0.9
const COOK_POINT: Vector3 = Vector3(9.5, 0.0, -3.5)
const CORRIDOR_POINT: Vector3 = Vector3(10.0, 0.0, -0.7)

var _root: Node3D = null
var _map: RID = RID()


func before_all() -> void:
	var scene: PackedScene = load(LEVEL_PATH) as PackedScene
	_root = scene.instantiate() as Node3D
	add_child(_root)
	_map = _root.get_world_3d().get_navigation_map()
	await _sync()


func after_all() -> void:
	await release_and_flush(_root)
	_root = null


func after_each() -> void:
	for door_id: StringName in DOOR_IDS:
		_link(door_id).enabled = true
	await _sync()


func test_sem_nenhum_link_nenhum_vao_de_porta_e_atravessavel() -> void:
	for door_id: StringName in DOOR_IDS:
		_link(door_id).enabled = false
	await _sync()
	for door_id: StringName in DOOR_IDS:
		var slot: Node3D = _slot(door_id)
		var side_a: Vector3 = _side(slot, -SIDE_OFFSET_M)
		var side_b: Vector3 = _side(slot, SIDE_OFFSET_M)
		var path: PackedVector3Array = _path(side_a, side_b)
		assert_false(_crosses_gap(path, slot), "sem link, %s não é atravessado" % door_id)
		assert_true(_end_far_from(path, side_b), "sem link, lado B de %s não é alcançado" % door_id)


func test_link_desligado_nao_deixa_o_caminho_passar_pela_porta() -> void:
	for door_id: StringName in DOOR_IDS:
		_link(door_id).enabled = false
		await _sync()
		var slot: Node3D = _slot(door_id)
		var path: PackedVector3Array = _path(_side(slot, -SIDE_OFFSET_M), _side(slot, SIDE_OFFSET_M))
		assert_false(_crosses_gap(path, slot), "com o link de %s desligado, o caminho não passa por ela" % door_id)
		_link(door_id).enabled = true
		await _sync()


func test_porta_trancada_obriga_o_caminho_cozinha_corredor_a_passar_pela_sala() -> void:
	_link(&"door_cozinha_corredor").enabled = false
	await _sync()
	var path: PackedVector3Array = _path(COOK_POINT, CORRIDOR_POINT)
	assert_true(_path_reaches(path, CORRIDOR_POINT), "com a porta trancada, a cozinha ainda chega ao corredor pela sala")
	assert_false(_crosses_gap(path, _slot(&"door_cozinha_corredor")), "a porta trancada não é atravessada")
	assert_true(_crosses_gap(path, _slot(&"door_sala_cozinha")), "o caminho passa pelo vão sala-cozinha")
	assert_true(_crosses_gap(path, _slot(&"door_sala_corredor")), "o caminho passa pelo vão sala-corredor (a sala)")


func _link(door_id: StringName) -> NavigationLink3D:
	return _root.get_node("NavLinks/NavLink_%s" % door_id) as NavigationLink3D


func _slot(door_id: StringName) -> Node3D:
	return _root.get_node("Openings/DoorSlot_%s" % door_id) as Node3D


## Espera o mapa sincronizar (iteration id > 0) e um frame de física a mais, depois de qualquer troca de link.
func _sync() -> void:
	var frames: int = 0
	while NavigationServer3D.map_get_iteration_id(_map) == 0 and frames < MAX_SYNC_FRAMES:
		await wait_physics_frames(1)
		frames += 1
	NavigationServer3D.map_force_update(_map)
	await wait_physics_frames(SYNC_FRAMES)


func _path(from: Vector3, to: Vector3) -> PackedVector3Array:
	return NavigationServer3D.map_get_path(_map, from, to, true)


## Ponto no piso a SIDE_OFFSET_M do centro do vão, do lado indicado pelo sinal (eixo normal do marcador).
func _side(slot: Node3D, sign_offset: float) -> Vector3:
	var normal: Vector3 = slot.global_transform.basis.x.normalized()
	var point: Vector3 = slot.global_position + normal * sign_offset
	point.y = 0.0
	return point


func _path_reaches(path: PackedVector3Array, target: Vector3) -> bool:
	if path.size() < 2:
		return false
	return _flat(path[path.size() - 1]).distance_to(_flat(target)) < TARGET_TOL_M


func _end_far_from(path: PackedVector3Array, target: Vector3) -> bool:
	if path.size() < 2:
		return true
	return _flat(path[path.size() - 1]).distance_to(_flat(target)) > UNREACHED_M


## Algum trecho do caminho cruza o plano do vão dentro da abertura (largura do metadado do marcador).
func _crosses_gap(path: PackedVector3Array, slot: Node3D) -> bool:
	var normal: Vector3 = slot.global_transform.basis.x.normalized()
	var along: Vector3 = slot.global_transform.basis.z.normalized()
	var centre: Vector3 = slot.global_position
	var half: float = float(slot.get_meta(&"opening_width_m", DEFAULT_DOOR_W_M)) / 2.0
	for index: int in range(path.size() - 1):
		var p: Vector3 = path[index]
		var q: Vector3 = path[index + 1]
		var sp: float = (p - centre).dot(normal)
		var sq: float = (q - centre).dot(normal)
		if sp * sq >= 0.0:
			continue
		var hit: Vector3 = p.lerp(q, sp / (sp - sq))
		if absf((hit - centre).dot(along)) <= half + GAP_SLACK_M:
			return true
	return false


func _flat(point: Vector3) -> Vector3:
	return Vector3(point.x, 0.0, point.z)

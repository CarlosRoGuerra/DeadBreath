extends TestCase
## F4-008 (Level Designer): sandbox para a IA. Navmesh assada (content/levels/sandbox_navmesh.tres), links de porta
## NavLink_<door_id> ligados, rota de patrulha do Observer (patrol_point) e surgimento (enemy_slot).
## Aqui só consultas: a cena é carregada uma vez e nenhum link muda. Os testes que desligam links ficam em
## tests/property/scenarios/test_f4008_portas_navegacao.gd. Autor: Level Designer (F4-008).
## A navegação só sincroniza depois de um frame de física: wait_physics_frames antes de consultar o mapa.

const LEVEL_PATH: String = "res://content/levels/sandbox.tscn"
const SYNC_FRAMES: int = 2
const MAX_SYNC_FRAMES: int = 60
const ROUTE_ID: StringName = &"observer"
const ENEMY_ID: StringName = &"observer"
const PROFILE_ID: StringName = &"observer"
const LINK_PREFIX: String = "NavLink_"
const PATROL_GROUP: StringName = &"patrol_point"
const SPAWN_GROUP: StringName = &"enemy_slot"
const DOOR_GROUP: StringName = &"door_slot"
const DOOR_IDS: Array[StringName] = [&"door_sala_corredor", &"door_sala_cozinha", &"door_cozinha_corredor", &"door_corredor_hall", &"door_hall_quintal"]
const ROOM_IDS: Array[StringName] = [&"sala", &"cozinha", &"corredor", &"hall", &"mezanino", &"quintal"]
const MIN_ROUTE_ROOMS: int = 3
const AGENT_RADIUS_M: float = 0.35
const AGENT_HEIGHT_M: float = 1.8
const AGENT_CLIMB_M: float = 0.3
const MEZZ_TOP_M: float = 1.08
const TARGET_TOL_M: float = 0.3
const TOL: float = 0.0001

var _root: Node3D = null
var _map: RID = RID()


## Carregada uma vez para o arquivo. A cena do nível vem sem os nós do jogador, então o teste só consulta a navegação.
func before_all() -> void:
	var scene: PackedScene = load(LEVEL_PATH) as PackedScene
	_root = scene.instantiate() as Node3D
	add_child(_root)
	_map = _root.get_world_3d().get_navigation_map()
	await _wait_map_synced()


func after_all() -> void:
	await release_and_flush(_root)
	_root = null


## O mapa só responde depois da primeira sincronização (iteration id > 0); consulta antes disso dá caminho vazio.
func _wait_map_synced() -> void:
	var frames: int = 0
	while NavigationServer3D.map_get_iteration_id(_map) == 0 and frames < MAX_SYNC_FRAMES:
		await wait_physics_frames(1)
		frames += 1
	await wait_physics_frames(SYNC_FRAMES)


func test_navmesh_existe_e_tem_os_parametros_do_agente() -> void:
	var region: NavigationRegion3D = _root.get_node("NavigationRegion") as NavigationRegion3D
	assert_not_null(region, "a sandbox tem o NavigationRegion3D")
	if region == null:
		return
	var nav: NavigationMesh = region.navigation_mesh
	assert_not_null(nav, "a região tem a navmesh assada (sandbox_navmesh.tres)")
	if nav == null:
		return
	assert_true(nav.get_polygon_count() > 0, "a navmesh tem polígonos (%d)" % nav.get_polygon_count())
	assert_true(nav.get_vertices().size() > 0, "a navmesh tem vértices")
	assert_almost_eq(nav.agent_radius, AGENT_RADIUS_M, TOL, "raio do agente 0,35 m")
	assert_almost_eq(nav.agent_height, AGENT_HEIGHT_M, TOL, "altura do agente 1,8 m")
	assert_almost_eq(nav.agent_max_climb, AGENT_CLIMB_M, TOL, "degrau máximo 0,3 m")


func test_rota_do_observer_tem_metas_e_ordem() -> void:
	var points: Array[Node3D] = _in_group(PATROL_GROUP)
	assert_true(points.size() >= 4, "a rota tem pontos suficientes (%d)" % points.size())
	var orders: Array[int] = []
	var rooms: Array[StringName] = []
	for point: Node3D in points:
		assert_eq(StringName(str(point.get_meta(&"route_id"))), ROUTE_ID, "route_id da rota em %s" % point.name)
		assert_eq(typeof(point.get_meta(&"order")), TYPE_INT, "order é inteiro em %s" % point.name)
		orders.append(int(point.get_meta(&"order")))
		var room: StringName = StringName(str(point.get_meta(&"room")))
		assert_true(ROOM_IDS.has(room), "sala conhecida no ponto %s: %s" % [point.name, room])
		if not rooms.has(room):
			rooms.append(room)
	orders.sort()
	for index: int in range(orders.size()):
		assert_eq(orders[index], index, "ordem contínua da rota a partir de 0")
	assert_true(rooms.size() >= MIN_ROUTE_ROOMS, "a rota passa por pelo menos 3 salas (%d)" % rooms.size())


func test_surgimento_do_observer_tem_metas_certas() -> void:
	var spawns: Array[Node3D] = _in_group(SPAWN_GROUP)
	assert_eq(spawns.size(), 1, "um único enemy_slot (o Observer)")
	if spawns.is_empty():
		return
	var spawn: Node3D = spawns[0]
	assert_eq(StringName(str(spawn.get_meta(&"enemy_id"))), ENEMY_ID, "enemy_id observer")
	assert_eq(StringName(str(spawn.get_meta(&"profile"))), PROFILE_ID, "profile observer")
	assert_eq(StringName(str(spawn.get_meta(&"route_id"))), ROUTE_ID, "route_id observer")


func test_cada_porta_tem_um_link_ligado_com_o_door_id() -> void:
	var links: Array[NavigationLink3D] = _links()
	assert_eq(links.size(), DOOR_IDS.size(), "um NavigationLink3D por porta (sem o vão hall-mezanino)")
	for door_id: StringName in DOOR_IDS:
		var link: NavigationLink3D = _root.get_node_or_null("NavLinks/%s%s" % [LINK_PREFIX, door_id]) as NavigationLink3D
		assert_not_null(link, "NavLink_%s existe" % door_id)
		if link == null:
			continue
		assert_eq(StringName(str(link.get_meta(&"door_id"))), door_id, "meta door_id de %s" % door_id)
		assert_true(link.bidirectional, "link de %s é bidirecional" % door_id)
		assert_true(link.enabled, "link de %s começa ligado" % door_id)
	assert_true(_root.get_node_or_null("NavLinks/%shall_mezanino" % LINK_PREFIX) == null, "vão hall-mezanino sem link (não tem porta)")


func test_rota_inteira_e_alcancavel_a_partir_do_surgimento() -> void:
	var spawn: Vector3 = _in_group(SPAWN_GROUP)[0].global_position
	for point: Node3D in _sorted_route():
		var path: PackedVector3Array = NavigationServer3D.map_get_path(_map, spawn, point.global_position, true)
		assert_true(path.size() >= 2, "ponto %s alcançável a partir do surgimento" % point.name)
		if path.size() < 2:
			continue
		var reached: Vector3 = path[path.size() - 1]
		assert_true(_flat(reached).distance_to(_flat(point.global_position)) < TARGET_TOL_M,
			"o caminho termina no ponto %s (dist %.2f)" % [point.name, _flat(reached).distance_to(_flat(point.global_position))])


func test_mezanino_e_alcancavel_pela_escada() -> void:
	var hall: Vector3 = Vector3(16.0, 0.0, -0.5)
	var mezzanine: Vector3 = Vector3(16.5, MEZZ_TOP_M, -4.5)
	var path: PackedVector3Array = NavigationServer3D.map_get_path(_map, hall, mezzanine, true)
	assert_true(path.size() >= 2, "o mezanino é alcançável a partir do hall")
	var top: float = -INF
	for p: Vector3 in path:
		top = maxf(top, p.y)
	assert_true(top > MEZZ_TOP_M - 0.1, "o caminho sobe ao mezanino pela escada (y máx %.2f)" % top)


func _in_group(group: StringName) -> Array[Node3D]:
	var found: Array[Node3D] = []
	for node: Node in get_tree().get_nodes_in_group(group):
		var n3: Node3D = node as Node3D
		if n3 != null and _root.is_ancestor_of(n3):
			found.append(n3)
	return found


func _links() -> Array[NavigationLink3D]:
	var found: Array[NavigationLink3D] = []
	var holder: Node = _root.get_node("NavLinks")
	for child: Node in holder.get_children():
		var link: NavigationLink3D = child as NavigationLink3D
		if link != null and link.name.begins_with(LINK_PREFIX):
			found.append(link)
	return found


## Pontos da rota na ordem da meta order.
func _sorted_route() -> Array[Node3D]:
	var points: Array[Node3D] = _in_group(PATROL_GROUP)
	points.sort_custom(func(a: Node3D, b: Node3D) -> bool: return int(a.get_meta(&"order")) < int(b.get_meta(&"order")))
	return points


func _flat(point: Vector3) -> Vector3:
	return Vector3(point.x, 0.0, point.z)


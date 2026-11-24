extends SceneTree
## F4-008 (Level Designer): assa a navmesh da sandbox e grava game/content/levels/sandbox_navmesh.tres.
## Ferramenta de level design, fora do jogo. Não é carregada pelo jogo. Como o Godot só lê res:// dentro de game/:
##   python tools/level/gen_sandbox.py                 (cria o .tres vazio se faltar e escreve a cena)
##   copy tools\level\bake_navmesh.gd game\bake_navmesh.gd
##   & (Get-GodotPath) --headless --path D:\Dev\DeadBreath\game --script res://bake_navmesh.gd
##   del game\bake_navmesh.gd   (e o .uid, se aparecer)
##
## Parâmetros do agente (DATA e F4-008): raio 0,35 m, altura 1,8 m, degrau máximo 0,3 m (espelho de 0,18 m).
## Geometria: os grupos de piso, parede, mesa, escada e mezanino (MeshInstance3D). O teto não entra (sobraria
## malha sobre o teto). Cada vão de porta (grupo door_slot) é fechado por uma caixa temporária de 2,0 m de altura,
## só nesta execução: a porta é atravessada pelo NavigationLink3D (D4-03). A cena não é gravada.
## Diagnóstico: com os vãos abertos (sem as caixas), mede a faixa livre de cada vão; a malha fechada tem
## de cobrir o centro das salas. Sai com 0 só se a malha foi gravada e o diagnóstico passou.

const SCENE_PATH: String = "res://content/levels/sandbox.tscn"
const NAVMESH_PATH: String = "res://content/levels/sandbox_navmesh.tres"
const REGION_NAME: String = "NavigationRegion"
const NAV_GROUP: StringName = &"navigation_source"
const GEOMETRY_ROOTS: Array[String] = [
	"Geometry/Floors", "Geometry/Walls", "Geometry/Furniture", "Geometry/Stairs", "Geometry/Mezzanine",
]
const DOOR_SLOT_GROUP: StringName = &"door_slot"
const BLOCK_HEIGHT_M: float = 2.0
const WALL_T_M: float = 0.2
const DEFAULT_DOOR_W_M: float = 0.9
const AGENT_RADIUS_M: float = 0.35
const AGENT_HEIGHT_M: float = 1.8
const AGENT_CLIMB_M: float = 0.3
const AGENT_SLOPE_DEG: float = 45.0
## Célula de 0,05 m, escolhida por medição: com 0,25 m (padrão do mapa) a malha aberta tem 23 polígonos e o centro
## dos vãos não fica na malha; com 0,10 m o centro também não fica (o agente de 0,35 m deixa uma faixa estreita
## demais). Com 0,05 m cada vão tem faixa livre de ~0,10 m. O mapa padrão é 0,25 m: o Godot avisa da diferença.
const CELL_SIZE_M: float = 0.05
const CELL_HEIGHT_M: float = 0.05
const SAMPLE_STEP_M: float = 0.05
const SAMPLE_MAX_M: float = 0.45
## Faixa mínima que o vão aberto tem de deixar livre para o agente (meia largura, em m). 0,05 = 0,10 m de faixa.
const MIN_GAP_HALF_M: float = 0.05
const FLOOR_Y_LIMIT_M: float = 0.5

var _started: bool = false
var _scene: Node3D = null
var _failures: int = 0


func _process(_delta: float) -> bool:
	if _started:
		return false
	_started = true
	_run()
	quit(1 if _failures > 0 else 0)
	return true


func _run() -> void:
	var packed: PackedScene = load(SCENE_PATH) as PackedScene
	if packed == null:
		_fail("não carregou " + SCENE_PATH)
		return
	_scene = packed.instantiate() as Node3D
	root.add_child(_scene)
	var region: NavigationRegion3D = _scene.get_node_or_null(REGION_NAME) as NavigationRegion3D
	if region == null:
		_fail("a cena não tem o NavigationRegion3D '%s' (rode tools/level/gen_sandbox.py)" % REGION_NAME)
		return
	for path: String in GEOMETRY_ROOTS:
		var geometry: Node = _scene.get_node_or_null(path)
		if geometry == null:
			_fail("sem o nó de geometria " + path)
			return
		geometry.add_to_group(NAV_GROUP)

	var started_ms: int = Time.get_ticks_msec()
	var open_nav: NavigationMesh = _bake(region)
	var open_ms: int = Time.get_ticks_msec() - started_ms
	print("bake aberto (sem vãos bloqueados): %d polígonos, %d ms" % [open_nav.get_polygon_count(), open_ms])
	_check_gaps(open_nav)

	var doors: Array[Node3D] = _add_door_blockers()
	started_ms = Time.get_ticks_msec()
	var closed_nav: NavigationMesh = _bake(region)
	print("bake final (%d vãos fechados): %d polígonos, %d vértices, %d ms" % [
		doors.size(), closed_nav.get_polygon_count(), closed_nav.get_vertices().size(), Time.get_ticks_msec() - started_ms,
	])
	if closed_nav.get_polygon_count() == 0:
		_fail("a malha final ficou vazia")
		return
	_report_height(closed_nav)
	var error: Error = ResourceSaver.save(closed_nav, NAVMESH_PATH)
	if error != OK:
		_fail("ResourceSaver falhou (%d) em %s" % [error, NAVMESH_PATH])
		return
	print("gravado: " + NAVMESH_PATH)


func _nav_settings() -> NavigationMesh:
	var nav: NavigationMesh = NavigationMesh.new()
	nav.cell_size = CELL_SIZE_M
	nav.cell_height = CELL_HEIGHT_M
	nav.agent_radius = AGENT_RADIUS_M
	nav.agent_height = AGENT_HEIGHT_M
	nav.agent_max_climb = AGENT_CLIMB_M
	nav.agent_max_slope = AGENT_SLOPE_DEG
	# Colisores (e não malhas visuais): o Godot só assa bem a partir de colisores, e a sandbox já os tem (camada 1).
	nav.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	nav.geometry_collision_mask = 1
	nav.geometry_source_geometry_mode = NavigationMesh.SOURCE_GEOMETRY_GROUPS_WITH_CHILDREN
	nav.geometry_source_group_name = NAV_GROUP
	return nav


func _bake(region: NavigationRegion3D) -> NavigationMesh:
	var probe: NavigationMesh = _nav_settings()
	var source: NavigationMeshSourceGeometryData3D = NavigationMeshSourceGeometryData3D.new()
	NavigationServer3D.parse_source_geometry_data(probe, source, _scene)
	print("fonte: %d vértices, %d índices de colisão no grupo %s" % [
		source.get_vertices().size(), source.get_indices().size(), NAV_GROUP,
	])
	region.navigation_mesh = _nav_settings()
	region.bake_navigation_mesh(false)
	return region.navigation_mesh


## Uma caixa por vão de door_slot, na posição e na rotação do marcador: fecha o vão até a verga (2,0 m).
func _add_door_blockers() -> Array[Node3D]:
	var holder: Node3D = Node3D.new()
	holder.name = "NavBlockers"
	_scene.add_child(holder)
	var made: Array[Node3D] = []
	for node: Node in get_nodes_in_group(DOOR_SLOT_GROUP):
		var slot: Node3D = node as Node3D
		if slot == null or not _scene.is_ancestor_of(slot):
			continue
		var width: float = float(slot.get_meta(&"opening_width_m", DEFAULT_DOOR_W_M))
		var shape: BoxShape3D = BoxShape3D.new()
		shape.size = Vector3(WALL_T_M, BLOCK_HEIGHT_M, width)
		var collision: CollisionShape3D = CollisionShape3D.new()
		collision.shape = shape
		var block: StaticBody3D = StaticBody3D.new()
		block.name = "Block_" + str(slot.get_meta(&"door_id", slot.name))
		block.add_child(collision)
		block.add_to_group(NAV_GROUP)
		holder.add_child(block)
		block.global_transform = slot.global_transform
		made.append(block)
	return made


## Diagnóstico com os vãos abertos: o centro de cada vão tem de estar sobre a malha e a faixa livre tem de passar
## MIN_GAP_HALF_M para cada lado. A largura da faixa é a folga real que o agente tem no vão de 0,9 m.
func _check_gaps(open_nav: NavigationMesh) -> void:
	var verts: PackedVector3Array = open_nav.get_vertices()
	for node: Node in get_nodes_in_group(DOOR_SLOT_GROUP):
		var slot: Node3D = node as Node3D
		if slot == null or not _scene.is_ancestor_of(slot):
			continue
		var door_id: String = str(slot.get_meta(&"door_id", slot.name))
		var centre: Vector3 = slot.global_position
		centre.y = 0.0
		var along: Vector2 = Vector2(slot.global_transform.basis.z.x, slot.global_transform.basis.z.z).normalized()
		var centre_2d: Vector2 = Vector2(centre.x, centre.z)
		if not _walkable(open_nav, verts, centre_2d):
			_fail("%s: o centro do vão não está na malha sem bloqueio" % door_id)
			continue
		var half: float = 0.0
		var t: float = SAMPLE_STEP_M
		while t <= SAMPLE_MAX_M:
			var plus: bool = _walkable(open_nav, verts, centre_2d + along * t)
			var minus: bool = _walkable(open_nav, verts, centre_2d - along * t)
			if not (plus and minus):
				break
			half = t
			t += SAMPLE_STEP_M
		var ok: bool = half >= MIN_GAP_HALF_M
		print("vão %s: faixa livre de %.2f m (meia largura %.2f m) %s" % [
			door_id, half * 2.0, half, "OK" if ok else "FALHA"])
		if not ok:
			_fail("%s: faixa livre menor que %.2f m de meia largura" % [door_id, MIN_GAP_HALF_M])


func _walkable(nav: NavigationMesh, verts: PackedVector3Array, point: Vector2) -> bool:
	for index: int in range(nav.get_polygon_count()):
		var poly: PackedInt32Array = nav.get_polygon(index)
		if poly.size() < 3:
			continue
		if verts[poly[0]].y > FLOOR_Y_LIMIT_M:
			continue
		if _inside(verts, poly, point):
			return true
	return false


func _inside(verts: PackedVector3Array, poly: PackedInt32Array, point: Vector2) -> bool:
	var sign_seen: int = 0
	for i: int in range(poly.size()):
		var a: Vector3 = verts[poly[i]]
		var b: Vector3 = verts[poly[(i + 1) % poly.size()]]
		var edge: Vector2 = Vector2(b.x - a.x, b.z - a.z)
		var rel: Vector2 = point - Vector2(a.x, a.z)
		var cross: float = edge.x * rel.y - edge.y * rel.x
		if absf(cross) < 1e-6:
			continue
		var s: int = 1 if cross > 0.0 else -1
		if sign_seen == 0:
			sign_seen = s
		elif s != sign_seen:
			return false
	return true


func _report_height(nav: NavigationMesh) -> void:
	var verts: PackedVector3Array = nav.get_vertices()
	var top: float = -INF
	for v: Vector3 in verts:
		top = maxf(top, v.y)
	print("altura máxima da malha: %.2f m (mezanino esperado em 1,08 m)" % top)


func _fail(message: String) -> void:
	_failures += 1
	printerr("bake_navmesh FALHA: " + message)

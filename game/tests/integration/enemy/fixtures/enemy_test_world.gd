class_name EnemyTestWorld
extends RefCounted
## Apoio aos testes do EnemyController (F4-004). Mundo de teste isolado (add_isolated_world): piso de navmesh montada à
## mão (sem bake: vértices e um polígono por metade do quadrado), alvos com sonda de luz, paredes, salas acústicas e rotas.
## Por que mundo próprio e não a sandbox nos cenários de AI-02..AI-06: a navmesh é exata e pequena (o caminho é sempre
## reto), o cenário não depende da cena de nível (portas, jogador e outros marcadores) e o teste roda em milissegundos.
## Os testes de portas e de rota usam a sandbox real (ver tests/property/enemy).
## Só dado de teste; não é usado pela produção. Autor: AI Engineer (F4-004).

const OBSERVER_SCENE_PATH: String = "res://content/enemies/observer.tscn"
const LAYER_WORLD_STATIC: int = 1
const LAYER_PLAYER_BODY: int = 4
const FLOOR_THICKNESS_M: float = 0.5
const FLOOR_TOP_BELOW_M: float = 0.01
const LAMP_HEIGHT_M: float = 3.0
const LAMP_ENERGY: float = 2.0
const LAMP_RANGE_M: float = 8.0
const SAMPLE_HEAD_M: float = 1.5
const SAMPLE_TORSO_M: float = 1.0
const SAMPLE_FEET_M: float = 0.5


## Piso de navmesh quadrado de half_m de meia-largura, no plano y = 0, em dois triângulos.
static func navigation_floor(container: Node3D, half_m: float) -> NavigationRegion3D:
	var mesh: NavigationMesh = NavigationMesh.new()
	var vertices: PackedVector3Array = PackedVector3Array([
		Vector3(-half_m, 0.0, -half_m), Vector3(half_m, 0.0, -half_m),
		Vector3(half_m, 0.0, half_m), Vector3(-half_m, 0.0, half_m),
	])
	mesh.set_vertices(vertices)
	mesh.add_polygon(PackedInt32Array([0, 1, 2]))
	mesh.add_polygon(PackedInt32Array([0, 2, 3]))
	var region: NavigationRegion3D = NavigationRegion3D.new()
	region.navigation_mesh = mesh
	container.add_child(region)
	# Piso físico (camada 1), face de cima 1 cm abaixo de y = 0: sem ele o inimigo cai (a navmesh não tem colisão). A face
	# fica abaixo do nível dos pés dos alvos: a sonda de luz amostra em y = 0 e um piso a essa altura bloquearia a luz.
	var floor_body: StaticBody3D = StaticBody3D.new()
	floor_body.collision_layer = LAYER_WORLD_STATIC
	var shape_node: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(2.0 * half_m, FLOOR_THICKNESS_M, 2.0 * half_m)
	shape_node.shape = box
	shape_node.position = Vector3(0.0, -FLOOR_TOP_BELOW_M - FLOOR_THICKNESS_M * 0.5, 0.0)
	floor_body.add_child(shape_node)
	container.add_child(floor_body)
	# Mapa do mundo do contêiner ativo: num SubViewport isolado o servidor não sincroniza o mapa sem isto.
	NavigationServer3D.map_set_active(container.get_world_3d().get_navigation_map(), true)
	return region


## Um Observer (cena de produção) em `at`, filho de container.
static func spawn_observer(container: Node3D, at: Vector3) -> EnemyController:
	var packed: PackedScene = load(OBSERVER_SCENE_PATH) as PackedScene
	var enemy: EnemyController = packed.instantiate() as EnemyController
	enemy.position = at
	container.add_child(enemy)
	return enemy


## Marcadores de rota: um por ponto, com route_id e order (o mesmo formato dos da sandbox).
static func add_route(container: Node3D, route_id: StringName, points: PackedVector3Array) -> void:
	for index: int in range(points.size()):
		var marker: Marker3D = Marker3D.new()
		marker.position = points[index]
		marker.set_meta(&"route_id", route_id)
		marker.set_meta(&"order", index)
		marker.add_to_group(&"patrol_point")
		container.add_child(marker)


## Alvo perceptível (PerceivableTarget com três pontos de amostra) com a base em `at`. Com lit, uma lâmpada e uma sonda
## de luz dão exposição 1,0 (AI-03), como em tests/integration/perception.
static func add_target(container: Node3D, at: Vector3, lit: bool) -> PerceivableTarget:
	var target: PerceivableTarget = PerceivableTarget.new()
	target.position = at
	container.add_child(target)
	var typed: Array[Marker3D] = []
	for height: float in [SAMPLE_HEAD_M, SAMPLE_TORSO_M, SAMPLE_FEET_M]:
		var marker: Marker3D = Marker3D.new()
		marker.position = Vector3(0.0, height, 0.0)
		target.add_child(marker)
		typed.append(marker)
	target.sample_points = typed
	if lit:
		var lamp: OmniLight3D = OmniLight3D.new()
		lamp.position = Vector3(0.0, LAMP_HEIGHT_M, 0.0)
		lamp.light_energy = LAMP_ENERGY
		lamp.omni_range = LAMP_RANGE_M
		target.add_child(lamp)
		var probe: LightExposureProbe = LightExposureProbe.new()
		probe.update_hz = 60.0
		target.add_child(probe)
		target.set_light_probe(probe)
	return target


## Parede (camada 1, a do mundo estático). Bloqueia a linha de visão do sensor.
static func add_wall(container: Node3D, centre: Vector3, size: Vector3) -> StaticBody3D:
	var body: StaticBody3D = StaticBody3D.new()
	body.position = centre
	body.collision_layer = LAYER_WORLD_STATIC
	var shape_node: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = size
	shape_node.shape = box
	body.add_child(shape_node)
	container.add_child(body)
	return body


## Corpo na camada do jogador (4), sem colisão com o inimigo além de estar sobreposto. Usado para a sobreposição da
## captura: o teste escolhe onde ele fica; o inimigo não o empurra (a máscara do inimigo não inclui a camada 3).
static func add_player_layer_body(container: Node3D, at: Vector3, radius: float) -> StaticBody3D:
	var body: StaticBody3D = StaticBody3D.new()
	body.position = at
	body.collision_layer = LAYER_PLAYER_BODY
	body.collision_mask = 0
	var shape_node: CollisionShape3D = CollisionShape3D.new()
	var capsule: CapsuleShape3D = CapsuleShape3D.new()
	capsule.radius = radius
	capsule.height = 1.8
	shape_node.shape = capsule
	shape_node.position = Vector3(0.0, 0.9, 0.0)
	body.add_child(shape_node)
	container.add_child(body)
	return body


## Sala acústica (RoomVolume com piso ambiente floor_db) e a caixa do tamanho size centrada em centre.
static func add_room(container: Node3D, room_id: StringName, centre: Vector3, size: Vector3, floor_db: float) -> void:
	var room: RoomVolume = RoomVolume.new()
	room.room_id = room_id
	room.ambient_floor_db = floor_db
	room.position = centre
	var shape_node: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = size
	shape_node.shape = box
	room.add_child(shape_node)
	container.add_child(room)


## Mundo acústico do nível de teste, com o ouvido do jogador em `ear` (sem ouvido, o AcousticWorld avisa a cada teste).
static func add_acoustic_world(container: Node3D, ear: Node3D) -> AcousticWorld:
	var world: AcousticWorld = AcousticWorld.new()
	container.add_child(world)
	world.set_player_ear(ear)
	return world

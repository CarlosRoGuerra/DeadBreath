extends RefCounted
## Fixture da ameaça percebida pelo jogador (F4-006b): inimigo de teste no grupo "enemy", com corpo visível na camada 4
## (fora da máscara de visão, como os corpos de inimigos de verdade) e um NoiseEmitter de fonte enemy_test. Também monta
## luz e parede de teste. Pasta "fixtures" não é descoberta pelo runner. Autor: Gameplay Engineer.

const ENEMY_LAYER: int = 8
const ENEMY_SOURCE: StringName = &"enemy_test"
## Origem do inimigo a 0,75 m do chão: o centro (origem + 0,9 m) fica na altura dos olhos do jogador (1,65 m).
const ENEMY_ORIGIN_EYE_LEVEL_Y: float = 0.75
const ENEMY_RADIUS_M: float = 0.3
const ENEMY_HEIGHT_M: float = 1.8
const CENTRE_OFFSET_Y: float = 0.9


## Inimigo de teste em position (coordenadas do pai). Devolve o corpo; o emissor é emitter_of(corpo).
static func make_enemy(parent: Node3D, position: Vector3) -> CharacterBody3D:
	var body: CharacterBody3D = CharacterBody3D.new()
	body.add_to_group(&"enemy")
	body.collision_layer = ENEMY_LAYER
	body.collision_mask = 0
	body.position = position
	var capsule: CapsuleShape3D = CapsuleShape3D.new()
	capsule.radius = ENEMY_RADIUS_M
	capsule.height = ENEMY_HEIGHT_M
	var shape_node: CollisionShape3D = CollisionShape3D.new()
	shape_node.shape = capsule
	shape_node.position = Vector3(0.0, CENTRE_OFFSET_Y, 0.0)
	body.add_child(shape_node)
	var mesh: CapsuleMesh = CapsuleMesh.new()
	mesh.radius = ENEMY_RADIUS_M
	mesh.height = ENEMY_HEIGHT_M
	var mesh_node: MeshInstance3D = MeshInstance3D.new()
	mesh_node.mesh = mesh
	mesh_node.position = Vector3(0.0, CENTRE_OFFSET_Y, 0.0)
	body.add_child(mesh_node)
	var emitter: NoiseEmitter = NoiseEmitter.new()
	emitter.source_id = ENEMY_SOURCE
	body.add_child(emitter)
	parent.add_child(body)
	return body


## NoiseEmitter filho direto do inimigo de teste.
static func emitter_of(body: Node3D) -> NoiseEmitter:
	for child: Node in body.get_children():
		var emitter: NoiseEmitter = child as NoiseEmitter
		if emitter != null:
			return emitter
	return null


## Luz omni de teste (energia e alcance) na posição dada, no pai.
static func add_light(parent: Node3D, position: Vector3, range_m: float) -> OmniLight3D:
	var light: OmniLight3D = OmniLight3D.new()
	light.position = position
	light.omni_range = range_m
	light.light_energy = 4.0
	parent.add_child(light)
	return light


## Piso de teste: topo em y = 0, de z = +6 a z = -20, largura 8 m (o jogador olha para -Z).
static func add_floor(parent: Node3D) -> void:
	var body: StaticBody3D = StaticBody3D.new()
	body.position = Vector3(0.0, -0.5, -7.0)
	var shape_node: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(8.0, 1.0, 26.0)
	shape_node.shape = box
	body.add_child(shape_node)
	parent.add_child(body)

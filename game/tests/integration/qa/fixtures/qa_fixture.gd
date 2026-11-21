extends RefCounted
## Fixture da validação independente da F1 (F1-011, QA Engineer). Pasta "fixtures": o runner não a descobre.
## Helpers de bot e de medição escritos do zero pelo QA, sem reutilizar os fixtures dos implementadores,
## para que as medições sejam independentes. Não contém asserts; os testes que a usam é que julgam.

const SANDBOX_PATH: String = "res://content/levels/sandbox.tscn"
const PLAYABLE_PATH: String = "res://content/levels/sandbox_playable.tscn"
## world_static (1) + world_dynamic (2): geometria e painéis de porta.
const WORLD_MASK: int = 3
const BODY_RADIUS_M: float = 0.25
## Encolhimento da forma usada para medir penetração (1 cm). Contato de margem de segurança (~1 mm) não conta.
const PENETRATION_SHRINK_M: float = 0.01
const EYE_OFFSET_M: float = 0.10
const STAND_HEIGHT_M: float = 1.75
const CROUCH_HEIGHT_M: float = 1.10
const CRAWL_HEIGHT_M: float = 0.55

## Ação de postura de um tick de bot.
const EDGE_NONE: int = 0
const EDGE_CROUCH: int = 1
const EDGE_CRAWL: int = 2


## Altura dos olhos acima dos pés, por postura (topo do colisor - eye_offset).
static func eye_height_for(stance: Enums.Stance) -> float:
	if stance == Enums.Stance.CRAWL:
		return CRAWL_HEIGHT_M - EYE_OFFSET_M
	if stance == Enums.Stance.CROUCH:
		return CROUCH_HEIGHT_M - EYE_OFFSET_M
	return STAND_HEIGHT_M - EYE_OFFSET_M


## Entrada de um tick com uma ação de borda (postura). Zera o resto.
static func edge_input(edge: int) -> MotorInput:
	var input: MotorInput = MotorInput.new()
	if edge == EDGE_CROUCH:
		input.crouch_pressed = true
	elif edge == EDGE_CRAWL:
		input.crawl_pressed = true
	return input


## Entrada de movimento contínuo. move.x = direita, move.y = frente.
static func move_input(move: Vector2, sprint: bool = false, slow_walk: bool = false) -> MotorInput:
	var input: MotorInput = MotorInput.new()
	input.move = move
	input.sprint = sprint
	input.slow_walk = slow_walk
	return input


const PLAYER_SCENE_PATH: String = "res://components/player/player.tscn"


## Instancia o jogador (player.tscn) dentro de parent, na posição indicada (pés na origem do corpo).
static func spawn_player_in(parent: Node3D, position: Vector3) -> PlayerRoot:
	var packed: PackedScene = load(PLAYER_SCENE_PATH) as PackedScene
	var player: PlayerRoot = packed.instantiate() as PlayerRoot
	player.position = position
	parent.add_child(player)
	return player


## Instancia uma cena de nível dentro de parent e devolve a raiz. Não toca na árvore principal além disso.
static func instantiate_level(path: String, parent: Node) -> Node3D:
	var packed: PackedScene = load(path) as PackedScene
	if packed == null:
		return null
	var level: Node3D = packed.instantiate() as Node3D
	parent.add_child(level)
	return level


## Instancia uma cena de qualquer raiz (ex.: sandbox_playable.tscn, cuja raiz é Node) dentro de parent.
static func instantiate_scene(path: String, parent: Node) -> Node:
	var packed: PackedScene = load(path) as PackedScene
	var root: Node = packed.instantiate()
	parent.add_child(root)
	return root


## Jogador de uma cena qualquer (procura pelo nome "Player" na subárvore).
static func find_player(root: Node) -> PlayerRoot:
	return root.find_child("Player", true, false) as PlayerRoot


## Penetração: o colisor do jogador (com 1 cm de folga para dentro) cruza geometria de mundo?
## Usa a forma atual do colisor (altura da postura) e exclui o próprio corpo e o objeto na mão (Director, BUG-016: desde
## a correção, o objeto segurado para na parede, diante da câmera, e pode sobrepor o volume do próprio jogador; ele
## não é geometria de mundo).
static func body_overlaps_world(player: PlayerRoot) -> bool:
	var height: float = player.get_motor().get_collider_height()
	var shape: CylinderShape3D = CylinderShape3D.new()
	shape.radius = BODY_RADIUS_M - PENETRATION_SHRINK_M
	shape.height = maxf(height - 2.0 * PENETRATION_SHRINK_M, 0.01)
	var query: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = player.global_transform * Transform3D(Basis.IDENTITY, Vector3(0.0, height * 0.5, 0.0))
	query.collision_mask = WORLD_MASK
	var exclude: Array[RID] = [player.get_rid()]
	var held: Throwable = player.get_hold().get_held() if player.get_hold() != null else null
	if held != null:
		exclude.append(held.get_rid())
	query.exclude = exclude
	var hits: Array[Dictionary] = player.get_world_3d().direct_space_state.intersect_shape(query, 1)
	return not hits.is_empty()


## Caixa estática na camada world_static (1). surface vai para o metadado lido pelos passos.
static func add_box(parent: Node3D, center: Vector3, size: Vector3, surface: StringName = &"") -> StaticBody3D:
	var body: StaticBody3D = StaticBody3D.new()
	body.position = center
	var shape_node: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = size
	shape_node.shape = box
	body.add_child(shape_node)
	if not surface.is_empty():
		body.set_meta(&"surface", surface)
	parent.add_child(body)
	return body


## Medidor de um trecho de bot: ticks, ticks sem chão (total e a maior sequência), eventos landed e
## ticks com penetração. Conecta-se ao sinal landed do motor com connect_motor().
class Meter extends RefCounted:
	var ticks: int = 0
	var airborne: int = 0
	var airborne_run_max: int = 0
	var landed: int = 0
	var penetrations: int = 0
	var first_penetration_tick: int = -1
	var _run: int = 0

	func connect_motor(player: PlayerRoot) -> void:
		player.get_motor().landed.connect(_on_landed)

	## overlaps = body_overlaps_world(player), calculado pelo chamador (função estática deste arquivo).
	func sample(player: PlayerRoot, overlaps: bool) -> void:
		ticks += 1
		if player.is_on_floor():
			_run = 0
		else:
			airborne += 1
			_run += 1
			airborne_run_max = maxi(airborne_run_max, _run)
		if overlaps:
			penetrations += 1
			if first_penetration_tick < 0:
				first_penetration_tick = ticks

	func _on_landed(_fall_speed: float) -> void:
		landed += 1

	func summary() -> String:
		return "ticks=%d no_ar=%d (sequencia_max=%d) landed=%d penetracao=%d" % [ticks, airborne, airborne_run_max, landed, penetrations]

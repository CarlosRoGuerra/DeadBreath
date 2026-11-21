class_name Throwable
extends RigidBody3D
## Throwable (L2, F3-004): objeto arremessável (RigidBody3D, camada world_dynamic). A "pega" é um Interactable filho
## direto (o InteractionComponent aceita isso). Tocar na pega pega o objeto; tocar de novo, com o objeto na mão, solta
## (o PlayerHold decide se a soltura é possível). Arremesso: ação throw, pelo PlayerHold.
## Impacto: OBJECT_IMPACT com sound_id impact, intensidade pela velocidade e pelo tamanho (PlayerNoiseMap.impact_db).
## Sem ruído abaixo de IMPACT_MIN_SPEED_MS e no máximo um evento a cada IMPACT_COOLDOWN_S por objeto.
## Empurrar com o corpo do jogador fica fora (limitação registrada): o CharacterBody3D só bloqueia o objeto.

signal picked_up(actor: Node)
signal released()

const HOLD_PATH: NodePath = ^"PlayerHold"
const SHAPE_PATH: NodePath = ^"CollisionShape3D"
## Máscara do teste de soltura: mundo estático (1), dinâmico (2) e jogador (4).
const DROP_MASK: int = 7
## BUG-016: a mão não atravessa o mundo. A forma é varrida contra o mundo estático (1) e dinâmico (2).
const HOLD_SWEEP_MASK: int = 3
## Passo do avanço da câmera rumo à mão quando a câmera já sobrepõe o mundo com a forma do objeto.
const HOLD_FORWARD_STEP_M: float = 0.1
const NOISE_LEVELS: NoiseLevels = preload("res://content/data/acoustics/noise_levels.tres")
## Revisão F3-010, R3-04: depois que o jogador solta ou arremessa, os impactos são "causados pelo jogador" (prefixo
## AcousticWorld.PLAYER_CAUSED_PREFIX) até o objeto dormir ou ser pego de novo: não assustam o próprio jogador.
const PLAYER_CAUSED_TAG: String = "thrown_"
## Verificação F3-010, N3: a causa do jogador vale no máximo este tempo depois da soltura (ou até o repouso, o que
## vier primeiro). Um objeto que nunca dorme não fica "do jogador" para sempre.
const PLAYER_CAUSED_MAX_S: float = 3.0

@export var throwable_id: StringName = &""
@export_enum("light", "medium", "heavy") var size: String = "light"

@onready var _grip: Interactable = $Grip
@onready var _noise: NoiseEmitter = $NoiseEmitter

var _held_by: Node = null
var _base_source: StringName = &""
var _player_caused_left_s: float = 0.0
var _speed_before_step: float = 0.0
var _cooldown_s: float = 0.0


func _ready() -> void:
	contact_monitor = true
	max_contacts_reported = 4
	body_entered.connect(_on_body_entered)
	_grip.interacted.connect(_on_grip_interacted)
	sleeping_state_changed.connect(_on_sleeping_state_changed)
	_base_source = throwable_id if throwable_id != &"" else StringName(name)
	_noise.source_id = _base_source


## source_id atual dos impactos: o id do objeto, ou o id marcado como causado pelo jogador depois de solto por ele.
func get_noise_source() -> StringName:
	return _noise.source_id


func is_player_caused() -> bool:
	return _noise.source_id != _base_source


func is_held() -> bool:
	return _held_by != null


func get_held_by() -> Node:
	return _held_by


func get_size() -> StringName:
	return StringName(size)


## Pega ou soltar, pelo jogador (ator). Quem decide é o PlayerHold do ator.
func on_interacted_by(actor: Node) -> void:
	var hold: PlayerHold = actor.get_node_or_null(HOLD_PATH) as PlayerHold
	if hold == null:
		return
	if is_held():
		if _held_by == actor:
			hold.drop_held()
		return
	hold.try_pick(self)


## Estado de mão: congelado (kinematic) e sem colisão com o ator; ao soltar, volta à física normal.
func set_held(held: bool, actor: Node) -> void:
	if held:
		_held_by = actor
		freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
		freeze = true
		linear_velocity = Vector3.ZERO
		angular_velocity = Vector3.ZERO
		if actor is PhysicsBody3D:
			add_collision_exception_with(actor as PhysicsBody3D)
		_noise.source_id = _base_source
		_player_caused_left_s = 0.0
		picked_up.emit(actor)
		return
	if _held_by is PhysicsBody3D:
		remove_collision_exception_with(_held_by as PhysicsBody3D)
	_held_by = null
	freeze = false
	_noise.source_id = StringName(AcousticWorld.PLAYER_CAUSED_PREFIX + PLAYER_CAUSED_TAG + String(_base_source))
	_player_caused_left_s = PLAYER_CAUSED_MAX_S
	released.emit()


## Posição da mão (chamada pelo PlayerHold a cada tick enquanto segura).
func set_hold_transform(target: Transform3D) -> void:
	global_transform = target


## BUG-016 (F3-011; reaberto pelo QA para o objeto pesado): posição segura da mão. Varre a forma do objeto até a posição
## desejada e para no primeiro contato com o mundo; o jogador e o próprio objeto ficam de fora. A varredura parte de um
## ponto recuado (a câmera menos o alcance da forma, rumo ao corpo), para que um objeto grande não comece a varredura
## já dentro da parede quando o jogador está encostado nela (o cast_motion não detecta a parede nesse caso). Se esse
## ponto sobrepõe o mundo (costas na parede), tenta da câmera; se os dois sobrepõem, o objeto fica onde estava.
func safe_hold_transform(from_position: Vector3, target: Transform3D, player: CollisionObject3D) -> Transform3D:
	var shape_node: CollisionShape3D = get_node_or_null(SHAPE_PATH) as CollisionShape3D
	if shape_node == null or shape_node.shape == null or not is_inside_tree():
		return target
	var toward: Vector3 = target.origin - from_position
	if toward.length() < 0.0001:
		return target
	var exclude: Array[RID] = [get_rid()]
	if player != null:
		exclude.append(player.get_rid())
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var query: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
	query.shape = shape_node.shape
	query.collision_mask = HOLD_SWEEP_MASK
	query.exclude = exclude
	var starts: Array[Vector3] = [from_position - toward.normalized() * shape_reach(shape_node.shape), from_position]
	for start: Vector3 in starts:
		query.transform = Transform3D(target.basis, start) * shape_node.transform
		query.motion = Vector3.ZERO
		if not space.intersect_shape(query, 1).is_empty():
			continue
		var motion: Vector3 = target.origin - start
		query.motion = motion
		var fractions: PackedFloat32Array = space.cast_motion(query)
		var safe: float = fractions[0] if fractions.size() > 0 else 1.0
		return Transform3D(target.basis, start + motion * safe)
	# Os dois pontos sobrepõem o mundo: objeto maior que o raio do corpo, com a câmera encostada (2ª verificação do
	# BUG-016: de costas para a parede, o objeto pesado ficava no ponto antigo). Avança da câmera rumo à mão em passos
	# curtos até um ponto livre, só enquanto o raio da câmera até esse ponto não cruza nada: de frente para a parede o
	# raio bate nela, e o objeto não pula para o outro lado.
	var direction: Vector3 = toward.normalized()
	var ray: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from_position, from_position,
		HOLD_SWEEP_MASK, exclude)
	var advance: float = HOLD_FORWARD_STEP_M
	while advance < toward.length():
		var candidate: Vector3 = from_position + direction * advance
		ray.to = candidate
		if not space.intersect_ray(ray).is_empty():
			break
		query.transform = Transform3D(target.basis, candidate) * shape_node.transform
		query.motion = Vector3.ZERO
		if space.intersect_shape(query, 1).is_empty():
			var rest: Vector3 = target.origin - candidate
			query.motion = rest
			var rest_fractions: PackedFloat32Array = space.cast_motion(query)
			var rest_safe: float = rest_fractions[0] if rest_fractions.size() > 0 else 1.0
			return Transform3D(target.basis, candidate + rest * rest_safe)
		advance += HOLD_FORWARD_STEP_M
	return global_transform


## Alcance da forma a partir do centro (raio da esfera que a contém).
static func shape_reach(shape: Shape3D) -> float:
	if shape is BoxShape3D:
		return (shape as BoxShape3D).size.length() * 0.5
	if shape is SphereShape3D:
		return (shape as SphereShape3D).radius
	if shape is CylinderShape3D:
		var cylinder: CylinderShape3D = shape as CylinderShape3D
		return Vector2(cylinder.radius, cylinder.height * 0.5).length()
	if shape is CapsuleShape3D:
		return (shape as CapsuleShape3D).height * 0.5
	return 0.5


## A forma cabe na posição dada, sem sobrepor mundo nem jogador? Usada antes de soltar.
func can_place_at(target: Transform3D, player: CollisionObject3D) -> bool:
	var shape_node: CollisionShape3D = get_node_or_null(SHAPE_PATH) as CollisionShape3D
	if shape_node == null or shape_node.shape == null or not is_inside_tree():
		return false
	var query: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
	query.shape = shape_node.shape
	query.transform = target * shape_node.transform
	query.collision_mask = DROP_MASK
	var exclude: Array[RID] = [get_rid()]
	if player != null:
		exclude.append(player.get_rid())
	query.exclude = exclude
	return get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()


## A velocidade é lida antes do passo físico (o sinal body_entered chega depois da resolução do contato, com a
## velocidade já amortecida); por isso não é lida em _integrate_forces.
func _physics_process(delta: float) -> void:
	_speed_before_step = linear_velocity.length()
	_cooldown_s = maxf(_cooldown_s - delta, 0.0)
	if _player_caused_left_s > 0.0:
		_player_caused_left_s -= delta
		if _player_caused_left_s <= 0.0 and not is_held():
			_player_caused_left_s = 0.0
			_noise.source_id = _base_source


## Em repouso, o objeto volta a ser fonte própria (um inimigo que o derrube depois não é "causado pelo jogador").
func _on_sleeping_state_changed() -> void:
	if sleeping and not is_held():
		_noise.source_id = _base_source


func _on_grip_interacted(actor: Node) -> void:
	on_interacted_by(actor)


func _on_body_entered(_body: Node) -> void:
	if is_held() or _cooldown_s > 0.0:
		return
	if not PlayerNoiseMap.impact_is_audible(_speed_before_step):
		return
	var level: float = PlayerNoiseMap.impact_db(_speed_before_step, get_size(), _impact_range())
	_noise.emit_noise(Enums.NoiseCategory.OBJECT_IMPACT, level, 0.0, &"impact")
	_cooldown_s = PlayerNoiseMap.IMPACT_COOLDOWN_S


func _impact_range() -> Vector2:
	return NOISE_LEVELS.object_impact_range_db

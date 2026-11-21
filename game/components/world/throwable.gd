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

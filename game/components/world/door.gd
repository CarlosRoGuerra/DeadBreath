class_name Door
extends Interactable
## Door (L2, COMPONENT_CONTRACTS §3, F1-007; fechar e ruídos na F3-004). Estados CLOSED, OPEN e LOCKED.
## Segurar abre/fecha devagar (slow = true); toque abre/fecha no tempo normal. Trancada: locked_feedback(actor).
## Fechar só vale com a porta aberta e parada. Porta em movimento conta como aberta (COMPONENT_CONTRACTS §6.5): o
## estado só vira CLOSED no fim do fechamento, então o portal do AcousticWorld fecha no state_changed final.
## Ruídos (F3-004, DOOR): abrir/fechar 30 dB (devagar, door_slow) ou 50 dB (door_normal); trancada 45 dB
## (door_locked); painel batendo num corpo 40 dB (door_normal). Fonte: door_id. Não é Saveable (fica para a F5).
## O movimento avança no tick de física (sem Tween), então é determinístico com passo fixo.
## Painel que não empurra (BUG-006, BUG-009, contrato §3.1): a cada tick o painel tenta avançar um incremento. O novo
## ângulo só vale se a caixa do painel, crescida em CLEARANCE_M, não encosta em corpo móvel (camadas 2, 3 e 4:
## objetos dinâmicos, jogador e inimigos). Se encostaria, ele fica onde está e emite blocked(body) uma vez por
## bloqueio. Retoma quando o caminho fica livre. Abrindo ou fechando, o bloqueio vale igual.
## Geometria estática (camada 1) não bloqueia: o arco livre é responsabilidade do level design (BUG-009).

enum State { CLOSED, OPEN, LOCKED }

signal state_changed(old_state: State, new_state: State)
## Emitido no início da abertura. slow = true quando foi segurado.
signal opened(slow: bool)
## Emitido no início do fechamento (F3-004). slow = true quando foi segurado.
signal closed(slow: bool)
## Porta trancada e o jogador tentou abrir: feedback para a UI e o áudio.
signal locked_feedback(actor: Node)
## O painel parou porque encostaria em body. Emitido uma vez por bloqueio.
signal blocked(body: Node)

## Camadas que travam o painel: objetos dinâmicos (2), jogador (3, valor 4) e inimigos (4, valor 8).
const BLOCK_MASK: int = 14
## Folga mínima entre o painel e o corpo (m): a caixa de consulta cresce 2 cm por lado.
const CLEARANCE_M: float = 0.02
## Níveis de ruído da porta. Trancada e batida não estão em NoiseLevels (DATA §2.1 é de sim/): valores locais,
## para o Acústica confirmar em DATA §2.1 (F3-004).
const LOCKED_DB: float = 45.0
const BLOCKED_DB: float = 40.0
const SOUND_SLOW: StringName = &"door_slow"
const SOUND_NORMAL: StringName = &"door_normal"
const SOUND_LOCKED: StringName = &"door_locked"
const NOISE_LEVELS: NoiseLevels = preload("res://content/data/acoustics/noise_levels.tres")

@export var door_id: StringName = &""
@export var initial_state: State = State.CLOSED
## Duração do movimento de abrir e de fechar (a mesma nos dois sentidos).
@export var open_time_fast_s: float = 0.35
@export var open_time_slow_s: float = 1.6
@export var open_angle_deg: float = 90.0

@onready var _panel: AnimatableBody3D = $Panel
@onready var _noise: NoiseEmitter = $NoiseEmitter

var _state: State = State.CLOSED
var _moving: bool = false
var _closing: bool = false
var _duration: float = 0.0
var _angle_deg: float = 0.0
var _blocked: bool = false


func _ready() -> void:
	_state = initial_state
	# Porta que começa aberta já nasce com o painel no ângulo de abertura (achado da integração F1-009).
	_angle_deg = open_angle_deg if _state == State.OPEN else 0.0
	_panel.rotation.y = deg_to_rad(_angle_deg)
	_noise.source_id = door_id if door_id != &"" else StringName(name)


func get_state() -> State:
	return _state


func is_moving() -> bool:
	return _moving


func is_closing() -> bool:
	return _moving and _closing


func is_blocked() -> bool:
	return _blocked


func get_panel_angle_deg() -> float:
	return _angle_deg


func lock() -> void:
	if _state == State.CLOSED and not _moving:
		_set_state(State.LOCKED)


func unlock() -> void:
	if _state == State.LOCKED:
		_set_state(State.CLOSED)


func can_interact(_context: InteractionContext) -> bool:
	return _state == State.LOCKED or not _moving


func interact(context: InteractionContext) -> void:
	if _state == State.LOCKED:
		locked_feedback.emit(context.actor)
		_emit_sound(LOCKED_DB, SOUND_LOCKED)
		return
	if _moving:
		return
	if _state == State.CLOSED:
		_begin_opening(context.held, context.actor)
	elif _state == State.OPEN:
		_begin_closing(context.held, context.actor)


func _begin_opening(slow: bool, actor: Node) -> void:
	_set_state(State.OPEN)
	_start_movement(false, slow)
	opened.emit(slow)
	_emit_movement_sound(slow)
	interacted.emit(actor)


## Fechar: o estado continua OPEN até o fim do movimento (portal aberto enquanto a porta se move).
func _begin_closing(slow: bool, actor: Node) -> void:
	_start_movement(true, slow)
	closed.emit(slow)
	_emit_movement_sound(slow)
	interacted.emit(actor)


func _start_movement(closing: bool, slow: bool) -> void:
	_moving = true
	_closing = closing
	_blocked = false
	_duration = open_time_slow_s if slow else open_time_fast_s


func _finish_movement() -> void:
	_moving = false
	if _closing:
		_closing = false
		_set_state(State.CLOSED)


func _emit_movement_sound(slow: bool) -> void:
	if slow:
		_emit_sound(NOISE_LEVELS.door_slow_db, SOUND_SLOW)
	else:
		_emit_sound(NOISE_LEVELS.door_normal_db, SOUND_NORMAL)


func _emit_sound(level_db: float, sound_id: StringName) -> void:
	_noise.emit_noise(Enums.NoiseCategory.DOOR, level_db, 0.0, sound_id)


func _set_state(new_state: State) -> void:
	var old_state: State = _state
	_state = new_state
	if old_state != new_state:
		state_changed.emit(old_state, new_state)


## Histerese da liberação (BUG-010): bloqueado, o painel só volta a andar quando DOIS incrementos seguidos
## estão livres. Sem isso, um corpo saindo devagar do arco fazia a porta liberar e bloquear de novo no tick
## seguinte, emitindo blocked duas vezes para o mesmo contato.
func _physics_process(delta: float) -> void:
	if not _moving:
		return
	var direction: float = -1.0 if _closing else 1.0
	var step_deg: float = open_angle_deg / _duration * delta
	var candidate: float = _clamp_angle(_angle_deg + direction * step_deg)
	var blocker: Node = _first_blocker(candidate)
	if blocker == null and _blocked:
		blocker = _first_blocker(_clamp_angle(candidate + direction * step_deg))
	if blocker == null:
		_angle_deg = candidate
		_blocked = false
		_panel.rotation.y = deg_to_rad(_angle_deg)
		if _reached_end():
			_finish_movement()
	elif not _blocked:
		_blocked = true
		blocked.emit(blocker)
		_emit_sound(BLOCKED_DB, SOUND_NORMAL)


func _clamp_angle(angle_deg: float) -> float:
	return clampf(angle_deg, 0.0, open_angle_deg)


func _reached_end() -> bool:
	if _closing:
		return _angle_deg <= 0.0
	return _angle_deg >= open_angle_deg


## Corpo que o painel, no ângulo dado, sobrepõe; null se o caminho está livre. O próprio painel não conta.
func _first_blocker(angle_deg: float) -> Node:
	var shape_node: CollisionShape3D = _panel.get_node("CollisionShape3D") as CollisionShape3D
	var box: BoxShape3D = shape_node.shape as BoxShape3D
	var grown: BoxShape3D = BoxShape3D.new()
	grown.size = box.size + Vector3.ONE * (2.0 * CLEARANCE_M)
	var query: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
	query.shape = grown
	query.transform = global_transform * Transform3D(Basis(Vector3.UP, deg_to_rad(angle_deg)), Vector3.ZERO) * shape_node.transform
	query.collision_mask = BLOCK_MASK
	query.exclude = [_panel.get_rid()]
	var hits: Array[Dictionary] = get_world_3d().direct_space_state.intersect_shape(query, 1)
	if hits.is_empty():
		return null
	return hits[0].get("collider") as Node

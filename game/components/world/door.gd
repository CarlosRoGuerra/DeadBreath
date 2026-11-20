class_name Door
extends Interactable
## Door (L2, COMPONENT_CONTRACTS §3, F1-007). Estados CLOSED, OPEN e LOCKED. Segurar abre devagar
## (opened(true)); toque abre no tempo normal (opened(false)). Trancada: locked_feedback(actor).
## Sem acústica nesta fase: a F3 liga o NoiseEmitter em opened(slow). Não é Saveable (fica para a F5).
## A abertura avança no tick de física (sem Tween), então é determinística com passo fixo.

enum State { CLOSED, OPEN, LOCKED }

signal state_changed(old_state: State, new_state: State)
## Emitido no início da abertura. slow = true quando foi segurado.
signal opened(slow: bool)
## Porta trancada e o jogador tentou abrir: feedback para a UI e o áudio.
signal locked_feedback(actor: Node)

@export var initial_state: State = State.CLOSED
@export var open_time_fast_s: float = 0.35
@export var open_time_slow_s: float = 1.6
@export var open_angle_deg: float = 90.0

@onready var _panel: AnimatableBody3D = $Panel

var _state: State = State.CLOSED
var _moving: bool = false
var _elapsed: float = 0.0
var _duration: float = 0.0


func _ready() -> void:
	_state = initial_state
	# Porta que começa aberta já nasce com o painel no ângulo de abertura (achado da integração F1-009).
	_panel.rotation.y = deg_to_rad(open_angle_deg) if _state == State.OPEN else 0.0


func get_state() -> State:
	return _state


func is_moving() -> bool:
	return _moving


func get_panel_angle_deg() -> float:
	return rad_to_deg(_panel.rotation.y)


func lock() -> void:
	if _state == State.CLOSED and not _moving:
		_set_state(State.LOCKED)


func unlock() -> void:
	if _state == State.LOCKED:
		_set_state(State.CLOSED)


func can_interact(_context: InteractionContext) -> bool:
	return _state == State.LOCKED or (_state == State.CLOSED and not _moving)


func interact(context: InteractionContext) -> void:
	if _state == State.LOCKED:
		locked_feedback.emit(context.actor)
		return
	if _state != State.CLOSED or _moving:
		return
	_begin_opening(context.held, context.actor)


func _begin_opening(slow: bool, actor: Node) -> void:
	_set_state(State.OPEN)
	_moving = true
	_elapsed = 0.0
	_duration = open_time_slow_s if slow else open_time_fast_s
	opened.emit(slow)
	interacted.emit(actor)


func _set_state(new_state: State) -> void:
	var old_state: State = _state
	_state = new_state
	if old_state != new_state:
		state_changed.emit(old_state, new_state)


func _physics_process(delta: float) -> void:
	if not _moving:
		return
	_elapsed += delta
	var progress: float = clampf(_elapsed / _duration, 0.0, 1.0)
	_panel.rotation.y = deg_to_rad(open_angle_deg) * progress
	if progress >= 1.0:
		_moving = false

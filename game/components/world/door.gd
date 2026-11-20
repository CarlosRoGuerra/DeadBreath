class_name Door
extends Interactable
## Door (L2, COMPONENT_CONTRACTS §3, F1-007). Estados CLOSED, OPEN e LOCKED. Segurar abre devagar
## (opened(true)); toque abre no tempo normal (opened(false)). Trancada: locked_feedback(actor).
## Sem acústica nesta fase: a F3 liga o NoiseEmitter em opened(slow). Não é Saveable (fica para a F5).
## A abertura avança no tick de física (sem Tween), então é determinística com passo fixo.
## Painel que não empurra (BUG-006, BUG-009, contrato §3.1): a cada tick o painel tenta avançar um incremento. O novo
## ângulo só vale se a caixa do painel, crescida em CLEARANCE_M, não encosta em corpo móvel (camadas 2, 3 e 4:
## objetos dinâmicos, jogador e inimigos). Se encostaria, ele fica onde está e emite blocked(body) uma vez por
## bloqueio. Retoma quando o caminho fica livre. O estado continua OPEN. Geometria estática (camada 1) não bloqueia:
## o arco livre é responsabilidade do level design (BUG-009).

enum State { CLOSED, OPEN, LOCKED }

signal state_changed(old_state: State, new_state: State)
## Emitido no início da abertura. slow = true quando foi segurado.
signal opened(slow: bool)
## Porta trancada e o jogador tentou abrir: feedback para a UI e o áudio.
signal locked_feedback(actor: Node)
## O painel parou porque encostaria em body. Emitido uma vez por bloqueio (gancho de batida na F3).
signal blocked(body: Node)

## Camadas que travam o painel: objetos dinâmicos (2), jogador (3, valor 4) e inimigos (4, valor 8).
const BLOCK_MASK: int = 14
## Folga mínima entre o painel e o corpo (m): a caixa de consulta cresce 2 cm por lado.
const CLEARANCE_M: float = 0.02

@export var initial_state: State = State.CLOSED
@export var open_time_fast_s: float = 0.35
@export var open_time_slow_s: float = 1.6
@export var open_angle_deg: float = 90.0

@onready var _panel: AnimatableBody3D = $Panel

var _state: State = State.CLOSED
var _moving: bool = false
var _elapsed: float = 0.0
var _duration: float = 0.0
var _angle_deg: float = 0.0
var _blocked: bool = false


func _ready() -> void:
	_state = initial_state
	# Porta que começa aberta já nasce com o painel no ângulo de abertura (achado da integração F1-009).
	_angle_deg = open_angle_deg if _state == State.OPEN else 0.0
	_panel.rotation.y = deg_to_rad(_angle_deg)


func get_state() -> State:
	return _state


func is_moving() -> bool:
	return _moving


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
	_blocked = false
	_elapsed = 0.0
	_duration = open_time_slow_s if slow else open_time_fast_s
	opened.emit(slow)
	interacted.emit(actor)


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
	var step_deg: float = open_angle_deg / _duration * delta
	var candidate: float = minf(_angle_deg + step_deg, open_angle_deg)
	var blocker: Node = _first_blocker(candidate)
	if blocker == null and _blocked:
		blocker = _first_blocker(minf(candidate + step_deg, open_angle_deg))
	if blocker == null:
		_angle_deg = candidate
		_blocked = false
		_panel.rotation.y = deg_to_rad(_angle_deg)
		if _angle_deg >= open_angle_deg:
			_moving = false
	elif not _blocked:
		_blocked = true
		blocked.emit(blocker)


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

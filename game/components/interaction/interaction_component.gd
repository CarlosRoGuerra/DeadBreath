class_name InteractionComponent
extends Node
## InteractionComponent (L2, COMPONENT_CONTRACTS §3, F1-007). Foco pelo raio da câmera, toque e segurar.
## Oclusão: o raio só atinge as camadas de mundo (1 e 2) e interactable (5). Parede na frente = sem foco
## e sem interação. Não conhece o PlayerMotor nem a fisiologia: recebe câmera, corpo e InteractionContext
## do PlayerRoot, que é quem monta o contexto (PLR-INV-1).

## Foco mudou (null = nada em foco).
signal focus_changed(target: Interactable)
## Acréscimo da F1-007: segurar interrompido (soltou antes, ou o foco saiu do alvo). Gancho do ruído da F3.
signal interaction_failed(target: Interactable)

const WORLD_MASK: int = 3
const INTERACTABLE_MASK: int = 16
const SIGHT_MASK: int = WORLD_MASK | INTERACTABLE_MASK

@export var reach_m: float = 2.0

var _camera: Camera3D = null
var _body: CollisionObject3D = null
var _focused: Interactable = null
var _hold_target: Interactable = null
var _hold_progress: float = 0.0
var _hold_required: float = 0.0
var _held: bool = false
var _pending_press: bool = false
var _pending_release: bool = false


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"interact"):
		press_interact()
	elif event.is_action_released(&"interact"):
		release_interact()


## Injetado pelo PlayerRoot: câmera do raio e corpo excluído do raio.
func setup(camera: Camera3D, body: CollisionObject3D) -> void:
	_camera = camera
	_body = body


## Aperto do botão de interação; processado no próximo step().
func press_interact() -> void:
	_pending_press = true


## Soltura do botão de interação; processada no próximo step().
func release_interact() -> void:
	_pending_release = true


func get_focused() -> Interactable:
	if _focused != null and not is_instance_valid(_focused):
		_focused = null
	return _focused


func is_holding() -> bool:
	return _hold_target != null


## Progresso do segurar em 0..1 (0 quando não há segurar em andamento).
func get_hold_progress() -> float:
	if _hold_required <= 0.0:
		return 0.0
	return clampf(_hold_progress / _hold_required, 0.0, 1.0)


## Tempo de segurar necessário. Com requires_steady_hands: hold_time × (1 + 1,5·(1 − steadiness)).
static func required_hold_time(target: Interactable, steadiness: float) -> float:
	if not target.requires_steady_hands:
		return target.hold_time
	return target.hold_time * (1.0 + 1.5 * (1.0 - clampf(steadiness, 0.0, 1.0)))


## Um tick: foco, aperto e soltura pendentes, e avanço do segurar.
func step(delta: float, context: InteractionContext) -> void:
	_update_focus()
	if _pending_press:
		_pending_press = false
		_on_press(context)
	if _pending_release:
		_pending_release = false
		_on_release(context)
	elif _held:
		_advance_hold(delta, context)


func _on_press(context: InteractionContext) -> void:
	_held = true
	var target: Interactable = get_focused()
	if target == null or _hold_target != null:
		return
	context.held = false
	if not target.can_interact(context):
		return
	if target.hold_time <= 0.0:
		_complete(target, context, false)
		return
	_hold_target = target
	_hold_progress = 0.0
	_hold_required = required_hold_time(target, context.steadiness)


func _on_release(context: InteractionContext) -> void:
	_held = false
	if _hold_target == null:
		return
	var target: Interactable = _hold_target
	_clear_hold()
	if target.tap_completes and target.can_interact(context):
		_complete(target, context, false)
	else:
		interaction_failed.emit(target)


func _advance_hold(delta: float, context: InteractionContext) -> void:
	if _hold_target == null:
		return
	if not is_instance_valid(_hold_target):
		_clear_hold()
		return
	_hold_progress += delta
	if _hold_progress >= _hold_required:
		var target: Interactable = _hold_target
		_clear_hold()
		_complete(target, context, true)


func _complete(target: Interactable, context: InteractionContext, held: bool) -> void:
	context.held = held
	target.interact(context)


func _clear_hold() -> void:
	_hold_target = null
	_hold_progress = 0.0
	_hold_required = 0.0


func _update_focus() -> void:
	var found: Interactable = _raycast_interactable()
	if found != get_focused():
		_focused = found
		focus_changed.emit(found)
	if _hold_target != null and (not is_instance_valid(_hold_target) or _hold_target != _focused):
		var lost: Interactable = _hold_target
		_clear_hold()
		if is_instance_valid(lost):
			interaction_failed.emit(lost)


## Primeiro collider atingido pelo raio da câmera. Só conta se ele (ou um ancestral) for Interactable.
func _raycast_interactable() -> Interactable:
	if _camera == null or _body == null or not _camera.is_inside_tree() or not _body.is_inside_tree():
		return null
	var origin: Vector3 = _camera.global_position
	var direction: Vector3 = -_camera.global_transform.basis.z
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
		origin, origin + direction * reach_m, SIGHT_MASK, [_body.get_rid()])
	var hit: Dictionary = _camera.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return null
	var node: Node = hit.get("collider") as Node
	while node != null:
		var target: Interactable = node as Interactable
		if target != null:
			return target
		node = node.get_parent()
	return null

class_name Pickup
extends Interactable
## Pickup (L2, COMPONENT_CONTRACTS §3, F1-007). Ao ser apanhado emite EventBus.item_picked e se remove.
## persist_id é obrigatório (ARC-02): sem ele o pickup fica inerte e registra Log.error.
## Saveable (consumido ou não) fica para a F5.

const LOG_CATEGORY: StringName = &"interaction"

@export var persist_id: StringName = &""
@export var item_id: StringName = &""
@export var quantity: int = 1

var _inert: bool = false
var _consumed: bool = false


func _ready() -> void:
	if persist_id.is_empty():
		_inert = true
		Log.error(LOG_CATEGORY, "pickup '%s' sem persist_id; fica inerte e não é salvo" % name)


func can_interact(_context: InteractionContext) -> bool:
	return not _inert and not _consumed


func interact(context: InteractionContext) -> void:
	if not can_interact(context):
		return
	_consumed = true
	EventBus.item_picked.emit(item_id, quantity, persist_id)
	interacted.emit(context.actor)
	queue_free()

class_name InventoryComponent
extends Node
## InventoryComponent (L2, F2-005): inventário mínimo do jogador sobre o InventoryModel (L1). Alimentado pelo
## EventBus.item_picked (pickups da sandbox). Não conhece a fisiologia nem outros componentes (PLR-INV-1): o PlayerRoot
## escuta doses_changed e repassa as cargas ao PhysiologyComponent.
## O jogador começa com `starting_inhaler_units` bombinhas (1 unidade = 3 doses).

signal doses_changed(item_id: StringName, doses: int)

@export var starting_inhaler_units: int = 1

var _model: InventoryModel = InventoryModel.new()
var _started: bool = false


func _ready() -> void:
	_ensure_started()
	EventBus.item_picked.connect(_on_item_picked)


func _exit_tree() -> void:
	if EventBus.item_picked.is_connected(_on_item_picked):
		EventBus.item_picked.disconnect(_on_item_picked)


func get_doses(item_id: StringName) -> int:
	_ensure_started()
	return _model.doses(item_id)


## Consome 1 dose. Emite doses_changed quando consome.
func consume_dose(item_id: StringName) -> bool:
	_ensure_started()
	if not _model.consume_dose(item_id):
		return false
	doses_changed.emit(item_id, _model.doses(item_id))
	return true


## Soma unidades de um item (pickup ou teste). Emite doses_changed quando soma.
func add_units(item_id: StringName, units: int) -> void:
	_ensure_started()
	if _model.add_units(item_id, units) > 0:
		doses_changed.emit(item_id, _model.doses(item_id))


func to_dict() -> Dictionary:
	return _model.to_dict()


## Restaura sem emitir sinais (carga de estado não é acontecimento).
func from_dict(data: Dictionary) -> void:
	_model.from_dict(data)
	_started = true


func _ensure_started() -> void:
	if _started:
		return
	_started = true
	_model.add_units(&"inhaler", starting_inhaler_units)


func _on_item_picked(item_id: StringName, quantity: int, _persist_id: StringName) -> void:
	add_units(item_id, quantity)

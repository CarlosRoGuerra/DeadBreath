class_name RespiratoryIndicator
extends CanvasLayer
## Indicador respiratório opcional (L3, F2-007, ACC-03): mostra respiratory_state. Desligado por padrão
## (Settings.respiratory_indicator). Atualiza no próprio sinal respiratory_state_changed: ≤ 1 frame após a mudança.

const LAYER: int = 60
const LABEL_PREFIX: String = "respiração: "

var _label: Label = null
var _physiology: PhysiologyComponent = null


func _ready() -> void:
	layer = LAYER
	_label = Label.new()
	_label.position = Vector2(12.0, 80.0)
	add_child(_label)
	_apply_setting()
	Settings.changed.connect(_on_settings_changed)


func _exit_tree() -> void:
	if Settings.changed.is_connected(_on_settings_changed):
		Settings.changed.disconnect(_on_settings_changed)
	if _physiology != null and _physiology.respiratory_state_changed.is_connected(_on_state_changed):
		_physiology.respiratory_state_changed.disconnect(_on_state_changed)


func bind(physiology: PhysiologyComponent) -> void:
	if _physiology == physiology:
		return
	if _physiology != null and _physiology.respiratory_state_changed.is_connected(_on_state_changed):
		_physiology.respiratory_state_changed.disconnect(_on_state_changed)
	_physiology = physiology
	_physiology.respiratory_state_changed.connect(_on_state_changed)
	_show(_physiology.get_snapshot().respiratory_state)


func get_text() -> String:
	return _label.text if _label != null else ""


func _show(state: Enums.RespiratoryState) -> void:
	if _label != null:
		_label.text = LABEL_PREFIX + RespiratoryModel.state_name(state)


func _on_state_changed(_old: Enums.RespiratoryState, new_state: Enums.RespiratoryState) -> void:
	_show(new_state)


func _on_settings_changed(key: StringName) -> void:
	if key == &"respiratory_indicator":
		_apply_setting()


func _apply_setting() -> void:
	visible = Settings.get_bool(&"respiratory_indicator")

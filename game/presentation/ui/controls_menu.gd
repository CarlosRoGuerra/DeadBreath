class_name ControlsMenu
extends Control
## Tela de controles (L3, F1-013, ACC-05). Lista as ações remapeáveis. "Remapear" e a próxima tecla ou
## botão do mouse viram a ligação. Se o evento já é usado por outra ação, avisa o conflito e não aplica.
## Aplicada, a ligação vai para Settings.input_bindings (que grava em disco com autosave).

signal closed

const STATUS_APPLIED: String = "applied"
const STATUS_CONFLICT: String = "conflict"
const STATUS_CANCELLED: String = "cancelled"
const STATUS_IGNORED: String = "ignored"
const STATUS_INVALID: String = "invalid"
const CANCEL_KEY: int = KEY_ESCAPE

var _capturing_action: StringName = &""
var _buttons: Dictionary = {}
var _list: VBoxContainer = null
var _status: Label = null


func _ready() -> void:
	var box: VBoxContainer = VBoxContainer.new()
	box.position = Vector2(24.0, 24.0)
	add_child(box)
	var title: Label = Label.new()
	title.text = "Controles"
	box.add_child(title)
	_list = VBoxContainer.new()
	box.add_child(_list)
	_status = Label.new()
	box.add_child(_status)
	var back: Button = Button.new()
	back.text = "Voltar"
	back.pressed.connect(_on_back_pressed)
	box.add_child(back)
	_rebuild_rows()


func is_capturing() -> bool:
	return not _capturing_action.is_empty()


func get_status_text() -> String:
	if _status == null:
		return ""
	return _status.text


func get_button_text(action: StringName) -> String:
	var button: Button = _buttons.get(action) as Button
	if button == null:
		return ""
	return button.text


## Entra no modo de captura para a ação. A próxima tecla ou botão (Esc cancela) é a nova ligação.
func begin_capture(action: StringName) -> void:
	_capturing_action = action
	_set_status("Pressione a nova tecla ou botão para '%s'. Esc cancela." % String(action))


## Trata um evento de captura. Devolve STATUS_APPLIED, STATUS_CONFLICT, STATUS_CANCELLED, STATUS_INVALID ou STATUS_IGNORED.
func capture_event(event: InputEvent) -> String:
	if not is_capturing():
		return STATUS_IGNORED
	if not _is_press(event):
		return STATUS_IGNORED
	var key: InputEventKey = event as InputEventKey
	if key != null and int(key.physical_keycode) == CANCEL_KEY:
		_capturing_action = &""
		_set_status("Captura cancelada.")
		return STATUS_CANCELLED
	var entry: Dictionary = InputBindings.entry_from_event(event)
	if entry.is_empty():
		return STATUS_IGNORED
	if not InputBindings.is_valid_entry(entry):
		_set_status("Tecla ou botão não suportado: a ligação não foi alterada.")
		return STATUS_INVALID
	var action: StringName = _capturing_action
	var conflicts: PackedStringArray = InputBindings.find_conflicts(entry, action)
	if not conflicts.is_empty():
		_set_status("Conflito: %s já usa %s. Remova essa ligação antes." % [", ".join(conflicts), InputBindings.describe(entry)])
		return STATUS_CONFLICT
	if not InputBindings.rebind(action, entry):
		_set_status("Ligação inválida: a ligação não foi alterada.")
		return STATUS_INVALID
	_capturing_action = &""
	Settings.set_value(&"input_bindings", InputBindings.current_overrides())
	_rebuild_rows()
	_set_status("Ligação salva: %s = %s." % [String(action), InputBindings.describe(entry)])
	return STATUS_APPLIED


## Captura antes da GUI: uma tecla ou clique que chega aqui é consumido pela captura.
func _input(event: InputEvent) -> void:
	if not is_capturing():
		return
	var status: String = capture_event(event)
	if status != STATUS_IGNORED:
		get_viewport().set_input_as_handled()


func _rebuild_rows() -> void:
	if _list == null:
		return
	for child: Node in _list.get_children():
		_list.remove_child(child)
		child.free()
	_buttons.clear()
	for action: String in InputBindings.rebindable_actions():
		var button: Button = Button.new()
		button.text = _row_text(StringName(action))
		button.pressed.connect(_on_row_pressed.bind(StringName(action)))
		_list.add_child(button)
		_buttons[StringName(action)] = button


func _row_text(action: StringName) -> String:
	var current: Array = InputBindings.action_entries(action)
	var label: String = "(sem ligação)"
	if not current.is_empty():
		label = InputBindings.describe(current[0] as Dictionary)
	return "%s: %s" % [String(action), label]


func _on_row_pressed(action: StringName) -> void:
	begin_capture(action)


func _on_back_pressed() -> void:
	_capturing_action = &""
	closed.emit()


func _set_status(text: String) -> void:
	if _status != null:
		_status.text = text


static func _is_press(event: InputEvent) -> bool:
	var key: InputEventKey = event as InputEventKey
	if key != null:
		return key.pressed and not key.echo
	var button: InputEventMouseButton = event as InputEventMouseButton
	if button != null:
		return button.pressed
	return false

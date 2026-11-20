class_name PauseMenu
extends CanvasLayer
## Menu de pausa mínimo (L3, F1-013). Esc (ação pause) abre e fecha. Opções: Continuar, Controles, Sair.
## Abrir pausa a árvore e solta o mouse. Continuar despausa e chama on_menu_resumed() no grupo "player":
## é o jogador que recaptura o mouse (o menu não mexe no mouse ao continuar).

signal resumed

const PLAYER_GROUP: StringName = &"player"
const RESUME_METHOD: StringName = &"on_menu_resumed"
const HEADLESS_DISPLAY_NAME: String = "headless"
const MENU_LAYER: int = 90

var _main: VBoxContainer = null
var _controls: ControlsMenu = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = MENU_LAYER
	var background: ColorRect = ColorRect.new()
	background.color = Color(0.0, 0.0, 0.0, 0.6)
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	_main = VBoxContainer.new()
	_main.position = Vector2(48.0, 48.0)
	add_child(_main)
	_add_button("Continuar", continue_game)
	_add_button("Controles", show_controls)
	_add_button("Sair", _quit)
	_controls = ControlsMenu.new()
	_controls.visible = false
	add_child(_controls)
	_controls.closed.connect(show_main)
	visible = false


func is_open() -> bool:
	return visible


func is_controls_visible() -> bool:
	return _controls != null and _controls.visible


func open_menu() -> void:
	if visible:
		return
	visible = true
	show_main()
	get_tree().paused = true
	_set_mouse_visible(true)


func continue_game() -> void:
	if not visible:
		return
	visible = false
	_controls.visible = false
	get_tree().paused = false
	get_tree().call_group(PLAYER_GROUP, RESUME_METHOD)
	resumed.emit()


func show_controls() -> void:
	_main.visible = false
	_controls.visible = true


func show_main() -> void:
	_controls.visible = false
	_main.visible = true


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed(&"pause"):
		return
	if is_controls_visible():
		show_main()
	elif visible:
		continue_game()
	else:
		open_menu()
	get_viewport().set_input_as_handled()


func _add_button(text: String, handler: Callable) -> void:
	var button: Button = Button.new()
	button.text = text
	button.pressed.connect(handler)
	_main.add_child(button)


func _quit() -> void:
	get_tree().quit()


func _set_mouse_visible(visible_mouse: bool) -> void:
	if DisplayServer.get_name() == HEADLESS_DISPLAY_NAME:
		return
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if visible_mouse else Input.MOUSE_MODE_CAPTURED

extends TestCase
## ACC-05 (TEST_PLAN §2.8): remapear controles, reiniciar o jogo e confirmar que a ligação persiste; conflitos
## são avisados. "Reiniciar" = o InputMap volta aos padrões e uma instância nova de Settings lê o mesmo
## arquivo. Usa um arquivo em tmp_dir(); o Settings do autoload é restaurado depois.
## Autor: Gameplay Engineer (F1-013).

const SettingsScript := preload("res://autoload/settings.gd")
const ACTION_CROUCH: StringName = &"crouch"
const ACTION_INTERACT: StringName = &"interact"
const ACTION_USE_ITEM: StringName = &"use_item"
const KEY_REMAP: int = KEY_F
const KEY_INTERACT_DEFAULT_CODE: int = KEY_E
const SAVE_FRAMES: int = 3

var _saved_path: String = ""
var _saved_autosave: bool = true


func before_all() -> void:
	InputBindings.capture_defaults()


func before_each() -> void:
	_saved_path = Settings.file_path
	_saved_autosave = Settings.autosave
	Settings.autosave = false
	InputBindings.apply({})


func after_each() -> void:
	Settings.autosave = false
	Settings.set_value(&"input_bindings", {})
	Settings.file_path = _saved_path
	Settings.autosave = _saved_autosave
	InputBindings.apply({})


func _key(code: int) -> InputEventKey:
	var event: InputEventKey = InputEventKey.new()
	event.physical_keycode = code as Key
	event.pressed = true
	return event


func _mouse(button: int) -> InputEventMouseButton:
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.button_index = button as MouseButton
	event.pressed = true
	return event


func _has_key(action: StringName, code: int) -> bool:
	for event: InputEvent in InputMap.action_get_events(action):
		var key: InputEventKey = event as InputEventKey
		if key != null and int(key.physical_keycode) == code:
			return true
	return false


func _has_mouse(action: StringName, button: int) -> bool:
	for event: InputEvent in InputMap.action_get_events(action):
		var mouse: InputEventMouseButton = event as InputEventMouseButton
		if mouse != null and int(mouse.button_index) == button:
			return true
	return false


func _menu() -> ControlsMenu:
	var menu: ControlsMenu = ControlsMenu.new()
	add_child_autofree(menu)
	return menu


func test_acc05_remapeia_reinicia_e_a_ligacao_persiste() -> void:
	var path: String = tmp_dir().path_join("settings.cfg")
	Settings.file_path = path
	Settings.autosave = true
	var menu: ControlsMenu = _menu()
	await wait_process_frames(1)
	menu.begin_capture(ACTION_CROUCH)
	assert_eq(menu.capture_event(_key(KEY_REMAP)), ControlsMenu.STATUS_APPLIED, "tecla livre é aplicada")
	assert_true(_has_key(ACTION_CROUCH, KEY_REMAP), "o InputMap usa a nova ligação")
	await wait_process_frames(SAVE_FRAMES)
	assert_true(FileAccess.file_exists(path), "a ligação foi gravada em user (aqui, no arquivo de teste)")

	# "Reiniciar": o processo volta aos padrões e uma instância nova lê o mesmo arquivo.
	InputBindings.apply({})
	assert_false(_has_key(ACTION_CROUCH, KEY_REMAP), "antes de reiniciar, o InputMap voltou ao padrão")
	var restarted: SettingsScript = SettingsScript.new()
	restarted.file_path = path
	restarted.autosave = false
	add_child_autofree(restarted)
	await wait_process_frames(1)
	assert_true(_has_key(ACTION_CROUCH, KEY_REMAP), "após reiniciar, a ligação de crouch persiste")
	assert_eq(restarted.get_value(&"input_bindings"), InputBindings.current_overrides(), "o valor lido é o mesmo que está aplicado")


func test_acc05_conflito_e_avisado_e_nao_aplica() -> void:
	var menu: ControlsMenu = _menu()
	await wait_process_frames(1)
	menu.begin_capture(ACTION_CROUCH)
	assert_eq(menu.capture_event(_key(KEY_REMAP)), ControlsMenu.STATUS_APPLIED, "crouch recebe F")
	menu.begin_capture(ACTION_INTERACT)
	assert_eq(menu.capture_event(_key(KEY_REMAP)), ControlsMenu.STATUS_CONFLICT, "F já é de crouch: conflito")
	assert_true(menu.get_status_text().contains("crouch"), "o aviso nomeia a ação em conflito: %s" % menu.get_status_text())
	assert_false(_has_key(ACTION_INTERACT, KEY_REMAP), "conflito não aplica a ligação")
	assert_true(_has_key(ACTION_INTERACT, KEY_INTERACT_DEFAULT_CODE), "interact continua com E")


func test_acc05_esc_cancela_a_captura() -> void:
	var menu: ControlsMenu = _menu()
	await wait_process_frames(1)
	menu.begin_capture(ACTION_INTERACT)
	assert_eq(menu.capture_event(_key(KEY_ESCAPE)), ControlsMenu.STATUS_CANCELLED, "Esc cancela")
	assert_false(menu.is_capturing(), "captura terminou")
	assert_eq(menu.capture_event(_key(KEY_REMAP)), ControlsMenu.STATUS_IGNORED, "fora da captura, tecla é ignorada")
	assert_true(_has_key(ACTION_INTERACT, KEY_INTERACT_DEFAULT_CODE), "interact não mudou")


func test_acc05_botao_do_mouse_persiste_depois_de_reiniciar() -> void:
	var path: String = tmp_dir().path_join("settings.cfg")
	Settings.file_path = path
	Settings.autosave = true
	var menu: ControlsMenu = _menu()
	await wait_process_frames(1)
	menu.begin_capture(ACTION_USE_ITEM)
	assert_eq(menu.capture_event(_mouse(MOUSE_BUTTON_MIDDLE)), ControlsMenu.STATUS_APPLIED, "botão do meio é aplicado")
	await wait_process_frames(SAVE_FRAMES)
	InputBindings.apply({})
	var restarted: SettingsScript = SettingsScript.new()
	restarted.file_path = path
	restarted.autosave = false
	add_child_autofree(restarted)
	await wait_process_frames(1)
	assert_true(_has_mouse(ACTION_USE_ITEM, MOUSE_BUTTON_MIDDLE), "o botão do mouse persiste após reiniciar")

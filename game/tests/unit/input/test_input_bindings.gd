extends TestCase
## F1-013: InputBindings (core/input_bindings.gd), formato de Settings.input_bindings. Unit: InputMap e eventos,
## sem cena. Cada teste começa e termina com os padrões do project.godot aplicados.
## Autor: Gameplay Engineer.

const KEY_CROUCH_TEST: int = KEY_F
const ACTION_CROUCH: StringName = &"crouch"
const ACTION_INTERACT: StringName = &"interact"


func before_each() -> void:
	InputBindings.capture_defaults()
	InputBindings.apply({})


func after_each() -> void:
	InputBindings.apply({})


func _key_entry(code: int) -> Dictionary:
	return {"type": "key", "physical_keycode": code}


func test_validate_aceita_listas_de_eventos_validos() -> void:
	assert_false(InputBindings.validate([]), "lista vazia é inválida: não pode gravar ação sem ligação (R1-06)")
	assert_true(InputBindings.validate([_key_entry(KEY_CROUCH_TEST)]), "tecla válida")
	assert_true(InputBindings.validate([{"type": "mouse_button", "button_index": 1}]), "botão do mouse válido")


func test_validate_rejeita_formatos_invalidos() -> void:
	assert_false(InputBindings.validate("nao e lista"), "não é Array")
	assert_false(InputBindings.validate([{"type": "joypad", "button_index": 1}]), "tipo não suportado")
	assert_false(InputBindings.validate([{"type": "key", "physical_keycode": 0}]), "código zero")
	assert_false(InputBindings.validate([{"type": "key", "physical_keycode": "F"}]), "código não inteiro")
	assert_false(InputBindings.validate([{"type": "mouse_button", "button_index": 10}]), "botão fora de 1..9")
	assert_false(InputBindings.validate([42]), "entrada que não é dicionário")


func test_rebindable_actions_exclui_ui_e_inclui_as_do_jogo() -> void:
	var actions: PackedStringArray = InputBindings.rebindable_actions()
	assert_true(actions.has(String(ACTION_CROUCH)), "crouch é remapeável")
	assert_true(actions.has(String(ACTION_INTERACT)), "interact é remapeável")
	for action: String in actions:
		assert_false(action.begins_with("ui_"), "ação de UI não entra na lista: %s" % action)


func test_rebind_e_current_overrides_refletem_so_o_que_mudou() -> void:
	assert_eq(InputBindings.current_overrides().size(), 0, "sem sobreposições no começo")
	InputBindings.rebind(ACTION_CROUCH, _key_entry(KEY_CROUCH_TEST))
	var overrides: Dictionary = InputBindings.current_overrides()
	assert_eq(overrides.keys(), [String(ACTION_CROUCH)], "só crouch aparece como sobreposição")
	assert_eq(overrides[String(ACTION_CROUCH)], [_key_entry(KEY_CROUCH_TEST)], "formato serializado")


func test_apply_ignora_acao_desconhecida_e_ligacao_invalida() -> void:
	var default_count: int = InputBindings.action_entries(ACTION_CROUCH).size()
	InputBindings.apply({
		"acao_inexistente": [_key_entry(KEY_CROUCH_TEST)],
		String(ACTION_CROUCH): [{"type": "key", "physical_keycode": -1}],
	})
	assert_eq(InputBindings.current_overrides().size(), 0, "nada foi aplicado: a ação é desconhecida e a ligação é inválida")
	assert_eq(InputBindings.action_entries(ACTION_CROUCH).size(), default_count, "crouch segue com o padrão")


func test_apply_sempre_parte_dos_padroes() -> void:
	InputBindings.apply({String(ACTION_CROUCH): [_key_entry(KEY_CROUCH_TEST)]})
	InputBindings.apply({})
	assert_eq(InputBindings.current_overrides().size(), 0, "apply sem sobreposições restaura os padrões")


func test_find_conflicts_aponta_a_outra_acao() -> void:
	InputBindings.rebind(ACTION_CROUCH, _key_entry(KEY_CROUCH_TEST))
	var conflicts: PackedStringArray = InputBindings.find_conflicts(_key_entry(KEY_CROUCH_TEST), ACTION_INTERACT)
	assert_eq(conflicts, PackedStringArray([String(ACTION_CROUCH)]), "F já é de crouch")
	var own: PackedStringArray = InputBindings.find_conflicts(_key_entry(KEY_CROUCH_TEST), ACTION_CROUCH)
	assert_eq(own.size(), 0, "a própria ação não conta como conflito")


func test_describe_le_teclas_e_mouse() -> void:
	assert_eq(InputBindings.describe({"type": "mouse_button", "button_index": 2}), "Mouse botão 2", "botão do mouse")
	assert_true(InputBindings.describe(_key_entry(KEY_CROUCH_TEST)).contains("F"), "tecla F aparece no texto")
	assert_eq(InputBindings.describe({}), "(vazio)", "entrada vazia")


func test_entry_from_event_e_round_trip_com_o_inputmap() -> void:
	var key: InputEventKey = InputEventKey.new()
	key.physical_keycode = KEY_CROUCH_TEST as Key
	assert_eq(InputBindings.entry_from_event(key), _key_entry(KEY_CROUCH_TEST), "tecla -> dicionário")
	var button: InputEventMouseButton = InputEventMouseButton.new()
	button.button_index = MOUSE_BUTTON_LEFT
	assert_eq(InputBindings.entry_from_event(button), {"type": "mouse_button", "button_index": 1}, "mouse -> dicionário")
	InputBindings.rebind(ACTION_CROUCH, _key_entry(KEY_CROUCH_TEST))
	assert_true(InputMap.event_is_action(key, ACTION_CROUCH), "o InputMap reconhece a ligação aplicada")


func test_apply_nao_mexe_nas_acoes_ui() -> void:
	# Regressão: ui_* têm ligações por keycode; apply() não pode apagá-las.
	var before: int = InputMap.action_get_events(&"ui_accept").size()
	assert_true(before > 0, "ui_accept tem ligações padrão no project.godot")
	InputBindings.apply({})
	InputBindings.apply({"ui_accept": [_key_entry(KEY_CROUCH_TEST)]})
	assert_eq(InputMap.action_get_events(&"ui_accept").size(), before, "ui_accept mantém as ligações padrão após apply")


func test_rebind_recusa_entrada_invalida_sem_alterar_nada() -> void:
	var before: int = InputBindings.action_entries(ACTION_INTERACT).size()
	assert_false(InputBindings.rebind(ACTION_INTERACT, {"type": "key", "physical_keycode": 0}), "código zero é recusado")
	assert_false(InputBindings.rebind(ACTION_INTERACT, {"type": "mouse_button", "button_index": 10}), "botão 10 é recusado")
	assert_eq(InputBindings.action_entries(ACTION_INTERACT).size(), before, "a ação mantém as ligações")
	assert_eq(InputBindings.current_overrides().size(), 0, "nada foi gravado como sobreposição")


func test_current_overrides_nunca_grava_acao_vazia() -> void:
	# Nenhuma ação pode ser serializada como lista vazia nas sobreposições, mesmo que o InputMap esteja vazio.
	InputMap.action_erase_events(ACTION_INTERACT)
	var overrides: Dictionary = InputBindings.current_overrides()
	assert_false(overrides.has(String(ACTION_INTERACT)), "ação sem eventos não entra nas sobreposições")
	InputBindings.apply({})
	assert_true(InputMap.action_get_events(ACTION_INTERACT).size() > 0, "apply restaura o padrão de interact")


func test_controls_menu_rejeita_tecla_sem_codigo_fisico_e_mouse_fora_de_faixa() -> void:
	var menu: ControlsMenu = ControlsMenu.new()
	var key: InputEventKey = InputEventKey.new()
	key.physical_keycode = 0 as Key
	key.pressed = true
	menu.begin_capture(ACTION_INTERACT)
	assert_eq(menu.capture_event(key), ControlsMenu.STATUS_INVALID, "tecla com physical_keycode 0 é inválida")
	assert_true(menu.is_capturing(), "a captura continua para o jogador tentar de novo")
	var mouse: InputEventMouseButton = InputEventMouseButton.new()
	mouse.button_index = 10 as MouseButton
	mouse.pressed = true
	assert_eq(menu.capture_event(mouse), ControlsMenu.STATUS_INVALID, "botão 10 do mouse é inválido")
	assert_true(InputMap.action_get_events(ACTION_INTERACT).size() > 0, "interact continua com a ligação")
	assert_eq(InputBindings.current_overrides().size(), 0, "nada foi gravado")
	menu.free()


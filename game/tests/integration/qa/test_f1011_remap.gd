extends TestCase
## F1-011 (QA independente): remapeamento de controles além do ACC-05: teclas inválidas, botões fora da faixa,
## conflito com a pausa e com outra ação, Esc cancelando a captura, e clique do mouse durante a captura.
## Restaura o InputMap e o Settings ao fim de cada teste; o arquivo de opções fica desligado (autosave = false).
## Autor: QA Engineer (F1-011).

const ControlsScript := preload("res://presentation/ui/controls_menu.gd")
const ACTION_CROUCH: StringName = &"crouch"
const ACTION_PAUSE: StringName = &"pause"
const ACTION_INTERACT: StringName = &"interact"
const TEST_KEY_F12: int = KEY_F12
const TEST_KEY_ESC: int = KEY_ESCAPE
const TEST_KEY_NONE: int = 0
const TEST_KEY_E: int = KEY_E
const MOUSE_OUT_OF_RANGE: int = 10
const MOUSE_LEFT: int = 1
## Botões livres por padrão (o esquerdo é do throw desde a F3-004).
const MOUSE_RIGHT: int = 2
const MOUSE_FREE: int = 8

var _saved_autosave: bool = true


func before_all() -> void:
	InputBindings.capture_defaults()


func before_each() -> void:
	_saved_autosave = Settings.autosave
	Settings.autosave = false
	InputBindings.apply({})


func after_each() -> void:
	Settings.set_value(&"input_bindings", {})
	InputBindings.apply({})
	Settings.autosave = _saved_autosave


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


func _menu() -> ControlsMenu:
	return add_child_autofree(ControlsScript.new()) as ControlsMenu


func _has_key(action: StringName, code: int) -> bool:
	for raw: Variant in InputBindings.action_entries(action):
		var entry: Dictionary = raw as Dictionary
		if entry.get("type") == InputBindings.TYPE_KEY and int(entry.get("physical_keycode", -1)) == code:
			return true
	return false


## Tecla sem código físico (0): não pode virar ligação, e a ação antiga continua valendo.
func test_remap_tecla_sem_codigo_e_recusada() -> void:
	var menu: ControlsMenu = _menu()
	var before: Array = InputBindings.action_entries(ACTION_CROUCH)
	menu.begin_capture(ACTION_CROUCH)
	var status: String = menu.capture_event(_key(TEST_KEY_NONE))
	assert_eq(status, ControlsMenu.STATUS_INVALID, "tecla com código 0 é recusada")
	assert_eq(InputBindings.action_entries(ACTION_CROUCH), before, "a ligação de crouch não mudou")
	assert_true(menu.is_capturing(), "a captura continua aberta depois de uma tecla inválida")


## Botão do mouse fora de 1..9 é recusado; botão livre dentro da faixa é aceito.
## Director, integração da F3-004: o botão 1 virou o padrão do throw; o caso "aceito" usa o botão 8 (livre) e o
## botão 1 passa a ser recusado por conflito.
func test_remap_botao_do_mouse_fora_da_faixa_e_recusado() -> void:
	var menu: ControlsMenu = _menu()
	menu.begin_capture(ACTION_CROUCH)
	assert_eq(menu.capture_event(_mouse(MOUSE_OUT_OF_RANGE)), ControlsMenu.STATUS_INVALID, "botão 10 é recusado")
	assert_false(_has_key(ACTION_CROUCH, TEST_KEY_NONE), "nenhuma ligação inválida foi gravada")
	assert_eq(menu.capture_event(_mouse(MOUSE_LEFT)), ControlsMenu.STATUS_CONFLICT, "botão 1 é do throw: conflito")
	assert_eq(menu.capture_event(_mouse(MOUSE_FREE)), ControlsMenu.STATUS_APPLIED, "botão 8 é aceito")
	assert_eq(InputBindings.describe(InputBindings.action_entries(ACTION_CROUCH)[0] as Dictionary), "Mouse botão 8", "crouch passou a usar o botão 8")


## Conflito com a pausa (Esc não pode ser capturado; usa F12 como tecla da pausa): crouch não pode usar F12.
func test_remap_conflito_com_a_pausa_e_recusado() -> void:
	var menu: ControlsMenu = _menu()
	menu.begin_capture(ACTION_PAUSE)
	assert_eq(menu.capture_event(_key(TEST_KEY_F12)), ControlsMenu.STATUS_APPLIED, "pausa passa para F12")
	var before: Array = InputBindings.action_entries(ACTION_CROUCH)
	menu.begin_capture(ACTION_CROUCH)
	var status: String = menu.capture_event(_key(TEST_KEY_F12))
	assert_eq(status, ControlsMenu.STATUS_CONFLICT, "crouch recusa F12, que já é a pausa")
	assert_eq(InputBindings.action_entries(ACTION_CROUCH), before, "crouch continua com a tecla anterior")
	assert_true(menu.get_status_text().contains("pause"), "o aviso de conflito cita a ação em conflito (%s)" % menu.get_status_text())


## Conflito com a interação: E já é 'interact', então crouch não pode receber E.
func test_remap_conflito_com_outra_acao_e_recusado() -> void:
	var menu: ControlsMenu = _menu()
	menu.begin_capture(ACTION_CROUCH)
	var status: String = menu.capture_event(_key(TEST_KEY_E))
	assert_eq(status, ControlsMenu.STATUS_CONFLICT, "crouch recusa E, que é a interação")
	assert_true(_has_key(ACTION_INTERACT, TEST_KEY_E), "interact continua com E")


## Esc cancela a captura e não grava nada.
func test_remap_esc_cancela_a_captura() -> void:
	var menu: ControlsMenu = _menu()
	var before: Array = InputBindings.action_entries(ACTION_CROUCH)
	menu.begin_capture(ACTION_CROUCH)
	assert_eq(menu.capture_event(_key(TEST_KEY_ESC)), ControlsMenu.STATUS_CANCELLED, "Esc cancela")
	assert_false(menu.is_capturing(), "a captura terminou")
	assert_eq(InputBindings.action_entries(ACTION_CROUCH), before, "nada foi gravado")


## Achado de uso (observação): durante a captura, um clique do mouse vira a nova ligação, inclusive sobre o botão
## "Voltar". O jogador que quer sair só com o mouse troca a tecla sem perceber. Documentado com o comportamento real.
## Director, integração da F3-004: o clique esquerdo agora é recusado por conflito com o throw, o que atenua o achado
## para o botão "Voltar". O clique direito (livre) continua virando ligação: o achado segue aberto para ele.
func test_remap_clique_durante_captura_vira_ligacao_observacao() -> void:
	var menu: ControlsMenu = _menu()
	menu.begin_capture(ACTION_CROUCH)
	var left_status: String = menu.capture_event(_mouse(MOUSE_LEFT))
	assert_eq(left_status, ControlsMenu.STATUS_CONFLICT, "clique esquerdo durante a captura: conflito com o throw")
	var status: String = menu.capture_event(_mouse(MOUSE_RIGHT))
	note("clique direito durante a captura: status=%s; crouch agora=%s" % [status, InputBindings.describe(InputBindings.action_entries(ACTION_CROUCH)[0] as Dictionary)])
	assert_eq(status, ControlsMenu.STATUS_APPLIED, "clique direito durante a captura é gravado como ligação (comportamento atual)")
	assert_true(_has_key(ACTION_CROUCH, TEST_KEY_NONE) == false, "nenhuma tecla inválida")



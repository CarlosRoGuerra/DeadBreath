extends TestCase
## F3-004: a ação throw existe, é remapeável (aparece nas ações do jogo) e vem com botão esquerdo do mouse.
## Autor: Gameplay Engineer.


func before_all() -> void:
	InputBindings.ensure_throw_action()


func test_acao_throw_existe_com_botao_esquerdo() -> void:
	assert_true(InputMap.has_action(InputBindings.THROW_ACTION), "a ação throw está no InputMap")
	var found: bool = false
	for event: InputEvent in InputMap.action_get_events(InputBindings.THROW_ACTION):
		var button: InputEventMouseButton = event as InputEventMouseButton
		if button != null and button.button_index == MOUSE_BUTTON_LEFT:
			found = true
	assert_true(found, "padrão: botão esquerdo do mouse")


func test_throw_e_remapeavel() -> void:
	assert_true(InputBindings.rebindable_actions().has(String(InputBindings.THROW_ACTION)), "throw aparece nas ações remapeáveis")


func test_ensure_e_idempotente() -> void:
	var before: int = InputMap.action_get_events(InputBindings.THROW_ACTION).size()
	InputBindings.ensure_throw_action()
	InputBindings.ensure_throw_action()
	assert_eq(InputMap.action_get_events(InputBindings.THROW_ACTION).size(), before, "chamar de novo não duplica o padrão")

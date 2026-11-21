extends TestCase
## F3-011 (QA independente), nível padrão (orçamento < 0,5 s para o conjunto): remapeamento da ação throw (F3-004) e
## legendas (F3-006, ACC-04) sob inundação de pedidos e mudança de opções com legendas na tela. Sem cena: só o Subtitles
## e o InputBindings. Autor: QA Engineer (F3-011).

const SUBTITLE_KEY: StringName = &"subtitle.door_normal"
const FLOOD_COUNT: int = 500
const LINE_LIMIT: int = 3


func before_all() -> void:
	Settings.autosave = false
	InputBindings.capture_defaults()


func after_all() -> void:
	InputBindings.apply({})
	Settings.reset_to_defaults(false)
	Settings.autosave = true


func after_each() -> void:
	InputBindings.apply({})
	Settings.reset_to_defaults(false)


func _mouse(button: int) -> InputEventMouseButton:
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.button_index = button
	event.pressed = true
	return event


func _key(keycode: int) -> InputEventKey:
	var event: InputEventKey = InputEventKey.new()
	event.physical_keycode = keycode as Key
	event.pressed = true
	return event


## throw: o padrão é o botão esquerdo; remapeada para G, o botão deixa de arremessar; restaurada, volta ao padrão.
func test_remap_throw_aplica_e_restaura() -> void:
	assert_true(InputMap.event_is_action(_mouse(MOUSE_BUTTON_LEFT), InputBindings.THROW_ACTION), "padrão: botão esquerdo arremessa")
	assert_true(InputBindings.rebind(InputBindings.THROW_ACTION, {"type": "key", "physical_keycode": KEY_G}), "remapeia throw para G")
	assert_true(InputMap.event_is_action(_key(KEY_G), InputBindings.THROW_ACTION), "G arremessa depois do remapeamento")
	assert_false(InputMap.event_is_action(_mouse(MOUSE_BUTTON_LEFT), InputBindings.THROW_ACTION), "o botão antigo deixou de arremessar")
	InputBindings.apply({})
	assert_true(InputMap.event_is_action(_mouse(MOUSE_BUTTON_LEFT), InputBindings.THROW_ACTION), "restaurado: o botão esquerdo volta a arremessar")
	assert_false(InputMap.event_is_action(_key(KEY_G), InputBindings.THROW_ACTION), "restaurado: G deixa de arremessar")
	assert_true(InputBindings.current_overrides().is_empty(), "restaurado: sem sobreposições gravadas")


## Conflito: throw remapeada para E (interação) é avisada pelo InputBindings, com o nome da ação em conflito.
func test_remap_throw_para_tecla_em_uso_e_avisado() -> void:
	var conflicts: PackedStringArray = InputBindings.find_conflicts({"type": "key", "physical_keycode": KEY_E}, InputBindings.THROW_ACTION)
	note("conflitos de throw em E: %s" % str(conflicts))
	assert_true(conflicts.has("interact"), "E conflita com a ação interact")


func _subtitles() -> Subtitles:
	var subs: Subtitles = Subtitles.new()
	add_child_autofree(subs)
	return subs


## Inundação: 500 pedidos seguidos não passam de 3 linhas na tela, e as linhas somem depois da duração.
func test_legendas_inundacao_respeita_o_limite_de_linhas() -> void:
	var subs: Subtitles = _subtitles()
	var shown: int = 0
	for _i: int in FLOOD_COUNT:
		if subs.show_subtitle(SUBTITLE_KEY, 1.5):
			shown += 1
	assert_eq(shown, FLOOD_COUNT, "todos os pedidos com legenda ligada são aceitos (%d)" % shown)
	assert_eq(subs.get_line_count(), LINE_LIMIT, "no máximo %d linhas na tela" % LINE_LIMIT)
	assert_eq(subs.get_visible_texts().size(), LINE_LIMIT, "as linhas visíveis respeitam o limite")
	subs.advance(2.0)
	assert_eq(subs.get_line_count(), 0, "as legendas somem depois da duração")


## ACC-04: desligar as legendas com linhas na tela as tira e recusa novos pedidos; ligar de novo volta a mostrar.
## O tamanho (subtitles_size) muda o tamanho da fonte das linhas na tela, ao vivo.
func test_legendas_desligar_e_tamanho_ao_vivo() -> void:
	var subs: Subtitles = _subtitles()
	assert_true(subs.show_subtitle(SUBTITLE_KEY, 5.0), "com legendas ligadas, o pedido aparece")
	Settings.set_value(&"subtitles_size", 2.0)
	assert_eq(subs.get_font_size(), roundi(Subtitles.BASE_FONT_SIZE * 2.0), "tamanho 2.0 vale para a fonte nova")
	Settings.set_value(&"subtitles_enabled", false)
	assert_eq(subs.get_line_count(), 0, "desligar as legendas tira as linhas da tela")
	assert_false(subs.show_subtitle(SUBTITLE_KEY, 5.0), "com legendas desligadas, o pedido é recusado")
	Settings.set_value(&"subtitles_enabled", true)
	assert_true(subs.show_subtitle(SUBTITLE_KEY, 5.0), "ligar de novo volta a mostrar")
	assert_eq(subs.get_font_size(), roundi(Subtitles.BASE_FONT_SIZE * 2.0), "o tamanho escolhido continua valendo")

extends TestCase
## F3-006 (ACC-04): a UI de legendas ouve EventBus.subtitle_requested, mostra até 3 linhas que somem pelo tempo pedido,
## respeita subtitles_enabled e subtitles_size (efeito imediato) e não mostra chave sem texto. Autor: Gameplay Engineer.

const SETTLE_FRAMES: int = 1

var _previous: Dictionary = {}


func before_all() -> void:
	Settings.autosave = false


func after_all() -> void:
	Settings.autosave = true


func before_each() -> void:
	_previous = {&"subtitles_enabled": Settings.get_bool(&"subtitles_enabled"), &"subtitles_size": Settings.get_float(&"subtitles_size")}
	Settings.set_value(&"subtitles_enabled", true)
	Settings.set_value(&"subtitles_size", 1.0)


func after_each() -> void:
	Settings.set_value(&"subtitles_enabled", bool(_previous[&"subtitles_enabled"]))
	Settings.set_value(&"subtitles_size", float(_previous[&"subtitles_size"]))


func _subtitles() -> Subtitles:
	var ui: Subtitles = add_child_autofree(Subtitles.new()) as Subtitles
	return ui


func test_legenda_aparece_e_some_pelo_tempo_pedido() -> void:
	var ui: Subtitles = _subtitles()
	await wait_physics_frames(SETTLE_FRAMES)
	EventBus.subtitle_requested.emit(&"subtitle.cough", 1.5)
	assert_eq(ui.get_visible_texts(), PackedStringArray(["[tosse]"]), "a tosse aparece como [tosse]")
	ui.advance(1.0)
	assert_eq(ui.get_line_count(), 1, "ainda visível antes do fim")
	ui.advance(0.6)
	assert_eq(ui.get_line_count(), 0, "some depois de 1,5 s")


func test_chave_sem_texto_nao_aparece() -> void:
	var ui: Subtitles = _subtitles()
	await wait_physics_frames(SETTLE_FRAMES)
	assert_false(ui.show_subtitle(&"subtitle.nao_existe", 2.0), "sem texto: não mostra")
	assert_eq(ui.get_line_count(), 0, "nenhuma linha")


func test_no_maximo_tres_linhas_com_a_mais_antiga_fora() -> void:
	var ui: Subtitles = _subtitles()
	await wait_physics_frames(SETTLE_FRAMES)
	EventBus.subtitle_requested.emit(&"subtitle.cough", 5.0)
	EventBus.subtitle_requested.emit(&"subtitle.door_slow", 5.0)
	EventBus.subtitle_requested.emit(&"subtitle.door_normal", 5.0)
	EventBus.subtitle_requested.emit(&"subtitle.door_locked", 5.0)
	assert_eq(ui.get_line_count(), Subtitles.MAX_LINES, "três linhas no máximo")
	assert_eq(ui.get_visible_texts(), PackedStringArray([ui.text_for(&"subtitle.door_slow"), ui.text_for(&"subtitle.door_normal"),
		ui.text_for(&"subtitle.door_locked")]), "a mais antiga saiu")


func test_desligar_legendas_limpa_e_bloqueia() -> void:
	var ui: Subtitles = _subtitles()
	await wait_physics_frames(SETTLE_FRAMES)
	EventBus.subtitle_requested.emit(&"subtitle.cough", 5.0)
	Settings.set_value(&"subtitles_enabled", false)
	assert_eq(ui.get_line_count(), 0, "desligar some com as legendas na tela, de imediato")
	EventBus.subtitle_requested.emit(&"subtitle.cough", 5.0)
	assert_eq(ui.get_line_count(), 0, "com legendas desligadas, nada novo aparece")


func test_tamanho_muda_a_fonte_de_imediato() -> void:
	var ui: Subtitles = _subtitles()
	await wait_physics_frames(SETTLE_FRAMES)
	assert_eq(ui.get_font_size(), Subtitles.BASE_FONT_SIZE, "tamanho 1,0: fonte base")
	EventBus.subtitle_requested.emit(&"subtitle.cough", 5.0)
	Settings.set_value(&"subtitles_size", 2.0)
	assert_eq(ui.get_font_size(), Subtitles.BASE_FONT_SIZE * 2, "tamanho 2,0: fonte dobrada")
	var label: Label = ui.get_child(0).get_child(0) as Label
	assert_eq(label.get_theme_font_size(&"font_size"), Subtitles.BASE_FONT_SIZE * 2, "a linha já visível muda de tamanho")

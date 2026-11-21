class_name Subtitles
extends CanvasLayer
## Subtitles (L3, F3-006, ACC-04): mostra as legendas pedidas por EventBus.subtitle_requested(text_key, duration).
## Até MAX_LINES linhas na base da tela; cada linha some depois da sua duração (advance). Escala: Settings
## subtitles_size; liga/desliga: Settings subtitles_enabled, com efeito imediato (Settings.changed).
## Textos: tabela pt-BR em TABLE_PATH (sem infraestrutura de tradução por enquanto). Chave sem texto: não aparece,
## e Log.warn uma vez por chave. O AcousticWorld é quem pede as chaves (subtitle.<sound_id>).
## Ligada na cena jogável pelo Gameplay (ver o relatório F3-006); não é ligada sozinha.

const TABLE_PATH: String = "res://content/data/subtitles/subtitles_pt_br.json"
const MAX_LINES: int = 3
const BASE_FONT_SIZE: int = 22
const BOTTOM_MARGIN_PX: int = 48
const LOG_CATEGORY: StringName = &"ui"

var _texts: Dictionary = {}
var _warned: Dictionary = {}
var _lines: Array[Label] = []
var _remaining_s: Array[float] = []
var _box: VBoxContainer = null


func _ready() -> void:
	layer = 40
	_texts = load_table(TABLE_PATH)
	_box = VBoxContainer.new()
	_box.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_box.alignment = BoxContainer.ALIGNMENT_END
	_box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_box.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_box.offset_bottom = -BOTTOM_MARGIN_PX
	_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_box)
	EventBus.subtitle_requested.connect(_on_subtitle_requested)
	Settings.changed.connect(_on_settings_changed)
	_apply_settings()


func _exit_tree() -> void:
	if EventBus.subtitle_requested.is_connected(_on_subtitle_requested):
		EventBus.subtitle_requested.disconnect(_on_subtitle_requested)
	if Settings.changed.is_connected(_on_settings_changed):
		Settings.changed.disconnect(_on_settings_changed)


## Lê a tabela chave → texto. Arquivo ausente ou inválido: erro no log e tabela vazia (nada aparece).
static func load_table(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		Log.error(LOG_CATEGORY, "tabela de legendas ausente: %s" % path)
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		Log.error(LOG_CATEGORY, "tabela de legendas inválida (esperado um objeto JSON): %s" % path)
		return {}
	return parsed as Dictionary


## Texto da chave, ou "" se não há. Chave sem texto: Log.warn uma vez.
func text_for(text_key: StringName) -> String:
	var key: String = String(text_key)
	if _texts.has(key):
		return str(_texts[key])
	if not _warned.has(key):
		_warned[key] = true
		Log.warn(LOG_CATEGORY, "legenda sem texto para a chave '%s'" % key)
	return ""


## Mostra uma legenda, se legendas estão ligadas e a chave tem texto. Retorna true se apareceu.
func show_subtitle(text_key: StringName, duration_s: float) -> bool:
	if not Settings.get_bool(&"subtitles_enabled"):
		return false
	var text: String = text_for(text_key)
	if text.is_empty():
		return false
	var label: Label = Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_color_override(&"font_color", Color(1.0, 1.0, 1.0, 1.0))
	label.add_theme_color_override(&"font_outline_color", Color(0.0, 0.0, 0.0, 1.0))
	label.add_theme_constant_override(&"outline_size", 4)
	label.add_theme_font_size_override(&"font_size", _font_size())
	_box.add_child(label)
	_lines.append(label)
	_remaining_s.append(maxf(duration_s, 0.0))
	while _lines.size() > MAX_LINES:
		_remove_line(0)
	return true


## Avança o tempo das linhas e remove as que venceram. _process chama isto a cada quadro.
func advance(delta: float) -> void:
	var index: int = _remaining_s.size() - 1
	while index >= 0:
		_remaining_s[index] -= delta
		if _remaining_s[index] <= 0.0:
			_remove_line(index)
		index -= 1


func get_visible_texts() -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	for label: Label in _lines:
		out.append(label.text)
	return out


func get_line_count() -> int:
	return _lines.size()


func get_font_size() -> int:
	return _font_size()


func clear() -> void:
	while not _lines.is_empty():
		_remove_line(0)


func _process(delta: float) -> void:
	advance(delta)


func _on_subtitle_requested(text_key: StringName, duration_s: float) -> void:
	show_subtitle(text_key, duration_s)


func _on_settings_changed(key: StringName) -> void:
	if key == &"subtitles_enabled" or key == &"subtitles_size":
		_apply_settings()


func _apply_settings() -> void:
	if not Settings.get_bool(&"subtitles_enabled"):
		clear()
	var size: int = _font_size()
	for label: Label in _lines:
		label.add_theme_font_size_override(&"font_size", size)


func _font_size() -> int:
	return roundi(BASE_FONT_SIZE * Settings.get_float(&"subtitles_size"))


func _remove_line(index: int) -> void:
	var label: Label = _lines[index]
	_lines.remove_at(index)
	_remaining_s.remove_at(index)
	if is_instance_valid(label):
		label.queue_free()

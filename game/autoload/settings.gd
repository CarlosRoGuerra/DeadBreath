extends Node
## Settings (L0, autoload "Settings"): opções do jogador, persistidas em
## user://settings.cfg com escrita atômica. Contrato: COMPONENT_CONTRACTS §15.
## Esquema (tipo, padrão, faixa): DATA_STRUCTURES §10.

signal changed(key: StringName)

const DEFAULT_PATH: String = "user://settings.cfg"
const SECTION: String = "settings"
const LOG_CATEGORY: StringName = &"settings"

## chave -> [tipo, padrão, mínimo, máximo]. Mínimo/máximo só valem para float/int.
const SCHEMA: Dictionary = {
	&"mouse_sensitivity": [TYPE_FLOAT, 0.12, 0.02, 0.6],
	&"invert_y": [TYPE_BOOL, false, null, null],
	&"fov": [TYPE_FLOAT, 75.0, 60.0, 100.0],
	&"motion_reduction": [TYPE_FLOAT, 0.0, 0.0, 1.0],
	&"tremor_reduction": [TYPE_FLOAT, 0.0, 0.0, 1.0],
	&"effects_intensity": [TYPE_FLOAT, 1.0, 0.0, 1.0],
	&"respiratory_indicator": [TYPE_BOOL, false, null, null],
	&"subtitles_enabled": [TYPE_BOOL, true, null, null],
	&"subtitles_size": [TYPE_FLOAT, 1.0, 0.75, 2.0],
	&"master_volume": [TYPE_FLOAT, 1.0, 0.0, 1.0],
	&"input_bindings": [TYPE_DICTIONARY, {}, null, null],
}

## Arquivo de persistência. Testes apontam para um diretório temporário antes de usar.
var file_path: String = DEFAULT_PATH
## Quando true, alterações agendam gravação automática no fim do frame (só dentro da árvore).
var autosave: bool = true

var _values: Dictionary = {}
var _save_pending: bool = false


func _init() -> void:
	reset_to_defaults(false)


func _ready() -> void:
	InputBindings.capture_defaults()
	load_from_disk()
	_apply_native(&"master_volume")
	_apply_native(&"input_bindings")


func _exit_tree() -> void:
	if _save_pending:
		save_to_disk()


func keys() -> Array[StringName]:
	var out: Array[StringName] = []
	for k: StringName in SCHEMA.keys():
		out.append(k)
	return out


func has_key(key: StringName) -> bool:
	return SCHEMA.has(key)


func get_default(key: StringName) -> Variant:
	if not SCHEMA.has(key):
		return null
	return _copy(_schema_entry(key)[1])


func get_value(key: StringName) -> Variant:
	if not _values.has(key):
		Log.warn(LOG_CATEGORY, "chave desconhecida: '%s'" % key)
		return null
	return _copy(_values[key])


func get_float(key: StringName) -> float:
	return float(get_value(key))


func get_bool(key: StringName) -> bool:
	return bool(get_value(key))


## Valida tipo e faixa. Valor de tipo errado, número não finito (NaN/INF) ou chave desconhecida
## é rejeitado com Log.warn. Números finitos fora da faixa são limitados a ela.
func set_value(key: StringName, value: Variant) -> void:
	if not SCHEMA.has(key):
		Log.warn(LOG_CATEGORY, "chave desconhecida: '%s'" % key)
		return
	var entry: Array = _schema_entry(key)
	var expected: int = entry[0]
	var actual: int = typeof(value)
	var coerced: Variant = value
	if expected == TYPE_FLOAT and actual == TYPE_INT:
		coerced = float(value)
	elif actual != expected:
		Log.warn(LOG_CATEGORY, "tipo inválido para '%s': esperado %s, recebido %s" % [key, type_string(expected), type_string(actual)])
		return
	if expected == TYPE_FLOAT:
		# clampf(NaN, ...) devolve NaN: não finitos precisam ser rejeitados antes (revisão F1-010, R1-05).
		if not is_finite(float(coerced)):
			Log.warn(LOG_CATEGORY, "valor não finito rejeitado para '%s': %s" % [key, coerced])
			return
		coerced = clampf(float(coerced), float(entry[2]), float(entry[3]))
	if _values.has(key) and _values[key] == coerced:
		return
	_values[key] = _copy(coerced)
	_apply_native(key)
	changed.emit(key)
	_schedule_save()


func reset_to_defaults(emit_changes: bool = true) -> void:
	for key: StringName in SCHEMA.keys():
		_values[key] = _copy(_schema_entry(key)[1])
		if emit_changes:
			_apply_native(key)
			changed.emit(key)
	if emit_changes:
		_schedule_save()


func save_to_disk() -> Error:
	_save_pending = false
	var cfg: ConfigFile = ConfigFile.new()
	for key: StringName in SCHEMA.keys():
		cfg.set_value(SECTION, String(key), _values[key])
	var err: Error = AtomicFile.write_text(file_path, cfg.encode_to_text())
	if err != OK:
		Log.error(LOG_CATEGORY, "falha ao gravar %s: %s" % [file_path, error_string(err)])
	return err


## Carrega do disco. Chaves ausentes ou inválidas ficam no padrão (com Log.warn).
func load_from_disk() -> Error:
	var result: AtomicFile.ReadResult = AtomicFile.read_text(file_path, _is_config_text)
	if not result.ok:
		Log.info(LOG_CATEGORY, "sem arquivo de opções válido em %s; usando padrões" % file_path)
		return ERR_FILE_NOT_FOUND
	if result.source != "main":
		Log.warn(LOG_CATEGORY, "opções recuperadas da cópia '%s'" % result.source)
	var cfg: ConfigFile = ConfigFile.new()
	cfg.parse(result.text)
	for key: StringName in SCHEMA.keys():
		if not cfg.has_section_key(SECTION, String(key)):
			continue
		# set_value valida tipo e faixa e registra Log.warn se rejeitar o valor.
		set_value(key, cfg.get_value(SECTION, String(key)))
	_save_pending = false
	return OK


func _schedule_save() -> void:
	if not autosave or not is_inside_tree() or _save_pending:
		return
	_save_pending = true
	_flush_save.call_deferred()


func _flush_save() -> void:
	if _save_pending:
		save_to_disk()


func _apply_native(key: StringName) -> void:
	if key == &"input_bindings" and is_inside_tree():
		# F1-013: sempre aplica padrões + sobreposições (ver core/input_bindings.gd).
		InputBindings.apply(_values[key] as Dictionary)
	if key == &"master_volume" and is_inside_tree():
		var volume: float = float(_values[key])
		AudioServer.set_bus_mute(0, volume <= 0.0001)
		if volume > 0.0001:
			AudioServer.set_bus_volume_db(0, linear_to_db(volume))


func _schema_entry(key: StringName) -> Array:
	return SCHEMA[key] as Array


func _copy(value: Variant) -> Variant:
	if value is Dictionary:
		return (value as Dictionary).duplicate(true)
	if value is Array:
		return (value as Array).duplicate(true)
	return value


func _is_config_text(text: String) -> bool:
	return ConfigFile.new().parse(text) == OK

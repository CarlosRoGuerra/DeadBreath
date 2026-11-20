extends TestCase
## Unit: autoload/settings.gd. Inclui o ACC-06 (todas as chaves sobrevivem a reiniciar).
## Usa instâncias próprias fora da árvore; não toca no user://settings.cfg real.
## Autor: Software Architect (F1-004).

const SettingsScript := preload("res://autoload/settings.gd")

## Chaves de COMPONENT_CONTRACTS §15.
const CONTRACT_KEYS: Array[StringName] = [
	&"mouse_sensitivity", &"invert_y", &"fov", &"motion_reduction", &"tremor_reduction",
	&"effects_intensity", &"respiratory_indicator", &"subtitles_enabled", &"subtitles_size",
	&"master_volume", &"input_bindings",
]

var _instances: Array[Node] = []


func after_each() -> void:
	for n: Node in _instances:
		if is_instance_valid(n):
			n.free()
	_instances.clear()


func _new_settings(path: String) -> SettingsScript:
	var s: SettingsScript = SettingsScript.new()
	s.file_path = path
	s.autosave = false
	_instances.append(s)
	return s


## Um valor diferente do padrão para cada chave.
func _custom_values() -> Dictionary:
	return {
		&"mouse_sensitivity": 0.33, &"invert_y": true, &"fov": 90.0, &"motion_reduction": 0.5,
		&"tremor_reduction": 1.0, &"effects_intensity": 0.25, &"respiratory_indicator": true,
		&"subtitles_enabled": false, &"subtitles_size": 1.5, &"master_volume": 0.4,
		&"input_bindings": {"interact": [{"type": "key", "physical_keycode": 70}]},
	}


func test_schema_has_exactly_the_contract_keys() -> void:
	var s: SettingsScript = _new_settings(tmp_dir().path_join("s.cfg"))
	var keys: Array[StringName] = s.keys()
	keys.sort()
	var expected: Array[StringName] = CONTRACT_KEYS.duplicate()
	expected.sort()
	assert_eq(keys, expected)


func test_acc06_all_keys_survive_restart() -> void:
	var path: String = tmp_dir().path_join("settings.cfg")
	var custom: Dictionary = _custom_values()
	var first: SettingsScript = _new_settings(path)
	for key: StringName in custom.keys():
		assert_ne(first.get_default(key), custom[key], "o valor de teste de '%s' precisa diferir do padrão" % key)
		first.set_value(key, custom[key])
	assert_eq(first.save_to_disk(), OK)
	# "Reinício": uma instância nova lê o mesmo arquivo.
	var second: SettingsScript = _new_settings(path)
	assert_eq(second.load_from_disk(), OK)
	for key: StringName in custom.keys():
		var expected: Variant = custom[key]
		if typeof(expected) == TYPE_FLOAT:
			assert_almost_eq(second.get_float(key), float(expected), 0.000001, "chave " + String(key))
		else:
			assert_eq(second.get_value(key), expected, "chave " + String(key))


func test_rejects_wrong_type_and_unknown_key_with_warning() -> void:
	var s: SettingsScript = _new_settings(tmp_dir().path_join("s.cfg"))
	var warnings: Array[String] = []
	var listener: Callable = func(level: int, category: StringName, message: String) -> void:
		if level == Log.WARN and category == &"settings":
			warnings.append(message)
	Log.message_logged.connect(listener)
	s.set_value(&"fov", "noventa")
	s.set_value(&"chave_inexistente", 1)
	Log.message_logged.disconnect(listener)
	assert_almost_eq(s.get_float(&"fov"), 75.0, 0.0001, "fov continua no padrão")
	assert_false(s.has_key(&"chave_inexistente"))
	assert_eq(warnings.size(), 2, "um aviso por valor rejeitado")


func test_clamps_numbers_and_accepts_int_for_float() -> void:
	var s: SettingsScript = _new_settings(tmp_dir().path_join("s.cfg"))
	s.set_value(&"fov", 200.0)
	assert_almost_eq(s.get_float(&"fov"), 100.0, 0.0001)
	s.set_value(&"mouse_sensitivity", -1.0)
	assert_almost_eq(s.get_float(&"mouse_sensitivity"), 0.02, 0.0001)
	s.set_value(&"fov", 80)
	assert_eq(typeof(s.get_value(&"fov")), TYPE_FLOAT)
	assert_almost_eq(s.get_float(&"fov"), 80.0, 0.0001)


func test_changed_signal_only_on_real_change() -> void:
	var s: SettingsScript = _new_settings(tmp_dir().path_join("s.cfg"))
	var changes: Array[StringName] = []
	s.changed.connect(func(key: StringName) -> void: changes.append(key))
	s.set_value(&"invert_y", false)
	s.set_value(&"invert_y", true)
	s.set_value(&"invert_y", true)
	var expected: Array[StringName] = [&"invert_y"]
	assert_eq(changes, expected)


func test_corrupt_file_falls_back_to_defaults() -> void:
	var path: String = tmp_dir().path_join("settings.cfg")
	var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	f.store_string("isto não é [um config válido = = =")
	f.close()
	expect_engine_error("ConfigFile parse error")
	var s: SettingsScript = _new_settings(path)
	assert_ne(s.load_from_disk(), OK)
	for key: StringName in CONTRACT_KEYS:
		assert_eq(s.get_value(key), s.get_default(key), "padrão em " + String(key))


## Revisão F1-010, R1-05: clampf(NaN) devolve NaN, então não finitos precisam ser rejeitados.
func test_rejects_non_finite_numbers() -> void:
	var s: SettingsScript = _new_settings(tmp_dir().path_join("s.cfg"))
	var warnings: Array[String] = []
	var listener: Callable = func(level: int, category: StringName, message: String) -> void:
		if level == Log.WARN and category == &"settings":
			warnings.append(message)
	Log.message_logged.connect(listener)
	s.set_value(&"fov", NAN)
	s.set_value(&"mouse_sensitivity", INF)
	s.set_value(&"master_volume", -INF)
	Log.message_logged.disconnect(listener)
	assert_almost_eq(s.get_float(&"fov"), 75.0, 0.0001, "fov segue no padrão")
	assert_almost_eq(s.get_float(&"mouse_sensitivity"), 0.12, 0.0001, "sensibilidade segue no padrão")
	assert_almost_eq(s.get_float(&"master_volume"), 1.0, 0.0001, "volume segue no padrão")
	assert_eq(warnings.size(), 3, "um aviso por valor não finito")


func test_non_finite_value_in_file_is_ignored_on_load() -> void:
	var path: String = tmp_dir().path_join("settings.cfg")
	var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	f.store_string("[settings]\nfov=nan\ninvert_y=true\n")
	f.close()
	var s: SettingsScript = _new_settings(path)
	assert_eq(s.load_from_disk(), OK)
	assert_true(is_finite(s.get_float(&"fov")), "fov não pode virar NaN ao carregar")
	assert_almost_eq(s.get_float(&"fov"), 75.0, 0.0001, "fov fica no padrão")
	assert_true(s.get_bool(&"invert_y"), "as demais chaves válidas do arquivo continuam carregando")


func test_get_value_returns_copy_of_collections() -> void:
	var s: SettingsScript = _new_settings(tmp_dir().path_join("s.cfg"))
	var bindings: Dictionary = s.get_value(&"input_bindings")
	bindings["hack"] = true
	assert_false((s.get_value(&"input_bindings") as Dictionary).has("hack"), "alterar a cópia não altera o Settings")

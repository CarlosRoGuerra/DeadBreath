extends TestCase
## Integration: autoload/save_service.gd. Inclui o PER-09 na versão L0 (escrita atômica).
## Usa instâncias próprias com base_dir temporário. Autor: Software Architect (F1-004).

const SaveScript := preload("res://autoload/save_service.gd")

var _instances: Array[Node] = []
var _log_listeners: Array[Callable] = []


func after_each() -> void:
	AtomicFile.simulate_failure_after_bytes = -1
	for listener: Callable in _log_listeners:
		if Log.message_logged.is_connected(listener):
			Log.message_logged.disconnect(listener)
	_log_listeners.clear()
	for n: Node in _instances:
		if is_instance_valid(n):
			n.free()
	_instances.clear()


func _service() -> SaveScript:
	var s: SaveScript = SaveScript.new()
	s.base_dir = tmp_dir()
	_instances.append(s)
	return s


func _capture_logs(levels: Array[int]) -> Array[String]:
	var captured: Array[String] = []
	var listener: Callable = func(level: int, category: StringName, message: String) -> void:
		if category == &"save" and levels.has(level):
			captured.append(message)
	Log.message_logged.connect(listener)
	_log_listeners.append(listener)
	return captured


func test_round_trip_keeps_values() -> void:
	var s: SaveScript = _service()
	var data: Dictionary = {"name": "slot de teste", "count": 3, "nested": {"flag": true}, "rng_state": "12345678901234567890"}
	assert_eq(s.write_json(&"slot_a", data), OK)
	assert_true(s.has_slot(&"slot_a"))
	var back: Dictionary = s.read_json(&"slot_a")
	assert_eq(back.get("name"), "slot de teste")
	assert_almost_eq(float(back.get("count")), 3.0, 0.0001)
	assert_eq((back.get("nested") as Dictionary).get("flag"), true)
	assert_eq(back.get("rng_state"), "12345678901234567890", "inteiro grande sobrevive como string")


func test_per09_simulated_crash_keeps_previous_file_readable() -> void:
	var s: SaveScript = _service()
	assert_eq(s.write_json(&"checkpoint", {"version": "anterior"}), OK)
	AtomicFile.simulate_failure_after_bytes = 8
	assert_ne(s.write_json(&"checkpoint", {"version": "nova"}), OK, "a escrita simulada falha")
	assert_eq(s.read_json(&"checkpoint"), {"version": "anterior"})


func test_missing_slot_returns_empty() -> void:
	var s: SaveScript = _service()
	assert_false(s.has_slot(&"nao_existe"))
	assert_eq(s.read_json(&"nao_existe"), {})


func test_corrupt_slot_without_copies_returns_empty_and_logs_error() -> void:
	var s: SaveScript = _service()
	var errors: Array[String] = _capture_logs([Log.ERROR])
	var f: FileAccess = FileAccess.open(s.get_slot_path(&"quebrado"), FileAccess.WRITE)
	f.store_string("{\"a\": ")
	f.close()
	assert_eq(s.read_json(&"quebrado"), {})
	assert_eq(errors.size(), 1, "um Log.error para slot corrompido")


func test_corrupt_main_recovers_from_backup_with_warning() -> void:
	var s: SaveScript = _service()
	assert_eq(s.write_json(&"slot_b", {"v": 1}), OK)
	assert_eq(s.write_json(&"slot_b", {"v": 2}), OK)
	var f: FileAccess = FileAccess.open(s.get_slot_path(&"slot_b"), FileAccess.WRITE)
	f.store_string("lixo")
	f.close()
	var warnings: Array[String] = _capture_logs([Log.WARN])
	var back: Dictionary = s.read_json(&"slot_b")
	assert_almost_eq(float(back.get("v", -1.0)), 1.0, 0.0001, "volta para a versão anterior (.bak)")
	assert_eq(warnings.size(), 1, "um Log.warn de recuperação")


func test_rejects_invalid_slot_names() -> void:
	var s: SaveScript = _service()
	for bad: StringName in [&"../fora", &"Maiuscula", &"", &"com espaço", &"a/b"]:
		assert_false(s.is_valid_slot(bad), "deveria rejeitar '%s'" % bad)
		assert_eq(s.write_json(bad, {}), ERR_INVALID_PARAMETER)
	assert_true(s.is_valid_slot(&"chapter_2_slot"))

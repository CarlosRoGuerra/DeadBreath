extends TestCase
## Unit: core/atomic_file.gd (escrita atômica, base do PER-09). Autor: Software Architect (F1-004).


func after_each() -> void:
	AtomicFile.simulate_failure_after_bytes = -1


func test_write_then_read_roundtrip() -> void:
	var path: String = tmp_dir().path_join("a.txt")
	assert_eq(AtomicFile.write_text(path, "olá, mundo"), OK)
	var r: AtomicFile.ReadResult = AtomicFile.read_text(path)
	assert_true(r.ok)
	assert_eq(r.text, "olá, mundo")
	assert_eq(r.source, "main")
	assert_false(FileAccess.file_exists(path + AtomicFile.TMP_SUFFIX), "não deve sobrar .tmp")


func test_second_write_keeps_previous_as_backup() -> void:
	var path: String = tmp_dir().path_join("b.txt")
	assert_eq(AtomicFile.write_text(path, "v1"), OK)
	assert_eq(AtomicFile.write_text(path, "v2"), OK)
	assert_eq(AtomicFile.read_text(path).text, "v2")
	assert_eq(FileAccess.get_file_as_string(path + AtomicFile.BAK_SUFFIX), "v1")


func test_simulated_crash_keeps_previous_version() -> void:
	var path: String = tmp_dir().path_join("c.txt")
	assert_eq(AtomicFile.write_text(path, "versão anterior completa"), OK)
	AtomicFile.simulate_failure_after_bytes = 5
	assert_ne(AtomicFile.write_text(path, "versão nova que falha no meio"), OK)
	assert_eq(AtomicFile.simulate_failure_after_bytes, -1, "o gancho se desarma sozinho")
	var r: AtomicFile.ReadResult = AtomicFile.read_text(path)
	assert_eq(r.text, "versão anterior completa")
	assert_eq(r.source, "main")


func test_recovers_from_tmp_when_swap_was_interrupted() -> void:
	# Queda entre "principal -> .bak" e ".tmp -> principal": só restam .tmp (novo) e .bak (antigo).
	var path: String = tmp_dir().path_join("d.txt")
	assert_eq(AtomicFile.write_text(path, "antigo"), OK)
	assert_eq(DirAccess.rename_absolute(path, path + AtomicFile.BAK_SUFFIX), OK)
	var f: FileAccess = FileAccess.open(path + AtomicFile.TMP_SUFFIX, FileAccess.WRITE)
	f.store_string("novo")
	f.close()
	var r: AtomicFile.ReadResult = AtomicFile.read_text(path)
	assert_eq(r.text, "novo")
	assert_eq(r.source, "tmp")


func test_validator_falls_back_to_backup_when_main_is_corrupt() -> void:
	var path: String = tmp_dir().path_join("e.json")
	assert_eq(AtomicFile.write_text(path, "{\"v\": 1}"), OK)
	assert_eq(AtomicFile.write_text(path, "{\"v\": 2}"), OK)
	var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	f.store_string("{\"v\": 2")
	f.close()
	var is_json: Callable = func(text: String) -> bool:
		return JSON.new().parse(text) == OK
	var r: AtomicFile.ReadResult = AtomicFile.read_text(path, is_json)
	assert_eq(r.source, "bak")
	assert_eq(r.text, "{\"v\": 1}")


func test_read_missing_file_is_not_ok() -> void:
	var r: AtomicFile.ReadResult = AtomicFile.read_text(tmp_dir().path_join("nada.txt"))
	assert_false(r.ok)
	assert_eq(r.source, "")

extends SceneTree
## Runner headless do DEAD BREATH (F1-005, contrato TEST_PLAN §4 v1.0).
##
## Uso (com o projeto já importado; tools/run_tests.ps1 faz a importação antes):
##   godot --headless --path game -s res://tests/run_all.gd -- [--filter=<texto>] [--level=<nivel>]
## Níveis: unit, integration, scenarios, architecture (padrão: os quatro) e meta.
## Opção extra, usada pelos meta-testes: --root=<pasta> substitui as pastas padrão.
##
## Saída: uma linha por teste (PASS/FAIL, arquivo::teste, tempo em ms) e um resumo.
## Código de saída: 0 só com ao menos 1 teste e nenhuma falha; 1 nos demais casos.
##
## Limite: erro de script em tempo de execução aparece só como "SCRIPT ERROR" no console
## (a função que falhou para e o chamador segue). O runner não intercepta isso; por isso
## tools/run_tests.ps1 trata essa linha como falha. Um await que nunca termina é pego pelo
## watchdog (PROGRESS_TIMEOUT_MS).

const LEVEL_DIRS: Dictionary = {
	"unit": "res://tests/unit",
	"integration": "res://tests/integration",
	"scenarios": "res://tests/scenarios",
	"architecture": "res://tests/architecture",
	"meta": "res://tests/meta",
}
const DEFAULT_LEVELS: Array[String] = ["unit", "integration", "scenarios", "architecture"]
## Pastas com este nome não são descobertas (fixtures de teste, nunca executadas direto).
const FIXTURE_DIR_NAME: String = "fixtures"
## Sem progresso por este tempo, o teste atual é reprovado por timeout e o runner encerra.
const PROGRESS_TIMEOUT_MS: int = 15000
const TESTS_PREFIX: String = "res://tests/"


class RunnerResult:
	extends RefCounted
	var file_name: String = ""
	var test_name: String = ""
	var passed: bool = false
	var duration_ms: int = 0
	var assert_count: int = 0
	var messages: PackedStringArray = PackedStringArray()
	var notes: PackedStringArray = PackedStringArray()


var _filter: String = ""
var _levels: Array[String] = []
var _root_override: String = ""
var _arg_error: String = ""
var _results: Array[RunnerResult] = []
var _started: bool = false
var _finished: bool = false
var _run_start_ms: int = 0
var _progress_ms: int = 0
var _progress_file: String = "(inicializacao)"
var _progress_test: String = ""


func _initialize() -> void:
	_run_start_ms = Time.get_ticks_msec()
	_progress_ms = _run_start_ms


func _process(_delta: float) -> bool:
	# A execução começa no primeiro frame, quando os autoloads já estão na árvore.
	if not _started:
		_started = true
		_execute()
		return false
	if not _finished and Time.get_ticks_msec() - _progress_ms > PROGRESS_TIMEOUT_MS:
		var stalled_ms: int = Time.get_ticks_msec() - _progress_ms
		_add_result(_progress_file, _progress_test, false, stalled_ms,
			PackedStringArray(["tempo esgotado: sem progresso por %d ms em '%s::%s' (await que nao termina ou erro de script em tempo de execucao)" % [stalled_ms, _progress_file, _progress_test]]),
			0, PackedStringArray())
		_finish()
	return false


func _execute() -> void:
	if not _parse_args():
		print("ERRO de argumentos: " + _arg_error)
		_finish()
		return
	var roots: Array[String] = []
	if _root_override.is_empty():
		for level: String in _levels:
			var level_dir: String = LEVEL_DIRS[level]
			roots.append(level_dir)
	else:
		roots.append(_root_override)
	var files: PackedStringArray = PackedStringArray()
	for root_dir: String in roots:
		_discover(root_dir, files)
	print("Descoberta: %d arquivo(s) de teste em: %s" % [files.size(), ", ".join(PackedStringArray(roots))])
	for file_path: String in files:
		await _run_file(file_path)
	_finish()


func _parse_args() -> bool:
	var levels_given: Array[String] = []
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--filter="):
			_filter = arg.trim_prefix("--filter=")
		elif arg.begins_with("--level="):
			var level: String = arg.trim_prefix("--level=")
			if not LEVEL_DIRS.has(level):
				_arg_error = "nivel desconhecido '%s' (use unit, integration, scenarios, architecture ou meta)" % level
				return false
			levels_given.append(level)
		elif arg.begins_with("--root="):
			_root_override = arg.trim_prefix("--root=")
		else:
			_arg_error = "argumento desconhecido '%s'" % arg
			return false
	if levels_given.is_empty():
		_levels.assign(DEFAULT_LEVELS)
	else:
		_levels = levels_given
	return true


## Coleta test_*.gd recursivamente, ordenado, sem entrar em pastas "fixtures" nem em pastas ocultas.
func _discover(dir_path: String, out: PackedStringArray) -> void:
	var dir: DirAccess = DirAccess.open(dir_path)
	if dir == null:
		return
	var files_here: PackedStringArray = PackedStringArray()
	var subdirs: PackedStringArray = PackedStringArray()
	dir.list_dir_begin()
	var entry: String = dir.get_next()
	while entry != "":
		if not entry.begins_with("."):
			if dir.current_is_dir():
				if entry != FIXTURE_DIR_NAME:
					subdirs.append(entry)
			elif entry.begins_with("test_") and entry.ends_with(".gd"):
				files_here.append(entry)
		entry = dir.get_next()
	dir.list_dir_end()
	files_here.sort()
	subdirs.sort()
	for file_name: String in files_here:
		out.append(dir_path.path_join(file_name))
	for subdir: String in subdirs:
		_discover(dir_path.path_join(subdir), out)


func _run_file(file_path: String) -> void:
	var display: String = _display_name(file_path)
	_set_progress(display, "(carga)")
	var test_script: GDScript = ResourceLoader.load(file_path, "GDScript", ResourceLoader.CACHE_MODE_REUSE) as GDScript
	if test_script == null or not test_script.can_instantiate():
		_add_result(display, "(carga)", false, 0,
			PackedStringArray(["script nao carrega: erro de parse ou aviso tratado como erro (veja SCRIPT ERROR acima)"]),
			0, PackedStringArray())
		return
	var selected: Array[String] = []
	for method_name: String in _test_names(test_script):
		if _matches_filter(display + "::" + method_name):
			selected.append(method_name)
	if selected.is_empty():
		return
	var instance: TestCase = test_script.new() as TestCase
	if instance == null:
		_add_result(display, "(carga)", false, 0,
			PackedStringArray(["o script nao estende TestCase"]), 0, PackedStringArray())
		return
	root.add_child(instance)

	_set_progress(display, "before_all")
	instance.harness_begin_test("before_all")
	await instance.call("before_all")
	var file_failures: PackedStringArray = PackedStringArray(instance.failures)
	instance.harness_end_test()

	for test_name: String in selected:
		_set_progress(display, test_name)
		var start_ms: int = Time.get_ticks_msec()
		if not file_failures.is_empty():
			_add_result(display, test_name, false, 0,
				PackedStringArray(["before_all falhou: " + "; ".join(file_failures)]), 0, PackedStringArray())
			continue
		instance.harness_begin_test(test_name)
		await instance.call("before_each")
		await instance.call(test_name)
		await instance.call("after_each")
		var messages: PackedStringArray = PackedStringArray(instance.failures)
		var asserts: int = instance.assert_count
		var notes: PackedStringArray = PackedStringArray(instance.notes)
		instance.harness_end_test()
		_add_result(display, test_name, messages.is_empty(), Time.get_ticks_msec() - start_ms, messages, asserts, notes)

	_set_progress(display, "after_all")
	instance.harness_begin_test("after_all")
	await instance.call("after_all")
	var after_failures: PackedStringArray = PackedStringArray(instance.failures)
	instance.harness_end_test()
	if not after_failures.is_empty():
		_add_result(display, "(after_all)", false, 0,
			PackedStringArray(["after_all falhou: " + "; ".join(after_failures)]), 0, PackedStringArray())

	root.remove_child(instance)
	instance.free()


func _test_names(test_script: GDScript) -> Array[String]:
	var names: Array[String] = []
	for method: Dictionary in test_script.get_script_method_list():
		var method_name: String = str(method.get("name", ""))
		var args: Array = method.get("args", [])
		if method_name.begins_with("test_") and args.is_empty():
			names.append(method_name)
	names.sort()
	return names


func _matches_filter(label: String) -> bool:
	return _filter.is_empty() or label.to_lower().contains(_filter.to_lower())


## Nome curto para a saída: relativo a res://tests/ ou à raiz informada com --root.
func _display_name(file_path: String) -> String:
	if not _root_override.is_empty() and file_path.begins_with(_root_override + "/"):
		return file_path.trim_prefix(_root_override + "/")
	if file_path.begins_with(TESTS_PREFIX):
		return file_path.trim_prefix(TESTS_PREFIX)
	return file_path


func _set_progress(file_name: String, test_name: String) -> void:
	_progress_ms = Time.get_ticks_msec()
	_progress_file = file_name
	_progress_test = test_name


func _add_result(file_name: String, test_name: String, passed: bool, duration_ms: int,
		messages: PackedStringArray, asserts: int, notes: PackedStringArray) -> void:
	var result: RunnerResult = RunnerResult.new()
	result.file_name = file_name
	result.test_name = test_name
	result.passed = passed
	result.duration_ms = duration_ms
	result.assert_count = asserts
	result.messages = messages
	result.notes = notes
	_results.append(result)
	_set_progress(file_name, test_name)
	var status: String = "PASS" if passed else "FAIL"
	print("%s  %s::%s  %d ms  (asserts: %d)" % [status, file_name, test_name, duration_ms, asserts])
	for note_text: String in notes:
		print("      nota: " + note_text)
	for message: String in messages:
		print("      - " + message)


func _finish() -> void:
	if _finished:
		return
	_finished = true
	var total: int = _results.size()
	var passed_count: int = 0
	var failed_names: PackedStringArray = PackedStringArray()
	var without_assert: int = 0
	for result: RunnerResult in _results:
		if result.passed:
			passed_count += 1
			if result.assert_count == 0:
				without_assert += 1
		else:
			failed_names.append(result.file_name + "::" + result.test_name)
	var elapsed_ms: int = Time.get_ticks_msec() - _run_start_ms
	var ok: bool = total >= 1 and failed_names.is_empty()
	print("")
	print("RESUMO: total=%d passou=%d falhou=%d sem_assert=%d tempo_total_ms=%d" % [
		total, passed_count, failed_names.size(), without_assert, elapsed_ms])
	for failed: String in failed_names:
		print("  falhou: " + failed)
	if total == 0:
		print("  nenhum teste executado (ver filtro, nivel e pastas)")
	if without_assert > 0:
		print("AVISO: %d teste(s) passaram sem nenhum assert (nao provam nada)" % without_assert)
	print("RESULTADO: %s (codigo de saida %d)" % ["APROVADO" if ok else "REPROVADO", 0 if ok else 1])
	quit(0 if ok else 1)

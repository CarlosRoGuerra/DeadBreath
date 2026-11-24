extends SceneTree
## Runner headless do DEAD BREATH (F1-005, contrato TEST_PLAN §4 v1.0).
##
## Uso (com o projeto já importado; tools/run_tests.ps1 faz a importação antes, com --fixed-fps 60):
##   godot --headless --fixed-fps 60 --path game -s res://tests/run_all.gd -- [--filter=<texto>] [--level=<nivel>]
## Níveis: unit, integration, scenarios, architecture (padrão: os quatro) e meta.
## Opções extras, usadas pelos meta-testes: --root=<pasta> substitui as pastas padrão;
## --stall-frames=<n> e --wall-ms=<n> trocam os limites do watchdog.
##
## Saída: uma linha por teste (PASS/FAIL, arquivo::teste, tempo em ms) e um resumo.
## Código de saída: 0 só com ao menos 1 teste e nenhuma falha; 1 nos demais casos.
##
## Regras:
##   - teste sem nenhum assert reprova (vacuidade justificada usa assert explícito);
##   - erro de script (tipo SCRIPT) reprova o teste em execução, com arquivo:linha, a não ser que o
##     teste o declare com expect_script_error(); erro de engine (ERROR) não reprova, é nota, a não ser
##     que o teste o declare com expect_engine_error(); declarado e não ocorrido reprova;
##   - entre um teste e o próximo o runner espera FLUSH_PHYSICS_FRAMES frames de física (R1-07);
##   - watchdog: reprova o teste após STALL_PHYSICS_FRAMES frames de física sem progresso (wait_* ou fim
##     do teste); teto de tempo de parede (WALL_CEILING_MS) como rede de segurança. Ao disparar, a
##     execução termina: a corrotina travada não pode ser cancelada em GDScript. Um laço síncrono sem
##     await não passa pelo watchdog (limite conhecido).
## tools/run_tests.ps1 barra também qualquer linha "SCRIPT ERROR" da saída (segunda linha de defesa).

const LEVEL_DIRS: Dictionary = {
	"unit": "res://tests/unit",
	"integration": "res://tests/integration",
	"scenarios": "res://tests/scenarios",
	"architecture": "res://tests/architecture",
	"arc04": "res://tests/arc04",
	"meta": "res://tests/meta",
	"property": "res://tests/property",
}
## Execução padrão. property (varreduras longas e determinísticas), meta e arc04 ficam fora dela: rodam com
## --level=property, --level=meta e --level=arc04 (tools/run_tests.ps1 tem uma etapa para cada um). O ARC-04 (compilar
## todos os scripts, ~1 s) já tem etapa própria no pipeline; rodar de novo na suíte padrão só dobrava o custo (F4).
const DEFAULT_LEVELS: Array[String] = ["unit", "integration", "scenarios", "architecture"]
## Pastas com este nome não são descobertas (fixtures de teste, nunca executadas direto).
const FIXTURE_DIR_NAME: String = "fixtures"
## Frames de física sem progresso até o watchdog reprovar o teste (600 = 10 s de física a 60 Hz).
const STALL_PHYSICS_FRAMES_DEFAULT: int = 600
## Teto de tempo de parede por fase de teste: rede de segurança, generosa de propósito.
const WALL_CEILING_MS_DEFAULT: int = 300000
const TESTS_PREFIX: String = "res://tests/"
## Quantos erros de engine não declarados são listados como nota por fase.
const MAX_UNDECLARED_NOTES: int = 3


class RunnerResult:
	extends RefCounted
	var file_name: String = ""
	var test_name: String = ""
	var passed: bool = false
	var duration_ms: int = 0
	var assert_count: int = 0
	var messages: PackedStringArray = PackedStringArray()
	var notes: PackedStringArray = PackedStringArray()


class ErrorVerdict:
	extends RefCounted
	var failures: PackedStringArray = PackedStringArray()
	var notes: PackedStringArray = PackedStringArray()


var _filter: String = ""
var _levels: Array[String] = []
var _root_override: String = ""
var _stall_frames: int = STALL_PHYSICS_FRAMES_DEFAULT
var _wall_ms: int = WALL_CEILING_MS_DEFAULT
var _arg_error: String = ""
var _results: Array[RunnerResult] = []
var _started: bool = false
var _finished: bool = false
var _run_start_ms: int = 0
var _capture: ErrorCapture = null
## Fase em execução (before_all, um teste ou after_all) observada pelo watchdog.
var _active: TestCase = null
var _active_file: String = "(inicializacao)"
var _active_test: String = ""
var _active_start_ms: int = 0
var _seen_progress: int = 0
var _stall_base_physics: int = 0


func _initialize() -> void:
	_run_start_ms = Time.get_ticks_msec()
	_capture = ErrorCapture.new()
	OS.add_logger(_capture)


func _process(_delta: float) -> bool:
	# A execução começa no primeiro frame, quando os autoloads já estão na árvore.
	if not _started:
		_started = true
		_execute()
		return false
	if not _finished and _active != null:
		# Teto de tempo de parede primeiro: vale mesmo quando o teste está progredindo.
		if Time.get_ticks_msec() - _active_start_ms > _wall_ms:
			_timeout("teto de tempo de parede de %d ms excedido" % _wall_ms)
			return false
		var physics_now: int = Engine.get_physics_frames()
		if _active.harness_progress != _seen_progress:
			_seen_progress = _active.harness_progress
			_stall_base_physics = physics_now
		elif physics_now - _stall_base_physics > _stall_frames:
			_timeout("sem progresso por %d frames de fisica (nenhum wait_* do teste nem fim da fase)" % (physics_now - _stall_base_physics))
	return false


## Reprova a fase em execução pelo watchdog e encerra a execução.
func _timeout(reason: String) -> void:
	var elapsed_ms: int = Time.get_ticks_msec() - _active_start_ms
	_add_result(_active_file, _active_test, false, elapsed_ms,
		PackedStringArray(["tempo esgotado: %s em '%s::%s' (await que nao termina ou laco de script; ver SCRIPT ERROR)" % [reason, _active_file, _active_test]]),
		0, PackedStringArray())
	_active = null
	_finish()


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
				_arg_error = "nivel desconhecido '%s' (use unit, integration, scenarios, architecture, arc04, property ou meta)" % level
				return false
			levels_given.append(level)
		elif arg.begins_with("--root="):
			_root_override = arg.trim_prefix("--root=")
		elif arg.begins_with("--stall-frames="):
			_stall_frames = int(arg.trim_prefix("--stall-frames="))
			if _stall_frames <= 0:
				_arg_error = "--stall-frames precisa ser positivo"
				return false
		elif arg.begins_with("--wall-ms="):
			_wall_ms = int(arg.trim_prefix("--wall-ms="))
			if _wall_ms <= 0:
				_arg_error = "--wall-ms precisa ser positivo"
				return false
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
	_begin_phase(display, "(carga)", null)
	var test_script: GDScript = ResourceLoader.load(file_path, "GDScript", ResourceLoader.CACHE_MODE_REUSE) as GDScript
	_end_phase()
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

	_begin_phase(display, "before_all", instance)
	instance.harness_begin_test("before_all")
	_capture.begin_window()
	await instance.call("before_all")
	var file_verdict: ErrorVerdict = _judge_errors(PackedStringArray(), PackedStringArray(), _capture.take_window())
	var file_failures: PackedStringArray = PackedStringArray(instance.failures)
	file_failures.append_array(file_verdict.failures)
	instance.harness_end_test()
	_end_phase()

	for test_name: String in selected:
		var start_ms: int = Time.get_ticks_msec()
		if not file_failures.is_empty():
			_add_result(display, test_name, false, 0,
				PackedStringArray(["before_all falhou: " + "; ".join(file_failures)]), 0, PackedStringArray())
			continue
		_begin_phase(display, test_name, instance)
		instance.harness_begin_test(test_name)
		_capture.begin_window()
		await instance.call("before_each")
		await instance.call(test_name)
		await instance.call("after_each")
		var verdict: ErrorVerdict = _judge_errors(instance.expected_script_errors, instance.expected_engine_errors, _capture.take_window())
		var messages: PackedStringArray = PackedStringArray(instance.failures)
		messages.append_array(verdict.failures)
		var notes: PackedStringArray = PackedStringArray(instance.notes)
		notes.append_array(verdict.notes)
		var asserts: int = instance.assert_count
		instance.harness_end_test()
		# O watchdog só observa entre frames; um teste que termina entre dois frames também é medido aqui.
		var test_elapsed_ms: int = Time.get_ticks_msec() - start_ms
		if test_elapsed_ms > _wall_ms:
			messages.append("teto de tempo de parede de %d ms excedido (o teste levou %d ms)" % [_wall_ms, test_elapsed_ms])
		if messages.is_empty() and asserts == 0:
			messages.append("teste sem nenhum assert: passa sem provar nada (vacuidade precisa de assert explicito, ex.: assert_true(true, 'vacuo: <motivo>'))")
		_add_result(display, test_name, messages.is_empty(), Time.get_ticks_msec() - start_ms, messages, asserts, notes)
		# R1-07: os nós do teste saem do espaço de física antes do próximo teste.
		await instance.wait_physics_frames(TestCase.FLUSH_PHYSICS_FRAMES)
		_end_phase()

	_begin_phase(display, "after_all", instance)
	instance.harness_begin_test("after_all")
	_capture.begin_window()
	await instance.call("after_all")
	var after_verdict: ErrorVerdict = _judge_errors(PackedStringArray(), PackedStringArray(), _capture.take_window())
	var after_failures: PackedStringArray = PackedStringArray(instance.failures)
	after_failures.append_array(after_verdict.failures)
	instance.harness_end_test()
	_end_phase()
	if not after_failures.is_empty():
		_add_result(display, "(after_all)", false, 0,
			PackedStringArray(["after_all falhou: " + "; ".join(after_failures)]), 0, PackedStringArray())

	root.remove_child(instance)
	instance.free()


func _begin_phase(file_name: String, test_name: String, instance: TestCase) -> void:
	_active_file = file_name
	_active_test = test_name
	_active = instance
	_active_start_ms = Time.get_ticks_msec()
	if instance != null:
		_seen_progress = instance.harness_progress
	_stall_base_physics = Engine.get_physics_frames()


func _end_phase() -> void:
	_active = null


## Confronta os erros capturados numa fase com as declarações do teste.
func _judge_errors(expected_script: PackedStringArray, expected_engine: PackedStringArray,
		errors: Array[ErrorCapture.CapturedError]) -> ErrorVerdict:
	var verdict: ErrorVerdict = ErrorVerdict.new()
	var consumed: Array[bool] = []
	for i: int in errors.size():
		consumed.append(false)
	_consume_expected(expected_script, Logger.ERROR_TYPE_SCRIPT, errors, consumed,
		verdict, "erro de script esperado nao ocorreu: '%s'")
	_consume_expected(expected_engine, Logger.ERROR_TYPE_ERROR, errors, consumed,
		verdict, "erro de engine esperado nao ocorreu: '%s'")
	var undeclared_engine: int = 0
	for i: int in errors.size():
		if consumed[i]:
			continue
		var error: ErrorCapture.CapturedError = errors[i]
		var where: String = "%s:%d" % [error.file, error.line]
		if error.kind == Logger.ERROR_TYPE_SCRIPT:
			verdict.failures.append("erro de script em tempo de execucao: %s (%s, funcao %s)" % [error.message, where, error.function])
		elif error.kind == Logger.ERROR_TYPE_ERROR:
			undeclared_engine += 1
			if undeclared_engine <= MAX_UNDECLARED_NOTES:
				verdict.notes.append("erro do engine nao declarado (nao reprova): %s (%s)" % [error.message, where])
	if undeclared_engine > MAX_UNDECLARED_NOTES:
		verdict.notes.append("... mais %d erro(s) do engine nao declarado(s)" % (undeclared_engine - MAX_UNDECLARED_NOTES))
	return verdict


## Marca como consumido o primeiro erro de cada tipo que contém o trecho esperado.
func _consume_expected(patterns: PackedStringArray, kind: int, errors: Array[ErrorCapture.CapturedError],
		consumed: Array[bool], verdict: ErrorVerdict, missing_format: String) -> void:
	for pattern: String in patterns:
		var found: bool = false
		for i: int in errors.size():
			if not consumed[i] and errors[i].kind == kind and errors[i].message.contains(pattern):
				consumed[i] = true
				found = true
				break
		if not found:
			verdict.failures.append(missing_format % pattern)


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
	if _capture != null:
		OS.remove_logger(_capture)
		_capture = null
	var total: int = _results.size()
	var passed_count: int = 0
	var failed_names: PackedStringArray = PackedStringArray()
	var without_assert: int = 0
	for result: RunnerResult in _results:
		if result.assert_count == 0:
			without_assert += 1
		if result.passed:
			passed_count += 1
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
	print("RESULTADO: %s (codigo de saida %d)" % ["APROVADO" if ok else "REPROVADO", 0 if ok else 1])
	quit(0 if ok else 1)

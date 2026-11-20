extends TestCase
## F2-008 (TASK_BOARD §4b): a simulação de balanceamento é determinística e bate com a referência. Roda
## tools/balance/balance_sim.gd duas vezes em pastas diferentes (processos Godot separados) e compara os bytes de
## cada arquivo; depois compara com os CSVs de referência de Docs/QA/EVIDENCE. Nível property: cada execução abre
## um processo do Godot, então fica fora da suíte padrão (< 10 s). Autor: Physiological Systems Engineer.

const PREFIX: String = "F2-008_"
const SCENARIO_FILES: PackedStringArray = [
	"sprint_exaustao.csv", "susto_estresse_alto.csv", "crise_tosse_recuperacao.csv",
	"bombinha_na_crise.csv", "perseguicao_continua.csv", "resumo.txt",
]
const CSV_HEADER: String = "tempo_s,marcha,esforco,velocidade_ms,distancia_m,estamina,estresse,faixa,severidade,estado,frequencia_irpm,chiado,risco_tosse_s,sprint_permitido,sprint_max,regeneracao_mult,firmeza,eventos"

var _run_index: int = 0


func _tool_path() -> String:
	return ProjectSettings.globalize_path("res://").path_join("../tools/balance/balance_sim.gd").simplify_path()


func _game_path() -> String:
	return ProjectSettings.globalize_path("res://").simplify_path()


func _reference_dir() -> String:
	return ProjectSettings.globalize_path("res://").path_join("../Docs/QA/EVIDENCE").simplify_path()


## Roda o simulador em `out_dir` (absoluto). Devolve o código de saída do processo.
func _run_tool(out_dir: String) -> int:
	var output: Array = []
	var args: PackedStringArray = PackedStringArray([
		"--headless", "--path", _game_path(), "-s", _tool_path(), "--",
		"--out=" + out_dir, "--prefix=" + PREFIX,
	])
	return OS.execute(OS.get_executable_path(), args, output, true)


func _fresh_dir() -> String:
	_run_index += 1
	var user_dir: String = "user://balance_sim_test_%d_%d" % [Time.get_ticks_usec(), _run_index]
	DirAccess.make_dir_recursive_absolute(user_dir)
	return ProjectSettings.globalize_path(user_dir)


func _read_bytes(path: String) -> PackedByteArray:
	return FileAccess.get_file_as_bytes(path)


func test_f2008_duas_execucoes_geram_arquivos_identicos() -> void:
	var first: String = _fresh_dir()
	var second: String = _fresh_dir()
	var code_a: int = _run_tool(first)
	var code_b: int = _run_tool(second)
	assert_eq(code_a, 0, "a primeira execução do simulador sai com 0")
	assert_eq(code_b, 0, "a segunda execução do simulador sai com 0")
	var identical: int = 0
	for file_name: String in SCENARIO_FILES:
		var a: PackedByteArray = _read_bytes(first.path_join(PREFIX + file_name))
		var b: PackedByteArray = _read_bytes(second.path_join(PREFIX + file_name))
		assert_true(a.size() > 0, "%s foi gravado" % file_name)
		assert_true(a == b, "%s idêntico nas duas execuções (mesma semente, mesmas entradas)" % file_name)
		if a == b and a.size() > 0:
			identical += 1
	note("determinismo: %d de %d arquivos idênticos entre duas execuções de processos separados" % [identical, SCENARIO_FILES.size()])
	var first_csv: String = FileAccess.get_file_as_string(first.path_join(PREFIX + "sprint_exaustao.csv"))
	assert_true(first_csv.begins_with(CSV_HEADER), "o CSV tem o cabeçalho documentado")
	_remove_dir(first)
	_remove_dir(second)


func test_f2008_saida_bate_com_a_referencia_de_evidencia() -> void:
	var out: String = _fresh_dir()
	assert_eq(_run_tool(out), 0, "o simulador sai com 0")
	var reference: String = _reference_dir()
	var compared: int = 0
	for file_name: String in SCENARIO_FILES:
		var reference_path: String = reference.path_join(PREFIX + file_name)
		assert_true(FileAccess.file_exists(reference_path), "referência gravada: %s" % file_name)
		if not FileAccess.file_exists(reference_path):
			continue
		var produced: PackedByteArray = _read_bytes(out.path_join(PREFIX + file_name))
		assert_true(produced == _read_bytes(reference_path), "%s igual à referência de Docs/QA/EVIDENCE" % file_name)
		compared += 1
	note("referência: %d de %d arquivos comparados byte a byte" % [compared, SCENARIO_FILES.size()])
	var summary: String = FileAccess.get_file_as_string(out.path_join(PREFIX + "resumo.txt"))
	assert_true(summary.contains("estamina_zerada"), "o resumo registra o esgotamento do sprint")
	assert_true(summary.contains("t=8.333 s  estamina_zerada"), "o sprint esgota em 500 ticks (8,333 s)")
	_remove_dir(out)


func _remove_dir(dir: String) -> void:
	var access: DirAccess = DirAccess.open(dir)
	if access == null:
		return
	access.list_dir_begin()
	var entry: String = access.get_next()
	while entry != "":
		if not access.current_is_dir():
			access.remove(entry)
		entry = access.get_next()
	access.list_dir_end()
	var parent: DirAccess = DirAccess.open(dir.get_base_dir())
	if parent != null:
		parent.remove(dir.get_file())

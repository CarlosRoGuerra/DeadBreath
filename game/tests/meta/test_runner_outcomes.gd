extends TestCase
## Meta-testes do runner (F1-005, TEST_PLAN §4): um que passa, um que falha, um com erro de script,
## além de aviso tratado como erro, raiz sem testes e filtro.
## Cada caso grava fixtures no tmp_dir() do teste (user://, fora de res://, por isso a execução
## normal nunca as descobre), roda o runner como subprocesso (OS.execute) apenas sobre essa pasta
## (--root) e confere o código de saída e o resumo.

const PASS_SRC: String = "extends TestCase\n\nfunc test_ok() -> void:\n\tassert_true(true, \"ok\")\n"
const FAIL_SRC: String = "extends TestCase\n\nfunc test_falha() -> void:\n\tassert_eq(1, 2, \"deliberado\")\n"
const BROKEN_SRC: String = "extends TestCase\n\nfunc test_quebrado( -> void:\n\tpass\n"
const UNTYPED_SRC: String = "extends TestCase\n\nfunc test_sem_tipo() -> void:\n\tvar x = 1\n\tassert_eq(x, 1)\n"


class RunOutcome:
	extends RefCounted
	var code: int = -999
	var output: String = ""


func test_fixture_que_passa_sai_com_0_e_resume() -> void:
	var dir: String = tmp_dir()
	_write(dir, "test_pass.gd", PASS_SRC)
	var outcome: RunOutcome = _run(dir, PackedStringArray())
	assert_eq(outcome.code, 0, "codigo de saida do runner")
	assert_true(outcome.output.contains("PASS  "), "linha PASS")
	assert_true(outcome.output.contains("test_ok"), "nome do teste na linha")
	assert_true(outcome.output.contains("falhou=0"), "resumo com falhou=0")
	assert_true(outcome.output.contains("RESULTADO: APROVADO"), "resultado APROVADO")


func test_fixture_que_falha_sai_com_1_e_mostra_a_mensagem() -> void:
	var dir: String = tmp_dir()
	_write(dir, "test_fail.gd", FAIL_SRC)
	var outcome: RunOutcome = _run(dir, PackedStringArray())
	assert_eq(outcome.code, 1, "codigo de saida do runner")
	assert_true(outcome.output.contains("FAIL  "), "linha FAIL")
	assert_true(outcome.output.contains("test_falha"), "nome do teste na linha")
	assert_true(outcome.output.contains("deliberado"), "mensagem da falha")
	assert_true(outcome.output.contains("falhou=1"), "resumo com falhou=1")
	assert_true(outcome.output.contains("RESULTADO: REPROVADO"), "resultado REPROVADO")


func test_script_com_erro_de_parse_sai_com_1_e_vira_falha() -> void:
	var dir: String = tmp_dir()
	_write(dir, "test_broken.gd", BROKEN_SRC)
	var outcome: RunOutcome = _run(dir, PackedStringArray())
	assert_eq(outcome.code, 1, "codigo de saida do runner")
	assert_true(outcome.output.contains("SCRIPT ERROR"), "o erro de script aparece no console")
	assert_true(outcome.output.contains("FAIL  test_broken.gd::(carga)"), "o arquivo quebrado vira FAIL")
	assert_true(outcome.output.contains("RESULTADO: REPROVADO"), "resultado REPROVADO")


func test_aviso_tratado_como_erro_sai_com_1() -> void:
	var dir: String = tmp_dir()
	_write(dir, "test_untyped.gd", UNTYPED_SRC)
	var outcome: RunOutcome = _run(dir, PackedStringArray())
	assert_eq(outcome.code, 1, "codigo de saida do runner")
	assert_true(outcome.output.contains("Warning treated as error"), "o aviso vira erro no console")
	assert_true(outcome.output.contains("FAIL  test_untyped.gd::(carga)"), "o arquivo vira FAIL")


func test_raiz_sem_testes_sai_com_1() -> void:
	var dir: String = tmp_dir()
	var outcome: RunOutcome = _run(dir, PackedStringArray())
	assert_eq(outcome.code, 1, "codigo de saida com zero testes")
	assert_true(outcome.output.contains("total=0"), "resumo com total=0")
	assert_true(outcome.output.contains("RESULTADO: REPROVADO"), "resultado REPROVADO")


func test_filtro_executa_so_o_teste_pedido() -> void:
	var dir: String = tmp_dir()
	_write(dir, "test_pass.gd", PASS_SRC)
	_write(dir, "test_fail.gd", FAIL_SRC)
	var outcome: RunOutcome = _run(dir, PackedStringArray(["--filter=test_ok"]))
	assert_eq(outcome.code, 0, "o filtro deixa só o teste que passa")
	assert_true(outcome.output.contains("test_ok"), "o teste filtrado aparece")
	assert_false(outcome.output.contains("test_falha"), "o teste de falha não é executado")


## Executa o runner como subprocesso sobre root_dir, com argumentos extras.
func _run(root_dir: String, extra: PackedStringArray) -> RunOutcome:
	var args: PackedStringArray = PackedStringArray([
		"--headless",
		"--path", ProjectSettings.globalize_path("res://"),
		"-s", "res://tests/run_all.gd",
		"--", "--root=" + root_dir,
	])
	for arg: String in extra:
		args.append(arg)
	var lines: Array = []
	var outcome: RunOutcome = RunOutcome.new()
	outcome.code = OS.execute(OS.get_executable_path(), args, lines, true)
	var text: String = ""
	for line: Variant in lines:
		text += str(line) + "\n"
	outcome.output = text
	return outcome


func _write(dir: String, file_name: String, source: String) -> void:
	var file: FileAccess = FileAccess.open(dir.path_join(file_name), FileAccess.WRITE)
	assert_not_null(file, "nao foi possivel gravar a fixture " + file_name)
	if file == null:
		return
	file.store_string(source)
	file.close()

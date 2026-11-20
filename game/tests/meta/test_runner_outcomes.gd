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
## Erro de script em tempo de execução: chamada de método inexistente. Linha 5 é a do call.
const RUNTIME_ERROR_SRC: String = "extends TestCase\n\nfunc _provoca() -> void:\n\tvar obj: Object = Object.new()\n\tobj.call(\"metodo_que_nao_existe\")\n\tobj.free()\n\nfunc test_erro_de_runtime() -> void:\n\t_provoca()\n\tassert_true(true, \"o teste continua apos o erro\")\n"
## Declarações de erro esperado: script (consumido), engine (consumido), engine não declarado (nota)
## e expectativa que não acontece (falha).
const EXPECTATIONS_SRC: String = "extends TestCase\n\nfunc _provoca() -> void:\n\tvar obj: Object = Object.new()\n\tobj.call(\"metodo_que_nao_existe\")\n\tobj.free()\n\nfunc test_erro_de_script_esperado() -> void:\n\texpect_script_error(\"metodo_que_nao_existe\")\n\t_provoca()\n\tassert_true(true, \"continua apos o erro esperado\")\n\nfunc test_erro_de_engine_esperado() -> void:\n\texpect_engine_error(\"erro declarado de proposito\")\n\tpush_error(\"erro declarado de proposito\")\n\tassert_true(true)\n\nfunc test_erro_de_engine_nao_declarado() -> void:\n\tpush_error(\"erro nao declarado\")\n\tassert_true(true)\n\nfunc test_expectativa_nao_cumprida() -> void:\n\texpect_engine_error(\"nunca_acontece\")\n\tassert_true(true)\n"


## Teste sem nenhum assert reprova (R1-10); o irmão com assert passa.
const ZERO_ASSERT_SRC: String = "extends TestCase\n\nfunc test_sem_assert() -> void:\n\tpass\n\nfunc test_com_assert() -> void:\n\tassert_true(true)\n"
## Await que nunca termina: o watchdog reprova por frames sem progresso (R1-10).
const STALL_SRC: String = "extends TestCase\n\nfunc test_parado() -> void:\n\tvar no: Node = Node.new()\n\tawait no.tree_exited\n"
## Progresso normal, mas tempo de parede acima do teto: a rede de segurança reprova (R1-10).
const WALL_SRC: String = "extends TestCase\n\nfunc test_lento() -> void:\n\tOS.delay_msec(2100)\n\tawait wait_physics_frames(3)\n\tassert_true(true)\n"


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


func test_erro_de_script_em_tempo_de_execucao_reprova_o_teste() -> void:
	var dir: String = tmp_dir()
	_write(dir, "test_erro_runtime.gd", RUNTIME_ERROR_SRC)
	var outcome: RunOutcome = _run(dir, PackedStringArray())
	assert_eq(outcome.code, 1, "codigo de saida do runner")
	assert_true(outcome.output.contains("FAIL  test_erro_runtime.gd::test_erro_de_runtime"), "o teste vira FAIL mesmo com o assert passando")
	assert_true(outcome.output.contains("erro de script em tempo de execucao"), "a falha diz que é erro de script")
	assert_true(outcome.output.contains("metodo_que_nao_existe"), "a mensagem do erro aparece")
	assert_true(outcome.output.contains("test_erro_runtime.gd:5"), "arquivo:linha do erro aparece")
	assert_true(outcome.output.contains("RESULTADO: REPROVADO"), "resultado REPROVADO")


func test_declaracoes_de_erro_esperado_no_runner() -> void:
	var dir: String = tmp_dir()
	_write(dir, "test_expectativas.gd", EXPECTATIONS_SRC)
	var outcome: RunOutcome = _run(dir, PackedStringArray())
	assert_eq(outcome.code, 1, "codigo de saida: só a expectativa não cumprida reprova")
	assert_true(outcome.output.contains("PASS  test_expectativas.gd::test_erro_de_script_esperado"), "erro de script declarado não reprova")
	assert_true(outcome.output.contains("PASS  test_expectativas.gd::test_erro_de_engine_esperado"), "erro de engine declarado não reprova")
	assert_true(outcome.output.contains("PASS  test_expectativas.gd::test_erro_de_engine_nao_declarado"), "erro de engine não declarado não reprova")
	assert_true(outcome.output.contains("nota: erro do engine nao declarado"), "erro de engine não declarado vira nota")
	assert_false(outcome.output.contains("FAIL  test_expectativas.gd::test_erro_de_script_esperado"), "o teste de script esperado não falha")
	assert_true(outcome.output.contains("FAIL  test_expectativas.gd::test_expectativa_nao_cumprida"), "expectativa não cumprida reprova")
	assert_true(outcome.output.contains("erro de engine esperado nao ocorreu: 'nunca_acontece'"), "a falha diz qual expectativa faltou")


func test_teste_sem_assert_reprova_e_watchdog_reprova_por_frames() -> void:
	var dir: String = tmp_dir()
	_write(dir, "test_a_zero.gd", ZERO_ASSERT_SRC)
	_write(dir, "test_b_parado.gd", STALL_SRC)
	var outcome: RunOutcome = _run(dir, PackedStringArray(["--stall-frames=30"]))
	assert_eq(outcome.code, 1, "codigo de saida do runner")
	assert_true(outcome.output.contains("PASS  test_a_zero.gd::test_com_assert"), "o teste com assert passa")
	assert_true(outcome.output.contains("FAIL  test_a_zero.gd::test_sem_assert"), "teste sem assert reprova")
	assert_true(outcome.output.contains("teste sem nenhum assert"), "a mensagem diz que nao ha assert")
	assert_true(outcome.output.contains("FAIL  test_b_parado.gd::test_parado"), "await parado reprova")
	assert_true(outcome.output.contains("sem progresso por"), "o watchdog mede frames sem progresso")
	assert_true(outcome.output.contains("RESULTADO: REPROVADO"), "resultado REPROVADO")


func test_teto_de_tempo_de_parede_reprova_mesmo_com_progresso() -> void:
	var dir: String = tmp_dir()
	_write(dir, "test_c_lento.gd", WALL_SRC)
	var outcome: RunOutcome = _run(dir, PackedStringArray(["--wall-ms=1500"]))
	assert_eq(outcome.code, 1, "codigo de saida do runner")
	assert_true(outcome.output.contains("FAIL  test_c_lento.gd::test_lento"), "o teste lento reprova")
	assert_true(outcome.output.contains("teto de tempo de parede"), "a mensagem diz que o teto foi excedido")


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

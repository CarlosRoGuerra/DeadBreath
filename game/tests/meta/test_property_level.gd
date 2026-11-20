extends TestCase
## Nível property (F1-010, decisão do Director): com --level=property o runner descobre tests/property/
## recursivamente; a execução padrão (sem --level) não descobre. Confere os dois lados com subprocessos.
## A sonda é tests/property/nivel/test_property_probe.gd (subpasta de propósito, para provar a recursão).

const PROBE_LABEL: String = "property/nivel/test_property_probe.gd::test_property_probe_descoberto"


class RunOutcome:
	extends RefCounted
	var code: int = -999
	var output: String = ""


func test_nivel_property_descobre_a_sonda_recursivamente() -> void:
	var outcome: RunOutcome = _run(PackedStringArray(["--level=property", "--filter=property_probe"]))
	assert_eq(outcome.code, 0, "codigo de saida com --level=property")
	assert_true(outcome.output.contains("PASS  " + PROBE_LABEL), "a sonda roda com --level=property")
	assert_true(outcome.output.contains("RESULTADO: APROVADO"), "resultado APROVADO")


func test_execucao_padrao_nao_descobre_o_nivel_property() -> void:
	var outcome: RunOutcome = _run(PackedStringArray(["--filter=property_probe"]))
	assert_eq(outcome.code, 1, "sem --level a sonda não roda: zero testes = código 1")
	assert_false(outcome.output.contains("PASS  " + PROBE_LABEL), "a sonda não aparece na execução padrão")
	assert_true(outcome.output.contains("total=0"), "nenhum teste executado na execução padrão")


## Executa o runner como subprocesso com os argumentos de usuário dados.
func _run(user_args: PackedStringArray) -> RunOutcome:
	var args: PackedStringArray = PackedStringArray([
		"--headless",
		"--path", ProjectSettings.globalize_path("res://"),
		"-s", "res://tests/run_all.gd",
		"--",
	])
	for arg: String in user_args:
		args.append(arg)
	var lines: Array = []
	var outcome: RunOutcome = RunOutcome.new()
	outcome.code = OS.execute(OS.get_executable_path(), args, lines, true)
	var text: String = ""
	for line: Variant in lines:
		text += str(line) + "\n"
	outcome.output = text
	return outcome

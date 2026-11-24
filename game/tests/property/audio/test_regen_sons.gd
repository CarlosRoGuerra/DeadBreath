extends TestCase
## F4-006a (property): tools/audio/check_regen.py passa para os conjuntos world (F3-003a + falas F4-006a) e music (F4-006a).
## Cada um gera duas vezes em pastas temporárias e compara bit a bit com o commitado e entre si. Usa o Python do sistema
## (python no PATH). A geração do conjunto world leva cerca de 20 s, por isso fica fora da suíte padrão.
## Autor: Audio Engineer (F4-006a).

const SCRIPT_REL: String = "../tools/audio/check_regen.py"


func _check_regen(set_name: String) -> int:
	var script_path: String = ProjectSettings.globalize_path("res://").path_join(SCRIPT_REL).simplify_path()
	var output: Array = []
	var code: int = OS.execute("python", PackedStringArray([script_path, "--set", set_name]), output, true)
	if code != 0:
		note("saída de check_regen --set %s (código %d): %s" % [set_name, code, str(output)])
	return code


func test_check_regen_world_passa_bit_a_bit() -> void:
	assert_eq(_check_regen("world"), 0, "check_regen --set world sai com 0 (PASS)")


func test_check_regen_music_passa_bit_a_bit() -> void:
	assert_eq(_check_regen("music"), 0, "check_regen --set music sai com 0 (PASS)")

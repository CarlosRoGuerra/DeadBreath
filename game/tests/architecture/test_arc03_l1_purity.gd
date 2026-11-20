extends TestCase
## ARC-03 (TEST_PLAN §2.10): scripts em sim/ (L1) são classes puras.
## Não usam get_node, get_tree nem $; não referenciam Node, SceneTree nem autoloads;
## não estendem Node. Verificação: varredura de texto (identificadores fora de comentários
## e strings) e reflexão (GDScript.get_instance_base_type()).
## Diretório vazio ou inexistente: passa por vacuidade, e a saída diz isso.

const SIM_DIR: String = "res://sim/"
const ALLOWED_BASES: Array[String] = ["RefCounted", "Resource", "Object"]
const FORBIDDEN_CORE: String = "\\b(get_node|get_node_or_null|get_tree|Node|SceneTree)\\b|\\$"


func test_sim_sem_get_node_get_tree_node_ou_autoloads() -> void:
	var files: PackedStringArray = SourceScan.list_gd_files(SIM_DIR)
	note("arquivos varridos em %s: %d%s" % [SIM_DIR, files.size(),
		" (pasta vazia ou inexistente: passa por vacuidade)" if files.is_empty() else ""])
	var pattern: String = FORBIDDEN_CORE
	var autoloads: PackedStringArray = SourceScan.autoload_names()
	if autoloads.is_empty():
		note("nenhum autoload em project.godot: verificacao de autoload nao aplicavel")
	else:
		pattern += "|\\b(" + "|".join(autoloads) + ")\\b"
	var violations: PackedStringArray = PackedStringArray()
	for path: String in files:
		var code: String = SourceScan.code_of(SourceScan.read(path), true)
		for hit: String in SourceScan.find_all(code, pattern):
			violations.append("%s %s" % [path, hit])
	assert_eq(violations.size(), 0, "violacoes de ARC-03: " + "; ".join(violations))


func test_sim_estende_apenas_classes_nao_node() -> void:
	var files: PackedStringArray = SourceScan.list_gd_files(SIM_DIR)
	note("scripts de L1 verificados por reflexao: %d%s" % [files.size(),
		" (pasta vazia ou inexistente: passa por vacuidade)" if files.is_empty() else ""])
	var bad: PackedStringArray = PackedStringArray()
	for path: String in files:
		var test_script: GDScript = ResourceLoader.load(path, "GDScript", ResourceLoader.CACHE_MODE_REUSE) as GDScript
		if test_script == null or not test_script.can_instantiate():
			bad.append(path + " (nao compila)")
			continue
		var base: String = str(test_script.get_instance_base_type())
		if not ALLOWED_BASES.has(base):
			bad.append("%s estende '%s'" % [path, base])
	assert_eq(bad.size(), 0, "L1 deve estender apenas RefCounted, Resource ou Object: " + "; ".join(bad))

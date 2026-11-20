extends TestCase
## ARC-03 (TEST_PLAN §2.10): scripts em sim/ (L1) são classes puras.
## Regras (L1Rules, architecture/l1_rules.gd): sem Node, SceneTree, get_node, get_tree, $; sem autoloads;
## sem acesso dinâmico ao scene tree (get_main_loop), sem ClassDB, sem call/callv/call_deferred,
## sem get(...) com string, sem load/preload (R1-11, F1-010). Não estendem Node.
## Verificação: varredura de texto e reflexão (GDScript.get_instance_base_type()).
## Diretório vazio ou inexistente: passa por vacuidade, e a saída diz isso.
## O meta-teste meta/test_arc03_regras_dinamicas.gd injeta cada violação e confere que ela é pega.

const SIM_DIR: String = "res://sim/"
const ALLOWED_BASES: Array[String] = ["RefCounted", "Resource", "Object"]


func test_sim_sem_dependencias_de_cena_dinamicas_ou_autoloads() -> void:
	var files: PackedStringArray = SourceScan.list_gd_files(SIM_DIR)
	note("arquivos varridos em %s: %d%s" % [SIM_DIR, files.size(),
		" (pasta vazia ou inexistente: passa por vacuidade)" if files.is_empty() else ""])
	var autoloads: PackedStringArray = SourceScan.autoload_names()
	if autoloads.is_empty():
		note("nenhum autoload em project.godot: verificacao de autoload nao aplicavel")
	var violations: PackedStringArray = PackedStringArray()
	for path: String in files:
		violations.append_array(L1Rules.scan(path, SourceScan.read(path), autoloads))
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

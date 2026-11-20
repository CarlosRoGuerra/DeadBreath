extends TestCase
## Verifica os detectores dos testes de arquitetura contra casos conhecidos (F1-005):
## violações reais têm de ser achadas (com número de linha); comentários e strings não
## contam como código, exceto onde a regra olha strings (caminhos res://<camada>/ e o grupo "player").
## Sem isso, uma varredura quebrada passaria por vacuidade sem ninguém perceber.


func test_comentarios_e_strings_nao_contam_como_codigo() -> void:
	var src: String = "extends RefCounted\n# get_node aqui\nvar s := \"get_tree() Node\"\n"
	var code: String = SourceScan.code_of(src, true)
	assert_eq(SourceScan.find_all(code, "\\bget_node\\b").size(), 0, "get_node em comentário não conta")
	assert_eq(SourceScan.find_all(code, "\\bget_tree\\b").size(), 0, "get_tree em string não conta")
	assert_eq(SourceScan.find_all(code, "\\bNode\\b").size(), 0, "Node em string não conta")


func test_violacao_real_e_achada_com_numero_de_linha() -> void:
	var src: String = "extends RefCounted\nfunc f() -> void:\n\tvar n := get_node(\"x\")\n"
	var hits: PackedStringArray = SourceScan.find_all(SourceScan.code_of(src, true), "\\bget_node\\b")
	assert_eq(hits.size(), 1, "uma ocorrência de get_node")
	if hits.size() == 1:
		assert_true(hits[0].begins_with("linha 3:"), "a linha reportada é a 3 (obtido: %s)" % hits[0])


func test_caminho_de_camada_so_aparece_com_strings_mantidas() -> void:
	var src: String = "const SIM_PATH := \"res://sim/foo.gd\"\n"
	assert_eq(SourceScan.find_all(SourceScan.code_of(src, false), "res://sim/").size(), 1, "caminho em string é achado")
	assert_eq(SourceScan.find_all(SourceScan.code_of(src, true), "res://sim/").size(), 0, "caminho em string some com strings apagadas")


func test_class_name_declarado_e_extraido() -> void:
	var src: String = "## doc\nclass_name Foo\nextends RefCounted\n# class_name Bar\n"
	var names: PackedStringArray = SourceScan.class_names_declared(SourceScan.code_of(src, false))
	assert_eq(names.size(), 1, "só a declaração real conta")
	assert_true(names.has("Foo"), "Foo é extraído")
	assert_false(names.has("Bar"), "class_name em comentário não conta")


func test_regras_do_firewall_pegam_casos_proibidos() -> void:
	var rule_script: GDScript = ResourceLoader.load("res://tests/architecture/test_arc01_perception_firewall.gd", "GDScript", ResourceLoader.CACHE_MODE_REUSE) as GDScript
	assert_not_null(rule_script, "script de ARC-01 carrega")
	if rule_script == null:
		return
	var constants: Dictionary = rule_script.get_script_constant_map()
	var identifiers: String = str(constants.get("FORBIDDEN_IDENTIFIERS", ""))
	var literals: String = str(constants.get("FORBIDDEN_LITERALS", ""))
	assert_false(identifiers.is_empty(), "constante FORBIDDEN_IDENTIFIERS existe")
	assert_eq(SourceScan.find_all(SourceScan.code_of("var p: PlayerRoot\n", true), identifiers).size(), 1, "PlayerRoot como tipo é proibido")
	assert_eq(SourceScan.find_all(SourceScan.code_of("var n: NoiseEvent\n", true), identifiers).size(), 1, "NoiseEvent é proibido")
	assert_eq(SourceScan.find_all(SourceScan.code_of("add_to_group(\"player\")\n", false), literals).size(), 1, "grupo \"player\" é proibido")
	assert_eq(SourceScan.find_all(SourceScan.code_of("var p := $\"../Player\"\n", false), literals).size(), 1, "caminho de nó com Player é proibido")
	assert_eq(SourceScan.find_all(SourceScan.code_of("var x := 1 # PlayerRoot em comentario\n", true), identifiers).size(), 0, "PlayerRoot em comentário é permitido")

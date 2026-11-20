extends TestCase
## Contexto do runner (F1-005, requisito do TEST_PLAN §4): com `-s`, os autoloads registrados em
## project.godot estão na árvore, e um script carregado pelo runner enxerga os identificadores globais.


func test_autoloads_registrados_estao_na_arvore() -> void:
	var names: PackedStringArray = SourceScan.autoload_names()
	note("autoloads registrados em project.godot: %d (%s)" % [names.size(), ", ".join(names)])
	if names.is_empty():
		note("nenhum autoload registrado: teste passa por vacuidade")
	var missing: PackedStringArray = PackedStringArray()
	for autoload_name: String in names:
		if get_tree().root.get_node_or_null(NodePath(autoload_name)) == null:
			missing.append(autoload_name)
	assert_eq(missing.size(), 0, "autoloads ausentes na arvore: " + ", ".join(missing))


func test_identificador_global_visivel_em_script_carregado() -> void:
	var names: PackedStringArray = SourceScan.autoload_names()
	if names.is_empty():
		note("nenhum autoload registrado: teste passa por vacuidade")
		return
	var first: String = names[0]
	var path: String = tmp_dir().path_join("uses_autoload.gd")
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	assert_not_null(file, "nao foi possivel gravar o script de teste")
	if file == null:
		return
	file.store_string("extends RefCounted\n\nfunc probe() -> Variant:\n\treturn %s\n" % first)
	file.close()
	var test_script: GDScript = ResourceLoader.load(path, "GDScript", ResourceLoader.CACHE_MODE_REUSE) as GDScript
	assert_not_null(test_script, "script gerado nao compila: referencia a '%s'" % first)
	if test_script == null or not test_script.can_instantiate():
		return
	var instance: RefCounted = test_script.new() as RefCounted
	assert_not_null(instance, "script gerado nao instancia")
	if instance == null:
		return
	var value: Variant = instance.call("probe")
	assert_not_null(value, "o identificador global '%s' nao esta visivel em script carregado" % first)

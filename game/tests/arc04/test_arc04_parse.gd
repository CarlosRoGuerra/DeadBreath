extends TestCase
## ARC-04 (TEST_PLAN §2.10): todos os scripts de game/ compilam, com warnings de tipagem
## (untyped_declaration, unsafe_method_access, unsafe_property_access) tratados como erro.
##
## Verificação em um único processo: ResourceLoader.load(..., CACHE_MODE_REUSE) e
## can_instantiate(). Um script com erro de parse ou com warning-como-erro fica sem
## instanciar. Não usar CACHE_MODE_IGNORE aqui: recarregar o próprio script em execução
## causa "Internal script error" e derruba o processo (verificado em F1-005).
## (`--check-only` por arquivo não serve: não registra autoloads e falha em qualquer
## script que os use.) As linhas "SCRIPT ERROR" do console são checadas por
## tools/run_tests.ps1, que trata qualquer uma delas como falha.


func test_todos_os_scripts_compilam() -> void:
	var files: PackedStringArray = SourceScan.list_gd_files("res://")
	note("scripts verificados em res://: %d" % files.size())
	assert_true(files.size() > 0, "nenhum script .gd encontrado em res://")
	var broken: PackedStringArray = PackedStringArray()
	for path: String in files:
		var test_script: GDScript = ResourceLoader.load(path, "GDScript", ResourceLoader.CACHE_MODE_REUSE) as GDScript
		if test_script == null or not test_script.can_instantiate():
			broken.append(path)
	assert_eq(broken.size(), 0, "scripts que nao compilam: " + ", ".join(broken))

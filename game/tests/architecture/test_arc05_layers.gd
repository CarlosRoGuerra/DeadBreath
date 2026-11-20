extends TestCase
## ARC-05 (TEST_PLAN §2.10, SYSTEM_ARCHITECTURE §2): dependência só para baixo.
##   autoload/ e core/ não referenciam sim/, components/ ou presentation/;
##   sim/ não referencia components/ nem presentation/;
##   components/ não referencia presentation/.
## Verificação: caminhos res://<camada>/ (código com strings, sem comentários) e nomes
## declarados com class_name em cada camada (identificadores fora de strings e comentários).
## Pastas vazias ou inexistentes: passam por vacuidade, e a saída diz isso.

const LAYER_DIRS: Dictionary = {
	"autoload": "res://autoload/",
	"core": "res://core/",
	"sim": "res://sim/",
	"components": "res://components/",
	"presentation": "res://presentation/",
}
## Camada de origem -> camadas que ela não pode referenciar.
const FORBIDDEN_TARGETS: Dictionary = {
	"autoload": ["sim", "components", "presentation"],
	"core": ["sim", "components", "presentation"],
	"sim": ["components", "presentation"],
	"components": ["presentation"],
}


func test_dependencias_so_para_baixo() -> void:
	var class_names_by_layer: Dictionary = {}
	for layer: String in LAYER_DIRS.keys():
		var names: PackedStringArray = PackedStringArray()
		var layer_dir: String = LAYER_DIRS[layer]
		for path: String in SourceScan.list_gd_files(layer_dir):
			names.append_array(SourceScan.class_names_declared(SourceScan.code_of(SourceScan.read(path), false)))
		class_names_by_layer[layer] = names

	var scanned: int = 0
	var violations: PackedStringArray = PackedStringArray()
	for source_layer: String in FORBIDDEN_TARGETS.keys():
		var source_dir: String = LAYER_DIRS[source_layer]
		var files: PackedStringArray = SourceScan.list_gd_files(source_dir)
		scanned += files.size()
		for path: String in files:
			var raw: String = SourceScan.read(path)
			var code_with_strings: String = SourceScan.code_of(raw, false)
			var code_identifiers: String = SourceScan.code_of(raw, true)
			var targets: Array = FORBIDDEN_TARGETS[source_layer]
			for target_layer: String in targets:
				var target_dir: String = LAYER_DIRS[target_layer]
				for path_hit: String in SourceScan.find_all(code_with_strings, target_dir):
					violations.append("%s referencia %s (%s)" % [path, target_dir, path_hit])
				var target_names: PackedStringArray = class_names_by_layer[target_layer]
				for class_label: String in target_names:
					for name_hit: String in SourceScan.find_all(code_identifiers, "\\b" + class_label + "\\b"):
						violations.append("%s usa a classe '%s' da camada %s (%s)" % [path, class_label, target_layer, name_hit])

	note("arquivos varridos nas camadas de origem: %d%s" % [scanned,
		" (pastas vazias ou inexistentes: passa por vacuidade)" if scanned == 0 else ""])
	assert_eq(violations.size(), 0, "violacoes de ARC-05: " + "; ".join(violations))

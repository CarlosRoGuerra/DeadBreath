extends TestCase
## ARC-06 (TEST_PLAN §2.10, PLR-INV-1, SYSTEM_ARCHITECTURE §1 princípio 3): os componentes do jogador
## (components/player/) não referenciam uns aos outros. Só o mediador (o script que declara
## class_name PlayerRoot) conhece os componentes; referências ao mediador a partir de outro componente
## também são violação.
## Componente = script cuja classe base é Node (ou derivada). Helpers RefCounted e configurações
## Resource (ex.: MotorInput, PlayerMotorConfig) não são componentes e podem ser usados por eles.
## Verificação: nomes declarados com class_name dos componentes (identificadores fora de strings e
## comentários) e caminhos de componentes em strings (código com strings).
## Pasta vazia ou inexistente, ou sem mediador: passa por vacuidade, e a saída diz isso.

const PLAYER_DIR: String = "res://components/player/"
const MEDIATOR_CLASS: String = "PlayerRoot"


func test_componentes_do_jogador_nao_se_referenciam() -> void:
	var files: PackedStringArray = SourceScan.list_gd_files(PLAYER_DIR)
	var mediator_path: String = ""
	var component_paths: PackedStringArray = PackedStringArray()
	var class_names_of: Dictionary = {}
	for path: String in files:
		var names: PackedStringArray = SourceScan.class_names_declared(SourceScan.code_of(SourceScan.read(path), false))
		if names.has(MEDIATOR_CLASS):
			mediator_path = path
		if _is_component(path):
			component_paths.append(path)
			class_names_of[path] = names
	note("scripts em components/player: %d; componentes (base Node): %d; mediador: %s%s" % [files.size(),
		component_paths.size(),
		mediator_path if not mediator_path.is_empty() else "(nenhum)",
		" (pasta vazia ou inexistente: passa por vacuidade)" if files.is_empty() else ""])

	var violations: PackedStringArray = PackedStringArray()
	for path: String in files:
		if path == mediator_path:
			continue
		var raw: String = SourceScan.read(path)
		var code_with_strings: String = SourceScan.code_of(raw, false)
		var code_identifiers: String = SourceScan.code_of(raw, true)
		for other: String in component_paths:
			if other == path:
				continue
			var other_names: PackedStringArray = class_names_of[other]
			for class_label: String in other_names:
				for name_hit: String in SourceScan.find_all(code_identifiers, "\\b" + class_label + "\\b"):
					violations.append("%s usa a classe '%s' do componente %s (%s)" % [path, class_label, other, name_hit])
			if code_with_strings.contains(other):
				violations.append("%s referencia o caminho do componente %s" % [path, other])

	assert_eq(violations.size(), 0, "violacoes de ARC-06: " + "; ".join(violations))


## Verdadeiro se a classe base do script for Node ou derivada. Script que não compila conta como
## componente por precaução (ARC-04 reprova o arquivo).
func _is_component(path: String) -> bool:
	var test_script: GDScript = ResourceLoader.load(path, "GDScript", ResourceLoader.CACHE_MODE_REUSE) as GDScript
	if test_script == null or not test_script.can_instantiate():
		return true
	var base: String = str(test_script.get_instance_base_type())
	return base == "Node" or ClassDB.is_parent_class(base, "Node")

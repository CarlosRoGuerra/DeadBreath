extends TestCase
## ARC-06 (TEST_PLAN §2.10, PLR-INV-1, SYSTEM_ARCHITECTURE §1 princípio 3): os scripts de
## componentes do jogador (components/player/) não referenciam uns aos outros. Só o mediador
## (o script que declara class_name PlayerRoot) conhece os componentes; referências ao mediador
## a partir de outro componente também são violação.
## Verificação: nomes declarados com class_name em outros scripts da pasta (identificadores fora
## de strings e comentários) e caminhos res://components/player/ (código com strings).
## Pasta vazia ou inexistente, ou sem mediador: passa por vacuidade, e a saída diz isso.

const PLAYER_DIR: String = "res://components/player/"
const MEDIATOR_CLASS: String = "PlayerRoot"


func test_componentes_do_jogador_nao_se_referenciam() -> void:
	var files: PackedStringArray = SourceScan.list_gd_files(PLAYER_DIR)
	var mediator_path: String = ""
	var declared: Dictionary = {}
	for path: String in files:
		var names: PackedStringArray = SourceScan.class_names_declared(SourceScan.code_of(SourceScan.read(path), false))
		declared[path] = names
		if names.has(MEDIATOR_CLASS):
			mediator_path = path
	note("componentes do jogador varridos: %d; mediador: %s%s" % [files.size(),
		mediator_path if not mediator_path.is_empty() else "(nenhum)",
		" (pasta vazia ou inexistente: passa por vacuidade)" if files.is_empty() else ""])

	var violations: PackedStringArray = PackedStringArray()
	for path: String in files:
		if path == mediator_path:
			continue
		var raw: String = SourceScan.read(path)
		var code_with_strings: String = SourceScan.code_of(raw, false)
		var code_identifiers: String = SourceScan.code_of(raw, true)
		for other: String in files:
			if other == path:
				continue
			var other_names: PackedStringArray = declared[other]
			for class_label: String in other_names:
				for name_hit: String in SourceScan.find_all(code_identifiers, "\\b" + class_label + "\\b"):
					violations.append("%s usa a classe '%s' de %s (%s)" % [path, class_label, other, name_hit])
		for path_hit: String in SourceScan.find_all(code_with_strings, PLAYER_DIR):
			violations.append("%s referencia %s (%s)" % [path, PLAYER_DIR, path_hit])

	assert_eq(violations.size(), 0, "violacoes de ARC-06: " + "; ".join(violations))

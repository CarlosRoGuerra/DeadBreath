extends TestCase
## ARC-01 (TEST_PLAN §2.10, SYSTEM_ARCHITECTURE §5): firewall de percepção por varredura de texto.
## Em sim/ai/, sim/difficulty/, components/enemy/ e components/perception/ (exceto
## vision_sensor.gd) são proibidas referências a PlayerRoot, PlayerMotor, PhysiologyComponent,
## PlayerThreatMonitor, PlayerHeardNoise, NoiseEvent, ao grupo "player" e a caminhos com Player.
## Identificadores Player* também são proibidos (cobre as classes do jogador).
## A varredura não pega todo acesso indireto: o teste comportamental AI-06 é a rede final. Desde a revisão F4-010
## (R4-04, Director), test_firewall_sem_acesso_indireto fecha as burlas mostradas pelo revisor: identificadores e
## literais "player" em minúsculo, grupos fora da lista, autoloads além de Log e do EventBus só emitindo, e acesso à
## raiz da árvore, ao viewport e a caminhos absolutos.
## Pastas vazias ou inexistentes: passam por vacuidade, e a saída diz isso.

const SCAN_DIRS: Array[String] = [
	"res://sim/ai/",
	"res://sim/difficulty/",
	"res://components/enemy/",
	"res://components/perception/",
]
const EXEMPT_FILES: Array[String] = [
	"res://components/perception/vision_sensor.gd",
]
## Identificadores de código (strings e comentários removidos).
const FORBIDDEN_IDENTIFIERS: String = "\\b(PlayerRoot|PlayerMotor|PhysiologyComponent|PlayerThreatMonitor|PlayerHeardNoise|NoiseEvent)\\b|\\bPlayer[A-Za-z0-9_]*"
## Literais de string e caminhos de nó (comentários removidos, strings mantidas).
const FORBIDDEN_LITERALS: String = "[\"']player[\"']|[\"'][^\"'\\n]*Player[^\"'\\n]*[\"']|\\$[^\\s]*Player"

## R4-04: identificadores que começam com "player" (minúsculo). Só os sinais de captura que a IA EMITE são permitidos.
const LOWER_PLAYER_IDENTIFIER: String = "\\bplayer[A-Za-z0-9_]*"
const ALLOWED_LOWER_PLAYER: Array[String] = ["player_caught", "player_captured"]
## R4-04: literal de string que contém "player" em qualquer caixa.
const ANY_CASE_PLAYER_LITERAL: String = "[\"'][^\"'\\n]*[Pp][Ll][Aa][Yy][Ee][Rr][^\"'\\n]*[\"']"
## R4-04: grupos que a IA pode consultar ou usar. Literal ou constante do próprio arquivo com um destes valores.
const ALLOWED_GROUPS: Array[String] = ["perceivable", "patrol_point", "hideable", "enemy", "hearing_sensor"]
const GROUP_CALL: String = "\\b(get_nodes_in_group|get_first_node_in_group|is_in_group|add_to_group|call_group|has_group)\\(\\s*([^),]+)"
const CONST_STRING: String = "const\\s+([A-Za-z_][A-Za-z0-9_]*)\\s*(?::\\s*[A-Za-z_][A-Za-z0-9_]*)?\\s*=\\s*&?\"([^\"]*)\""
## R4-04: autoloads proibidos e uso do EventBus que não seja emitir.
const FORBIDDEN_AUTOLOADS: String = "\\b(GameState|Settings|SaveService)\\b"
const EVENT_BUS_USE: String = "\\bEventBus\\.[A-Za-z_][A-Za-z0-9_]*(\\.[A-Za-z_][A-Za-z0-9_]*)?"
## R4-04: raiz da árvore, viewport e caminhos absolutos. A sonda de luz percorre a árvore só para achar luzes.
const TREE_ESCAPE: String = "\\.root\\b|\\bget_viewport\\(|get_node(_or_null)?\\(\\s*&?\"/"
const TREE_ESCAPE_EXEMPT: Array[String] = ["res://components/perception/light_exposure_probe.gd"]


func test_firewall_sem_referencias_ao_jogador() -> void:
	var files: PackedStringArray = PackedStringArray()
	for dir_path: String in SCAN_DIRS:
		for path: String in SourceScan.list_gd_files(dir_path):
			if not EXEMPT_FILES.has(path):
				files.append(path)
	note("arquivos varridos pelo firewall: %d%s" % [files.size(),
		" (pastas-alvo vazias ou inexistentes: passa por vacuidade)" if files.is_empty() else ""])
	var violations: PackedStringArray = PackedStringArray()
	for path: String in files:
		var raw: String = SourceScan.read(path)
		for hit: String in SourceScan.find_all(SourceScan.code_of(raw, true), FORBIDDEN_IDENTIFIERS):
			violations.append("%s %s" % [path, hit])
		for hit: String in SourceScan.find_all(SourceScan.code_of(raw, false), FORBIDDEN_LITERALS):
			violations.append("%s %s" % [path, hit])
	assert_eq(violations.size(), 0, "violacoes de ARC-01: " + "; ".join(violations))


## R4-04 (revisão F4-010): fecha as burlas que a varredura por nome não pegava.
func test_firewall_sem_acesso_indireto() -> void:
	var violations: PackedStringArray = PackedStringArray()
	var scanned: int = 0
	for dir_path: String in SCAN_DIRS:
		for path: String in SourceScan.list_gd_files(dir_path):
			if EXEMPT_FILES.has(path):
				continue
			scanned += 1
			var raw: String = SourceScan.read(path)
			var code: String = SourceScan.code_of(raw, true)
			var with_strings: String = SourceScan.code_of(raw, false)
			for found: RegExMatch in _matches(code, LOWER_PLAYER_IDENTIFIER):
				if not ALLOWED_LOWER_PLAYER.has(found.get_string()):
					violations.append("%s identificador '%s'" % [path, found.get_string()])
			for hit: String in SourceScan.find_all(with_strings, ANY_CASE_PLAYER_LITERAL):
				violations.append("%s literal com player: %s" % [path, hit])
			violations.append_array(_group_violations(path, with_strings))
			for hit: String in SourceScan.find_all(code, FORBIDDEN_AUTOLOADS):
				violations.append("%s autoload proibido: %s" % [path, hit])
			for found: RegExMatch in _matches(code, EVENT_BUS_USE):
				if not found.get_string().ends_with(".emit") and not _emits(code, found):
					violations.append("%s EventBus só pode emitir: %s" % [path, found.get_string()])
			if not TREE_ESCAPE_EXEMPT.has(path):
				for hit: String in SourceScan.find_all(with_strings, TREE_ESCAPE):
					violations.append("%s acesso fora do escopo da árvore: %s" % [path, hit])
	note("arquivos varridos (acesso indireto): %d" % scanned)
	assert_true(scanned > 0, "a varredura encontrou arquivos")
	assert_eq(violations.size(), 0, "violacoes de ARC-01 (acesso indireto): " + "; ".join(violations))


func _matches(text: String, pattern: String) -> Array[RegExMatch]:
	var regex: RegEx = RegEx.new()
	regex.compile(pattern)
	return regex.search_all(text)


## O uso EventBus.<sinal> é seguido de ".emit(" (forma "EventBus.sinal.emit(...)")?
func _emits(code: String, found: RegExMatch) -> bool:
	return code.substr(found.get_end(), 6) == ".emit("


## Cada chamada de grupo precisa de um literal permitido ou de uma constante do arquivo com valor permitido.
func _group_violations(path: String, with_strings: String) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	var constants: Dictionary = {}
	for found: RegExMatch in _matches(with_strings, CONST_STRING):
		constants[found.get_string(1)] = found.get_string(2)
	for found: RegExMatch in _matches(with_strings, GROUP_CALL):
		var argument: String = found.get_string(2).strip_edges()
		var group: String = ""
		if argument.begins_with("&\"") or argument.begins_with("\""):
			group = argument.trim_prefix("&").trim_prefix("\"").trim_suffix("\"")
		elif constants.has(argument):
			group = str(constants[argument])
		if not ALLOWED_GROUPS.has(group):
			out.append("%s grupo não permitido ou não verificável: %s" % [path, found.get_string()])
	return out


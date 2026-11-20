extends TestCase
## ARC-01 (TEST_PLAN §2.10, SYSTEM_ARCHITECTURE §5): firewall de percepção por varredura de texto.
## Em sim/ai/, sim/difficulty/, components/enemy/ e components/perception/ (exceto
## vision_sensor.gd) são proibidas referências a PlayerRoot, PlayerMotor, PhysiologyComponent,
## PlayerThreatMonitor, PlayerHeardNoise, NoiseEvent, ao grupo "player" e a caminhos com Player.
## Identificadores Player* também são proibidos (cobre as classes do jogador).
## A varredura não pega acesso indireto: isso é papel do teste comportamental AI-06.
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

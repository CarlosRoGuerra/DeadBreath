extends TestCase
## F4-005 (AI-07, ENM-INV-1): a captura não entra no PerceptBatch. Verificação estática do que a área de captura lê e
## do que o controlador faz quando ela dispara: a área não conhece o cérebro nem os percepts; o tratador do sinal só
## emite EventBus.player_captured e o sinal local (nada vai para o lote). O comportamental está em
## tests/integration/enemy/test_enemy_contrato.gd (test_ai07_...). Autor: AI Engineer (F4-005).

const CAPTURE_PATH: String = "res://components/enemy/enemy_capture_area.gd"
const CONTROLLER_PATH: String = "res://components/enemy/enemy_controller.gd"
const FORBIDDEN_IN_CAPTURE: String = "\b(EnemyBrain|PerceptBatch|VisualPercept|HeardNoise|PerceptionMemory|EnemyWorldQuery|perception|percept)\b"


func test_area_de_captura_nao_conhece_o_cerebro_nem_os_percepts() -> void:
	var code: String = SourceScan.code_of(SourceScan.read(CAPTURE_PATH), true)
	var hits: PackedStringArray = SourceScan.find_all(code, FORBIDDEN_IN_CAPTURE)
	assert_eq(hits.size(), 0, "AI-07: a área de captura não toca o cérebro nem os percepts (%s)" % ", ".join(hits))


func test_tratador_da_captura_nao_adiciona_nada_ao_lote() -> void:
	var source: String = SourceScan.code_of(SourceScan.read(CONTROLLER_PATH), true)
	var start: int = source.find("func _on_capture_area_caught()")
	assert_true(start >= 0, "o controlador tem o tratador da captura")
	if start < 0:
		return
	var end: int = source.find("\nfunc ", start + 1)
	var body: String = source.substr(start, end - start if end > start else source.length() - start)
	assert_true(body.find("EventBus.player_captured.emit") >= 0, "repassa para EventBus.player_captured")
	assert_true(body.find("player_caught.emit") >= 0, "emite o sinal local player_caught")
	assert_eq(body.find("_pending_percepts"), -1, "o tratador não mexe na fila de percepts")
	assert_eq(body.find("PerceptBatch"), -1, "o tratador não monta lote")

extends TestCase
## PHY-08 (determinismo), PHY-10 (histerese e permanência mínima) e PHY-11 (invariância a dt), TEST_PLAN §2.2,
## no nível dos modelos. Aqui, as versões curtas (suíte padrão, < 10 s). As versões completas (PHY-08 de 90 s,
## PHY-11 de 60 s, PHY-10 com os sete limiares a 30 s) são varreduras longas e estão em
## tests/property/physiology/. Autor: Physiological Systems Engineer.

const Fx := preload("res://tests/unit/physiology/fixtures/physio_fixture.gd")
const DT: float = 1.0 / 60.0
const DT_PROPERTY: float = 0.1
const DWELL_S: float = 1.0
## Duração da versão curta de PHY-08 (uma fase de sprint com ameaça basta para haver tosse).
const DETERMINISM_SHORT_S: float = 30.0
## Duração da versão curta de PHY-11 (checkpoints de 10 s).
const INVARIANCE_SHORT_S: float = 20.0
## Oscilação de PHY-10 em torno de cada limiar (TEST_PLAN: ±0,02) e sua duração curta.
const WOBBLE: float = 0.02
const OSCILLATION_SHORT_S: float = 10.0
const SEVERITY_TOLERANCE: float = 0.02


func test_phy08_mesmo_rng_e_mesmas_entradas_geram_snapshots_identicos() -> void:
	var result: Array = Fx.determinism_run(808, DETERMINISM_SHORT_S)
	var mismatches: int = result[0]
	var coughs: int = result[1]
	var ticks: int = result[2]
	note("PHY-08 (curto): %d ticks, %d tosse(s) no caminho exercitado pelo RNG, divergências: %d" % [ticks, coughs, mismatches])
	assert_true(coughs >= 1, "o RNG é exercitado: houve tosse na sequência")
	assert_eq(mismatches, 0, "snapshots idênticos em todos os ticks com a mesma semente e as mesmas entradas")


func test_phy10_oscilacao_curta_em_0_20_e_sem_saida_em_0_30_nao_gera_ping_pong() -> void:
	# Casos curtos: [nome, estado inicial, centro, EMA, transições esperadas]. Os demais limiares: ver a versão longa.
	var cases: Array[Array] = [
		["NORMAL→ACCELERATED em 0,20", "NORMAL", 0.20, 0.0, 1],
		["RECOVERING sem saída em 0,30", "RECOVERING", 0.30, 0.2, 0],
	]
	for case: Array in cases:
		var transitions: Array = Fx.oscillate(case[1], case[2], case[3], OSCILLATION_SHORT_S, 2.0, WOBBLE)
		note("PHY-10 %s: %d transição(ões) em %.0f s de oscilação" % [case[0], transitions.size(), OSCILLATION_SHORT_S])
		assert_eq(transitions.size(), case[4], "%s: transições esperadas %d" % [case[0], case[4]])
		_assert_dwell_respected(transitions, case[0])


func _assert_dwell_respected(transitions: Array, label: String) -> void:
	for index: int in range(1, transitions.size()):
		var gap: float = float(transitions[index][0]) - float(transitions[index - 1][0])
		assert_true(gap >= DWELL_S - 0.02, "%s: transições separadas por ≥ 1 s (obtido %.3f)" % [label, gap])


func test_phy10_permanencia_minima_bloqueia_transicao_imediata() -> void:
	var resp: RespiratoryModel = Fx.make_resp(811)
	Fx.set_resp(resp, 0.7, 0.0, "NORMAL", 0.0)
	var idle: PhysiologyInputs = Fx.inputs(0.0, Enums.Gait.IDLE)
	var elapsed: float = 0.0
	var changed_at: float = -1.0
	while elapsed < 2.0:
		resp.tick(DT, idle, 0.0)
		elapsed += DT
		if changed_at < 0.0 and resp.state != Enums.RespiratoryState.NORMAL:
			changed_at = elapsed
	note("PHY-10 permanência: NORMAL com severidade 0,7 mudou em %.3f s (mínimo 1,0 s)" % changed_at)
	assert_true(changed_at >= DWELL_S - 0.02, "nenhuma transição antes de state_min_dwell_s (1 s)")
	assert_true(changed_at <= DWELL_S + 0.05, "a transição acontece logo após 1 s")


func test_phy11_severidade_independe_do_passo_de_tempo() -> void:
	var coarse: Array[float] = Fx.severity_checkpoints(DT_PROPERTY, INVARIANCE_SHORT_S, 10.0)
	var fine: Array[float] = Fx.severity_checkpoints(DT, INVARIANCE_SHORT_S, 10.0)
	var worst: float = 0.0
	for index: int in coarse.size():
		worst = maxf(worst, absf(coarse[index] - fine[index]))
	note("PHY-11 (curto): severidade com dt 0,1 e 1/60 em checkpoints de 10 s, diferença máxima %.5f (limite 0,02)" % worst)
	assert_true(worst <= SEVERITY_TOLERANCE, "diferença ≤ 0,02 entre dt 0,1 e 1/60 (obtida %.5f)" % worst)

extends TestCase
## Versões longas de PHY-08 (determinismo, 90 s com fases de sprint, tosse e repouso) e PHY-11 (invariância a dt,
## 60 s com checkpoints de 10 s), TEST_PLAN §2.2. São varreduras longas: nível property, fora da suíte padrão.
## As versões curtas estão em tests/unit/physiology/test_phy08_10_11_determinismo_histerese_dt.gd.
## Autor: Physiological Systems Engineer.

const Fx := preload("res://tests/unit/physiology/fixtures/physio_fixture.gd")
const DT: float = 1.0 / 60.0
const DT_PROPERTY: float = 0.1
const DETERMINISM_LONG_S: float = 90.0
const INVARIANCE_LONG_S: float = 60.0
const SEVERITY_TOLERANCE: float = 0.02


func test_phy08_longo_mesmo_rng_e_mesmas_entradas_geram_snapshots_identicos() -> void:
	var result: Array = Fx.determinism_run(808, DETERMINISM_LONG_S)
	var mismatches: int = result[0]
	var coughs: int = result[1]
	var ticks: int = result[2]
	note("PHY-08 (longo, 90 s): %d ticks, %d tosses no caminho exercitado pelo RNG, divergências: %d" % [ticks, coughs, mismatches])
	assert_true(coughs >= 1, "o RNG é exercitado: houve tosse na sequência")
	assert_eq(mismatches, 0, "snapshots idênticos em todos os ticks, tick a tick")


func test_phy11_longo_severidade_independe_do_passo_de_tempo() -> void:
	var coarse: Array[float] = Fx.severity_checkpoints(DT_PROPERTY, INVARIANCE_LONG_S, 10.0)
	var fine: Array[float] = Fx.severity_checkpoints(DT, INVARIANCE_LONG_S, 10.0)
	var worst: float = 0.0
	for index: int in coarse.size():
		worst = maxf(worst, absf(coarse[index] - fine[index]))
	note("PHY-11 (longo, 60 s): diferença máxima de severidade entre dt 0,1 e 1/60 em checkpoints de 10 s: %.5f (limite 0,02)" % worst)
	assert_true(worst <= SEVERITY_TOLERANCE, "diferença ≤ 0,02 entre dt 0,1 e 1/60 (obtida %.5f)" % worst)

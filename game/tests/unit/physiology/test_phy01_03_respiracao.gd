extends TestCase
## PHY-01, PHY-02 e PHY-03 (TEST_PLAN §2.2) no nível dos modelos (composição igual à do PhysiologyComponent).
## PHY-01: sprint com tanque cheio até esgotar (≈ 8,3 s) → LABORED ou pior no esgotamento.
## PHY-02: mesmo esforço, estresse 80 → alvo ≥ alvo com estresse 0 + 0,25.
## PHY-03: severidade 0,6 em repouso → < 0,2 em ≤ 25 s. Autor: Physiological Systems Engineer.

const Fx := preload("res://tests/unit/physiology/fixtures/physio_fixture.gd")
const DT: float = 1.0 / 60.0
## Calibração de DATA_STRUCTURES §1.4: a severidade cruza 0,35 em ≈ 5,5 s de sprint.
const LABORED_DOC_S: float = 5.5
const LABORED_TOLERANCE_S: float = 0.5


func test_phy01_sprint_leva_a_laboured_antes_do_esgotamento() -> void:
	var rig: Fx.Rig = Fx.make_rig(101)
	var sprint: PhysiologyInputs = Fx.inputs(Fx.SPRINT_EXERTION, Enums.Gait.SPRINT)
	var ticks: int = 0
	var labored_at: float = -1.0
	while not rig.stamina.exhausted and ticks < 60 * 20:
		rig.step(DT, sprint)
		ticks += 1
		var state: Enums.RespiratoryState = rig.resp.state
		if labored_at < 0.0 and (state == Enums.RespiratoryState.LABORED or state == Enums.RespiratoryState.SYMPTOMATIC):
			labored_at = ticks * DT
	var exhaustion_s: float = ticks * DT
	var at_exhaustion: String = RespiratoryModel.state_name(rig.resp.state)
	note("PHY-01: esgotamento em %.3f s; LABORED em %.3f s (DATA §1.4: ≈ 5,5 s); estado no esgotamento %s, severidade %.3f, EMA %.3f"
		% [exhaustion_s, labored_at, at_exhaustion, rig.resp.symptom_severity, rig.resp.exertion_ema])
	assert_true(rig.stamina.exhausted, "o sprint esgota a stamina")
	assert_true(rig.resp.state == Enums.RespiratoryState.LABORED or rig.resp.state == Enums.RespiratoryState.SYMPTOMATIC,
		"no esgotamento o estado é LABORED ou pior (obtido %s)" % at_exhaustion)
	assert_almost_eq(labored_at, LABORED_DOC_S, LABORED_TOLERANCE_S, "LABORED em ≈ 5,5 s (calibração de DATA §1.4)")


func test_phy02_estresse_80_eleva_o_alvo_em_pelo_menos_0_25() -> void:
	var calm: Fx.Rig = Fx.make_rig(202)
	var stressed: Fx.Rig = Fx.make_rig(202)
	calm.stress.value = 0.0
	stressed.stress.value = 80.0
	var walk: PhysiologyInputs = Fx.inputs(0.9, Enums.Gait.WALK)
	# Com a entrada constante, a severidade chega ao alvo (EMA estável): comparar o regime permanente.
	var steps: int = 20 * 60
	for _i: int in steps:
		calm.resp.tick(DT, walk, 0.0)
		stressed.resp.tick(DT, walk, 80.0)
	var target_calm: float = calm.resp.symptom_severity
	var target_stressed: float = stressed.resp.symptom_severity
	# Os dois rigs têm a mesma EMA a cada tick, então a diferença entre os alvos é exata em qualquer instante
	# (0,4 · 0,8/0,7 · ... = 0,2857), mesmo antes do regime permanente (EMA em 40 s: ≈ 0,894 de 0,9).
	note("PHY-02 (20 s, EMA ainda em subida): alvo com estresse 0 = %.4f; com estresse 80 = %.4f; diferença %.4f (limite 0,25)"
		% [target_calm, target_stressed, target_stressed - target_calm])
	assert_true(target_stressed >= target_calm + 0.25, "alvo com estresse 80 ≥ alvo com estresse 0 + 0,25")
	assert_almost_eq(target_stressed - target_calm, 0.4 * (0.8 - 0.3) / 0.7, 0.002,
		"a diferença é o termo de estresse: 0,4 · (0,8 − 0,3)/0,7 = 0,2857 (DATA §1.4)")


func test_phy03_descanso_leva_0_6_abaixo_de_0_2_em_ate_25_s() -> void:
	var from_clean: float = _seconds_to_recover(0.0)
	var from_sprint: float = _seconds_to_recover(0.857)
	note("PHY-03: severidade 0,6 em repouso → < 0,2 em %.2f s (EMA inicial 0) e %.2f s (EMA inicial 0,857, após sprint longo)"
		% [from_clean, from_sprint])
	assert_true(from_clean <= 25.0, "recuperação em ≤ 25 s com EMA inicial 0 (obtido %.2f s)" % from_clean)
	assert_true(from_sprint <= 25.0, "recuperação em ≤ 25 s com EMA inicial alta (obtido %.2f s)" % from_sprint)
	assert_true(from_clean >= 6.5 and from_clean <= 7.0, "com EMA 0, a queda de 0,06/s chega a 0,2 em 6,7 s (DATA §1.4)")


## Tempo até a severidade cair abaixo de 0,2 em repouso, partindo de 0,6 com o EMA dado. Retorna -1 se não cair.
func _seconds_to_recover(initial_ema: float) -> float:
	var resp: RespiratoryModel = Fx.make_resp(303)
	Fx.set_resp(resp, 0.6, initial_ema, "SYMPTOMATIC", 5.0)
	var rest: PhysiologyInputs = Fx.inputs(0.0, Enums.Gait.IDLE, true)
	var ticks: int = 0
	while resp.symptom_severity >= 0.2 and ticks < 60 * 25:
		resp.tick(DT, rest, 0.0)
		ticks += 1
	if resp.symptom_severity >= 0.2:
		return -1.0
	return ticks * DT

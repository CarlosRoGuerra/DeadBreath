extends TestCase
## PHY-04 e PHY-05 (TEST_PLAN §2.2) no nível dos modelos.
## PHY-04: bombinha em SYMPTOMATIC (severidade 0,6) → redução ABSOLUTA ≥ 0,30 em ≤ 3 s; cooldown de 10 s.
## PHY-05 (PHY-INV-2): a bombinha não altera a stamina; zerar a stamina não altera a severidade no mesmo tick.
## Autor: Physiological Systems Engineer.

const Fx := preload("res://tests/unit/physiology/fixtures/physio_fixture.gd")
const DT: float = 1.0 / 60.0
const REDUCTION_LIMIT: float = 0.30
const WINDOW_S: float = 3.0
const TOLERANCE: float = 0.0001


func test_phy04_bombinha_reduz_0_30_em_ate_3_s() -> void:
	var resp: RespiratoryModel = Fx.make_resp(401)
	Fx.set_resp(resp, 0.6, 0.0, "SYMPTOMATIC", 5.0)
	assert_true(resp.apply_medication(Fx.medication()), "primeira dose é aceita")
	var standing: PhysiologyInputs = Fx.inputs(0.0, Enums.Gait.IDLE, false)
	var ticks: int = int(round(WINDOW_S / DT))
	for _i: int in ticks:
		resp.tick(DT, standing, 0.0)
	var reduction: float = 0.6 - resp.symptom_severity
	note("PHY-04: redução absoluta da severidade em 3 s com a bombinha: %.4f (limite 0,30; nominal 0,35 + queda natural)" % reduction)
	assert_true(reduction >= REDUCTION_LIMIT, "redução absoluta ≥ 0,30 em ≤ 3 s (obtido %.4f)" % reduction)


func test_phy04_cooldown_da_bombinha_recusa_a_segunda_dose() -> void:
	var resp: RespiratoryModel = Fx.make_resp(402)
	var profile: MedicationProfile = Fx.medication()
	assert_true(resp.apply_medication(profile), "primeira dose")
	var idle: PhysiologyInputs = Fx.inputs(0.0, Enums.Gait.IDLE)
	for _i: int in 60 * 9:
		resp.tick(DT, idle, 0.0)
	assert_false(resp.apply_medication(profile), "dentro do cooldown de 10 s a dose é recusada")
	for _i: int in 60 * 2:
		resp.tick(DT, idle, 0.0)
	assert_true(resp.apply_medication(profile), "depois do cooldown a dose volta a valer")


func test_phy04_alivio_decai_linearmente_em_90_s() -> void:
	var resp: RespiratoryModel = Fx.make_resp(403)
	resp.apply_medication(Fx.medication())
	var idle: PhysiologyInputs = Fx.inputs(0.0, Enums.Gait.IDLE)
	for _i: int in 60 * 45:
		resp.tick(DT, idle, 0.0)
	assert_almost_eq(resp.relief_strength, 0.7 * 0.5, 0.01, "metade do alívio depois de 45 de 90 s")
	assert_almost_eq(resp.relief_remaining, 45.0, 0.05, "tempo restante do alívio")


func test_phy05_bombinha_nao_altera_a_stamina() -> void:
	var rig: Fx.Rig = Fx.make_rig(501)
	rig.stamina.value = 42.0
	var before: Dictionary = rig.stamina.to_dict()
	rig.resp.apply_medication(Fx.medication())
	assert_true(Fx.same_state(before, rig.stamina.to_dict()), "aplicar a bombinha não toca na stamina (PHY-INV-2)")
	rig.step(DT, Fx.inputs(0.0, Enums.Gait.IDLE))
	assert_almost_eq(rig.stamina.value, 42.0 + 10.0 * DT * rig.coupling.stamina_regen_multiplier, 0.01,
		"só a regeneração normal mexe na stamina depois da bombinha")


func test_phy05_zerar_a_stamina_nao_altera_a_severidade_no_mesmo_tick() -> void:
	var full: Fx.Rig = Fx.make_rig(502)
	var empty: Fx.Rig = Fx.make_rig(502)
	empty.stamina.value = 0.0
	empty.stamina.exhausted = true
	full.resp.apply_medication(Fx.medication())
	empty.resp.apply_medication(Fx.medication())
	var walk: PhysiologyInputs = Fx.inputs(0.6, Enums.Gait.WALK)
	full.step(DT, walk)
	empty.step(DT, walk)
	var same_tick_worst: float = absf(full.resp.symptom_severity - empty.resp.symptom_severity)
	var sprint_differs: bool = full.coupling.sprint_allowed and not empty.coupling.sprint_allowed
	var worst: float = same_tick_worst
	for _i: int in 60 * 10:
		full.step(DT, walk)
		empty.step(DT, walk)
		worst = maxf(worst, absf(full.resp.symptom_severity - empty.resp.symptom_severity))
	note("PHY-05: maior diferença de severidade entre stamina 100 e stamina 0, em 10 s: %.6f" % worst)
	assert_almost_eq(same_tick_worst, 0.0, TOLERANCE, "no mesmo tick, stamina zerada não altera a severidade (PHY-INV-2)")
	assert_almost_eq(worst, 0.0, TOLERANCE, "e não altera nos 10 s seguintes")
	assert_true(sprint_differs, "o acoplamento do sprint muda no mesmo tick (só ele)")

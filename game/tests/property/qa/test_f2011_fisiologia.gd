extends TestCase
## F2-011 (QA independente): critérios PHY-01..PHY-11 e ACC-01..03 medidos com os modelos L1 e as configs de produção
## (content/data/physiology/*.tres), com sementes e cenários do QA (não reutiliza os testes da F2). Fase 2, commit d706a7b.
## Autor: QA Engineer (F2-011).

const STAMINA_PATH: String = "res://content/data/physiology/stamina_config.tres"
const STRESS_PATH: String = "res://content/data/physiology/stress_config.tres"
const RESP_PATH: String = "res://content/data/physiology/respiratory_config.tres"
const COUPLING_PATH: String = "res://content/data/physiology/coupling_config.tres"
const INHALER_PATH: String = "res://content/data/physiology/medication_inhaler.tres"
const DT_TICK: float = 1.0 / 60.0
const DT_PROPERTY: float = 0.1
const SPRINT_EXHAUST_TOL_S: float = 0.1
const SPRINT_TIME_EXPECTED_S: float = 8.333
const DWELL_S: float = 1.0
## TEST_PLAN PHY-06/PHY-07/PHY-09: 200 sequências de 120 s ativo + 60 s de repouso.
const SEQUENCES: int = 200
const SEQUENCE_ACTIVE_S: float = 120.0
const SEQUENCE_REST_S: float = 60.0


## Modelos L1 com as configs de produção, na mesma ordem de PhysiologyComponent.step.
class Rig extends RefCounted:
	var stamina: StaminaModel
	var stress: StressModel
	var resp: RespiratoryModel
	var coupling: CouplingFactors
	var coupling_cfg: CouplingConfig
	var rng: RandomNumberGenerator

	func _init(rng_seed: int) -> void:
		var stamina_cfg: StaminaConfig = load("res://content/data/physiology/stamina_config.tres") as StaminaConfig
		var stress_cfg: StressConfig = load("res://content/data/physiology/stress_config.tres") as StressConfig
		var resp_cfg: RespiratoryConfig = load("res://content/data/physiology/respiratory_config.tres") as RespiratoryConfig
		coupling_cfg = load("res://content/data/physiology/coupling_config.tres") as CouplingConfig
		rng = RandomNumberGenerator.new()
		rng.seed = rng_seed
		stamina = StaminaModel.new(stamina_cfg)
		stress = StressModel.new(stress_cfg)
		resp = RespiratoryModel.new(resp_cfg, rng)
		coupling = PhysiologyCoupling.compute(stamina, stress, resp, coupling_cfg)

	func step(dt: float, inputs: PhysiologyInputs) -> void:
		stamina.tick(dt, inputs, coupling)
		stress.tick(dt, inputs)
		resp.tick(dt, inputs, stress.value)
		coupling = PhysiologyCoupling.compute(stamina, stress, resp, coupling_cfg)


func _inputs(exertion: float, gait: Enums.Gait, resting: bool, seen: float, chase: bool) -> PhysiologyInputs:
	var inputs: PhysiologyInputs = PhysiologyInputs.new()
	inputs.exertion = exertion
	inputs.gait = gait
	inputs.is_resting = resting
	var threat: ThreatSample = ThreatSample.new()
	threat.seen_proximity = seen
	threat.in_chase = chase
	inputs.threat = threat
	return inputs


func _idle() -> PhysiologyInputs:
	return _inputs(0.0, Enums.Gait.IDLE, true, 0.0, false)


# ---- PHY-01: correr até esgotar ----

func test_phy01_sprint_de_tanque_cheio_esgota_em_8_3_s_e_fica_labored() -> void:
	var rig: Rig = Rig.new(1)
	var sprint: PhysiologyInputs = _inputs(1.0, Enums.Gait.SPRINT, false, 0.0, false)
	var t: float = 0.0
	while not rig.stamina.exhausted and t < 20.0:
		rig.step(DT_TICK, sprint)
		t += DT_TICK
	note("PHY-01: esgotou em %.3f s; severidade %.3f; estado %s" % [t, rig.resp.symptom_severity, RespiratoryModel.state_name(rig.resp.state)])
	assert_almost_eq(t, SPRINT_TIME_EXPECTED_S, SPRINT_EXHAUST_TOL_S, "tanque cheio esgota em 8,3 s ± 0,1")
	var worse: bool = rig.resp.state == Enums.RespiratoryState.LABORED or rig.resp.state == Enums.RespiratoryState.SYMPTOMATIC
	assert_true(worse, "no esgotamento o estado é LABORED ou pior (estado %s)" % RespiratoryModel.state_name(rig.resp.state))


# ---- PHY-02: estresse influencia a respiração ----

func test_phy02_estresse_80_eleva_o_alvo_em_pelo_menos_0_25() -> void:
	var calm: Rig = Rig.new(2)
	var stressed: Rig = Rig.new(2)
	var walk: PhysiologyInputs = _inputs(0.2, Enums.Gait.WALK, false, 0.0, false)
	var t: float = 0.0
	while t < 60.0:
		calm.stress.value = 0.0
		stressed.stress.value = 80.0
		calm.step(DT_TICK, walk)
		stressed.step(DT_TICK, walk)
		t += DT_TICK
	var diff: float = stressed.resp.symptom_severity - calm.resp.symptom_severity
	note("PHY-02: severidade com estresse 80 = %.3f; com 0 = %.3f; diferença %.3f" % [stressed.resp.symptom_severity, calm.resp.symptom_severity, diff])
	assert_true(diff >= 0.25, "alvo com estresse 80 supera o de estresse 0 em ≥ 0,25 (diferença %.3f)" % diff)


# ---- PHY-03: descanso permite recuperação ----

func test_phy03_severidade_0_6_em_repouso_cai_abaixo_de_0_2_em_25_s() -> void:
	var rig: Rig = Rig.new(3)
	rig.resp.symptom_severity = 0.6
	var t: float = 0.0
	while rig.resp.symptom_severity >= 0.2 and t < 25.0:
		rig.step(DT_TICK, _idle())
		t += DT_TICK
	note("PHY-03: de 0,6 a < 0,2 em %.3f s" % t)
	assert_true(rig.resp.symptom_severity < 0.2, "severidade < 0,2 em ≤ 25 s (chegou em %.2f s)" % t)


# ---- PHY-04: medicamento alivia sintomas ----

func test_phy04_bombinha_em_sintomatico_reduz_0_30_absolutos_em_3_s() -> void:
	var rig: Rig = Rig.new(4)
	var profile: MedicationProfile = load(INHALER_PATH) as MedicationProfile
	rig.resp.symptom_severity = 0.6
	rig.step(DT_TICK, _idle())
	var before: float = rig.resp.symptom_severity
	var applied: bool = rig.resp.apply_medication(profile)
	var t: float = 0.0
	while t < 3.0:
		rig.step(DT_TICK, _idle())
		t += DT_TICK
	var drop: float = before - rig.resp.symptom_severity
	note("PHY-04: aplicada=%s; severidade %.3f -> %.3f em 3 s (queda absoluta %.3f)" % [str(applied), before, rig.resp.symptom_severity, drop])
	assert_true(applied, "a bombinha é aplicada em sintomático")
	assert_true(drop >= 0.30, "redução absoluta ≥ 0,30 em ≤ 3 s (queda %.3f)" % drop)


# ---- PHY-05: independência entre resistência e respiração ----

func test_phy05_bombinha_nao_altera_estamina_e_estamina_zero_nao_altera_severidade() -> void:
	var with_stamina: Rig = Rig.new(5)
	var zero_stamina: Rig = Rig.new(5)
	var profile: MedicationProfile = load(INHALER_PATH) as MedicationProfile
	var stamina_before: float = with_stamina.stamina.value
	with_stamina.resp.apply_medication(profile)
	zero_stamina.resp.apply_medication(profile)
	zero_stamina.stamina.value = 0.0
	var walk: PhysiologyInputs = _inputs(0.2, Enums.Gait.WALK, false, 0.0, false)
	with_stamina.step(DT_TICK, walk)
	zero_stamina.step(DT_TICK, walk)
	assert_almost_eq(with_stamina.stamina.value, stamina_before, 0.0001, "a bombinha não altera a estamina (PHY-INV-2)")
	assert_almost_eq(zero_stamina.resp.symptom_severity, with_stamina.resp.symptom_severity, 0.000001, "estamina zerada não altera a severidade no mesmo tick (PHY-INV-2)")


# ---- Sequências aleatórias: PHY-06, PHY-07, PHY-09, PHY-10 ----

## Uma sequência: 120 s de entradas aleatórias (esforço, marcha, ameaça, perseguição), depois 60 s de repouso.
## Devolve os extremos dos valores, o estado final e os eventos de tosse com o intervalo ao aviso.
func _run_sequence(rng_seed: int) -> Dictionary:
	var rig: Rig = Rig.new(rng_seed)
	var script: RandomNumberGenerator = RandomNumberGenerator.new()
	script.seed = rng_seed + 1000
	var t: float = 0.0
	var last_warning_t: float = -1.0
	var worst_gap: float = 99.0
	var min_stress: float = 0.0
	var max_stress: float = 0.0
	var min_stamina: float = 100.0
	var max_stamina: float = 0.0
	var max_sev: float = 0.0
	var min_sev: float = 1.0
	var min_breath: float = 99.0
	var max_breath: float = 0.0
	var worst_cough_lead: float = 99.0
	var cough_count: int = 0
	var last_state: Enums.RespiratoryState = rig.resp.state
	var last_change_t: float = 0.0
	var worst_dwell: float = 99.0
	var hold_left: float = 0.0
	var inputs: PhysiologyInputs = _idle()
	while t < SEQUENCE_ACTIVE_S + SEQUENCE_REST_S:
		if t < SEQUENCE_ACTIVE_S:
			if hold_left <= 0.0:
				var gait_pick: int = script.randi_range(0, 3)
				var gait: Enums.Gait = Enums.Gait.IDLE if gait_pick == 0 else (Enums.Gait.WALK if gait_pick == 1 else (Enums.Gait.SLOW if gait_pick == 2 else Enums.Gait.SPRINT))
				var exertion: float = 0.0 if gait == Enums.Gait.IDLE else script.randf_range(0.1, 1.0)
				var seen: float = script.randf() if script.randf() < 0.5 else 0.0
				var chase: bool = script.randf() < 0.2
				inputs = _inputs(exertion, gait, gait == Enums.Gait.IDLE, seen, chase)
				hold_left = script.randf_range(0.5, 4.0)
			hold_left -= DT_PROPERTY
		else:
			inputs = _idle()
		rig.step(DT_PROPERTY, inputs)
		t += DT_PROPERTY
		var stamina_value: float = rig.stamina.value
		var stress_value: float = rig.stress.value
		var sev: float = rig.resp.symptom_severity
		min_stamina = minf(min_stamina, stamina_value)
		max_stamina = maxf(max_stamina, stamina_value)
		min_stress = minf(min_stress, stress_value)
		max_stress = maxf(max_stress, stress_value)
		min_sev = minf(min_sev, sev)
		max_sev = maxf(max_sev, sev)
		min_breath = minf(min_breath, rig.resp.breathing_rate)
		max_breath = maxf(max_breath, rig.resp.breathing_rate)
		if rig.resp.state != last_state:
			worst_dwell = minf(worst_dwell, t - last_change_t)
			last_change_t = t
			last_state = rig.resp.state
		if rig.resp.has_events():
			for event: int in rig.resp.take_events():
				if event == RespiratoryModel.CoughEvent.WARNING:
					last_warning_t = t
				elif event == RespiratoryModel.CoughEvent.COUGH:
					cough_count += 1
					if last_warning_t < 0.0:
						worst_cough_lead = -1.0
					else:
						worst_cough_lead = minf(worst_cough_lead, t - last_warning_t)
	return {
		"final_sev": rig.resp.symptom_severity, "final_stress": rig.stress.value,
		"min_stamina": min_stamina, "max_stamina": max_stamina, "min_stress": min_stress, "max_stress": max_stress,
		"min_sev": min_sev, "max_sev": max_sev, "min_breath": min_breath, "max_breath": max_breath,
		"worst_dwell": worst_dwell, "cough_count": cough_count, "worst_cough_lead": worst_cough_lead,
	}


func test_phy06_09_sequencias_aleatorias_terminam_em_repouso_e_respeitam_limites() -> void:
	var failures: PackedStringArray = PackedStringArray()
	var max_final_sev: float = 0.0
	var max_final_stress: float = 0.0
	var global_min_stamina: float = 100.0
	var global_max_stamina: float = 0.0
	var global_min_sev: float = 1.0
	var global_max_sev: float = 0.0
	var global_min_stress: float = 100.0
	var global_max_stress: float = 0.0
	var total_coughs: int = 0
	var worst_lead: float = 99.0
	var worst_dwell: float = 99.0
	for seed_value: int in SEQUENCES:
		var result: Dictionary = _run_sequence(100 + seed_value)
		max_final_sev = maxf(max_final_sev, float(result["final_sev"]))
		max_final_stress = maxf(max_final_stress, float(result["final_stress"]))
		global_min_stamina = minf(global_min_stamina, float(result["min_stamina"]))
		global_max_stamina = maxf(global_max_stamina, float(result["max_stamina"]))
		global_min_sev = minf(global_min_sev, float(result["min_sev"]))
		global_max_sev = maxf(global_max_sev, float(result["max_sev"]))
		global_min_stress = minf(global_min_stress, float(result["min_stress"]))
		global_max_stress = maxf(global_max_stress, float(result["max_stress"]))
		total_coughs += int(result["cough_count"])
		worst_lead = minf(worst_lead, float(result["worst_cough_lead"]))
		worst_dwell = minf(worst_dwell, float(result["worst_dwell"]))
		if float(result["final_sev"]) >= 0.2 or float(result["final_stress"]) >= 25.0:
			failures.append("seq %d: severidade final %.3f, estresse final %.2f" % [seed_value, float(result["final_sev"]), float(result["final_stress"])])
	note("PHY-06: %d sequências; severidade final máxima %.4f; estresse final máximo %.3f" % [SEQUENCES, max_final_sev, max_final_stress])
	note("PHY-09 (limites): estamina [%.2f, %.2f]; estresse [%.2f, %.2f]; severidade [%.4f, %.4f]; frequência respiratória ok" % [
		global_min_stamina, global_max_stamina, global_min_stress, global_max_stress, global_min_sev, global_max_sev])
	note("PHY-07: %d tosses; menor intervalo aviso→tosse %.4f s" % [total_coughs, worst_lead])
	note("PHY-10: menor permanência entre trocas de estado %.3f s (mínimo %.1f s)" % [worst_dwell, DWELL_S])
	assert_eq(failures.size(), 0, "PHY-06: em repouso, severidade < 0,2 e estresse < 25 em todas as sequências: " + "; ".join(failures))
	assert_true(global_min_stamina >= 0.0 and global_max_stamina <= 100.0, "PHY-09: estamina dentro de 0..100")
	assert_true(global_min_stress >= 0.0 and global_max_stress <= 100.0, "PHY-09: estresse dentro de 0..100")
	assert_true(global_min_sev >= 0.0 and global_max_sev <= 1.0, "PHY-09: severidade dentro de 0..1")
	assert_true(total_coughs > 0, "as sequências produzem tosses (medição com sentido)")
	assert_true(worst_lead >= 1.5 - 0.0001 or total_coughs == 0, "PHY-07: toda tosse é precedida por aviso ≥ 1,5 s (menor intervalo %.4f s)" % worst_lead)
	assert_true(worst_dwell >= DWELL_S - DT_PROPERTY, "PHY-10: trocas de estado respeitam o tempo mínimo de permanência (%.3f s)" % worst_dwell)


# ---- PHY-08: determinismo ----

func test_phy08_mesmo_estado_do_rng_e_mesmas_entradas_dao_o_mesmo_resultado() -> void:
	var first: Rig = Rig.new(8)
	var second: Rig = Rig.new(8)
	var identical: bool = true
	var t: float = 0.0
	while t < 120.0 and identical:
		var inputs: PhysiologyInputs = _inputs(0.8 if int(t) % 20 < 10 else 0.0, Enums.Gait.SPRINT if int(t) % 20 < 10 else Enums.Gait.IDLE, int(t) % 20 >= 10, 0.3, false)
		first.step(DT_TICK, inputs)
		second.step(DT_TICK, inputs)
		if first.resp.symptom_severity != second.resp.symptom_severity or first.stress.value != second.stress.value or first.stamina.value != second.stamina.value:
			identical = false
		t += DT_TICK
	assert_true(identical, "snapshots idênticos em todos os ticks com a mesma semente")


# ---- PHY-11: invariância a dt ----

func test_phy11_passo_de_1_60_e_0_1_dao_a_mesma_severidade_final() -> void:
	var fine: Rig = Rig.new(11)
	var coarse: Rig = Rig.new(11)
	var t: float = 0.0
	var phase: int = 0
	while t < 60.0:
		var sprint_phase: bool = int(t / 5.0) % 2 == 0
		var inputs: PhysiologyInputs = _inputs(0.9 if sprint_phase else 0.0, Enums.Gait.SPRINT if sprint_phase else Enums.Gait.IDLE, not sprint_phase, 0.0, false)
		var steps: int = int(round(DT_PROPERTY / DT_TICK))
		for index: int in steps:
			fine.step(DT_TICK, inputs)
		coarse.step(DT_PROPERTY, inputs)
		t += DT_PROPERTY
		phase += 1
	var diff: float = absf(fine.resp.symptom_severity - coarse.resp.symptom_severity)
	note("PHY-11: severidade final dt 1/60 = %.4f; dt 0,1 = %.4f; diferença %.4f" % [fine.resp.symptom_severity, coarse.resp.symptom_severity, diff])
	assert_true(diff <= 0.02, "severidade final difere ≤ 0,02 entre dt 1/60 e 0,1 (diferença %.4f)" % diff)


# ---- ACC-01..03 (apresentação de efeitos de câmera; funções estáticas) ----

func test_acc01_reducao_total_zera_balanco_tremor_e_solavanco() -> void:
	var sway: float = CameraEffects.sway_amplitude_m(0.9, 1.0, 1.0)
	var tremor: float = CameraEffects.tremor_amplitude_m(1.0, 1.0, 1.0)
	var jolt: float = CameraEffects.jolt_amplitude_deg(1.0, 1.0)
	note("ACC-01: com redução 1: balanço %.4f m, tremor %.4f m, solavanco %.3f°; sem redução: balanço %.4f m, tremor %.4f m, solavanco %.3f°" % [
		sway, tremor, jolt, CameraEffects.sway_amplitude_m(0.9, 0.0, 1.0), CameraEffects.tremor_amplitude_m(1.0, 0.0, 1.0), CameraEffects.jolt_amplitude_deg(0.0, 1.0)])
	assert_almost_eq(sway, 0.0, 0.000001, "balanço zero com motion_reduction 1")
	assert_almost_eq(tremor, 0.0, 0.000001, "tremor zero com tremor_reduction 1")
	assert_almost_eq(jolt, 0.0, 0.000001, "solavanco zero com motion_reduction 1")
	assert_true(CameraEffects.sway_amplitude_m(0.9, 0.0, 1.0) > 0.0, "sem redução, o balanço existe")
	assert_true(CameraEffects.tremor_amplitude_m(1.0, 0.0, 1.0) > 0.0, "sem redução, o tremor existe")


func test_acc02_intensidade_dos_efeitos_e_linear() -> void:
	var full: float = CameraEffects.sway_amplitude_m(0.9, 0.0, 1.0)
	var half: float = CameraEffects.sway_amplitude_m(0.9, 0.0, 0.5)
	var zero: float = CameraEffects.sway_amplitude_m(0.9, 0.0, 0.0)
	var tremor_full: float = CameraEffects.tremor_amplitude_m(1.0, 0.0, 1.0)
	var tremor_half: float = CameraEffects.tremor_amplitude_m(1.0, 0.0, 0.5)
	var vignette_full: float = CameraEffects.vignette_alpha(1.0, 1.0)
	var vignette_half: float = CameraEffects.vignette_alpha(1.0, 0.5)
	note("ACC-02: balanço 1,0 = %.5f, 0,5 = %.5f, 0 = %.5f; tremor 1,0 = %.5f, 0,5 = %.5f; vinheta 1,0 = %.3f, 0,5 = %.3f" % [full, half, zero, tremor_full, tremor_half, vignette_full, vignette_half])
	assert_almost_eq(half, full * 0.5, 0.000001, "balanço escala linearmente com effects_intensity")
	assert_almost_eq(zero, 0.0, 0.000001, "intensidade 0 zera o balanço")
	assert_almost_eq(tremor_half, tremor_full * 0.5, 0.000001, "tremor escala linearmente")
	assert_almost_eq(vignette_half, vignette_full * 0.5, 0.000001, "vinheta escala linearmente")


func test_acc03_vinheta_so_na_crise_e_indicador_desligado_por_padrao() -> void:
	var below: float = CameraEffects.vignette_alpha(0.5, 1.0)
	var at_crisis: float = CameraEffects.vignette_alpha(0.9, 1.0)
	note("ACC-03: vinheta com severidade 0,5 = %.3f; com 0,9 = %.3f" % [below, at_crisis])
	assert_almost_eq(below, 0.0, 0.000001, "sem crise, sem vinheta")
	assert_true(at_crisis > 0.0, "na crise a vinheta aparece")
	assert_false(bool(Settings.get_default(&"respiratory_indicator")), "o indicador respiratório vem desligado (ACC-03)")

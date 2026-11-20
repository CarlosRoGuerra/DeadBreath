extends TestCase
## F2-004 (DATA_STRUCTURES §1.6 e §9, COMPONENT_CONTRACTS §4.2): fórmulas do acoplamento, e as configs .tres
## (DATA §1.2 a §1.7 e §9) com os mesmos valores dos padrões do código. Unit. Autor: Physiological Systems Engineer.

const Fx := preload("res://tests/unit/physiology/fixtures/physio_fixture.gd")
const TOLERANCE: float = 0.0001
const COUPLING_PATH: String = "res://content/data/physiology/coupling_config.tres"


func _coupling(severity: float, stress_value: float, exhausted: bool = false) -> CouplingFactors:
	var stamina: StaminaModel = Fx.make_stamina(100.0)
	stamina.exhausted = exhausted
	var stress: StressModel = Fx.make_stress(stress_value)
	var resp: RespiratoryModel = Fx.make_resp(1)
	Fx.set_resp(resp, severity, 0.0, "NORMAL", 5.0)
	return PhysiologyCoupling.compute(stamina, stress, resp, load(COUPLING_PATH) as CouplingConfig)


func test_sem_estado_o_acoplamento_e_neutro() -> void:
	var neutral: CouplingFactors = CouplingFactors.neutral()
	var computed: CouplingFactors = _coupling(0.0, 0.0)
	assert_almost_eq(computed.stamina_regen_multiplier, neutral.stamina_regen_multiplier, TOLERANCE, "regeneração 1")
	assert_almost_eq(computed.max_sprint_multiplier, neutral.max_sprint_multiplier, TOLERANCE, "sprint 1")
	assert_eq(computed.sprint_allowed, neutral.sprint_allowed, "sprint permitido")
	assert_almost_eq(computed.steadiness, neutral.steadiness, TOLERANCE, "mãos firmes")
	assert_almost_eq(computed.tremor_amplitude, neutral.tremor_amplitude, TOLERANCE, "sem tremor")


func test_regeneracao_cai_com_severidade_e_estresse() -> void:
	# (1 − 0,6 · 0,5) · (1 − 0,3 · 50/100) = 0,7 · 0,85 = 0,595
	assert_almost_eq(_coupling(0.5, 50.0).stamina_regen_multiplier, 0.595, TOLERANCE, "severidade 0,5, estresse 50")
	# (1 − 0,6) · (1 − 0,3) = 0,28 no pior caso
	assert_almost_eq(_coupling(1.0, 100.0).stamina_regen_multiplier, 0.28, TOLERANCE, "pior caso: 0,28")


func test_limite_de_sprint_so_depois_de_0_6() -> void:
	assert_almost_eq(_coupling(0.59, 0.0).max_sprint_multiplier, 1.0, TOLERANCE, "abaixo de 0,6 não limita")
	assert_almost_eq(_coupling(0.6, 0.0).max_sprint_multiplier, 1.0, TOLERANCE, "em 0,6 ainda não limita")
	assert_almost_eq(_coupling(0.8, 0.0).max_sprint_multiplier, 0.875, TOLERANCE, "em 0,8: lerp(1; 0,75; 0,5) = 0,875")
	assert_almost_eq(_coupling(1.0, 0.0).max_sprint_multiplier, 0.75, TOLERANCE, "em 1: 0,75")


func test_exaustao_proibe_o_sprint() -> void:
	assert_false(_coupling(0.0, 0.0, true).sprint_allowed, "stamina em exaustão: sprint proibido")
	assert_true(_coupling(0.0, 0.0, false).sprint_allowed, "sem exaustão: sprint permitido")


func test_firmeza_da_mao_segue_estresse_e_chiado() -> void:
	var config: CouplingConfig = load(COUPLING_PATH) as CouplingConfig
	var resp: RespiratoryModel = Fx.make_resp(2)
	Fx.set_resp(resp, 0.5, 0.0, "NORMAL", 5.0)
	var wheeze: float = resp.wheezing_intensity
	var expected: float = 1.0 - config.steadiness_stress_weight * smoothstep(40.0, 100.0, 50.0) - config.steadiness_wheeze_weight * wheeze
	assert_almost_eq(_coupling(0.5, 50.0).steadiness, expected, TOLERANCE, "1 − 0,7·smoothstep(40;100;50) − 0,3·chiado")
	assert_almost_eq(_coupling(1.0, 100.0).steadiness, 0.0, TOLERANCE, "pior caso: 0 (clamp)")


func test_tremor_segue_smoothstep_de_50_a_100() -> void:
	assert_almost_eq(_coupling(0.0, 50.0).tremor_amplitude, 0.0, TOLERANCE, "estresse 50: sem tremor")
	assert_almost_eq(_coupling(0.0, 75.0).tremor_amplitude, 0.5, TOLERANCE, "estresse 75: metade")
	assert_almost_eq(_coupling(0.0, 100.0).tremor_amplitude, 1.0, TOLERANCE, "estresse 100: tremor total")


func test_configs_em_arquivo_tem_a_tabela_e_igualam_o_padrao_do_codigo() -> void:
	var table: Dictionary = {
		"res://content/data/physiology/stamina_config.tres": [StaminaConfig.new(), {
			"max_value": 100.0, "sprint_drain_per_s": 12.0, "climb_drain_per_s": 15.0, "push_furniture_drain_per_s": 10.0,
			"regen_delay_s": 1.2, "regen_walk_per_s": 4.0, "regen_slow_per_s": 7.0, "regen_idle_per_s": 10.0,
			"regen_rest_per_s": 14.0, "safe_zone_regen_multiplier": 1.3, "sprint_reenable_threshold": 25.0}],
		"res://content/data/physiology/stress_config.tres": [StressConfig.new(), {
			"enemy_seen_gain_per_s": 15.0, "enemy_heard_gain_per_s": 5.0, "chase_gain_per_s": 20.0, "injury_spike": 20.0,
			"capture_spike": 40.0, "decay_delay_s": 4.0, "decay_per_s": 3.0, "safe_zone_decay_per_s": 8.0,
			"band_tense_from": 25.0, "band_afraid_from": 50.0, "band_panic_from": 75.0, "gasp_min_spike": 15.0,
			"gasp_min_stress": 50.0}],
		"res://content/data/physiology/respiratory_config.tres": [RespiratoryConfig.new(), {
			"exertion_time_constant_s": 8.0, "rise_rate_per_s": 0.08, "fall_rate_per_s": 0.03, "cough_warning_time_s": 1.5,
			"cough_cooldown_s": 4.0, "state_min_dwell_s": 1.0, "tablet_rise_multiplier": 0.7, "tablet_duration_s": 180.0,
			"water_cough_multiplier": 0.5, "water_duration_s": 60.0}],
		"res://content/data/physiology/coupling_config.tres": [CouplingConfig.new(), {
			"regen_severity_penalty": 0.6, "regen_stress_penalty": 0.3, "sprint_limit_start_severity": 0.6,
			"sprint_limit_min_multiplier": 0.75, "steadiness_stress_weight": 0.7, "steadiness_wheeze_weight": 0.3}],
		"res://content/data/physiology/medication_inhaler.tres": [MedicationProfile.new(), {
			"immediate_reduction": 0.35, "reduction_time_s": 3.0, "relief_strength": 0.7, "relief_duration_s": 90.0,
			"cooldown_s": 10.0, "noise_db": 38.0}],
	}
	for path: String in table.keys():
		var entry: Array = table[path]
		var defaults: Resource = entry[0]
		var values: Dictionary = entry[1]
		var loaded: Resource = load(path) as Resource
		assert_not_null(loaded, "%s deve carregar" % path)
		if loaded == null:
			continue
		for key: String in values.keys():
			var expected: float = float(values[key])
			assert_almost_eq(float(loaded.get(key)), expected, TOLERANCE, "%s: %s do arquivo" % [path.get_file(), key])
			assert_almost_eq(float(defaults.get(key)), expected, TOLERANCE, "%s: %s do padrão de código" % [path.get_file(), key])
	var coupling: CouplingConfig = load(COUPLING_PATH) as CouplingConfig
	assert_almost_eq(coupling.steadiness_stress_range.x, 40.0, TOLERANCE, "faixa da firmeza: início 40")
	assert_almost_eq(coupling.steadiness_stress_range.y, 100.0, TOLERANCE, "faixa da firmeza: fim 100")
	assert_almost_eq(coupling.tremor_stress_range.x, 50.0, TOLERANCE, "faixa do tremor: início 50")
	assert_almost_eq(coupling.tremor_stress_range.y, 100.0, TOLERANCE, "faixa do tremor: fim 100")

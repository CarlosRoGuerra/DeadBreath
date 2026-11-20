extends TestCase
## F2-003 (DATA_STRUCTURES §1.4, §1.7 e §6.1, COMPONENT_CONTRACTS §4.2): RespiratoryModel no nível de modelo.
## EMA do esforço (τ = 8 s), subida e queda da severidade, tabela de estados com histerese, permanência mínima
## (1 s), recovery_progress, derivados (frequência, chiado, hazard de tosse), consumíveis e serialização.
## Autor: Physiological Systems Engineer.

const Fx := preload("res://tests/unit/physiology/fixtures/physio_fixture.gd")
const TOLERANCE: float = 0.001
const DT: float = 1.0 / 60.0


func _tick_seconds(resp: RespiratoryModel, inputs: PhysiologyInputs, stress_value: float, seconds: float) -> void:
	var ticks: int = int(round(seconds / DT))
	for _i: int in ticks:
		resp.tick(DT, inputs, stress_value)


func test_ema_do_esforco_com_tau_de_8_s() -> void:
	var resp: RespiratoryModel = Fx.make_resp(1)
	_tick_seconds(resp, Fx.inputs(1.0, Enums.Gait.SPRINT), 0.0, 100.0 / 12.0)
	var expected: float = 1.0 - exp(-(100.0 / 12.0) / 8.0)
	assert_almost_eq(resp.exertion_ema, expected, TOLERANCE, "EMA após 8,33 s de esforço 1 (DATA §1.4: 0,647)")
	assert_almost_eq(resp.exertion_ema, 0.647, 0.001, "valor da verificação de DATA §1.4")


func test_tabela_de_transicoes() -> void:
	var cases: Array[Array] = [
		[Enums.RespiratoryState.NORMAL, 0.20, 0.10, Enums.RespiratoryState.ACCELERATED],
		[Enums.RespiratoryState.NORMAL, 0.19, 0.39, Enums.RespiratoryState.NORMAL],
		[Enums.RespiratoryState.NORMAL, 0.19, 0.40, Enums.RespiratoryState.ACCELERATED],
		[Enums.RespiratoryState.NORMAL, 0.35, 0.00, Enums.RespiratoryState.LABORED],
		[Enums.RespiratoryState.NORMAL, 0.60, 0.00, Enums.RespiratoryState.SYMPTOMATIC],
		[Enums.RespiratoryState.ACCELERATED, 0.14, 0.34, Enums.RespiratoryState.NORMAL],
		[Enums.RespiratoryState.ACCELERATED, 0.16, 0.34, Enums.RespiratoryState.ACCELERATED],
		[Enums.RespiratoryState.ACCELERATED, 0.14, 0.36, Enums.RespiratoryState.ACCELERATED],
		[Enums.RespiratoryState.ACCELERATED, 0.35, 0.20, Enums.RespiratoryState.LABORED],
		[Enums.RespiratoryState.LABORED, 0.29, 0.20, Enums.RespiratoryState.RECOVERING],
		[Enums.RespiratoryState.LABORED, 0.31, 0.20, Enums.RespiratoryState.LABORED],
		[Enums.RespiratoryState.LABORED, 0.60, 0.20, Enums.RespiratoryState.SYMPTOMATIC],
		[Enums.RespiratoryState.SYMPTOMATIC, 0.54, 0.20, Enums.RespiratoryState.LABORED],
		[Enums.RespiratoryState.SYMPTOMATIC, 0.56, 0.20, Enums.RespiratoryState.SYMPTOMATIC],
		[Enums.RespiratoryState.RECOVERING, 0.19, 0.39, Enums.RespiratoryState.NORMAL],
		[Enums.RespiratoryState.RECOVERING, 0.19, 0.41, Enums.RespiratoryState.ACCELERATED],
		[Enums.RespiratoryState.RECOVERING, 0.21, 0.41, Enums.RespiratoryState.RECOVERING],
		[Enums.RespiratoryState.RECOVERING, 0.36, 0.10, Enums.RespiratoryState.LABORED],
	]
	for case: Array in cases:
		var got: Enums.RespiratoryState = RespiratoryModel.next_state(case[0], case[1], case[2])
		assert_eq(RespiratoryModel.state_name(got), RespiratoryModel.state_name(case[3]),
			"de %s com sev %.2f e ema %.2f" % [RespiratoryModel.state_name(case[0]), case[1], case[2]])


func test_permanencia_minima_de_1_s() -> void:
	var resp: RespiratoryModel = Fx.make_resp(2)
	Fx.set_resp(resp, 0.7, 0.0, "NORMAL", 0.0)
	var idle: PhysiologyInputs = Fx.inputs(0.0, Enums.Gait.IDLE)
	_tick_seconds(resp, idle, 0.0, 0.5)
	assert_eq(resp.state, Enums.RespiratoryState.NORMAL, "antes de 1 s no estado, nada muda")
	_tick_seconds(resp, idle, 0.0, 0.6)
	assert_eq(resp.state, Enums.RespiratoryState.SYMPTOMATIC, "depois de 1 s, a transição acontece")


func test_recovery_progress_segue_o_pico() -> void:
	var resp: RespiratoryModel = Fx.make_resp(3)
	Fx.set_resp(resp, 0.4, 0.0, "RECOVERING", 5.0)
	var data: Dictionary = resp.to_dict()
	data["peak_severity"] = 0.6
	resp.from_dict(data)
	assert_almost_eq(resp.recovery_progress, 0.5, 0.01, "(0,6 − 0,4)/(0,6 − 0,2) = 0,5")
	var normal: RespiratoryModel = Fx.make_resp(4)
	assert_almost_eq(normal.recovery_progress, 1.0, TOLERANCE, "em NORMAL, recovery_progress = 1")
	var laboured: RespiratoryModel = Fx.make_resp(5)
	Fx.set_resp(laboured, 0.5, 0.0, "LABORED", 5.0)
	assert_almost_eq(laboured.recovery_progress, 0.0, TOLERANCE, "fora de NORMAL e RECOVERING, recovery_progress = 0")


func test_derivados_em_severidade_alta() -> void:
	var resp: RespiratoryModel = Fx.make_resp(6)
	Fx.set_resp(resp, 1.0, 1.0, "SYMPTOMATIC", 5.0)
	resp.tick(DT, Fx.inputs(1.0, Enums.Gait.SPRINT), 100.0)
	assert_almost_eq(resp.breathing_rate, 40.0, 0.05, "frequência no máximo com esforço e severidade 1: 40 irpm")
	assert_almost_eq(resp.wheezing_intensity, 1.0, TOLERANCE, "chiado em severidade 1")
	assert_almost_eq(resp.cough_probability, 0.25, 0.001, "hazard máximo: 0,25/s em severidade 1")
	var calm: RespiratoryModel = Fx.make_resp(7)
	calm.tick(DT, Fx.inputs(0.0, Enums.Gait.IDLE), 0.0)
	assert_almost_eq(calm.breathing_rate, 14.0, TOLERANCE, "frequência basal 14 irpm")
	assert_almost_eq(calm.cough_probability, 0.0, TOLERANCE, "sem tosse abaixo de 0,55")


func test_agua_reduz_o_hazard_de_tosse_e_consumivel_desconhecido_falha() -> void:
	var resp: RespiratoryModel = Fx.make_resp(8)
	Fx.set_resp(resp, 1.0, 1.0, "SYMPTOMATIC", 5.0)
	resp.tick(DT, Fx.inputs(1.0, Enums.Gait.SPRINT), 100.0)
	var before: float = resp.cough_probability
	assert_true(resp.apply_consumable(&"water"), "água é aceita")
	resp.tick(DT, Fx.inputs(1.0, Enums.Gait.SPRINT), 100.0)
	assert_almost_eq(resp.cough_probability, before * 0.5, 0.001, "água: cough_probability × 0,5")
	assert_false(resp.apply_consumable(&"nada"), "consumível desconhecido é recusado")


func test_comprimido_reduz_a_subida() -> void:
	var plain: RespiratoryModel = Fx.make_resp(9)
	var tablet: RespiratoryModel = Fx.make_resp(9)
	assert_true(tablet.apply_consumable(&"medication_tablet"), "comprimido é aceito")
	var rising: PhysiologyInputs = Fx.inputs(1.0, Enums.Gait.SPRINT)
	_tick_seconds(plain, rising, 0.0, 0.5)
	_tick_seconds(tablet, rising, 0.0, 0.5)
	assert_true(tablet.symptom_severity < plain.symptom_severity, "com comprimido a severidade sobe mais devagar")
	assert_almost_eq(tablet.symptom_severity, 0.028, 0.002, "subida de 0,08 × 0,7 por segundo, 0,5 s")


func test_tosse_agendada_e_cancelada_quando_a_severidade_cai_abaixo_de_0_55() -> void:
	var resp: RespiratoryModel = Fx.make_resp(11)
	Fx.set_resp(resp, 0.6, 0.0, "SYMPTOMATIC", 5.0)
	var data: Dictionary = resp.to_dict()
	data["pending_cough_in"] = 1.5
	resp.from_dict(data)
	resp.apply_medication(Fx.medication())
	var events: Array[int] = []
	for _i: int in 60 * 2:
		resp.tick(DT, Fx.inputs(0.0, Enums.Gait.IDLE), 0.0)
		events.append_array(resp.take_events())
		if resp.pending_cough_in < 0.0:
			break
	assert_eq(events.size(), 1, "uma única saída de evento: o cancelamento")
	assert_eq(events[0] if not events.is_empty() else -1, RespiratoryModel.CoughEvent.CANCELLED,
		"com a bombinha a severidade cai abaixo de 0,55 no aviso: tosse cancelada")
	assert_almost_eq(resp.cough_cooldown_remaining, 0.0, TOLERANCE, "cancelar não inicia o cooldown da tosse")


func test_tosse_agendada_acontece_quando_a_severidade_se_mantem() -> void:
	var resp: RespiratoryModel = Fx.make_resp(12)
	Fx.set_resp(resp, 0.7, 0.0, "SYMPTOMATIC", 5.0)
	var data: Dictionary = resp.to_dict()
	data["pending_cough_in"] = 1.5
	resp.from_dict(data)
	var events: Array[int] = []
	var cough_at: float = -1.0
	var cooldown_at_cough: float = -1.0
	var elapsed: float = 0.0
	for _i: int in 60 * 3:
		resp.tick(DT, Fx.inputs(0.0, Enums.Gait.IDLE), 0.0)
		elapsed += DT
		for event: int in resp.take_events():
			events.append(event)
			if event == RespiratoryModel.CoughEvent.COUGH:
				cough_at = elapsed
				cooldown_at_cough = resp.cough_cooldown_remaining
	assert_eq(events, [RespiratoryModel.CoughEvent.COUGH], "sem bombinha, a tosse acontece")
	assert_true(cough_at >= 1.5 - 0.0001, "a tosse vem depois de cough_warning_time_s (1,5 s), obtido %.3f" % cough_at)
	assert_almost_eq(cooldown_at_cough, 4.0, TOLERANCE, "no tick da tosse, o cooldown começa em 4 s")


func test_to_dict_from_dict_preserva_todos_os_campos() -> void:
	var resp: RespiratoryModel = Fx.make_resp(10)
	_tick_seconds(resp, Fx.inputs(1.0, Enums.Gait.SPRINT), 60.0, 6.0)
	resp.apply_medication(Fx.medication())
	resp.apply_consumable(&"water")
	var data: Dictionary = resp.to_dict()
	var copy: RespiratoryModel = Fx.make_resp(99)
	copy.from_dict(data)
	assert_true(Fx.same_state(data, copy.to_dict()), "from_dict(to_dict()) reproduz o estado")
	assert_eq(copy.state, resp.state, "estado respiratório")
	assert_almost_eq(copy.recovery_progress, resp.recovery_progress, TOLERANCE, "recovery_progress recalculado")

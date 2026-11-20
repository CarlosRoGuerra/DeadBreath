extends TestCase
## F2-002 (DATA_STRUCTURES §1.3 e §6.1, COMPONENT_CONTRACTS §4.2): StressModel no nível de modelo.
## Ganhos por ameaça (somados por segundo), picos (susto, ferimento), decaimento com atraso de 4 s e 3/s
## (100 → 0 em ≈ 37,3 s), zona segura, faixas CALM..PANIC nos limiares e fórmula do susto. Autor: Physiological Systems Engineer.

const Fx := preload("res://tests/unit/physiology/fixtures/physio_fixture.gd")
const TOLERANCE: float = 0.01
const DT: float = 1.0 / 60.0


func _inputs_with(sample: ThreatSample, safe: bool = false) -> PhysiologyInputs:
	var entry: PhysiologyInputs = Fx.inputs(0.0, Enums.Gait.IDLE, false, sample)
	entry.in_safe_zone = safe
	return entry


func test_faixas_nos_limiares() -> void:
	var model: StressModel = Fx.make_stress(0.0)
	var cases: Array[Array] = [
		[0.0, Enums.StressBand.CALM], [24.9, Enums.StressBand.CALM],
		[25.0, Enums.StressBand.TENSE], [49.9, Enums.StressBand.TENSE],
		[50.0, Enums.StressBand.AFRAID], [74.9, Enums.StressBand.AFRAID],
		[75.0, Enums.StressBand.PANIC], [100.0, Enums.StressBand.PANIC],
	]
	for case: Array in cases:
		model.value = case[0]
		assert_eq(model.get_band(), case[1], "faixa em %s" % str(case[0]))


func test_ganhos_por_ameaca_somam_por_segundo() -> void:
	var seen: StressModel = Fx.make_stress(0.0)
	seen.tick(1.0, _inputs_with(Fx.threat(1.0, 0.0, false)))
	assert_almost_eq(seen.value, 15.0, TOLERANCE, "inimigo visto a 3 m: +15/s")
	var heard: StressModel = Fx.make_stress(0.0)
	heard.tick(1.0, _inputs_with(Fx.threat(0.0, 1.0, false)))
	assert_almost_eq(heard.value, 5.0, TOLERANCE, "inimigo ouvido com fator 1: +5/s")
	var chase: StressModel = Fx.make_stress(0.0)
	chase.tick(1.0, _inputs_with(Fx.threat(0.0, 0.0, true)))
	assert_almost_eq(chase.value, 20.0, TOLERANCE, "perseguição: +20/s")
	var all: StressModel = Fx.make_stress(0.0)
	all.tick(1.0, _inputs_with(Fx.threat(1.0, 1.0, true)))
	assert_almost_eq(all.value, 40.0, TOLERANCE, "somados: 15 + 5 + 20")


func test_decaimento_de_100_a_0_em_37_3_s() -> void:
	var model: StressModel = Fx.make_stress(0.0)
	model.add_spike(100.0)
	var ticks: int = 0
	while model.value > 0.0 and ticks < 60 * 60:
		model.tick(DT, _inputs_with(ThreatSample.new()))
		ticks += 1
	var seconds: float = ticks * DT
	note("decaimento do estresse de 100 a 0 sem ameaça: %.3f s (atraso 4 s + 100/3 s)" % seconds)
	assert_almost_eq(seconds, 4.0 + 100.0 / 3.0, 0.1, "4 s de atraso + 3/s: ≈ 37,3 s")


func test_atraso_de_decaimento_e_zona_segura() -> void:
	var model: StressModel = Fx.make_stress(50.0)
	model.time_since_threat = 0.0
	var quiet: PhysiologyInputs = _inputs_with(ThreatSample.new())
	var elapsed: float = 0.0
	while elapsed < 3.9:
		model.tick(DT, quiet)
		elapsed += DT
	assert_almost_eq(model.value, 50.0, TOLERANCE, "nenhuma queda antes de decay_delay_s (4 s)")
	var safe: StressModel = Fx.make_stress(50.0)
	safe.time_since_threat = 10.0
	safe.tick(1.0, _inputs_with(ThreatSample.new(), true))
	assert_almost_eq(safe.value, 42.0, TOLERANCE, "zona segura cai 8/s")


func test_ameaca_zera_o_atraso() -> void:
	var model: StressModel = Fx.make_stress(50.0)
	model.time_since_threat = 3.9
	model.tick(0.2, _inputs_with(Fx.threat(0.0, 0.0, true)))
	assert_almost_eq(model.time_since_threat, 0.0, TOLERANCE, "ameaça reinicia o contador")


func test_pico_de_susto_segue_a_formula() -> void:
	assert_almost_eq(StressModel.startle_spike_for_db(54.9), 0.0, TOLERANCE, "abaixo de 55 dB não há pico")
	assert_almost_eq(StressModel.startle_spike_for_db(55.0), 10.0, TOLERANCE, "55 dB: (55 − 55)/2 + 10 = 10")
	assert_almost_eq(StressModel.startle_spike_for_db(65.0), 15.0, TOLERANCE, "65 dB: 15")
	assert_almost_eq(StressModel.startle_spike_for_db(85.0), 25.0, TOLERANCE, "85 dB: 25 (teto)")
	assert_almost_eq(StressModel.startle_spike_for_db(200.0), 25.0, TOLERANCE, "acima do teto: 25")


func test_pico_de_ferimento_e_clamp() -> void:
	var model: StressModel = Fx.make_stress(90.0)
	model.add_spike(20.0)
	assert_almost_eq(model.value, 100.0, TOLERANCE, "pico acima de 100 é limitado a 100")
	model.add_spike(-5.0)
	assert_almost_eq(model.value, 100.0, TOLERANCE, "pico negativo é ignorado")


func test_to_dict_from_dict_preserva_todos_os_campos() -> void:
	var model: StressModel = Fx.make_stress(61.25)
	model.time_since_threat = 2.5
	var data: Dictionary = model.to_dict()
	var copy: StressModel = Fx.make_stress(0.0)
	copy.from_dict(data)
	assert_true(Fx.same_state(data, copy.to_dict()), "from_dict(to_dict()) reproduz o estado")

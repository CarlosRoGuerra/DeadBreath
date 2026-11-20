extends TestCase
## F2-001 (DATA_STRUCTURES §1.2 e §6.1, COMPONENT_CONTRACTS §4.2): StaminaModel no nível de modelo.
## Dreno de sprint (tanque cheio: 8,3 s ± 0,1), atraso de regeneração (1,2 s), regeneração por marcha e
## repouso, multiplicador do acoplamento, zona segura, histerese de exaustão (25) e limites 0..100 (PHY-INV-1).
## Autor: Physiological Systems Engineer.

const Fx := preload("res://tests/unit/physiology/fixtures/physio_fixture.gd")
const TOLERANCE: float = 0.01
const SPRINT_TOLERANCE_S: float = 0.1
const DT: float = 1.0 / 60.0


## Ganho de stamina depois de `seconds` de um tick de regeneração, partindo de `start` sem atraso.
func _gain_after(inputs: PhysiologyInputs, coupling: CouplingFactors, seconds: float, start: float = 50.0) -> float:
	var model: StaminaModel = Fx.make_stamina(start)
	var ticks: int = int(round(seconds / DT))
	for _i: int in ticks:
		model.tick(DT, inputs, coupling)
	return model.value - start


func test_tanque_cheio_sprint_dura_8_3_s() -> void:
	var model: StaminaModel = Fx.make_stamina()
	var sprint: PhysiologyInputs = Fx.inputs(Fx.SPRINT_EXERTION, Enums.Gait.SPRINT)
	var neutral: CouplingFactors = CouplingFactors.neutral()
	var ticks: int = 0
	while not model.exhausted and ticks < 60 * 20:
		model.tick(DT, sprint, neutral)
		ticks += 1
	var seconds: float = ticks * DT
	note("sprint de tanque cheio até esgotar a stamina: %.3f s (%d ticks a 1/60 s)" % [seconds, ticks])
	assert_true(model.exhausted, "o sprint esgota a stamina")
	assert_almost_eq(seconds, 100.0 / 12.0, SPRINT_TOLERANCE_S, "tanque cheio: 100 / 12 = 8,3 s ± 0,1")


func test_sem_regeneracao_durante_regen_delay() -> void:
	var model: StaminaModel = Fx.make_stamina(50.0)
	var neutral: CouplingFactors = CouplingFactors.neutral()
	model.tick(0.1, Fx.inputs(Fx.SPRINT_EXERTION, Enums.Gait.SPRINT), neutral)
	var after_sprint: float = model.value
	assert_almost_eq(after_sprint, 48.8, TOLERANCE, "um tick de sprint de 0,1 s gasta 1,2")
	var idle: PhysiologyInputs = Fx.inputs(0.0, Enums.Gait.IDLE)
	var elapsed: float = 0.0
	while elapsed < 1.1:
		model.tick(DT, idle, neutral)
		elapsed += DT
	assert_almost_eq(model.value, after_sprint, TOLERANCE, "nenhuma regeneração antes de regen_delay_s (1,2 s)")
	for _i: int in 60:
		model.tick(DT, idle, neutral)
	assert_true(model.value > after_sprint + 1.0, "a regeneração volta depois do atraso")


func test_regeneracao_por_marcha_e_repouso() -> void:
	var neutral: CouplingFactors = CouplingFactors.neutral()
	assert_almost_eq(_gain_after(Fx.inputs(0.0, Enums.Gait.IDLE), neutral, 1.0), 10.0, TOLERANCE, "parado em pé: 10/s")
	assert_almost_eq(_gain_after(Fx.inputs(0.1, Enums.Gait.SLOW), neutral, 1.0), 7.0, TOLERANCE, "andando devagar: 7/s")
	assert_almost_eq(_gain_after(Fx.inputs(0.2, Enums.Gait.WALK), neutral, 1.0), 4.0, TOLERANCE, "andando: 4/s")
	assert_almost_eq(_gain_after(Fx.inputs(0.0, Enums.Gait.IDLE, true), neutral, 1.0), 14.0, TOLERANCE, "agachado parado: 14/s")


func test_multiplicador_do_acoplamento_e_zona_segura() -> void:
	var half: CouplingFactors = CouplingFactors.new()
	half.stamina_regen_multiplier = 0.5
	assert_almost_eq(_gain_after(Fx.inputs(0.0, Enums.Gait.IDLE), half, 1.0), 5.0, TOLERANCE, "multiplicador 0,5 reduz a regeneração de 10 para 5")
	var safe: PhysiologyInputs = Fx.inputs(0.0, Enums.Gait.IDLE)
	safe.in_safe_zone = true
	assert_almost_eq(_gain_after(safe, CouplingFactors.neutral(), 1.0), 13.0, TOLERANCE, "zona segura: 10 × 1,3 = 13/s")


func test_histerese_de_exaustao_reabilita_em_25() -> void:
	var model: StaminaModel = Fx.make_stamina(0.1)
	var neutral: CouplingFactors = CouplingFactors.neutral()
	model.tick(DT, Fx.inputs(Fx.SPRINT_EXERTION, Enums.Gait.SPRINT), neutral)
	assert_true(model.exhausted, "zerar a stamina esgota")
	var walk: PhysiologyInputs = Fx.inputs(Fx.WALK_EXERTION, Enums.Gait.WALK)
	var reenabled_at: float = -1.0
	for _i: int in 60 * 60:
		var before: bool = model.exhausted
		model.tick(DT, walk, neutral)
		if before and not model.exhausted:
			reenabled_at = model.value
			break
	assert_true(reenabled_at >= 25.0, "o sprint volta só com stamina >= 25 (obtido %.3f)" % reenabled_at)
	assert_true(reenabled_at < 25.6, "o sprint volta logo ao chegar a 25 (obtido %.3f)" % reenabled_at)


func test_stamina_fica_entre_0_e_100() -> void:
	var model: StaminaModel = Fx.make_stamina(100.0)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 11
	var low: float = 100.0
	var high: float = 0.0
	for _i: int in 1200:
		var gait: Enums.Gait = Enums.Gait.values()[rng.randi_range(0, 3)]
		var coupling: CouplingFactors = CouplingFactors.new()
		coupling.stamina_regen_multiplier = rng.randf_range(0.0, 1.5)
		model.tick(DT, Fx.inputs(0.5, gait, rng.randf() < 0.3), coupling)
		low = minf(low, model.value)
		high = maxf(high, model.value)
	assert_true(low >= 0.0 and high <= 100.0, "stamina em [0, 100] (PHY-INV-1): mínimo %.3f, máximo %.3f" % [low, high])


func test_to_dict_from_dict_preserva_todos_os_campos() -> void:
	var model: StaminaModel = Fx.make_stamina(37.5)
	model.exhausted = true
	model.regen_delay_remaining = 0.7
	var data: Dictionary = model.to_dict()
	var copy: StaminaModel = Fx.make_stamina(100.0)
	copy.from_dict(data)
	assert_true(Fx.same_state(data, copy.to_dict()), "from_dict(to_dict()) reproduz o estado")
	assert_almost_eq(copy.value, 37.5, TOLERANCE, "valor")
	assert_true(copy.exhausted, "exaustão")
	assert_almost_eq(copy.regen_delay_remaining, 0.7, TOLERANCE, "atraso de regeneração")

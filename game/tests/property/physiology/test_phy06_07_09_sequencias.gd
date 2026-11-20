extends TestCase
## PHY-06, PHY-07 e PHY-09 (TEST_PLAN §2.2), em propriedade: 200 sequências aleatórias de 120 s de entradas
## (dt = 0,1 s, TEST_PLAN §1), seguidas de 60 s de repouso. Nível property (fora da suíte padrão, que tem de ficar
## abaixo de 10 s). Passa pelo PhysiologyComponent, a composição de produção, com os sinais reais.
##   PHY-06: no fim do repouso, severidade < 0,2 e estresse < 25 em todas as sequências.
##   PHY-07: toda tosse involuntária é precedida de cough_warning, com pelo menos 1,5 s de antecedência.
##   PHY-09: nenhum valor sai do intervalo (stamina e estresse 0..100; severidade 0..1; demais derivados).
## Autor: Physiological Systems Engineer.

const Fx := preload("res://tests/unit/physiology/fixtures/physio_fixture.gd")
const DIR: String = "res://content/data/physiology/"
const SEQUENCES: int = 200
const ACTIVE_S: float = 120.0
const REST_S: float = 60.0
const DT: float = 0.1
const WARNING_MIN_S: float = 1.5
const TIME_EPS: float = 0.000000001
const MAX_EXAMPLES: int = 5
const EPS: float = 0.000001

var _now: float = 0.0
var _pending_warning_s: float = -1.0
var _warnings: int = 0
var _coughs: int = 0
var _cancelled: int = 0
var _violations: PackedStringArray = PackedStringArray()


func _on_warning(_seconds: float) -> void:
	if _pending_warning_s >= 0.0:
		_flag("aviso sobreposto em t=%.1f s" % _now)
	_pending_warning_s = _now
	_warnings += 1


func _on_coughed(suppressed: bool) -> void:
	if suppressed:
		_cancelled += 1
		_pending_warning_s = -1.0
		return
	_coughs += 1
	if _pending_warning_s < 0.0:
		_flag("tosse sem aviso em t=%.1f s" % _now)
		return
	var lead: float = _now - _pending_warning_s
	if lead < WARNING_MIN_S - TIME_EPS:
		_flag("tosse com aviso de só %.3f s em t=%.1f s" % [lead, _now])
	_pending_warning_s = -1.0


func _flag(text: String) -> void:
	if _violations.size() < MAX_EXAMPLES:
		_violations.append(text)
	else:
		_violations.append("")


func _component(seed_value: int) -> PhysiologyComponent:
	var component: PhysiologyComponent = PhysiologyComponent.new()
	component.stamina_config = load(DIR + "stamina_config.tres") as StaminaConfig
	component.stress_config = load(DIR + "stress_config.tres") as StressConfig
	component.respiratory_config = load(DIR + "respiratory_config.tres") as RespiratoryConfig
	component.coupling_config = load(DIR + "coupling_config.tres") as CouplingConfig
	component.rng_seed = seed_value
	return component


## Verifica os limites de um instante (PHY-09). Limites com folga de ponto flutuante.
func _check_bounds(component: PhysiologyComponent, label: String) -> void:
	var snapshot: PhysiologySnapshot = component.get_snapshot()
	var coupling: CouplingFactors = component.get_coupling()
	var bad: PackedStringArray = PackedStringArray()
	if snapshot.stamina < -EPS or snapshot.stamina > 100.0 + EPS:
		bad.append("stamina %.4f" % snapshot.stamina)
	if snapshot.stress < -EPS or snapshot.stress > 100.0 + EPS:
		bad.append("estresse %.4f" % snapshot.stress)
	if snapshot.symptom_severity < -EPS or snapshot.symptom_severity > 1.0 + EPS:
		bad.append("severidade %.4f" % snapshot.symptom_severity)
	if snapshot.breathing_rate < 14.0 - EPS or snapshot.breathing_rate > 40.0 + EPS:
		bad.append("frequência %.4f" % snapshot.breathing_rate)
	if snapshot.wheezing_intensity < -EPS or snapshot.wheezing_intensity > 1.0 + EPS:
		bad.append("chiado %.4f" % snapshot.wheezing_intensity)
	if snapshot.cough_probability < -EPS or snapshot.cough_probability > 0.25 + EPS:
		bad.append("tosse/s %.4f" % snapshot.cough_probability)
	if snapshot.recovery_progress < -EPS or snapshot.recovery_progress > 1.0 + EPS:
		bad.append("recuperação %.4f" % snapshot.recovery_progress)
	if coupling.steadiness < -EPS or coupling.steadiness > 1.0 + EPS:
		bad.append("firmeza %.4f" % coupling.steadiness)
	if coupling.tremor_amplitude < -EPS or coupling.tremor_amplitude > 1.0 + EPS:
		bad.append("tremor %.4f" % coupling.tremor_amplitude)
	if coupling.max_sprint_multiplier < 0.75 - EPS or coupling.max_sprint_multiplier > 1.0 + EPS:
		bad.append("sprint %.4f" % coupling.max_sprint_multiplier)
	if coupling.stamina_regen_multiplier < 0.28 - EPS or coupling.stamina_regen_multiplier > 1.0 + EPS:
		bad.append("regeneração %.4f" % coupling.stamina_regen_multiplier)
	if not bad.is_empty():
		_flag("%s: %s" % [label, ", ".join(bad)])


## Entrada aleatória de um segmento: perfil de marcha, ameaça, bordas de zona segura, e eventos esporádicos.
func _run_active(component: PhysiologyComponent, rng: RandomNumberGenerator, seed_label: int) -> void:
	var profiles: Array[Array] = [
		[Enums.Gait.SPRINT, 1.0, false],
		[Enums.Gait.WALK, 0.2, false],
		[Enums.Gait.SLOW, 0.1, false],
		[Enums.Gait.IDLE, 0.0, true],
		[Enums.Gait.IDLE, 0.0, false],
		[Enums.Gait.WALK, 0.25, false],
	]
	var elapsed: float = 0.0
	var step_index: int = 0
	while elapsed < ACTIVE_S - EPS:
		var segment_s: float = rng.randf_range(2.0, 15.0)
		var profile: Array = profiles[rng.randi_range(0, profiles.size() - 1)]
		if rng.randf() < 0.1:
			component.add_startle(rng.randf_range(10.0, 25.0))
		if rng.randf() < 0.05:
			component.apply_medication(load(DIR + "medication_inhaler.tres") as MedicationProfile)
		var seen: float = rng.randf() if rng.randf() < 0.5 else 0.0
		var heard: float = rng.randf() if rng.randf() < 0.3 else 0.0
		var chase: bool = rng.randf() < 0.1
		var sample: ThreatSample = Fx.threat(seen, heard, chase)
		var gait: Enums.Gait = profile[0]
		var entry: PhysiologyInputs = Fx.inputs(float(profile[1]), gait, bool(profile[2]), sample)
		entry.in_safe_zone = rng.randf() < 0.2
		var segment_end: float = minf(elapsed + segment_s, ACTIVE_S)
		while elapsed < segment_end - EPS:
			_now = float(step_index) * DT
			component.step(DT, entry)
			_check_bounds(component, "t=%.1f s, sequência %d" % [_now, seed_label])
			elapsed += DT
			step_index += 1


func _run_rest(component: PhysiologyComponent, seed_label: int, start_index: int) -> void:
	var rest: PhysiologyInputs = Fx.inputs(0.0, Enums.Gait.IDLE, true)
	var steps: int = int(round(REST_S / DT))
	for offset: int in steps:
		_now = float(start_index + offset) * DT
		component.step(DT, rest)
		_check_bounds(component, "repouso t=%.1f s, sequência %d" % [_now, seed_label])


func test_phy06_07_09_duzentas_sequencias() -> void:
	var worst_severity: float = 0.0
	var worst_stress: float = 0.0
	var failing_recovery: int = 0
	var total_warnings: int = 0
	var total_coughs: int = 0
	var total_cancelled: int = 0
	for index: int in SEQUENCES:
		var seed_label: int = 10000 + index
		var component: PhysiologyComponent = _component(seed_label)
		component.cough_warning.connect(_on_warning)
		component.coughed.connect(_on_coughed)
		var rng: RandomNumberGenerator = RandomNumberGenerator.new()
		rng.seed = seed_label
		_now = 0.0
		_pending_warning_s = -1.0
		_warnings = 0
		_coughs = 0
		_cancelled = 0
		_run_active(component, rng, seed_label)
		var rest_start: int = int(round(ACTIVE_S / DT))
		_run_rest(component, seed_label, rest_start)
		var end: PhysiologySnapshot = component.get_snapshot()
		worst_severity = maxf(worst_severity, end.symptom_severity)
		worst_stress = maxf(worst_stress, end.stress)
		if not (end.symptom_severity < 0.2 and end.stress < 25.0):
			failing_recovery += 1
			_flag("PHY-06 sequência %d: fim com severidade %.4f e estresse %.4f" % [seed_label, end.symptom_severity, end.stress])
		total_warnings += _warnings
		total_coughs += _coughs
		total_cancelled += _cancelled
		component.cough_warning.disconnect(_on_warning)
		component.coughed.disconnect(_on_coughed)
		component.free()
	note("200 sequências (120 s ativos + 60 s de repouso, dt 0,1 s): avisos %d, tosses %d, tosses canceladas %d"
		% [total_warnings, total_coughs, total_cancelled])
	note("PHY-06: pior severidade no fim do repouso %.4f (limite 0,2); pior estresse %.4f (limite 25); sequências reprovadas %d"
		% [worst_severity, worst_stress, failing_recovery])
	assert_true(total_coughs >= 1, "as sequências exercitam a tosse involuntária")
	assert_eq(_violations.size(), 0, "violações em PHY-06/07/09: " + "; ".join(_violations))

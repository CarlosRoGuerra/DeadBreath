extends TestCase
## F2-011 (QA Engineer): estresse máximo constante por 10 min (36000 ticks a 60 Hz) no PhysiologyComponent de produção.
## Ameaça máxima vista e em perseguição, corrida sustentada (exertion 1). Duas variantes: (A) sem tratamento;
## (B) a bombinha aplicada a cada aviso de tosse, sem limite de doses (limite superior do abuso; o cooldown de 10 s
## continua valendo). Invariantes a cada 60 ticks: estresse 0..100, severidade 0..1, probabilidade 0..1, tremor >= 0,
## nenhum NaN. Mede tosses, avisos e exaustões. Escrito do zero pelo QA.

const CONFIG_DIR: String = "res://content/data/physiology/"
const DT: float = 1.0 / 60.0
const TICKS: int = 36000
const SAMPLE_EVERY: int = 60
const SEED: int = 99


func test_estresse_maximo_constante_por_10_min_sem_tratamento() -> void:
	var result: Dictionary = _run(false)
	note("sem tratamento: avisos=%d tosses=%d suprimidas=%d exaustoes=%d; estresse final=%.3f; severidade final=%.4f" % [
		int(result["avisos"]), int(result["tosses"]), int(result["suprimidas"]), int(result["exaustoes"]),
		float(result["estresse"]), float(result["severidade"])])
	assert_true(bool(result["invariantes"]), "sem tratamento: limites 0..100 / 0..1 e sem NaN durante 10 min")
	assert_almost_eq(float(result["estresse"]), 100.0, 0.01, "estresse sustentado no máximo (100) ao fim de 10 min")
	assert_true(int(result["tosses"]) >= 1, "em estresse máximo sustentado há tosse ao longo de 10 min")


func test_bombinha_a_cada_aviso_sem_limite_de_doses_nao_zera_a_tosse() -> void:
	var result: Dictionary = _run(true)
	note("com bombinha a cada aviso (sem limite de doses): avisos=%d tosses=%d suprimidas=%d aplicacoes=%d" % [
		int(result["avisos"]), int(result["tosses"]), int(result["suprimidas"]), int(result["aplicacoes"])])
	assert_true(bool(result["invariantes"]), "com bombinha: limites e sem NaN durante 10 min")
	assert_almost_eq(float(result["estresse"]), 100.0, 0.01, "a bombinha não tira o estresse do máximo")
	assert_true(int(result["aplicacoes"]) <= 60, "cooldown de 10 s: no máximo 60 aplicações em 10 min")


func _run(use_inhaler: bool) -> Dictionary:
	var physio: PhysiologyComponent = PhysiologyComponent.new()
	physio.stamina_config = load(CONFIG_DIR + "stamina_config.tres") as StaminaConfig
	physio.stress_config = load(CONFIG_DIR + "stress_config.tres") as StressConfig
	physio.respiratory_config = load(CONFIG_DIR + "respiratory_config.tres") as RespiratoryConfig
	physio.coupling_config = load(CONFIG_DIR + "coupling_config.tres") as CouplingConfig
	physio.rng_seed = SEED
	var profile: MedicationProfile = load(CONFIG_DIR + "medication_inhaler.tres") as MedicationProfile
	## Dicionário (e não variável local) porque lambdas do GDScript capturam variáveis simples por valor.
	var counts: Dictionary = {"avisos": 0, "tosses": 0, "suprimidas": 0, "exaustoes": 0, "aplicacoes": 0, "pendente": false}
	physio.cough_warning.connect(func(_seconds: float) -> void:
		counts["avisos"] = int(counts["avisos"]) + 1
		counts["pendente"] = true)
	physio.coughed.connect(func(suppressed: bool) -> void:
		if suppressed:
			counts["suprimidas"] = int(counts["suprimidas"]) + 1
		else:
			counts["tosses"] = int(counts["tosses"]) + 1)
	physio.stamina_depleted.connect(func() -> void:
		counts["exaustoes"] = int(counts["exaustoes"]) + 1)
	var invariants: bool = true
	var last: PhysiologySnapshot = null
	for tick: int in TICKS:
		physio.step(DT, _max_inputs())
		if use_inhaler and bool(counts["pendente"]):
			counts["pendente"] = false
			if physio.apply_medication(profile):
				counts["aplicacoes"] = int(counts["aplicacoes"]) + 1
		if tick % SAMPLE_EVERY == 0 or tick == TICKS - 1:
			last = physio.get_snapshot()
			invariants = invariants and _in_bounds(last)
	counts["invariantes"] = invariants
	counts["estresse"] = last.stress
	counts["severidade"] = last.symptom_severity
	return counts


func _in_bounds(snap: PhysiologySnapshot) -> bool:
	var values: Array[float] = [snap.stamina, snap.stress, snap.symptom_severity, snap.cough_probability,
		snap.recovery_progress, snap.wheezing_intensity, snap.breathing_rate]
	for value: float in values:
		if is_nan(value) or is_inf(value):
			return false
	if snap.stress < 0.0 or snap.stress > 100.0:
		return false
	if snap.symptom_severity < 0.0 or snap.symptom_severity > 1.0:
		return false
	if snap.cough_probability < 0.0 or snap.cough_probability > 1.0:
		return false
	if snap.stamina < 0.0 or snap.stamina > 100.0:
		return false
	return true


func _max_inputs() -> PhysiologyInputs:
	var inputs: PhysiologyInputs = PhysiologyInputs.new()
	var sample: ThreatSample = ThreatSample.new()
	sample.seen_proximity = 1.0
	sample.threat_level = 1.0
	sample.in_chase = true
	inputs.threat = sample
	inputs.exertion = 1.0
	inputs.gait = Enums.Gait.SPRINT
	inputs.is_resting = false
	return inputs

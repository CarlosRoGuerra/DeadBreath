extends TestCase
## F2-011 (QA Engineer): salvar e restaurar a fisiologia no meio de um aviso de tosse (em memória: to_dict/from_dict do
## PhysiologyComponent), e a bombinha durante o aviso. Configs de produção e semente fixa. Escrito do zero pelo QA.
## Hipóteses testadas: (a) a restauração repete a mesma história, sem perder nem duplicar o aviso pendente nem a
## tosse; (b) a bombinha no aviso só cancela a tosse pela severidade (abaixo de 0,55 no vencimento), nunca por fora.

const CONFIG_DIR: String = "res://content/data/physiology/"
const DT: float = 1.0 / 60.0
const ACTIVE_TICKS: int = 1200
const TOTAL_TICKS: int = 3000
const SEED: int = 4242
const SEVERITY_CANCEL: float = 0.55
const TOLERANCE: float = 0.000001
const BRANCH_TICKS: int = 240
const SEVERITY_AT_TICKS: int = 30

var _tick: int = 0
var _cough_now: bool = false
var _cough_suppressed: bool = false


func test_salvar_e_restaurar_no_meio_do_aviso_repete_a_mesma_historia() -> void:
	var a: PhysiologyComponent = _component(SEED)
	var events_a: Array[Dictionary] = []
	var snaps_a: Array[Dictionary] = []
	var saved: Dictionary = {}
	var save_tick: int = -1
	a.cough_warning.connect(_on_warning.bind(events_a))
	a.coughed.connect(_on_coughed.bind(events_a))
	for tick: int in TOTAL_TICKS:
		_tick = tick
		a.step(DT, _schedule(tick))
		snaps_a.append(_snap(a))
		if save_tick < 0 and not events_a.is_empty() and str(events_a[events_a.size() - 1]["tipo"]) == "aviso":
			saved = a.to_dict()
			save_tick = tick
	assert_true(save_tick >= 0, "a corrida sob ameaça produz um aviso de tosse para salvar nele")
	if save_tick < 0:
		return
	var b: PhysiologyComponent = _component(SEED + 1)
	b.from_dict(saved)
	var events_b: Array[Dictionary] = []
	b.cough_warning.connect(_on_warning.bind(events_b))
	b.coughed.connect(_on_coughed.bind(events_b))
	var max_diff: float = 0.0
	for tick: int in range(save_tick + 1, TOTAL_TICKS):
		_tick = tick
		b.step(DT, _schedule(tick))
		var sa: Dictionary = snaps_a[tick]
		var sb: Dictionary = _snap(b)
		max_diff = maxf(max_diff, absf(float(sa["estamina"]) - float(sb["estamina"])))
		max_diff = maxf(max_diff, absf(float(sa["estresse"]) - float(sb["estresse"])))
		max_diff = maxf(max_diff, absf(float(sa["severidade"]) - float(sb["severidade"])))
		if int(sa["estado"]) != int(sb["estado"]):
			max_diff = maxf(max_diff, 1.0)
	var after_a: Array[Dictionary] = []
	for event: Dictionary in events_a:
		if int(event["tick"]) > save_tick:
			after_a.append(event)
	note("aviso no quadro %d; eventos após o salvamento: A=%d B=%d; maior diferença de estado: %.9f" % [
		save_tick, after_a.size(), events_b.size(), max_diff])
	assert_true(max_diff <= TOLERANCE, "restaurado no meio do aviso, o estado segue idêntico ao contínuo")
	assert_eq(_strip(after_a), _strip(events_b), "a tosse e o aviso seguintes acontecem no mesmo quadro nas duas linhas")


func test_bombinha_no_aviso_so_cancela_pela_severidade() -> void:
	var a: PhysiologyComponent = _component(SEED)
	var events_a: Array[Dictionary] = []
	var saved: Dictionary = {}
	var save_tick: int = -1
	a.cough_warning.connect(_on_warning.bind(events_a))
	for tick: int in TOTAL_TICKS:
		_tick = tick
		a.step(DT, _schedule(tick))
		if save_tick < 0 and not events_a.is_empty():
			saved = a.to_dict()
			save_tick = tick
			break
	assert_true(save_tick >= 0, "há um aviso de tosse para usar a bombinha nele")
	if save_tick < 0:
		return
	var profile: MedicationProfile = load(CONFIG_DIR + "medication_inhaler.tres") as MedicationProfile
	var branch_x: Dictionary = _branch(saved, save_tick, null)
	var branch_y: Dictionary = _branch(saved, save_tick, profile)
	note("sem bombinha: %s; com bombinha no aviso: %s" % [str(branch_x["resumo"]), str(branch_y["resumo"])])
	assert_true(bool(branch_y["aplicada"]), "a bombinha é aceita no aviso (sem cooldown)")
	assert_true(_consistent(branch_x), "sem bombinha: tosse suprimida se e só se a severidade estava abaixo de 0,55")
	assert_true(_consistent(branch_y), "com bombinha: tosse suprimida se e só se a severidade estava abaixo de 0,55")
	assert_true(float(branch_y["sev_30"]) < float(branch_x["sev_30"]),
		"a bombinha reduz a severidade mais que o curso natural nos 0,5 s seguintes")


## Ramo a partir do estado salvo no aviso: aplica (ou não) a bombinha antes do primeiro quadro, roda 4 s e mede o
## primeiro desfecho de tosse com a severidade do próprio quadro em que foi emitido.
func _branch(saved: Dictionary, save_tick: int, profile: MedicationProfile) -> Dictionary:
	var physio: PhysiologyComponent = _component(SEED + 7)
	physio.from_dict(saved)
	var applied: bool = false
	if profile != null:
		applied = physio.apply_medication(profile)
	physio.coughed.connect(_on_cough_flag)
	var outcome: Dictionary = {}
	var sev_30: float = -1.0
	for index: int in BRANCH_TICKS:
		_tick = save_tick + 1 + index
		_cough_now = false
		physio.step(DT, _schedule(_tick))
		var severity: float = physio.get_snapshot().symptom_severity
		if index == SEVERITY_AT_TICKS - 1:
			sev_30 = severity
		if _cough_now and outcome.is_empty():
			outcome = {"suppressed": _cough_suppressed, "severidade": severity, "tick": _tick}
	physio.coughed.disconnect(_on_cough_flag)
	var resumo: String = "sem evento de tosse em 4 s"
	if not outcome.is_empty():
		resumo = "%s no quadro %d, severidade %.4f" % [
			"tosse suprimida" if bool(outcome["suppressed"]) else "tosse ocorreu",
			int(outcome["tick"]), float(outcome["severidade"])]
	return {"resumo": resumo, "outcome": outcome, "sev_30": sev_30, "aplicada": applied}


func _on_cough_flag(suppressed: bool) -> void:
	_cough_now = true
	_cough_suppressed = suppressed


func _consistent(branch: Dictionary) -> bool:
	var outcome: Dictionary = branch["outcome"]
	if outcome.is_empty():
		return true
	var suppressed: bool = bool(outcome["suppressed"])
	var below: bool = float(outcome["severidade"]) < SEVERITY_CANCEL
	return suppressed == below


func _component(seed_value: int) -> PhysiologyComponent:
	var physio: PhysiologyComponent = PhysiologyComponent.new()
	physio.stamina_config = load(CONFIG_DIR + "stamina_config.tres") as StaminaConfig
	physio.stress_config = load(CONFIG_DIR + "stress_config.tres") as StressConfig
	physio.respiratory_config = load(CONFIG_DIR + "respiratory_config.tres") as RespiratoryConfig
	physio.coupling_config = load(CONFIG_DIR + "coupling_config.tres") as CouplingConfig
	physio.rng_seed = seed_value
	return physio


## Corrida sob ameaça por 20 s, depois repouso sob ameaça (um aviso tem chance de ocorrer nos dois).
func _schedule(tick: int) -> PhysiologyInputs:
	var inputs: PhysiologyInputs = PhysiologyInputs.new()
	var sample: ThreatSample = ThreatSample.new()
	var active: bool = tick < ACTIVE_TICKS
	sample.seen_proximity = 1.0 if active else 0.5
	sample.threat_level = sample.seen_proximity
	sample.in_chase = active
	inputs.threat = sample
	inputs.exertion = 1.0 if active else 0.0
	inputs.gait = Enums.Gait.SPRINT if active else Enums.Gait.IDLE
	inputs.is_resting = not active
	return inputs


func _snap(physio: PhysiologyComponent) -> Dictionary:
	var snap: PhysiologySnapshot = physio.get_snapshot()
	return {"estamina": snap.stamina, "estresse": snap.stress, "severidade": snap.symptom_severity,
		"estado": int(snap.respiratory_state)}


func _on_warning(seconds_until: float, events: Array[Dictionary]) -> void:
	events.append({"tick": _tick, "tipo": "aviso", "suppressed": false, "severidade": -1.0, "s": seconds_until})


func _on_coughed(suppressed: bool, events: Array[Dictionary]) -> void:
	events.append({"tick": _tick, "tipo": "tosse", "suppressed": suppressed, "severidade": -1.0})


func _strip(events: Array[Dictionary]) -> String:
	var parts: PackedStringArray = PackedStringArray()
	for event: Dictionary in events:
		parts.append("%d:%s:%s" % [int(event["tick"]), str(event["tipo"]), str(event["suppressed"])])
	return ";".join(parts)

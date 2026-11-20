extends RefCounted
## Fixture dos testes de fisiologia (F2-001..F2-004). Carrega os .tres padrão, monta os modelos L1 com a mesma
## composição do PhysiologyComponent (Rig, abaixo) e cria entradas. Pasta "fixtures": o runner não a descobre.
## Autor: Physiological Systems Engineer.

const DIR: String = "res://content/data/physiology/"
## Passo de física da produção (60 Hz) e passo das propriedades (TEST_PLAN §1: dt = 0,1 s).
const DT_FRAME: float = 1.0 / 60.0
const DT_PROPERTY: float = 0.1
const SPRINT_EXERTION: float = 1.0
const WALK_EXERTION: float = 0.2


## Composição igual à do PhysiologyComponent: stamina, estresse, respiração e acoplamento, com um RNG.
class Rig extends RefCounted:
	var stamina: StaminaModel = null
	var stress: StressModel = null
	var resp: RespiratoryModel = null
	var rng: RandomNumberGenerator = null
	var coupling: CouplingFactors = null
	var coupling_config: CouplingConfig = null

	func step(dt: float, inputs: PhysiologyInputs) -> void:
		stamina.tick(dt, inputs, coupling)
		stress.tick(dt, inputs)
		resp.tick(dt, inputs, stress.value)
		coupling = PhysiologyCoupling.compute(stamina, stress, resp, coupling_config)


static func make_rig(seed_value: int) -> Rig:
	var rig: Rig = Rig.new()
	rig.rng = RandomNumberGenerator.new()
	rig.rng.seed = seed_value
	rig.coupling_config = load(DIR + "coupling_config.tres") as CouplingConfig
	rig.stamina = StaminaModel.new(load(DIR + "stamina_config.tres") as StaminaConfig)
	rig.stress = StressModel.new(load(DIR + "stress_config.tres") as StressConfig)
	rig.resp = RespiratoryModel.new(load(DIR + "respiratory_config.tres") as RespiratoryConfig, rig.rng)
	rig.coupling = PhysiologyCoupling.compute(rig.stamina, rig.stress, rig.resp, rig.coupling_config)
	return rig


static func make_stamina(value: float = 100.0) -> StaminaModel:
	var model: StaminaModel = StaminaModel.new(load(DIR + "stamina_config.tres") as StaminaConfig)
	model.value = value
	return model


static func make_stress(value: float = 0.0) -> StressModel:
	var model: StressModel = StressModel.new(load(DIR + "stress_config.tres") as StressConfig)
	model.value = value
	return model


static func make_resp(seed_value: int) -> RespiratoryModel:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	return RespiratoryModel.new(load(DIR + "respiratory_config.tres") as RespiratoryConfig, rng)


static func medication() -> MedicationProfile:
	return load(DIR + "medication_inhaler.tres") as MedicationProfile


static func threat(seen: float = 0.0, heard: float = 0.0, chase: bool = false) -> ThreatSample:
	var sample: ThreatSample = ThreatSample.new()
	sample.seen_proximity = seen
	sample.heard_factor = heard
	sample.in_chase = chase
	sample.threat_level = maxf(seen, 0.5 * heard)
	if chase:
		sample.threat_level = 1.0
	return sample


static func inputs(exertion: float, gait: Enums.Gait, resting: bool = false, sample: ThreatSample = null) -> PhysiologyInputs:
	var entry: PhysiologyInputs = PhysiologyInputs.new()
	entry.exertion = exertion
	entry.gait = gait
	entry.is_resting = resting
	entry.threat = sample if sample != null else ThreatSample.new()
	return entry


## Altera campos do modelo respiratório pelo caminho de persistência (from_dict), sem tocar em estado interno.
static func set_resp(resp: RespiratoryModel, severity: float, exertion_ema: float, state_key: String,
		dwell: float = 5.0) -> void:
	var data: Dictionary = resp.to_dict()
	data["severity"] = severity
	data["exertion_ema"] = exertion_ema
	data["state"] = state_key
	data["state_dwell"] = dwell
	data["peak_severity"] = severity
	resp.from_dict(data)


## Estresse que produz o alvo de severidade `target` com a EMA dada (sem alívio). Inverso de DATA §1.4.
static func stress_for_target(target: float, exertion_ema: float) -> float:
	var stress_term: float = (target - 0.7 * exertion_ema) / 0.4
	return 100.0 * (0.3 + 0.7 * stress_term)


## Compara dois dicionários de estado (PER-07, PHY-08): mesmas chaves e mesmos valores, exatamente.
static func same_state(a: Dictionary, b: Dictionary) -> bool:
	return a == b


## Estado completo de um rig para comparação (PHY-08): modelos e RNG.
static func snapshot_of(rig: Rig) -> Dictionary:
	return {
		"stamina": rig.stamina.to_dict(),
		"stress": rig.stress.to_dict(),
		"resp": rig.resp.to_dict(),
		"rng": str(rig.rng.state),
	}


## PHY-08: dois rigs com a mesma semente e as mesmas entradas, por `seconds` a 1/60 s. Fases de 20 s: sprint com
## ameaça contínua; parado com ameaça aleatória; repouso; sprint de novo; parado. Devolve [divergências, tosses, ticks].
static func determinism_run(seed_value: int, seconds: float) -> Array:
	var first: Rig = make_rig(seed_value)
	var second: Rig = make_rig(seed_value)
	var driver: RandomNumberGenerator = RandomNumberGenerator.new()
	driver.seed = 5
	var mismatches: int = 0
	var coughs: int = 0
	var ticks: int = int(round(seconds / DT_FRAME))
	for tick: int in ticks:
		var phase: int = int(float(tick) / 1200.0) % 5
		var entry: PhysiologyInputs
		if phase == 0 or phase == 3:
			entry = inputs(SPRINT_EXERTION, Enums.Gait.SPRINT, false, threat(1.0, 0.0, false))
		elif phase == 1:
			entry = inputs(0.0, Enums.Gait.IDLE, false, threat(driver.randf(), 0.0, false))
		elif phase == 2:
			entry = inputs(0.0, Enums.Gait.IDLE, true)
		else:
			entry = inputs(0.0, Enums.Gait.IDLE, false)
		first.step(DT_FRAME, entry)
		second.step(DT_FRAME, entry)
		for event: int in first.resp.take_events():
			if event == RespiratoryModel.CoughEvent.COUGH:
				coughs += 1
		second.resp.take_events()
		if not same_state(snapshot_of(first), snapshot_of(second)):
			mismatches += 1
	return [mismatches, coughs, ticks]


## PHY-11: severidade em cada `interval_s` até `total_s`, para um perfil fixo (sprint com ameaça, depois repouso
## agachado), com o passo `dt`.
static func severity_checkpoints(dt: float, total_s: float, interval_s: float) -> Array[float]:
	var rig: Rig = make_rig(1111)
	var out: Array[float] = []
	var elapsed: float = 0.0
	var next_checkpoint: float = interval_s
	var steps: int = int(round(total_s / dt))
	for _i: int in steps:
		var entry: PhysiologyInputs
		if elapsed < total_s * 0.5:
			var pressure: ThreatSample = threat(1.0 if elapsed >= total_s * 0.16 and elapsed < total_s * 0.33 else 0.0, 0.0, false)
			entry = inputs(1.0, Enums.Gait.SPRINT, false, pressure)
		else:
			entry = inputs(0.0, Enums.Gait.IDLE, true)
		rig.step(dt, entry)
		elapsed += dt
		if elapsed + 0.000001 >= next_checkpoint:
			out.append(rig.resp.symptom_severity)
			next_checkpoint += interval_s
	return out


## --- PER-07: estado completo para salvar e carregar (usado pela versão curta e pela longa) ---

const PER07_GROUPS: Array[String] = ["stamina", "stress", "resp"]


static func payload_of(rig: Rig) -> Dictionary:
	return {
		"stamina": rig.stamina.to_dict(),
		"stress": rig.stress.to_dict(),
		"resp": rig.resp.to_dict(),
		"rng": str(rig.rng.state),
	}


## Carrega o estado em um rig, pelo contrato to_dict/from_dict, em memória (exato).
static func load_payload(rig: Rig, payload: Dictionary) -> void:
	var stamina_data: Dictionary = payload["stamina"]
	var stress_data: Dictionary = payload["stress"]
	var resp_data: Dictionary = payload["resp"]
	rig.stamina.from_dict(stamina_data)
	rig.stress.from_dict(stress_data)
	rig.resp.from_dict(resp_data)
	rig.rng.state = int(str(payload["rng"]))
	rig.coupling = PhysiologyCoupling.compute(rig.stamina, rig.stress, rig.resp, rig.coupling_config)


## Descrições dos campos que diferem entre dois payloads (vazio = iguais, campo a campo).
static func payload_mismatches(a: Dictionary, b: Dictionary, label: String) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	for group: String in PER07_GROUPS:
		var left: Dictionary = a[group]
		var right: Dictionary = b[group]
		for key: String in left.keys():
			if left[key] != right[key]:
				out.append("%s: %s.%s" % [label, group, key])
	if str(a["rng"]) != str(b["rng"]):
		out.append("%s: estado do RNG" % label)
	return out


## Quantos campos mudam numa ida e volta por um transporte de texto ("json", "var" ou "b64"). Medida, não critério.
static func transport_drift(payload: Dictionary, transport: String) -> int:
	var parsed: Dictionary = {}
	if transport == "json":
		parsed = JSON.parse_string(JSON.stringify(payload))
	elif transport == "var":
		parsed = str_to_var(var_to_str(payload))
	else:
		parsed = Marshalls.base64_to_variant(Marshalls.variant_to_base64(payload))
	var drift: int = 0
	for group: String in PER07_GROUPS:
		var before: Dictionary = payload[group]
		var after: Dictionary = parsed[group]
		for key: String in before.keys():
			if before[key] != after[key]:
				drift += 1
	if str(payload["rng"]) != str(parsed["rng"]):
		drift += 1
	return drift


## Continua os dois rigs com as mesmas entradas, por `ticks` ticks, comparando todos os campos a cada tick.
## Devolve [divergências, avisos, tosses, tosses canceladas].
static func continue_and_compare(original: Rig, restored: Rig, ticks: int) -> Array:
	var mismatches: int = 0
	var events: Array[int] = [0, 0, 0]
	var driver: RandomNumberGenerator = RandomNumberGenerator.new()
	driver.seed = 77
	for _tick: int in ticks:
		var pressure: float = driver.randf() if driver.randf() < 0.7 else 0.0
		var entry: PhysiologyInputs = inputs(driver.randf(), Enums.Gait.WALK, driver.randf() < 0.3, threat(pressure, 0.0, false))
		original.step(DT_FRAME, entry)
		restored.step(DT_FRAME, entry)
		for event: int in original.resp.take_events():
			events[event] += 1
		restored.resp.take_events()
		if not same_state(payload_of(original), payload_of(restored)):
			mismatches += 1
	return [mismatches, events[0], events[1], events[2]]


## Sprint com ameaça contínua: o estresse sobe a 100 e a severidade passa de 0,55, onde a tosse tem risco.
static func pressured_sprint() -> PhysiologyInputs:
	return inputs(SPRINT_EXERTION, Enums.Gait.SPRINT, false, threat(1.0, 0.0, false))


## Ponto (a) de PER-07: avança até haver aviso de tosse agendado, dá bombinha e água, e devolve o rig.
static func run_to_pending_cough(seed_value: int, max_ticks: int) -> Rig:
	var rig: Rig = make_rig(seed_value)
	var sprint: PhysiologyInputs = pressured_sprint()
	for _tick: int in max_ticks:
		rig.step(DT_FRAME, sprint)
		if rig.resp.pending_cough_in >= 0.0:
			rig.resp.apply_medication(medication())
			rig.resp.apply_consumable(&"water")
			rig.step(DT_FRAME, sprint)
			return rig
	return null


## Ponto (b) de PER-07: avança até a primeira tosse involuntária, e devolve o rig (cooldown de tosse ativo).
static func run_to_cough(seed_value: int, max_ticks: int) -> Rig:
	var rig: Rig = make_rig(seed_value)
	var sprint: PhysiologyInputs = pressured_sprint()
	for _tick: int in max_ticks:
		rig.step(DT_FRAME, sprint)
		for event: int in rig.resp.take_events():
			if event == RespiratoryModel.CoughEvent.COUGH:
				return rig
	return null


## Oscila o valor-alvo em torno de `center` (±wobble) a cada `period` / 2 e devolve as transições de estado
## [segundo, nome do estado]. O alvo é controlado pelo estresse, com a EMA fixa (entrada = EMA).
static func oscillate(start_state: String, center: float, ema: float, seconds: float, period: float, wobble: float) -> Array:
	var resp: RespiratoryModel = make_resp(810)
	set_resp(resp, center, ema, start_state, 1.0)
	var entry: PhysiologyInputs = inputs(ema, Enums.Gait.WALK)
	var transitions: Array = []
	var last: Enums.RespiratoryState = resp.state
	var elapsed: float = 0.0
	while elapsed < seconds:
		var high: bool = fmod(elapsed, period) < period * 0.5
		var target: float = center + (wobble if high else -wobble)
		resp.tick(DT_FRAME, entry, stress_for_target(target, ema))
		elapsed += DT_FRAME
		if resp.state != last:
			transitions.append([elapsed, RespiratoryModel.state_name(resp.state)])
			last = resp.state
	return transitions

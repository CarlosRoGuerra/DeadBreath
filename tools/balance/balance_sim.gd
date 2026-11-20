extends SceneTree
## Simulação de balanceamento headless (F2-008, Physiological Systems Engineer).
## Roda cenários padrão sobre os modelos L1 de sim/physiology (StaminaModel, StressModel, RespiratoryModel,
## PhysiologyCoupling), com semente fixa e passo de 1/60 s, e grava um CSV por cenário e um resumo legível.
## Não usa cena, autoload nem PhysiologyComponent (ele referencia o autoload Log, que não existe com -s):
## repete a ordem de tick do componente (estamina → estresse → respiração → acoplamento) e a regra de gasp de
## PhysiologyComponent.add_startle. O sprint segue o motor em circuito fechado: só sprinta se o acoplamento do
## tick anterior permitir (como o limite do tick seguinte em COMPONENT_CONTRACTS §1).
## Esforço e velocidade dos perfis seguem as constantes de PlayerMotor (DATA §1.1). Os cenários de crise usam um
## esforço contínuo sintético de 0,9 (fuga sem sprint), declarado no resumo.
##
## Uso (ver run_balance.ps1):
##   godot --headless --path game -s <este arquivo> -- --out=<pasta> [--config=<pasta dos .tres>]
##         [--prefix=F2-008_] [--only=<cenário>]
## Sai com 0 se gravou os arquivos; 2 em erro de argumento ou de configuração.

const DT: float = 1.0 / 60.0
## Uma amostra a cada 6 ticks (10 por segundo). Eventos entre amostras entram na linha seguinte.
const SAMPLE_TICKS: int = 6
const DEFAULT_CONFIG_DIR: String = "res://content/data/physiology/"
const DEFAULT_PREFIX: String = "F2-008_"
const SPRINT_SPEED_MS: float = 4.8
const WALK_SPEED_MS: float = 1.6
const SLOW_SPEED_MS: float = 0.9
const SPRINT_EXERTION: float = 1.0
const WALK_EXERTION: float = 0.2
const CRISIS_EXERTION: float = 0.9
const STARTLE_DB: float = 85.0
const RECOVERED_SEVERITY: float = 0.2
const MEDICATION_WINDOW_TICKS: int = 180
const EPS: float = 0.0000001
const CSV_HEADER: String = "tempo_s,marcha,esforco,velocidade_ms,distancia_m,estamina,estresse,faixa,severidade,estado,frequencia_irpm,chiado,risco_tosse_s,sprint_permitido,sprint_max,regeneracao_mult,firmeza,eventos"
const GAIT_NAMES: Array = ["parado", "devagar", "andando", "correndo"]

## Cenários padrão: duração (s) e fim do estímulo (s), a partir do qual se mede a recuperação.
const SCENARIOS: Array = ["sprint_exaustao", "susto_estresse_alto", "crise_tosse_recuperacao", "bombinha_na_crise", "perseguicao_continua"]
const SCENARIO_DURATION_S: Dictionary = {
	"sprint_exaustao": 60.0,
	"susto_estresse_alto": 30.0,
	"crise_tosse_recuperacao": 90.0,
	"bombinha_na_crise": 60.0,
	"perseguicao_continua": 60.0,
}
const STIMULUS_END_S: Dictionary = {
	"sprint_exaustao": 12.0,
	"susto_estresse_alto": 6.5,
	"crise_tosse_recuperacao": 25.0,
	"bombinha_na_crise": 25.0,
	"perseguicao_continua": 40.0,
}
const SCENARIO_NOTES: Dictionary = {
	"sprint_exaustao": "sprint contínuo até 12 s (depois para); o motor só sprinta se o acoplamento permitir",
	"susto_estresse_alto": "parado em pé; quatro sustos de 85 dB (pico 25) em 5,0; 5,5; 6,0 e 6,5 s",
	"crise_tosse_recuperacao": "esforço sintético 0,9 com inimigo visto a 3 m até 25 s; depois repouso agachado sem ameaça",
	"bombinha_na_crise": "igual à crise; bombinha em 15 s; depois repouso agachado",
	"perseguicao_continua": "andando (esforço 0,2) com perseguição ativa até 40 s; depois parado e sem ameaça",
}


## Um tick: esforço, marcha e ameaça, além de pico e bombinha previstos para o tick.
class Plan extends RefCounted:
	var entry: PhysiologyInputs = null
	var spikes: Array[float] = []
	var medication: bool = false


## Modelos de um cenário, na ordem do PhysiologyComponent.
class Rig extends RefCounted:
	var stamina: StaminaModel = null
	var stress: StressModel = null
	var resp: RespiratoryModel = null
	var coupling: CouplingFactors = null
	var coupling_config: CouplingConfig = null

	func step(dt: float, entry: PhysiologyInputs) -> void:
		stamina.tick(dt, entry, coupling)
		stress.tick(dt, entry)
		resp.tick(dt, entry, stress.value)
		coupling = PhysiologyCoupling.compute(stamina, stress, resp, coupling_config)


## Configs carregadas do diretório de .tres (ou do padrão de produção).
class Configs extends RefCounted:
	var stamina: StaminaConfig = null
	var stress: StressConfig = null
	var respiratory: RespiratoryConfig = null
	var coupling: CouplingConfig = null
	var medication: MedicationProfile = null


func _initialize() -> void:
	var options: Dictionary = _parse_args()
	var out_dir: String = String(options["out"])
	if out_dir.is_empty():
		printerr("balance_sim: falta --out=<pasta>")
		quit(2)
		return
	var configs: Configs = _load_configs(String(options["config"]))
	if configs == null:
		quit(2)
		return
	if not DirAccess.dir_exists_absolute(out_dir):
		DirAccess.make_dir_recursive_absolute(out_dir)
	var prefix: String = String(options["prefix"])
	var only: String = String(options["only"])
	var summary: PackedStringArray = PackedStringArray()
	for scenario_variant: Variant in SCENARIOS:
		var scenario: String = String(scenario_variant)
		if not only.is_empty() and only != scenario:
			continue
		var result: Dictionary = _run(scenario, configs)
		var rows: PackedStringArray = result["rows"]
		_write_text(out_dir.path_join(prefix + scenario + ".csv"), "\n".join(rows) + "\n")
		var lines: PackedStringArray = result["summary"]
		summary.append_array(lines)
		summary.append("")
	var text: String = "\n".join(summary) + "\n"
	_write_text(out_dir.path_join(prefix + "resumo.txt"), text)
	print(text)
	quit(0)


## Argumentos depois de "--" na linha de comando do Godot.
func _parse_args() -> Dictionary:
	var options: Dictionary = {"out": "", "config": DEFAULT_CONFIG_DIR, "prefix": DEFAULT_PREFIX, "only": ""}
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			options["out"] = arg.trim_prefix("--out=")
		elif arg.begins_with("--config="):
			options["config"] = arg.trim_prefix("--config=")
		elif arg.begins_with("--prefix="):
			options["prefix"] = arg.trim_prefix("--prefix=")
		elif arg.begins_with("--only="):
			options["only"] = arg.trim_prefix("--only=")
	return options


func _load_configs(dir: String) -> Configs:
	var configs: Configs = Configs.new()
	configs.stamina = _load_resource(dir, "stamina_config.tres") as StaminaConfig
	configs.stress = _load_resource(dir, "stress_config.tres") as StressConfig
	configs.respiratory = _load_resource(dir, "respiratory_config.tres") as RespiratoryConfig
	configs.coupling = _load_resource(dir, "coupling_config.tres") as CouplingConfig
	configs.medication = _load_resource(dir, "medication_inhaler.tres") as MedicationProfile
	var missing: PackedStringArray = PackedStringArray()
	if configs.stamina == null:
		missing.append("stamina_config.tres")
	if configs.stress == null:
		missing.append("stress_config.tres")
	if configs.respiratory == null:
		missing.append("respiratory_config.tres")
	if configs.coupling == null:
		missing.append("coupling_config.tres")
	if configs.medication == null:
		missing.append("medication_inhaler.tres")
	if not missing.is_empty():
		printerr("balance_sim: configs ausentes em %s: %s" % [dir, ", ".join(missing)])
		return null
	return configs


## Carrega do disco sem cache (o .tres editado é lido como está).
func _load_resource(dir: String, file_name: String) -> Resource:
	return ResourceLoader.load(dir.path_join(file_name), "", ResourceLoader.CACHE_MODE_IGNORE) as Resource


func _run(scenario: String, configs: Configs) -> Dictionary:
	var rig: Rig = _make_rig(configs)
	var stress_config: StressConfig = configs.stress
	var duration: float = float(SCENARIO_DURATION_S[scenario])
	var stimulus_end: float = float(STIMULUS_END_S[scenario])
	var ticks: int = int(round(duration / DT))
	var rows: PackedStringArray = PackedStringArray([CSV_HEADER])
	var pending: PackedStringArray = PackedStringArray()
	var first: Dictionary = {}
	var counts: Dictionary = {}
	var distance: float = 0.0
	var stress_max: float = 0.0
	var stress_max_t: float = 0.0
	var severity_max: float = 0.0
	var severity_max_t: float = 0.0
	var stamina_min: float = 100.0
	var stamina_min_t: float = 0.0
	var recovered_t: float = -1.0
	var risen: bool = false
	var medication_tick: int = -1
	var medication_severity: float = 0.0
	var reduction_3s: float = -1.0
	var prev_band: int = int(rig.stress.get_band())
	var prev_state: int = int(rig.resp.state)
	var prev_exhausted: bool = rig.stamina.exhausted
	for tick: int in ticks:
		var t: float = float(tick) * DT
		var plan: Plan = _plan(scenario, t, rig)
		for amount: float in plan.spikes:
			var stress_before: float = rig.stress.value
			rig.stress.add_spike(amount)
			if amount >= stress_config.gasp_min_spike - EPS and stress_before >= stress_config.gasp_min_stress - EPS:
				_note(first, counts, pending, "gasp", t)
		if plan.medication:
			rig.resp.apply_medication(configs.medication)
			_note(first, counts, pending, "bombinha", t)
			medication_tick = tick
			medication_severity = rig.resp.symptom_severity
		var speed: float = _speed(plan.entry.gait, rig.coupling.max_sprint_multiplier)
		var sprint_allowed: bool = rig.coupling.sprint_allowed
		var max_sprint: float = rig.coupling.max_sprint_multiplier
		var regen_mult: float = rig.coupling.stamina_regen_multiplier
		var steadiness_before: float = rig.coupling.steadiness
		rig.step(DT, plan.entry)
		var t_end: float = float(tick + 1) * DT
		distance += speed * DT
		var band: int = int(rig.stress.get_band())
		if band != prev_band:
			_note(first, counts, pending, "faixa:%s" % _band_name(band), t_end)
			prev_band = band
		var state: int = int(rig.resp.state)
		if state != prev_state:
			_note(first, counts, pending, "estado:%s" % RespiratoryModel.state_name(rig.resp.state), t_end)
			prev_state = state
		if rig.stamina.exhausted != prev_exhausted:
			_note(first, counts, pending, "estamina_zerada" if rig.stamina.exhausted else "estamina_recuperada", t_end)
			prev_exhausted = rig.stamina.exhausted
		for event: int in rig.resp.take_events():
			if event == RespiratoryModel.CoughEvent.WARNING:
				_note(first, counts, pending, "tosse_aviso", t_end)
			elif event == RespiratoryModel.CoughEvent.COUGH:
				_note(first, counts, pending, "tosse", t_end)
			else:
				_note(first, counts, pending, "tosse_cancelada", t_end)
		if rig.stress.value > stress_max:
			stress_max = rig.stress.value
			stress_max_t = t_end
		if rig.resp.symptom_severity > severity_max:
			severity_max = rig.resp.symptom_severity
			severity_max_t = t_end
		if rig.stamina.value < stamina_min:
			stamina_min = rig.stamina.value
			stamina_min_t = t_end
		# Recuperação: depois do fim do estímulo, a severidade precisa ter subido a 0,2 e caído abaixo dele.
		if t_end >= stimulus_end - EPS and rig.resp.symptom_severity >= RECOVERED_SEVERITY:
			risen = true
		if risen and recovered_t < 0.0 and rig.resp.symptom_severity < RECOVERED_SEVERITY:
			recovered_t = t_end
		if medication_tick >= 0 and tick - medication_tick == MEDICATION_WINDOW_TICKS:
			reduction_3s = medication_severity - rig.resp.symptom_severity
		if (tick + 1) % SAMPLE_TICKS == 0:
			var time_s: float = float(tick + 1) * DT
			rows.append(_row(time_s, plan.entry, speed, distance, rig, sprint_allowed, max_sprint, regen_mult,
				steadiness_before, pending))
			pending = PackedStringArray()
	var summary: PackedStringArray = _summary(scenario, duration, first, counts, distance, stress_max, stress_max_t,
		severity_max, severity_max_t, stamina_min, stamina_min_t, recovered_t, stimulus_end, reduction_3s)
	return {"rows": rows, "summary": summary}


## Perfil de cada cenário. Circuito fechado: o sprint só segue se o acoplamento do tick anterior permitir.
func _plan(scenario: String, t: float, rig: Rig) -> Plan:
	var plan: Plan = Plan.new()
	var none: ThreatSample = _threat(0.0, 0.0, false)
	match scenario:
		"sprint_exaustao":
			if t < 12.0:
				var sprint_ok: bool = rig.coupling.sprint_allowed
				var gait: Enums.Gait = Enums.Gait.SPRINT if sprint_ok else Enums.Gait.WALK
				var exertion: float = SPRINT_EXERTION if sprint_ok else WALK_EXERTION
				plan.entry = _entry(exertion, gait, false, none)
			else:
				plan.entry = _entry(0.0, Enums.Gait.IDLE, false, none)
		"susto_estresse_alto":
			plan.entry = _entry(0.0, Enums.Gait.IDLE, false, none)
			var startle: float = StressModel.startle_spike_for_db(STARTLE_DB)
			for moment: float in [5.0, 5.5, 6.0, 6.5]:
				if _at(t, moment):
					plan.spikes.append(startle)
		"crise_tosse_recuperacao":
			if t < 25.0:
				plan.entry = _entry(CRISIS_EXERTION, Enums.Gait.WALK, false, _threat(1.0, 0.0, false))
			else:
				plan.entry = _entry(0.0, Enums.Gait.IDLE, true, none)
		"bombinha_na_crise":
			if t < 25.0:
				plan.entry = _entry(CRISIS_EXERTION, Enums.Gait.WALK, false, _threat(1.0, 0.0, false))
			else:
				plan.entry = _entry(0.0, Enums.Gait.IDLE, true, none)
			plan.medication = _at(t, 15.0)
		"perseguicao_continua":
			if t < 40.0:
				plan.entry = _entry(WALK_EXERTION, Enums.Gait.WALK, false, _threat(0.0, 0.0, true))
			else:
				plan.entry = _entry(0.0, Enums.Gait.IDLE, true, none)
		_:
			plan.entry = _entry(0.0, Enums.Gait.IDLE, false, none)
	return plan


func _entry(exertion: float, gait: Enums.Gait, resting: bool, sample: ThreatSample) -> PhysiologyInputs:
	var entry: PhysiologyInputs = PhysiologyInputs.new()
	entry.exertion = exertion
	entry.gait = gait
	entry.is_resting = resting
	entry.threat = sample
	return entry


## Mesma regra de DATA §1.5 que BalancePanel.threat_from (o tool não carrega o painel: depende de autoloads).
func _threat(seen: float, heard: float, chase: bool) -> ThreatSample:
	var sample: ThreatSample = ThreatSample.new()
	sample.seen_proximity = seen
	sample.heard_factor = heard
	sample.in_chase = chase
	sample.threat_level = maxf(seen, 0.5 * heard)
	if chase:
		sample.threat_level = maxf(sample.threat_level, 1.0)
	return sample


func _make_rig(configs: Configs) -> Rig:
	var rig: Rig = Rig.new()
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 2008
	rig.coupling_config = configs.coupling
	rig.stamina = StaminaModel.new(configs.stamina)
	rig.stress = StressModel.new(configs.stress)
	rig.resp = RespiratoryModel.new(configs.respiratory, rng)
	rig.coupling = PhysiologyCoupling.compute(rig.stamina, rig.stress, rig.resp, rig.coupling_config)
	return rig


func _speed(gait: Enums.Gait, sprint_max: float) -> float:
	match gait:
		Enums.Gait.SPRINT:
			return SPRINT_SPEED_MS * sprint_max
		Enums.Gait.WALK:
			return WALK_SPEED_MS
		Enums.Gait.SLOW:
			return SLOW_SPEED_MS
	return 0.0


func _at(t: float, moment: float) -> bool:
	return absf(t - moment) < DT * 0.5


func _band_name(band: int) -> String:
	var names: Array = Enums.StressBand.keys()
	return String(names[band])


## Registra um evento: entra na linha da amostra, na contagem e na primeira ocorrência.
func _note(first: Dictionary, counts: Dictionary, pending: PackedStringArray, name: String, t: float) -> void:
	pending.append(name)
	counts[name] = int(counts.get(name, 0)) + 1
	if not first.has(name):
		first[name] = t


func _row(time_s: float, entry: PhysiologyInputs, speed: float, distance: float, rig: Rig, sprint_allowed: bool,
		sprint_max: float, regen_mult: float, steadiness: float, pending: PackedStringArray) -> String:
	var fields: PackedStringArray = PackedStringArray()
	fields.append("%.4f" % time_s)
	fields.append(String(GAIT_NAMES[int(entry.gait)]))
	fields.append("%.2f" % entry.exertion)
	fields.append("%.3f" % speed)
	fields.append("%.3f" % distance)
	fields.append("%.3f" % rig.stamina.value)
	fields.append("%.3f" % rig.stress.value)
	fields.append(_band_name(int(rig.stress.get_band())))
	fields.append("%.4f" % rig.resp.symptom_severity)
	fields.append(RespiratoryModel.state_name(rig.resp.state))
	fields.append("%.2f" % rig.resp.breathing_rate)
	fields.append("%.4f" % rig.resp.wheezing_intensity)
	fields.append("%.4f" % rig.resp.cough_probability)
	fields.append("1" if sprint_allowed else "0")
	fields.append("%.4f" % sprint_max)
	fields.append("%.4f" % regen_mult)
	fields.append("%.4f" % steadiness)
	fields.append(";".join(pending))
	return ",".join(fields)


## Resumo legível de um cenário: picos, primeiras ocorrências de cada evento (em ordem de tempo) e recuperação.
func _summary(scenario: String, duration: float, first: Dictionary, counts: Dictionary, distance: float,
		stress_max: float, stress_max_t: float, severity_max: float, severity_max_t: float, stamina_min: float,
		stamina_min_t: float, recovered_t: float, stimulus_end: float, reduction_3s: float) -> PackedStringArray:
	var lines: PackedStringArray = PackedStringArray()
	lines.append("[%s] duracao %.1f s; %s" % [scenario, duration, String(SCENARIO_NOTES[scenario])])
	lines.append("  estresse max %.2f em t=%.3f s; severidade max %.4f em t=%.3f s"
		% [stress_max, stress_max_t, severity_max, severity_max_t])
	lines.append("  estamina min %.2f em t=%.3f s; distancia %.2f m" % [stamina_min, stamina_min_t, distance])
	if recovered_t >= 0.0:
		lines.append("  severidade abaixo de %.1f depois de %.1f s: t=%.3f s" % [RECOVERED_SEVERITY, stimulus_end, recovered_t])
	else:
		lines.append("  severidade abaixo de %.1f depois de %.1f s: nao ocorreu" % [RECOVERED_SEVERITY, stimulus_end])
	if reduction_3s >= -EPS and scenario == "bombinha_na_crise":
		lines.append("  reducao da severidade 3 s depois da bombinha: %.4f" % reduction_3s)
	var ordered: Array = []
	for name_variant: Variant in first.keys():
		ordered.append([float(first[name_variant]), String(name_variant)])
	ordered.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0] or (a[0] == b[0] and String(a[1]) < String(b[1])))
	lines.append("  eventos (primeira ocorrencia; total):")
	if ordered.is_empty():
		lines.append("    nenhum")
	for entry: Array in ordered:
		var name: String = String(entry[1])
		lines.append("    t=%.3f s  %s  (%d)" % [float(entry[0]), name, int(counts[name])])
	return lines


func _write_text(path: String, text: String) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		printerr("balance_sim: nao foi possivel gravar %s" % path)
		return
	file.store_string(text)
	file.close()

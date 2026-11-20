class_name RespiratoryModel
extends RefCounted
## RespiratoryModel (L1, DATA_STRUCTURES §1.4, §1.7 e §6.1, COMPONENT_CONTRACTS §4.2, F2-003).
## EMA do esforço, severidade com subida e descida, frequência e chiado, hazard de tosse com aviso,
## máquina de estados com histerese e permanência mínima, recovery_progress, medicação e consumíveis.
## RNG injetado (PHY-INV-6). Sem cena: o PhysiologyComponent chama tick() e lê take_events().
##
## Eventos de tosse vão para uma fila consumida no mesmo tick (take_events). Não são persistidos.

## Eventos de tosse produzidos por tick.
enum CoughEvent { WARNING, COUGH, CANCELLED }

const EPS: float = 0.000000001
## Pesos do alvo de severidade (DATA §1.4): target = clamp(0,7·ema + 0,4·stress_term, 0, 1)·(1 − relief).
const EXERTION_WEIGHT: float = 0.7
const STRESS_WEIGHT: float = 0.4
const STRESS_TERM_START: float = 0.3
const STRESS_TERM_RANGE: float = 0.7
## Queda em repouso: o dobro (DATA §1.4).
const FALL_RESTING_FACTOR: float = 2.0
## Frequência respiratória (irpm) e chiado.
const BREATH_RATE_MIN: float = 14.0
const BREATH_RATE_MAX: float = 40.0
const WHEEZE_START: float = 0.35
const WHEEZE_END: float = 0.9
## Tosse: hazard só acima de COUGH_SEVERITY_MIN; máximo 0,25 por segundo.
const COUGH_SEVERITY_MIN: float = 0.55
const COUGH_PROBABILITY_MAX: float = 0.25
## Limiares de transição (DATA §1.4). Histerese: cada par de entrada/saída tem faixa entre eles.
const SYMPTOM_ENTER: float = 0.60
const SYMPTOM_EXIT: float = 0.55
const LABORED_ENTER: float = 0.35
const RECOVER_ENTER: float = 0.30
const ACCEL_ENTER_SEVERITY: float = 0.20
const ACCEL_ENTER_EMA: float = 0.40
const NORMAL_EXIT_SEVERITY: float = 0.15
const NORMAL_EXIT_EMA: float = 0.35
const RECOVERY_FLOOR: float = 0.20

## Severidade 0..1 (PHY-INV-1).
var symptom_severity: float = 0.0
## Derivados (recalculados a cada tick e ao carregar).
var breathing_rate: float = BREATH_RATE_MIN
var wheezing_intensity: float = 0.0
var cough_probability: float = 0.0
var recovery_progress: float = 1.0
var state: Enums.RespiratoryState = Enums.RespiratoryState.NORMAL
## EMA do esforço, τ = exertion_time_constant_s.
var exertion_ema: float = 0.0
## Segundos no estado atual (para state_min_dwell_s).
var state_dwell: float = 0.0
## Maior severidade desde a saída de NORMAL.
var peak_severity: float = 0.0
## Segundos até a tosse agendada; −1 = nenhuma.
var pending_cough_in: float = -1.0
var cough_cooldown_remaining: float = 0.0
## Força atual do alívio da bombinha (0..1); decai linearmente em relief_remaining.
var relief_strength: float = 0.0
var relief_remaining: float = 0.0
## Redução absoluta de severidade ainda não aplicada, e a taxa por segundo.
var reduction_remaining: float = 0.0
var reduction_rate_per_s: float = 0.0
var medication_cooldown_remaining: float = 0.0
var tablet_effect_remaining: float = 0.0
var water_effect_remaining: float = 0.0

var _config: RespiratoryConfig
var _rng: RandomNumberGenerator
var _events: Array[int] = []


func _init(config: RespiratoryConfig = null, rng: RandomNumberGenerator = null) -> void:
	_config = config if config != null else RespiratoryConfig.new()
	_rng = rng if rng != null else RandomNumberGenerator.new()
	_refresh_derived()


## Função pura da máquina de estados, sem permanência mínima (ela é aplicada em tick).
static func next_state(current: Enums.RespiratoryState, severity: float, exertion_ema_value: float) -> Enums.RespiratoryState:
	match current:
		Enums.RespiratoryState.NORMAL:
			if severity >= SYMPTOM_ENTER:
				return Enums.RespiratoryState.SYMPTOMATIC
			if severity >= LABORED_ENTER:
				return Enums.RespiratoryState.LABORED
			if exertion_ema_value >= ACCEL_ENTER_EMA or severity >= ACCEL_ENTER_SEVERITY:
				return Enums.RespiratoryState.ACCELERATED
		Enums.RespiratoryState.ACCELERATED:
			if severity >= SYMPTOM_ENTER:
				return Enums.RespiratoryState.SYMPTOMATIC
			if severity >= LABORED_ENTER:
				return Enums.RespiratoryState.LABORED
			if exertion_ema_value < NORMAL_EXIT_EMA and severity < NORMAL_EXIT_SEVERITY:
				return Enums.RespiratoryState.NORMAL
		Enums.RespiratoryState.LABORED:
			if severity >= SYMPTOM_ENTER:
				return Enums.RespiratoryState.SYMPTOMATIC
			if severity < RECOVER_ENTER:
				return Enums.RespiratoryState.RECOVERING
		Enums.RespiratoryState.SYMPTOMATIC:
			if severity < SYMPTOM_EXIT:
				return Enums.RespiratoryState.LABORED
		Enums.RespiratoryState.RECOVERING:
			if severity >= SYMPTOM_ENTER:
				return Enums.RespiratoryState.SYMPTOMATIC
			if severity >= LABORED_ENTER:
				return Enums.RespiratoryState.LABORED
			if severity < RECOVERY_FLOOR:
				if exertion_ema_value >= ACCEL_ENTER_EMA:
					return Enums.RespiratoryState.ACCELERATED
				return Enums.RespiratoryState.NORMAL
	return current


## Um tick. stress_value é o estresse 0..100 do StressModel neste tick.
func tick(dt: float, inputs: PhysiologyInputs, stress_value: float) -> void:
	_events.clear()
	if dt <= 0.0:
		return
	_advance_timers(dt)
	_advance_exertion(dt, inputs.exertion)
	var target: float = _target_severity(stress_value)
	_advance_severity(dt, target, inputs.is_resting)
	_update_state()
	_update_peak()
	_refresh_derived()
	_update_cough(dt)


## Medicação (bombinha): redução absoluta com taxa constante, alívio linear e cooldown.
## Falso (e nada muda) em cooldown. Não toca na stamina (PHY-INV-2).
func apply_medication(profile: MedicationProfile) -> bool:
	if profile == null or medication_cooldown_remaining > 0.0:
		return false
	medication_cooldown_remaining = profile.cooldown_s
	reduction_remaining = profile.immediate_reduction
	reduction_rate_per_s = profile.immediate_reduction / maxf(profile.reduction_time_s, EPS)
	relief_strength = maxf(relief_strength, profile.relief_strength)
	relief_remaining = maxf(relief_remaining, profile.relief_duration_s)
	return true


## Consumíveis (DATA §1.7): "medication_tablet" reduz a subida; "water" reduz a tosse. Falso para outros ids.
func apply_consumable(kind: StringName) -> bool:
	match kind:
		&"medication_tablet":
			tablet_effect_remaining = _config.tablet_duration_s
			return true
		&"water":
			water_effect_remaining = _config.water_duration_s
			return true
	return false


## Há eventos de tosse pendentes de leitura (sem alocar).
func has_events() -> bool:
	return not _events.is_empty()


## Eventos de tosse do último tick. Esvazia a fila.
func take_events() -> Array[int]:
	var taken: Array[int] = []
	taken.assign(_events)
	_events.clear()
	return taken


func to_dict() -> Dictionary:
	return {
		"severity": symptom_severity,
		"exertion_ema": exertion_ema,
		"state": state_name(state),
		"state_dwell": state_dwell,
		"peak_severity": peak_severity,
		"pending_cough_in": pending_cough_in,
		"cough_cooldown_remaining": cough_cooldown_remaining,
		"relief_strength": relief_strength,
		"relief_remaining": relief_remaining,
		"reduction_remaining": reduction_remaining,
		"reduction_rate_per_s": reduction_rate_per_s,
		"medication_cooldown_remaining": medication_cooldown_remaining,
		"consumable_effects": {
			"medication_tablet": tablet_effect_remaining,
			"water": water_effect_remaining,
		},
	}


func from_dict(data: Dictionary) -> void:
	var effects: Dictionary = data["consumable_effects"]
	symptom_severity = clampf(float(data["severity"]), 0.0, 1.0)
	exertion_ema = clampf(float(data["exertion_ema"]), 0.0, 1.0)
	state = state_from_name(str(data["state"]))
	state_dwell = maxf(0.0, float(data["state_dwell"]))
	peak_severity = clampf(float(data["peak_severity"]), 0.0, 1.0)
	pending_cough_in = float(data["pending_cough_in"])
	cough_cooldown_remaining = maxf(0.0, float(data["cough_cooldown_remaining"]))
	relief_strength = clampf(float(data["relief_strength"]), 0.0, 1.0)
	relief_remaining = maxf(0.0, float(data["relief_remaining"]))
	reduction_remaining = maxf(0.0, float(data["reduction_remaining"]))
	reduction_rate_per_s = maxf(0.0, float(data["reduction_rate_per_s"]))
	medication_cooldown_remaining = maxf(0.0, float(data["medication_cooldown_remaining"]))
	tablet_effect_remaining = maxf(0.0, float(effects["medication_tablet"]))
	water_effect_remaining = maxf(0.0, float(effects["water"]))
	_events.clear()
	_refresh_derived()


static func state_name(value: Enums.RespiratoryState) -> String:
	var names: Array = Enums.RespiratoryState.keys()
	return str(names[value])


## Nome desconhecido vira NORMAL (o carregamento valida o esquema antes, na F5).
static func state_from_name(state_key: String) -> Enums.RespiratoryState:
	var names: Array = Enums.RespiratoryState.keys()
	var index: int = names.find(state_key)
	if index < 0:
		return Enums.RespiratoryState.NORMAL
	return Enums.RespiratoryState.values()[index]


func _advance_timers(dt: float) -> void:
	medication_cooldown_remaining = maxf(0.0, medication_cooldown_remaining - dt)
	cough_cooldown_remaining = maxf(0.0, cough_cooldown_remaining - dt)
	tablet_effect_remaining = maxf(0.0, tablet_effect_remaining - dt)
	water_effect_remaining = maxf(0.0, water_effect_remaining - dt)
	state_dwell += dt
	_advance_relief(dt)


## Alívio linear: a força cai na mesma proporção do tempo restante.
func _advance_relief(dt: float) -> void:
	if relief_remaining <= 0.0:
		relief_strength = 0.0
		return
	var before: float = relief_remaining
	relief_remaining = maxf(0.0, relief_remaining - dt)
	if relief_remaining <= EPS:
		relief_remaining = 0.0
		relief_strength = 0.0
	else:
		relief_strength *= relief_remaining / before


func _advance_exertion(dt: float, exertion: float) -> void:
	var alpha: float = 1.0 - exp(-dt / maxf(_config.exertion_time_constant_s, EPS))
	exertion_ema += (clampf(exertion, 0.0, 1.0) - exertion_ema) * alpha


func _target_severity(stress_value: float) -> float:
	var stress_term: float = maxf(0.0, stress_value / 100.0 - STRESS_TERM_START) / STRESS_TERM_RANGE
	var raw: float = clampf(EXERTION_WEIGHT * exertion_ema + STRESS_WEIGHT * stress_term, 0.0, 1.0)
	return raw * (1.0 - relief_strength)


## Subida ou queda em direção ao alvo, sem ultrapassá-lo; depois, a redução da bombinha.
func _advance_severity(dt: float, target: float, resting: bool) -> void:
	if target > symptom_severity:
		var rise: float = _config.rise_rate_per_s
		if tablet_effect_remaining > 0.0:
			rise *= _config.tablet_rise_multiplier
		symptom_severity = minf(target, symptom_severity + rise * dt)
	else:
		var fall: float = _config.fall_rate_per_s
		if resting:
			fall *= FALL_RESTING_FACTOR
		symptom_severity = maxf(target, symptom_severity - fall * dt)
	if reduction_remaining > 0.0:
		var applied: float = minf(reduction_rate_per_s * dt, reduction_remaining)
		symptom_severity -= applied
		reduction_remaining = maxf(0.0, reduction_remaining - applied)
		if reduction_remaining <= EPS:
			reduction_remaining = 0.0
	symptom_severity = clampf(symptom_severity, 0.0, 1.0)


## Permanência mínima: nenhuma transição antes de state_min_dwell_s no estado atual.
func _update_state() -> void:
	if state_dwell < _config.state_min_dwell_s - EPS:
		return
	var next: Enums.RespiratoryState = next_state(state, symptom_severity, exertion_ema)
	if next != state:
		state = next
		state_dwell = 0.0


func _update_peak() -> void:
	if state == Enums.RespiratoryState.NORMAL:
		peak_severity = symptom_severity
	else:
		peak_severity = maxf(peak_severity, symptom_severity)


func _refresh_derived() -> void:
	breathing_rate = lerpf(BREATH_RATE_MIN, BREATH_RATE_MAX, maxf(exertion_ema, symptom_severity))
	wheezing_intensity = smoothstep(WHEEZE_START, WHEEZE_END, symptom_severity)
	var probability: float = 0.0
	if symptom_severity > COUGH_SEVERITY_MIN:
		var excess: float = (symptom_severity - COUGH_SEVERITY_MIN) / (1.0 - COUGH_SEVERITY_MIN)
		probability = COUGH_PROBABILITY_MAX * excess * excess
	if water_effect_remaining > 0.0:
		probability *= _config.water_cough_multiplier
	cough_probability = probability
	recovery_progress = _recovery_progress()


## DATA §1.4: em RECOVERING, (pico − severidade)/(pico − 0,20). Em NORMAL, 1. Nos demais estados, 0.
func _recovery_progress() -> float:
	if state == Enums.RespiratoryState.NORMAL:
		return 1.0
	if state != Enums.RespiratoryState.RECOVERING:
		return 0.0
	var span: float = peak_severity - RECOVERY_FLOOR
	if span <= EPS:
		return 1.0
	return clampf((peak_severity - symptom_severity) / span, 0.0, 1.0)


## Tosse com aviso (DATA §1.4): agenda com hazard por tick, cancela se a severidade cai abaixo de 0,55 no aviso.
## O RNG só é consumido quando há risco (probabilidade > 0), sem tosse pendente e sem cooldown.
func _update_cough(dt: float) -> void:
	if pending_cough_in >= 0.0:
		pending_cough_in -= dt
		if pending_cough_in <= EPS:
			pending_cough_in = -1.0
			if symptom_severity < COUGH_SEVERITY_MIN:
				_events.append(CoughEvent.CANCELLED)
			else:
				cough_cooldown_remaining = _config.cough_cooldown_s
				_events.append(CoughEvent.COUGH)
		return
	if cough_cooldown_remaining > 0.0 or cough_probability <= 0.0:
		return
	if _rng.randf() < cough_probability * dt:
		pending_cough_in = _config.cough_warning_time_s
		_events.append(CoughEvent.WARNING)

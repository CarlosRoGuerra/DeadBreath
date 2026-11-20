class_name StressModel
extends RefCounted
## StressModel (L1, DATA_STRUCTURES §1.3 e §6.1, COMPONENT_CONTRACTS §4.2, F2-002).
## Ganhos por ameaça (inimigo visto, ouvido e perseguição, somados por segundo), picos instantâneos
## (susto, ferimento, captura), decaimento depois de um atraso sem ameaça, e faixas CALM..PANIC.
## Sem cena: o PhysiologyComponent chama tick().

const MAX_VALUE: float = 100.0
## Susto: só ruído com perceived_db >= STARTLE_MIN_DB gera pico (DATA §1.3).
const STARTLE_MIN_DB: float = 55.0
const STARTLE_SPIKE_MIN: float = 10.0
const STARTLE_SPIKE_MAX: float = 25.0
const EPS: float = 0.000000001

## Estresse atual, 0..100 (PHY-INV-1).
var value: float = 0.0
## Segundos desde a última ameaça ou pico (para decay_delay_s).
var time_since_threat: float = 0.0

var _config: StressConfig


func _init(config: StressConfig = null) -> void:
	_config = config if config != null else StressConfig.new()
	time_since_threat = _config.decay_delay_s


## Pico de estresse para um ruído que não foi causado pelo jogador (DATA §1.3).
## Abaixo de 55 dB não há pico (0). Acima, clamp((db − 55)/2 + 10, 10, 25).
static func startle_spike_for_db(perceived_db: float) -> float:
	if perceived_db < STARTLE_MIN_DB:
		return 0.0
	return clampf((perceived_db - STARTLE_MIN_DB) / 2.0 + STARTLE_SPIKE_MIN, STARTLE_SPIKE_MIN, STARTLE_SPIKE_MAX)


## Um tick. Qualquer ameaça (ganho > 0) zera o contador; sem ameaça, o estresse cai depois de decay_delay_s.
func tick(dt: float, inputs: PhysiologyInputs) -> void:
	if dt <= 0.0:
		return
	var threat: ThreatSample = inputs.threat
	var gain: float = _config.enemy_seen_gain_per_s * clampf(threat.seen_proximity, 0.0, 1.0)
	gain += _config.enemy_heard_gain_per_s * clampf(threat.heard_factor, 0.0, 1.0)
	if threat.in_chase:
		gain += _config.chase_gain_per_s
	if gain > 0.0:
		time_since_threat = 0.0
		value = minf(MAX_VALUE, value + gain * dt)
		return
	time_since_threat += dt
	if time_since_threat >= _config.decay_delay_s - EPS:
		var rate: float = _config.safe_zone_decay_per_s if inputs.in_safe_zone else _config.decay_per_s
		value = maxf(0.0, value - rate * dt)


## Pico instantâneo (susto, ferimento, captura). Reinicia o atraso de decaimento.
func add_spike(amount: float) -> void:
	if amount <= 0.0:
		return
	value = minf(MAX_VALUE, value + amount)
	time_since_threat = 0.0


func get_band() -> Enums.StressBand:
	if value < _config.band_tense_from:
		return Enums.StressBand.CALM
	if value < _config.band_afraid_from:
		return Enums.StressBand.TENSE
	if value < _config.band_panic_from:
		return Enums.StressBand.AFRAID
	return Enums.StressBand.PANIC


func to_dict() -> Dictionary:
	return {
		"value": value,
		"time_since_threat": time_since_threat,
	}


func from_dict(data: Dictionary) -> void:
	value = clampf(float(data["value"]), 0.0, MAX_VALUE)
	time_since_threat = maxf(0.0, float(data["time_since_threat"]))

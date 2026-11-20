class_name StaminaModel
extends RefCounted
## StaminaModel (L1, DATA_STRUCTURES §1.2 e §6.1, COMPONENT_CONTRACTS §4.2, F2-001).
## Dreno do sprint, atraso de regeneração, regeneração por marcha e repouso, multiplicador do acoplamento
## e histerese de exaustão (o sprint volta a valer em sprint_reenable_threshold).
## Não recebe medicação (PHY-INV-2). Sem cena: o PhysiologyComponent chama tick().
## Dreno de escalada e de empurrar móvel: reservados (sem entrada na F2).

## Stamina atual, 0..max_value (PHY-INV-1).
var value: float = 100.0
## Verdadeiro depois de zerar, até a stamina chegar a sprint_reenable_threshold.
var exhausted: bool = false
## Segundos restantes sem regeneração depois do último gasto.
var regen_delay_remaining: float = 0.0

var _config: StaminaConfig


func _init(config: StaminaConfig = null) -> void:
	_config = config if config != null else StaminaConfig.new()
	value = _config.max_value


## Um tick. coupling é o acoplamento calculado no tick anterior (os limites valem no tick seguinte).
func tick(dt: float, inputs: PhysiologyInputs, coupling: CouplingFactors) -> void:
	if dt <= 0.0:
		return
	if inputs.gait == Enums.Gait.SPRINT:
		value = maxf(0.0, value - _config.sprint_drain_per_s * dt)
		regen_delay_remaining = _config.regen_delay_s
	elif regen_delay_remaining > 0.0:
		regen_delay_remaining = maxf(0.0, regen_delay_remaining - dt)
	else:
		var multiplier: float = coupling.stamina_regen_multiplier
		if inputs.in_safe_zone:
			multiplier *= _config.safe_zone_regen_multiplier
		value = minf(_config.max_value, value + _regen_per_s(inputs) * multiplier * dt)
	_update_exhaustion()


func to_dict() -> Dictionary:
	return {
		"value": value,
		"exhausted": exhausted,
		"regen_delay_remaining": regen_delay_remaining,
	}


func from_dict(data: Dictionary) -> void:
	value = clampf(float(data["value"]), 0.0, _config.max_value)
	exhausted = bool(data["exhausted"])
	regen_delay_remaining = maxf(0.0, float(data["regen_delay_remaining"]))


func _regen_per_s(inputs: PhysiologyInputs) -> float:
	if inputs.is_resting:
		return _config.regen_rest_per_s
	if inputs.gait == Enums.Gait.IDLE:
		return _config.regen_idle_per_s
	if inputs.gait == Enums.Gait.SLOW:
		return _config.regen_slow_per_s
	return _config.regen_walk_per_s


func _update_exhaustion() -> void:
	if value <= 0.0:
		exhausted = true
	elif exhausted and value >= _config.sprint_reenable_threshold:
		exhausted = false

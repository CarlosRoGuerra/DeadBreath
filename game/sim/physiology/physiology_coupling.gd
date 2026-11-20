class_name PhysiologyCoupling
extends RefCounted
## PhysiologyCoupling (L1, DATA_STRUCTURES §1.6, COMPONENT_CONTRACTS §4.2): fatores que a fisiologia
## devolve ao motor e à interação. Função pura do estado dos modelos. A stamina não entra na severidade (PHY-05).


## Calcula o acoplamento a partir do estado atual dos três modelos.
static func compute(stamina: StaminaModel, stress: StressModel, resp: RespiratoryModel, config: CouplingConfig) -> CouplingFactors:
	var factors: CouplingFactors = CouplingFactors.new()
	var severity: float = resp.symptom_severity
	var stress_value: float = stress.value
	factors.stamina_regen_multiplier = (1.0 - config.regen_severity_penalty * severity) \
		* (1.0 - config.regen_stress_penalty * stress_value / 100.0)
	factors.max_sprint_multiplier = _sprint_multiplier(severity, config)
	factors.sprint_allowed = not stamina.exhausted
	factors.steadiness = clampf(
		1.0 - config.steadiness_stress_weight * smoothstep(config.steadiness_stress_range.x, config.steadiness_stress_range.y, stress_value)
		- config.steadiness_wheeze_weight * resp.wheezing_intensity,
		0.0, 1.0)
	factors.tremor_amplitude = smoothstep(config.tremor_stress_range.x, config.tremor_stress_range.y, stress_value)
	return factors


## 1 abaixo do limiar de severidade; depois, interpola até sprint_limit_min_multiplier em severidade 1.
static func _sprint_multiplier(severity: float, config: CouplingConfig) -> float:
	var start: float = config.sprint_limit_start_severity
	if severity < start:
		return 1.0
	var t: float = clampf((severity - start) / (1.0 - start), 0.0, 1.0)
	return lerpf(1.0, config.sprint_limit_min_multiplier, t)

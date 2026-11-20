class_name CouplingConfig
extends Resource
## CouplingConfig (L1, DATA_STRUCTURES §1.6 e §9): parâmetros do acoplamento fisiologia → motor e interação.
## Valores de produção: content/data/physiology/coupling_config.tres.

@export var regen_severity_penalty: float = 0.6
@export var regen_stress_penalty: float = 0.3
@export var sprint_limit_start_severity: float = 0.6
@export var sprint_limit_min_multiplier: float = 0.75
@export var steadiness_stress_weight: float = 0.7
@export var steadiness_stress_range: Vector2 = Vector2(40.0, 100.0)
@export var steadiness_wheeze_weight: float = 0.3
@export var tremor_stress_range: Vector2 = Vector2(50.0, 100.0)

class_name RespiratoryConfig
extends Resource
## RespiratoryConfig (L1, DATA_STRUCTURES §1.4 e §1.7): parâmetros respiratórios.
## Os limiares de estado e de tosse (0,20, 0,35, 0,40, 0,55 etc.) são constantes das fórmulas, em RespiratoryModel.
## Valores de produção: content/data/physiology/respiratory_config.tres.

@export var exertion_time_constant_s: float = 8.0   ## τ da EMA do esforço
@export var rise_rate_per_s: float = 0.08           ## subida da severidade (1/s)
@export var fall_rate_per_s: float = 0.03           ## queda da severidade (1/s); em repouso, o dobro
@export var cough_warning_time_s: float = 1.5       ## aviso antes da tosse
@export var cough_cooldown_s: float = 4.0           ## intervalo mínimo entre tosses
@export var state_min_dwell_s: float = 1.0          ## permanência mínima em cada estado
@export var tablet_rise_multiplier: float = 0.7     ## comprimido: rise_rate × 0,7
@export var tablet_duration_s: float = 180.0        ## comprimido: duração do efeito
@export var water_cough_multiplier: float = 0.5     ## água: cough_probability × 0,5
@export var water_duration_s: float = 60.0          ## água: duração do efeito

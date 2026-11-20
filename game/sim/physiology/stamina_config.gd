class_name StaminaConfig
extends Resource
## StaminaConfig (L1, DATA_STRUCTURES §1.2): parâmetros da stamina. Os padrões são a tabela §1.2.
## Valores de produção: content/data/physiology/stamina_config.tres.
## climb_drain_per_s e push_furniture_drain_per_s são reservados: a F2 não tem entrada de escalada nem de empurrar móvel.

@export var max_value: float = 100.0                  ## unidades de stamina
@export var sprint_drain_per_s: float = 12.0          ## por segundo, correndo (tanque cheio: 8,3 s)
@export var climb_drain_per_s: float = 15.0           ## por segundo, subindo (reservado)
@export var push_furniture_drain_per_s: float = 10.0  ## por segundo, empurrando móvel (reservado)
@export var regen_delay_s: float = 1.2                ## s sem regeneração depois de gastar
@export var regen_walk_per_s: float = 4.0             ## andando
@export var regen_slow_per_s: float = 7.0             ## andando devagar
@export var regen_idle_per_s: float = 10.0            ## parado em pé
@export var regen_rest_per_s: float = 14.0            ## parado agachado/rastejando, ou escondido
@export var safe_zone_regen_multiplier: float = 1.3   ## zona segura
@export var sprint_reenable_threshold: float = 25.0   ## histerese: o sprint volta a valer com esta stamina

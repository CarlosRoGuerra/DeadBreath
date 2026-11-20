class_name StressConfig
extends Resource
## StressConfig (L1, DATA_STRUCTURES §1.3): parâmetros do estresse. Os padrões são a tabela §1.3.
## Valores de produção: content/data/physiology/stress_config.tres.

@export var enemy_seen_gain_per_s: float = 15.0   ## ganho por segundo × seen_proximity
@export var enemy_heard_gain_per_s: float = 5.0   ## ganho por segundo × heard_factor
@export var chase_gain_per_s: float = 20.0        ## ganho por segundo enquanto in_chase
@export var injury_spike: float = 20.0            ## pico de um ferimento (queda acima de fall_injury_height)
@export var capture_spike: float = 40.0           ## pico durante a sequência de captura (F5)
@export var decay_delay_s: float = 4.0            ## s sem ameaça antes de o estresse cair
@export var decay_per_s: float = 3.0              ## queda por segundo
@export var safe_zone_decay_per_s: float = 8.0    ## queda por segundo em zona segura
@export var band_tense_from: float = 25.0         ## CALM < 25 <= TENSE
@export var band_afraid_from: float = 50.0        ## TENSE < 50 <= AFRAID
@export var band_panic_from: float = 75.0         ## AFRAID < 75 <= PANIC
@export var gasp_min_spike: float = 15.0          ## gasp de susto: pico >= 15 ...
@export var gasp_min_stress: float = 50.0         ## ... com estresse >= 50 antes do pico

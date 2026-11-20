class_name PlayerMotorConfig
extends Resource
## Parâmetros do PlayerMotor (DATA_STRUCTURES §1.1, mais os acréscimos da F1-006).
## Os padrões são os da tabela; o valor de produção fica em content/data/player_motor_config.tres.
## Unidades: metros, m/s, m/s², segundos ou graus, conforme o comentário de cada campo.

@export var walk_speed: float = 1.6                 ## m/s
@export var slow_walk_speed: float = 0.9            ## m/s
@export var crouch_speed: float = 1.0               ## m/s
@export var crawl_speed: float = 0.5                ## m/s
@export var sprint_speed: float = 4.8               ## m/s
@export var acceleration: float = 10.0              ## m/s²
@export var deceleration: float = 14.0              ## m/s²
@export var stand_height: float = 1.75              ## m (altura do colisor em pé)
@export var crouch_height: float = 1.10             ## m
@export var crawl_height: float = 0.55              ## m
## Raio do colisor cilíndrico. O nome vem do contrato (capsule_radius), mantido por compatibilidade.
@export var capsule_radius: float = 0.25            ## m
@export var step_height: float = 0.30               ## m, degrau que o motor sobe sozinho
@export var fall_injury_height: float = 2.5         ## m (usado pela fisiologia na F2)
@export var head_bob_amplitude: float = 0.03        ## m, com motion_reduction = 0
@export var eye_offset: float = 0.10                ## m, do topo do colisor até os olhos
@export var stance_transition_time_s: float = 0.25  ## s, troca de altura dos olhos entre posturas
@export var gravity: float = 9.8                    ## m/s²
@export var floor_snap_length: float = 0.30         ## m
@export var step_probe_distance: float = 0.27       ## m, sondagem horizontal do step-up (≥ raio, spike V6)
@export var pitch_limit_deg: float = 85.0           ## graus
@export var camera_step_smoothing: float = 12.0     ## 1/s, decaimento exponencial da altura visual após degrau
@export var stride_slow: float = 0.5                ## m por passada
@export var stride_walk: float = 0.7                ## m por passada
@export var stride_sprint: float = 1.1              ## m por passada
@export var stride_crouch: float = 0.5              ## m por passada
@export var stride_crawl: float = 0.4               ## m por passada
@export var head_bob_frequency_per_stride: float = 0.5  ## ciclos de bob por passada

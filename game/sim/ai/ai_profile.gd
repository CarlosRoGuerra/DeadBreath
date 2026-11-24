class_name AIProfile
extends Resource
## AIProfile (L1, DATA_STRUCTURES §3.1 e §9; F4-003): parâmetros de um perfil de inimigo.
## Os padrões são os do OBSERVER. Valores de produção: content/data/ai/observer.tres, aggressive.tres, leader.tres.
## Campos de percepção (sight, fov, hearing_threshold, masking) são lidos pelos sensores e pelo AcousticWorld;
## o EnemyBrain lê os de suspeita, confirmação, velocidade, busca e memória.

@export var sight_range_m: float = 16.0
@export var fov_deg: float = 110.0
@export var hearing_threshold_db: float = 15.0
## Negativo: o inimigo atento distingue sons abaixo do ruído de fundo (DATA §2.3).
@export var masking_margin_db: float = -3.0
@export var vision_suspicion_gain_per_s: float = 1.6
@export var hearing_suspicion_per_db: float = 0.04
@export var hearing_suspicion_cap_per_event: float = 0.6
## Aplicado depois de 2 s sem estímulo.
@export var suspicion_decay_per_s: float = 0.05
@export var suspicious_threshold: float = 0.25
@export var investigate_threshold: float = 0.5
@export var visual_confirm_time_s: float = 0.6
@export var min_visibility_for_confirm: float = 0.4
@export var patrol_speed: float = 1.2
@export var investigate_speed: float = 1.8
@export var chase_speed: float = 4.2
@export var lost_contact_pursuit_s: float = 6.0
@export var search_duration_s: float = 60.0
## Dificuldade (F6). Multiplica search_duration_s; 1.0 até a F6.
@export var search_duration_multiplier: float = 1.0
@export var inspect_hideable_chance: float = 0.6
@export var memory_confidence_decay_per_s: float = 0.02
@export var squad_latency_s: float = 1.5
## 1.0 = sempre segue ordens do Leader. Só o AGGRESSIVE obedece parcialmente (0.5). Para OBSERVER e LEADER não se aplica (1.0).
@export var squad_obedience: float = 1.0

class_name AcousticConfig
extends Resource
## AcousticConfig (L1, DATA_STRUCTURES §2.2 e §9; ADR-004, ADR-006): parâmetros de propagação acústica.
## Os valores padrão são os da §2.2. Valores de produção: content/data/acoustics/acoustic_config.tres.
## Perda por distância: 20·log10(max(d; min_distance_m)) + extra_loss_per_m_db·d.

@export var portal_open_loss_db: float = 3.0           ## perda ao atravessar um portal aberto
@export var portal_closed_loss_db: float = 18.0        ## perda ao atravessar um portal fechado
@export var wall_transmission_loss_db: float = 25.0    ## perda por parede atravessada
@export var floor_transmission_loss_db: float = 30.0   ## perda por piso (face horizontal) atravessado
@export var extra_loss_per_m_db: float = 0.1           ## perda extra por metro (ar e obstáculos)
@export var min_distance_m: float = 1.0                ## distância mínima da fórmula logarítmica
@export var position_error_per_db_lost: float = 0.05   ## erro da posição estimada, m por dB perdido (F3-002/F4)

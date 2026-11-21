class_name NoiseLevels
extends Resource
## NoiseLevels (L1, DATA_STRUCTURES §2.1; F3-002, decisão D-03 do Director): níveis iniciais de emissão (dB a 1 m)
## e os modificadores de superfície. Valores de produção: content/data/acoustics/noise_levels.tres. Funções puras.
## Mapeamento dos nomes: rastejar = crawl, agachado = crouch, andando devagar = slow, andando = walk.
## Respiração e chiado não estão aqui: a faixa vem de BreathParams (§2.4). Não há tabela de abafamento de superfície
## para o jogador escondido: é Hideable.muffle_db (COMPONENT_CONTRACTS §9).

@export var footstep_crawl_db: float = 18.0     ## passos rastejando
@export var footstep_crouch_db: float = 25.0    ## passos agachado
@export var footstep_slow_db: float = 32.0      ## passos andando devagar
@export var footstep_walk_db: float = 40.0      ## passos andando
@export var running_db: float = 60.0            ## corrida (passo de corrida)
@export var cough_db: float = 65.0              ## tosse
@export var door_slow_db: float = 30.0          ## porta lenta
@export var door_normal_db: float = 50.0        ## porta normal
@export var door_slam_db: float = 75.0          ## porta batida
@export var object_impact_range_db: Vector2 = Vector2(50.0, 80.0)  ## impacto de objeto: mín e máx
@export var medication_db: float = 38.0         ## bombinha
@export var furniture_range_db: Vector2 = Vector2(55.0, 70.0)      ## arrasto de móvel: mín e máx
@export var fall_db: float = 80.0               ## queda
@export var voice_talk_db: float = 55.0         ## fala
@export var voice_shout_db: float = 75.0        ## grito
@export var surface_wood_loose_db: float = 6.0  ## madeira solta sob o pé
@export var surface_carpet_db: float = -8.0     ## tapete
@export var surface_tile_db: float = 3.0        ## azulejo
@export var surface_concrete_db: float = 0.0    ## concreto (referência)


## Modificador da superfície, em dB. Superfície desconhecida: push_error e 0,0.
func surface_modifier_db(surface_id: StringName) -> float:
	match surface_id:
		&"wood_loose":
			return surface_wood_loose_db
		&"carpet":
			return surface_carpet_db
		&"tile":
			return surface_tile_db
		&"concrete":
			return surface_concrete_db
	push_error("NoiseLevels.surface_modifier_db: superfície '%s' desconhecida" % [surface_id])
	return 0.0


## Passo de uma marcha sobre uma superfície. Marcha ou superfície desconhecida: push_error e 0,0.
func footstep_level(gait_id: StringName, surface_id: StringName) -> float:
	var base: float = 0.0
	match gait_id:
		&"crawl":
			base = footstep_crawl_db
		&"crouch":
			base = footstep_crouch_db
		&"slow":
			base = footstep_slow_db
		&"walk":
			base = footstep_walk_db
		_:
			push_error("NoiseLevels.footstep_level: marcha '%s' desconhecida" % [gait_id])
			return 0.0
	if not _is_known_surface(surface_id):
		push_error("NoiseLevels.footstep_level: superfície '%s' desconhecida" % [surface_id])
		return 0.0
	return base + surface_modifier_db(surface_id)


## Corrida sobre uma superfície. Superfície desconhecida: push_error e 0,0.
func running_level(surface_id: StringName) -> float:
	if not _is_known_surface(surface_id):
		push_error("NoiseLevels.running_level: superfície '%s' desconhecida" % [surface_id])
		return 0.0
	return running_db + surface_modifier_db(surface_id)


func _is_known_surface(surface_id: StringName) -> bool:
	return surface_id == &"wood_loose" or surface_id == &"carpet" or surface_id == &"tile" \
		or surface_id == &"concrete"

class_name AcousticLevels
extends RefCounted
## AcousticLevels (L1, DATA_STRUCTURES §2.1): níveis iniciais de emissão (dB a 1 m) e modificadores de superfície.
## Funções puras. Mapeamento de nomes: rastejar = crawl, agachado = crouch, andando devagar = slow,
## andando = walk. Pontos de partida: ainda não há Resource para esta tabela (ver relatório F3-001).

const FOOTSTEP_DB: Dictionary = {&"crawl": 18.0, &"crouch": 25.0, &"slow": 32.0, &"walk": 40.0}
const RUNNING_DB: float = 60.0
const COUGH_DB: float = 65.0
const FALL_DB: float = 80.0
## Modificador da superfície sob o pé. Somado a passos e corrida (DATA §2.1).
const SURFACE_DB: Dictionary = {&"wood_loose": 6.0, &"carpet": -8.0, &"tile": 3.0, &"concrete": 0.0}


## Passo de uma marcha sobre uma superfície. Marcha ou superfície desconhecida: push_error e 0,0.
static func footstep_db(gait_id: StringName, surface_id: StringName) -> float:
	if not FOOTSTEP_DB.has(gait_id) or not SURFACE_DB.has(surface_id):
		push_error("AcousticLevels.footstep_db: marcha '%s' ou superfície '%s' desconhecida" % [gait_id, surface_id])
		return 0.0
	return float(FOOTSTEP_DB[gait_id]) + float(SURFACE_DB[surface_id])


## Corrida sobre uma superfície. Superfície desconhecida: push_error e 0,0.
static func running_db(surface_id: StringName) -> float:
	if not SURFACE_DB.has(surface_id):
		push_error("AcousticLevels.running_db: superfície '%s' desconhecida" % [surface_id])
		return 0.0
	return RUNNING_DB + float(SURFACE_DB[surface_id])

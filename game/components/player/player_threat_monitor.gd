class_name PlayerThreatMonitor
extends Node
## PlayerThreatMonitor (L2, Physiological Systems Engineer, F4-006b; COMPONENT_CONTRACTS §5; decisão D4-01):
## ameaça percebida PELO JOGADOR (inimigos vistos e ouvidos, perseguição). Alimenta o estresse (fisiologia) e a
## música adaptativa. Não é a percepção da IA: nada da IA lê este componente nem PlayerHeardNoise (TMN-INV-1, ARC-01).
##
## Ligação, toda feita pelo PlayerRoot (PLR-INV-1; este script não referencia outro componente do jogador):
##   - setup(câmera): a câmera do jogador é o olho da visão;
##   - step(delta) a cada tick, antes de o PlayerRoot montar as entradas da fisiologia;
##   - get_threat_source(): o ThreatSource que o PlayerRoot passa a usar (composição, D4-01);
##   - AcousticWorld.register_player_listener(receive_heard, câmera);
##   - startled(amount) é ligado a PhysiologyComponent.add_startle.
##
## Fórmulas (DATA_STRUCTURES §1.5):
##   seen_proximity = max sobre inimigos vistos de clamp(1 − (d − 3)/12, 0, 1)
##   heard_factor   = max sobre PlayerHeardNoise de inimigo nos últimos 3 s de clamp((perceived_db − 15)/30, 0, 1)
##   threat_level   = max(seen_proximity, 0,5 · heard_factor, in_chase ? 1 : 0)
##
## Decisões de F4-006b (relatório da onda B):
##   - Visão: inimigo no grupo "enemy" com um ponto de amostra no frustum da câmera e linha de visão por raio (máscara
##     das camadas 1, 2 e 7, a mesma do VisionSensor; corpos de inimigos e do jogador não bloqueiam). Pontos de amostra:
##     a origem do inimigo e 0,15 m, 0,9 m e 1,6 m acima dela. d = distância da câmera até o centro do inimigo
##     (origem + 0,9 m, a meia altura do tronco).
##     COMPONENT §5 exige também exposição ≥ 0,15 (LightExposureProbe filho do inimigo) ou d ≤ 3 m; sem sonda, a
##     exposição é 0, então só vale a regra dos 3 m.
##   - Perseguição (in_chase) dura 3 s, a janela de DATA §6.1, a partir de: grito voice_chase_* de inimigo ouvido;
##     corrida (RUNNING) de inimigo ouvida; ou inimigo visto em CHASE. O estado é lido por get_state() do
##     inimigo, se ele expuser esse método (o EnemyController da F4-004 deve expô-lo; sem ele, a visão nunca liga
##     a perseguição). O catálogo §16 proíbe ao monitor consumir chase_started/chase_ended.
##   - Relógio: a soma dos deltas de step(). Um PlayerHeardNoise é carimbado na chegada (latência de 1 tick).
##
## Sinais: threat_changed(level, in_chase) só quando o nível muda ≥ 0,01 ou a perseguição muda (alimenta
## AdaptiveMusic.set_threat); startled(amount) para cada som de outra fonte com 55 dB percebidos ou mais.
## Autor: Gameplay Engineer, com a decisão de fisiologia (Physiological Systems Engineer).

signal threat_changed(level: float, in_chase: bool)
signal startled(amount: float)

const ENEMY_GROUP: StringName = &"enemy"
## Janela de 3 s (DATA §6.1 e COMPONENT §5): perseguição e ruído de inimigo.
const WINDOW_S: float = 3.0
## Valor de "nunca" para o tempo desde o último inimigo visto em perseguição (cabe em JSON).
const NEVER_S: float = 1000000.0
## Fórmula de visão (DATA §1.5): 1 até 3 m; 0 a partir de 15 m.
const SEEN_FULL_DISTANCE_M: float = 3.0
const SEEN_FALLOFF_M: float = 12.0
## Fórmula de audição (DATA §1.5): 0 em 15 dB; 1 em 45 dB.
const HEARD_FLOOR_DB: float = 15.0
const HEARD_SPAN_DB: float = 30.0
## threat_level dá peso 0,5 à audição (DATA §1.5).
const HEARD_THREAT_WEIGHT: float = 0.5
## Regra de visibilidade do inimigo (COMPONENT §5): exposição mínima, ou distância máxima sem exigir luz.
const VISIBLE_LIGHT_MIN: float = 0.15
const VISIBLE_CLOSE_M: float = 3.0
## Máscara dos raios de visão: 1 (world_static) + 2 (world_dynamic) + 64 (vision_occluder, camada 7).
const VISION_MASK: int = 67
const CHASE_SHOUT_PREFIX: String = "voice_chase_"
const ENEMY_STATE_METHOD: StringName = &"get_state"
## Altura do centro usado para pesar a fração de linha de visão (pontos de amostra do inimigo, em metros).
const TORSO_HEIGHT_M: float = 0.9
## Só registra mudança do nível a partir deste passo (evita chamar a música a cada tick por ruído numérico).
const LEVEL_EMIT_STEP: float = 0.01

## Um PlayerHeardNoise de inimigo guardado na janela (DATA §6.1: category, perceived_db, sound_id, age_s).
class HeardEntry:
	extends RefCounted
	var category: Enums.NoiseCategory = Enums.NoiseCategory.BREATHING
	var perceived_db: float = 0.0
	var sound_id: StringName = &""
	var age_s: float = 0.0

var _camera: Camera3D = null
## Amostra da ameaça. O ThreatSource lê este mesmo objeto; o monitor o atualiza em step().
var _state: ThreatSample = ThreatSample.new()
var _source: MonitoredThreatSource = null
var _heard: Array[HeardEntry] = []
var _last_seen_chase_s: float = NEVER_S
var _last_level: float = -1.0
var _last_chase: bool = false


func _init() -> void:
	_source = MonitoredThreatSource.new(_state)


## Câmera do jogador (olho da visão). Sem ela, a visão fica desligada e só a audição conta.
func setup(camera: Camera3D) -> void:
	_camera = camera


## Fonte de ameaça por composição (D4-01): o PlayerRoot a passa a set_threat_source().
func get_threat_source() -> ThreatSource:
	return _source


## Um tick do monitor: envelhece as janelas, mede a visão e a audição e atualiza a amostra. Chamado pelo PlayerRoot.
func step(delta: float) -> void:
	_age_records(delta)
	var seen: float = 0.0
	var seen_in_chase: bool = false
	if _camera != null and is_instance_valid(_camera) and is_inside_tree():
		for node: Node in get_tree().get_nodes_in_group(ENEMY_GROUP):
			var enemy: Node3D = node as Node3D
			if enemy == null or not enemy.is_inside_tree():
				continue
			var proximity: float = _enemy_proximity(enemy)
			if proximity <= 0.0:
				continue
			seen = maxf(seen, proximity)
			if _enemy_in_chase(enemy):
				seen_in_chase = true
	if seen_in_chase:
		_last_seen_chase_s = 0.0
	_state.seen_proximity = seen
	_state.heard_factor = _heard_factor()
	_state.in_chase = _last_seen_chase_s <= WINDOW_S or _has_chase_hearing()
	_state.threat_level = threat_level_for(_state.seen_proximity, _state.heard_factor, _state.in_chase)
	_emit_if_changed()


## Recebe um som de outra fonte audível no ouvido do jogador (só o AcousticWorld chama, pelo listener).
## Sobe o susto a partir de 55 dB percebidos (qualquer fonte que chega aqui) e guarda os sons de inimigo na janela.
func receive_heard(heard: PlayerHeardNoise) -> void:
	if heard == null:
		return
	if heard.perceived_db >= PlayerNoiseMap.STARTLE_THRESHOLD_DB:
		startled.emit(PlayerNoiseMap.startle_amount(heard.perceived_db))
	if not heard.source_is_enemy:
		return
	var entry: HeardEntry = HeardEntry.new()
	entry.category = heard.category
	entry.perceived_db = heard.perceived_db
	entry.sound_id = heard.sound_id
	entry.age_s = 0.0
	_heard.append(entry)


## Fator de proximidade de inimigo visto (DATA §1.5). Ver o cabeçalho.
static func seen_proximity_for(distance_m: float) -> float:
	return clampf(1.0 - (distance_m - SEEN_FULL_DISTANCE_M) / SEEN_FALLOFF_M, 0.0, 1.0)


## Fator de ruído de inimigo ouvido (DATA §1.5) para um som com perceived_db.
static func heard_factor_for(perceived_db: float) -> float:
	return clampf((perceived_db - HEARD_FLOOR_DB) / HEARD_SPAN_DB, 0.0, 1.0)


## Nível de ameaça (DATA §1.5): máximo entre visão, 0,5 da audição e 1 em perseguição.
static func threat_level_for(seen: float, heard: float, in_chase: bool) -> float:
	var chase_term: float = 1.0 if in_chase else 0.0
	return clampf(maxf(maxf(clampf(seen, 0.0, 1.0), HEARD_THREAT_WEIGHT * clampf(heard, 0.0, 1.0)), chase_term), 0.0, 1.0)


## Estado para salvar (DATA §6.1): tempo desde o último inimigo visto em perseguição e os sons de inimigo da janela.
func to_dict() -> Dictionary:
	var heard_list: Array = []
	for entry: HeardEntry in _heard:
		heard_list.append({
			"category": int(entry.category),
			"perceived_db": entry.perceived_db,
			"sound_id": String(entry.sound_id),
			"age_s": entry.age_s,
		})
	return {"last_seen_chase_s": _last_seen_chase_s, "recent_enemy_heard": heard_list}


## Restaura o estado salvo. A perseguição vista e a janela de sons voltam; o estado dos inimigos não é salvo aqui.
func from_dict(data: Dictionary) -> void:
	_last_seen_chase_s = clampf(float(data.get("last_seen_chase_s", NEVER_S)), 0.0, NEVER_S)
	_heard.clear()
	var list: Array = data.get("recent_enemy_heard", [])
	for raw: Variant in list:
		var item: Dictionary = raw
		var entry: HeardEntry = HeardEntry.new()
		entry.category = int(item.get("category", 0)) as Enums.NoiseCategory
		entry.perceived_db = float(item.get("perceived_db", 0.0))
		entry.sound_id = StringName(String(item.get("sound_id", "")))
		entry.age_s = clampf(float(item.get("age_s", 0.0)), 0.0, WINDOW_S)
		_heard.append(entry)
	_state.in_chase = _last_seen_chase_s <= WINDOW_S or _has_chase_hearing()
	_state.heard_factor = _heard_factor()
	_state.threat_level = threat_level_for(_state.seen_proximity, _state.heard_factor, _state.in_chase)


## Envelhece a janela de sons e o tempo de perseguição, e descarta sons com mais de 3 s.
func _age_records(delta: float) -> void:
	_last_seen_chase_s = minf(_last_seen_chase_s + delta, NEVER_S)
	var kept: Array[HeardEntry] = []
	for entry: HeardEntry in _heard:
		entry.age_s += delta
		if entry.age_s <= WINDOW_S:
			kept.append(entry)
	_heard = kept


## Proximidade do inimigo (DATA §1.5) se ele é visto agora; 0 se não é visto.
func _enemy_proximity(enemy: Node3D) -> float:
	var origin: Vector3 = enemy.global_position
	var centre: Vector3 = origin + Vector3(0.0, TORSO_HEIGHT_M, 0.0)
	var distance_m: float = _camera.global_position.distance_to(centre)
	if _enemy_light(enemy) < VISIBLE_LIGHT_MIN and distance_m > VISIBLE_CLOSE_M:
		return 0.0
	if not _has_line_of_sight(origin):
		return 0.0
	return seen_proximity_for(distance_m)


## Verdadeiro se algum ponto de amostra do inimigo está no frustum da câmera e tem raio livre até a câmera.
func _has_line_of_sight(origin: Vector3) -> bool:
	var space: PhysicsDirectSpaceState3D = _camera.get_world_3d().direct_space_state
	var eye: Vector3 = _camera.global_position
	for height: float in _sample_heights():
		var point: Vector3 = origin + Vector3(0.0, height, 0.0)
		if not _camera.is_position_in_frustum(point):
			continue
		var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(eye, point, VISION_MASK)
		if space.intersect_ray(query).is_empty():
			return true
	return false


## Alturas dos pontos de amostra do inimigo, acima da origem (metros). Constante, sem alocação por inimigo.
func _sample_heights() -> PackedFloat32Array:
	return PackedFloat32Array([0.15, TORSO_HEIGHT_M, 1.6])


## Exposição à luz sobre o inimigo, lida do LightExposureProbe filho dele. Sem sonda: 0.
func _enemy_light(enemy: Node3D) -> float:
	for child: Node in enemy.get_children():
		var probe: LightExposureProbe = child as LightExposureProbe
		if probe != null:
			return probe.get_exposure()
	return 0.0


## Verdadeiro se o inimigo expõe get_state() e está em CHASE. Sem o método, falso.
func _enemy_in_chase(enemy: Node3D) -> bool:
	if not enemy.has_method(ENEMY_STATE_METHOD):
		return false
	return int(enemy.call(ENEMY_STATE_METHOD)) == Enums.EnemyState.CHASE


## Maior fator de audição entre os sons de inimigo da janela.
func _heard_factor() -> float:
	var best: float = 0.0
	for entry: HeardEntry in _heard:
		best = maxf(best, heard_factor_for(entry.perceived_db))
	return best


## Verdadeiro se algum som de inimigo da janela é corrida ou grito de perseguição.
func _has_chase_hearing() -> bool:
	for entry: HeardEntry in _heard:
		if entry.category == Enums.NoiseCategory.RUNNING:
			return true
		if String(entry.sound_id).begins_with(CHASE_SHOUT_PREFIX):
			return true
	return false


func _emit_if_changed() -> void:
	var level: float = _state.threat_level
	var chase: bool = _state.in_chase
	if absf(level - _last_level) < LEVEL_EMIT_STEP and chase == _last_chase:
		return
	_last_level = level
	_last_chase = chase
	threat_changed.emit(level, chase)

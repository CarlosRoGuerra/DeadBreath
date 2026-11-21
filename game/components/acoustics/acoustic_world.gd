class_name AcousticWorld
extends Node
## AcousticWorld (L2, COMPONENT_CONTRACTS §6.2, §6.4 e §6.5; DATA_STRUCTURES §2.3 e §2.5; F3-002): mundo acústico do
## nível, um por nível, no grupo "acoustic_world". Recebe NoiseEvents por emit_noise (preenche room_id), resolve cada um
## no tick de prioridade -60 e:
##   - emite noise_resolved_for_player(event, result) para todo evento (L3 e debug);
##   - entrega PlayerHeardNoise ao ouvinte do jogador (register_player_listener) para eventos de OUTRA fonte audíveis
##     no ouvido, com o limiar efetivo do jogador (10 dB, margem 0, piso da sala);
##   - pede legendas (EventBus.subtitle_requested) para os sons relevantes audíveis no ouvido do jogador.
## Geometria: com RoomVolume no nível, a propagação é AcousticGraph.propagate, e as portas com door sincronizam os
## portais. Sem RoomVolume (cena mínima e testes da F2), volta à regra provisória: AcousticPropagation.perceive, só
## distância. Clima: piso por sala no grafo e trovão (+20 dB por 2,5 s) com RNG próprio semeável.
## Invariantes: NOI-INV-1 (emit_noise é o único caminho para a IA), NOI-INV-2 (o nível do jogador vem de propagate),
## NOI-INV-3 (propagação pura), NOI-INV-4 (PlayerHeardNoise sem posição, id nem sala da fonte).

signal noise_resolved_for_player(event: NoiseEvent, result: PropagationResult)
## Trovão começou (COMPONENT_CONTRACTS §6.5): para a ambiência (NoiseAudioRouter) e para o level design.
signal thunder_started(duration_s: float)

const GROUP: StringName = &"acoustic_world"
const PROCESS_PRIORITY: int = -60
const LOG_CATEGORY: StringName = &"acoustics"
const CONFIG_PATH: String = "res://content/data/acoustics/acoustic_config.tres"
const PLAYER_SOURCE_ID: StringName = &"player"
## Fonte causada pelo jogador (revisão F3-010, R3-04): "player_<...>", ex.: objeto que ele soltou ou arremessou.
const PLAYER_CAUSED_PREFIX: String = "player_"
## Fonte inimiga: o id do emissor começa com este prefixo (convenção F3-002; a F4 confirma).
const ENEMY_SOURCE_PREFIX: String = "enemy"
## Ouvinte do jogador (DATA §2.3): hearing_threshold_db 10 e margem 0 sobre o piso da sala.
const PLAYER_HEARING_DB: float = 10.0
const PLAYER_MARGIN_DB: float = 0.0
## Trovão (DATA §2.3): +20 dB no piso por 2,5 s.
const THUNDER_OFFSET_DB: float = 20.0
const THUNDER_DURATION_S: float = 2.5
## Legendas: tosse, porta, falas e passos próximos (decisão F3-002, ver _maybe_subtitle).
const SUBTITLE_COUGH_SOUND: StringName = &"cough"
const SUBTITLE_MIN_DURATION_S: float = 1.5
const SUBTITLE_COOLDOWN_S: float = 2.0
## Passo "próximo": nível percebido pelo menos este valor acima do limiar do jogador.
const NEAR_MARGIN_DB: float = 10.0

## Config de propagação (DATA §2.2). Vazio: usa content/data/acoustics/acoustic_config.tres.
@export var config: AcousticConfig
## Trovão aleatório no nível (desligado por padrão; o level design liga em níveis com chuva).
@export var thunder_enabled: bool = false
@export var thunder_interval_min_s: float = 60.0
@export var thunder_interval_max_s: float = 180.0
## Semente do RNG próprio do clima. O mesmo valor dá o mesmo calendário de trovões.
@export var weather_seed: int = 1

var _queue: Array[NoiseEvent] = []
var _ear: Node3D = null
var _clock_s: float = 0.0
var _next_id: int = 1
var _warned_no_listener: bool = false
var _graph: AcousticGraph = null
var _graph_dirty: bool = true
var _has_geometry: bool = false
var _linked_doors: Array[Door] = []
var _link_callbacks: Array[Callable] = []
var _player_on_heard: Callable = Callable()
var _weather_rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _weather_offset_db: float = 0.0
var _thunder_remaining_s: float = 0.0
var _next_thunder_in_s: float = -1.0
var _subtitle_last_s: Dictionary = {}


func _ready() -> void:
	add_to_group(GROUP)
	process_physics_priority = PROCESS_PRIORITY
	_weather_rng.seed = weather_seed


func _physics_process(delta: float) -> void:
	advance(delta)


## Um tick do mundo: avança o relógio e o clima e resolve a fila. O tick de física chama isto; os testes chamam direto.
func advance(delta: float) -> void:
	_clock_s += delta
	_update_weather(delta)
	flush()


## Tempo do mundo (s), avançado no tick de física. Os timestamps dos eventos usam este relógio.
func now() -> float:
	return _clock_s


## Ouvido do jogador: o ponto onde os sons são percebidos (a câmera). Sem ouvido definido, usa a câmera ativa da
## viewport; sem câmera, a origem, com um aviso. Não entrega PlayerHeardNoise (isso é register_player_listener).
func set_player_ear(ear: Node3D) -> void:
	_ear = ear


## Ponte para o ouvinte do jogador (COMPONENT_CONTRACTS §6.5). on_heard(heard: PlayerHeardNoise) é chamado para cada
## evento de OUTRA fonte (não o próprio jogador) audível no ouvido. Só diz "é inimigo ou não": sem posição, id nem sala.
func register_player_listener(on_heard: Callable, ear: Node3D) -> void:
	_player_on_heard = on_heard
	_ear = ear


func unregister_player_listener() -> void:
	_player_on_heard = Callable()


## O jogador ou algo que ele causou ("player_<...>"). O ouvinte do jogador não recebe esses eventos: sem susto e sem
## legenda pelo próprio barulho. A IA (F4) ouve normalmente, na posição do evento.
static func is_player_source(source_id: StringName) -> bool:
	return source_id == PLAYER_SOURCE_ID or String(source_id).begins_with(PLAYER_CAUSED_PREFIX)


## Enfileira um NoiseEvent. O id, o timestamp e a sala (room_at da posição, quando há geometria) são atribuídos aqui.
## Resolvido no próximo tick (-60).
func emit_noise(event: NoiseEvent) -> void:
	if event == null:
		Log.error(LOG_CATEGORY, "emit_noise sem NoiseEvent; nada enfileirado")
		return
	_ensure_graph()
	if event.id == 0:
		event.id = _next_id
		_next_id += 1
	event.timestamp = _clock_s
	if _has_geometry:
		event.room_id = _graph.room_at(event.position)
	_queue.append(event)


func pending_count() -> int:
	return _queue.size()


## Resolve a fila agora. Chamado pelo tick de física; os testes podem chamar direto para determinismo.
func flush() -> void:
	if _queue.is_empty():
		return
	_ensure_graph()
	var listener: Vector3 = _listener_position()
	var batch: Array[NoiseEvent] = []
	batch.append_array(_queue)
	_queue.clear()
	for event: NoiseEvent in batch:
		var result: PropagationResult = _propagate(event, listener)
		noise_resolved_for_player.emit(event, result)
		_deliver_to_player(event, result)


## Grafo do nível (constrói se preciso). Sem RoomVolume, o grafo existe mas está vazio (has_geometry() = false).
func get_graph() -> AcousticGraph:
	_ensure_graph()
	return _graph


## Há salas no nível? Se não, a propagação é a regra provisória da F2.
func has_geometry() -> bool:
	_ensure_graph()
	return _has_geometry


## Reconstrói o grafo a partir dos RoomVolume e Portal do nível (depois de mudanças na cena).
func rebuild_graph() -> void:
	_graph_dirty = true
	_ensure_graph()


## Offset de trovão somado ao piso de todas as salas (0,0 ou THUNDER_OFFSET_DB).
func get_weather_offset() -> float:
	return _weather_offset_db


## Limiar efetivo de audibilidade do jogador no ponto (DATA §2.3). Sem geometria: só o limiar de audição.
func player_threshold_db(position: Vector3) -> float:
	_ensure_graph()
	if _has_geometry:
		return _graph.effective_threshold_db(position, PLAYER_HEARING_DB, PLAYER_MARGIN_DB)
	return PLAYER_HEARING_DB


func _propagate(event: NoiseEvent, listener: Vector3) -> PropagationResult:
	if _has_geometry:
		return _graph.propagate(event, listener)
	return AcousticPropagation.perceive(event, listener)


func _listener_position() -> Vector3:
	if _ear != null and is_instance_valid(_ear):
		return _ear.global_position
	if is_inside_tree() and get_viewport() != null:
		var camera: Camera3D = get_viewport().get_camera_3d()
		if camera != null:
			return camera.global_position
	if not _warned_no_listener:
		_warned_no_listener = true
		Log.warn(LOG_CATEGORY, "AcousticWorld sem ouvido do jogador nem câmera ativa; propagando a partir da origem")
	return Vector3.ZERO


## Entrega ao ouvinte do jogador (PlayerHeardNoise, outras fontes) e pede legendas. Só com ouvido definido.
func _deliver_to_player(event: NoiseEvent, result: PropagationResult) -> void:
	if _ear == null or not is_instance_valid(_ear):
		return
	var threshold: float = player_threshold_db(_ear.global_position)
	if result.perceived_db < threshold:
		return
	if _player_on_heard.is_valid() and not is_player_source(event.source_id):
		var heard: PlayerHeardNoise = PlayerHeardNoise.new()
		heard.category = event.category
		heard.perceived_db = result.perceived_db
		heard.source_is_enemy = String(event.source_id).begins_with(ENEMY_SOURCE_PREFIX)
		heard.sound_id = event.sound_id
		heard.timestamp = event.timestamp
		_player_on_heard.call(heard)
	_maybe_subtitle(event, result.perceived_db, threshold)


## Legendas (decisão F3-002): tosse (sound_id cough), porta e falas sempre que audíveis; passos e corrida só de outra
## fonte e "próximos" (nível ≥ limiar + 10 dB). Um mesmo sound_id não repete antes de 2 s. Duração ≥ 1,5 s.
## A UI é do Gameplay; aqui só o pedido EventBus.subtitle_requested(&"subtitle.<sound_id>", duration).
func _maybe_subtitle(event: NoiseEvent, perceived_db: float, threshold_db: float) -> void:
	if event.sound_id == &"":
		return
	var relevant: bool = false
	match event.category:
		Enums.NoiseCategory.COUGHING:
			relevant = event.sound_id == SUBTITLE_COUGH_SOUND
		Enums.NoiseCategory.DOOR, Enums.NoiseCategory.VOICE:
			relevant = true
		Enums.NoiseCategory.FOOTSTEP, Enums.NoiseCategory.RUNNING:
			relevant = not is_player_source(event.source_id) and perceived_db >= threshold_db + NEAR_MARGIN_DB
	if not relevant:
		return
	var last_s: float = float(_subtitle_last_s.get(event.sound_id, -INF))
	if _clock_s - last_s < SUBTITLE_COOLDOWN_S:
		return
	_subtitle_last_s[event.sound_id] = _clock_s
	var key: StringName = StringName("subtitle." + String(event.sound_id))
	EventBus.subtitle_requested.emit(key, maxf(event.duration, SUBTITLE_MIN_DURATION_S))


## Clima: o trovão começa com intervalo aleatório (RNG próprio, semeado) e dura THUNDER_DURATION_S.
func _update_weather(delta: float) -> void:
	if _thunder_remaining_s > 0.0:
		_thunder_remaining_s -= delta
		if _thunder_remaining_s <= 0.0:
			_thunder_remaining_s = 0.0
			_set_weather_offset(0.0)
	if not thunder_enabled:
		return
	if _next_thunder_in_s < 0.0:
		_next_thunder_in_s = _roll_thunder_interval()
	_next_thunder_in_s -= delta
	if _next_thunder_in_s <= 0.0:
		_start_thunder()
		_next_thunder_in_s = _roll_thunder_interval()


func _roll_thunder_interval() -> float:
	var low: float = minf(thunder_interval_min_s, thunder_interval_max_s)
	var high: float = maxf(thunder_interval_min_s, thunder_interval_max_s)
	return _weather_rng.randf_range(low, high)


func _start_thunder() -> void:
	_thunder_remaining_s = THUNDER_DURATION_S
	_set_weather_offset(THUNDER_OFFSET_DB)
	thunder_started.emit(THUNDER_DURATION_S)


func _set_weather_offset(offset_db: float) -> void:
	_weather_offset_db = offset_db
	if _graph != null:
		_graph.set_weather_floor_offset(offset_db)


## Monta o grafo a partir do nível quando há mudanças pendentes. Fora da árvore não monta (o nível ainda não existe).
func _ensure_graph() -> void:
	if not _graph_dirty and _graph != null:
		return
	if not is_inside_tree():
		if _graph == null:
			_graph = AcousticGraph.new(_resolved_config())
		return
	_graph_dirty = false
	_unlink_doors()
	_graph = AcousticGraph.new(_resolved_config())
	_has_geometry = false
	_graph.set_weather_floor_offset(_weather_offset_db)
	for node: Node in _level_nodes(RoomVolume.GROUP):
		var room: RoomVolume = node as RoomVolume
		if room == null:
			continue
		var bounds: AABB = room.bounds_world()
		if bounds.size.x <= 0.0 or bounds.size.y <= 0.0 or bounds.size.z <= 0.0:
			Log.error(LOG_CATEGORY, "RoomVolume '%s' sem BoxShape3D válido; sala ignorada" % [room.room_id])
			continue
		_graph.add_room(room.room_id, bounds, room.ambient_floor_db)
		_has_geometry = true
	for node: Node in _level_nodes(Portal.GROUP):
		var portal: Portal = node as Portal
		if portal == null:
			continue
		_graph.add_portal(portal.portal_id, portal.room_a, portal.room_b, portal.global_position)
		_link_door(portal)


func _resolved_config() -> AcousticConfig:
	if config != null:
		return config
	var loaded: AcousticConfig = load(CONFIG_PATH) as AcousticConfig
	if loaded == null:
		Log.error(LOG_CATEGORY, "acoustic_config.tres ausente; usando os padrões do código")
		return AcousticConfig.new()
	return loaded


## Nós do grupo que são descendentes do pai deste mundo (o nível). Só essa árvore conta.
func _level_nodes(group: StringName) -> Array[Node]:
	var found: Array[Node] = []
	if not is_inside_tree():
		return found
	var scope: Node = get_parent() if get_parent() != null else self
	for node: Node in get_tree().get_nodes_in_group(group):
		if scope.is_ancestor_of(node):
			found.append(node)
	return found


## Liga o portal à porta: o estado inicial vem da porta e as mudanças chegam por state_changed.
func _link_door(portal: Portal) -> void:
	if portal.door.is_empty():
		return
	var door: Door = portal.get_node_or_null(portal.door) as Door
	if door == null:
		Log.error(LOG_CATEGORY, "Portal '%s': porta em '%s' não encontrada; portal fica aberto" % [
			portal.portal_id, str(portal.door)])
		return
	_graph.set_portal_open(portal.portal_id, _door_is_open(door))
	var callback: Callable = _on_door_state_changed.bind(portal.portal_id)
	door.state_changed.connect(callback)
	_linked_doors.append(door)
	_link_callbacks.append(callback)


func _unlink_doors() -> void:
	for index: int in range(_linked_doors.size()):
		var door: Door = _linked_doors[index]
		var callback: Callable = _link_callbacks[index]
		if is_instance_valid(door) and door.state_changed.is_connected(callback):
			door.state_changed.disconnect(callback)
	_linked_doors.clear()
	_link_callbacks.clear()


## OPEN = aberto; CLOSED e LOCKED = fechado. Porta em movimento conta como aberta (is_moving).
func _door_is_open(door: Door) -> bool:
	return door.get_state() == Door.State.OPEN or door.is_moving()


func _on_door_state_changed(_old_state: int, new_state: int, portal_id: StringName) -> void:
	if _graph == null:
		return
	_graph.set_portal_open(portal_id, new_state == Door.State.OPEN)

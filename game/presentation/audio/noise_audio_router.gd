class_name NoiseAudioRouter
extends Node
## NoiseAudioRouter (L3, COMPONENT_CONTRACTS §14; F3-003b): toca no espaço os eventos de som do mundo, isto é, todo
## NoiseEvent de AcousticWorld.noise_resolved_for_player que NÃO é do corpo do jogador. Os sons do corpo (source player
## e categorias BREATHING, WHEEZING, COUGHING, MEDICATION) são do BreathingAudio. Os passos e as portas do próprio jogador
## são do mundo e passam aqui.
##
## Decisões (F3-003b):
##   - posição: result.entry_point. Na propagação direta é a fonte; quando o som chega por um portal, é o portal por onde
##     ele entra na sala do ouvinte. A direção percebida é a da passagem, não a da parede onde a fonte está.
##   - reverb: o barramento de reverb da sala do OUVINTE (RoomVolume.reverb_bus), porque o espaço que o jogador ouve é o
##     dele, mesmo quando o som nasceu noutra sala. Sem sala (cena sem geometria) ou sala sem barramento: Master.
##   - volume: NoiseGain.gain_for_db(perceived_db), a mesma regra de ganho do BreathingAudio (DATA §2.4).
##   - atenuação nativa desligada (NOI-INV-2): só o panning do AudioStreamPlayer3D.
##
## Audibilidade: só toca o que chega ao ouvido acima do limiar do jogador (DATA §2.3; AcousticWorld.player_threshold_db).
##
## Escolha de arquivo: sound_id; nos passos (footstep_<superfície>) a marcha vem da intensidade, descontado o
## modificador de superfície de DATA §2.1 (o emissor de passos já soma esse modificador); RUNNING é sempre corrida.
## Nos impactos (OBJECT_IMPACT, sound_id impact), a faixa de intensidade escolhe leve, médio ou pesado.
## Pitch: variação de ±4 % (PITCH_JITTER). Vozes simultâneas: MAX_VOICES; a mais antiga sai quando passa do limite.

const PLAYER_SOURCE: StringName = &"player"
const LOG_CATEGORY: StringName = &"audio"
const MASTER_BUS: StringName = &"Master"
const MAX_VOICES: int = 12
const PITCH_JITTER: float = 0.04
const MAX_LOG_ENTRIES: int = 256
const FOOTSTEP_PREFIX: String = "footstep_"
const IMPACT_SOUND: StringName = &"impact"
## Modificadores de superfície (DATA §2.1; espelham noise_levels.tres).
const SURFACE_OFFSET_DB: Dictionary = {"wood": 6.0, "carpet": -8.0, "tile": 3.0, "concrete": 0.0}
## Fronteiras de marcha: nível sem o modificador. Entre os níveis de DATA §2.1 (18, 25, 32, 40 e corrida 60),
## no ponto médio entre vizinhos: 21,5; 28,5; 36 e 50.
const GAIT_BOUND_CRAWL_DB: float = 21.5
const GAIT_BOUND_CROUCH_DB: float = 28.5
const GAIT_BOUND_SLOW_DB: float = 36.0
const GAIT_BOUND_WALK_DB: float = 50.0
## Impactos (OBJECT_IMPACT 50 a 80 dB, DATA §2.1): leve abaixo de 60, médio até 70, pesado acima.
const IMPACT_LIGHT_MAX_DB: float = 60.0
const IMPACT_MEDIUM_MAX_DB: float = 70.0

## Voz 3D tocada: sound_id, file, variation, gait, gain_db, pitch, bus, perceived_db, category, position, event_id.
var played_log: Array[Dictionary] = []

var _clips: WorldClips = WorldClips.new()
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _world: AcousticWorld = null
var _listener: Node3D = null
var _voices: Array[AudioStreamPlayer3D] = []
var _warned: Dictionary = {}


func _ready() -> void:
	_rng.randomize()
	_clips.load_manifest()
	call_deferred("_bind_group_world")


## Liga ao AcousticWorld. Religar desliga o anterior.
func bind_world(world: AcousticWorld) -> void:
	if _world == world:
		return
	if _world != null and _world.noise_resolved_for_player.is_connected(_on_noise_resolved):
		_world.noise_resolved_for_player.disconnect(_on_noise_resolved)
	_world = world
	if _world != null and not _world.noise_resolved_for_player.is_connected(_on_noise_resolved):
		_world.noise_resolved_for_player.connect(_on_noise_resolved)


## Ouvido do jogador (a câmera). Sem definição, usa a câmera ativa da viewport.
func set_listener(listener: Node3D) -> void:
	_listener = listener


func set_random_seed(seed_value: int) -> void:
	_rng.seed = seed_value


func active_voice_count() -> int:
	return _voices.size()


## Marcha de um passo a partir da intensidade (descontado o modificador da superfície).
static func gait_for_level(level_db: float, surface: String) -> String:
	var base: float = level_db - float(SURFACE_OFFSET_DB.get(surface, 0.0))
	if base < GAIT_BOUND_CRAWL_DB:
		return "crawl"
	if base < GAIT_BOUND_CROUCH_DB:
		return "crouch"
	if base < GAIT_BOUND_SLOW_DB:
		return "slow"
	if base < GAIT_BOUND_WALK_DB:
		return "walk"
	return "run"


## Faixa do impacto de objeto pela intensidade.
static func impact_for_level(level_db: float) -> String:
	if level_db < IMPACT_LIGHT_MAX_DB:
		return "light"
	if level_db <= IMPACT_MEDIUM_MAX_DB:
		return "medium"
	return "heavy"


## Arquivo escolhido para um evento: {"sound": StringName, "gait": String}. Vazio se o evento não tem som do mundo.
static func choose_sound(event: NoiseEvent) -> Dictionary:
	if event.sound_id == &"":
		return {}
	var sound_text: String = String(event.sound_id)
	if (event.category == Enums.NoiseCategory.FOOTSTEP or event.category == Enums.NoiseCategory.RUNNING) \
			and sound_text.begins_with(FOOTSTEP_PREFIX):
		var surface: String = sound_text.trim_prefix(FOOTSTEP_PREFIX)
		var gait: String = "run" if event.category == Enums.NoiseCategory.RUNNING \
			else gait_for_level(event.intensity_db, surface)
		return {"sound": StringName(sound_text), "gait": gait}
	if event.category == Enums.NoiseCategory.OBJECT_IMPACT and event.sound_id == IMPACT_SOUND:
		return {"sound": StringName("impact_" + impact_for_level(event.intensity_db)), "gait": ""}
	return {"sound": event.sound_id, "gait": ""}


static func is_body_category(category: Enums.NoiseCategory) -> bool:
	return category == Enums.NoiseCategory.BREATHING \
		or category == Enums.NoiseCategory.WHEEZING \
		or category == Enums.NoiseCategory.COUGHING \
		or category == Enums.NoiseCategory.MEDICATION


func _on_noise_resolved(event: NoiseEvent, result: PropagationResult) -> void:
	if event.source_id == PLAYER_SOURCE and is_body_category(event.category):
		return
	if _world != null and result.perceived_db < _world.player_threshold_db(_listener_position()):
		return
	var choice: Dictionary = choose_sound(event)
	if choice.is_empty():
		return
	if not _clips.is_loaded():
		_warn_once("no-library", "biblioteca de sons do mundo vazia; nada tocado")
		return
	var entry: Dictionary = _clips.pick(choice["sound"], choice["gait"], _rng)
	if entry.is_empty():
		_warn_once("missing:%s/%s" % [choice["sound"], choice["gait"]],
			"sem arquivo para %s (marcha %s)" % [choice["sound"], choice["gait"]])
		return
	var gain: float = NoiseGain.gain_for_db(result.perceived_db)
	var pitch: float = 1.0 + (2.0 * _rng.randf() - 1.0) * PITCH_JITTER
	_play(entry, gain, pitch, result, event, choice)


func _play(entry: Dictionary, gain: float, pitch: float, result: PropagationResult, event: NoiseEvent,
		choice: Dictionary) -> void:
	var bus: StringName = _bus_for_listener()
	var voice: AudioStreamPlayer3D = AudioStreamPlayer3D.new()
	voice.stream = entry["stream"]
	voice.attenuation_model = AudioStreamPlayer3D.ATTENUATION_DISABLED
	voice.volume_db = gain
	voice.pitch_scale = pitch
	voice.bus = bus
	add_child(voice)
	if is_inside_tree():
		voice.global_position = result.entry_point
	voice.finished.connect(_on_voice_finished.bind(voice))
	voice.play()
	_voices.append(voice)
	_enforce_voice_limit()
	played_log.append({
		"sound_id": choice["sound"],
		"file": entry["file"],
		"gait": choice["gait"],
		"variation": entry["variation"],
		"gain_db": gain,
		"pitch": pitch,
		"bus": bus,
		"perceived_db": result.perceived_db,
		"category": event.category,
		"position": result.entry_point,
		"event_id": event.id,
	})
	if played_log.size() > MAX_LOG_ENTRIES:
		played_log.remove_at(0)


func _enforce_voice_limit() -> void:
	while _voices.size() > MAX_VOICES:
		var oldest: AudioStreamPlayer3D = _voices.pop_front()
		if is_instance_valid(oldest):
			oldest.stop()
			oldest.queue_free()


func _on_voice_finished(voice: AudioStreamPlayer3D) -> void:
	_voices.erase(voice)
	if is_instance_valid(voice):
		voice.queue_free()


## Barramento de reverb da sala do ouvinte (RoomVolume.reverb_bus). Master sem sala, sem barramento na sala ou
## com barramento inexistente (com aviso uma vez).
func _bus_for_listener() -> StringName:
	if _world == null or not _world.has_geometry():
		return MASTER_BUS
	var room: StringName = _world.get_graph().room_at(_listener_position())
	var buses: Dictionary = _room_buses()
	if not buses.has(room):
		return MASTER_BUS
	var bus_name: StringName = buses[room]
	if bus_name == &"":
		return MASTER_BUS
	if AudioServer.get_bus_index(String(bus_name)) < 0:
		_warn_once("bus:" + String(bus_name), "barramento '%s' da sala não existe; usando Master" % bus_name)
		return MASTER_BUS
	return bus_name


## Sala (room_id) -> reverb_bus, para as salas do mesmo nível do AcousticWorld.
func _room_buses() -> Dictionary:
	var out: Dictionary = {}
	if _world == null or not is_inside_tree():
		return out
	var scope: Node = _world.get_parent() if _world.get_parent() != null else _world
	for node: Node in get_tree().get_nodes_in_group(RoomVolume.GROUP):
		var room: RoomVolume = node as RoomVolume
		if room == null or not scope.is_ancestor_of(room):
			continue
		out[room.room_id] = room.reverb_bus
	return out


func _listener_position() -> Vector3:
	if _listener != null and is_instance_valid(_listener):
		return _listener.global_position
	if is_inside_tree() and get_viewport() != null:
		var camera: Camera3D = get_viewport().get_camera_3d()
		if camera != null:
			return camera.global_position
	return Vector3.ZERO


func _bind_group_world() -> void:
	if _world != null or not is_inside_tree():
		return
	var world: AcousticWorld = get_tree().get_first_node_in_group(AcousticWorld.GROUP) as AcousticWorld
	if world != null:
		bind_world(world)


func _warn_once(key: String, message: String) -> void:
	if _warned.has(key):
		return
	_warned[key] = true
	Log.warn(LOG_CATEGORY, message)

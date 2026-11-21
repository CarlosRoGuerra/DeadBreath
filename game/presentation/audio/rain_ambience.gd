class_name RainAmbience
extends Node
## RainAmbience (L3, COMPONENT_CONTRACTS §14; F3-003b): ambiência de chuva e trovão. Não é evento de ruído: é o leito do
## ambiente, por isso não passa pelo AcousticWorld como fonte. A camada muda com o piso de ruído da sala do ouvinte
## (DATA §2.3): abaixo de 25 dB é interna (rain_interior), de 25 a 33 é com janela (rain_window), a partir de 33 é
## exterior (rain_exterior). Fora de qualquer sala, o piso é o exterior (38 dB). A troca de camada é um crossfade de
## potência constante de CROSSFADE_S segundos; a mudança de piso dentro da mesma camada desliza o ganho.
##
## Coerência com o piso (DATA §2.3): a saída de cada camada cai em BODY_REFERENCE_DB pelo mesmo caminho dos sons do
## mundo (NoiseGain). Ou seja: o nível que o jogador ouve da chuva é o piso da sala, na mesma escala dos eventos, e
## o que a IA usa como mascaramento é o mesmo número (piso + offset de trovão).
##
## Trovão: thunder_started(duration) do AcousticWorld toca thunder_rumble (sempre) e thunder_crack (com chance). O
## nível ouvido é o do mascaramento que ele cria: piso da sala + THUNDER_OFFSET_DB, pela regra de NoiseGain (revisão
## F3-010, R3-07; ver thunder_gain_for_floor).
## Sem sinal de tempo real: tick(delta) é chamado por _process; os testes chamam direto.

const LAYER_INTERIOR: StringName = &"rain_interior"
const LAYER_WINDOW: StringName = &"rain_window"
const LAYER_EXTERIOR: StringName = &"rain_exterior"
const LAYERS: Array[StringName] = [&"rain_interior", &"rain_window", &"rain_exterior"]
const LOG_CATEGORY: StringName = &"audio"
## Piso abaixo deste valor: camada interna (DATA §2.3: porão 12 e cômodo interno 22).
const INTERIOR_MAX_FLOOR_DB: float = 25.0
## Piso a partir deste valor: camada exterior (DATA §2.3: exterior 38). Entre os dois: janela (28).
const EXTERIOR_MIN_FLOOR_DB: float = 33.0
const OUTSIDE_FLOOR_DB: float = 38.0
const CLIP_REF_DBFS: float = -24.0
const CROSSFADE_S: float = 2.0
## Velocidade do deslize de ganho entre salas da mesma camada (dB por segundo).
const GAIN_SLEW_DB_PER_S: float = 20.0
const MIN_LAYER_DB: float = -80.0
const THUNDER_RUMBLE: StringName = &"thunder_rumble"
const THUNDER_CRACK: StringName = &"thunder_crack"
const THUNDER_CRACK_CHANCE: float = 0.5
const MAX_THUNDER_VOICES: int = 4
const MAX_LOG_ENTRIES: int = 128

## Trovão tocado: sound_id, file, gain_db, crack (bool), start_s.
var played_log: Array[Dictionary] = []

var _clips: WorldClips = WorldClips.new()
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _world: AcousticWorld = null
var _listener: Node3D = null
var _players: Dictionary = {}
var _fade: Dictionary = {}
var _gain_db: Dictionary = {}
var _target_gain_db: Dictionary = {}
var _active: StringName = LAYER_EXTERIOR
var _floor_db: float = OUTSIDE_FLOOR_DB
var _clock_s: float = 0.0
var _thunder_voices: Array[AudioStreamPlayer] = []


func _ready() -> void:
	_rng.randomize()
	_clips.load_manifest()
	for layer: StringName in LAYERS:
		var entry: Dictionary = _clips.first(layer)
		var player: AudioStreamPlayer = AudioStreamPlayer.new()
		player.name = String(layer)
		if not entry.is_empty():
			player.stream = entry["stream"]
		player.volume_db = MIN_LAYER_DB
		add_child(player)
		player.play()
		_players[layer] = player
		_fade[layer] = 0.0
		_gain_db[layer] = MIN_LAYER_DB
		_target_gain_db[layer] = MIN_LAYER_DB
	_fade[LAYER_EXTERIOR] = 1.0
	call_deferred("_bind_group_world")


func _process(delta: float) -> void:
	tick(delta)


## Um tick: atualiza a sala do ouvinte, a camada ativa e os volumes (crossfade e deslize de ganho).
func tick(delta: float) -> void:
	_clock_s += delta
	_update_listener_floor()
	var step: float = delta / maxf(CROSSFADE_S, 0.0001)
	for layer: StringName in LAYERS:
		var target_fade: float = 1.0 if layer == _active else 0.0
		_fade[layer] = move_toward(float(_fade[layer]), target_fade, step)
		_gain_db[layer] = move_toward(float(_gain_db[layer]), float(_target_gain_db[layer]), GAIN_SLEW_DB_PER_S * delta)
		_players[layer].volume_db = layer_output_db(layer)


## Liga ao AcousticWorld: o trovão vem do sinal thunder_started. Religar desliga o anterior.
func bind_world(world: AcousticWorld) -> void:
	if _world == world:
		return
	if _world != null and _world.thunder_started.is_connected(_on_thunder_started):
		_world.thunder_started.disconnect(_on_thunder_started)
	_world = world
	if _world != null and not _world.thunder_started.is_connected(_on_thunder_started):
		_world.thunder_started.connect(_on_thunder_started)


func set_listener(listener: Node3D) -> void:
	_listener = listener


func set_random_seed(seed_value: int) -> void:
	_rng.seed = seed_value


## Camada para um piso de ruído (DATA §2.3).
static func layer_for_floor(floor_db: float) -> StringName:
	if floor_db < INTERIOR_MAX_FLOOR_DB:
		return LAYER_INTERIOR
	if floor_db < EXTERIOR_MIN_FLOOR_DB:
		return LAYER_WINDOW
	return LAYER_EXTERIOR


## Ganho do leito de chuva para um piso: o mesmo caminho dos eventos (NoiseGain), com o RMS do clip compensado.
## Saída = floor − BODY_REFERENCE_DB − 24 dBFS, para qualquer camada (ver cabeçalho).
static func gain_for_floor(floor_db: float, clip_rms_dbfs: float) -> float:
	var raw: float = floor_db - NoiseGain.BODY_REFERENCE_DB - (clip_rms_dbfs - CLIP_REF_DBFS)
	return clampf(raw, MIN_LAYER_DB, 0.0)


## Ganho de trovão no piso dado: o trovão soa no nível do limiar que ele impõe (piso + 20 dB, AcousticWorld), pela
## mesma regra dos eventos. Ao ar livre (38) = 58 dB, +3,25 dB; cômodo interno (22) = 42 dB, −3 dB.
static func thunder_gain_for_floor(floor_db: float) -> float:
	return NoiseGain.gain_for_db(floor_db + AcousticWorld.THUNDER_OFFSET_DB)


func active_layer() -> StringName:
	return _active


func current_floor_db() -> float:
	return _floor_db


func layer_fade(layer: StringName) -> float:
	return float(_fade.get(layer, 0.0))


func layer_volume_db(layer: StringName) -> float:
	return _players[layer].volume_db if _players.has(layer) else MIN_LAYER_DB


## Saída (dB) da camada: ganho deslizado mais a curva de potência constante do crossfade. Silêncio com fade zero.
func layer_output_db(layer: StringName) -> float:
	var fade: float = float(_fade.get(layer, 0.0))
	if fade <= 0.0:
		return MIN_LAYER_DB
	var amplitude: float = sin(0.5 * PI * fade)
	return float(_gain_db[layer]) + linear_to_db(maxf(amplitude, 0.0001))


func _update_listener_floor() -> void:
	var position: Vector3 = _listener_position()
	var floor_db: float = OUTSIDE_FLOOR_DB
	if _world != null and _world.has_geometry():
		floor_db = _world.get_graph().ambient_floor_at(position)
	_floor_db = floor_db
	_active = layer_for_floor(floor_db)
	var clip_rms: float = _layer_rms(_active)
	_target_gain_db[_active] = gain_for_floor(floor_db, clip_rms)
	if float(_gain_db[_active]) <= MIN_LAYER_DB:
		_gain_db[_active] = _target_gain_db[_active]


## RMS do clip da camada (dBFS). A saída é este valor mais o ganho de layer_volume_db.
func layer_clip_db(layer: StringName) -> float:
	return _layer_rms(layer)


func _layer_rms(layer: StringName) -> float:
	var entry: Dictionary = _clips.first(layer)
	return float(entry.get("rms_dbfs", CLIP_REF_DBFS))


func _on_thunder_started(_duration_s: float) -> void:
	var gain: float = thunder_gain_for_floor(_floor_db)
	_start_one_shot(THUNDER_RUMBLE, gain, false)
	if _rng.randf() < THUNDER_CRACK_CHANCE:
		_start_one_shot(THUNDER_CRACK, gain, true)


func _start_one_shot(sound_id: StringName, gain: float, crack: bool) -> void:
	var entry: Dictionary = _clips.pick(sound_id, "", _rng)
	if entry.is_empty():
		Log.warn(LOG_CATEGORY, "sem arquivo de trovão: %s" % sound_id)
		return
	var voice: AudioStreamPlayer = AudioStreamPlayer.new()
	voice.stream = entry["stream"]
	voice.volume_db = gain
	add_child(voice)
	voice.finished.connect(_on_thunder_finished.bind(voice))
	voice.play()
	_thunder_voices.append(voice)
	while _thunder_voices.size() > MAX_THUNDER_VOICES:
		var oldest: AudioStreamPlayer = _thunder_voices.pop_front()
		if is_instance_valid(oldest):
			oldest.stop()
			oldest.queue_free()
	played_log.append({
		"sound_id": sound_id,
		"file": entry["file"],
		"variation": entry["variation"],
		"gain_db": gain,
		"crack": crack,
		"start_s": _clock_s,
	})
	if played_log.size() > MAX_LOG_ENTRIES:
		played_log.remove_at(0)


func _on_thunder_finished(voice: AudioStreamPlayer) -> void:
	_thunder_voices.erase(voice)
	if is_instance_valid(voice):
		voice.queue_free()


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

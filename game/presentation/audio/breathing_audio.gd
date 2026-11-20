class_name BreathingAudio
extends Node
## BreathingAudio (L3, COMPONENT_CONTRACTS §14, F2-006b): toca os sons do corpo do jogador. Só reage a
## AcousticWorld.noise_resolved_for_player com source_id == &"player" e categoria BREATHING, WHEEZING, COUGHING
## ou MEDICATION. Nunca toca por conta própria: sem evento, não há som (é o silêncio que vale como terror).
## Som "dentro da cabeça": AudioStreamPlayer sem posição, sem atenuação (NOI-INV-2: o volume vem de
## PropagationResult.perceived_db, não da distância ao emissor).
## Cada ciclo respiratório encadeia inspiração e expiração no período do evento, pelo encaixe de
## BreathParams.chain_timing (pitch entre 1/1.15 e 1.15; o resto é silêncio). Chiado (WHEEZING) toca como camada
## a partir do início da expiração. Gasp, aviso de tosse, tosse e puff tocam como um disparo.
## Os arquivos vêm de game/content/audio/body/manifest.json, escolhidos por sound_id e papel.
## Ligação: bind_world(world), ou automática pelo grupo "acoustic_world" no primeiro quadro.

const SOURCE_ID: StringName = &"player"
const WORLD_GROUP: StringName = &"acoustic_world"
const MANIFEST_PATH: String = "res://content/audio/body/manifest.json"
const BODY_DIR: String = "res://content/audio/body/"
const LOG_CATEGORY: StringName = &"audio"
## Percepção (dB) que toca em 0 dB de ganho. Acima disso o ganho fica em 0 dB: tosse e gasp não passam do
## nível do clip, e o mixer não clipa. Abaixo, o ganho cai até MIN_GAIN_DB (silêncio audível do ciclo calmo).
const BODY_REFERENCE_DB: float = 45.0
const MIN_GAIN_DB: float = -45.0
const LAYER_SOUND: StringName = &"wheeze"
const ROLE_INHALE: StringName = &"inhale"
const ROLE_EXHALE: StringName = &"exhale"
const ROLE_LAYER: StringName = &"layer"
const ROLE_ONE_SHOT: StringName = &"one_shot"
const ONE_SHOT_SOUNDS: Array[StringName] = [&"gasp", &"cough_warning", &"cough", &"inhaler_puff"]
const MAX_LOG_ENTRIES: int = 256

## Registro das vozes iniciadas (para teste e depuração): sound_id, role, variation, file, gain_db, pitch, start_s.
var played_log: Array[Dictionary] = []

var _clips: Dictionary = {}
var _pending: Array[Dictionary] = []
var _clock_s: float = 0.0
var _world: AcousticWorld = null
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _warned: Dictionary = {}


func _ready() -> void:
	_rng.randomize()
	_load_manifest()
	call_deferred("_bind_group_world")


func _process(delta: float) -> void:
	tick(delta)


## Avança o relógio e dispara as vozes agendadas (expiração, camada de chiado). Chamado por _process;
## os testes chamam direto para não depender do quadro.
func tick(delta: float) -> void:
	_clock_s += delta
	if _pending.is_empty():
		return
	var still: Array[Dictionary] = []
	for item: Dictionary in _pending:
		item["remaining_s"] = float(item["remaining_s"]) - delta
		if float(item["remaining_s"]) <= 0.0:
			_start(item)
		else:
			still.append(item)
	_pending = still


## Liga ao AcousticWorld. Religar a outro mundo desliga o anterior.
func bind_world(world: AcousticWorld) -> void:
	if _world == world:
		return
	if _world != null and _world.noise_resolved_for_player.is_connected(_on_noise_resolved):
		_world.noise_resolved_for_player.disconnect(_on_noise_resolved)
	_world = world
	if _world != null and not _world.noise_resolved_for_player.is_connected(_on_noise_resolved):
		_world.noise_resolved_for_player.connect(_on_noise_resolved)


## Semente da escolha de variação (testes fixam para resultado repetível).
func set_random_seed(seed_value: int) -> void:
	_rng.seed = seed_value


## Ganho (dB) a partir do nível percebido: 0 dB em BODY_REFERENCE_DB ou acima, MIN_GAIN_DB como piso.
static func gain_for_db(perceived_db: float) -> float:
	return clampf(perceived_db - BODY_REFERENCE_DB, MIN_GAIN_DB, 0.0)


func variation_count(sound_id: StringName, role: StringName) -> int:
	if not _clips.has(sound_id):
		return 0
	var by_role: Dictionary = _clips[sound_id]
	if not by_role.has(role):
		return 0
	var variants: Array = by_role[role]
	return variants.size()


func _on_noise_resolved(event: NoiseEvent, result: PropagationResult) -> void:
	if event.source_id != SOURCE_ID:
		return
	if not _is_body_category(event.category):
		return
	var gain: float = gain_for_db(result.perceived_db)
	if ONE_SHOT_SOUNDS.has(event.sound_id):
		_queue(event.sound_id, ROLE_ONE_SHOT, 0.0, gain, 1.0)
		return
	if BreathParams.FAMILY_TABLE.has(event.sound_id):
		_play_breath(event, gain)
		return
	_warn_once("unknown:" + str(event.sound_id), "sound_id sem arquivo de corpo: %s" % str(event.sound_id))


func _play_breath(event: NoiseEvent, gain: float) -> void:
	var timing: Dictionary = BreathParams.chain_timing(event.sound_id, event.duration)
	if timing.is_empty():
		return
	var pitch: float = float(timing["pitch_scale"])
	var inhale_s: float = float(timing["inhale_s"])
	_queue(event.sound_id, ROLE_INHALE, 0.0, gain, pitch)
	_queue(event.sound_id, ROLE_EXHALE, inhale_s, gain, pitch)
	if event.category == Enums.NoiseCategory.WHEEZING:
		_queue(LAYER_SOUND, ROLE_LAYER, inhale_s, gain, pitch)


func _queue(sound_id: StringName, role: StringName, delay_s: float, gain: float, pitch: float) -> void:
	var entry: Dictionary = _pick(sound_id, role)
	if entry.is_empty():
		_warn_once("missing:%s/%s" % [sound_id, role], "sem arquivo para %s (%s)" % [sound_id, role])
		return
	var item: Dictionary = {
		"sound_id": sound_id,
		"role": role,
		"variation": entry["variation"],
		"file": entry["file"],
		"stream": entry["stream"],
		"gain_db": gain,
		"pitch": pitch,
		"remaining_s": delay_s,
	}
	if delay_s <= 0.0:
		_start(item)
	else:
		_pending.append(item)


func _pick(sound_id: StringName, role: StringName) -> Dictionary:
	if not _clips.has(sound_id):
		return {}
	var by_role: Dictionary = _clips[sound_id]
	if not by_role.has(role):
		return {}
	var variants: Array = by_role[role]
	if variants.is_empty():
		return {}
	return variants[_rng.randi() % variants.size()]


func _start(item: Dictionary) -> void:
	var player: AudioStreamPlayer = AudioStreamPlayer.new()
	player.stream = item["stream"]
	player.volume_db = float(item["gain_db"])
	player.pitch_scale = float(item["pitch"])
	add_child(player)
	player.finished.connect(player.queue_free)
	player.play()
	played_log.append({
		"sound_id": item["sound_id"],
		"role": item["role"],
		"variation": item["variation"],
		"file": item["file"],
		"gain_db": item["gain_db"],
		"pitch": item["pitch"],
		"start_s": _clock_s,
	})
	if played_log.size() > MAX_LOG_ENTRIES:
		played_log.remove_at(0)


func _load_manifest() -> void:
	var file: FileAccess = FileAccess.open(MANIFEST_PATH, FileAccess.READ)
	if file == null:
		Log.error(LOG_CATEGORY, "manifest dos sons do corpo ausente: %s" % MANIFEST_PATH)
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not (parsed is Dictionary):
		Log.error(LOG_CATEGORY, "manifest dos sons do corpo inválido: %s" % MANIFEST_PATH)
		return
	var files: Variant = (parsed as Dictionary).get("files", [])
	if not (files is Array):
		return
	for entry: Variant in files:
		if not (entry is Dictionary):
			continue
		var item: Dictionary = entry
		var file_name: String = str(item.get("file", ""))
		var stream: AudioStreamWAV = load(BODY_DIR + file_name) as AudioStreamWAV
		if stream == null:
			Log.error(LOG_CATEGORY, "som do corpo não importou: %s" % file_name)
			continue
		var sound_id: StringName = StringName(str(item.get("sound_id", "")))
		var role: StringName = StringName(str(item.get("role", "")))
		if not _clips.has(sound_id):
			_clips[sound_id] = {}
		var by_role: Dictionary = _clips[sound_id]
		if not by_role.has(role):
			by_role[role] = []
		var variants: Array = by_role[role]
		variants.append({"stream": stream, "file": file_name, "variation": int(item.get("variation", 0))})


func _bind_group_world() -> void:
	if _world != null or not is_inside_tree():
		return
	var world: AcousticWorld = get_tree().get_first_node_in_group(WORLD_GROUP) as AcousticWorld
	if world != null:
		bind_world(world)


func _is_body_category(category: Enums.NoiseCategory) -> bool:
	return category == Enums.NoiseCategory.BREATHING \
		or category == Enums.NoiseCategory.WHEEZING \
		or category == Enums.NoiseCategory.COUGHING \
		or category == Enums.NoiseCategory.MEDICATION


func _warn_once(key: String, message: String) -> void:
	if _warned.has(key):
		return
	_warned[key] = true
	Log.warn(LOG_CATEGORY, message)

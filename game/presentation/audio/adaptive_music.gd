class_name AdaptiveMusic
extends Node
## AdaptiveMusic (L3, F4-006a): música adaptativa básica. Três camadas procedurais em loop (tools/audio/music_synth.py,
## game/content/audio/music/), com a mesma duração e o mesmo tempo. As três tocam JUNTAS desde o início e só o volume
## muda. Não é diegética: vai ao barramento "music" (envia ao Master, sem reverb), fora da regra de ganho dos sons
## (NoiseGain). Quem chama set_threat é o PlayerThreatMonitor (F4-006b); a ligação é do Director.
##
## Curva do crossfade, em set_threat(level, in_chase). level = ThreatSample.threat_level, limitado a [0; 1];
## in_chase = perseguição (ThreatSample.in_chase). Com t = level e c = 1 se in_chase (senão 0), os PESOS são:
##   calma       = (1 − t) · (1 − c)   sem ameaça (t = 0) só a calma toca; a calma cede com a ameaça
##   tensão      = t · (1 − c)         cresce com o threat_level
##   perseguição = c                   com perseguição, zera calma e tensão, qualquer que seja o level
## Amplitude de cada camada = raiz(peso). A soma das potências é 1 em todo ponto: o volume percebido não afunda
## na transição (potência constante). Exemplos: level 0 → calma 1; level 0,5 sem perseguição → calma e tensão 0,707
## cada; level 1 → tensão 1; perseguição → perseguição 1.
## O alvo é atingido em CROSSFADE_S = 2 s: a amplitude desliza linearmente em tick() (chamado por _process).

const MANIFEST_PATH: String = "res://content/audio/music/manifest.json"
const MUSIC_DIR: String = "res://content/audio/music/"
const LOG_CATEGORY: StringName = &"audio"
const MUSIC_BUS: StringName = &"music"
const MASTER_BUS: StringName = &"Master"
const LAYER_CALM: StringName = &"calm"
const LAYER_TENSION: StringName = &"tension"
const LAYER_CHASE: StringName = &"chase"
const LAYERS: Array[StringName] = [&"calm", &"tension", &"chase"]
## Tempo, em segundos, para a amplitude ir de 0 a 1.
const CROSSFADE_S: float = 2.0
## Volume (dB) abaixo do qual a camada fica muda.
const MIN_DB: float = -80.0

## Liga as camadas no _ready. Com false, o Director chama start() quando quiser.
@export var autostart: bool = true
## Integração da F4 (Director): liga set_threat ao threat_changed do PlayerThreatMonitor do jogador do nível
## (grupo "player"). Desligado por padrão, para não mudar cenas e testes que não querem a música guiada.
@export var bind_player_monitor: bool = false

var _bound_monitor: PlayerThreatMonitor = null

var _players: Dictionary = {}
var _target: Dictionary = {&"calm": 1.0, &"tension": 0.0, &"chase": 0.0}
var _gain: Dictionary = {&"calm": 1.0, &"tension": 0.0, &"chase": 0.0}
var _threat_level: float = 0.0
var _in_chase: bool = false
var _started: bool = false
var _warned_bus: bool = false


func _ready() -> void:
	_build_players()
	if autostart:
		start()
	if bind_player_monitor:
		call_deferred("_bind_player_monitor")


## A música está ligada ao monitor de ameaça do jogador?
func is_bound_to_monitor() -> bool:
	return _bound_monitor != null and is_instance_valid(_bound_monitor)


func _bind_player_monitor() -> void:
	if not is_inside_tree():
		return
	var player: PlayerRoot = get_tree().get_first_node_in_group(&"player") as PlayerRoot
	if player == null or player.get_threat_monitor() == null:
		Log.warn(LOG_CATEGORY, "AdaptiveMusic sem jogador com monitor de ameaça; a música fica calma")
		return
	_bound_monitor = player.get_threat_monitor()
	if not _bound_monitor.threat_changed.is_connected(set_threat):
		_bound_monitor.threat_changed.connect(set_threat)


func _process(delta: float) -> void:
	tick(delta)


## Pesos (potência) das três camadas: Vector3(calma, tensão, perseguição). Soma 1 em todo ponto (ver cabeçalho).
static func weights_for(level: float, in_chase: bool) -> Vector3:
	var t: float = clampf(level, 0.0, 1.0)
	var c: float = 1.0 if in_chase else 0.0
	return Vector3((1.0 - t) * (1.0 - c), t * (1.0 - c), c)


## Amplitudes-alvo (0 a 1) das três camadas: raiz quadrada dos pesos. Vector3(calma, tensão, perseguição).
static func gains_for(level: float, in_chase: bool) -> Vector3:
	var w: Vector3 = weights_for(level, in_chase)
	return Vector3(sqrt(w.x), sqrt(w.y), sqrt(w.z))


## Volume (dB) de uma amplitude linear; abaixo de MIN_DB (ou zero) vira MIN_DB.
static func db_for_gain(gain: float) -> float:
	if gain <= 0.0:
		return MIN_DB
	return maxf(linear_to_db(gain), MIN_DB)


## Ameaça e perseguição (F4-006b). O crossfade acontece em tick(); aqui só se define o alvo.
func set_threat(level: float, in_chase: bool) -> void:
	_threat_level = clampf(level, 0.0, 1.0)
	_in_chase = in_chase
	var g: Vector3 = gains_for(_threat_level, in_chase)
	_target = {LAYER_CALM: g.x, LAYER_TENSION: g.y, LAYER_CHASE: g.z}


## Liga as três camadas no mesmo quadro (tocam juntas desde o início). Repetir não faz nada.
func start() -> void:
	if _started:
		return
	_started = true
	for layer: StringName in LAYERS:
		var player: AudioStreamPlayer = _players[layer] as AudioStreamPlayer
		if player != null and player.stream != null:
			player.play()


## Um passo do crossfade: cada amplitude anda até o alvo, no máximo 1 unidade em CROSSFADE_S segundos.
func tick(delta: float) -> void:
	var step: float = delta / maxf(CROSSFADE_S, 0.0001)
	for layer: StringName in LAYERS:
		var gain: float = move_toward(float(_gain[layer]), float(_target[layer]), step)
		_gain[layer] = gain
		var player: AudioStreamPlayer = _players.get(layer) as AudioStreamPlayer
		if player != null:
			player.volume_db = db_for_gain(gain)


func threat_level() -> float:
	return _threat_level


func in_chase() -> bool:
	return _in_chase


func target_gain(layer: StringName) -> float:
	return float(_target.get(layer, 0.0))


func layer_gain(layer: StringName) -> float:
	return float(_gain.get(layer, 0.0))


func layer_volume_db(layer: StringName) -> float:
	var player: AudioStreamPlayer = _players.get(layer) as AudioStreamPlayer
	return player.volume_db if player != null else MIN_DB


func layer_player(layer: StringName) -> AudioStreamPlayer:
	return _players.get(layer) as AudioStreamPlayer


## Verdadeiro quando as três camadas têm stream, estão tocando e têm a mesma duração (sincronia).
func is_synced() -> bool:
	if not _started or _players.size() != LAYERS.size():
		return false
	var length: float = -1.0
	for layer: StringName in LAYERS:
		var player: AudioStreamPlayer = _players[layer] as AudioStreamPlayer
		if player == null or player.stream == null or not player.playing:
			return false
		var here: float = player.stream.get_length()
		if length < 0.0:
			length = here
		elif absf(here - length) > 0.0001:
			return false
	return true


func _build_players() -> void:
	var streams: Dictionary = _load_streams()
	for layer: StringName in LAYERS:
		var player: AudioStreamPlayer = AudioStreamPlayer.new()
		player.name = String(layer)
		player.bus = _bus_name()
		player.volume_db = MIN_DB
		if streams.has(layer):
			player.stream = streams[layer] as AudioStream
		else:
			Log.warn(LOG_CATEGORY, "camada de música ausente: %s" % String(layer))
		add_child(player)
		_players[layer] = player


## Streams por camada, lidos do manifesto. Cada um com repetição direta (o loop é a própria música).
func _load_streams() -> Dictionary:
	var out: Dictionary = {}
	var file: FileAccess = FileAccess.open(MANIFEST_PATH, FileAccess.READ)
	if file == null:
		Log.error(LOG_CATEGORY, "manifest da música ausente: %s" % MANIFEST_PATH)
		return out
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not (parsed is Dictionary):
		Log.error(LOG_CATEGORY, "manifest da música inválido: %s" % MANIFEST_PATH)
		return out
	var files: Variant = (parsed as Dictionary).get("files", [])
	if not (files is Array):
		return out
	for raw: Variant in files:
		if not (raw is Dictionary):
			continue
		var item: Dictionary = raw
		var layer: StringName = StringName(str(item.get("layer", "")))
		if not LAYERS.has(layer):
			continue
		var stream: AudioStreamWAV = load(MUSIC_DIR + str(item.get("file", ""))) as AudioStreamWAV
		if stream == null:
			Log.error(LOG_CATEGORY, "camada de música não importou: %s" % str(item.get("file", "")))
			continue
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		out[layer] = stream
	return out


func _bus_name() -> StringName:
	if AudioServer.get_bus_index(String(MUSIC_BUS)) >= 0:
		return MUSIC_BUS
	if not _warned_bus:
		_warned_bus = true
		Log.warn(LOG_CATEGORY, "barramento 'music' ausente; a música vai ao Master")
	return MASTER_BUS

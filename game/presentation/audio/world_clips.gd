class_name WorldClips
extends RefCounted
## WorldClips (L3, F3-003b): biblioteca dos sons do mundo (game/content/audio/world/manifest.json, F3-003a). Lê o
## manifesto uma vez e escolhe a variação por sound_id e, nos passos, por marcha (campo gait). A escolha nunca repete a
## variação anterior do mesmo grupo (não evidencia a repetição). Não toca nada: quem toca é o NoiseAudioRouter ou a
## RainAmbience.

const MANIFEST_PATH: String = "res://content/audio/world/manifest.json"
const WORLD_DIR: String = "res://content/audio/world/"
const LOG_CATEGORY: StringName = &"audio"

## Cache por processo: o manifesto e os streams são lidos uma vez (os streams são imutáveis; cada instância guarda só a
## própria rotação de variações). Sem isso, cada router e cada ambiência recarregavam os 98 WAV.
static var _manifest_cache: Dictionary = {}

## sound_id -> Array de entradas (Dictionary: file, stream, variation, gait, loop, rms_dbfs, duration_s).
var _entries: Dictionary = {}
## grupo (sound_id|gait) -> índice da última variação escolhida.
var _last_index: Dictionary = {}
var _loaded: bool = false


## Carrega o manifesto e os streams. Retorna false se o manifesto não existe ou não tem entradas válidas.
func load_manifest(path: String = MANIFEST_PATH) -> bool:
	_last_index.clear()
	_loaded = false
	if _manifest_cache.has(path):
		_entries = _manifest_cache[path]
		_loaded = not _entries.is_empty()
		return _loaded
	_entries = {}
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		Log.error(LOG_CATEGORY, "manifest dos sons do mundo ausente: %s" % path)
		return false
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not (parsed is Dictionary):
		Log.error(LOG_CATEGORY, "manifest dos sons do mundo inválido: %s" % path)
		return false
	var files: Variant = (parsed as Dictionary).get("files", [])
	if not (files is Array):
		return false
	for raw: Variant in files:
		if not (raw is Dictionary):
			continue
		var item: Dictionary = raw
		var file_name: String = str(item.get("file", ""))
		var stream: AudioStreamWAV = load(WORLD_DIR + file_name) as AudioStreamWAV
		if stream == null:
			Log.error(LOG_CATEGORY, "som do mundo não importou: %s" % file_name)
			continue
		var gait_value: String = str(item.get("gait", ""))
		var entry: Dictionary = {
			"file": file_name,
			"stream": stream,
			"variation": int(item.get("variation", 0)),
			"gait": gait_value if gait_value != "<null>" else "",
			"loop": bool(item.get("loop", false)),
			"rms_dbfs": float(item.get("rms_dbfs", -24.0)),
			"duration_s": float(item.get("duration_s", stream.get_length())),
			"sound_id": StringName(str(item.get("sound_id", ""))),
		}
		var key: StringName = entry["sound_id"]
		if not _entries.has(key):
			_entries[key] = []
		var list: Array = _entries[key]
		list.append(entry)
	_loaded = not _entries.is_empty()
	if _loaded:
		_manifest_cache[path] = _entries
	return _loaded


func is_loaded() -> bool:
	return _loaded


func has_sound(sound_id: StringName) -> bool:
	return _entries.has(sound_id)


## Número de variações de um sound_id (e de uma marcha, se gait não for vazio).
func count(sound_id: StringName, gait: String = "") -> int:
	return _matching(sound_id, gait).size()


## Entrada da variação escolhida, ou {} se não há. Evita repetir a última variação do grupo quando há mais de uma.
func pick(sound_id: StringName, gait: String, rng: RandomNumberGenerator) -> Dictionary:
	var candidates: Array = _matching(sound_id, gait)
	if candidates.is_empty():
		return {}
	var group_key: String = "%s|%s" % [sound_id, gait]
	var last: int = int(_last_index.get(group_key, -1))
	var index: int = rng.randi() % candidates.size()
	if candidates.size() > 1 and index == last:
		index = (index + 1 + rng.randi() % (candidates.size() - 1)) % candidates.size()
	_last_index[group_key] = index
	return candidates[index]


## Primeira variação de um sound_id, sem efeitos colaterais (loops têm uma variação; não mexe na rotação).
func first(sound_id: StringName) -> Dictionary:
	var candidates: Array = _matching(sound_id, "")
	if candidates.is_empty():
		return {}
	return candidates[0]


## Entrada pelo nome do arquivo (para testes e registro).
func entry_for_file(file_name: String) -> Dictionary:
	for key: Variant in _entries.keys():
		for entry: Dictionary in _entries[key]:
			if entry["file"] == file_name:
				return entry
	return {}


func _matching(sound_id: StringName, gait: String) -> Array:
	var out: Array = []
	if not _entries.has(sound_id):
		return out
	for entry: Dictionary in _entries[sound_id]:
		if gait == "" or entry["gait"] == gait:
			out.append(entry)
	return out

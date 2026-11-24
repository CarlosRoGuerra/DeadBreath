extends TestCase
## F4-006a (D4-06): falas PROVISÓRIAS do Observer na biblioteca do mundo (game/content/audio/world/). Quatro sound_id
## (DATA §3: voice_suspicious, voice_investigate, voice_chase_shout, voice_search), três variações cada, marcadas
## provisional no manifesto, e resolvidas pelo WorldClips pelo próprio sound_id (falas não têm marcha).
## Autor: Audio Engineer (F4-006a).

const MANIFEST_PATH: String = "res://content/audio/world/manifest.json"
const WORLD_DIR: String = "res://content/audio/world/"
const VOICES: Array[String] = ["voice_suspicious", "voice_investigate", "voice_chase_shout", "voice_search"]
const VARIATIONS: Array[int] = [1, 2, 3]


func _manifest() -> Dictionary:
	var file: FileAccess = FileAccess.open(MANIFEST_PATH, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary:
		return parsed
	return {}


func _items_for(sound_id: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var files: Variant = _manifest().get("files", [])
	if not (files is Array):
		return out
	for raw: Variant in files:
		if raw is Dictionary and str((raw as Dictionary).get("sound_id", "")) == sound_id:
			out.append(raw as Dictionary)
	return out


func test_cada_fala_tem_tres_variacoes_marcadas_provisorias() -> void:
	for sound: String in VOICES:
		var items: Array[Dictionary] = _items_for(sound)
		assert_eq(items.size(), VARIATIONS.size(), "%s: três variações no manifesto" % sound)
		var seen: Array[int] = []
		for item: Dictionary in items:
			assert_eq(str(item["role"]), "voice", "%s: papel voice" % sound)
			assert_true(bool(item["provisional"]), "%s: marcada provisória (%s)" % [sound, str(item["file"])])
			assert_eq(str(item["class"]), "one_shot", "%s: classe one_shot" % sound)
			seen.append(int(item["variation"]))
		for v: int in VARIATIONS:
			assert_true(seen.has(v), "%s: variação %d presente" % [sound, v])


func test_manifesto_registra_que_as_falas_sao_provisorias() -> void:
	var provisional: Variant = _manifest().get("provisional", {})
	assert_true(provisional is Dictionary, "bloco provisional no manifesto")
	if not (provisional is Dictionary):
		return
	var roles: Variant = (provisional as Dictionary).get("roles", [])
	assert_true(roles is Array and (roles as Array).has("voice"), "o papel voice está marcado como provisório")


func test_worldclips_resolve_cada_fala_pelo_proprio_sound_id() -> void:
	var clips: WorldClips = WorldClips.new()
	assert_true(clips.load_manifest(), "biblioteca do mundo carrega")
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 7
	for sound: String in VOICES:
		var key: StringName = StringName(sound)
		assert_true(clips.has_sound(key), "%s está na biblioteca" % sound)
		assert_eq(clips.count(key), VARIATIONS.size(), "%s: três variações na biblioteca" % sound)
		var entry: Dictionary = clips.pick(key, "", rng)
		assert_false(entry.is_empty(), "%s: pick devolve uma variação" % sound)
		if entry.is_empty():
			continue
		assert_true(str(entry["file"]).begins_with(sound + "_v"), "%s: arquivo do próprio sound_id (%s)" % [sound, str(entry["file"])])
		assert_true(entry["stream"] is AudioStreamWAV, "%s: stream WAV importado" % sound)

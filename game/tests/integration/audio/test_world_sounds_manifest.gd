extends TestCase
## F3-003a (Docs/Development/TASK_BOARD §4c; contrato de dados em content/audio/world/manifest.json).
## A varredura de pico sobre todos os clips está em tests/property/audio/test_world_peaks.gd (regra de tempo da suíte).
## Para cada item do manifesto dos sons do mundo confere: manifesto × disco, importação como AudioStreamWAV com
## a duração e o formato declarados (PCM 16 bits, mono, 44,1 kHz), pico real abaixo de -1 dBFS, os sound_id
## exigidos com variações, e os loops de chuva com a emenda sem estalo (medida no áudio importado, não no que o
## gerador declara) e com loop_mode de repetição direta.
## Autor: Audio Engineer (F3-003a).

const WORLD_DIR: String = "res://content/audio/world/"
const MANIFEST_PATH: String = "res://content/audio/world/manifest.json"
const EXPECTED_SAMPLE_RATE: int = 44100
const DURATION_TOLERANCE_S: float = 0.0005
const PEAK_LIMIT_DBFS: float = -1.0
const PEAK_DECLARED_TOLERANCE_DB: float = 0.05
const MIN_VARIATIONS: int = 2
## Razão salto da emenda / diferença média entre vizinhos. Um estalo dá razão muito acima de 4.
const SEAM_RATIO_LIMIT: float = 4.0
const GAITS: Array[String] = ["crawl", "crouch", "slow", "walk", "run"]
const SURFACES: Array[String] = ["wood", "carpet", "tile", "concrete"]
const REQUIRED_ONE_SHOTS: Array[String] = [
	"door_slow", "door_normal", "door_slam", "door_locked",
	"impact_light", "impact_medium", "impact_heavy",
	"furniture_drag", "fall_body", "thunder_rumble", "thunder_crack",
]
const REQUIRED_LOOPS: Array[String] = ["rain_interior", "rain_window", "rain_exterior"]
const WORLD_BUDGET_BYTES: int = 15000000


func _read_manifest() -> Dictionary:
	var file: FileAccess = FileAccess.open(MANIFEST_PATH, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary:
		return parsed
	return {}


func _items() -> Array:
	var files: Variant = _read_manifest().get("files", [])
	if files is Array:
		return files
	return []


func _wav_names_on_disk() -> Array[String]:
	var out: Array[String] = []
	var dir: DirAccess = DirAccess.open(WORLD_DIR)
	if dir == null:
		return out
	dir.list_dir_begin()
	var name: String = dir.get_next()
	while name != "":
		if not dir.current_is_dir() and name.ends_with(".wav"):
			out.append(name)
		name = dir.get_next()
	dir.list_dir_end()
	out.sort()
	return out


func _stream(file: String) -> AudioStreamWAV:
	var res: Resource = load(WORLD_DIR + file)
	return res as AudioStreamWAV


## Razão salto / diferença média entre vizinhos, no próprio loop (a última amostra contra a primeira).
func _seam_ratio(stream: AudioStreamWAV) -> float:
	var data: PackedByteArray = stream.data
	var count: int = data.size() / 2
	if count < 2:
		return 0.0
	var total: float = 0.0
	var prev: float = float(data.decode_s16(0))
	for i in range(1, count):
		var cur: float = float(data.decode_s16(i * 2))
		total += absf(cur - prev)
		prev = cur
	var mean_diff: float = total / float(count - 1)
	var first: float = float(data.decode_s16(0))
	var last: float = float(data.decode_s16((count - 1) * 2))
	var jump: float = absf(first - last)
	if mean_diff <= 0.0:
		return 0.0
	return jump / mean_diff


func test_manifest_present_and_lists_every_wav_on_disk() -> void:
	assert_false(_read_manifest().is_empty(), "manifest.json ausente ou inválido")
	var listed: Dictionary = {}
	for item: Dictionary in _items():
		listed[String(item["file"])] = true
	var on_disk: Array[String] = _wav_names_on_disk()
	assert_true(on_disk.size() > 0, "nenhum WAV em " + WORLD_DIR)
	assert_eq(listed.size(), on_disk.size(), "quantidade de WAV no manifesto e no disco")
	for name: String in on_disk:
		assert_true(listed.has(name), "WAV sem entrada no manifesto: " + name)


func test_required_sound_ids_have_variations_and_gaits() -> void:
	var counts: Dictionary = {}
	for item: Dictionary in _items():
		var key: String = "%s|%s" % [String(item["sound_id"]), String(item["role"])]
		counts[key] = int(counts.get(key, 0)) + 1
	for surface: String in SURFACES:
		var sound: String = "footstep_" + surface
		for gait: String in GAITS:
			var n: int = 0
			for item: Dictionary in _items():
				if String(item["sound_id"]) == sound and str(item["gait"]) == gait:
					n += 1
			assert_true(n >= MIN_VARIATIONS, "%s marcha %s: %d variação(ões) (mínimo %d)" % [sound, gait, n, MIN_VARIATIONS])
	for sound: String in REQUIRED_ONE_SHOTS:
		var n_shots: int = int(counts.get(sound + "|one_shot", 0))
		assert_true(n_shots >= MIN_VARIATIONS, "%s: %d variação(ões) (mínimo %d)" % [sound, n_shots, MIN_VARIATIONS])
	for sound: String in REQUIRED_LOOPS:
		assert_eq(int(counts.get(sound + "|loop", 0)), 1, "%s: um loop declarado" % sound)


func test_every_item_imports_as_wav_with_declared_duration_and_format() -> void:
	for item: Dictionary in _items():
		var file: String = String(item["file"])
		var stream: AudioStreamWAV = _stream(file)
		assert_not_null(stream, "não importou como AudioStreamWAV: " + file)
		if stream == null:
			continue
		assert_almost_eq(stream.get_length(), float(item["duration_s"]), DURATION_TOLERANCE_S, "duração de " + file)
		assert_eq(stream.format, AudioStreamWAV.FORMAT_16_BITS,
			file + ": formato deve ser PCM 16 bits (o .wav.import tem compress/mode=0)")
		assert_false(stream.stereo, file + ": deve ser mono")
		assert_eq(stream.mix_rate, EXPECTED_SAMPLE_RATE, file + ": taxa de amostragem")
		assert_eq(stream.data.size() / 2, int(item["samples"]), file + ": número de amostras")


func test_loops_are_flagged_forward_looped_and_seamless() -> void:
	var loops: int = 0
	for item: Dictionary in _items():
		if not bool(item["loop"]):
			continue
		loops += 1
		var file: String = String(item["file"])
		var stream: AudioStreamWAV = _stream(file)
		if stream == null:
			fail("sem stream: " + file)
			continue
		assert_eq(stream.loop_mode, AudioStreamWAV.LOOP_FORWARD,
			file + ": loop de repetição direta (edit/loop_mode=2 no .wav.import)")
		var ratio: float = _seam_ratio(stream)
		assert_true(ratio <= SEAM_RATIO_LIMIT,
			"%s: emenda com estalo (salto / diferença média = %.2f, limite %.1f)" % [file, ratio, SEAM_RATIO_LIMIT])
	assert_eq(loops, REQUIRED_LOOPS.size(), "três camadas de chuva em loop")


func test_world_total_size_is_within_budget() -> void:
	var total: int = 0
	for name: String in _wav_names_on_disk():
		var stream: AudioStreamWAV = _stream(name)
		if stream != null:
			total += stream.data.size()
	assert_true(total <= WORLD_BUDGET_BYTES, "sons do mundo somam %d bytes (orçamento %d)" % [total, WORLD_BUDGET_BYTES])

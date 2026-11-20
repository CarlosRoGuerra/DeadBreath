extends TestCase
## Integration: manifesto dos sons procedurais do corpo (F2-006a; contrato em TEST_PLAN §4).
## Para cada item de content/audio/body/manifest.json confere que: importa como AudioStreamWAV,
## com a duracao, o formato e o numero de amostras declarados; os sound_id exigidos existem com
## variacoes; o pico real esta abaixo de -1 dBFS (sem clipping); a duracao do aviso de tosse e 1,5 s;
## e cada familia de respiracao cabe na faixa de periodos de DATA_STRUCTURES §1.4 (1,5 a 4,3 s).
## Autor: Audio Engineer (F2-006a).

const BODY_DIR: String = "res://content/audio/body"
const MANIFEST_PATH: String = "res://content/audio/body/manifest.json"
const EXPECTED_SAMPLE_RATE: int = 44100
const DURATION_TOLERANCE_S: float = 0.0005
const PEAK_LIMIT_DBFS: float = -1.0
const PEAK_DECLARED_TOLERANCE_DB: float = 0.05
const MIN_VARIATIONS: int = 2
const COUGH_WARNING_DURATION_S: float = 1.5
const BREATH_PERIOD_MIN_S: float = 1.5
const BREATH_PERIOD_MAX_S: float = 4.3
## sound_id exigido -> papeis que precisam existir, com pelo menos MIN_VARIATIONS arquivos cada.
const REQUIRED: Dictionary = {
	"breath_calm": ["inhale", "exhale"],
	"breath_fast": ["inhale", "exhale"],
	"breath_labored": ["inhale", "exhale"],
	"wheeze": ["layer"],
	"cough_warning": ["one_shot"],
	"cough": ["one_shot"],
	"gasp": ["one_shot"],
	"inhaler_puff": ["one_shot"],
}


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


func _families() -> Dictionary:
	var families: Variant = _read_manifest().get("families", {})
	if families is Dictionary:
		return families
	return {}


func _wav_names_on_disk() -> Array[String]:
	var out: Array[String] = []
	var dir: DirAccess = DirAccess.open(BODY_DIR)
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
	var res: Resource = load(BODY_DIR + "/" + file)
	return res as AudioStreamWAV


func _peak_dbfs(stream: AudioStreamWAV) -> float:
	var data: PackedByteArray = stream.data
	var count: int = data.size() / 2
	var peak: int = 0
	for i in range(count):
		var a: int = absi(data.decode_s16(i * 2))
		if a > peak:
			peak = a
	if peak == 0:
		return -120.0
	return 20.0 * log(float(peak) / 32768.0) / log(10.0)


func test_manifest_present_and_lists_every_wav_on_disk() -> void:
	assert_false(_read_manifest().is_empty(), "manifest.json ausente ou invalido")
	var listed: Dictionary = {}
	for item: Dictionary in _items():
		listed[String(item["file"])] = true
	var on_disk: Array[String] = _wav_names_on_disk()
	assert_true(on_disk.size() > 0, "nenhum WAV em " + BODY_DIR)
	assert_eq(listed.size(), on_disk.size(), "quantidade de WAV no manifesto e no disco")
	for name: String in on_disk:
		assert_true(listed.has(name), "WAV sem entrada no manifesto: " + name)


func test_required_sound_ids_have_roles_and_variations() -> void:
	var counts: Dictionary = {}
	for item: Dictionary in _items():
		var key: String = "%s|%s" % [String(item["sound_id"]), String(item["role"])]
		counts[key] = int(counts.get(key, 0)) + 1
	for sound_id: String in REQUIRED.keys():
		for role: String in REQUIRED[sound_id]:
			var n: int = int(counts.get("%s|%s" % [sound_id, role], 0))
			assert_true(n >= MIN_VARIATIONS,
				"%s: %d variacao(oes) de papel %s (minimo %d)" % [sound_id, n, role, MIN_VARIATIONS])


func test_every_item_imports_as_wav_with_declared_duration() -> void:
	for item: Dictionary in _items():
		var file: String = String(item["file"])
		var stream: AudioStreamWAV = _stream(file)
		assert_not_null(stream, "nao importou como AudioStreamWAV: " + file)
		if stream == null:
			continue
		assert_almost_eq(stream.get_length(), float(item["duration_s"]), DURATION_TOLERANCE_S,
			"duracao de " + file)


func test_format_is_mono_16_bit_44100_with_declared_samples() -> void:
	for item: Dictionary in _items():
		var file: String = String(item["file"])
		var stream: AudioStreamWAV = _stream(file)
		if stream == null:
			fail("sem stream: " + file)
			continue
		assert_eq(stream.format, AudioStreamWAV.FORMAT_16_BITS, file + ": formato")
		assert_false(stream.stereo, file + ": deve ser mono")
		assert_eq(stream.mix_rate, EXPECTED_SAMPLE_RATE, file + ": taxa de amostragem")
		assert_eq(stream.data.size() / 2, int(item["samples"]), file + ": numero de amostras")


func test_no_clipping_peak_below_minus_1_dbfs() -> void:
	for item: Dictionary in _items():
		var file: String = String(item["file"])
		var stream: AudioStreamWAV = _stream(file)
		if stream == null:
			fail("sem stream: " + file)
			continue
		var peak_db: float = _peak_dbfs(stream)
		assert_true(peak_db < PEAK_LIMIT_DBFS,
			"%s: pico %.2f dBFS (limite %.1f)" % [file, peak_db, PEAK_LIMIT_DBFS])


func test_declared_peak_matches_measured_peak() -> void:
	for item: Dictionary in _items():
		var file: String = String(item["file"])
		var stream: AudioStreamWAV = _stream(file)
		if stream == null:
			fail("sem stream: " + file)
			continue
		var measured: float = _peak_dbfs(stream)
		assert_almost_eq(measured, float(item["peak_dbfs"]), PEAK_DECLARED_TOLERANCE_DB,
			"pico declarado vs medido: " + file)


func test_cough_warning_lasts_1_5_seconds() -> void:
	var found: int = 0
	for item: Dictionary in _items():
		if String(item["sound_id"]) != "cough_warning":
			continue
		found += 1
		var file: String = String(item["file"])
		var stream: AudioStreamWAV = _stream(file)
		if stream == null:
			fail("sem stream: " + file)
			continue
		assert_almost_eq(stream.get_length(), COUGH_WARNING_DURATION_S, DURATION_TOLERANCE_S,
			"aviso de tosse deve durar 1,5 s: " + file)
	assert_true(found > 0, "nenhum cough_warning no manifesto")


func test_breath_families_fit_the_period_range() -> void:
	var families: Dictionary = _families()
	assert_false(families.is_empty(), "manifesto sem o bloco families")
	for family_name: String in families.keys():
		var fam: Dictionary = families[family_name]
		var cycle: float = float(fam["cycle_s"])
		assert_true(cycle >= BREATH_PERIOD_MIN_S and cycle <= BREATH_PERIOD_MAX_S,
			"familia %s: ciclo %.3f s fora de 1,5 a 4,3 s" % [family_name, cycle])

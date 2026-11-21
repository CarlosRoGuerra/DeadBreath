extends TestCase
## F3-003a (varredura longa, nível property): pico real de cada clip do mundo abaixo de -1 dBFS (sem clipping) e pico
## declarado no manifesto igual ao medido. Varre todas as amostras, por isso fica fora da suíte padrão (TEST_PLAN §4).
## Autor: Audio Engineer (F3-003a).

const WORLD_DIR: String = "res://content/audio/world/"
const MANIFEST_PATH: String = "res://content/audio/world/manifest.json"
const PEAK_LIMIT_DBFS: float = -1.0
const PEAK_DECLARED_TOLERANCE_DB: float = 0.05


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


func _stream(file: String) -> AudioStreamWAV:
	var res: Resource = load(WORLD_DIR + file)
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


func test_no_clipping_and_declared_peak_matches() -> void:
	for item: Dictionary in _items():
		var file: String = String(item["file"])
		var stream: AudioStreamWAV = _stream(file)
		if stream == null:
			fail("sem stream: " + file)
			continue
		var peak_db: float = _peak_dbfs(stream)
		assert_true(peak_db < PEAK_LIMIT_DBFS, "%s: pico %.2f dBFS (limite %.1f)" % [file, peak_db, PEAK_LIMIT_DBFS])
		assert_almost_eq(peak_db, float(item["peak_dbfs"]), PEAK_DECLARED_TOLERANCE_DB, "pico declarado vs medido: " + file)



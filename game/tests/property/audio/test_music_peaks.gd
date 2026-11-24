extends TestCase
## F4-006a (varredura longa, nível property): em cada camada da música, o pico real abaixo de -1 dBFS (sem clipping),
## o pico declarado igual ao medido, e a emenda do loop sem estalo: o salto entre a última e a primeira amostra não passa
## da maior diferença entre vizinhos do próprio loop. Varre todas as amostras, por isso fica fora da suíte padrão.
## Autor: Audio Engineer (F4-006a).

const MANIFEST_PATH: String = "res://content/audio/music/manifest.json"
const MUSIC_DIR: String = "res://content/audio/music/"
const PEAK_LIMIT_DBFS: float = -1.0
const PEAK_DECLARED_TOLERANCE_DB: float = 0.05
## Salto na emenda / maior diferença entre vizinhos. Acima de 1 seria um estalo mais forte que qualquer passo do sinal.
const SEAM_LIMIT: float = 1.0


func _items() -> Array:
	var file: FileAccess = FileAccess.open(MANIFEST_PATH, FileAccess.READ)
	if file == null:
		return []
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not (parsed is Dictionary):
		return []
	var files: Variant = (parsed as Dictionary).get("files", [])
	if files is Array:
		return files
	return []


func test_pico_pico_declarado_e_emenda_das_camadas() -> void:
	var checked: int = 0
	for raw: Variant in _items():
		if not (raw is Dictionary):
			continue
		var item: Dictionary = raw
		var file: String = str(item["file"])
		var stream: AudioStreamWAV = load(MUSIC_DIR + file) as AudioStreamWAV
		if stream == null:
			fail("sem stream: " + file)
			continue
		checked += 1
		var data: PackedByteArray = stream.data
		var count: int = data.size() / 2
		var peak: int = 0
		var max_diff: int = 0
		var prev: int = data.decode_s16(0)
		for i: int in range(count):
			var cur: int = data.decode_s16(i * 2)
			var a: int = absi(cur)
			if a > peak:
				peak = a
			if i > 0:
				var d: int = absi(cur - prev)
				if d > max_diff:
					max_diff = d
			prev = cur
		var peak_db: float = -120.0 if peak == 0 else 20.0 * log(float(peak) / 32768.0) / log(10.0)
		assert_true(peak_db < PEAK_LIMIT_DBFS, "%s: pico %.2f dBFS (limite %.1f)" % [file, peak_db, PEAK_LIMIT_DBFS])
		assert_almost_eq(peak_db, float(item["peak_dbfs"]), PEAK_DECLARED_TOLERANCE_DB, "pico declarado vs medido: " + file)
		var first: int = data.decode_s16(0)
		var last: int = data.decode_s16((count - 1) * 2)
		var jump: int = absi(first - last)
		var ratio: float = float(jump) / float(max_diff) if max_diff > 0 else 0.0
		assert_true(ratio <= SEAM_LIMIT, "%s: emenda com salto %d, maior diferença entre vizinhos %d (razão %.3f)" % [
			file, jump, max_diff, ratio])
	assert_eq(checked, 3, "três camadas varridas")

extends TestCase
## F4-006a: manifesto das camadas da música (game/content/audio/music/manifest.json, gerado por tools/audio/music_synth.py).
## Confere manifesto × disco, importação (PCM 16 bits, mono, 44,1 kHz, repetição direta), duração, tempo e nível iguais
## nas três camadas, e pico declarado abaixo de -3 dBFS. A varredura de amostras (pico e emenda) fica em
## tests/property/audio/test_music_peaks.gd.
## Autor: Audio Engineer (F4-006a).

const MANIFEST_PATH: String = "res://content/audio/music/manifest.json"
const MUSIC_DIR: String = "res://content/audio/music/"
const LAYERS: Array[String] = ["calm", "tension", "chase"]
const EXPECTED_SAMPLE_RATE: int = 44100
const EXPECTED_BPM: float = 80.0
const EXPECTED_LOOP_S: float = 12.0
const DURATION_TOL_S: float = 0.0005
const RMS_TARGET_DBFS: float = -20.0
const RMS_TOL_DB: float = 0.1
const PEAK_CEILING_DBFS: float = -3.0


func _manifest() -> Dictionary:
	var file: FileAccess = FileAccess.open(MANIFEST_PATH, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary:
		return parsed
	return {}


func _items() -> Array:
	var files: Variant = _manifest().get("files", [])
	if files is Array:
		return files
	return []


func _item_for_layer(layer: String) -> Dictionary:
	for item: Dictionary in _items():
		if str(item.get("layer", "")) == layer:
			return item
	return {}


func _stream(file: String) -> AudioStreamWAV:
	return load(MUSIC_DIR + file) as AudioStreamWAV


func test_tres_camadas_no_manifesto_e_no_disco() -> void:
	assert_false(_manifest().is_empty(), "manifest.json ausente ou inválido")
	assert_eq(_items().size(), LAYERS.size(), "uma entrada por camada")
	for layer: String in LAYERS:
		var item: Dictionary = _item_for_layer(layer)
		assert_false(item.is_empty(), "camada %s no manifesto" % layer)
		if item.is_empty():
			continue
		assert_eq(str(item["sound_id"]), "music_" + layer, "sound_id da camada %s" % layer)
		assert_true(FileAccess.file_exists(MUSIC_DIR + str(item["file"])), "WAV da camada %s no disco" % layer)


func test_mesma_duracao_e_mesmo_tempo_nas_tres_camadas() -> void:
	var manifest: Dictionary = _manifest()
	assert_almost_eq(float(manifest.get("bpm", 0.0)), EXPECTED_BPM, 0.0001, "tempo do conjunto: 80 BPM")
	assert_almost_eq(float(manifest.get("loop_seconds", 0.0)), EXPECTED_LOOP_S, 0.0001, "duração do loop: 12 s")
	for layer: String in LAYERS:
		var item: Dictionary = _item_for_layer(layer)
		if item.is_empty():
			continue
		assert_almost_eq(float(item["duration_s"]), EXPECTED_LOOP_S, DURATION_TOL_S, "duração de %s" % layer)
		assert_almost_eq(float(item["bpm"]), EXPECTED_BPM, 0.0001, "tempo de %s" % layer)
		assert_true(bool(item["loop"]), "%s é loop" % layer)


func test_importacao_pcm_mono_44100_com_repeticao_direta() -> void:
	for layer: String in LAYERS:
		var item: Dictionary = _item_for_layer(layer)
		if item.is_empty():
			continue
		var stream: AudioStreamWAV = _stream(str(item["file"]))
		assert_not_null(stream, "importa como AudioStreamWAV: " + layer)
		if stream == null:
			continue
		assert_eq(stream.format, AudioStreamWAV.FORMAT_16_BITS, "%s: PCM 16 bits (compress/mode=0)" % layer)
		assert_false(stream.stereo, "%s: mono" % layer)
		assert_eq(stream.mix_rate, EXPECTED_SAMPLE_RATE, "%s: 44,1 kHz" % layer)
		assert_eq(stream.loop_mode, AudioStreamWAV.LOOP_FORWARD, "%s: repetição direta (edit/loop_mode=2)" % layer)
		assert_eq(stream.data.size() / 2, int(item["samples"]), "%s: número de amostras" % layer)


func test_nivel_declarado_e_pico_abaixo_do_teto() -> void:
	for layer: String in LAYERS:
		var item: Dictionary = _item_for_layer(layer)
		if item.is_empty():
			continue
		assert_almost_eq(float(item["rms_dbfs"]), RMS_TARGET_DBFS, RMS_TOL_DB, "RMS de %s em −20 dBFS" % layer)
		assert_true(float(item["peak_dbfs"]) <= PEAK_CEILING_DBFS + 0.0001,
			"%s: pico declarado %.2f dBFS (teto %.1f)" % [layer, float(item["peak_dbfs"]), PEAK_CEILING_DBFS])

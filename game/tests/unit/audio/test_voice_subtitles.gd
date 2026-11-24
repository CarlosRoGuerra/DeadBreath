extends TestCase
## F4-006a (ACC-04, D4-06): legendas provisórias das falas do Observer em content/data/subtitles/subtitles_pt_br.json.
## Cada sound_id de voz do manifesto do mundo tem a chave subtitle.<sound_id> com o texto provisório, em pt-BR, curto.
## Os textos seguem o pedido do Director ("[Observador] ..."), que termina em ? ou !. A regra de tests/unit/ui/
## test_legendas_tabela.gd (texto termina em "]") não cabe nessas falas: conflito registrado no relatório da F4-006a.
## Autor: Audio Engineer (F4-006a).

const TABLE_PATH: String = "res://content/data/subtitles/subtitles_pt_br.json"
const WORLD_MANIFEST: String = "res://content/audio/world/manifest.json"
const MAX_CHARS: int = 32
const PREFIX: String = "[Observador] "
const EXPECTED: Dictionary = {
	"subtitle.voice_suspicious": "[Observador] Hm?",
	"subtitle.voice_investigate": "[Observador] Quem está aí?",
	"subtitle.voice_chase_shout": "[Observador] Ali!",
	"subtitle.voice_search": "[Observador] Cadê você?",
}


func _table() -> Dictionary:
	return Subtitles.load_table(TABLE_PATH)


func _voice_sound_ids() -> Array[String]:
	var out: Array[String] = []
	var file: FileAccess = FileAccess.open(WORLD_MANIFEST, FileAccess.READ)
	if file == null:
		return out
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not (parsed is Dictionary):
		return out
	var files: Variant = (parsed as Dictionary).get("files", [])
	if not (files is Array):
		return out
	for raw: Variant in files:
		if raw is Dictionary and str((raw as Dictionary).get("role", "")) == "voice":
			var sound: String = str((raw as Dictionary).get("sound_id", ""))
			if not out.has(sound):
				out.append(sound)
	return out


func test_quatro_falas_tem_o_texto_provisorio_aprovado() -> void:
	var table: Dictionary = _table()
	assert_false(table.is_empty(), "a tabela carrega")
	for raw_key: Variant in EXPECTED.keys():
		var key: String = str(raw_key)
		assert_true(table.has(key), "%s existe" % key)
		if table.has(key):
			assert_eq(str(table[key]), str(EXPECTED[key]), "texto de %s" % key)


func test_cada_fala_do_manifesto_tem_legenda() -> void:
	var table: Dictionary = _table()
	var sounds: Array[String] = _voice_sound_ids()
	assert_eq(sounds.size(), EXPECTED.size(), "quatro sound_id de voz no manifesto do mundo")
	for sound: String in sounds:
		var key: String = "subtitle." + sound
		assert_true(table.has(key), "%s tem legenda" % key)


func test_legendas_de_voz_sao_curtas_e_tem_o_prefixo_do_observador() -> void:
	for raw_key: Variant in EXPECTED.keys():
		var key: String = str(raw_key)
		var text: String = str(EXPECTED[key])
		assert_true(text.begins_with(PREFIX), "%s começa com [Observador]" % key)
		assert_true(text.length() <= MAX_CHARS, "%s curta (%d caracteres)" % [key, text.length()])

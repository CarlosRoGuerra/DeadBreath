extends TestCase
## F3-006 (ACC-04): a tabela de legendas cobre todas as chaves que o AcousticWorld pode pedir (subtitle.<sound_id>),
## com os sound_id vindos dos próprios produtores (constantes), e os textos seguem o padrão curto entre colchetes.
## Autor: Gameplay Engineer.


const TABLE_PATH: String = "res://content/data/subtitles/subtitles_pt_br.json"
const VOICE_PREFIX: String = "subtitle.voice_"
const VOICE_MAX_CHARS: int = 40


func _table() -> Dictionary:
	return Subtitles.load_table(TABLE_PATH)


## Sound ids que o AcousticWorld pode transformar em legenda (_maybe_subtitle): tosse, portas (DOOR) e passos/corrida
## de outra fonte (FOOTSTEP/RUNNING). Falas (VOICE) ainda não têm produtor no jogo.
func _requestable_keys() -> PackedStringArray:
	var keys: PackedStringArray = PackedStringArray()
	keys.append("subtitle." + String(BreathEmitter.COUGH_SOUND))
	for sound: StringName in [Door.SOUND_SLOW, Door.SOUND_NORMAL, Door.SOUND_LOCKED, &"door_slam"]:
		keys.append("subtitle." + String(sound))
	for surface: StringName in [&"wood", &"carpet", &"tile", &"concrete"]:
		keys.append("subtitle." + String(PlayerNoiseMap.footstep_sound(surface)))
	return keys


func test_toda_chave_pedivel_tem_texto() -> void:
	var table: Dictionary = _table()
	assert_false(table.is_empty(), "a tabela carrega")
	for key: String in _requestable_keys():
		assert_true(table.has(key), "%s tem texto" % key)
		if table.has(key):
			assert_false(str(table[key]).strip_edges().is_empty(), "%s não é vazio" % key)


## Sons: texto curto entre colchetes ("[tosse]"). Falas (subtitle.voice_*; Director, D4-06 da F4): "[Falante] texto",
## com o nome de quem fala entre colchetes e a fala depois.
func test_textos_curtos_entre_colchetes() -> void:
	var table: Dictionary = _table()
	for key: Variant in table.keys():
		var text: String = str(table[key])
		if String(key).begins_with(VOICE_PREFIX):
			var close: int = text.find("] ")
			assert_true(text.begins_with("[") and close > 1 and text.length() > close + 2,
				"%s é fala com falante: %s" % [key, text])
			assert_true(text.length() <= VOICE_MAX_CHARS, "%s curto (%d caracteres)" % [key, text.length()])
			continue
		assert_true(text.begins_with("[") and text.ends_with("]"), "%s entre colchetes: %s" % [key, text])
		assert_true(text.length() <= 32, "%s curto (%d caracteres)" % [key, text.length()])


func test_tabela_ausente_nao_derruba_o_jogo() -> void:
	assert_eq(Subtitles.load_table("res://content/data/subtitles/nao_existe.json").size(), 0, "tabela vazia, nada aparece")

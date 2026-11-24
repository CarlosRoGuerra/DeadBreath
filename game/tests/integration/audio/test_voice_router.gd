extends TestCase
## F4-006a (D4-06): o NoiseAudioRouter toca VOICE pelo sound_id, sem código novo (WorldClips resolve a fala pelo próprio
## sound_id; falas não têm marcha). Confere o arquivo do sound_id certo, a regra de ganho (DATA §2.4), a ordem de volume
## entre fala e grito, o limiar do jogador e as legendas pedidas ao EventBus (subtitle.voice_*).
## Autor: Audio Engineer (F4-006a).

const Rooms := preload("res://tests/integration/audio/fixtures/acoustic_rooms.gd")
const TOL: float = 0.0001
const VOICES: Array[StringName] = [&"voice_suspicious", &"voice_investigate", &"voice_chase_shout", &"voice_search"]
const SPEECH_DB: float = 55.0
const SHOUT_DB: float = 75.0
const NEAR_M: float = 2.0

var _level: Node3D = null
var _world: AcousticWorld = null
var _router: NoiseAudioRouter = null
var _ear: Node3D = null
var _subtitles: Array[StringName] = []


func before_each() -> void:
	_level = Node3D.new()
	add_child_autofree(_level)
	_world = Rooms.build_plain_world(_level)
	_ear = Node3D.new()
	_level.add_child(_ear)
	_world.set_player_ear(_ear)
	_router = NoiseAudioRouter.new()
	_level.add_child(_router)
	_router.bind_world(_world)
	_router.set_random_seed(23)
	_subtitles.clear()
	EventBus.subtitle_requested.connect(_collect_subtitle)


func after_each() -> void:
	if EventBus.subtitle_requested.is_connected(_collect_subtitle):
		EventBus.subtitle_requested.disconnect(_collect_subtitle)


func _collect_subtitle(text_key: StringName, _duration: float) -> void:
	_subtitles.append(text_key)


func _emit_voice(sound: StringName, level_db: float, distance: float) -> void:
	var event: NoiseEvent = NoiseEvent.create(Enums.NoiseCategory.VOICE, Vector3(distance, 0.0, 0.0), level_db, 1.0,
		&"observer", sound)
	_world.emit_noise(event)
	_world.advance(0.0)


func test_cada_fala_toca_o_arquivo_do_proprio_sound_id() -> void:
	for sound: StringName in VOICES:
		_emit_voice(sound, SPEECH_DB, NEAR_M)
	assert_eq(_router.played_log.size(), VOICES.size(), "uma voz tocada por fala")
	for index: int in range(_router.played_log.size()):
		var entry: Dictionary = _router.played_log[index]
		var sound: String = String(entry["sound_id"])
		assert_true(VOICES.has(StringName(sound)), "sound_id de voz: %s" % sound)
		assert_true(String(entry["file"]).begins_with(sound + "_v"), "arquivo %s é do sound_id %s" % [entry["file"], sound])
		assert_eq(int(entry["category"]), Enums.NoiseCategory.VOICE, "categoria VOICE")


func test_voz_segue_a_regra_de_ganho() -> void:
	_emit_voice(&"voice_search", SPEECH_DB, NEAR_M)
	_emit_voice(&"voice_chase_shout", SHOUT_DB, NEAR_M)
	assert_eq(_router.played_log.size(), 2, "fala e grito tocados")
	for entry: Dictionary in _router.played_log:
		var perceived: float = float(entry["perceived_db"])
		assert_almost_eq(float(entry["gain_db"]), NoiseGain.gain_for_db(perceived), TOL,
			"ganho da voz = regra de NoiseGain sobre %.2f dB" % perceived)


func test_grito_sai_mais_alto_que_a_fala() -> void:
	_emit_voice(&"voice_suspicious", SPEECH_DB, NEAR_M)
	_emit_voice(&"voice_chase_shout", SHOUT_DB, NEAR_M)
	assert_eq(_router.played_log.size(), 2, "os dois tocaram")
	var speech_gain: float = float(_router.played_log[0]["gain_db"])
	var shout_gain: float = float(_router.played_log[1]["gain_db"])
	assert_true(shout_gain > speech_gain, "grito (%.2f dB) acima da fala (%.2f dB)" % [shout_gain, speech_gain])


func test_fala_abaixo_do_limiar_do_jogador_nao_toca() -> void:
	_emit_voice(&"voice_investigate", 20.0, 30.0)
	assert_eq(_router.played_log.size(), 0, "fala a 30 m, 20 dB: abaixo do limiar do jogador, não toca")


func test_falas_pedem_legenda_pela_chave_do_sound_id() -> void:
	for sound: StringName in VOICES:
		_emit_voice(sound, SPEECH_DB, NEAR_M)
	for sound: StringName in VOICES:
		var key: StringName = StringName("subtitle." + String(sound))
		assert_true(_subtitles.has(key), "legenda pedida: %s" % String(key))

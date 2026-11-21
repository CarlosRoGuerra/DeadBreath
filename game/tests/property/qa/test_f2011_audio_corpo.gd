extends TestCase
## F2-011 (QA Engineer): nenhum som do corpo sem evento. No sandbox_playable.tscn real, em repouso e depois de uma
## corrida curta. Medição por janelas: o BreathingAudio liga-se ao AcousticWorld por call_deferred, então a janela só
## abre depois de confirmar a ligação e de um período de regime. Dentro da janela, contador e áudio escutam o mesmo
## sinal (noise_resolved_for_player): a inspiração toca no instante do evento (atraso zero), então é contada exata;
## expiração e camada de chiado tocam depois (chain_timing) e admitem uma pendente de cada lado da janela. Sons com
## sound_id sem evento são verificados no log inteiro.

const QaFixture := preload("res://tests/integration/qa/fixtures/qa_fixture.gd")
const PlayerWorld := preload("res://tests/integration/player/fixtures/player_world.gd")
const SETTLE_FRAMES: int = 12
const REST_FRAMES: int = 420
const RUN_FRAMES: int = 300
const BIND_FRAMES_MAX: int = 10
const ONE_SHOT_IDS: Array[String] = ["gasp", "cough_warning", "cough", "inhaler_puff"]
const LAYER_ID: String = "wheeze"
const PENDING_TOLERANCE: int = 1

var _previous: Dictionary = {}
var _body_events: Array[NoiseEvent] = []
var _window_events_start: int = 0
var _window_played_start: int = 0


func before_all() -> void:
	Settings.autosave = false


func after_all() -> void:
	Settings.autosave = true


func before_each() -> void:
	_previous = PlayerWorld.override_settings({&"master_volume": 0.0})
	_body_events = []


func after_each() -> void:
	PlayerWorld.restore_settings(_previous)


func test_cada_som_do_corpo_tem_um_evento_em_repouso_e_na_corrida() -> void:
	var world: Node3D = add_isolated_world()
	var scene_root: Node = QaFixture.instantiate_scene(QaFixture.PLAYABLE_PATH, world)
	var player: PlayerRoot = QaFixture.find_player(scene_root)
	var audio: BreathingAudio = scene_root.get_node("BreathingAudio") as BreathingAudio
	var acoustic: AcousticWorld = scene_root.get_node("AcousticWorld") as AcousticWorld
	acoustic.noise_resolved_for_player.connect(_on_noise)
	var bound: bool = false
	for _frame: int in BIND_FRAMES_MAX:
		await get_tree().process_frame
		bound = audio.get("_world") == acoustic
		if bound:
			break
	assert_true(bound, "pré-condição: o BreathingAudio já está ligado ao AcousticWorld da cena")
	await wait_physics_frames(SETTLE_FRAMES)
	_open_window(audio)
	await wait_physics_frames(REST_FRAMES)
	_check_window(audio, "repouso")
	_open_window(audio)
	player.get_motor().set_scripted_input(PlayerWorld.move_input(Vector2(0.0, 1.0), true))
	await wait_physics_frames(RUN_FRAMES)
	player.get_motor().set_scripted_input(null)
	await wait_physics_frames(SETTLE_FRAMES)
	_check_window(audio, "corrida")
	_check_whole_log(audio)
	release_and_flush(world)


func _on_noise(event: NoiseEvent, _result: PropagationResult) -> void:
	if event.source_id == &"player":
		_body_events.append(event)


## Abre uma janela de medição: a partir de agora, eventos e entradas do played_log novos pertencem a ela.
func _open_window(audio: BreathingAudio) -> void:
	_window_events_start = _body_events.size()
	_window_played_start = audio.played_log.size()


func _check_window(audio: BreathingAudio, label: String) -> void:
	var breath_events: int = 0
	var wheeze_events: int = 0
	var shot_events: int = 0
	for index: int in range(_window_events_start, _body_events.size()):
		var event: NoiseEvent = _body_events[index]
		var id: String = str(event.sound_id)
		if ONE_SHOT_IDS.has(id):
			shot_events += 1
		elif BreathParams.FAMILY_TABLE.has(event.sound_id):
			breath_events += 1
			if event.category == Enums.NoiseCategory.WHEEZING:
				wheeze_events += 1
	var inhale_n: int = 0
	var exhale_n: int = 0
	var layer_n: int = 0
	var shot_n: int = 0
	for index: int in range(_window_played_start, audio.played_log.size()):
		var entry: Dictionary = audio.played_log[index]
		var role: String = str(entry["role"])
		if role == "inhale":
			inhale_n += 1
		elif role == "exhale":
			exhale_n += 1
		elif role == "layer":
			layer_n += 1
		elif role == "one_shot":
			shot_n += 1
	note("%s: eventos de respiração=%d (chiado=%d), pontuais=%d; sons: inspiração=%d expiração=%d camada=%d pontual=%d" % [
		label, breath_events, wheeze_events, shot_events, inhale_n, exhale_n, layer_n, shot_n])
	assert_eq(inhale_n, breath_events, "%s: cada evento de respiração gera uma inspiração, sem extra" % label)
	assert_true(absi(exhale_n - breath_events) <= PENDING_TOLERANCE,
		"%s: cada inspiração tem sua expiração (no máximo uma pendente na borda)" % label)
	assert_true(absi(layer_n - wheeze_events) <= PENDING_TOLERANCE,
		"%s: cada evento de chiado tem sua camada (no máximo uma pendente na borda)" % label)
	assert_eq(shot_n, shot_events, "%s: cada evento pontual toca uma vez" % label)


## Nenhum som do corpo sem evento: todo sound_id tocado no log inteiro existe entre os eventos do jogador.
func _check_whole_log(audio: BreathingAudio) -> void:
	var allowed: Array[String] = [LAYER_ID]
	for event: NoiseEvent in _body_events:
		allowed.append(str(event.sound_id))
	var unexpected: int = 0
	for entry: Dictionary in audio.played_log:
		if not allowed.has(str(entry["sound_id"])):
			unexpected += 1
	assert_eq(unexpected, 0, "nenhum som do corpo com sound_id sem evento (log inteiro)")

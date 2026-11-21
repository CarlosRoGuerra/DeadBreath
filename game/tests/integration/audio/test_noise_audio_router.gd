extends TestCase
## F3-003b: NoiseAudioRouter com AcousticWorld real (COMPONENT_CONTRACTS §14).
## NOI-04 (20 eventos: volume aplicado × perceived_db pela regra de ganho), exclusão dos sons do corpo do jogador (e
## do BreathingAudio dos sons do mundo), escolha de arquivo por superfície, marcha e faixa de impacto, limite de vozes,
## panning sem atenuação nativa, variação de pitch contida, não repetir a mesma variação em seguida, posição pelo
## entry_point e barramento de reverb pela sala do ouvinte.
## Autor: Audio Engineer (F3-003b).

const Rooms := preload("res://tests/integration/audio/fixtures/acoustic_rooms.gd")
const TOL: float = 0.0001
const NOI04_EVENTS: int = 20

var _level: Node3D = null
var _world: AcousticWorld = null
var _router: NoiseAudioRouter = null
var _ear: Node3D = null


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
	_router.set_random_seed(11)


func _emit(category: Enums.NoiseCategory, level_db: float, sound: StringName, source: StringName = &"world_door",
		at: Vector3 = Vector3(2.0, 0.0, 0.0)) -> void:
	var event: NoiseEvent = NoiseEvent.create(category, at, level_db, 1.0, source, sound)
	_world.emit_noise(event)
	_world.advance(0.0)


func _entry_files() -> Array[String]:
	var out: Array[String] = []
	for entry: Dictionary in _router.played_log:
		out.append(entry["file"])
	return out


func test_noi_04_volume_matches_perceived_rule_over_20_events() -> void:
	# Eventos a distâncias e intensidades crescentes: uns caem na faixa 0..45 dB (regra linear), outros saturam em 0 dB.
	for i in range(NOI04_EVENTS):
		var distance: float = 1.0 + 0.5 * float(i)
		var level: float = 45.0 + 2.0 * float(i)
		_emit(Enums.NoiseCategory.DOOR, level, &"door_normal", &"world_door", Vector3(distance, 0.0, 0.0))
	assert_eq(_router.played_log.size(), NOI04_EVENTS, "os 20 eventos tocaram")
	var linear_band: int = 0
	for entry: Dictionary in _router.played_log:
		var perceived: float = entry["perceived_db"]
		var gain: float = entry["gain_db"]
		assert_almost_eq(gain, NoiseGain.gain_for_db(perceived), 0.5,
			"NOI-04: volume aplicado difere ≤ 0,5 dB da regra sobre o perceived_db (%.2f dB)" % perceived)
		if perceived <= NoiseGain.BODY_REFERENCE_DB and perceived >= NoiseGain.MIN_GAIN_DB + NoiseGain.BODY_REFERENCE_DB:
			linear_band += 1
			assert_almost_eq(gain, perceived - NoiseGain.BODY_REFERENCE_DB, 0.5,
				"na faixa linear o volume é perceived − 45 dB (referência compartilhada)")
	assert_true(linear_band >= 5, "pelo menos 5 eventos caem na faixa linear (%d)" % linear_band)


func test_perceived_level_comes_from_the_propagation_not_the_source() -> void:
	# O nível registrado é o que o AcousticWorld calcula para o ouvido: intensidade − perda por distância.
	_emit(Enums.NoiseCategory.DOOR, 70.0, &"door_normal", &"world_door", Vector3(10.0, 0.0, 0.0))
	var expected: float = 70.0 - AcousticPropagation.distance_loss_db(10.0)
	assert_almost_eq(float(_router.played_log[0]["perceived_db"]), expected, TOL, "perceived = intensidade − perda a 10 m")


func test_router_ignores_the_players_own_body_sounds() -> void:
	_emit(Enums.NoiseCategory.BREATHING, 30.0, &"breath_calm", &"player")
	_emit(Enums.NoiseCategory.COUGHING, 65.0, &"cough", &"player")
	_emit(Enums.NoiseCategory.MEDICATION, 38.0, &"inhaler_puff", &"player")
	_emit(Enums.NoiseCategory.WHEEZING, 40.0, &"breath_labored", &"player")
	assert_eq(_router.played_log.size(), 0, "sons do corpo do jogador são do BreathingAudio")


func test_router_plays_the_players_steps_and_doors_as_world_sounds() -> void:
	_emit(Enums.NoiseCategory.FOOTSTEP, 40.0, &"footstep_wood", &"player")
	_emit(Enums.NoiseCategory.DOOR, 50.0, &"door_normal", &"player")
	assert_eq(_router.played_log.size(), 2, "passos e portas do jogador são do mundo")


func test_breathing_audio_ignores_world_events() -> void:
	var breathing: BreathingAudio = BreathingAudio.new()
	_level.add_child(breathing)
	breathing.bind_world(_world)
	_emit(Enums.NoiseCategory.FOOTSTEP, 40.0, &"footstep_wood", &"enemy_observer")
	_emit(Enums.NoiseCategory.DOOR, 50.0, &"door_normal", &"world_door")
	assert_eq(breathing.played_log.size(), 0, "o BreathingAudio não toca sons do mundo")
	assert_eq(_router.played_log.size(), 2, "o router toca os dois")


func test_footstep_file_follows_surface_and_gait() -> void:
	# Intensidade = nível da marcha + modificador da superfície (madeira +6): 18+6, 25+6, 32+6, 40+6.
	_emit(Enums.NoiseCategory.FOOTSTEP, 24.0, &"footstep_wood", &"player")
	_emit(Enums.NoiseCategory.FOOTSTEP, 31.0, &"footstep_wood", &"player")
	_emit(Enums.NoiseCategory.FOOTSTEP, 38.0, &"footstep_wood", &"player")
	_emit(Enums.NoiseCategory.FOOTSTEP, 46.0, &"footstep_wood", &"player")
	_emit(Enums.NoiseCategory.FOOTSTEP, 32.0, &"footstep_carpet", &"player")
	_emit(Enums.NoiseCategory.RUNNING, 60.0, &"footstep_concrete", &"player")
	var expected: Array[String] = ["crawl", "crouch", "slow", "walk", "walk", "run"]
	var surfaces: Array[String] = ["wood", "wood", "wood", "wood", "carpet", "concrete"]
	assert_eq(_router.played_log.size(), 6, "seis passos tocaram")
	for i in range(min(6, _router.played_log.size())):
		var entry: Dictionary = _router.played_log[i]
		var file: String = entry["file"]
		assert_true(file.begins_with("footstep_%s_%s_v" % [surfaces[i], expected[i]]),
			"passo %d: %s (esperado %s/%s)" % [i, file, surfaces[i], expected[i]])


func test_impact_file_follows_intensity_band() -> void:
	_emit(Enums.NoiseCategory.OBJECT_IMPACT, 55.0, &"impact", &"world_object")
	_emit(Enums.NoiseCategory.OBJECT_IMPACT, 65.0, &"impact", &"world_object")
	_emit(Enums.NoiseCategory.OBJECT_IMPACT, 78.0, &"impact", &"world_object")
	var files: Array[String] = _entry_files()
	assert_eq(files.size(), 3, "três impactos tocaram")
	if files.size() == 3:
		assert_true(files[0].begins_with("impact_light_v"), "55 dB: leve (%s)" % files[0])
		assert_true(files[1].begins_with("impact_medium_v"), "65 dB: médio (%s)" % files[1])
		assert_true(files[2].begins_with("impact_heavy_v"), "78 dB: pesado (%s)" % files[2])


func test_voices_are_limited_to_the_maximum() -> void:
	for i in range(30):
		_emit(Enums.NoiseCategory.DOOR, 60.0, &"door_normal", &"world_door", Vector3(2.0 + 0.1 * i, 0.0, 0.0))
	assert_eq(_router.played_log.size(), 30, "os 30 eventos foram tocados")
	assert_eq(_router.active_voice_count(), NoiseAudioRouter.MAX_VOICES, "vozes simultâneas limitadas a MAX_VOICES")


func test_voices_are_3d_with_native_attenuation_disabled() -> void:
	_emit(Enums.NoiseCategory.DOOR, 60.0, &"door_normal")
	_emit(Enums.NoiseCategory.DOOR, 60.0, &"door_slam")
	var voices: int = 0
	for child: Node in _router.get_children():
		if child is AudioStreamPlayer3D:
			voices += 1
			var player: AudioStreamPlayer3D = child
			assert_eq(player.attenuation_model, AudioStreamPlayer3D.ATTENUATION_DISABLED,
				"atenuação nativa desligada (NOI-INV-2)")
	assert_eq(voices, 2, "duas vozes 3D")


func test_pitch_is_contained_within_four_percent() -> void:
	for i in range(20):
		_emit(Enums.NoiseCategory.DOOR, 60.0, &"door_normal")
	for entry: Dictionary in _router.played_log:
		var pitch: float = entry["pitch"]
		assert_true(pitch >= 1.0 - NoiseAudioRouter.PITCH_JITTER - TOL and pitch <= 1.0 + NoiseAudioRouter.PITCH_JITTER + TOL,
			"pitch %.4f dentro de ±4 %%" % pitch)


func test_same_variation_is_not_repeated_back_to_back() -> void:
	for i in range(12):
		_emit(Enums.NoiseCategory.DOOR, 60.0, &"door_normal")
	var previous: int = -1
	for entry: Dictionary in _router.played_log:
		var variation: int = entry["variation"]
		assert_true(variation != previous, "a mesma variação não se repete em seguida (%d)" % variation)
		previous = variation


func test_position_is_the_entry_point_of_the_path() -> void:
	# Caminho direto (sem portal): o entry_point é a própria fonte.
	_emit(Enums.NoiseCategory.DOOR, 60.0, &"door_normal", &"world_door", Vector3(3.0, 0.0, 4.0))
	assert_eq(_router.played_log[0]["position"], Vector3(3.0, 0.0, 4.0), "posição = entry_point (fonte, caminho direto)")


func test_sound_below_the_player_threshold_is_not_played() -> void:
	# 10 dB de audibilidade: 12 dB a 1 m de distância ainda sobra; 12 dB a 50 m não toca.
	_emit(Enums.NoiseCategory.DOOR, 12.0, &"door_normal", &"world_door", Vector3(50.0, 0.0, 0.0))
	assert_eq(_router.played_log.size(), 0, "abaixo do limiar do jogador não toca")


func test_missing_sound_plays_nothing() -> void:
	_emit(Enums.NoiseCategory.DOOR, 60.0, &"door_inexistente")
	assert_eq(_router.played_log.size(), 0, "sem arquivo, nada toca")


func test_reverb_bus_follows_the_listener_room() -> void:
	# Sala A (piso 22, barramento reverb_small) e sala B (piso 38, barramento reverb_large).
	var scene: Node3D = Node3D.new()
	add_child_autofree(scene)
	var rooms: Dictionary = Rooms.build_two_rooms(scene)
	var world: AcousticWorld = rooms["world"]
	var listener: Node3D = Node3D.new()
	scene.add_child(listener)
	world.set_player_ear(listener)
	var router: NoiseAudioRouter = NoiseAudioRouter.new()
	scene.add_child(router)
	router.bind_world(world)
	router.set_listener(listener)

	listener.global_position = Vector3(0.0, 1.0, 0.0)
	world.emit_noise(NoiseEvent.create(Enums.NoiseCategory.DOOR, Vector3(1.0, 0.0, 0.0), 60.0, 1.0, &"world_door", &"door_normal"))
	world.advance(0.0)
	listener.global_position = Vector3(10.0, 1.0, 0.0)
	world.emit_noise(NoiseEvent.create(Enums.NoiseCategory.DOOR, Vector3(9.0, 0.0, 0.0), 60.0, 1.0, &"world_door", &"door_normal"))
	world.advance(0.0)
	assert_eq(router.played_log.size(), 2, "dois eventos tocaram")
	if router.played_log.size() == 2:
		assert_eq(router.played_log[0]["bus"], &"reverb_small", "ouvinte na sala A: reverb_small")
		assert_eq(router.played_log[1]["bus"], &"reverb_large", "ouvinte na sala B: reverb_large")


func test_bus_is_master_outside_any_room() -> void:
	var scene: Node3D = Node3D.new()
	add_child_autofree(scene)
	var rooms: Dictionary = Rooms.build_two_rooms(scene)
	var world: AcousticWorld = rooms["world"]
	var listener: Node3D = Node3D.new()
	scene.add_child(listener)
	listener.global_position = Vector3(5.0, 1.0, 0.0)
	world.set_player_ear(listener)
	var router: NoiseAudioRouter = NoiseAudioRouter.new()
	scene.add_child(router)
	router.bind_world(world)
	router.set_listener(listener)
	world.emit_noise(NoiseEvent.create(Enums.NoiseCategory.DOOR, Vector3(5.0, 0.0, 0.0), 60.0, 1.0, &"world_door", &"door_normal"))
	world.advance(0.0)
	assert_eq(router.played_log.size(), 1, "um evento tocou")
	if router.played_log.size() == 1:
		assert_eq(router.played_log[0]["bus"], NoiseAudioRouter.MASTER_BUS, "fora das salas: Master")

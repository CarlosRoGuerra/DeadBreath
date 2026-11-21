extends TestCase
## F2-006b (COMPONENT_CONTRACTS §14, DATA_STRUCTURES §2.4): BreathingAudio toca só a partir de
## AcousticWorld.noise_resolved_for_player, do jogador, nas categorias do corpo. Escolhe o arquivo por sound_id
## e papel, encadeia inspiração e expiração no período do evento (sem cortar a expiração), toca a camada de
## chiado, e o volume vem de perceived_db (NOI-INV-2). Nunca toca sem evento.
## Autor: Audio Engineer (F2-006b).

const TOL: float = 0.0001
const DT: float = 1.0 / 60.0
const MANIFEST_PATH: String = "res://content/audio/body/manifest.json"
const REQUIRED: Array[Array] = [
	[&"breath_calm", &"inhale"], [&"breath_calm", &"exhale"],
	[&"breath_fast", &"inhale"], [&"breath_fast", &"exhale"],
	[&"breath_labored", &"inhale"], [&"breath_labored", &"exhale"],
	[&"wheeze", &"layer"],
	[&"cough_warning", &"one_shot"], [&"cough", &"one_shot"],
	[&"gasp", &"one_shot"], [&"inhaler_puff", &"one_shot"],
]

var _audio: BreathingAudio = null
var _world: AcousticWorld = null
var _ear: Node3D = null


func before_each() -> void:
	_audio = BreathingAudio.new()
	add_child_autofree(_audio)
	_audio.set_random_seed(7)
	_ear = Node3D.new()
	add_child_autofree(_ear)
	_world = AcousticWorld.new()
	add_child_autofree(_world)
	_world.set_player_ear(_ear)
	_audio.bind_world(_world)


func _push(category: Enums.NoiseCategory, level_db: float, length_s: float, sound: StringName,
		source: StringName = &"player", at: Vector3 = Vector3.ZERO) -> void:
	var event: NoiseEvent = NoiseEvent.create(category, at, level_db, length_s, source, sound)
	_world.emit_noise(event)
	_world.advance(0.0)


func _ticks(seconds: float) -> void:
	var steps: int = int(round(seconds / DT))
	for i in range(steps):
		_audio.tick(DT)


func _find(sound_id: StringName, role: StringName) -> Dictionary:
	for entry: Dictionary in _audio.played_log:
		if entry["sound_id"] == sound_id and entry["role"] == role:
			return entry
	return {}


func test_every_required_sound_has_variations_loaded() -> void:
	for pair: Array in REQUIRED:
		var count: int = _audio.variation_count(pair[0], pair[1])
		assert_true(count >= 2, "%s/%s: %d variações carregadas (mínimo 2)" % [pair[0], pair[1], count])


func test_silent_without_events() -> void:
	_ticks(30.0)
	await wait_process_frames(60)
	assert_eq(_audio.played_log.size(), 0, "nenhum som sem evento (BreathingAudio nunca toca por conta própria)")


func test_breath_event_plays_inhale_then_exhale_chained_to_the_period() -> void:
	var period: float = 60.0 / 14.0
	_push(Enums.NoiseCategory.BREATHING, 20.0, period, &"breath_calm")
	assert_eq(_audio.played_log.size(), 1, "a inspiração começa na hora")
	var timing: Dictionary = BreathParams.chain_timing(&"breath_calm", period)
	_ticks(float(timing["inhale_s"]) + 0.05)
	var inhale: Dictionary = _find(&"breath_calm", &"inhale")
	var exhale: Dictionary = _find(&"breath_calm", &"exhale")
	assert_false(inhale.is_empty(), "inspiração tocada")
	assert_false(exhale.is_empty(), "expiração tocada depois da inspiração")
	if not exhale.is_empty() and not inhale.is_empty():
		assert_almost_eq(float(exhale["start_s"]) - float(inhale["start_s"]), float(timing["inhale_s"]), DT + TOL,
			"expiração começa quando a inspiração (tocada) termina")
		assert_almost_eq(float(inhale["pitch"]), float(timing["pitch_scale"]), TOL, "pitch do encaixe")


func test_exhale_is_never_cut_by_the_next_event_timing() -> void:
	# Família ofegante em 2,4 s: nominal 2,2 s cabe, então a expiração inteira é tocada no pitch do encaixe.
	_push(Enums.NoiseCategory.BREATHING, 30.0, 2.4, &"breath_labored")
	_ticks(3.0)
	var exhale: Dictionary = _find(&"breath_labored", &"exhale")
	assert_false(exhale.is_empty(), "expiração tocada")
	if not exhale.is_empty():
		var timing: Dictionary = BreathParams.chain_timing(&"breath_labored", 2.4)
		var played_exhale: float = float(BreathParams.FAMILY_TABLE[&"breath_labored"]["exhale_s"]) / float(timing["pitch_scale"])
		assert_true(float(exhale["start_s"]) + played_exhale <= 2.4 + DT + TOL,
			"a expiração tocada termina dentro do período (não invade o próximo ciclo)")


func test_wheezing_cycle_adds_layer_starting_with_exhale() -> void:
	_push(Enums.NoiseCategory.WHEEZING, 37.0, 2.2, &"breath_labored")
	_ticks(3.0)
	var exhale: Dictionary = _find(&"breath_labored", &"exhale")
	var layer: Dictionary = _find(&"wheeze", &"layer")
	assert_false(layer.is_empty(), "camada de chiado tocada")
	if not exhale.is_empty() and not layer.is_empty():
		assert_almost_eq(float(layer["start_s"]), float(exhale["start_s"]), DT + TOL, "chiado começa com a expiração")
		assert_true(String(layer["file"]).begins_with("wheeze_layer_"), "arquivo da camada: %s" % layer["file"])


func test_non_wheezing_breath_has_no_layer() -> void:
	_push(Enums.NoiseCategory.BREATHING, 20.0, 4.2857, &"breath_calm")
	_ticks(5.0)
	assert_true(_find(&"wheeze", &"layer").is_empty(), "sem chiado, sem camada")


func test_events_from_other_sources_or_categories_are_ignored() -> void:
	_push(Enums.NoiseCategory.BREATHING, 20.0, 2.0, &"breath_calm", &"enemy_01")
	_push(Enums.NoiseCategory.FOOTSTEP, 40.0, 0.5, &"breath_calm", &"player")
	_push(Enums.NoiseCategory.DOOR, 50.0, 0.5, &"gasp", &"player")
	_ticks(3.0)
	assert_eq(_audio.played_log.size(), 0, "inimigo e categorias fora do corpo não tocam")


func test_one_shots_play_their_own_files() -> void:
	_push(Enums.NoiseCategory.BREATHING, 42.0, 1.2, &"gasp")
	_push(Enums.NoiseCategory.COUGHING, 32.0, 1.5, &"cough_warning")
	_push(Enums.NoiseCategory.COUGHING, 65.0, 1.0, &"cough")
	_push(Enums.NoiseCategory.MEDICATION, 38.0, 1.0, &"inhaler_puff")
	_ticks(0.1)
	assert_eq(_audio.played_log.size(), 4, "quatro disparos")
	for sound: StringName in [&"gasp", &"cough_warning", &"cough", &"inhaler_puff"]:
		var entry: Dictionary = _find(sound, &"one_shot")
		assert_false(entry.is_empty(), "%s tocado como one_shot" % sound)
		if not entry.is_empty():
			assert_true(String(entry["file"]).begins_with(String(sound) + "_v"), "arquivo de %s: %s" % [sound, entry["file"]])


func test_volume_comes_from_perceived_level_not_from_the_source() -> void:
	# Mesma fonte de 45 dB: a 0 m (ouvido na fonte) soa 45 dB (gain 0); a 20 m soa 45 - 0,1·20 - 20·log10(20) dB.
	_push(Enums.NoiseCategory.BREATHING, 45.0, 4.2857, &"breath_calm", &"player", Vector3.ZERO)
	var near: Dictionary = _audio.played_log[0]
	assert_almost_eq(float(near["gain_db"]), 0.0, TOL, "45 dB percebidos = 0 dB de ganho")
	_audio.played_log.clear()
	_push(Enums.NoiseCategory.BREATHING, 45.0, 4.2857, &"breath_calm", &"player", Vector3(0.0, 0.0, 20.0))
	var far: Dictionary = _audio.played_log[0]
	var perceived: float = 45.0 - AcousticPropagation.distance_loss_db(20.0)
	assert_almost_eq(float(far["gain_db"]), BreathingAudio.gain_for_db(perceived), TOL,
		"ganho segue o nível percebido a 20 m (NOI-INV-2)")
	assert_true(float(far["gain_db"]) < float(near["gain_db"]), "mais longe soa mais baixo")


func test_gain_mapping_bounds() -> void:
	assert_almost_eq(BreathingAudio.gain_for_db(60.0), 3.75, TOL, "acima da referência: comprimido 4:1 (60 dB = +3,75 dB)")
	assert_almost_eq(BreathingAudio.gain_for_db(20.0), -25.0, TOL, "respiração calma (20 dB) = -25 dB")
	assert_almost_eq(BreathingAudio.gain_for_db(-100.0), BreathingAudio.MIN_GAIN_DB, TOL, "piso de ganho")


func test_pitch_stays_within_the_fit_tolerance() -> void:
	_push(Enums.NoiseCategory.BREATHING, 30.0, 2.0, &"breath_fast")
	_push(Enums.NoiseCategory.BREATHING, 30.0, 1.5, &"breath_fast")
	_ticks(0.1)
	for entry: Dictionary in _audio.played_log:
		var pitch: float = float(entry["pitch"])
		assert_true(pitch >= BreathParams.PITCH_MIN - TOL and pitch <= BreathParams.PITCH_MAX + TOL,
			"pitch %.3f dentro de 1/1.15..1.15" % pitch)


func test_players_are_not_spatial_and_source_has_no_attenuation() -> void:
	_push(Enums.NoiseCategory.BREATHING, 30.0, 2.0, &"breath_fast")
	_ticks(3.0)
	for child: Node in _audio.get_children():
		assert_false(child is AudioStreamPlayer3D, "voz do corpo não é 3D (sem atenuação nativa, NOI-INV-2)")
	var source: String = SourceScan.read("res://presentation/audio/breathing_audio.gd")
	assert_true(SourceScan.find_all(SourceScan.code_of(source, true), "AudioStreamPlayer3D").is_empty(),
		"breathing_audio.gd não usa AudioStreamPlayer3D")
	assert_true(SourceScan.find_all(SourceScan.code_of(source, true), "(?i)attenuation").is_empty(),
		"breathing_audio.gd não mexe em atenuação")


func test_manifest_families_match_breath_params_table() -> void:
	var file: FileAccess = FileAccess.open(MANIFEST_PATH, FileAccess.READ)
	assert_not_null(file, "manifesto dos sons do corpo")
	if file == null:
		return
	var manifest: Dictionary = JSON.parse_string(file.get_as_text())
	var families: Dictionary = manifest["families"]
	for family_key: String in families.keys():
		var sound: StringName = StringName(String(families[family_key]["sound_id"]))
		assert_true(BreathParams.FAMILY_TABLE.has(sound), "%s existe em BreathParams" % sound)
		if BreathParams.FAMILY_TABLE.has(sound):
			var table: Dictionary = BreathParams.FAMILY_TABLE[sound]
			assert_almost_eq(float(families[family_key]["inhale_s"]), float(table["inhale_s"]), TOL, "inspiração de %s" % sound)
			assert_almost_eq(float(families[family_key]["exhale_s"]), float(table["exhale_s"]), TOL, "expiração de %s" % sound)

extends TestCase
## F3-003b (DATA_STRUCTURES §2.1, §2.3, §2.4; COMPONENT_CONTRACTS §14): funções puras de áudio do mundo.
## Marcha pela intensidade descontada a superfície, faixa do impacto, escolha de som, regra de ganho compartilhada,
## camada de chuva pelo piso e a saída de cada camada (piso − 69 dBFS). Constantes conferidas com noise_levels.tres.
## Autor: Audio Engineer (F3-003b).

const TOL: float = 0.0001
const NOISE_LEVELS_PATH: String = "res://content/data/acoustics/noise_levels.tres"


func test_gait_bands_follow_data_levels() -> void:
	assert_eq(NoiseAudioRouter.gait_for_level(18.0, "concrete"), "crawl", "rastejando 18 dB")
	assert_eq(NoiseAudioRouter.gait_for_level(25.0, "concrete"), "crouch", "agachado 25 dB")
	assert_eq(NoiseAudioRouter.gait_for_level(32.0, "concrete"), "slow", "andando devagar 32 dB")
	assert_eq(NoiseAudioRouter.gait_for_level(40.0, "concrete"), "walk", "andando 40 dB")


func test_surface_offset_is_removed_before_banding() -> void:
	# Tapete tem −8 dB (DATA §2.1): um passo de 32 dB no tapete é andar normal (40 dB sem o modificador).
	assert_eq(NoiseAudioRouter.gait_for_level(32.0, "carpet"), "walk", "32 dB no tapete = andando")
	# Madeira solta tem +6 dB: 40 dB na madeira é andar devagar (34 dB sem o modificador).
	assert_eq(NoiseAudioRouter.gait_for_level(40.0, "wood"), "slow", "40 dB na madeira = andando devagar")


func test_running_is_always_run_and_high_levels_are_run() -> void:
	var choice: Dictionary = NoiseAudioRouter.choose_sound(_event(Enums.NoiseCategory.RUNNING, 60.0, &"footstep_wood"))
	assert_eq(choice["gait"], "run", "RUNNING é corrida")
	assert_eq(NoiseAudioRouter.gait_for_level(60.0, "concrete"), "run", "60 dB é corrida")


func test_impact_bands_by_intensity() -> void:
	assert_eq(NoiseAudioRouter.impact_for_level(55.0), "light", "abaixo de 60: leve")
	assert_eq(NoiseAudioRouter.impact_for_level(60.0), "medium", "60 dB: médio")
	assert_eq(NoiseAudioRouter.impact_for_level(70.0), "medium", "70 dB: médio")
	assert_eq(NoiseAudioRouter.impact_for_level(78.0), "heavy", "acima de 70: pesado")


func test_choose_sound_for_steps_impacts_and_doors() -> void:
	var step: Dictionary = NoiseAudioRouter.choose_sound(_event(Enums.NoiseCategory.FOOTSTEP, 40.0, &"footstep_tile"))
	assert_eq(step["sound"], &"footstep_tile", "passo mantém o som da superfície")
	assert_eq(step["gait"], "walk", "marcha pela intensidade")
	var impact: Dictionary = NoiseAudioRouter.choose_sound(_event(Enums.NoiseCategory.OBJECT_IMPACT, 65.0, &"impact"))
	assert_eq(impact["sound"], &"impact_medium", "impacto de 65 dB é médio")
	var door: Dictionary = NoiseAudioRouter.choose_sound(_event(Enums.NoiseCategory.DOOR, 50.0, &"door_normal"))
	assert_eq(door["sound"], &"door_normal", "porta mantém o sound_id")
	assert_eq(door["gait"], "", "porta não tem marcha")


func test_choose_sound_without_sound_id_is_empty() -> void:
	assert_true(NoiseAudioRouter.choose_sound(_event(Enums.NoiseCategory.DOOR, 50.0, &"")).is_empty(),
		"evento sem sound_id não tem arquivo")


func test_body_categories_are_recognised() -> void:
	assert_true(NoiseAudioRouter.is_body_category(Enums.NoiseCategory.BREATHING), "BREATHING é do corpo")
	assert_true(NoiseAudioRouter.is_body_category(Enums.NoiseCategory.WHEEZING), "WHEEZING é do corpo")
	assert_true(NoiseAudioRouter.is_body_category(Enums.NoiseCategory.COUGHING), "COUGHING é do corpo")
	assert_true(NoiseAudioRouter.is_body_category(Enums.NoiseCategory.MEDICATION), "MEDICATION é do corpo")
	assert_false(NoiseAudioRouter.is_body_category(Enums.NoiseCategory.FOOTSTEP), "FOOTSTEP é do mundo")
	assert_false(NoiseAudioRouter.is_body_category(Enums.NoiseCategory.DOOR), "DOOR é do mundo")


func test_router_constants_match_noise_levels_resource() -> void:
	var levels: NoiseLevels = load(NOISE_LEVELS_PATH) as NoiseLevels
	assert_not_null(levels, "noise_levels.tres carrega")
	if levels == null:
		return
	assert_almost_eq(float(NoiseAudioRouter.SURFACE_OFFSET_DB["wood"]), levels.surface_wood_loose_db, TOL, "madeira")
	assert_almost_eq(float(NoiseAudioRouter.SURFACE_OFFSET_DB["carpet"]), levels.surface_carpet_db, TOL, "tapete")
	assert_almost_eq(float(NoiseAudioRouter.SURFACE_OFFSET_DB["tile"]), levels.surface_tile_db, TOL, "azulejo")
	assert_almost_eq(float(NoiseAudioRouter.SURFACE_OFFSET_DB["concrete"]), levels.surface_concrete_db, TOL, "concreto")
	# A fronteira de marcha é o ponto médio entre os níveis vizinhos de DATA §2.1.
	assert_almost_eq(NoiseAudioRouter.GAIT_BOUND_CRAWL_DB, (levels.footstep_crawl_db + levels.footstep_crouch_db) * 0.5, TOL,
		"fronteira rastejar/agachado")
	assert_almost_eq(NoiseAudioRouter.GAIT_BOUND_CROUCH_DB, (levels.footstep_crouch_db + levels.footstep_slow_db) * 0.5, TOL,
		"fronteira agachado/devagar")
	assert_almost_eq(NoiseAudioRouter.GAIT_BOUND_SLOW_DB, (levels.footstep_slow_db + levels.footstep_walk_db) * 0.5, TOL,
		"fronteira devagar/andando")
	assert_almost_eq(NoiseAudioRouter.GAIT_BOUND_WALK_DB, (levels.footstep_walk_db + levels.running_db) * 0.5, TOL,
		"fronteira andando/corrida")


func test_gain_rule_is_the_breathing_rule() -> void:
	assert_almost_eq(NoiseGain.gain_for_db(60.0), 3.75, TOL, "acima da referência: 4:1 (60 dB = +3,75 dB)")
	assert_almost_eq(NoiseGain.gain_for_db(45.0), 0.0, TOL, "na referência: 0 dB")
	assert_almost_eq(NoiseGain.gain_for_db(69.0), NoiseGain.MAX_GAIN_DB, TOL, "teto alcançado em 69 dB")
	assert_almost_eq(NoiseGain.gain_for_db(90.0), NoiseGain.MAX_GAIN_DB, TOL, "nunca acima do teto")
	assert_almost_eq(NoiseGain.gain_for_db(20.0), -25.0, TOL, "20 dB: −25 dB")
	assert_almost_eq(NoiseGain.gain_for_db(-100.0), NoiseGain.MIN_GAIN_DB, TOL, "piso")
	for level: float in [10.0, 30.0, 45.0, 52.0]:
		assert_almost_eq(BreathingAudio.gain_for_db(level), NoiseGain.gain_for_db(level), TOL,
			"BreathingAudio e router usam a mesma regra em %.0f dB" % level)


## Decisão do Director (integração da F3-003b): acima da referência a regra não satura mais em 0 dB. O que a IA
## ouve mais alto o jogador também ouve mais alto: porta normal (50) < corrida (60) < tosse (65) < 69 dB.
func test_gain_keeps_the_order_above_the_reference() -> void:
	var levels: Array[float] = [20.0, 30.0, 40.0, 45.0, 50.0, 55.0, 60.0, 65.0, 69.0]
	for index: int in range(levels.size() - 1):
		var lower: float = NoiseGain.gain_for_db(levels[index])
		var upper: float = NoiseGain.gain_for_db(levels[index + 1])
		assert_true(lower < upper, "%.0f dB (%.2f) soa abaixo de %.0f dB (%.2f)" % [levels[index], lower,
			levels[index + 1], upper])
	assert_true(NoiseGain.gain_for_db(75.0) - NoiseGain.gain_for_db(50.0) >= 4.5,
		"porta batida (75) pelo menos 4,5 dB acima da porta normal (50)")


func test_rain_layer_follows_room_floor() -> void:
	assert_eq(RainAmbience.layer_for_floor(12.0), RainAmbience.LAYER_INTERIOR, "porão 12 dB: interna")
	assert_eq(RainAmbience.layer_for_floor(22.0), RainAmbience.LAYER_INTERIOR, "cômodo interno 22 dB: interna")
	assert_eq(RainAmbience.layer_for_floor(25.0), RainAmbience.LAYER_WINDOW, "25 dB: janela")
	assert_eq(RainAmbience.layer_for_floor(28.0), RainAmbience.LAYER_WINDOW, "janela 28 dB: janela")
	assert_eq(RainAmbience.layer_for_floor(33.0), RainAmbience.LAYER_EXTERIOR, "33 dB: exterior")
	assert_eq(RainAmbience.layer_for_floor(38.0), RainAmbience.LAYER_EXTERIOR, "exterior 38 dB: exterior")


func test_rain_output_level_is_the_floor_for_every_layer() -> void:
	# Saída = clip RMS + ganho = piso − 69 dBFS, qualquer que seja a camada (mesma escala dos eventos com clip de −24).
	var cases: Array = [[22.0, -34.0], [28.0, -28.0], [38.0, -24.0], [30.0, -28.0], [12.0, -34.0]]
	for case: Array in cases:
		var floor_db: float = case[0]
		var clip_rms: float = case[1]
		var gain: float = RainAmbience.gain_for_floor(floor_db, clip_rms)
		assert_almost_eq(clip_rms + gain, floor_db - NoiseGain.BODY_REFERENCE_DB - 24.0, TOL,
			"piso %.0f com clip %.0f: saída = piso − 69" % [floor_db, clip_rms])


func test_thunder_gain_is_muffled_inside_rooms() -> void:
	# Revisão F3-010, R3-07: o trovão soa no nível do mascaramento (piso + 20 dB).
	assert_almost_eq(RainAmbience.thunder_gain_for_floor(38.0), NoiseGain.gain_for_db(58.0), TOL, "ao ar livre: 58 dB")
	assert_almost_eq(RainAmbience.thunder_gain_for_floor(22.0), -3.0, TOL, "cômodo interno: 42 dB, −3 dB")
	assert_almost_eq(RainAmbience.thunder_gain_for_floor(60.0), NoiseGain.MAX_GAIN_DB, TOL, "nunca acima do teto")
	for floor_db: float in [12.0, 22.0, 28.0, 38.0]:
		var equivalent: float = NoiseGain.gain_for_db(floor_db + AcousticWorld.THUNDER_OFFSET_DB)
		assert_almost_eq(RainAmbience.thunder_gain_for_floor(floor_db), equivalent, TOL,
			"piso %.0f: o trovão soa no limiar que impõe" % floor_db)


func _event(category: Enums.NoiseCategory, level_db: float, sound: StringName) -> NoiseEvent:
	return NoiseEvent.create(category, Vector3.ZERO, level_db, 1.0, &"world", sound)

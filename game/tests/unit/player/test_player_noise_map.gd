extends TestCase
## F3-004 (PlayerNoiseMap, funções puras): marcha e superfície dos passos, susto, impacto de objeto, e o contrato com o
## roteador de áudio (F3-003b): para cada marcha e superfície, o nível emitido faz o roteador escolher a marcha certa.
## Autor: Gameplay Engineer.

const TOL: float = 0.000001
const LEVELS: NoiseLevels = preload("res://content/data/acoustics/noise_levels.tres")
const LEVEL_SURFACES: Array[StringName] = [&"wood", &"carpet", &"tile", &"concrete"]
const GAITS: Array[StringName] = [&"crawl", &"crouch", &"slow", &"walk"]


func test_marcha_segue_postura_e_passo() -> void:
	assert_eq(PlayerNoiseMap.footstep_gait(Enums.Gait.WALK, Enums.Stance.CRAWL), &"crawl", "rastejando é crawl")
	assert_eq(PlayerNoiseMap.footstep_gait(Enums.Gait.SLOW, Enums.Stance.CROUCH), &"crouch", "agachado é crouch")
	assert_eq(PlayerNoiseMap.footstep_gait(Enums.Gait.SLOW, Enums.Stance.STAND), &"slow", "andando devagar é slow")
	assert_eq(PlayerNoiseMap.footstep_gait(Enums.Gait.WALK, Enums.Stance.STAND), &"walk", "andando é walk")


func test_superficie_do_nivel_e_do_som() -> void:
	assert_eq(PlayerNoiseMap.level_surface(&"wood"), &"wood_loose", "madeira do nível é madeira solta no ruído")
	assert_eq(PlayerNoiseMap.level_surface(&"default"), &"concrete", "sem metadado: concrete (0 dB)")
	assert_eq(PlayerNoiseMap.level_surface(&"carpet"), &"carpet", "tapete passa direto")
	assert_eq(PlayerNoiseMap.footstep_sound(&"wood"), &"footstep_wood", "som da madeira")
	assert_eq(PlayerNoiseMap.footstep_sound(&"default"), &"footstep_concrete", "som do padrão cai em concrete")


func test_intensidade_cresce_com_a_marcha_em_cada_superficie() -> void:
	for surface: StringName in LEVEL_SURFACES:
		var level: StringName = PlayerNoiseMap.level_surface(surface)
		var previous: float = -INF
		for gait: StringName in GAITS:
			var db: float = LEVELS.footstep_level(gait, level)
			assert_true(db > previous, "%s: %s (%.1f dB) acima da marcha anterior" % [surface, gait, db])
			previous = db
		assert_true(LEVELS.running_level(level) > previous, "%s: correr acima de andar" % surface)


func test_roteador_recupera_a_marcha_certa_para_cada_superficie() -> void:
	for surface: StringName in LEVEL_SURFACES:
		var level: StringName = PlayerNoiseMap.level_surface(surface)
		var sound_surface: String = String(PlayerNoiseMap.sound_surface(surface))
		for gait: StringName in GAITS:
			var db: float = LEVELS.footstep_level(gait, level)
			assert_eq(NoiseAudioRouter.gait_for_level(db, sound_surface), String(gait),
				"%s/%s: o roteador escolhe a marcha certa (%.1f dB)" % [surface, gait, db])


func test_corrida_vai_para_run_no_roteador() -> void:
	var event: NoiseEvent = NoiseEvent.create(Enums.NoiseCategory.RUNNING, Vector3.ZERO,
		LEVELS.running_level(&"wood_loose"), 0.0, &"player", &"footstep_wood")
	assert_eq(NoiseAudioRouter.choose_sound(event)["gait"], "run", "RUNNING é sempre corrida")


func test_susto_segue_a_formula_do_contrato() -> void:
	assert_almost_eq(PlayerNoiseMap.startle_amount(55.0), 10.0, TOL, "55 dB: piso de 10")
	assert_almost_eq(PlayerNoiseMap.startle_amount(65.0), 15.0, TOL, "65 dB: (65-55)/2 + 10")
	assert_almost_eq(PlayerNoiseMap.startle_amount(100.0), 25.0, TOL, "teto de 25")


func test_impacto_cresce_com_velocidade_e_tamanho() -> void:
	var range_db: Vector2 = LEVELS.object_impact_range_db
	assert_almost_eq(PlayerNoiseMap.impact_db(PlayerNoiseMap.IMPACT_MIN_SPEED_MS, &"light", range_db), 50.0, TOL, "leve, devagar: piso")
	assert_almost_eq(PlayerNoiseMap.impact_db(PlayerNoiseMap.IMPACT_MAX_SPEED_MS, &"heavy", range_db), 80.0, TOL, "pesado, rápido: teto")
	assert_almost_eq(PlayerNoiseMap.impact_db(PlayerNoiseMap.IMPACT_MAX_SPEED_MS, &"light", range_db), 65.0, TOL, "leve, rápido: meio da faixa")
	assert_almost_eq(PlayerNoiseMap.impact_db(PlayerNoiseMap.IMPACT_MIN_SPEED_MS, &"heavy", range_db), 65.0, TOL, "pesado, devagar: meio da faixa")
	assert_true(PlayerNoiseMap.impact_db(6.0, &"heavy", range_db) > PlayerNoiseMap.impact_db(3.0, &"heavy", range_db), "mais rápido, mais alto")


func test_impacto_abaixo_da_velocidade_minima_nao_e_audivel() -> void:
	assert_false(PlayerNoiseMap.impact_is_audible(0.3), "0,3 m/s: sem ruído")
	assert_true(PlayerNoiseMap.impact_is_audible(PlayerNoiseMap.IMPACT_MIN_SPEED_MS), "no mínimo: com ruído")

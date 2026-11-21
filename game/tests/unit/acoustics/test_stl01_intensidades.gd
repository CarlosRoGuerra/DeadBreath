extends TestCase
## STL-01 (TEST_PLAN §2.4; DATA_STRUCTURES §2.1): ordem das intensidades, com os modificadores de superfície.
## Valores lidos do Resource NoiseLevels (content/data/acoustics/noise_levels.tres, decisão D-03). Autor: AI Engineer
## (F3-001; migrado para NoiseLevels na F3-002).

const TOL: float = 0.0001
const LEVELS_PATH: String = "res://content/data/acoustics/noise_levels.tres"
const SURFACES: Array[StringName] = [&"concrete", &"tile", &"carpet", &"wood_loose"]


func _levels() -> NoiseLevels:
	return load(LEVELS_PATH) as NoiseLevels


func test_valores_base_de_data_2_1() -> void:
	var levels: NoiseLevels = _levels()
	assert_not_null(levels, "noise_levels.tres carrega como NoiseLevels")
	if levels == null:
		return
	assert_almost_eq(levels.footstep_level(&"crawl", &"concrete"), 18.0, TOL, "rastejando 18 dB")
	assert_almost_eq(levels.footstep_level(&"crouch", &"concrete"), 25.0, TOL, "agachado 25 dB")
	assert_almost_eq(levels.footstep_level(&"slow", &"concrete"), 32.0, TOL, "andando devagar 32 dB")
	assert_almost_eq(levels.footstep_level(&"walk", &"concrete"), 40.0, TOL, "andando 40 dB")
	assert_almost_eq(levels.running_level(&"concrete"), 60.0, TOL, "correndo 60 dB")
	assert_almost_eq(levels.cough_db, 65.0, TOL, "tosse 65 dB")
	assert_almost_eq(levels.fall_db, 80.0, TOL, "queda 80 dB")


func test_tres_de_producao_igual_aos_padroes_do_codigo() -> void:
	var loaded: NoiseLevels = _levels()
	var defaults: NoiseLevels = NoiseLevels.new()
	assert_not_null(loaded, "o .tres carrega")
	if loaded == null:
		return
	assert_almost_eq(loaded.footstep_crawl_db, defaults.footstep_crawl_db, TOL, "rastejar")
	assert_almost_eq(loaded.footstep_walk_db, defaults.footstep_walk_db, TOL, "andar")
	assert_almost_eq(loaded.running_db, defaults.running_db, TOL, "correr")
	assert_almost_eq(loaded.cough_db, defaults.cough_db, TOL, "tosse")
	assert_almost_eq(loaded.surface_carpet_db, defaults.surface_carpet_db, TOL, "tapete")
	assert_eq(loaded.object_impact_range_db, defaults.object_impact_range_db, "impacto de objeto")


func test_ordem_base_rastejar_agachado_andar_correr_tosse_queda() -> void:
	var levels: NoiseLevels = _levels()
	if levels == null:
		fail("noise_levels.tres ausente")
		return
	var crawl: float = levels.footstep_level(&"crawl", &"concrete")
	var crouch: float = levels.footstep_level(&"crouch", &"concrete")
	var walk: float = levels.footstep_level(&"walk", &"concrete")
	var run: float = levels.running_level(&"concrete")
	var cough: float = levels.cough_db
	var fall: float = levels.fall_db
	assert_true(crawl < crouch, "rastejar < agachado")
	assert_true(crouch < walk, "agachado < andar")
	assert_true(walk < run, "andar < correr")
	assert_true(run < cough, "correr < tosse")
	assert_true(cough < fall, "tosse < queda")


func test_modificadores_de_superficie_de_data_2_1() -> void:
	var levels: NoiseLevels = _levels()
	if levels == null:
		fail("noise_levels.tres ausente")
		return
	var walk_concrete: float = levels.footstep_level(&"walk", &"concrete")
	assert_almost_eq(levels.footstep_level(&"walk", &"wood_loose") - walk_concrete, 6.0, TOL, "madeira solta +6")
	assert_almost_eq(levels.footstep_level(&"walk", &"carpet") - walk_concrete, -8.0, TOL, "tapete −8")
	assert_almost_eq(levels.footstep_level(&"walk", &"tile") - walk_concrete, 3.0, TOL, "azulejo +3")
	assert_almost_eq(levels.footstep_level(&"walk", &"concrete") - walk_concrete, 0.0, TOL, "concreto 0")
	assert_almost_eq(levels.running_level(&"wood_loose") - levels.running_level(&"concrete"), 6.0, TOL,
		"a corrida recebe o mesmo modificador (F3-004)")


## Decisão D-01 do Director (abertura da F3, relatório F3-001): a cadeia completa "rastejar < agachado < andar <
## correr < tosse < queda" vale para os VALORES BASE (test_ordem_base_...). O modificador de superfície pode
## reordenar categorias de propósito: correr sobre madeira solta (66 dB) soa mais que a tosse (65 dB), porque o
## piso solto é perigoso (TEST_PLAN STL-01 atualizado). Em cada superfície, a ordem das marchas precisa valer.
func test_ordem_das_marchas_em_cada_superficie() -> void:
	var levels: NoiseLevels = _levels()
	if levels == null:
		fail("noise_levels.tres ausente")
		return
	for surface: StringName in SURFACES:
		var chain: Array[float] = [
			levels.footstep_level(&"crawl", surface),
			levels.footstep_level(&"crouch", surface),
			levels.footstep_level(&"walk", surface),
			levels.running_level(surface),
		]
		var labels: PackedStringArray = PackedStringArray(["rastejar", "agachado", "andar", "correr"])
		for index: int in range(chain.size() - 1):
			assert_true(chain[index] < chain[index + 1],
				"superfície %s: %s %.1f dB deveria ser menor que %s %.1f dB" % [
					surface, labels[index], chain[index], labels[index + 1], chain[index + 1]])
		assert_true(levels.cough_db < levels.fall_db, "tosse < queda")


func test_superficie_ou_marcha_desconhecida_e_recusada() -> void:
	var levels: NoiseLevels = _levels()
	if levels == null:
		fail("noise_levels.tres ausente")
		return
	expect_engine_error("desconhecida")
	assert_almost_eq(levels.footstep_level(&"crawl", &"lava"), 0.0, TOL, "superfície inexistente devolve 0")
	expect_engine_error("desconhecida")
	assert_almost_eq(levels.running_level(&"lava"), 0.0, TOL, "superfície inexistente devolve 0")

extends TestCase
## STL-01 (TEST_PLAN §2.4; DATA_STRUCTURES §2.1): ordem das intensidades, com os modificadores de superfície.
## Valores de AcousticLevels, que são os de §2.1. Autor: AI Engineer (F3-001).

const TOL: float = 0.0001
const SURFACES: Array[StringName] = [&"concrete", &"tile", &"carpet", &"wood_loose"]


func test_valores_base_de_data_2_1() -> void:
	assert_almost_eq(AcousticLevels.footstep_db(&"crawl", &"concrete"), 18.0, TOL, "rastejando 18 dB")
	assert_almost_eq(AcousticLevels.footstep_db(&"crouch", &"concrete"), 25.0, TOL, "agachado 25 dB")
	assert_almost_eq(AcousticLevels.footstep_db(&"slow", &"concrete"), 32.0, TOL, "andando devagar 32 dB")
	assert_almost_eq(AcousticLevels.footstep_db(&"walk", &"concrete"), 40.0, TOL, "andando 40 dB")
	assert_almost_eq(AcousticLevels.running_db(&"concrete"), 60.0, TOL, "correndo 60 dB")
	assert_almost_eq(AcousticLevels.COUGH_DB, 65.0, TOL, "tosse 65 dB")
	assert_almost_eq(AcousticLevels.FALL_DB, 80.0, TOL, "queda 80 dB")


func test_ordem_base_rastejar_agachado_andar_correr_tosse_queda() -> void:
	var crawl: float = AcousticLevels.footstep_db(&"crawl", &"concrete")
	var crouch: float = AcousticLevels.footstep_db(&"crouch", &"concrete")
	var walk: float = AcousticLevels.footstep_db(&"walk", &"concrete")
	var run: float = AcousticLevels.running_db(&"concrete")
	var cough: float = AcousticLevels.COUGH_DB
	var fall: float = AcousticLevels.FALL_DB
	assert_true(crawl < crouch, "rastejar < agachado")
	assert_true(crouch < walk, "agachado < andar")
	assert_true(walk < run, "andar < correr")
	assert_true(run < cough, "correr < tosse")
	assert_true(cough < fall, "tosse < queda")


func test_modificadores_de_superficie_de_data_2_1() -> void:
	var walk_concrete: float = AcousticLevels.footstep_db(&"walk", &"concrete")
	assert_almost_eq(AcousticLevels.footstep_db(&"walk", &"wood_loose") - walk_concrete, 6.0, TOL, "madeira solta +6")
	assert_almost_eq(AcousticLevels.footstep_db(&"walk", &"carpet") - walk_concrete, -8.0, TOL, "tapete −8")
	assert_almost_eq(AcousticLevels.footstep_db(&"walk", &"tile") - walk_concrete, 3.0, TOL, "azulejo +3")
	assert_almost_eq(AcousticLevels.footstep_db(&"walk", &"concrete") - walk_concrete, 0.0, TOL, "concreto 0")
	assert_almost_eq(AcousticLevels.running_db(&"wood_loose") - AcousticLevels.running_db(&"concrete"), 6.0, TOL,
		"a corrida recebe o mesmo modificador (F3-004)")


## Decisão D-01 do Director (abertura da F3, relatório F3-001): a cadeia completa "rastejar < agachado < andar <
## correr < tosse < queda" vale para os VALORES BASE (test_ordem_base_...). O modificador de superfície pode
## reordenar categorias de propósito: correr sobre madeira solta (66 dB) soa mais que a tosse (65 dB), porque o
## piso solto é perigoso (TEST_PLAN STL-01 atualizado). Em cada superfície, a ordem das marchas precisa valer.
func test_ordem_das_marchas_em_cada_superficie() -> void:
	for surface: StringName in SURFACES:
		var chain: Array[float] = [
			AcousticLevels.footstep_db(&"crawl", surface),
			AcousticLevels.footstep_db(&"crouch", surface),
			AcousticLevels.footstep_db(&"walk", surface),
			AcousticLevels.running_db(surface),
		]
		var labels: PackedStringArray = PackedStringArray(["rastejar", "agachado", "andar", "correr"])
		for index: int in range(chain.size() - 1):
			assert_true(chain[index] < chain[index + 1],
				"superfície %s: %s %.1f dB deveria ser menor que %s %.1f dB" % [
					surface, labels[index], chain[index], labels[index + 1], chain[index + 1]])
		assert_true(AcousticLevels.COUGH_DB < AcousticLevels.FALL_DB, "tosse < queda")


func test_superficie_ou_marcha_desconhecida_e_recusada() -> void:
	expect_engine_error("desconhecida")
	assert_almost_eq(AcousticLevels.footstep_db(&"crawl", &"lava"), 0.0, TOL, "superfície inexistente devolve 0")
	expect_engine_error("desconhecida")
	assert_almost_eq(AcousticLevels.running_db(&"lava"), 0.0, TOL, "superfície inexistente devolve 0")

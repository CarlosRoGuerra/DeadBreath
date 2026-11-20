extends TestCase
## MOT-02 (TEST_PLAN §2.1, MOT-INV-2): esforço por marcha e postura, com os valores de
## DATA_STRUCTURES §1.1 e tolerância de 0,01. Unit: função pura, sem cena nem física.
## Autor: Gameplay Engineer (F1-006).

const EXERTION_TOLERANCE: float = 0.01


func test_mot02_esforco_em_pe_por_marcha() -> void:
	assert_almost_eq(PlayerMotor.exertion_for(Enums.Gait.IDLE, Enums.Stance.STAND), 0.0, EXERTION_TOLERANCE, "parado")
	assert_almost_eq(PlayerMotor.exertion_for(Enums.Gait.SLOW, Enums.Stance.STAND), 0.1, EXERTION_TOLERANCE, "andar devagar")
	assert_almost_eq(PlayerMotor.exertion_for(Enums.Gait.WALK, Enums.Stance.STAND), 0.2, EXERTION_TOLERANCE, "andar")
	assert_almost_eq(PlayerMotor.exertion_for(Enums.Gait.SPRINT, Enums.Stance.STAND), 1.0, EXERTION_TOLERANCE, "correr")


func test_mot02_esforco_agachado_e_rastejando() -> void:
	assert_almost_eq(PlayerMotor.exertion_for(Enums.Gait.WALK, Enums.Stance.CROUCH), 0.15, EXERTION_TOLERANCE, "agachado andando")
	assert_almost_eq(PlayerMotor.exertion_for(Enums.Gait.WALK, Enums.Stance.CRAWL), 0.25, EXERTION_TOLERANCE, "rastejando")
	assert_almost_eq(PlayerMotor.exertion_for(Enums.Gait.IDLE, Enums.Stance.CROUCH), 0.0, EXERTION_TOLERANCE, "agachado parado")
	assert_almost_eq(PlayerMotor.exertion_for(Enums.Gait.IDLE, Enums.Stance.CRAWL), 0.0, EXERTION_TOLERANCE, "rastejando parado")


func test_mot02_limites_do_contrato_para_todas_as_combinacoes() -> void:
	# MOT-INV-2: agachado <= 0,15 e rastejando <= 0,25 em qualquer marcha; parado sempre 0.
	for gait: Enums.Gait in Enums.Gait.values():
		var crouch: float = PlayerMotor.exertion_for(gait, Enums.Stance.CROUCH)
		var crawl: float = PlayerMotor.exertion_for(gait, Enums.Stance.CRAWL)
		assert_true(crouch <= 0.15 + EXERTION_TOLERANCE, "agachado acima do limite para marcha %d: %f" % [gait, crouch])
		assert_true(crawl <= 0.25 + EXERTION_TOLERANCE, "rastejando acima do limite para marcha %d: %f" % [gait, crawl])
		assert_true(PlayerMotor.exertion_for(gait, Enums.Stance.STAND) >= 0.0, "esforço negativo para marcha %d" % gait)
	assert_almost_eq(PlayerMotor.exertion_for(Enums.Gait.IDLE, Enums.Stance.STAND), 0.0, 0.0, "parado é exatamente 0")

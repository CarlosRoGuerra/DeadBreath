extends TestCase
## F4-001 (DATA_STRUCTURES §3.2 e §3.3; COMPONENT_CONTRACTS §7.2): fórmula de visibilidade do VisionSensor, funções
## puras, sem física. Os números esperados são contas feitas à mão, no comentário de cada caso.
##   C1 AI-03 (DATA §3.3): em pé, iluminado, a 8 m, linha livre: 1 × (1 − 64/256) × 1 × 1 = 0,75.
##   C2 agachado, mesmo cenário: 0,75 × 0,6 = 0,45.
##   C3 rastejando, mesmo cenário: 0,75 × 0,35 = 0,2625.
##   C4 no escuro a 8 m: luz = 0,1 + 0,9 × 0 = 0,1; visibilidade = 0,75 × 0,1 = 0,075.
##   C5 no escuro a 1 m: distância = 1 − (1/16)² = 0,99609375; luz = max(0,1; 0,6) = 0,6; visibilidade = 0,59765625.
##   C6 iluminado a 1 m: luz = 1; visibilidade = 0,99609375.
##   C7 oclusão parcial, 2 de 3 pontos visíveis, 8 m, iluminado: 2/3 × 0,75 = 0,5.
##   C8 ocultação 0,5 sem outros fatores: 1 × 1 × 1 × 1 × (1 − 0,5) = 0,5.

const TOL: float = 0.000001


func test_c1_ai03_em_pe_iluminado_a_8_m_vale_0_75() -> void:
	assert_almost_eq(VisionSensor.distance_factor(8.0, 16.0), 0.75, TOL, "1 − (8/16)² = 0,75")
	assert_almost_eq(VisionSensor.light_factor(1.0, 8.0), 1.0, TOL, "iluminado: lerp(0,1; 1,0; 1) = 1")
	assert_almost_eq(VisionSensor.visibility_of(1.0, 0.75, 1.0, 1.0, 0.0), 0.75, TOL, "C1: 0,75")


func test_c2_c3_postura_multiplica() -> void:
	assert_almost_eq(VisionSensor.visibility_of(1.0, 0.75, 1.0, PerceivableTarget.STANCE_FACTOR_CROUCH, 0.0), 0.45, TOL,
		"C2 agachado: 0,75 × 0,6")
	assert_almost_eq(VisionSensor.visibility_of(1.0, 0.75, 1.0, PerceivableTarget.STANCE_FACTOR_CRAWL, 0.0), 0.2625, TOL,
		"C3 rastejando: 0,75 × 0,35")


func test_c4_escuro_a_8_m_usa_o_piso_de_luz() -> void:
	assert_almost_eq(VisionSensor.light_factor(0.0, 8.0), 0.1, TOL, "escuro, longe: piso 0,1")
	assert_almost_eq(VisionSensor.light_factor(0.5, 8.0), 0.55, TOL, "meia luz: 0,1 + 0,9 × 0,5 = 0,55")
	assert_almost_eq(VisionSensor.visibility_of(1.0, 0.75, 0.1, 1.0, 0.0), 0.075, TOL, "C4: 0,075")


func test_c5_c6_a_1_m_o_minimo_de_luz_e_0_6() -> void:
	assert_almost_eq(VisionSensor.distance_factor(1.0, 16.0), 0.99609375, TOL, "1 − 1/256")
	assert_almost_eq(VisionSensor.light_factor(0.0, 1.0), 0.6, TOL, "escuro a 1 m: max(0,1; 0,6) = 0,6")
	assert_almost_eq(VisionSensor.visibility_of(1.0, 0.99609375, 0.6, 1.0, 0.0), 0.59765625, TOL, "C5: 0,59765625")
	assert_almost_eq(VisionSensor.visibility_of(1.0, 0.99609375, 1.0, 1.0, 0.0), 0.99609375, TOL, "C6: iluminado a 1 m")


func test_piso_de_1_5_m_e_fronteira_do_minimo_de_luz() -> void:
	assert_almost_eq(VisionSensor.light_factor(0.0, 1.5), 0.6, TOL, "a 1,5 m ainda vale o mínimo de 0,6")
	assert_almost_eq(VisionSensor.light_factor(0.0, 1.6), 0.1, TOL, "a 1,6 m o mínimo sai")


func test_c7_oclusao_parcial_e_linear_na_fracao_de_linha_de_visao() -> void:
	assert_almost_eq(VisionSensor.visibility_of(2.0 / 3.0, 0.75, 1.0, 1.0, 0.0), 0.5, TOL, "C7: 2/3 × 0,75 = 0,5")
	assert_almost_eq(VisionSensor.visibility_of(0.0, 0.75, 1.0, 1.0, 0.0), 0.0, TOL, "linha de visão nula: 0")


func test_c8_ocultacao_reduz_pelo_complemento() -> void:
	assert_almost_eq(VisionSensor.visibility_of(1.0, 1.0, 1.0, 1.0, 0.5), 0.5, TOL, "C8: 1 − 0,5")
	assert_almost_eq(VisionSensor.visibility_of(1.0, 1.0, 1.0, 1.0, 1.0), 0.0, TOL, "proteção total: 0")


func test_alcance_zera_a_distancia() -> void:
	assert_almost_eq(VisionSensor.distance_factor(0.0, 16.0), 1.0, TOL, "no sensor: 1")
	assert_almost_eq(VisionSensor.distance_factor(16.0, 16.0), 0.0, TOL, "no alcance: 0")
	assert_almost_eq(VisionSensor.distance_factor(17.0, 16.0), 0.0, TOL, "além do alcance: 0")
	assert_almost_eq(VisionSensor.distance_factor(1.0, 0.0), 0.0, TOL, "alcance nulo: 0 (sem divisão por zero)")


func test_entradas_fora_da_faixa_sao_limitadas() -> void:
	assert_almost_eq(VisionSensor.visibility_of(1.5, 1.0, 1.0, 1.0, -1.0), 1.0, TOL, "los acima de 1 vira 1; ocultação negativa vira 0")
	assert_almost_eq(VisionSensor.light_factor(2.0, 8.0), 1.0, TOL, "exposição acima de 1 vira 1")
	assert_almost_eq(VisionSensor.light_factor(-1.0, 8.0), 0.1, TOL, "exposição negativa vira 0")


func test_visibilidade_fica_entre_zero_e_um_em_uma_grade() -> void:
	var values: Array[float] = [0.0, 0.25, 0.5, 1.0]
	var violations: int = 0
	var checked: int = 0
	for los: float in values:
		for distance: float in [0.0, 1.0, 4.0, 8.0, 12.0, 16.0]:
			for light: float in values:
				for stance: float in [0.35, 0.6, 1.0]:
					for concealment: float in values:
						var vis: float = VisionSensor.visibility_of(los, VisionSensor.distance_factor(distance, 16.0),
							VisionSensor.light_factor(light, distance), stance, concealment)
						checked += 1
						if vis < 0.0 or vis > 1.0:
							violations += 1
	assert_eq(violations, 0, "visibilidade sempre em 0..1 (%d combinações)" % checked)
	assert_true(checked > 0, "a grade foi percorrida")

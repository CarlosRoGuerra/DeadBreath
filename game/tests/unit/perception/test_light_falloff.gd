extends TestCase
## F3-005 (LightExposureProbe): escalas puras de atenuação radial, cone do spot e combinação com o piso ambiente.
## Sem cena. Autor: Gameplay Engineer.

const TOL: float = 0.000001


func test_alcance_zera_e_centro_vale_um() -> void:
	assert_almost_eq(LightExposureProbe.radial_factor(0.0, 8.0, 1.0), 1.0, TOL, "no centro: 1")
	assert_almost_eq(LightExposureProbe.radial_factor(8.0, 8.0, 1.0), 0.0, TOL, "no alcance: 0")
	assert_almost_eq(LightExposureProbe.radial_factor(9.0, 8.0, 1.0), 0.0, TOL, "além do alcance: 0")
	assert_almost_eq(LightExposureProbe.radial_factor(4.0, 8.0, 1.0), 0.5, TOL, "linear: metade a meia distância")


func test_atenuacao_maior_escurece_as_bordas() -> void:
	assert_almost_eq(LightExposureProbe.radial_factor(4.0, 8.0, 2.0), 0.25, TOL, "expoente 2: 0,5 ao quadrado")
	assert_true(LightExposureProbe.radial_factor(4.0, 8.0, 2.0) < LightExposureProbe.radial_factor(4.0, 8.0, 1.0), "mais atenuação, menos luz")


func test_radial_decresce_com_a_distancia() -> void:
	var previous: float = 2.0
	for step: int in 9:
		var distance: float = float(step)
		var value: float = LightExposureProbe.radial_factor(distance, 8.0, 1.0)
		assert_true(value <= previous, "monotônico em d=%.1f" % distance)
		previous = value


func test_alcance_invalido_nao_ilumina() -> void:
	assert_almost_eq(LightExposureProbe.radial_factor(0.0, 0.0, 1.0), 0.0, TOL, "alcance 0: sem luz")
	assert_almost_eq(LightExposureProbe.radial_factor(0.5, -2.0, 1.0), 0.0, TOL, "alcance negativo: sem luz")


func test_cone_eixo_vale_um_e_borda_zero() -> void:
	assert_almost_eq(LightExposureProbe.cone_factor(0.0, 30.0, 1.0), 1.0, TOL, "no eixo: 1")
	assert_almost_eq(LightExposureProbe.cone_factor(30.0, 30.0, 1.0), 0.0, TOL, "na borda: 0")
	assert_almost_eq(LightExposureProbe.cone_factor(45.0, 30.0, 1.0), 0.0, TOL, "fora do cone: 0")


func test_cone_dentro_e_entre_zero_e_um() -> void:
	var inside: float = LightExposureProbe.cone_factor(15.0, 30.0, 1.0)
	assert_true(inside > 0.0 and inside < 1.0, "dentro do cone, entre 0 e 1")
	assert_true(inside > LightExposureProbe.cone_factor(25.0, 30.0, 1.0), "mais perto do eixo, mais luz")


func test_combinacao_limitada_e_com_piso_ambiente() -> void:
	assert_almost_eq(LightExposureProbe.combine(3.0, 0.0), 1.0, TOL, "soma acima de 1 satura em 1")
	assert_almost_eq(LightExposureProbe.combine(0.0, 0.2), 0.2, TOL, "sem luz: piso ambiente")
	assert_almost_eq(LightExposureProbe.combine(0.1, 0.2), 0.2, TOL, "piso prevalece sobre luz fraca")
	assert_almost_eq(LightExposureProbe.combine(-1.0, 0.0), 0.0, TOL, "soma negativa: 0")

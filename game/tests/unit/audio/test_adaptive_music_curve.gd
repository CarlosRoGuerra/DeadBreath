extends TestCase
## F4-006a (AdaptiveMusic, curva do crossfade documentada no cabeçalho de presentation/audio/adaptive_music.gd): pesos e
## amplitudes por level e perseguição, potência constante, limites do level e volume em dB. Funções puras, sem nó.
## Autor: Audio Engineer (F4-006a).

const TOL: float = 0.0001


func test_sem_ameaca_so_a_calma_toca() -> void:
	var w: Vector3 = AdaptiveMusic.weights_for(0.0, false)
	assert_almost_eq(w.x, 1.0, TOL, "calma 1 sem ameaça")
	assert_almost_eq(w.y, 0.0, TOL, "tensão 0 sem ameaça")
	assert_almost_eq(w.z, 0.0, TOL, "perseguição 0 sem perseguição")
	assert_almost_eq(AdaptiveMusic.gains_for(0.0, false).x, 1.0, TOL, "amplitude da calma = 1")


func test_meia_ameaca_divide_calma_e_tensao_a_meia_potencia() -> void:
	var w: Vector3 = AdaptiveMusic.weights_for(0.5, false)
	assert_almost_eq(w.x, 0.5, TOL, "calma 0,5 em level 0,5")
	assert_almost_eq(w.y, 0.5, TOL, "tensão 0,5 em level 0,5")
	assert_almost_eq(w.z, 0.0, TOL, "sem perseguição")
	var g: Vector3 = AdaptiveMusic.gains_for(0.5, false)
	assert_almost_eq(g.x, sqrt(0.5), TOL, "amplitude da calma = raiz de 0,5")
	assert_almost_eq(g.y, sqrt(0.5), TOL, "amplitude da tensão = raiz de 0,5")


func test_ameaca_maxima_e_so_tensao() -> void:
	var w: Vector3 = AdaptiveMusic.weights_for(1.0, false)
	assert_almost_eq(w.x, 0.0, TOL, "calma 0 com level 1")
	assert_almost_eq(w.y, 1.0, TOL, "tensão 1 com level 1")
	assert_almost_eq(w.z, 0.0, TOL, "sem perseguição")


func test_perseguicao_zera_calma_e_tensao_em_qualquer_level() -> void:
	for level: float in [0.0, 0.5, 1.0]:
		var w: Vector3 = AdaptiveMusic.weights_for(level, true)
		assert_almost_eq(w.x, 0.0, TOL, "calma 0 com perseguição, level %.1f" % level)
		assert_almost_eq(w.y, 0.0, TOL, "tensão 0 com perseguição, level %.1f" % level)
		assert_almost_eq(w.z, 1.0, TOL, "perseguição 1, level %.1f" % level)


func test_potencia_constante_em_todo_ponto() -> void:
	for chase: bool in [false, true]:
		for step: int in range(11):
			var level: float = float(step) / 10.0
			var g: Vector3 = AdaptiveMusic.gains_for(level, chase)
			var power: float = g.x * g.x + g.y * g.y + g.z * g.z
			assert_almost_eq(power, 1.0, TOL, "soma das potências = 1 (level %.1f, perseguição %s)" % [level, str(chase)])


func test_calma_cai_e_tensao_sobe_com_a_ameaca() -> void:
	var last_calm: float = 2.0
	var last_tension: float = -1.0
	for step: int in range(11):
		var w: Vector3 = AdaptiveMusic.weights_for(float(step) / 10.0, false)
		assert_true(w.x <= last_calm + TOL, "calma não sobe com a ameaça (passo %d)" % step)
		assert_true(w.y >= last_tension - TOL, "tensão não cai com a ameaça (passo %d)" % step)
		last_calm = w.x
		last_tension = w.y


func test_level_fora_da_faixa_e_limitado() -> void:
	assert_almost_eq(AdaptiveMusic.weights_for(-1.0, false).x, 1.0, TOL, "level −1 vale 0: só calma")
	assert_almost_eq(AdaptiveMusic.weights_for(3.0, false).y, 1.0, TOL, "level 3 vale 1: tensão cheia")


func test_volume_em_db_da_amplitude() -> void:
	assert_almost_eq(AdaptiveMusic.db_for_gain(1.0), 0.0, TOL, "amplitude 1 = 0 dB")
	assert_almost_eq(AdaptiveMusic.db_for_gain(0.5), -6.0206, 0.001, "amplitude 0,5 = −6,02 dB")
	assert_almost_eq(AdaptiveMusic.db_for_gain(0.0), AdaptiveMusic.MIN_DB, TOL, "zero = piso")

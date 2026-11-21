extends TestCase
## F3-008 (unit): raio do anel de ruído pela fórmula de DATA_STRUCTURES §2.2 em campo livre (sem paredes), função pura
## AcousticDebugView.ring_radius_for. Os valores esperados são contas à mão, no comentário de ring_radius_for:
##   margem 0,05 dB → 0,5 m; margem 20 dB → 9,01 m; margem 30 dB → 23,99 m (tosse de 65 dB com limiar 35: "≈ 24 m");
##   margem 40 dB → 53,82 m. Também: abaixo ou igual ao limiar, raio 0; o raio cresce com a intensidade; cor por
## categoria distinta; cor da sala pelo piso.

const RADIUS_TOL_M: float = 0.02


func _config() -> AcousticConfig:
	return AcousticConfig.new()


func test_raio_pela_formula_em_quatro_casos_calculados_a_mao() -> void:
	# Config padrão: min_distance 1 m, 0,1 dB/m. Perda(d) = 20·log10(max(d;1)) + 0,1·d.
	# Margem 0,05 dB: d ≤ 1 m tem perda 0,1·d, então 0,1·d = 0,05 → d = 0,5 m.
	assert_almost_eq(AcousticDebugView.ring_radius_for(0.05, 0.0, _config()), 0.5, RADIUS_TOL_M, "margem 0,05 dB → 0,5 m")
	# Margem 20 dB: 20·log10(d) + 0,1·d = 20. d = 9: 19,085 + 0,9 = 19,985; d = 9,014: 20,000 → 9,01 m.
	assert_almost_eq(AcousticDebugView.ring_radius_for(20.0, 0.0, _config()), 9.01, RADIUS_TOL_M, "margem 20 dB → 9,01 m")
	# Margem 30 dB (tosse 65 dB, limiar 35): d = 24: 27,604 + 2,4 = 30,004 → 23,99 m (DATA §2.3, "≈ 24 m").
	assert_almost_eq(AcousticDebugView.ring_radius_for(65.0, 35.0, _config()), 23.99, RADIUS_TOL_M, "tosse 65 dB, limiar 35 → ≈ 24 m")
	# Margem 40 dB: d = 53,82: 34,618 + 5,382 = 40,000 → 53,82 m.
	assert_almost_eq(AcousticDebugView.ring_radius_for(40.0, 0.0, _config()), 53.82, RADIUS_TOL_M, "margem 40 dB → 53,82 m")


func test_abaixo_ou_igual_ao_limiar_o_raio_e_zero() -> void:
	assert_eq(AcousticDebugView.ring_radius_for(30.0, 40.0, _config()), 0.0, "abaixo do limiar: raio 0")
	assert_eq(AcousticDebugView.ring_radius_for(40.0, 40.0, _config()), 0.0, "igual ao limiar: raio 0 (margem zero não audível)")


func test_raio_cresce_com_a_intensidade() -> void:
	var quiet: float = AcousticDebugView.ring_radius_for(30.0, 20.0, _config())
	var medium: float = AcousticDebugView.ring_radius_for(40.0, 20.0, _config())
	var loud: float = AcousticDebugView.ring_radius_for(50.0, 20.0, _config())
	assert_true(quiet > 0.0, "30 dB com limiar 20 deixa um anel")
	assert_true(quiet < medium and medium < loud, "mais intensidade, raio maior: %f < %f < %f" % [quiet, medium, loud])


func test_raio_cresce_quando_o_limiar_cai() -> void:
	var high_threshold: float = AcousticDebugView.ring_radius_for(40.0, 30.0, _config())
	var low_threshold: float = AcousticDebugView.ring_radius_for(40.0, 12.0, _config())
	assert_true(low_threshold > high_threshold, "limiar mais baixo (ouvinte no porão), raio maior")


func test_cada_categoria_tem_cor_distinta() -> void:
	var seen: Dictionary = {}
	var count: int = Enums.NoiseCategory.size()
	for index: int in range(count):
		var category: Enums.NoiseCategory = index as Enums.NoiseCategory
		seen[AcousticDebugView.ring_color_for(category).to_html()] = true
	assert_eq(count, 11, "o enum tem 11 categorias")
	assert_eq(seen.size(), count, "as 11 categorias têm cores diferentes")


func test_cor_da_sala_vai_do_silencio_ao_exterior() -> void:
	var quiet: Color = AcousticDebugView.room_color_for_floor(12.0)
	var outside: Color = AcousticDebugView.room_color_for_floor(38.0)
	# Cor de ponto flutuante: compara com tolerância (is_equal_approx), não com ==.
	assert_true(quiet.is_equal_approx(AcousticDebugView.ROOM_QUIET_COLOR), "piso de 12 dB: cor do silêncio")
	assert_true(outside.is_equal_approx(AcousticDebugView.ROOM_LOUD_COLOR), "piso de 38 dB: cor do exterior")
	assert_true(AcousticDebugView.room_color_for_floor(99.0).is_equal_approx(AcousticDebugView.ROOM_LOUD_COLOR),
		"piso acima do limite: satura")


func test_cores_de_portal_sao_diferentes() -> void:
	assert_ne(AcousticDebugView.portal_color_for(true), AcousticDebugView.portal_color_for(false), "aberto e fechado têm cores diferentes")
	assert_eq(AcousticDebugView.portal_color_for(true), AcousticDebugView.OPEN_COLOR, "aberto = verde")
	assert_eq(AcousticDebugView.portal_color_for(false), AcousticDebugView.CLOSED_COLOR, "fechado = vermelho")

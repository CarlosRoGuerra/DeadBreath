extends TestCase
## F2-007 (ACC-01, ACC-02; TEST_PLAN §2.8): escalas puras dos efeitos de câmera. Com motion_reduction e tremor_reduction
## em 1, a amplitude é zero; em 0, é a normal. effects_intensity escala tudo linearmente. Autor: Gameplay Engineer.

const TOL: float = 0.000001


func test_acc01_reducao_total_zera_balanco_tremor_e_solavanco() -> void:
	assert_almost_eq(CameraEffects.sway_amplitude_m(1.0, 1.0, 1.0), 0.0, TOL, "balanço com redução de movimento 1")
	assert_almost_eq(CameraEffects.tremor_amplitude_m(1.0, 1.0, 1.0), 0.0, TOL, "tremor com redução de tremor 1")
	assert_almost_eq(CameraEffects.jolt_amplitude_deg(1.0, 1.0), 0.0, TOL, "solavanco com redução de movimento 1")


func test_acc01_sem_reducao_amplitude_normal() -> void:
	assert_almost_eq(CameraEffects.sway_amplitude_m(0.0, 0.0, 1.0), CameraEffects.BASE_SWAY_M, TOL, "balanço em repouso")
	assert_almost_eq(CameraEffects.sway_amplitude_m(1.0, 0.0, 1.0), CameraEffects.BASE_SWAY_M + CameraEffects.SWAY_PER_SEVERITY_M, TOL, "balanço na crise")
	assert_almost_eq(CameraEffects.tremor_amplitude_m(1.0, 0.0, 1.0), CameraEffects.TREMOR_MAX_M, TOL, "tremor no máximo")
	assert_almost_eq(CameraEffects.jolt_amplitude_deg(0.0, 1.0), CameraEffects.JOLT_DEG, TOL, "solavanco normal")


func test_acc02_intensidade_escala_linearmente() -> void:
	for intensity: float in [0.0, 0.25, 0.5, 0.75, 1.0]:
		assert_almost_eq(CameraEffects.sway_amplitude_m(0.8, 0.0, intensity), intensity * CameraEffects.sway_amplitude_m(0.8, 0.0, 1.0), TOL, "balanço com intensidade %.2f" % intensity)
		assert_almost_eq(CameraEffects.tremor_amplitude_m(0.6, 0.0, intensity), intensity * CameraEffects.tremor_amplitude_m(0.6, 0.0, 1.0), TOL, "tremor com intensidade %.2f" % intensity)
		assert_almost_eq(CameraEffects.jolt_amplitude_deg(0.0, intensity), intensity * CameraEffects.jolt_amplitude_deg(0.0, 1.0), TOL, "solavanco com intensidade %.2f" % intensity)
		assert_almost_eq(CameraEffects.vignette_alpha(0.9, intensity), intensity * CameraEffects.vignette_alpha(0.9, 1.0), TOL, "vinheta com intensidade %.2f" % intensity)


func test_vinheta_so_na_crise() -> void:
	assert_almost_eq(CameraEffects.vignette_alpha(0.5, 1.0), 0.0, TOL, "abaixo de 0,6 não escurece")
	assert_true(CameraEffects.vignette_alpha(1.0, 1.0) <= CameraEffects.VIGNETTE_MAX_ALPHA + TOL, "limite do alpha")
	assert_true(CameraEffects.vignette_alpha(1.0, 1.0) > 0.0, "na crise escurece")


func test_frequencia_do_balanco_em_hz() -> void:
	assert_almost_eq(CameraEffects.breath_frequency_hz(60.0), 1.0, TOL, "60 respirações por minuto = 1 Hz")
	assert_almost_eq(CameraEffects.breath_frequency_hz(14.0), 14.0 / 60.0, TOL, "frequência de repouso")

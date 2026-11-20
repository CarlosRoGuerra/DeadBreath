extends TestCase
## F2-006b (DATA_STRUCTURES §1.4, §2.1, §2.4): BreathParams é função pura do PhysiologySnapshot.
## Cobre período, intensidade, chiado, escolha da família pelo período e o encaixe chain_timing
## (pitch dentro de 1/1.15..1.15, expiração sem corte, silêncio ou sobra no ciclo).
## Autor: Audio Engineer (F2-006b).

const TOL: float = 0.0001


func _snap(rate: float, wheeze: float = 0.0, state: Enums.RespiratoryState = Enums.RespiratoryState.NORMAL) -> PhysiologySnapshot:
	var snapshot: PhysiologySnapshot = PhysiologySnapshot.new()
	snapshot.breathing_rate = rate
	snapshot.wheezing_intensity = wheeze
	snapshot.respiratory_state = state
	return snapshot


func test_rest_rate_gives_calm_period_and_20_db() -> void:
	var params: BreathParams = BreathParams.from_snapshot(_snap(14.0))
	assert_almost_eq(params.period_s, 60.0 / 14.0, TOL, "período em repouso")
	assert_almost_eq(params.intensity_db, 20.0, TOL, "respiração calma = 20 dB (DATA §2.4)")
	assert_eq(params.category, Enums.NoiseCategory.BREATHING, "sem chiado: BREATHING")
	assert_eq(params.sound_id, &"breath_calm", "repouso usa a família calma")
	assert_false(params.wheeze_layer, "sem camada de chiado")


func test_max_rate_gives_fast_period_and_35_db() -> void:
	var params: BreathParams = BreathParams.from_snapshot(_snap(40.0))
	assert_almost_eq(params.period_s, 1.5, TOL, "40 rpm = 1,5 s")
	assert_almost_eq(params.intensity_db, 35.0, TOL, "ofegante máxima = 35 dB")
	assert_eq(params.sound_id, &"breath_fast", "1,5 s só cabe a família rápida")


func test_intensity_is_linear_in_rate() -> void:
	var params: BreathParams = BreathParams.from_snapshot(_snap(27.0))
	assert_almost_eq(params.intensity_db, 20.0 + 15.0 * (13.0 / 26.0), TOL, "lerp(20, 35, (rate-14)/26)")


func test_rate_is_clamped_to_contract_range() -> void:
	var low: BreathParams = BreathParams.from_snapshot(_snap(2.0))
	var high: BreathParams = BreathParams.from_snapshot(_snap(90.0))
	assert_almost_eq(low.period_s, 60.0 / 14.0, TOL, "abaixo de 14 rpm usa 14")
	assert_almost_eq(high.period_s, 1.5, TOL, "acima de 40 rpm usa 40")


func test_wheeze_threshold_is_strictly_above_0_1() -> void:
	var at_threshold: BreathParams = BreathParams.from_snapshot(_snap(14.0, 0.1))
	assert_eq(at_threshold.category, Enums.NoiseCategory.BREATHING, "0,1 exato ainda não é chiado (DATA §2.4: > 0,1)")
	var above: BreathParams = BreathParams.from_snapshot(_snap(14.0, 0.2))
	assert_eq(above.category, Enums.NoiseCategory.WHEEZING, "acima de 0,1 é WHEEZING")
	assert_true(above.wheeze_layer, "chiado marca a camada")
	assert_almost_eq(above.intensity_db, 30.0 + 12.0 * 0.2, TOL, "lerp(30, 42, wheeze) quando maior que a base")


func test_full_wheeze_is_42_db() -> void:
	var params: BreathParams = BreathParams.from_snapshot(_snap(14.0, 1.0))
	assert_almost_eq(params.intensity_db, 42.0, TOL, "chiado forte = 42 dB (DATA §2.1 / §2.4)")


func test_wheeze_keeps_breath_family_not_wheeze_id() -> void:
	var params: BreathParams = BreathParams.from_snapshot(_snap(25.0, 0.8, Enums.RespiratoryState.LABORED))
	assert_ne(params.sound_id, &"wheeze", "o chiado é camada; o corpo continua na família (decisão F2-006b)")
	assert_eq(params.sound_id, &"breath_labored", "estado LABORED com família ofegante cabendo")


func test_labored_state_prefers_labored_when_it_fits() -> void:
	# 25 rpm = 2,4 s; ofegante (2,2 s) cabe em 1,15 x 2,4 = 2,76 s; calma (4,2 s) não.
	var params: BreathParams = BreathParams.from_snapshot(_snap(25.0, 0.0, Enums.RespiratoryState.SYMPTOMATIC))
	assert_eq(params.sound_id, &"breath_labored", "SYMPTOMATIC prefere a família ofegante quando cabe")


func test_family_follows_period_when_state_does_not_fit() -> void:
	# 36 rpm = 1,67 s: só a rápida cabe (1,7 <= 1,92). Estado LABORED não força a ofegante aqui.
	var params: BreathParams = BreathParams.from_snapshot(_snap(36.0, 0.0, Enums.RespiratoryState.LABORED))
	assert_eq(params.sound_id, &"breath_fast", "ofegante não cabe em 1,67 s, então a rápida")


func test_every_period_in_range_maps_to_a_known_family() -> void:
	var seen: Dictionary = {}
	var rate: float = 14.0
	while rate <= 40.0:
		var params: BreathParams = BreathParams.from_snapshot(_snap(rate))
		assert_true(BreathParams.FAMILY_TABLE.has(params.sound_id), "rate %.1f: família desconhecida" % rate)
		seen[params.sound_id] = true
		rate += 0.5
	assert_true(seen.has(&"breath_calm") and seen.has(&"breath_labored") and seen.has(&"breath_fast"),
		"as três famílias aparecem na faixa 14 a 40 rpm")


func test_chain_timing_never_cuts_exhale_and_fits_period() -> void:
	var period: float = 1.5
	while period <= 4.3:
		for family: StringName in BreathParams.FAMILY_ORDER:
			if BreathParams.cycle_nominal_s(family) > period * BreathParams.FIT_MAX_RATIO:
				continue
			var timing: Dictionary = BreathParams.chain_timing(family, period)
			var fam: Dictionary = BreathParams.FAMILY_TABLE[family]
			var pitch: float = timing["pitch_scale"]
			assert_true(pitch >= BreathParams.PITCH_MIN - TOL and pitch <= BreathParams.PITCH_MAX + TOL,
				"%s em %.2f s: pitch %.3f fora de 1/1.15..1.15" % [family, period, pitch])
			assert_almost_eq(float(timing["exhale_s"]), float(fam["exhale_s"]) / pitch, TOL,
				"%s em %.2f s: expiração tocada = nominal / pitch (sem corte)" % [family, period])
			assert_almost_eq(float(timing["overlap_s"]), 0.0, TOL, "%s em %.2f s: cabe sem sobrepor o próximo ciclo" % [family, period])
			assert_almost_eq(float(timing["inhale_s"]) + float(timing["exhale_s"]) + float(timing["silence_s"]), period, TOL,
				"%s em %.2f s: inspiração + expiração + silêncio = período" % [family, period])
		period += 0.05


func test_chain_timing_unknown_or_bad_period_is_empty() -> void:
	assert_true(BreathParams.chain_timing(&"gasp", 2.0).is_empty(), "gasp não é família de respiração")
	assert_true(BreathParams.chain_timing(&"breath_calm", 0.0).is_empty(), "período zero não tem encaixe")

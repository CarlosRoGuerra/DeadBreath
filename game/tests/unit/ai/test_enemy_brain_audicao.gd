extends TestCase
## Suspeita por audição (DATA_STRUCTURES §2.3, §3.3; F4-003, decisão D4-08). HeardNoise traz effective_threshold_db.
## Fórmula: min(cap; per_db · (perceived − limiar efetivo)) por evento. Ruído abaixo do limiar não conta.
## Novo ruído com suspeita ≥ 0,5 leva a INVESTIGATE (PATROL, SUSPICIOUS, SEARCH, RETURN).

const DT: float = 1.0 / 60.0
const NOISE_AT: Vector3 = Vector3(8.0, 0.0, 0.0)


func _noise(perceived_db: float, threshold_db: float, at: Vector3, time_s: float) -> HeardNoise:
	var noise: HeardNoise = HeardNoise.new()
	noise.perceived_db = perceived_db
	noise.effective_threshold_db = threshold_db
	noise.estimated_position = at
	noise.confidence = HeardNoise.confidence_for(perceived_db, threshold_db)
	noise.timestamp = time_s
	return noise


func _heard_batch(noises: Array[HeardNoise]) -> PerceptBatch:
	var batch: PerceptBatch = PerceptBatch.new()
	for noise: HeardNoise in noises:
		batch.heard.append(noise)
	return batch


func test_ai02_formula_30_db_com_limiar_15_da_mais_0_6() -> void:
	# Observer: 0,04 · (30 − 15) = 0,6. Cap por evento 0,6. min(0,6; 0,6) = 0,6.
	var profile: AIProfile = AIProfile.new()
	assert_almost_eq(EnemyBrain.hearing_suspicion_gain(30.0, 15.0, profile), 0.6, 0.000001, "AI-02: +0,6")


func test_formula_cap_por_evento() -> void:
	# 40 dB com limiar 15: 0,04 · 25 = 1,0 → cap 0,6.
	var profile: AIProfile = AIProfile.new()
	assert_almost_eq(EnemyBrain.hearing_suspicion_gain(40.0, 15.0, profile), 0.6, 0.000001, "cap do Observer")


func test_formula_agressivo_usa_o_proprio_coeficiente() -> void:
	# Aggressive: 0,02 · (30 − 24) = 0,12 (< cap 0,4) → 0,12.
	var profile: AIProfile = load("res://content/data/ai/aggressive.tres") as AIProfile
	assert_almost_eq(EnemyBrain.hearing_suspicion_gain(30.0, 24.0, profile), 0.12, 0.000001, "coeficiente 0,02")


func test_formula_abaixo_do_limiar_da_zero() -> void:
	var profile: AIProfile = AIProfile.new()
	assert_almost_eq(EnemyBrain.hearing_suspicion_gain(10.0, 15.0, profile), 0.0, 0.000001, "excesso negativo vale 0")


func test_ai02_ponta_a_ponta_30_db_vai_a_pista_chega_e_procura_apos_3_s() -> void:
	# Ruído de 30 dB, limiar efetivo 15, em (8,0,0). Suspeita += 0,6 (cap 0,6). Num só tick: PATROL → INVESTIGATE.
	# Destino = posição estimada. O inimigo anda a 1,8 m/s (8 m → ≈ 4,4 s) e chega a ≤ 2 m (AI-02).
	# Depois de chegar (≤ 1 m), 3 s sem visão → SEARCH.
	var world: FakeBrainWorld = AITestSupport.world_with_route()
	var brain: EnemyBrain = EnemyBrain.new(AIProfile.new(), AITestSupport.rng(2))
	var noises: Array[HeardNoise] = [_noise(30.0, 15.0, NOISE_AT, 0.0)]
	var first: EnemyIntent = brain.tick(DT, _heard_batch(noises), world)
	assert_almost_eq(brain.suspicion, 0.6, 0.000001, "suspeita +0,6")
	assert_eq(brain.state, Enums.EnemyState.INVESTIGATE, "novo ruído com suspeita ≥ 0,5: INVESTIGATE")
	assert_eq(first.move_target, NOISE_AT, "destino é a posição estimada")
	assert_eq(first.voice_line, &"voice_investigate", "fala de entrada em INVESTIGATE")
	assert_almost_eq(first.move_speed, 1.8, 0.000001, "velocidade de investigação")

	var within_2_m: int = -1
	var arrived: int = -1
	var search: int = -1
	for tick_index: int in range(1, 1200):
		var intent: EnemyIntent = brain.tick(DT, AITestSupport.empty_batch(), world)
		world.position = AITestSupport.move_towards(world.position, intent.move_target, intent.move_speed, DT)
		var distance: float = AITestSupport.horizontal_distance(world.position, NOISE_AT)
		if within_2_m < 0 and distance <= 2.0:
			within_2_m = tick_index
		if arrived < 0 and distance <= 1.0:
			arrived = tick_index
		if brain.state == Enums.EnemyState.SEARCH:
			search = tick_index
			break
	assert_true(within_2_m > 0, "chegou a ≤ 2 m da posição estimada (AI-02)")
	assert_true(arrived > 0, "chegou a ≤ 1 m da pista")
	assert_true(search > 0, "passou a SEARCH")
	if arrived > 0 and search > 0:
		assert_true(absf(float(search - arrived) * DT - 3.0) <= 2.0 * DT + 0.000001,
			"SEARCH ≈ 3 s depois de chegar (medido %.3f s)" % (float(search - arrived) * DT))


func test_ruido_abaixo_do_limiar_nao_soma() -> void:
	# 14 dB com limiar 15: não é audível. Suspeita fica em 0, PATROL, sem fala.
	var world: FakeBrainWorld = AITestSupport.world_with_route()
	var brain: EnemyBrain = EnemyBrain.new(AIProfile.new(), AITestSupport.rng(1))
	var noises: Array[HeardNoise] = [_noise(14.0, 15.0, NOISE_AT, 0.0)]
	var intent: EnemyIntent = brain.tick(0.1, _heard_batch(noises), world)
	assert_almost_eq(brain.suspicion, 0.0, 0.000001, "abaixo do limiar não soma")
	assert_eq(brain.state, Enums.EnemyState.PATROL, "segue em PATROL")
	assert_eq(intent.voice_line, &"", "sem fala")


func test_teto_por_evento_vale_para_cada_ruido() -> void:
	# Dois ruídos de 40 dB, limiar 15: cada um vale min(0,6; 1,0) = 0,6. Soma 1,2 (não 2,0).
	var world: FakeBrainWorld = AITestSupport.world_with_route()
	var brain: EnemyBrain = EnemyBrain.new(AIProfile.new(), AITestSupport.rng(1))
	var noises: Array[HeardNoise] = [_noise(40.0, 15.0, NOISE_AT, 0.0), _noise(40.0, 15.0, NOISE_AT, 0.0)]
	brain.tick(0.1, _heard_batch(noises), world)
	assert_almost_eq(brain.suspicion, 1.2, 0.000001, "dois eventos, cada um com teto 0,6")


func test_ruido_que_leva_a_suspeita_entre_025_e_05_fica_em_suspicious() -> void:
	# 24 dB, limiar 15: 0,04 · 9 = 0,36. Entre 0,25 e 0,5: SUSPICIOUS, não INVESTIGATE. Fala voice_suspicious.
	var world: FakeBrainWorld = AITestSupport.world_with_route()
	var brain: EnemyBrain = EnemyBrain.new(AIProfile.new(), AITestSupport.rng(1))
	var noises: Array[HeardNoise] = [_noise(24.0, 15.0, NOISE_AT, 0.0)]
	var intent: EnemyIntent = brain.tick(0.1, _heard_batch(noises), world)
	assert_almost_eq(brain.suspicion, 0.36, 0.000001, "suspeita 0,36")
	assert_eq(brain.state, Enums.EnemyState.SUSPICIOUS, "0,36 leva a SUSPICIOUS")
	assert_eq(intent.voice_line, &"voice_suspicious", "fala de SUSPICIOUS")

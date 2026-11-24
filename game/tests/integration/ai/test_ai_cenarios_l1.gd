extends TestCase
## Cenários L1 de AI-03, AI-04 e AI-05 (TEST_PLAN §2.5; F4-003). Um mundo falso e um passo de movimento simples
## fazem o papel do NavigationAgent3D: o inimigo anda até move_target na velocidade do intent.
## Passo de 1/60 s (--fixed-fps 60). O jogador não entra no PerceptBatch além do percept de visão que o teste desenha.

const DT: float = 1.0 / 60.0
const PLAYER_AT: Vector3 = Vector3(8.0, 0.0, 0.0)


func _walk(world: FakeBrainWorld, intent: EnemyIntent) -> void:
	world.position = AITestSupport.move_towards(world.position, intent.move_target, intent.move_speed, DT)


func test_ai03_observer_chega_a_chase_em_0_8_s_com_visibilidade_0_75() -> void:
	# AI-03 em L1. Confirmação += 0,75 · dt por tick. 0,6 / 0,75 = 0,8 s = 48 ticks de 1/60 s.
	# Limite do teste: 1,5 s. Tolerância: um tick (1/60 s), por arredondamento.
	var world: FakeBrainWorld = AITestSupport.world_with_route()
	var brain: EnemyBrain = EnemyBrain.new(AIProfile.new(), AITestSupport.rng(3))
	var chase_tick: int = -1
	for tick_index: int in range(1, 91):
		var intent: EnemyIntent = brain.tick(DT, AITestSupport.sight(0.75, PLAYER_AT, float(tick_index) * DT), world)
		_walk(world, intent)
		if brain.state == Enums.EnemyState.CHASE:
			chase_tick = tick_index
			break
	assert_true(chase_tick > 0, "chega a CHASE em até 1,5 s (90 ticks)")
	if chase_tick > 0:
		assert_almost_eq(float(chase_tick) * DT, 0.8, DT + 0.000001, "CHASE em ≈ 0,8 s")


func test_ai04_linha_quebrada_1_5_s_vai_a_lost_contact_e_depois_search_pelo_tempo() -> void:
	# Sem movimento: o inimigo não alcança a última posição (8 m). Visão 0,75 por 1 s (CHASE), depois 0.
	# LOST_CONTACT ao completar 1,5 s sem visão (≈ 90 ticks). SEARCH ao completar lost_contact_pursuit_s = 6 s.
	var world: FakeBrainWorld = AITestSupport.world_with_route()
	var brain: EnemyBrain = EnemyBrain.new(AIProfile.new(), AITestSupport.rng(4))
	for tick_index: int in range(60):
		brain.tick(DT, AITestSupport.sight(0.75, PLAYER_AT, float(tick_index) * DT), world)
	assert_eq(brain.state, Enums.EnemyState.CHASE, "pré-condição: CHASE")
	var lost_tick: int = -1
	var search_tick: int = -1
	for tick_index: int in range(1, 700):
		brain.tick(DT, AITestSupport.empty_batch(), world)
		if brain.state == Enums.EnemyState.LOST_CONTACT and lost_tick < 0:
			lost_tick = tick_index
		if brain.state == Enums.EnemyState.SEARCH:
			search_tick = tick_index
			break
	assert_true(lost_tick > 0, "LOST_CONTACT aconteceu")
	assert_true(search_tick > 0, "SEARCH aconteceu")
	if lost_tick > 0:
		assert_true(float(lost_tick) * DT >= 1.45 and float(lost_tick) * DT <= 1.6,
			"LOST_CONTACT em ≈ 1,5 s sem visão (medido %.3f s)" % (float(lost_tick) * DT))
	if lost_tick > 0 and search_tick > 0:
		assert_true(absf(float(search_tick - lost_tick) * DT - 6.0) <= 0.05,
			"SEARCH em ≈ 6 s de LOST_CONTACT (medido %.3f s)" % (float(search_tick - lost_tick) * DT))


func test_ai04_ai05_perde_o_jogador_e_chega_a_ultima_posicao_antes_do_limite() -> void:
	# Com movimento: o inimigo corre para o jogador (16 m) enquanto o vê (4,2 m/s). Ao perder a visão, em ≈ 2,5 s,
	# LOST_CONTACT vai à última posição vista (AI-05: primeiro destino a ≤ 1 m dela). Ainda não chegou ao entrar em
	# LOST (≈ 8,9 m), chega em ≈ 4,4 s a 1,8 m/s e passa a SEARCH antes do limite de 6 s (AI-04).
	# Com o jogador a 8 m, o inimigo já estaria no ponto ao entrar em LOST e a cascata iria direto a SEARCH.
	var player_far: Vector3 = Vector3(16.0, 0.0, 0.0)
	var world: FakeBrainWorld = AITestSupport.world_with_route()
	var brain: EnemyBrain = EnemyBrain.new(AIProfile.new(), AITestSupport.rng(5))
	for tick_index: int in range(60):
		var intent: EnemyIntent = brain.tick(DT, AITestSupport.sight(0.75, player_far, float(tick_index) * DT), world)
		_walk(world, intent)
	assert_eq(brain.state, Enums.EnemyState.CHASE, "pré-condição: CHASE")
	var lost_tick: int = -1
	var search_tick: int = -1
	var first_lost_target: Vector3 = Vector3.ZERO
	for tick_index: int in range(1, 700):
		var intent: EnemyIntent = brain.tick(DT, AITestSupport.empty_batch(), world)
		_walk(world, intent)
		if brain.state == Enums.EnemyState.LOST_CONTACT and lost_tick < 0:
			lost_tick = tick_index
			first_lost_target = intent.move_target
		if brain.state == Enums.EnemyState.SEARCH:
			search_tick = tick_index
			break
	assert_true(lost_tick > 0, "entrou em LOST_CONTACT")
	assert_true(search_tick > 0, "saiu para SEARCH")
	assert_true(AITestSupport.horizontal_distance(first_lost_target, player_far) <= 1.0,
		"AI-05: primeiro destino de LOST_CONTACT a ≤ 1 m da última posição vista")
	if lost_tick > 0 and search_tick > 0:
		assert_true(float(search_tick - lost_tick) * DT < 6.0, "AI-04: chegou antes do limite de 6 s")
	assert_true(AITestSupport.horizontal_distance(world.position, player_far) <= 1.0,
		"chegou à última posição vista antes de procurar")

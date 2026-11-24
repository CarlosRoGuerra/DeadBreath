extends TestCase
## INVESTIGATE em casos de borda (F4-003, decisão D4-08): novo ruído em SEARCH e RETURN, pista inalcançável,
## timeout de 15 s sem chegar. A âncora da busca é a posição atual quando a pista é descartada.

const LEAD: Vector3 = Vector3(8.0, 0.0, 0.0)
const OTHER_NOISE: Vector3 = Vector3(20.0, 0.0, 0.0)


func _loud_noise_batch(at: Vector3, time_s: float) -> PerceptBatch:
	var noise: HeardNoise = HeardNoise.new()
	noise.perceived_db = 30.0
	noise.effective_threshold_db = 15.0
	noise.estimated_position = at
	noise.confidence = HeardNoise.confidence_for(30.0, 15.0)
	noise.timestamp = time_s
	var batch: PerceptBatch = PerceptBatch.new()
	batch.heard.append(noise)
	return batch


func test_novo_ruido_em_search_leva_a_investigate() -> void:
	# SEARCH com suspeita 0,8 (herdada da visão). Um ruído novo de 30 dB: suspeita 1,4 ≥ 0,5 → INVESTIGATE.
	var world: FakeBrainWorld = AITestSupport.world_with_route()
	var brain: EnemyBrain = EnemyBrain.new(AIProfile.new(), AITestSupport.rng(1))
	AITestSupport.drive_to_search(brain, world, LEAD)
	assert_eq(brain.state, Enums.EnemyState.SEARCH, "pré-condição: SEARCH")
	var intent: EnemyIntent = brain.tick(0.1, _loud_noise_batch(OTHER_NOISE, 1.0), world)
	assert_eq(brain.state, Enums.EnemyState.INVESTIGATE, "novo ruído em SEARCH: INVESTIGATE")
	assert_eq(intent.voice_line, &"voice_investigate", "fala de entrada em INVESTIGATE")


func test_sem_ruido_novo_search_nao_volta_a_investigate() -> void:
	# A suspeita de 0,8 sozinha não basta em SEARCH: a regra exige um ruído novo.
	var world: FakeBrainWorld = AITestSupport.world_with_route()
	var brain: EnemyBrain = EnemyBrain.new(AIProfile.new(), AITestSupport.rng(1))
	AITestSupport.drive_to_search(brain, world, LEAD)
	for _index: int in range(5):
		brain.tick(0.1, AITestSupport.empty_batch(), world)
	assert_eq(brain.state, Enums.EnemyState.SEARCH, "sem ruído novo: segue em SEARCH")


func test_novo_ruido_em_return_leva_a_investigate() -> void:
	var world: FakeBrainWorld = FakeBrainWorld.new()
	world.route = PackedVector3Array([Vector3(0.0, 0.0, -20.0), Vector3(0.0, 0.0, 10.0)])
	var brain: EnemyBrain = EnemyBrain.new(AIProfile.new(), AITestSupport.rng(1))
	AITestSupport.drive_to_return(brain, world, LEAD)
	assert_eq(brain.state, Enums.EnemyState.RETURN, "pré-condição: RETURN")
	var intent: EnemyIntent = brain.tick(0.1, _loud_noise_batch(OTHER_NOISE, 1.0), world)
	assert_eq(brain.state, Enums.EnemyState.INVESTIGATE, "novo ruído em RETURN: INVESTIGATE")
	assert_eq(intent.voice_line, &"voice_investigate", "fala de entrada em INVESTIGATE")


func test_pista_inalcancavel_vai_direto_a_search_com_ancora_na_posicao_atual() -> void:
	# INVESTIGATE para a pista em (8,0,0). A pista deixa de ser alcançável: SEARCH no mesmo tick, com centro na
	# posição atual do inimigo (origem), e não na pista.
	var world: FakeBrainWorld = AITestSupport.world_with_route()
	var brain: EnemyBrain = EnemyBrain.new(AIProfile.new(), AITestSupport.rng(1))
	AITestSupport.drive_to_investigate(brain, world, LEAD)
	assert_eq(brain.state, Enums.EnemyState.INVESTIGATE, "pré-condição: INVESTIGATE")
	world.reachable = false
	var intent: EnemyIntent = brain.tick(0.1, AITestSupport.empty_batch(), world)
	assert_eq(brain.state, Enums.EnemyState.SEARCH, "pista inalcançável: SEARCH")
	assert_eq(intent.voice_line, &"voice_search", "fala de entrada em SEARCH")
	assert_eq(world.last_search_center, Vector3.ZERO, "centro da busca é a posição atual")


func test_pista_inalcancavel_no_proprio_ruido_vai_a_search_no_mesmo_tick() -> void:
	# Ruído novo cuja pista não é alcançável: INVESTIGATE e SEARCH no mesmo tick (cascata), com âncora atual.
	var world: FakeBrainWorld = AITestSupport.world_with_route()
	world.reachable = false
	var brain: EnemyBrain = EnemyBrain.new(AIProfile.new(), AITestSupport.rng(1))
	brain.tick(0.1, _loud_noise_batch(OTHER_NOISE, 0.0), world)
	assert_eq(brain.state, Enums.EnemyState.SEARCH, "cascata: ruído → INVESTIGATE → SEARCH")
	assert_eq(world.last_search_center, Vector3.ZERO, "âncora é a posição atual, não o ruído")


func test_timeout_de_15_s_sem_chegar_vai_a_search_com_ancora_atual() -> void:
	# O inimigo não anda (fica na origem, longe da pista). Em 14 s: INVESTIGATE. Em 15 s: SEARCH.
	var world: FakeBrainWorld = AITestSupport.world_with_route()
	var brain: EnemyBrain = EnemyBrain.new(AIProfile.new(), AITestSupport.rng(1))
	AITestSupport.drive_to_investigate(brain, world, LEAD)
	for _index: int in range(14):
		brain.tick(1.0, AITestSupport.empty_batch(), world)
	assert_eq(brain.state, Enums.EnemyState.INVESTIGATE, "14 s: ainda INVESTIGATE")
	brain.tick(1.0, AITestSupport.empty_batch(), world)
	assert_eq(brain.state, Enums.EnemyState.SEARCH, "15 s sem chegar à pista: SEARCH")
	assert_eq(world.last_search_center, Vector3.ZERO, "âncora é a posição atual")


func test_timeout_nao_dispara_quando_chega_a_tempo() -> void:
	# O inimigo chega à pista em 4 s e fica 3 s sem visão: SEARCH pela regra de 3 s, antes do timeout de 15 s.
	var world: FakeBrainWorld = AITestSupport.world_with_route()
	var brain: EnemyBrain = EnemyBrain.new(AIProfile.new(), AITestSupport.rng(1))
	AITestSupport.drive_to_investigate(brain, world, LEAD)
	world.position = LEAD
	for _index: int in range(3):
		brain.tick(1.0, AITestSupport.empty_batch(), world)
	assert_eq(brain.state, Enums.EnemyState.SEARCH, "3 s no ponto: SEARCH antes do timeout")
	assert_eq(world.last_search_center, LEAD, "âncora da busca é a pista, pois foi alcançada")

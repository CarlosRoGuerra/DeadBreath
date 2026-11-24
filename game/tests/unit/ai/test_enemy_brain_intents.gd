extends TestCase
## Intent por estado (F4-003; DATA §3.3 e COMPONENT_CONTRACTS §8.1): destino, velocidade, olhar, busca, inspeção e falas.
## Velocidades do OBSERVER: patrulha 1,2; investigação 1,8; perseguição 4,2. SEARCH e RETURN: 1,2 (patrulha).
## LOST_CONTACT: 1,8 (investigação). Contas à mão nos comentários.

const PLAYER_SEEN_AT: Vector3 = Vector3(8.0, 0.0, 0.0)


func _brain(seed_value: int = 1, profile: AIProfile = null) -> EnemyBrain:
	var used: AIProfile = profile
	if used == null:
		used = AIProfile.new()
	return EnemyBrain.new(used, AITestSupport.rng(seed_value))


func test_patrulha_percorre_os_pontos_em_ordem_e_em_laco() -> void:
	# Rota A, B, C. Inimigo começa longe de A: vai a A. Ao chegar, passa a B; depois C; depois A de novo.
	var world: FakeBrainWorld = FakeBrainWorld.new()
	var point_a: Vector3 = Vector3(0.0, 0.0, -10.0)
	var point_b: Vector3 = Vector3(10.0, 0.0, -10.0)
	var point_c: Vector3 = Vector3(10.0, 0.0, 10.0)
	world.route = PackedVector3Array([point_a, point_b, point_c])
	var brain: EnemyBrain = _brain()
	var first: EnemyIntent = brain.tick(0.1, AITestSupport.empty_batch(), world)
	assert_eq(first.move_target, point_a, "primeiro destino: A")
	assert_almost_eq(first.move_speed, 1.2, 0.000001, "patrulha: 1,2 m/s")
	assert_eq(first.look_target, point_a, "olha para onde anda")
	world.position = point_a
	assert_eq(brain.tick(0.1, AITestSupport.empty_batch(), world).move_target, point_b, "após A: B")
	world.position = point_b
	assert_eq(brain.tick(0.1, AITestSupport.empty_batch(), world).move_target, point_c, "após B: C")
	world.position = point_c
	assert_eq(brain.tick(0.1, AITestSupport.empty_batch(), world).move_target, point_a, "após C: volta a A (laço)")


func test_patrulha_com_rota_vazia_avisa_e_fica_parado() -> void:
	var world: FakeBrainWorld = FakeBrainWorld.new()
	var brain: EnemyBrain = _brain()
	expect_engine_error("rota de patrulha vazia")
	var intent: EnemyIntent = brain.tick(0.1, AITestSupport.empty_batch(), world)
	assert_almost_eq(intent.move_speed, 0.0, 0.000001, "sem rota, fica parado")


func test_suspicious_fica_parado_e_olha_para_o_estimulo() -> void:
	# Entra em SUSPICIOUS por 4 ticks de visibilidade 0,5 em (8,0,0). Velocidade 0; olhar para o estímulo.
	var world: FakeBrainWorld = AITestSupport.world_with_route()
	var brain: EnemyBrain = _brain()
	world.position = Vector3(1.0, 0.0, 1.0)
	for _index: int in range(4):
		brain.tick(0.1, AITestSupport.sight(0.5, PLAYER_SEEN_AT, 1.0), world)
	assert_eq(brain.state, Enums.EnemyState.SUSPICIOUS, "pré-condição: SUSPICIOUS")
	var intent: EnemyIntent = brain.tick(0.1, AITestSupport.empty_batch(), world)
	assert_almost_eq(intent.move_speed, 0.0, 0.000001, "parado")
	assert_eq(intent.move_target, Vector3(1.0, 0.0, 1.0), "destino é a própria posição")
	assert_eq(intent.look_target, PLAYER_SEEN_AT, "olha para o estímulo")


func test_investigate_vai_a_pista_com_velocidade_de_investigacao() -> void:
	var world: FakeBrainWorld = AITestSupport.world_with_route()
	var brain: EnemyBrain = _brain()
	AITestSupport.drive_to_investigate(brain, world, PLAYER_SEEN_AT)
	var intent: EnemyIntent = brain.tick(0.1, AITestSupport.empty_batch(), world)
	assert_eq(brain.state, Enums.EnemyState.INVESTIGATE, "pré-condição: INVESTIGATE")
	assert_eq(intent.move_target, PLAYER_SEEN_AT, "destino é o best_lead")
	assert_almost_eq(intent.move_speed, 1.8, 0.000001, "investigação: 1,8 m/s")


func test_chase_vai_a_ultima_posicao_vista_com_velocidade_de_perseguicao() -> void:
	# Percept mais novo em (8,0,0). A última posição vista acompanha o percept com visibilidade > 0.
	var world: FakeBrainWorld = AITestSupport.world_with_route()
	var brain: EnemyBrain = _brain()
	AITestSupport.drive_to_investigate(brain, world, Vector3(2.0, 0.0, 2.0))
	brain.tick(0.2, AITestSupport.sight(1.0, PLAYER_SEEN_AT, 0.7), world)
	assert_eq(brain.state, Enums.EnemyState.CHASE, "pré-condição: CHASE")
	var intent: EnemyIntent = brain.tick(0.1, AITestSupport.sight(1.0, PLAYER_SEEN_AT, 0.8), world)
	assert_eq(intent.move_target, PLAYER_SEEN_AT, "vai à última posição vista")
	assert_almost_eq(intent.move_speed, 4.2, 0.000001, "perseguição: 4,2 m/s")
	assert_eq(intent.voice_line, &"", "fala só na transição")


func test_lost_contact_primeiro_destino_a_ate_1_metro_da_ultima_posicao() -> void:
	# AI-05: o primeiro destino de LOST_CONTACT fica a ≤ 1 m da última posição vista. Aqui é a própria posição (0 m).
	var world: FakeBrainWorld = AITestSupport.world_with_route()
	var brain: EnemyBrain = _brain()
	AITestSupport.drive_to_lost(brain, world, PLAYER_SEEN_AT)
	var intent: EnemyIntent = brain.tick(0.1, AITestSupport.empty_batch(), world)
	assert_eq(brain.state, Enums.EnemyState.LOST_CONTACT, "pré-condição: LOST_CONTACT")
	assert_true(AITestSupport.horizontal_distance(intent.move_target, PLAYER_SEEN_AT) <= 1.0,
		"primeiro destino a ≤ 1 m da última posição vista")
	assert_almost_eq(intent.move_speed, 1.8, 0.000001, "LOST_CONTACT: velocidade de investigação")


func test_search_visita_os_pontos_em_ordem_pelo_rng_e_sem_repetir() -> void:
	# Cinco pontos de busca. Com a mesma semente, a mesma ordem; os cinco são visitados uma vez antes de recomeçar.
	var candidates: PackedVector3Array = PackedVector3Array([
		Vector3(20.0, 0.0, 0.0), Vector3(21.0, 0.0, 0.0), Vector3(20.0, 0.0, 1.0),
		Vector3(21.0, 0.0, 1.0), Vector3(20.5, 0.0, 2.0),
	])
	var first_order: PackedVector3Array = _visit_order(7, candidates)
	var second_order: PackedVector3Array = _visit_order(7, candidates)
	assert_eq(first_order, second_order, "mesma semente: mesma ordem de busca")
	var sorted_visited: PackedVector3Array = first_order.duplicate()
	var sorted_candidates: PackedVector3Array = candidates.duplicate()
	sorted_visited.sort()
	sorted_candidates.sort()
	assert_eq(sorted_visited, sorted_candidates, "cada ponto visitado uma vez")


func _visit_order(seed_value: int, candidates: PackedVector3Array) -> PackedVector3Array:
	var world: FakeBrainWorld = AITestSupport.world_with_route()
	world.search_candidates = candidates
	var brain: EnemyBrain = _brain(seed_value)
	AITestSupport.drive_to_search(brain, world, PLAYER_SEEN_AT)
	var visited: PackedVector3Array = PackedVector3Array()
	for _index: int in range(candidates.size()):
		var intent: EnemyIntent = brain.tick(0.1, AITestSupport.empty_batch(), world)
		visited.append(intent.move_target)
		world.position = intent.move_target
	return visited


func test_search_com_inspecao_sorteada_vai_ao_esconderijo_e_posta_a_inspecao_uma_vez() -> void:
	# Chance de inspeção 1,0 (sempre). Todos os pontos de busca estão a ≤ 1,5 m de um esconderijo em (20.5, 0, 20).
	# Ao chegar ao primeiro ponto: vai ao esconderijo. Ao chegar a ele: inspect_hideable = persist_id, uma vez.
	var profile: AIProfile = AIProfile.new()
	profile.inspect_hideable_chance = 1.0
	var world: FakeBrainWorld = AITestSupport.world_with_route()
	world.search_candidates = PackedVector3Array([Vector3(20.0, 0.0, 20.0), Vector3(21.0, 0.0, 20.0)])
	var hideable_position: Vector3 = Vector3(20.5, 0.0, 20.0)
	world.hideables = [HideableInfo.create(&"wardrobe_hall", hideable_position)]
	var brain: EnemyBrain = _brain(3, profile)
	AITestSupport.drive_to_search(brain, world, PLAYER_SEEN_AT)
	var at_point: EnemyIntent = brain.tick(0.1, AITestSupport.empty_batch(), world)
	world.position = at_point.move_target
	var to_hideable: EnemyIntent = brain.tick(0.1, AITestSupport.empty_batch(), world)
	assert_eq(to_hideable.move_target, hideable_position, "chegou ao ponto: vai ao esconderijo")
	assert_eq(to_hideable.inspect_hideable, &"", "ainda não chegou: sem inspeção")
	world.position = hideable_position
	var arrived: EnemyIntent = brain.tick(0.1, AITestSupport.empty_batch(), world)
	assert_eq(arrived.inspect_hideable, &"wardrobe_hall", "chegou: posta a inspeção")
	var after: EnemyIntent = brain.tick(0.1, AITestSupport.empty_batch(), world)
	assert_eq(after.inspect_hideable, &"", "a inspeção não se repete nos ticks seguintes")


func test_search_com_chance_zero_nunca_inspeciona() -> void:
	var profile: AIProfile = AIProfile.new()
	profile.inspect_hideable_chance = 0.0
	var world: FakeBrainWorld = AITestSupport.world_with_route()
	world.search_candidates = PackedVector3Array([Vector3(20.0, 0.0, 20.0), Vector3(21.0, 0.0, 20.0)])
	world.hideables = [HideableInfo.create(&"wardrobe_hall", Vector3(20.5, 0.0, 20.0))]
	var brain: EnemyBrain = _brain(3, profile)
	AITestSupport.drive_to_search(brain, world, PLAYER_SEEN_AT)
	var seen_any: bool = false
	for _index: int in range(6):
		var intent: EnemyIntent = brain.tick(0.1, AITestSupport.empty_batch(), world)
		if intent.inspect_hideable != &"":
			seen_any = true
		world.position = intent.move_target
	assert_false(seen_any, "com chance 0, nenhuma inspeção")


func test_return_vai_ao_ponto_mais_proximo_com_velocidade_de_patrulha() -> void:
	var world: FakeBrainWorld = FakeBrainWorld.new()
	world.route = PackedVector3Array([Vector3(0.0, 0.0, -20.0), Vector3(0.0, 0.0, 10.0)])
	var brain: EnemyBrain = _brain()
	AITestSupport.drive_to_return(brain, world, PLAYER_SEEN_AT)
	var intent: EnemyIntent = brain.tick(0.1, AITestSupport.empty_batch(), world)
	assert_eq(brain.state, Enums.EnemyState.RETURN, "pré-condição: RETURN")
	assert_eq(intent.move_target, Vector3(0.0, 0.0, 10.0), "ponto mais próximo da pista (12,8 m contra 21,5 m)")
	assert_almost_eq(intent.move_speed, 1.2, 0.000001, "RETURN: velocidade de patrulha")


func test_intent_de_voz_so_no_tick_da_transicao() -> void:
	# Visibilidade 0,5 e dt 0,1 por 6 ticks: SUSPICIOUS entra no tick 4 (suspeita 0,32) e segue até o 6.
	# A fala sai só no tick 4, a transição; nos ticks 5 e 6 o campo volta vazio.
	var world: FakeBrainWorld = AITestSupport.world_with_route()
	var brain: EnemyBrain = _brain()
	var spoken: int = 0
	for _index: int in range(6):
		var intent: EnemyIntent = brain.tick(0.1, AITestSupport.sight(0.5, PLAYER_SEEN_AT, 1.0), world)
		if intent.voice_line != &"":
			spoken += 1
	assert_eq(spoken, 1, "a fala de SUSPICIOUS sai uma vez, na transição")

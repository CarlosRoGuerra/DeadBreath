extends TestCase
## Tabela de transições (DATA_STRUCTURES §3.3; F4-003), uma linha por teste, com as contas à mão nos comentários.
## Perfil OBSERVER (padrão do AIProfile). Visibilidades e dt escolhidos para contas exatas.
## A linha "novo ruído → INVESTIGATE" não está aqui: depende do limiar efetivo (contrato pendente, ver test_enemy_brain_audicao).

const PLAYER_SEEN_AT: Vector3 = Vector3(8.0, 0.0, 0.0)
const EMPTY_LABEL: String = ""


func _brain() -> EnemyBrain:
	return EnemyBrain.new(AIProfile.new(), AITestSupport.rng(1))


func test_patrol_para_suspicious_por_visao() -> void:
	# Visibilidade 0,5 e dt 0,1: suspeita += 1,6 · 0,5 · 0,1 = 0,08 por tick; confirmação += 0,05 (0,5 ≥ 0,4).
	# Ticks 1 a 3: suspeita 0,08 / 0,16 / 0,24 (< 0,25): PATROL, sem fala.
	# Tick 4: suspeita 0,32 ≥ 0,25: SUSPICIOUS, fala voice_suspicious. Confirmação 0,2 < 0,6: sem CHASE.
	var world: FakeBrainWorld = AITestSupport.world_with_route()
	var brain: EnemyBrain = _brain()
	for index: int in range(1, 4):
		var intent: EnemyIntent = brain.tick(0.1, AITestSupport.sight(0.5, PLAYER_SEEN_AT, 0.1 * index), world)
		assert_eq(brain.state, Enums.EnemyState.PATROL, "tick %d: segue em PATROL" % index)
		assert_eq(intent.voice_line, &"", "tick %d: sem fala" % index)
	var intent: EnemyIntent = brain.tick(0.1, AITestSupport.sight(0.5, PLAYER_SEEN_AT, 0.4), world)
	assert_eq(brain.state, Enums.EnemyState.SUSPICIOUS, "tick 4: suspeita 0,32 ≥ 0,25")
	assert_eq(intent.voice_line, &"voice_suspicious", "fala de entrada em SUSPICIOUS")
	assert_almost_eq(brain.suspicion, 0.32, 0.000001, "suspeita 0,32")
	assert_almost_eq(brain.confirmation, 0.2, 0.000001, "confirmação 0,2")


func test_suspicious_volta_a_patrol_quando_a_suspeita_cai_abaixo_de_0_15() -> void:
	# Entrada: 4 ticks de visibilidade 0,5 e dt 0,1 → suspeita 0,32, SUSPICIOUS.
	# Sem estímulo, o decaimento começa após 2 s (0,05/s). Em 4 s: 0,32 − 0,05 · 2,0 ≈ 0,22 (≥ 0,15: SUSPICIOUS).
	# Em 6 s: 0,32 − 0,05 · 4,0 ≈ 0,12 (< 0,15): PATROL. Nenhuma fala na volta.
	var world: FakeBrainWorld = AITestSupport.world_with_route()
	var brain: EnemyBrain = _brain()
	for index: int in range(4):
		brain.tick(0.1, AITestSupport.sight(0.5, PLAYER_SEEN_AT, 0.1 * index), world)
	assert_eq(brain.state, Enums.EnemyState.SUSPICIOUS, "entrada: SUSPICIOUS")
	var spoken: int = 0
	for index: int in range(40):
		var intent: EnemyIntent = brain.tick(0.1, AITestSupport.empty_batch(), world)
		if intent.voice_line != &"":
			spoken += 1
	assert_eq(brain.state, Enums.EnemyState.SUSPICIOUS, "em 4 s ainda SUSPICIOUS")
	for index: int in range(20):
		var intent_back: EnemyIntent = brain.tick(0.1, AITestSupport.empty_batch(), world)
		if intent_back.voice_line != &"":
			spoken += 1
	assert_eq(brain.state, Enums.EnemyState.PATROL, "em 6 s voltou a PATROL")
	assert_eq(brain.suspicion, 0.0, "entrar em PATROL zera a suspeita")
	assert_eq(spoken, 0, "nenhuma fala durante a queda")


func test_suspicious_para_investigate_por_suspeita_com_fala_e_pista() -> void:
	# Visibilidade 1,0 e dt 0,1: suspeita += 0,16 por tick; confirmação += 0,1 por tick.
	# Tick 1: 0,16 (PATROL). Tick 2: 0,32 → SUSPICIOUS (voice_suspicious). Tick 3: 0,48 (< 0,5, SUSPICIOUS).
	# Tick 4: 0,64 ≥ 0,5 → INVESTIGATE (voice_investigate), destino = a posição do percept. Confirmação 0,4: sem CHASE.
	var world: FakeBrainWorld = AITestSupport.world_with_route()
	var brain: EnemyBrain = _brain()
	var voices: PackedStringArray = PackedStringArray()
	var last: EnemyIntent = null
	for index: int in range(1, 5):
		last = brain.tick(0.1, AITestSupport.sight(1.0, PLAYER_SEEN_AT, 0.1 * index), world)
		voices.append(String(last.voice_line))
	assert_eq(brain.state, Enums.EnemyState.INVESTIGATE, "tick 4: INVESTIGATE")
	assert_eq(voices, PackedStringArray([EMPTY_LABEL, "voice_suspicious", EMPTY_LABEL, "voice_investigate"]),
		"fala posta uma vez por transição, nos ticks 2 e 4")
	assert_eq(last.move_target, PLAYER_SEEN_AT, "destino é a pista")
	assert_almost_eq(last.move_speed, 1.8, 0.000001, "velocidade de investigação do OBSERVER")


func test_patrol_para_investigate_em_cascata_no_mesmo_tick() -> void:
	# Visibilidade 1,0 e dt 0,5: suspeita += 1,6 · 1,0 · 0,5 = 0,8 num único tick; confirmação += 0,5 (< 0,6).
	# PATROL → SUSPICIOUS (0,8 ≥ 0,25) → INVESTIGATE (0,8 ≥ 0,5), no mesmo tick. Fala final: voice_investigate.
	var world: FakeBrainWorld = AITestSupport.world_with_route()
	var brain: EnemyBrain = _brain()
	var intent: EnemyIntent = brain.tick(0.5, AITestSupport.sight(1.0, PLAYER_SEEN_AT, 0.5), world)
	assert_eq(brain.state, Enums.EnemyState.INVESTIGATE, "cascata: PATROL → SUSPICIOUS → INVESTIGATE")
	assert_eq(intent.voice_line, &"voice_investigate", "a fala final da cascata vale")
	assert_eq(intent.move_target, PLAYER_SEEN_AT, "destino é a pista da cascata")


func test_investigate_para_search_depois_de_chegar_e_3_s_sem_visao() -> void:
	# Pista em (8,0,0). Chegou (inimigo no ponto). Sem visão, ticks de 1,0 s: 1 s e 2 s → INVESTIGATE; 3 s → SEARCH.
	# Sem chegada, mesmo com 5 s sem visão, fica em INVESTIGATE.
	var world: FakeBrainWorld = AITestSupport.world_with_route()
	var brain: EnemyBrain = _brain()
	AITestSupport.drive_to_investigate(brain, world, PLAYER_SEEN_AT)
	world.position = PLAYER_SEEN_AT
	brain.tick(1.0, AITestSupport.empty_batch(), world)
	brain.tick(1.0, AITestSupport.empty_batch(), world)
	assert_eq(brain.state, Enums.EnemyState.INVESTIGATE, "2 s sem visão: ainda INVESTIGATE")
	var intent: EnemyIntent = brain.tick(1.0, AITestSupport.empty_batch(), world)
	assert_eq(brain.state, Enums.EnemyState.SEARCH, "3 s sem visão no ponto: SEARCH")
	assert_eq(intent.voice_line, &"voice_search", "fala de entrada em SEARCH")

	var far: FakeBrainWorld = AITestSupport.world_with_route()
	var other: EnemyBrain = _brain()
	AITestSupport.drive_to_investigate(other, far, PLAYER_SEEN_AT)
	for index: int in range(5):
		other.tick(1.0, AITestSupport.empty_batch(), far)
	assert_eq(other.state, Enums.EnemyState.INVESTIGATE, "sem chegar à pista, não passa a SEARCH")


func test_qualquer_estado_vai_a_chase_por_confirmacao() -> void:
	# INVESTIGATE com confirmação 0,5 (cascata). Visibilidade 1,0 e dt 0,2: confirmação 0,5 + 0,2 = 0,7 ≥ 0,6.
	# CHASE, fala voice_chase_shout, destino = última posição vista.
	var world: FakeBrainWorld = AITestSupport.world_with_route()
	var brain: EnemyBrain = _brain()
	AITestSupport.drive_to_investigate(brain, world, PLAYER_SEEN_AT)
	assert_eq(brain.state, Enums.EnemyState.INVESTIGATE, "pré-condição: INVESTIGATE")
	var intent: EnemyIntent = brain.tick(0.2, AITestSupport.sight(1.0, PLAYER_SEEN_AT, 0.7), world)
	assert_eq(brain.state, Enums.EnemyState.CHASE, "confirmação 0,7 ≥ 0,6")
	assert_eq(intent.voice_line, &"voice_chase_shout", "grito de perseguição")
	assert_eq(intent.move_target, PLAYER_SEEN_AT, "vai à última posição vista")
	assert_almost_eq(intent.move_speed, 4.2, 0.000001, "velocidade de perseguição do OBSERVER")


func test_chase_para_lost_contact_apos_1_5_s_sem_visao() -> void:
	# CHASE; depois visibilidade 0, ticks de 0,1 s. Em 1,4 s: CHASE (14 ticks). Em 1,6 s: LOST_CONTACT (16 ticks).
	# O tick 15 (1,5 s exatos) fica fora da asserção por arredondamento de ponto flutuante.
	var world: FakeBrainWorld = AITestSupport.world_with_route()
	var brain: EnemyBrain = _brain()
	AITestSupport.drive_to_investigate(brain, world, PLAYER_SEEN_AT)
	brain.tick(0.2, AITestSupport.sight(1.0, PLAYER_SEEN_AT, 0.7), world)
	for index: int in range(14):
		brain.tick(0.1, AITestSupport.empty_batch(), world)
	assert_eq(brain.state, Enums.EnemyState.CHASE, "1,4 s sem visão: CHASE")
	brain.tick(0.1, AITestSupport.empty_batch(), world)
	brain.tick(0.1, AITestSupport.empty_batch(), world)
	assert_eq(brain.state, Enums.EnemyState.LOST_CONTACT, "1,6 s sem visão: LOST_CONTACT")


func test_lost_contact_para_search_ao_chegar_a_ultima_posicao() -> void:
	# LOST_CONTACT com o inimigo ainda na origem (8 m da última posição): continua LOST_CONTACT.
	# Ao chegar a ≤ 1 m da última posição, SEARCH no mesmo tick, fala voice_search.
	var world: FakeBrainWorld = AITestSupport.world_with_route()
	var brain: EnemyBrain = _brain()
	AITestSupport.drive_to_lost(brain, world, PLAYER_SEEN_AT)
	assert_eq(brain.state, Enums.EnemyState.LOST_CONTACT, "pré-condição: LOST_CONTACT")
	brain.tick(0.1, AITestSupport.empty_batch(), world)
	assert_eq(brain.state, Enums.EnemyState.LOST_CONTACT, "longe da última posição: segue LOST_CONTACT")
	world.position = PLAYER_SEEN_AT
	var intent: EnemyIntent = brain.tick(0.1, AITestSupport.empty_batch(), world)
	assert_eq(brain.state, Enums.EnemyState.SEARCH, "chegou: SEARCH")
	assert_eq(intent.voice_line, &"voice_search", "fala de entrada em SEARCH")


func test_lost_contact_para_search_por_tempo_com_6_s() -> void:
	# lost_contact_pursuit_s = 6 s (OBSERVER), sem chegada. Em 5,9 s: LOST_CONTACT. Em 6,1 s: SEARCH.
	var world: FakeBrainWorld = AITestSupport.world_with_route()
	var brain: EnemyBrain = _brain()
	AITestSupport.drive_to_lost(brain, world, PLAYER_SEEN_AT)
	for index: int in range(59):
		brain.tick(0.1, AITestSupport.empty_batch(), world)
	assert_eq(brain.state, Enums.EnemyState.LOST_CONTACT, "5,9 s: ainda LOST_CONTACT")
	for index: int in range(2):
		brain.tick(0.1, AITestSupport.empty_batch(), world)
	assert_eq(brain.state, Enums.EnemyState.SEARCH, "6,1 s: SEARCH pelo tempo")


func test_search_para_return_apos_60_s_sem_pista_nova() -> void:
	# SEARCH dura search_duration_s × 1,0 = 60 s. Em 59 s: SEARCH. Em 60 s: RETURN.
	var world: FakeBrainWorld = AITestSupport.world_with_route()
	var brain: EnemyBrain = _brain()
	AITestSupport.drive_to_search(brain, world, PLAYER_SEEN_AT)
	for index: int in range(59):
		brain.tick(1.0, AITestSupport.empty_batch(), world)
	assert_eq(brain.state, Enums.EnemyState.SEARCH, "59 s: SEARCH")
	brain.tick(1.0, AITestSupport.empty_batch(), world)
	assert_eq(brain.state, Enums.EnemyState.RETURN, "60 s sem pista: RETURN")


func test_search_pista_nova_reinicia_o_cronometro() -> void:
	# SEARCH entra no tempo 0. Até 49 s, nada. Em 50 s, visibilidade 0,2 (pista; não confirma): zera o cronômetro.
	# Em 109 s (59 s depois da pista): SEARCH. Em 110 s: RETURN.
	var world: FakeBrainWorld = AITestSupport.world_with_route()
	var brain: EnemyBrain = _brain()
	AITestSupport.drive_to_search(brain, world, PLAYER_SEEN_AT)
	for index: int in range(49):
		brain.tick(1.0, AITestSupport.empty_batch(), world)
	brain.tick(1.0, AITestSupport.sight(0.2, PLAYER_SEEN_AT, 50.0), world)
	for index: int in range(59):
		brain.tick(1.0, AITestSupport.empty_batch(), world)
	assert_eq(brain.state, Enums.EnemyState.SEARCH, "109 s: SEARCH (cronômetro reiniciado em 50 s)")
	brain.tick(1.0, AITestSupport.empty_batch(), world)
	assert_eq(brain.state, Enums.EnemyState.RETURN, "110 s: RETURN")


func test_return_para_patrol_no_ponto_mais_proximo_e_segue_a_rota() -> void:
	# Rota A(0,0,-20), B(0,0,10), C(0,0,20). Da pista (8,0,0), o mais próximo é B: 12,8 m (A e C: 21,5 m).
	# Ao chegar a B, PATROL retoma no ponto seguinte: C.
	var world: FakeBrainWorld = FakeBrainWorld.new()
	var point_a: Vector3 = Vector3(0.0, 0.0, -20.0)
	var point_b: Vector3 = Vector3(0.0, 0.0, 10.0)
	var point_c: Vector3 = Vector3(0.0, 0.0, 20.0)
	world.route = PackedVector3Array([point_a, point_b, point_c])
	var brain: EnemyBrain = _brain()
	AITestSupport.drive_to_return(brain, world, PLAYER_SEEN_AT)
	assert_eq(brain.state, Enums.EnemyState.RETURN, "pré-condição: RETURN")
	var returning: EnemyIntent = brain.tick(0.1, AITestSupport.empty_batch(), world)
	assert_eq(returning.move_target, point_b, "RETURN vai ao ponto de patrulha mais próximo")
	world.position = point_b
	var intent: EnemyIntent = brain.tick(0.1, AITestSupport.empty_batch(), world)
	assert_eq(brain.state, Enums.EnemyState.PATROL, "chegou a B: PATROL")
	assert_eq(intent.move_target, point_c, "retoma no ponto seguinte a B")
	assert_eq(intent.voice_line, &"", "volta a PATROL sem fala")

extends TestCase
## Revisão F4-010 (decisão D4-09 do Director):
## - R4-01: a confirmação tem teto em visual_confirm_time_s e zera ao entrar em LOST_CONTACT. Depois de uma
##   perseguição longa, perder a visão leva a LOST_CONTACT em 1,5 s, com um grito só; voltar a CHASE exige visão nova.
## - R4-03: RETURN e PATROL não ficam presos em destino inalcançável nem em destino que nunca é alcançado.
## Autor: Director (correção da revisão).

const SEEN_AT: Vector3 = Vector3(0.0, 0.0, -8.0)
const DT: float = 1.0 / 60.0


func _profile() -> AIProfile:
	return load("res://content/data/ai/observer.tres") as AIProfile


func test_perseguicao_longa_perde_contato_em_1_5_s_com_um_grito() -> void:
	var world: FakeBrainWorld = AITestSupport.world_with_route()
	var brain: EnemyBrain = EnemyBrain.new(_profile(), AITestSupport.rng(5))
	var shouts: int = 0
	var t: float = 0.0
	for _tick: int in range(600):
		t += DT
		var intent: EnemyIntent = brain.tick(DT, AITestSupport.sight(0.75, SEEN_AT, t), world)
		shouts += int(intent.voice_line == EnemyBrain.VOICE_CHASE)
	assert_eq(brain.state, Enums.EnemyState.CHASE, "10 s vendo o jogador: CHASE")
	assert_true(brain.confirmation <= _profile().visual_confirm_time_s + 0.0001,
		"a confirmação tem teto (%.3f)" % brain.confirmation)
	var lost_after: float = -1.0
	var elapsed: float = 0.0
	for _tick: int in range(480):
		elapsed += DT
		t += DT
		var intent: EnemyIntent = brain.tick(DT, AITestSupport.empty_batch(), world)
		shouts += int(intent.voice_line == EnemyBrain.VOICE_CHASE)
		if lost_after < 0.0 and brain.state != Enums.EnemyState.CHASE:
			lost_after = elapsed
	note("LOST_CONTACT %.3f s depois de perder a visão; gritos %d" % [lost_after, shouts])
	assert_true(absf(lost_after - EnemyBrain.LOST_CONTACT_NO_SIGHT_S) <= 0.05,
		"sai de CHASE em 1,5 s (%.3f s)" % lost_after)
	assert_eq(shouts, 1, "um grito de perseguição no episódio inteiro")


func test_voltar_a_chase_exige_visao_nova() -> void:
	var world: FakeBrainWorld = AITestSupport.world_with_route()
	var brain: EnemyBrain = EnemyBrain.new(_profile(), AITestSupport.rng(6))
	var t: float = 0.0
	for _tick: int in range(300):
		t += DT
		brain.tick(DT, AITestSupport.sight(0.75, SEEN_AT, t), world)
	for _tick: int in range(100):
		t += DT
		brain.tick(DT, AITestSupport.empty_batch(), world)
	assert_eq(brain.state, Enums.EnemyState.LOST_CONTACT, "pré-condição: LOST_CONTACT")
	assert_almost_eq(brain.confirmation, 0.0, 0.0001, "a confirmação zerou ao entrar em LOST_CONTACT")
	var back_after: float = -1.0
	var elapsed: float = 0.0
	for _tick: int in range(120):
		elapsed += DT
		t += DT
		brain.tick(DT, AITestSupport.sight(0.75, SEEN_AT, t), world)
		if back_after < 0.0 and brain.state == Enums.EnemyState.CHASE:
			back_after = elapsed
	# 0,6 s de confirmação a 0,75 de visibilidade = 0,8 s de visão nova.
	assert_true(back_after >= 0.79 and back_after <= 0.82, "volta a CHASE só com 0,8 s de visão nova (%.3f s)" % back_after)


func test_patrulha_pula_ponto_inalcancavel() -> void:
	var world: FakeBrainWorld = FakeBrainWorld.new()
	world.route = PackedVector3Array([Vector3(0.0, 0.0, -5.0), Vector3(0.0, 0.0, -10.0), Vector3(0.0, 0.0, -15.0)])
	world.unreachable_points = PackedVector3Array([Vector3(0.0, 0.0, -5.0)])
	var brain: EnemyBrain = EnemyBrain.new(_profile(), AITestSupport.rng(7))
	var intent: EnemyIntent = brain.tick(DT, AITestSupport.empty_batch(), world)
	assert_eq(intent.move_target, Vector3(0.0, 0.0, -10.0), "o ponto inalcançável é pulado")


func test_patrulha_sem_ponto_alcancavel_fica_parada() -> void:
	var world: FakeBrainWorld = AITestSupport.world_with_route()
	world.position = Vector3(3.0, 0.0, 3.0)
	world.reachable = false
	var brain: EnemyBrain = EnemyBrain.new(_profile(), AITestSupport.rng(8))
	var intent: EnemyIntent = brain.tick(DT, AITestSupport.empty_batch(), world)
	assert_eq(intent.move_target, world.position, "sem ponto alcançável, fica onde está")
	assert_almost_eq(intent.move_speed, 0.0, 0.0001, "parado")


func test_patrulha_passa_ao_ponto_seguinte_depois_do_tempo_limite() -> void:
	var world: FakeBrainWorld = AITestSupport.world_with_route()
	var brain: EnemyBrain = EnemyBrain.new(_profile(), AITestSupport.rng(9))
	var first: EnemyIntent = brain.tick(1.0, AITestSupport.empty_batch(), world)
	var target_before: Vector3 = first.move_target
	var last: EnemyIntent = first
	for _tick: int in range(int(EnemyBrain.PATROL_LEG_TIMEOUT_S) + 1):
		last = brain.tick(1.0, AITestSupport.empty_batch(), world)
	assert_ne(last.move_target, target_before, "o inimigo parado desiste do ponto depois de 30 s")


func test_return_inalcancavel_volta_a_patrulha() -> void:
	var world: FakeBrainWorld = AITestSupport.world_with_route()
	var brain: EnemyBrain = EnemyBrain.new(_profile(), AITestSupport.rng(10))
	AITestSupport.drive_to_return(brain, world, Vector3(5.0, 0.0, 0.0))
	assert_eq(brain.state, Enums.EnemyState.RETURN, "pré-condição: RETURN")
	world.reachable = false
	brain.tick(DT, AITestSupport.empty_batch(), world)
	assert_eq(brain.state, Enums.EnemyState.PATROL, "RETURN com destino inalcançável passa a PATROL")


func test_return_sem_chegar_volta_a_patrulha_depois_do_tempo_limite() -> void:
	var world: FakeBrainWorld = AITestSupport.world_with_route()
	var brain: EnemyBrain = EnemyBrain.new(_profile(), AITestSupport.rng(11))
	AITestSupport.drive_to_return(brain, world, Vector3(5.0, 0.0, 0.0))
	assert_eq(brain.state, Enums.EnemyState.RETURN, "pré-condição: RETURN")
	for _tick: int in range(int(EnemyBrain.RETURN_TIMEOUT_S) - 1):
		brain.tick(1.0, AITestSupport.empty_batch(), world)
	assert_eq(brain.state, Enums.EnemyState.RETURN, "antes de 30 s continua em RETURN")
	brain.tick(1.5, AITestSupport.empty_batch(), world)
	assert_eq(brain.state, Enums.EnemyState.PATROL, "30 s sem chegar: PATROL")

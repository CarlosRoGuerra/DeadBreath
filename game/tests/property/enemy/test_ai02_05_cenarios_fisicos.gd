extends TestCase
## F4-004 (TEST_PLAN §2.5: AI-02, AI-03, AI-04 e AI-05), cenários com física e navmesh do mundo de teste (EnemyTestWorld).
## Por que mundo de teste e não a sandbox: a navmesh é exata (o caminho é reto e o alvo é alcançável), não há porta,
## jogador nem marcador de outro nível no caminho, e cada cenário roda em poucos milissegundos. A sandbox fica com os
## testes de rota e de porta (test_ai01_rota_sandbox e test_portas_sandbox_inimigo).
## Passo de física de 1/60 s (--fixed-fps 60). Autor: AI Engineer (F4-004).

const Fx := preload("res://tests/integration/enemy/fixtures/enemy_test_world.gd")
const SETTLE_FRAMES: int = 8
const MAX_FRAMES: int = 900
const PLAYER_AT: Vector3 = Vector3(0.0, 0.0, -8.0)
const FAR_PLAYER_AT: Vector3 = Vector3(0.0, 0.0, -12.0)
const TARGET_CENTRE_Y: float = 1.0
const EAR_AT: Vector3 = Vector3(20.0, 1.6, 20.0)
const ROOM_FLOOR_DB: float = 12.0
const STEP_DB: float = 40.0
const STEP_SOURCE: Vector3 = Vector3(0.0, 1.6, 0.0)
const HEARING_DISTANCE_M: float = 3.05
const TIME_TOLERANCE_S: float = 0.1


## Mundo isolado com navmesh, um Observer parado em `spawn` (rota de um ponto: o próprio spawn) e um ouvido distante.
func _stationary_world(spawn: Vector3 = Vector3.ZERO) -> Dictionary:
	var world: Node3D = add_isolated_world()
	Fx.navigation_floor(world, 40.0)
	var ear: Node3D = Node3D.new()
	ear.position = EAR_AT
	world.add_child(ear)
	var acoustic: AcousticWorld = Fx.add_acoustic_world(world, ear)
	Fx.add_route(world, &"observer", PackedVector3Array([spawn]))
	var enemy: EnemyController = Fx.spawn_observer(world, spawn)
	await wait_physics_frames(SETTLE_FRAMES)
	return {"world": world, "enemy": enemy, "acoustic": acoustic}


func test_ai02_passo_de_40_db_em_piso_de_12_db_leva_a_investigate_e_chega_a_2_m() -> void:
	# Cômodo com piso ambiente de 12 dB: limiar efetivo do Observer = max(15; 12 − 3) = 15. Passo de 40 dB a 1 m da
	# fonte, ouvido a 3,05 m: 40 − (20·log10(3,05) + 0,1·3,05) = 30,0 dB. Suspeita += 0,04 · (30 − 15) = 0,6 (teto 0,6).
	# O Observer nasce a 3,05 m da fonte (a cabeça, o sensor, a 1,62 m; a fonte, a 1,6 m: distância 3,05 m).
	var setup: Dictionary = await _stationary_world(Vector3(0.0, 0.0, HEARING_DISTANCE_M))
	var world: Node3D = setup["world"] as Node3D
	var enemy: EnemyController = setup["enemy"] as EnemyController
	var acoustic: AcousticWorld = setup["acoustic"] as AcousticWorld
	Fx.add_room(world, &"comodo_teste", Vector3(0.0, 1.5, 0.0), Vector3(12.0, 3.0, 12.0), ROOM_FLOOR_DB)
	var listener: HearingSensor = enemy.get_node("HearingSensor") as HearingSensor
	var listener_pos: Vector3 = listener.global_position
	acoustic.emit_noise(NoiseEvent.create(Enums.NoiseCategory.FOOTSTEP, STEP_SOURCE, STEP_DB, 0.5, &"prop_teste",
		&"footstep_concrete"))
	var went_investigate: bool = false
	var estimate: Vector3 = Vector3.ZERO
	var closest: float = INF
	for frame: int in range(MAX_FRAMES):
		await wait_physics_frames(1)
		var batch: PerceptBatch = enemy.last_batch()
		if batch != null and batch.heard.size() > 0 and estimate == Vector3.ZERO:
			estimate = batch.heard[0].estimated_position
		if enemy.get_state() == Enums.EnemyState.INVESTIGATE:
			went_investigate = true
		if estimate != Vector3.ZERO:
			closest = minf(closest, Vector2(enemy.global_position.x - estimate.x, enemy.global_position.z - estimate.z).length())
		if closest <= 2.0:
			break
	assert_true(listener_pos.distance_to(STEP_SOURCE) > 3.0, "pré-condição: ouvido a ~3,05 m da fonte")
	assert_true(went_investigate, "AI-02: o ruído leva a INVESTIGATE")
	assert_true(estimate != Vector3.ZERO, "o sensor recebeu o som com posição estimada")
	assert_true(closest <= 2.0, "AI-02: chega a ≤ 2 m da posição estimada (mais perto: %.2f m)" % closest)



func test_ai03_observer_em_pe_iluminado_a_8_m_vai_a_chase_em_ate_1_5_s() -> void:
	# Alvo em pé, exposição 1, no FOV, sem oclusão, a 8 m: visibilidade ≈ 0,75; confirmação em ≈ 0,8 s.
	var setup: Dictionary = await _stationary_world()
	var world: Node3D = setup["world"] as Node3D
	var enemy: EnemyController = setup["enemy"] as EnemyController
	Fx.add_target(world, PLAYER_AT, true)
	var chase_frame: int = -1
	for frame: int in range(int(1.5 * 60.0) + 1):
		await wait_physics_frames(1)
		if enemy.get_state() == Enums.EnemyState.CHASE:
			chase_frame = frame + 1
			break
	assert_true(chase_frame > 0, "AI-03: chega a CHASE em até 1,5 s (90 quadros)")
	if chase_frame > 0:
		note("AI-03: CHASE em %d quadros (%.3f s)" % [chase_frame, float(chase_frame) / 60.0])


func test_ai04_linha_quebrada_por_1_5_s_vai_a_lost_contact_e_depois_a_search() -> void:
	# Em CHASE, uma parede entre o inimigo e o alvo quebra a linha de visão. LOST_CONTACT após 1,5 s sem visão; SEARCH
	# quando passam lost_contact_pursuit_s (6 s) sem chegar à última posição (a parede impede o inimigo de chegar).
	var setup: Dictionary = await _stationary_world()
	var world: Node3D = setup["world"] as Node3D
	var enemy: EnemyController = setup["enemy"] as EnemyController
	Fx.add_target(world, PLAYER_AT, true)
	var frames: int = 0
	while enemy.get_state() != Enums.EnemyState.CHASE and frames < MAX_FRAMES:
		await wait_physics_frames(1)
		frames += 1
	assert_eq(enemy.get_state(), Enums.EnemyState.CHASE, "pré-condição: CHASE")
	# A parede entra agora (quadro 0): a partir daqui o sensor não vê o alvo.
	Fx.add_wall(world, Vector3(0.0, 1.5, -4.0), Vector3(4.0, 3.0, 0.2))
	var lost_frame: int = -1
	var search_frame: int = -1
	for frame: int in range(1, MAX_FRAMES):
		await wait_physics_frames(1)
		if enemy.get_state() == Enums.EnemyState.LOST_CONTACT and lost_frame < 0:
			lost_frame = frame
		if enemy.get_state() == Enums.EnemyState.SEARCH:
			search_frame = frame
			break
	assert_true(lost_frame > 0, "AI-04: LOST_CONTACT depois da linha quebrada")
	assert_true(search_frame > 0, "AI-04: depois, SEARCH")
	if lost_frame > 0:
		var lost_s: float = float(lost_frame) / 60.0
		assert_true(absf(lost_s - 1.5) <= TIME_TOLERANCE_S,
			"LOST_CONTACT em ≈ 1,5 s sem visão (medido %.2f s)" % lost_s)
	if lost_frame > 0 and search_frame > 0:
		var lost_to_search: float = float(search_frame - lost_frame) / 60.0
		assert_true(absf(lost_to_search - 6.0) <= TIME_TOLERANCE_S,
			"SEARCH cerca de 6 s depois de LOST_CONTACT (medido %.2f s)" % lost_to_search)


func test_ai05_primeiro_destino_de_lost_contact_fica_a_1_m_da_ultima_posicao_vista() -> void:
	var setup: Dictionary = await _stationary_world()
	var world: Node3D = setup["world"] as Node3D
	var enemy: EnemyController = setup["enemy"] as EnemyController
	# Alvo a 12 m (visibilidade ≈ 0,44, acima de 0,4 para confirmar): com 8 m o inimigo já estaria a 1 m da última posição
	# quando o LOST_CONTACT disparasse, e a regra vai direto a SEARCH no mesmo tick (o LOST_CONTACT nunca apareceria).
	var target: PerceivableTarget = Fx.add_target(world, FAR_PLAYER_AT, true)
	var frames: int = 0
	while enemy.get_state() != Enums.EnemyState.CHASE and frames < MAX_FRAMES:
		await wait_physics_frames(1)
		frames += 1
	assert_eq(enemy.get_state(), Enums.EnemyState.CHASE, "pré-condição: CHASE")
	var last_seen: Vector3 = Vector3(FAR_PLAYER_AT.x, TARGET_CENTRE_Y, FAR_PLAYER_AT.z)
	target.set_concealment(1.0)
	var first_lost_target: Vector3 = Vector3.INF
	for frame: int in range(MAX_FRAMES):
		await wait_physics_frames(1)
		if enemy.get_state() == Enums.EnemyState.LOST_CONTACT:
			var intent: EnemyIntent = enemy.last_intent()
			first_lost_target = intent.move_target
			break
	assert_true(first_lost_target != Vector3.INF, "AI-05: entra em LOST_CONTACT")
	if first_lost_target != Vector3.INF:
		var gap: float = Vector2(first_lost_target.x - last_seen.x, first_lost_target.z - last_seen.z).length()
		assert_true(gap <= 1.0, "AI-05: primeiro destino a ≤ 1 m da última posição vista (%.2f m)" % gap)

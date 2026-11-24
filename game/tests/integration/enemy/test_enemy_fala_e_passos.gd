extends TestCase
## F4-004 (COMPONENT_CONTRACTS §8.1; DATA_STRUCTURES §3 falas e §2.1; PHY-12 do lado do inimigo): fala uma vez por
## transição pelo NoiseEmitter filho (55 dB para a fala, 75 para o grito de perseguição); passos de andar (FOOTSTEP) e
## de perseguição (RUNNING) com a fonte "enemy_observer". Vê os eventos pelo AcousticWorld real (noise_resolved_for_player),
## do mesmo jeito que o jogador e a IA os recebem. Autor: AI Engineer (F4-004).

const Fx := preload("res://tests/integration/enemy/fixtures/enemy_test_world.gd")
const SOURCE: StringName = &"enemy_observer"
const EAR_POSITION: Vector3 = Vector3(5.0, 1.6, 0.0)
const SETTLE_FRAMES: int = 8
const MAX_FRAMES_TO_CHASE: int = 150
const WALK_DB: float = 40.0
const SLOW_DB: float = 32.0
const RUN_DB: float = 60.0
const VOICE_TALK_DB: float = 55.0
const VOICE_SHOUT_DB: float = 75.0
const AUDIBLE_RUN_DB: float = 30.0

var _events: Array[NoiseEvent] = []
var _perceived: Array[float] = []


## Um TestCase serve a todos os testes do arquivo: os eventos são zerados antes de cada um.
func before_each() -> void:
	_events.clear()
	_perceived.clear()


func _on_resolved(event: NoiseEvent, result: PropagationResult) -> void:
	_events.append(event)
	_perceived.append(result.perceived_db)


func _events_from_enemy(category: Enums.NoiseCategory, sound: StringName) -> Array[NoiseEvent]:
	var found: Array[NoiseEvent] = []
	for event: NoiseEvent in _events:
		if event.source_id == SOURCE and event.category == category and event.sound_id == sound:
			found.append(event)
	return found


func _world_with_patrol(walk: bool) -> Dictionary:
	var world: Node3D = add_isolated_world()
	Fx.navigation_floor(world, 20.0)
	var acoustic: AcousticWorld = Fx.add_acoustic_world(world, _ear(world))
	acoustic.noise_resolved_for_player.connect(_on_resolved)
	var route: PackedVector3Array = PackedVector3Array([Vector3.ZERO])
	if walk:
		route = PackedVector3Array([Vector3(0.0, 0.0, 0.0), Vector3(0.0, 0.0, 2.0)])
	Fx.add_route(world, &"observer", route)
	var enemy: EnemyController = Fx.spawn_observer(world, Vector3.ZERO)
	return {"world": world, "acoustic": acoustic, "enemy": enemy}


func _ear(world: Node3D) -> Node3D:
	var ear: Node3D = Node3D.new()
	ear.position = EAR_POSITION
	world.add_child(ear)
	return ear


func test_fala_de_investigacao_sai_uma_vez_a_55_db() -> void:
	# Passo de 40 dB a 3,05 m (AI-02): o Observer vai a INVESTIGATE e fala "voice_investigate" uma vez.
	var setup: Dictionary = _world_with_patrol(false)
	var world: Node3D = setup["world"] as Node3D
	var enemy: EnemyController = setup["enemy"] as EnemyController
	await wait_physics_frames(SETTLE_FRAMES)
	var acoustic: AcousticWorld = setup["acoustic"] as AcousticWorld
	acoustic.emit_noise(NoiseEvent.create(Enums.NoiseCategory.FOOTSTEP, Vector3(0.0, 1.6, 3.05), WALK_DB, 0.5,
		&"prop_teste", &"footstep_concrete"))
	await wait_physics_frames(3)
	assert_eq(enemy.get_state(), Enums.EnemyState.INVESTIGATE, "pré-condição: INVESTIGATE pelo ruído")
	var talks: Array[NoiseEvent] = _events_from_enemy(Enums.NoiseCategory.VOICE, &"voice_investigate")
	assert_eq(talks.size(), 1, "a fala de investigação sai uma vez")
	if talks.size() == 1:
		assert_almost_eq(talks[0].intensity_db, VOICE_TALK_DB, 0.0001, "fala: 55 dB (DATA §2.1)")
	await wait_physics_frames(30)
	assert_eq(_events_from_enemy(Enums.NoiseCategory.VOICE, &"voice_investigate").size(), 1,
		"sem nova transição, a fala não se repete")


func test_grito_de_perseguicao_sai_uma_vez_a_75_db() -> void:
	var setup: Dictionary = _world_with_patrol(false)
	var world: Node3D = setup["world"] as Node3D
	var enemy: EnemyController = setup["enemy"] as EnemyController
	Fx.add_target(world, Vector3(0.0, 0.0, -8.0), true)
	await wait_physics_frames(SETTLE_FRAMES)
	var frames: int = 0
	while enemy.get_state() != Enums.EnemyState.CHASE and frames < MAX_FRAMES_TO_CHASE:
		await wait_physics_frames(1)
		frames += 1
	assert_eq(enemy.get_state(), Enums.EnemyState.CHASE, "pré-condição: CHASE pela visão")
	await wait_physics_frames(3)
	var shouts: Array[NoiseEvent] = _events_from_enemy(Enums.NoiseCategory.VOICE, &"voice_chase_shout")
	assert_eq(shouts.size(), 1, "o grito de perseguição sai uma vez")
	if shouts.size() == 1:
		assert_almost_eq(shouts[0].intensity_db, VOICE_SHOUT_DB, 0.0001, "grito: 75 dB (DATA §2.1)")


func test_passos_de_andar_e_de_perseguicao_com_a_fonte_do_inimigo() -> void:
	# Patrulha a 1,2 m/s (marcha devagar): FOOTSTEP 32 dB, sound footstep_concrete (piso sem metadado). Em CHASE: RUNNING 60 dB,
	# e o ouvido do jogador (5 m) ouve a corrida acima do limiar de 30 dB (PHY-12 do lado do inimigo).
	var setup: Dictionary = _world_with_patrol(true)
	var world: Node3D = setup["world"] as Node3D
	var enemy: EnemyController = setup["enemy"] as EnemyController
	await wait_physics_frames(SETTLE_FRAMES)
	await wait_physics_frames(120)
	var walks: Array[NoiseEvent] = _events_from_enemy(Enums.NoiseCategory.FOOTSTEP, &"footstep_concrete")
	assert_true(walks.size() > 0, "patrulhando, o inimigo produz passos com a fonte enemy_observer")
	if walks.size() > 0:
		assert_almost_eq(walks[0].intensity_db, SLOW_DB, 0.0001, "passo de marcha devagar em concreto: 32 dB")
	Fx.add_target(world, Vector3(0.0, 0.0, -8.0), true)
	var frames: int = 0
	while enemy.get_state() != Enums.EnemyState.CHASE and frames < MAX_FRAMES_TO_CHASE:
		await wait_physics_frames(1)
		frames += 1
	await wait_physics_frames(60)
	var runs: Array[NoiseEvent] = _events_from_enemy(Enums.NoiseCategory.RUNNING, &"footstep_concrete")
	assert_true(runs.size() > 0, "em CHASE, o inimigo corre e produz RUNNING")
	var loudest: float = -INF
	for index: int in range(_events.size()):
		var event: NoiseEvent = _events[index]
		if event.source_id == SOURCE and event.category == Enums.NoiseCategory.RUNNING:
			loudest = maxf(loudest, _perceived[index])
	assert_true(loudest >= AUDIBLE_RUN_DB, "a corrida do inimigo é audível ao jogador (≥ 30 dB; PHY-12)")
	if runs.size() > 0:
		assert_almost_eq(runs[0].intensity_db, RUN_DB, 0.0001, "corrida em concreto: 60 dB (DATA §2.1)")

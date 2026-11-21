extends TestCase
## F3-004 (STL-01 no jogo, ruído de queda, escada sem FALL): dirigindo o jogador em concreto, os passos saem na ordem
## rastejar < agachado < andar < correr < tosse < queda (D-01: mesma superfície). Queda do alto gera FALL; descer a escada
## sintética (dois sentidos de subida e descida, ver stair_cycle) não gera FALL nenhum. Varredura longa: property.
## Autor: Gameplay Engineer.

const PlayerWorld := preload("res://tests/integration/player/fixtures/player_world.gd")
const StairCycle := preload("res://tests/integration/player/fixtures/stair_cycle.gd")
const FRAMES_PER_GAIT: int = 150
const SETTLE_FRAMES: int = 3
const DROP_FRAMES: int = 70
const FLOOR_TOP_Y: float = 0.0
const STAIR_TREAD_M: float = 0.3
const DESCENT_MAX_FRAMES: int = 360
const DESCENT_DONE_Z: float = -0.4

var _events: Array[NoiseEvent] = []


func _on_resolved(event: NoiseEvent, _result: PropagationResult) -> void:
	_events.append(event)


func _floor(root: Node3D) -> void:
	PlayerWorld.add_box(root, Vector3(0.0, -0.5, -5.0), Vector3(8.0, 1.0, 30.0), &"concrete")


func _world(root: Node3D) -> AcousticWorld:
	var world: AcousticWorld = AcousticWorld.new()
	root.add_child(world)
	world.noise_resolved_for_player.connect(_on_resolved)
	return world


func _count(category: Enums.NoiseCategory) -> int:
	var n: int = 0
	for event: NoiseEvent in _events:
		if event.category == category:
			n += 1
	return n


## Média dos níveis dos passos e corridas (FOOTSTEP e RUNNING) de um trecho dirigido.
func _mean_step_level(gait: StringName) -> float:
	var root: Node3D = add_child_autofree(Node3D.new()) as Node3D
	_floor(root)
	_world(root)
	var player: PlayerRoot = PlayerWorld.spawn_player(root, Vector3.ZERO)
	await wait_physics_frames(SETTLE_FRAMES)
	_events.clear()
	var sprint: bool = gait == &"run"
	if gait == &"crawl":
		player.get_motor().set_scripted_input(PlayerWorld.edge_input(false, true))
		await wait_physics_frames(1)
	elif gait == &"crouch":
		player.get_motor().set_scripted_input(PlayerWorld.edge_input(true, false))
		await wait_physics_frames(1)
	player.get_motor().set_scripted_input(PlayerWorld.move_input(Vector2(0.0, 1.0), sprint))
	await wait_physics_frames(FRAMES_PER_GAIT)
	player.get_motor().set_scripted_input(MotorInput.new())
	var total: float = 0.0
	var steps: int = 0
	for event: NoiseEvent in _events:
		if event.category == Enums.NoiseCategory.FOOTSTEP or event.category == Enums.NoiseCategory.RUNNING:
			total += event.intensity_db
			steps += 1
	assert_true(steps >= 2, "%s: dois ou mais passos no trecho (%d)" % [gait, steps])
	return total / float(maxi(steps, 1))


func test_stl01_ordem_dos_sons_do_jogador_em_concreto() -> void:
	var crawl: float = await _mean_step_level(&"crawl")
	var crouch: float = await _mean_step_level(&"crouch")
	var walk: float = await _mean_step_level(&"walk")
	var run: float = await _mean_step_level(&"run")
	var cough: float = BreathEmitter.COUGH_DB
	var fall: float = NoiseLevels.new().fall_db
	note("STL-01 concreto (dB): rastejar %.1f | agachado %.1f | andar %.1f | correr %.1f | tosse %.1f | queda %.1f" % [crawl, crouch, walk, run, cough, fall])
	assert_true(crawl < crouch, "rastejar < agachado")
	assert_true(crouch < walk, "agachado < andar")
	assert_true(walk < run, "andar < correr")
	assert_true(run < cough, "correr < tosse")
	assert_true(cough < fall, "tosse < queda")


func test_queda_do_alto_gera_fall_com_80_db() -> void:
	var root: Node3D = add_child_autofree(Node3D.new()) as Node3D
	_floor(root)
	_world(root)
	var player: PlayerRoot = PlayerWorld.spawn_player(root, Vector3(0.0, 2.0, 0.0))
	await wait_physics_frames(DROP_FRAMES)
	assert_true(_count(Enums.NoiseCategory.FALL) >= 1, "a queda de 2 m gera FALL")
	for event: NoiseEvent in _events:
		if event.category == Enums.NoiseCategory.FALL:
			assert_eq(event.sound_id, &"fall_body", "fall_body")
			assert_almost_eq(event.intensity_db, NoiseLevels.new().fall_db, 0.001, "80 dB")
			break
	assert_true(player.is_on_floor(), "pousou no piso")


func test_descer_a_escada_nao_gera_fall() -> void:
	var root: Node3D = add_child_autofree(Node3D.new()) as Node3D
	var geometry: Dictionary = StairCycle.build_synthetic(root, STAIR_TREAD_M)
	var top: float = float(geometry["top"])
	var platform_start: float = float(geometry["platform_start"])
	_world(root)
	var player: PlayerRoot = PlayerWorld.spawn_player(root, Vector3(0.0, top + 0.02, platform_start - 1.0))
	var landed_speeds: Array[float] = []
	player.get_motor().landed.connect(func(speed: float) -> void: landed_speeds.append(absf(speed)))
	await wait_physics_frames(SETTLE_FRAMES)
	_events.clear()
	player.get_motor().set_scripted_input(PlayerWorld.move_input(Vector2(0.0, -1.0)))
	var frames: int = 0
	while frames < DESCENT_MAX_FRAMES and player.global_position.z < DESCENT_DONE_Z:
		await wait_physics_frames(1)
		frames += 1
	player.get_motor().set_scripted_input(MotorInput.new())
	assert_true(player.global_position.z >= DESCENT_DONE_Z, "desceu a escada (z = %.2f)" % player.global_position.z)
	assert_eq(_count(Enums.NoiseCategory.FALL), 0, "descida de escada: nenhum FALL")
	var max_landing: float = 0.0
	for speed: float in landed_speeds:
		max_landing = maxf(max_landing, speed)
	note("escada: %d aterrissagens, maior velocidade %.2f m/s (limiar %.2f)" % [landed_speeds.size(), max_landing, player.fall_noise.min_fall_speed_mps])
	assert_true(max_landing < player.fall_noise.min_fall_speed_mps, "a maior aterrissagem da escada fica abaixo do limiar de queda")

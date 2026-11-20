extends TestCase
## MOT-04 (TEST_PLAN §2.1): navegação básica com bot por set_scripted_input, num percurso montado por código
## (WorldScript.build_route): vão de 0,6 m rastejando, escada de 8 degraus de 0,18 m e parede que não pode ser
## atravessada. A sandbox F1-009 ainda não existe. Física em tick fixo de 1/60 s.
## Dois testes porque a física headless roda a ~60 ticks/s reais e o runner reprova um teste sem progresso
## por 15 s; cada um monta o próprio mundo. Autor: Gameplay Engineer (F1-006).

const WorldScript := preload("res://tests/integration/player/fixtures/player_world.gd")

const SETTLE_FRAMES: int = 10
const MAX_FRAMES: int = 400
const HEIGHT_TOLERANCE_M: float = 0.01
const CRAWL_HEIGHT_M: float = 0.55
const STAND_HEIGHT_M: float = 1.75
const CROUCH_HEIGHT_M: float = 1.10
const STAIRS_TOP_M: float = 1.44
const CLEAR_OF_SLAB_Z_M: float = -2.6
const PASSED_SLAB_Z_M: float = -2.2
## Trecho sob a laje com o corpo inteiro por baixo (laje em z de -1,9 a -1,5; corpo com raio 0,25).
const UNDER_SLAB_Z_MIN_M: float = -1.85
const UNDER_SLAB_Z_MAX_M: float = -1.55
const WALL_FACE_Z_M: float = -7.9
const CLIMB_TO_Z_M: float = -7.2
const WALL_PUSH_FRAMES: int = 60
const DESCEND_TO_Z_M: float = -3.2
const FLOOR_Y_TOLERANCE_M: float = 0.02

var _previous: Dictionary = {}
var _slab_violations: int = 0
var _airborne_ticks: int = 0


func before_all() -> void:
	Settings.autosave = false


func after_all() -> void:
	Settings.autosave = true


func before_each() -> void:
	_previous = WorldScript.override_settings({&"motion_reduction": 0.0, &"mouse_sensitivity": 0.12, &"invert_y": false, &"fov": 75.0})
	_slab_violations = 0
	_airborne_ticks = 0


func after_each() -> void:
	WorldScript.restore_settings(_previous)


func test_mot04_passa_pelo_vao_de_0_6_m_rastejando() -> void:
	var root: Node3D = add_child_autofree(Node3D.new()) as Node3D
	WorldScript.build_route(root)
	var player: PlayerRoot = WorldScript.spawn_player(root, Vector3(0.0, 0.0, -1.0))
	var motor: PlayerMotor = player.get_motor()
	await wait_physics_frames(SETTLE_FRAMES)
	assert_eq(motor.get_stance(), Enums.Stance.STAND, "começa em pé, antes da laje")

	motor.set_scripted_input(WorldScript.edge_input(false, true))
	await wait_physics_frames(1)
	motor.set_scripted_input(MotorInput.new())
	assert_eq(motor.get_stance(), Enums.Stance.CRAWL, "rastejar antes do vão")

	# Atravessa o vão. Sob a laje, a postura tem de ser CRAWL em todos os ticks.
	var passed: bool = await _walk_until_z(player, PASSED_SLAB_Z_M, Vector2(0.0, 1.0))
	assert_true(passed, "o bot não atravessou o vão (z = %f)" % player.global_position.z)
	assert_eq(_slab_violations, 0, "sob a laje o corpo sempre esteve rastejando (ticks fora da postura: %d)" % _slab_violations)
	assert_eq(motor.get_stance(), Enums.Stance.CRAWL, "depois do vão continua rastejando")

	var clear: bool = await _walk_until_z(player, CLEAR_OF_SLAB_Z_M, Vector2(0.0, 1.0))
	assert_true(clear, "o bot não se afastou da laje")
	# Fora da laje há espaço: rastejar -> agachar -> em pé.
	motor.set_scripted_input(WorldScript.edge_input(false, true))
	await wait_physics_frames(1)
	motor.set_scripted_input(MotorInput.new())
	assert_eq(motor.get_stance(), Enums.Stance.CROUCH, "fora da laje, rastejar -> agachar")
	assert_almost_eq(motor.get_collider_height(), CROUCH_HEIGHT_M, HEIGHT_TOLERANCE_M, "colisor agachado fora da laje")
	motor.set_scripted_input(WorldScript.edge_input(true, false))
	await wait_physics_frames(1)
	motor.set_scripted_input(MotorInput.new())
	assert_eq(motor.get_stance(), Enums.Stance.STAND, "fora da laje, agachar -> em pé")
	assert_almost_eq(motor.get_collider_height(), STAND_HEIGHT_M, HEIGHT_TOLERANCE_M, "colisor em pé fora da laje")


func test_mot04_sobe_escada_de_8_degraus_nao_atravessa_parede_e_desce() -> void:
	var root: Node3D = add_child_autofree(Node3D.new()) as Node3D
	WorldScript.build_route(root)
	var player: PlayerRoot = WorldScript.spawn_player(root, Vector3(0.0, 0.0, -3.0))
	var motor: PlayerMotor = player.get_motor()
	await wait_physics_frames(SETTLE_FRAMES)

	# Sobe a escada e segue até o patamar.
	var climbed: bool = await _walk_until_z(player, CLIMB_TO_Z_M, Vector2(0.0, 1.0))
	assert_true(climbed, "o bot não chegou ao patamar (z = %f, y = %f)" % [player.global_position.z, player.global_position.y])
	assert_almost_eq(player.global_position.y, STAIRS_TOP_M, FLOOR_Y_TOLERANCE_M, "sobre o patamar a 1,44 m")
	assert_eq(_airborne_ticks, 0, "a escada não deixa o corpo sem chão (ticks no ar: %d)" % _airborne_ticks)

	# Empurra a parede: o corpo não pode atravessar a face em z = -7,9.
	motor.set_scripted_input(WorldScript.move_input(Vector2(0.0, 1.0)))
	await wait_physics_frames(WALL_PUSH_FRAMES)
	motor.set_scripted_input(MotorInput.new())
	assert_true(player.global_position.z > WALL_FACE_Z_M, "atravessou a parede (z = %f)" % player.global_position.z)
	assert_almost_eq(player.global_position.y, STAIRS_TOP_M, FLOOR_Y_TOLERANCE_M, "continua sobre o patamar diante da parede")

	# Desce a escada andando para trás.
	var descended: bool = await _walk_until_descended(player)
	assert_true(descended, "o bot não desceu até o piso (z = %f, y = %f)" % [player.global_position.z, player.global_position.y])
	assert_almost_eq(player.global_position.y, 0.0, FLOOR_Y_TOLERANCE_M, "de volta ao piso")
	assert_eq(_airborne_ticks, 0, "a descida também não deixa o corpo no ar (ticks no ar: %d)" % _airborne_ticks)


## Anda com move até z <= target_z (ou esgota MAX_FRAMES). Conta, sob a laje, os ticks fora de CRAWL.
func _walk_until_z(player: PlayerRoot, target_z: float, move: Vector2) -> bool:
	var motor: PlayerMotor = player.get_motor()
	motor.set_scripted_input(WorldScript.move_input(move))
	var frames: int = 0
	while player.global_position.z > target_z and frames < MAX_FRAMES:
		await wait_physics_frames(1)
		frames += 1
		_count_tick(player)
	motor.set_scripted_input(MotorInput.new())
	return player.global_position.z <= target_z


## Anda para trás até voltar ao piso perto da entrada da escada.
func _walk_until_descended(player: PlayerRoot) -> bool:
	var motor: PlayerMotor = player.get_motor()
	motor.set_scripted_input(WorldScript.move_input(Vector2(0.0, -1.0)))
	var frames: int = 0
	while not (player.global_position.z > DESCEND_TO_Z_M and player.global_position.y < 0.2) and frames < MAX_FRAMES:
		await wait_physics_frames(1)
		frames += 1
		_count_tick(player)
	motor.set_scripted_input(MotorInput.new())
	return player.global_position.z > DESCEND_TO_Z_M and player.global_position.y < 0.2


func _count_tick(player: PlayerRoot) -> void:
	var z: float = player.global_position.z
	if z > UNDER_SLAB_Z_MIN_M and z < UNDER_SLAB_Z_MAX_M and player.get_motor().get_stance() != Enums.Stance.CRAWL:
		_slab_violations += 1
	if not player.is_on_floor():
		_airborne_ticks += 1

extends TestCase
## Controles do PlayerMotor em física real (tick fixo de 1/60 s): esforço ao vivo por marcha e postura (MOT-02
## em integração), mouse look com Settings (graus por pixel, invert_y, limite de pitch), head bob com
## motion_reduction e FOV vindo de Settings. Autor: Gameplay Engineer (F1-006).

const WorldScript := preload("res://tests/integration/player/fixtures/player_world.gd")

const EXERTION_TOLERANCE: float = 0.01
const SETTLE_FRAMES: int = 8
const PHASE_FRAMES: int = 30
const IDLE_FRAMES: int = 20
const BOB_FRAMES: int = 60
const BOB_MIN_RANGE_M: float = 0.02
const BOB_FLAT_RANGE_M: float = 0.0005
const SENSITIVITY_DEG: float = 0.12
const LOOK_PX: float = 100.0
const ANGLE_TOLERANCE_RAD: float = 0.0005
const FOV_TOLERANCE_DEG: float = 0.001
const PITCH_LIMIT_DEG: float = 85.0
const EYE_HEIGHT_STAND_M: float = 1.65

var _previous: Dictionary = {}


func before_all() -> void:
	Settings.autosave = false


func after_all() -> void:
	Settings.autosave = true


func before_each() -> void:
	_previous = WorldScript.override_settings({&"motion_reduction": 0.0, &"mouse_sensitivity": SENSITIVITY_DEG, &"invert_y": false, &"fov": 75.0})


func after_each() -> void:
	WorldScript.restore_settings(_previous)


## Mantém uma entrada por frames ticks e volta ao repouso.
func _hold(motor: PlayerMotor, input: MotorInput, frames: int) -> void:
	motor.set_scripted_input(input)
	await wait_physics_frames(frames)
	motor.set_scripted_input(MotorInput.new())


## Um tick com a entrada dada (bordas), depois repouso.
func _tick(motor: PlayerMotor, input: MotorInput) -> void:
	await _hold(motor, input, 1)


func _floor_world(parent: Node3D) -> void:
	WorldScript.add_box(parent, Vector3(0.0, -0.5, -15.0), Vector3(10.0, 1.0, 40.0), &"wood")


func test_exertion_ao_vivo_por_marcha_e_postura() -> void:
	var root: Node3D = add_child_autofree(Node3D.new()) as Node3D
	_floor_world(root)
	var player: PlayerRoot = WorldScript.spawn_player(root, Vector3.ZERO)
	var motor: PlayerMotor = player.get_motor()
	await wait_physics_frames(SETTLE_FRAMES)
	assert_almost_eq(motor.get_exertion(), 0.0, EXERTION_TOLERANCE, "parado, em pé")

	await _hold(motor, WorldScript.move_input(Vector2(0.0, 1.0)), PHASE_FRAMES)
	assert_eq(motor.get_gait(), Enums.Gait.WALK, "andar")
	assert_almost_eq(motor.get_exertion(), 0.2, EXERTION_TOLERANCE, "esforço ao andar")

	await _hold(motor, WorldScript.move_input(Vector2(0.0, 1.0), false, true), PHASE_FRAMES)
	assert_eq(motor.get_gait(), Enums.Gait.SLOW, "andar devagar")
	assert_almost_eq(motor.get_exertion(), 0.1, EXERTION_TOLERANCE, "esforço ao andar devagar")

	await _hold(motor, WorldScript.move_input(Vector2(0.0, 1.0), true, false), PHASE_FRAMES)
	assert_eq(motor.get_gait(), Enums.Gait.SPRINT, "correr")
	assert_almost_eq(motor.get_exertion(), 1.0, EXERTION_TOLERANCE, "esforço ao correr")

	await _hold(motor, MotorInput.new(), IDLE_FRAMES)
	assert_almost_eq(motor.get_exertion(), 0.0, EXERTION_TOLERANCE, "parado depois de correr")

	await _tick(motor, WorldScript.edge_input(true, false))
	assert_eq(motor.get_stance(), Enums.Stance.CROUCH, "agachar em campo aberto")
	await _hold(motor, WorldScript.move_input(Vector2(0.0, 1.0)), PHASE_FRAMES)
	assert_almost_eq(motor.get_exertion(), 0.15, EXERTION_TOLERANCE, "esforço agachado andando")

	await _tick(motor, WorldScript.edge_input(false, true))
	assert_eq(motor.get_stance(), Enums.Stance.CRAWL, "rastejar a partir de agachado")
	await _hold(motor, WorldScript.move_input(Vector2(0.0, 1.0)), PHASE_FRAMES)
	assert_almost_eq(motor.get_exertion(), 0.25, EXERTION_TOLERANCE, "esforço rastejando")


func test_mouse_look_usa_sensibilidade_inversao_e_limite_de_pitch() -> void:
	var root: Node3D = add_child_autofree(Node3D.new()) as Node3D
	_floor_world(root)
	var normal: PlayerRoot = WorldScript.spawn_player(root, Vector3(0.0, 0.0, 0.0))
	await wait_physics_frames(SETTLE_FRAMES)
	var head: Node3D = normal.get_node("Head") as Node3D
	var look_right: MotorInput = MotorInput.new()
	look_right.look_delta = Vector2(LOOK_PX, 0.0)
	await _tick(normal.get_motor(), look_right)
	assert_almost_eq(normal.rotation.y, -deg_to_rad(LOOK_PX * SENSITIVITY_DEG), ANGLE_TOLERANCE_RAD, "mouse para a direita gira o corpo para a direita (12°)")

	var look_up: MotorInput = MotorInput.new()
	look_up.look_delta = Vector2(0.0, -LOOK_PX)
	await _tick(normal.get_motor(), look_up)
	assert_almost_eq(head.rotation.x, deg_to_rad(LOOK_PX * SENSITIVITY_DEG), ANGLE_TOLERANCE_RAD, "mouse para cima olha para cima (12°)")

	# invert_y: o mesmo movimento do mouse inverte o pitch. Jogador novo, para partir de zero.
	WorldScript.override_settings({&"invert_y": true})
	var inverted: PlayerRoot = WorldScript.spawn_player(root, Vector3(8.0, 0.0, 0.0))
	await wait_physics_frames(SETTLE_FRAMES)
	var inverted_head: Node3D = inverted.get_node("Head") as Node3D
	await _tick(inverted.get_motor(), look_up)
	assert_almost_eq(inverted_head.rotation.x, -deg_to_rad(LOOK_PX * SENSITIVITY_DEG), ANGLE_TOLERANCE_RAD, "com invert_y, mouse para cima olha para baixo")

	var look_far: MotorInput = MotorInput.new()
	look_far.look_delta = Vector2(0.0, 100000.0)
	await _tick(inverted.get_motor(), look_far)
	assert_almost_eq(inverted_head.rotation.x, deg_to_rad(PITCH_LIMIT_DEG), ANGLE_TOLERANCE_RAD, "pitch limitado a 85°")


func test_head_bob_zerado_com_reducao_total_de_movimento() -> void:
	var root: Node3D = add_child_autofree(Node3D.new()) as Node3D
	_floor_world(root)
	var player: PlayerRoot = WorldScript.spawn_player(root, Vector3.ZERO)
	var motor: PlayerMotor = player.get_motor()
	var head: Node3D = player.get_node("Head") as Node3D
	await wait_physics_frames(SETTLE_FRAMES)

	WorldScript.override_settings({&"motion_reduction": 1.0})
	var still_range: float = await _sample_head_range(motor, head)
	assert_true(still_range < BOB_FLAT_RANGE_M, "com motion_reduction 1,0 a cabeça não balança (amplitude %f m)" % still_range)
	assert_almost_eq(head.position.y, EYE_HEIGHT_STAND_M, BOB_FLAT_RANGE_M, "altura dos olhos em pé sem balanço")

	WorldScript.override_settings({&"motion_reduction": 0.0})
	var bob_range: float = await _sample_head_range(motor, head)
	assert_true(bob_range > BOB_MIN_RANGE_M, "com motion_reduction 0,0 o head bob aparece (amplitude %f m)" % bob_range)


## Anda para a frente BOB_FRAMES ticks e devolve a amplitude (max - min) da altura da cabeça.
func _sample_head_range(motor: PlayerMotor, head: Node3D) -> float:
	motor.set_scripted_input(WorldScript.move_input(Vector2(0.0, 1.0)))
	var low: float = INF
	var high: float = -INF
	for _frame: int in BOB_FRAMES:
		await wait_physics_frames(1)
		low = minf(low, head.position.y)
		high = maxf(high, head.position.y)
	motor.set_scripted_input(MotorInput.new())
	return high - low


func test_fov_vem_das_opcoes_e_acompanha_a_mudanca() -> void:
	WorldScript.override_settings({&"fov": 90.0})
	var root: Node3D = add_child_autofree(Node3D.new()) as Node3D
	_floor_world(root)
	var player: PlayerRoot = WorldScript.spawn_player(root, Vector3.ZERO)
	var camera: Camera3D = player.get_node("Head/Camera3D") as Camera3D
	await wait_physics_frames(2)
	assert_almost_eq(camera.fov, 90.0, FOV_TOLERANCE_DEG, "FOV inicial vem de Settings.fov")
	Settings.set_value(&"fov", 60.0)
	assert_almost_eq(camera.fov, 60.0, FOV_TOLERANCE_DEG, "mudar Settings.fov atualiza a câmera")

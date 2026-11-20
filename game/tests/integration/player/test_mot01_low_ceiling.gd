extends TestCase
## MOT-01 (TEST_PLAN §2.1, MOT-INV-1): não fica em pé nem agachado sob teto baixo. Integração com física real,
## laje com face inferior a 0,6 m e bot por set_scripted_input. Passos em tick fixo (1/60 s).
## Autor: Gameplay Engineer (F1-006).

const WorldScript := preload("res://tests/integration/player/fixtures/player_world.gd")

const SLAB_UNDERSIDE_M: float = 0.6
const SLAB_THICKNESS_M: float = 0.05
## Laje rasa, com a entrada em z = +0,2 e a saída em z = -0,2.
const SLAB_DEPTH_M: float = 0.4
const SPAWN_Z_M: float = 0.6
const CRAWL_HEIGHT_M: float = 0.55
const STAND_HEIGHT_M: float = 1.75
const CROUCH_HEIGHT_M: float = 1.10
const HEIGHT_TOLERANCE_M: float = 0.001
const SETTLE_FRAMES: int = 10
const MAX_WALK_FRAMES: int = 400

var _previous: Dictionary = {}


func before_all() -> void:
	Settings.autosave = false


func after_all() -> void:
	Settings.autosave = true


func before_each() -> void:
	_previous = WorldScript.override_settings({&"motion_reduction": 0.0, &"mouse_sensitivity": 0.12, &"invert_y": false, &"fov": 75.0})


func after_each() -> void:
	WorldScript.restore_settings(_previous)


## Mesa de 4 m × 0,4 m com face inferior a 0,6 m, sobre piso de madeira.
func _build_table_world(parent: Node3D) -> void:
	WorldScript.add_box(parent, Vector3(0.0, -0.5, -5.0), Vector3(6.0, 1.0, 16.0), &"wood")
	WorldScript.add_box(parent, Vector3(0.0, SLAB_UNDERSIDE_M + SLAB_THICKNESS_M * 0.5, 0.0),
		Vector3(4.0, SLAB_THICKNESS_M, SLAB_DEPTH_M))


## Um tick com a entrada dada (o bot injeta e volta ao repouso no fim).
func _drive(motor: PlayerMotor, input: MotorInput, ticks: int) -> void:
	motor.set_scripted_input(input)
	await wait_physics_frames(ticks)
	motor.set_scripted_input(MotorInput.new())


## Anda para a frente até z <= target_z (ou esgota o limite). Retorna se chegou.
func _walk_until_z(player: PlayerRoot, target_z: float) -> bool:
	player.get_motor().set_scripted_input(WorldScript.move_input(Vector2(0.0, 1.0)))
	var frames: int = 0
	while player.global_position.z > target_z and frames < MAX_WALK_FRAMES:
		await wait_physics_frames(1)
		frames += 1
	player.get_motor().set_scripted_input(MotorInput.new())
	return player.global_position.z <= target_z


func test_mot01_levantar_sob_a_laje_nao_muda_a_postura() -> void:
	var root: Node3D = add_child_autofree(Node3D.new()) as Node3D
	_build_table_world(root)
	var player: PlayerRoot = WorldScript.spawn_player(root, Vector3(0.0, 0.0, SPAWN_Z_M))
	var motor: PlayerMotor = player.get_motor()
	await wait_physics_frames(SETTLE_FRAMES)
	assert_eq(motor.get_stance(), Enums.Stance.STAND, "começa em pé, fora da laje")

	await _drive(motor, WorldScript.edge_input(false, true), 1)
	assert_eq(motor.get_stance(), Enums.Stance.CRAWL, "rastejar troca para CRAWL")
	assert_almost_eq(motor.get_collider_height(), CRAWL_HEIGHT_M, HEIGHT_TOLERANCE_M, "colisor de rastejar")

	var reached: bool = await _walk_until_z(player, 0.0)
	assert_true(reached, "o bot não chegou ao centro do vão")
	assert_eq(motor.get_stance(), Enums.Stance.CRAWL, "no centro do vão continua rastejando")

	# Três tentativas de levantar sob a laje (crouch e crawl): a postura não pode mudar.
	for _attempt: int in 3:
		await _drive(motor, WorldScript.edge_input(true, false), 1)
		await _drive(motor, WorldScript.edge_input(false, true), 1)
	assert_eq(motor.get_stance(), Enums.Stance.CRAWL, "levantar sob a laje não muda a postura")
	assert_almost_eq(motor.get_collider_height(), CRAWL_HEIGHT_M, HEIGHT_TOLERANCE_M, "colisor continua baixo sob a laje")

	# Sai do vão e volta a ter espaço: agora as trocas de postura passam.
	var out: bool = await _walk_until_z(player, -0.5)
	assert_true(out, "o bot não saiu do vão")
	await _drive(motor, WorldScript.edge_input(false, true), 1)
	assert_eq(motor.get_stance(), Enums.Stance.CROUCH, "fora do vão, rastejar -> agachar (com espaço)")
	assert_almost_eq(motor.get_collider_height(), CROUCH_HEIGHT_M, HEIGHT_TOLERANCE_M, "colisor agachado")
	await _drive(motor, WorldScript.edge_input(true, false), 1)
	assert_eq(motor.get_stance(), Enums.Stance.STAND, "fora do vão, agachar -> em pé (com espaço)")
	assert_almost_eq(motor.get_collider_height(), STAND_HEIGHT_M, HEIGHT_TOLERANCE_M, "colisor em pé")


func test_mot01_agachado_nao_entra_sob_a_laje() -> void:
	var root: Node3D = add_child_autofree(Node3D.new()) as Node3D
	_build_table_world(root)
	var player: PlayerRoot = WorldScript.spawn_player(root, Vector3(0.0, 0.0, SPAWN_Z_M))
	var motor: PlayerMotor = player.get_motor()
	await wait_physics_frames(SETTLE_FRAMES)
	await _drive(motor, WorldScript.edge_input(true, false), 1)
	assert_eq(motor.get_stance(), Enums.Stance.CROUCH, "agachar em campo aberto")

	# Anda 75 ticks: a face da laje (z = +0,2) tem de bloquear o corpo de 1,10 m antes do vão.
	motor.set_scripted_input(WorldScript.move_input(Vector2(0.0, 1.0)))
	await wait_physics_frames(75)
	motor.set_scripted_input(MotorInput.new())
	assert_true(player.global_position.z > 0.4, "agachado entrou sob a laje (z = %f)" % player.global_position.z)
	assert_eq(motor.get_stance(), Enums.Stance.CROUCH, "a postura agachada se mantém diante da laje")

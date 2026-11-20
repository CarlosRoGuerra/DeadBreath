extends TestCase
## Integração do PlayerMotor: landed (ar -> chão, com a velocidade de impacto), footstep com a superfície do
## metadado "surface" do piso e nenhum passo no ar. Faixas paralelas no mesmo mundo, física em tick fixo.
## Autor: Gameplay Engineer (F1-006).

const WorldScript := preload("res://tests/integration/player/fixtures/player_world.gd")

const GRAVITY_MS2: float = 9.8
const DROP_HEIGHT_M: float = 1.0
## Impacto de uma queda de 1 m: sqrt(2 g h) = 4,43 m/s. Tolerância cobre um tick de gravidade (0,16 m/s).
const IMPACT_TOLERANCE_MS: float = 0.25
const SETTLE_FRAMES: int = 6
const LANE_TILE_X: float = 4.0
const LANE_DEFAULT_X: float = 8.0
const LANE_DROP_X: float = -4.0
const LANE_STILL_X: float = 0.0
const LANE_AIR_X: float = 12.0
const WALK_FRAMES: int = 75
const AIR_DROP_HEIGHT_M: float = 1.5
const TILE: StringName = &"tile"

var _previous: Dictionary = {}
var _air_landed: bool = false
var _air_steps: int = 0


func before_all() -> void:
	Settings.autosave = false


func after_all() -> void:
	Settings.autosave = true


func before_each() -> void:
	_previous = WorldScript.override_settings({&"motion_reduction": 0.0, &"mouse_sensitivity": 0.12, &"invert_y": false, &"fov": 75.0})


func after_each() -> void:
	WorldScript.restore_settings(_previous)


func test_landed_informa_a_velocidade_de_impacto_de_uma_queda() -> void:
	var root: Node3D = add_child_autofree(Node3D.new()) as Node3D
	WorldScript.add_lane_floor(root, LANE_DROP_X)
	var player: PlayerRoot = WorldScript.spawn_player(root, Vector3(LANE_DROP_X, DROP_HEIGHT_M, 0.0))
	var speeds: Array[float] = []
	player.get_motor().landed.connect(func(fall_speed: float) -> void: speeds.append(fall_speed))
	await wait_physics_frames(60)
	assert_eq(speeds.size(), 1, "landed deve ser emitido uma vez na queda")
	if speeds.size() == 1:
		var expected: float = sqrt(2.0 * GRAVITY_MS2 * DROP_HEIGHT_M)
		assert_almost_eq(speeds[0], expected, IMPACT_TOLERANCE_MS, "velocidade de impacto de uma queda de 1 m")
	assert_true(player.get_motor().get_stance() == Enums.Stance.STAND, "a queda não muda a postura")


func test_landed_nao_dispara_quando_nasce_no_chao() -> void:
	var root: Node3D = add_child_autofree(Node3D.new()) as Node3D
	WorldScript.add_lane_floor(root, LANE_STILL_X)
	var player: PlayerRoot = WorldScript.spawn_player(root, Vector3(LANE_STILL_X, 0.0, 0.0))
	var landings: Array[float] = []
	player.get_motor().landed.connect(func(fall_speed: float) -> void: landings.append(fall_speed))
	await wait_physics_frames(30)
	assert_eq(landings.size(), 0, "nascer apoiado no chão não é aterrissagem")


func test_footstep_usa_a_superficie_do_metadado() -> void:
	var root: Node3D = add_child_autofree(Node3D.new()) as Node3D
	WorldScript.add_lane_floor(root, LANE_TILE_X, TILE)
	var player: PlayerRoot = WorldScript.spawn_player(root, Vector3(LANE_TILE_X, 0.0, 0.0))
	var surfaces: Array[StringName] = []
	var gaits: Array[int] = []
	player.get_motor().footstep.connect(func(surface: StringName, gait: Enums.Gait, _stance: Enums.Stance) -> void:
		surfaces.append(surface)
		gaits.append(int(gait)))
	await wait_physics_frames(SETTLE_FRAMES)
	player.get_motor().set_scripted_input(WorldScript.move_input(Vector2(0.0, 1.0)))
	await wait_physics_frames(WALK_FRAMES)
	player.get_motor().set_scripted_input(MotorInput.new())
	assert_true(surfaces.size() >= 2, "andar 1,3 m a 1,6 m/s deve gerar pelo menos 2 passos (obtido %d)" % surfaces.size())
	for surface: StringName in surfaces:
		assert_eq(surface, TILE, "superfície do passo vem do metadado")
	for gait: int in gaits:
		assert_eq(gait, int(Enums.Gait.WALK), "marcha informada no passo")


func test_footstep_sem_metadado_usa_default() -> void:
	var root: Node3D = add_child_autofree(Node3D.new()) as Node3D
	WorldScript.add_lane_floor(root, LANE_DEFAULT_X)
	var player: PlayerRoot = WorldScript.spawn_player(root, Vector3(LANE_DEFAULT_X, 0.0, 0.0))
	var surfaces: Array[StringName] = []
	player.get_motor().footstep.connect(func(surface: StringName, _gait: Enums.Gait, _stance: Enums.Stance) -> void: surfaces.append(surface))
	await wait_physics_frames(SETTLE_FRAMES)
	player.get_motor().set_scripted_input(WorldScript.move_input(Vector2(0.0, 1.0)))
	await wait_physics_frames(WALK_FRAMES)
	player.get_motor().set_scripted_input(MotorInput.new())
	assert_true(surfaces.size() >= 1, "deve haver passo")
	for surface: StringName in surfaces:
		assert_eq(surface, &"default", "piso sem metadado usa 'default'")


func _on_air_landed(_fall_speed: float) -> void:
	_air_landed = true


func _on_air_footstep(_surface: StringName, _gait: Enums.Gait, _stance: Enums.Stance) -> void:
	if not _air_landed:
		_air_steps += 1


func test_footstep_nao_dispara_no_ar() -> void:
	var root: Node3D = add_child_autofree(Node3D.new()) as Node3D
	WorldScript.add_lane_floor(root, LANE_AIR_X)
	var player: PlayerRoot = WorldScript.spawn_player(root, Vector3(LANE_AIR_X, AIR_DROP_HEIGHT_M, 0.0))
	var motor: PlayerMotor = player.get_motor()
	_air_landed = false
	_air_steps = 0
	motor.landed.connect(_on_air_landed)
	motor.footstep.connect(_on_air_footstep)
	motor.set_scripted_input(WorldScript.move_input(Vector2(0.0, 1.0)))
	# A queda de 1,5 m dura cerca de 33 ticks; o passo só pode aparecer depois da aterrissagem.
	await wait_physics_frames(WALK_FRAMES)
	motor.set_scripted_input(MotorInput.new())
	assert_true(_air_landed, "o jogador deve ter aterrissado")
	assert_eq(_air_steps, 0, "nenhum passo antes da aterrissagem")

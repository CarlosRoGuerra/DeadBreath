extends TestCase
## Step-up (COMPONENT_CONTRACTS §2; spike V6, ENGINE_DECISION §7.1): sobe degraus até step_height = 0,30 m
## e bloqueia acima disso. Faixas paralelas (x diferente) no mesmo mundo; os jogadores não colidem entre si.
## Física em tick fixo de 1/60 s. Autor: Gameplay Engineer (F1-006).

const WorldScript := preload("res://tests/integration/player/fixtures/player_world.gd")

const SETTLE_FRAMES: int = 8
## 75 ticks a 1,6 m/s (com aceleração) levam o corpo para o patamar, depois da face em z = -1.
const CLIMB_FRAMES: int = 75
const SETTLE_AFTER_CLIMB_FRAMES: int = 30
const HEIGHT_TOLERANCE_M: float = 0.01
const BLOCKED_HEIGHT_MAX_M: float = 0.05
const FACE_Z_M: float = -1.0
## A câmera absorve o degrau (contrato §2): sem a absorção, a cabeça subiria o degrau inteiro num tick.
const CAMERA_MAX_JUMP_PER_TICK_M: float = 0.06
const CAMERA_CONVERGED_TOLERANCE_M: float = 0.01
const EYE_OFFSET_M: float = 0.10
const STAND_HEIGHT_M: float = 1.75

var _previous: Dictionary = {}
var _max_head_jump: Array[float] = []


func before_all() -> void:
	Settings.autosave = false


func after_all() -> void:
	Settings.autosave = true


func before_each() -> void:
	_previous = WorldScript.override_settings({&"motion_reduction": 0.0, &"mouse_sensitivity": 0.12, &"invert_y": false, &"fov": 75.0})


func after_each() -> void:
	WorldScript.restore_settings(_previous)


## Monta uma faixa por degrau e anda todos para a frente por CLIMB_FRAMES ticks. Devolve os jogadores e,
## em _max_head_jump, a maior variação num tick da altura global da cabeça de cada jogador.
func _run_lanes(root: Node3D, step_heights: Array[float], lane_x: Array[float]) -> Array[PlayerRoot]:
	var players: Array[PlayerRoot] = []
	for index: int in step_heights.size():
		WorldScript.add_lane_floor(root, lane_x[index])
		WorldScript.add_lane_step(root, lane_x[index], step_heights[index])
		players.append(WorldScript.spawn_player(root, Vector3(lane_x[index], 0.0, 0.0)))
	await wait_physics_frames(SETTLE_FRAMES)
	_max_head_jump = []
	var last_head_y: Array[float] = []
	for player: PlayerRoot in players:
		player.get_motor().set_scripted_input(WorldScript.move_input(Vector2(0.0, 1.0)))
		_max_head_jump.append(0.0)
		last_head_y.append((player.get_node("Head") as Node3D).global_position.y)
	for _frame: int in CLIMB_FRAMES:
		await wait_physics_frames(1)
		for index: int in players.size():
			var head_y: float = (players[index].get_node("Head") as Node3D).global_position.y
			_max_head_jump[index] = maxf(_max_head_jump[index], absf(head_y - last_head_y[index]))
			last_head_y[index] = head_y
	# Para o bot e espera o head bob zerar (o balanço de andar soma até ±0,03 m à altura da cabeça).
	for player: PlayerRoot in players:
		player.get_motor().set_scripted_input(MotorInput.new())
	await wait_physics_frames(SETTLE_AFTER_CLIMB_FRAMES)
	return players


func test_step_up_sobe_degraus_ate_0_30_m() -> void:
	var root: Node3D = add_child_autofree(Node3D.new()) as Node3D
	var heights: Array[float] = [0.10, 0.25, 0.30]
	var lanes: Array[float] = [-4.0, 0.0, 4.0]
	var players: Array[PlayerRoot] = await _run_lanes(root, heights, lanes)
	for index: int in heights.size():
		var player: PlayerRoot = players[index]
		var label: String = "degrau %.2f m" % heights[index]
		assert_almost_eq(player.global_position.y, heights[index], HEIGHT_TOLERANCE_M, label + ": altura final sobre o degrau")
		assert_true(player.global_position.z < FACE_Z_M, "%s: não passou da face do degrau (z = %f)" % [label, player.global_position.z])
		assert_true(_max_head_jump[index] < CAMERA_MAX_JUMP_PER_TICK_M,
			"%s: a câmera subiu %f m num tick (a absorção deveria suavizar)" % [label, _max_head_jump[index]])
		var head: Node3D = player.get_node("Head") as Node3D
		var eye_target: float = player.global_position.y + STAND_HEIGHT_M - EYE_OFFSET_M
		assert_almost_eq(head.global_position.y, eye_target, CAMERA_CONVERGED_TOLERANCE_M, label + ": a câmera converge para a altura dos olhos")


func test_step_up_bloqueia_degraus_acima_de_0_30_m() -> void:
	var root: Node3D = add_child_autofree(Node3D.new()) as Node3D
	var heights: Array[float] = [0.31, 0.35]
	var lanes: Array[float] = [-4.0, 0.0]
	var players: Array[PlayerRoot] = await _run_lanes(root, heights, lanes)
	for index: int in heights.size():
		var player: PlayerRoot = players[index]
		var label: String = "degrau %.2f m" % heights[index]
		assert_true(player.global_position.y < BLOCKED_HEIGHT_MAX_M, "%s: subiu sem permissão (y = %f)" % [label, player.global_position.y])
		assert_true(player.global_position.z > FACE_Z_M, "%s: atravessou a face (z = %f)" % [label, player.global_position.z])

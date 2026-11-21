extends TestCase
## BUG-003 (F1-010 R1-03): a altura da câmera acompanha a do corpo em rampa. Rampas de 10°, 20° e 30°, andando e
## correndo, subindo e descendo, em mundo de física próprio. Critério: erro ≤ 1 cm entre a altura global dos olhos e
## (corpo + 1,65 m) em regime (sobre a rampa, sem contar a entrada e a saída). motion_reduction = 1 zera o head bob,
## para medir só a compensação. Autor: Gameplay Engineer (F1-010).

const Stair := preload("res://tests/integration/player/fixtures/stair_cycle.gd")
const WorldScript := preload("res://tests/integration/player/fixtures/player_world.gd")

const RAMP_LEN_M: float = 8.0
const RAMP_THICKNESS_M: float = 0.2
const EYE_ABOVE_BODY_M: float = 1.65
const TOLERANCE_M: float = 0.01
const STEADY_FROM_Z: float = -6.0
const STEADY_TO_Z: float = -1.0
const WALK_FRAMES: int = 500
const LOCKED_SETTLE_FRAMES: int = 6

var _previous: Dictionary = {}


func before_all() -> void:
	Settings.autosave = false


func after_all() -> void:
	Settings.autosave = true


func before_each() -> void:
	_previous = WorldScript.override_settings({&"motion_reduction": 1.0, &"mouse_sensitivity": 0.12, &"invert_y": false, &"fov": 75.0})


func after_each() -> void:
	WorldScript.restore_settings(_previous)


## Piso plano em z de -1 a +5 (topo em y = 0) e uma rampa de angle_deg começando em z = 0, subindo para -Z.
func _build_ramp(root: Node3D, angle_deg: float) -> void:
	WorldScript.add_box(root, Vector3(0.0, -0.5, 2.0), Vector3(2.4, 1.0, 6.0), &"wood")
	var theta: float = deg_to_rad(angle_deg)
	var direction: Vector3 = Vector3(0.0, sin(theta), -cos(theta))
	var normal: Vector3 = Vector3(0.0, cos(theta), sin(theta))
	var center: Vector3 = direction * (RAMP_LEN_M * 0.5) - normal * (RAMP_THICKNESS_M * 0.5)
	var ramp: StaticBody3D = WorldScript.add_box(root, center, Vector3(2.4, RAMP_THICKNESS_M, RAMP_LEN_M), &"wood")
	ramp.rotation.x = theta


func _ramp_height(angle_deg: float, z: float) -> float:
	return -z * tan(deg_to_rad(angle_deg))


## Anda com move_y por WALK_FRAMES ticks (ou até sair da janela) e devolve o maior erro da câmera na janela de regime.
func _measure(player: PlayerRoot, head: Node3D, move_y: float, sprint: bool) -> float:
	player.get_motor().set_scripted_input(WorldScript.move_input(Vector2(0.0, move_y), sprint))
	var worst: float = 0.0
	var samples: int = 0
	for _frame: int in WALK_FRAMES:
		await wait_physics_frames(1)
		var z: float = player.global_position.z
		if z > STEADY_FROM_Z and z < STEADY_TO_Z:
			var error: float = head.global_position.y - (player.global_position.y + EYE_ABOVE_BODY_M)
			worst = maxf(worst, absf(error))
			samples += 1
		if (move_y < 0.0 and z > STEADY_TO_Z + 1.0) or (move_y > 0.0 and z < STEADY_FROM_Z - 1.0):
			break
	player.get_motor().set_scripted_input(MotorInput.new())
	assert_true(samples > 20, "amostras em regime suficientes (%d)" % samples)
	note("erro máximo da câmera em regime: %.4f m (%d amostras)" % [worst, samples])
	return worst


func _run_angle(angle_deg: float) -> void:
	var viewport: SubViewport = Stair.new_isolated_viewport(self)
	var root: Node3D = Node3D.new()
	viewport.add_child(root)
	_build_ramp(root, angle_deg)
	var player: PlayerRoot = WorldScript.spawn_player(root, Vector3(0.0, 0.0, 1.0))
	var head: Node3D = player.get_node("Head") as Node3D
	await wait_physics_frames(LOCKED_SETTLE_FRAMES)

	var label: String = "rampa %.0f°" % angle_deg
	var walk_up: float = await _measure(player, head, 1.0, false)
	assert_true(walk_up <= TOLERANCE_M, "%s andando, subindo: erro da câmera %.4f m" % [label, walk_up])
	# Volta ao piso e sobe correndo.
	player.teleport_to(Vector3(0.0, 0.0, 1.0))
	await wait_physics_frames(LOCKED_SETTLE_FRAMES)
	var run_up: float = await _measure(player, head, 1.0, true)
	assert_true(run_up <= TOLERANCE_M, "%s correndo, subindo: erro da câmera %.4f m" % [label, run_up])

	# Descida: começa no topo da rampa e anda para trás (+Z).
	var top_z: float = -RAMP_LEN_M + 1.5
	player.teleport_to(Vector3(0.0, _ramp_height(angle_deg, top_z), top_z))
	await wait_physics_frames(LOCKED_SETTLE_FRAMES)
	var walk_down: float = await _measure(player, head, -1.0, false)
	assert_true(walk_down <= TOLERANCE_M, "%s andando, descendo: erro da câmera %.4f m" % [label, walk_down])
	player.teleport_to(Vector3(0.0, _ramp_height(angle_deg, top_z), top_z))
	await wait_physics_frames(LOCKED_SETTLE_FRAMES)
	var run_down: float = await _measure(player, head, -1.0, true)
	assert_true(run_down <= TOLERANCE_M, "%s correndo, descendo: erro da câmera %.4f m" % [label, run_down])
	Stair.discard_viewport(viewport)


func test_camera_rampa_10_graus() -> void:
	await _run_angle(10.0)


func test_camera_rampa_20_graus() -> void:
	await _run_angle(20.0)


func test_camera_rampa_30_graus() -> void:
	await _run_angle(30.0)

extends TestCase
## F1-007 (COMPONENT_CONTRACTS §3, Door): toque abre rápido, segurar abre devagar, porta trancada dá
## feedback por sinal, e a porta fechada bloqueia o corpo do jogador (camada 2) até abrir.
## Física em tick fixo de 1/60 s. Autor: Gameplay Engineer.

const InteractionWorld := preload("res://tests/integration/interaction/fixtures/interaction_world.gd")
const PlayerWorld := preload("res://tests/integration/player/fixtures/player_world.gd")

const SETTLE_FRAMES: int = 6
const PRESS_FRAMES: int = 2
const FAST_DONE_FRAMES: int = 30
const SLOW_BEFORE_FRAMES: int = 20
const SLOW_MID_FRAMES: int = 30
const SLOW_DONE_FRAMES: int = 120
const WALK_BLOCKED_FRAMES: int = 60
const WALK_THROUGH_FRAMES: int = 120
const OPEN_ANGLE_OK_DEG: float = 85.0
const SLOW_MID_MIN_DEG: float = 5.0
const SLOW_MID_MAX_DEG: float = 60.0
## Hinge da porta em x = -0,45: o vão fica centrado em x = 0, a 2 m do centro do corredor.
const DOOR_POSITION: Vector3 = Vector3(-0.45, 0.0, -2.0)
const PLAYER_START_Z: float = -0.8
const BLOCKED_Z_MAX: float = -1.8
const THROUGH_Z_MAX: float = -2.5

var _previous: Dictionary = {}
var _slow_flags: Array[bool] = []
var _feedback_count: int = 0


func before_all() -> void:
	Settings.autosave = false


func after_all() -> void:
	Settings.autosave = true


func before_each() -> void:
	_previous = PlayerWorld.override_settings({&"motion_reduction": 0.0, &"mouse_sensitivity": 0.12, &"invert_y": false, &"fov": 75.0})
	_slow_flags.clear()
	_feedback_count = 0


func after_each() -> void:
	PlayerWorld.restore_settings(_previous)


func _on_opened(slow: bool) -> void:
	_slow_flags.append(slow)


func _on_locked_feedback(_actor: Node) -> void:
	_feedback_count += 1


func _world(root: Node3D) -> void:
	PlayerWorld.add_box(root, Vector3(0.0, -0.5, -5.0), Vector3(6.0, 1.0, 16.0), &"wood")


func test_toque_abre_a_porta_rapido() -> void:
	var root: Node3D = add_child_autofree(Node3D.new()) as Node3D
	_world(root)
	var player: PlayerRoot = PlayerWorld.spawn_player(root, Vector3(0.0, 0.0, PLAYER_START_Z))
	var door: Door = InteractionWorld.spawn_door(root, DOOR_POSITION)
	door.opened.connect(_on_opened)
	await wait_physics_frames(SETTLE_FRAMES)
	assert_eq(player.get_interaction().get_focused(), door, "porta em foco a 1,2 m")
	player.get_interaction().press_interact()
	await wait_physics_frames(PRESS_FRAMES)
	player.get_interaction().release_interact()
	await wait_physics_frames(FAST_DONE_FRAMES)
	assert_eq(door.get_state(), Door.State.OPEN, "toque deixa a porta aberta")
	assert_false(door.is_moving(), "a abertura rápida já terminou em 0,5 s")
	assert_true(door.get_panel_angle_deg() >= OPEN_ANGLE_OK_DEG, "abertura completa (obtido %f graus)" % door.get_panel_angle_deg())
	assert_eq(_slow_flags, [false] as Array[bool], "opened(slow = false) no toque")


func test_segurar_abre_a_porta_devagar() -> void:
	var root: Node3D = add_child_autofree(Node3D.new()) as Node3D
	_world(root)
	var player: PlayerRoot = PlayerWorld.spawn_player(root, Vector3(0.0, 0.0, PLAYER_START_Z))
	var door: Door = InteractionWorld.spawn_door(root, DOOR_POSITION)
	door.opened.connect(_on_opened)
	await wait_physics_frames(SETTLE_FRAMES)
	player.get_interaction().press_interact()
	# Antes do limiar de segurar (0,35 s) a porta não se mexe.
	await wait_physics_frames(SLOW_BEFORE_FRAMES)
	assert_eq(door.get_state(), Door.State.CLOSED, "antes de 0,35 s segurando a porta continua fechada")
	# Depois do limiar: abertura lenta, ainda na metade do caminho (1,6 s) meio segundo depois.
	await wait_physics_frames(SLOW_MID_FRAMES)
	assert_true(door.is_moving(), "segurando, a porta está abrindo")
	var mid_angle: float = door.get_panel_angle_deg()
	assert_true(mid_angle > SLOW_MID_MIN_DEG and mid_angle < SLOW_MID_MAX_DEG,
		"abertura lenta: ângulo intermediário fora da faixa (obtido %f graus)" % mid_angle)
	player.get_interaction().release_interact()
	await wait_physics_frames(SLOW_DONE_FRAMES)
	assert_true(door.get_panel_angle_deg() >= OPEN_ANGLE_OK_DEG, "a abertura lenta termina aberta (obtido %f graus)" % door.get_panel_angle_deg())
	assert_eq(_slow_flags, [true] as Array[bool], "opened(slow = true) ao segurar")


func test_porta_trancada_dá_feedback_e_nao_abre() -> void:
	var root: Node3D = add_child_autofree(Node3D.new()) as Node3D
	_world(root)
	var player: PlayerRoot = PlayerWorld.spawn_player(root, Vector3(0.0, 0.0, PLAYER_START_Z))
	var door: Door = InteractionWorld.spawn_door(root, DOOR_POSITION)
	door.locked_feedback.connect(_on_locked_feedback)
	door.opened.connect(_on_opened)
	door.lock()
	await wait_physics_frames(SETTLE_FRAMES)
	assert_eq(door.get_state(), Door.State.LOCKED, "porta trancada")
	player.get_interaction().press_interact()
	await wait_physics_frames(PRESS_FRAMES)
	player.get_interaction().release_interact()
	await wait_physics_frames(FAST_DONE_FRAMES)
	assert_eq(_feedback_count, 1, "toque em porta trancada emite locked_feedback uma vez")
	assert_eq(door.get_state(), Door.State.LOCKED, "continua trancada")
	assert_almost_eq(door.get_panel_angle_deg(), 0.0, 0.001, "trancada não se mexe")
	player.get_interaction().press_interact()
	await wait_physics_frames(SLOW_MID_FRAMES)
	player.get_interaction().release_interact()
	assert_eq(_feedback_count, 2, "segurar em porta trancada também dá feedback")
	assert_eq(_slow_flags.size(), 0, "porta trancada nunca emite opened")


func test_porta_fechada_bloqueia_e_aberta_libera() -> void:
	var root: Node3D = add_child_autofree(Node3D.new()) as Node3D
	_world(root)
	var player: PlayerRoot = PlayerWorld.spawn_player(root, Vector3(0.0, 0.0, PLAYER_START_Z))
	var door: Door = InteractionWorld.spawn_door(root, DOOR_POSITION)
	await wait_physics_frames(SETTLE_FRAMES)
	player.get_motor().set_scripted_input(PlayerWorld.move_input(Vector2(0.0, 1.0)))
	await wait_physics_frames(WALK_BLOCKED_FRAMES)
	player.get_motor().set_scripted_input(MotorInput.new())
	assert_true(player.global_position.z > BLOCKED_Z_MAX,
		"porta fechada bloqueia o corpo (z = %f)" % player.global_position.z)
	player.get_interaction().press_interact()
	await wait_physics_frames(PRESS_FRAMES)
	player.get_interaction().release_interact()
	await wait_physics_frames(FAST_DONE_FRAMES)
	assert_eq(door.get_state(), Door.State.OPEN, "a porta abriu com o toque")
	player.get_motor().set_scripted_input(PlayerWorld.move_input(Vector2(0.0, 1.0)))
	await wait_physics_frames(WALK_THROUGH_FRAMES)
	player.get_motor().set_scripted_input(MotorInput.new())
	assert_true(player.global_position.z < THROUGH_Z_MAX,
		"com a porta aberta o jogador passa (z = %f)" % player.global_position.z)

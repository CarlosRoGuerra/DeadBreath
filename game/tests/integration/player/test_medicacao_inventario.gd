extends TestCase
## F2-005: bombinha no jogador. Começa com 1 unidade (3 doses) no inventário; Q usa uma dose (try_use_inhaler); falha
## sem cargas ou em cooldown, com feedback por sinal e sem consumir; pickup (EventBus.item_picked) soma doses; as cargas
## chegam à fisiologia (set_medication_charges). Física em tick fixo. Autor: Gameplay Engineer (F2-005).

const WorldScript := preload("res://tests/integration/player/fixtures/player_world.gd")
const SETTLE_FRAMES: int = 6

var _previous: Dictionary = {}
var _failures: Array[StringName] = []


func before_all() -> void:
	Settings.autosave = false


func after_all() -> void:
	Settings.autosave = true


func before_each() -> void:
	_previous = WorldScript.override_settings({&"motion_reduction": 0.0, &"mouse_sensitivity": 0.12, &"invert_y": false, &"fov": 75.0})
	_failures.clear()


func after_each() -> void:
	WorldScript.restore_settings(_previous)


func _on_failed(reason: StringName) -> void:
	_failures.append(reason)


func _player(root: Node3D) -> PlayerRoot:
	WorldScript.add_box(root, Vector3(0.0, -0.5, -5.0), Vector3(6.0, 1.0, 16.0), &"wood")
	return WorldScript.spawn_player(root, Vector3.ZERO)


func test_comeca_com_uma_bombinha_e_tres_cargas() -> void:
	var root: Node3D = add_child_autofree(Node3D.new()) as Node3D
	var player: PlayerRoot = _player(root)
	await wait_physics_frames(SETTLE_FRAMES)
	assert_eq(player.get_inventory().get_doses(&"inhaler"), 3, "1 bombinha = 3 doses no inventário")
	assert_eq(player.get_physiology().get_snapshot().medication_charges, 3, "as cargas chegam à fisiologia")


func test_usar_consome_uma_dose_e_atualiza_a_fisiologia() -> void:
	var root: Node3D = add_child_autofree(Node3D.new()) as Node3D
	var player: PlayerRoot = _player(root)
	await wait_physics_frames(SETTLE_FRAMES)
	var used: Array[bool] = [false]
	player.inhaler_used.connect(func() -> void: used[0] = true)
	assert_true(player.try_use_inhaler(), "bombinha usada")
	assert_true(used[0], "inhaler_used emitido")
	assert_eq(player.get_inventory().get_doses(&"inhaler"), 2, "uma dose consumida")
	assert_eq(player.get_physiology().get_snapshot().medication_charges, 2, "fisiologia recebe a nova carga")


func test_cooldown_recusa_sem_consumir() -> void:
	var root: Node3D = add_child_autofree(Node3D.new()) as Node3D
	var player: PlayerRoot = _player(root)
	await wait_physics_frames(SETTLE_FRAMES)
	player.item_use_failed.connect(_on_failed)
	assert_true(player.try_use_inhaler(), "primeira dose")
	assert_false(player.try_use_inhaler(), "segunda dose em cooldown é recusada")
	assert_eq(_failures, [&"cooldown"] as Array[StringName], "feedback de cooldown por sinal")
	assert_eq(player.get_inventory().get_doses(&"inhaler"), 2, "a recusa não consome dose")


func test_sem_doses_recusa_com_feedback() -> void:
	var root: Node3D = add_child_autofree(Node3D.new()) as Node3D
	var player: PlayerRoot = _player(root)
	await wait_physics_frames(SETTLE_FRAMES)
	player.item_use_failed.connect(_on_failed)
	player.get_inventory().consume_dose(&"inhaler")
	player.get_inventory().consume_dose(&"inhaler")
	player.get_inventory().consume_dose(&"inhaler")
	assert_false(player.try_use_inhaler(), "sem doses não usa")
	assert_eq(_failures, [&"no_doses"] as Array[StringName], "feedback de sem doses")
	assert_eq(player.get_physiology().get_snapshot().medication_charges, 0, "cargas zero na fisiologia")


func test_pickup_soma_doses_pelo_eventbus() -> void:
	var root: Node3D = add_child_autofree(Node3D.new()) as Node3D
	var player: PlayerRoot = _player(root)
	await wait_physics_frames(SETTLE_FRAMES)
	EventBus.item_picked.emit(&"inhaler", 1, &"pk_test_inhaler")
	assert_eq(player.get_inventory().get_doses(&"inhaler"), 6, "pickup de uma unidade soma 3 doses")
	assert_eq(player.get_physiology().get_snapshot().medication_charges, 6, "cargas atualizadas na fisiologia")


func test_tecla_q_usa_a_bombinha() -> void:
	var root: Node3D = add_child_autofree(Node3D.new()) as Node3D
	var player: PlayerRoot = _player(root)
	await wait_physics_frames(SETTLE_FRAMES)
	var event: InputEventAction = InputEventAction.new()
	event.action = &"use_item"
	event.pressed = true
	player.get_viewport().push_input(event)
	assert_eq(player.get_inventory().get_doses(&"inhaler"), 2, "Q consome uma dose")

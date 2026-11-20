extends TestCase
## F1-007 (COMPONENT_CONTRACTS §3): segurar que falha. Soltar antes do tempo, ou o foco sair do alvo no
## meio do segurar, emite interaction_failed (gancho do ruído do objeto na F3) e não conclui.
## Autor: Gameplay Engineer.

const InteractionWorld := preload("res://tests/integration/interaction/fixtures/interaction_world.gd")
const PlayerWorld := preload("res://tests/integration/player/fixtures/player_world.gd")

const SETTLE_FRAMES: int = 6
const HOLD_TIME_S: float = 0.5
const HOLD_PARTIAL_FRAMES: int = 20
const AFTER_RELEASE_FRAMES: int = 40
## Yaw de 120° (1000 px × 0,12 graus/px): o alvo sai da mira.
const LOOK_AWAY_PX: float = 1000.0

var _previous: Dictionary = {}
var _failed: Array[StringName] = []
var _picked_count: int = 0


func before_all() -> void:
	Settings.autosave = false


func after_all() -> void:
	Settings.autosave = true


func before_each() -> void:
	_previous = PlayerWorld.override_settings({&"motion_reduction": 0.0, &"mouse_sensitivity": 0.12, &"invert_y": false, &"fov": 75.0})
	_failed.clear()
	_picked_count = 0
	EventBus.item_picked.connect(_on_item_picked)


func after_each() -> void:
	PlayerWorld.restore_settings(_previous)
	if EventBus.item_picked.is_connected(_on_item_picked):
		EventBus.item_picked.disconnect(_on_item_picked)


func _on_item_picked(_item_id: StringName, _quantity: int, _persist_id: StringName) -> void:
	_picked_count += 1


func _on_failed(target: Interactable) -> void:
	_failed.append(StringName(target.name))


func _setup(root: Node3D) -> Dictionary:
	PlayerWorld.add_box(root, Vector3(0.0, -0.5, -5.0), Vector3(6.0, 1.0, 16.0), &"wood")
	var player: PlayerRoot = PlayerWorld.spawn_player(root, Vector3.ZERO)
	var pickup: Pickup = InteractionWorld.spawn_pickup(root, Vector3(0.0, InteractionWorld.EYE_HEIGHT_M, -1.2), &"pk_fail_1", &"chave", HOLD_TIME_S)
	player.get_interaction().interaction_failed.connect(_on_failed)
	return {"player": player, "pickup": pickup}


func test_soltar_antes_do_tempo_falha_e_nao_conclui() -> void:
	var root: Node3D = add_child_autofree(Node3D.new()) as Node3D
	var parts: Dictionary = _setup(root)
	var player: PlayerRoot = parts["player"] as PlayerRoot
	var pickup: Pickup = parts["pickup"] as Pickup
	await wait_physics_frames(SETTLE_FRAMES)
	player.get_interaction().press_interact()
	await wait_physics_frames(HOLD_PARTIAL_FRAMES)
	player.get_interaction().release_interact()
	await wait_physics_frames(AFTER_RELEASE_FRAMES)
	assert_eq(_failed.size(), 1, "soltar antes de 0,5 s emite interaction_failed uma vez")
	assert_eq(_picked_count, 0, "soltar antes não conclui o item")
	assert_true(is_instance_valid(pickup) and not pickup.is_queued_for_deletion(), "o item continua no lugar")


func test_foco_que_sai_do_alvo_no_meio_do_segurar_falha() -> void:
	var root: Node3D = add_child_autofree(Node3D.new()) as Node3D
	var parts: Dictionary = _setup(root)
	var player: PlayerRoot = parts["player"] as PlayerRoot
	await wait_physics_frames(SETTLE_FRAMES)
	player.get_interaction().press_interact()
	await wait_physics_frames(HOLD_PARTIAL_FRAMES)
	var away: MotorInput = MotorInput.new()
	away.look_delta = Vector2(LOOK_AWAY_PX, 0.0)
	player.get_motor().set_scripted_input(away)
	await wait_physics_frames(1)
	player.get_motor().set_scripted_input(MotorInput.new())
	await wait_physics_frames(AFTER_RELEASE_FRAMES)
	player.get_interaction().release_interact()
	assert_eq(_failed.size(), 1, "o alvo saiu da mira: segurar falha uma vez")
	assert_eq(_picked_count, 0, "sem o alvo em foco o item não é apanhado")
	assert_false(player.get_interaction().is_holding(), "o segurar foi cancelado")

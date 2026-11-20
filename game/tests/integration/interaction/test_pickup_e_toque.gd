extends TestCase
## F1-007 (COMPONENT_CONTRACTS §3): pickup emite EventBus.item_picked e some; sem persist_id fica inerte
## (ARC-02); toque em item instantâneo (hold_time 0) e a fórmula de mãos firmes com steadiness neutro.
## Autor: Gameplay Engineer.

const InteractionWorld := preload("res://tests/integration/interaction/fixtures/interaction_world.gd")
const PlayerWorld := preload("res://tests/integration/player/fixtures/player_world.gd")

const SETTLE_FRAMES: int = 6
const PRESS_FRAMES: int = 2
const HOLD_TIME_S: float = 0.5
const FRAME_S: float = 1.0 / 60.0
## Tolerância em ticks para o segurar de 0,5 s (um tick de folga para o aperto e a soltura).
const HOLD_TOLERANCE_TICKS: int = 2

var _previous: Dictionary = {}
var _picked: Array[StringName] = []
var _picked_quantity: Array[int] = []
var _picked_persist: Array[StringName] = []


func before_all() -> void:
	Settings.autosave = false


func after_all() -> void:
	Settings.autosave = true


func before_each() -> void:
	_previous = PlayerWorld.override_settings({&"motion_reduction": 0.0, &"mouse_sensitivity": 0.12, &"invert_y": false, &"fov": 75.0})
	_picked.clear()
	_picked_quantity.clear()
	_picked_persist.clear()
	EventBus.item_picked.connect(_on_item_picked)


func after_each() -> void:
	PlayerWorld.restore_settings(_previous)
	if EventBus.item_picked.is_connected(_on_item_picked):
		EventBus.item_picked.disconnect(_on_item_picked)


func _on_item_picked(item_id: StringName, quantity: int, persist_id: StringName) -> void:
	_picked.append(item_id)
	_picked_quantity.append(quantity)
	_picked_persist.append(persist_id)


func _world_with_player(root: Node3D) -> PlayerRoot:
	PlayerWorld.add_box(root, Vector3(0.0, -0.5, -5.0), Vector3(6.0, 1.0, 16.0), &"wood")
	return PlayerWorld.spawn_player(root, Vector3.ZERO)


func test_pegar_item_emite_item_picked_e_some() -> void:
	var root: Node3D = add_child_autofree(Node3D.new()) as Node3D
	var player: PlayerRoot = _world_with_player(root)
	var pickup: Pickup = InteractionWorld.spawn_pickup(root, Vector3(0.0, InteractionWorld.EYE_HEIGHT_M, -1.2), &"pk_bombinha_1", &"bombinha")
	await wait_physics_frames(SETTLE_FRAMES)
	assert_eq(player.get_interaction().get_focused(), pickup, "item em foco antes de apertar")
	player.get_interaction().press_interact()
	await wait_physics_frames(PRESS_FRAMES)
	assert_eq(_picked.size(), 1, "exatamente um item_picked")
	if _picked.size() == 1:
		assert_eq(_picked[0], &"bombinha", "item_id no evento")
		assert_eq(_picked_quantity[0], 1, "quantidade no evento")
		assert_eq(_picked_persist[0], &"pk_bombinha_1", "persist_id no evento")
	assert_true(not is_instance_valid(pickup) or pickup.is_queued_for_deletion(), "o pickup some depois de apanhado")


func test_pickup_sem_persist_id_fica_inerte() -> void:
	var root: Node3D = add_child_autofree(Node3D.new()) as Node3D
	var player: PlayerRoot = _world_with_player(root)
	var pickup: Pickup = InteractionWorld.spawn_pickup(root, Vector3(0.0, InteractionWorld.EYE_HEIGHT_M, -1.2), &"", &"bombinha")
	await wait_physics_frames(SETTLE_FRAMES)
	assert_eq(player.get_interaction().get_focused(), pickup, "o item continua visível e em foco")
	player.get_interaction().press_interact()
	await wait_physics_frames(PRESS_FRAMES)
	assert_eq(_picked.size(), 0, "sem persist_id não há item_picked (ARC-02)")
	assert_true(is_instance_valid(pickup) and not pickup.is_queued_for_deletion(), "item sem persist_id não some")


func test_item_de_segurar_conclui_so_depois_do_tempo() -> void:
	var root: Node3D = add_child_autofree(Node3D.new()) as Node3D
	var player: PlayerRoot = _world_with_player(root)
	InteractionWorld.spawn_pickup(root, Vector3(0.0, InteractionWorld.EYE_HEIGHT_M, -1.2), &"pk_hold_1", &"chave", HOLD_TIME_S)
	await wait_physics_frames(SETTLE_FRAMES)
	player.get_interaction().press_interact()
	await wait_physics_frames(int(HOLD_TIME_S / FRAME_S) - HOLD_TOLERANCE_TICKS)
	assert_eq(_picked.size(), 0, "antes de 0,5 s segurando, nada é apanhado")
	await wait_physics_frames(2 * HOLD_TOLERANCE_TICKS + 2)
	assert_eq(_picked.size(), 1, "segurando por 0,5 s, o item é apanhado")
	player.get_interaction().release_interact()


func test_maos_firmes_neutras_mantem_o_tempo_de_segurar() -> void:
	# CouplingFactors.neutral() dá steadiness 1,0: a fórmula devolve hold_time exato, mesmo com requires_steady_hands.
	var root: Node3D = add_child_autofree(Node3D.new()) as Node3D
	var player: PlayerRoot = _world_with_player(root)
	InteractionWorld.spawn_pickup(root, Vector3(0.0, InteractionWorld.EYE_HEIGHT_M, -1.2), &"pk_steady_1", &"chave", HOLD_TIME_S, true)
	await wait_physics_frames(SETTLE_FRAMES)
	player.get_interaction().press_interact()
	await wait_physics_frames(int(HOLD_TIME_S / FRAME_S) + HOLD_TOLERANCE_TICKS)
	assert_eq(_picked.size(), 1, "com mãos firmes (steadiness 1,0) o tempo é o hold_time, sem multiplicador")
	player.get_interaction().release_interact()

extends TestCase
## F1-007 (COMPONENT_CONTRACTS §3): foco pelo raio da câmera, alcance de 2 m, só alvos da camada 5 e
## oclusão por paredes (camadas 1 e 2): não há interação através de paredes. Física em tick fixo.
## Autor: Gameplay Engineer.

const InteractionWorld := preload("res://tests/integration/interaction/fixtures/interaction_world.gd")
const PlayerWorld := preload("res://tests/integration/player/fixtures/player_world.gd")

const SETTLE_FRAMES: int = 6
const PRESS_FRAMES: int = 4

var _previous: Dictionary = {}
var _picked: Array[StringName] = []


func before_all() -> void:
	Settings.autosave = false


func after_all() -> void:
	Settings.autosave = true


func before_each() -> void:
	_previous = PlayerWorld.override_settings({&"motion_reduction": 0.0, &"mouse_sensitivity": 0.12, &"invert_y": false, &"fov": 75.0})
	_picked.clear()
	EventBus.item_picked.connect(_on_item_picked)


func after_each() -> void:
	PlayerWorld.restore_settings(_previous)
	if EventBus.item_picked.is_connected(_on_item_picked):
		EventBus.item_picked.disconnect(_on_item_picked)


func _on_item_picked(item_id: StringName, _quantity: int, _persist_id: StringName) -> void:
	_picked.append(item_id)


func test_foco_em_item_a_menos_de_2_m_na_altura_dos_olhos() -> void:
	var root: Node3D = add_child_autofree(Node3D.new()) as Node3D
	PlayerWorld.add_box(root, Vector3(0.0, -0.5, -5.0), Vector3(6.0, 1.0, 16.0), &"wood")
	var player: PlayerRoot = PlayerWorld.spawn_player(root, Vector3.ZERO)
	var pickup: Pickup = InteractionWorld.spawn_pickup(root, Vector3(0.0, InteractionWorld.EYE_HEIGHT_M, -1.2), &"foco_1", &"bombinha")
	await wait_physics_frames(SETTLE_FRAMES)
	assert_eq(player.get_interaction().get_focused(), pickup, "item a 1,2 m no centro da câmera deve estar em foco")


func test_parede_bloqueia_o_foco() -> void:
	var root: Node3D = add_child_autofree(Node3D.new()) as Node3D
	PlayerWorld.add_box(root, Vector3(0.0, -0.5, -5.0), Vector3(6.0, 1.0, 16.0), &"wood")
	var player: PlayerRoot = PlayerWorld.spawn_player(root, Vector3.ZERO)
	InteractionWorld.add_wall(root, -1.6)
	InteractionWorld.spawn_pickup(root, Vector3(0.0, InteractionWorld.EYE_HEIGHT_M, -2.0), &"foco_2", &"bombinha")
	await wait_physics_frames(SETTLE_FRAMES)
	assert_null(player.get_interaction().get_focused(), "parede na frente do item: sem foco (oclusão)")


func test_item_alem_do_alcance_nao_tem_foco() -> void:
	var root: Node3D = add_child_autofree(Node3D.new()) as Node3D
	PlayerWorld.add_box(root, Vector3(0.0, -0.5, -5.0), Vector3(6.0, 1.0, 16.0), &"wood")
	var player: PlayerRoot = PlayerWorld.spawn_player(root, Vector3.ZERO)
	InteractionWorld.spawn_pickup(root, Vector3(0.0, InteractionWorld.EYE_HEIGHT_M, -3.0), &"foco_3", &"bombinha")
	await wait_physics_frames(SETTLE_FRAMES)
	assert_null(player.get_interaction().get_focused(), "item a 3 m está fora do alcance de 2 m")


func test_mundo_sem_interactable_nao_tem_foco() -> void:
	var root: Node3D = add_child_autofree(Node3D.new()) as Node3D
	PlayerWorld.add_box(root, Vector3(0.0, -0.5, -5.0), Vector3(6.0, 1.0, 16.0), &"wood")
	var player: PlayerRoot = PlayerWorld.spawn_player(root, Vector3.ZERO)
	PlayerWorld.add_box(root, Vector3(0.0, InteractionWorld.EYE_HEIGHT_M, -1.2), Vector3(0.5, 0.5, 0.5))
	await wait_physics_frames(SETTLE_FRAMES)
	assert_null(player.get_interaction().get_focused(), "caixa de mundo sem Interactable não recebe foco")


func test_parede_impede_o_aperto_e_o_item_fica() -> void:
	var root: Node3D = add_child_autofree(Node3D.new()) as Node3D
	PlayerWorld.add_box(root, Vector3(0.0, -0.5, -5.0), Vector3(6.0, 1.0, 16.0), &"wood")
	var player: PlayerRoot = PlayerWorld.spawn_player(root, Vector3.ZERO)
	InteractionWorld.add_wall(root, -1.6)
	var pickup: Pickup = InteractionWorld.spawn_pickup(root, Vector3(0.0, InteractionWorld.EYE_HEIGHT_M, -2.0), &"oclusao_1", &"bombinha")
	await wait_physics_frames(SETTLE_FRAMES)
	player.get_interaction().press_interact()
	await wait_physics_frames(PRESS_FRAMES)
	player.get_interaction().release_interact()
	await wait_physics_frames(2)
	assert_true(is_instance_valid(pickup) and not pickup.is_queued_for_deletion(), "através da parede o item não pode ser apanhado")
	assert_eq(_picked.size(), 0, "nenhum item_picked através da parede")

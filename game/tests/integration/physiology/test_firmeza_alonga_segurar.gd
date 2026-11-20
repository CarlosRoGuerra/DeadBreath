extends TestCase
## Firmeza da mão (COMPONENT_CONTRACTS §3 e §4.3; DATA §1.6): com estresse alto, a steadiness cai, o tempo de
## segurar aumenta (hold_time × (1 + 1,5·(1 − firmeza))), e o PlayerRoot entrega a firmeza ao InteractionContext
## no mesmo tick. Pickup com requires_steady_hands, hold_time 0,5 s. Autor: Physiological Systems Engineer.

const PlayerWorld := preload("res://tests/integration/player/fixtures/player_world.gd")
const InteractionWorld := preload("res://tests/integration/interaction/fixtures/interaction_world.gd")
const SETTLE_FRAMES: int = 6
const PRESS_FRAMES: int = 2
const HOLD_S: float = 0.5
const CALM_HOLD_S: float = 0.8
const STRESSED_HOLD_S: float = 1.3
const FRAME_S: float = 1.0 / 60.0
const TOLERANCE: float = 0.01

var _previous: Dictionary = {}
var _picked: int = 0


func before_all() -> void:
	Settings.autosave = false


func after_all() -> void:
	Settings.autosave = true


func before_each() -> void:
	_previous = PlayerWorld.override_settings({&"motion_reduction": 0.0, &"mouse_sensitivity": 0.12, &"invert_y": false, &"fov": 75.0})
	_picked = 0
	EventBus.item_picked.connect(_on_picked)


func after_each() -> void:
	PlayerWorld.restore_settings(_previous)
	if EventBus.item_picked.is_connected(_on_picked):
		EventBus.item_picked.disconnect(_on_picked)


func _on_picked(_item_id: StringName, _quantity: int, _persist_id: StringName) -> void:
	_picked += 1


## Mundo com jogador e um pickup de mãos firmes à frente. Retorna o jogador.
func _world(root: Node3D) -> PlayerRoot:
	PlayerWorld.add_box(root, Vector3(0.0, -0.5, -5.0), Vector3(6.0, 1.0, 16.0), &"wood")
	var player: PlayerRoot = PlayerWorld.spawn_player(root, Vector3.ZERO)
	InteractionWorld.spawn_pickup(root, Vector3(0.0, InteractionWorld.EYE_HEIGHT_M, -1.2), &"pk_firmeza_1", &"bombinha",
		HOLD_S, true)
	return player


## Segura o botão por `seconds` e solta. Devolve quantos quadros o segurar durou.
func _hold(player: PlayerRoot, seconds: float) -> void:
	await wait_physics_frames(PRESS_FRAMES)
	player.get_interaction().press_interact()
	await wait_physics_frames(1)
	var frames: int = int(round(seconds / FRAME_S))
	await wait_physics_frames(frames)
	player.get_interaction().release_interact()
	await wait_physics_frames(PRESS_FRAMES)


func test_firmeza_neutra_segurar_de_0_5_s_conclui() -> void:
	var root: Node3D = add_child_autofree(Node3D.new()) as Node3D
	var player: PlayerRoot = _world(root)
	await wait_physics_frames(SETTLE_FRAMES)
	assert_almost_eq(player.get_physiology().get_coupling().steadiness, 1.0, TOLERANCE, "sem estresse, mãos firmes (1,0)")
	await _hold(player, CALM_HOLD_S)
	assert_eq(_picked, 1, "com mãos firmes, segurar 0,8 s conclui um pickup de 0,5 s")


func test_estresse_alto_alonga_o_segurar_e_o_contexto_recebe_a_firmeza() -> void:
	var root: Node3D = add_child_autofree(Node3D.new()) as Node3D
	var player: PlayerRoot = _world(root)
	await wait_physics_frames(SETTLE_FRAMES)
	var physiology: PhysiologyComponent = player.get_physiology()
	for _i: int in 4:
		physiology.add_startle(25.0)
	await wait_physics_frames(1)
	var steadiness: float = physiology.get_coupling().steadiness
	note("firmeza com estresse %.1f: %.3f; segurar necessário: %.3f s (base 0,5 s)"
		% [physiology.get_snapshot().stress, steadiness, InteractionComponent.required_hold_time(_pickup(root), steadiness)])
	assert_almost_eq(steadiness, 0.3, TOLERANCE, "estresse 100 com severidade 0: firmeza 1 − 0,7 = 0,3")
	assert_almost_eq(player.get_interaction().get_focused().hold_time, HOLD_S, 0.0001, "o alvo tem hold_time 0,5 s")
	assert_almost_eq(InteractionComponent.required_hold_time(_pickup(root), steadiness), HOLD_S * 2.05, 0.01,
		"tempo necessário: 0,5 × (1 + 1,5 × 0,7) = 1,025 s")
	await _hold(player, CALM_HOLD_S)
	assert_eq(_picked, 0, "segurar 0,8 s não basta com mãos trêmulas")
	await _hold(player, STRESSED_HOLD_S)
	assert_eq(_picked, 1, "segurar 1,3 s basta")


func _pickup(root: Node3D) -> Interactable:
	for child: Node in root.get_children():
		var target: Interactable = child as Interactable
		if target != null:
			return target
	return null

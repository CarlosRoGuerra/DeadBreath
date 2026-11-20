extends TestCase
## Integration: LevelSlots + content/levels/sandbox_playable.tscn (integração da F1-009).
## Autor: Project Director.

const PLAYABLE_PATH: String = "res://content/levels/sandbox_playable.tscn"
## door_id -> estado inicial, conforme os door_slot da sandbox (relatório da F1-009).
const EXPECTED_DOORS: Dictionary = {
	"door_sala_corredor": Door.State.CLOSED,
	"door_sala_cozinha": Door.State.OPEN,
	"door_cozinha_corredor": Door.State.LOCKED,
	"door_corredor_hall": Door.State.CLOSED,
}
const EXPECTED_PICKUP_COUNT: int = 2
const WORLD_DYNAMIC_MASK: int = 2

var _root: Node = null


func before_each() -> void:
	var scene: PackedScene = load(PLAYABLE_PATH) as PackedScene
	_root = add_child_autofree(scene.instantiate())
	await wait_physics_frames(2)


func _slots() -> LevelSlots:
	return _root.get_node("LevelSlots") as LevelSlots


func test_one_door_per_slot_with_slot_state() -> void:
	var doors: Array[Door] = _slots().get_doors()
	assert_eq(doors.size(), EXPECTED_DOORS.size(), "uma porta por door_slot")
	for door: Door in doors:
		var door_name: String = String(door.name)
		assert_true(EXPECTED_DOORS.has(door_name), "porta inesperada: " + door_name)
		if EXPECTED_DOORS.has(door_name):
			assert_eq(door.get_state(), EXPECTED_DOORS[door_name], "estado inicial de " + door_name)


func test_open_door_starts_with_panel_open() -> void:
	for door: Door in _slots().get_doors():
		var expected_angle: float = door.open_angle_deg if door.get_state() == Door.State.OPEN else 0.0
		assert_almost_eq(door.get_panel_angle_deg(), expected_angle, 0.01, "ângulo inicial do painel de " + String(door.name))


func test_closed_doors_block_the_opening_and_open_door_frees_it() -> void:
	var space: PhysicsDirectSpaceState3D = (_root.get_node("Level") as Node3D).get_world_3d().direct_space_state
	for door: Door in _slots().get_doors():
		var slot: Marker3D = door.get_parent() as Marker3D
		var params: PhysicsPointQueryParameters3D = PhysicsPointQueryParameters3D.new()
		params.position = slot.global_position
		params.collision_mask = WORLD_DYNAMIC_MASK
		var blocked: bool = not space.intersect_point(params, 4).is_empty()
		assert_eq(blocked, door.get_state() != Door.State.OPEN, "o centro do vão de %s está bloqueado?" % door.name)


func test_pickups_have_unique_non_empty_ids() -> void:
	var pickups: Array[Pickup] = _slots().get_pickups()
	assert_eq(pickups.size(), EXPECTED_PICKUP_COUNT, "um pickup por pickup_slot")
	var seen: Dictionary = {}
	for p: Pickup in pickups:
		assert_ne(String(p.persist_id), "", "persist_id vazio")
		assert_ne(String(p.item_id), "", "item_id vazio")
		assert_false(seen.has(p.persist_id), "persist_id repetido: %s" % p.persist_id)
		seen[p.persist_id] = true


## Revisão F1-010, R1-14: o painel tem 0,9 m fixos; outro vão precisa ser denunciado.
func test_opening_width_different_from_panel_logs_error() -> void:
	var holder: Node = Node.new()
	var level: Node3D = Node3D.new()
	level.name = "WideLevel"
	var slot: Marker3D = Marker3D.new()
	slot.add_to_group(&"door_slot")
	slot.set_meta(&"door_id", &"door_wide")
	slot.set_meta(&"start_state", &"closed")
	slot.set_meta(&"opening_width_m", 1.2)
	slot.position = Vector3(100.0, 1.0, 100.0)
	level.add_child(slot)
	holder.add_child(level)
	var slots: LevelSlots = LevelSlots.new()
	slots.level_path = NodePath("../WideLevel")
	holder.add_child(slots)
	var errors: Array[String] = []
	var listener: Callable = func(log_level: int, category: StringName, message: String) -> void:
		if log_level == Log.ERROR and category == &"level":
			errors.append(message)
	Log.message_logged.connect(listener)
	add_child_autofree(holder)
	Log.message_logged.disconnect(listener)
	assert_eq(slots.get_doors().size(), 1, "a porta é criada mesmo assim")
	assert_eq(errors.size(), 1, "um Log.error para o vão fora da medida")
	if errors.size() == 1:
		assert_true(errors[0].contains("1.20"), "mensagem cita a largura: " + errors[0])


func test_playable_scene_has_player_pause_menu_and_debug_overlay() -> void:
	assert_not_null(_root.get_node_or_null("PauseMenu") as PauseMenu, "menu de pausa")
	assert_not_null(_root.get_node_or_null("DebugOverlay") as DebugOverlay, "overlay de debug")
	assert_eq(get_tree().get_nodes_in_group(&"player").size(), 1, "exatamente um jogador")

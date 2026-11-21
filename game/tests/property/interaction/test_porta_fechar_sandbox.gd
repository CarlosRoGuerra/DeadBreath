extends TestCase
## F3-004 (teste obrigatório na sandbox jogável): a porta corredor–hall, aberta e depois fechada pela interação, muda o
## nível percebido do corredor ao hall em 15 dB (18 - 3, DATA §2.2). O portal só fecha no fim do movimento (§6.5).
## Autor: Gameplay Engineer (F3-004).

const PLAYABLE_PATH: String = "res://content/levels/sandbox_playable.tscn"
const DOOR_NAME: String = "door_corredor_hall"
const PORTAL_ID: StringName = &"portal_corredor_hall"
const SOURCE_CORRIDOR: Vector3 = Vector3(10.0, 1.0, -0.7)
const LISTENER_HALL: Vector3 = Vector3(16.0, 1.0, -0.7)
const DELTA_DB: float = 15.0
const TOL: float = 0.0001
const MOVE_FRAMES: int = 30
const SETTLE_FRAMES: int = 3


func _instance() -> Node:
	var scene: PackedScene = load(PLAYABLE_PATH) as PackedScene
	assert_not_null(scene, "a sandbox jogável carrega")
	return add_child_autofree(scene.instantiate())


func test_fechar_a_porta_pela_interacao_reduz_15_db_do_corredor_ao_hall() -> void:
	var root: Node = _instance()
	await wait_physics_frames(SETTLE_FRAMES)
	var door: Door = root.find_child(DOOR_NAME, true, false) as Door
	assert_not_null(door, "a porta %s existe" % DOOR_NAME)
	if door == null:
		return
	var world: AcousticWorld = root.find_child("AcousticWorld", true, false) as AcousticWorld
	assert_not_null(world, "o AcousticWorld do nível existe")
	if world == null:
		return
	var graph: AcousticGraph = world.get_graph()
	var sound: NoiseEvent = NoiseEvent.create(Enums.NoiseCategory.VOICE, SOURCE_CORRIDOR, 60.0, 1.0, &"enemy_test", &"voice_test")
	assert_eq(door.get_state(), Door.State.CLOSED, "a porta nasce fechada")
	var context: InteractionContext = InteractionContext.new()
	door.interact(context)
	await wait_physics_frames(MOVE_FRAMES)
	assert_eq(door.get_state(), Door.State.OPEN, "aberta pela interação")
	var opened: PropagationResult = graph.propagate(sound, LISTENER_HALL)
	door.interact(context)
	await wait_physics_frames(SETTLE_FRAMES)
	assert_true(door.is_closing(), "fechando")
	assert_true(graph.is_portal_open(PORTAL_ID), "durante o fechamento o portal segue aberto")
	await wait_physics_frames(MOVE_FRAMES)
	assert_eq(door.get_state(), Door.State.CLOSED, "fechada no fim do movimento")
	assert_false(graph.is_portal_open(PORTAL_ID), "o portal fecha com state_changed")
	var closed: PropagationResult = graph.propagate(sound, LISTENER_HALL)
	assert_almost_eq(opened.perceived_db - closed.perceived_db, DELTA_DB, TOL, "aberta - fechada = 15 dB (fechada soa 15 dB mais baixo)")
	assert_eq(closed.path_portals, [PORTAL_ID] as Array[StringName], "a rota segue pela porta")

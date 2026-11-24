extends TestCase
## F4-004 (D4-03): EnemyDoorLinkGate mantém desligado o NavigationLink3D de porta trancada e o religa ao destrancar,
## acompanhando Door.state_changed. Mundo isolado com uma porta (door.tscn), um link com metadado door_id e um Observer
## (o gate fica no Observer e age no ramo do pai). A navegação pelo vão (o caminho de fato) está em tests/property.
## Autor: AI Engineer (F4-004).

const Fx := preload("res://tests/integration/enemy/fixtures/enemy_test_world.gd")
const DOOR_SCENE_PATH: String = "res://components/world/door.tscn"
const DOOR_ID: StringName = &"door_gate_teste"
const SETTLE_FRAMES: int = 2


## Porta e link no mundo de teste, com o estado inicial dado. Devolve o link e a porta.
func _door_and_link(initial: Door.State) -> Dictionary:
	var world: Node3D = add_isolated_world()
	var door: Door = (load(DOOR_SCENE_PATH) as PackedScene).instantiate() as Door
	door.door_id = DOOR_ID
	door.initial_state = initial
	door.position = Vector3(0.0, 0.0, 0.0)
	world.add_child(door)
	var link: NavigationLink3D = NavigationLink3D.new()
	link.start_position = Vector3(-0.6, 0.0, 0.0)
	link.end_position = Vector3(0.6, 0.0, 0.0)
	link.bidirectional = true
	link.set_meta(&"door_id", DOOR_ID)
	world.add_child(link)
	Fx.add_route(world, &"observer", PackedVector3Array([Vector3(5.0, 0.0, 5.0)]))
	var enemy: EnemyController = Fx.spawn_observer(world, Vector3(5.0, 0.0, 5.0))
	return {"door": door, "link": link, "gate": enemy.get_node("DoorLinkGate") as EnemyDoorLinkGate}


func test_link_de_porta_trancada_nasce_desligado() -> void:
	var setup: Dictionary = _door_and_link(Door.State.LOCKED)
	var link: NavigationLink3D = setup["link"] as NavigationLink3D
	var gate: EnemyDoorLinkGate = setup["gate"] as EnemyDoorLinkGate
	await wait_physics_frames(SETTLE_FRAMES)
	assert_false(link.enabled, "porta trancada: o link fica desligado (D4-03)")
	assert_false(gate.is_link_enabled(DOOR_ID), "o gate reporta o link desligado")


func test_link_de_porta_destrancada_nasce_ligado() -> void:
	var setup: Dictionary = _door_and_link(Door.State.CLOSED)
	var link: NavigationLink3D = setup["link"] as NavigationLink3D
	await wait_physics_frames(SETTLE_FRAMES)
	assert_true(link.enabled, "porta fechada e destrancada: o link fica ligado")


func test_destrancar_religa_o_link_e_trancar_desliga() -> void:
	var setup: Dictionary = _door_and_link(Door.State.LOCKED)
	var link: NavigationLink3D = setup["link"] as NavigationLink3D
	var door: Door = setup["door"] as Door
	await wait_physics_frames(SETTLE_FRAMES)
	assert_false(link.enabled, "pré-condição: trancada, link desligado")
	door.unlock()
	assert_true(link.enabled, "destrancar (Door.state_changed) religa o link")
	door.lock()
	assert_false(link.enabled, "trancar de novo desliga o link")
	door.unlock()
	assert_true(link.enabled, "e destrancar religa outra vez")

extends TestCase
## F4-004 (AI-01, TEST_PLAN §2.5): o Observer percorre os 8 pontos da rota da sandbox em ordem, sem estímulos, passando
## pelas portas fechadas da rota (abre-as), e nunca toca a trancada. Cena real (sandbox.tscn com LevelSlots), jogador
## retirado (ver EnemySandbox). Autor: AI Engineer (F4-004).

const EnemySandboxScript := preload("res://tests/property/enemy/fixtures/enemy_sandbox.gd")
const ARRIVAL_M: float = 1.0
const ROUTE_LOOPS: int = 2
const MAX_FRAMES: int = 16200
const DOOR_OPENED_IDS: Array[StringName] = [&"door_hall_quintal", &"door_corredor_hall", &"door_sala_corredor"]
const DOOR_LOCKED_ID: StringName = &"door_cozinha_corredor"
const SPAWN: Vector3 = Vector3(23.0, 0.0, -1.0)


func test_ai01_percorre_a_rota_em_ordem_sem_estimulo_abrindo_as_portas_fechadas() -> void:
	var root: Node3D = EnemySandboxScript.build(self)
	var enemy: EnemyController = EnemySandboxScript.add_observer(root, SPAWN, &"observer")
	await wait_physics_frames(3)
	var route: PackedVector3Array = enemy.patrol_route()
	assert_eq(route.size(), 8, "rota com os 8 pontos da sandbox")
	var opened: Dictionary = {}
	var locked_ever_changed: bool = false
	var arrivals: Array[int] = []
	var next_index: int = 0
	var only_patrol: bool = true
	var door_locked: Door = EnemySandboxScript.door(root, DOOR_LOCKED_ID)
	for frame: int in range(MAX_FRAMES):
		await wait_physics_frames(1)
		for door_id: StringName in DOOR_OPENED_IDS:
			var door: Door = EnemySandboxScript.door(root, door_id)
			if door != null and door.get_state() == Door.State.OPEN:
				opened[door_id] = true
		if door_locked.get_state() != Door.State.LOCKED:
			locked_ever_changed = true
		if enemy.get_state() != Enums.EnemyState.PATROL:
			only_patrol = false
		var flat: Vector3 = Vector3(enemy.global_position.x, 0.0, enemy.global_position.z)
		var goal: Vector3 = route[next_index]
		if Vector2(flat.x - goal.x, flat.z - goal.z).length() <= ARRIVAL_M:
			arrivals.append(next_index)
			next_index = (next_index + 1) % route.size()
			if arrivals.size() >= ROUTE_LOOPS * route.size():
				break
	assert_eq(arrivals.size(), ROUTE_LOOPS * route.size(), "chega aos pontos de %d voltas" % ROUTE_LOOPS)
	var in_order: bool = true
	for index: int in range(arrivals.size()):
		if arrivals[index] != index % route.size():
			in_order = false
	assert_true(in_order, "AI-01: os pontos são visitados em ordem (0..7, 0..7)")
	assert_true(only_patrol, "sem estímulos, o inimigo fica em PATROL o tempo todo")
	for door_id: StringName in DOOR_OPENED_IDS:
		assert_true(opened.has(door_id), "a porta fechada da rota %s foi aberta" % door_id)
	assert_false(locked_ever_changed, "a porta trancada nunca muda de estado")

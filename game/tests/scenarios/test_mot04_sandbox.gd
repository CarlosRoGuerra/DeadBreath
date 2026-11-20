extends TestCase
## MOT-04 na sandbox (F1-009, TEST_PLAN §2.1): o bot rasteja sob a mesa de 0,6 m, sobe a escada até o
## mezanino, não atravessa paredes e passa pelos vãos de porta. Carrega content/levels/sandbox.tscn, que
## já contém o jogador no PlayerSpawn. Um percurso por teste, para caber no watchdog de 15 s.
## Física em tick fixo (runner com --fixed-fps 60). Autor: Level Designer (F1-009).
## Medidas: content/levels/sandbox.tscn gerado por tools/level/gen_sandbox.py.

const LEVEL_PATH: String = "res://content/levels/sandbox.tscn"
const WorldScript := preload("res://tests/integration/player/fixtures/player_world.gd")

const SETTLE_FRAMES: int = 10
const MAX_FRAMES: int = 500
const HEIGHT_TOLERANCE_M: float = 0.01
const FLOOR_Y_TOLERANCE_M: float = 0.02
const STAND_HEIGHT_M: float = 1.75
const CROUCH_HEIGHT_M: float = 1.10
const MEZZ_TOP_M: float = 1.08
const MEZZ_CLEAR_Z_M: float = -3.1
const WALL_FACE_X_M: float = 0.1
const WALL_FACE_HALL_X_M: float = 14.1
const WALL_FACE_CORRIDOR_Z_M: float = -1.3
const CORRIDOR_DOOR_X_M: float = 14.0
const COOK_DOOR_X_M: float = 6.0

## Mesa: tampo de x 2,5 a 3,5 e z -4,2 a -2,8; face inferior em 0,60 m.
const TABLE_NEAR_Z_M: float = -2.8
const TABLE_FAR_Z_M: float = -4.2
const TABLE_MARGIN_M: float = 0.25

const AXIS_X: int = 0
const AXIS_Y: int = 1
const AXIS_Z: int = 2

const ROOM_IDS: Array[StringName] = [&"sala", &"cozinha", &"corredor", &"hall"]
const SURFACE_IDS: Array[StringName] = [&"wood", &"carpet", &"tile", &"concrete"]
const DOOR_IDS: Array[StringName] = [&"door_sala_corredor", &"door_sala_cozinha", &"door_cozinha_corredor", &"door_corredor_hall"]
const STATE_IDS: Array[StringName] = [&"closed", &"locked", &"open"]

var _previous: Dictionary = {}
var _table_violations: int = 0
var _airborne_ticks: int = 0


func before_all() -> void:
	Settings.autosave = false


func after_all() -> void:
	Settings.autosave = true


func before_each() -> void:
	_previous = WorldScript.override_settings({&"motion_reduction": 0.0, &"mouse_sensitivity": 0.12, &"invert_y": false, &"fov": 75.0})
	_table_violations = 0
	_airborne_ticks = 0


func after_each() -> void:
	WorldScript.restore_settings(_previous)


func test_sandbox_rasteja_sob_a_mesa_de_0_6_m() -> void:
	var level: Node3D = _load_level()
	var player: PlayerRoot = _player(level)
	var motor: PlayerMotor = player.get_motor()
	player.global_position = Vector3(3.0, 0.0, -2.3)
	await wait_physics_frames(SETTLE_FRAMES)
	assert_eq(motor.get_stance(), Enums.Stance.STAND, "começa em pé, antes da mesa")

	motor.set_scripted_input(WorldScript.edge_input(false, true))
	await wait_physics_frames(1)
	motor.set_scripted_input(MotorInput.new())
	assert_eq(motor.get_stance(), Enums.Stance.CRAWL, "rastejar antes da mesa")

	var passed: bool = await _walk_until(player, Vector2(0.0, 1.0), AXIS_Z, -4.7, true)
	assert_true(passed, "o bot não passou da mesa (z = %f)" % player.global_position.z)
	assert_eq(_table_violations, 0, "sob a mesa o corpo sempre esteve rastejando (ticks fora da postura: %d)" % _table_violations)
	assert_eq(motor.get_stance(), Enums.Stance.CRAWL, "depois da mesa continua rastejando")

	# Fora da mesa há espaço: rastejar -> agachar -> em pé.
	motor.set_scripted_input(WorldScript.edge_input(false, true))
	await wait_physics_frames(1)
	motor.set_scripted_input(MotorInput.new())
	assert_eq(motor.get_stance(), Enums.Stance.CROUCH, "fora da mesa, rastejar -> agachar")
	assert_almost_eq(motor.get_collider_height(), CROUCH_HEIGHT_M, HEIGHT_TOLERANCE_M, "colisor agachado fora da mesa")
	motor.set_scripted_input(WorldScript.edge_input(true, false))
	await wait_physics_frames(1)
	motor.set_scripted_input(MotorInput.new())
	assert_eq(motor.get_stance(), Enums.Stance.STAND, "fora da mesa, agachar -> em pé")
	assert_almost_eq(motor.get_collider_height(), STAND_HEIGHT_M, HEIGHT_TOLERANCE_M, "colisor em pé fora da mesa")


func test_sandbox_nao_levanta_sob_a_mesa() -> void:
	var level: Node3D = _load_level()
	var player: PlayerRoot = _player(level)
	var motor: PlayerMotor = player.get_motor()
	player.global_position = Vector3(3.0, 0.0, -2.3)
	await wait_physics_frames(SETTLE_FRAMES)
	motor.set_scripted_input(WorldScript.edge_input(false, true))
	await wait_physics_frames(1)
	motor.set_scripted_input(MotorInput.new())

	var inside: bool = await _walk_until(player, Vector2(0.0, 1.0), AXIS_Z, -3.5, true)
	assert_true(inside, "o bot não chegou ao meio da mesa (z = %f)" % player.global_position.z)
	# Sob o tampo (MOT-01): pedir para levantar não pode mudar a postura.
	motor.set_scripted_input(WorldScript.edge_input(false, true))
	await wait_physics_frames(1)
	motor.set_scripted_input(MotorInput.new())
	assert_eq(motor.get_stance(), Enums.Stance.CRAWL, "sob o tampo, o comando de levantar é ignorado (MOT-01)")
	assert_almost_eq(motor.get_collider_height(), 0.55, HEIGHT_TOLERANCE_M, "colisor continua rastejando sob a mesa")


func test_sandbox_sobe_a_escada_ate_o_mezanino_e_desce() -> void:
	var level: Node3D = _load_level()
	var player: PlayerRoot = _player(level)
	var motor: PlayerMotor = player.get_motor()
	player.global_position = Vector3(17.0, 0.0, -0.5)
	await wait_physics_frames(SETTLE_FRAMES)
	assert_eq(motor.get_stance(), Enums.Stance.STAND, "começa em pé, no pé da escada")

	var climbed: bool = await _walk_until(player, Vector2(0.0, 1.0), AXIS_Z, MEZZ_CLEAR_Z_M, true)
	assert_true(climbed, "o bot não chegou ao mezanino (z = %f, y = %f)" % [player.global_position.z, player.global_position.y])
	assert_almost_eq(player.global_position.y, MEZZ_TOP_M, FLOOR_Y_TOLERANCE_M, "sobre o mezanino a 1,08 m")
	assert_eq(motor.get_stance(), Enums.Stance.STAND, "sobe em pé: a cabeça tem folga sob o teto de 3,0 m")
	assert_eq(_airborne_ticks, 0, "a escada não deixa o corpo sem chão (ticks no ar: %d) [BUG-001]" % _airborne_ticks)

	var descended: bool = await _walk_until(player, Vector2(0.0, -1.0), AXIS_Z, -0.6, false)
	assert_true(descended, "o bot não desceu até o piso (z = %f, y = %f)" % [player.global_position.z, player.global_position.y])
	assert_almost_eq(player.global_position.y, 0.0, FLOOR_Y_TOLERANCE_M, "de volta ao piso do hall")
	assert_eq(_airborne_ticks, 0, "a descida também não deixa o corpo no ar (ticks no ar: %d) [BUG-001]" % _airborne_ticks)


func test_sandbox_nao_atravessa_paredes_da_sala_e_do_hall() -> void:
	var level: Node3D = _load_level()
	var player: PlayerRoot = _player(level)
	# Parede oeste da sala (x = 0): empurra para -X.
	player.global_position = Vector3(1.0, 0.0, -5.0)
	await wait_physics_frames(SETTLE_FRAMES)
	player.get_motor().set_scripted_input(WorldScript.move_input(Vector2(-1.0, 0.0)))
	await wait_physics_frames(120)
	player.get_motor().set_scripted_input(MotorInput.new())
	assert_true(player.global_position.x > WALL_FACE_X_M, "atravessou a parede oeste da sala (x = %f)" % player.global_position.x)

	# Parede oeste do hall (x = 14), no trecho ao sul do mezanino: empurra para -X.
	player.global_position = Vector3(15.0, 0.0, -2.0)
	await wait_physics_frames(SETTLE_FRAMES)
	player.get_motor().set_scripted_input(WorldScript.move_input(Vector2(-1.0, 0.0)))
	await wait_physics_frames(120)
	player.get_motor().set_scripted_input(MotorInput.new())
	assert_true(player.global_position.x > WALL_FACE_HALL_X_M, "atravessou a parede entre cozinha e hall (x = %f)" % player.global_position.x)


func test_sandbox_nao_atravessa_a_parede_do_corredor_fora_do_vao() -> void:
	var level: Node3D = _load_level()
	var player: PlayerRoot = _player(level)
	# Parede entre corredor e cozinha em z = -1,4, em x = 10 (o vão está em x = 8,5): empurra para -Z.
	player.global_position = Vector3(10.0, 0.0, -0.7)
	await wait_physics_frames(SETTLE_FRAMES)
	player.get_motor().set_scripted_input(WorldScript.move_input(Vector2(0.0, 1.0)))
	await wait_physics_frames(90)
	player.get_motor().set_scripted_input(MotorInput.new())
	assert_true(player.global_position.z > WALL_FACE_CORRIDOR_Z_M, "atravessou a parede do corredor fora do vão (z = %f)" % player.global_position.z)


func test_sandbox_vaos_sala_corredor_hall() -> void:
	var level: Node3D = _load_level()
	var player: PlayerRoot = _player(level)
	# Sala -> corredor pelo vão em x = 6, z = -0,7.
	player.global_position = Vector3(4.5, 0.0, -0.7)
	await wait_physics_frames(SETTLE_FRAMES)
	var in_corridor: bool = await _walk_until(player, Vector2(1.0, 0.0), AXIS_X, 7.0, false)
	assert_true(in_corridor, "não passou do vão sala -> corredor (x = %f)" % player.global_position.x)
	# Corredor -> hall pelo vão em x = 14, z = -0,7.
	var in_hall: bool = await _walk_until(player, Vector2(1.0, 0.0), AXIS_X, CORRIDOR_DOOR_X_M + 1.0, false)
	assert_true(in_hall, "não passou do vão corredor -> hall (x = %f)" % player.global_position.x)
	assert_eq(player.get_motor().get_stance(), Enums.Stance.STAND, "passa pelos vãos em pé")


func test_sandbox_vaos_sala_cozinha_corredor() -> void:
	var level: Node3D = _load_level()
	var player: PlayerRoot = _player(level)
	# Sala -> cozinha pelo vão em x = 6, z = -3,0.
	player.global_position = Vector3(4.5, 0.0, -3.0)
	await wait_physics_frames(SETTLE_FRAMES)
	var in_kitchen: bool = await _walk_until(player, Vector2(1.0, 0.0), AXIS_X, COOK_DOOR_X_M + 1.5, false)
	assert_true(in_kitchen, "não passou do vão sala -> cozinha (x = %f)" % player.global_position.x)
	# Cozinha -> corredor pelo vão em z = -1,4, x = 8,5 (andando para +Z).
	player.global_position = Vector3(8.5, 0.0, -2.5)
	await wait_physics_frames(SETTLE_FRAMES)
	var in_corridor: bool = await _walk_until(player, Vector2(0.0, -1.0), AXIS_Z, -0.7, false)
	assert_true(in_corridor, "não passou do vão cozinha -> corredor (z = %f)" % player.global_position.z)


func test_sandbox_contrato_de_marcadores_e_superficies() -> void:
	var level: Node3D = _load_level()
	var door_slots: Array[Node3D] = _in_group(level, &"door_slot")
	assert_eq(door_slots.size(), 4, "quatro door_slot (uma por abertura)")
	var seen_doors: Array[StringName] = []
	for slot: Node3D in door_slots:
		var door_id: StringName = StringName(str(slot.get_meta(&"door_id")))
		var state: StringName = StringName(str(slot.get_meta(&"start_state")))
		assert_true(DOOR_IDS.has(door_id), "door_id conhecido: %s" % door_id)
		assert_true(STATE_IDS.has(state), "start_state válido em %s: %s" % [door_id, state])
		seen_doors.append(door_id)
	assert_eq(seen_doors.size(), DOOR_IDS.size(), "door_id distintos")

	var pickups: Array[Node3D] = _in_group(level, &"pickup_slot")
	assert_eq(pickups.size(), 2, "dois pickup_slot")
	var persist_ids: Array[StringName] = []
	for pickup: Node3D in pickups:
		var persist_id: StringName = StringName(str(pickup.get_meta(&"persist_id")))
		assert_false(String(pickup.get_meta(&"item_id")).is_empty(), "item_id preenchido em %s" % persist_id)
		assert_false(persist_ids.has(persist_id), "persist_id único: %s" % persist_id)
		persist_ids.append(persist_id)

	var volumes: Array[Node3D] = _in_group(level, &"room_volume")
	assert_eq(volumes.size(), 4, "quatro room_volume (uma por sala)")
	for volume: Node3D in volumes:
		var area: Area3D = volume as Area3D
		assert_not_null(area, "room_volume é Area3D")
		if area != null:
			assert_eq(area.collision_layer, 128, "room_volume na camada 8 (trigger)")
		var room_id: StringName = StringName(str(volume.get_meta(&"room_id")))
		assert_true(ROOM_IDS.has(room_id), "room_id conhecido: %s" % room_id)

	var portals: Array[Node3D] = _in_group(level, &"portal")
	assert_eq(portals.size(), 4, "quatro portais (uma por abertura entre salas)")
	for portal: Node3D in portals:
		var room_a: StringName = StringName(str(portal.get_meta(&"room_a")))
		var room_b: StringName = StringName(str(portal.get_meta(&"room_b")))
		assert_true(ROOM_IDS.has(room_a) and ROOM_IDS.has(room_b), "portal liga salas conhecidas")

	var floors: Array[String] = ["sala", "cozinha", "corredor", "hall"]
	var expected_surfaces: Array[StringName] = [&"wood", &"tile", &"concrete", &"carpet"]
	for index: int in range(floors.size()):
		var body: Node = level.get_node("Geometry/Floors/Floor_" + floors[index])
		var surface: StringName = StringName(str(body.get_meta(&"surface")))
		assert_eq(surface, expected_surfaces[index], "superfície do piso da sala %s" % floors[index])
		assert_true(SURFACE_IDS.has(surface), "superfície válida do piso %s" % floors[index])

	var spawn: Node3D = level.get_node("PlayerSpawn") as Node3D
	assert_not_null(spawn, "PlayerSpawn existe")


## Anda com move até o eixo passar de target (below = true: fica menor que target; false: maior).
## Conta, sob a mesa, os ticks fora de CRAWL e, em todo o percurso, os ticks no ar.
func _walk_until(player: PlayerRoot, move: Vector2, axis: int, target: float, below: bool) -> bool:
	var motor: PlayerMotor = player.get_motor()
	motor.set_scripted_input(WorldScript.move_input(move))
	var frames: int = 0
	while not _past(player, axis, target, below) and frames < MAX_FRAMES:
		await wait_physics_frames(1)
		frames += 1
		_count_tick(player)
	motor.set_scripted_input(MotorInput.new())
	return _past(player, axis, target, below)


func _past(player: PlayerRoot, axis: int, target: float, below: bool) -> bool:
	var value: float = _axis_value(player.global_position, axis)
	if below:
		return value < target
	return value > target


func _axis_value(point: Vector3, axis: int) -> float:
	if axis == AXIS_X:
		return point.x
	if axis == AXIS_Y:
		return point.y
	return point.z


func _count_tick(player: PlayerRoot) -> void:
	var z: float = player.global_position.z
	var near_table: bool = z < TABLE_NEAR_Z_M + TABLE_MARGIN_M and z > TABLE_FAR_Z_M - TABLE_MARGIN_M
	var x: float = player.global_position.x
	if near_table and x > 2.0 and x < 4.0 and player.get_motor().get_stance() != Enums.Stance.CRAWL:
		_table_violations += 1
	if not player.is_on_floor() and player.global_position.y < 1.2:
		_airborne_ticks += 1


func _load_level() -> Node3D:
	var packed: PackedScene = load(LEVEL_PATH) as PackedScene
	assert_not_null(packed, "a sandbox carrega")
	return add_child_autofree(packed.instantiate()) as Node3D


func _player(level: Node3D) -> PlayerRoot:
	var player: PlayerRoot = level.get_node("Player") as PlayerRoot
	assert_not_null(player, "a sandbox tem o jogador instanciado")
	return player


func _in_group(root: Node, group: StringName) -> Array[Node3D]:
	var found: Array[Node3D] = []
	var pending: Array[Node] = [root]
	while not pending.is_empty():
		var node: Node = pending.pop_back()
		if node is Node3D and node.is_in_group(group):
			found.append(node as Node3D)
		for child: Node in node.get_children():
			pending.append(child)
	return found

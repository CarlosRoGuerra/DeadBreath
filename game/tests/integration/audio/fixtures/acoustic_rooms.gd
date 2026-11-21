extends RefCounted
## Fixture (F3-003b): nível com AcousticWorld e duas salas (RoomVolume com BoxShape3D). Sala A: x em [-3; 3], piso 22 dB,
## barramento reverb_small. Sala B: x em [7; 13], piso 38 dB (exterior), barramento reverb_large. Entre elas, um vão de
## 4 m sem portal. A pasta "fixtures" não é descoberta pelo runner: só é carregada pelos testes.

const ROOM_A_ID: StringName = &"room_a"
const ROOM_B_ID: StringName = &"room_b"
const ROOM_A_CENTER: Vector3 = Vector3(0.0, 0.0, 0.0)
const ROOM_B_CENTER: Vector3 = Vector3(10.0, 0.0, 0.0)
const ROOM_SIZE: Vector3 = Vector3(6.0, 3.0, 6.0)
const ROOM_A_FLOOR_DB: float = 22.0
const ROOM_B_FLOOR_DB: float = 38.0
const ROOM_A_BUS: StringName = &"reverb_small"
const ROOM_B_BUS: StringName = &"reverb_large"


## Cria o mundo e as duas salas dentro de `level` (já na árvore). Devolve {"world", "room_a", "room_b"}.
static func build_two_rooms(level: Node3D) -> Dictionary:
	var world: AcousticWorld = AcousticWorld.new()
	level.add_child(world)
	var room_a: RoomVolume = _room(level, ROOM_A_ID, ROOM_A_CENTER, ROOM_A_FLOOR_DB, ROOM_A_BUS)
	var room_b: RoomVolume = _room(level, ROOM_B_ID, ROOM_B_CENTER, ROOM_B_FLOOR_DB, ROOM_B_BUS)
	return {"world": world, "room_a": room_a, "room_b": room_b}


## Mundo sem salas (propagação provisória da F2), dentro de `level`.
static func build_plain_world(level: Node3D) -> AcousticWorld:
	var world: AcousticWorld = AcousticWorld.new()
	level.add_child(world)
	return world


static func _room(level: Node3D, id: StringName, center: Vector3, floor_db: float, bus: StringName) -> RoomVolume:
	var room: RoomVolume = RoomVolume.new()
	room.room_id = id
	room.ambient_floor_db = floor_db
	room.reverb_bus = bus
	room.position = center
	var shape: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = ROOM_SIZE
	shape.shape = box
	room.add_child(shape)
	level.add_child(room)
	return room

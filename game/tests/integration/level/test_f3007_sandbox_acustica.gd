extends TestCase
## F3-007 (TASK_BOARD §4c, DATA_STRUCTURES §2.3 e §2.5): contrato acústico da sandbox, sem física.
## Cobre: as seis salas são RoomVolume com piso de ruído e reverb de DATA §2.3; cada ponto de piso cai em uma única
## sala; os portais são Portal e ligam as salas certas; cada porta tem o nó que o portal aponta; há uma área exterior
## (quintal, 38 dB) com porta para dentro; os slots de arremessável têm metadados válidos.
## Autor: Level Designer (F3-007).

const SANDBOX_PATH: String = "res://content/levels/sandbox.tscn"
const EXPECTED_ROOMS: Dictionary = {
	&"sala": [28.0, &"reverb_small"],
	&"cozinha": [22.0, &"reverb_small"],
	&"corredor": [22.0, &"reverb_large"],
	&"hall": [22.0, &"reverb_large"],
	&"mezanino": [22.0, &"reverb_small"],
	&"quintal": [38.0, &""],
}
const EXPECTED_PORTALS: Dictionary = {
	&"portal_sala_corredor": [&"sala", &"corredor"],
	&"portal_sala_cozinha": [&"sala", &"cozinha"],
	&"portal_cozinha_corredor": [&"cozinha", &"corredor"],
	&"portal_corredor_hall": [&"corredor", &"hall"],
	&"portal_hall_quintal": [&"hall", &"quintal"],
	&"portal_hall_mezanino": [&"hall", &"mezanino"],
}
## Um ponto de piso (y 0,5 m) em cada sala, longe das paredes e das divisas (DATA §2.3, RoomVolume é piso a teto).
const FLOOR_SAMPLES: Dictionary = {
	&"sala": Vector3(0.5, 0.5, -5.5),
	&"cozinha": Vector3(10.0, 0.5, -4.5),
	&"corredor": Vector3(10.0, 0.5, -0.7),
	&"hall": Vector3(16.0, 0.5, -1.2),
	&"mezanino": Vector3(15.0, 0.5, -4.5),
	&"quintal": Vector3(22.0, 0.5, -3.0),
}
const THROWABLE_SIZES: Array[StringName] = [&"light", &"medium", &"heavy"]

var _level: Node3D = null


## A cena é carregada uma vez para o arquivo inteiro: nenhum teste daqui altera a sandbox (só consultam).
## Orçamento da suíte padrão < 10 s (Director, integração da F3-007).
func before_all() -> void:
	var packed: PackedScene = load(SANDBOX_PATH) as PackedScene
	_level = packed.instantiate() as Node3D
	add_child(_level)


func after_all() -> void:
	await release_and_flush(_level)
	_level = null


func test_seis_salas_com_piso_de_ruido_e_reverb() -> void:
	var rooms: Array[RoomVolume] = _rooms()
	assert_eq(rooms.size(), EXPECTED_ROOMS.size(), "seis RoomVolume")
	for room: RoomVolume in rooms:
		assert_true(EXPECTED_ROOMS.has(room.room_id), "room_id conhecido: %s" % room.room_id)
		if not EXPECTED_ROOMS.has(room.room_id):
			continue
		var expected: Array = EXPECTED_ROOMS[room.room_id]
		assert_almost_eq(room.ambient_floor_db, float(expected[0]), 0.0001, "piso de ruído de %s" % room.room_id)
		assert_eq(room.reverb_bus, StringName(expected[1]), "reverb de %s" % room.room_id)


func test_cada_ponto_de_piso_cai_em_uma_so_sala() -> void:
	var rooms: Array[RoomVolume] = _rooms()
	for room_id: StringName in FLOOR_SAMPLES.keys():
		var point: Vector3 = FLOOR_SAMPLES[room_id]
		var hits: Array[StringName] = []
		for room: RoomVolume in rooms:
			if room.bounds_world().has_point(point):
				hits.append(room.room_id)
		assert_eq(hits, [room_id] as Array[StringName], "ponto de piso de %s cai só nessa sala" % room_id)


func test_portais_sao_portal_e_ligam_as_salas_certas() -> void:
	var portals: Array[Portal] = _portals()
	assert_eq(portals.size(), EXPECTED_PORTALS.size(), "seis portais")
	var seen: Array[StringName] = []
	for portal: Portal in portals:
		assert_true(EXPECTED_PORTALS.has(portal.portal_id), "portal_id conhecido: %s" % portal.portal_id)
		if not EXPECTED_PORTALS.has(portal.portal_id):
			continue
		seen.append(portal.portal_id)
		var pair: Array = EXPECTED_PORTALS[portal.portal_id]
		assert_eq(portal.room_a, StringName(pair[0]), "room_a de %s" % portal.portal_id)
		assert_eq(portal.room_b, StringName(pair[1]), "room_b de %s" % portal.portal_id)
	assert_eq(seen.size(), EXPECTED_PORTALS.size(), "portal_id distintos")


func test_portas_apontam_para_o_no_que_o_levelslots_cria() -> void:
	# Na sandbox pura não há LevelSlots, então a porta ainda não existe: o caminho do portal tem de cair no slot
	# (DoorSlot_<door_id>), que é o pai onde o LevelSlots cria a porta com nome = door_id. A ligação real é testada
	# na sandbox jogável (test_f3007_porta_playable).
	var portals: Array[Portal] = _portals()
	for portal: Portal in portals:
		if portal.door.is_empty():
			assert_eq(portal.portal_id, &"portal_hall_mezanino", "só o vão hall-mezanino é sem porta")
			continue
		var door_id: String = "door_" + String(portal.portal_id).trim_prefix("portal_")
		var slot: Node = portal.get_node_or_null(NodePath("../../Openings/DoorSlot_" + door_id))
		assert_not_null(slot, "o portal %s aponta para o slot de %s" % [portal.portal_id, door_id])
		assert_eq(String(portal.door).get_file(), door_id, "o caminho de %s termina em %s" % [portal.portal_id, door_id])


func test_area_exterior_tem_porta_para_dentro_e_sem_teto() -> void:
	var yard: RoomVolume = _room(&"quintal")
	assert_not_null(yard, "quintal existe")
	if yard == null:
		return
	assert_almost_eq(yard.ambient_floor_db, 38.0, 0.0001, "exterior: 38 dB (DATA §2.3)")
	var doors: Array[Node3D] = _in_group(_level, &"door_slot")
	var found_yard_door: bool = false
	for slot: Node3D in doors:
		if StringName(str(slot.get_meta(&"door_id"))) == &"door_hall_quintal":
			found_yard_door = true
			assert_true(yard.bounds_world().grow(0.05).has_point(slot.global_position), "a porta do quintal está na borda do quintal")
	assert_true(found_yard_door, "porta hall -> quintal existe")
	var ceilings: Node = _level.get_node("Geometry/Ceilings")
	assert_null(ceilings.get_node_or_null("Ceil_quintal"), "o quintal não tem teto")


func test_arremessaveis_tem_metadados_validos() -> void:
	var slots: Array[Node3D] = _in_group(_level, &"throwable_slot")
	assert_eq(slots.size(), 5, "cinco throwable_slot (F3-004 instancia nelas)")
	var ids: Array[StringName] = []
	for slot: Node3D in slots:
		var throwable_id: StringName = StringName(str(slot.get_meta(&"throwable_id")))
		var size: StringName = StringName(str(slot.get_meta(&"size")))
		assert_false(String(throwable_id).is_empty(), "throwable_id preenchido")
		assert_false(ids.has(throwable_id), "throwable_id único: %s" % throwable_id)
		ids.append(throwable_id)
		assert_true(THROWABLE_SIZES.has(size), "size válido em %s: %s" % [throwable_id, size])
		assert_true(_room_containing(slot.global_position) != &"", "%s está dentro de uma sala" % throwable_id)


## RoomVolume do nível, na ordem da árvore.
func _rooms() -> Array[RoomVolume]:
	var out: Array[RoomVolume] = []
	for node: Node3D in _in_group(_level, &"room_volume"):
		var room: RoomVolume = node as RoomVolume
		if room != null:
			out.append(room)
	return out


func _portals() -> Array[Portal]:
	var out: Array[Portal] = []
	for node: Node3D in _in_group(_level, &"portal"):
		var portal: Portal = node as Portal
		if portal != null:
			out.append(portal)
	return out


func _room(room_id: StringName) -> RoomVolume:
	for room: RoomVolume in _rooms():
		if room.room_id == room_id:
			return room
	return null


func _room_containing(point: Vector3) -> StringName:
	for room: RoomVolume in _rooms():
		if room.bounds_world().has_point(point):
			return room.room_id
	return &""


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

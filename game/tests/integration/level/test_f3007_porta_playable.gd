extends TestCase
## F3-007 (DATA_STRUCTURES §2.3 e §2.5; COMPONENT_CONTRACTS §6.5): na sandbox jogável, com as portas instanciadas
## pelo LevelSlots, o grafo do AcousticWorld tem as salas e os portais, a porta real sincroniza o portal, a porta
## fechada ou aberta muda o nível percebido entre salas vizinhas, e o trovão eleva o limiar em cada sala.
## Autor: Level Designer (F3-007).

const PLAYABLE_PATH: String = "res://content/levels/sandbox_playable.tscn"
const TOL: float = 0.0001
const DELTA_DB: float = 15.0
## Corredor -> hall pela porta door_corredor_hall (em z = -0,7, x = 14). Único caminho entre as duas salas.
const SOURCE_CORRIDOR: Vector3 = Vector3(10.0, 1.0, -0.7)
const LISTENER_HALL: Vector3 = Vector3(16.0, 1.0, -0.7)
const POINTS_BY_ROOM: Dictionary = {
	&"sala": Vector3(0.5, 0.5, -5.5),
	&"cozinha": Vector3(10.0, 0.5, -4.5),
	&"corredor": Vector3(10.0, 0.5, -0.7),
	&"hall": Vector3(16.0, 0.5, -1.2),
	&"mezanino": Vector3(15.0, 0.5, -4.5),
	&"quintal": Vector3(22.0, 0.5, -3.0),
}
const FLOOR_DB: Dictionary = {
	&"sala": 28.0,
	&"cozinha": 22.0,
	&"corredor": 22.0,
	&"hall": 22.0,
	&"mezanino": 22.0,
	&"quintal": 38.0,
}
## Estado inicial das portas (LevelSlots) e do portal sem porta.
const INITIAL_PORTALS: Dictionary = {
	&"portal_sala_corredor": false,
	&"portal_sala_cozinha": true,
	&"portal_cozinha_corredor": false,
	&"portal_corredor_hall": false,
	&"portal_hall_quintal": false,
	&"portal_hall_mezanino": true,
}

var _root: Node = null


## A cena é carregada uma vez para o arquivo inteiro. Só um teste muda estado (abre a porta corredor-hall), e
## nenhum outro depende do estado das portas: room_at, piso e limiar com trovão não mudam com elas.
## Orçamento da suíte padrão < 10 s (Director, integração da F3-007).
func before_all() -> void:
	var scene: PackedScene = load(PLAYABLE_PATH) as PackedScene
	_root = scene.instantiate()
	add_child(_root)
	await wait_physics_frames(2)


func after_all() -> void:
	await release_and_flush(_root)
	_root = null


func _world() -> AcousticWorld:
	return _root.get_node("AcousticWorld") as AcousticWorld


func _door(door_id: String) -> Door:
	return _root.get_node("Level/Openings/DoorSlot_%s/%s" % [door_id, door_id]) as Door


func test_grafo_tem_as_seis_salas_e_o_piso_certo_em_cada_ponto() -> void:
	var graph: AcousticGraph = _world().get_graph()
	assert_true(_world().has_geometry(), "o nível tem geometria acústica")
	for room_id: StringName in POINTS_BY_ROOM.keys():
		var point: Vector3 = POINTS_BY_ROOM[room_id]
		assert_eq(graph.room_at(point), room_id, "room_at do ponto de %s" % room_id)
		assert_almost_eq(graph.ambient_floor_at(point), float(FLOOR_DB[room_id]), TOL, "piso de ruído de %s" % room_id)


## Único teste que muda estado: começa com as portas como o LevelSlots criou.
func test_portas_nascem_com_o_estado_do_slot_e_a_porta_real_muda_15_db() -> void:
	var graph: AcousticGraph = _world().get_graph()
	for portal_id: StringName in INITIAL_PORTALS.keys():
		assert_eq(graph.is_portal_open(portal_id), INITIAL_PORTALS[portal_id], "estado inicial de %s" % portal_id)
	var door: Door = _door("door_corredor_hall")
	assert_not_null(door, "a porta door_corredor_hall foi instanciada pelo LevelSlots")
	if door == null:
		return
	assert_eq(door.get_state(), Door.State.CLOSED, "a porta nasce fechada")
	# A porta é a única rota entre as duas salas: fechada 18 dB, aberta 3 dB (DATA §2.2, STL-03 no nível real).
	var sound: NoiseEvent = NoiseEvent.create(Enums.NoiseCategory.VOICE, SOURCE_CORRIDOR, 60.0, 1.0, &"enemy_test", &"voice_test")
	var closed: PropagationResult = graph.propagate(sound, LISTENER_HALL)
	door.interact(InteractionContext.new())
	assert_true(graph.is_portal_open(&"portal_corredor_hall"), "abrir a porta abre o portal (state_changed)")
	var opened: PropagationResult = graph.propagate(sound, LISTENER_HALL)
	assert_almost_eq(opened.perceived_db - closed.perceived_db, DELTA_DB, TOL, "fechada -> aberta: 18 - 3 = 15 dB")
	assert_eq(closed.path_portals, [&"portal_corredor_hall"] as Array[StringName], "fechada: a rota passa pela porta")
	assert_eq(opened.path_portals, [&"portal_corredor_hall"] as Array[StringName], "aberta: a rota passa pela porta")
	# F3-004: a porta fecha pela interação, mas só com ela aberta e parada. Durante o movimento de abertura, uma
	# segunda interação não inverte: o portal segue aberto (o fechamento completo é testado na F3-004).
	door.interact(InteractionContext.new())
	assert_true(graph.is_portal_open(&"portal_corredor_hall"), "segunda interação durante o movimento não fecha: o portal segue aberto")


func test_trovao_eleva_o_limiar_em_cada_sala() -> void:
	# Chuva por sala (DATA §2.3): o trovão soma +20 dB ao piso de cada sala no limiar de audibilidade.
	var graph: AcousticGraph = _world().get_graph()
	graph.set_weather_floor_offset(0.0)
	for room_id: StringName in POINTS_BY_ROOM.keys():
		var point: Vector3 = POINTS_BY_ROOM[room_id]
		var quiet: float = graph.effective_threshold_db(point, 10.0, 0.0)
		graph.set_weather_floor_offset(20.0)
		var storm: float = graph.effective_threshold_db(point, 10.0, 0.0)
		graph.set_weather_floor_offset(0.0)
		assert_almost_eq(storm - quiet, 20.0, TOL, "trovão em %s: +20 dB no limiar" % room_id)

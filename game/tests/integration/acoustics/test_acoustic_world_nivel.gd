extends TestCase
## F3-002 (COMPONENT_CONTRACTS §6.2, §6.3 e §6.5; DATA_STRUCTURES §2.3 e §2.5): AcousticWorld com a geometria do nível.
## Cobre: porta fechada e aberta (sincronizada por state_changed), trovão (limiar e sinal), ouvinte do jogador (só
## outras fontes, sem dados da fonte), room_id preenchido, legendas, NoiseEmitter, e a cena sem salas mantendo a F2.
## Autor: AI Engineer (F3-002).

const Fx := preload("res://tests/unit/acoustics/fixtures/acoustic_fixture.gd")
const DOOR_SCENE_PATH: String = "res://components/world/door.tscn"
const TOL: float = 0.0001
const LISTENER_IN_B: Vector3 = Vector3(2.0, 1.5, 0.0)
const SOURCE_IN_A: Vector3 = Vector3(-2.0, 1.5, 0.0)

var _level: Node3D = null
var _world: AcousticWorld = null
var _ear: Node3D = null
var _events: Array[NoiseEvent] = []
var _results: Array[PropagationResult] = []
var _heard: Array[PlayerHeardNoise] = []
var _subtitles: Array[StringName] = []
var _subtitle_durations: Array[float] = []
var _thunders: int = 0


func before_each() -> void:
	_events = []
	_results = []
	_heard = []
	_subtitles = []
	_subtitle_durations = []
	_thunders = 0
	_level = Node3D.new()
	add_child_autofree(_level)
	_world = AcousticWorld.new()
	_level.add_child(_world)
	_world.noise_resolved_for_player.connect(_collect_event)
	_world.thunder_started.connect(_collect_thunder)
	_ear = Node3D.new()
	_ear.position = LISTENER_IN_B
	_level.add_child(_ear)
	EventBus.subtitle_requested.connect(_collect_subtitle)


func after_each() -> void:
	if EventBus.subtitle_requested.is_connected(_collect_subtitle):
		EventBus.subtitle_requested.disconnect(_collect_subtitle)


func _collect_event(event: NoiseEvent, result: PropagationResult) -> void:
	_events.append(event)
	_results.append(result)


func _collect_heard(heard: PlayerHeardNoise) -> void:
	_heard.append(heard)


func _collect_subtitle(text_key: StringName, duration: float) -> void:
	_subtitles.append(text_key)
	_subtitle_durations.append(duration)


func _collect_thunder(_duration_s: float) -> void:
	_thunders += 1


## Sala como RoomVolume com caixa de colisão: centro, tamanho e piso (DATA §2.3).
func _room(id: StringName, centre: Vector3, size: Vector3, floor_db: float) -> RoomVolume:
	var room: RoomVolume = RoomVolume.new()
	room.room_id = id
	room.ambient_floor_db = floor_db
	room.position = centre
	var shape_node: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = size
	shape_node.shape = box
	room.add_child(shape_node)
	_level.add_child(room)
	return room


## Duas salas (a: x −10..0, b: x 0..10) separadas por uma parede com o portal "porta" no meio. A porta é uma
## Door real (components/world/door.tscn), filha do portal, fechada no início.
func _build_two_rooms() -> Door:
	_room(&"a", Vector3(-5.0, 1.5, 0.0), Vector3(10.0, 3.0, 10.0), 22.0)
	_room(&"b", Vector3(5.0, 1.5, 0.0), Vector3(10.0, 3.0, 10.0), 22.0)
	var portal: Portal = Portal.new()
	portal.portal_id = &"porta"
	portal.room_a = &"a"
	portal.room_b = &"b"
	portal.door = NodePath("Door")
	portal.position = Vector3(0.0, 1.5, 0.0)
	_level.add_child(portal)
	var door: Door = (load(DOOR_SCENE_PATH) as PackedScene).instantiate() as Door
	door.name = "Door"
	portal.add_child(door)
	return door


func _script_var_names(instance: Object) -> PackedStringArray:
	var names: PackedStringArray = PackedStringArray()
	var properties: Array = instance.get_property_list()
	for prop: Dictionary in properties:
		if (int(prop.get("usage", 0)) & PROPERTY_USAGE_SCRIPT_VARIABLE) != 0:
			names.append(str(prop.get("name")))
	names.sort()
	return names


func test_room_volume_envolve_a_caixa_de_colisao() -> void:
	var room: RoomVolume = _room(&"sala", Vector3(-5.0, 1.5, 0.0), Vector3(10.0, 3.0, 10.0), 22.0)
	var bounds: AABB = room.bounds_world()
	assert_almost_eq(bounds.position.x, -10.0, TOL, "x mínimo")
	assert_almost_eq(bounds.end.x, 0.0, TOL, "x máximo")
	assert_almost_eq(bounds.position.y, 0.0, TOL, "y mínimo")
	assert_almost_eq(bounds.end.y, 3.0, TOL, "y máximo")
	assert_almost_eq(bounds.size.z, 10.0, TOL, "profundidade")


func test_porta_fechada_reduz_15_db_e_abrir_sobe_o_nivel() -> void:
	# DATA §2.2 / STL-03 no nível real: a porta é a rota (18 dB fechada, 3 dB aberta). O estado chega ao grafo por
	# state_changed da Door, sem que o teste mexa no portal.
	var door: Door = _build_two_rooms()
	var graph: AcousticGraph = _world.get_graph()
	assert_eq(door.get_state(), Door.State.CLOSED, "a porta nasce fechada")
	assert_false(graph.is_portal_open(&"porta"), "porta fechada: portal fechado")
	var sound: NoiseEvent = Fx.event(60.0, SOURCE_IN_A)
	var closed: PropagationResult = graph.propagate(sound, LISTENER_IN_B)
	door.interact(InteractionContext.new())
	assert_eq(door.get_state(), Door.State.OPEN, "a porta abriu")
	assert_true(graph.is_portal_open(&"porta"), "state_changed da porta levou o portal a aberto")
	var opened: PropagationResult = graph.propagate(sound, LISTENER_IN_B)
	assert_almost_eq(opened.perceived_db - closed.perceived_db, 15.0, TOL, "fechada → aberta: 18 − 3 = 15 dB")
	assert_eq(closed.path_portals, [&"porta"], "fechada: a rota ainda passa pela porta (18 dB < 25 dB da parede)")


func test_portal_sem_porta_nasce_aberto() -> void:
	_room(&"a", Vector3(-5.0, 1.5, 0.0), Vector3(10.0, 3.0, 10.0), 22.0)
	_room(&"b", Vector3(5.0, 1.5, 0.0), Vector3(10.0, 3.0, 10.0), 22.0)
	var portal: Portal = Portal.new()
	portal.portal_id = &"aberta"
	portal.room_a = &"a"
	portal.room_b = &"b"
	portal.position = Vector3(0.0, 1.5, 0.0)
	_level.add_child(portal)
	assert_true(_world.get_graph().is_portal_open(&"aberta"), "D-09: portal sem porta nasce aberto")


func test_trovao_eleva_o_limiar_e_dispara_o_sinal() -> void:
	_build_two_rooms()
	_world.thunder_enabled = true
	_world.thunder_interval_min_s = 5.0
	_world.thunder_interval_max_s = 5.0
	var graph: AcousticGraph = _world.get_graph()
	var listener: Vector3 = SOURCE_IN_A
	var quiet: float = graph.effective_threshold_db(listener, Fx.OBSERVER_HEARING_DB, Fx.OBSERVER_MARGIN_DB)
	assert_almost_eq(quiet, 19.0, TOL, "Observer na sala de piso 22: 22 − 3 = 19 dB")
	for _step: int in range(4):
		_world.advance(1.0)
	assert_eq(_thunders, 0, "antes do intervalo de 5 s não há trovão")
	assert_almost_eq(_world.get_weather_offset(), 0.0, TOL, "sem trovão, offset zero")
	_world.advance(1.5)
	assert_eq(_thunders, 1, "trovão no 5º segundo dispara thunder_started")
	assert_almost_eq(_world.get_weather_offset(), 20.0, TOL, "+20 dB no piso durante o trovão")
	assert_almost_eq(graph.effective_threshold_db(listener, Fx.OBSERVER_HEARING_DB, Fx.OBSERVER_MARGIN_DB), 39.0, TOL,
		"trovão eleva o limiar: 22 + 20 − 3 = 39 dB")
	_world.advance(0.6)
	assert_almost_eq(_world.get_weather_offset(), 20.0, TOL, "ainda dentro dos 2,5 s")
	_world.advance(2.0)
	assert_almost_eq(_world.get_weather_offset(), 0.0, TOL, "depois de 2,5 s o offset volta a zero")
	assert_eq(_thunders, 1, "um trovão no intervalo")


func test_ouvinte_do_jogador_recebe_so_outras_fontes_sem_dados_da_fonte() -> void:
	_build_two_rooms()
	_world.register_player_listener(Callable(self, &"_collect_heard"), _ear)
	_world.emit_noise(NoiseEvent.create(Enums.NoiseCategory.BREATHING, LISTENER_IN_B, 40.0, 1.0, &"player", &"breath_calm"))
	_world.emit_noise(NoiseEvent.create(Enums.NoiseCategory.VOICE, SOURCE_IN_A, 75.0, 1.0, &"enemy_guard", &"voice_chase_shout"))
	_world.emit_noise(NoiseEvent.create(Enums.NoiseCategory.DOOR, SOURCE_IN_A, 60.0, 0.4, &"door_front", &"door_slam"))
	_world.emit_noise(NoiseEvent.create(Enums.NoiseCategory.BREATHING, SOURCE_IN_A, 10.0, 1.0, &"far_away", &"breath_calm"))
	_world.advance(0.0)
	assert_eq(_heard.size(), 2, "o próprio jogador e o som inaudível não são entregues")
	if _heard.size() != 2:
		return
	var enemy: PlayerHeardNoise = _heard[0]
	var door: PlayerHeardNoise = _heard[1]
	assert_eq(enemy.category, Enums.NoiseCategory.VOICE, "categoria do inimigo")
	assert_true(enemy.source_is_enemy, "source_is_enemy para emissor 'enemy_*'")
	assert_eq(enemy.sound_id, &"voice_chase_shout", "sound_id passa adiante")
	assert_almost_eq(enemy.perceived_db, 75.0 - Fx.distance_loss_db(4.0) - 18.0, 0.001,
		"nível percebido pela rota da porta fechada")
	assert_false(door.source_is_enemy, "porta de outra fonte não é inimiga")
	assert_eq(door.category, Enums.NoiseCategory.DOOR, "categoria da porta")
	assert_eq(_script_var_names(enemy), PackedStringArray(["category", "perceived_db", "sound_id", "source_is_enemy",
		"timestamp"]), "PlayerHeardNoise tem só os campos permitidos (NOI-INV-4)")


func test_room_id_e_preenchido_pelo_mundo() -> void:
	_build_two_rooms()
	var in_a: NoiseEvent = NoiseEvent.create(Enums.NoiseCategory.BREATHING, SOURCE_IN_A, 40.0, 1.0, &"player", &"breath_calm")
	var in_b: NoiseEvent = NoiseEvent.create(Enums.NoiseCategory.BREATHING, LISTENER_IN_B, 40.0, 1.0, &"player", &"breath_calm")
	var outside: NoiseEvent = NoiseEvent.create(Enums.NoiseCategory.BREATHING, Vector3(50.0, 0.0, 50.0), 40.0, 1.0,
		&"player", &"breath_calm")
	_world.emit_noise(in_a)
	_world.emit_noise(in_b)
	_world.emit_noise(outside)
	assert_eq(in_a.room_id, &"a", "evento na sala a")
	assert_eq(in_b.room_id, &"b", "evento na sala b")
	assert_eq(outside.room_id, &"", "fora de qualquer sala")


func test_sem_salas_o_mundo_mantem_a_regra_provisoria_da_f2() -> void:
	# Outro nível (outra subárvore), sem RoomVolume: o mundo não enxerga as salas de _level.
	_build_two_rooms()
	var plain_root: Node3D = Node3D.new()
	add_child_autofree(plain_root)
	var plain: AcousticWorld = AcousticWorld.new()
	plain_root.add_child(plain)
	var plain_ear: Node3D = Node3D.new()
	plain_ear.position = Vector3(0.0, 0.0, 10.0)
	plain_root.add_child(plain_ear)
	plain.set_player_ear(plain_ear)
	plain.noise_resolved_for_player.connect(_collect_event)
	assert_false(plain.has_geometry(), "nível sem RoomVolume não tem geometria")
	var event: NoiseEvent = NoiseEvent.create(Enums.NoiseCategory.BREATHING, Vector3.ZERO, 40.0, 1.0, &"player", &"breath_calm")
	var expected: PropagationResult = AcousticPropagation.perceive(event, plain_ear.global_position)
	plain.emit_noise(event)
	plain.advance(0.0)
	assert_eq(_results.size(), 1, "um resultado")
	if _results.size() == 1:
		assert_almost_eq(_results[0].perceived_db, expected.perceived_db, TOL, "40 dB a 10 m = 19 dB, como na F2")
		assert_true(_results[0].path_portals.is_empty(), "sem geometria não há portal")
	assert_eq(event.room_id, &"", "sem salas, room_id fica vazio")


func test_legendas_para_sons_relevantes_audiveis() -> void:
	_build_two_rooms()
	_world.set_player_ear(_ear)
	# Tosse do próprio jogador: legenda. O pigarro (cough_warning) não é a tosse: sem legenda.
	_world.emit_noise(NoiseEvent.create(Enums.NoiseCategory.COUGHING, LISTENER_IN_B, 65.0, 1.0, &"player", &"cough"))
	_world.emit_noise(NoiseEvent.create(Enums.NoiseCategory.COUGHING, LISTENER_IN_B, 32.0, 1.5, &"player", &"cough_warning"))
	# Passo do próprio jogador: não é "passo próximo". Passo distante de outra fonte: abaixo de limiar + 10 dB.
	_world.emit_noise(NoiseEvent.create(Enums.NoiseCategory.FOOTSTEP, LISTENER_IN_B, 40.0, 0.5, &"player", &"step_walk"))
	_world.emit_noise(NoiseEvent.create(Enums.NoiseCategory.FOOTSTEP, SOURCE_IN_A, 40.0, 0.5, &"enemy_guard", &"step_walk"))
	# Passo próximo de outra fonte: legenda.
	_world.emit_noise(NoiseEvent.create(Enums.NoiseCategory.FOOTSTEP, Vector3(1.0, 1.5, 0.0), 70.0, 0.5, &"enemy_guard",
		&"step_walk"))
	# Fala e porta audíveis: legenda.
	_world.emit_noise(NoiseEvent.create(Enums.NoiseCategory.VOICE, SOURCE_IN_A, 75.0, 1.0, &"enemy_guard", &"voice_chase_shout"))
	_world.emit_noise(NoiseEvent.create(Enums.NoiseCategory.DOOR, SOURCE_IN_A, 75.0, 0.4, &"door_front", &"door_slam"))
	_world.advance(0.0)
	assert_eq(_subtitles, [&"subtitle.cough", &"subtitle.step_walk", &"subtitle.voice_chase_shout", &"subtitle.door_slam"],
		"tosse, passo próximo, fala e porta; sem pigarro, passo do jogador, nem passo distante")
	if _subtitle_durations.size() > 0:
		assert_almost_eq(_subtitle_durations[0], 1.5, TOL, "duração mínima de 1,5 s")
	_world.emit_noise(NoiseEvent.create(Enums.NoiseCategory.COUGHING, LISTENER_IN_B, 65.0, 1.0, &"player", &"cough"))
	_world.advance(0.0)
	assert_eq(_subtitles.size(), 4, "a mesma tosse não repete antes de 2 s")
	_world.advance(2.0)
	_world.emit_noise(NoiseEvent.create(Enums.NoiseCategory.COUGHING, LISTENER_IN_B, 65.0, 1.0, &"player", &"cough"))
	_world.advance(0.0)
	assert_eq(_subtitles.size(), 5, "depois de 2 s, a tosse volta a ser legendada")


func test_emissor_de_fonte_do_mundo_entrega_ao_mundo() -> void:
	_build_two_rooms()
	var emitter: NoiseEmitter = NoiseEmitter.new()
	emitter.source_id = &"door_front"
	emitter.position = SOURCE_IN_A
	_level.add_child(emitter)
	emitter.emit_noise(Enums.NoiseCategory.DOOR, 50.0, 0.4, &"door_normal")
	_world.advance(0.0)
	assert_eq(_events.size(), 1, "um evento do emissor")
	if _events.size() != 1:
		return
	var event: NoiseEvent = _events[0]
	assert_eq(event.source_id, &"door_front", "fonte do emissor")
	assert_eq(event.room_id, &"a", "sala preenchida pelo mundo")
	assert_eq(event.position, SOURCE_IN_A, "posição global do emissor")
	assert_almost_eq(event.intensity_db, 50.0, TOL, "intensidade entregue")

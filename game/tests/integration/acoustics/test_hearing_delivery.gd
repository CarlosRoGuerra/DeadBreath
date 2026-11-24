extends TestCase
## F4-002 (COMPONENT_CONTRACTS §6.2 e §7.2; DATA_STRUCTURES §2.3, §3.1 e D-07): entrega do AcousticWorld aos
## HearingSensor do nível. Cenários com salas, portas (portais) e trovão, com o limiar efetivo de cada sensor.
## Contas à mão: perda a 2 m = 20·log10(2) + 0,2 = 6,2206 dB. Porão (piso 12): limiar do Observer = max(15; 12 − 3) = 15;
## limiar do Aggressive = max(24; 12 + 3) = 24. Interior (piso 22): Observer = max(15; 19) = 19; trovão soma 20 → 39.
## Autor: AI Engineer (F4-002).

const Fx := preload("res://tests/unit/acoustics/fixtures/acoustic_fixture.gd")
const TOL: float = 0.0001
const SEED: int = 7
const AGGRESSIVE_THRESHOLD_DB: float = 24.0
const AGGRESSIVE_MARGIN_DB: float = 3.0
const SOURCE: Vector3 = Vector3(-1.0, 1.5, 0.0)
const OBSERVER_SPOT: Vector3 = Vector3(1.0, 1.5, 0.0)
const AGGRESSIVE_SPOT: Vector3 = Vector3(-1.0, 1.5, 2.0)
const SOURCE_IN_A: Vector3 = Vector3(-2.0, 1.5, 0.0)
const LISTENER_IN_B: Vector3 = Vector3(2.0, 1.5, 0.0)

var _level: Node3D = null
var _world: AcousticWorld = null
var _ear: Node3D = null


func before_each() -> void:
	_level = Node3D.new()
	add_child_autofree(_level)
	_world = AcousticWorld.new()
	_world.acoustics_seed = SEED
	_level.add_child(_world)
	_ear = Node3D.new()
	_ear.position = Vector3(100.0, 0.0, 100.0)
	_level.add_child(_ear)
	_world.set_player_ear(_ear)


func _room(parent: Node3D, id: StringName, centre: Vector3, size: Vector3, floor_db: float) -> void:
	var room: RoomVolume = RoomVolume.new()
	room.room_id = id
	room.ambient_floor_db = floor_db
	room.position = centre
	var shape_node: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = size
	shape_node.shape = box
	room.add_child(shape_node)
	parent.add_child(room)


func _sensor(parent: Node3D, at: Vector3, owner_id: StringName, threshold_db: float, margin_db: float) -> HearingSensor:
	var sensor: HearingSensor = HearingSensor.new()
	sensor.owner_id = owner_id
	sensor.hearing_threshold_db = threshold_db
	sensor.masking_margin_db = margin_db
	sensor.position = at
	parent.add_child(sensor)
	return sensor


func _emit(world: AcousticWorld, intensity_db: float, at: Vector3, source: StringName) -> void:
	world.emit_noise(NoiseEvent.create(Enums.NoiseCategory.FOOTSTEP, at, intensity_db, 0.5, source, &"step_walk"))


func _observer(parent: Node3D, at: Vector3, owner_id: StringName) -> HearingSensor:
	return _sensor(parent, at, owner_id, Fx.OBSERVER_HEARING_DB, Fx.OBSERVER_MARGIN_DB)


func test_observer_ouve_no_porao_o_que_o_aggressive_nao_ouve() -> void:
	# Porão (piso 12). A 2 m: 30 dB → 23,78 (≥ 15, < 24); 45 dB → 38,78 (ambos); 10 dB → 3,78 (nenhum).
	_room(_level, &"porao", Vector3(0.0, 1.5, 0.0), Vector3(10.0, 3.0, 10.0), 12.0)
	var observer: HearingSensor = _observer(_level, OBSERVER_SPOT, &"enemy_observer")
	var aggressive: HearingSensor = _sensor(_level, AGGRESSIVE_SPOT, &"enemy_aggressive", AGGRESSIVE_THRESHOLD_DB,
		AGGRESSIVE_MARGIN_DB)
	_emit(_world, 30.0, SOURCE, &"player")
	_emit(_world, 45.0, SOURCE, &"player")
	_emit(_world, 10.0, SOURCE, &"player")
	assert_eq(observer.drain().size(), 0, "o som só é entregue no tick, não no emit")
	_world.advance(0.0)
	var heard_observer: Array[HeardNoise] = observer.drain()
	var heard_aggressive: Array[HeardNoise] = aggressive.drain()
	assert_eq(heard_observer.size(), 2, "Observer (limiar 15): ouve 30 e 45 dB")
	assert_eq(heard_aggressive.size(), 1, "Aggressive (limiar 24): ouve só 45 dB")
	if heard_aggressive.size() == 1:
		assert_almost_eq(heard_aggressive[0].perceived_db, 45.0 - Fx.distance_loss_db(2.0), TOL, "45 − 6,2206")


func test_campos_do_heard_noise_seguem_o_d07() -> void:
	# D-07: posição estimada no disco de raio 0,05 m por dB perdido, em volta do entry_point (no caminho direto, a
	# fonte), mesma altura; confiança = clamp((23,78 − 15)/20; 0,1; 1); timestamp do evento.
	_room(_level, &"porao", Vector3(0.0, 1.5, 0.0), Vector3(10.0, 3.0, 10.0), 12.0)
	var observer: HearingSensor = _observer(_level, OBSERVER_SPOT, &"enemy_observer")
	_world.advance(1.25)
	_emit(_world, 30.0, SOURCE, &"player")
	_world.advance(0.0)
	var heard: Array[HeardNoise] = observer.drain()
	assert_eq(heard.size(), 1, "um som audível")
	if heard.size() != 1:
		return
	var noise: HeardNoise = heard[0]
	var perceived: float = 30.0 - Fx.distance_loss_db(2.0)
	assert_eq(noise.category, Enums.NoiseCategory.FOOTSTEP, "categoria copiada")
	assert_almost_eq(noise.perceived_db, perceived, TOL, "nível percebido pelo sensor")
	assert_almost_eq(noise.timestamp, 1.25, TOL, "timestamp do evento")
	assert_almost_eq(noise.confidence, clampf((perceived - 15.0) / 20.0, 0.1, 1.0), TOL, "confiança pelo excesso")
	var radius: float = Fx.production_config().position_error_per_db_lost * (30.0 - perceived)
	var offset: Vector3 = noise.estimated_position - SOURCE
	assert_almost_eq(offset.y, 0.0, TOL, "o desvio é horizontal")
	assert_true(Vector2(offset.x, offset.z).length() <= radius + TOL, "dentro do disco de raio %.3f m" % radius)


func test_posicao_estimada_parte_do_portal_quando_o_som_entra_por_outra_sala() -> void:
	# Fonte na sala a; sensor na sala b; portal aberto sem porta em (0, 1,5, 0). Pelo portal: 60 − (12,44 + 3) = 44,56,
	# acima do direto (60 − 37,44). Limiar do Observer na sala b: 19. O entry_point é o portal, não a fonte.
	_room(_level, &"a", Vector3(-5.0, 1.5, 0.0), Vector3(10.0, 3.0, 10.0), 22.0)
	_room(_level, &"b", Vector3(5.0, 1.5, 0.0), Vector3(10.0, 3.0, 10.0), 22.0)
	var portal: Portal = Portal.new()
	portal.portal_id = &"passagem"
	portal.room_a = &"a"
	portal.room_b = &"b"
	portal.position = Vector3(0.0, 1.5, 0.0)
	_level.add_child(portal)
	var observer: HearingSensor = _observer(_level, LISTENER_IN_B, &"enemy_observer")
	_emit(_world, 60.0, SOURCE_IN_A, &"player")
	_world.advance(0.0)
	var heard: Array[HeardNoise] = observer.drain()
	assert_eq(heard.size(), 1, "ouve pelo portal aberto")
	if heard.size() != 1:
		return
	var through_portal: float = 60.0 - (Fx.distance_loss_db(4.0) + 3.0)
	assert_almost_eq(heard[0].perceived_db, through_portal, TOL, "nível pelo caminho do portal")
	var radius: float = Fx.production_config().position_error_per_db_lost * (60.0 - through_portal)
	var offset: Vector3 = heard[0].estimated_position - portal.position
	assert_true(Vector2(offset.x, offset.z).length() <= radius + TOL, "estimativa em volta do portal")
	assert_true(heard[0].estimated_position.distance_to(SOURCE_IN_A) > 1.0, "longe da fonte real")


func test_o_proprio_som_nao_chega_ao_dono() -> void:
	_room(_level, &"porao", Vector3(0.0, 1.5, 0.0), Vector3(10.0, 3.0, 10.0), 12.0)
	var observer: HearingSensor = _observer(_level, OBSERVER_SPOT, &"enemy_observer")
	_emit(_world, 45.0, SOURCE, &"enemy_observer")
	_emit(_world, 45.0, SOURCE, &"player")
	_world.advance(0.0)
	var heard: Array[HeardNoise] = observer.drain()
	assert_eq(heard.size(), 1, "o som do próprio dono não chega; o do jogador chega")


func test_trovao_eleva_o_limiar_do_sensor() -> void:
	# Interior (piso 22): sem trovão, limiar 19 → 40 dB a 2 m (33,78) é ouvido. Com trovão, 39 → não.
	# Trovão a cada 5 s, dura 2,5 s: ativo em t = 5; encerrado em t = 8.
	_room(_level, &"interior", Vector3(0.0, 1.5, 0.0), Vector3(10.0, 3.0, 10.0), 22.0)
	_world.thunder_enabled = true
	_world.thunder_interval_min_s = 5.0
	_world.thunder_interval_max_s = 5.0
	var observer: HearingSensor = _observer(_level, OBSERVER_SPOT, &"enemy_observer")
	for _step: int in range(5):
		_world.advance(1.0)
	assert_almost_eq(_world.get_weather_offset(), 20.0, TOL, "trovão ativo em t = 5 s")
	_emit(_world, 40.0, SOURCE, &"player")
	_world.advance(0.0)
	assert_eq(observer.drain().size(), 0, "com trovão, limiar 39: 33,78 não é ouvido")
	_world.advance(3.0)
	assert_almost_eq(_world.get_weather_offset(), 0.0, TOL, "trovão encerrado em t = 8 s")
	_emit(_world, 40.0, SOURCE, &"player")
	_world.advance(0.0)
	assert_eq(observer.drain().size(), 1, "sem trovão, limiar 19: é ouvido")


func test_sem_salas_vale_so_o_limiar_de_audicao() -> void:
	# Regra provisória da F2 (como o ouvido do jogador): sem RoomVolume, o piso da sala e a margem não entram.
	var sensor: HearingSensor = _sensor(_level, OBSERVER_SPOT, &"enemy_observer", 15.0, 3.0)
	_emit(_world, 17.0 + Fx.distance_loss_db(2.0), SOURCE, &"player")
	_emit(_world, 14.0 + Fx.distance_loss_db(2.0), SOURCE, &"player")
	_world.advance(0.0)
	assert_false(_world.has_geometry(), "nível sem RoomVolume")
	var heard: Array[HeardNoise] = sensor.drain()
	assert_eq(heard.size(), 1, "17 dB ≥ 15 (margem +3 ignorada); 14 dB não")


func test_sensor_fora_do_nivel_nao_recebe() -> void:
	var other: Node3D = Node3D.new()
	add_child_autofree(other)
	var outsider: HearingSensor = _observer(other, OBSERVER_SPOT, &"enemy_observer")
	var insider: HearingSensor = _observer(_level, OBSERVER_SPOT, &"enemy_insider")
	_emit(_world, 45.0, SOURCE, &"player")
	_world.advance(0.0)
	assert_eq(outsider.drain().size(), 0, "outro nível: fora do escopo do AcousticWorld")
	assert_eq(insider.drain().size(), 1, "mesmo nível: recebe")


func _estimate_with_seed(seed_value: int) -> Vector3:
	var level: Node3D = Node3D.new()
	add_child_autofree(level)
	var world: AcousticWorld = AcousticWorld.new()
	world.acoustics_seed = seed_value
	level.add_child(world)
	var ear: Node3D = Node3D.new()
	ear.position = Vector3(100.0, 0.0, 100.0)
	level.add_child(ear)
	world.set_player_ear(ear)
	var observer: HearingSensor = _observer(level, OBSERVER_SPOT, &"enemy_observer")
	_emit(world, 45.0, SOURCE, &"player")
	world.advance(0.0)
	var heard: Array[HeardNoise] = observer.drain()
	if heard.size() != 1:
		return Vector3.INF
	return heard[0].estimated_position


func test_rng_da_acustica_e_semeado_e_reproduzivel() -> void:
	var first: Vector3 = _estimate_with_seed(SEED)
	var again: Vector3 = _estimate_with_seed(SEED)
	var other: Vector3 = _estimate_with_seed(SEED + 1)
	assert_true(first.is_finite(), "o som chega nas duas execuções")
	assert_true(first.is_equal_approx(again), "mesma acoustics_seed, mesma estimativa")
	assert_false(first.is_equal_approx(other), "outra semente, outra estimativa")

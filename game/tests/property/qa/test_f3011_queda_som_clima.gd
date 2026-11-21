extends TestCase
## F3-011 (QA independente): queda e escada, bombinha, som e clima na sandbox_playable.tscn real. Cada teste monta o
## próprio mundo isolado. Cobre: queda do mezanino gera FALL e descer a escada correndo não gera; a bombinha (Q) vira um
## som do corpo que não passa pelo roteador; som fora de qualquer sala; muitos eventos simultâneos (limite de vozes e
## custo); a chuva durante a passagem por um portal; a visão de debug (F5) com eventos em massa. Autor: QA Engineer (F3-011).

const Fx := preload("res://tests/integration/qa/fixtures/qa_fixture.gd")
const PLAYABLE_PATH: String = "res://content/levels/sandbox_playable.tscn"
const SETTLE: int = 12
const MEZZ_TOP_Y: float = 1.08
const MEZZ_EDGE_START: Vector3 = Vector3(16.5, MEZZ_TOP_Y, -3.4)
const STAIR_TOP: Vector3 = Vector3(17.0, MEZZ_TOP_Y, -3.0)
const STAIR_BOTTOM: Vector3 = Vector3(17.0, 0.0, -0.4)
const HALL_STAND: Vector3 = Vector3(15.5, 0.0, -0.7)
const MANY_EVENTS: int = 300
const VOICE_CAP: int = 12
const MAX_FLUSH_MS: float = 2000.0


func before_all() -> void:
	Settings.autosave = false


func after_all() -> void:
	Settings.autosave = true


func _world(start: Vector3, yaw_rad: float) -> Dictionary:
	var container: Node3D = add_isolated_world()
	var root: Node = Fx.instantiate_scene(PLAYABLE_PATH, container)
	await wait_physics_frames(SETTLE)
	var player: PlayerRoot = Fx.find_player(root)
	player.global_position = start
	player.rotation.y = yaw_rad
	await wait_physics_frames(SETTLE)
	var meter: Fx.Meter = Fx.Meter.new()
	meter.connect_motor(player)
	return {"root": root, "player": player, "meter": meter}


func _tick(player: PlayerRoot, meter: Fx.Meter, input: MotorInput) -> void:
	player.get_motor().set_scripted_input(input)
	await wait_physics_frames(1)
	meter.sample(player, Fx.body_overlaps_world(player))


func _run(player: PlayerRoot, meter: Fx.Meter, move: Vector2, sprint: bool, ticks: int) -> void:
	for _i: int in ticks:
		await _tick(player, meter, Fx.move_input(move, sprint))


## Grava os NoiseEvent do mundo do nível (todos os eventos resolvidos para o jogador).
func _recorder(root: Node) -> Array[NoiseEvent]:
	var events: Array[NoiseEvent] = []
	var world: AcousticWorld = root.get_node("AcousticWorld") as AcousticWorld
	world.noise_resolved_for_player.connect(func(event: NoiseEvent, _result: PropagationResult) -> void: events.append(event))
	return events


func _count(events: Array[NoiseEvent], category: Enums.NoiseCategory) -> int:
	var total: int = 0
	for event: NoiseEvent in events:
		if event.category == category:
			total += 1
	return total


# ---- Queda e escada ----

## Queda de altura: 1,5 m livres sobre o piso da hall (fora da escadaria) geram FALL e pouso acima de 2,5 m/s.
func test_queda_de_altura_gera_fall() -> void:
	var world: Dictionary = await _world(HALL_STAND, PI / 2.0)
	var root: Node = world["root"] as Node
	var player: PlayerRoot = world["player"] as PlayerRoot
	var meter: Fx.Meter = world["meter"] as Fx.Meter
	var events: Array[NoiseEvent] = _recorder(root)
	var speeds: Array[float] = []
	player.get_motor().landed.connect(func(speed: float) -> void: speeds.append(speed))
	player.global_position = Vector3(18.2, 1.6, -1.8)
	await _run(player, meter, Vector2.ZERO, false, 90)
	var falls: int = _count(events, Enums.NoiseCategory.FALL)
	var max_speed: float = 0.0
	for speed: float in speeds:
		max_speed = maxf(max_speed, speed)
	note("queda de 1,5 m: pousos %d, maior %.2f m/s, FALL=%d, y final %.2f" % [speeds.size(), max_speed, falls, player.global_position.y])
	assert_true(max_speed >= 2.5, "a queda de 1,5 m passa de 2,5 m/s (%.2f)" % max_speed)
	assert_true(falls >= 1, "a queda de altura gera FALL (%d)" % falls)


## O mezanino da sandbox só se desce pela escada: guardas (1 m) nas bordas sul, paredes no oeste, norte e leste, e
## os degraus cobrem a abertura de 1,2 m. Andando ou correndo, a descida não é queda (FALL = 0). Esta é a cobertura
## real do nível: a queda do mezanino por entradas não existe na sandbox (ver o relatório, achado de level design).
func test_mezanino_so_se_desce_pela_escada_sem_fall() -> void:
	var walk_world: Dictionary = await _world(MEZZ_EDGE_START, PI)
	var walk_root: Node = walk_world["root"] as Node
	var walk_player: PlayerRoot = walk_world["player"] as PlayerRoot
	var walk_meter: Fx.Meter = walk_world["meter"] as Fx.Meter
	var walk_events: Array[NoiseEvent] = _recorder(walk_root)
	walk_player.global_position = Vector3(17.0, MEZZ_TOP_Y + 0.05, -3.2)
	await _run(walk_player, walk_meter, Vector2.ZERO, false, 20)
	await _run(walk_player, walk_meter, Vector2(0.0, 1.0), false, 80)
	var walk_falls: int = _count(walk_events, Enums.NoiseCategory.FALL)
	note("mezanino andando: y final %.2f; FALL=%d" % [walk_player.global_position.y, walk_falls])
	assert_eq(walk_falls, 0, "andando pela escada, a descida não gera FALL")

	var run_world: Dictionary = await _world(MEZZ_EDGE_START, PI)
	var run_root: Node = run_world["root"] as Node
	var run_player: PlayerRoot = run_world["player"] as PlayerRoot
	var run_meter: Fx.Meter = run_world["meter"] as Fx.Meter
	var run_events: Array[NoiseEvent] = _recorder(run_root)
	run_player.global_position = Vector3(17.0, MEZZ_TOP_Y + 0.05, -3.2)
	await _run(run_player, run_meter, Vector2.ZERO, false, 20)
	await _run(run_player, run_meter, Vector2(0.0, 1.0), true, 80)
	var run_falls: int = _count(run_events, Enums.NoiseCategory.FALL)
	note("mezanino correndo: y final %.2f; FALL=%d" % [run_player.global_position.y, run_falls])
	assert_eq(run_falls, 0, "correndo pela escada, a descida não gera FALL")

	var edge_world: Dictionary = await _world(Vector3(14.6, MEZZ_TOP_Y + 0.05, -4.4), -PI / 2.0)
	var edge_player: PlayerRoot = edge_world["player"] as PlayerRoot
	var edge_meter: Fx.Meter = edge_world["meter"] as Fx.Meter
	await _run(edge_player, edge_meter, Vector2(0.0, 1.0), true, 90)
	note("mezanino, borda oeste correndo: y=%.2f, x=%.2f" % [edge_player.global_position.y, edge_player.global_position.x])
	assert_true(edge_player.global_position.y > 0.9, "a borda oeste do mezanino não deixa cair (y=%.2f)" % edge_player.global_position.y)


## Descer a escada correndo não gera FALL nem landed acima do limiar: escada e degrau nunca são queda.
func test_descer_a_escada_correndo_nao_gera_fall() -> void:
	var world: Dictionary = await _world(STAIR_TOP, 0.0)
	var root: Node = world["root"] as Node
	var player: PlayerRoot = world["player"] as PlayerRoot
	var meter: Fx.Meter = world["meter"] as Fx.Meter
	var events: Array[NoiseEvent] = _recorder(root)
	player.global_position = STAIR_TOP
	player.rotation.y = PI
	await _run(player, meter, Vector2.ZERO, false, 20)
	var landed_speed: Array[float] = []
	player.get_motor().landed.connect(func(speed: float) -> void: landed_speed.append(speed))
	await _run(player, meter, Vector2(0.0, 1.0), true, 260)
	var falls: int = _count(events, Enums.NoiseCategory.FALL)
	var max_landing: float = 0.0
	for speed: float in landed_speed:
		max_landing = maxf(max_landing, speed)
	note("escada correndo: y final %.2f; FALL=%d; maior pouso %.3f m/s (%d pousos)" % [player.global_position.y, falls, max_landing, landed_speed.size()])
	assert_true(player.global_position.y < 0.5, "o jogador desceu a escada (y=%.2f)" % player.global_position.y)
	assert_eq(falls, 0, "descer a escada correndo não gera FALL")
	assert_true(max_landing < 2.5, "nenhum pouso da escada passa de 2,5 m/s (maior %.3f)" % max_landing)
	assert_eq(meter.penetrations, 0, "sem penetração na escada")


# ---- Bombinha ----

## A bombinha (Q): o puff é um som do corpo (MEDICATION, 38 dB) emitido pelo BreathEmitter, e não passa pelo roteador.
func test_bombinha_gera_puff_do_corpo_e_nao_passa_pelo_roteador() -> void:
	var world: Dictionary = await _world(HALL_STAND, PI / 2.0)
	var root: Node = world["root"] as Node
	var player: PlayerRoot = world["player"] as PlayerRoot
	var meter: Fx.Meter = world["meter"] as Fx.Meter
	var events: Array[NoiseEvent] = _recorder(root)
	var router: NoiseAudioRouter = root.get_node("NoiseAudioRouter") as NoiseAudioRouter
	var breathing: BreathingAudio = root.get_node("BreathingAudio") as BreathingAudio
	await _run(player, meter, Vector2.ZERO, false, 10)
	var doses_before: int = player.get_inventory().get_doses(&"inhaler")
	var router_before: int = router.played_log.size()
	var event_action: InputEventAction = InputEventAction.new()
	event_action.action = &"use_item"
	event_action.pressed = true
	player.get_viewport().push_input(event_action)
	await _run(player, meter, Vector2.ZERO, false, 10)
	var puffs: int = 0
	for event: NoiseEvent in events:
		if event.sound_id == &"inhaler_puff":
			puffs += 1
			assert_eq(event.category, Enums.NoiseCategory.MEDICATION, "o puff é MEDICATION")
			assert_almost_eq(event.intensity_db, 38.0, 0.01, "o puff tem 38 dB a 1 m")
			assert_eq(event.source_id, &"player", "o puff é do jogador")
	var doses_after: int = player.get_inventory().get_doses(&"inhaler")
	note("bombinha: doses %d -> %d; puffs no mundo=%d; entradas novas no roteador=%d" % [doses_before, doses_after, puffs, router.played_log.size() - router_before])
	assert_eq(doses_after, doses_before - 1, "a bombinha consome uma dose")
	assert_eq(puffs, 1, "a bombinha gera um único puff")
	var routed_puff: bool = false
	for index: int in range(router_before, router.played_log.size()):
		if String(router.played_log[index]["sound_id"]) == "inhaler_puff":
			routed_puff = true
	assert_false(routed_puff, "o puff não passa pelo roteador de áudio do mundo")
	var breathing_puff: bool = false
	for entry: Dictionary in breathing.played_log:
		if String(entry["sound_id"]) == "inhaler_puff":
			breathing_puff = true
	assert_true(breathing_puff, "o puff é tocado pelo BreathingAudio (som do corpo)")


# ---- Som: fora de sala, muitos eventos, portal durante a chuva ----

## Um evento fora de qualquer sala (room_id vazio) é propagado com a regra de exterior (38 dB) e não quebra o roteador.
func test_evento_fora_de_qualquer_sala_usa_o_exterior() -> void:
	var world: Dictionary = await _world(HALL_STAND, PI / 2.0)
	var root: Node = world["root"] as Node
	var player: PlayerRoot = world["player"] as PlayerRoot
	var meter: Fx.Meter = world["meter"] as Fx.Meter
	var events: Array[NoiseEvent] = _recorder(root)
	var results: Array[PropagationResult] = []
	var acoustic: AcousticWorld = root.get_node("AcousticWorld") as AcousticWorld
	acoustic.noise_resolved_for_player.connect(func(_event: NoiseEvent, result: PropagationResult) -> void: results.append(result))
	var outside: Vector3 = Vector3(40.0, 0.0, 40.0)
	var graph: AcousticGraph = acoustic.get_graph()
	assert_eq(String(graph.room_at(outside)), "", "pré-condição: o ponto está fora de qualquer sala")
	assert_almost_eq(graph.ambient_floor_at(outside), 38.0, 0.01, "fora de sala o piso é o exterior (38 dB, D-06)")
	acoustic.emit_noise(NoiseEvent.create(Enums.NoiseCategory.DOOR, outside, 50.0, 0.0, &"controle", &"door_normal"))
	acoustic.flush()
	await _run(player, meter, Vector2.ZERO, false, 2)
	var last: NoiseEvent = events.back()
	assert_eq(String(last.room_id), "", "o evento fora de sala não recebe room_id")
	var outside_result: PropagationResult = results.back()
	assert_true(outside_result.perceived_db < 50.0, "propagação fora de sala calcula um nível (%.2f dB)" % outside_result.perceived_db)
	assert_eq(meter.penetrations, 0, "sem penetração")


## Muitos eventos simultâneos: o roteador não passa do limite de vozes, o registro não cresce sem limite e o custo do
## tick fica dentro de MAX_FLUSH_MS (orçamento de desempenho de teste, não medição de produção).
func test_muitos_eventos_simultaneos_respeitam_o_limite_de_vozes() -> void:
	var world: Dictionary = await _world(HALL_STAND, PI / 2.0)
	var root: Node = world["root"] as Node
	var player: PlayerRoot = world["player"] as PlayerRoot
	var meter: Fx.Meter = world["meter"] as Fx.Meter
	var router: NoiseAudioRouter = root.get_node("NoiseAudioRouter") as NoiseAudioRouter
	var acoustic: AcousticWorld = root.get_node("AcousticWorld") as AcousticWorld
	var at: Vector3 = player.global_position + Vector3(0.0, 1.0, -1.0)
	var started: int = Time.get_ticks_usec()
	for index: int in MANY_EVENTS:
		acoustic.emit_noise(NoiseEvent.create(Enums.NoiseCategory.OBJECT_IMPACT, at, 70.0 + float(index % 5), 0.0, &"controle", &"impact"))
	acoustic.flush()
	var elapsed_ms: float = float(Time.get_ticks_usec() - started) / 1000.0
	await _run(player, meter, Vector2.ZERO, false, 3)
	var voices: int = router.active_voice_count()
	note("%d eventos num flush: %.1f ms; vozes ativas %d; registro do roteador %d" % [MANY_EVENTS, elapsed_ms, voices, router.played_log.size()])
	assert_true(voices <= VOICE_CAP, "no máximo %d vozes ativas (%d)" % [VOICE_CAP, voices])
	assert_true(router.played_log.size() <= NoiseAudioRouter.MAX_LOG_ENTRIES, "o registro do roteador é limitado")
	assert_true(elapsed_ms < MAX_FLUSH_MS, "o flush de %d eventos cabe no orçamento (%.1f ms)" % [MANY_EVENTS, elapsed_ms])
	assert_eq(meter.penetrations, 0, "sem penetração durante a rajada")


## Passagem por um portal durante o crossfade da chuva: a camada muda do interior para o exterior, o crossfade fica
## dentro de [0; 1] em todo quadro, a saída é finita e a camada final é a do quintal.
func test_portal_durante_o_crossfade_da_chuva() -> void:
	var world: Dictionary = await _world(Vector3(19.0, 0.0, -1.2), PI / 2.0 + PI)
	var root: Node = world["root"] as Node
	var player: PlayerRoot = world["player"] as PlayerRoot
	var meter: Fx.Meter = world["meter"] as Fx.Meter
	var rain: RainAmbience = root.get_node("RainAmbience") as RainAmbience
	var door: Door = root.find_child("door_hall_quintal", true, false) as Door
	_aim_at(player, Vector3(20.0, 1.0, -1.2))
	player.get_interaction().press_interact()
	await wait_physics_frames(2)
	player.get_interaction().release_interact()
	await wait_physics_frames(40)
	assert_eq(door.get_state(), Door.State.OPEN, "a porta do quintal abriu")
	await wait_physics_frames(60)
	var first_layer: String = String(rain.active_layer())
	var bad_fade: int = 0
	var nan_output: int = 0
	var layers: PackedStringArray = PackedStringArray()
	var target: Vector3 = Vector3(22.0, 0.0, -1.2)
	for _i: int in 240:
		var delta_v: Vector3 = target - player.global_position
		var dist: float = Vector2(delta_v.x, delta_v.z).length()
		var move: Vector2 = Vector2(0.0, 1.0) if dist > 0.15 else Vector2.ZERO
		await _tick(player, meter, Fx.move_input(move, false))
		for layer_id: StringName in RainAmbience.LAYERS:
			var fade: float = rain.layer_fade(layer_id)
			if fade < -0.0001 or fade > 1.0001:
				bad_fade += 1
			if is_nan(rain.layer_output_db(layer_id)):
				nan_output += 1
		var active: String = String(rain.active_layer())
		if layers.is_empty() or layers[layers.size() - 1] != active:
			layers.append(active)
	var final_layer: String = String(rain.active_layer())
	note("chuva: camadas %s; ao entrar %s; fora de [0;1] %d; NaN %d" % [str(layers), first_layer, bad_fade, nan_output])
	assert_true(layers.has("rain_interior") or first_layer == "rain_interior", "a camada começa interna (hall, piso 22)")
	assert_eq(final_layer, "rain_exterior", "no quintal a camada final é a exterior")
	assert_eq(bad_fade, 0, "o crossfade fica dentro de [0; 1] em todo quadro")
	assert_eq(nan_output, 0, "a saída da chuva é finita durante a troca")
	assert_eq(meter.penetrations, 0, "sem penetração pela porta")


func _aim_at(player: PlayerRoot, target: Vector3) -> void:
	var delta: Vector3 = target - player.global_position
	player.rotation.y = atan2(-delta.x, -delta.z)


# ---- Visão de debug (F3-008) ----

## F5 liga a visão no build de desenvolvimento; uma rajada de eventos não passa do limite de anéis e os anéis expiram.
func test_visao_de_debug_com_eventos_em_massa() -> void:
	var world: Dictionary = await _world(HALL_STAND, PI / 2.0)
	var root: Node = world["root"] as Node
	var player: PlayerRoot = world["player"] as PlayerRoot
	var meter: Fx.Meter = world["meter"] as Fx.Meter
	var view: AcousticDebugView = root.get_node("AcousticDebugView") as AcousticDebugView
	assert_false(view.is_view_visible(), "a visão nasce desligada")
	var key: InputEventKey = InputEventKey.new()
	key.physical_keycode = KEY_F5
	key.pressed = true
	player.get_viewport().push_input(key)
	await wait_physics_frames(2)
	assert_true(view.is_view_visible(), "F5 liga a visão no build de desenvolvimento")
	var acoustic: AcousticWorld = root.get_node("AcousticWorld") as AcousticWorld
	var at: Vector3 = player.global_position + Vector3(0.0, 0.0, -1.0)
	var started: int = Time.get_ticks_usec()
	for _i: int in MANY_EVENTS:
		acoustic.emit_noise(NoiseEvent.create(Enums.NoiseCategory.DOOR, at, 60.0, 0.0, &"controle", &"door_normal"))
	acoustic.flush()
	var elapsed_ms: float = float(Time.get_ticks_usec() - started) / 1000.0
	await wait_physics_frames(2)
	var rings: int = view.get_ring_count()
	note("visão de debug: %d eventos em %.1f ms; anéis %d; salas %d" % [MANY_EVENTS, elapsed_ms, rings, view.get_room_count()])
	assert_true(rings >= 1, "os eventos criam anéis")
	assert_true(rings <= AcousticDebugView.MAX_RINGS, "anéis limitados a %d (%d)" % [AcousticDebugView.MAX_RINGS, rings])
	assert_eq(view.get_room_count(), 6, "a visão lê as 6 salas do nível")
	await wait_physics_frames(int(ceil(AcousticDebugView.RING_LIFETIME_S * 60.0)) + 10)
	view.tick(0.0)
	assert_eq(view.get_ring_count(), 0, "os anéis expiram depois do tempo de vida")
	assert_eq(meter.penetrations, 0, "sem penetração")

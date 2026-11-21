class_name F3011Roteiro
extends RefCounted
## Roteiro "atravessar a casa em silêncio" (F3-011, QA Engineer; validação independente da Fase 3).
## Dirige o jogador da sandbox_playable.tscn real com entradas simuladas (MotorInput, tecla E, ação throw). Cada
## NoiseEvent que chega ao AcousticWorld é gravado com: o que o ouvido recebe (perceived_db), o limiar do jogador, se o
## roteador de áudio tocou (e com que ganho), se a legenda foi pedida e o salto de estresse do tick.
## Usado pela suíte (property/qa/test_f3011_cenario_silencio.gd) e pela sonda que grava as evidências
## (integration/qa/probes/f3011_cenario.gd). Os números vêm daqui, não de cálculo à mão.
##
## Limitações do roteiro (declaradas no relatório):
##   - o trovão é forçado: chama AcousticWorld._start_thunder() (mesmo caminho do sorteio, sem o sorteio);
##   - não há inimigo na F3: o "susto por outra fonte" é medido com um evento de controle (fonte "controle");
##   - a posição da câmera (pitch) é ajustada direto na cabeça para pegar o objeto do chão; a direção horizontal
##     é ajustada por yaw. Todo o resto (andar, correr, tecla E, arremesso) passa pelas entradas do jogo.

const Fx := preload("res://tests/integration/qa/fixtures/qa_fixture.gd")
const PLAYABLE_PATH: String = "res://content/levels/sandbox_playable.tscn"
const SETTLE_TICKS: int = 12
const TELEMETRY_EVERY_TICKS: int = 15
const CONTROL_SOURCE: StringName = &"controle"
const STRESS_JUMP_MIN: float = 5.0
## Porta do controle: nível a 1 m de DOOR normal (DATA §2.1).
const CONTROL_DOOR_DB: float = 50.0
## Porta batida (DATA §2.1: 75 dB a 1 m), usada só como controle de atenuação.
const CONTROL_SLAM_DB: float = 75.0
## Evento de outra fonte (fonte "enemy_teste") a 75 dB: o caminho de susto de produção (BUG-014).
const STARTLE_SOURCE: StringName = &"enemy_teste"
const STARTLE_POINT: Vector3 = Vector3(22.0, 1.0, -3.2)

const START_POS: Vector3 = Vector3(3.0, 0.0, -1.0)
const STAND_SALA_CORREDOR: Vector3 = Vector3(4.6, 0.0, -0.7)
const PANEL_SALA_CORREDOR: Vector3 = Vector3(6.0, 1.0, -0.7)
const CORREDOR_MEIO: Vector3 = Vector3(7.2, 0.0, -0.7)
const STAND_CORREDOR_HALL: Vector3 = Vector3(13.0, 0.0, -0.7)
const PANEL_CORREDOR_HALL: Vector3 = Vector3(14.0, 1.0, -0.7)
const STAND_HALL: Vector3 = Vector3(15.5, 0.0, -0.7)
const HALL_SPRINT_TO: Vector3 = Vector3(18.5, 0.0, -0.7)
const CONTROL_CORREDOR_POINT: Vector3 = Vector3(12.5, 1.0, -0.7)
const SALA_PASSAGE: Vector3 = Vector3(5.0, 0.0, -0.7)
const SALA_KITCHEN_PASSAGE: Vector3 = Vector3(5.0, 0.0, -3.0)
const KITCHEN_DOOR_PASSAGE: Vector3 = Vector3(6.6, 0.0, -3.0)
const KITCHEN_POT_STAND: Vector3 = Vector3(11.6, 0.0, -2.6)
const POT_POS: Vector3 = Vector3(12.6, 0.2, -2.6)
const KITCHEN_NORTH_WALL_AIM: Vector3 = Vector3(11.6, 1.5, -6.0)
## Arremesso de perto (~1,2 m da parede norte): o impacto precisa chegar acima de 55 dB ao ouvido para o teste do
## arremesso ser não vacuo.
const KITCHEN_NORTH_THROW_STAND: Vector3 = Vector3(11.6, 0.0, -4.8)
const STAND_QUINTAL_DOOR: Vector3 = Vector3(19.0, 0.0, -1.2)
const PANEL_QUINTAL_DOOR: Vector3 = Vector3(20.0, 1.0, -1.2)
const QUINTAL_IN: Vector3 = Vector3(22.0, 0.0, -1.2)
const QUINTAL_CONTROL_POINT: Vector3 = Vector3(21.0, 1.0, -3.0)

## Ao fechar a porta do hall, o painel aberto fica em z = -1,15, avançando para +X (dentro do hall).
const PANEL_HALL_OPEN: Vector3 = Vector3(14.45, 1.0, -1.15)

var root: Node = null
var player: PlayerRoot = null
var world: AcousticWorld = null
var router: NoiseAudioRouter = null
var rain: RainAmbience = null
var breathing: BreathingAudio = null
var subtitles: Subtitles = null
var graph: AcousticGraph = null
var events: Array[Dictionary] = []
var telemetry: Array[Dictionary] = []
var marks: Array[Dictionary] = []
var subtitle_requests: Array[Dictionary] = []
## Desvios do roteiro (ex.: o caminho travou). Vazio = roteiro executado como planejado.
var deviations: PackedStringArray = PackedStringArray()
var phase: String = "00_inicio"

## Dados do áudio do corpo e do roteador ao fim do roteiro (para a suíte conferir a origem de cada som).
var breathing_log: Array[Dictionary] = []
var router_log: Array[Dictionary] = []

var _host: TestCase = null
var _tree: SceneTree = null
var _tick: int = 0
var _by_id: Dictionary = {}
var _tick_events: Array[Dictionary] = []
var _last_played_id: int = 0
var _stress_prev: float = 0.0
var _control_label: String = ""
var _last_event: Dictionary = {}
var _connected: bool = false


## Monta a cena dentro de container, roda o roteiro inteiro e deixa os registros em events, telemetry e marks.
## host: o TestCase que roda o roteiro (espera pelos quadros com wait_physics_frames, para o watchdog do runner);
## null na sonda de gravação (espera direta pelo SceneTree).
func run(tree: SceneTree, container: Node3D, host: TestCase = null) -> void:
	_tree = tree
	_host = host
	root = Fx.instantiate_scene(PLAYABLE_PATH, container)
	for _i: int in SETTLE_TICKS:
		await _step()
	player = Fx.find_player(root)
	world = root.get_node("AcousticWorld") as AcousticWorld
	router = root.get_node("NoiseAudioRouter") as NoiseAudioRouter
	rain = root.get_node("RainAmbience") as RainAmbience
	breathing = root.get_node("BreathingAudio") as BreathingAudio
	subtitles = root.get_node("Subtitles") as Subtitles
	graph = world.get_graph()
	world.noise_resolved_for_player.connect(_on_noise)
	EventBus.subtitle_requested.connect(_on_subtitle)
	_connected = true
	_stress_prev = player.get_physiology().get_snapshot().stress
	await _execute()
	breathing_log = breathing.played_log.duplicate()
	router_log = router.played_log.duplicate()
	finish()


## Desconecta os sinais. Chamado ao fim de run(); seguro chamar duas vezes.
func finish() -> void:
	if not _connected:
		return
	_connected = false
	if is_instance_valid(world) and world.noise_resolved_for_player.is_connected(_on_noise):
		world.noise_resolved_for_player.disconnect(_on_noise)
	if EventBus.subtitle_requested.is_connected(_on_subtitle):
		EventBus.subtitle_requested.disconnect(_on_subtitle)


func _execute() -> void:
	phase = "00_sala_silencio"
	await _wait(60)
	_mark("silencio_inicial")

	phase = "01_sala_porta_corredor"
	await _go(STAND_SALA_CORREDOR)
	_aim(PANEL_SALA_CORREDOR)
	await _tap()
	await _wait(45)
	_mark_door("door_sala_corredor", "porta_sala_corredor_aberta_tocar")
	await _go(CORREDOR_MEIO)

	phase = "02_corredor_ate_porta_hall"
	await _go(STAND_CORREDOR_HALL)
	_aim(PANEL_CORREDOR_HALL)

	phase = "03_porta_hall_devagar"
	await _hold_e(30)
	await _wait(110)
	_mark_door("door_corredor_hall", "porta_hall_aberta_segurando")
	await _go(STAND_HALL)
	await _wait(10)
	_control("porta_aberta", CONTROL_CORREDOR_POINT, Enums.NoiseCategory.DOOR, CONTROL_DOOR_DB, &"door_normal")
	_control("porta_aberta_batida", CONTROL_CORREDOR_POINT, Enums.NoiseCategory.DOOR, CONTROL_SLAM_DB, &"door_normal")

	phase = "04_fechar_porta_hall_atras"
	_aim(PANEL_HALL_OPEN)
	await _hold_e(30)
	await _wait(110)
	_mark_door("door_corredor_hall", "porta_hall_fechada_segurando")
	await _wait(10)
	_control("porta_fechada", CONTROL_CORREDOR_POINT, Enums.NoiseCategory.DOOR, CONTROL_DOOR_DB, &"door_normal")
	_control("porta_fechada_batida", CONTROL_CORREDOR_POINT, Enums.NoiseCategory.DOOR, CONTROL_SLAM_DB, &"door_normal")

	phase = "05_hall_correr"
	_aim(HALL_SPRINT_TO)
	await _walk(3.0, true)
	await _wait(40)
	_mark("hall_depois_da_corrida")

	phase = "06_volta_cozinha"
	await _go(STAND_HALL)
	_aim(PANEL_CORREDOR_HALL)
	await _tap()
	await _wait(45)
	_mark_door("door_corredor_hall", "porta_hall_aberta_tocar_volta")
	await _go(STAND_CORREDOR_HALL)
	await _go(SALA_PASSAGE)
	await _go(SALA_KITCHEN_PASSAGE)
	await _go(KITCHEN_DOOR_PASSAGE)
	await _go(KITCHEN_POT_STAND)

	phase = "07_pegar_e_arremessar"
	_aim(POT_POS)
	_pitch(-55.0)
	await _tap()
	await _wait(3)
	_mark("objeto_na_mao", {"segurando": player.get_hold().is_holding()})
	_pitch(0.0)
	await _go(KITCHEN_NORTH_THROW_STAND)
	_aim(KITCHEN_NORTH_WALL_AIM)
	await _throw()
	await _wait(60)
	_mark("arremesso_pote")

	phase = "08_rota_quintal"
	await _go(KITCHEN_DOOR_PASSAGE)
	await _go(SALA_KITCHEN_PASSAGE)
	await _go(SALA_PASSAGE)
	await _go(STAND_CORREDOR_HALL)
	await _go(STAND_HALL)
	await _go(STAND_QUINTAL_DOOR)
	_aim(PANEL_QUINTAL_DOOR)
	await _tap()
	await _wait(45)
	_mark_door("door_hall_quintal", "porta_quintal_aberta_tocar")
	await _go(QUINTAL_IN)

	phase = "09_quintal_trovao"
	await _wait(120)
	_mark("quintal_antes_trovao")
	_control("antes_trovao", QUINTAL_CONTROL_POINT, Enums.NoiseCategory.DOOR, CONTROL_DOOR_DB, &"door_normal")
	world._start_thunder()
	_after_tick()
	_mark("trovao_forcado")
	await _wait(2)
	_control("durante_trovao", QUINTAL_CONTROL_POINT, Enums.NoiseCategory.DOOR, CONTROL_DOOR_DB, &"door_normal")
	await _wait(150)
	_mark("apos_trovao")
	phase = "10_susto_outra_fonte"
	_control("susto_outra_fonte", STARTLE_POINT, Enums.NoiseCategory.OBJECT_IMPACT, CONTROL_SLAM_DB, &"impact", STARTLE_SOURCE)
	await _wait(30)
	_mark("apos_susto_outra_fonte")


## Um tick: entradas do jogo para o tick seguinte, espera o tick de física e processa o que ele registrou.
func _step(move: Vector2 = Vector2.ZERO, sprint: bool = false) -> void:
	_tick += 1
	if player != null:
		player.get_motor().set_scripted_input(Fx.move_input(move, sprint))
	if _host != null:
		await _host.wait_physics_frames(1)
	else:
		await _tree.physics_frame
	_after_tick()
	if _tick % TELEMETRY_EVERY_TICKS == 0 and player != null:
		_telemetry_row()


func _wait(ticks: int) -> void:
	for _i: int in ticks:
		await _step()


## Anda para a frente por "meters" metros (linha reta), com corrida ou passo normal.
func _walk(meters: float, sprint: bool = false) -> void:
	var start: Vector3 = player.global_position
	var limit: int = int(meters / 0.3 * 60.0) + 120
	var moved: float = 0.0
	var count: int = 0
	while moved < meters and count < limit:
		await _step(Vector2(0.0, 1.0), sprint)
		count += 1
		var now: Vector3 = player.global_position
		moved = Vector2(now.x - start.x, now.z - start.z).length()
	if moved < meters - 0.2:
		deviations.append("%s: andar travou (%.2f de %.2f m) em %s" % [phase, moved, meters, str(start)])


## Vira para o ponto e anda até ele.
func _go(point: Vector3, sprint: bool = false) -> void:
	_aim(point)
	var here: Vector3 = player.global_position
	var distance: float = Vector2(point.x - here.x, point.z - here.z).length()
	if distance > 0.05:
		await _walk(distance, sprint)


func _aim(target: Vector3) -> void:
	var delta: Vector3 = target - player.global_position
	player.rotation.y = atan2(-delta.x, -delta.z)


func _pitch(degrees: float) -> void:
	(player.get_node("Head") as Node3D).rotation.x = deg_to_rad(degrees)


## Toque na tecla E (interação): aperto e soltura no mesmo tick de pressão.
func _tap() -> void:
	player.get_interaction().press_interact()
	await _step()
	player.get_interaction().release_interact()
	await _step()


## Segurar a tecla E por "ticks" ticks (acima de 0,35 s, a abertura vira lenta).
func _hold_e(ticks: int) -> void:
	player.get_interaction().press_interact()
	await _wait(ticks)
	player.get_interaction().release_interact()
	await _step()


## Ação throw pela entrada do viewport (passa pelo PlayerRoot._unhandled_input, como a tecla real).
func _throw() -> void:
	var event: InputEventAction = InputEventAction.new()
	event.action = InputBindings.THROW_ACTION
	event.pressed = true
	player.get_viewport().push_input(event)
	await _step()


func _door(door_name: String) -> Door:
	return root.find_child(door_name, true, false) as Door


func _mark_door(door_name: String, mark_name: String) -> void:
	var door: Door = _door(door_name)
	_mark(mark_name, {"porta": door_name, "estado": int(door.get_state()), "angulo": door.get_panel_angle_deg(),
		"movendo": door.is_moving()})


func _mark(mark_name: String, extra: Dictionary = {}) -> void:
	var row: Dictionary = {"nome": mark_name, "fase": phase, "tick": _tick, "t": _now(),
		"pos": _vec(player.global_position), "layer": String(rain.active_layer()), "floor": rain.current_floor_db(),
		"limiar": world.player_threshold_db(_ear()), "offset_trovao": world.get_weather_offset()}
	for key: Variant in extra.keys():
		row[key] = extra[key]
	marks.append(row)


## Evento de controle: mesmo caminho do AcousticWorld (emit_noise + flush), com fonte "controle" (não é o jogador).
func _control(label: String, at: Vector3, category: Enums.NoiseCategory, level_db: float, sound: StringName,
		source: StringName = CONTROL_SOURCE) -> void:
	_control_label = label
	var event: NoiseEvent = NoiseEvent.create(category, at, level_db, 0.0, source, sound)
	world.emit_noise(event)
	world.flush()
	_after_tick()
	_control_label = ""


func _ear() -> Vector3:
	return player.get_camera().global_position


func _now() -> float:
	return snappedf(world.now(), 0.001)


func _vec(value: Vector3) -> String:
	return "%.2f;%.2f;%.2f" % [value.x, value.y, value.z]


func _category_name(category: Enums.NoiseCategory) -> String:
	return String(Enums.NoiseCategory.keys()[int(category)])


## Callback de cada NoiseEvent resolvido para o jogador (ordem: emissão, depois o ouvinte do jogador).
func _on_noise(event: NoiseEvent, result: PropagationResult) -> void:
	var threshold: float = world.player_threshold_db(_ear())
	var portals: PackedStringArray = PackedStringArray()
	for portal_id: StringName in result.path_portals:
		portals.append(String(portal_id))
	var row: Dictionary = {
		"t": _now(), "tick": _tick, "fase": phase, "controle": _control_label,
		"id": event.id, "categoria": _category_name(event.category), "fonte": String(event.source_id),
		"som": String(event.sound_id), "sala": String(event.room_id), "pos": _vec(event.position),
		"dB_1m": event.intensity_db, "perceived_db": result.perceived_db, "limiar_db": threshold,
		"audivel": result.perceived_db >= threshold, "parede": result.through_wall,
		"portais": ",".join(portals), "roteador": false, "ganho_db": 0.0, "arquivo": "",
		"legenda": false, "salto_estresse": 0.0,
	}
	events.append(row)
	_by_id[event.id] = row
	_tick_events.append(row)
	_last_event = row


## Pedido de legenda: vai para o último evento processado (o sinal chega logo depois do evento).
func _on_subtitle(text_key: StringName, duration_s: float) -> void:
	subtitle_requests.append({"tick": _tick, "chave": String(text_key), "duration": duration_s, "evento": int(_last_event.get("id", 0))})
	if not _last_event.is_empty():
		_last_event["legenda"] = true


## Depois de cada tick: liga as entradas do roteador a seus eventos e mede o salto de estresse do tick.
func _after_tick() -> void:
	if router == null:
		return
	var played: Array[Dictionary] = router.played_log
	var index: int = played.size() - 1
	var newest: int = _last_played_id
	while index >= 0 and int(played[index]["event_id"]) > _last_played_id:
		var entry: Dictionary = played[index]
		var event_id: int = int(entry["event_id"])
		newest = maxi(newest, event_id)
		if _by_id.has(event_id):
			var row: Dictionary = _by_id[event_id]
			row["roteador"] = true
			row["ganho_db"] = float(entry["gain_db"])
			row["arquivo"] = String(entry["file"])
		index -= 1
	_last_played_id = newest
	var stress: float = player.get_physiology().get_snapshot().stress
	var jump: float = stress - _stress_prev
	_stress_prev = stress
	for row: Dictionary in _tick_events:
		row["salto_estresse"] = jump
	_tick_events.clear()


func _telemetry_row() -> void:
	var snap: PhysiologySnapshot = player.get_physiology().get_snapshot()
	var door_states: Array[String] = []
	for door_name: String in ["door_sala_corredor", "door_sala_cozinha", "door_cozinha_corredor", "door_corredor_hall", "door_hall_quintal"]:
		door_states.append("%s=%d/%.0f" % [door_name, int(_door(door_name).get_state()), _door(door_name).get_panel_angle_deg()])
	telemetry.append({
		"t": _now(), "fase": phase, "pos": _vec(player.global_position), "sala": String(graph.room_at(player.global_position)),
		"marcha": int(player.get_motor().get_gait()), "postura": int(player.get_motor().get_stance()),
		"estresse": snap.stress, "faixa": int(snap.stress_band), "severidade": snap.symptom_severity,
		"estado_resp": int(snap.respiratory_state), "estamina": snap.stamina,
		"camada_chuva": String(rain.active_layer()), "piso_db": rain.current_floor_db(),
		"limiar_ouvido_db": world.player_threshold_db(_ear()), "offset_trovao_db": world.get_weather_offset(),
		"portas": " ".join(door_states),
	})

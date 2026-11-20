extends TestCase
## F1-011 (QA independente), verificação das correções de BUG-004 e efeitos colaterais do contorno (levantar 1 cm e
## refazer o movimento quando o corpo trava no chão). Para cada empurrão contra parede, canto, face de degrau e porta
## parcialmente aberta, medimos: penetração do colisor; ticks no ar e landed; variação da altura do corpo depois de
## assentar; erro da câmera (contra a altura de olhos da postura); footsteps consistentes com o deslocamento realizado;
## e se o corpo cruza a parede. Motion_reduction = 1 zera o head bob. Autor: QA Engineer (F1-011).

const Fx := preload("res://tests/integration/qa/fixtures/qa_fixture.gd")

const SETTLE_TICKS: int = 12
const PUSH_TICKS: int = 120
const TAIL_TICKS: int = 40
const POST_SETTLE_TICKS: int = 25
const FLOOR_TOL_M: float = 0.005
const CAMERA_TOL_M: float = 0.01
const WALK_SPEED_MS: float = 1.6
const CRAWL_SPEED_MS: float = 0.5
const REVERSE_SECONDS: float = 1.5
const MIN_REVERSE_FRACTION: float = 0.8
const NORTH_WALL_CENTER_LIMIT_Z: float = -5.66
const SALA_START: Vector3 = Vector3(1.5, 0.0, -5.2)
## Passos (motor_config): andando 0,7 m, correndo 1,1 m, agachado 0,5 m, rastejando 0,4 m.
const STRIDE_WALK_M: float = 0.7
const STRIDE_SPRINT_M: float = 1.1
const STRIDE_CROUCH_M: float = 0.5
const STRIDE_CRAWL_M: float = 0.4

var _previous_motion_reduction: float = 0.0


func before_all() -> void:
	Settings.autosave = false


func after_all() -> void:
	Settings.autosave = true


func before_each() -> void:
	_previous_motion_reduction = Settings.get_float(&"motion_reduction")
	Settings.set_value(&"motion_reduction", 1.0)


func after_each() -> void:
	Settings.set_value(&"motion_reduction", _previous_motion_reduction)


## Conta footsteps do motor.
class StepCounter extends RefCounted:
	var steps: int = 0

	func on_step(_surface: StringName, _gait: Enums.Gait, _stance: Enums.Stance) -> void:
		steps += 1


## Mundo isolado com a sandbox (sem cena de porta), jogador em start.
func _sandbox(start: Vector3) -> Dictionary:
	var container: Node3D = add_isolated_world()
	var level: Node = Fx.instantiate_scene(Fx.SANDBOX_PATH, container)
	var player: PlayerRoot = Fx.find_player(level)
	player.global_position = start
	await wait_physics_frames(SETTLE_TICKS)
	var meter: Fx.Meter = Fx.Meter.new()
	meter.connect_motor(player)
	return {"container": container, "player": player, "head": player.get_node("Head") as Node3D, "meter": meter}


## Empurra por PUSH_TICKS com o mesmo comando. edge (postura) é aplicado antes. Mede altura, câmera, footsteps e
## deslocamento realizado no trecho final (contato).
func _push(world: Dictionary, move: Vector2, sprint: bool, slow: bool, edge: int) -> Dictionary:
	var player: PlayerRoot = world["player"] as PlayerRoot
	var head: Node3D = world["head"] as Node3D
	var meter: Fx.Meter = world["meter"] as Fx.Meter
	var motor: PlayerMotor = player.get_motor()
	var counter: StepCounter = StepCounter.new()
	motor.footstep.connect(counter.on_step)
	if edge != Fx.EDGE_NONE:
		motor.set_scripted_input(Fx.edge_input(edge))
		await wait_physics_frames(1)
		meter.sample(player, Fx.body_overlaps_world(player))
	var y_min: float = 99.0
	var y_max: float = -99.0
	var camera_worst: float = 0.0
	var tail_start: Vector3 = Vector3.ZERO
	var tail_steps_start: int = 0
	var lowest_x: float = 99.0
	for index: int in PUSH_TICKS:
		motor.set_scripted_input(Fx.move_input(move, sprint, slow))
		await wait_physics_frames(1)
		meter.sample(player, Fx.body_overlaps_world(player))
		var p: Vector3 = player.global_position
		lowest_x = minf(lowest_x, p.x)
		if index >= POST_SETTLE_TICKS:
			y_min = minf(y_min, p.y)
			y_max = maxf(y_max, p.y)
			var expected: float = p.y + Fx.eye_height_for(motor.get_stance())
			camera_worst = maxf(camera_worst, absf(head.global_position.y - expected))
		if index == PUSH_TICKS - TAIL_TICKS:
			tail_start = p
			tail_steps_start = counter.steps
	motor.set_scripted_input(MotorInput.new())
	var tail_distance: float = Vector2(player.global_position.x - tail_start.x, player.global_position.z - tail_start.z).length()
	var tail_steps: int = counter.steps - tail_steps_start
	motor.footstep.disconnect(counter.on_step)
	return {
		"meter": meter, "player": player, "y_range": y_max - y_min, "camera": camera_worst,
		"tail_distance": tail_distance, "tail_steps": tail_steps, "lowest_x": lowest_x,
		"stance": int(motor.get_stance()), "end": player.global_position,
	}


func _stride_for(stance: int, sprint: bool) -> float:
	if sprint:
		return STRIDE_SPRINT_M
	if stance == int(Enums.Stance.CRAWL):
		return STRIDE_CRAWL_M
	if stance == int(Enums.Stance.CROUCH):
		return STRIDE_CROUCH_M
	return STRIDE_WALK_M


## Julga um empurrão: sem penetração, sem ar, sem landed, altura estável, câmera ≤ 1 cm, footsteps coerentes com o
## deslocamento realizado (no máximo um a mais que distância/passada). Devolve a lista de falhas.
func _judge(label: String, result: Dictionary, sprint: bool) -> PackedStringArray:
	var meter: Fx.Meter = result["meter"] as Fx.Meter
	var failures: PackedStringArray = PackedStringArray()
	if meter.penetrations > 0:
		failures.append("%s: penetração em %d ticks" % [label, meter.penetrations])
	if meter.airborne > 0 or meter.landed > 0:
		failures.append("%s: no ar=%d landed=%d" % [label, meter.airborne, meter.landed])
	if float(result["y_range"]) > FLOOR_TOL_M:
		failures.append("%s: altura do corpo variou %.4f m depois de assentar" % [label, float(result["y_range"])])
	if float(result["camera"]) > CAMERA_TOL_M:
		failures.append("%s: erro da câmera %.4f m" % [label, float(result["camera"])])
	var max_steps: int = int(floor(float(result["tail_distance"]) / _stride_for(int(result["stance"]), sprint))) + 1
	if int(result["tail_steps"]) > max_steps:
		failures.append("%s: footsteps espúrios (%d no contato, máximo coerente %d; deslocou %.4f m)" % [label, int(result["tail_steps"]), max_steps, float(result["tail_distance"])])
	return failures


# ---- BUG-004: parede de frente e em ângulo, em todas as posturas ----

## Empurra contra a parede norte da sala (z = -5,9) em 0°, 30° e 60° do eixo da parede, correndo, andando, agachado e
## rastejando. Os efeitos colaterais medidos são os do contorno (levantar 1 cm e refazer o movimento).
func test_correcao_bug004_empurrar_parede_todas_posturas_e_angulos() -> void:
	var failures: PackedStringArray = PackedStringArray()
	var lines: PackedStringArray = PackedStringArray()
	var postures: Array[Dictionary] = [
		{"name": "em pé andando", "edge": Fx.EDGE_NONE, "sprint": false, "slow": false},
		{"name": "em pé correndo", "edge": Fx.EDGE_NONE, "sprint": true, "slow": false},
		{"name": "agachado", "edge": Fx.EDGE_CROUCH, "sprint": false, "slow": false},
		{"name": "rastejando", "edge": Fx.EDGE_CRAWL, "sprint": false, "slow": false},
	]
	for posture: Dictionary in postures:
		for angle_deg: float in [0.0, 30.0, 60.0]:
			var sprint: bool = bool(posture["sprint"])
			# Correr só vale com a frente acima de 0,5: cos(φ) > 0,5 (φ < 60°).
			if sprint and angle_deg >= 60.0:
				continue
			var phi: float = deg_to_rad(angle_deg)
			var move: Vector2 = Vector2(sin(phi), cos(phi))
			var label: String = "%s, %.0f°" % [str(posture["name"]), angle_deg]
			var world: Dictionary = await _sandbox(SALA_START)
			var result: Dictionary = await _push(world, move, sprint, bool(posture["slow"]), int(posture["edge"]))
			lines.append("%s: deslocou no contato %.4f m (%d footsteps), altura %.4f m, câmera %.4f m, %s" % [
				label, float(result["tail_distance"]), int(result["tail_steps"]), float(result["y_range"]), float(result["camera"]),
				(result["meter"] as Fx.Meter).summary()])
			failures.append_array(_judge(label, result, sprint))
			await release_and_flush(world["container"] as Node3D)
	note("efeitos do contorno, parede norte da sala:\n" + "\n".join(lines))
	assert_eq(failures.size(), 0, "empurrões contra parede sem efeitos colaterais: " + "; ".join(failures))


# ---- BUG-004: cantos da sala, cozinha e hall, e a reversão diagonal que reproduzia o bug ----

func test_correcao_bug004_cantos_e_reversao_diagonal() -> void:
	var failures: PackedStringArray = PackedStringArray()
	var corners: Array[Dictionary] = [
		{"name": "sala SO (0,0)", "start": Vector3(1.0, 0.0, -1.0), "push": Vector2(-0.707, -0.707), "edge": Fx.EDGE_NONE},
		{"name": "sala NO (0,-6)", "start": Vector3(1.0, 0.0, -5.0), "push": Vector2(-0.707, 0.707), "edge": Fx.EDGE_NONE},
		{"name": "hall SE (20,0)", "start": Vector3(19.0, 0.0, -1.0), "push": Vector2(0.707, -0.707), "edge": Fx.EDGE_NONE},
		{"name": "hall NE (20,-6), sob o mezanino", "start": Vector3(19.0, 0.0, -5.0), "push": Vector2(0.707, 0.707), "edge": Fx.EDGE_CRAWL},
		{"name": "cozinha NE (14,-6)", "start": Vector3(12.5, 0.0, -5.0), "push": Vector2(0.707, 0.707), "edge": Fx.EDGE_NONE},
		{"name": "cozinha SE (14,-1,4)", "start": Vector3(12.5, 0.0, -2.0), "push": Vector2(0.707, -0.707), "edge": Fx.EDGE_NONE},
	]
	for corner: Dictionary in corners:
		var world: Dictionary = await _sandbox(corner["start"] as Vector3)
		var player: PlayerRoot = world["player"] as PlayerRoot
		var meter: Fx.Meter = world["meter"] as Fx.Meter
		var edge: int = int(corner["edge"])
		var push: Vector2 = corner["push"] as Vector2
		var label: String = str(corner["name"])
		if edge != Fx.EDGE_NONE:
			player.get_motor().set_scripted_input(Fx.edge_input(edge))
			await wait_physics_frames(1)
		var pushed: Dictionary = await _push(world, push, false, false, Fx.EDGE_NONE)
		var at_corner: Vector3 = player.global_position
		var speed: float = CRAWL_SPEED_MS if edge == Fx.EDGE_CRAWL else WALK_SPEED_MS
		var required: float = MIN_REVERSE_FRACTION * speed * REVERSE_SECONDS
		for index: int in 90:
			player.get_motor().set_scripted_input(Fx.move_input(-push))
			await wait_physics_frames(1)
			meter.sample(player, Fx.body_overlaps_world(player))
		var moved_away: float = player.global_position.distance_to(at_corner)
		note("%s: canto; reversão afastou %.3f m (mínimo %.3f); %s" % [label, moved_away, required, meter.summary()])
		failures.append_array(_judge(label, pushed, false))
		if meter.penetrations > 0 or moved_away < required:
			failures.append("%s: reversão afastou %.3f m (mínimo %.3f), penetração %d" % [label, moved_away, required, meter.penetrations])
		await release_and_flush(world["container"] as Node3D)
	# O caso que reproduzia o BUG-004: 240 ticks empurrando para o canto NE do hall (rastejando) e reversão diagonal
	# sem soltar a tecla nem zerar a velocidade.
	var world_bug: Dictionary = await _sandbox(Vector3(19.0, 0.0, -5.0))
	var bug_player: PlayerRoot = world_bug["player"] as PlayerRoot
	var bug_meter: Fx.Meter = world_bug["meter"] as Fx.Meter
	bug_player.get_motor().set_scripted_input(Fx.edge_input(Fx.EDGE_CRAWL))
	await wait_physics_frames(1)
	for index: int in 240:
		bug_player.get_motor().set_scripted_input(Fx.move_input(Vector2(0.707, 0.707)))
		await wait_physics_frames(1)
		bug_meter.sample(bug_player, Fx.body_overlaps_world(bug_player))
	var stuck_at: Vector3 = bug_player.global_position
	for index: int in 300:
		bug_player.get_motor().set_scripted_input(Fx.move_input(Vector2(-0.707, -0.707)))
		await wait_physics_frames(1)
		bug_meter.sample(bug_player, Fx.body_overlaps_world(bug_player))
	var escaped: float = bug_player.global_position.distance_to(stuck_at)
	note("reversão diagonal após 240 ticks no canto (BUG-004): deslocou %.3f m em 300 ticks; %s" % [escaped, bug_meter.summary()])
	if escaped < MIN_REVERSE_FRACTION * CRAWL_SPEED_MS * 2.0 or bug_meter.penetrations > 0:
		failures.append("reversão diagonal presa: %.3f m em 300 ticks" % escaped)
	await release_and_flush(world_bug["container"] as Node3D)
	assert_eq(failures.size(), 0, "cantos e reversão diagonal: " + "; ".join(failures))


# ---- BUG-004: escada com parede lateral, em cada degrau ----

## Empurra de lado (+X) contra a face de cada degrau, a partir do piso do hall. O corpo (0,5 m) encosta também nos
## degraus vizinhos, então o repouso final pode ser qualquer altura de degrau (0, 0,18, ... 1,08), mas nunca um valor
## intermediário: sem penetração, sem ar e sem landed.
func test_correcao_bug004_escada_parede_lateral_em_cada_degrau() -> void:
	var failures: PackedStringArray = PackedStringArray()
	var lines: PackedStringArray = PackedStringArray()
	for step_index: int in 6:
		var z_mid: float = -1.14 - 0.28 * float(step_index)
		var world: Dictionary = await _sandbox(Vector3(15.6, 0.0, z_mid))
		var player: PlayerRoot = world["player"] as PlayerRoot
		var meter: Fx.Meter = world["meter"] as Fx.Meter
		var final_y: float = 0.0
		for index: int in 60:
			player.get_motor().set_scripted_input(Fx.move_input(Vector2(1.0, 0.0), false, true))
			await wait_physics_frames(1)
			meter.sample(player, Fx.body_overlaps_world(player))
		final_y = player.global_position.y
		var top: float = 0.18 * float(step_index + 1)
		var on_tread: bool = false
		for level_index: int in 7:
			if absf(final_y - 0.18 * float(level_index)) < 0.01:
				on_tread = true
		var label: String = "degrau %d (face %.2f m, z %.2f)" % [step_index + 1, top, z_mid]
		lines.append("%s: x=%.3f y=%.3f; %s" % [label, player.global_position.x, final_y, meter.summary()])
		if meter.penetrations > 0 or meter.airborne > 0 or meter.landed > 0:
			failures.append("%s: %s" % [label, meter.summary()])
		if not on_tread:
			failures.append("%s: altura final %.3f m (não é altura de degrau)" % [label, final_y])
		await release_and_flush(world["container"] as Node3D)
	note("escada, parede lateral:\n" + "\n".join(lines))
	assert_eq(failures.size(), 0, "escada com parede lateral: " + "; ".join(failures))


# ---- BUG-006: porta parcialmente aberta como obstáculo ----

## O corpo para encostado no painel no arco (porta parada pelo corpo). Parado ali por 60 ticks: sem penetração, sem
## deslocamento, sem ar, e o primeiro bloqueio é o próprio jogador.
func test_correcao_porta_parcial_com_corpo_parado_encostado() -> void:
	var packed: PackedScene = load(Fx.PLAYABLE_PATH) as PackedScene
	var container: Node3D = add_isolated_world()
	var root: Node = packed.instantiate()
	container.add_child(root)
	await wait_physics_frames(SETTLE_TICKS)
	var player: PlayerRoot = Fx.find_player(root)
	var door: Door = root.find_child("door_sala_corredor", true, false) as Door
	player.global_position = Vector3(6.45, 0.0, -0.7)
	player.rotation.y = PI / 2.0
	await wait_physics_frames(SETTLE_TICKS)
	var meter: Fx.Meter = Fx.Meter.new()
	meter.connect_motor(player)
	var blocks: Array[Node] = []
	door.blocked.connect(func(body: Node) -> void: blocks.append(body))
	player.get_interaction().press_interact()
	await wait_physics_frames(2)
	player.get_interaction().release_interact()
	var waited: int = 0
	while not door.is_blocked() and waited < 60:
		player.get_motor().set_scripted_input(MotorInput.new())
		await wait_physics_frames(1)
		meter.sample(player, Fx.body_overlaps_world(player))
		waited += 1
	var partial_angle: float = door.get_panel_angle_deg()
	var start: Vector3 = player.global_position
	for index: int in 60:
		player.get_motor().set_scripted_input(MotorInput.new())
		await wait_physics_frames(1)
		meter.sample(player, Fx.body_overlaps_world(player))
	player.get_motor().set_scripted_input(MotorInput.new())
	var held_angle: float = door.get_panel_angle_deg()
	var held_distance: float = player.global_position.distance_to(start)
	var first_blocker: Node = blocks[0] if blocks.size() > 0 else null
	note("porta parcial com corpo parado: parou em %.1f°; primeiro bloqueio=%s; depois de 60 ticks: ângulo %.1f°, corpo deslocou %.4f m; %s" % [
		partial_angle, str(first_blocker.name) if first_blocker != null else "nenhum", held_angle, held_distance, meter.summary()])
	assert_true(door.is_blocked(), "a porta fica bloqueada pelo corpo no arco (ângulo %.1f°)" % partial_angle)
	assert_true(first_blocker == player, "o primeiro bloqueio é o próprio jogador")
	assert_true(absf(held_angle - partial_angle) < 0.5, "com o corpo parado, o painel não avança (%.1f° -> %.1f°)" % [partial_angle, held_angle])
	assert_true(held_distance < 0.01, "o corpo não é empurrado pelo painel parcial (deslocou %.4f m)" % held_distance)
	assert_eq(meter.penetrations, 0, "o painel parcial não é cruzado pelo corpo (penetração %d)" % meter.penetrations)
	assert_eq(meter.airborne, 0, "contra o painel parcial o corpo continua no chão (%s)" % meter.summary())
	await release_and_flush(container)


## BUG-009 (regressão introduzida pela regra de não empurrar): sem nenhum corpo por perto, a porta de passagem tem de
## abrir por inteiro (>= 85°). Hoje a quina da dobradiça encosta no batente (Div_sala_corredor_0) a partir de 27°, e a
## porta para ali para sempre. Falha de propósito, até a correção.
func test_correcao_porta_sem_corpo_abre_por_inteiro() -> void:
	var packed: PackedScene = load(Fx.PLAYABLE_PATH) as PackedScene
	var container: Node3D = add_isolated_world()
	var root: Node = packed.instantiate()
	container.add_child(root)
	await wait_physics_frames(SETTLE_TICKS)
	var player: PlayerRoot = Fx.find_player(root)
	var door: Door = root.find_child("door_sala_corredor", true, false) as Door
	player.global_position = Vector3(7.8, 0.0, -0.7)
	player.rotation.y = PI / 2.0
	await wait_physics_frames(SETTLE_TICKS)
	player.get_interaction().press_interact()
	await wait_physics_frames(2)
	player.get_interaction().release_interact()
	await wait_physics_frames(150)
	var angle: float = door.get_panel_angle_deg()
	note("porta sem corpo por perto: ângulo final %.1f°; bloqueada=%s" % [angle, str(door.is_blocked())])
	assert_true(angle >= 85.0, "sem corpo no arco, a porta de passagem abre por inteiro (ângulo %.1f°; BUG-009)" % angle)
	await release_and_flush(container)

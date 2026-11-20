extends TestCase
## F1-011 (QA independente): verificação de BUG-003 (câmera afunda em rampa) com experimentos que a suíte da F1 não
## cobre: andar devagar, agachado, rastejando, rampa em diagonal, parada e inversão na rampa, troca de postura no
## meio da rampa e saída para um plano no topo. Critério (BUG_REPORTS): erro da altura dos olhos ≤ 1 cm em regime,
## medido contra a altura de olhos da postura atual (em pé 1,65 m; agachado 1,00 m; rastejando 0,45 m).
## motion_reduction = 1 zera o head bob, para medir só a compensação. Autor: QA Engineer (F1-011).

const Fx := preload("res://tests/integration/qa/fixtures/qa_fixture.gd")

const TOLERANCE_M: float = 0.01
const SETTLE_TICKS: int = 12
## Ticks na mesma postura antes de contar o erro (a altura dos olhos leva 0,25 s para mudar).
const STANCE_SETTLE_TICKS: int = 30
const RAMP_LEN_M: float = 6.0
const RAMP_WIDTH_M: float = 4.0
const RAMP_THICKNESS_M: float = 0.2
const WINDOW_MARGIN_M: float = 0.8
const WALK_TICKS: int = 420
const STOP_TICKS: int = 120
const STOP_SETTLE_TICKS: int = 15
const SLIDE_TOL_M: float = 0.01
const DIAGONAL_MOVE: Vector2 = Vector2(0.25, 0.968)

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


# ---- Geometria: piso plano, rampa e plano opcional no topo ----

## Piso plano (topo em y = 0) de z = -1 a z = 6. Rampa de angle_deg que sobe para -Z a partir de z = 0.
## O topo da rampa fica em (0, L·sen θ, -L·cos θ). Com plateau, um plano de 3 m começa no topo.
func _build_ramp(root: Node3D, angle_deg: float, plateau: bool) -> void:
	Fx.add_box(root, Vector3(0.0, -0.5, 2.5), Vector3(RAMP_WIDTH_M, 1.0, 7.0), &"wood")
	var theta: float = deg_to_rad(angle_deg)
	var pivot: Node3D = Node3D.new()
	pivot.rotation.x = theta
	root.add_child(pivot)
	Fx.add_box(pivot, Vector3(0.0, -RAMP_THICKNESS_M * 0.5, -RAMP_LEN_M * 0.5), Vector3(RAMP_WIDTH_M, RAMP_THICKNESS_M, RAMP_LEN_M), &"wood")
	if plateau:
		var top_y: float = RAMP_LEN_M * sin(theta)
		Fx.add_box(root, Vector3(0.0, top_y - 0.5, _top_z(angle_deg) - 1.5), Vector3(RAMP_WIDTH_M, 1.0, 3.0), &"wood")


## z do topo da rampa.
func _top_z(angle_deg: float) -> float:
	return -RAMP_LEN_M * cos(deg_to_rad(angle_deg))


## Altura da superfície da rampa em z (ela passa pela origem).
func _ramp_y(angle_deg: float, z: float) -> float:
	return -z * tan(deg_to_rad(angle_deg))


## Zona de regime na rampa, em z (sem contar entrada, saída nem as bordas).
func _ramp_window(angle_deg: float) -> Vector2:
	return Vector2(_top_z(angle_deg) + WINDOW_MARGIN_M, -WINDOW_MARGIN_M)


## Mundo isolado com a rampa. Devolve o contêiner, o jogador e a cabeça.
func _world(angle_deg: float, plateau: bool, start: Vector3) -> Dictionary:
	var container: Node3D = add_isolated_world()
	_build_ramp(container, angle_deg, plateau)
	var player: PlayerRoot = Fx.spawn_player_in(container, start)
	var head: Node3D = player.get_node("Head") as Node3D
	return {"container": container, "player": player, "head": head}


# ---- Bot e medição ----

## Anda com move por ticks e mede o maior erro da câmera em regime dentro da zona. Só conta ticks com o corpo no
## chão e com a postura estável há STANCE_SETTLE_TICKS ticks (contados a partir do início desta medição).
func _measure(player: PlayerRoot, head: Node3D, meter: Fx.Meter, move: Vector2, sprint: bool, slow: bool, ticks: int, window: Vector2) -> Dictionary:
	var worst: float = 0.0
	var samples: int = 0
	var last_stance: int = int(player.get_motor().get_stance())
	var since: int = 0
	for index: int in ticks:
		player.get_motor().set_scripted_input(Fx.move_input(move, sprint, slow))
		await wait_physics_frames(1)
		var stance: Enums.Stance = player.get_motor().get_stance()
		if int(stance) != last_stance:
			last_stance = int(stance)
			since = 0
		else:
			since += 1
		meter.sample(player, Fx.body_overlaps_world(player))
		var p: Vector3 = player.global_position
		var expected: float = p.y + Fx.eye_height_for(stance)
		var err: float = head.global_position.y - expected
		if since >= STANCE_SETTLE_TICKS and player.is_on_floor() and p.z > window.x and p.z < window.y:
			worst = maxf(worst, absf(err))
			samples += 1
	player.get_motor().set_scripted_input(MotorInput.new())
	return {"worst": worst, "samples": samples}


## Aplica uma ação de postura num tick.
func _edge(player: PlayerRoot, edge: int) -> void:
	player.get_motor().set_scripted_input(Fx.edge_input(edge))
	await wait_physics_frames(1)
	player.get_motor().set_scripted_input(MotorInput.new())


# ---- Experimentos ----

## Andando devagar, subindo e descendo, em três inclinações (dados de referência para as outras medidas).
func test_bug003_rampa_andando_devagar_10_20_30_graus() -> void:
	var failures: PackedStringArray = PackedStringArray()
	for angle: float in [10.0, 20.0, 30.0]:
		var window: Vector2 = _ramp_window(angle)
		var world: Dictionary = _world(angle, false, Vector3(0.0, 0.0, 1.0))
		var player: PlayerRoot = world["player"] as PlayerRoot
		var head: Node3D = world["head"] as Node3D
		await wait_physics_frames(SETTLE_TICKS)
		var up_meter: Fx.Meter = Fx.Meter.new()
		var up: Dictionary = await _measure(player, head, up_meter, Vector2(0.0, 1.0), false, true, WALK_TICKS, window)
		var z0: float = _top_z(angle) + 0.5
		player.teleport_to(Vector3(0.0, _ramp_y(angle, z0), z0))
		await wait_physics_frames(SETTLE_TICKS)
		var down_meter: Fx.Meter = Fx.Meter.new()
		var down: Dictionary = await _measure(player, head, down_meter, Vector2(0.0, -1.0), false, true, WALK_TICKS, window)
		note("rampa %.0f° devagar: subida erro=%.4f m (%d amostras; %s); descida erro=%.4f m (%d amostras; %s)" % [
			angle, float(up["worst"]), int(up["samples"]), up_meter.summary(), float(down["worst"]), int(down["samples"]), down_meter.summary()])
		if float(up["worst"]) > TOLERANCE_M or float(down["worst"]) > TOLERANCE_M or int(up["samples"]) < 20 or int(down["samples"]) < 20:
			failures.append("%.0f°: subida %.4f m, descida %.4f m (amostras %d/%d)" % [angle, float(up["worst"]), float(down["worst"]), int(up["samples"]), int(down["samples"])])
		await release_and_flush(world["container"] as Node3D)
	assert_eq(failures.size(), 0, "andando devagar, erro da câmera ≤ 1 cm em regime: " + "; ".join(failures))


func test_bug003_rampa_agachado_30_graus() -> void:
	var window: Vector2 = _ramp_window(30.0)
	var world: Dictionary = _world(30.0, false, Vector3(0.0, 0.0, 1.0))
	var player: PlayerRoot = world["player"] as PlayerRoot
	var head: Node3D = world["head"] as Node3D
	await wait_physics_frames(SETTLE_TICKS)
	await _edge(player, Fx.EDGE_CROUCH)
	var up_meter: Fx.Meter = Fx.Meter.new()
	var up: Dictionary = await _measure(player, head, up_meter, Vector2(0.0, 1.0), false, false, WALK_TICKS, window)
	var z0: float = _top_z(30.0) + 0.5
	player.teleport_to(Vector3(0.0, _ramp_y(30.0, z0), z0))
	await wait_physics_frames(SETTLE_TICKS)
	var down_meter: Fx.Meter = Fx.Meter.new()
	var down: Dictionary = await _measure(player, head, down_meter, Vector2(0.0, -1.0), false, false, WALK_TICKS, window)
	note("rampa 30° agachado: subida erro=%.4f m (%d amostras; %s); descida erro=%.4f m (%d amostras; %s)" % [
		float(up["worst"]), int(up["samples"]), up_meter.summary(), float(down["worst"]), int(down["samples"]), down_meter.summary()])
	assert_true(int(up["samples"]) > 20 and int(down["samples"]) > 20, "amostras em regime (subida %d, descida %d)" % [int(up["samples"]), int(down["samples"])])
	assert_true(float(up["worst"]) <= TOLERANCE_M, "agachado, subindo: erro da câmera %.4f m (olhos 1,00 m)" % float(up["worst"]))
	assert_true(float(down["worst"]) <= TOLERANCE_M, "agachado, descendo: erro da câmera %.4f m (olhos 1,00 m)" % float(down["worst"]))
	await release_and_flush(world["container"] as Node3D)


func test_bug003_rampa_rastejando_20_graus() -> void:
	var window: Vector2 = _ramp_window(20.0)
	var world: Dictionary = _world(20.0, false, Vector3(0.0, 0.0, 1.0))
	var player: PlayerRoot = world["player"] as PlayerRoot
	var head: Node3D = world["head"] as Node3D
	await wait_physics_frames(SETTLE_TICKS)
	await _edge(player, Fx.EDGE_CRAWL)
	var up_meter: Fx.Meter = Fx.Meter.new()
	var up: Dictionary = await _measure(player, head, up_meter, Vector2(0.0, 1.0), false, false, WALK_TICKS, window)
	note("rampa 20° rastejando: subida erro=%.4f m (%d amostras; %s)" % [float(up["worst"]), int(up["samples"]), up_meter.summary()])
	assert_true(int(up["samples"]) > 20, "amostras em regime (%d)" % int(up["samples"]))
	assert_true(float(up["worst"]) <= TOLERANCE_M, "rastejando, subindo: erro da câmera %.4f m (olhos 0,45 m)" % float(up["worst"]))
	await release_and_flush(world["container"] as Node3D)


## Caminhada em diagonal (14° fora do eixo da rampa): a direção no plano não é mais só em z.
func test_bug003_rampa_diagonal_20_graus() -> void:
	var window: Vector2 = _ramp_window(20.0)
	var world: Dictionary = _world(20.0, false, Vector3(-0.4, 0.0, 1.0))
	var player: PlayerRoot = world["player"] as PlayerRoot
	var head: Node3D = world["head"] as Node3D
	await wait_physics_frames(SETTLE_TICKS)
	var up_meter: Fx.Meter = Fx.Meter.new()
	var up: Dictionary = await _measure(player, head, up_meter, DIAGONAL_MOVE, false, true, WALK_TICKS, window)
	note("rampa 20° diagonal: subida erro=%.4f m (%d amostras; %s); x final=%.3f" % [float(up["worst"]), int(up["samples"]), up_meter.summary(), player.global_position.x])
	assert_true(int(up["samples"]) > 20, "amostras em regime (%d)" % int(up["samples"]))
	assert_true(float(up["worst"]) <= TOLERANCE_M, "diagonal na rampa: erro da câmera %.4f m" % float(up["worst"]))
	await release_and_flush(world["container"] as Node3D)


## Para no meio da rampa de 30°: o corpo não pode escorregar e a câmera não pode afundar durante a parada.
## O deslize mede-se depois de STOP_SETTLE_TICKS (a desaceleração de 14 m/s² ainda leva alguns centímetros).
func test_bug003_parada_na_rampa_30_graus_nao_escorrega() -> void:
	var world: Dictionary = _world(30.0, false, Vector3(0.0, 0.0, 1.0))
	var player: PlayerRoot = world["player"] as PlayerRoot
	var head: Node3D = world["head"] as Node3D
	await wait_physics_frames(SETTLE_TICKS)
	var meter: Fx.Meter = Fx.Meter.new()
	await _measure(player, head, meter, Vector2(0.0, 1.0), false, false, 120, _ramp_window(30.0))
	var climbed_z: float = player.global_position.z
	var worst_stop: float = 0.0
	var stop_point: Vector3 = Vector3.ZERO
	var max_slide: float = 0.0
	for index: int in STOP_TICKS:
		player.get_motor().set_scripted_input(MotorInput.new())
		await wait_physics_frames(1)
		meter.sample(player, Fx.body_overlaps_world(player))
		if index == STOP_SETTLE_TICKS - 1:
			stop_point = player.global_position
		if index >= STOP_SETTLE_TICKS:
			var expected: float = player.global_position.y + Fx.eye_height_for(player.get_motor().get_stance())
			worst_stop = maxf(worst_stop, absf(head.global_position.y - expected))
			max_slide = maxf(max_slide, player.global_position.distance_to(stop_point))
	note("parada na rampa 30° em z=%.3f (y=%.3f): erro da câmera parada=%.4f m; deslize após assentar=%.4f m; %s" % [
		climbed_z, stop_point.y, worst_stop, max_slide, meter.summary()])
	assert_true(climbed_z < -1.0, "a caminhada até a parada subiu a rampa (z = %.3f)" % climbed_z)
	assert_true(worst_stop <= TOLERANCE_M, "parado na rampa, erro da câmera %.4f m" % worst_stop)
	assert_true(max_slide <= SLIDE_TOL_M, "parado na rampa de 30° o corpo não escorrega (deslize %.4f m)" % max_slide)
	assert_eq(meter.airborne, 0, "parado na rampa, o corpo continua no chão (%s)" % meter.summary())
	await release_and_flush(world["container"] as Node3D)


## Sobe 1 s, inverte e desce a rampa de 30° sem parar: o erro tem de voltar a ≤ 1 cm no sentido contrário.
func test_bug003_inversao_no_meio_da_rampa_30_graus() -> void:
	var window: Vector2 = _ramp_window(30.0)
	var world: Dictionary = _world(30.0, false, Vector3(0.0, 0.0, 1.0))
	var player: PlayerRoot = world["player"] as PlayerRoot
	var head: Node3D = world["head"] as Node3D
	await wait_physics_frames(SETTLE_TICKS)
	var meter: Fx.Meter = Fx.Meter.new()
	# Sobe até a zona de regime (caminhada normal), inverte e mede só a descida.
	await _measure(player, head, meter, Vector2(0.0, 1.0), false, false, 150, window)
	var back: Dictionary = await _measure(player, head, meter, Vector2(0.0, -1.0), false, false, 300, window)
	note("inversão na rampa 30°: erro depois de inverter=%.4f m (%d amostras); %s" % [float(back["worst"]), int(back["samples"]), meter.summary()])
	assert_true(int(back["samples"]) > 20, "amostras em regime depois de inverter (%d)" % int(back["samples"]))
	assert_true(float(back["worst"]) <= TOLERANCE_M, "depois de inverter a direção na rampa, erro %.4f m" % float(back["worst"]))
	await release_and_flush(world["container"] as Node3D)


## Troca de postura no meio da rampa de 30°: em pé, agachado, rastejando, agachado. Cada postura tem a sua altura de olhos.
func test_bug003_troca_de_postura_no_meio_da_rampa_30_graus() -> void:
	var window: Vector2 = _ramp_window(30.0)
	var world: Dictionary = _world(30.0, false, Vector3(0.0, 0.0, 1.0))
	var player: PlayerRoot = world["player"] as PlayerRoot
	var head: Node3D = world["head"] as Node3D
	await wait_physics_frames(SETTLE_TICKS)
	var meter: Fx.Meter = Fx.Meter.new()
	# Sobe até a zona de regime (caminhada normal) antes das trocas.
	await _measure(player, head, meter, Vector2(0.0, 1.0), false, false, 150, window)
	var failures: PackedStringArray = PackedStringArray()
	var measured_stance: Array[int] = []
	for edge: int in [Fx.EDGE_CROUCH, Fx.EDGE_CRAWL, Fx.EDGE_CROUCH]:
		await _edge(player, edge)
		var stance: Enums.Stance = player.get_motor().get_stance()
		var result: Dictionary = await _measure(player, head, meter, Vector2(0.0, 1.0), false, true, 60, window)
		note("troca na rampa 30°: postura=%d, olhos=%.2f m, erro=%.4f m, amostras=%d" % [int(stance), Fx.eye_height_for(stance), float(result["worst"]), int(result["samples"])])
		measured_stance.append(int(stance))
		if int(result["samples"]) < 10 or float(result["worst"]) > TOLERANCE_M:
			failures.append("postura %d: erro %.4f m (amostras %d)" % [int(stance), float(result["worst"]), int(result["samples"])])
	assert_eq(measured_stance.size(), 3, "três trocas de postura medidas")
	assert_eq(failures.size(), 0, "troca de postura na rampa: " + "; ".join(failures))
	await release_and_flush(world["container"] as Node3D)


## Sobe a rampa de 30° e segue por um plano no topo: a câmera tem de voltar ao erro ≤ 1 cm no plano.
func test_bug003_saida_da_rampa_para_o_plano_30_graus() -> void:
	var world: Dictionary = _world(30.0, true, Vector3(0.0, 0.0, 1.0))
	var player: PlayerRoot = world["player"] as PlayerRoot
	var head: Node3D = world["head"] as Node3D
	await wait_physics_frames(SETTLE_TICKS)
	var meter: Fx.Meter = Fx.Meter.new()
	var top_z: float = _top_z(30.0)
	player.get_motor().set_scripted_input(Fx.move_input(Vector2(0.0, 1.0)))
	var ticks: int = 0
	while ticks < WALK_TICKS * 2 and player.global_position.z > top_z - 1.0:
		await wait_physics_frames(1)
		meter.sample(player, Fx.body_overlaps_world(player))
		ticks += 1
	var reached: bool = player.global_position.z <= top_z - 1.0
	var plane: Dictionary = await _measure(player, head, meter, Vector2(0.0, 1.0), false, true, 120, Vector2(top_z - 2.5, top_z - 0.5))
	note("saída para o plano 30°: chegou ao plano=%s; z=%.3f y=%.3f; erro no plano=%.4f m (%d amostras); %s" % [
		str(reached), player.global_position.z, player.global_position.y, float(plane["worst"]), int(plane["samples"]), meter.summary()])
	assert_true(reached, "chegou ao plano do topo (z = %.3f)" % player.global_position.z)
	assert_true(int(plane["samples"]) > 10, "amostras no plano depois da saída (%d)" % int(plane["samples"]))
	assert_true(float(plane["worst"]) <= TOLERANCE_M, "no plano do topo, erro da câmera %.4f m" % float(plane["worst"]))
	assert_eq(meter.penetrations, 0, "sem penetração ao sair da rampa (%s)" % meter.summary())
	await release_and_flush(world["container"] as Node3D)

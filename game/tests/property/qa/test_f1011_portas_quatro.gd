extends TestCase
## F1-011 (QA independente), verificação de BUG-009 e BUG-006 com a correção da porta (regras do Director: (1) a porta
## só para por corpos móveis (camadas 2, 3 e 4); geometria estática não bloqueia o giro; (2) o painel avança só com
## folga de 2 cm; (3) bloqueio contínuo emite blocked uma vez; liberação = is_blocked() == false).
## As quatro portas da sandbox jogável: door_sala_corredor (fechada), door_corredor_hall (fechada), door_sala_cozinha
## (aberta no início) e door_cozinha_corredor (trancada). Também: corpo entrando no arco no meio da abertura, e a
## brecha no batente (passagem pelo encontro do painel com o batente). Autor: QA Engineer (F1-011).

const Fx := preload("res://tests/integration/qa/fixtures/qa_fixture.gd")

const SETTLE_TICKS: int = 12
const FULLY_OPEN_MIN_DEG: float = 85.0
const MOVE_TOL_M: float = 0.01
const OPEN_TICKS: int = 150
const PANEL_THICKNESS_M: float = 0.06
const PANEL_WIDTH_M: float = 0.9
const PANEL_HEIGHT_M: float = 2.0
const DOOR_NAMES: Array[String] = ["door_sala_corredor", "door_corredor_hall", "door_sala_cozinha", "door_cozinha_corredor"]
const WORLD_STATIC_MASK: int = 1

var _meter: Fx.Meter = null


func before_all() -> void:
	Settings.autosave = false


func after_all() -> void:
	Settings.autosave = true


## Cena jogável com o jogador em (x, 0, z), de frente para -X (yaw 90°). Devolve contêiner, raiz, jogador e medidor.
func _world(start: Vector3, yaw_rad: float) -> Dictionary:
	var container: Node3D = add_isolated_world()
	var root: Node = Fx.instantiate_scene(Fx.PLAYABLE_PATH, container)
	await wait_physics_frames(SETTLE_TICKS)
	var player: PlayerRoot = Fx.find_player(root)
	player.global_position = start
	player.rotation.y = yaw_rad
	await wait_physics_frames(SETTLE_TICKS)
	var meter: Fx.Meter = Fx.Meter.new()
	meter.connect_motor(player)
	return {"container": container, "root": root, "player": player, "meter": meter}


func _door(root: Node, door_name: String) -> Door:
	return root.find_child(door_name, true, false) as Door


func _tick(player: PlayerRoot, meter: Fx.Meter, input: MotorInput) -> void:
	player.get_motor().set_scripted_input(input)
	await wait_physics_frames(1)
	meter.sample(player, Fx.body_overlaps_world(player))


func _tap(player: PlayerRoot) -> void:
	player.get_interaction().press_interact()
	await wait_physics_frames(2)
	player.get_interaction().release_interact()


func _hold(player: PlayerRoot, ticks: int) -> void:
	player.get_interaction().press_interact()
	await wait_physics_frames(ticks)
	player.get_interaction().release_interact()


## Profundidade aproximada em que o painel (a um ângulo dado) entra no mundo estático: menor encolhimento da caixa do
## painel que libera a sobreposição (bisseção). Devolve 0 se já está livre.
func _static_intrusion_m(door: Door, angle_deg: float) -> float:
	var panel: AnimatableBody3D = door.get_node("Panel") as AnimatableBody3D
	var shape_node: Node3D = panel.get_node("CollisionShape3D") as Node3D
	var base: Transform3D = door.global_transform * Transform3D(Basis(Vector3.UP, deg_to_rad(angle_deg)), Vector3.ZERO) * shape_node.transform
	var space: PhysicsDirectSpaceState3D = door.get_world_3d().direct_space_state
	if not _panel_overlaps(space, base, 0.0, panel):
		return 0.0
	var low: float = 0.0
	var high: float = 0.025
	if _panel_overlaps(space, base, high, panel):
		return high
	for step: int in 14:
		var mid: float = (low + high) * 0.5
		if _panel_overlaps(space, base, mid, panel):
			low = mid
		else:
			high = mid
	return high


func _panel_overlaps(space: PhysicsDirectSpaceState3D, base: Transform3D, shrink: float, panel: AnimatableBody3D) -> bool:
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(PANEL_WIDTH_M - 2.0 * shrink, PANEL_HEIGHT_M - 2.0 * shrink, PANEL_THICKNESS_M - 2.0 * shrink)
	var query: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
	query.shape = box
	query.transform = base
	query.collision_mask = WORLD_STATIC_MASK
	query.exclude = [panel.get_rid()]
	return not space.intersect_shape(query, 1).is_empty()


# ---- Sem corpo: BUG-009 ----

## door_sala_corredor, toque, sem corpo no arco: tem de abrir por inteiro.
func test_porta_sala_corredor_toque_sem_corpo_abre_por_inteiro() -> void:
	var world: Dictionary = await _world(Vector3(7.8, 0.0, -0.7), PI / 2.0)
	var root: Node = world["root"] as Node
	var player: PlayerRoot = world["player"] as PlayerRoot
	var door: Door = _door(root, "door_sala_corredor")
	await _tap(player)
	await wait_physics_frames(OPEN_TICKS)
	note("sala-corredor, toque, sem corpo: ângulo %.1f°; bloqueada=%s" % [door.get_panel_angle_deg(), str(door.is_blocked())])
	assert_true(door.get_panel_angle_deg() >= FULLY_OPEN_MIN_DEG, "sem corpo, a porta abre por inteiro (ângulo %.1f°)" % door.get_panel_angle_deg())
	await release_and_flush(world["container"] as Node3D)


## door_sala_corredor, segurando, sem corpo: abertura lenta por inteiro.
func test_porta_sala_corredor_segurar_sem_corpo_abre_por_inteiro() -> void:
	var world: Dictionary = await _world(Vector3(7.8, 0.0, -0.7), PI / 2.0)
	var root: Node = world["root"] as Node
	var player: PlayerRoot = world["player"] as PlayerRoot
	var door: Door = _door(root, "door_sala_corredor")
	await _hold(player, 30)
	await wait_physics_frames(OPEN_TICKS)
	note("sala-corredor, segurar, sem corpo: ângulo %.1f°; bloqueada=%s" % [door.get_panel_angle_deg(), str(door.is_blocked())])
	assert_true(door.get_panel_angle_deg() >= FULLY_OPEN_MIN_DEG, "segurando e sem corpo, a porta abre por inteiro (ângulo %.1f°)" % door.get_panel_angle_deg())
	await release_and_flush(world["container"] as Node3D)


## door_corredor_hall (painel para a sala grande do hall), toque e segurar sem corpo.
func test_porta_corredor_hall_sem_corpo_abre_por_inteiro() -> void:
	var results: PackedStringArray = PackedStringArray()
	var failures: PackedStringArray = PackedStringArray()
	for hold: bool in [false, true]:
		var world: Dictionary = await _world(Vector3(15.5, 0.0, -0.7), PI / 2.0)
		var root: Node = world["root"] as Node
		var player: PlayerRoot = world["player"] as PlayerRoot
		var door: Door = _door(root, "door_corredor_hall")
		if hold:
			await _hold(player, 30)
		else:
			await _tap(player)
		await wait_physics_frames(OPEN_TICKS)
		var label: String = "segurar" if hold else "toque"
		results.append("%s: %.1f°" % [label, door.get_panel_angle_deg()])
		if door.get_panel_angle_deg() < FULLY_OPEN_MIN_DEG:
			failures.append("%s: %.1f°" % [label, door.get_panel_angle_deg()])
		await release_and_flush(world["container"] as Node3D)
	note("corredor-hall, sem corpo: " + "; ".join(results))
	assert_eq(failures.size(), 0, "porta corredor-hall sem corpo abre por inteiro: " + "; ".join(failures))


# ---- Com corpo no arco: BUG-006 ----

## door_corredor_hall com corpo no arco (hall, de frente para a porta), toque e segurar: para, não desloca, bloqueio
## emitido uma vez, e liberada quando o corpo sai.
func test_porta_corredor_hall_corpo_no_arco_para_e_libera() -> void:
	var failures: PackedStringArray = PackedStringArray()
	var notes_text: PackedStringArray = PackedStringArray()
	for hold: bool in [false, true]:
		var world: Dictionary = await _world(Vector3(14.45, 0.0, -0.7), PI / 2.0)
		var root: Node = world["root"] as Node
		var player: PlayerRoot = world["player"] as PlayerRoot
		var meter: Fx.Meter = world["meter"] as Fx.Meter
		var door: Door = _door(root, "door_corredor_hall")
		var blocks: Array[Node] = []
		door.blocked.connect(func(body: Node) -> void: blocks.append(body))
		var start: Vector3 = player.global_position
		if hold:
			await _hold(player, 30)
		else:
			await _tap(player)
		await wait_physics_frames(OPEN_TICKS)
		var label: String = "segurar" if hold else "toque"
		var blocked_now: bool = door.is_blocked()
		var moved: float = player.global_position.distance_to(start)
		notes_text.append("%s no arco: ângulo %.1f°, bloqueada=%s, blocked emitido %d vez(es), corpo deslocou %.4f m, penetração=%d" % [
			label, door.get_panel_angle_deg(), str(blocked_now), blocks.size(), moved, meter.penetrations])
		if not blocked_now:
			failures.append("%s: não bloqueou com o corpo no arco" % label)
		if moved > MOVE_TOL_M:
			failures.append("%s: deslocou o corpo %.4f m" % [label, moved])
		if blocks.size() != 1:
			failures.append("%s: blocked emitido %d vezes (esperado 1, regra 3)" % [label, blocks.size()])
		if meter.penetrations > 0:
			failures.append("%s: penetração %d" % [label, meter.penetrations])
		# Sai do arco (para +X, na hall): a porta tem de ser liberada e completar.
		for index: int in 45:
			await _tick(player, meter, Fx.move_input(Vector2(0.0, -1.0)))
		player.get_motor().set_scripted_input(MotorInput.new())
		await wait_physics_frames(OPEN_TICKS)
		notes_text.append("%s, depois de sair: ângulo %.1f°, bloqueada=%s" % [label, door.get_panel_angle_deg(), str(door.is_blocked())])
		if door.is_blocked() or door.get_panel_angle_deg() < FULLY_OPEN_MIN_DEG:
			failures.append("%s: não liberou e completou (ângulo %.1f°, bloqueada=%s)" % [label, door.get_panel_angle_deg(), str(door.is_blocked())])
		await release_and_flush(world["container"] as Node3D)
	note("corredor-hall, corpo no arco: " + " | ".join(notes_text))
	assert_eq(failures.size(), 0, "porta corredor-hall com corpo no arco: " + "; ".join(failures))


## Corpo entra no arco no meio da abertura. Abertura lenta (segurar): o painel leva ~1,6 s para girar, e o corpo, que
## começa fora do arco (x = 7,3), entra no arco nos primeiros 25 ticks e fica parado. A porta tem de parar ao encostar
## no corpo (um blocked, sem deslocar o corpo) e completar depois que o corpo sai.
func test_porta_sala_corredor_corpo_entra_no_arco_no_meio_da_abertura() -> void:
	var world: Dictionary = await _world(Vector3(7.3, 0.0, -0.7), PI / 2.0)
	var root: Node = world["root"] as Node
	var player: PlayerRoot = world["player"] as PlayerRoot
	var meter: Fx.Meter = world["meter"] as Fx.Meter
	var door: Door = _door(root, "door_sala_corredor")
	var blocks: Array[Node] = []
	door.blocked.connect(func(body: Node) -> void: blocks.append(body))
	player.get_interaction().press_interact()
	for index: int in 25:
		await _tick(player, meter, Fx.move_input(Vector2(0.0, 1.0), false, true))
	player.get_interaction().release_interact()
	var entry_pos: Vector3 = player.global_position
	var contact_angle: float = -1.0
	var waited: int = 0
	while not door.is_blocked() and waited < 150:
		await _tick(player, meter, MotorInput.new())
		waited += 1
	var contact_pos: Vector3 = player.global_position
	contact_angle = door.get_panel_angle_deg()
	var entered: bool = door.is_blocked()
	for index: int in 30:
		await _tick(player, meter, MotorInput.new())
	var still_blocked: bool = door.is_blocked()
	var pushed: float = player.global_position.distance_to(contact_pos)
	for index: int in 45:
		await _tick(player, meter, Fx.move_input(Vector2(0.0, -1.0)))
	player.get_motor().set_scripted_input(MotorInput.new())
	await wait_physics_frames(OPEN_TICKS)
	note("entrada no meio da abertura (segurar): entrou no arco em %.2f m, bloqueou=%s em %.1f°; deslocou %.4f m depois do contato; blocked emitido %d vez(es); depois de sair: %.1f°, bloqueada=%s; %s" % [
		entry_pos.x, str(entered), contact_angle, pushed, blocks.size(), door.get_panel_angle_deg(), str(door.is_blocked()), meter.summary()])
	assert_true(entered, "o corpo que entra no meio da abertura bloqueia a porta")
	assert_true(still_blocked, "enquanto o corpo fica no arco, a porta continua bloqueada")
	assert_true(pushed <= MOVE_TOL_M, "o corpo não é empurrado depois do contato (%.4f m)" % pushed)
	assert_eq(blocks.size(), 1, "um único bloqueio contínuo emite blocked uma vez (regra 3; emitido %d)" % blocks.size())
	assert_false(door.is_blocked(), "liberada quando o corpo sai")
	assert_true(door.get_panel_angle_deg() >= FULLY_OPEN_MIN_DEG, "depois de liberada, completa a abertura (%.1f°)" % door.get_panel_angle_deg())
	assert_eq(meter.penetrations, 0, "sem penetração durante a entrada no meio da abertura (%d)" % meter.penetrations)
	await release_and_flush(world["container"] as Node3D)


# ---- Porta aberta e porta trancada ----

## door_sala_cozinha começa aberta: o corpo no arco dela não a bloqueia (não há giro) e o estado continua OPEN.
## Director, integração da F3-004: o toque numa porta aberta passou a FECHÁ-LA (decisão da F3-002). Antes, este teste
## esperava que nada acontecesse. Com o jogador no arco do painel, o fechamento para no corpo (blocked), a porta
## continua OPEN (o portal acústico segue aberto) e o jogador não é empurrado.
func test_porta_sala_cozinha_aberta_toque_fecha_e_para_no_corpo() -> void:
	var world: Dictionary = await _world(Vector3(6.45, 0.0, -3.0), 0.0)
	var root: Node = world["root"] as Node
	var player: PlayerRoot = world["player"] as PlayerRoot
	var door: Door = _door(root, "door_sala_cozinha")
	var blocks: Array[Node] = []
	door.blocked.connect(func(body: Node) -> void: blocks.append(body))
	assert_eq(door.get_state(), Door.State.OPEN, "a porta começa aberta")
	var start: Vector3 = player.global_position
	await _tap(player)
	await wait_physics_frames(OPEN_TICKS)
	note("sala-cozinha (aberta): estado=%d, blocked=%d, ângulo %.1f°, jogador deslocado %.3f m" % [int(door.get_state()),
		blocks.size(), door.get_panel_angle_deg(), player.global_position.distance_to(start)])
	assert_true(blocks.size() >= 1, "o painel parou no corpo do jogador (blocked)")
	assert_eq(door.get_state(), Door.State.OPEN, "fechamento interrompido: a porta continua OPEN")
	assert_true(player.global_position.distance_to(start) < 0.05, "o jogador não foi empurrado pelo painel")
	await release_and_flush(world["container"] as Node3D)


## door_cozinha_corredor está trancada: toque dá locked_feedback, o estado continua LOCKED e nada se mexe.
func test_porta_cozinha_corredor_trancada_so_da_feedback() -> void:
	var world: Dictionary = await _world(Vector3(8.5, 0.0, -0.6), 0.0)
	var root: Node = world["root"] as Node
	var player: PlayerRoot = world["player"] as PlayerRoot
	var door: Door = _door(root, "door_cozinha_corredor")
	var feedback: Array[int] = [0]
	door.locked_feedback.connect(func(_actor: Node) -> void: feedback[0] += 1)
	var angle_before: float = door.get_panel_angle_deg()
	await _tap(player)
	await wait_physics_frames(OPEN_TICKS)
	note("cozinha-corredor (trancada): feedback=%d, estado=%d, ângulo %.1f -> %.1f" % [feedback[0], int(door.get_state()), angle_before, door.get_panel_angle_deg()])
	assert_eq(door.get_state(), Door.State.LOCKED, "a porta continua trancada")
	assert_eq(feedback[0], 1, "toque em porta trancada emite locked_feedback uma vez")
	assert_almost_eq(door.get_panel_angle_deg(), angle_before, 0.01, "a porta trancada não se mexe")
	await release_and_flush(world["container"] as Node3D)


# ---- Brecha no batente e intrusão do painel ----

## Profundidade em que o painel entra no batente estático, por ângulo (medida, não passa nem reprova). É a informação
## para classificar o efeito visual do giro com a regra 1 (geometria estática não bloqueia).
func test_medicao_intrusao_do_painel_no_batente_por_angulo() -> void:
	var world: Dictionary = await _world(Vector3(7.8, 0.0, -0.7), PI / 2.0)
	var root: Node = world["root"] as Node
	var door: Door = _door(root, "door_sala_corredor")
	var lines: PackedStringArray = PackedStringArray()
	var worst: float = 0.0
	var worst_angle: float = 0.0
	var panel: Node3D = door.get_node("Panel") as Node3D
	for angle: float in [0.0, 10.0, 20.0, 27.0, 35.0, 45.0, 60.0, 75.0, 90.0]:
		var depth: float = _static_intrusion_m(door, angle)
		if depth > worst:
			worst = depth
			worst_angle = angle
		lines.append("%.0f°: %.1f mm" % [angle, depth * 1000.0])
	note("intrusão do painel no batente (encolhimento que libera a sobreposição): " + "; ".join(lines) + " | pior %.1f mm a %.0f°" % [worst * 1000.0, worst_angle])
	assert_true(panel != null, "o painel existe para a medição")
	assert_true(worst < 0.03, "medida dentro da faixa de busca (pior %.1f mm; 25 mm = limite da busca)" % (worst * 1000.0))
	await release_and_flush(world["container"] as Node3D)


## Brecha: o corpo tenta atravessar o trecho de batente onde o painel encontra a parede (z entre −1,45 e −1,20, parede
## estática) em vários ângulos do painel. Se algum ângulo deixar passar, o encontro painel-batente abre passagem.
func test_brecha_no_encontro_do_painel_com_o_batente_nao_existe() -> void:
	var failures: PackedStringArray = PackedStringArray()
	for angle: float in [0.0, 15.0, 27.0, 45.0, 60.0, 90.0]:
		var world: Dictionary = await _world(Vector3(4.2, 0.0, -1.32), -PI / 2.0)
		var root: Node = world["root"] as Node
		var player: PlayerRoot = world["player"] as PlayerRoot
		var door: Door = _door(root, "door_sala_corredor")
		var panel: Node3D = door.get_node("Panel") as Node3D
		panel.rotation.y = deg_to_rad(angle)
		await wait_physics_frames(4)
		var meter: Fx.Meter = world["meter"] as Fx.Meter
		var max_x: float = player.global_position.x
		for index: int in 120:
			await _tick(player, meter, Fx.move_input(Vector2(0.0, 1.0)))
			max_x = maxf(max_x, player.global_position.x)
		if max_x > 6.6:
			failures.append("painel a %.0f°: corpo passou (x máximo %.2f)" % [angle, max_x])
		note("batente em z=-1,32, painel a %.0f°: x máximo %.2f; penetração=%d" % [angle, max_x, meter.penetrations])
		await release_and_flush(world["container"] as Node3D)
	assert_eq(failures.size(), 0, "nenhuma brecha pelo batente: " + "; ".join(failures))


## Consequência da regra (1), aceita pelo Director: geometria estática no arco não bloqueia o giro (é responsabilidade do
## level design). Uma caixa estática no caminho do painel: a porta completa 90° e o painel passa por dentro dela.
## O teste documenta o comportamento aceito; a profundidade medida vai para a nota.
func test_geometria_estatica_no_arco_nao_bloqueia_o_giro_aceito() -> void:
	var world: Dictionary = await _world(Vector3(7.8, 0.0, -0.7), PI / 2.0)
	var root: Node = world["root"] as Node
	var player: PlayerRoot = world["player"] as PlayerRoot
	var container: Node3D = world["container"] as Node3D
	var door: Door = _door(root, "door_sala_corredor")
	var box: StaticBody3D = StaticBody3D.new()
	box.position = Vector3(6.8, 1.0, -1.0)  # dentro do arco, fora da linha de visão da mira (z = -0,7)
	var shape_node: CollisionShape3D = CollisionShape3D.new()
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = Vector3(0.3, 2.0, 0.3)
	shape_node.shape = shape
	box.add_child(shape_node)
	container.add_child(box)
	await wait_physics_frames(SETTLE_TICKS)
	await _tap(player)
	await wait_physics_frames(OPEN_TICKS)
	var intrusion: float = _static_intrusion_m(door, 90.0)
	note("caixa estática no arco: ângulo final %.1f°; bloqueada=%s; intrusão do painel na caixa (aprox.) %.1f mm" % [door.get_panel_angle_deg(), str(door.is_blocked()), intrusion * 1000.0])
	assert_true(door.get_panel_angle_deg() >= FULLY_OPEN_MIN_DEG, "geometria estática no arco não bloqueia o giro (ângulo %.1f°)" % door.get_panel_angle_deg())
	assert_false(door.is_blocked(), "a porta não fica bloqueada por geometria estática")
	await release_and_flush(world["container"] as Node3D)

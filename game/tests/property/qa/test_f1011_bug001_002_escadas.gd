extends TestCase
## F1-011 (QA independente): verificação de BUG-001 (subida) e BUG-002 (descida) com experimentos que a suíte
## da F1 não cobre: andar devagar, agachado, rastejando, correndo, diagonal suave, troca de postura no meio da
## escada, parada no meio da escada, entrada pela borda e encosto na face lateral. Mundo: a sandbox real
## (content/levels/sandbox.tscn), um mundo de física isolado por fase.
## Critério (BUG_REPORTS): 0 ticks sem chão, nenhum landed espúrio, nenhuma penetração do colisor em geometria.
## Autor: QA Engineer (F1-011).

const Fx := preload("res://tests/integration/qa/fixtures/qa_fixture.gd")

const SETTLE_TICKS: int = 12
const MAX_TICKS: int = 900
const PLATFORM_WAIT_TICKS: int = 40
const HOLD_TICKS: int = 60
## Medida de parada: a queda é contada a partir deste tick da parada (o corpo termina de frear antes).
const HOLD_SETTLE_TICKS: int = 12
const HOLD_DROP_TOL_M: float = 0.005
const TOP_Z: float = -2.95
const TOP_Y: float = 1.0
const BOTTOM_Z: float = -0.9
const BOTTOM_Y: float = 0.1
const MEZZ_Y: float = 1.08
const MEZZ_START_Z: float = -3.0
const STAIR_X: float = 17.0
const HALL_START_Z: float = -0.55
## Com centro em z > -0,75 o colisor (raio 0,25) nasce dentro do degrau 1 (topo 0,18 m): essas fases são inválidas.
const SWEEP_FINE_COUNT: int = 20
const SWEEP_FINE_STEP_M: float = 0.01
const SWEEP_COARSE_COUNT: int = 10
const SWEEP_COARSE_STEP_M: float = 0.02
## Abertura da escada em x (1,2 m, de 16,4 a 17,6). Com o centro dentro de [16,65; 17,35] o colisor cabe inteiro.
const OPENING_MIN_X: float = 16.65
const OPENING_MAX_X: float = 17.35
## Diagonal suave: 14° em relação ao eixo da escada (o corpo continua sobre a escada).
const SOFT_DIAGONAL_MOVE: Vector2 = Vector2(0.25, 0.968)

## Estado do bot (zerado em cada passagem).
var _hold_drop_m: float = 0.0
var _stance_changes: int = 0


func before_all() -> void:
	Settings.autosave = false


func after_all() -> void:
	Settings.autosave = true


func before_each() -> void:
	_hold_drop_m = 0.0
	_stance_changes = 0


func _on_stance_changed(_old: Enums.Stance, _new: Enums.Stance) -> void:
	_stance_changes += 1


# ---- Bot ----

## Um tick: aplica a entrada, espera um tick de física e mede.
func _tick(player: PlayerRoot, input: MotorInput, meter: Fx.Meter) -> void:
	player.get_motor().set_scripted_input(input)
	await wait_physics_frames(1)
	meter.sample(player, Fx.body_overlaps_world(player))


func _idle(player: PlayerRoot, meter: Fx.Meter, ticks: int) -> void:
	for index: int in ticks:
		await _tick(player, MotorInput.new(), meter)


func _arrived(player: PlayerRoot, going_up: bool) -> bool:
	var p: Vector3 = player.global_position
	if going_up:
		return p.z < TOP_Z and p.y > TOP_Y
	return p.z > BOTTOM_Z and p.y < BOTTOM_Y


func _event_due(player: PlayerRoot, event: Dictionary) -> bool:
	var z: float = player.global_position.z
	var threshold: float = float(event["z"])
	if str(event["when"]) == "below":
		return z < threshold
	return z > threshold


func _apply_event(player: PlayerRoot, meter: Fx.Meter, event: Dictionary) -> void:
	var kind: String = str(event["kind"])
	if kind == "edge":
		await _tick(player, Fx.edge_input(int(event["edge"])), meter)
		return
	if kind == "hold":
		var ticks: int = int(event["ticks"])
		var y_settled: float = 0.0
		for index: int in ticks:
			await _tick(player, MotorInput.new(), meter)
			if index == HOLD_SETTLE_TICKS - 1:
				y_settled = player.global_position.y
		_hold_drop_m = maxf(_hold_drop_m, y_settled - player.global_position.y)


## Anda com move até chegar (going_up: no mezanino; senão: no piso), disparando os eventos na ordem de z.
func _walk(player: PlayerRoot, meter: Fx.Meter, move: Vector2, sprint: bool, slow: bool, events: Array, going_up: bool) -> bool:
	var pending: Array = events.duplicate()
	var ticks: int = 0
	while ticks < MAX_TICKS and not _arrived(player, going_up):
		if not pending.is_empty() and _event_due(player, pending[0] as Dictionary):
			var event: Dictionary = pending.pop_front() as Dictionary
			await _apply_event(player, meter, event)
		else:
			await _tick(player, Fx.move_input(move, sprint, slow), meter)
		ticks += 1
	return _arrived(player, going_up)


## Uma passagem. climb = true: começa no piso, sobe ao mezanino, espera e desce. climb = false: começa no mezanino
## (y = 1,08 m) e só desce. profile: edge (postura antes de andar), slow, sprint. move: direção no plano (y = frente).
## Os medidores só começam depois do assentamento inicial.
func _run_phase(start: Vector3, climb: bool, profile: Dictionary, move: Vector2, up_events: Array, down_events: Array) -> Dictionary:
	var container: Node3D = add_isolated_world()
	var level: Node3D = Fx.instantiate_level(Fx.SANDBOX_PATH, container)
	var player: PlayerRoot = level.get_node("Player") as PlayerRoot
	_hold_drop_m = 0.0
	_stance_changes = 0
	player.global_position = start
	await wait_physics_frames(SETTLE_TICKS)
	var motor: PlayerMotor = player.get_motor()
	motor.stance_changed.connect(_on_stance_changed)
	var slow: bool = bool(profile.get("slow", false))
	var sprint: bool = bool(profile.get("sprint", false))
	var edge: int = int(profile.get("edge", Fx.EDGE_NONE))
	var up: Fx.Meter = Fx.Meter.new()
	var down: Fx.Meter = Fx.Meter.new()
	up.connect_motor(player)
	down.connect_motor(player)
	var up_ok: bool = true
	if climb:
		if edge != Fx.EDGE_NONE:
			await _tick(player, Fx.edge_input(edge), up)
		up_ok = await _walk(player, up, move, sprint, slow, up_events, true)
		await _idle(player, up, PLATFORM_WAIT_TICKS)
	elif edge != Fx.EDGE_NONE:
		await _tick(player, Fx.edge_input(edge), down)
	var down_ok: bool = await _walk(player, down, -move, false, slow, down_events, false)
	var result: Dictionary = {
		"up": up, "down": down, "up_ok": up_ok, "down_ok": down_ok,
		"hold_drop": _hold_drop_m, "stance_changes": _stance_changes,
		"final": player.global_position,
	}
	motor.stance_changed.disconnect(_on_stance_changed)
	await release_and_flush(container.get_parent())
	return result


## Varredura de fases: uma passagem por posição inicial. Devolve as falhas (vazio = nenhuma).
func _sweep(label: String, climb: bool, profile: Dictionary, count: int, step_m: float) -> PackedStringArray:
	var failures: PackedStringArray = PackedStringArray()
	var total_air: int = 0
	var total_landed: int = 0
	var total_pen: int = 0
	var worst_run: int = 0
	for index: int in count:
		var start: Vector3 = Vector3(STAIR_X, 0.0, HALL_START_Z - step_m * float(index))
		if not climb:
			start = Vector3(STAIR_X, MEZZ_Y, MEZZ_START_Z - step_m * float(index))
		var result: Dictionary = await _run_phase(start, climb, profile, Vector2(0.0, 1.0), [], [])
		var up: Fx.Meter = result["up"] as Fx.Meter
		var down: Fx.Meter = result["down"] as Fx.Meter
		total_air += up.airborne + down.airborne
		total_landed += up.landed + down.landed
		total_pen += up.penetrations + down.penetrations
		worst_run = maxi(worst_run, maxi(up.airborne_run_max, down.airborne_run_max))
		var clean: bool = up.airborne + down.airborne == 0 and up.landed + down.landed == 0 and up.penetrations + down.penetrations == 0
		if not (bool(result["up_ok"]) and bool(result["down_ok"])) or not clean:
			failures.append("%s fase %d (inicio %s): chegou=%s/%s subida[%s] descida[%s]" % [
				label, index, str(start), str(result["up_ok"]), str(result["down_ok"]), up.summary(), down.summary()])
	note("%s: %d fases; ticks sem chão=%d; landed=%d; penetrações=%d; maior sequência sem chão=%d" % [label, count, total_air, total_landed, total_pen, worst_run])
	return failures


func _assert_sweep(failures: PackedStringArray, label: String) -> void:
	assert_eq(failures.size(), 0, "%s: %s" % [label, "; ".join(failures)])


# ---- Subida e descida em varredura (BUG-001 e BUG-002) ----

func test_bug001_bug002_andando_devagar_varredura_de_fase() -> void:
	var failures: PackedStringArray = await _sweep("devagar", true, {"slow": true}, SWEEP_FINE_COUNT, SWEEP_FINE_STEP_M)
	_assert_sweep(failures, "andar devagar (0,9 m/s), subida e descida")


func test_bug001_bug002_agachado_varredura_de_fase() -> void:
	var failures: PackedStringArray = await _sweep("agachado", true, {"edge": Fx.EDGE_CROUCH}, SWEEP_FINE_COUNT, SWEEP_FINE_STEP_M)
	_assert_sweep(failures, "agachado (colisor 1,10 m), subida e descida")


func test_bug001_bug002_rastejando_varredura_de_fase() -> void:
	var failures: PackedStringArray = await _sweep("rastejando", true, {"edge": Fx.EDGE_CRAWL}, SWEEP_COARSE_COUNT, SWEEP_COARSE_STEP_M)
	_assert_sweep(failures, "rastejando (colisor 0,55 m), subida e descida")


func test_bug001_bug002_correndo_varredura_de_fase() -> void:
	var failures: PackedStringArray = await _sweep("correndo", true, {"sprint": true}, SWEEP_FINE_COUNT, SWEEP_FINE_STEP_M)
	_assert_sweep(failures, "correndo (4,8 m/s) na subida, descida andando")


func test_bug002_descida_a_partir_do_mezanino_andando_devagar() -> void:
	var failures: PackedStringArray = await _descent_sweep("descida devagar", {"slow": true}, SWEEP_FINE_COUNT, SWEEP_FINE_STEP_M)
	_assert_sweep(failures, "descida devagar a partir do mezanino, BUG-002")


func test_bug002_descida_agachado_a_partir_do_mezanino() -> void:
	var failures: PackedStringArray = await _descent_sweep("descida agachado", {"edge": Fx.EDGE_CROUCH}, SWEEP_FINE_COUNT, SWEEP_FINE_STEP_M)
	_assert_sweep(failures, "descida agachado a partir do mezanino, BUG-002")


func test_bug002_descida_rastejando_a_partir_do_mezanino() -> void:
	var failures: PackedStringArray = await _descent_sweep("descida rastejando", {"edge": Fx.EDGE_CRAWL}, SWEEP_COARSE_COUNT, SWEEP_COARSE_STEP_M)
	_assert_sweep(failures, "descida rastejando a partir do mezanino, BUG-002")


func _descent_sweep(label: String, profile: Dictionary, count: int, step_m: float) -> PackedStringArray:
	var failures: PackedStringArray = PackedStringArray()
	var total_air: int = 0
	var total_landed: int = 0
	var total_pen: int = 0
	for index: int in count:
		var start: Vector3 = Vector3(STAIR_X, MEZZ_Y, MEZZ_START_Z - step_m * float(index))
		var result: Dictionary = await _run_phase(start, false, profile, Vector2(0.0, 1.0), [], [])
		var down: Fx.Meter = result["down"] as Fx.Meter
		total_air += down.airborne
		total_landed += down.landed
		total_pen += down.penetrations
		if not bool(result["down_ok"]) or down.airborne > 0 or down.landed > 0 or down.penetrations > 0:
			failures.append("%s fase %d (inicio %s): desceu=%s descida[%s]" % [label, index, str(start), str(result["down_ok"]), down.summary()])
	note("%s: %d fases; ticks sem chão=%d; landed=%d; penetrações=%d" % [label, count, total_air, total_landed, total_pen])
	return failures


# ---- Diagonal suave e entradas deslocadas ----

## Diagonal de 14° (o corpo fica sobre a escada): sem ticks no ar, sem landed espúrio, sem penetração.
func test_bug001_diagonal_suave_sobe_e_desce_sem_queda() -> void:
	var failures: PackedStringArray = PackedStringArray()
	var total_air: int = 0
	var total_landed: int = 0
	var total_pen: int = 0
	# Com deriva de 0,44 m em x, o colisor fica entre 16,55 e 17,49 m: não toca a guarda do lado leste.
	for start_x: float in [16.75, 16.85]:
		for index: int in 3:
			var start: Vector3 = Vector3(start_x, 0.0, HALL_START_Z - 0.02 * float(index))
			var result: Dictionary = await _run_phase(start, true, {"slow": true}, SOFT_DIAGONAL_MOVE, [], [])
			var up: Fx.Meter = result["up"] as Fx.Meter
			var down: Fx.Meter = result["down"] as Fx.Meter
			total_air += up.airborne + down.airborne
			total_landed += up.landed + down.landed
			total_pen += up.penetrations + down.penetrations
			if not (bool(result["up_ok"]) and bool(result["down_ok"])) or up.airborne + down.airborne > 0 or up.landed + down.landed > 0 or up.penetrations + down.penetrations > 0:
				failures.append("x0=%.2f fase %d: chegou=%s/%s subida[%s] descida[%s]" % [start_x, index, str(result["up_ok"]), str(result["down_ok"]), up.summary(), down.summary()])
	note("diagonal 14°: 6 passagens; ticks sem chão=%d; landed=%d; penetrações=%d" % [total_air, total_landed, total_pen])
	assert_eq(failures.size(), 0, "diagonal suave: " + "; ".join(failures))


## Entrada pela borda da escada (centro de x fora de [16,65; 17,35]): a guarda do mezanino (x 14 a 16,4 e 17,6 a 20)
## bloqueia o colisor. O esperado é: não cai, não atravessa e, andando para o centro da abertura, sobe.
func test_bug001_entrada_pela_borda_e_guarda_do_mezanino() -> void:
	var failures: PackedStringArray = PackedStringArray()
	for start_x: float in [16.3, 16.45, 17.55, 17.7]:
		var container: Node3D = add_isolated_world()
		var level: Node3D = Fx.instantiate_level(Fx.SANDBOX_PATH, container)
		var player: PlayerRoot = level.get_node("Player") as PlayerRoot
		player.global_position = Vector3(start_x, 0.0, HALL_START_Z)
		await wait_physics_frames(SETTLE_TICKS)
		var meter: Fx.Meter = Fx.Meter.new()
		meter.connect_motor(player)
		# Sobe reto até encostar na guarda (ou chegar).
		for index: int in 500:
			await _tick(player, Fx.move_input(Vector2(0.0, 1.0), false, true), meter)
			if _arrived(player, true):
				break
		var blocked_at: Vector3 = player.global_position
		# Recupera: anda para o centro da abertura (x) e depois sobe de novo.
		var toward_center: float = 1.0 if start_x < OPENING_MIN_X else -1.0
		for index: int in 60:
			await _tick(player, Fx.move_input(Vector2(toward_center, 0.0), false, true), meter)
		for index: int in 500:
			await _tick(player, Fx.move_input(Vector2(0.0, 1.0), false, true), meter)
			if _arrived(player, true):
				break
		note("entrada x=%.2f: parou em z=%.3f (y=%.2f); depois de recentrar chegou=%s; %s" % [
			start_x, blocked_at.z, blocked_at.y, str(_arrived(player, true)), meter.summary()])
		if meter.airborne > 0 or meter.landed > 0 or meter.penetrations > 0:
			failures.append("x=%.2f: %s" % [start_x, meter.summary()])
		if not _arrived(player, true):
			failures.append("x=%.2f: preso, não subiu nem depois de recentrar (z=%.3f y=%.2f)" % [start_x, player.global_position.z, player.global_position.y])
		await release_and_flush(container.get_parent())
	assert_eq(failures.size(), 0, "entrada pela borda: " + "; ".join(failures))


## Entrada deslocada em x, dentro da abertura, sobe em linha reta sem queda (o colisor cabe inteiro).
func test_bug001_entrada_dentro_da_abertura_sobe_sem_queda() -> void:
	var failures: PackedStringArray = PackedStringArray()
	for start_x: float in [16.7, 16.9, 17.1, 17.3]:
		var start: Vector3 = Vector3(start_x, 0.0, HALL_START_Z)
		var result: Dictionary = await _run_phase(start, true, {"slow": false}, Vector2(0.0, 1.0), [], [])
		var up: Fx.Meter = result["up"] as Fx.Meter
		var down: Fx.Meter = result["down"] as Fx.Meter
		if not bool(result["up_ok"]) or not bool(result["down_ok"]) or up.airborne + down.airborne > 0 or up.landed + down.landed > 0 or up.penetrations + down.penetrations > 0:
			failures.append("x=%.2f: chegou=%s/%s subida[%s] descida[%s]" % [start_x, str(result["up_ok"]), str(result["down_ok"]), up.summary(), down.summary()])
	assert_eq(failures.size(), 0, "entrada dentro da abertura: " + "; ".join(failures))


# ---- Postura e parada no meio da escada ----

## Troca de postura no meio da subida: agacha no degrau 3, rasteja, volta a agachar e levanta no mezanino.
func test_bug001_troca_de_postura_no_meio_da_subida() -> void:
	var events: Array = [
		{"z": -1.5, "when": "below", "kind": "edge", "edge": Fx.EDGE_CROUCH},
		{"z": -1.9, "when": "below", "kind": "edge", "edge": Fx.EDGE_CRAWL},
		{"z": -2.3, "when": "below", "kind": "edge", "edge": Fx.EDGE_CRAWL},
		{"z": -2.6, "when": "below", "kind": "edge", "edge": Fx.EDGE_CROUCH},
		{"z": -2.7, "when": "below", "kind": "edge", "edge": Fx.EDGE_CROUCH},
	]
	var result: Dictionary = await _run_phase(Vector3(STAIR_X, 0.0, HALL_START_Z), true, {"slow": false}, Vector2(0.0, 1.0), events, [])
	var up: Fx.Meter = result["up"] as Fx.Meter
	var down: Fx.Meter = result["down"] as Fx.Meter
	note("troca de postura na subida: mudanças de postura=%d; subida[%s]; descida[%s]" % [int(result["stance_changes"]), up.summary(), down.summary()])
	assert_true(bool(result["up_ok"]), "chegou ao mezanino trocando de postura")
	assert_eq(up.airborne + up.landed + up.penetrations, 0, "troca de postura no meio da subida: sem ticks no ar, landed ou penetração (%s)" % up.summary())
	assert_eq(down.airborne + down.penetrations, 0, "descida depois da troca: sem ticks no ar ou penetração (%s)" % down.summary())


## Parada no meio da subida: para três vezes por 60 ticks, em degraus diferentes, e segue.
func test_bug001_parada_no_meio_da_subida_nao_cai() -> void:
	var events: Array = [
		{"z": -1.2, "when": "below", "kind": "hold", "ticks": HOLD_TICKS},
		{"z": -1.9, "when": "below", "kind": "hold", "ticks": HOLD_TICKS},
		{"z": -2.5, "when": "below", "kind": "hold", "ticks": HOLD_TICKS},
	]
	var result: Dictionary = await _run_phase(Vector3(STAIR_X, 0.0, HALL_START_Z), true, {"slow": true}, Vector2(0.0, 1.0), events, [])
	var up: Fx.Meter = result["up"] as Fx.Meter
	note("parada na subida: queda parado (após %d ticks)=%.4f m; subida[%s]" % [HOLD_SETTLE_TICKS, float(result["hold_drop"]), up.summary()])
	assert_true(bool(result["up_ok"]), "chegou ao mezanino depois das paradas")
	assert_true(float(result["hold_drop"]) <= HOLD_DROP_TOL_M, "parado na escada o corpo não desce (queda %.4f m)" % float(result["hold_drop"]))
	assert_eq(up.airborne + up.penetrations, 0, "paradas na subida: sem ticks no ar ou penetração (%s)" % up.summary())


## Parada no meio da descida, sobre os degraus 5, 4 e 3: para 60 ticks e segue.
func test_bug002_parada_no_meio_da_descida_nao_cai() -> void:
	var events: Array = [
		{"z": -2.2, "when": "above", "kind": "hold", "ticks": HOLD_TICKS},
		{"z": -1.9, "when": "above", "kind": "hold", "ticks": HOLD_TICKS},
		{"z": -1.5, "when": "above", "kind": "hold", "ticks": HOLD_TICKS},
	]
	var result: Dictionary = await _run_phase(Vector3(STAIR_X, MEZZ_Y, MEZZ_START_Z), false, {"slow": true}, Vector2(0.0, 1.0), [], events)
	var down: Fx.Meter = result["down"] as Fx.Meter
	note("parada na descida: queda parado (após %d ticks)=%.4f m; descida[%s]" % [HOLD_SETTLE_TICKS, float(result["hold_drop"]), down.summary()])
	assert_true(bool(result["down_ok"]), "desceu até o piso depois das paradas")
	assert_true(float(result["hold_drop"]) <= HOLD_DROP_TOL_M, "parado na descida o corpo não cai (queda %.4f m)" % float(result["hold_drop"]))
	assert_eq(down.airborne + down.penetrations, 0, "paradas na descida: sem ticks no ar ou penetração (%s)" % down.summary())


# ---- Face lateral e saída lateral ----

## Anda de lado (+X) contra a face de um degrau de 0,72 m: a face é alta demais para subir, então o corpo para
## antes dela, sem atravessar e sem ficar no ar.
func test_bug001_parede_lateral_da_escada_bloqueia_sem_atravessar() -> void:
	var container: Node3D = add_isolated_world()
	var level: Node3D = Fx.instantiate_level(Fx.SANDBOX_PATH, container)
	var player: PlayerRoot = level.get_node("Player") as PlayerRoot
	player.global_position = Vector3(15.6, 0.0, -2.0)
	await wait_physics_frames(SETTLE_TICKS)
	var meter: Fx.Meter = Fx.Meter.new()
	meter.connect_motor(player)
	for index: int in 120:
		await _tick(player, Fx.move_input(Vector2(1.0, 0.0)), meter)
	note("encosto lateral no degrau de 0,72 m: x final=%.3f; %s" % [player.global_position.x, meter.summary()])
	assert_true(player.global_position.x < 16.4, "o corpo para antes da face lateral do degrau (x = %.3f)" % player.global_position.x)
	assert_eq(meter.penetrations, 0, "encostado na face lateral o colisor não cruza a geometria (%s)" % meter.summary())
	assert_eq(meter.airborne, 0, "encostado na face lateral o corpo continua no chão (%s)" % meter.summary())
	await release_and_flush(container.get_parent())


## Sobe no degrau de 0,18 m de lado e sai da escada pelo lado de fora: a descida de 0,18 m não pode gerar
## ticks no ar nem landed.
func test_bug002_saida_lateral_do_degrau_de_0_18_nao_gera_queda() -> void:
	var container: Node3D = add_isolated_world()
	var level: Node3D = Fx.instantiate_level(Fx.SANDBOX_PATH, container)
	var player: PlayerRoot = level.get_node("Player") as PlayerRoot
	# Nasce em cima do degrau 1 (topo em 0,18 m), não dentro dele.
	player.global_position = Vector3(16.6, 0.18, -1.14)
	await wait_physics_frames(SETTLE_TICKS)
	var meter: Fx.Meter = Fx.Meter.new()
	meter.connect_motor(player)
	for index: int in 3:
		await _tick(player, MotorInput.new(), meter)
	for index: int in 120:
		await _tick(player, Fx.move_input(Vector2(1.0, 0.0), false, true), meter)
	note("saída lateral do degrau de 0,18 m: x final=%.3f y=%.3f; %s" % [player.global_position.x, player.global_position.y, meter.summary()])
	assert_true(player.global_position.x > 17.8, "saiu da escada para o lado (x = %.3f)" % player.global_position.x)
	assert_almost_eq(player.global_position.y, 0.0, 0.02, "no piso do hall ao sair (y = %.3f)" % player.global_position.y)
	assert_eq(meter.airborne, 0, "a queda de 0,18 m ao sair de lado não deixa o corpo no ar (%s)" % meter.summary())
	assert_eq(meter.landed, 0, "a queda de 0,18 m ao sair de lado não gera landed (%s)" % meter.summary())
	assert_eq(meter.penetrations, 0, "sem penetração ao sair de lado (%s)" % meter.summary())
	await release_and_flush(container.get_parent())

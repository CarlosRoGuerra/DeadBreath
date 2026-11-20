extends RefCounted
## Núcleo do cenário gravado (F2-011, QA). Roteiro: idle, correr até esgotar sob ameaça, seguir se esforçando sob
## ameaça até a crise (SYMPTOMATIC), esperar a primeira tosse, usar a bombinha, descansar agachado até a recuperação.
## Grava capturas com janela (PNG), telemetria por tick de física (CSV), eventos com o tempo (JSON) e o played_log do
## BreathingAudio (JSON). O master_volume fica em 0 (mudo): nada toca nos alto-falantes; os logs são a evidência.
## Autor: QA Engineer (F2-011). Saídas em Docs/QA/EVIDENCE/F2-011_cenario_*.

const PLAYABLE_PATH: String = "res://content/levels/sandbox_playable.tscn"
const OUT_DIR: String = "D:/Dev/DeadBreath/Docs/QA/EVIDENCE/"
const PREFIX: String = "F2-011_cenario_"
const SPAWN: Vector3 = Vector3(9.0, 0.0, -4.5)
const WEST_BOUND_X: float = 7.2
const EAST_BOUND_X: float = 12.8
const STEP_S: float = 1.0 / 60.0
const SETTLE_FRAMES: int = 12
const IDLE_S: float = 1.5
const TIMEOUT_RUN_S: float = 40.0
const CRISIS_CAPTURE_DELAY_S: float = 1.0
const TIMEOUT_COUGH_S: float = 180.0
const BEFORE_INHALER_S: float = 1.0
const AFTER_INHALER_S: float = 4.0
const TIMEOUT_RECOVERY_S: float = 150.0
const TAIL_S: float = 2.0

var _tree: SceneTree = null
var _root: Node = null
var _player: PlayerRoot = null
var _physio: PhysiologyComponent = null
var _audio: BreathingAudio = null
var _world: AcousticWorld = null
var _fx: CameraEffects = null
var _stub: StubThreatSource = null
var _facing_east: bool = true
var _phase: String = "inicio"
var _t_s: float = 0.0
var _frame_events: PackedStringArray = PackedStringArray()
var _events: Array[Dictionary] = []
var _rows: PackedStringArray = PackedStringArray()
var _pending_capture: String = ""
var _depleted: bool = false
var _symptomatic_seen: bool = false
var _symptomatic_t_s: float = 0.0
var _crisis_captured: bool = false
var _cough_seen: bool = false
var _recovering_seen: bool = false
var _recovered: bool = false
var _state_names: PackedStringArray = PackedStringArray()


func start(tree: SceneTree) -> void:
	_tree = tree
	_run()


func _run() -> void:
	var settings: Node = _tree.root.get_node("Settings")
	settings.set("autosave", false)
	settings.call("set_value", &"master_volume", 0.0)
	var scene: PackedScene = load(PLAYABLE_PATH) as PackedScene
	_root = scene.instantiate()
	_tree.root.add_child(_root)
	for _i: int in SETTLE_FRAMES:
		await _tree.process_frame
	_player = _find_player(_root)
	if _player == null:
		push_error("F2-011 cenario: PlayerRoot não encontrado na cena")
		_tree.quit(1)
		return
	_physio = _player.get_physiology()
	_audio = _root.get_node("BreathingAudio") as BreathingAudio
	_world = _root.get_node("AcousticWorld") as AcousticWorld
	_fx = _root.get_node("CameraEffects") as CameraEffects
	_stub = _player.get_threat_source() as StubThreatSource
	if _stub == null:
		push_error("F2-011 cenario: ThreatSource padrão não é StubThreatSource")
		_tree.quit(1)
		return
	_player.teleport_to(SPAWN)
	_player.rotation.y = -PI / 2.0
	_connect_signals()
	for _i: int in SETTLE_FRAMES:
		await _tree.physics_frame
	await _scenario()
	_write_outputs()
	print("CENARIO fim: t=%.2f s; capturas=%d; linhas=%d; eventos=%d; entradas_played_log=%d" % [
		_t_s, _captures_count(), _rows.size(), _events.size(), _audio.played_log.size()])
	print("CENARIO estados: " + ", ".join(_state_names))
	_tree.quit(0)


func _find_player(node: Node) -> PlayerRoot:
	if node is PlayerRoot:
		return node as PlayerRoot
	for child: Node in node.get_children():
		var found: PlayerRoot = _find_player(child)
		if found != null:
			return found
	return null


func _captures_count() -> int:
	var count: int = 0
	for event: Dictionary in _events:
		if str(event["tipo"]) == "captura":
			count += 1
	return count


func _connect_signals() -> void:
	_physio.stamina_depleted.connect(_on_depleted)
	_physio.cough_warning.connect(_on_cough_warning)
	_physio.coughed.connect(_on_coughed)
	_physio.respiratory_state_changed.connect(_on_state_changed)
	_physio.stress_band_changed.connect(_on_band_changed)
	_player.inhaler_used.connect(_on_inhaler_used)
	_player.item_use_failed.connect(_on_item_use_failed)
	_world.noise_resolved_for_player.connect(_on_noise)


func _log(kind: String, detail: String) -> void:
	_events.append({"t": snappedf(_t_s, 0.001), "fase": _phase, "tipo": kind, "detalhe": detail})
	_frame_events.append(kind + (":" + detail if not detail.is_empty() else ""))


func _band_name(band: int) -> String:
	var names: Array[String] = ["CALM", "TENSE", "AFRAID", "PANIC"]
	return names[clampi(band, 0, names.size() - 1)]


func _noise_name(category: int) -> String:
	var names: Array[String] = ["FOOTSTEP", "RUNNING", "BREATHING", "WHEEZING", "COUGHING", "DOOR", "OBJECT_IMPACT",
		"MEDICATION", "FURNITURE", "FALL", "VOICE"]
	return names[clampi(category, 0, names.size() - 1)]


func _on_depleted() -> void:
	_log("estamina_esgotou", "stamina=%.2f" % _physio.get_snapshot().stamina)
	_depleted = true
	_pending_capture = "02_esgotamento"


func _on_cough_warning(seconds_until: float) -> void:
	_log("aviso_tosse", "em %.2f s" % seconds_until)


func _on_coughed(suppressed: bool) -> void:
	_log("tosse", "suprimida" if suppressed else "ocorreu")
	if not suppressed and _symptomatic_seen and not _cough_seen:
		_cough_seen = true
		_pending_capture = "04_tosse"


func _on_state_changed(old_state: Enums.RespiratoryState, new_state: Enums.RespiratoryState) -> void:
	var new_name: String = RespiratoryModel.state_name(new_state)
	_log("estado", "%s -> %s" % [RespiratoryModel.state_name(old_state), new_name])
	_state_names.append(new_name)
	if new_state == Enums.RespiratoryState.SYMPTOMATIC and not _symptomatic_seen:
		_symptomatic_seen = true
		_symptomatic_t_s = _t_s
	if new_state == Enums.RespiratoryState.RECOVERING:
		_recovering_seen = true


func _on_band_changed(old_band: Enums.StressBand, new_band: Enums.StressBand) -> void:
	_log("faixa_estresse", "%s -> %s" % [_band_name(int(old_band)), _band_name(int(new_band))])


func _on_inhaler_used() -> void:
	_log("bombinha_usada", "doses_restantes=%d" % _player.get_inventory().get_doses(PlayerRoot.INHALER_ITEM))
	_pending_capture = "05_bombinha"


func _on_item_use_failed(reason: StringName) -> void:
	_log("bombinha_recusada", str(reason))


func _on_noise(event: NoiseEvent, result: PropagationResult) -> void:
	_log("ruido_resolvido", "%s %s %.1f dB perceb=%.1f" % [_noise_name(int(event.category)), str(event.sound_id),
		event.intensity_db, result.perceived_db])


## Um tick de física: entrada roteirizada, captura pendente (se houver) e uma linha de telemetria.
func _frame(move: Vector2, sprint: bool, crouch: bool) -> void:
	var input: MotorInput = MotorInput.new()
	input.move = move
	input.sprint = sprint
	input.crouch_pressed = crouch
	_player.get_motor().set_scripted_input(input)
	await _tree.physics_frame
	_t_s += STEP_S
	_record_row()
	_check_scheduled_capture()
	if _pending_capture != "":
		var capture_name: String = _pending_capture
		_pending_capture = ""
		await _capture(capture_name)


func _check_scheduled_capture() -> void:
	if _symptomatic_seen and not _crisis_captured and _t_s - _symptomatic_t_s >= CRISIS_CAPTURE_DELAY_S:
		_crisis_captured = true
		_pending_capture = "03_crise"


func _set_threat(on: bool) -> void:
	if on:
		var sample: ThreatSample = ThreatSample.new()
		sample.seen_proximity = 1.0
		sample.in_chase = true
		sample.threat_level = 1.0
		_stub.forced = sample
		_log("ameaca", "perseguicao_ligada")
	else:
		_stub.forced = null
		_log("ameaca", "desligada")


## Mantém o jogador na cozinha: vira ao chegar nas bordas (o movimento é sempre para a frente do corpo).
func _turn_at_bounds() -> void:
	if _facing_east and _player.global_position.x > EAST_BOUND_X:
		_player.rotation.y += PI
		_facing_east = false
	elif not _facing_east and _player.global_position.x < WEST_BOUND_X:
		_player.rotation.y -= PI
		_facing_east = true


## Bombinha pela mesma entrada do jogador (tecla use_item: pressionar e soltar), no mesmo quadro.
func _press_use_item() -> void:
	var pressed: InputEventAction = InputEventAction.new()
	pressed.action = &"use_item"
	pressed.pressed = true
	_tree.root.push_input(pressed)
	var released: InputEventAction = InputEventAction.new()
	released.action = &"use_item"
	released.pressed = false
	_tree.root.push_input(released)


func _record_row() -> void:
	var snapshot: PhysiologySnapshot = _physio.get_snapshot()
	var coupling: CouplingFactors = _physio.get_coupling()
	var line: String = "%.3f,%s,%.2f,%.2f,%s,%.4f,%s,%.2f,%.4f,%.4f,%.4f,%d,%.3f,%.3f,%.3f,%.3f,%d,%s" % [
		_t_s, _phase, snapshot.stamina, snapshot.stress, _band_name(int(snapshot.stress_band)),
		snapshot.symptom_severity, RespiratoryModel.state_name(snapshot.respiratory_state),
		snapshot.breathing_rate, snapshot.wheezing_intensity, snapshot.cough_probability,
		snapshot.recovery_progress, snapshot.medication_charges, _fx.get_vignette_alpha(), coupling.steadiness,
		coupling.tremor_amplitude, _player.get_motor().get_exertion(), int(_player.get_motor().get_stance()),
		"|".join(_frame_events)]
	_rows.append(line)
	_frame_events = PackedStringArray()


func _capture(capture_name: String) -> void:
	await RenderingServer.frame_post_draw
	var image: Image = _tree.root.get_texture().get_image()
	var err: int = image.save_png(OUT_DIR + PREFIX + capture_name + ".png")
	_log("captura", "%s err=%d" % [capture_name, err])


func _scenario() -> void:
	# 1. Início parado.
	_phase = "inicio"
	_pending_capture = "01_inicio"
	var start_t: float = _t_s
	while _t_s - start_t < IDLE_S:
		await _frame(Vector2.ZERO, false, false)
	# 2. Correr até esgotar, sob perseguição.
	_phase = "correr"
	_set_threat(true)
	start_t = _t_s
	while not _depleted and _t_s - start_t < TIMEOUT_RUN_S:
		_turn_at_bounds()
		await _frame(Vector2(0.0, 1.0), true, false)
	# 3. Crise: segue se esforçando sob ameaça (sprint pedido sempre; o motor recusa enquanto esgotado, e volta a
	# permitir ao recuperar 25 de estamina) até a primeira tosse ocorrida em SYMPTOMATIC.
	_phase = "crise"
	start_t = _t_s
	while not _cough_seen and _t_s - start_t < TIMEOUT_COUGH_S:
		_turn_at_bounds()
		await _frame(Vector2(0.0, 1.0), true, false)
	# 5. Bombinha depois da tosse.
	_phase = "bombinha"
	start_t = _t_s
	while _t_s - start_t < BEFORE_INHALER_S:
		_turn_at_bounds()
		await _frame(Vector2(0.0, 1.0), false, false)
	_press_use_item()
	start_t = _t_s
	while _t_s - start_t < AFTER_INHALER_S:
		_turn_at_bounds()
		await _frame(Vector2(0.0, 1.0), false, false)
	# 6. Descanso: sem ameaça, agachado (um aperto só) e parado até RECOVERING -> NORMAL.
	_phase = "descanso"
	_set_threat(false)
	start_t = _t_s
	var crouch_once: bool = true
	while not _recovered and _t_s - start_t < TIMEOUT_RECOVERY_S:
		await _frame(Vector2.ZERO, false, crouch_once)
		crouch_once = false
		if _recovering_seen and _physio.get_snapshot().respiratory_state == Enums.RespiratoryState.NORMAL:
			_recovered = true
	_phase = "recuperado"
	_pending_capture = "06_recuperacao"
	start_t = _t_s
	while _t_s - start_t < TAIL_S:
		await _frame(Vector2.ZERO, false, false)


func _write_outputs() -> void:
	var csv: FileAccess = FileAccess.open(OUT_DIR + PREFIX + "telemetria.csv", FileAccess.WRITE)
	csv.store_string("t_s,fase,estamina,estresse,faixa_estresse,severidade,estado,freq_resp_irpm,chiado,prob_tosse," +
		"recuperacao,doses,vinheta,estabilidade,tremor_m,esforco,postura,eventos\n")
	for row: String in _rows:
		csv.store_string(row + "\n")
	csv.close()
	var played: Array[Dictionary] = _audio.played_log.duplicate()
	var log_file: FileAccess = FileAccess.open(OUT_DIR + PREFIX + "played_log.json", FileAccess.WRITE)
	log_file.store_string(JSON.stringify(played, "  "))
	log_file.close()
	var events_file: FileAccess = FileAccess.open(OUT_DIR + PREFIX + "eventos.json", FileAccess.WRITE)
	events_file.store_string(JSON.stringify(_events, "  "))
	events_file.close()

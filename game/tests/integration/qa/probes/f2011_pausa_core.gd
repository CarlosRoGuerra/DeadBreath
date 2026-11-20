extends RefCounted
## Probe F2-011 (QA): pausa no meio da crise com o mesmo mecanismo do menu de pausa (SceneTree.paused = true).
## Corre sob ameaça até o primeiro aviso de tosse, pausa 5 s (300 quadros de física) no meio do aviso, retoma e
## espera 5 s. Mede: fisiologia parada na pausa, played_log sem entradas na pausa, AudioStreamPlayer pausados e
## tosse agendada disparando depois da retomada (frames de aviso -> tosse, excluindo a pausa).
## Saídas: Docs/QA/EVIDENCE/F2-011_pausa_probe.txt, F2-011_pausa_played_log.json, F2-011_pausa_eventos.json.

const PLAYABLE_PATH: String = "res://content/levels/sandbox_playable.tscn"
const OUT_DIR: String = "D:/Dev/DeadBreath/Docs/QA/EVIDENCE/"
const PREFIX: String = "F2-011_pausa_"
const SETTLE_FRAMES: int = 20
const MAX_WARNING_FRAMES: int = 3600
const PAUSE_FRAMES: int = 300
const AFTER_FRAMES: int = 300
const STRESS_TOLERANCE: float = 0.0001

var _tree: SceneTree = null
var _root: Node = null
var _player: PlayerRoot = null
var _physio: PhysiologyComponent = null
var _audio: BreathingAudio = null
var _stub: StubThreatSource = null
var _lines: PackedStringArray = PackedStringArray()
var _events: Array[Dictionary] = []
var _in_pause: bool = false
var _warning_seen: bool = false
var _warning_frame: int = -1
var _cough_frame: int = -1
var _cough_suppressed: bool = false
var _pause_changes: int = 0
var _pause_played_growth: int = 0
var _pause_players_frozen: int = 0
var _pause_players_sounding: int = 0
var _pause_frames_seen: int = 0


func start(tree: SceneTree) -> void:
	_tree = tree
	_run()


func _run() -> void:
	var settings: Node = _tree.root.get_node("Settings")
	settings.set("autosave", false)
	settings.call("set_value", &"master_volume", 0.0)
	var packed: PackedScene = load(PLAYABLE_PATH) as PackedScene
	_root = packed.instantiate()
	_tree.root.add_child(_root)
	for _i: int in SETTLE_FRAMES:
		await _tree.physics_frame
	_player = _find_player(_root)
	_physio = _player.get_physiology()
	_audio = _root.get_node("BreathingAudio") as BreathingAudio
	_stub = _player.get_threat_source() as StubThreatSource
	var sample: ThreatSample = ThreatSample.new()
	sample.seen_proximity = 1.0
	sample.in_chase = true
	sample.threat_level = 1.0
	_stub.forced = sample
	_physio.stamina_depleted.connect(_on_depleted)
	_physio.cough_warning.connect(_on_warning)
	_physio.coughed.connect(_on_coughed)
	_physio.respiratory_state_changed.connect(_on_state)
	_note("inicio: corrida sob ameaça")
	var frames: int = 0
	while not _warning_seen and frames < MAX_WARNING_FRAMES:
		_player.get_motor().set_scripted_input(_sprint_input())
		await _tree.physics_frame
		frames += 1
	_note("aviso de tosse visto (%d quadros de corrida)" % frames)
	var before: Dictionary = _snapshot()
	var played_before: int = _audio.played_log.size()
	_note("ANTES da pausa: %s; played_log=%d" % [_format(before), played_before])
	_tree.paused = true
	_in_pause = true
	_note("PAUSA ligada (tree.paused=true)")
	for _i: int in PAUSE_FRAMES:
		await _tree.physics_frame
		_pause_frames_seen += 1
		var now: Dictionary = _snapshot()
		if _differs(before, now):
			_pause_changes += 1
		_pause_played_growth = maxi(_pause_played_growth, _audio.played_log.size() - played_before)
		for child: Node in _audio.get_children():
			var player: AudioStreamPlayer = child as AudioStreamPlayer
			if player == null:
				continue
			if player.playing and not player.stream_paused:
				_pause_players_sounding += 1
			elif player.playing:
				_pause_players_frozen += 1
	var during: Dictionary = _snapshot()
	_note("DURANTE a pausa (último quadro): %s; played_log=%d" % [_format(during), _audio.played_log.size()])
	_tree.paused = false
	_in_pause = false
	_note("PAUSA desligada (tree.paused=false)")
	for _i: int in AFTER_FRAMES:
		_player.get_motor().set_scripted_input(_sprint_input())
		await _tree.physics_frame
	var after: Dictionary = _snapshot()
	_note("DEPOIS da retomada (5 s): %s; played_log=%d" % [_format(after), _audio.played_log.size()])
	_write()
	print("PAUSA_PROBE fim: quadros_pausa=%d mudancas_fisiologia=%d crescimento_played_log=%d players_pausados=%d players_tocando_na_pausa=%d" % [
		_pause_frames_seen, _pause_changes, _pause_played_growth, _pause_players_frozen, _pause_players_sounding])
	_tree.quit(0)


func _sprint_input() -> MotorInput:
	var input: MotorInput = MotorInput.new()
	input.move = Vector2(0.0, 1.0)
	input.sprint = true
	return input


func _snapshot() -> Dictionary:
	var snap: PhysiologySnapshot = _physio.get_snapshot()
	return {
		"stamina": snap.stamina,
		"stress": snap.stress,
		"severity": snap.symptom_severity,
		"state": RespiratoryModel.state_name(snap.respiratory_state),
		"wheeze": snap.wheezing_intensity,
	}


func _differs(a: Dictionary, b: Dictionary) -> bool:
	if str(a["state"]) != str(b["state"]):
		return true
	for key: String in ["stamina", "stress", "severity", "wheeze"]:
		if absf(float(a[key]) - float(b[key])) > STRESS_TOLERANCE:
			return true
	return false


func _format(snap: Dictionary) -> String:
	return "estamina=%.3f estresse=%.3f severidade=%.4f estado=%s chiado=%.4f" % [
		float(snap["stamina"]), float(snap["stress"]), float(snap["severity"]), str(snap["state"]), float(snap["wheeze"])]


func _note(text: String) -> void:
	var tag: String = "[PAUSA]" if _in_pause else "[ativo]"
	var line: String = "f=%d %s %s" % [Engine.get_physics_frames(), tag, text]
	_lines.append(line)
	print("PAUSA_PROBE " + line)


func _record(kind: String, detail: String) -> void:
	_events.append({"frame": Engine.get_physics_frames(), "pausa": _in_pause, "tipo": kind, "detalhe": detail})
	_note("%s %s" % [kind, detail])


func _on_depleted() -> void:
	_record("estamina_esgotou", "")


func _on_warning(seconds_until: float) -> void:
	if not _warning_seen:
		_warning_seen = true
		_warning_frame = Engine.get_physics_frames()
	_record("aviso_tosse", "em %.2f s" % seconds_until)


func _on_coughed(suppressed: bool) -> void:
	if _cough_frame < 0:
		_cough_frame = Engine.get_physics_frames()
		_cough_suppressed = suppressed
	_record("tosse", "suprimida" if suppressed else "ocorreu")


func _on_state(old_state: Enums.RespiratoryState, new_state: Enums.RespiratoryState) -> void:
	_record("estado", "%s -> %s" % [RespiratoryModel.state_name(old_state), RespiratoryModel.state_name(new_state)])


func _write() -> void:
	var gap: String = "indisponivel (sem tosse)"
	if _cough_frame >= 0:
		gap = "%d quadros de fisica (esperado 90 = 1,5 s), sem contar a pausa" % (_cough_frame - _warning_frame - PAUSE_FRAMES)
	_lines.append("RESUMO: frames aviso=%d; frames tosse=%d; tosse suprimida=%s; intervalo aviso->tosse: %s" % [
		_warning_frame, _cough_frame, str(_cough_suppressed), gap])
	_lines.append("RESUMO: quadros de pausa observados=%d; quadros com fisiologia alterada=%d; crescimento do played_log na pausa=%d; players pausados (stream_paused)=%d; players tocando na pausa=%d" % [
		_pause_frames_seen, _pause_changes, _pause_played_growth, _pause_players_frozen, _pause_players_sounding])
	var file: FileAccess = FileAccess.open(OUT_DIR + PREFIX + "probe.txt", FileAccess.WRITE)
	file.store_string("\n".join(_lines) + "\n")
	file.close()
	var log_file: FileAccess = FileAccess.open(OUT_DIR + PREFIX + "played_log.json", FileAccess.WRITE)
	log_file.store_string(JSON.stringify(_audio.played_log, "  "))
	log_file.close()
	var events_file: FileAccess = FileAccess.open(OUT_DIR + PREFIX + "eventos.json", FileAccess.WRITE)
	events_file.store_string(JSON.stringify(_events, "  "))
	events_file.close()


func _find_player(node: Node) -> PlayerRoot:
	if node is PlayerRoot:
		return node as PlayerRoot
	for child: Node in node.get_children():
		var found: PlayerRoot = _find_player(child)
		if found != null:
			return found
	return null

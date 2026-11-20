extends TestCase
## F2-006b (COMPONENT_CONTRACTS §6.3, DATA_STRUCTURES §6.1): BreathEmitter com snapshots sintéticos.
## Um NoiseEvent por ciclo (BREATHING ou WHEEZING), gasp, aviso de tosse, tosse, som pontual do corpo,
## sem mundo não emite (e avisa uma vez), e to_dict/from_dict preservam a fase do ciclo.
## Autor: Audio Engineer (F2-006b).

const DT: float = 1.0 / 60.0
const TOL: float = 0.0001

var _world: AcousticWorld = null
var _root: Node3D = null
var _emitter: BreathEmitter = null
var _events: Array[NoiseEvent] = []


func before_each() -> void:
	_events = []
	_world = AcousticWorld.new()
	add_child_autofree(_world)
	var ear: Node3D = Node3D.new()
	add_child_autofree(ear)
	_world.set_player_ear(ear)
	_root = Node3D.new()
	add_child_autofree(_root)
	_root.position = Vector3(0.0, 1.0, 0.0)
	_emitter = BreathEmitter.new()
	_root.add_child(_emitter)
	_world.noise_resolved_for_player.connect(_collect)


func after_each() -> void:
	if _world.noise_resolved_for_player.is_connected(_collect):
		_world.noise_resolved_for_player.disconnect(_collect)


func _collect(event: NoiseEvent, _result: PropagationResult) -> void:
	_events.append(event)


func _snap(rate: float, wheeze: float = 0.0, state: Enums.RespiratoryState = Enums.RespiratoryState.NORMAL) -> PhysiologySnapshot:
	var snapshot: PhysiologySnapshot = PhysiologySnapshot.new()
	snapshot.breathing_rate = rate
	snapshot.wheezing_intensity = wheeze
	snapshot.respiratory_state = state
	return snapshot


## Avança o emissor e o mundo por `seconds` em passos de 1/60 s (como o tick de física).
func _run(seconds: float, rate: float, wheeze: float = 0.0, state: Enums.RespiratoryState = Enums.RespiratoryState.NORMAL) -> void:
	var steps: int = int(round(seconds / DT))
	for i in range(steps):
		_emitter.step(DT, _snap(rate, wheeze, state))
		_world.advance(DT)


func test_one_event_per_cycle_at_rest() -> void:
	# 14 rpm = 4,286 s. Em 10 s: eventos em t = 0, 4,3 e 8,6 s.
	_run(10.0, 14.0)
	assert_eq(_events.size(), 3, "três ciclos em 10 s a 14 rpm")
	assert_eq(_emitter.cycles_emitted(), 3, "contador de ciclos do emissor")


func test_cycle_spacing_matches_period() -> void:
	_run(12.0, 14.0)
	var period: float = 60.0 / 14.0
	assert_true(_events.size() >= 2, "há pelo menos dois ciclos")
	if _events.size() >= 2:
		var gap: float = _events[1].timestamp - _events[0].timestamp
		assert_almost_eq(gap, period, DT + TOL, "intervalo entre ciclos = período do snapshot")


func test_breathing_event_fields() -> void:
	_run(DT, 14.0)
	assert_eq(_events.size(), 1, "o primeiro tick já emite o primeiro ciclo")
	var event: NoiseEvent = _events[0]
	assert_eq(event.category, Enums.NoiseCategory.BREATHING, "sem chiado: BREATHING")
	assert_eq(event.source_id, &"player", "fonte do jogador")
	assert_eq(event.sound_id, &"breath_calm", "repouso: família calma")
	assert_almost_eq(event.intensity_db, 20.0, TOL, "intensidade de repouso = 20 dB")
	assert_almost_eq(event.duration, 60.0 / 14.0, TOL, "duração do evento = período do ciclo")
	assert_eq(event.position, Vector3(0.0, 1.0, 0.0), "posição = posição global do emissor")
	assert_true(event.id > 0, "id atribuído pelo mundo")


func test_wheezing_cycles_are_wheezing_category() -> void:
	_run(DT, 30.0, 0.6)
	assert_eq(_events.size(), 1, "um ciclo")
	var event: NoiseEvent = _events[0]
	assert_eq(event.category, Enums.NoiseCategory.WHEEZING, "chiado: WHEEZING")
	assert_eq(event.sound_id, &"breath_labored", "o corpo segue na família; o chiado é camada")
	assert_true(event.intensity_db >= 30.0 + 12.0 * 0.6 - TOL, "intensidade >= lerp(30, 42, 0,6)")


func test_period_follows_snapshot_on_next_cycle() -> void:
	_run(DT, 14.0)
	assert_eq(_events.size(), 1, "primeiro ciclo a 14 rpm")
	# Muda para 40 rpm (1,5 s) e espera o próximo ciclo.
	var steps: int = 0
	while _events.size() < 2 and steps < 600:
		_emitter.step(DT, _snap(40.0))
		_world.advance(DT)
		steps += 1
	assert_eq(_events.size(), 2, "um novo ciclo chega")
	if _events.size() >= 2:
		assert_almost_eq(_events[1].duration, 1.5, TOL, "o ciclo seguinte já usa 1,5 s")
		assert_eq(_events[1].sound_id, &"breath_fast", "1,5 s só cabe a família rápida")


func test_gasp_is_42_db_and_keeps_cycle_phase() -> void:
	_run(1.0, 14.0)
	var phase_before: float = _emitter.cycle_phase_s()
	_emitter.emit_gasp()
	_world.flush()
	assert_eq(_events.size(), 2, "gasp é um evento extra")
	var gasp: NoiseEvent = _events[_events.size() - 1]
	assert_eq(gasp.category, Enums.NoiseCategory.BREATHING, "gasp é BREATHING")
	assert_almost_eq(gasp.intensity_db, 42.0, TOL, "gasp = 42 dB (COMPONENT_CONTRACTS §6.3)")
	assert_eq(gasp.sound_id, &"gasp", "sound_id gasp")
	assert_almost_eq(gasp.duration, 1.2, TOL, "duração do gasp")
	assert_almost_eq(_emitter.cycle_phase_s(), phase_before, TOL, "gasp não reinicia o ciclo")


func test_cough_warning_is_low_and_cough_is_65_db() -> void:
	_emitter.emit_cough_warning()
	_emitter.emit_cough(false)
	_world.flush()
	assert_eq(_events.size(), 2, "aviso e tosse")
	if _events.size() == 2:
		var warning: NoiseEvent = _events[0]
		assert_eq(warning.category, Enums.NoiseCategory.COUGHING, "aviso é COUGHING")
		assert_almost_eq(warning.intensity_db, 32.0, TOL, "aviso = 32 dB (abaixo da tosse)")
		assert_eq(warning.sound_id, &"cough_warning", "sound_id do aviso")
		assert_almost_eq(warning.duration, 1.5, TOL, "aviso dura 1,5 s")
		var cough: NoiseEvent = _events[1]
		assert_almost_eq(cough.intensity_db, 65.0, TOL, "tosse = 65 dB (DATA §2.1)")
		assert_eq(cough.sound_id, &"cough", "sound_id da tosse")


func test_cancelled_cough_makes_no_sound() -> void:
	_emitter.emit_cough(true)
	_world.flush()
	assert_eq(_events.size(), 0, "tosse cancelada no aviso não produz som")


func test_body_sound_with_explicit_category_and_level() -> void:
	_emitter.emit_body_sound(Enums.NoiseCategory.MEDICATION, 38.0, &"inhaler_puff")
	_world.flush()
	assert_eq(_events.size(), 1, "um evento do puff")
	if _events.size() == 1:
		assert_eq(_events[0].category, Enums.NoiseCategory.MEDICATION, "puff é MEDICATION")
		assert_almost_eq(_events[0].intensity_db, 38.0, TOL, "puff = 38 dB (DATA §1.7)")
		assert_eq(_events[0].sound_id, &"inhaler_puff", "sound_id do puff")


func test_without_world_nothing_is_emitted_and_warning_is_logged_once() -> void:
	_world.remove_from_group(AcousticWorld.GROUP)
	var warnings: Array[int] = [0]
	var counter: Callable = func(level: int, category: StringName, _message: String) -> void:
		if level == Log.WARN and category == BreathEmitter.LOG_CATEGORY:
			warnings[0] += 1
	Log.message_logged.connect(counter)
	_run(6.0, 14.0)
	_emitter.emit_gasp()
	_emitter.emit_cough_warning()
	_emitter.emit_cough(false)
	Log.message_logged.disconnect(counter)
	assert_eq(_events.size(), 0, "sem mundo não há evento")
	assert_eq(warnings[0], 1, "um único Log.warn para a falta de mundo")
	assert_eq(_emitter.cycles_emitted(), 0, "ciclos não contam sem mundo")


func test_to_dict_round_trip_keeps_cycle_phase() -> void:
	_run(2.0, 14.0)
	var saved: Dictionary = _emitter.to_dict()
	var copy: BreathEmitter = BreathEmitter.new()
	_root.add_child(copy)
	copy.from_dict(saved)
	assert_almost_eq(copy.next_event_in_s(), _emitter.next_event_in_s(), TOL, "next_event_in_s restaurado")
	assert_almost_eq(copy.cycle_phase_s(), _emitter.cycle_phase_s(), TOL, "cycle_phase_s restaurado")
	for i in range(120):
		_emitter.step(DT, _snap(14.0))
		copy.step(DT, _snap(14.0))
	var a: Dictionary = _emitter.to_dict()
	var b: Dictionary = copy.to_dict()
	assert_almost_eq(float(a["cycle_phase_s"]), float(b["cycle_phase_s"]), TOL, "mesma fase depois de andar iguais")
	assert_almost_eq(float(a["next_event_in_s"]), float(b["next_event_in_s"]), TOL, "mesmo próximo evento")


func test_next_event_is_period_minus_phase() -> void:
	_run(1.0, 14.0)
	var period: float = 60.0 / 14.0
	assert_almost_eq(_emitter.next_event_in_s() + _emitter.cycle_phase_s(), period, TOL, "próximo + fase = período")

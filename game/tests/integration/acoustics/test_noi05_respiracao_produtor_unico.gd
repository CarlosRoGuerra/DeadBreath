extends TestCase
## NOI-05 (TEST_PLAN §2.3; COMPONENT_CONTRACTS §6.3 e §14; F3-002): respiração com produtor único. Com o
## PhysiologyComponent em LABORED por 10 s, cada som de respiração tocado pelo BreathingAudio tem um NoiseEvent
## correspondente, e cada NoiseEvent de respiração do jogador tem um som tocado. Cadeia real: PhysiologyComponent →
## BreathEmitter (único produtor) → AcousticWorld → BreathingAudio. Autor: AI Engineer (F3-002).

const DT: float = 1.0 / 60.0
const WINDOW_S: float = 10.0
const MAX_WARMUP_S: float = 60.0
const MIN_CYCLES: int = 3
const DIR: String = "res://content/data/physiology/"

var _world: AcousticWorld = null
var _physio: PhysiologyComponent = null
var _emitter: BreathEmitter = null
var _audio: BreathingAudio = null
var _events: Array[String] = []
var _states: Array[int] = []


func before_each() -> void:
	_events = []
	_states = []
	_world = AcousticWorld.new()
	add_child_autofree(_world)
	var ear: Node3D = Node3D.new()
	add_child_autofree(ear)
	_world.set_player_ear(ear)
	var root: Node3D = Node3D.new()
	add_child_autofree(root)
	_physio = PhysiologyComponent.new()
	_physio.stamina_config = load(DIR + "stamina_config.tres") as StaminaConfig
	_physio.stress_config = load(DIR + "stress_config.tres") as StressConfig
	_physio.respiratory_config = load(DIR + "respiratory_config.tres") as RespiratoryConfig
	_physio.coupling_config = load(DIR + "coupling_config.tres") as CouplingConfig
	root.add_child(_physio)
	_emitter = BreathEmitter.new()
	root.add_child(_emitter)
	_audio = BreathingAudio.new()
	add_child_autofree(_audio)
	_audio.set_random_seed(7)
	_audio.bind_world(_world)
	_world.noise_resolved_for_player.connect(_collect)


func after_each() -> void:
	if _world.noise_resolved_for_player.is_connected(_collect):
		_world.noise_resolved_for_player.disconnect(_collect)


func _collect(event: NoiseEvent, _result: PropagationResult) -> void:
	if event.source_id != &"player":
		return
	if event.category == Enums.NoiseCategory.BREATHING or event.category == Enums.NoiseCategory.WHEEZING:
		_events.append(String(event.sound_id))


## Um tick da cadeia, na ordem do PlayerRoot: fisiologia, emissor, mundo (-60) e áudio.
func _step(inputs: PhysiologyInputs) -> void:
	_physio.step(DT, inputs)
	_emitter.step(DT, _physio.get_snapshot())
	_world.advance(DT)
	_audio.tick(DT)
	_states.append(int(_physio.get_snapshot().respiratory_state))


func _sprint() -> PhysiologyInputs:
	var inputs: PhysiologyInputs = PhysiologyInputs.new()
	inputs.exertion = 1.0
	inputs.gait = Enums.Gait.SPRINT
	return inputs


func test_noi05_cada_som_de_respiracao_tem_um_evento_e_vice_versa() -> void:
	var sprint: PhysiologyInputs = _sprint()
	var warmup_steps: int = 0
	while _physio.get_snapshot().respiratory_state != Enums.RespiratoryState.LABORED \
			and float(warmup_steps) * DT < MAX_WARMUP_S:
		_step(sprint)
		warmup_steps += 1
	assert_eq(_physio.get_snapshot().respiratory_state, Enums.RespiratoryState.LABORED,
		"o esforço leva o PhysiologyComponent a LABORED")
	if _physio.get_snapshot().respiratory_state != Enums.RespiratoryState.LABORED:
		return

	_events = []
	_states = []
	_audio.played_log.clear()
	var window_steps: int = int(round(WINDOW_S / DT))
	for _step_index: int in range(window_steps):
		_step(sprint)

	var laboured: int = 0
	var worse: int = 0
	for state: int in _states:
		if state == Enums.RespiratoryState.LABORED:
			laboured += 1
		elif state == Enums.RespiratoryState.SYMPTOMATIC:
			worse += 1
	note("NOI-05 janela de %.0f s: %d ticks em LABORED, %d em SYMPTOMATIC (fora de LABORED: %d)" % [
		WINDOW_S, laboured, worse, _states.size() - laboured - worse])
	assert_eq(laboured + worse, _states.size(), "a janela fica em LABORED ou pior (PHY-01)")

	var inhale_ids: Array[String] = []
	var exhale_count: int = 0
	for entry: Dictionary in _audio.played_log:
		var role: String = str(entry.get("role"))
		if role == "inhale":
			inhale_ids.append(str(entry.get("sound_id")))
		elif role == "exhale":
			exhale_count += 1
	note("NOI-05 eventos de respiração do jogador: %d; inspirações tocadas: %d; expirações tocadas: %d" % [
		_events.size(), inhale_ids.size(), exhale_count])
	assert_true(_events.size() >= MIN_CYCLES, "vacuidade: ao menos %d ciclos na janela" % [MIN_CYCLES])
	assert_eq(inhale_ids, _events, "cada respiração tocada tem um NoiseEvent, na mesma ordem, e vice-versa")
	assert_true(exhale_count >= inhale_ids.size() - 1, "cada inspiração tem a sua expiração (a última pode estar em curso)")

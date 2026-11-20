extends TestCase
## Integração da fisiologia (F2-004): queda que fere (altura > fall_injury_height) e não fere (abaixo); sinais do
## PhysiologyComponent (mudança de estado, faixa de estresse, exaustão, aviso e tosse, gasp); carregamento sem sinais;
## config ausente com Log.error e padrões do código. Autor: Physiological Systems Engineer.

const PlayerWorld := preload("res://tests/integration/player/fixtures/player_world.gd")
const Fx := preload("res://tests/unit/physiology/fixtures/physio_fixture.gd")
const SETTLE_FRAMES: int = 6
const LANDING_WAIT_FRAMES: int = 90
const DT: float = 1.0 / 60.0
const TOLERANCE: float = 0.01

var _previous: Dictionary = {}
var _warnings: int = 0
var _coughs: int = 0
var _cancelled: int = 0
var _gasps: int = 0
var _bands: int = 0
var _states: int = 0
var _depleted: int = 0
var _errors: PackedStringArray = PackedStringArray()


func before_all() -> void:
	Settings.autosave = false


func after_all() -> void:
	Settings.autosave = true


func before_each() -> void:
	_previous = PlayerWorld.override_settings({&"motion_reduction": 0.0, &"mouse_sensitivity": 0.12, &"invert_y": false, &"fov": 75.0})
	_warnings = 0
	_coughs = 0
	_cancelled = 0
	_gasps = 0
	_bands = 0
	_states = 0
	_depleted = 0
	_errors = PackedStringArray()


func after_each() -> void:
	PlayerWorld.restore_settings(_previous)
	if Log.message_logged.is_connected(_on_logged):
		Log.message_logged.disconnect(_on_logged)


func _on_logged(level: int, category: StringName, message: String) -> void:
	if level == Log.ERROR and category == &"physiology":
		_errors.append(message)


## Queda de uma altura dada, em mundo isolado (cada queda tem o seu espaço de física). Devolve o estresse depois do pouso.
func _fall_stress(height: float) -> float:
	var root: Node3D = add_isolated_world()
	PlayerWorld.add_box(root, Vector3(0.0, -0.5, -5.0), Vector3(6.0, 1.0, 16.0), &"wood")
	var player: PlayerRoot = PlayerWorld.spawn_player(root, Vector3(0.0, height, 0.0))
	var physiology: PhysiologyComponent = player.get_physiology()
	await wait_physics_frames(LANDING_WAIT_FRAMES)
	var stress: float = physiology.get_snapshot().stress
	await release_and_flush(player)
	return stress


func test_queda_de_3_m_fere_e_queda_de_1_m_nao() -> void:
	var from_three: float = await _fall_stress(3.0)
	var from_one: float = await _fall_stress(1.0)
	note("estresse depois da queda de 3 m: %.3f; depois da queda de 1 m: %.3f (pico de ferimento 20)" % [from_three, from_one])
	assert_almost_eq(from_three, 20.0, 1.0, "queda de 3 m (acima de 2,5 m) dá pico de ferimento de 20")
	assert_almost_eq(from_one, 0.0, 0.01, "queda de 1 m (abaixo de 2,5 m) não fere")


func test_sinais_do_componente_acompanham_os_limiares() -> void:
	var component: PhysiologyComponent = _component_with_configs()
	component.rng_seed = 9001
	add_child_autofree(component)
	component.respiratory_state_changed.connect(_on_state)
	component.stress_band_changed.connect(_on_band)
	component.stamina_depleted.connect(_on_depleted)
	component.cough_warning.connect(_on_warning)
	component.coughed.connect(_on_coughed)
	component.startle_gasp.connect(_on_gasp)
	var sprint: PhysiologyInputs = Fx.inputs(1.0, Enums.Gait.SPRINT, false, Fx.threat(1.0, 0.0, false))
	for _i: int in 60 * 25:
		component.step(DT, sprint)
	assert_true(_states >= 2, "a mudança de estado respiratório dispara sinal (obtido %d)" % _states)
	assert_true(_bands >= 3, "a passagem por faixas de estresse dispara sinal (obtido %d)" % _bands)
	assert_eq(_depleted, 1, "esgotar a stamina dispara stamina_depleted uma vez")
	assert_true(_warnings >= 1, "o aviso de tosse dispara cough_warning")
	assert_true(_coughs + _cancelled >= 1, "a tosse, ou o cancelamento dela, dispara coughed")
	note("sinais em 25 s de sprint sob ameaça: estados %d, faixas %d, avisos %d, tosses %d, canceladas %d"
		% [_states, _bands, _warnings, _coughs, _cancelled])


## Gasp (DATA §1.3): pico ≥ 15 com estresse ≥ 50 antes do pico. Componente novo, sem ameaça prévia.
func test_gasp_de_susto_exige_pico_e_estresse_previo() -> void:
	var component: PhysiologyComponent = _component_with_configs()
	component.rng_seed = 12
	add_child_autofree(component)
	component.startle_gasp.connect(_on_gasp)
	component.add_startle(20.0)
	component.add_startle(25.0)
	component.add_startle(25.0)
	assert_eq(_gasps, 0, "estresse antes de cada pico abaixo de 50: nenhum gasp")
	component.add_startle(25.0)
	assert_eq(_gasps, 1, "pico de 25 com estresse 70 antes (≥ 50): um gasp")
	component.add_startle(10.0)
	assert_eq(_gasps, 1, "pico de 10 (< 15) não dá gasp, mesmo com estresse 95 antes")


func test_carregar_estado_nao_emite_sinais() -> void:
	var source: PhysiologyComponent = _component_with_configs()
	source.rng_seed = 42
	add_child_autofree(source)
	source.step(DT, Fx.inputs(1.0, Enums.Gait.SPRINT, false, Fx.threat(1.0, 0.0, false)))
	for _i: int in 60 * 20:
		source.step(DT, Fx.inputs(1.0, Enums.Gait.SPRINT, false, Fx.threat(1.0, 0.0, false)))
	var saved: Dictionary = source.to_dict()
	var target: PhysiologyComponent = _component_with_configs()
	target.rng_seed = 7
	add_child_autofree(target)
	target.respiratory_state_changed.connect(_on_state)
	target.stress_band_changed.connect(_on_band)
	target.stamina_depleted.connect(_on_depleted)
	target.from_dict(saved)
	assert_eq(_states + _bands + _depleted, 0, "from_dict não emite sinais (o estado carregado não é um acontecimento)")
	assert_true(Fx.same_state(saved, target.to_dict()), "from_dict(to_dict()) reproduz o estado do componente, RNG incluso")


func test_config_ausente_registra_erro_e_usa_padroes() -> void:
	Log.message_logged.connect(_on_logged)
	var component: PhysiologyComponent = PhysiologyComponent.new()
	add_child_autofree(component)
	var snapshot: PhysiologySnapshot = component.get_snapshot()
	assert_almost_eq(snapshot.stamina, 100.0, TOLERANCE, "sem config, a stamina começa com o padrão de 100")
	assert_not_null(component.stamina_config, "o componente cria a config padrão de stamina")
	assert_not_null(component.coupling_config, "o componente cria a config padrão de acoplamento")
	assert_eq(_errors.size(), 4, "um Log.error por config ausente (obtido %d)" % _errors.size())


func test_medicacao_nula_registra_erro_e_nao_aplica() -> void:
	Log.message_logged.connect(_on_logged)
	var component: PhysiologyComponent = _component_with_configs()
	component.rng_seed = 3
	add_child_autofree(component)
	assert_false(component.apply_medication(null), "sem perfil, nada é aplicado")
	assert_eq(_errors.size(), 1, "um Log.error para o perfil ausente")


## Componente com as quatro configs de produção (sem Log.error de config ausente).
func _component_with_configs() -> PhysiologyComponent:
	var component: PhysiologyComponent = PhysiologyComponent.new()
	component.stamina_config = load(Fx.DIR + "stamina_config.tres") as StaminaConfig
	component.stress_config = load(Fx.DIR + "stress_config.tres") as StressConfig
	component.respiratory_config = load(Fx.DIR + "respiratory_config.tres") as RespiratoryConfig
	component.coupling_config = load(Fx.DIR + "coupling_config.tres") as CouplingConfig
	return component


func _on_state(_old: Enums.RespiratoryState, _new: Enums.RespiratoryState) -> void:
	_states += 1


func _on_band(_old: Enums.StressBand, _new: Enums.StressBand) -> void:
	_bands += 1


func _on_depleted() -> void:
	_depleted += 1


func _on_warning(_seconds: float) -> void:
	_warnings += 1


func _on_coughed(suppressed: bool) -> void:
	if suppressed:
		_cancelled += 1
	else:
		_coughs += 1


func _on_gasp() -> void:
	_gasps += 1

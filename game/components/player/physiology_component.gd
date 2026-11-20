class_name PhysiologyComponent
extends Node
## PhysiologyComponent (L2, COMPONENT_CONTRACTS §4.1 e §4.3, F2-004): compõe StaminaModel, StressModel,
## RespiratoryModel e PhysiologyCoupling. É o dono do RNG da fisiologia (rng_seed; o estado vai no to_dict).
## Não conhece o motor, a interação nem outros componentes do jogador (PLR-INV-1): recebe PhysiologyInputs
## do PlayerRoot, que também lê get_coupling() e aplica os limites no tick seguinte.
## Sem config: usa os padrões do código e registra Log.error (mesma regra do PlayerMotor).
## Os modelos são criados no primeiro uso (_ready ou primeira chamada), então funciona fora da árvore nos testes.

signal respiratory_state_changed(old: Enums.RespiratoryState, new: Enums.RespiratoryState)
signal cough_warning(seconds_until: float)
## suppressed = false: a tosse aconteceu. suppressed = true: a tosse foi cancelada no aviso (severidade caiu abaixo de 0,55).
signal coughed(suppressed: bool)
signal stamina_depleted()
signal stamina_recovered()
signal stress_band_changed(old: Enums.StressBand, new: Enums.StressBand)
## Gasp de susto: BreathEmitter (F2-006b) o transforma em respiração de 42 dB.
signal startle_gasp()

const LOG_CATEGORY: StringName = &"physiology"

@export var stamina_config: StaminaConfig
@export var stress_config: StressConfig
@export var respiratory_config: RespiratoryConfig
@export var coupling_config: CouplingConfig
## 0 = semente aleatória no primeiro uso; testes fixam um valor antes do primeiro tick.
@export var rng_seed: int = 0

var _initialized: bool = false
var _stamina: StaminaModel = null
var _stress: StressModel = null
var _resp: RespiratoryModel = null
var _rng: RandomNumberGenerator = null
var _coupling: CouplingFactors = null
var _medication_charges: int = 0
var _last_state: Enums.RespiratoryState = Enums.RespiratoryState.NORMAL
var _last_band: Enums.StressBand = Enums.StressBand.CALM
var _last_exhausted: bool = false


func _ready() -> void:
	_ensure_ready()


## Um tick da fisiologia. Os limites de coupling valem a partir do próximo tick (COMPONENT_CONTRACTS §1).
func step(dt: float, inputs: PhysiologyInputs) -> void:
	_ensure_ready()
	var sample: PhysiologyInputs = inputs if inputs != null else PhysiologyInputs.new()
	_stamina.tick(dt, sample, _coupling)
	_stress.tick(dt, sample)
	_resp.tick(dt, sample, _stress.value)
	_refresh_coupling()
	_sync_signals()
	_emit_cough_events()


func get_snapshot() -> PhysiologySnapshot:
	_ensure_ready()
	var snapshot: PhysiologySnapshot = PhysiologySnapshot.new()
	snapshot.stamina = _stamina.value
	snapshot.stress = _stress.value
	snapshot.stress_band = _stress.get_band()
	snapshot.symptom_severity = _resp.symptom_severity
	snapshot.breathing_rate = _resp.breathing_rate
	snapshot.wheezing_intensity = _resp.wheezing_intensity
	snapshot.cough_probability = _resp.cough_probability
	snapshot.recovery_progress = _resp.recovery_progress
	snapshot.respiratory_state = _resp.state
	snapshot.medication_charges = _medication_charges
	snapshot.medication_relief_remaining = _resp.relief_remaining
	return snapshot


## Acoplamento do último tick (ou do estado atual, após add_startle, add_injury ou from_dict).
func get_coupling() -> CouplingFactors:
	_ensure_ready()
	return _coupling


func get_stress_config() -> StressConfig:
	_ensure_ready()
	return stress_config


## Bombinha: false (e nada muda) em cooldown. As cargas são do inventário (F2-005), não daqui.
func apply_medication(profile: MedicationProfile) -> bool:
	_ensure_ready()
	if profile == null:
		Log.error(LOG_CATEGORY, "apply_medication sem MedicationProfile; nada aplicado")
		return false
	return _resp.apply_medication(profile)


## Cargas de medicação, informadas pelo inventário (leitura do snapshot).
func set_medication_charges(count: int) -> void:
	_medication_charges = maxi(0, count)


## Susto: pico de estresse. Gasp (startle_gasp) se o pico for >= gasp_min_spike com estresse >= gasp_min_stress antes do pico.
func add_startle(amount: float) -> void:
	_ensure_ready()
	var stress_before: float = _stress.value
	_stress.add_spike(amount)
	if amount >= stress_config.gasp_min_spike and stress_before >= stress_config.gasp_min_stress:
		startle_gasp.emit()
	_refresh_coupling()
	_sync_signals()


## Ferimento (queda, captura): pico de estresse. Não há sistema de vida (DATA §1.3).
func add_injury(amount: float) -> void:
	_ensure_ready()
	_stress.add_spike(amount)
	_refresh_coupling()
	_sync_signals()


func to_dict() -> Dictionary:
	_ensure_ready()
	return {
		"stamina": _stamina.to_dict(),
		"stress": _stress.to_dict(),
		"respiratory": _resp.to_dict(),
		"rng_state": str(_rng.state),
	}


## Restaura modelos e RNG sem emitir sinais (o estado carregado não é um acontecimento).
func from_dict(data: Dictionary) -> void:
	_ensure_ready()
	var stamina_data: Dictionary = data["stamina"]
	var stress_data: Dictionary = data["stress"]
	var resp_data: Dictionary = data["respiratory"]
	_stamina.from_dict(stamina_data)
	_stress.from_dict(stress_data)
	_resp.from_dict(resp_data)
	_rng.state = int(str(data["rng_state"]))
	_refresh_coupling()
	_sync_silent()


func _ensure_ready() -> void:
	if _initialized:
		return
	_initialized = true
	if stamina_config == null:
		Log.error(LOG_CATEGORY, "StaminaConfig ausente; usando os padrões do código")
		stamina_config = StaminaConfig.new()
	if stress_config == null:
		Log.error(LOG_CATEGORY, "StressConfig ausente; usando os padrões do código")
		stress_config = StressConfig.new()
	if respiratory_config == null:
		Log.error(LOG_CATEGORY, "RespiratoryConfig ausente; usando os padrões do código")
		respiratory_config = RespiratoryConfig.new()
	if coupling_config == null:
		Log.error(LOG_CATEGORY, "CouplingConfig ausente; usando os padrões do código")
		coupling_config = CouplingConfig.new()
	_rng = RandomNumberGenerator.new()
	if rng_seed == 0:
		_rng.randomize()
	else:
		_rng.seed = rng_seed
	_stamina = StaminaModel.new(stamina_config)
	_stress = StressModel.new(stress_config)
	_resp = RespiratoryModel.new(respiratory_config, _rng)
	_refresh_coupling()
	_sync_silent()


func _refresh_coupling() -> void:
	_coupling = PhysiologyCoupling.compute(_stamina, _stress, _resp, coupling_config)


## Emite a mudança de estado respiratório, de faixa de estresse e de exaustão desde a última sincronização.
func _sync_signals() -> void:
	var state_now: Enums.RespiratoryState = _resp.state
	if state_now != _last_state:
		respiratory_state_changed.emit(_last_state, state_now)
		_last_state = state_now
	var band_now: Enums.StressBand = _stress.get_band()
	if band_now != _last_band:
		stress_band_changed.emit(_last_band, band_now)
		_last_band = band_now
	var exhausted_now: bool = _stamina.exhausted
	if exhausted_now != _last_exhausted:
		_last_exhausted = exhausted_now
		if exhausted_now:
			stamina_depleted.emit()
		else:
			stamina_recovered.emit()


func _sync_silent() -> void:
	_last_state = _resp.state
	_last_band = _stress.get_band()
	_last_exhausted = _stamina.exhausted


func _emit_cough_events() -> void:
	if not _resp.has_events():
		return
	for event: int in _resp.take_events():
		if event == RespiratoryModel.CoughEvent.WARNING:
			cough_warning.emit(respiratory_config.cough_warning_time_s)
		elif event == RespiratoryModel.CoughEvent.COUGH:
			coughed.emit(false)
		else:
			coughed.emit(true)

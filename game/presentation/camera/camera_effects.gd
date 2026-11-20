class_name CameraEffects
extends Node
## CameraEffects (L3, F2-007; COMPONENT_CONTRACTS §14): balanço respiratório, tremor, solavanco da tosse e vinheta
## discreta na crise. Lê o jogador (grupo "player", ou set_player) e observa a fisiologia; não altera estado de jogo.
## Escalas (DATA_STRUCTURES §10): motion_reduction reduz o balanço e o solavanco; tremor_reduction reduz o tremor;
## effects_intensity multiplica tudo, linearmente (ACC-02). Com as reduções em 1, a amplitude é zero (ACC-01).
## Escreve só a posição e a rotação LOCAIS da câmera (o motor mexe na cabeça, o pai da câmera).

const BASE_SWAY_M: float = 0.004
const SWAY_PER_SEVERITY_M: float = 0.010
const TREMOR_MAX_M: float = 0.004
const ROLL_PER_TREMOR_M: float = 0.5
const JOLT_DEG: float = 1.5
const JOLT_TIME_S: float = 0.35
const VIGNETTE_START_SEVERITY: float = 0.6
const VIGNETTE_MAX_ALPHA: float = 0.35
const TREMOR_FREQ_A: float = 17.0
const TREMOR_FREQ_B: float = 23.0
const TREMOR_FREQ_C: float = 31.0
const SECONDS_PER_MINUTE: float = 60.0
const VIGNETTE_LAYER: int = 50

var _player: PlayerRoot = null
var _camera: Camera3D = null
var _physiology: PhysiologyComponent = null
var _viewmodel: Viewmodel = null
var _indicator: RespiratoryIndicator = null
var _vignette_rect: ColorRect = null
var _time: float = 0.0
var _jolt_remaining: float = 0.0


## Escalas puras (testáveis sem cena). Amplitudes em metros; intensidade e reduções vêm do Settings (0..1).
static func sway_amplitude_m(severity: float, motion_reduction: float, intensity: float) -> float:
	var base: float = BASE_SWAY_M + SWAY_PER_SEVERITY_M * clampf(severity, 0.0, 1.0)
	return base * (1.0 - clampf(motion_reduction, 0.0, 1.0)) * clampf(intensity, 0.0, 1.0)


static func tremor_amplitude_m(tremor: float, tremor_reduction: float, intensity: float) -> float:
	return TREMOR_MAX_M * clampf(tremor, 0.0, 1.0) * (1.0 - clampf(tremor_reduction, 0.0, 1.0)) * clampf(intensity, 0.0, 1.0)


## Solavanco da tosse em graus (é movimento de câmera: segue motion_reduction).
static func jolt_amplitude_deg(motion_reduction: float, intensity: float) -> float:
	return JOLT_DEG * (1.0 - clampf(motion_reduction, 0.0, 1.0)) * clampf(intensity, 0.0, 1.0)


## Vinheta (alpha 0..1): cresce acima de VIGNETTE_START_SEVERITY e segue effects_intensity.
static func vignette_alpha(severity: float, intensity: float) -> float:
	var excess: float = clampf((clampf(severity, 0.0, 1.0) - VIGNETTE_START_SEVERITY) / (1.0 - VIGNETTE_START_SEVERITY), 0.0, 1.0)
	return VIGNETTE_MAX_ALPHA * excess * clampf(intensity, 0.0, 1.0)


## Frequência do balanço em Hz a partir da frequência respiratória em respirações por minuto.
static func breath_frequency_hz(breathing_rate_per_min: float) -> float:
	return maxf(breathing_rate_per_min, 1.0) / SECONDS_PER_MINUTE


func _ready() -> void:
	_vignette_rect = _build_vignette()
	_indicator = RespiratoryIndicator.new()
	add_child(_indicator)
	if _physiology != null:
		_indicator.bind(_physiology)


func _exit_tree() -> void:
	if _physiology != null and _physiology.coughed.is_connected(_on_coughed):
		_physiology.coughed.disconnect(_on_coughed)


## Liga os efeitos a um jogador (sem set_player, o nó procura o primeiro no grupo "player").
func set_player(player: PlayerRoot) -> void:
	if player == null or player == _player:
		return
	_player = player
	_camera = player.get_camera()
	_physiology = player.get_physiology()
	_physiology.coughed.connect(_on_coughed)
	if _viewmodel == null:
		_viewmodel = Viewmodel.new()
		_camera.add_child(_viewmodel)
	player.inhaler_used.connect(_on_inhaler_used)
	if _indicator != null:
		_indicator.bind(_physiology)


func get_player() -> PlayerRoot:
	return _player


func get_viewmodel() -> Viewmodel:
	return _viewmodel


func get_indicator() -> RespiratoryIndicator:
	return _indicator


func get_vignette_alpha() -> float:
	if _vignette_rect == null:
		return 0.0
	return _vignette_rect.color.a


func _process(delta: float) -> void:
	_ensure_bound()
	if _player == null or _camera == null:
		return
	var snapshot: PhysiologySnapshot = _physiology.get_snapshot()
	var coupling: CouplingFactors = _physiology.get_coupling()
	var motion_reduction: float = Settings.get_float(&"motion_reduction")
	var tremor_reduction: float = Settings.get_float(&"tremor_reduction")
	var intensity: float = Settings.get_float(&"effects_intensity")
	_time += delta
	var sway: float = sway_amplitude_m(snapshot.symptom_severity, motion_reduction, intensity) \
		* sin(TAU * breath_frequency_hz(snapshot.breathing_rate) * _time)
	var tremor: float = tremor_amplitude_m(coupling.tremor_amplitude, tremor_reduction, intensity)
	var tremor_x: float = tremor * (sin(_time * TREMOR_FREQ_A) + 0.5 * sin(_time * TREMOR_FREQ_B)) / 1.5
	var tremor_y: float = tremor * cos(_time * TREMOR_FREQ_C)
	var jolt_pitch: float = 0.0
	if _jolt_remaining > 0.0:
		_jolt_remaining = maxf(_jolt_remaining - delta, 0.0)
		var progress: float = 1.0 - _jolt_remaining / JOLT_TIME_S
		jolt_pitch = deg_to_rad(jolt_amplitude_deg(motion_reduction, intensity)) * sin(PI * clampf(progress, 0.0, 1.0))
	_camera.position = Vector3(tremor_x, sway + tremor_y, 0.0)
	_camera.rotation = Vector3(jolt_pitch, 0.0, tremor_x * ROLL_PER_TREMOR_M)
	_vignette_rect.color.a = vignette_alpha(snapshot.symptom_severity, intensity)


func _ensure_bound() -> void:
	if _player != null and is_instance_valid(_player):
		return
	if not is_inside_tree():
		return
	var found: PlayerRoot = get_tree().get_first_node_in_group(PlayerRoot.PLAYER_GROUP) as PlayerRoot
	if found != null:
		set_player(found)


func _on_coughed(suppressed: bool) -> void:
	if suppressed:
		return
	_jolt_remaining = JOLT_TIME_S
	if _viewmodel != null:
		_viewmodel.play_cough()


func _on_inhaler_used() -> void:
	if _viewmodel != null:
		_viewmodel.play_use()


func _build_vignette() -> ColorRect:
	var layer: CanvasLayer = CanvasLayer.new()
	layer.layer = VIGNETTE_LAYER
	add_child(layer)
	var rect: ColorRect = ColorRect.new()
	rect.color = Color(0.0, 0.0, 0.0, 0.0)
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(rect)
	return rect

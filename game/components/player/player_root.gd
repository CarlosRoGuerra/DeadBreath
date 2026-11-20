class_name PlayerRoot
extends CharacterBody3D
## PlayerRoot (L2, Gameplay Engineer, F1-006/F1-007; fisiologia na F2-004): mediador do jogador (COMPONENT_CONTRACTS §1).
## É o único script que conhece os componentes do jogador. Monta o InteractionContext (F1-007) e os PhysiologyInputs (F2-004).
## Não trata a tecla pause: o menu de pausa (presentation/ui) pausa a árvore e chama on_menu_resumed().
## Ordem do tick: process_physics_priority = -90 (SYSTEM_ARCHITECTURE §6; COMPONENT_CONTRACTS §1):
##   motor.step → inputs → physiology.step → apply_limits(physiology.get_coupling()) → interaction.step(steadiness)

const PHYSICS_PRIORITY: int = -90
const HEADLESS_DISPLAY_NAME: String = "headless"
## Grupo usado pelo menu de pausa para devolver o controle ao jogador (captura do mouse).
const PLAYER_GROUP: StringName = &"player"

@onready var _motor: PlayerMotor = $PlayerMotor
@onready var _interaction: InteractionComponent = $InteractionComponent
@onready var _physiology: PhysiologyComponent = $PhysiologyComponent
@onready var _head: Node3D = $Head
@onready var _camera: Camera3D = $Head/Camera3D

var _context: InteractionContext = null
var _mouse_capture_requested: bool = false
## Fonte da ameaça percebida (F2: stub; F4: PlayerThreatMonitor). ThreatSource é RefCounted (ver threat_source.gd).
var _threat_source: ThreatSource = StubThreatSource.new()
var _physiology_inputs: PhysiologyInputs = PhysiologyInputs.new()


func _ready() -> void:
	process_physics_priority = PHYSICS_PRIORITY
	add_to_group(PLAYER_GROUP)
	_motor.setup(self, _head)
	_interaction.setup(_camera, self)
	_motor.landed.connect(_on_motor_landed)
	_context = InteractionContext.new()
	_context.actor = self
	apply_limits(_physiology.get_coupling())
	_camera.fov = Settings.get_float(&"fov")
	Settings.changed.connect(_on_settings_changed)
	set_mouse_captured(true)


func _exit_tree() -> void:
	if Settings.changed.is_connected(_on_settings_changed):
		Settings.changed.disconnect(_on_settings_changed)


func _physics_process(delta: float) -> void:
	_motor.step(delta)
	var inputs: PhysiologyInputs = _build_physiology_inputs()
	_physiology.step(delta, inputs)
	# Limites do acoplamento deste tick: o motor os usa a partir do próximo tick (COMPONENT_CONTRACTS §1).
	var coupling: CouplingFactors = _physiology.get_coupling()
	apply_limits(coupling)
	_context.steadiness = coupling.steadiness
	_context.is_hidden = inputs.is_hidden
	_interaction.step(delta, _context)


## Repassa os limites da fisiologia ao motor (só reduzem; MOT-INV-3).
func apply_limits(coupling: CouplingFactors) -> void:
	_motor.apply_limits(coupling)


func get_motor() -> PlayerMotor:
	return _motor


func get_interaction() -> InteractionComponent:
	return _interaction


func get_physiology() -> PhysiologyComponent:
	return _physiology


func get_threat_source() -> ThreatSource:
	return _threat_source


## Troca a fonte da ameaça (F4: PlayerThreatMonitor). null volta ao StubThreatSource com ameaça zero.
func set_threat_source(source: ThreatSource) -> void:
	_threat_source = source if source != null else StubThreatSource.new()


func get_camera() -> Camera3D:
	return _camera


## Captura ou solta o mouse. No headless não altera o modo, mas o pedido fica registrado.
func set_mouse_captured(captured: bool) -> void:
	_mouse_capture_requested = captured
	if _is_headless():
		return
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if captured else Input.MOUSE_MODE_VISIBLE


func is_mouse_capture_requested() -> bool:
	return _mouse_capture_requested


## Chamado pelo menu de pausa (grupo "player") ao continuar o jogo: recaptura o mouse.
func on_menu_resumed() -> void:
	set_mouse_captured(true)


## Teleporte (comando de debug da F1-008). O destino é escolhido por quem chama.
func teleport_to(position: Vector3) -> void:
	global_position = position
	velocity = Vector3.ZERO
	_motor.notify_teleported()


## Noclip (comando de debug da F1-008).
func set_noclip(enabled: bool) -> void:
	_motor.set_noclip(enabled)


func is_noclip() -> bool:
	return _motor.is_noclip()


func _on_settings_changed(key: StringName) -> void:
	if key == &"fov":
		_camera.fov = Settings.get_float(&"fov")


## Entradas da fisiologia deste tick. Parado e agachado ou rastejando conta como repouso (escondido também, F5).
func _build_physiology_inputs() -> PhysiologyInputs:
	# Um só objeto, reaproveitado a cada tick (a fisiologia não o guarda).
	var inputs: PhysiologyInputs = _physiology_inputs
	inputs.exertion = _motor.get_exertion()
	inputs.gait = _motor.get_gait()
	inputs.threat = _threat_source.sample()
	inputs.is_hidden = _context.is_hidden
	inputs.in_safe_zone = false
	var still_low: bool = inputs.gait == Enums.Gait.IDLE and _motor.get_stance() != Enums.Stance.STAND
	inputs.is_resting = still_low or inputs.is_hidden
	return inputs


## Queda: o impacto só fere se a altura de queda (v²/2g) passar de fall_injury_height (DATA §1.3).
func _on_motor_landed(fall_speed: float) -> void:
	var gravity: float = _motor.config.gravity
	var fall_height: float = fall_speed * fall_speed / (2.0 * gravity)
	if fall_height > _motor.config.fall_injury_height:
		_physiology.add_injury(_physiology.get_stress_config().injury_spike)


func _is_headless() -> bool:
	return DisplayServer.get_name() == HEADLESS_DISPLAY_NAME

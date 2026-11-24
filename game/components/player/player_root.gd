class_name PlayerRoot
extends CharacterBody3D
## PlayerRoot (L2, Gameplay Engineer, F1-006/F1-007; fisiologia na F2-004): mediador do jogador (COMPONENT_CONTRACTS §1).
## É o único script que conhece os componentes do jogador. Monta o InteractionContext (F1-007) e os PhysiologyInputs (F2-004).
## Não trata a tecla pause: o menu de pausa (presentation/ui) pausa a árvore e chama on_menu_resumed().
## Ordem do tick: process_physics_priority = -90 (SYSTEM_ARCHITECTURE §6; COMPONENT_CONTRACTS §1):
##   motor.step → inputs → physiology.step → apply_limits(physiology.get_coupling()) → breath_emitter.step(snapshot)
##   → interaction.step(steadiness). O BreathEmitter é o produtor único dos sons do corpo (F2-006b, §6.3).
## Uso da bombinha (F2-005, tecla use_item / Q): try_use_inhaler() consome uma dose do inventário e aplica o efeito na
## fisiologia. Os sinais item_use_failed e inhaler_used são para a apresentação (viewmodel, UI e som).
## Sons do próprio jogador (F3-004): passos e corrida (motor.footstep → FootNoise), queda (landed, acima de
## fall_noise.min_fall_speed_mps). Arremessáveis: a mão (PlayerHold), tecla throw.
## Ameaça e susto (F4-009, D4-01): o PlayerThreatMonitor é a fonte da ameaça (get_threat_source) e recebe os sons do
## AcousticWorld (register_player_listener); o susto dele (startled) vai a physiology.add_startle. O monitor é atualizado
## no tick, antes das entradas da fisiologia. Sonda de luz e PerceivableTarget (F4-009): a postura vem do motor.
## Captura (F4-005, D4-04): ao EventBus.player_captured, a entrada do jogador é travada (set_input_locked).

const PHYSICS_PRIORITY: int = -90
const NOISE_LEVELS: NoiseLevels = preload("res://content/data/acoustics/noise_levels.tres")
const FALL_SOUND: StringName = &"fall_body"
const HEADLESS_DISPLAY_NAME: String = "headless"
## Grupo usado pelo menu de pausa para devolver o controle ao jogador (captura do mouse).
const PLAYER_GROUP: StringName = &"player"
const INHALER_ITEM: StringName = &"inhaler"
## Altura do marcador do tronco em relação à altura dos olhos (o tronco fica a meia altura da cabeça).
const TORSO_HEIGHT_RATIO: float = 0.5

## Uso da bombinha falhou: &"no_doses" (sem cargas) ou &"cooldown" (em cooldown; nada é consumido).
signal item_use_failed(reason: StringName)
## Bombinha usada com sucesso (uma dose consumida). A apresentação e o som se ligam aqui.
signal inhaler_used()

## Perfil da bombinha (DATA_STRUCTURES §1.7). Vem da cena do jogador.
@export var inhaler_profile: MedicationProfile
## Limiar de queda que faz ruído (F3-004). Sem valor na cena, o padrão do Resource.
@export var fall_noise: FallNoiseConfig = preload("res://content/data/player/fall_noise.tres")

@onready var _motor: PlayerMotor = $PlayerMotor
@onready var _interaction: InteractionComponent = $InteractionComponent
@onready var _physiology: PhysiologyComponent = $PhysiologyComponent
@onready var _inventory: InventoryComponent = $InventoryComponent
@onready var _breath: BreathEmitter = $Head/BreathEmitter
@onready var _head: Node3D = $Head
@onready var _camera: Camera3D = $Head/Camera3D
@onready var _foot_noise: NoiseEmitter = $FootNoise
@onready var _hold: PlayerHold = $PlayerHold
@onready var _threat_monitor: PlayerThreatMonitor = $PlayerThreatMonitor
@onready var _light_probe: LightExposureProbe = $LightExposureProbe
@onready var _perceivable: PerceivableTarget = $PerceivableTarget
@onready var _sample_head: Marker3D = $PerceivableTarget/SampleHead
@onready var _sample_torso: Marker3D = $PerceivableTarget/SampleTorso
@onready var _sample_feet: Marker3D = $PerceivableTarget/SampleFeet

var _bound_world: AcousticWorld = null
var _context: InteractionContext = null
var _mouse_capture_requested: bool = false
## Entrada do jogador travada (captura, F4-005). O motor recebe a mesma trava.
var _input_locked: bool = false
## Fonte da ameaça percebida. O _ready troca este valor pela fonte do PlayerThreatMonitor (F4-009, D4-01).
## ThreatSource é RefCounted (threat_source.gd).
var _threat_source: ThreatSource = StubThreatSource.new()
var _physiology_inputs: PhysiologyInputs = PhysiologyInputs.new()


func _ready() -> void:
	process_physics_priority = PHYSICS_PRIORITY
	add_to_group(PLAYER_GROUP)
	_motor.setup(self, _head)
	_interaction.setup(_camera, self)
	_motor.landed.connect(_on_motor_landed)
	_inventory.doses_changed.connect(_on_doses_changed)
	# Sons involuntários do corpo: a fisiologia decide, o BreathEmitter emite (integração F2-006b, Director).
	_physiology.cough_warning.connect(_breath.emit_cough_warning)
	_physiology.coughed.connect(_breath.emit_cough)
	_physiology.startle_gasp.connect(_breath.emit_gasp)
	_physiology.set_medication_charges(_inventory.get_doses(INHALER_ITEM))
	_context = InteractionContext.new()
	_context.actor = self
	apply_limits(_physiology.get_coupling())
	_camera.fov = Settings.get_float(&"fov")
	Settings.changed.connect(_on_settings_changed)
	_motor.footstep.connect(_on_footstep)
	_hold.setup(self, _camera)
	_wire_threat_monitor()
	_wire_perceivable()
	EventBus.player_captured.connect(_on_player_captured)
	# O AcousticWorld do nível pode entrar na árvore depois do jogador: o registro vai no fim do quadro.
	_bind_acoustic_world.call_deferred()
	set_mouse_captured(true)


func _exit_tree() -> void:
	if Settings.changed.is_connected(_on_settings_changed):
		Settings.changed.disconnect(_on_settings_changed)
	if EventBus.player_captured.is_connected(_on_player_captured):
		EventBus.player_captured.disconnect(_on_player_captured)
	if _bound_world != null and is_instance_valid(_bound_world):
		_bound_world.unregister_player_listener()
	_bound_world = null


func _physics_process(delta: float) -> void:
	_motor.step(delta)
	# Ameaça percebida (F4-006b): o monitor atualiza a amostra antes de as entradas deste tick serem montadas.
	_threat_monitor.step(delta)
	_update_perceivable()
	var inputs: PhysiologyInputs = _build_physiology_inputs()
	_physiology.step(delta, inputs)
	# Limites do acoplamento deste tick: o motor os usa a partir do próximo tick (COMPONENT_CONTRACTS §1).
	var coupling: CouplingFactors = _physiology.get_coupling()
	apply_limits(coupling)
	_breath.step(delta, _physiology.get_snapshot())
	_context.steadiness = coupling.steadiness
	_context.is_hidden = inputs.is_hidden
	_interaction.step(delta, _context)
	_hold.step(delta)


## Tecla use_item (Q): tenta usar a bombinha. Tecla throw: arremessa o objeto da mão, se houver um.
func _unhandled_input(event: InputEvent) -> void:
	if _input_locked:
		return
	if event.is_action_pressed(&"use_item"):
		try_use_inhaler()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(InputBindings.THROW_ACTION) and _hold.is_holding():
		_hold.throw_held()
		get_viewport().set_input_as_handled()


## Usa uma dose da bombinha. Falha sem consumir nada se não há doses ou se a bombinha está em cooldown.
func try_use_inhaler() -> bool:
	if _inventory.get_doses(INHALER_ITEM) <= 0:
		item_use_failed.emit(&"no_doses")
		return false
	if inhaler_profile == null:
		Log.error(&"player", "PlayerRoot sem inhaler_profile; a bombinha não é usada")
		item_use_failed.emit(&"no_profile")
		return false
	if not _physiology.apply_medication(inhaler_profile):
		item_use_failed.emit(&"cooldown")
		return false
	_inventory.consume_dose(INHALER_ITEM)
	_on_inhaler_used()
	inhaler_used.emit()
	return true


func get_inventory() -> InventoryComponent:
	return _inventory


## Som da bombinha (F2-005 + F2-006b): o puff é um som do corpo, emitido pelo BreathEmitter (MEDICATION 38 dB).
func _on_inhaler_used() -> void:
	var profile_db: float = inhaler_profile.noise_db if inhaler_profile != null else 38.0
	_breath.emit_body_sound(Enums.NoiseCategory.MEDICATION, profile_db, &"inhaler_puff", 1.0)


func _on_doses_changed(item_id: StringName, doses: int) -> void:
	if item_id == INHALER_ITEM:
		_physiology.set_medication_charges(doses)


## Repassa os limites da fisiologia ao motor (só reduzem; MOT-INV-3).
func apply_limits(coupling: CouplingFactors) -> void:
	_motor.apply_limits(coupling)


func get_motor() -> PlayerMotor:
	return _motor


func get_interaction() -> InteractionComponent:
	return _interaction


func get_breath_emitter() -> BreathEmitter:
	return _breath


func get_physiology() -> PhysiologyComponent:
	return _physiology


func get_threat_source() -> ThreatSource:
	return _threat_source


## Troca a fonte da ameaça. null volta ao StubThreatSource com ameaça zero (testes e depuração).
func set_threat_source(source: ThreatSource) -> void:
	_threat_source = source if source != null else StubThreatSource.new()


func get_threat_monitor() -> PlayerThreatMonitor:
	return _threat_monitor


func get_perceivable_target() -> PerceivableTarget:
	return _perceivable


func get_light_probe() -> LightExposureProbe:
	return _light_probe


## Trava a entrada do jogador (captura, F4-005): o motor zera a entrada e os atalhos do PlayerRoot são ignorados.
func set_input_locked(locked: bool) -> void:
	_input_locked = locked
	_motor.set_input_locked(locked)


func is_input_locked() -> bool:
	return _input_locked


## Captura do Observer (EventBus.player_captured): trava a entrada. A tela de captura cuida do fade e do reinício.
func _on_player_captured(_enemy_id: StringName) -> void:
	set_input_locked(true)


## Liga o monitor à fisiologia e à fonte da ameaça (D4-01). O susto do monitor vira add_startle (COMPONENT §6.5).
func _wire_threat_monitor() -> void:
	_threat_monitor.setup(_camera)
	set_threat_source(_threat_monitor.get_threat_source())
	_threat_monitor.startled.connect(_physiology.add_startle)


## Liga a sonda de luz e os marcadores de amostra ao PerceivableTarget (PLR-INV-1: só o mediador faz a ligação).
func _wire_perceivable() -> void:
	_perceivable.set_light_probe(_light_probe)
	_perceivable.set_concealment(0.0)
	var samples: Array[Marker3D] = [_sample_head, _sample_torso, _sample_feet]
	_perceivable.sample_points = samples


## Atualiza a postura e a altura dos marcadores de amostra (cabeça, tronco e pés) com a altura dos olhos do tick.
func _update_perceivable() -> void:
	_perceivable.set_stance(_motor.get_stance())
	var eye_height: float = _head.position.y
	_sample_head.position.y = eye_height
	_sample_torso.position.y = eye_height * TORSO_HEIGHT_RATIO


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
	# Ruído de queda (F3-004): só acima da velocidade mínima; escada e degrau nunca chegam aqui.
	if fall_noise != null and absf(fall_speed) >= fall_noise.min_fall_speed_mps:
		_foot_noise.emit_noise(Enums.NoiseCategory.FALL, NOISE_LEVELS.fall_db, 0.0, FALL_SOUND)


## Passo ou corrida (F3-004): nível pela marcha e superfície (NoiseLevels), sound_id footstep_<superfície>.
func _on_footstep(surface: StringName, gait: Enums.Gait, stance: Enums.Stance) -> void:
	var level_surface: StringName = PlayerNoiseMap.level_surface(surface)
	var sound: StringName = PlayerNoiseMap.footstep_sound(surface)
	if gait == Enums.Gait.SPRINT:
		_foot_noise.emit_noise(Enums.NoiseCategory.RUNNING, NOISE_LEVELS.running_level(level_surface), 0.0, sound)
		return
	var gait_key: StringName = PlayerNoiseMap.footstep_gait(gait, stance)
	_foot_noise.emit_noise(Enums.NoiseCategory.FOOTSTEP, NOISE_LEVELS.footstep_level(gait_key, level_surface), 0.0, sound)


## Registro no AcousticWorld do nível (grupo acoustic_world): o ouvido é a câmera. Sem mundo, aviso e sem susto.
## O ouvinte é o PlayerThreatMonitor, que também faz o susto por som (F4-009, substitui a ponte da F3).
func _bind_acoustic_world() -> void:
	if not is_inside_tree() or _bound_world != null:
		return
	var world: AcousticWorld = get_tree().get_first_node_in_group(AcousticWorld.GROUP) as AcousticWorld
	if world == null:
		Log.warn(&"player", "PlayerRoot sem AcousticWorld no nível; sem susto por som")
		return
	world.register_player_listener(_threat_monitor.receive_heard, _camera)
	_bound_world = world


## Mão do jogador (arremessáveis, F3-004).
func get_hold() -> PlayerHold:
	return _hold


func _is_headless() -> bool:
	return DisplayServer.get_name() == HEADLESS_DISPLAY_NAME

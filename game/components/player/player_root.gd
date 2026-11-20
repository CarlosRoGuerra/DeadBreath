class_name PlayerRoot
extends CharacterBody3D
## PlayerRoot (L2, Gameplay Engineer, F1-006): mediador do jogador (COMPONENT_CONTRACTS §1).
## É o único script que conhece os componentes do jogador. Na F1 só existe o PlayerMotor; a
## fisiologia, a ameaça e a respiração entram nas fases seguintes. Não contém regras de movimento.
## Ordem do tick: process_physics_priority = -90 (SYSTEM_ARCHITECTURE §6).

const PHYSICS_PRIORITY: int = -90
const HEADLESS_DISPLAY_NAME: String = "headless"

@onready var _motor: PlayerMotor = $PlayerMotor
@onready var _head: Node3D = $Head
@onready var _camera: Camera3D = $Head/Camera3D


func _ready() -> void:
	process_physics_priority = PHYSICS_PRIORITY
	_motor.setup(self, _head)
	apply_limits(CouplingFactors.neutral())
	_camera.fov = Settings.get_float(&"fov")
	Settings.changed.connect(_on_settings_changed)
	if not _is_headless():
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _exit_tree() -> void:
	if Settings.changed.is_connected(_on_settings_changed):
		Settings.changed.disconnect(_on_settings_changed)


func _physics_process(delta: float) -> void:
	_motor.step(delta)
	# Sem fisiologia na F1: limites neutros. Passam a valer no próximo tick (contrato §1).
	apply_limits(CouplingFactors.neutral())


## "pause" alterna a captura do mouse (a F1 não tem menu de pausa).
func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed(&"pause"):
		return
	if _is_headless():
		return
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	get_viewport().set_input_as_handled()


## Repassa os limites da fisiologia ao motor (só reduzem; MOT-INV-3).
func apply_limits(coupling: CouplingFactors) -> void:
	_motor.apply_limits(coupling)


func get_motor() -> PlayerMotor:
	return _motor


func _on_settings_changed(key: StringName) -> void:
	if key == &"fov":
		_camera.fov = Settings.get_float(&"fov")


func _is_headless() -> bool:
	return DisplayServer.get_name() == HEADLESS_DISPLAY_NAME

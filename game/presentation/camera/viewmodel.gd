class_name Viewmodel
extends Node3D
## Viewmodel provisório (L3, F2-009): mão e bombinha em primitivas, presas à câmera (filho da Camera3D), então herdam
## o balanço respiratório e o tremor da câmera (coerência). Animação de uso: a bombinha sobe à boca e volta.
## Sobressalto da tosse: a mão cai e volta. Amplitudes escalam por effects_intensity; o sobressalto também por
## motion_reduction. Não altera estado de jogo.

const USE_TIME_S: float = 0.8
const COUGH_TIME_S: float = 0.4
const USE_LIFT_M: float = 0.10
const COUGH_DROP_M: float = 0.03
const HAND_REST: Vector3 = Vector3(0.22, -0.24, -0.42)
const HAND_SIZE: Vector3 = Vector3(0.09, 0.07, 0.20)
const INHALER_RADIUS_M: float = 0.012
const INHALER_HEIGHT_M: float = 0.08

var _hand: Node3D = null
var _use_time: float = -1.0
var _cough_time: float = -1.0


func _ready() -> void:
	_hand = Node3D.new()
	_hand.position = HAND_REST
	add_child(_hand)
	var palm: MeshInstance3D = MeshInstance3D.new()
	var box: BoxMesh = BoxMesh.new()
	box.size = HAND_SIZE
	palm.mesh = box
	_hand.add_child(palm)
	var inhaler: MeshInstance3D = MeshInstance3D.new()
	var cylinder: CylinderMesh = CylinderMesh.new()
	cylinder.top_radius = INHALER_RADIUS_M
	cylinder.bottom_radius = INHALER_RADIUS_M
	cylinder.height = INHALER_HEIGHT_M
	inhaler.mesh = cylinder
	inhaler.position = Vector3(0.0, HAND_SIZE.y * 0.5 + INHALER_HEIGHT_M * 0.5, 0.0)
	_hand.add_child(inhaler)


func play_use() -> void:
	_use_time = 0.0


func play_cough() -> void:
	_cough_time = 0.0


func is_using() -> bool:
	return _use_time >= 0.0


func is_coughing() -> bool:
	return _cough_time >= 0.0


func get_hand_position() -> Vector3:
	return _hand.position if _hand != null else Vector3.ZERO


func _process(delta: float) -> void:
	if _hand == null:
		return
	var intensity: float = Settings.get_float(&"effects_intensity")
	var motion: float = 1.0 - Settings.get_float(&"motion_reduction")
	var lift: float = 0.0
	var drop: float = 0.0
	if _use_time >= 0.0:
		_use_time += delta
		var progress: float = clampf(_use_time / USE_TIME_S, 0.0, 1.0)
		lift = sin(PI * progress) * USE_LIFT_M * intensity
		if progress >= 1.0:
			_use_time = -1.0
	if _cough_time >= 0.0:
		_cough_time += delta
		var cough_progress: float = clampf(_cough_time / COUGH_TIME_S, 0.0, 1.0)
		drop = sin(PI * cough_progress) * COUGH_DROP_M * intensity * motion
		if cough_progress >= 1.0:
			_cough_time = -1.0
	_hand.position = HAND_REST + Vector3(0.0, lift - drop, 0.0)

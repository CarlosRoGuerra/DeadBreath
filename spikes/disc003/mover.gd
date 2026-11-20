extends CharacterBody3D
## DISC-003 V6: controlador mínimo (NÃO é o PlayerMotor). Anda numa direção fixa,
## aplica gravidade e, opcionalmente, faz step-up por test_move até step_height.

const GRAVITY: float = 9.8
const FLOOR_NORMAL_MIN_Y: float = 0.7

var move_dir: Vector3 = Vector3.RIGHT
var speed: float = 1.6
var step_height: float = 0.30
var use_step_up: bool = true
## Distância horizontal da sondagem do step-up. Com cápsula, precisa passar do raio
## para que a base arredondada fique sobre o degrau (senão a normal é da quina).
var probe_distance: float = 0.27
var step_ups: int = 0


func _physics_process(dt: float) -> void:
	var horizontal: Vector3 = move_dir * speed
	velocity.x = horizontal.x
	velocity.z = horizontal.z
	if is_on_floor():
		velocity.y = 0.0
	else:
		velocity.y -= GRAVITY * dt
	if use_step_up and is_on_floor() and speed > 0.0:
		_try_step_up(horizontal * dt)
	move_and_slide()


func _try_step_up(motion: Vector3) -> void:
	var hit: KinematicCollision3D = KinematicCollision3D.new()
	if not test_move(global_transform, motion, hit):
		return
	if hit.get_normal().y >= FLOOR_NORMAL_MIN_Y:
		return
	var start: Transform3D = global_transform
	var up: Vector3 = Vector3.UP * step_height
	var up_hit: KinematicCollision3D = KinematicCollision3D.new()
	var raised: Transform3D = start.translated(up)
	if test_move(start, up, up_hit):
		raised = start.translated(up_hit.get_travel())
	var probe: Vector3 = motion.normalized() * maxf(motion.length(), probe_distance)
	if test_move(raised, probe):
		return
	var forward: Transform3D = raised.translated(probe)
	var down_hit: KinematicCollision3D = KinematicCollision3D.new()
	if not test_move(forward, -up - Vector3.UP * 0.05, down_hit):
		return
	if down_hit.get_normal().y < FLOOR_NORMAL_MIN_Y:
		return
	var rise: float = forward.translated(down_hit.get_travel()).origin.y - start.origin.y
	if rise <= 0.01:
		return
	global_transform = start.translated(Vector3.UP * (rise + 0.005))
	step_ups += 1

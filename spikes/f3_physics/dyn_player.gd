extends CharacterBody3D
## F3-005: jogador de teste (CharacterBody3D) que anda a velocidade fixa em +X. NÃO é o PlayerMotor.

const GRAVITY: float = 9.8

var move_speed: float = 3.0


func _physics_process(delta: float) -> void:
	velocity.x = move_speed
	velocity.z = 0.0
	if is_on_floor():
		velocity.y = 0.0
	else:
		velocity.y -= GRAVITY * delta
	move_and_slide()

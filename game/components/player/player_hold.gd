class_name PlayerHold
extends Node
## PlayerHold (L2, F3-004): a mão do jogador. Pega um Throwable, segura-o diante da câmera, arremessa (ação throw) ou
## solta com cuidado (só se a forma couber no lugar; se não couber, continua segurando). Só o PlayerRoot o usa.
## Ordem do tick: step(delta) depois do motor e da interação, para o objeto acompanhar a câmera do tick.

const HOLD_OFFSET: Vector3 = Vector3(0.0, -0.25, -0.7)
const THROW_SPEED_MS: float = 9.0
const THROW_LIFT_MS: float = 1.5

var _body: CollisionObject3D = null
var _camera: Camera3D = null
var _held: Throwable = null


## body: o corpo do jogador (CollisionObject3D); camera: a câmera de onde se pega e se arremessa.
func setup(body: CollisionObject3D, camera: Camera3D) -> void:
	_body = body
	_camera = camera


func is_holding() -> bool:
	return _held != null and is_instance_valid(_held)


func get_held() -> Throwable:
	return _held if is_holding() else null


## Pega o objeto se a mão estiver livre. Retorna false se já segura algo.
func try_pick(item: Throwable) -> bool:
	if item == null or is_holding():
		return false
	_held = item
	item.set_held(true, _body)
	return true


## Arremessa para onde a câmera olha, com um pouco de elevação. Sem objeto na mão, não faz nada.
func throw_held() -> bool:
	if not is_holding() or _camera == null:
		return false
	var item: Throwable = _held
	var forward: Vector3 = -_camera.global_transform.basis.z
	_release(item)
	item.linear_velocity = forward * THROW_SPEED_MS + Vector3.UP * THROW_LIFT_MS
	return true


## Solta no lugar atual, sem velocidade, se a forma couber ali (o que soltar for possível). False: segura.
func drop_held() -> bool:
	if not is_holding():
		return false
	var item: Throwable = _held
	if not item.can_place_at(item.global_transform, _body):
		return false
	_release(item)
	return true


## Acompanha a câmera: o objeto segurado fica na posição da mão.
func step(_delta: float) -> void:
	if not is_holding() or _camera == null:
		return
	var camera_transform: Transform3D = _camera.global_transform
	var target: Transform3D = Transform3D(camera_transform.basis, camera_transform * HOLD_OFFSET)
	_held.set_hold_transform(target)


func _release(item: Throwable) -> void:
	_held = null
	item.set_held(false, _body)

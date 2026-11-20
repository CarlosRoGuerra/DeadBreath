class_name DebugCommands
extends RefCounted
## Comandos de debug (L3, F1-008): noclip e teleporte para o ponto do chão na mira.
## Desligados em build de produção (GameState.is_production_build): cada comando recusa e devolve false.
## Usam a API de teste do PlayerRoot (set_noclip, teleport_to); não alteram o estado do jogo por conta própria.

const FLOOR_NORMAL_MIN_Y: float = 0.7
const AIM_REACH_M: float = 100.0
const WORLD_MASK: int = 3
const TELEPORT_LIFT_M: float = 0.05


static func is_allowed() -> bool:
	return not GameState.is_production_build


static func set_noclip(player: PlayerRoot, enabled: bool) -> bool:
	if not is_allowed() or player == null:
		return false
	player.set_noclip(enabled)
	return true


## Teleporta para o ponto do chão (normal quase vertical) atingido pela mira. Sem chão na mira, recusa.
static func teleport_to_aim(player: PlayerRoot) -> bool:
	if not is_allowed() or player == null:
		return false
	var point: PackedVector3Array = floor_point_under_aim(player)
	if point.is_empty():
		return false
	player.teleport_to(point[0] + Vector3.UP * TELEPORT_LIFT_M)
	return true


## Ponto do chão na mira, em um array de 0 ou 1 elemento (GDScript não tem retorno opcional).
static func floor_point_under_aim(player: PlayerRoot) -> PackedVector3Array:
	var result: PackedVector3Array = PackedVector3Array()
	var camera: Camera3D = player.get_camera()
	if camera == null or not camera.is_inside_tree():
		return result
	var origin: Vector3 = camera.global_position
	var direction: Vector3 = -camera.global_transform.basis.z
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
		origin, origin + direction * AIM_REACH_M, WORLD_MASK, [player.get_rid()])
	var hit: Dictionary = camera.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return result
	var normal: Vector3 = hit.get("normal", Vector3.ZERO) as Vector3
	if normal.y < FLOOR_NORMAL_MIN_Y:
		return result
	result.append(hit.get("position", origin) as Vector3)
	return result

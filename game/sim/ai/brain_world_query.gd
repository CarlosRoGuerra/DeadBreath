class_name BrainWorldQuery
extends RefCounted
## BrainWorldQuery (L1, COMPONENT_CONTRACTS §8.2, DATA_STRUCTURES §3; F4-003): base abstrata de consultas ao mundo.
## Implementada pelo EnemyWorldQuery (L2, F4-004). Nenhum método retorna dado do jogador.
## Subclasses que não sobrescrevem um método recebem push_error e o valor neutro.
## self_position é a posição do próprio inimigo (acréscimo D4-07), não a do jogador.


func self_position() -> Vector3:
	push_error("BrainWorldQuery.self_position() nao sobrescrito")
	return Vector3.ZERO


func is_reachable(_point: Vector3) -> bool:
	push_error("BrainWorldQuery.is_reachable() nao sobrescrito")
	return false


func search_points_near(_center: Vector3, _radius: float) -> PackedVector3Array:
	push_error("BrainWorldQuery.search_points_near() nao sobrescrito")
	return PackedVector3Array()


func hideables_near(_center: Vector3, _radius: float) -> Array[HideableInfo]:
	push_error("BrainWorldQuery.hideables_near() nao sobrescrito")
	var none: Array[HideableInfo] = []
	return none


func patrol_points() -> PackedVector3Array:
	push_error("BrainWorldQuery.patrol_points() nao sobrescrito")
	return PackedVector3Array()

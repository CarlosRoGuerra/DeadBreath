class_name FakeBrainWorld
extends BrainWorldQuery
## Mundo falso para os testes do EnemyBrain (F4-003). Dado de cenário, sem jogador.
## O teste move self_position a mão, como faria o EnemyController: é a posição do próprio inimigo.

var position: Vector3 = Vector3.ZERO
var route: PackedVector3Array = PackedVector3Array()
var search_candidates: PackedVector3Array = PackedVector3Array()
var hideables: Array[HideableInfo] = []
var reachable: bool = true
## Centro da última consulta de busca (para conferir a âncora da SEARCH).
var last_search_center: Vector3 = Vector3.ZERO


func self_position() -> Vector3:
	return position


func is_reachable(_point: Vector3) -> bool:
	return reachable


func search_points_near(center: Vector3, _radius: float) -> PackedVector3Array:
	last_search_center = center
	return search_candidates.duplicate()


func hideables_near(center: Vector3, radius: float) -> Array[HideableInfo]:
	var found: Array[HideableInfo] = []
	for hideable: HideableInfo in hideables:
		if Vector2(hideable.position.x - center.x, hideable.position.z - center.z).length() <= radius:
			found.append(hideable)
	return found


func patrol_points() -> PackedVector3Array:
	return route.duplicate()

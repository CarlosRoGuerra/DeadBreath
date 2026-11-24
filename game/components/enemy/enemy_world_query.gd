class_name EnemyWorldQuery
extends BrainWorldQuery
## EnemyWorldQuery (L2, COMPONENT_CONTRACTS §8.1 e §8.2, DATA_STRUCTURES §3; F4-004): adaptador do EnemyController para o
## EnemyBrain. Responde só com geometria do mundo e com a posição do próprio inimigo. Nenhum método devolve dado do
## jogador (FW-INV-1): a consulta não recebe nem procura o jogador.
##
## Decisões (F4-004):
## - is_reachable: consulta barata. map_get_path até o destino; é alcançável se o fim do caminho fica a até
##   REACH_TOLERANCE_M do destino (horizontal). Tolerância de 0,5 m: a navmesh é recuada pelo raio do agente (0,35 m),
##   então um ponto de patrulha junto a parede cai fora da malha e o servidor devolve o ponto mais próximo. Resultado
##   em cache por ponto (0,1 m), invalidado quando o mapa muda (map_get_iteration_id): links de porta ligados ou
##   desligados e malha reassada zeram o cache. O cérebro consulta a cada tick em INVESTIGATE.
## - search_points_near: amostras no disco de raio `radius` em volta do centro, puxadas para a malha
##   (map_get_closest_point) e descartadas se ficarem longe demais ou perto de outra amostra. O RNG é o do inimigo,
##   então a mesma semente dá a mesma sequência de pontos.
## - hideables_near: vazio na F4 (sem esconderijos até a F5). Quando a F5 chegar, consulta o grupo de esconderijos.
## - patrol_points: a rota do controlador, na ordem dos marcadores (metadado order).
## Autor: AI Engineer (F4-004).

const REACH_TOLERANCE_M: float = 0.5
const CACHE_CELL_M: float = 0.1
const CACHE_MAX_ENTRIES: int = 256
const SAMPLE_TRIES: int = 16
const SAMPLE_MAX: int = 8
const SAMPLE_MIN_SEPARATION_M: float = 0.5
const SNAP_TOLERANCE_M: float = 0.5
const LOG_CATEGORY: StringName = &"enemy"

var _controller: EnemyController = null
var _map: RID = RID()
var _sampling_rng: RandomNumberGenerator = null
var _reach_cache: Dictionary = {}
var _cache_iteration: int = -1


## controller: o inimigo dono (posição e rota). navigation_map: o mapa do agente. sampling_rng: o RNG do inimigo.
func _init(controller: EnemyController, navigation_map: RID, sampling_rng: RandomNumberGenerator) -> void:
	_controller = controller
	_map = navigation_map
	if sampling_rng == null:
		Log.error(LOG_CATEGORY, "EnemyWorldQuery sem RNG; usando semente 1 (amostragem determinística)")
		sampling_rng = RandomNumberGenerator.new()
		sampling_rng.seed = 1
	_sampling_rng = sampling_rng


func self_position() -> Vector3:
	if _controller == null:
		return Vector3.ZERO
	return _controller.global_position


## Consulta barata (ver o cabeçalho): cache por ponto, zerado quando o mapa muda.
func is_reachable(point: Vector3) -> bool:
	var iteration: int = NavigationServer3D.map_get_iteration_id(_map)
	if iteration != _cache_iteration or _reach_cache.size() > CACHE_MAX_ENTRIES:
		_reach_cache.clear()
		_cache_iteration = iteration
	var key: Vector2i = _cache_key(point)
	if _reach_cache.has(key):
		return bool(_reach_cache[key])
	var reachable: bool = _compute_reachable(point)
	_reach_cache[key] = reachable
	return reachable


func search_points_near(center: Vector3, radius: float) -> PackedVector3Array:
	var found: PackedVector3Array = PackedVector3Array()
	if radius <= 0.0:
		return found
	for _attempt: int in range(SAMPLE_TRIES):
		if found.size() >= SAMPLE_MAX:
			break
		var angle: float = _sampling_rng.randf() * TAU
		var distance: float = sqrt(_sampling_rng.randf()) * radius
		var candidate: Vector3 = center + Vector3(cos(angle) * distance, 0.0, sin(angle) * distance)
		var snapped: Vector3 = NavigationServer3D.map_get_closest_point(_map, candidate)
		if _flat_distance(snapped, center) > radius + SNAP_TOLERANCE_M:
			continue
		if _too_close_to_any(snapped, found):
			continue
		found.append(snapped)
	return found


## F4: nenhum esconderijo. A F5 consulta os nós do grupo de esconderijos dentro de radius.
func hideables_near(_center: Vector3, _radius: float) -> Array[HideableInfo]:
	var none: Array[HideableInfo] = []
	return none


func patrol_points() -> PackedVector3Array:
	if _controller == null:
		return PackedVector3Array()
	return _controller.patrol_route()


## O ponto é projetado na malha antes do caminho: uma pista de som vem na altura da fonte (ex.: respiração a 1,6 m), e
## map_get_path não acha caminho para um ponto muito acima da malha. A tolerância é medida contra o ponto original.
func _compute_reachable(point: Vector3) -> bool:
	if not _map.is_valid():
		return false
	var goal: Vector3 = NavigationServer3D.map_get_closest_point(_map, point)
	var path: PackedVector3Array = NavigationServer3D.map_get_path(_map, self_position(), goal, true)
	if path.is_empty():
		return false
	return _flat_distance(path[path.size() - 1], point) <= REACH_TOLERANCE_M


func _cache_key(point: Vector3) -> Vector2i:
	return Vector2i(roundi(point.x / CACHE_CELL_M), roundi(point.z / CACHE_CELL_M))


func _too_close_to_any(point: Vector3, others: PackedVector3Array) -> bool:
	for other: Vector3 in others:
		if _flat_distance(point, other) < SAMPLE_MIN_SEPARATION_M:
			return true
	return false


static func _flat_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()

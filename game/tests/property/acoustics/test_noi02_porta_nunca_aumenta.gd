extends TestCase
## NOI-02 e NOI-INV-3 em varredura (TEST_PLAN §2.3), F3-001. Sobre grafos aleatórios com semente fixa:
##   (a) mesmo grafo e evento dão o mesmo resultado, e grafos reconstruídos com a mesma semente também;
##   (b) fechar portas (uma a uma, em ordem sorteada) nunca aumenta o nível percebido em nenhum ouvinte;
##   (c) em cada estado de porta (abertas, e depois cada fechamento), o nível escolhido é o máximo entre o caminho
##       direto e TODOS os caminhos simples por portais, obtidos por enumeração exaustiva (implementação independente
##       da busca do AcousticGraph). Nível property: --level=property.
## Autor: AI Engineer (F3-001).

const Fx := preload("res://tests/unit/acoustics/fixtures/acoustic_fixture.gd")
const SCENARIO_COUNT: int = 1000
const QUERIES_PER_SCENARIO: int = 6
## Enumeração exaustiva só até este número de portais (o número de caminhos cresce como fatorial).
const BRUTE_FORCE_MAX_PORTALS: int = 7
const CELL_M: float = 4.0
const TOL: float = 0.000001
const FLOOR_CHOICES: Array = [12.0, 22.0, 28.0, 38.0]


## Cenário sorteado com uma semente: salas numa grade (com vãos), portais nas faces compartilhadas, um andar
## acima de uma célula (piso), e consultas (fonte, ouvinte, intensidade).
class Scenario extends RefCounted:
	var config: AcousticConfig
	var room_ids: Array[StringName] = []
	var room_boxes: Array[AABB] = []
	var room_floors: Array[float] = []
	var portal_ids: Array[StringName] = []
	var portal_a: Array[int] = []
	var portal_b: Array[int] = []
	var portal_positions: Array[Vector3] = []
	var sounds: Array[NoiseEvent] = []
	var listeners: Array[Vector3] = []


## Enumeração de caminhos simples por portais (cada portal no máximo uma vez), guardando o melhor nível.
class Search extends RefCounted:
	var scenario: Scenario
	var open: Array[bool] = []
	var used: Array[bool] = []
	var listener: Vector3 = Vector3.ZERO
	var listener_room: int = -1
	var intensity_db: float = 0.0
	var best_db: float = -INF

	func visit(room: int, position: Vector3, length_m: float, loss_db: float) -> void:
		if room == listener_room:
			var total_m: float = length_m + position.distance_to(listener)
			best_db = maxf(best_db, intensity_db - Fx.distance_loss_db(total_m) - loss_db)
		for portal_index: int in range(scenario.portal_ids.size()):
			if used[portal_index]:
				continue
			var other: int = -1
			if scenario.portal_a[portal_index] == room:
				other = scenario.portal_b[portal_index]
			elif scenario.portal_b[portal_index] == room:
				other = scenario.portal_a[portal_index]
			if other < 0:
				continue
			var next_position: Vector3 = scenario.portal_positions[portal_index]
			var portal_loss: float = scenario.config.portal_open_loss_db if open[portal_index] \
				else scenario.config.portal_closed_loss_db
			used[portal_index] = true
			visit(other, next_position, length_m + position.distance_to(next_position), loss_db + portal_loss)
			used[portal_index] = false


class Tally extends RefCounted:
	var mismatches: int = 0
	var rising: int = 0
	var closures: int = 0
	var queries: int = 0
	var routes_chosen: int = 0
	var brute_checks: int = 0
	var brute_route_best: int = 0
	var brute_skipped: int = 0
	var brute_mismatches: int = 0


static func _add_room(s: Scenario, room_id: StringName, box: AABB, floor_db: float) -> int:
	s.room_ids.append(room_id)
	s.room_boxes.append(box)
	s.room_floors.append(floor_db)
	return s.room_ids.size() - 1


static func _add_portal(s: Scenario, portal_id: StringName, room_a: int, room_b: int, at: Vector3) -> void:
	s.portal_ids.append(portal_id)
	s.portal_a.append(room_a)
	s.portal_b.append(room_b)
	s.portal_positions.append(at)


static func _scenario(seed_value: int) -> Scenario:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	var s: Scenario = Scenario.new()
	s.config = Fx.production_config()
	var size_x: int = rng.randi_range(1, 3)
	var size_z: int = rng.randi_range(1, 3)
	var cell_room: Array[int] = []
	for i: int in range(size_x):
		for j: int in range(size_z):
			var present: bool = rng.randf() < 0.8
			if present:
				var floor_db: float = FLOOR_CHOICES[rng.randi_range(0, FLOOR_CHOICES.size() - 1)]
				var box: AABB = Fx.box(i * CELL_M, (i + 1) * CELL_M, 0.0, 3.0, j * CELL_M, (j + 1) * CELL_M)
				cell_room.append(_add_room(s, StringName("r_%d_%d" % [i, j]), box, floor_db))
			else:
				cell_room.append(-1)
	for i: int in range(size_x):
		for j: int in range(size_z):
			var here: int = cell_room[i * size_z + j]
			if here < 0:
				continue
			if i + 1 < size_x and cell_room[(i + 1) * size_z + j] >= 0 and rng.randf() < 0.6:
				var east: int = cell_room[(i + 1) * size_z + j]
				_add_portal(s, StringName("pe_%d_%d" % [i, j]), here, east,
					Vector3((i + 1) * CELL_M, 1.5, j * CELL_M + 0.5 * CELL_M))
			if j + 1 < size_z and cell_room[i * size_z + j + 1] >= 0 and rng.randf() < 0.6:
				var north: int = cell_room[i * size_z + j + 1]
				_add_portal(s, StringName("pn_%d_%d" % [i, j]), here, north,
					Vector3(i * CELL_M + 0.5 * CELL_M, 1.5, (j + 1) * CELL_M))
	if cell_room[0] >= 0 and rng.randf() < 0.5:
		var upper: int = _add_room(s, &"andar_de_cima", Fx.box(0.0, CELL_M, 3.0, 6.0, 0.0, CELL_M),
			FLOOR_CHOICES[rng.randi_range(0, FLOOR_CHOICES.size() - 1)])
		_add_portal(s, &"escada", cell_room[0], upper, Vector3(0.5 * CELL_M, 3.0, 0.5 * CELL_M))
	var extent_x: float = size_x * CELL_M + 2.0
	var extent_z: float = size_z * CELL_M + 2.0
	for _query: int in range(QUERIES_PER_SCENARIO):
		var source: Vector3 = _sample_point(s, rng, extent_x, extent_z)
		s.sounds.append(Fx.event(rng.randf_range(14.0, 80.0), source))
		s.listeners.append(_sample_point(s, rng, extent_x, extent_z))
	return s


## Ponto dentro de uma sala sorteada (85%) ou na área em volta da grade (15%, pode cair fora de qualquer sala).
static func _sample_point(s: Scenario, rng: RandomNumberGenerator, extent_x: float, extent_z: float) -> Vector3:
	if not s.room_boxes.is_empty() and rng.randf() < 0.85:
		var box: AABB = s.room_boxes[rng.randi_range(0, s.room_boxes.size() - 1)]
		var low: Vector3 = box.position + box.size * 0.05
		return low + Vector3(rng.randf() * box.size.x * 0.9, rng.randf() * box.size.y * 0.9,
			rng.randf() * box.size.z * 0.9)
	return Vector3(rng.randf_range(-2.0, extent_x), rng.randf_range(0.5, 5.5), rng.randf_range(-2.0, extent_z))


static func _build(s: Scenario, with_portals: bool) -> AcousticGraph:
	var graph: AcousticGraph = AcousticGraph.new(s.config)
	for index: int in range(s.room_ids.size()):
		graph.add_room(s.room_ids[index], s.room_boxes[index], s.room_floors[index])
	if with_portals:
		for index: int in range(s.portal_ids.size()):
			graph.add_portal(s.portal_ids[index], s.room_ids[s.portal_a[index]], s.room_ids[s.portal_b[index]],
				s.portal_positions[index])
	return graph


static func _levels(graph: AcousticGraph, s: Scenario) -> PackedFloat64Array:
	var levels: PackedFloat64Array = PackedFloat64Array()
	for index: int in range(s.sounds.size()):
		levels.append(graph.propagate(s.sounds[index], s.listeners[index]).perceived_db)
	return levels


static func _count_routes(graph: AcousticGraph, s: Scenario) -> int:
	var count: int = 0
	for index: int in range(s.sounds.size()):
		if not graph.propagate(s.sounds[index], s.listeners[index]).path_portals.is_empty():
			count += 1
	return count


static func _room_containing(s: Scenario, point: Vector3) -> int:
	for index: int in range(s.room_boxes.size()):
		var box: AABB = s.room_boxes[index]
		var inside: bool = true
		for axis: int in range(3):
			var low: float = box.position[axis]
			if point[axis] < low or point[axis] >= low + box.size[axis]:
				inside = false
		if inside:
			return index
	return -1


## Melhor nível por caminhos de portais simples (enumeração), ou -INF se não há rota entre salas distintas.
static func _brute_best_db(s: Scenario, open: Array[bool], sound: NoiseEvent, listener: Vector3) -> float:
	var source_room: int = _room_containing(s, sound.position)
	var listener_room: int = _room_containing(s, listener)
	if source_room < 0 or listener_room < 0 or source_room == listener_room:
		return -INF
	var search: Search = Search.new()
	search.scenario = s
	search.open = open
	search.listener = listener
	search.listener_room = listener_room
	search.intensity_db = sound.intensity_db
	search.used.resize(s.portal_ids.size())
	search.used.fill(false)
	search.visit(source_room, sound.position, 0.0, 0.0)
	return search.best_db


## Confere, no estado atual de portas, que o nível do grafo é o máximo entre o direto e a enumeração.
static func _check_exact(graph: AcousticGraph, direct_graph: AcousticGraph, s: Scenario, open: Array[bool],
		tally: Tally) -> void:
	if s.portal_ids.size() > BRUTE_FORCE_MAX_PORTALS:
		tally.brute_skipped += s.sounds.size()
		return
	for query: int in range(s.sounds.size()):
		var sound: NoiseEvent = s.sounds[query]
		var listener: Vector3 = s.listeners[query]
		var direct_db: float = direct_graph.propagate(sound, listener).perceived_db
		var route_db: float = _brute_best_db(s, open, sound, listener)
		var actual: float = graph.propagate(sound, listener).perceived_db
		tally.brute_checks += 1
		if route_db > direct_db:
			tally.brute_route_best += 1
		if absf(actual - maxf(direct_db, route_db)) > TOL:
			tally.brute_mismatches += 1


## Permutação de 0..count-1 com o RNG semeado (Array.shuffle usaria o RNG global e não seria reproduzível).
static func _shuffled_indices(count: int, rng: RandomNumberGenerator) -> Array[int]:
	var order: Array[int] = []
	for index: int in range(count):
		order.append(index)
	for index: int in range(count - 1, 0, -1):
		var swap_with: int = rng.randi_range(0, index)
		var held: int = order[index]
		order[index] = order[swap_with]
		order[swap_with] = held
	return order


func test_mesma_semente_mesmo_resultado_e_fechar_porta_nunca_aumenta() -> void:
	var tally: Tally = Tally.new()
	for scenario_index: int in range(SCENARIO_COUNT):
		var seed_value: int = 3001 + scenario_index
		var first: Scenario = _scenario(seed_value)
		var second: Scenario = _scenario(seed_value)
		var graph: AcousticGraph = _build(first, true)
		var levels: PackedFloat64Array = _levels(graph, first)
		if levels != _levels(_build(second, true), second):
			tally.mismatches += 1
		if levels != _levels(graph, first):
			tally.mismatches += 1
		tally.routes_chosen += _count_routes(graph, first)
		tally.queries += first.sounds.size()

		var open: Array[bool] = []
		for _portal: StringName in first.portal_ids:
			open.append(true)
		var direct_graph: AcousticGraph = _build(first, false)
		_check_exact(graph, direct_graph, first, open, tally)
		var rng: RandomNumberGenerator = RandomNumberGenerator.new()
		rng.seed = seed_value + 100000
		for portal_index: int in _shuffled_indices(first.portal_ids.size(), rng):
			graph.set_portal_open(first.portal_ids[portal_index], false)
			open[portal_index] = false
			tally.closures += 1
			var closed_levels: PackedFloat64Array = _levels(graph, first)
			for query: int in range(closed_levels.size()):
				if closed_levels[query] > levels[query] + TOL:
					tally.rising += 1
			levels = closed_levels
			_check_exact(graph, direct_graph, first, open, tally)

	note("NOI-02 varredura: %d grafos, %d consultas, %d fechamentos de porta, %d consultas com rota por portal (estado inicial)" % [
		SCENARIO_COUNT, tally.queries, tally.closures, tally.routes_chosen])
	note("NOI-02 máximo exato: %d conferências por enumeração em todos os estados de porta (%d com rota por portal como melhor caminho), %d puladas (mais de %d portais)" % [
		tally.brute_checks, tally.brute_route_best, tally.brute_skipped, BRUTE_FORCE_MAX_PORTALS])
	assert_eq(tally.mismatches, 0, "mesma semente: resultados diferentes")
	assert_eq(tally.rising, 0, "fechar porta aumentou o nível percebido em %d casos (NOI-INV-3)" % [tally.rising])
	assert_eq(tally.brute_mismatches, 0,
		"a busca por portais não achou o máximo da enumeração em %d casos" % [tally.brute_mismatches])
	assert_true(tally.brute_checks > 0, "vacuidade: nenhuma consulta foi conferida por enumeração")

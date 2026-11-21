class_name AcousticGraph
extends RefCounted
## AcousticGraph (L1, COMPONENT_CONTRACTS §6.1; DATA_STRUCTURES §2.2 a §2.5; SYSTEM_ARCHITECTURE §7, ADR-004).
## Salas (AABB) e portais. propagate() devolve o nível percebido no ouvinte pelo caminho de MAIOR nível:
##   1. caminho direto: perda por distância mais a perda de cada parede e de cada piso atravessados;
##   2. caminho por portais: perda por distância sobre a poligonal fonte → portais → ouvinte, mais a perda de cada
##      portal (aberto ou fechado). Esse caminho passa pelo portal, então não tem perda de parede nem de piso.
## Função pura e determinística (NOI-INV-3, NOI-02): sem RNG, sem Node, sem autoload. Fechar um portal só soma
## perda, então o nível percebido nunca sobe.
##
## Regras de fronteira do caminho direto (decididas na F3-001):
##   - Regiões: cada sala (AABB semiaberta: min <= p < max) e o exterior (o resto do espaço).
##   - Cada troca de região ao longo do segmento fonte→ouvinte é uma fronteira. Parede entre duas salas vizinhas
##     conta UMA vez. Sala→exterior e exterior→sala contam uma. Duas paredes com vão no meio contam duas.
##   - A fronteira é PISO quando a face atravessada é horizontal (normal em Y, salas empilhadas). Caso contrário,
##     é PAREDE. Sem face identificável, conta como parede.
##   - Encostar numa face sem atravessá-la (segmento de comprimento zero dentro da sala) não conta.
##   - As salas devem ser disjuntas. Se se sobreporem, room_at devolve a primeira adicionada.
##
## Busca por portais: Dijkstra com rótulos não dominados. A perda por distância é logarítmica, então não é aditiva
## e o Dijkstra simples sobre uma métrica não daria o melhor nível. A busca guarda, por (portal, sala em que o
## caminho entrou), os pares (comprimento, perda dos portais) não dominados, processa por comprimento crescente e
## escolhe o melhor nível com a fórmula exata. Um rótulo dominado nunca dá nível maior que o dominante.
## Quando fonte e ouvinte estão no mesmo cômodo, ou um deles fora de qualquer sala, só vale o caminho direto.
##
## Audibilidade (DATA §2.3): effective_threshold_db(). Fora de qualquer sala, o piso é OUTSIDE_AMBIENT_FLOOR_DB
## (o "Exterior" de DATA §2.3; decisão F3-001, a ratificar).

## Piso de ruído ambiente fora de qualquer sala: linha "Exterior" de DATA §2.3.
const OUTSIDE_AMBIENT_FLOOR_DB: float = 38.0
## Limite de rótulos da busca por portais. Um nível típico usa algumas dezenas; o limite só protege contra abuso.
const MAX_ROUTE_LABELS: int = 512
const SEGMENT_EPSILON_M: float = 0.000001
const PARAMETER_EPSILON: float = 0.000001
const DIRECTION_EPSILON: float = 0.000000001
const VERTICAL_AXIS: int = 1

var _config: AcousticConfig
var _rooms: Array[_Room] = []
var _portals: Array[_Portal] = []
var _weather_floor_offset_db: float = 0.0


class _Room extends RefCounted:
	var id: StringName = &""
	var bounds: AABB = AABB()
	var ambient_floor_db: float = 0.0


class _Portal extends RefCounted:
	var id: StringName = &""
	var room_a: int = -1
	var room_b: int = -1
	var position: Vector3 = Vector3.ZERO
	var open: bool = true


## Interseção de um segmento com um AABB: parâmetros de entrada e saída (0..1) e eixos das faces (-1 se o
## segmento começa ou termina dentro da sala nesse ponto).
class _Hit extends RefCounted:
	var room: int = -1
	var t_enter: float = 0.0
	var t_exit: float = 1.0
	var axis_enter: int = -1
	var axis_exit: int = -1


class _Label extends RefCounted:
	var portal_index: int = -1
	var portal_id: StringName = &""
	## Sala em que o caminho entrou por este portal.
	var room: int = -1
	var length_m: float = 0.0
	var loss_db: float = 0.0
	var position: Vector3 = Vector3.ZERO
	var parent: int = -1
	var expanded: bool = false


class _Route extends RefCounted:
	var perceived_db: float = 0.0
	var portal_ids: Array[StringName] = []
	var last_position: Vector3 = Vector3.ZERO


func _init(config: AcousticConfig) -> void:
	if config == null:
		push_error("AcousticGraph: config nula; usando os valores padrão de AcousticConfig")
		config = AcousticConfig.new()
	_config = config


## Adiciona uma sala. bounds: AABB (min inclusivo, max exclusivo). Id vazio, id repetido ou volume não positivo:
## push_error e nada é adicionado.
func add_room(room_id: StringName, bounds: AABB, ambient_floor_db: float) -> void:
	if room_id == &"":
		push_error("AcousticGraph.add_room: id de sala vazio")
		return
	if _find_room(room_id) >= 0:
		push_error("AcousticGraph.add_room: sala '%s' já existe" % [room_id])
		return
	if bounds.size.x <= 0.0 or bounds.size.y <= 0.0 or bounds.size.z <= 0.0:
		push_error("AcousticGraph.add_room: sala '%s' com volume não positivo" % [room_id])
		return
	var room: _Room = _Room.new()
	room.id = room_id
	room.bounds = bounds
	room.ambient_floor_db = ambient_floor_db
	_rooms.append(room)


## Adiciona um portal aberto entre duas salas, na posição dada (sobre a face compartilhada). Salas inexistentes,
## salas iguais, id vazio ou id repetido: push_error e nada é adicionado.
func add_portal(portal_id: StringName, room_a: StringName, room_b: StringName, position: Vector3) -> void:
	if portal_id == &"":
		push_error("AcousticGraph.add_portal: id de portal vazio")
		return
	if _find_portal(portal_id) >= 0:
		push_error("AcousticGraph.add_portal: portal '%s' já existe" % [portal_id])
		return
	var index_a: int = _find_room(room_a)
	var index_b: int = _find_room(room_b)
	if index_a < 0 or index_b < 0:
		push_error("AcousticGraph.add_portal: portal '%s' liga sala inexistente" % [portal_id])
		return
	if index_a == index_b:
		push_error("AcousticGraph.add_portal: portal '%s' liga a sala '%s' a ela mesma" % [portal_id, room_a])
		return
	var portal: _Portal = _Portal.new()
	portal.id = portal_id
	portal.room_a = index_a
	portal.room_b = index_b
	portal.position = position
	_portals.append(portal)


## Abre ou fecha um portal. Portal inexistente: push_error.
func set_portal_open(portal_id: StringName, open: bool) -> void:
	var index: int = _find_portal(portal_id)
	if index < 0:
		push_error("AcousticGraph.set_portal_open: portal '%s' não existe" % [portal_id])
		return
	_portals[index].open = open


## Estado do portal. Portal inexistente: push_error e false.
func is_portal_open(portal_id: StringName) -> bool:
	var index: int = _find_portal(portal_id)
	if index < 0:
		push_error("AcousticGraph.is_portal_open: portal '%s' não existe" % [portal_id])
		return false
	return _portals[index].open


## Offset climático somado ao piso de todas as salas no limiar de audibilidade (trovão: +20 dB).
func set_weather_floor_offset(offset_db: float) -> void:
	_weather_floor_offset_db = offset_db


func weather_floor_offset_db() -> float:
	return _weather_floor_offset_db


## Id da sala que contém o ponto (semiaberta), ou &"" fora de qualquer sala.
func room_at(position: Vector3) -> StringName:
	var index: int = _region_at(position)
	if index < 0:
		return &""
	return _rooms[index].id


## Piso de ruído ambiente no ponto: o da sala que o contém, ou OUTSIDE_AMBIENT_FLOOR_DB fora de qualquer sala.
func ambient_floor_at(position: Vector3) -> float:
	var index: int = _region_at(position)
	if index < 0:
		return OUTSIDE_AMBIENT_FLOOR_DB
	return _rooms[index].ambient_floor_db


## Limiar efetivo de audibilidade (DATA §2.3): max(hearing_threshold_db; piso da sala do ouvinte + offset climático +
## masking_margin_db). O jogador usa hearing 10 e margem 0; os inimigos usam o AIProfile. Audível ⇔ perceived_db
## >= limiar. Função pura: não altera o grafo.
func effective_threshold_db(listener_position: Vector3, hearing_threshold_db: float, masking_margin_db: float) -> float:
	var floor_db: float = ambient_floor_at(listener_position) + _weather_floor_offset_db + masking_margin_db
	return maxf(hearing_threshold_db, floor_db)


## Nível percebido pelo ouvinte, pelo caminho de maior nível (ver cabeçalho). Empate entre o caminho direto e o
## por portais: vence o direto. Não altera o evento nem o grafo.
## Campos: entry_point é o último portal do caminho escolhido, ou a fonte no caminho direto. through_wall é
## verdadeiro só se o caminho escolhido é direto e atravessa ao menos uma PAREDE; piso atravessado conta na
## perda, mas não liga through_wall (decisão F3-001: o campo tem o nome de DATA §2, que só fala em parede).
func propagate(event: NoiseEvent, listener_position: Vector3) -> PropagationResult:
	var result: PropagationResult = PropagationResult.new()
	var source: Vector3 = event.position
	var counts: Vector2i = _count_boundaries(source, listener_position)
	var direct_loss_db: float = _distance_loss_db(source.distance_to(listener_position)) \
		+ float(counts.x) * _config.wall_transmission_loss_db \
		+ float(counts.y) * _config.floor_transmission_loss_db
	result.perceived_db = event.intensity_db - direct_loss_db
	result.entry_point = source
	result.through_wall = counts.x > 0
	var source_room: int = _region_at(source)
	var listener_room: int = _region_at(listener_position)
	if source_room >= 0 and listener_room >= 0 and source_room != listener_room:
		var route: _Route = _best_route(source, source_room, listener_position, listener_room, event.intensity_db)
		if route != null and route.perceived_db > result.perceived_db:
			result.perceived_db = route.perceived_db
			result.path_portals = route.portal_ids
			result.entry_point = route.last_position
			result.through_wall = false
	return result


## Perda por distância: 20·log10(max(d; min_distance_m)) + extra_loss_per_m_db·d (DATA §2.2).
func _distance_loss_db(length_m: float) -> float:
	var clamped: float = maxf(length_m, _config.min_distance_m)
	return 20.0 * log(clamped) / log(10.0) + _config.extra_loss_per_m_db * length_m


func _portal_loss_db(portal: _Portal) -> float:
	if portal.open:
		return _config.portal_open_loss_db
	return _config.portal_closed_loss_db


func _find_room(room_id: StringName) -> int:
	for index: int in range(_rooms.size()):
		if _rooms[index].id == room_id:
			return index
	return -1


func _find_portal(portal_id: StringName) -> int:
	for index: int in range(_portals.size()):
		if _portals[index].id == portal_id:
			return index
	return -1


## Índice da primeira sala cujo AABB semiaberto contém o ponto, ou -1 (exterior).
func _region_at(point: Vector3) -> int:
	for index: int in range(_rooms.size()):
		if _contains(_rooms[index].bounds, point):
			return index
	return -1


static func _contains(bounds: AABB, point: Vector3) -> bool:
	for axis: int in range(3):
		var low: float = bounds.position[axis]
		if point[axis] < low or point[axis] >= low + bounds.size[axis]:
			return false
	return true


## Fronteiras atravessadas pelo segmento direto, como Vector2i(paredes, pisos).
## Sequência de regiões: sala da fonte, região de cada subintervalo entre cortes, sala do ouvinte. Cada troca
## de região na sequência conta uma fronteira, no instante do corte correspondente. Assim, fonte ou ouvinte
## sobre uma face contam como estando no lado de sua própria sala (semiaberta).
func _count_boundaries(source: Vector3, listener: Vector3) -> Vector2i:
	var counts: Vector2i = Vector2i.ZERO
	var delta: Vector3 = listener - source
	if delta.length() <= SEGMENT_EPSILON_M:
		return counts
	var hits: Array[_Hit] = []
	var times: Array[float] = [0.0, 1.0]
	for room_index: int in range(_rooms.size()):
		var hit: _Hit = _segment_hit(source, delta, _rooms[room_index].bounds, room_index)
		if hit != null:
			hits.append(hit)
			times.append(hit.t_enter)
			times.append(hit.t_exit)
	times.sort()
	var cuts: Array[float] = []
	for t: float in times:
		if cuts.is_empty() or t - cuts[cuts.size() - 1] > PARAMETER_EPSILON:
			cuts.append(t)
	var sequence: Array[int] = [_region_at(source)]
	for k: int in range(cuts.size() - 1):
		sequence.append(_region_at(source + delta * (0.5 * (cuts[k] + cuts[k + 1]))))
	sequence.append(_region_at(listener))
	for j: int in range(sequence.size() - 1):
		if sequence[j] == sequence[j + 1]:
			continue
		if _boundary_axis(hits, sequence[j], sequence[j + 1], cuts[j]) == VERTICAL_AXIS:
			counts.y += 1
		else:
			counts.x += 1
	return counts


## Eixo da face atravessada na fronteira entre duas regiões no instante t, ou -1 se não identificado.
func _boundary_axis(hits: Array[_Hit], from_room: int, to_room: int, t: float) -> int:
	for hit: _Hit in hits:
		if hit.room == from_room and hit.axis_exit >= 0 and absf(hit.t_exit - t) <= PARAMETER_EPSILON:
			return hit.axis_exit
	for hit: _Hit in hits:
		if hit.room == to_room and hit.axis_enter >= 0 and absf(hit.t_enter - t) <= PARAMETER_EPSILON:
			return hit.axis_enter
	return -1


## Intervalo do segmento (parâmetro em [0; 1]) dentro do AABB, com os eixos das faces. Null se não cruza a sala.
static func _segment_hit(origin: Vector3, delta: Vector3, bounds: AABB, room: int) -> _Hit:
	var hit: _Hit = _Hit.new()
	hit.room = room
	for axis: int in range(3):
		var low: float = bounds.position[axis]
		var high: float = low + bounds.size[axis]
		var start: float = origin[axis]
		var step: float = delta[axis]
		if absf(step) <= DIRECTION_EPSILON:
			if start < low or start > high:
				return null
			continue
		var t_low: float = (low - start) / step
		var t_high: float = (high - start) / step
		var near: float = minf(t_low, t_high)
		var far: float = maxf(t_low, t_high)
		if near > hit.t_enter:
			hit.t_enter = near
			hit.axis_enter = axis
		if far < hit.t_exit:
			hit.t_exit = far
			hit.axis_exit = axis
		if hit.t_enter > hit.t_exit:
			return null
	return hit


## Melhor caminho por portais entre duas salas distintas (Dijkstra com rótulos não dominados). Null se o
## ouvinte não é alcançável por portais.
func _best_route(source: Vector3, source_room: int, listener: Vector3, listener_room: int, intensity_db: float) -> _Route:
	var labels: Array[_Label] = []
	_offer_from_source(labels, source, source_room)
	var best_index: int = -1
	var best_db: float = -INF
	var current: int = _next_label(labels)
	while current >= 0:
		labels[current].expanded = true
		if labels[current].room == listener_room:
			var total_m: float = labels[current].length_m + labels[current].position.distance_to(listener)
			var candidate_db: float = intensity_db - _distance_loss_db(total_m) - labels[current].loss_db
			if candidate_db > best_db:
				best_db = candidate_db
				best_index = current
		else:
			if labels.size() >= MAX_ROUTE_LABELS:
				push_error("AcousticGraph: busca por portais atingiu %d rótulos; resultado parcial" % [MAX_ROUTE_LABELS])
				break
			_expand(labels, current)
		current = _next_label(labels)
	if best_index < 0:
		return null
	var route: _Route = _Route.new()
	route.perceived_db = best_db
	route.last_position = labels[best_index].position
	var index: int = best_index
	while index >= 0:
		route.portal_ids.push_front(labels[index].portal_id)
		index = labels[index].parent
	return route


func _offer_from_source(labels: Array[_Label], source: Vector3, source_room: int) -> void:
	for portal_index: int in range(_portals.size()):
		var portal: _Portal = _portals[portal_index]
		var other: int = _other_room(portal, source_room)
		if other < 0:
			continue
		_offer(labels, portal_index, other, source.distance_to(portal.position), _portal_loss_db(portal), portal.position, -1)


func _expand(labels: Array[_Label], index: int) -> void:
	var origin: _Label = labels[index]
	for portal_index: int in range(_portals.size()):
		var portal: _Portal = _portals[portal_index]
		var other: int = _other_room(portal, origin.room)
		if other < 0:
			continue
		_offer(labels, portal_index, other, origin.length_m + origin.position.distance_to(portal.position),
			origin.loss_db + _portal_loss_db(portal), portal.position, index)


## Acrescenta um rótulo, salvo se outro com o mesmo (portal, sala de entrada) for igual ou melhor em comprimento e
## perda. Um rótulo dominado nunca dá nível maior, então pode ser descartado sem perder o melhor caminho.
func _offer(labels: Array[_Label], portal_index: int, room: int, length_m: float, loss_db: float,
		position: Vector3, parent: int) -> void:
	for existing: _Label in labels:
		if existing.portal_index == portal_index and existing.room == room \
				and existing.length_m <= length_m and existing.loss_db <= loss_db:
			return
	var label: _Label = _Label.new()
	label.portal_index = portal_index
	label.portal_id = _portals[portal_index].id
	label.room = room
	label.length_m = length_m
	label.loss_db = loss_db
	label.position = position
	label.parent = parent
	labels.append(label)


## Índice do rótulo ainda não expandido de menor comprimento (empate: o de menor índice), ou -1.
func _next_label(labels: Array[_Label]) -> int:
	var best: int = -1
	for index: int in range(labels.size()):
		if labels[index].expanded:
			continue
		if best < 0 or labels[index].length_m < labels[best].length_m:
			best = index
	return best


## Sala do outro lado do portal, a partir da sala dada, ou -1 se o portal não toca essa sala.
func _other_room(portal: _Portal, room: int) -> int:
	if portal.room_a == room:
		return portal.room_b
	if portal.room_b == room:
		return portal.room_a
	return -1

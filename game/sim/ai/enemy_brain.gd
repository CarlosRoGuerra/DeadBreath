class_name EnemyBrain
extends RefCounted
## EnemyBrain (L1, COMPONENT_CONTRACTS §8.2, DATA_STRUCTURES §3.3; F4-003): máquina de estados do inimigo.
##
## Entrada: PerceptBatch (percepts dos sensores) e BrainWorldQuery (geometria do mundo; nunca dado do jogador).
## Saída: EnemyIntent. Não move nada: o EnemyController (F4-004) aplica o intent.
## Determinístico: o único aleatório é o RandomNumberGenerator injetado. Sem Node, sem autoload, sem cena.
##
## Ordem do tick: (1) percepts: visão, pistas, suspeita, confirmação e decaimento da memória;
## (2) transições, em cascata, até MAX_TRANSITIONS_PER_TICK; (3) intent do estado final.
##
## Decisões de implementação (F4-003):
## - Chegada: distância no plano horizontal (XZ) ≤ ARRIVAL_RADIUS_M = 1,0 m. O controlador deve levar o
##   NavigationAgent3D até o destino dentro desse raio (target_desired_distance ≤ 1,0).
## - Velocidades: patrulha, investigação e perseguição vêm do AIProfile. SEARCH e RETURN usam patrol_speed.
##   LOST_CONTACT usa investigate_speed: o inimigo já não vê o jogador e vai à última posição vista sem correr.
## - Suspeita por visão: += vision_suspicion_gain_per_s · visibilidade · dt, com a maior visibilidade do tick.
## - Confirmação: += visibilidade · dt se visibilidade ≥ min_visibility_for_confirm; senão −2 · dt (piso 0).
## - Pista de INVESTIGATE: PerceptionMemory.best_lead() a cada tick; sem pista útil, mantém o último destino.
## - SEARCH: pontos de search_points_near(âncora, SEARCH_RADIUS_M), filtrados por is_reachable e embaralhados pelo
##   RNG; recomeçam embaralhados quando a lista acaba. Pista nova (visão ou ruído audível) reinicia o cronômetro da
##   busca (DATA §3.3, "nova pista").
## - D4-09 (revisão F4-010): a confirmação tem teto em visual_confirm_time_s e zera ao entrar em LOST_CONTACT; RETURN
##   e PATROL desistem de destino inalcançável ou depois de 30 s sem chegar.
## - Inspeção (SEARCH): ao chegar a um ponto, se hideables_near(ponto, HIDEABLE_RADIUS_M) não for vazio, sorteia
##   inspect_hideable_chance. Se der certo, vai ao esconderijo e, ao chegar, posta inspect_hideable uma vez.
## - Falas: a voice_line é a da última transição do tick (em cascata, vale a fala final).
## - Entrar em PATROL zera suspeita, confirmação e memória. Entrar em RETURN limpa a memória.
## - Chegar à patrulha no RETURN retoma a rota no ponto em que o inimigo voltou.
## Audição (D4-08, HeardNoise com effective_threshold_db):
## - Cada ruído audível (perceived_db ≥ effective_threshold_db) soma hearing_suspicion_gain(...) à suspeita, com o teto
##   hearing_suspicion_cap_per_event por evento. Grava a pista na memória (estimated_position, confidence, origem
##   &"hearing") e conta como estímulo (zera o decaimento). Ruído abaixo do limiar é ignorado.
## - Novo ruído com suspeita ≥ investigate_threshold leva a INVESTIGATE a partir de PATROL, SUSPICIOUS, SEARCH e RETURN.
##   O sinal de "novo ruído" vale só no tick em que o ruído chegou.
## - Pista de INVESTIGATE é o best_lead (critério acima). Ela pode não ser a do ruído que disparou a transição, se
##   houver outra pista mais confiável na memória.
## INVESTIGATE (D4-08):
## - Pista inalcançável (is_reachable falso): vai direto a SEARCH com âncora na posição atual.
## - INVESTIGATE_TIMEOUT_S sem chegar à pista: vai a SEARCH com âncora na posição atual.
## - Os 3 s sem visibilidade contam a partir da chegada à pista (INVESTIGATE_WATCH_S).
## - is_reachable é consultado a cada tick em INVESTIGATE; o controlador deve manter essa consulta barata.

const ARRIVAL_RADIUS_M: float = 1.0
const SEARCH_RADIUS_M: float = 6.0
const HIDEABLE_RADIUS_M: float = 2.0
## CHASE → LOST_CONTACT: visibilidade 0 por este tempo contínuo (DATA §3.3).
const LOST_CONTACT_NO_SIGHT_S: float = 1.5
## INVESTIGATE → SEARCH: chegou à pista e passou este tempo sem visibilidade (DATA §3.3). Conta a partir da chegada.
const INVESTIGATE_WATCH_S: float = 3.0
## INVESTIGATE → SEARCH sem chegar à pista (D4-08). Tempo desde a entrada em INVESTIGATE.
const INVESTIGATE_TIMEOUT_S: float = 15.0
## D4-09 (revisão F4-010, R4-03): RETURN e PATROL também não ficam presos. Destino inalcançável ou este tempo sem
## chegar: RETURN passa a PATROL (que pula pontos inalcançáveis) e PATROL passa ao ponto seguinte.
const RETURN_TIMEOUT_S: float = 30.0
const PATROL_LEG_TIMEOUT_S: float = 30.0
## Suspeita decai só depois deste tempo sem estímulo visual (DATA §3.3).
const SUSPICION_DECAY_DELAY_S: float = 2.0
## SUSPICIOUS → PATROL: suspeita abaixo deste valor (DATA §3.3; constante, não é do perfil).
const SUSPICION_RELAX_BELOW: float = 0.15
## Perda de confirmação por segundo sem visibilidade suficiente (DATA §3.3).
const CONFIRM_LOSS_PER_S: float = 2.0
const MAX_TRANSITIONS_PER_TICK: int = 6

## Falas do Observer (DATA §3, tabela de falas; D4-06).
const VOICE_SUSPICIOUS: StringName = &"voice_suspicious"
const VOICE_INVESTIGATE: StringName = &"voice_investigate"
const VOICE_CHASE: StringName = &"voice_chase_shout"
const VOICE_SEARCH: StringName = &"voice_search"

## Estado atual (leitura pelo controlador e pelos testes).
var state: Enums.EnemyState = Enums.EnemyState.PATROL
## Suspeita 0..; ≥ suspicious_threshold leva a SUSPICIOUS, ≥ investigate_threshold leva a INVESTIGATE.
var suspicion: float = 0.0
## Tempo de confirmação acumulado (s); ≥ visual_confirm_time_s leva a CHASE.
var confirmation: float = 0.0

var _profile: AIProfile
var _rng: RandomNumberGenerator
var _memory: PerceptionMemory
## Segundos desde a entrada no estado atual.
var _state_time: float = 0.0
## Segundos seguidos com visibilidade 0 (zerado por qualquer visibilidade e ao entrar em INVESTIGATE e CHASE).
var _no_sight_s: float = 0.0
var _time_since_stimulus: float = 0.0
## Segundos seguidos no ponto da pista de INVESTIGATE, sem visibilidade (zerado ao sair do ponto ou ver alguém).
var _watch_s: float = 0.0
## Neste tick: houve visibilidade > 0, e chegou um ruído audível (sinal de "novo ruído").
var _seen_this_tick: bool = false
var _heard_this_tick: bool = false
## Posição do último estímulo (visual ou sonoro), para olhar em SUSPICIOUS.
var _stimulus: Vector3 = Vector3.ZERO
## Última posição vista do jogador (CHASE e LOST_CONTACT).
var _last_seen: Vector3 = Vector3.ZERO
## Área de interesse atual: pista de INVESTIGATE ou última posição vista. Âncora da busca.
var _anchor: Vector3 = Vector3.ZERO
## Destino atual de INVESTIGATE, LOST_CONTACT e RETURN.
var _target: Vector3 = Vector3.ZERO
var _patrol_index: int = 0
## Segundos indo ao ponto de patrulha atual (D4-09). Zera ao trocar de ponto e ao entrar em PATROL.
var _patrol_leg_s: float = 0.0
var _return_index: int = 0
var _search_points: PackedVector3Array = PackedVector3Array()
var _search_index: int = 0
var _inspect_pending: bool = false
var _inspect_target: Vector3 = Vector3.ZERO
var _inspect_id: StringName = &""
## Fala a postar neste tick (a da última transição).
var _pending_voice: StringName = &""


func _init(profile: AIProfile, rng: RandomNumberGenerator) -> void:
	_profile = profile
	_rng = rng
	_memory = PerceptionMemory.new(profile.memory_confidence_decay_per_s)


## Um tick do cérebro. dt em segundos (≥ 0). Devolve um EnemyIntent novo.
func tick(dt: float, percepts: PerceptBatch, world: BrainWorldQuery) -> EnemyIntent:
	var step: float = maxf(dt, 0.0)
	_pending_voice = &""
	var here: Vector3 = world.self_position()
	_state_time += step
	_patrol_leg_s += step
	_update_perception(step, percepts)
	if state == Enums.EnemyState.INVESTIGATE:
		_follow_best_lead()
		_update_watch(step, here)
	for _attempt: int in range(MAX_TRANSITIONS_PER_TICK):
		if not _try_transition(world, here):
			break
	return _build_intent(world, here)


## Suspeita por audição (DATA §3.3): min(cap, per_db · (perceived − limiar efetivo)). Excesso negativo vale 0.
## Suspeita por um ruído audível (DATA §3.3, D4-08). Função pura: o cérebro a chama para cada HeardNoise.
static func hearing_suspicion_gain(perceived_db: float, effective_threshold_db: float, profile: AIProfile) -> float:
	var excess: float = maxf(perceived_db - effective_threshold_db, 0.0)
	return minf(profile.hearing_suspicion_cap_per_event, profile.hearing_suspicion_per_db * excess)


## Percepts do tick: decaimento da memória, visão (suspeita, pista, última posição vista), ruídos (suspeita, pista),
## decaimento da suspeita sem estímulo e confirmação. Estímulo = visão > 0 ou ruído audível.
func _update_perception(step: float, percepts: PerceptBatch) -> void:
	_memory.decay(step)
	var best: VisualPercept = null
	for percept: VisualPercept in percepts.visual:
		if percept.visibility > 0.0 and (best == null or percept.visibility > best.visibility):
			best = percept
	_seen_this_tick = best != null
	_heard_this_tick = _hear_all(percepts.heard)
	var visibility: float = 0.0
	if best != null:
		visibility = best.visibility
		_no_sight_s = 0.0
		_stimulus = best.position
		_last_seen = best.position
		_memory.record(PerceptionRecord.create(best.position, best.timestamp, best.visibility, &"vision"))
		suspicion += _profile.vision_suspicion_gain_per_s * best.visibility * step
	else:
		_no_sight_s += step
	if best != null or _heard_this_tick:
		_time_since_stimulus = 0.0
		if state == Enums.EnemyState.SEARCH:
			_state_time = 0.0
	else:
		_time_since_stimulus += step
		if _time_since_stimulus >= SUSPICION_DECAY_DELAY_S:
			suspicion = maxf(0.0, suspicion - _profile.suspicion_decay_per_s * step)
	_add_confirmation(visibility, step)


## Ruídos do tick (D4-08). Ruído abaixo do limiar efetivo é ignorado. Cada audível soma a sua suspeita (com teto
## por evento), vira pista na memória e vira estímulo. Devolve se algum foi audível.
func _hear_all(heard: Array[HeardNoise]) -> bool:
	var any_audible: bool = false
	for noise: HeardNoise in heard:
		if noise.perceived_db < noise.effective_threshold_db:
			continue
		any_audible = true
		suspicion += EnemyBrain.hearing_suspicion_gain(noise.perceived_db, noise.effective_threshold_db, _profile)
		_memory.record(PerceptionRecord.create(noise.estimated_position, noise.timestamp, noise.confidence, &"hearing"))
		_stimulus = noise.estimated_position
	return any_audible


## Tempo no ponto da pista sem visibilidade (INVESTIGATE). Zera ao sair do ponto ou ver alguém.
func _update_watch(step: float, here: Vector3) -> void:
	if _is_at(here, _target) and not _seen_this_tick:
		_watch_s += step
	else:
		_watch_s = 0.0


## D4-09 (revisão F4-010, R4-01): a confirmação tem teto em visual_confirm_time_s. Sem teto, ela crescia durante a
## perseguição e devolvia o inimigo a CHASE logo depois de LOST_CONTACT, sem visão nova.
func _add_confirmation(visibility: float, step: float) -> void:
	if visibility > 0.0 and visibility >= _profile.min_visibility_for_confirm:
		confirmation = minf(confirmation + visibility * step, _profile.visual_confirm_time_s)
	else:
		confirmation = maxf(0.0, confirmation - CONFIRM_LOSS_PER_S * step)


## Estados em que um ruído novo leva a INVESTIGATE (DATA §3.3).
func _listens_to_noise() -> bool:
	return state == Enums.EnemyState.PATROL or state == Enums.EnemyState.SUSPICIOUS \
		or state == Enums.EnemyState.SEARCH or state == Enums.EnemyState.RETURN


func _follow_best_lead() -> void:
	var lead: PerceptionRecord = _memory.best_lead()
	if lead != null:
		_target = lead.position
		_anchor = lead.position


## Uma transição, se a condição de alguma linha da tabela (DATA §3.3) for verdadeira. Devolve se houve.
func _try_transition(world: BrainWorldQuery, here: Vector3) -> bool:
	if state != Enums.EnemyState.CHASE and confirmation >= _profile.visual_confirm_time_s:
		_enter(Enums.EnemyState.CHASE, world, here, VOICE_CHASE)
		return true
	if _heard_this_tick and suspicion >= _profile.investigate_threshold and _listens_to_noise():
		_heard_this_tick = false
		_enter(Enums.EnemyState.INVESTIGATE, world, here, VOICE_INVESTIGATE)
		return true
	if state == Enums.EnemyState.PATROL:
		if suspicion >= _profile.suspicious_threshold:
			_enter(Enums.EnemyState.SUSPICIOUS, world, here, VOICE_SUSPICIOUS)
			return true
		return false
	if state == Enums.EnemyState.SUSPICIOUS:
		if suspicion >= _profile.investigate_threshold:
			_enter(Enums.EnemyState.INVESTIGATE, world, here, VOICE_INVESTIGATE)
			return true
		if suspicion < SUSPICION_RELAX_BELOW:
			_enter(Enums.EnemyState.PATROL, world, here, &"")
			return true
		return false
	if state == Enums.EnemyState.INVESTIGATE:
		if not world.is_reachable(_target):
			_anchor = here
			_enter(Enums.EnemyState.SEARCH, world, here, VOICE_SEARCH)
			return true
		if _state_time >= INVESTIGATE_TIMEOUT_S:
			_anchor = here
			_enter(Enums.EnemyState.SEARCH, world, here, VOICE_SEARCH)
			return true
		if _watch_s >= INVESTIGATE_WATCH_S:
			_enter(Enums.EnemyState.SEARCH, world, here, VOICE_SEARCH)
			return true
		return false
	if state == Enums.EnemyState.CHASE:
		if _no_sight_s >= LOST_CONTACT_NO_SIGHT_S:
			_enter(Enums.EnemyState.LOST_CONTACT, world, here, &"")
			return true
		return false
	if state == Enums.EnemyState.LOST_CONTACT:
		if _is_at(here, _target) or _state_time >= _profile.lost_contact_pursuit_s:
			_enter(Enums.EnemyState.SEARCH, world, here, VOICE_SEARCH)
			return true
		return false
	if state == Enums.EnemyState.SEARCH:
		if _state_time >= _profile.search_duration_s * _profile.search_duration_multiplier:
			_enter(Enums.EnemyState.RETURN, world, here, &"")
			return true
		return false
	if state == Enums.EnemyState.RETURN:
		if _is_at(here, _target) or not world.is_reachable(_target) or _state_time >= RETURN_TIMEOUT_S:
			_patrol_index = _return_index
			_enter(Enums.EnemyState.PATROL, world, here, &"")
			return true
		return false
	return false


## Entrada em um estado: zera o cronômetro, prepara o destino e registra a fala da transição.
func _enter(next: Enums.EnemyState, world: BrainWorldQuery, here: Vector3, voice: StringName) -> void:
	state = next
	_state_time = 0.0
	_pending_voice = voice
	match next:
		Enums.EnemyState.PATROL:
			suspicion = 0.0
			confirmation = 0.0
			_patrol_leg_s = 0.0
			_memory.clear()
		Enums.EnemyState.INVESTIGATE:
			_watch_s = 0.0
			_inspect_pending = false
			var lead: PerceptionRecord = _memory.best_lead()
			if lead != null:
				_target = lead.position
			else:
				_target = _stimulus
			_anchor = _target
		Enums.EnemyState.CHASE:
			_no_sight_s = 0.0
		Enums.EnemyState.LOST_CONTACT:
			# D4-09 (R4-01): voltar a CHASE exige visão nova.
			confirmation = 0.0
			_target = _last_seen
			_anchor = _last_seen
		Enums.EnemyState.SEARCH:
			_start_search(world)
		Enums.EnemyState.RETURN:
			_inspect_pending = false
			_memory.clear()
			var route: PackedVector3Array = world.patrol_points()
			if route.is_empty():
				_return_index = 0
				_target = here
			else:
				_return_index = _nearest_index(route, here)
				_target = route[_return_index]
		_:
			pass


func _start_search(world: BrainWorldQuery) -> void:
	_search_points.clear()
	var candidates: PackedVector3Array = world.search_points_near(_anchor, SEARCH_RADIUS_M)
	for point: Vector3 in candidates:
		if world.is_reachable(point):
			_search_points.append(point)
	_shuffle_search_points()
	_search_index = 0
	_inspect_pending = false


## Fisher-Yates com o RNG injetado: a mesma semente dá a mesma ordem.
func _shuffle_search_points() -> void:
	for index: int in range(_search_points.size() - 1, 0, -1):
		var other: int = _rng.randi_range(0, index)
		var held: Vector3 = _search_points[index]
		_search_points[index] = _search_points[other]
		_search_points[other] = held


func _advance_search_index() -> void:
	if _search_points.is_empty():
		return
	_search_index += 1
	if _search_index >= _search_points.size():
		_search_index = 0
		_shuffle_search_points()


## Sorteia a inspeção de um esconderijo perto do ponto. Sem esconderijo, não consome o RNG.
func _try_start_inspection(world: BrainWorldQuery, point: Vector3) -> bool:
	var hideables: Array[HideableInfo] = world.hideables_near(point, HIDEABLE_RADIUS_M)
	if hideables.is_empty():
		return false
	if _rng.randf() >= _profile.inspect_hideable_chance:
		return false
	var chosen: HideableInfo = hideables[_rng.randi_range(0, hideables.size() - 1)]
	_inspect_pending = true
	_inspect_target = chosen.position
	_inspect_id = chosen.persist_id
	return true


func _build_intent(world: BrainWorldQuery, here: Vector3) -> EnemyIntent:
	var intent: EnemyIntent = EnemyIntent.new()
	intent.voice_line = _pending_voice
	match state:
		Enums.EnemyState.PATROL:
			_build_patrol_intent(intent, world, here)
		Enums.EnemyState.SUSPICIOUS:
			_head_to(intent, here, 0.0)
			intent.look_target = _stimulus
		Enums.EnemyState.INVESTIGATE:
			_head_to(intent, _target, _profile.investigate_speed)
		Enums.EnemyState.CHASE:
			_head_to(intent, _last_seen, _profile.chase_speed)
		Enums.EnemyState.LOST_CONTACT:
			_head_to(intent, _target, _profile.investigate_speed)
		Enums.EnemyState.SEARCH:
			_build_search_intent(intent, world, here)
		Enums.EnemyState.RETURN:
			_head_to(intent, _target, _profile.patrol_speed)
		_:
			_head_to(intent, here, 0.0)
	return intent


## Patrulha em laço. Ao chegar a um ponto, passa ao seguinte. D4-09 (R4-03): ponto inalcançável ou
## PATROL_LEG_TIMEOUT_S sem chegar também passam ao seguinte; sem nenhum ponto alcançável, fica parado.
func _build_patrol_intent(intent: EnemyIntent, world: BrainWorldQuery, here: Vector3) -> void:
	var route: PackedVector3Array = world.patrol_points()
	if route.is_empty():
		push_error("EnemyBrain: rota de patrulha vazia")
		_head_to(intent, here, 0.0)
		return
	if _patrol_index >= route.size():
		_patrol_index = 0
	if _is_at(here, route[_patrol_index]) or _patrol_leg_s >= PATROL_LEG_TIMEOUT_S:
		_next_patrol_point(route.size())
	for _skip: int in range(route.size()):
		if world.is_reachable(route[_patrol_index]):
			_head_to(intent, route[_patrol_index], _profile.patrol_speed)
			return
		_next_patrol_point(route.size())
	_head_to(intent, here, 0.0)


func _next_patrol_point(route_size: int) -> void:
	_patrol_index = (_patrol_index + 1) % route_size
	_patrol_leg_s = 0.0


## Busca: visita os pontos embaralhados e, se houver esconderijo sorteado, vai inspecioná-lo antes de seguir.
func _build_search_intent(intent: EnemyIntent, world: BrainWorldQuery, here: Vector3) -> void:
	if _inspect_pending:
		if not _is_at(here, _inspect_target):
			_head_to(intent, _inspect_target, _profile.patrol_speed)
			return
		_inspect_pending = false
		intent.inspect_hideable = _inspect_id
		_advance_search_index()
	elif not _search_points.is_empty() and _is_at(here, _search_points[_search_index]):
		if _try_start_inspection(world, _search_points[_search_index]):
			_head_to(intent, _inspect_target, _profile.patrol_speed)
			return
		_advance_search_index()
	if _search_points.is_empty():
		_head_to(intent, here, 0.0)
		return
	_head_to(intent, _search_points[_search_index], _profile.patrol_speed)


func _head_to(intent: EnemyIntent, target: Vector3, speed: float) -> void:
	intent.move_target = target
	intent.move_speed = speed
	intent.look_target = target


func _nearest_index(route: PackedVector3Array, here: Vector3) -> int:
	var best: int = 0
	var best_distance: float = INF
	for index: int in range(route.size()):
		var distance: float = _horizontal_distance(route[index], here)
		if distance < best_distance:
			best_distance = distance
			best = index
	return best


func _is_at(here: Vector3, point: Vector3) -> bool:
	return _horizontal_distance(here, point) <= ARRIVAL_RADIUS_M


static func _horizontal_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()

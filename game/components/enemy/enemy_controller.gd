class_name EnemyController
extends CharacterBody3D
## EnemyController (L2, COMPONENT_CONTRACTS §8.1, SYSTEM_ARCHITECTURE §6; F4-004): corpo do inimigo (THE OBSERVER na F4).
## Grupo "enemy". Tick de IA com process_physics_priority = -40:
##   1. avalia cada nó do grupo "perceivable" pelo VisionSensor (só entra no lote o que tem visibilidade > 0);
##   2. drena o HearingSensor (os sons já foram entregues pelo AcousticWorld em -60);
##   3. monta o PerceptBatch (squad vazio: D4-02) com os resultados de inspeções pendentes (ENM-INV-2);
##   4. chama EnemyBrain.tick com o EnemyWorldQuery;
##   5. aplica o EnemyIntent: destino e velocidade (NavigationAgent3D), olhar (corpo e olho), passagem por porta (D4-03),
##      fala pelo NoiseEmitter filho (uma vez por transição) e passos.
## Captura: o EnemyCaptureArea (-30) repassa por player_caught; o controlador emite EventBus.player_captured. Nada da
## captura entra no lote (ENM-INV-1).
##
## Firewall (ARC-01, FW-INV-1): este arquivo não referencia o jogador. O único dado vindo do mundo sobre o jogador é o
## que o VisionSensor e o HearingSensor entregam.
##
## Decisões (F4-004):
## - Sensores: o perfil é copiado para o VisionSensor (alcance, FOV) e o HearingSensor (limiar, margem) em _ready.
## - Fonte dos sons do inimigo: "enemy_<enemy_id>". O owner_id do HearingSensor é a mesma fonte (o próprio som não volta).
## - Rota: marcadores do grupo "patrol_point" com metadado route_id igual ao deste inimigo, na ordem do metadado order,
##   dentro do mesmo ramo do pai (o nível).
## - Navegação: o tick só roda com o mapa pronto: com região registrada, MAP_MIN_ITERATION sincronismos e
##   MAP_SETTLE_FRAMES frames forçados. Antes disso map_get_path falha em pontos da malha (medido: sem isso, o primeiro
##   tick caía em SEARCH sem investigar). Sem o mapa pronto em MAP_WAIT_LIMIT_FRAMES, segue com um Log.error.
##   O destino do agente é projetado na malha (map_get_closest_point):
##   uma pista de som pode vir na altura da fonte (ex.: respiração a 1,6 m). Só é reposto quando muda mais de
##   TARGET_EPSILON_M.
## - Olhar: o corpo gira no plano (yaw) para o alvo, sem limite de velocidade de giro (greybox; limitação do relatório).
##   O olho inclina até PITCH_MAX_DEG para cima ou para baixo.
## - Portas (D4-03): o agente avisa com link_reached ao chegar a um NavLink_<door_id>. Porta fechada: Door.interact com
##   este inimigo como ator (ruído de 50 dB sai da própria porta). O agente espera a porta abrir. Se a porta relata
##   bloqueio (o painel encosta no inimigo, camadas 2, 3 e 4), o inimigo recua RETREAT_M para fora do arco e espera de
##   novo: a porta nunca empurra nem prende o inimigo. Porta trancada não é rota (EnemyDoorLinkGate).
## - Passos (PHY-12 e legendas): a cada STRIDE_*_M percorrido no chão, FOOTSTEP (andar) ou RUNNING (perseguição), com o
##   modificador de superfície de NoiseLevels. A marcha vem da velocidade do intent e do perfil.
## - reset_to: cérebro novo, semente do RNG de volta ao valor inicial, posição de spawn, captura rearmada. Estado
##   inicial que não é PATROL vira PATROL com Log.warn (só a patrulha existe na F4).
## - Inspeção (AI-08, ENM-INV-2): o esconderijo é um nó do grupo "hideable" com metadado persist_id e um método
##   inspect(by_enemy_id) -> bool (contrato da F5). Achou: um VisualPercept na posição do esconderijo, entregue no tick
##   seguinte. Não achou: nada. Na F4 não há esconderijos, então esta via não é exercitada no jogo.
## Autor: AI Engineer (F4-004).

const GROUP: StringName = &"enemy"
const PROCESS_PRIORITY: int = -40
const LOG_CATEGORY: StringName = &"enemy"
const SOURCE_PREFIX: String = "enemy_"
const PATROL_GROUP: StringName = &"patrol_point"
const HIDEABLE_GROUP: StringName = &"hideable"
const ROUTE_META: StringName = &"route_id"
const ORDER_META: StringName = &"order"
const PERSIST_META: StringName = &"persist_id"
const DOOR_LINK_META: StringName = &"door_id"
const NOISE_LEVELS: NoiseLevels = preload("res://content/data/acoustics/noise_levels.tres")
const WORLD_STATIC_MASK: int = 1
const SURFACE_META: StringName = &"surface"
const DEFAULT_SURFACE: StringName = &"concrete"
const RUN_GAIT: StringName = &"run"
const WALK_GAIT: StringName = &"walk"
const SLOW_GAIT: StringName = &"slow"
const STRIDE_SLOW_M: float = 0.6
const STRIDE_WALK_M: float = 0.7
const STRIDE_RUN_M: float = 1.1
const SPEED_EPSILON: float = 0.001
const LOOK_EPSILON_M: float = 0.001
const PITCH_MAX_DEG: float = 30.0
const TARGET_EPSILON_M: float = 0.05
const MAP_WAIT_LIMIT_FRAMES: int = 120
const MAP_SETTLE_FRAMES: int = 2
## Sincronismos antes de o mapa responder a caminho: com a região já registrada, o primeiro sincronismo (iteration 1)
## ainda dá map_get_path vazio para pontos da malha (medido: o cérebro caía em SEARCH no primeiro tick).
const MAP_MIN_ITERATION: int = 2
const DOOR_RETREAT_M: float = 0.8
const DOOR_ARRIVE_M: float = 0.2
const RETREAT_SPEED_MS: float = 1.0
## Visibilidade de uma inspeção que achou o jogador (AI-08): inspeção de perto não deixa dúvida para a confirmação.
const INSPECTION_VISIBILITY: float = 1.0

enum DoorPassage { NONE, WAIT, RETREAT }

## Estado mudou (entre ticks). Para a apresentação e a telemetria.
signal state_changed(old_state: Enums.EnemyState, new_state: Enums.EnemyState)
## O inimigo capturou o jogador (CHASE e sobreposição). Repassado pelo EventBus.player_captured.
signal player_caught()

## Identificador do inimigo (grupo de falas e captura). Base da fonte de som: "enemy_<enemy_id>".
@export var enemy_id: StringName = &"observer"
## Perfil de IA (content/data/ai/*.tres). Sem perfil: AIProfile padrão e Log.error.
@export var profile: AIProfile
## Rota de patrulha: marcadores com este route_id.
@export var route_id: StringName = &"observer"
## Semente do RNG do inimigo (cérebro e amostragem de busca). Mesma semente, mesmo comportamento.
@export var brain_seed: int = 1

@onready var _eye: VisionSensor = $Eye
@onready var _hearing: HearingSensor = $HearingSensor
@onready var _noise: NoiseEmitter = $NoiseEmitter
@onready var _nav: NavigationAgent3D = $NavigationAgent3D
@onready var _capture: EnemyCaptureArea = $CaptureArea

var _brain: EnemyBrain = null
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _world_query: EnemyWorldQuery = null
var _route: PackedVector3Array = PackedVector3Array()
var _known_state: Enums.EnemyState = Enums.EnemyState.PATROL
var _pending_percepts: Array[VisualPercept] = []
var _last_batch: PerceptBatch = null
var _last_intent: EnemyIntent = null
var _nav_target: Vector3 = Vector3.ZERO
var _has_nav_target: bool = false
var _map_wait_frames: int = 0
var _map_settled_frames: int = 0
var _map_wait_reported: bool = false
var _gravity: float = 9.8
var _stride_m: float = 0.0
var _door_id: StringName = &""
var _door_entry: Vector3 = Vector3.ZERO
var _door_mid: Vector3 = Vector3.ZERO
var _retreat_point: Vector3 = Vector3.ZERO
var _has_retreat: bool = false
var _passage: DoorPassage = DoorPassage.NONE
var _doors: Dictionary = {}
var _source_id: StringName = &""


func _ready() -> void:
	add_to_group(GROUP)
	process_physics_priority = PROCESS_PRIORITY
	if profile == null:
		Log.error(LOG_CATEGORY, "EnemyController '%s' sem AIProfile; usando o padrão" % [name])
		profile = AIProfile.new()
	_source_id = _make_source_id()
	_apply_profile()
	_gravity = float(ProjectSettings.get_setting("physics/3d/default_gravity", 9.8))
	_nav.avoidance_enabled = false
	_nav.target_desired_distance = minf(_nav.target_desired_distance, EnemyBrain.ARRIVAL_RADIUS_M)
	_nav.link_reached.connect(_on_link_reached)
	_capture.player_caught.connect(_on_capture_area_caught)
	_route = _collect_route()
	if _route.is_empty():
		Log.error(LOG_CATEGORY, "EnemyController '%s': rota '%s' sem marcadores" % [name, route_id])
	_rng.seed = brain_seed
	_brain = EnemyBrain.new(profile, _rng)
	_world_query = EnemyWorldQuery.new(self, _nav.get_navigation_map(), _rng)
	_known_state = _brain.state


func _physics_process(delta: float) -> void:
	tick(delta)


## Um tick de IA: percepts, cérebro, intent. Chamado pelo tick de física (-40); os testes chamam direto.
func tick(delta: float) -> void:
	if not _navigation_ready():
		return
	var batch: PerceptBatch = _build_batch()
	var intent: EnemyIntent = _brain.tick(delta, batch, _world_query)
	_last_batch = batch
	_last_intent = intent
	if intent.inspect_hideable != &"":
		inspect_hideable(intent.inspect_hideable)
	if intent.voice_line != &"":
		_speak(intent.voice_line)
	_set_nav_target(intent.move_target)
	_look(intent.look_target)
	_drive(intent.move_speed, delta)
	_update_state_events()


## Estado atual do cérebro (lido pela captura e pela apresentação).
func get_state() -> Enums.EnemyState:
	return _brain.state


## Rota de patrulha em ordem (posições globais). Usada pelo EnemyWorldQuery.
func patrol_route() -> PackedVector3Array:
	return _route


## Último lote de percepts montado (teste e depuração). Vazio antes do primeiro tick.
func last_batch() -> PerceptBatch:
	return _last_batch


## Último intent aplicado (teste e depuração).
func last_intent() -> EnemyIntent:
	return _last_intent


## Volta ao estado inicial (CheckpointManager, F5). Cérebro novo; o RNG volta à semente de brain_seed.
func reset_to(initial: EnemyInitialState) -> void:
	if initial == null:
		Log.error(LOG_CATEGORY, "EnemyController.reset_to sem EnemyInitialState; nada feito")
		return
	if initial.state != Enums.EnemyState.PATROL:
		Log.warn(LOG_CATEGORY, "EnemyController '%s': estado inicial %d não existe na F4; usando PATROL" % [name, initial.state])
	_rng.seed = brain_seed
	_brain = EnemyBrain.new(profile, _rng)
	_world_query = EnemyWorldQuery.new(self, _nav.get_navigation_map(), _rng)
	global_position = initial.spawn_position
	velocity = Vector3.ZERO
	_pending_percepts.clear()
	# Revisão F4-010, R4-07: sons ouvidos antes do reset não chegam ao cérebro novo.
	_hearing.drain()
	_clear_passage()
	_has_nav_target = false
	_stride_m = 0.0
	_last_batch = null
	_last_intent = null
	_capture.rearm()
	_update_state_events()


## ENM-INV-2 (AI-08): converte o resultado de uma inspeção em percepts. Achou: exatamente um VisualPercept na posição
## do esconderijo. Não achou: nenhum. Função pura: não toca o cérebro nem o jogador.
static func percepts_from_inspection(found: bool, hideable_position: Vector3, time_s: float) -> Array[VisualPercept]:
	var out: Array[VisualPercept] = []
	if found:
		out.append(VisualPercept.create(INSPECTION_VISIBILITY, hideable_position, time_s))
	return out


## Marcha do passo pela velocidade comandada: correr (perseguição), andar (acima da patrulha) ou devagar.
func gait_for_speed(speed: float) -> StringName:
	if speed >= profile.chase_speed - SPEED_EPSILON:
		return RUN_GAIT
	if speed > profile.patrol_speed + SPEED_EPSILON:
		return WALK_GAIT
	return SLOW_GAIT


## Distância entre passos (m) para cada marcha.
static func stride_for_gait(gait: StringName) -> float:
	if gait == RUN_GAIT:
		return STRIDE_RUN_M
	if gait == WALK_GAIT:
		return STRIDE_WALK_M
	return STRIDE_SLOW_M


## Superfície (metadado "surface" do piso) reduzida às quatro do NoiseLevels. Desconhecida ou ausente: concreto.
static func normalise_surface(surface: StringName) -> StringName:
	if surface == &"wood" or surface == &"carpet" or surface == &"tile" or surface == &"concrete":
		return surface
	return DEFAULT_SURFACE


func _apply_profile() -> void:
	_eye.sight_range_m = profile.sight_range_m
	_eye.fov_deg = profile.fov_deg
	_hearing.hearing_threshold_db = profile.hearing_threshold_db
	_hearing.masking_margin_db = profile.masking_margin_db
	_hearing.owner_id = _source_id
	_noise.source_id = _source_id


func _make_source_id() -> StringName:
	var id_text: String = String(enemy_id)
	if id_text.is_empty():
		Log.error(LOG_CATEGORY, "EnemyController '%s' sem enemy_id; fonte 'enemy_unnamed'" % [name])
		id_text = "unnamed"
	return StringName(SOURCE_PREFIX + id_text)


## Espera o mapa de navegação sincronizar e assentar: o primeiro sincronismo (iteration > 0) ainda não responde a
## map_get_path para pontos fora do vértice inicial; MAP_SETTLE_FRAMES frames de física depois, responde (o mesmo
## cuidado do teste da sandbox, F4-008). Depois de MAP_WAIT_LIMIT_FRAMES sem sincronismo, segue com erro.
func _navigation_ready() -> bool:
	var map: RID = _nav.get_navigation_map()
	# Pronto = o mapa sincronizou e já tem região. Um sincronismo sem região (a NavigationRegion3D ainda não entrou no mapa)
	# dá map_get_closest_point = origem e map_get_path vazio: o cérebro cairia em SEARCH sem investigar.
	if NavigationServer3D.map_get_iteration_id(map) >= MAP_MIN_ITERATION and not NavigationServer3D.map_get_regions(map).is_empty():
		# Sincronização forçada enquanto assenta, uma vez por frame: o primeiro tick só consulta caminho com o mapa estável.
		_map_settled_frames += 1
		if _map_settled_frames <= MAP_SETTLE_FRAMES:
			NavigationServer3D.map_force_update(map)
			return false
		return true
	NavigationServer3D.map_force_update(map)
	_map_wait_frames += 1
	if _map_wait_frames < MAP_WAIT_LIMIT_FRAMES:
		return false
	if not _map_wait_reported:
		_map_wait_reported = true
		Log.error(LOG_CATEGORY, "EnemyController '%s': mapa de navegação sem sincronismo; seguindo sem navmesh" % [name])
	return true


## Percepts do tick (passos 1 a 3 do tick de IA).
func _build_batch() -> PerceptBatch:
	var batch: PerceptBatch = PerceptBatch.new()
	# Verificação F4-010, N1: só o VisionSensor conhece os alvos perceptíveis (FW-INV-1).
	batch.visual = _eye.evaluate_all(_scope())
	batch.heard = _hearing.drain()
	for percept: VisualPercept in _pending_percepts:
		batch.visual.append(percept)
	_pending_percepts.clear()
	return batch


## Alvo do agente: projetado na malha (uma pista de som pode vir na altura da fonte) e reposto só quando muda, para não
## refazer o caminho a cada tick.
func _set_nav_target(target: Vector3) -> void:
	var on_mesh: Vector3 = NavigationServer3D.map_get_closest_point(_nav.get_navigation_map(), target)
	if _has_nav_target and on_mesh.distance_to(_nav_target) <= TARGET_EPSILON_M:
		return
	_nav_target = on_mesh
	_has_nav_target = true
	_nav.target_position = on_mesh


## Olhar: o corpo gira no plano para o alvo, e o olho inclina até PITCH_MAX_DEG.
func _look(target: Vector3) -> void:
	var flat: Vector3 = Vector3(target.x - global_position.x, 0.0, target.z - global_position.z)
	var flat_length: float = flat.length()
	if flat_length > LOOK_EPSILON_M:
		rotation.y = atan2(-flat.x, -flat.z)
	var rise: float = target.y - _eye.global_position.y
	var pitch: float = atan2(rise, flat_length)
	_eye.rotation.x = clampf(pitch, -deg_to_rad(PITCH_MAX_DEG), deg_to_rad(PITCH_MAX_DEG))


## Movimento: passagem por porta (espera ou recuo) ou o próximo ponto do caminho, então física do corpo e passos.
func _drive(speed: float, delta: float) -> void:
	_update_passage()
	var horizontal: Vector3 = Vector3.ZERO
	if _passage == DoorPassage.RETREAT:
		horizontal = _toward(_retreat_point, RETREAT_SPEED_MS)
		if _flat_distance(global_position, _retreat_point) <= DOOR_ARRIVE_M:
			_passage = DoorPassage.WAIT
			horizontal = Vector3.ZERO
	elif _passage == DoorPassage.NONE and speed > SPEED_EPSILON and not _nav.is_navigation_finished():
		horizontal = _toward(_nav.get_next_path_position(), speed)
	velocity.x = horizontal.x
	velocity.z = horizontal.z
	if is_on_floor():
		velocity.y = 0.0
	else:
		velocity.y -= _gravity * delta
	var before: Vector3 = global_position
	move_and_slide()
	_accumulate_steps(before, speed)


func _toward(point: Vector3, speed: float) -> Vector3:
	var flat: Vector3 = Vector3(point.x - global_position.x, 0.0, point.z - global_position.z)
	if flat.length() <= SPEED_EPSILON:
		return Vector3.ZERO
	return flat.normalized() * speed


## Estado da passagem por porta a cada tick. Link de porta que o agente alcançou (link_reached) aciona a passagem.
func _update_passage() -> void:
	if _door_id == &"":
		_passage = DoorPassage.NONE
		return
	var door: Door = _door_for(_door_id)
	if door == null or door.get_state() == Door.State.LOCKED:
		_clear_passage()
		return
	if door.get_state() == Door.State.CLOSED:
		_open_door(door)
	if door.is_moving():
		if door.is_blocked():
			_begin_retreat()
		elif _passage != DoorPassage.RETREAT:
			_passage = DoorPassage.WAIT
		return
	_clear_passage()


## Porta bloqueada pelo inimigo: recua para fora do arco do painel (uma vez por bloqueio).
func _begin_retreat() -> void:
	if not _has_retreat:
		var away: Vector3 = Vector3(_door_entry.x - _door_mid.x, 0.0, _door_entry.z - _door_mid.z)
		if away.length() <= SPEED_EPSILON:
			_passage = DoorPassage.WAIT
			return
		_retreat_point = _door_entry + away.normalized() * DOOR_RETREAT_M
		_has_retreat = true
	_passage = DoorPassage.RETREAT


func _open_door(door: Door) -> void:
	var context: InteractionContext = InteractionContext.new()
	context.actor = self
	context.held = false
	door.interact(context)


func _clear_passage() -> void:
	_door_id = &""
	_passage = DoorPassage.NONE
	_has_retreat = false


## NavigationAgent3D.link_reached: o agente chegou a um link. Só porta (metadado door_id) interessa; outros links são
## atravessados sem parar. A passagem começa com a posição de entrada e o centro do link (o vão).
func _on_link_reached(details: Dictionary) -> void:
	var link: NavigationLink3D = _link_from_details(details)
	if link == null or not link.has_meta(DOOR_LINK_META):
		return
	var door_id: StringName = StringName(str(link.get_meta(DOOR_LINK_META)))
	if door_id == _door_id:
		return
	_door_id = door_id
	_door_entry = global_position
	var start: Vector3 = link.global_transform * link.start_position
	var end: Vector3 = link.global_transform * link.end_position
	_door_mid = (start + end) * 0.5
	_has_retreat = false
	_passage = DoorPassage.WAIT


## Link do details (chave "owner" do NavigationAgent3D). Sem o nó, null.
func _link_from_details(details: Dictionary) -> NavigationLink3D:
	var owner_value: Variant = details.get("owner")
	return owner_value as NavigationLink3D


## Porta do nível pelo door_id (Door com esse id no ramo do pai). Cache depois da primeira busca.
func _door_for(door_id: StringName) -> Door:
	if _doors.has(door_id):
		return _doors[door_id] as Door
	var found: Door = _find_door(_scope(), door_id)
	if found == null:
		Log.error(LOG_CATEGORY, "EnemyController '%s': porta '%s' não encontrada no nível" % [name, door_id])
		return null
	_doors[door_id] = found
	return found


func _find_door(node: Node, door_id: StringName) -> Door:
	if node == null:
		return null
	var door: Door = node as Door
	if door != null and door.door_id == door_id:
		return door
	for child: Node in node.get_children():
		var hit: Door = _find_door(child, door_id)
		if hit != null:
			return hit
	return null


## Fala do Observer: uma vez por transição (EnemyIntent.voice_line). Grito na perseguição (75 dB), fala (55 dB).
func _speak(voice_line: StringName) -> void:
	var level_db: float = NOISE_LEVELS.voice_talk_db
	if voice_line == EnemyBrain.VOICE_CHASE:
		level_db = NOISE_LEVELS.voice_shout_db
	_noise.emit_noise(Enums.NoiseCategory.VOICE, level_db, 0.0, voice_line)


## Inspeção de esconderijo (ENM-INV-2): pergunta ao esconderijo e guarda o resultado como percept para o próximo tick.
## Chamada pelo tick quando o intent pede (inspect_hideable); pública para os testes de AI-08.
func inspect_hideable(persist_id: StringName) -> void:
	var hideable: Node3D = _find_hideable(persist_id)
	if hideable == null:
		Log.error(LOG_CATEGORY, "EnemyController '%s': esconderijo '%s' não encontrado" % [name, persist_id])
		return
	var found: bool = _ask_inspection(hideable)
	_pending_percepts.append_array(percepts_from_inspection(found, hideable.global_position, _now_s()))


func _find_hideable(persist_id: StringName) -> Node3D:
	var scope: Node = _scope()
	for node: Node in get_tree().get_nodes_in_group(HIDEABLE_GROUP):
		var hideable: Node3D = node as Node3D
		if hideable == null or scope == null or not scope.is_ancestor_of(hideable):
			continue
		if hideable.has_meta(PERSIST_META) and StringName(str(hideable.get_meta(PERSIST_META))) == persist_id:
			return hideable
	return null


## Chama inspect(by_enemy_id) do esconderijo. Sem o método: erro e nenhum percept.
func _ask_inspection(hideable: Node) -> bool:
	if not hideable.has_method(&"inspect"):
		Log.error(LOG_CATEGORY, "esconderijo '%s' sem inspect(by_enemy_id)" % [hideable.name])
		return false
	return bool(hideable.call(&"inspect", enemy_id))


## Passos: a cada stride percorrido no chão. Marcha pela velocidade comandada; superfície do piso sob o corpo.
func _accumulate_steps(from: Vector3, speed: float) -> void:
	if not is_on_floor():
		return
	var moved: float = _flat_distance(global_position, from)
	if moved <= 0.0:
		return
	_stride_m += moved
	var gait: StringName = gait_for_speed(speed)
	var stride: float = stride_for_gait(gait)
	if _stride_m < stride:
		return
	_stride_m -= stride
	_emit_step(gait)


func _emit_step(gait: StringName) -> void:
	var surface: StringName = _surface_under()
	var sound: StringName = StringName("footstep_" + String(surface))
	if gait == RUN_GAIT:
		_noise.emit_noise(Enums.NoiseCategory.RUNNING, NOISE_LEVELS.running_level(_level_surface(surface)), 0.0, sound)
		return
	_noise.emit_noise(Enums.NoiseCategory.FOOTSTEP, NOISE_LEVELS.footstep_level(gait, _level_surface(surface)), 0.0, sound)


## Superfície do NoiseLevels: madeira ("wood") é madeira solta (+6 dB); os demais valem como estão.
static func _level_surface(surface: StringName) -> StringName:
	if surface == &"wood":
		return &"wood_loose"
	return surface


func _surface_under() -> StringName:
	var origin: Vector3 = global_position
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
		origin + Vector3.UP * 0.05, origin + Vector3.DOWN * 0.15, WORLD_STATIC_MASK, [get_rid()])
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return DEFAULT_SURFACE
	var collider: Object = hit.get("collider") as Object
	if collider == null or not collider.has_meta(SURFACE_META):
		return DEFAULT_SURFACE
	return normalise_surface(StringName(str(collider.get_meta(SURFACE_META))))


## Estado mudou: sinal local, e EventBus para a telemetria (chase_started / chase_ended).
func _update_state_events() -> void:
	var now: Enums.EnemyState = _brain.state
	if now == _known_state:
		return
	var old: Enums.EnemyState = _known_state
	_known_state = now
	state_changed.emit(old, now)
	if now == Enums.EnemyState.CHASE:
		EventBus.chase_started.emit(enemy_id)
	if old == Enums.EnemyState.CHASE:
		EventBus.chase_ended.emit(enemy_id)


func _on_capture_area_caught() -> void:
	EventBus.player_captured.emit(enemy_id)
	player_caught.emit()


## Escopo do inimigo: o pai (o nível). Marcadores, portas e outros nós do ramo são procurados aqui.
func _scope() -> Node:
	return get_parent() if get_parent() != null else self


func _collect_route() -> PackedVector3Array:
	var by_order: Dictionary = {}
	var scope: Node = _scope()
	for node: Node in get_tree().get_nodes_in_group(PATROL_GROUP):
		var marker: Node3D = node as Node3D
		if marker == null or scope == null or not scope.is_ancestor_of(marker):
			continue
		if not marker.has_meta(ROUTE_META) or StringName(str(marker.get_meta(ROUTE_META))) != route_id:
			continue
		var order: int = int(marker.get_meta(ORDER_META, -1))
		if by_order.has(order):
			Log.error(LOG_CATEGORY, "rota '%s': ordem %d repetida em '%s'" % [route_id, order, marker.name])
		by_order[order] = marker.global_position
	var orders: Array[int] = []
	orders.assign(by_order.keys())
	orders.sort()
	var route: PackedVector3Array = PackedVector3Array()
	for order: int in orders:
		route.append(by_order[order] as Vector3)
	return route


func _now_s() -> float:
	return float(Engine.get_physics_frames()) / float(maxi(Engine.physics_ticks_per_second, 1))


static func _flat_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()

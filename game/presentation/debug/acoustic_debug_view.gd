class_name AcousticDebugView
extends Node3D
## Visão de debug acústica (L3, F3-008; ROADMAP Fase 3). Desenha por cima do nível, com ImmediateMesh e sem sombra
## nem colisão:
##   - o grafo: cada RoomVolume como caixa em arame, com cor pelo piso de ruído da sala;
##   - cada Portal como marcador na sua posição: verde se aberto, vermelho se fechado. O estado é lido ao vivo do
##     AcousticGraph do AcousticWorld (is_portal_open), então abrir ou fechar a porta muda a cor no mesmo quadro;
##   - anéis horizontais no chão, um por ruído resolvido para o jogador (AcousticWorld.noise_resolved_for_player).
##     Raio = alcance em campo livre até o limiar do ouvinte (DATA_STRUCTURES §2.2, sem paredes), cor por categoria,
##     some em RING_LIFETIME_S. Evento com raio 0 (inaudível em campo livre) não cria anel.
## Liga e desliga com F5, só quando DebugCommands.is_allowed(). Em produção nasce desligada, não processa, não lê
## entrada e não conecta o sinal do AcousticWorld. Desligada, não redesenha e não acumula anéis.
## É observadora: só lê o AcousticWorld (grupo acoustic_world) e os RoomVolume e Portal do mesmo nível (COMPONENT_CONTRACTS §6.6).

const TOGGLE_KEY: int = KEY_F5
const LOG_CATEGORY: StringName = &"acoustics"

## Vida de um anel (s). Some depois disso; o alfa cai linearmente.
const RING_LIFETIME_S: float = 1.5
## Limite de anéis simultâneos; ao passar, sai o mais antigo.
const MAX_RINGS: int = 32
const RING_SEGMENTS: int = 48
const RING_ALPHA: float = 0.9
## Anel levemente acima do piso, para não sumir no z-fighting.
const RING_LIFT_M: float = 0.05
## Piso sob o evento: raio de busca para baixo e folga para cima do ponto de partida.
const FLOOR_SEARCH_M: float = 10.0
const FLOOR_PROBE_UP_M: float = 0.5
## Mesma máscara do DebugCommands (camadas 1 e 2: mundo e objetos); o jogador (camada 4) fica de fora.
const FLOOR_MASK: int = 3
const PORTAL_MARKER_HEIGHT_M: float = 2.0
const PORTAL_MARKER_ARM_M: float = 0.3
## Busca do raio: 60 bisseções dão precisão muito além de um centímetro.
const RADIUS_SEARCH_ITERATIONS: int = 60
const MAX_RING_RADIUS_M: float = 1000.0

const OPEN_COLOR: Color = Color(0.2, 0.9, 0.3)
const CLOSED_COLOR: Color = Color(0.95, 0.2, 0.2)
## Piso de ruído das salas: do silencioso (12 dB, porão) ao exterior (38 dB) (DATA §2.3).
const ROOM_QUIET_DB: float = 12.0
const ROOM_LOUD_DB: float = 38.0
const ROOM_QUIET_COLOR: Color = Color(0.3, 0.6, 1.0)
const ROOM_LOUD_COLOR: Color = Color(1.0, 0.6, 0.2)

var _wires: MeshInstance3D = null
var _mesh: ImmediateMesh = null
var _material: StandardMaterial3D = null
var _rings: Array[_Ring] = []
var _rooms: Array[_RoomRecord] = []
var _portals: Array[_PortalRecord] = []
var _world: AcousticWorld = null
var _config: AcousticConfig = null
var _shown_portal_open: Dictionary = {}
var _dirty: bool = false
var _warned_no_world: bool = false


## Anel ativo no chão: centro (com o Y do piso), raio em metros, cor e tempo restante.
class _Ring extends RefCounted:
	var center: Vector3 = Vector3.ZERO
	var radius_m: float = 0.0
	var color: Color = Color.WHITE
	var remaining_s: float = 0.0


## Sala lida do RoomVolume: id, AABB no mundo e piso de ruído (o da configuração da sala).
class _RoomRecord extends RefCounted:
	var id: StringName = &""
	var bounds: AABB = AABB()
	var floor_db: float = 0.0


class _PortalRecord extends RefCounted:
	var id: StringName = &""
	var position: Vector3 = Vector3.ZERO


func _ready() -> void:
	top_level = true
	_mesh = ImmediateMesh.new()
	_material = StandardMaterial3D.new()
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.vertex_color_use_as_albedo = true
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	# Overlay de depuração: portais e anéis aparecem mesmo atrás de paredes e pisos (sem teste de profundidade).
	_material.no_depth_test = true
	_wires = MeshInstance3D.new()
	_wires.mesh = _mesh
	_wires.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_wires)
	visible = false
	set_process(false)
	if not DebugCommands.is_allowed():
		set_process_unhandled_input(false)


func _exit_tree() -> void:
	_disconnect_world()


func _unhandled_input(event: InputEvent) -> void:
	var key: InputEventKey = event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	if key.physical_keycode == TOGGLE_KEY:
		toggle_view()
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	tick(delta)


## Avança os anéis e redesenha quando algo mudou (anel, expiração ou estado de portal). Chamado por _process;
## os testes chamam direto, para não esperar 1,5 s de quadros.
func tick(delta: float) -> void:
	if not visible:
		return
	for index: int in range(_rings.size() - 1, -1, -1):
		_rings[index].remaining_s -= delta
		if _rings[index].remaining_s <= 0.0:
			_rings.remove_at(index)
	var portals_changed: bool = _portal_states_changed()
	if not _rings.is_empty() or portals_changed:
		_dirty = true
	if _dirty:
		_rebuild()


## Alterna a visão. Em produção recusa e devolve false. Devolve o novo estado de visibilidade.
func toggle_view() -> bool:
	if not DebugCommands.is_allowed():
		_switch_off()
		return false
	if visible:
		_switch_off()
	else:
		_switch_on()
	return visible


func is_view_visible() -> bool:
	return visible


func get_ring_count() -> int:
	return _rings.size()


func get_room_count() -> int:
	return _rooms.size()


## Cor de cada portal do nível, pelo id (StringName): OPEN_COLOR se aberto, CLOSED_COLOR se fechado. Lê o estado ao vivo.
func get_portal_colors() -> Dictionary:
	var colors: Dictionary = {}
	for portal: _PortalRecord in _portals:
		colors[portal.id] = portal_color_for(_read_portal_open(portal.id))
	return colors


## Raio do anel (m) pela fórmula de DATA_STRUCTURES §2.2 em campo livre, sem paredes:
##   perda(d) = 20·log10(max(d; min_distance_m)) + extra_loss_per_m_db·d
## O anel vai até a distância em que a perda chega à margem = intensidade − limiar. Abaixo ou igual ao limiar, 0.
## Função pura (sem Node nem estado), testável. Casos com a config padrão (min 1 m, 0,1 dB/m), contas à mão:
##   margem 0,05 dB: 0,1·d = 0,05 → d = 0,5 m (dentro de 1 m, só a perda por metro conta);
##   margem 20 dB: 20·log10(d) + 0,1·d = 20 → d ≈ 9,01 m (d = 9: 19,085 + 0,9 = 19,985; d = 9,014: 20,000);
##   margem 30 dB (tosse 65 dB, limiar 35): d ≈ 23,99 m, o "≈ 24 m" de DATA §2.3;
##   margem 40 dB: 20·log10(d) + 0,1·d = 40 → d ≈ 53,82 m (d = 53,82: 34,618 + 5,382 = 40,000).
## Monotonia: margem maior dá raio maior; margem ≤ 0 dá 0.
static func ring_radius_for(intensity_db: float, threshold_db: float, config: AcousticConfig) -> float:
	var margin_db: float = intensity_db - threshold_db
	if margin_db <= 0.0:
		return 0.0
	var cfg: AcousticConfig = config if config != null else AcousticConfig.new()
	if _free_field_loss_db(0.0, cfg) >= margin_db:
		return 0.0
	var high: float = 1.0
	while _free_field_loss_db(high, cfg) < margin_db:
		if high >= MAX_RING_RADIUS_M:
			return MAX_RING_RADIUS_M
		high = minf(high * 2.0, MAX_RING_RADIUS_M)
	var low: float = 0.0
	for _step: int in range(RADIUS_SEARCH_ITERATIONS):
		var middle: float = 0.5 * (low + high)
		if _free_field_loss_db(middle, cfg) < margin_db:
			low = middle
		else:
			high = middle
	return 0.5 * (low + high)


## Cor do anel por categoria de ruído (uma cor distinta para cada uma das 11 categorias).
static func ring_color_for(category: Enums.NoiseCategory) -> Color:
	match category:
		Enums.NoiseCategory.FOOTSTEP:
			return Color(0.85, 0.85, 0.85)
		Enums.NoiseCategory.RUNNING:
			return Color(1.0, 0.5, 0.1)
		Enums.NoiseCategory.BREATHING:
			return Color(0.3, 0.9, 0.9)
		Enums.NoiseCategory.WHEEZING:
			return Color(0.1, 0.6, 0.6)
		Enums.NoiseCategory.COUGHING:
			return Color(0.9, 0.3, 0.9)
		Enums.NoiseCategory.DOOR:
			return Color(1.0, 0.85, 0.2)
		Enums.NoiseCategory.OBJECT_IMPACT:
			return Color(0.7, 0.5, 0.3)
		Enums.NoiseCategory.MEDICATION:
			return Color(0.5, 0.8, 0.4)
		Enums.NoiseCategory.FURNITURE:
			return Color(0.5, 0.5, 0.8)
		Enums.NoiseCategory.FALL:
			return Color(1.0, 0.2, 0.2)
		Enums.NoiseCategory.VOICE:
			return Color(1.0, 1.0, 0.6)
	return Color.WHITE


## Cor da caixa da sala pelo piso de ruído: azul no silêncio, laranja no exterior (interpolação linear e limitada).
static func room_color_for_floor(floor_db: float) -> Color:
	var weight: float = clampf((floor_db - ROOM_QUIET_DB) / (ROOM_LOUD_DB - ROOM_QUIET_DB), 0.0, 1.0)
	return ROOM_QUIET_COLOR.lerp(ROOM_LOUD_COLOR, weight)


static func portal_color_for(open: bool) -> Color:
	if open:
		return OPEN_COLOR
	return CLOSED_COLOR


static func _free_field_loss_db(distance_m: float, config: AcousticConfig) -> float:
	var clamped: float = maxf(distance_m, config.min_distance_m)
	return 20.0 * log(clamped) / log(10.0) + config.extra_loss_per_m_db * distance_m


func _switch_on() -> void:
	_collect_level()
	_config = _config_for_world()
	if _world != null and not _world.noise_resolved_for_player.is_connected(_on_noise_resolved):
		_world.noise_resolved_for_player.connect(_on_noise_resolved)
	visible = true
	set_process(true)
	_dirty = true
	_rebuild()


func _switch_off() -> void:
	_disconnect_world()
	visible = false
	set_process(false)
	_rings.clear()
	_rooms.clear()
	_portals.clear()
	_shown_portal_open.clear()
	_dirty = false
	_mesh.clear_surfaces()


func _disconnect_world() -> void:
	if _world != null and is_instance_valid(_world) and _world.noise_resolved_for_player.is_connected(_on_noise_resolved):
		_world.noise_resolved_for_player.disconnect(_on_noise_resolved)
	_world = null


## Ruído resolvido: cria o anel no chão em volta da fonte. Só com a visão ligada (o sinal só está conectado nesse caso).
func _on_noise_resolved(event: NoiseEvent, _result: PropagationResult) -> void:
	if not visible or _world == null or event == null:
		return
	var threshold_db: float = _world.player_threshold_db(_listener_position())
	var radius_m: float = ring_radius_for(event.intensity_db, threshold_db, _config)
	if radius_m <= 0.0:
		return
	var ring: _Ring = _Ring.new()
	var floor_y: float = _floor_y_below(event.position)
	ring.center = Vector3(event.position.x, floor_y + RING_LIFT_M, event.position.z)
	ring.radius_m = radius_m
	ring.color = ring_color_for(event.category)
	ring.remaining_s = RING_LIFETIME_S
	if _rings.size() >= MAX_RINGS:
		_rings.remove_at(0)
	_rings.append(ring)
	_dirty = true


## Ouvido do jogador para o limiar: a câmera ativa (o mesmo ouvido que o PlayerRoot registra no AcousticWorld).
func _listener_position() -> Vector3:
	if not is_inside_tree() or get_viewport() == null:
		return Vector3.ZERO
	var camera: Camera3D = get_viewport().get_camera_3d()
	if camera == null:
		return Vector3.ZERO
	return camera.global_position


## Altura do piso sob o ponto (raio para baixo). Sem piso encontrado, usa a altura do ponto.
func _floor_y_below(point: Vector3) -> float:
	if not is_inside_tree():
		return point.y
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
		point + Vector3.UP * FLOOR_PROBE_UP_M, point + Vector3.DOWN * FLOOR_SEARCH_M, FLOOR_MASK)
	var hit: Dictionary = space.intersect_ray(query)
	if hit.is_empty():
		return point.y
	return (hit.get("position", point) as Vector3).y


func _config_for_world() -> AcousticConfig:
	if _world != null and _world.config != null:
		return _world.config
	var loaded: AcousticConfig = load(AcousticWorld.CONFIG_PATH) as AcousticConfig
	if loaded != null:
		return loaded
	return AcousticConfig.new()


## Lê o AcousticWorld, as salas (RoomVolume) e os portais (Portal) do mesmo nível que o mundo.
func _collect_level() -> void:
	_rooms.clear()
	_portals.clear()
	_shown_portal_open.clear()
	_world = _find_world()
	var scope: Node = _scope()
	if scope == null:
		return
	for node: Node in get_tree().get_nodes_in_group(RoomVolume.GROUP):
		var room: RoomVolume = node as RoomVolume
		if room == null or not scope.is_ancestor_of(room):
			continue
		var bounds: AABB = room.bounds_world()
		if bounds.size.x <= 0.0 or bounds.size.y <= 0.0 or bounds.size.z <= 0.0:
			continue
		var room_record: _RoomRecord = _RoomRecord.new()
		room_record.id = room.room_id
		room_record.bounds = bounds
		room_record.floor_db = room.ambient_floor_db
		_rooms.append(room_record)
	for node: Node in get_tree().get_nodes_in_group(Portal.GROUP):
		var portal: Portal = node as Portal
		if portal == null or not scope.is_ancestor_of(portal):
			continue
		var portal_record: _PortalRecord = _PortalRecord.new()
		portal_record.id = portal.portal_id
		portal_record.position = portal.global_position
		_portals.append(portal_record)


## O AcousticWorld do nível: o que é irmão de um ancestral desta visão, ou o primeiro do grupo.
func _find_world() -> AcousticWorld:
	if not is_inside_tree():
		return null
	var found: AcousticWorld = null
	for node: Node in get_tree().get_nodes_in_group(AcousticWorld.GROUP):
		var world: AcousticWorld = node as AcousticWorld
		if world == null:
			continue
		if found == null:
			found = world
		var scope: Node = world.get_parent() if world.get_parent() != null else world
		if scope.is_ancestor_of(self):
			return world
	if found == null and not _warned_no_world:
		_warned_no_world = true
		Log.warn(LOG_CATEGORY, "AcousticDebugView sem AcousticWorld no nível; grafo e anéis indisponíveis")
	return found


## Nível da cena: o pai do AcousticWorld (onde ficam os RoomVolume e os Portal), ou o pai desta visão.
func _scope() -> Node:
	if _world != null and _world.get_parent() != null:
		return _world.get_parent()
	return get_parent()


func _read_portal_open(portal_id: StringName) -> bool:
	if _world == null or not is_instance_valid(_world):
		return false
	return _world.get_graph().is_portal_open(portal_id)


## True se algum portal mudou de estado desde o último quadro (e guarda o estado novo).
func _portal_states_changed() -> bool:
	var changed: bool = false
	for portal: _PortalRecord in _portals:
		var open: bool = _read_portal_open(portal.id)
		if not _shown_portal_open.has(portal.id) or (_shown_portal_open[portal.id] as bool) != open:
			changed = true
		_shown_portal_open[portal.id] = open
	return changed


func _rebuild() -> void:
	_dirty = false
	var points: PackedVector3Array = PackedVector3Array()
	var colors: PackedColorArray = PackedColorArray()
	for room: _RoomRecord in _rooms:
		_add_box(points, colors, room.bounds, room_color_for_floor(room.floor_db))
	for portal: _PortalRecord in _portals:
		_add_portal_marker(points, colors, portal.position, portal_color_for(_read_portal_open(portal.id)))
	for ring: _Ring in _rings:
		_add_ring(points, colors, ring)
	_mesh.clear_surfaces()
	if points.is_empty():
		return
	_mesh.surface_begin(Mesh.PRIMITIVE_LINES, _material)
	for index: int in range(points.size()):
		_mesh.surface_set_color(colors[index])
		_mesh.surface_add_vertex(points[index])
	_mesh.surface_end()


func _add_line(points: PackedVector3Array, colors: PackedColorArray, from: Vector3, to: Vector3, color: Color) -> void:
	points.append(from)
	points.append(to)
	colors.append(color)
	colors.append(color)


## As 12 arestas da caixa AABB (vértices indexados por bits x, y, z).
func _add_box(points: PackedVector3Array, colors: PackedColorArray, box: AABB, color: Color) -> void:
	var lo: Vector3 = box.position
	var hi: Vector3 = box.end
	var corners: PackedVector3Array = PackedVector3Array()
	for index: int in range(8):
		corners.append(Vector3(
			hi.x if (index & 1) != 0 else lo.x,
			hi.y if (index & 2) != 0 else lo.y,
			hi.z if (index & 4) != 0 else lo.z))
	for index: int in range(8):
		for axis: int in range(3):
			var bit: int = 1 << axis
			if (index & bit) == 0:
				_add_line(points, colors, corners[index], corners[index | bit], color)


## Marcador de portal: uma haste de PORTAL_MARKER_HEIGHT_M e uma cruz na metade, na cor do estado.
func _add_portal_marker(points: PackedVector3Array, colors: PackedColorArray, base: Vector3, color: Color) -> void:
	_add_line(points, colors, base, base + Vector3.UP * PORTAL_MARKER_HEIGHT_M, color)
	var mid: Vector3 = base + Vector3.UP * (PORTAL_MARKER_HEIGHT_M * 0.5)
	_add_line(points, colors, mid + Vector3.LEFT * PORTAL_MARKER_ARM_M, mid + Vector3.RIGHT * PORTAL_MARKER_ARM_M, color)
	_add_line(points, colors, mid + Vector3.FORWARD * PORTAL_MARKER_ARM_M, mid + Vector3.BACK * PORTAL_MARKER_ARM_M, color)


func _add_ring(points: PackedVector3Array, colors: PackedColorArray, ring: _Ring) -> void:
	var fade: float = clampf(ring.remaining_s / RING_LIFETIME_S, 0.0, 1.0)
	var color: Color = Color(ring.color.r, ring.color.g, ring.color.b, RING_ALPHA * fade)
	var previous: Vector3 = ring.center + Vector3(ring.radius_m, 0.0, 0.0)
	for step: int in range(1, RING_SEGMENTS + 1):
		var angle: float = TAU * float(step) / float(RING_SEGMENTS)
		var current: Vector3 = ring.center + Vector3(cos(angle) * ring.radius_m, 0.0, sin(angle) * ring.radius_m)
		_add_line(points, colors, previous, current, color)
		previous = current

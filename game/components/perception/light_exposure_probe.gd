class_name LightExposureProbe
extends Node3D
## LightExposureProbe (L2, F3-005; DATA_STRUCTURES §9, COMPONENT_CONTRACTS §7.1): exposição 0..1 à luz da cena,
## medida em pontos de amostra (offsets locais ao probe; a exposição final é a média dos pontos).
## Usado pelo jogador (PerceivableTarget, F4) e pelos inimigos (visão, COMPONENT §5).
## Luzes: OmniLight3D e SpotLight3D do mesmo World3D. Atenuação: radial pow(1 - d/alcance, attenuation) (mesma
## forma do Godot sem unidades físicas); cone do spot: pow(t, spot_angle_attenuation) com t de 1 no eixo a 0 na borda.
## Oclusão: raio até a luz contra world_static (1), world_dynamic (2) e vision_occluder (7). O corpo pai (se for
## CollisionObject3D) é ignorado. Corpos de inimigos e do jogador não bloqueiam a luz.
## Amostragem a update_hz; sem alocação por chamada (uma PhysicsRayQueryParameters3D reutilizada).
## Autor: Gameplay Engineer (F3-005).

const OCCLUDER_MASK: int = 67  ## bits 1 (world_static) + 2 (world_dynamic) + 64 (vision_occluder, camada 7)
const SAMPLE_EPSILON_M: float = 0.001  ## abaixo disto, a luz está no ponto: sem raio de oclusão

@export var update_hz: float = 10.0
## Luz mínima do ambiente (0..1): piso da exposição quando nenhuma luz alcança o ponto.
@export_range(0.0, 1.0) var ambient_floor: float = 0.0
## Pontos de amostra em metros, no referencial do probe. A exposição final é a média entre eles.
@export var sample_offsets: PackedVector3Array = PackedVector3Array([Vector3.ZERO])

var _exposure: float = 0.0
var _accum: float = 0.0
var _sample_count: int = 0
var _lights: Array[Light3D] = []
var _lights_dirty: bool = true
var _exclude: Array[RID] = []
var _query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.new()


## Atenuação radial de uma luz em 0..1: 1 no centro, 0 no alcance. attenuation > 1 escurece as bordas mais depressa.
static func radial_factor(distance_m: float, light_range_m: float, attenuation: float) -> float:
	if light_range_m <= 0.0 or distance_m >= light_range_m:
		return 0.0
	return pow(1.0 - maxf(distance_m, 0.0) / light_range_m, maxf(attenuation, 0.0))


## Cone do spot em 0..1: 1 no eixo, 0 a partir do semiângulo (angle_deg e half_angle_deg em graus).
static func cone_factor(angle_deg: float, half_angle_deg: float, angle_attenuation: float) -> float:
	if half_angle_deg <= 0.0 or angle_deg >= half_angle_deg:
		return 0.0
	var cos_angle: float = cos(deg_to_rad(maxf(angle_deg, 0.0)))
	var cos_edge: float = cos(deg_to_rad(half_angle_deg))
	var t: float = clampf((cos_angle - cos_edge) / (1.0 - cos_edge), 0.0, 1.0)
	return pow(t, maxf(angle_attenuation, 0.0))


## Soma das contribuições limitada a 0..1, com o piso ambiente.
static func combine(sum_contributions: float, ambient: float) -> float:
	return maxf(clampf(sum_contributions, 0.0, 1.0), clampf(ambient, 0.0, 1.0))


func _ready() -> void:
	var parent: Node = get_parent()
	if parent is CollisionObject3D:
		_exclude.append((parent as CollisionObject3D).get_rid())
	_query.exclude = _exclude
	_query.collision_mask = OCCLUDER_MASK
	_accum = 1.0 / maxf(update_hz, 0.001)  ## a primeira amostra sai no primeiro tick físico


## As conexões da árvore ficam em _enter_tree/_exit_tree: se o probe sai e volta, a lista de luzes é refeita
## (luzes criadas enquanto estava fora entram na próxima amostra).
func _enter_tree() -> void:
	var tree: SceneTree = get_tree()
	tree.node_added.connect(_on_tree_changed)
	tree.node_removed.connect(_on_tree_changed)
	_lights_dirty = true


func _exit_tree() -> void:
	var tree: SceneTree = get_tree()
	if tree != null:
		if tree.node_added.is_connected(_on_tree_changed):
			tree.node_added.disconnect(_on_tree_changed)
		if tree.node_removed.is_connected(_on_tree_changed):
			tree.node_removed.disconnect(_on_tree_changed)


func _physics_process(delta: float) -> void:
	var period: float = 1.0 / maxf(update_hz, 0.001)
	_accum += delta
	if _accum < period:
		return
	_accum = minf(_accum - period, period)
	sample_now()


## Última exposição amostrada (0..1). Atualizada a cada amostragem, não a cada chamada.
func get_exposure() -> float:
	return _exposure


## Número de amostragens feitas (para testar a taxa de amostragem).
func get_sample_count() -> int:
	return _sample_count


## Amostra agora e devolve a exposição. Só funciona com o espaço físico acessível (dentro de _physics_process
## ou depois de um frame físico); fora disso, devolve a última amostra.
func sample_now() -> float:
	if not is_inside_tree():
		return _exposure
	if _lights_dirty:
		_collect_lights()
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var total: float = 0.0
	var count: int = 0
	for offset: Vector3 in sample_offsets:
		var world_point: Vector3 = global_transform * offset
		var sum: float = 0.0
		for light: Light3D in _lights:
			if light.is_visible_in_tree():
				sum += _light_contribution(world_point, light, space)
		total += combine(sum, ambient_floor)
		count += 1
	_exposure = total / float(count) if count > 0 else clampf(ambient_floor, 0.0, 1.0)
	_sample_count += 1
	return _exposure


func _light_contribution(sample_world: Vector3, light: Light3D, space: PhysicsDirectSpaceState3D) -> float:
	var offset: Vector3 = light.global_position - sample_world
	var distance: float = offset.length()
	var radial: float = 0.0
	var cone: float = 1.0
	if light is OmniLight3D:
		var omni: OmniLight3D = light as OmniLight3D
		radial = radial_factor(distance, omni.omni_range, omni.omni_attenuation)
	elif light is SpotLight3D:
		var spot: SpotLight3D = light as SpotLight3D
		radial = radial_factor(distance, spot.spot_range, spot.spot_attenuation)
		if radial > 0.0 and distance > SAMPLE_EPSILON_M:
			var forward: Vector3 = -spot.global_transform.basis.z
			var from_light: Vector3 = -offset.normalized()
			var angle_deg: float = rad_to_deg(acos(clampf(forward.dot(from_light), -1.0, 1.0)))
			cone = cone_factor(angle_deg, spot.spot_angle, spot.spot_angle_attenuation)
	else:
		return 0.0
	if radial * cone <= 0.0:
		return 0.0
	if distance > SAMPLE_EPSILON_M and not _visible_from(sample_world, light.global_position, space):
		return 0.0
	return light.light_energy * radial * cone


func _visible_from(from_world: Vector3, to_world: Vector3, space: PhysicsDirectSpaceState3D) -> bool:
	_query.from = from_world
	_query.to = to_world
	var hit: Dictionary = space.intersect_ray(_query)
	return hit.is_empty()


func _collect_lights() -> void:
	_lights.clear()
	var world: World3D = get_world_3d()
	_collect_from(get_tree().root, world)
	_lights_dirty = false


func _collect_from(node: Node, world: World3D) -> void:
	if node is OmniLight3D or node is SpotLight3D:
		var light: Light3D = node as Light3D
		if light.get_world_3d() == world:
			_lights.append(light)
	for child: Node in node.get_children():
		_collect_from(child, world)


func _on_tree_changed(node: Node) -> void:
	if node is Light3D:
		_lights_dirty = true

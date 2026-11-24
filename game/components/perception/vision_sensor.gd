class_name VisionSensor
extends Node3D
## VisionSensor (L2, COMPONENT_CONTRACTS §7.2; DATA_STRUCTURES §3.2; F4-001): visão da IA. evaluate(target) devolve o
## VisualPercept do alvo: visibilidade 0..1 pela fórmula de DATA §3.2 e, com visibilidade > 0, a posição do alvo.
## Isento do ARC-01: é o único componente de percepção que conhece o PerceivableTarget (e só por evaluate).
##
## Decisões de geometria (F4-001):
##   - olho = origem do sensor; frente = −Z local; fov_deg é o cone de ângulo total (metade para cada lado da frente);
##   - distância, ângulo e posição do percept usam o CENTRO do alvo: média dos pontos de amostra;
##   - linha de visão: um raio do olho até cada ponto de amostra; raio bloqueado conta 0. Máscara world_static (1),
##     world_dynamic (2) e vision_occluder (7). Corpos do jogador (3) e de inimigos (4) não bloqueiam;
##   - o corpo pai do sensor, se for CollisionObject3D, é excluído dos raios.
## Sem visibilidade (fora do cone, do alcance, sem linha de visão ou com visibilidade 0), o percept sai zerado, com
## posição zero: nada do alvo vaza para a IA fora de percepção (base do AI-06).
## Tempo do percept: frames de física / ticks por segundo (determinístico, sem relógio de parede).
## Sem alocação por chamada além do que o motor devolve no raio: PhysicsRayQueryParameters3D é reutilizado.
## Autor: AI Engineer (F4-001).

## Bits 1 (world_static) + 2 (world_dynamic) + 64 (vision_occluder, camada 7).
const OCCLUDER_MASK: int = 67
## Luz mínima de quem está no escuro (DATA §3.2: lerp(0,1; 1,0; exposição)).
const LIGHT_FLOOR: float = 0.1
## Até esta distância, a luz mínima sobe para CLOSE_LIGHT_MIN (DATA §3.2: "se d ≤ 1,5 m").
const CLOSE_RANGE_M: float = 1.5
const CLOSE_LIGHT_MIN: float = 0.6
const EPSILON_M: float = 0.000001

## Alcance e cone de visão. Os valores são os do OBSERVER (DATA §3.1); o EnemyController os copia do AIProfile (F4-004).
@export var sight_range_m: float = 16.0
@export var fov_deg: float = 110.0

var _query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.new()
var _exclude: Array[RID] = []


func _ready() -> void:
	_query.collision_mask = OCCLUDER_MASK
	var parent: Node = get_parent()
	if parent is CollisionObject3D:
		_exclude.append((parent as CollisionObject3D).get_rid())
	_query.exclude = _exclude


## Fator de distância (DATA §3.2): 1 − (d / alcance)²; zero a partir do alcance.
static func distance_factor(distance_m: float, range_m: float) -> float:
	if range_m <= 0.0 or distance_m >= range_m:
		return 0.0
	var ratio: float = maxf(distance_m, 0.0) / range_m
	return 1.0 - ratio * ratio


## Fator de luz (DATA §3.2): lerp(0,1; 1,0; exposição), com piso de 0,6 a até 1,5 m.
static func light_factor(exposure: float, distance_m: float) -> float:
	var factor: float = lerpf(LIGHT_FLOOR, 1.0, clampf(exposure, 0.0, 1.0))
	if distance_m <= CLOSE_RANGE_M:
		factor = maxf(factor, CLOSE_LIGHT_MIN)
	return factor


## Visibilidade (DATA §3.2): produto de linha de visão, distância, luz, postura e (1 − ocultação).
static func visibility_of(los: float, distance: float, light: float, stance: float, concealment: float) -> float:
	return clampf(los, 0.0, 1.0) * clampf(distance, 0.0, 1.0) * clampf(light, 0.0, 1.0) \
		* clampf(stance, 0.0, 1.0) * (1.0 - clampf(concealment, 0.0, 1.0))


## Avalia o alvo. Com visibilidade > 0, o percept traz a visibilidade e o centro do alvo; sem ela, sai zerado.
func evaluate(target: PerceivableTarget) -> VisualPercept:
	var now_s: float = _now_s()
	if not is_instance_valid(target) or not is_inside_tree() or not target.is_inside_tree():
		return VisualPercept.create(0.0, Vector3.ZERO, now_s)
	var points: PackedVector3Array = target.get_sample_points()
	if points.is_empty():
		return VisualPercept.create(0.0, Vector3.ZERO, now_s)
	var centre: Vector3 = _centre_of(points)
	var to_centre: Vector3 = centre - global_position
	var distance_m: float = to_centre.length()
	if not _in_view(to_centre, distance_m):
		return VisualPercept.create(0.0, Vector3.ZERO, now_s)
	var los: float = _line_of_sight_fraction(points)
	if los <= 0.0:
		return VisualPercept.create(0.0, Vector3.ZERO, now_s)
	var visibility: float = visibility_of(los, distance_factor(distance_m, sight_range_m),
		light_factor(target.get_light_exposure(), distance_m), target.get_stance_factor(), target.get_concealment())
	if visibility <= 0.0:
		return VisualPercept.create(0.0, Vector3.ZERO, now_s)
	return VisualPercept.create(visibility, centre, now_s)


## Dentro do alcance e do cone de visão (ângulo até o centro ≤ fov/2). Centro coincidente com o olho: visto.
func _in_view(to_centre: Vector3, distance_m: float) -> bool:
	if sight_range_m <= 0.0 or distance_m > sight_range_m:
		return false
	if distance_m <= EPSILON_M:
		return true
	var forward: Vector3 = (-global_transform.basis.z).normalized()
	var cos_to_centre: float = forward.dot(to_centre) / distance_m
	return cos_to_centre >= cos(deg_to_rad(fov_deg * 0.5))


## Fração dos pontos de amostra com linha de visão livre (raios do olho até cada ponto).
func _line_of_sight_fraction(points: PackedVector3Array) -> float:
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var eye: Vector3 = global_position
	var clear: int = 0
	for point: Vector3 in points:
		if eye.distance_to(point) <= EPSILON_M:
			clear += 1
			continue
		_query.from = eye
		_query.to = point
		if space.intersect_ray(_query).is_empty():
			clear += 1
	return float(clear) / float(points.size())


static func _centre_of(points: PackedVector3Array) -> Vector3:
	var sum: Vector3 = Vector3.ZERO
	for point: Vector3 in points:
		sum += point
	return sum / float(points.size())


## Tempo do percept em segundos: frames de física decorridos (determinístico).
static func _now_s() -> float:
	return float(Engine.get_physics_frames()) / float(maxi(Engine.physics_ticks_per_second, 1))

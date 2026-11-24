class_name PerceivableTarget
extends Node3D
## PerceivableTarget (L2, COMPONENT_CONTRACTS §7.1; DATA_STRUCTURES §3.2; F4-001): o que a IA pode perceber de um alvo.
## Componente-filho do jogador, no grupo "perceivable". Expõe os pontos de amostra (cabeça, tronco e pés, em coordenadas
## globais), a exposição à luz, o fator de postura e a ocultação. Os dados vêm de componentes irmãos, ligados por
## injeção (set_light_probe, set_stance, set_concealment); este arquivo não conhece o nó do dono (ARC-01).
## Ocultação: 0 até a F5 (esconderijos).
## Autor: AI Engineer (F4-001).

const GROUP: StringName = &"perceivable"
const LOG_CATEGORY: StringName = &"perception"
## Fatores de postura (DATA §3.2): em pé 1,0; agachado 0,6; rastejando 0,35.
const STANCE_FACTOR_STAND: float = 1.0
const STANCE_FACTOR_CROUCH: float = 0.6
const STANCE_FACTOR_CRAWL: float = 0.35

## Pontos de amostra (cabeça, tronco e pés). Marcadores nulos ou fora da árvore são ignorados.
@export var sample_points: Array[Marker3D] = []

var _light_probe: LightExposureProbe = null
var _stance: Enums.Stance = Enums.Stance.STAND
var _concealment: float = 0.0
var _warned_no_samples: bool = false


func _ready() -> void:
	add_to_group(GROUP)


## Sonda de luz (LightExposureProbe) de onde vem a exposição. Null desliga: sem sonda, a exposição é 0 (escuro).
func set_light_probe(probe: LightExposureProbe) -> void:
	_light_probe = probe


## Postura atual (Enums.Stance), definida pelo componente de movimento.
func set_stance(stance: Enums.Stance) -> void:
	_stance = stance


## Ocultação 0..1: 0 exposto; 1 dentro de esconderijo com proteção total. Valores fora da faixa são limitados.
func set_concealment(value: float) -> void:
	_concealment = clampf(value, 0.0, 1.0)


## Pontos de amostra em coordenadas globais. Sem nenhum marcador válido, devolve a origem do alvo (com um aviso).
func get_sample_points() -> PackedVector3Array:
	var points: PackedVector3Array = PackedVector3Array()
	for marker: Marker3D in sample_points:
		if is_instance_valid(marker) and marker.is_inside_tree():
			points.append(marker.global_position)
	if points.is_empty():
		if not _warned_no_samples:
			_warned_no_samples = true
			Log.warn(LOG_CATEGORY, "PerceivableTarget '%s' sem pontos de amostra; usando a origem" % [name])
		points.append(global_position)
	return points


## Exposição 0..1 à luz, lida da última amostra da sonda. Sem sonda: 0.
func get_light_exposure() -> float:
	if is_instance_valid(_light_probe):
		return _light_probe.get_exposure()
	return 0.0


## Fator de postura (DATA §3.2): em pé 1,0; agachado 0,6; rastejando 0,35.
func get_stance_factor() -> float:
	if _stance == Enums.Stance.CROUCH:
		return STANCE_FACTOR_CROUCH
	if _stance == Enums.Stance.CRAWL:
		return STANCE_FACTOR_CRAWL
	return STANCE_FACTOR_STAND


## Ocultação 0..1 (0 exposto).
func get_concealment() -> float:
	return _concealment

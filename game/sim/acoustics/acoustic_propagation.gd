class_name AcousticPropagation
extends RefCounted
## AcousticPropagation (L1, COMPONENT_CONTRACTS §6.4, DATA_STRUCTURES §2.2): propagação provisória da F2.
## Só perda por distância, sem grafo, paredes nem portas. A F3 troca por AcousticGraph.propagate()
## mantendo esta assinatura. Função pura e determinística (NOI-INV-3).

const MIN_DISTANCE_M: float = 1.0
const EXTRA_LOSS_PER_M_DB: float = 0.1


## Perda por distância: 20·log10(max(d, 1)) + 0.1·d.
static func distance_loss_db(distance_m: float) -> float:
	var clamped: float = maxf(distance_m, MIN_DISTANCE_M)
	return 20.0 * log(clamped) / log(10.0) + EXTRA_LOSS_PER_M_DB * distance_m


## Nível percebido no ponto do ouvinte: intensidade da fonte menos a perda por distância.
static func perceive(event: NoiseEvent, listener_position: Vector3) -> PropagationResult:
	var result: PropagationResult = PropagationResult.new()
	var distance_m: float = event.position.distance_to(listener_position)
	result.perceived_db = event.intensity_db - distance_loss_db(distance_m)
	result.entry_point = event.position
	return result

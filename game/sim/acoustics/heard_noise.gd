class_name HeardNoise
extends RefCounted
## HeardNoise (L1, DATA_STRUCTURES §2; NOI-INV-4): o que a IA recebe de um som. Exatamente estes cinco campos:
## sem posição real, sem id e sem sala da fonte. NOI-03 confere a lista por reflexão. É o único dado de som que a IA
## pode ler (sim/ai/, components/enemy/, components/perception/); NoiseEvent e PlayerHeardNoise são proibidos lá (ARC-01).
## Só o AcousticWorld cria e entrega este tipo (pela HearingSensor.receive, F4).

var category: Enums.NoiseCategory = Enums.NoiseCategory.BREATHING
var perceived_db: float = 0.0
## Posição estimada (entry_point mais erro proporcional aos dB perdidos). Nunca é a posição real da fonte.
var estimated_position: Vector3 = Vector3.ZERO
## 0..1: clamp((perceived_db − limiar) / 20; 0,1; 1) (DATA §2).
var confidence: float = 0.0
var timestamp: float = 0.0
## Limiar efetivo do OUVINTE neste som (DATA §2.3; decisão D4-08 da F4): a suspeita por audição usa
## perceived_db − effective_threshold_db (DATA §3.3). É dado de quem ouve, não da fonte (NOI-INV-4 continua).
var effective_threshold_db: float = 0.0

## Revisão F3-010, R3-01: a estimativa de D-07 (DATA §2) fica pronta em L1 para o HearingSensor da F4.
const CONFIDENCE_SPAN_DB: float = 20.0
const CONFIDENCE_MIN: float = 0.1


## O que a IA ouve de um evento propagado: posição estimada num disco horizontal (plano XZ) em volta do entry_point,
## de raio position_error_per_db_lost × dB perdidos (D-07), e confiança pelo excesso sobre o limiar. Função pura: o RNG
## é do chamador (o AcousticWorld), então a mesma semente dá o mesmo resultado. Nunca usa event.position.
static func from_propagation(event: NoiseEvent, result: PropagationResult, threshold_db: float,
		config: AcousticConfig, rng: RandomNumberGenerator) -> HeardNoise:
	var heard: HeardNoise = HeardNoise.new()
	heard.category = event.category
	heard.perceived_db = result.perceived_db
	heard.timestamp = event.timestamp
	var lost_db: float = maxf(event.intensity_db - result.perceived_db, 0.0)
	heard.estimated_position = result.entry_point + disk_offset(config.position_error_per_db_lost * lost_db, rng)
	heard.confidence = confidence_for(result.perceived_db, threshold_db)
	heard.effective_threshold_db = threshold_db
	return heard


## Confiança (DATA §2): clamp((perceived_db − limiar) / 20; 0,1; 1).
static func confidence_for(perceived_db: float, threshold_db: float) -> float:
	return clampf((perceived_db - threshold_db) / CONFIDENCE_SPAN_DB, CONFIDENCE_MIN, 1.0)


## Ponto uniforme num disco horizontal de raio radius (r = R·√u, ângulo uniforme). Raio 0: sem desvio.
static func disk_offset(radius: float, rng: RandomNumberGenerator) -> Vector3:
	if radius <= 0.0:
		return Vector3.ZERO
	var distance: float = radius * sqrt(rng.randf())
	var angle: float = rng.randf() * TAU
	return Vector3(cos(angle) * distance, 0.0, sin(angle) * distance)

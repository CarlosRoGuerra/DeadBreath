class_name HeardNoise
extends RefCounted
## HeardNoise (L1, DATA_STRUCTURES §2; NOI-INV-4): o que a IA recebe de um som. Exatamente estes cinco campos:
## sem posição real, sem id e sem sala da fonte. NOI-03 confere a lista por reflexão. Proibido em sim/ai/,
## components/enemy/ e components/perception/ (ARC-01). Só o AcousticWorld cria e entrega este tipo.

var category: Enums.NoiseCategory = Enums.NoiseCategory.BREATHING
var perceived_db: float = 0.0
## Posição estimada (entry_point mais erro proporcional aos dB perdidos). Nunca é a posição real da fonte.
var estimated_position: Vector3 = Vector3.ZERO
## 0..1: clamp((perceived_db − limiar) / 20; 0,1; 1) (DATA §2).
var confidence: float = 0.0
var timestamp: float = 0.0

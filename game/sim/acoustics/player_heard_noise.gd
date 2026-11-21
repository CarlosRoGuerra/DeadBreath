class_name PlayerHeardNoise
extends RefCounted
## PlayerHeardNoise (L1, DATA_STRUCTURES §2; COMPONENT_CONTRACTS §6.2 e §6.5): som de outra fonte audível no ouvido
## do jogador, entregue só ao PlayerThreatMonitor. Exatamente estes cinco campos: sem posição, sem id e sem sala.
## source_is_enemy é o único dado de origem. Proibido na IA (ARC-01). NOI-03 confere a lista por reflexão.

var category: Enums.NoiseCategory = Enums.NoiseCategory.BREATHING
var perceived_db: float = 0.0
var source_is_enemy: bool = false
## Identifica o som (ex.: voice_chase_shout). Para in_chase e legendas; não é o id da fonte.
var sound_id: StringName = &""
var timestamp: float = 0.0

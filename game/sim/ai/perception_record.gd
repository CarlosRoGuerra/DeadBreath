class_name PerceptionRecord
extends RefCounted
## PerceptionRecord (L1, DATA_STRUCTURES §3; F4-003): uma pista guardada na PerceptionMemory.
## Dado puro: posição, instante, confiança (0..1) e origem. Nunca identifica a fonte real do som ou o jogador.

var position: Vector3 = Vector3.ZERO
var timestamp: float = 0.0
## 0..1. Para visão, é a visibilidade do percept; decai com o tempo pela PerceptionMemory.
var confidence: float = 0.0
## &"vision", &"hearing" ou &"squad" (squad só na F6).
var source: StringName = &""


static func create(at: Vector3, time_s: float, confidence_value: float, source_id: StringName) -> PerceptionRecord:
	var record_value: PerceptionRecord = PerceptionRecord.new()
	record_value.position = at
	record_value.timestamp = time_s
	record_value.confidence = confidence_value
	record_value.source = source_id
	return record_value

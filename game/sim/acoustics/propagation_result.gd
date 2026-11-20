class_name PropagationResult
extends RefCounted
## PropagationResult (L1, DATA_STRUCTURES §2): resultado de propagar um NoiseEvent até um ouvinte.
## Na F2 a propagação é provisória (só distância): path_portals fica vazio e through_wall é false.

var perceived_db: float = 0.0
var path_portals: Array[StringName] = []
var through_wall: bool = false
## Último portal do caminho, ou a própria fonte quando o caminho é direto.
var entry_point: Vector3 = Vector3.ZERO

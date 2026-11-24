class_name SquadMessage
extends RefCounted
## SquadMessage (L1, DATA_STRUCTURES §3; F4-003): só o tipo. O SquadCoordinator e o uso real são da F6 (D4-02).
## kind: &"spotted", &"heard", &"search_sector" ou &"all_clear".

var sender_id: StringName = &""
var kind: StringName = &""
var position: Vector3 = Vector3.ZERO
var sent_at: float = 0.0
var deliver_at: float = 0.0

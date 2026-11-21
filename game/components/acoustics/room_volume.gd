class_name RoomVolume
extends Area3D
## RoomVolume (L2, DATA_STRUCTURES §2.5; F3-002): sala acústica do nível. O volume é o do CollisionShape3D filho que
## tem um BoxShape3D: o AABB no mundo é o envelope da caixa transformada. O AcousticWorld do nível monta o grafo com
## os RoomVolume do mesmo nível. Grupo "room_volume". Salas precisam estar alinhadas aos eixos (o envelope de uma
## caixa girada é maior que a caixa; o relatório F3-002 registra a limitação).

const GROUP: StringName = &"room_volume"

@export var room_id: StringName = &""
@export var ambient_floor_db: float = 12.0
@export var reverb_bus: StringName = &""


func _enter_tree() -> void:
	add_to_group(GROUP)


## AABB no mundo da sala. Tamanho zero se não há CollisionShape3D com BoxShape3D (o AcousticWorld registra o erro).
func bounds_world() -> AABB:
	for child: Node in get_children():
		var shape_node: CollisionShape3D = child as CollisionShape3D
		if shape_node == null or not (shape_node.shape is BoxShape3D):
			continue
		var box: BoxShape3D = shape_node.shape as BoxShape3D
		var half: Vector3 = box.size * 0.5
		var shape_transform: Transform3D = shape_node.global_transform
		var result: AABB = AABB(shape_transform * Vector3(-half.x, -half.y, -half.z), Vector3.ZERO)
		for sx: float in [-1.0, 1.0]:
			for sy: float in [-1.0, 1.0]:
				for sz: float in [-1.0, 1.0]:
					result = result.expand(shape_transform * Vector3(sx * half.x, sy * half.y, sz * half.z))
		return result
	return AABB()

class_name Portal
extends Node3D
## Portal (L2, DATA_STRUCTURES §2.5; F3-002): passagem entre duas salas. A posição do portal é a posição global do nó,
## que deve estar sobre a face compartilhada das duas salas (não é validado). door: porta opcional cujo state_changed
## abre e fecha o portal no AcousticWorld (OPEN, ou porta em movimento, = aberto; CLOSED e LOCKED = fechado).
## Sem door, o portal fica aberto. Grupo "portal".

const GROUP: StringName = &"portal"

@export var portal_id: StringName = &""
@export var room_a: StringName = &""
@export var room_b: StringName = &""
@export var door: NodePath


func _enter_tree() -> void:
	add_to_group(GROUP)

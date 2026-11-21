class_name LevelSlots
extends Node
## LevelSlots (L2, Project Director, integração F1-009): instancia portas e pickups nos marcadores
## que o Level Designer deixa no nível. Assim a cena do nível (gerada por ferramenta) não precisa
## conhecer as cenas de Door e Pickup.
##
## Convenção dos marcadores (Marker3D):
## - grupo `door_slot`: centro do vão, 1,0 m acima do piso, +Z local ao longo da largura do vão.
##   Metadados: `door_id` (StringName), `start_state` (`closed`/`open`/`locked`), `opening_width_m` (float).
## - grupo `pickup_slot`: posição do item. Metadados: `persist_id`, `item_id` (StringName).
## - grupo `throwable_slot` (F3-004): objeto arremessável. Metadados: `throwable_id` (StringName), `size`
##   (`light`/`medium`/`heavy`). A cena do objeto vem de content/props/throwables/.

const DOOR_SCENE: PackedScene = preload("res://components/world/door.tscn")
const PICKUP_SCENE: PackedScene = preload("res://components/world/pickup.tscn")
const THROWABLE_SCENES: Dictionary = {
	&"light": preload("res://content/props/throwables/throwable_light.tscn"),
	&"medium": preload("res://content/props/throwables/throwable_medium.tscn"),
	&"heavy": preload("res://content/props/throwables/throwable_heavy.tscn"),
}
const DOOR_SLOT_GROUP: StringName = &"door_slot"
const PICKUP_SLOT_GROUP: StringName = &"pickup_slot"
const THROWABLE_SLOT_GROUP: StringName = &"throwable_slot"
const DEFAULT_THROWABLE_SIZE: StringName = &"light"
const SLOT_HEIGHT_ABOVE_FLOOR_M: float = 1.0
const DEFAULT_OPENING_WIDTH_M: float = 0.9
## Largura fixa do painel de door.tscn. Vãos com outra largura geram Log.error (F1-010, R1-14).
const DOOR_PANEL_WIDTH_M: float = 0.9
const WIDTH_TOLERANCE_M: float = 0.01
const LOG_CATEGORY: StringName = &"level"

## Nó raiz do nível que contém os marcadores.
@export var level_path: NodePath

var _doors: Array[Door] = []
var _pickups: Array[Pickup] = []
var _throwables: Array[Throwable] = []


func _ready() -> void:
	var level: Node = get_node_or_null(level_path)
	if level == null:
		Log.error(LOG_CATEGORY, "LevelSlots sem nível válido em level_path '%s'" % level_path)
		return
	var seen_ids: Dictionary = {}
	for node: Node in get_tree().get_nodes_in_group(DOOR_SLOT_GROUP):
		var slot: Marker3D = node as Marker3D
		if slot != null and level.is_ancestor_of(slot):
			_spawn_door(slot)
	for node: Node in get_tree().get_nodes_in_group(PICKUP_SLOT_GROUP):
		var slot: Marker3D = node as Marker3D
		if slot != null and level.is_ancestor_of(slot):
			_spawn_pickup(slot, seen_ids)
	for node: Node in get_tree().get_nodes_in_group(THROWABLE_SLOT_GROUP):
		var slot: Marker3D = node as Marker3D
		if slot != null and level.is_ancestor_of(slot):
			_spawn_throwable(slot)


func get_throwables() -> Array[Throwable]:
	var alive: Array[Throwable] = []
	for item: Throwable in _throwables:
		if is_instance_valid(item):
			alive.append(item)
	return alive


func get_doors() -> Array[Door]:
	return _doors.duplicate()


func get_pickups() -> Array[Pickup]:
	var alive: Array[Pickup] = []
	for p: Pickup in _pickups:
		if is_instance_valid(p):
			alive.append(p)
	return alive


func _spawn_door(slot: Marker3D) -> void:
	var door: Door = DOOR_SCENE.instantiate() as Door
	var width: float = float(slot.get_meta(&"opening_width_m", DEFAULT_OPENING_WIDTH_M))
	if absf(width - DOOR_PANEL_WIDTH_M) > WIDTH_TOLERANCE_M:
		Log.error(LOG_CATEGORY, "vão de %.2f m em %s, mas o painel da porta tem %.2f m (sobra folga ou o painel atravessa a parede)" % [width, slot.get_path(), DOOR_PANEL_WIDTH_M])
	door.name = str(slot.get_meta(&"door_id", slot.name))
	door.door_id = StringName(door.name)
	door.initial_state = _parse_state(str(slot.get_meta(&"start_state", "closed")), slot)
	# O painel cresce em +X local da porta; girar -90° em Y alinha esse eixo ao +Z do marcador.
	# A dobradiça fica na borda -Z do vão, no nível do piso.
	door.transform = Transform3D(Basis(Vector3.UP, -PI / 2.0), Vector3(0.0, -SLOT_HEIGHT_ABOVE_FLOOR_M, -width / 2.0))
	slot.add_child(door)
	_doors.append(door)


func _spawn_pickup(slot: Marker3D, seen_ids: Dictionary) -> void:
	var persist_id: StringName = StringName(str(slot.get_meta(&"persist_id", "")))
	if seen_ids.has(persist_id):
		Log.error(LOG_CATEGORY, "persist_id repetido no nível: '%s' (%s)" % [persist_id, slot.get_path()])
	seen_ids[persist_id] = true
	var pickup: Pickup = PICKUP_SCENE.instantiate() as Pickup
	pickup.persist_id = persist_id
	pickup.item_id = StringName(str(slot.get_meta(&"item_id", "")))
	pickup.name = String(persist_id) if not String(persist_id).is_empty() else "Pickup"
	slot.add_child(pickup)
	_pickups.append(pickup)


func _spawn_throwable(slot: Marker3D) -> void:
	var size: StringName = StringName(str(slot.get_meta(&"size", DEFAULT_THROWABLE_SIZE)))
	if not THROWABLE_SCENES.has(size):
		Log.error(LOG_CATEGORY, "tamanho de arremessável desconhecido '%s' em %s; usando light" % [size, slot.get_path()])
		size = DEFAULT_THROWABLE_SIZE
	var item: Throwable = (THROWABLE_SCENES[size] as PackedScene).instantiate() as Throwable
	item.throwable_id = StringName(str(slot.get_meta(&"throwable_id", slot.name)))
	item.name = String(item.throwable_id)
	slot.add_child(item)
	_throwables.append(item)


func _parse_state(value: String, slot: Node) -> Door.State:
	match value:
		"closed":
			return Door.State.CLOSED
		"open":
			return Door.State.OPEN
		"locked":
			return Door.State.LOCKED
	Log.warn(LOG_CATEGORY, "start_state desconhecido '%s' em %s; usando closed" % [value, slot.get_path()])
	return Door.State.CLOSED

class_name EnemyDoorLinkGate
extends Node
## EnemyDoorLinkGate (L2, D4-03, F4-004): mantém desligado o NavigationLink3D de porta trancada e o religa quando a porta
## é destrancada. Porta trancada nunca é rota (decisão D4-03). Acompanha Door.state_changed, como o AcousticWorld faz
## com os portais (COMPONENT_CONTRACTS §6.5).
##
## Escopo: scope_path (padrão "../.." a partir deste nó) é o nó onde ficam os NavigationLink3D (metadado door_id) e as
## portas (Door com door_id). Os links são do mapa de navegação inteiro, então o estado é o mesmo para todo inimigo do
## nível; vários gates no mesmo nível são redundantes mas não conflitam (cada um só grava o estado que a porta exige).
##
## Ligação adiada (call_deferred): as portas são criadas pelo LevelSlots no _ready do nível, e o gate pode entrar antes.
## Link sem porta correspondente: Log.error e o link fica como está. Autor: AI Engineer (F4-004).

const LINK_DOOR_META: StringName = &"door_id"
const LOG_CATEGORY: StringName = &"enemy"

## Nó que contém os NavigationLink3D e as portas do nível.
@export var scope_path: NodePath = NodePath("../..")

var _links: Dictionary = {}
var _connected_doors: Array[Door] = []


func _ready() -> void:
	_bind.call_deferred()


func _exit_tree() -> void:
	for door: Door in _connected_doors:
		if is_instance_valid(door) and door.state_changed.is_connected(_on_door_state_changed):
			door.state_changed.disconnect(_on_door_state_changed)
	_connected_doors.clear()


## Estado atual do link de uma porta (true = ligado). Para testes e depuração. Sem link: false.
func is_link_enabled(door_id: StringName) -> bool:
	var link: NavigationLink3D = _links.get(door_id) as NavigationLink3D
	return link != null and link.enabled


## Liga os links ao estado das portas. Idempotente: chamar de novo não duplica conexões.
func _bind() -> void:
	var scope: Node = get_node_or_null(scope_path)
	if scope == null:
		Log.error(LOG_CATEGORY, "EnemyDoorLinkGate '%s' sem nível em '%s'" % [name, str(scope_path)])
		return
	var doors: Dictionary = {}
	_collect_doors(scope, doors)
	var links: Dictionary = {}
	_collect_links(scope, links)
	_links = links
	for key: Variant in links.keys():
		var door_id: StringName = key as StringName
		var link: NavigationLink3D = links[door_id] as NavigationLink3D
		var door: Door = doors.get(door_id) as Door
		if door == null:
			Log.error(LOG_CATEGORY, "link '%s' sem porta '%s' no nível; link mantido como está" % [link.name, door_id])
			continue
		link.enabled = door.get_state() != Door.State.LOCKED
		_connect_door(door, door_id)


func _connect_door(door: Door, door_id: StringName) -> void:
	var callback: Callable = _on_door_state_changed.bind(door_id)
	if door.state_changed.is_connected(callback):
		return
	door.state_changed.connect(callback)
	_connected_doors.append(door)


func _on_door_state_changed(_old_state: Door.State, new_state: Door.State, door_id: StringName) -> void:
	var link: NavigationLink3D = _links.get(door_id) as NavigationLink3D
	if link == null:
		return
	link.enabled = new_state != Door.State.LOCKED


func _collect_doors(node: Node, out: Dictionary) -> void:
	var door: Door = node as Door
	if door != null and door.door_id != &"":
		out[door.door_id] = door
	for child: Node in node.get_children():
		_collect_doors(child, out)


func _collect_links(node: Node, out: Dictionary) -> void:
	var link: NavigationLink3D = node as NavigationLink3D
	if link != null and link.has_meta(LINK_DOOR_META):
		out[StringName(str(link.get_meta(LINK_DOOR_META)))] = link
	for child: Node in node.get_children():
		_collect_links(child, out)

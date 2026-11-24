class_name EnemySandbox
extends RefCounted
## Apoio aos testes de IA na sandbox real (F4-004): monta a sandbox como a cena jogável (LevelSlots cria as portas) e
## retira o jogador, que já é percebível e daria estímulo ao Observer. Sem AcousticWorld: o inimigo não ouve as portas
## que ele mesmo abre, então o teste de patrulha fica sem estímulo (AI-01). Só dado de teste. Autor: AI Engineer (F4-004).

const LEVEL_PATH: String = "res://content/levels/sandbox.tscn"
const OBSERVER_SCENE_PATH: String = "res://content/enemies/observer.tscn"
const LEVEL_NAME: String = "Level"
const PLAYER_NODE_NAME: String = "Player"


## Raiz de teste com a sandbox, os LevelSlots e sem jogador. Liberada ao fim do teste (add_child_autofree).
static func build(test: TestCase) -> Node3D:
	var root: Node3D = Node3D.new()
	test.add_child_autofree(root)
	var level: Node3D = (load(LEVEL_PATH) as PackedScene).instantiate() as Node3D
	level.name = LEVEL_NAME
	root.add_child(level)
	var player: Node = level.get_node_or_null(PLAYER_NODE_NAME)
	if player != null:
		level.remove_child(player)
		player.free()
	var slots: LevelSlots = LevelSlots.new()
	slots.level_path = NodePath("../" + LEVEL_NAME)
	root.add_child(slots)
	return root


## Um Observer em `spawn`, com a rota `route_id` (os marcadores têm de estar em root antes de chamar).
static func add_observer(root: Node3D, spawn: Vector3, route_id: StringName) -> EnemyController:
	var enemy: EnemyController = (load(OBSERVER_SCENE_PATH) as PackedScene).instantiate() as EnemyController
	enemy.route_id = route_id
	enemy.position = spawn
	root.add_child(enemy)
	return enemy


## Porta com door_id dentro de root (LevelSlots a cria sob o marcador de vão). Null se não existir.
static func door(root: Node, door_id: StringName) -> Door:
	var found: Door = root as Door
	if found != null and found.door_id == door_id:
		return found
	for child: Node in root.get_children():
		var hit: Door = door(child, door_id)
		if hit != null:
			return hit
	return null

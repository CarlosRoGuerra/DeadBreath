extends RefCounted
## Fixture dos testes de interação (F1-007). Reusa a montagem do jogador (física, jogador, Settings) e
## instancia Pickup e Door a partir das cenas em components/world/. Pasta "fixtures" não é descoberta pelo runner.
## Autor: Gameplay Engineer.

const PlayerWorld := preload("res://tests/integration/player/fixtures/player_world.gd")
const PICKUP_SCENE: PackedScene = preload("res://components/world/pickup.tscn")
const DOOR_SCENE: PackedScene = preload("res://components/world/door.tscn")

## Altura dos olhos em pé (topo do colisor 1,75 m menos 0,10 m): alvos nessa altura caem no centro da câmera.
const EYE_HEIGHT_M: float = 1.65
const WALL_LAYER_SIZE: Vector3 = Vector3(3.0, 3.0, 0.1)


static func spawn_pickup(parent: Node3D, position: Vector3, persist_id: StringName, item_id: StringName,
		hold_time: float = 0.0, steady: bool = false) -> Pickup:
	var pickup: Pickup = PICKUP_SCENE.instantiate() as Pickup
	pickup.persist_id = persist_id
	pickup.item_id = item_id
	pickup.quantity = 1
	pickup.hold_time = hold_time
	pickup.requires_steady_hands = steady
	pickup.position = position
	parent.add_child(pickup)
	return pickup


static func spawn_door(parent: Node3D, position: Vector3) -> Door:
	var door: Door = DOOR_SCENE.instantiate() as Door
	door.position = position
	parent.add_child(door)
	return door


## Parede de mundo (camada 1) entre o jogador e o alvo.
static func add_wall(parent: Node3D, z: float) -> void:
	PlayerWorld.add_box(parent, Vector3(0.0, 1.5, z), WALL_LAYER_SIZE)

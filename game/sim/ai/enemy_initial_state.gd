class_name EnemyInitialState
extends Resource
## EnemyInitialState (L1, DATA_STRUCTURES §3; F4-003): estado inicial de um inimigo (spawn, rota e estado).
## Usado pelo EnemyController.reset_to (CheckpointManager, F5). Dado puro.

@export var spawn_position: Vector3 = Vector3.ZERO
@export var patrol_route: NodePath = NodePath()
@export var state: Enums.EnemyState = Enums.EnemyState.PATROL

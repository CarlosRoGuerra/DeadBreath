class_name EnemyCaptureArea
extends Area3D
## EnemyCaptureArea (L2, COMPONENT_CONTRACTS §8.1, DATA_STRUCTURES §9; F4-005): captura básica do inimigo.
## Dispara player_caught só quando um corpo da camada do jogador (3) está sobreposto E o estado do controlador é CHASE.
## Prioridade de física -30 (SYSTEM_ARCHITECTURE §6): roda depois do tick de IA (-40), no mesmo quadro.
##
## ENM-INV-1 / AI-07: a captura NÃO entra no PerceptBatch. Este arquivo não conhece o cérebro nem os percepts; a única
## saída é o sinal, que o controlador repassa para EventBus.player_captured. Nada aqui lê dado do jogador além da
## sobreposição física.
##
## Trava (D4-04): depois de disparar, não dispara de novo até rearm(), que o controlador chama no reset_to (o
## checkpoint da F5 e a tela de captura do Gameplay recomeçam daí).
## Autor: AI Engineer (F4-005).

signal player_caught()

## Camada 3 (player) como máscara: bit 2 (valor 4). O jogador é reconhecido pela camada física, não por grupo ou classe.
const BODY_LAYER_MASK: int = 4
const PROCESS_PRIORITY: int = -30
const LOG_CATEGORY: StringName = &"enemy"

## Controlador dono (caminho relativo ao nó desta área). A captura só vale em CHASE.
@export var controller: NodePath = NodePath("..")

var _owner_body: EnemyController = null
var _latched: bool = false


func _ready() -> void:
	collision_layer = 0
	collision_mask = BODY_LAYER_MASK
	monitoring = true
	process_physics_priority = PROCESS_PRIORITY
	_owner_body = get_node_or_null(controller) as EnemyController
	if _owner_body == null:
		Log.error(LOG_CATEGORY, "EnemyCaptureArea '%s' sem EnemyController em '%s'; captura desligada" % [name, str(controller)])


func _physics_process(_delta: float) -> void:
	evaluate()


## Libera a captura para um novo episódio (reset_to do controlador).
func rearm() -> void:
	_latched = false


func is_latched() -> bool:
	return _latched


## Avalia a captura agora: sobreposição com o jogador, estado CHASE e trava. Chamado pelo tick de física; os testes
## podem chamar direto depois de esperar a sobreposição.
func evaluate() -> void:
	if _latched or _owner_body == null:
		return
	if _owner_body.get_state() != Enums.EnemyState.CHASE:
		return
	if get_overlapping_bodies().is_empty():
		return
	_latched = true
	player_caught.emit()

class_name Interactable
extends Node3D
## Interactable (L2, COMPONENT_CONTRACTS §3). Alvo de interação: precisa de um collider na camada 5
## (interactable) como filho. hold_time = 0: conclui ao apertar. hold_time > 0: exige segurar; a fórmula
## de mãos firmes fica no InteractionComponent.
## Acréscimo da F1-007: tap_completes = soltar antes de hold_time ainda conclui, como toque (ex.: porta).

signal interacted(actor: Node)

@export var prompt_key: StringName = &""
@export var hold_time: float = 0.0
@export var requires_steady_hands: bool = false
@export var tap_completes: bool = false


func can_interact(_context: InteractionContext) -> bool:
	return true


func interact(context: InteractionContext) -> void:
	interacted.emit(context.actor)

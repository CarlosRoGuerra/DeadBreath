class_name InteractionContext
extends RefCounted
## InteractionContext (L2, DATA_STRUCTURES §5): dados do ator para Interactable.can_interact e interact.
## Acréscimo da F1-007: held = true quando a interação foi concluída por segurar (false = toque).

var actor: Node = null
## 0..1 (1 = mãos firmes). Na F1 vem de CouplingFactors.neutral().
var steadiness: float = 1.0
var is_hidden: bool = false
var held: bool = false

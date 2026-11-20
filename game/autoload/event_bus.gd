extends Node
## EventBus (L0, autoload "EventBus"): sinais globais do catálogo COMPONENT_CONTRACTS §16.
## Regra: payloads só com tipos nativos (StringName, String, int, float, bool) ou Enums.
## O teste de integração do EventBus verifica as declarações por reflexão.
## Os emissores e consumidores permitidos de cada sinal estão no catálogo.

@warning_ignore("unused_signal")
signal player_captured(enemy_id: StringName)
@warning_ignore("unused_signal")
signal checkpoint_reached(checkpoint_id: StringName)
@warning_ignore("unused_signal")
signal objective_updated(objective_id: StringName, status: Enums.ObjectiveStatus)
@warning_ignore("unused_signal")
signal item_picked(item_id: StringName, quantity: int, persist_id: StringName)
@warning_ignore("unused_signal")
signal chapter_changed(chapter_id: StringName)
## Somente o DifficultyManager pode consumir (métricas). Proibido em L3.
@warning_ignore("unused_signal")
signal chase_started(enemy_id: StringName)
## Somente o DifficultyManager pode consumir (métricas). Proibido em L3.
@warning_ignore("unused_signal")
signal chase_ended(enemy_id: StringName)
@warning_ignore("unused_signal")
signal subtitle_requested(text_key: StringName, duration: float)

## Nomes do catálogo, na ordem de COMPONENT_CONTRACTS §16.
const CATALOG: PackedStringArray = [
	"player_captured", "checkpoint_reached", "objective_updated", "item_picked",
	"chapter_changed", "chase_started", "chase_ended", "subtitle_requested",
]

## Tipos de payload permitidos (Enums chegam como TYPE_INT).
const ALLOWED_ARG_TYPES: Array[int] = [TYPE_STRING_NAME, TYPE_STRING, TYPE_INT, TYPE_FLOAT, TYPE_BOOL]

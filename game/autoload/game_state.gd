extends Node
## GameState (L0, autoload "GameState"): estado global mínimo. Contrato: COMPONENT_CONTRACTS §15.

var chapter_id: StringName = &""
## true em build de release ou com o argumento de usuário `--production`
## (usado para simular produção em testes; F1-008 desliga overlay e comandos de debug).
var is_production_build: bool = false


func _init() -> void:
	is_production_build = not OS.is_debug_build() or OS.get_cmdline_user_args().has("--production")


## Troca o capítulo e emite EventBus.chapter_changed (emissor do catálogo §16).
func set_chapter(id: StringName) -> void:
	if id == chapter_id:
		return
	chapter_id = id
	EventBus.chapter_changed.emit(id)

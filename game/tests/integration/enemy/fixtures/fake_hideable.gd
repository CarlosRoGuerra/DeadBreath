class_name FakeHideable
extends Node3D
## Esconderijo falso para o teste de AI-08 (F4-004). Mesma forma que a F5 entrega: grupo "hideable", metadado persist_id
## e inspect(by_enemy_id) -> bool. O resultado é fixo (answer) e as chamadas são contadas. Só dado de teste.

var answer: bool = false
var calls: int = 0


func _ready() -> void:
	add_to_group(&"hideable")


func inspect(_by_enemy_id: StringName) -> bool:
	calls += 1
	return answer

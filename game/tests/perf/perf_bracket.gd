extends Node
## Marcador de tempo da medição de desempenho (F4-007). Um par de marcadores (início com prioridade menor, fim com
## prioridade maior) cerca um sistema no tick de física ou de processo; o harness soma o tempo entre eles por quadro.
## Ferramenta de medição, não é teste: fica fora das pastas de nível do runner (tests/perf/).

var bucket: String = ""
var is_start: bool = true
var use_process: bool = false
var harness: Node = null


func _ready() -> void:
	set_physics_process(not use_process)
	set_process(use_process)


func _physics_process(_delta: float) -> void:
	harness.call("mark", bucket, is_start)


func _process(_delta: float) -> void:
	harness.call("mark", bucket, is_start)

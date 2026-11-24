class_name VisualPercept
extends RefCounted
## VisualPercept (L1, DATA_STRUCTURES §3; F4): o que o VisionSensor entrega ao EnemyController sobre um alvo perceptível.
## Criado pelo Director na abertura da F4 para os dois agentes da onda A (percepção e cérebro) usarem o mesmo tipo.
## Sem referência ao jogador: só visibilidade, posição (válida com visibility > 0) e instante.

var visibility: float = 0.0
## Posição percebida; válida somente se visibility > 0.
var position: Vector3 = Vector3.ZERO
var timestamp: float = 0.0


static func create(visibility_value: float, at: Vector3, time_s: float) -> VisualPercept:
	var percept: VisualPercept = VisualPercept.new()
	percept.visibility = visibility_value
	percept.position = at
	percept.timestamp = time_s
	return percept

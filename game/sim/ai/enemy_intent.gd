class_name EnemyIntent
extends RefCounted
## EnemyIntent (L1, DATA_STRUCTURES §3; F4-003): o que o EnemyBrain pede ao EnemyController neste tick.
## Não move nada: o controlador aplica (NavigationAgent3D, velocidade, olhar, inspeção e fala).
## Campos instantâneos (inspect_hideable e voice_line) valem só no tick em que foram postos; nos demais ficam vazios.

## Destino de navegação (no mundo). Em SUSPICIOUS, é a posição atual do inimigo (ele fica parado).
var move_target: Vector3 = Vector3.ZERO
## m/s. 0 quando parado.
var move_speed: float = 0.0
## Para onde olhar. Em SUSPICIOUS, o estímulo; nos demais estados, o destino.
var look_target: Vector3 = Vector3.ZERO
## persist_id do esconderijo inspecionado. Posto uma vez, ao chegar ao esconderijo. Vazio = nenhum.
var inspect_hideable: StringName = &""
## sound_id da fala do Observer (DATA §3, tabela de falas). Posto uma vez, na transição. Vazio = nenhuma.
var voice_line: StringName = &""

class_name PerceptBatch
extends RefCounted
## PerceptBatch (L1, DATA_STRUCTURES §3; F4-003): entrada de um tick do EnemyBrain.
## Montado pelo EnemyController (F4-004). Só contém o que os sensores entregam; nunca dado do jogador (FW-INV-1).
## squad fica vazio na F4 (decisão D4-02: um inimigo; SquadCoordinator só na F6).

## Percepts visuais do tick (VisionSensor.evaluate). Pode estar vazio.
var visual: Array[VisualPercept] = []
## Sons entregues pelo HearingSensor. Ver EnemyBrain: a suspeita por audição depende do limiar efetivo,
## que ainda não chega ao cérebro (contrato pendente, F4-003). Hoje o brain recusa ruído com erro.
var heard: Array[HeardNoise] = []
## Mensagens de esquadrão. Vazio na F4 (D4-02).
var squad: Array[SquadMessage] = []

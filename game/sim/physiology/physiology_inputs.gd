class_name PhysiologyInputs
extends RefCounted
## PhysiologyInputs (L1, DATA_STRUCTURES §1): entradas de um tick da fisiologia.
## Montado pelo PlayerRoot (COMPONENT_CONTRACTS §4.3). Dado puro.

## 0..1, PlayerMotor.get_exertion() do tick.
var exertion: float = 0.0
## Marcha do motor no tick (Enums.Gait).
var gait: Enums.Gait = Enums.Gait.IDLE
## Ameaça percebida pelo jogador neste tick.
var threat: ThreatSample = ThreatSample.new()
## Parado e agachado ou rastejando, ou escondido.
var is_resting: bool = false
## Dentro de zona segura (regeneração e alívio do estresse mais rápidos).
var in_safe_zone: bool = false
## Escondido em um esconderijo (F5; falso na F2).
var is_hidden: bool = false

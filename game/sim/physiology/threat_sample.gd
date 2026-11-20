class_name ThreatSample
extends RefCounted
## ThreatSample (L1, DATA_STRUCTURES §5 e §1.5): amostra da ameaça percebida pelo jogador.
## Produzida por um ThreatSource (F2: StubThreatSource; F4: PlayerThreatMonitor) e consumida pela fisiologia.
## Dado puro: sem cena, sem autoload.

## 0..1: max(seen_proximity, 0,5 · heard_factor, in_chase ? 1 : 0). Informativo (música, apresentação).
var threat_level: float = 0.0
## 0..1: proximidade de inimigo visto (1 a até 3 m, 0 a partir de 15 m).
var seen_proximity: float = 0.0
## 0..1: fator de ruído de inimigo ouvido nos últimos 3 s.
var heard_factor: float = 0.0
## Verdadeiro se algum inimigo está em perseguição.
var in_chase: bool = false

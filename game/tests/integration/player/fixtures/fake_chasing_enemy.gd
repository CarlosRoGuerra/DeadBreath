extends CharacterBody3D
## Inimigo falso para os testes do PlayerThreatMonitor (F4-006b): expõe get_state() com a assinatura do
## EnemyController (COMPONENT_CONTRACTS §8.1). O estado é trocado pelo teste (propriedade "state").
## Pasta "fixtures" não é descoberta pelo runner. Autor: Gameplay Engineer.

var state: Enums.EnemyState = Enums.EnemyState.CHASE


func get_state() -> Enums.EnemyState:
	return state

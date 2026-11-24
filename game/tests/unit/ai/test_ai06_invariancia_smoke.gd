extends TestCase
## AI-06 em L1, versão de nível padrão (F4-003): mesmo RNG e mesmos percepts dão intents idênticos em todos os ticks.
## Versão completa (50 pares, 600 ticks) em tests/property/ai/test_ai06_invariancia.gd.
## Ver AITestSupport.run_episode: o jogador (posição diferente em cada execução) nunca chega ao cérebro.

const TICKS: int = 200
const PAIRS: int = 3
const FAR_PLAYER_A: Vector3 = Vector3(40.0, 0.0, 0.0)
const FAR_PLAYER_B: Vector3 = Vector3(-35.0, 0.0, 30.0)


func test_ai06_smoke_fora_de_visao_e_silencioso() -> void:
	for pair: int in range(PAIRS):
		var first: Array[EnemyIntent] = AITestSupport.run_episode(pair + 1, pair + 1000, TICKS, 0, FAR_PLAYER_A)
		var second: Array[EnemyIntent] = AITestSupport.run_episode(pair + 1, pair + 1000, TICKS, 0, FAR_PLAYER_B)
		assert_eq(AITestSupport.first_difference(first, second), -1, "par %d: intents idênticos" % pair)


func test_ai06_smoke_com_percepts_iguais_dao_intents_iguais() -> void:
	for pair: int in range(PAIRS):
		var first: Array[EnemyIntent] = AITestSupport.run_episode(pair + 1, pair + 1000, TICKS, 1, FAR_PLAYER_A)
		var second: Array[EnemyIntent] = AITestSupport.run_episode(pair + 1, pair + 1000, TICKS, 1, FAR_PLAYER_A)
		assert_eq(AITestSupport.first_difference(first, second), -1, "par %d: intents idênticos" % pair)


func test_ai06_smoke_com_ruidos_no_lote_dao_intents_iguais() -> void:
	# D4-08: visão e ruídos sorteados no lote, iguais nas duas execuções.
	for pair: int in range(PAIRS):
		var first: Array[EnemyIntent] = AITestSupport.run_episode(pair + 1, pair + 3000, TICKS, 2, FAR_PLAYER_A)
		var second: Array[EnemyIntent] = AITestSupport.run_episode(pair + 1, pair + 3000, TICKS, 2, FAR_PLAYER_B)
		assert_eq(AITestSupport.first_difference(first, second), -1, "par %d: intents idênticos com ruídos" % pair)


func test_ai06_smoke_semente_diferente_muda_a_sequencia() -> void:
	# Sanidade do próprio teste: se os percepts não variassem, a igualdade acima seria vazia.
	var first: Array[EnemyIntent] = AITestSupport.run_episode(1, 1000, TICKS, 1, FAR_PLAYER_A)
	var other: Array[EnemyIntent] = AITestSupport.run_episode(1, 1001, TICKS, 1, FAR_PLAYER_A)
	assert_true(AITestSupport.first_difference(first, other) >= 0, "percepts diferentes produzem outra sequência")

extends TestCase
## AI-06 em L1, versão completa (TEST_PLAN §2.5; F4-003): 50 pares, 600 ticks cada, com o mesmo RNG e os mesmos percepts,
## jogadores em posições diferentes e fora de visão e silenciosos → EnemyIntent idêntico em todos os ticks.
## Mais uma varredura de invariantes sobre episódios com percepts sorteados (suspeita e intents válidos).
## Nível property: roda com --level=property. Versão rápida no nível padrão: tests/unit/ai/test_ai06_invariancia_smoke.gd.

const PAIRS: int = 50
const TICKS: int = 600
const PLAYER_ONE: Vector3 = Vector3(40.0, 0.0, 0.0)
const PLAYER_TWO: Vector3 = Vector3(-35.0, 0.0, 30.0)
const SWEEP_EPISODES: int = 40
const MAX_SPEED: float = 5.0


func test_ai06_50_pares_fora_de_visao_dao_intents_identicos() -> void:
	var diverged: PackedStringArray = PackedStringArray()
	for pair: int in range(PAIRS):
		var first: Array[EnemyIntent] = AITestSupport.run_episode(pair + 1, pair + 1000, TICKS, 0, PLAYER_ONE)
		var second: Array[EnemyIntent] = AITestSupport.run_episode(pair + 1, pair + 1000, TICKS, 0, PLAYER_TWO)
		var index: int = AITestSupport.first_difference(first, second)
		if index >= 0:
			diverged.append("par %d, tick %d" % [pair, index])
	assert_eq(diverged.size(), 0, "pares divergentes: " + ", ".join(diverged))


func test_ai06_50_pares_com_percepts_iguais_dao_intents_iguais() -> void:
	var diverged: PackedStringArray = PackedStringArray()
	for pair: int in range(PAIRS):
		var first: Array[EnemyIntent] = AITestSupport.run_episode(pair + 1, pair + 1000, TICKS, 1, PLAYER_ONE)
		var second: Array[EnemyIntent] = AITestSupport.run_episode(pair + 1, pair + 1000, TICKS, 1, PLAYER_ONE)
		var index: int = AITestSupport.first_difference(first, second)
		if index >= 0:
			diverged.append("par %d, tick %d" % [pair, index])
	assert_eq(diverged.size(), 0, "pares divergentes: " + ", ".join(diverged))


func test_ai06_50_pares_com_ruidos_no_lote_dao_intents_iguais() -> void:
	# D4-08: o lote traz visão e ruídos sorteados (mesmos nas duas execuções). Os jogadores não entram no lote.
	var diverged: PackedStringArray = PackedStringArray()
	for pair: int in range(PAIRS):
		var first: Array[EnemyIntent] = AITestSupport.run_episode(pair + 1, pair + 3000, TICKS, 2, PLAYER_ONE)
		var second: Array[EnemyIntent] = AITestSupport.run_episode(pair + 1, pair + 3000, TICKS, 2, PLAYER_TWO)
		var index: int = AITestSupport.first_difference(first, second)
		if index >= 0:
			diverged.append("par %d, tick %d" % [pair, index])
	assert_eq(diverged.size(), 0, "pares divergentes com ruídos: " + ", ".join(diverged))


func test_varredura_intents_validos_em_episodios_com_percepts_sorteados() -> void:
	# Invariantes de saída: destinos finitos, velocidade entre 0 e a de perseguição, fala só com id conhecido.
	# Usa o modo 2 (visão e ruídos sorteados), que cobre os modos 1 e 2.
	var bad: PackedStringArray = PackedStringArray()
	var known_voices: PackedStringArray = PackedStringArray(["", "voice_suspicious", "voice_investigate",
		"voice_chase_shout", "voice_search"])
	for episode: int in range(SWEEP_EPISODES):
		var intents: Array[EnemyIntent] = AITestSupport.run_episode(episode + 7, episode + 5000, TICKS, 2, PLAYER_ONE)
		for index: int in range(intents.size()):
			var intent: EnemyIntent = intents[index]
			var finite: bool = not is_nan(intent.move_target.x) and not is_nan(intent.move_target.z) \
				and not is_inf(intent.move_target.x) and not is_inf(intent.move_target.z)
			if not finite or intent.move_speed < 0.0 or intent.move_speed > MAX_SPEED:
				bad.append("ep %d tick %d" % [episode, index])
			if not known_voices.has(String(intent.voice_line)):
				bad.append("voz desconhecida ep %d tick %d" % [episode, index])
	assert_eq(bad.size(), 0, "intents inválidos: " + ", ".join(bad.slice(0, 10)))

extends TestCase
## PHY-10 (histerese e permanência mínima, TEST_PLAN §2.2) em versão completa: oscilação de ±0,02 em torno de cada
## limiar de estado durante 30 s, com a permanência mínima de 1 s. Varredura longa: nível property.
## A versão curta (2 casos, 10 s) está em tests/unit/physiology/test_phy08_10_11_determinismo_histerese_dt.gd.
## Autor: Physiological Systems Engineer.

const Fx := preload("res://tests/unit/physiology/fixtures/physio_fixture.gd")
const WOBBLE: float = 0.02
const OSCILLATION_S: float = 30.0
const PERIOD_S: float = 2.0
const DWELL_S: float = 1.0


func _assert_dwell_respected(transitions: Array, label: String) -> void:
	for index: int in range(1, transitions.size()):
		var gap: float = float(transitions[index][0]) - float(transitions[index - 1][0])
		assert_true(gap >= DWELL_S - 0.02, "%s: transições separadas por ≥ 1 s (obtido %.3f)" % [label, gap])


func test_phy10_sete_limiares_30_s_sem_ping_pong() -> void:
	# Cada caso: [nome, estado inicial, centro, EMA, transições esperadas].
	var cases: Array[Array] = [
		["NORMAL→ACCELERATED em 0,20", "NORMAL", 0.20, 0.0, 1],
		["LABORED→RECOVERING em 0,30", "LABORED", 0.30, 0.2, 1],
		["SYMPTOMATIC→LABORED em 0,55", "SYMPTOMATIC", 0.55, 0.2, 1],
		["LABORED→SYMPTOMATIC em 0,60", "LABORED", 0.60, 0.2, 1],
		["ACCELERATED→NORMAL em 0,15", "ACCELERATED", 0.15, 0.0, 1],
		["ACCELERATED→LABORED em 0,35", "ACCELERATED", 0.35, 0.2, 1],
		["RECOVERING sem saída em 0,30", "RECOVERING", 0.30, 0.2, 0],
	]
	for case: Array in cases:
		var transitions: Array = Fx.oscillate(case[1], case[2], case[3], OSCILLATION_S, PERIOD_S, WOBBLE)
		note("PHY-10 (30 s) %s: %d transição(ões)" % [case[0], transitions.size()])
		assert_eq(transitions.size(), case[4], "%s: transições esperadas %d" % [case[0], case[4]])
		_assert_dwell_respected(transitions, case[0])

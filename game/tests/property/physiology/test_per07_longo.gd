extends TestCase
## PER-07 (TEST_PLAN §2.6) em versão longa: 20 s de continuação depois de carregar, nos dois pontos de salvamento
## (aviso agendado com bombinha, alívio, água e exaustão; e cooldown de tosse). Varredura longa: nível property.
## A versão curta está em tests/unit/physiology/test_per07_reprodutibilidade.gd. Autor: Physiological Systems Engineer.

const Fx := preload("res://tests/unit/physiology/fixtures/physio_fixture.gd")
const CONTINUE_TICKS_LONG: int = 60 * 20
const MAX_TICKS_SEARCH: int = 60 * 60


func _check_point(label: String, rig: Fx.Rig) -> void:
	var payload: Dictionary = Fx.payload_of(rig)
	var restored: Fx.Rig = Fx.make_rig(1)
	Fx.load_payload(restored, payload)
	var mismatches: PackedStringArray = Fx.payload_mismatches(payload, Fx.payload_of(restored), label + " após carregar")
	assert_true(mismatches.is_empty(), "campo a campo após carregar: " + ", ".join(mismatches))
	var result: Array = Fx.continue_and_compare(rig, restored, CONTINUE_TICKS_LONG)
	note("%s (longo): %d ticks após o carregamento, divergências %d; avisos %d, tosses %d, tosses canceladas %d"
		% [label, CONTINUE_TICKS_LONG, result[0], result[1], result[2], result[3]])
	assert_eq(result[0], 0, "%s: continuação idêntica à execução contínua, tick a tick" % label)


func test_per07_longo_aviso_agendado() -> void:
	var rig: Fx.Rig = Fx.run_to_pending_cough(707, MAX_TICKS_SEARCH)
	assert_not_null(rig, "a sequência chega a um aviso de tosse agendado")
	if rig == null:
		return
	_check_point("ponto (a)", rig)


func test_per07_longo_cooldown_de_tosse() -> void:
	var rig: Fx.Rig = Fx.run_to_cough(708, MAX_TICKS_SEARCH)
	assert_not_null(rig, "a sequência tem uma tosse involuntária")
	if rig == null:
		return
	_check_point("ponto (b)", rig)

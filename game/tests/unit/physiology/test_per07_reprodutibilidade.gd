extends TestCase
## PER-07 (TEST_PLAN §2.6, DATA_STRUCTURES §6.1): salvar no meio de uma sequência, carregar e comparar campo a campo;
## depois continuar e obter exatamente o que a execução contínua produz. Dois pontos de salvamento: (a) aviso de tosse
## agendado, bombinha em cooldown, alívio ativo, água ativa e stamina em exaustão; (b) cooldown de tosse ativo.
## Aqui, a versão curta (3 s de continuação, suíte padrão). A versão longa (20 s) está em
## tests/property/physiology/test_per07_longo.gd. Nível: modelo. Autor: Physiological Systems Engineer.
##
## O que é exato aqui: o contrato to_dict/from_dict em memória (o RNG vai como string, DATA §6).
## ACHADO (ver relatório F2-004): nenhum transporte de TEXTO do Godot 4.7 preserva floats com exatidão. O JSON
## do Godot escreve 15 dígitos; var_to_str/str_to_var perde 1 ulp em parte dos valores; a forma binária
## (var_to_bytes / Marshalls.variant_to_base64) é exata. As medidas saem como nota, e a escolha do formato
## de persistência fica com o Software Architect (SaveService, F5).

const Fx := preload("res://tests/unit/physiology/fixtures/physio_fixture.gd")
const CONTINUE_TICKS_SHORT: int = 60 * 3
const MAX_TICKS_SEARCH: int = 60 * 60


func _check_point(label: String, rig: Fx.Rig, ticks: int) -> void:
	var payload: Dictionary = Fx.payload_of(rig)
	var restored: Fx.Rig = Fx.make_rig(1)
	Fx.load_payload(restored, payload)
	var mismatches: PackedStringArray = Fx.payload_mismatches(payload, Fx.payload_of(restored), label + " após carregar")
	assert_true(mismatches.is_empty(), "campo a campo após carregar: " + ", ".join(mismatches))
	note("transportes de texto (%s), campos que mudam: JSON %d, var_to_str %d, base64 binário %d"
		% [label, Fx.transport_drift(payload, "json"), Fx.transport_drift(payload, "var"), Fx.transport_drift(payload, "b64")])
	var result: Array = Fx.continue_and_compare(rig, restored, ticks)
	note("%s: %d ticks após o carregamento, divergências %d; avisos %d, tosses %d, tosses canceladas %d"
		% [label, ticks, result[0], result[1], result[2], result[3]])
	assert_eq(result[0], 0, "%s: continuação idêntica à execução contínua, tick a tick" % label)


func test_per07_aviso_agendado_com_bombinha_alivio_agua_e_exaustao() -> void:
	var rig: Fx.Rig = Fx.run_to_pending_cough(707, MAX_TICKS_SEARCH)
	assert_not_null(rig, "a sequência chega a um aviso de tosse agendado")
	if rig == null:
		return
	assert_true(rig.resp.pending_cough_in >= 0.0, "o aviso agendado está pendente no ponto de salvamento")
	assert_true(rig.resp.medication_cooldown_remaining > 0.0, "cooldown da bombinha ativo")
	assert_true(rig.resp.relief_strength > 0.0, "alívio ativo")
	assert_true(rig.resp.water_effect_remaining > 0.0, "efeito da água ativo")
	assert_true(rig.stamina.exhausted, "stamina em exaustão")
	_check_point("ponto (a)", rig, CONTINUE_TICKS_SHORT)


func test_per07_cooldown_de_tosse_ativo() -> void:
	var rig: Fx.Rig = Fx.run_to_cough(708, MAX_TICKS_SEARCH)
	assert_not_null(rig, "a sequência tem uma tosse involuntária")
	if rig == null:
		return
	assert_true(rig.resp.cough_cooldown_remaining > 0.0, "o cooldown da tosse está ativo no ponto de salvamento")
	_check_point("ponto (b)", rig, CONTINUE_TICKS_SHORT)

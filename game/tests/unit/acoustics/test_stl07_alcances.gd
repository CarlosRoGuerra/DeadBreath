extends TestCase
## STL-07 (TEST_PLAN §2.4; DATA_STRUCTURES §2.3): os sete exemplos de alcance da config padrão, com ±0,2 m.
## Observer (hearing 15, margem −3). Cômodo interno: piso 22 → limiar 19. Exterior: piso 38 → limiar 35.
## Porão: piso 12 → limiar 15. O abafamento do guarda-roupa (−6 dB, exemplo de §2.3) entra na intensidade.
## Medição: bisseção sobre AcousticGraph.propagate e effective_threshold_db, andando em linha reta a partir da fonte.
## Se um alcance divergir do documentado, o teste reprova. Não ajustar o teste: relatar a divergência.
## Autor: AI Engineer (F3-001).

const Fx := preload("res://tests/unit/acoustics/fixtures/acoustic_fixture.gd")
const TOL_M: float = 0.2
const LIMIT_M: float = 60.0
const WARDROBE_MUFFLE_DB: float = 6.0


func _check_range(label: String, measured_m: float, expected_m: float) -> void:
	note("STL-07 %s: esperado %.2f m, medido %.3f m, diferença %.3f m" % [label, expected_m, measured_m,
		measured_m - expected_m])
	assert_almost_eq(measured_m, expected_m, TOL_M, label)


func _interior_graph() -> AcousticGraph:
	var graph: AcousticGraph = AcousticGraph.new(Fx.production_config())
	graph.add_room(&"interno", Fx.box(-100.0, 100.0, 0.0, 3.0, -100.0, 100.0), 22.0)
	return graph


func test_exemplo_1_respiracao_calma_no_guarda_roupa_e_inaudivel() -> void:
	var graph: AcousticGraph = _interior_graph()
	var sound: NoiseEvent = Fx.event(20.0 - WARDROBE_MUFFLE_DB, Vector3(0, 1, 0))
	var measured: float = Fx.max_audible_m(graph, sound, Fx.OBSERVER_HEARING_DB, Fx.OBSERVER_MARGIN_DB, LIMIT_M)
	note("STL-07 respiração calma no guarda-roupa: 20 − 6 = 14 dB < 19 dB, alcance medido %.3f m" % [measured])
	assert_eq(measured, 0.0, "inaudível a qualquer distância (14 dB < limiar 19 dB)")
	assert_false(Fx.audible_at(graph, sound, Vector3(1, 1, 0), Fx.OBSERVER_HEARING_DB, Fx.OBSERVER_MARGIN_DB),
		"nem a 1 m")


func test_exemplo_2_respiracao_ofegante_no_guarda_roupa_1_7_m() -> void:
	var graph: AcousticGraph = _interior_graph()
	var sound: NoiseEvent = Fx.event(30.0 - WARDROBE_MUFFLE_DB, Vector3(0, 1, 0))
	var measured: float = Fx.max_audible_m(graph, sound, Fx.OBSERVER_HEARING_DB, Fx.OBSERVER_MARGIN_DB, LIMIT_M)
	_check_range("respiração ofegante no guarda-roupa", measured, 1.7)


func test_exemplo_3_chiado_forte_no_guarda_roupa_6_6_m() -> void:
	var graph: AcousticGraph = _interior_graph()
	var sound: NoiseEvent = Fx.event(42.0 - WARDROBE_MUFFLE_DB, Vector3(0, 1, 0))
	var measured: float = Fx.max_audible_m(graph, sound, Fx.OBSERVER_HEARING_DB, Fx.OBSERVER_MARGIN_DB, LIMIT_M)
	_check_range("chiado forte no guarda-roupa", measured, 6.6)


func test_exemplo_4_tosse_atraves_de_uma_parede_10_m() -> void:
	var graph: AcousticGraph = AcousticGraph.new(Fx.production_config())
	graph.add_room(&"origem", Fx.box(-100.0, 0.0, 0.0, 3.0, -100.0, 100.0), 22.0)
	graph.add_room(&"ouvinte", Fx.box(0.0, 100.0, 0.0, 3.0, -100.0, 100.0), 22.0)
	var sound: NoiseEvent = Fx.event(65.0, Vector3(-0.5, 1, 0))
	var measured: float = Fx.max_audible_m(graph, sound, Fx.OBSERVER_HEARING_DB, Fx.OBSERVER_MARGIN_DB, LIMIT_M)
	_check_range("tosse através de uma parede", measured, 10.0)


func test_exemplo_5_tosse_atraves_de_duas_paredes_e_inaudivel() -> void:
	# Duas paredes: a sala do meio (x 0..1) é uma parede a menos; o ouvinte fica no quarto do fundo (x ≥ 1).
	var graph: AcousticGraph = AcousticGraph.new(Fx.production_config())
	graph.add_room(&"origem", Fx.box(-100.0, 0.0, 0.0, 3.0, -100.0, 100.0), 22.0)
	graph.add_room(&"meio", Fx.box(0.0, 1.0, 0.0, 3.0, -100.0, 100.0), 22.0)
	graph.add_room(&"fundo", Fx.box(1.0, 100.0, 0.0, 3.0, -100.0, 100.0), 22.0)
	var sound: NoiseEvent = Fx.event(65.0, Vector3(-0.5, 1, 0))
	for x: float in [1.0, 1.5, 3.0, 10.0, 50.0]:
		var listener: Vector3 = Vector3(x, 1, 0)
		var perceived: float = graph.propagate(sound, listener).perceived_db
		var threshold: float = graph.effective_threshold_db(listener, Fx.OBSERVER_HEARING_DB, Fx.OBSERVER_MARGIN_DB)
		note("STL-07 tosse através de duas paredes: ouvinte em x=%.1f m, %.2f dB percebidos, limiar %.1f dB" % [
			x, perceived, threshold])
		assert_true(perceived < threshold, "inaudível no quarto do fundo, x=%.1f m" % [x])


func test_exemplo_6_tosse_no_quintal_24_m() -> void:
	var graph: AcousticGraph = AcousticGraph.new(Fx.production_config())
	graph.add_room(&"quintal", Fx.box(-100.0, 100.0, 0.0, 3.0, -100.0, 100.0), 38.0)
	var sound: NoiseEvent = Fx.event(65.0, Vector3(0, 1, 0))
	var measured: float = Fx.max_audible_m(graph, sound, Fx.OBSERVER_HEARING_DB, Fx.OBSERVER_MARGIN_DB, LIMIT_M)
	_check_range("tosse no quintal (limiar 35)", measured, 24.0)


func test_exemplo_7_respiracao_ofegante_no_porao_2_7_m() -> void:
	var graph: AcousticGraph = AcousticGraph.new(Fx.production_config())
	graph.add_room(&"porao", Fx.box(-100.0, 100.0, -3.0, 0.0, -100.0, 100.0), 12.0)
	var sound: NoiseEvent = Fx.event(30.0 - WARDROBE_MUFFLE_DB, Vector3(0, -1.5, 0))
	var measured: float = Fx.max_audible_m(graph, sound, Fx.OBSERVER_HEARING_DB, Fx.OBSERVER_MARGIN_DB, LIMIT_M)
	_check_range("respiração ofegante no porão (limiar 15)", measured, 2.7)

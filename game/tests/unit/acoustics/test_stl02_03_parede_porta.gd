extends TestCase
## STL-02 (parede: ≥ 20 dB a menos que em linha livre, à mesma distância) e STL-03 (porta fechada reduz ≥ 14,5 dB
## em relação a aberta). TEST_PLAN §2.4; DATA_STRUCTURES §2.2. Autor: AI Engineer (F3-001).

const Fx := preload("res://tests/unit/acoustics/fixtures/acoustic_fixture.gd")
const TOL: float = 0.01
const INTENSITY_DB: float = 60.0


func test_stl02_atraves_de_parede_perde_25_db_na_mesma_distancia() -> void:
	var config: AcousticConfig = Fx.production_config()
	var open_space: AcousticGraph = AcousticGraph.new(config)
	open_space.add_room(&"sala", Fx.box(-10.0, 10.0, 0.0, 3.0, -10.0, 10.0), 22.0)
	var free: PropagationResult = open_space.propagate(Fx.event(INTENSITY_DB, Vector3(-2, 1.5, 0)), Vector3(2, 1.5, 0))

	var walled: AcousticGraph = AcousticGraph.new(config)
	walled.add_room(&"esquerda", Fx.box(-10.0, 0.0, 0.0, 3.0, -10.0, 10.0), 22.0)
	walled.add_room(&"direita", Fx.box(0.0, 10.0, 0.0, 3.0, -10.0, 10.0), 22.0)
	var wall: PropagationResult = walled.propagate(Fx.event(INTENSITY_DB, Vector3(-2, 1.5, 0)), Vector3(2, 1.5, 0))

	var difference: float = free.perceived_db - wall.perceived_db
	assert_true(difference >= 20.0, "parede: diferença de %.2f dB, exigido ≥ 20" % [difference])
	assert_almost_eq(difference, 25.0, TOL, "a diferença exata é a parede de 25 dB (DATA §2.2)")
	assert_false(free.through_wall, "linha livre não atravessa parede")
	assert_true(wall.through_wall, "a rota direta atravessa a parede")
	assert_true(wall.path_portals.is_empty(), "sem portal, o caminho é direto")


func test_stl03_porta_fechada_reduz_15_db_com_a_porta_na_rota() -> void:
	var graph: AcousticGraph = AcousticGraph.new(Fx.production_config())
	graph.add_room(&"a", Fx.box(-10.0, 2.0, 0.0, 3.0, -10.0, 10.0), 22.0)
	graph.add_room(&"b", Fx.box(2.0, 10.0, 0.0, 3.0, -10.0, 10.0), 22.0)
	graph.add_portal(&"porta", &"a", &"b", Vector3(2.0, 1.5, 0.0))
	var sound: NoiseEvent = Fx.event(INTENSITY_DB, Vector3(0, 1.5, 0))
	var listener: Vector3 = Vector3(4, 1.5, 0)

	var opened: PropagationResult = graph.propagate(sound, listener)
	graph.set_portal_open(&"porta", false)
	var closed: PropagationResult = graph.propagate(sound, listener)

	var reduction: float = opened.perceived_db - closed.perceived_db
	assert_true(reduction >= 14.5, "porta fechada: redução de %.2f dB, exigido ≥ 14,5" % [reduction])
	assert_almost_eq(reduction, 15.0, TOL, "18 − 3 = 15 dB (DATA §2.2)")
	assert_eq(opened.path_portals, [&"porta"], "aberta: a rota passa pela porta")
	assert_eq(closed.path_portals, [&"porta"], "fechada: a porta ainda é a melhor rota (18 dB < 25 dB da parede)")
	assert_false(closed.through_wall, "a rota pela porta não conta como parede")


func test_stl03_porta_longe_da_rota_nao_muda_o_nivel() -> void:
	# Limite do modelo, documentado: se a parede é o melhor caminho, a porta só vale quando está na rota.
	var graph: AcousticGraph = AcousticGraph.new(Fx.production_config())
	graph.add_room(&"a", Fx.box(-10.0, 0.0, 0.0, 3.0, -10.0, 10.0), 22.0)
	graph.add_room(&"b", Fx.box(0.0, 10.0, 0.0, 3.0, -10.0, 10.0), 22.0)
	graph.add_portal(&"porta_distante", &"a", &"b", Vector3(0.0, 1.5, -9.0))
	var sound: NoiseEvent = Fx.event(INTENSITY_DB, Vector3(-0.5, 1.5, 0))
	var listener: Vector3 = Vector3(0.5, 1.5, 0)
	var opened: PropagationResult = graph.propagate(sound, listener)
	graph.set_portal_open(&"porta_distante", false)
	var closed: PropagationResult = graph.propagate(sound, listener)
	assert_almost_eq(closed.perceived_db - opened.perceived_db, 0.0, TOL,
		"porta a 18 m da rota: o caminho pela parede (25 dB) vence nos dois estados")
	assert_true(closed.through_wall, "o caminho escolhido é o direto pela parede")

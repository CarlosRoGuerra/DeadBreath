extends TestCase
## AcousticGraph (F3-001): fronteiras (parede, vão, exterior, piso), busca por portais (Dijkstra com rótulos não
## dominados) e casos de borda (mesma sala, sem caminho, fora de qualquer sala, entradas inválidas).
## Regras de fronteira: AcousticGraph (cabeçalho). Autor: AI Engineer (F3-001).

const Fx := preload("res://tests/unit/acoustics/fixtures/acoustic_fixture.gd")
const TOL: float = 0.0001
const INTENSITY_DB: float = 80.0


func _graph() -> AcousticGraph:
	return AcousticGraph.new(Fx.production_config())


func test_mesma_sala_so_perda_por_distancia() -> void:
	var graph: AcousticGraph = _graph()
	graph.add_room(&"sala", Fx.box(-10.0, 10.0, 0.0, 3.0, -10.0, 10.0), 22.0)
	var source: Vector3 = Vector3(-2, 1, 0)
	var result: PropagationResult = graph.propagate(Fx.event(INTENSITY_DB, source), Vector3(3, 1, 0))
	assert_almost_eq(result.perceived_db, INTENSITY_DB - Fx.distance_loss_db(5.0), TOL, "5 m, sem fronteira")
	assert_false(result.through_wall, "mesma sala: nenhuma parede")
	assert_true(result.path_portals.is_empty(), "caminho direto: sem portais")
	assert_eq(result.entry_point, source, "caminho direto: entry_point é a fonte")


func test_parede_entre_salas_vizinhas_conta_uma_vez() -> void:
	var graph: AcousticGraph = _graph()
	graph.add_room(&"esquerda", Fx.box(-10.0, 0.0, 0.0, 3.0, -10.0, 10.0), 22.0)
	graph.add_room(&"direita", Fx.box(0.0, 10.0, 0.0, 3.0, -10.0, 10.0), 22.0)
	var result: PropagationResult = graph.propagate(Fx.event(INTENSITY_DB, Vector3(-2, 1, 0)), Vector3(2, 1, 0))
	assert_almost_eq(result.perceived_db, INTENSITY_DB - Fx.distance_loss_db(4.0) - 25.0, TOL,
		"parede compartilhada: uma única parede de 25 dB")
	assert_true(result.through_wall, "atravessou uma parede")


func test_vao_entre_salas_conta_duas_paredes() -> void:
	var graph: AcousticGraph = _graph()
	graph.add_room(&"esquerda", Fx.box(-10.0, -1.0, 0.0, 3.0, -10.0, 10.0), 22.0)
	graph.add_room(&"direita", Fx.box(1.0, 10.0, 0.0, 3.0, -10.0, 10.0), 22.0)
	var result: PropagationResult = graph.propagate(Fx.event(INTENSITY_DB, Vector3(-2, 1, 0)), Vector3(2, 1, 0))
	assert_almost_eq(result.perceived_db, INTENSITY_DB - Fx.distance_loss_db(4.0) - 50.0, TOL,
		"com vão no meio: sai de uma sala (parede), passa pelo exterior e entra na outra (parede)")


func test_exterior_para_sala_conta_uma_parede() -> void:
	var graph: AcousticGraph = _graph()
	graph.add_room(&"sala", Fx.box(0.0, 10.0, 0.0, 3.0, -10.0, 10.0), 22.0)
	var result: PropagationResult = graph.propagate(Fx.event(INTENSITY_DB, Vector3(-2, 1, 0)), Vector3(2, 1, 0))
	assert_almost_eq(result.perceived_db, INTENSITY_DB - Fx.distance_loss_db(4.0) - 25.0, TOL,
		"fonte fora de sala: a entrada na sala cruza uma parede")
	assert_true(result.through_wall, "a entrada na sala atravessa parede")


func test_salas_empilhadas_contam_piso_e_nao_parede() -> void:
	var graph: AcousticGraph = _graph()
	graph.add_room(&"porao", Fx.box(-5.0, 5.0, -3.0, 0.0, -5.0, 5.0), 12.0)
	graph.add_room(&"terreo", Fx.box(-5.0, 5.0, 0.0, 3.0, -5.0, 5.0), 22.0)
	var result: PropagationResult = graph.propagate(Fx.event(INTENSITY_DB, Vector3(0, -1.5, 0)), Vector3(0, 1.5, 0))
	assert_almost_eq(result.perceived_db, INTENSITY_DB - Fx.distance_loss_db(3.0) - 30.0, TOL,
		"face horizontal: piso de 30 dB, não parede de 25 dB")
	assert_false(result.through_wall, "piso não conta como parede em through_wall")


func test_dijkstra_encadeia_dois_portais() -> void:
	var graph: AcousticGraph = _graph()
	graph.add_room(&"a", Fx.box(-10.0, 0.0, 0.0, 3.0, -10.0, 10.0), 22.0)
	graph.add_room(&"b", Fx.box(0.0, 10.0, 0.0, 3.0, -10.0, 10.0), 22.0)
	graph.add_room(&"c", Fx.box(10.0, 20.0, 0.0, 3.0, -10.0, 10.0), 22.0)
	graph.add_portal(&"p1", &"a", &"b", Vector3(0.0, 1.5, 0.0))
	graph.add_portal(&"p2", &"b", &"c", Vector3(10.0, 1.5, 0.0))
	var result: PropagationResult = graph.propagate(Fx.event(INTENSITY_DB, Vector3(-1, 1.5, 0)), Vector3(11, 1.5, 0))
	assert_eq(result.path_portals, [&"p1", &"p2"], "a rota passa pelos dois portais, em ordem")
	assert_eq(result.entry_point, Vector3(10.0, 1.5, 0.0), "entry_point é o último portal do caminho")
	assert_almost_eq(result.perceived_db, INTENSITY_DB - Fx.distance_loss_db(12.0) - 6.0, TOL,
		"poligonal fonte→p1→p2→ouvinte (1 + 10 + 1 m) e 3 dB por portal aberto")
	assert_false(result.through_wall, "caminho por portais não tem parede")


func test_porta_fechada_desvia_para_a_rota_alternativa() -> void:
	# S (x −10..0, z 0..4) e L (x 0..10, z 0..4) são vizinhas por d1. M (x −10..10, z 4..8) liga S a L por d2 e d3.
	var graph: AcousticGraph = _graph()
	graph.add_room(&"s", Fx.box(-10.0, 0.0, 0.0, 3.0, 0.0, 4.0), 22.0)
	graph.add_room(&"l", Fx.box(0.0, 10.0, 0.0, 3.0, 0.0, 4.0), 22.0)
	graph.add_room(&"m", Fx.box(-10.0, 10.0, 0.0, 3.0, 4.0, 8.0), 22.0)
	graph.add_portal(&"d1", &"s", &"l", Vector3(0.0, 1.5, 2.0))
	graph.add_portal(&"d2", &"s", &"m", Vector3(-1.0, 1.5, 4.0))
	graph.add_portal(&"d3", &"m", &"l", Vector3(1.0, 1.5, 4.0))
	var sound: NoiseEvent = Fx.event(INTENSITY_DB, Vector3(-1, 1.5, 2))
	var listener: Vector3 = Vector3(1, 1.5, 2)

	var opened: PropagationResult = graph.propagate(sound, listener)
	assert_eq(opened.path_portals, [&"d1"], "d1 aberta: o caminho curto vence")
	assert_almost_eq(opened.perceived_db, INTENSITY_DB - Fx.distance_loss_db(2.0) - 3.0, TOL, "d1 aberta: 2 m e 3 dB")

	graph.set_portal_open(&"d1", false)
	var closed: PropagationResult = graph.propagate(sound, listener)
	assert_eq(closed.path_portals, [&"d2", &"d3"], "d1 fechada: a rota por M (3 + 3 dB) vence a d1 fechada (18 dB)")
	assert_almost_eq(closed.perceived_db, INTENSITY_DB - Fx.distance_loss_db(6.0) - 6.0, TOL,
		"rota S→d2→M→d3→L: 2 + 2 + 2 m e 6 dB de portais")


func test_busca_escolhe_o_maior_nivel_e_nao_o_caminho_mais_curto() -> void:
	# Dois caminhos até T. X: S0→p1→M→pmt→T, 1 + 10 + 5 m, com p1 fechada (18 dB) e pmt aberta (3 dB): perda 21 dB.
	# Y: S0→p2→N→px→M→pmt→T, 6,4 + 10 + 7,1 + 5 m, com três portais abertos (9 dB). Y é mais longo e perde menos.
	# Uma busca que descarta rótulos só pelo comprimento ficaria com X e erraria. Esta é a regra do Pareto.
	var graph: AcousticGraph = _graph()
	graph.add_room(&"s0", Fx.box(-10.0, 0.0, 0.0, 3.0, 0.0, 10.0), 22.0)
	graph.add_room(&"m", Fx.box(0.0, 10.0, 0.0, 3.0, 0.0, 10.0), 22.0)
	graph.add_room(&"t", Fx.box(10.0, 20.0, 0.0, 3.0, 0.0, 10.0), 22.0)
	graph.add_room(&"n", Fx.box(-10.0, 10.0, 0.0, 3.0, 10.0, 20.0), 22.0)
	var p1: Vector3 = Vector3(0.0, 1.5, 5.0)
	var pmt: Vector3 = Vector3(10.0, 1.5, 5.0)
	var p2: Vector3 = Vector3(-5.0, 1.5, 10.0)
	var px: Vector3 = Vector3(5.0, 1.5, 10.0)
	graph.add_portal(&"p1", &"s0", &"m", p1)
	graph.add_portal(&"pmt", &"m", &"t", pmt)
	graph.add_portal(&"p2", &"s0", &"n", p2)
	graph.add_portal(&"px", &"n", &"m", px)
	graph.set_portal_open(&"p1", false)
	var source: Vector3 = Vector3(-1.0, 1.5, 5.0)
	var listener: Vector3 = Vector3(15.0, 1.5, 5.0)
	var result: PropagationResult = graph.propagate(Fx.event(INTENSITY_DB, source), listener)
	var length_y: float = source.distance_to(p2) + p2.distance_to(px) + px.distance_to(pmt) + pmt.distance_to(listener)
	assert_eq(result.path_portals, [&"p2", &"px", &"pmt"], "o caminho de maior nível é o mais longo, com menos perda")
	assert_almost_eq(result.perceived_db, INTENSITY_DB - Fx.distance_loss_db(length_y) - 9.0, TOL,
		"Y: comprimento %.2f m e 3 portais abertos (9 dB)" % [length_y])


func test_caminho_direto_vence_com_porta_longe() -> void:
	var graph: AcousticGraph = _graph()
	graph.add_room(&"a", Fx.box(-10.0, 0.0, 0.0, 3.0, -10.0, 10.0), 22.0)
	graph.add_room(&"b", Fx.box(0.0, 10.0, 0.0, 3.0, -10.0, 10.0), 22.0)
	graph.add_portal(&"longe", &"a", &"b", Vector3(0.0, 1.5, -9.0))
	var result: PropagationResult = graph.propagate(Fx.event(INTENSITY_DB, Vector3(-0.5, 1.5, 0)), Vector3(0.5, 1.5, 0))
	assert_true(result.path_portals.is_empty(), "a porta a 18 m do caminho não vence a parede")
	assert_true(result.through_wall, "o caminho escolhido atravessa a parede")


func test_salas_sem_portal_so_pelo_caminho_direto() -> void:
	var graph: AcousticGraph = _graph()
	graph.add_room(&"a", Fx.box(-10.0, 0.0, 0.0, 3.0, -10.0, 10.0), 22.0)
	graph.add_room(&"b", Fx.box(0.0, 10.0, 0.0, 3.0, -10.0, 10.0), 22.0)
	var result: PropagationResult = graph.propagate(Fx.event(INTENSITY_DB, Vector3(-2, 1, 0)), Vector3(2, 1, 0))
	assert_true(result.path_portals.is_empty(), "sem portal entre as salas não há rota por portal")
	assert_true(result.through_wall, "o caminho direto atravessa a parede")


func test_fora_de_salas_so_caminho_direto() -> void:
	var graph: AcousticGraph = _graph()
	graph.add_room(&"sala_longe", Fx.box(100.0, 110.0, 0.0, 3.0, 100.0, 110.0), 22.0)
	var result: PropagationResult = graph.propagate(Fx.event(INTENSITY_DB, Vector3(0, 1, 0)), Vector3(6, 1, 0))
	assert_almost_eq(result.perceived_db, INTENSITY_DB - Fx.distance_loss_db(6.0), TOL, "ambos fora de sala: só distância")
	assert_eq(graph.room_at(Vector3(0, 1, 0)), &"", "fora de qualquer sala: room_at é vazio")


func test_room_at_e_semiaberto() -> void:
	var graph: AcousticGraph = _graph()
	graph.add_room(&"sala", Fx.box(0.0, 10.0, 0.0, 3.0, 0.0, 10.0), 22.0)
	assert_eq(graph.room_at(Vector3(0.0, 1.0, 5.0)), &"sala", "face mínima pertence à sala")
	assert_eq(graph.room_at(Vector3(10.0, 1.0, 5.0)), &"", "face máxima não pertence à sala")
	assert_eq(graph.room_at(Vector3(-0.001, 1.0, 5.0)), &"", "logo antes da face mínima, fora")
	assert_eq(graph.room_at(Vector3(5.0, 1.0, 5.0)), &"sala", "interior")


func test_entradas_invalidas_sao_recusadas() -> void:
	var graph: AcousticGraph = _graph()
	graph.add_room(&"sala", Fx.box(0.0, 10.0, 0.0, 3.0, 0.0, 10.0), 22.0)
	expect_engine_error("já existe")
	graph.add_room(&"sala", Fx.box(20.0, 30.0, 0.0, 3.0, 0.0, 10.0), 22.0)
	expect_engine_error("volume não positivo")
	graph.add_room(&"vazia", Fx.box(20.0, 20.0, 0.0, 3.0, 0.0, 10.0), 22.0)
	expect_engine_error("liga sala inexistente")
	graph.add_portal(&"p", &"sala", &"nao_existe", Vector3(10.0, 1.0, 5.0))
	expect_engine_error("liga a sala")
	graph.add_portal(&"p", &"sala", &"sala", Vector3(10.0, 1.0, 5.0))
	expect_engine_error("não existe")
	graph.set_portal_open(&"inexistente", false)
	expect_engine_error("não existe")
	assert_false(graph.is_portal_open(&"inexistente"), "portal inexistente: estado falso")
	assert_eq(graph.room_at(Vector3(25.0, 1.0, 5.0)), &"", "a sala inválida não foi adicionada")
	assert_eq(graph.room_at(Vector3(15.0, 1.0, 5.0)), &"", "a sala de volume zero não foi adicionada")

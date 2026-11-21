extends TestCase
## Audibilidade (DATA_STRUCTURES §2.3): limiar efetivo = max(hearing_threshold_db; piso da sala do ouvinte +
## offset climático + masking_margin_db). Tabela de perfis (Observer, Leader, Aggressive) e do jogador.
## Autor: AI Engineer (F3-001).

const Fx := preload("res://tests/unit/acoustics/fixtures/acoustic_fixture.gd")
const TOL: float = 0.0001
const LEADER_HEARING_DB: float = 20.0
const LEADER_MARGIN_DB: float = 0.0
const AGGRESSIVE_HEARING_DB: float = 24.0
const AGGRESSIVE_MARGIN_DB: float = 3.0
## Linhas de DATA §2.3: piso da sala, depois os limiares efetivos de Observer, Leader e Aggressive.
const PROFILE_TABLE: Array = [
	[12.0, 15.0, 20.0, 24.0],
	[22.0, 19.0, 22.0, 25.0],
	[28.0, 25.0, 28.0, 31.0],
	[38.0, 35.0, 38.0, 41.0],
]


func _graph_with_floor(floor_db: float) -> AcousticGraph:
	var graph: AcousticGraph = AcousticGraph.new(Fx.production_config())
	graph.add_room(&"sala", Fx.box(-10.0, 10.0, 0.0, 3.0, -10.0, 10.0), floor_db)
	return graph


func test_tabela_de_limiares_por_perfil_de_data_2_3() -> void:
	var listener: Vector3 = Vector3(0, 1, 0)
	for row: Array in PROFILE_TABLE:
		var graph: AcousticGraph = _graph_with_floor(float(row[0]))
		var observer: float = graph.effective_threshold_db(listener, Fx.OBSERVER_HEARING_DB, Fx.OBSERVER_MARGIN_DB)
		var leader: float = graph.effective_threshold_db(listener, LEADER_HEARING_DB, LEADER_MARGIN_DB)
		var aggressive: float = graph.effective_threshold_db(listener, AGGRESSIVE_HEARING_DB, AGGRESSIVE_MARGIN_DB)
		var label: String = "piso %.0f dB" % [float(row[0])]
		assert_almost_eq(observer, float(row[1]), TOL, "Observer, " + label)
		assert_almost_eq(leader, float(row[2]), TOL, "Leader, " + label)
		assert_almost_eq(aggressive, float(row[3]), TOL, "Aggressive, " + label)


func test_limiar_do_jogador_e_o_piso_da_sala() -> void:
	var listener: Vector3 = Vector3(0, 1, 0)
	for floor_db: float in [12.0, 22.0, 28.0, 38.0]:
		var graph: AcousticGraph = _graph_with_floor(floor_db)
		assert_almost_eq(graph.effective_threshold_db(listener, Fx.PLAYER_HEARING_DB, Fx.PLAYER_MARGIN_DB), floor_db, TOL,
			"jogador (10 dB, margem 0) no piso %.0f: limiar é o piso" % [floor_db])


func test_clima_soma_ao_piso_e_so_ao_limiar() -> void:
	var graph: AcousticGraph = _graph_with_floor(22.0)
	var listener: Vector3 = Vector3(0, 1, 0)
	graph.set_weather_floor_offset(20.0)
	assert_eq(graph.weather_floor_offset_db(), 20.0, "offset guardado")
	assert_almost_eq(graph.effective_threshold_db(listener, Fx.OBSERVER_HEARING_DB, Fx.OBSERVER_MARGIN_DB), 39.0, TOL,
		"trovão: 22 + 20 − 3 = 39 dB para o Observer")
	var sound: NoiseEvent = Fx.event(60.0, Vector3(3, 1, 0))
	var perceived_with_thunder: float = graph.propagate(sound, listener).perceived_db
	graph.set_weather_floor_offset(0.0)
	var perceived_without: float = graph.propagate(sound, listener).perceived_db
	assert_almost_eq(perceived_with_thunder, perceived_without, TOL, "o clima não altera o nível percebido, só o limiar")


func test_limiar_com_chuva_no_porao_para_o_jogador() -> void:
	var graph: AcousticGraph = _graph_with_floor(12.0)
	graph.set_weather_floor_offset(20.0)
	assert_almost_eq(graph.effective_threshold_db(Vector3(0, 1, 0), Fx.PLAYER_HEARING_DB, Fx.PLAYER_MARGIN_DB), 32.0, TOL,
		"porão com trovão: max(10; 12 + 20) = 32 dB")


func test_fora_de_sala_usa_o_piso_exterior() -> void:
	var graph: AcousticGraph = _graph_with_floor(12.0)
	var outside: Vector3 = Vector3(50, 1, 50)
	assert_almost_eq(graph.ambient_floor_at(outside), AcousticGraph.OUTSIDE_AMBIENT_FLOOR_DB, TOL,
		"fora de qualquer sala: piso 38 dB (linha Exterior)")
	assert_almost_eq(graph.effective_threshold_db(outside, Fx.OBSERVER_HEARING_DB, Fx.OBSERVER_MARGIN_DB), 35.0, TOL,
		"Observer fora de sala: 38 − 3 = 35 dB")

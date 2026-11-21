extends TestCase
## NOI-02 (TEST_PLAN §2.3; NOI-INV-3): propagação pura e determinística. Mesmo grafo e evento dão o mesmo resultado;
## a varredura longa de "fechar porta nunca aumenta" fica em tests/property/acoustics/. Também: a assinatura de
## AcousticGraph.propagate é a de AcousticPropagation.perceive (a troca da F3-002 não muda a interface), e o caso
## sem portal bate com a propagação provisória da F2. Autor: AI Engineer (F3-001).

const Fx := preload("res://tests/unit/acoustics/fixtures/acoustic_fixture.gd")
const TOL: float = 0.0001
const PROPAGATION_SCRIPT: String = "res://sim/acoustics/acoustic_propagation.gd"


## Duas salas com porta na parede compartilhada e uma segunda rota por outra porta.
func _two_rooms(config: AcousticConfig) -> AcousticGraph:
	var graph: AcousticGraph = AcousticGraph.new(config)
	graph.add_room(&"a", Fx.box(-10.0, 0.0, 0.0, 3.0, -10.0, 10.0), 22.0)
	graph.add_room(&"b", Fx.box(0.0, 10.0, 0.0, 3.0, -10.0, 10.0), 22.0)
	graph.add_portal(&"porta", &"a", &"b", Vector3(0.0, 1.5, 0.5))
	graph.add_portal(&"janela", &"a", &"b", Vector3(0.0, 2.0, -6.0))
	return graph


func _same(first: PropagationResult, second: PropagationResult) -> bool:
	return absf(first.perceived_db - second.perceived_db) <= TOL and first.path_portals == second.path_portals \
		and first.through_wall == second.through_wall and first.entry_point == second.entry_point


func _signature(method: Dictionary) -> String:
	var parts: PackedStringArray = PackedStringArray()
	var args: Array = method.get("args", [])
	for arg: Dictionary in args:
		parts.append("%s:%s:%s" % [arg.get("name"), arg.get("type"), arg.get("class_name")])
	var ret: Dictionary = method.get("return", {})
	return "(%s)->%s:%s" % [", ".join(parts), ret.get("type"), ret.get("class_name")]


func _method_named(methods: Array, wanted: String) -> Dictionary:
	for method: Dictionary in methods:
		if str(method.get("name")) == wanted:
			return method
	return {}


func test_mesmo_grafo_e_evento_mesmo_resultado() -> void:
	var config: AcousticConfig = Fx.production_config()
	var graph: AcousticGraph = _two_rooms(config)
	var sound: NoiseEvent = Fx.event(50.0, Vector3(-1, 1, 0.5))
	var listener: Vector3 = Vector3(3, 1, 0)
	var first: PropagationResult = graph.propagate(sound, listener)
	var second: PropagationResult = graph.propagate(sound, listener)
	assert_true(_same(first, second), "duas chamadas com o mesmo grafo e evento dão o mesmo resultado")


func test_grafos_iguais_construidos_separadamente_dao_o_mesmo_resultado() -> void:
	var config: AcousticConfig = Fx.production_config()
	var sound: NoiseEvent = Fx.event(50.0, Vector3(-1, 1, 0.5))
	var listener: Vector3 = Vector3(3, 1, 0)
	var first: PropagationResult = _two_rooms(config).propagate(sound, listener)
	var second: PropagationResult = _two_rooms(config).propagate(sound, listener)
	assert_true(_same(first, second), "grafos construídos do mesmo jeito: mesmo resultado")


func test_propagar_nao_altera_evento_nem_grafo() -> void:
	var graph: AcousticGraph = _two_rooms(Fx.production_config())
	var sound: NoiseEvent = Fx.event(50.0, Vector3(-1, 1, 0.5))
	var position_before: Vector3 = sound.position
	graph.propagate(sound, Vector3(3, 1, 0))
	assert_almost_eq(sound.intensity_db, 50.0, TOL, "o evento não é alterado")
	assert_eq(sound.position, position_before, "a posição do evento não é alterada")
	assert_true(graph.is_portal_open(&"porta"), "o grafo não muda de estado")
	assert_eq(graph.room_at(Vector3(-1, 1, 0.5)), &"a", "as salas não mudam")


func test_ordem_das_consultas_nao_muda_resultado() -> void:
	var graph: AcousticGraph = _two_rooms(Fx.production_config())
	var sound_one: NoiseEvent = Fx.event(50.0, Vector3(-1, 1, 0.5))
	var sound_two: NoiseEvent = Fx.event(35.0, Vector3(-4, 1, -5))
	var listener_one: Vector3 = Vector3(3, 1, 0)
	var listener_two: Vector3 = Vector3(5, 1, -2)
	var a_then_b_one: PropagationResult = graph.propagate(sound_one, listener_one)
	var a_then_b_two: PropagationResult = graph.propagate(sound_two, listener_two)
	var b_then_a_two: PropagationResult = graph.propagate(sound_two, listener_two)
	var b_then_a_one: PropagationResult = graph.propagate(sound_one, listener_one)
	assert_true(_same(a_then_b_one, b_then_a_one), "consulta 1 não depende da ordem")
	assert_true(_same(a_then_b_two, b_then_a_two), "consulta 2 não depende da ordem")


func test_sem_portal_bate_com_a_propagacao_provisoria_da_f2() -> void:
	var graph: AcousticGraph = AcousticGraph.new(Fx.production_config())
	graph.add_room(&"sala", Fx.box(-50.0, 50.0, 0.0, 3.0, -50.0, 50.0), 22.0)
	var sound: NoiseEvent = Fx.event(60.0, Vector3(0, 1, 0))
	var listener: Vector3 = Vector3(7.3, 1, 2.1)
	var direct: PropagationResult = graph.propagate(sound, listener)
	var provisional: PropagationResult = AcousticPropagation.perceive(sound, listener)
	assert_almost_eq(direct.perceived_db, provisional.perceived_db, TOL,
		"mesma sala, sem portal: a perda é a da F2 (20·log10 + 0,1·d)")


func test_fechar_porta_nao_aumenta_amostra_fixa() -> void:
	var graph: AcousticGraph = _two_rooms(Fx.production_config())
	var sound: NoiseEvent = Fx.event(60.0, Vector3(-1, 1, 0.5))
	var listeners: Array[Vector3] = [Vector3(1, 1, 0), Vector3(3, 1, 0), Vector3(6, 1, -4), Vector3(9, 1, 8)]
	var opened: Array[float] = []
	for listener: Vector3 in listeners:
		opened.append(graph.propagate(sound, listener).perceived_db)
	graph.set_portal_open(&"porta", false)
	graph.set_portal_open(&"janela", false)
	for index: int in range(listeners.size()):
		var closed: float = graph.propagate(sound, listeners[index]).perceived_db
		assert_true(closed <= opened[index] + TOL,
			"ouvinte %d: fechadas %.3f dB, abertas %.3f dB" % [index, closed, opened[index]])


func test_assinatura_de_propagate_igual_a_de_perceive() -> void:
	var graph: AcousticGraph = _two_rooms(Fx.production_config())
	var propagate_method: Dictionary = _method_named(graph.get_method_list(), "propagate")
	var static_script: GDScript = load(PROPAGATION_SCRIPT) as GDScript
	var perceive_method: Dictionary = _method_named(static_script.get_script_method_list(), "perceive")
	assert_false(propagate_method.is_empty(), "AcousticGraph.propagate existe")
	assert_false(perceive_method.is_empty(), "AcousticPropagation.perceive existe")
	assert_eq(_signature(propagate_method), _signature(perceive_method), "mesmos argumentos (nomes, tipos) e mesmo retorno")

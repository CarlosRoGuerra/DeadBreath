extends TestCase
## F4-002 (COMPONENT_CONTRACTS §7.2): HearingSensor sem mundo. Grupo "hearing_sensor", padrões do OBSERVER (DATA §3.1:
## limiar 15, margem −3), fila de entrega em ordem, drain que esvazia e limite da fila (64; o mais antigo sai).
## receive() é chamado aqui direto só para testar a fila; o caminho real é o AcousticWorld (NOI-01).
## Autor: AI Engineer (F4-002).

const TOL: float = 0.0001


func _heard(perceived_db: float) -> HeardNoise:
	var heard: HeardNoise = HeardNoise.new()
	heard.perceived_db = perceived_db
	return heard


func _sensor() -> HearingSensor:
	var sensor: HearingSensor = HearingSensor.new()
	add_child_autofree(sensor)
	return sensor


func test_entra_no_grupo_e_tem_padroes_do_observer() -> void:
	var sensor: HearingSensor = _sensor()
	assert_eq(HearingSensor.GROUP, &"hearing_sensor", "nome do grupo")
	assert_true(sensor.is_in_group(&"hearing_sensor"), "o sensor está no grupo hearing_sensor")
	assert_almost_eq(sensor.hearing_threshold_db, 15.0, TOL, "limiar do OBSERVER (DATA §3.1)")
	assert_almost_eq(sensor.masking_margin_db, -3.0, TOL, "margem do OBSERVER (DATA §3.1)")
	assert_eq(sensor.owner_id, &"", "sem dono até o controlador definir")


func test_drain_devolve_na_ordem_e_esvazia() -> void:
	var sensor: HearingSensor = _sensor()
	sensor.receive(_heard(20.0))
	sensor.receive(_heard(30.0))
	var first: Array[HeardNoise] = sensor.drain()
	assert_eq(first.size(), 2, "dois sons entregues")
	if first.size() == 2:
		assert_almost_eq(first[0].perceived_db, 20.0, TOL, "primeiro a chegar, primeiro a sair")
		assert_almost_eq(first[1].perceived_db, 30.0, TOL, "segundo")
	assert_eq(sensor.drain().size(), 0, "o segundo drain sai vazio")


func test_receive_nulo_e_ignorado() -> void:
	var sensor: HearingSensor = _sensor()
	sensor.receive(null)
	assert_eq(sensor.drain().size(), 0, "nulo não entra na fila")


func test_fila_limitada_descarta_o_mais_antigo() -> void:
	var sensor: HearingSensor = _sensor()
	for index: int in range(HearingSensor.MAX_PENDING + 6):
		sensor.receive(_heard(float(index)))
	var kept: Array[HeardNoise] = sensor.drain()
	assert_eq(kept.size(), HearingSensor.MAX_PENDING, "a fila para em 64")
	if kept.size() == HearingSensor.MAX_PENDING:
		assert_almost_eq(kept[0].perceived_db, 6.0, TOL, "os 6 mais antigos saíram")
		assert_almost_eq(kept[kept.size() - 1].perceived_db, float(HearingSensor.MAX_PENDING + 5), TOL,
			"o mais recente ficou")


func test_depois_do_drain_a_fila_volta_a_receber() -> void:
	var sensor: HearingSensor = _sensor()
	sensor.receive(_heard(10.0))
	sensor.drain()
	sensor.receive(_heard(11.0))
	var again: Array[HeardNoise] = sensor.drain()
	assert_eq(again.size(), 1, "novo som depois do drain")

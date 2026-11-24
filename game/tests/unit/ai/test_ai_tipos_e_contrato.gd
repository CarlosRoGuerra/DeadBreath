extends TestCase
## Tipos de DATA_STRUCTURES §3 (F4-003): campos, valores padrão e a base abstrata BrainWorldQuery.
## Autor: AI Engineer (F4-003). Reflexão sobre as propriedades de script, como o NOI-03.


func _script_fields(instance: Object) -> PackedStringArray:
	var fields: PackedStringArray = PackedStringArray()
	for prop: Dictionary in instance.get_property_list():
		if (int(prop.get("usage", 0)) & PROPERTY_USAGE_SCRIPT_VARIABLE) != 0:
			fields.append(str(prop.get("name")))
	fields.sort()
	return fields


func test_squad_message_so_tipo_com_campos_de_data() -> void:
	var fields: PackedStringArray = _script_fields(SquadMessage.new())
	var expected: PackedStringArray = PackedStringArray(["deliver_at", "kind", "position", "sender_id", "sent_at"])
	assert_eq(fields, expected, "SquadMessage: campos de DATA §3")


func test_perception_batch_squad_vazio_na_f4() -> void:
	var batch: PerceptBatch = PerceptBatch.new()
	assert_true(batch.visual.is_empty(), "visual começa vazio")
	assert_true(batch.heard.is_empty(), "heard começa vazio")
	assert_true(batch.squad.is_empty(), "squad vazio na F4 (D4-02)")


func test_enemy_intent_padroes_sao_neutros() -> void:
	var intent: EnemyIntent = EnemyIntent.new()
	assert_eq(intent.move_speed, 0.0, "velocidade padrão 0")
	assert_eq(intent.inspect_hideable, &"", "sem inspeção por padrão")
	assert_eq(intent.voice_line, &"", "sem fala por padrão")


func test_perception_record_create_preenche_os_campos() -> void:
	var record_value: PerceptionRecord = PerceptionRecord.create(Vector3(1.0, 0.0, 2.0), 3.5, 0.75, &"vision")
	assert_eq(record_value.position, Vector3(1.0, 0.0, 2.0), "posição")
	assert_almost_eq(record_value.timestamp, 3.5, 0.000001, "instante")
	assert_almost_eq(record_value.confidence, 0.75, 0.000001, "confiança")
	assert_eq(record_value.source, &"vision", "origem")


func test_hideable_info_create_preenche_os_campos() -> void:
	var info: HideableInfo = HideableInfo.create(&"wardrobe_hall", Vector3(4.0, 0.0, 4.0))
	assert_eq(info.persist_id, &"wardrobe_hall", "persist_id")
	assert_eq(info.position, Vector3(4.0, 0.0, 4.0), "posição")


func test_enemy_initial_state_padrao_e_patrulha() -> void:
	var initial: EnemyInitialState = EnemyInitialState.new()
	assert_eq(initial.state, Enums.EnemyState.PATROL, "estado inicial padrão é PATROL")
	assert_eq(initial.spawn_position, Vector3.ZERO, "spawn padrão na origem")


func test_brain_world_query_base_avisa_metodos_nao_sobrescritos() -> void:
	var query: BrainWorldQuery = BrainWorldQuery.new()
	expect_engine_error("self_position")
	expect_engine_error("is_reachable")
	expect_engine_error("search_points_near")
	expect_engine_error("hideables_near")
	expect_engine_error("patrol_points")
	assert_eq(query.self_position(), Vector3.ZERO, "self_position neutro")
	assert_false(query.is_reachable(Vector3.ONE), "is_reachable neutro: falso")
	assert_true(query.search_points_near(Vector3.ZERO, 5.0).is_empty(), "busca vazia")
	assert_true(query.hideables_near(Vector3.ZERO, 5.0).is_empty(), "sem esconderijos")
	assert_true(query.patrol_points().is_empty(), "sem rota")


func test_fake_world_sobrescreve_todos_os_metodos() -> void:
	var world: FakeBrainWorld = FakeBrainWorld.new()
	world.position = Vector3(1.0, 0.0, 1.0)
	world.route = PackedVector3Array([Vector3.ONE])
	assert_eq(world.self_position(), Vector3(1.0, 0.0, 1.0), "posição do próprio inimigo")
	assert_eq(world.patrol_points().size(), 1, "rota devolvida")
	assert_true(world.is_reachable(Vector3.ZERO), "alcançável por padrão no fake")
	assert_eq(world.search_points_near(Vector3.ZERO, 3.0).size(), 0, "sem pontos de busca por padrão")

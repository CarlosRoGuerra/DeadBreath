extends TestCase
## F4-004 e F4-005 (COMPONENT_CONTRACTS §8.1; ENM-INV-1 e ENM-INV-2): contrato do EnemyController com física e navmesh
## de teste (EnemyTestWorld). Cobre: cópia do perfil para os sensores, fonte do som, rota por route_id, inspeção por
## esconderijo (AI-08), captura só em CHASE e fora do lote (AI-07), eventos e reset.
## Os cenários longos de comportamento (AI-02..AI-06) estão em tests/property/enemy. Autor: AI Engineer (F4-004/005).

const Fx := preload("res://tests/integration/enemy/fixtures/enemy_test_world.gd")
const FakeHideableScript := preload("res://tests/integration/enemy/fixtures/fake_hideable.gd")
const DT: float = 1.0 / 60.0
const MAX_FRAMES_TO_CHASE: int = 120
const SETTLE_FRAMES: int = 8
const ENEMY_ID: StringName = &"observer"

var _captured_ids: Array[StringName] = []
var _chase_started_ids: Array[StringName] = []
var _chase_ended_ids: Array[StringName] = []


func before_each() -> void:
	_captured_ids.clear()
	_chase_started_ids.clear()
	_chase_ended_ids.clear()
	EventBus.player_captured.connect(_on_captured)
	EventBus.chase_started.connect(_on_chase_started)
	EventBus.chase_ended.connect(_on_chase_ended)


func after_each() -> void:
	if EventBus.player_captured.is_connected(_on_captured):
		EventBus.player_captured.disconnect(_on_captured)
	if EventBus.chase_started.is_connected(_on_chase_started):
		EventBus.chase_started.disconnect(_on_chase_started)
	if EventBus.chase_ended.is_connected(_on_chase_ended):
		EventBus.chase_ended.disconnect(_on_chase_ended)


func _on_captured(enemy_id: StringName) -> void:
	_captured_ids.append(enemy_id)


func _on_chase_started(enemy_id: StringName) -> void:
	_chase_started_ids.append(enemy_id)


func _on_chase_ended(enemy_id: StringName) -> void:
	_chase_ended_ids.append(enemy_id)


## Mundo com navmesh, um Observer em (0, 0, 0) e, se wanted, um alvo iluminado a 8 m à frente (−Z). Espera o mapa
## sincronizar e o primeiro tick de IA (o tick só roda com o mapa sincronizado, EnemyController.tick).
func _world(with_target: bool) -> Dictionary:
	var world: Node3D = add_isolated_world()
	Fx.navigation_floor(world, 20.0)
	# Rota de um único ponto, no próprio spawn: o inimigo fica parado e olha para onde o teste mandar (o alvo em −Z).
	Fx.add_route(world, &"observer", PackedVector3Array([Vector3.ZERO]))
	var enemy: EnemyController = Fx.spawn_observer(world, Vector3.ZERO)
	var target: PerceivableTarget = null
	if with_target:
		target = Fx.add_target(world, Vector3(0.0, 0.0, -8.0), true)
	await wait_physics_frames(SETTLE_FRAMES)
	return {"world": world, "enemy": enemy, "target": target}


## Espera até o inimigo estar em CHASE (ou esgotar o limite). Devolve true se chegou.
func _until_chase(enemy: EnemyController) -> bool:
	for _frame: int in range(MAX_FRAMES_TO_CHASE):
		if enemy.get_state() == Enums.EnemyState.CHASE:
			return true
		await wait_physics_frames(1)
	return enemy.get_state() == Enums.EnemyState.CHASE


func test_sensores_recebem_o_perfil_e_a_fonte_do_inimigo() -> void:
	var setup: Dictionary = await _world(false)
	var enemy: EnemyController = setup["enemy"] as EnemyController
	await wait_physics_frames(1)
	var profile: AIProfile = enemy.profile
	var eye: VisionSensor = enemy.get_node("Eye") as VisionSensor
	var hearing: HearingSensor = enemy.get_node("HearingSensor") as HearingSensor
	var noise: NoiseEmitter = enemy.get_node("NoiseEmitter") as NoiseEmitter
	assert_almost_eq(eye.sight_range_m, profile.sight_range_m, 0.0001, "alcance do VisionSensor vem do perfil")
	assert_almost_eq(eye.fov_deg, profile.fov_deg, 0.0001, "FOV do VisionSensor vem do perfil")
	assert_almost_eq(hearing.hearing_threshold_db, profile.hearing_threshold_db, 0.0001, "limiar vem do perfil")
	assert_almost_eq(hearing.masking_margin_db, profile.masking_margin_db, 0.0001, "margem vem do perfil")
	assert_eq(noise.source_id, &"enemy_observer", "fonte do som: enemy_<enemy_id>")
	assert_eq(hearing.owner_id, noise.source_id, "owner_id do HearingSensor é a fonte do próprio NoiseEmitter")
	assert_true(String(noise.source_id).begins_with("enemy"), "a fonte começa com enemy (regra da trava de som do corpo)")


func test_rota_vem_dos_marcadores_do_route_id_em_ordem() -> void:
	var world: Node3D = add_isolated_world()
	Fx.navigation_floor(world, 20.0)
	Fx.add_route(world, &"observer", PackedVector3Array([Vector3(1.0, 0.0, 0.0), Vector3(2.0, 0.0, 0.0)]))
	Fx.add_route(world, &"outra", PackedVector3Array([Vector3(9.0, 0.0, 9.0)]))
	var enemy: EnemyController = Fx.spawn_observer(world, Vector3.ZERO)
	await wait_physics_frames(1)
	var route: PackedVector3Array = enemy.patrol_route()
	assert_eq(route.size(), 2, "só os marcadores de route_id observer entram")
	if route.size() == 2:
		assert_true(route[0].is_equal_approx(Vector3(1.0, 0.0, 0.0)), "primeiro ponto é o de ordem 0")
		assert_true(route[1].is_equal_approx(Vector3(2.0, 0.0, 0.0)), "segundo ponto é o de ordem 1")


func test_ai08_inspecao_com_esconderijo_falso_gera_um_percept_so_se_achou() -> void:
	var setup: Dictionary = await _world(false)
	var enemy: EnemyController = setup["enemy"] as EnemyController
	var world: Node3D = setup["world"] as Node3D
	var hideable: FakeHideable = FakeHideableScript.new() as FakeHideable
	hideable.position = Vector3(4.0, 0.0, 0.0)
	hideable.set_meta(&"persist_id", &"hide_a")
	world.add_child(hideable)
	hideable.answer = true
	enemy.inspect_hideable(&"hide_a")
	await wait_physics_frames(1)
	assert_eq(hideable.calls, 1, "a inspeção pergunta ao esconderijo uma vez")
	var found_batch: PerceptBatch = enemy.last_batch()
	assert_not_null(found_batch, "há lote depois do tick")
	if found_batch != null:
		assert_eq(found_batch.visual.size(), 1, "achou: exatamente um VisualPercept")
		if found_batch.visual.size() == 1:
			assert_true(found_batch.visual[0].position.is_equal_approx(hideable.global_position),
				"o percept fica na posição do esconderijo")
			assert_almost_eq(found_batch.visual[0].visibility, 1.0, 0.0001, "inspeção de perto vale 1,0")
	hideable.answer = false
	enemy.inspect_hideable(&"hide_a")
	await wait_physics_frames(1)
	assert_eq(hideable.calls, 2, "segunda inspeção")
	var empty_batch: PerceptBatch = enemy.last_batch()
	if empty_batch != null:
		assert_eq(empty_batch.visual.size(), 0, "não achou: nenhum percept da inspeção")


func test_ai07_captura_em_chase_nao_entra_no_lote_do_cerebro() -> void:
	# O jogador some da visão (concealment 1 = visibilidade 0) e, em CHASE, um corpo na camada do jogador sobrepõe a
	# área de captura. A captura dispara; o lote do tick seguinte continua sem nenhum percept nem som.
	var setup: Dictionary = await _world(true)
	var enemy: EnemyController = setup["enemy"] as EnemyController
	var world: Node3D = setup["world"] as Node3D
	var target: PerceivableTarget = setup["target"] as PerceivableTarget
	assert_true(await _until_chase(enemy), "pré-condição: CHASE pela visão")
	target.set_concealment(1.0)
	var body: StaticBody3D = Fx.add_player_layer_body(world, enemy.global_position, 0.4)
	var captured: Array[bool] = [false]
	enemy.player_caught.connect(func() -> void: captured[0] = true)
	await wait_physics_frames(3)
	assert_true(captured[0], "sobreposição em CHASE dispara a captura")
	assert_true(_captured_ids.has(ENEMY_ID), "EventBus.player_captured recebe o enemy_id")
	var batch: PerceptBatch = enemy.last_batch()
	assert_not_null(batch, "há lote depois da captura")
	if batch != null:
		assert_eq(batch.visual.size(), 0, "AI-07: a captura não adiciona percept visual")
		assert_eq(batch.heard.size(), 0, "AI-07: a captura não adiciona som")
		assert_eq(batch.squad.size(), 0, "AI-07: squad vazio na F4 (D4-02)")
	await release_and_flush(body)


func test_captura_so_dispara_em_chase() -> void:
	var setup: Dictionary = await _world(false)
	var enemy: EnemyController = setup["enemy"] as EnemyController
	var world: Node3D = setup["world"] as Node3D
	var body: StaticBody3D = Fx.add_player_layer_body(world, enemy.global_position, 0.4)
	await wait_physics_frames(10)
	assert_eq(enemy.get_state(), Enums.EnemyState.PATROL, "pré-condição: PATROL")
	assert_eq(_captured_ids.size(), 0, "em PATROL, sobreposição não captura")
	await release_and_flush(body)


func test_eventos_chase_started_e_chase_ended_seguem_o_estado() -> void:
	var setup: Dictionary = await _world(true)
	var enemy: EnemyController = setup["enemy"] as EnemyController
	var target: PerceivableTarget = setup["target"] as PerceivableTarget
	assert_true(await _until_chase(enemy), "chega a CHASE")
	assert_eq(_chase_started_ids.size(), 1, "chase_started uma vez")
	assert_true(_chase_started_ids.size() == 1 and _chase_started_ids[0] == ENEMY_ID, "chase_started leva o enemy_id")
	target.set_concealment(1.0)
	await wait_physics_frames(120)
	assert_ne(enemy.get_state(), Enums.EnemyState.CHASE, "sem visão, deixa CHASE")
	assert_eq(_chase_ended_ids.size(), 1, "chase_ended uma vez ao sair de CHASE")
	assert_true(_chase_ended_ids.size() == 1 and _chase_ended_ids[0] == ENEMY_ID, "chase_ended leva o enemy_id")


func test_reset_to_cria_cerebro_novo_volta_ao_spawn_e_rearma_a_captura() -> void:
	var setup: Dictionary = await _world(true)
	var enemy: EnemyController = setup["enemy"] as EnemyController
	var world: Node3D = setup["world"] as Node3D
	var target: PerceivableTarget = setup["target"] as PerceivableTarget
	assert_true(await _until_chase(enemy), "pré-condição: CHASE")
	target.set_concealment(1.0)
	var body: StaticBody3D = Fx.add_player_layer_body(world, enemy.global_position, 0.4)
	await wait_physics_frames(3)
	assert_eq(_captured_ids.size(), 1, "captura uma vez antes do reset")
	await release_and_flush(body)
	var initial: EnemyInitialState = EnemyInitialState.new()
	initial.spawn_position = Vector3(-3.0, 0.0, 2.0)
	initial.state = Enums.EnemyState.PATROL
	enemy.reset_to(initial)
	await wait_physics_frames(2)
	assert_eq(enemy.get_state(), Enums.EnemyState.PATROL, "volta a PATROL")
	assert_true(enemy.global_position.distance_to(initial.spawn_position) < 0.5, "volta ao spawn do checkpoint")
	var eye: VisionSensor = enemy.get_node("Eye") as VisionSensor
	assert_true(eye.is_inside_tree(), "sensores continuam ligados depois do reset")
	var capture: EnemyCaptureArea = enemy.get_node("CaptureArea") as EnemyCaptureArea
	assert_false(capture.is_latched(), "captura rearmada pelo reset")

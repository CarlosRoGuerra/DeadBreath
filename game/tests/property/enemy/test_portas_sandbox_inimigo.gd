extends TestCase
## F4-004 (D4-03): portas no caminho do Observer, na sandbox real. Porta destrancada na rota: aberta e atravessada.
## Porta trancada: evitada (o link fica desligado). Destrancar religa o link. Porta que o painel bate no inimigo: o
## inimigo recua para fora do arco e passa (a porta não prende nem empurra). Rotas de teste (marcadores route_id
## "teste_porta") são acrescentadas à sandbox do teste; os marcadores da sandbox não são alterados.
## Autor: AI Engineer (F4-004).

const EnemySandboxScript := preload("res://tests/property/enemy/fixtures/enemy_sandbox.gd")
const Fx := preload("res://tests/integration/enemy/fixtures/enemy_test_world.gd")
const ROUTE_TEST: StringName = &"teste_porta"
const ARRIVAL_M: float = 1.0
const MAX_FRAMES: int = 1800
const SETTLE_FRAMES: int = 3
const LINK_SYNC_FRAMES: int = 3

const DOOR_SALA_CORREDOR: StringName = &"door_sala_corredor"
const DOOR_COZINHA_CORREDOR: StringName = &"door_cozinha_corredor"
const DOOR_SALA_COZINHA: StringName = &"door_sala_cozinha"

## Sala (x < 6) e corredor (x > 6) da porta sala-corredor: o painel abre para o lado do corredor.
const SALA_SIDE: Vector3 = Vector3(4.0, 0.0, -0.7)
const CORREDOR_SIDE: Vector3 = Vector3(7.0, 0.0, -0.7)
const SALA_TARGET: Vector3 = Vector3(4.5, 0.0, -1.5)
const CORREDOR_TARGET: Vector3 = Vector3(8.0, 0.0, -0.7)
const COZINHA_SPAWN: Vector3 = Vector3(9.5, 0.0, -3.5)
const CORREDOR_TARGET_AFTER_COZINHA: Vector3 = Vector3(11.0, 0.0, -0.7)

var _blocked_count: int = 0


func before_each() -> void:
	_blocked_count = 0


func _on_blocked(_body: Node) -> void:
	_blocked_count += 1


func _route_to(root: Node3D, points: PackedVector3Array) -> void:
	Fx.add_route(root, ROUTE_TEST, points)


## Espera até o inimigo chegar a `goal` (≤ ARRIVAL_M no plano) ou esgotar MAX_FRAMES. Devolve o quadro da chegada, ou -1.
func _until_at(enemy: EnemyController, goal: Vector3) -> int:
	for frame: int in range(MAX_FRAMES):
		await wait_physics_frames(1)
		var flat: Vector3 = Vector3(enemy.global_position.x - goal.x, 0.0, enemy.global_position.z - goal.z)
		if flat.length() <= ARRIVAL_M:
			return frame
	return -1


func test_porta_destrancada_na_rota_e_aberta_e_atravessada() -> void:
	var root: Node3D = EnemySandboxScript.build(self)
	_route_to(root, PackedVector3Array([CORREDOR_TARGET]))
	var enemy: EnemyController = EnemySandboxScript.add_observer(root, SALA_SIDE, ROUTE_TEST)
	var door: Door = EnemySandboxScript.door(root, DOOR_SALA_CORREDOR)
	assert_not_null(door, "a porta da sala-corredor existe no nível")
	if door == null:
		return
	assert_eq(door.get_state(), Door.State.CLOSED, "pré-condição: fechada e destrancada")
	var was_open: bool = false
	var arrival: int = -1
	for frame: int in range(MAX_FRAMES):
		await wait_physics_frames(1)
		if door.get_state() == Door.State.OPEN:
			was_open = true
		var flat: Vector3 = Vector3(enemy.global_position.x - CORREDOR_TARGET.x, 0.0, enemy.global_position.z - CORREDOR_TARGET.z)
		if flat.length() <= ARRIVAL_M:
			arrival = frame
			break
	assert_true(was_open, "o inimigo abre a porta fechada da rota")
	assert_true(arrival >= 0, "atravessa a porta e chega ao outro lado")


func test_porta_trancada_e_evitada_o_caminho_contorna_pela_sala() -> void:
	# Cozinha → corredor: o caminho mais curto passa pela porta trancada cozinha-corredor. Ela não é rota: o inimigo
	# vai pela sala (sala-cozinha, sala-corredor) e a trancada continua trancada.
	var root: Node3D = EnemySandboxScript.build(self)
	_route_to(root, PackedVector3Array([COZINHA_SPAWN, CORREDOR_TARGET_AFTER_COZINHA]))
	var enemy: EnemyController = EnemySandboxScript.add_observer(root, COZINHA_SPAWN, ROUTE_TEST)
	var locked: Door = EnemySandboxScript.door(root, DOOR_COZINHA_CORREDOR)
	var sala_corredor: Door = EnemySandboxScript.door(root, DOOR_SALA_CORREDOR)
	assert_not_null(locked, "a porta trancada existe")
	assert_not_null(sala_corredor, "a porta da sala existe")
	if locked == null or sala_corredor == null:
		return
	assert_eq(locked.get_state(), Door.State.LOCKED, "pré-condição: trancada")
	var sala_was_open: bool = false
	var arrival: int = -1
	for frame: int in range(MAX_FRAMES):
		await wait_physics_frames(1)
		if sala_corredor.get_state() == Door.State.OPEN:
			sala_was_open = true
		if locked.get_state() != Door.State.LOCKED:
			break
		var flat: Vector3 = Vector3(enemy.global_position.x - CORREDOR_TARGET_AFTER_COZINHA.x, 0.0,
			enemy.global_position.z - CORREDOR_TARGET_AFTER_COZINHA.z)
		if flat.length() <= ARRIVAL_M:
			arrival = frame
			break
	assert_eq(locked.get_state(), Door.State.LOCKED, "a porta trancada nunca é aberta")
	assert_true(sala_was_open, "o caminho contorna pela sala: a porta sala-corredor foi aberta")
	assert_true(arrival >= 0, "chega ao corredor pela sala")


func test_destrancar_religa_o_link_e_o_caminho_passa_pela_porta() -> void:
	# Com a porta cozinha-corredor destrancada, o link volta e o caminho mais curto passa por ela: o inimigo a abre.
	var root: Node3D = EnemySandboxScript.build(self)
	_route_to(root, PackedVector3Array([COZINHA_SPAWN, CORREDOR_TARGET_AFTER_COZINHA]))
	var enemy: EnemyController = EnemySandboxScript.add_observer(root, COZINHA_SPAWN, ROUTE_TEST)
	var door: Door = EnemySandboxScript.door(root, DOOR_COZINHA_CORREDOR)
	assert_not_null(door, "a porta cozinha-corredor existe")
	if door == null:
		return
	await wait_physics_frames(SETTLE_FRAMES)
	door.unlock()
	await wait_physics_frames(LINK_SYNC_FRAMES)
	assert_eq(door.get_state(), Door.State.CLOSED, "destrancada: fechada")
	var opened: bool = false
	var arrival: int = -1
	for frame: int in range(MAX_FRAMES):
		await wait_physics_frames(1)
		if door.get_state() == Door.State.OPEN:
			opened = true
		var flat: Vector3 = Vector3(enemy.global_position.x - CORREDOR_TARGET_AFTER_COZINHA.x, 0.0,
			enemy.global_position.z - CORREDOR_TARGET_AFTER_COZINHA.z)
		if flat.length() <= ARRIVAL_M:
			arrival = frame
			break
	assert_true(opened, "com o link religado, o inimigo abre a porta destrancada")
	assert_true(arrival >= 0, "chega ao corredor")


func test_painel_que_bate_no_inimigo_faz_recuar_e_a_porta_passa() -> void:
	# Pelo lado do corredor, o painel da porta sala-corredor varre o inimigo (ele está dentro do arco). A porta para
	# (blocked), o inimigo recua para fora do arco, a porta termina de abrir e o inimigo atravessa para a sala.
	var root: Node3D = EnemySandboxScript.build(self)
	_route_to(root, PackedVector3Array([SALA_TARGET]))
	var enemy: EnemyController = EnemySandboxScript.add_observer(root, CORREDOR_SIDE, ROUTE_TEST)
	var door: Door = EnemySandboxScript.door(root, DOOR_SALA_CORREDOR)
	assert_not_null(door, "a porta sala-corredor existe")
	if door == null:
		return
	door.blocked.connect(_on_blocked)
	var arrival: int = await _until_at(enemy, SALA_TARGET)
	assert_true(_blocked_count >= 1, "o painel bateu no inimigo (blocked) pelo menos uma vez")
	assert_true(arrival >= 0, "o inimigo não fica preso: chega à sala")
	assert_eq(door.get_state(), Door.State.OPEN, "a porta termina aberta")
	assert_false(door.is_moving(), "a porta para de se mover depois da passagem")
	door.blocked.disconnect(_on_blocked)

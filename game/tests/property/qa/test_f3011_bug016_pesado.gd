extends TestCase
## Segunda verificação do BUG-016 (commit a992082): o objeto pesado (meia-aresta 0,3 m) na mão, com a varredura
## recuada (Throwable.safe_hold_transform). Casos: de costas para a parede (a partida recuada sobrepõe o mundo e a
## varredura usa a câmera); na quina de duas paredes; ao se afastar da parede (o objeto não pode ficar grudado no ponto
## antigo: volta ao alvo da mão); soltar e arremessar perto da parede (não pode ficar do outro lado).
## Invariantes: o objeto não sobrepõe o mundo em nenhum tick (folga de 1 cm); a profundidade além da face próxima da
## parede sul é de no máximo 1 cm. Autor: QA Engineer (2ª verificação do BUG-016, F3-011).

const Fx := preload("res://tests/integration/qa/fixtures/qa_fixture.gd")
const PLAYABLE_PATH: String = "res://content/levels/sandbox_playable.tscn"
const HEAVY_SCENE: String = "res://content/props/throwables/throwable_heavy.tscn"
const SETTLE: int = 12
const WALK_TICKS: int = 150
const REVERSE_TICKS: int = 150
const THROW_TICKS: int = 90
const SHRINK_M: float = 0.01
const WORLD_MASK: int = 3
const HEAVY_HALF_M: float = 0.3
const SOUTH_WALL_NEAR_Z: float = -0.1
const DEPTH_MAX_M: float = 0.011
const HAND_TOL_M: float = 0.05
## Corredor: o jogador de costas para a parede norte (z = -1,4, face próxima -1,3) recua o suficiente para que a partida
## recuada da varredura caia dentro da parede.
const CORRIDOR_BACK_START: Vector3 = Vector3(9.0, 0.0, -1.0)
const CORRIDOR_MID_START: Vector3 = Vector3(9.0, 0.0, -0.6)


func before_all() -> void:
	Settings.autosave = false


func after_all() -> void:
	Settings.autosave = true


func _scene(start: Vector3, yaw_rad: float) -> Dictionary:
	var container: Node3D = add_isolated_world()
	var root: Node = Fx.instantiate_scene(PLAYABLE_PATH, container)
	await wait_physics_frames(SETTLE)
	var player: PlayerRoot = Fx.find_player(root)
	player.global_position = start
	player.rotation.y = yaw_rad
	await wait_physics_frames(SETTLE)
	var meter: Fx.Meter = Fx.Meter.new()
	meter.connect_motor(player)
	return {"container": container, "root": root, "player": player, "meter": meter}


func _boxes(start: Vector3, yaw_rad: float) -> Dictionary:
	var container: Node3D = add_isolated_world()
	Fx.add_box(container, Vector3(0.0, -0.05, 0.0), Vector3(20.0, 0.1, 20.0), &"concrete")
	var player: PlayerRoot = Fx.spawn_player_in(container, start)
	player.rotation.y = yaw_rad
	await wait_physics_frames(SETTLE)
	var meter: Fx.Meter = Fx.Meter.new()
	meter.connect_motor(player)
	return {"container": container, "player": player, "meter": meter}


func _spawn(parent: Node, at: Vector3) -> Throwable:
	var item: Throwable = (load(HEAVY_SCENE) as PackedScene).instantiate() as Throwable
	item.throwable_id = &"throwable_bug016_pesado"
	parent.add_child(item)
	item.global_position = at
	return item


func _pick(player: PlayerRoot, meter: Fx.Meter, item: Throwable) -> bool:
	await wait_physics_frames(4)
	var picked: bool = player.get_hold().try_pick(item)
	await wait_physics_frames(2)
	meter.sample(player, Fx.body_overlaps_world(player))
	return picked


## O objeto segurado sobrepõe o mundo? Forma encolhida em 1 cm, para contato não contar.
func _held_overlaps_world(item: Throwable, player: PlayerRoot) -> bool:
	if not item.is_held():
		return false
	var shape_node: CollisionShape3D = item.get_node("CollisionShape3D") as CollisionShape3D
	var box: BoxShape3D = shape_node.shape as BoxShape3D
	var shrunk: BoxShape3D = BoxShape3D.new()
	shrunk.size = box.size - Vector3.ONE * (2.0 * SHRINK_M)
	var query: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
	query.shape = shrunk
	query.transform = item.global_transform * shape_node.transform
	query.collision_mask = WORLD_MASK
	query.exclude = [item.get_rid(), player.get_rid()]
	return not item.get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()


## Um tick com o objeto na mão; devolve true se o objeto sobrepõe o mundo neste tick.
func _tick(player: PlayerRoot, meter: Fx.Meter, item: Throwable, move: Vector2) -> bool:
	player.get_motor().set_scripted_input(Fx.move_input(move, false))
	await wait_physics_frames(1)
	meter.sample(player, Fx.body_overlaps_world(player))
	return _held_overlaps_world(item, player)


## Alvo da mão: a posição que o PlayerHold daria ao objeto, sem varredura.
func _hand_target(player: PlayerRoot) -> Vector3:
	return player.get_camera().global_transform * PlayerHold.HOLD_OFFSET


## De costas para a parede norte, com o objeto pesado na mão: anda para a parede sul (a frente) e volta até a parede
## norte (as costas). Invariantes em todo tick, e a mão volta ao alvo quando o caminho fica livre.
func test_pesado_de_costas_na_parede_nao_atravessa_e_nao_gruda() -> void:
	var world: Dictionary = await _scene(CORRIDOR_BACK_START, PI)
	var root: Node = world["root"] as Node
	var player: PlayerRoot = world["player"] as PlayerRoot
	var meter: Fx.Meter = world["meter"] as Fx.Meter
	var item: Throwable = _spawn(root, Vector3(11.0, 1.2, -0.7))
	assert_true(await _pick(player, meter, item), "pré-condição: pegou o objeto pesado")
	var overlaps: int = 0
	var depth: float = 0.0
	for _i: int in WALK_TICKS:
		if await _tick(player, meter, item, Vector2(0.0, 1.0)):
			overlaps += 1
		depth = maxf(depth, (item.global_position.z + HEAVY_HALF_M) - SOUTH_WALL_NEAR_Z)
	note("pesado, ida (parede sul, a frente): ticks sobrepostos %d; profundidade %.4f m; objeto z %.3f; jogador z %.3f" % [
		overlaps, depth, item.global_position.z, player.global_position.z])
	assert_eq(overlaps, 0, "a ida: o objeto pesado nunca sobrepõe o mundo")
	assert_true(depth <= DEPTH_MAX_M, "a ida: o objeto não passa da face próxima (%.4f m)" % depth)
	var back_overlaps: int = 0
	for _i: int in REVERSE_TICKS:
		if await _tick(player, meter, item, Vector2(0.0, -1.0)):
			back_overlaps += 1
	# O alvo da mão (z = -0,348) atravessaria a parede sul: o objeto para no limite dela (centro em z = -0,404).
	var wall_limit_z: float = SOUTH_WALL_NEAR_Z - HEAVY_HALF_M
	var target: Vector3 = _hand_target(player)
	var expected_z: float = minf(target.z, wall_limit_z)
	note("pesado, volta (costas na parede norte): ticks sobrepostos %d; objeto z %.3f; alvo da mão z %.3f; limite da parede sul z %.3f; jogador z %.3f" % [
		back_overlaps, item.global_position.z, target.z, wall_limit_z, player.global_position.z])
	assert_eq(back_overlaps, 0, "a volta: o objeto pesado nunca sobrepõe o mundo, com as costas na parede")
	assert_true(absf(item.global_position.z - expected_z) <= 0.01, "a volta: o objeto segue a mão até o limite da parede (z %.3f, esperado %.3f)" % [item.global_position.z, expected_z])
	assert_eq(meter.penetrations, 0, "o corpo do jogador não penetra a parede")
	await release_and_flush(world["container"] as Node3D)


## Quina de duas paredes com o objeto pesado: a ida termina encostada no canto, e a volta solta a mão do canto.
func test_pesado_na_quina_nao_atravessa() -> void:
	var world: Dictionary = await _boxes(Vector3(0.4, 0.0, -0.6), -3.0 * PI / 4.0)
	var container: Node3D = world["container"] as Node3D
	var player: PlayerRoot = world["player"] as PlayerRoot
	var meter: Fx.Meter = world["meter"] as Fx.Meter
	Fx.add_box(container, Vector3(0.0, 1.5, 0.0), Vector3(4.0, 3.0, 0.2), &"wood")
	Fx.add_box(container, Vector3(1.0, 1.5, -1.5), Vector3(0.2, 3.0, 3.0), &"wood")
	await wait_physics_frames(3)
	var item: Throwable = _spawn(container, Vector3(-1.5, 1.0, -1.5))
	assert_true(await _pick(player, meter, item), "pré-condição: pegou o objeto pesado")
	var overlaps: int = 0
	for _i: int in WALK_TICKS:
		if await _tick(player, meter, item, Vector2(0.0, 1.0)):
			overlaps += 1
	var corner_distance: float = Vector2(player.global_position.x - 0.9, player.global_position.z + 0.1).length()
	note("pesado na quina, ida: ticks sobrepostos %d; jogador (%.2f, %.2f), a %.2f m do canto (0,9; -0,1)" % [
		overlaps, player.global_position.x, player.global_position.z, corner_distance])
	assert_eq(overlaps, 0, "na quina, o objeto pesado nunca sobrepõe as paredes")
	assert_true(corner_distance < 0.4, "a ida chega ao canto (%.2f m)" % corner_distance)
	var back_overlaps: int = 0
	for _i: int in REVERSE_TICKS:
		if await _tick(player, meter, item, Vector2(0.0, -1.0)):
			back_overlaps += 1
	var gap: float = item.global_position.distance_to(_hand_target(player))
	assert_eq(back_overlaps, 0, "na volta da quina, o objeto pesado segue sem sobrepor")
	assert_true(gap <= HAND_TOL_M, "afastando-se do canto, o objeto volta ao alvo da mão (%.3f m)" % gap)
	assert_eq(meter.penetrations, 0, "o corpo não penetra na quina")
	await release_and_flush(container)


## Soltar e arremessar o pesado perto da parede: soltar encostado na parede deixa o objeto do lado do jogador (sem
## sobrepor); arremessar contra a parede não pode fazer o objeto cair do outro lado.
func test_pesado_soltar_e_arremessar_perto_da_parede_nao_passa() -> void:
	var world: Dictionary = await _scene(CORRIDOR_MID_START, PI)
	var root: Node = world["root"] as Node
	var player: PlayerRoot = world["player"] as PlayerRoot
	var meter: Fx.Meter = world["meter"] as Fx.Meter
	var item: Throwable = _spawn(root, Vector3(11.0, 1.2, -0.7))
	assert_true(await _pick(player, meter, item), "pré-condição: pegou o objeto pesado")
	for _i: int in WALK_TICKS:
		await _tick(player, meter, item, Vector2(0.0, 1.0))
	var dropped: bool = player.get_hold().drop_held()
	note("soltar encostado: soltou=%s; objeto z=%.3f" % [str(dropped), item.global_position.z])
	assert_true(dropped, "soltar o pesado encostado na parede é permitido (cabe do lado do jogador)")
	for _i: int in 60:
		await wait_physics_frames(1)
	assert_true(item.global_position.z <= SOUTH_WALL_NEAR_Z + 0.001, "solto, o objeto fica do lado do jogador (z %.3f)" % item.global_position.z)
	assert_false(item.is_held(), "solto, o objeto não está na mão")
	assert_true(player.get_hold().try_pick(item), "pega de novo, sem distância")
	for _i: int in 30:
		await _tick(player, meter, item, Vector2.ZERO)
	var thrown: bool = player.get_hold().throw_held()
	assert_true(thrown, "arremessar o pesado com a mão do lado do jogador é permitido")
	var beyond: bool = false
	for _i: int in THROW_TICKS:
		await wait_physics_frames(1)
		if item.global_position.z > SOUTH_WALL_NEAR_Z + 0.001:
			beyond = true
	note("arremesso contra a parede sul: objeto z final %.3f (face próxima %.2f); passou da parede=%s" % [
		item.global_position.z, SOUTH_WALL_NEAR_Z, str(beyond)])
	assert_false(beyond, "o arremesso não faz o objeto pesado passar da parede sul")
	assert_true(item.global_position.z <= SOUTH_WALL_NEAR_Z + 0.001, "depois do arremesso, o objeto fica do lado do jogador (z %.3f)" % item.global_position.z)
	assert_eq(meter.penetrations, 0, "o corpo do jogador não penetra a parede")
	await release_and_flush(world["container"] as Node3D)


## Não grudar: o objeto pesado trava na parede (alvo da mão atravessaria) e, quando o jogador vira e o alvo fica livre,
## o objeto tem de seguir a mão. Só uma parede, em mundo aberto: a mão livre é a que está atrás do jogador.
func test_pesado_nao_gruda_quando_o_alvo_fica_livre() -> void:
	var world: Dictionary = await _boxes(Vector3(0.0, 0.0, -0.6), PI)
	var container: Node3D = world["container"] as Node3D
	var player: PlayerRoot = world["player"] as PlayerRoot
	var meter: Fx.Meter = world["meter"] as Fx.Meter
	Fx.add_box(container, Vector3(0.0, 1.5, 0.0), Vector3(12.0, 3.0, 0.2), &"wood")
	await wait_physics_frames(3)
	var item: Throwable = _spawn(container, Vector3(-2.0, 1.0, -2.0))
	assert_true(await _pick(player, meter, item), "pré-condição: pegou o objeto pesado")
	var overlaps: int = 0
	for _i: int in WALK_TICKS:
		if await _tick(player, meter, item, Vector2(0.0, 1.0)):
			overlaps += 1
	var pinned_z: float = item.global_position.z
	note("pesado travado na parede sul: z %.3f (limite -0,400); ticks sobrepostos %d" % [pinned_z, overlaps])
	assert_eq(overlaps, 0, "travado, o objeto pesado nunca sobrepõe a parede")
	assert_true(absf(pinned_z - (SOUTH_WALL_NEAR_Z - HEAVY_HALF_M)) <= 0.01, "o objeto trava no limite da parede (z %.3f)" % pinned_z)
	# Virar de costas para a parede, ainda encostado nela: a forma sobrepõe a parede a partir da câmera. Director, depois
	# da 3ª correção (avanço da câmera rumo à mão com o raio livre): o objeto volta a seguir a mão. Antes ficava no ponto antigo.
	player.rotation.y = 0.0
	for _i: int in 60:
		if await _tick(player, meter, item, Vector2.ZERO):
			overlaps += 1
	var stuck_gap: float = item.global_position.distance_to(_hand_target(player))
	note("virado para -Z, ainda encostado na parede sul: objeto z %.3f; alvo z %.3f; distância %.3f m" % [
		item.global_position.z, _hand_target(player).z, stuck_gap])
	assert_true(stuck_gap <= HAND_TOL_M, "de costas para a parede, o objeto segue a mão (%.3f m)" % stuck_gap)
	# Afastar-se da parede: a câmera sai da zona de sobreposição e o objeto tem de voltar a seguir a mão.
	for _i: int in 60:
		if await _tick(player, meter, item, Vector2(0.0, 1.0)):
			overlaps += 1
	var target: Vector3 = _hand_target(player)
	var gap: float = item.global_position.distance_to(target)
	note("depois de se afastar da parede: objeto z %.3f; alvo z %.3f; distância %.3f m; jogador z %.3f" % [
		item.global_position.z, target.z, gap, player.global_position.z])
	assert_eq(overlaps, 0, "afastando-se, o objeto pesado nunca sobrepõe o mundo")
	assert_true(item.global_position.z < pinned_z - 0.5, "o objeto saiu do ponto antigo ao se afastar (z %.3f)" % item.global_position.z)
	assert_true(gap <= HAND_TOL_M, "afastando-se da parede, o objeto volta a seguir a mão (%.3f m)" % gap)
	assert_eq(meter.penetrations, 0, "o corpo não penetra")
	await release_and_flush(container)

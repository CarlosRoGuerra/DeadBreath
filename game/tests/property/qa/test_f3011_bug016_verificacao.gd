extends TestCase
## Verificação independente da correção do BUG-016 (commit 8c158df): o objeto segurado para na parede
## (Throwable.safe_hold_transform, varredura da forma desde a câmera até a mão).
## Cenários: o original (corredor, parede sul, andar contra a parede com o objeto na mão), objeto pesado, agachado,
## olhando para o chão perto da parede, quina de duas paredes, batente de porta aberta; e soltar e arremessar dentro de
## parede. Invariantes, tick a tick: o objeto não sobrepõe o mundo (folga de 1 cm para contato não contar); o jogador não
## penetra o mundo e não fica preso. Autor: QA Engineer (verificação do BUG-016, F3-011).

const Fx := preload("res://tests/integration/qa/fixtures/qa_fixture.gd")
const PLAYABLE_PATH: String = "res://content/levels/sandbox_playable.tscn"
const LIGHT_SCENE: String = "res://content/props/throwables/throwable_light.tscn"
const HEAVY_SCENE: String = "res://content/props/throwables/throwable_heavy.tscn"
const SETTLE: int = 12
const WALK_TICKS: int = 150
const REVERSE_TICKS: int = 120
const MIN_UNSTUCK_M: float = 0.5
## Folga de 1 cm: o contato exato com a parede não conta como sobreposição.
const SHRINK_M: float = 0.01
const WORLD_MASK: int = 3
## Face do lado do jogador da parede sul do corredor (parede em z = 0, espessura 0,2 m).
const SOUTH_WALL_NEAR_Z: float = -0.1
const SOUTH_WALL_FAR_Z: float = 0.1


func before_all() -> void:
	Settings.autosave = false


func after_all() -> void:
	Settings.autosave = true


## Cena jogável em um mundo isolado, com o jogador em start e virado para yaw.
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


## Mundo isolado só com geometria (caixas), sem a cena do nível. Devolve o contêiner e o jogador.
func _boxes(start: Vector3, yaw_rad: float) -> Dictionary:
	var container: Node3D = add_isolated_world()
	# Piso (topo em y = 0): sem ele o jogador e o objeto caem no vazio e o teste não mede parede.
	Fx.add_box(container, Vector3(0.0, -0.05, 0.0), Vector3(20.0, 0.1, 20.0), &"concrete")
	var player: PlayerRoot = Fx.spawn_player_in(container, start)
	player.rotation.y = yaw_rad
	await wait_physics_frames(SETTLE)
	var meter: Fx.Meter = Fx.Meter.new()
	meter.connect_motor(player)
	return {"container": container, "player": player, "meter": meter}


func _spawn(parent: Node, scene_path: String, at: Vector3) -> Throwable:
	var item: Throwable = (load(scene_path) as PackedScene).instantiate() as Throwable
	item.throwable_id = &"throwable_bug016"
	parent.add_child(item)
	item.global_position = at
	return item


## Um tick de andar (ou parado) com o objeto na mão; devolve true se o objeto sobrepõe o mundo neste tick.
func _tick(player: PlayerRoot, meter: Fx.Meter, item: Throwable, move: Vector2) -> bool:
	player.get_motor().set_scripted_input(Fx.move_input(move, false))
	await wait_physics_frames(1)
	meter.sample(player, Fx.body_overlaps_world(player))
	return _held_overlaps_world(item, player)


func _run(player: PlayerRoot, meter: Fx.Meter, item: Throwable, move: Vector2, ticks: int) -> int:
	var overlaps: int = 0
	for _i: int in ticks:
		if await _tick(player, meter, item, move):
			overlaps += 1
	return overlaps


## O objeto segurado sobrepõe o mundo (camada 1 e 2)? A forma do objeto é encolhida em SHRINK_M para não contar contato.
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


func _pick(player: PlayerRoot, meter: Fx.Meter, item: Throwable) -> bool:
	await wait_physics_frames(4)
	var picked: bool = player.get_hold().try_pick(item)
	await wait_physics_frames(2)
	meter.sample(player, Fx.body_overlaps_world(player))
	return picked


func _throw_action(player: PlayerRoot) -> void:
	var event: InputEventAction = InputEventAction.new()
	event.action = InputBindings.THROW_ACTION
	event.pressed = true
	player.get_viewport().push_input(event)
	await wait_physics_frames(1)


## Original (BUG-016): corredor, parede sul (z = 0), andar contra ela com o objeto leve na mão.
func test_bug016_original_corredor_parede_sul_leve() -> void:
	var world: Dictionary = await _scene(Vector3(9.0, 0.0, -0.6), PI)
	var root: Node = world["root"] as Node
	var player: PlayerRoot = world["player"] as PlayerRoot
	var meter: Fx.Meter = world["meter"] as Fx.Meter
	var item: Throwable = _spawn(root, LIGHT_SCENE, Vector3(11.0, 1.2, -0.7))
	assert_true(await _pick(player, meter, item), "pré-condição: pegou o objeto leve")
	var overlaps: int = await _run(player, meter, item, Vector2(0.0, 1.0), WALK_TICKS)
	var start_z: float = player.global_position.z
	var back_overlaps: int = await _run(player, meter, item, Vector2(0.0, -1.0), REVERSE_TICKS)
	var back: float = absf(player.global_position.z - start_z)
	note("leve contra a parede sul: objeto z=%.3f (face próxima %.2f), jogador z=%.3f; ticks sobrepostos %d; recuou %.2f m" % [
		item.global_position.z, SOUTH_WALL_NEAR_Z, player.global_position.z, overlaps, back])
	assert_eq(overlaps + back_overlaps, 0, "o objeto leve nunca sobrepõe o mundo")
	assert_true(item.global_position.z <= SOUTH_WALL_NEAR_Z + 0.001, "o objeto leve para do lado do jogador (z %.3f)" % item.global_position.z)
	assert_true(back >= MIN_UNSTUCK_M, "o jogador não fica preso (recuou %.2f m)" % back)
	assert_eq(meter.penetrations, 0, "o corpo do jogador não penetra a parede")
	await release_and_flush(world["container"] as Node3D)


## Objeto pesado (meia-aresta 0,3 m, maior que os 0,25 m do raio do corpo). BUG-016 REABERTO pela verificação do QA:
## com o jogador encostado na parede, a varredura começa com a forma já dentro da parede, e o cast_motion devolve o
## movimento inteiro; o objeto atravessa a parede. Este teste documenta o comportamento real (o defeito), não o desejado:
## se a correção for estendida ao pesado, ele reprova e deve ser atualizado para assertar que o objeto para na parede.
func test_bug016_objeto_pesado_atravessa_a_parede_reaberto() -> void:
	var world: Dictionary = await _scene(Vector3(9.0, 0.0, -0.6), PI)
	var root: Node = world["root"] as Node
	var player: PlayerRoot = world["player"] as PlayerRoot
	var meter: Fx.Meter = world["meter"] as Fx.Meter
	var item: Throwable = _spawn(root, HEAVY_SCENE, Vector3(11.0, 1.2, -0.7))
	assert_true(await _pick(player, meter, item), "pré-condição: pegou o objeto pesado")
	var overlaps: int = 0
	var depth: float = 0.0
	for _i: int in WALK_TICKS:
		if await _tick(player, meter, item, Vector2(0.0, 1.0)):
			overlaps += 1
		# Profundidade da face mais distante do objeto (z + meia-aresta) além da face próxima da parede sul.
		depth = maxf(depth, (item.global_position.z + 0.3) - SOUTH_WALL_NEAR_Z)
	note("BUG-016 (pesado, após a correção do Director): ticks com o objeto sobre o mundo %d; profundidade máxima além da face próxima = %.3f m; objeto z %.3f (face externa em %.2f)" % [
		overlaps, depth, item.global_position.z, SOUTH_WALL_FAR_Z])
	# Director: atualizado depois da correção da varredura (ponto de partida recuado). Antes documentava o defeito.
	assert_eq(overlaps, 0, "o objeto pesado nunca sobrepõe a parede")
	assert_true(depth <= 0.011, "o objeto pesado não passa da face próxima (%.3f m)" % depth)
	assert_eq(meter.penetrations, 0, "o corpo do jogador não penetra o mundo")
	await release_and_flush(world["container"] as Node3D)


## Agachado: a câmera fica mais baixa e a mão desce; o objeto continua do lado do jogador.
func test_bug016_agachado_contra_a_parede() -> void:
	var world: Dictionary = await _scene(Vector3(9.0, 0.0, -0.6), PI)
	var root: Node = world["root"] as Node
	var player: PlayerRoot = world["player"] as PlayerRoot
	var meter: Fx.Meter = world["meter"] as Fx.Meter
	var item: Throwable = _spawn(root, LIGHT_SCENE, Vector3(11.0, 0.6, -0.7))
	assert_true(await _pick(player, meter, item), "pré-condição: pegou o objeto")
	await _tick(player, meter, item, Vector2.ZERO)
	# Um único pulso de agachar: a borda não pode ficar ativa, senão alterna a postura a cada tick.
	player.get_motor().set_scripted_input(Fx.edge_input(Fx.EDGE_CROUCH))
	await wait_physics_frames(1)
	await _tick(player, meter, item, Vector2.ZERO)
	await wait_physics_frames(SETTLE)
	var overlaps: int = await _run(player, meter, item, Vector2(0.0, 1.0), WALK_TICKS)
	var start_z: float = player.global_position.z
	var back_overlaps: int = await _run(player, meter, item, Vector2(0.0, -1.0), REVERSE_TICKS)
	var back: float = absf(player.global_position.z - start_z)
	note("agachado contra a parede sul: postura %d, objeto z=%.3f, ticks sobrepostos %d, recuou %.2f m" % [
		int(player.get_motor().get_stance()), item.global_position.z, overlaps, back])
	assert_eq(overlaps + back_overlaps, 0, "agachado, o objeto nunca sobrepõe o mundo")
	assert_true(back >= MIN_UNSTUCK_M, "agachado, o jogador não fica preso (recuou %.2f m)" % back)
	await release_and_flush(world["container"] as Node3D)


## Olhando para o chão perto da parede: a mão aponta para baixo, e o objeto pode querer entrar no piso ou na parede.
func test_bug016_olhando_para_o_chao_perto_da_parede() -> void:
	var world: Dictionary = await _scene(Vector3(9.0, 0.0, -0.6), PI)
	var root: Node = world["root"] as Node
	var player: PlayerRoot = world["player"] as PlayerRoot
	var meter: Fx.Meter = world["meter"] as Fx.Meter
	var item: Throwable = _spawn(root, LIGHT_SCENE, Vector3(11.0, 1.2, -0.7))
	assert_true(await _pick(player, meter, item), "pré-condição: pegou o objeto")
	(player.get_node("Head") as Node3D).rotation.x = deg_to_rad(-45.0)
	await wait_physics_frames(2)
	var overlaps: int = await _run(player, meter, item, Vector2(0.0, 1.0), WALK_TICKS)
	var start_z: float = player.global_position.z
	var back_overlaps: int = await _run(player, meter, item, Vector2(0.0, -1.0), REVERSE_TICKS)
	var back: float = absf(player.global_position.z - start_z)
	note("olhando para baixo (-45°): objeto em (%.2f, %.2f, %.2f), ticks sobrepostos %d, recuou %.2f m" % [
		item.global_position.x, item.global_position.y, item.global_position.z, overlaps, back])
	assert_eq(overlaps + back_overlaps, 0, "olhando para o chão, o objeto nunca sobrepõe o mundo")
	assert_true(back >= MIN_UNSTUCK_M, "olhando para o chão, o jogador não fica preso (recuou %.2f m)" % back)
	await release_and_flush(world["container"] as Node3D)


## Soltar e arremessar dentro de parede continuam recusados. O objeto é posto dentro de um bloco no mesmo tick da soltura
## e do arremesso (a varredura da mão não deixa o objeto entrar em bloco novo sozinho); fora do bloco, a soltura funciona.
func test_bug016_soltar_e_arremessar_dentro_de_parede_seguem_recusados() -> void:
	var world: Dictionary = await _scene(Vector3(9.0, 0.0, -0.6), PI)
	var root: Node = world["root"] as Node
	var player: PlayerRoot = world["player"] as PlayerRoot
	var meter: Fx.Meter = world["meter"] as Fx.Meter
	var container: Node3D = world["container"] as Node3D
	var item: Throwable = _spawn(root, LIGHT_SCENE, Vector3(11.0, 1.2, -0.7))
	assert_true(await _pick(player, meter, item), "pré-condição: pegou o objeto")
	await _run(player, meter, item, Vector2(0.0, 1.0), WALK_TICKS)
	var inside: Vector3 = Vector3(9.0, 1.2, -0.7)
	var block: StaticBody3D = Fx.add_box(container, inside, Vector3(0.6, 0.6, 0.6), &"wood")
	await wait_physics_frames(3)
	item.set_hold_transform(Transform3D(Basis(), inside))
	note("bloco em %s; objeto posto dentro dele; can_place_at=%s" % [str(block.global_position), str(item.can_place_at(item.global_transform, player))])
	assert_false(item.can_place_at(item.global_transform, player), "pré-condição: o objeto está dentro do bloco")
	assert_false(player.get_hold().drop_held(), "dentro de um bloco, a soltura é recusada")
	assert_true(item.is_held(), "segue na mão depois da soltura recusada")
	assert_false(player.get_hold().throw_held(), "dentro de um bloco, o arremesso é recusado")
	assert_true(item.is_held(), "segue na mão depois do arremesso recusado")
	await release_and_flush(block)
	await wait_physics_frames(2)
	assert_true(player.get_hold().drop_held(), "tirado o bloco, a soltura funciona")


## Quina de duas paredes (canto interno): o jogador anda na diagonal até o canto com o objeto leve na mão.
func test_bug016_quina_de_duas_paredes() -> void:
	var world: Dictionary = await _boxes(Vector3(0.4, 0.0, -0.6), -3.0 * PI / 4.0)
	var container: Node3D = world["container"] as Node3D
	var player: PlayerRoot = world["player"] as PlayerRoot
	var meter: Fx.Meter = world["meter"] as Fx.Meter
	Fx.add_box(container, Vector3(0.0, 1.5, 0.0), Vector3(4.0, 3.0, 0.2), &"wood")
	Fx.add_box(container, Vector3(1.0, 1.5, -1.5), Vector3(0.2, 3.0, 3.0), &"wood")
	await wait_physics_frames(3)
	var item: Throwable = _spawn(container, LIGHT_SCENE, Vector3(-1.5, 1.0, -1.5))
	assert_true(await _pick(player, meter, item), "pré-condição: pegou o objeto")
	var overlaps: int = await _run(player, meter, item, Vector2(0.0, 1.0), WALK_TICKS)
	var start: Vector3 = player.global_position
	# Canto interno em (0,9; -0,1): a ida tem de terminar encostada no canto para o teste contar.
	var corner_distance: float = Vector2(start.x - 0.9, start.z + 0.1).length()
	var back_overlaps: int = await _run(player, meter, item, Vector2(0.0, -1.0), REVERSE_TICKS)
	var back: float = player.global_position.distance_to(start)
	note("quina: ida terminou em (%.2f, %.2f), a %.2f m do canto; objeto (%.2f, %.2f); ticks sobrepostos %d; recuou %.2f m" % [
		start.x, start.z, corner_distance, item.global_position.x, item.global_position.z, overlaps, back])
	assert_true(corner_distance < 0.4, "a ida chega ao canto (%.2f m)" % corner_distance)
	assert_eq(overlaps + back_overlaps, 0, "na quina, o objeto nunca sobrepõe as paredes")
	assert_true(back >= MIN_UNSTUCK_M, "na quina, o jogador não fica preso (recuou %.2f m)" % back)
	assert_eq(meter.penetrations, 0, "na quina, o corpo não penetra")
	await release_and_flush(container)


## Batente de porta: vão de 1 m numa parede (x = 0) e o jogador passa com o objeto na mão, passando perto do batente.
func test_bug016_batente_de_porta_aberta() -> void:
	# Direção para a quina do vão (0; -1,0): a mão, 0,7 m à frente, passa perto do batente.
	var world: Dictionary = await _boxes(Vector3(-1.0, 0.0, -0.5), atan2(-1.0, 0.5))
	var container: Node3D = world["container"] as Node3D
	var player: PlayerRoot = world["player"] as PlayerRoot
	var meter: Fx.Meter = world["meter"] as Fx.Meter
	Fx.add_box(container, Vector3(0.0, 1.5, -1.75), Vector3(0.2, 3.0, 1.5), &"wood")
	Fx.add_box(container, Vector3(0.0, 1.5, 0.75), Vector3(0.2, 3.0, 1.5), &"wood")
	await wait_physics_frames(3)
	var item: Throwable = _spawn(container, LIGHT_SCENE, Vector3(-1.5, 1.0, -0.5))
	assert_true(await _pick(player, meter, item), "pré-condição: pegou o objeto")
	var overlaps: int = await _run(player, meter, item, Vector2(0.0, 1.0), WALK_TICKS)
	note("batente: objeto (%.2f, %.2f, %.2f), jogador x=%.2f, ticks sobrepostos %d" % [
		item.global_position.x, item.global_position.y, item.global_position.z, player.global_position.x, overlaps])
	assert_eq(overlaps, 0, "passando pelo batente, o objeto nunca sobrepõe o batente")
	assert_eq(meter.penetrations, 0, "passando pelo batente, o corpo não penetra")
	await release_and_flush(container)

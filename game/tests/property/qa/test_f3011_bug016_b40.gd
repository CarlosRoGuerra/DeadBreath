extends TestCase
## Terceira verificação do BUG-016 (commit b40c218): avanço da câmera rumo à mão, em passos de 0,1 m, quando a partida
## recuada e a câmera sobrepõem o mundo. Riscos testados: encostado e de frente para muro fino (0,05 m e 0,1 m) e para
## batente (trecho estreito); diagonal; giro de 360° encostado na parede. Além de sobreposição tick a tick (folga de 1 cm),
## mede se o centro do objeto passou da face próxima do muro dentro da largura dele (um objeto que pula inteiro para o
## outro lado não sobrepõe nada, por isso a checagem de sobreposição sozinha não basta). Autor: QA Engineer (BUG-016, F3-011).

const Fx := preload("res://tests/integration/qa/fixtures/qa_fixture.gd")
const HEAVY_SCENE: String = "res://content/props/throwables/throwable_heavy.tscn"
const SETTLE: int = 12
const WALK_TICKS: int = 150
const SHRINK_M: float = 0.01
const WORLD_MASK: int = 3
const HEAVY_HALF_M: float = 0.3
const SPIN_TICKS: int = 180


func before_all() -> void:
	Settings.autosave = false


func after_all() -> void:
	Settings.autosave = true


## Mundo isolado só com geometria (piso e caixas), sem a cena do nível.
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
	item.throwable_id = &"throwable_bug016_b40"
	parent.add_child(item)
	item.global_position = at
	return item


func _pick(player: PlayerRoot, meter: Fx.Meter, item: Throwable) -> bool:
	await wait_physics_frames(4)
	var picked: bool = player.get_hold().try_pick(item)
	await wait_physics_frames(2)
	meter.sample(player, Fx.body_overlaps_world(player))
	return picked


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


## O centro do objeto passou da face próxima do muro (face_z, lado do jogador em -z) dentro da largura do muro?
## half_x e center_x descrevem o trecho do muro; o objeto conta como da largura se o seu centro está a menos de
## half_x + meia-aresta do centro do trecho.
func _beyond(item: Throwable, face_z: float, center_x: float, half_x: float) -> bool:
	var position: Vector3 = item.global_position
	return position.z > face_z + 0.001 and absf(position.x - center_x) < half_x + HEAVY_HALF_M


## Um tick com o objeto na mão. Devolve true se sobrepõe o mundo neste tick.
func _tick(player: PlayerRoot, meter: Fx.Meter, item: Throwable, move: Vector2) -> bool:
	player.get_motor().set_scripted_input(Fx.move_input(move, false))
	await wait_physics_frames(1)
	meter.sample(player, Fx.body_overlaps_world(player))
	return _held_overlaps_world(item, player)


## Muro (ou batente) de frente: anda para ele com o objeto pesado na mão; em todo tick, nada de sobreposição e o
## objeto não passa da face próxima dentro da largura do muro.
func _face_on_wall(thickness: float, half_x: float, label: String) -> void:
	var world: Dictionary = await _boxes(Vector3(0.0, 0.0, -0.6), PI)
	var container: Node3D = world["container"] as Node3D
	var player: PlayerRoot = world["player"] as PlayerRoot
	var meter: Fx.Meter = world["meter"] as Fx.Meter
	var face_z: float = -thickness * 0.5
	Fx.add_box(container, Vector3(0.0, 1.5, 0.0), Vector3(half_x * 2.0, 3.0, thickness), &"wood")
	await wait_physics_frames(3)
	var item: Throwable = _spawn(container, Vector3(-2.0, 1.0, -2.0))
	assert_true(await _pick(player, meter, item), "%s: pegou o objeto pesado" % label)
	var overlaps: int = 0
	var beyond_ticks: int = 0
	for _i: int in WALK_TICKS:
		if await _tick(player, meter, item, Vector2(0.0, 1.0)):
			overlaps += 1
		if _beyond(item, face_z, 0.0, half_x):
			beyond_ticks += 1
	note("%s: ticks sobrepostos %d; ticks além da face %d; objeto z %.3f (face %.3f); jogador z %.3f" % [
		label, overlaps, beyond_ticks, item.global_position.z, face_z, player.global_position.z])
	assert_eq(overlaps, 0, "%s: o objeto nunca sobrepõe o muro" % label)
	assert_eq(beyond_ticks, 0, "%s: o objeto nunca passa da face próxima para o outro lado" % label)
	assert_eq(meter.penetrations, 0, "%s: o corpo do jogador não penetra" % label)
	await release_and_flush(container)


## Muro fino de 0,05 m, de frente, encostado.
func test_muro_fino_005_de_frente_nao_pula() -> void:
	await _face_on_wall(0.05, 3.0, "muro 0,05 m")


## Muro fino de 0,10 m, de frente, encostado.
func test_muro_fino_010_de_frente_nao_pula() -> void:
	await _face_on_wall(0.10, 3.0, "muro 0,10 m")


## Batente: trecho estreito (0,5 m de largura, 0,2 m de espessura) à frente do jogador, com o objeto centrado no eixo.
func test_batente_estreito_de_frente_nao_pula() -> void:
	var world: Dictionary = await _boxes(Vector3(0.0, 0.0, -0.6), PI)
	var container: Node3D = world["container"] as Node3D
	var player: PlayerRoot = world["player"] as PlayerRoot
	var meter: Fx.Meter = world["meter"] as Fx.Meter
	const JAMB_CENTER_X: float = 0.0
	const JAMB_HALF_X: float = 0.25
	Fx.add_box(container, Vector3(JAMB_CENTER_X, 1.5, 0.0), Vector3(JAMB_HALF_X * 2.0, 3.0, 0.2), &"wood")
	await wait_physics_frames(3)
	var item: Throwable = _spawn(container, Vector3(-2.0, 1.0, -2.0))
	assert_true(await _pick(player, meter, item), "batente: pegou o objeto pesado")
	var overlaps: int = 0
	var beyond_ticks: int = 0
	for _i: int in WALK_TICKS:
		if await _tick(player, meter, item, Vector2(0.0, 1.0)):
			overlaps += 1
		if _beyond(item, -0.1, JAMB_CENTER_X, JAMB_HALF_X):
			beyond_ticks += 1
	note("batente: ticks sobrepostos %d; ticks além da face %d; objeto (%.3f, %.3f); jogador z %.3f" % [
		overlaps, beyond_ticks, item.global_position.x, item.global_position.z, player.global_position.z])
	assert_eq(overlaps, 0, "batente: o objeto nunca sobrepõe o batente")
	assert_eq(beyond_ticks, 0, "batente: o objeto nunca passa do batente para o outro lado (no seu trecho)")
	assert_eq(meter.penetrations, 0, "batente: o corpo não penetra")
	await release_and_flush(container)


## Diagonal: o jogador anda a 45° para um muro de 0,2 m, com o objeto pesado na mão.
func test_diagonal_contra_muro_nao_pula() -> void:
	var world: Dictionary = await _boxes(Vector3(0.0, 0.0, -0.6), -3.0 * PI / 4.0)
	var container: Node3D = world["container"] as Node3D
	var player: PlayerRoot = world["player"] as PlayerRoot
	var meter: Fx.Meter = world["meter"] as Fx.Meter
	Fx.add_box(container, Vector3(0.0, 1.5, 0.0), Vector3(8.0, 3.0, 0.2), &"wood")
	await wait_physics_frames(3)
	var item: Throwable = _spawn(container, Vector3(-2.0, 1.0, -2.0))
	assert_true(await _pick(player, meter, item), "diagonal: pegou o objeto pesado")
	var overlaps: int = 0
	var beyond_ticks: int = 0
	for _i: int in WALK_TICKS:
		if await _tick(player, meter, item, Vector2(0.0, 1.0)):
			overlaps += 1
		if _beyond(item, -0.1, 0.0, 4.0):
			beyond_ticks += 1
	note("diagonal: ticks sobrepostos %d; ticks além da face %d; objeto (%.3f, %.3f); jogador (%.3f, %.3f)" % [
		overlaps, beyond_ticks, item.global_position.x, item.global_position.z, player.global_position.x, player.global_position.z])
	assert_eq(overlaps, 0, "diagonal: o objeto nunca sobrepõe o muro")
	assert_eq(beyond_ticks, 0, "diagonal: o objeto nunca passa da face próxima")
	assert_eq(meter.penetrations, 0, "diagonal: o corpo não penetra")
	await release_and_flush(container)


## Giro de 360° encostado na parede sul (corpo tocando a face), com o objeto pesado na mão: em todo tick, sem
## sobreposição e sem passar da face próxima.
func test_giro_360_encostado_na_parede_nao_passa() -> void:
	var world: Dictionary = await _boxes(Vector3(0.0, 0.0, -0.35), PI)
	var container: Node3D = world["container"] as Node3D
	var player: PlayerRoot = world["player"] as PlayerRoot
	var meter: Fx.Meter = world["meter"] as Fx.Meter
	Fx.add_box(container, Vector3(0.0, 1.5, 0.0), Vector3(12.0, 3.0, 0.2), &"wood")
	await wait_physics_frames(3)
	var item: Throwable = _spawn(container, Vector3(-2.0, 1.0, -2.0))
	assert_true(await _pick(player, meter, item), "giro: pegou o objeto pesado")
	var overlaps: int = 0
	var beyond_ticks: int = 0
	var worst_z: float = -INF
	for _i: int in 60:
		if await _tick(player, meter, item, Vector2(0.0, 1.0)):
			overlaps += 1
	for step: int in SPIN_TICKS:
		player.rotation.y = PI + TAU * float(step) / float(SPIN_TICKS)
		if await _tick(player, meter, item, Vector2.ZERO):
			overlaps += 1
		worst_z = maxf(worst_z, item.global_position.z)
		if _beyond(item, -0.1, 0.0, 6.0):
			beyond_ticks += 1
	note("giro 360° encostado: ticks sobrepostos %d; ticks além da face %d; maior z do objeto %.3f (face -0,100); jogador z %.3f" % [
		overlaps, beyond_ticks, worst_z, player.global_position.z])
	assert_eq(overlaps, 0, "giro: o objeto nunca sobrepõe o mundo em nenhum tick")
	assert_eq(beyond_ticks, 0, "giro: o objeto nunca passa da face próxima em nenhum tick")
	assert_eq(meter.penetrations, 0, "giro: o corpo do jogador não penetra")
	await release_and_flush(container)

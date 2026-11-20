extends TestCase
## F1-011 (QA independente): interação através de paredes, portas e pickups na cena jogável, e interação segurada com o
## menu de pausa (BUG-005, correção: pausar no meio do segurar cancela o segurar com interaction_failed). Foco = raio da
## câmera (camadas 1, 2 e 5), como em InteractionComponent. Autor: QA Engineer (F1-011).

const Fx := preload("res://tests/integration/qa/fixtures/qa_fixture.gd")

const SETTLE_TICKS: int = 12
const RAY_SAMPLES: int = 1200
const RAY_SEED: int = 20261122
const SIGHT_MASK: int = 19
const HIT_TOL_M: float = 0.15
## Abertura com o painel aberto (door_sala_cozinha, x = 6, z de -3,45 a -2,55, até 2,0 m): raios passam.
const OPEN_DOORWAY_X: float = 6.0
const OPEN_DOORWAY_Z_MIN: float = -3.45
const OPEN_DOORWAY_Z_MAX: float = -2.55
const OPEN_DOORWAY_TOP_Y: float = 2.0
const LOCKED_DOOR_NAME: String = "door_cozinha_corredor"
const PICKUP_NAME: String = "pickup_inhaler_kitchen"
const SLOW_OPEN_TICKS: int = 90
const HOLD_BEFORE_PAUSE_TICKS: int = 12
const PAUSED_FRAMES: int = 40
const AFTER_RESUME_FRAMES: int = 90
const DOOR_NAME: String = "door_sala_corredor"


func before_all() -> void:
	Settings.autosave = false


func after_all() -> void:
	Settings.autosave = true


func after_each() -> void:
	get_tree().paused = false


func _push_action(action: StringName, pressed: bool) -> void:
	var event: InputEventAction = InputEventAction.new()
	event.action = action
	event.pressed = pressed
	get_viewport().push_input(event)


## Cena jogável em um mundo isolado (para os raios e o pickup).
func _playable_isolated() -> Dictionary:
	var container: Node3D = add_isolated_world()
	var root: Node = Fx.instantiate_scene(Fx.PLAYABLE_PATH, container)
	await wait_physics_frames(SETTLE_TICKS)
	return {"container": container, "root": root, "player": Fx.find_player(root)}


## Cena jogável na árvore principal (recebe input de ação e pausa de verdade).
func _playable_in_tree() -> Dictionary:
	var packed: PackedScene = load(Fx.PLAYABLE_PATH) as PackedScene
	var root: Node = add_child_autofree(packed.instantiate())
	await wait_physics_frames(SETTLE_TICKS)
	var player: PlayerRoot = Fx.find_player(root)
	var door: Door = root.find_child(DOOR_NAME, true, false) as Door
	player.global_position = Vector3(6.45, 0.0, -0.7)
	player.rotation.y = PI / 2.0
	await wait_physics_frames(SETTLE_TICKS)
	return {"root": root, "player": player, "door": door, "menu": root.get_node("PauseMenu") as PauseMenu}


## Raios de salas vizinhas, atravessando as paredes e as portas fechadas. Vazamento = nada no caminho, ou o primeiro
## acerto depois do plano da parede. Móveis e paredes antes do plano (ex.: a mesa) são acertos legítimos.
func test_interacao_raios_nao_atravessam_paredes_nem_portas_fechadas() -> void:
	var world: Dictionary = await _playable_isolated()
	var player: PlayerRoot = world["player"] as PlayerRoot
	var space: PhysicsDirectSpaceState3D = player.get_world_3d().direct_space_state
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = RAY_SEED
	var tested: int = 0
	var through_open: int = 0
	var leaks: PackedStringArray = PackedStringArray()
	for sample: int in RAY_SAMPLES:
		var pair: int = rng.randi_range(0, 4)
		var p: Vector3 = Vector3.ZERO
		var q: Vector3 = Vector3.ZERO
		var plane_axis: int = 0
		var plane_value: float = 0.0
		if pair == 0:
			p = Vector3(rng.randf_range(0.3, 5.7), rng.randf_range(0.05, 1.7), rng.randf_range(-5.7, -0.3))
			q = Vector3(rng.randf_range(6.3, 13.7), rng.randf_range(0.05, 1.7), rng.randf_range(-5.7, -1.7))
			plane_axis = 0
			plane_value = 6.0
		elif pair == 1:
			p = Vector3(rng.randf_range(0.3, 5.7), rng.randf_range(0.05, 1.7), rng.randf_range(-5.7, -0.3))
			q = Vector3(rng.randf_range(6.3, 13.7), rng.randf_range(0.05, 1.7), rng.randf_range(-1.1, -0.3))
			plane_axis = 0
			plane_value = 6.0
		elif pair == 2:
			p = Vector3(rng.randf_range(6.3, 13.7), rng.randf_range(0.05, 1.7), rng.randf_range(-5.7, -1.7))
			q = Vector3(rng.randf_range(14.3, 19.7), rng.randf_range(0.05, 1.7), rng.randf_range(-5.7, -0.3))
			plane_axis = 0
			plane_value = 14.0
		elif pair == 3:
			p = Vector3(rng.randf_range(6.3, 13.7), rng.randf_range(0.05, 1.7), rng.randf_range(-5.7, -1.7))
			q = Vector3(rng.randf_range(6.3, 13.7), rng.randf_range(0.05, 1.7), rng.randf_range(-1.1, -0.3))
			plane_axis = 2
			plane_value = -1.4
		else:
			p = Vector3(rng.randf_range(0.3, 5.7), rng.randf_range(0.05, 1.7), rng.randf_range(-5.7, -0.3))
			q = Vector3(rng.randf_range(-3.0, -0.5), rng.randf_range(0.05, 1.7), rng.randf_range(-5.7, -0.3))
			plane_axis = 0
			plane_value = 0.0
		var p_coord: float = p.x if plane_axis == 0 else p.z
		var q_coord: float = q.x if plane_axis == 0 else q.z
		var t: float = (plane_value - p_coord) / (q_coord - p_coord)
		if t <= 0.0 or t >= 1.0:
			continue
		var crossing: Vector3 = p.lerp(q, t)
		if plane_axis == 0 and plane_value == OPEN_DOORWAY_X and crossing.z > OPEN_DOORWAY_Z_MIN and crossing.z < OPEN_DOORWAY_Z_MAX and crossing.y < OPEN_DOORWAY_TOP_Y:
			through_open += 1
			continue
		tested += 1
		var params: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(p, q, SIGHT_MASK)
		var hit: Dictionary = space.intersect_ray(params)
		var leaked: bool = hit.is_empty()
		if not hit.is_empty():
			var position: Vector3 = hit.get("position", Vector3.ZERO) as Vector3
			leaked = p.distance_to(position) > p.distance_to(crossing) + HIT_TOL_M
		if leaked and leaks.size() < 6:
			leaks.append("par %d: de %s a %s cruza em %s, primeiro acerto em %s" % [pair, str(p), str(q), str(crossing), "nada" if hit.is_empty() else str(hit.get("position"))])
		elif leaked:
			leaks.append("")
	var leak_count: int = 0
	for leak: String in leaks:
		if not leak.is_empty():
			leak_count += 1
	note("raios testados=%d; passando pelo vão aberto=%d; vazamentos=%d" % [tested, through_open, leak_count])
	assert_true(tested > 500, "amostra suficiente de raios (%d)" % tested)
	assert_eq(leak_count, 0, "nenhum raio atravessa parede ou porta fechada: " + "; ".join(leaks))
	await release_and_flush(world["container"] as Node3D)


## Pela porta trancada (fechada), a mira acerta a porta, não o pickup atrás dela. Apertar E dá feedback de porta
## trancada e o pickup continua no lugar.
func test_interacao_pickup_atras_da_porta_trancada_nao_e_alcancado() -> void:
	var world: Dictionary = await _playable_isolated()
	var player: PlayerRoot = world["player"] as PlayerRoot
	var root: Node = world["root"] as Node
	var locked: Door = root.find_child(LOCKED_DOOR_NAME, true, false) as Door
	var pickup: Pickup = root.find_child(PICKUP_NAME, true, false) as Pickup
	assert_not_null(locked, "a porta trancada existe")
	assert_not_null(pickup, "o pickup da cozinha existe")
	if locked == null or pickup == null:
		await release_and_flush(world["container"] as Node3D)
		return
	# Do corredor, olhando para a porta trancada: a mira passa pelo painel em (8,5; -1,4).
	player.global_position = Vector3(7.7, 0.0, -0.76)
	player.rotation.y = -0.894
	await wait_physics_frames(SETTLE_TICKS)
	var focus: Interactable = player.get_interaction().get_focused()
	assert_eq(focus, locked, "a mira acerta a porta trancada, não o pickup atrás dela")
	var picked: Array[bool] = [false]
	var on_picked: Callable = func(_id: StringName, _qty: int, _pid: StringName) -> void:
		picked[0] = true
	EventBus.item_picked.connect(on_picked)
	player.get_interaction().press_interact()
	await wait_physics_frames(2)
	player.get_interaction().release_interact()
	await wait_physics_frames(30)
	EventBus.item_picked.disconnect(on_picked)
	assert_false(picked[0], "nenhum item foi apanhado através da porta trancada")
	assert_true(is_instance_valid(pickup), "o pickup continua no mundo")
	assert_eq(locked.get_state(), Door.State.LOCKED, "a porta continua trancada")
	await release_and_flush(world["container"] as Node3D)


## Controle: o mesmo aperto (0,2 s) e a mesma soltura, sem menu, abrem a porta rápido (toque), não devagar.
func test_interacao_controle_segurar_sem_pausa_abre_rapido() -> void:
	var world: Dictionary = await _playable_in_tree()
	var player: PlayerRoot = world["player"] as PlayerRoot
	var door: Door = world["door"] as Door
	var opened_slow: Array[bool] = []
	door.opened.connect(func(slow: bool) -> void: opened_slow.append(slow))
	_push_action(&"interact", true)
	await wait_physics_frames(HOLD_BEFORE_PAUSE_TICKS)
	_push_action(&"interact", false)
	await wait_physics_frames(AFTER_RESUME_FRAMES)
	note("controle sem pausa: estado=%d; aberturas=%s" % [int(door.get_state()), str(opened_slow)])
	assert_eq(opened_slow, [false] as Array[bool], "sem pausa, o toque abre a porta rápido (aberturas=%s)" % str(opened_slow))
	assert_eq(player.get_interaction().is_holding(), false, "sem pausa, nenhum segurar fica pendente")


## BUG-005, correção: segurar E, abrir o menu no meio do segurar e soltar E com o menu aberto. Ao continuar, a pausa
## tem de ter cancelado o segurar (interaction_failed), a porta não pode abrir e nada fica pendente.
func test_interacao_segurada_com_menu_de_pausa_cancela_o_segurar() -> void:
	var world: Dictionary = await _playable_in_tree()
	var door: Door = world["door"] as Door
	var menu: PauseMenu = world["menu"] as PauseMenu
	var player: PlayerRoot = world["player"] as PlayerRoot
	assert_eq(player.get_interaction().get_focused(), door, "a porta está em foco antes de apertar E")
	var opened: Array[bool] = []
	var failed: Array[int] = [0]
	door.opened.connect(func(slow: bool) -> void: opened.append(slow))
	player.get_interaction().interaction_failed.connect(func(_target: Interactable) -> void: failed[0] += 1)
	_push_action(&"interact", true)
	await wait_physics_frames(HOLD_BEFORE_PAUSE_TICKS)
	_push_action(&"pause", true)
	assert_true(menu.is_open(), "o menu de pausa abriu no meio do segurar")
	assert_true(get_tree().paused, "a árvore está pausada")
	await wait_physics_frames(PAUSED_FRAMES)
	_push_action(&"interact", false)
	await wait_physics_frames(10)
	_push_action(&"pause", true)
	assert_false(menu.is_open(), "o menu fechou (continuar)")
	await wait_physics_frames(AFTER_RESUME_FRAMES)
	note("segurar com pausa: estado=%d; aberturas=%s; interaction_failed=%d; segurando=%s" % [
		int(door.get_state()), str(opened), failed[0], str(player.get_interaction().is_holding())])
	assert_true(failed[0] >= 1, "a pausa cancela o segurar (interaction_failed emitido)")
	assert_eq(door.get_state(), Door.State.CLOSED, "a porta continua fechada depois de continuar")
	assert_eq(opened.size(), 0, "nenhuma abertura sem a tecla apertada (aberturas=%s)" % str(opened))
	assert_false(player.get_interaction().is_holding(), "nada fica segurando depois de continuar")


## Aperto de E com o menu aberto é ignorado; depois de continuar, sem nova tecla, a porta não se mexe.
func test_interacao_aperto_durante_a_pausa_e_ignorado() -> void:
	var world: Dictionary = await _playable_in_tree()
	var door: Door = world["door"] as Door
	var menu: PauseMenu = world["menu"] as PauseMenu
	var opened: Array[bool] = []
	door.opened.connect(func(slow: bool) -> void: opened.append(slow))
	_push_action(&"pause", true)
	assert_true(menu.is_open(), "menu aberto")
	_push_action(&"interact", true)
	await wait_physics_frames(HOLD_BEFORE_PAUSE_TICKS)
	_push_action(&"interact", false)
	_push_action(&"pause", true)
	await wait_physics_frames(AFTER_RESUME_FRAMES)
	assert_eq(opened.size(), 0, "um aperto durante a pausa não abre a porta (aberturas=%s)" % str(opened))
	assert_eq(door.get_state(), Door.State.CLOSED, "a porta continua fechada")


## Depois do cancelamento, uma nova tecla (toque) funciona normalmente: a correção não pode travar a interação.
func test_interacao_depois_da_pausa_um_toque_abre_rapido() -> void:
	var world: Dictionary = await _playable_in_tree()
	var door: Door = world["door"] as Door
	var menu: PauseMenu = world["menu"] as PauseMenu
	var opened: Array[bool] = []
	door.opened.connect(func(slow: bool) -> void: opened.append(slow))
	_push_action(&"interact", true)
	await wait_physics_frames(HOLD_BEFORE_PAUSE_TICKS)
	_push_action(&"pause", true)
	await wait_physics_frames(PAUSED_FRAMES)
	_push_action(&"interact", false)
	_push_action(&"pause", true)
	assert_false(menu.is_open(), "menu fechado")
	await wait_physics_frames(4)
	_push_action(&"interact", true)
	await wait_physics_frames(2)
	_push_action(&"interact", false)
	await wait_physics_frames(AFTER_RESUME_FRAMES)
	note("toque depois da pausa: estado=%d; aberturas=%s" % [int(door.get_state()), str(opened)])
	assert_eq(opened, [false] as Array[bool], "depois da pausa, um toque abre a porta rápido (aberturas=%s)" % str(opened))

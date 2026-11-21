extends TestCase
## F3-004 (porta que fecha): fechar pela interação com a porta aberta e parada. Tocar fecha no tempo normal e faz
## 50 dB (door_normal); segurar fecha devagar e faz 30 dB (door_slow); trancada faz 45 dB (door_locked); o painel que
## bate num corpo para e faz 40 dB (door_normal). Durante o fechamento o estado segue OPEN (portal aberto) e vira
## CLOSED no fim. Tempos de movimento encurtados no teste (open_time_*_s). Autor: Gameplay Engineer.

const DOOR_SCENE: PackedScene = preload("res://components/world/door.tscn")
const SETTLE_FRAMES: int = 3
const FAST_S: float = 0.1
const SLOW_S: float = 0.4
const FAST_DONE_FRAMES: int = 14
const SLOW_HALF_FRAMES: int = 12
const BLOCK_FRAMES: int = 16
const OBSTACLE_LAYER: int = 2

var _events: Array[NoiseEvent] = []
var _closed_flags: Array[bool] = []


func before_all() -> void:
	Settings.autosave = false


func after_all() -> void:
	Settings.autosave = true


func before_each() -> void:
	_events.clear()
	_closed_flags.clear()


func _on_resolved(event: NoiseEvent, _result: PropagationResult) -> void:
	_events.append(event)


func _spawn(root: Node3D, state: Door.State) -> Door:
	var door: Door = DOOR_SCENE.instantiate() as Door
	door.initial_state = state
	door.open_time_fast_s = FAST_S
	door.open_time_slow_s = SLOW_S
	root.add_child(door)
	return door


func _world(root: Node3D) -> AcousticWorld:
	var world: AcousticWorld = AcousticWorld.new()
	root.add_child(world)
	world.noise_resolved_for_player.connect(_on_resolved)
	return world


func _context(held: bool) -> InteractionContext:
	var context: InteractionContext = InteractionContext.new()
	context.held = held
	return context


## Resolve a fila agora e devolve o último som de porta (DOOR) emitido.
func _last_door_event(world: AcousticWorld) -> NoiseEvent:
	_events.clear()
	world.flush()
	var found: NoiseEvent = null
	for event: NoiseEvent in _events:
		if event.category == Enums.NoiseCategory.DOOR:
			found = event
	return found


func test_tocar_fecha_no_tempo_normal_com_som_de_50_db() -> void:
	var root: Node3D = add_child_autofree(Node3D.new()) as Node3D
	var world: AcousticWorld = _world(root)
	var door: Door = _spawn(root, Door.State.OPEN)
	await wait_physics_frames(SETTLE_FRAMES)
	_closed_flags.clear()
	door.closed.connect(func(slow: bool) -> void: _closed_flags.append(slow))
	door.interact(_context(false))
	assert_true(door.is_closing(), "fechando")
	assert_eq(door.get_state(), Door.State.OPEN, "durante o fechamento o estado segue OPEN (portal aberto)")
	assert_false(door.can_interact(_context(false)), "não se interage com a porta enquanto ela se move")
	assert_eq(_closed_flags, [false] as Array[bool], "closed(false) no toque")
	var event: NoiseEvent = _last_door_event(world)
	assert_not_null(event, "o fechamento faz som de porta")
	if event != null:
		assert_eq(event.sound_id, &"door_normal", "toque: door_normal")
		assert_almost_eq(event.intensity_db, 50.0, 0.001, "toque: 50 dB")
	await wait_physics_frames(FAST_DONE_FRAMES)
	assert_eq(door.get_state(), Door.State.CLOSED, "no fim do movimento a porta vira CLOSED")
	assert_false(door.is_closing(), "parada")
	assert_almost_eq(door.get_panel_angle_deg(), 0.0, 0.001, "painel fechado")


func test_segurar_fecha_devagar_com_som_de_30_db() -> void:
	var root: Node3D = add_child_autofree(Node3D.new()) as Node3D
	var world: AcousticWorld = _world(root)
	var door: Door = _spawn(root, Door.State.OPEN)
	await wait_physics_frames(SETTLE_FRAMES)
	_closed_flags.clear()
	door.closed.connect(func(slow: bool) -> void: _closed_flags.append(slow))
	door.interact(_context(true))
	assert_eq(_closed_flags, [true] as Array[bool], "closed(true) ao segurar")
	var event: NoiseEvent = _last_door_event(world)
	assert_not_null(event, "o fechamento lento faz som")
	if event != null:
		assert_eq(event.sound_id, &"door_slow", "segurando: door_slow")
		assert_almost_eq(event.intensity_db, 30.0, 0.001, "segurando: 30 dB")
	await wait_physics_frames(SLOW_HALF_FRAMES)
	assert_true(door.is_closing(), "ainda fechando no meio do tempo lento")
	await wait_physics_frames(SLOW_HALF_FRAMES + 8)
	assert_eq(door.get_state(), Door.State.CLOSED, "fecha no fim do tempo lento")


func test_trancada_nao_fecha_e_faz_som_de_45_db() -> void:
	var root: Node3D = add_child_autofree(Node3D.new()) as Node3D
	var world: AcousticWorld = _world(root)
	var door: Door = _spawn(root, Door.State.LOCKED)
	await wait_physics_frames(SETTLE_FRAMES)
	door.interact(_context(false))
	assert_eq(door.get_state(), Door.State.LOCKED, "trancada continua trancada")
	var event: NoiseEvent = _last_door_event(world)
	assert_not_null(event, "a tentativa em porta trancada faz som")
	if event != null:
		assert_eq(event.sound_id, &"door_locked", "door_locked")
		assert_almost_eq(event.intensity_db, 45.0, 0.001, "45 dB")


func test_painel_que_bate_num_corpo_para_e_faz_som_de_40_db() -> void:
	var root: Node3D = add_child_autofree(Node3D.new()) as Node3D
	var world: AcousticWorld = _world(root)
	var door: Door = _spawn(root, Door.State.OPEN)
	# Corpo dinâmico (camada 2) onde o painel fechado iria: o fechamento encosta nele.
	var obstacle: StaticBody3D = StaticBody3D.new()
	obstacle.collision_layer = OBSTACLE_LAYER
	obstacle.position = Vector3(0.45, 1.0, 0.0)
	var shape_node: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(0.3, 2.0, 0.3)
	shape_node.shape = box
	obstacle.add_child(shape_node)
	root.add_child(obstacle)
	await wait_physics_frames(SETTLE_FRAMES)
	var blockers: Array[Node] = []
	door.blocked.connect(func(body: Node) -> void: blockers.append(body))
	door.interact(_context(false))
	await wait_physics_frames(BLOCK_FRAMES)
	assert_eq(blockers.size(), 1, "um bloqueio por contato")
	if blockers.size() == 1:
		assert_eq(blockers[0], obstacle, "o bloqueio é o corpo")
	assert_true(door.is_blocked(), "parada no contato")
	assert_eq(door.get_state(), Door.State.OPEN, "bloqueada continua OPEN")
	var angle: float = door.get_panel_angle_deg()
	assert_true(angle > 1.0 and angle < 89.0, "o painel parou no meio do caminho (%.1f°)" % angle)
	# Os sons chegam por flush do próprio AcousticWorld (tick de física) e ficam em _events.
	world.flush()
	var batida: NoiseEvent = null
	for candidate: NoiseEvent in _events:
		if candidate.category == Enums.NoiseCategory.DOOR and candidate.sound_id == &"door_normal" and is_equal_approx(candidate.intensity_db, 40.0):
			batida = candidate
	assert_not_null(batida, "a batida faz door_normal de 40 dB")


func test_segunda_interacao_com_a_porta_em_movimento_nao_inverte() -> void:
	var root: Node3D = add_child_autofree(Node3D.new()) as Node3D
	_world(root)
	var door: Door = _spawn(root, Door.State.OPEN)
	await wait_physics_frames(SETTLE_FRAMES)
	_closed_flags.clear()
	door.closed.connect(func(slow: bool) -> void: _closed_flags.append(slow))
	door.interact(_context(false))
	door.interact(_context(false))
	assert_eq(_closed_flags.size(), 1, "só um fechamento começou")
	await wait_physics_frames(FAST_DONE_FRAMES)
	assert_eq(door.get_state(), Door.State.CLOSED, "o fechamento terminou fechado")

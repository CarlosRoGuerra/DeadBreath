extends TestCase
## Verificação F3-010, N1 (NOI-05, COMPONENT_CONTRACTS §6.3): as fontes do mundo nunca tentam emitir som do corpo.
## A trava do NoiseEmitter recusa com Log.error (categoria acoustics), sem evento. Aqui o ciclo inteiro de uma porta
## (abrir tocando, fechar segurando, trancar e sacudir) e o impacto de um arremessável rodam sem nenhuma recusa, e todo
## evento sai na categoria da fonte. Uma porta que tentasse emitir tosse falharia aqui. Autor: Director.

const DOOR_SCENE: PackedScene = preload("res://components/world/door.tscn")
const THROWABLE_SCENE: PackedScene = preload("res://content/props/throwables/throwable_light.tscn")
const SETTLE_FRAMES: int = 3
const MOVE_FRAMES: int = 30
const FAST_S: float = 0.1
const SLOW_S: float = 0.3

var _errors: Array[String] = []
var _events: Array[NoiseEvent] = []


func before_each() -> void:
	_errors.clear()
	_events.clear()


func _on_logged(log_level: int, category: StringName, message: String) -> void:
	if log_level == Log.ERROR and category == &"acoustics":
		_errors.append(message)


func _on_resolved(event: NoiseEvent, _result: PropagationResult) -> void:
	_events.append(event)


func _world(root: Node3D) -> AcousticWorld:
	var world: AcousticWorld = AcousticWorld.new()
	root.add_child(world)
	world.noise_resolved_for_player.connect(_on_resolved)
	return world


func _context(held: bool) -> InteractionContext:
	var context: InteractionContext = InteractionContext.new()
	context.held = held
	return context


func test_ciclo_da_porta_sem_recusa_e_so_categoria_porta() -> void:
	var root: Node3D = add_child_autofree(Node3D.new()) as Node3D
	var world: AcousticWorld = _world(root)
	var door: Door = DOOR_SCENE.instantiate() as Door
	door.initial_state = Door.State.CLOSED
	door.open_time_fast_s = FAST_S
	door.open_time_slow_s = SLOW_S
	root.add_child(door)
	await wait_physics_frames(SETTLE_FRAMES)
	Log.message_logged.connect(_on_logged)
	door.interact(_context(false))
	await wait_physics_frames(MOVE_FRAMES)
	door.interact(_context(true))
	await wait_physics_frames(MOVE_FRAMES)
	door.lock()
	door.interact(_context(false))
	world.flush()
	Log.message_logged.disconnect(_on_logged)
	assert_eq(door.get_state(), Door.State.LOCKED, "pré-condição: a porta abriu, fechou e foi trancada")
	assert_eq(_errors.size(), 0, "nenhuma recusa do NoiseEmitter: %s" % [_errors])
	assert_true(_events.size() >= 3, "abrir, fechar e sacudir emitiram (%d eventos)" % _events.size())
	for event: NoiseEvent in _events:
		assert_eq(event.category, Enums.NoiseCategory.DOOR, "a porta só emite DOOR (%s)" % event.sound_id)


func test_impacto_do_arremessavel_sem_recusa() -> void:
	var root: Node3D = add_child_autofree(Node3D.new()) as Node3D
	var world: AcousticWorld = _world(root)
	var item: Throwable = THROWABLE_SCENE.instantiate() as Throwable
	item.throwable_id = &"throwable_test"
	root.add_child(item)
	await wait_physics_frames(SETTLE_FRAMES)
	Log.message_logged.connect(_on_logged)
	item._speed_before_step = 6.0
	item._on_body_entered(null)
	world.flush()
	Log.message_logged.disconnect(_on_logged)
	assert_eq(_errors.size(), 0, "nenhuma recusa do NoiseEmitter: %s" % [_errors])
	assert_eq(_events.size(), 1, "um impacto")
	if _events.size() == 1:
		assert_eq(_events[0].category, Enums.NoiseCategory.OBJECT_IMPACT, "o objeto só emite OBJECT_IMPACT")

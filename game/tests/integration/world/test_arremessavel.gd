extends TestCase
## F3-004 (arremessáveis): pegar com interação (toque na pega), segurar diante da câmera, arremessar (ação throw,
## aqui chamada direto) e o impacto que vira OBJECT_IMPACT (sound_id impact, 50 a 80 dB). Cooldown de 0,25 s por
## objeto e velocidade mínima para ruído. Autor: Gameplay Engineer.

const PlayerWorld := preload("res://tests/integration/player/fixtures/player_world.gd")
const THROWABLE_SCENE: PackedScene = preload("res://content/props/throwables/throwable_light.tscn")
const SETTLE_FRAMES: int = 3
const FLIGHT_FRAMES: int = 24
const WALL_Z: float = -2.6
const LEVEL_MIN_DB: float = 50.0
const LEVEL_MAX_DB: float = 80.0
const TOL: float = 0.001

var _events: Array[NoiseEvent] = []


func before_all() -> void:
	Settings.autosave = false


func after_all() -> void:
	Settings.autosave = true


func before_each() -> void:
	_events.clear()


func _on_resolved(event: NoiseEvent, _result: PropagationResult) -> void:
	_events.append(event)


func _spawn_item(root: Node3D, position: Vector3) -> Throwable:
	var item: Throwable = THROWABLE_SCENE.instantiate() as Throwable
	item.throwable_id = &"throwable_test"
	item.position = position
	root.add_child(item)
	return item


func _impacts() -> Array[NoiseEvent]:
	var out: Array[NoiseEvent] = []
	for event: NoiseEvent in _events:
		if event.category == Enums.NoiseCategory.OBJECT_IMPACT:
			out.append(event)
	return out


func test_pega_segura_e_arremessa_com_impacto_de_ruido() -> void:
	var root: Node3D = add_child_autofree(Node3D.new()) as Node3D
	var world: AcousticWorld = AcousticWorld.new()
	root.add_child(world)
	world.noise_resolved_for_player.connect(_on_resolved)
	var player: PlayerRoot = PlayerWorld.spawn_player(root, Vector3.ZERO)
	PlayerWorld.add_box(root, Vector3(0.0, 1.5, WALL_Z), Vector3(3.0, 3.0, 0.2), &"wood")
	var item: Throwable = _spawn_item(root, Vector3(0.0, 1.65, -1.0))
	await wait_physics_frames(SETTLE_FRAMES)
	assert_eq(player.get_interaction().get_focused(), item.get_node("Grip"), "a pega do objeto está em foco")
	player.get_interaction().press_interact()
	player.get_interaction().release_interact()
	await wait_physics_frames(1)
	assert_true(item.is_held(), "tocar na pega pega o objeto")
	assert_eq(player.get_hold().get_held(), item, "a mão segura o objeto")
	player.get_hold().throw_held()
	assert_false(item.is_held(), "arremessado: não está mais na mão")
	await wait_physics_frames(FLIGHT_FRAMES)
	var impacts: Array[NoiseEvent] = _impacts()
	assert_true(impacts.size() >= 1, "o objeto bate na parede e faz ruído de impacto (%d)" % impacts.size())
	if impacts.size() >= 1:
		var event: NoiseEvent = impacts[0]
		assert_eq(event.sound_id, &"impact", "sound_id impact")
		assert_eq(event.source_id, &"throwable_test", "fonte: o id do objeto")
		assert_true(event.intensity_db >= LEVEL_MIN_DB - TOL and event.intensity_db <= LEVEL_MAX_DB + TOL,
			"intensidade de impacto entre 50 e 80 dB (%.1f)" % event.intensity_db)


func test_soltar_so_quando_a_forma_cabe() -> void:
	var root: Node3D = add_child_autofree(Node3D.new()) as Node3D
	var player: PlayerRoot = PlayerWorld.spawn_player(root, Vector3.ZERO)
	var item: Throwable = _spawn_item(root, Vector3(0.0, 1.65, -1.0))
	await wait_physics_frames(SETTLE_FRAMES)
	assert_true(player.get_hold().try_pick(item), "a mão livre pega o objeto")
	assert_false(player.get_hold().try_pick(item), "a mão já cheia não pega outro")
	await wait_physics_frames(1)
	# A mão fica a 0,7 m à frente da câmera e 0,25 m abaixo dela: o bloco ocupa esse ponto.
	PlayerWorld.add_box(root, Vector3(0.0, 1.4, -0.7), Vector3(0.6, 0.6, 0.6), &"wood")
	await wait_physics_frames(2)
	assert_false(player.get_hold().drop_held(), "dentro de uma parede não solta: continua segurando")
	assert_true(item.is_held(), "segue na mão")


func test_cooldown_e_velocidade_minima_do_ruido() -> void:
	var root: Node3D = add_child_autofree(Node3D.new()) as Node3D
	var world: AcousticWorld = AcousticWorld.new()
	root.add_child(world)
	world.noise_resolved_for_player.connect(_on_resolved)
	var item: Throwable = _spawn_item(root, Vector3(0.0, 1.0, 0.0))
	await wait_physics_frames(SETTLE_FRAMES)
	item._speed_before_step = 0.3
	item._on_body_entered(null)
	assert_eq(world.pending_count(), 0, "0,3 m/s: sem ruído")
	item._speed_before_step = 5.0
	item._on_body_entered(null)
	assert_eq(world.pending_count(), 1, "o primeiro impacto faz ruído")
	item._on_body_entered(null)
	assert_eq(world.pending_count(), 1, "o segundo impacto no mesmo instante não faz ruído (cooldown)")
	item._physics_process(0.3)
	item._speed_before_step = 5.0
	item._on_body_entered(null)
	assert_eq(world.pending_count(), 2, "depois de 0,3 s, o impacto faz ruído de novo")

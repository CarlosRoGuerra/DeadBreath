extends TestCase
## Revisão F4-010, R4-07: reset_to (CheckpointManager, F5) descarta os sons que o HearingSensor recebeu antes do reset;
## o cérebro novo não reage a ruído de uma vida anterior. Autor: Director (correção da revisão).

const OBSERVER_SCENE: PackedScene = preload("res://content/enemies/observer.tscn")


func test_reset_descarta_os_sons_pendentes() -> void:
	var root: Node3D = add_child_autofree(Node3D.new()) as Node3D
	var observer: EnemyController = OBSERVER_SCENE.instantiate() as EnemyController
	root.add_child(observer)
	await wait_physics_frames(1)
	var sensor: HearingSensor = observer.get_node("HearingSensor") as HearingSensor
	var heard: HeardNoise = HeardNoise.new()
	heard.category = Enums.NoiseCategory.FOOTSTEP
	heard.perceived_db = 40.0
	heard.effective_threshold_db = 15.0
	sensor.receive(heard)
	sensor.receive(heard)
	var initial: EnemyInitialState = EnemyInitialState.new()
	initial.spawn_position = Vector3(1.0, 0.0, 1.0)
	observer.reset_to(initial)
	assert_eq(sensor.drain().size(), 0, "o reset descartou os sons pendentes")
	assert_true(observer.global_position.is_equal_approx(Vector3(1.0, 0.0, 1.0)), "volta ao ponto inicial")

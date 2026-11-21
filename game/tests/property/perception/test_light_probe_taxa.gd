extends TestCase
## F3-005 (property): a taxa de amostragem do LightExposureProbe segue update_hz (10 Hz e 2 Hz), com 60 ticks/s fixos.
## Autor: Gameplay Engineer.

const WINDOW_FRAMES: int = 60  ## 1 s de física


func _probe(world: Node3D, hz: float) -> LightExposureProbe:
	var holder: Node3D = Node3D.new()
	holder.position = Vector3(0.0, 1.0, float(hz) * 0.01)
	world.add_child(holder)
	var probe: LightExposureProbe = LightExposureProbe.new()
	probe.update_hz = hz
	holder.add_child(probe)
	return probe


func test_taxa_de_amostragem_segue_update_hz() -> void:
	var world: Node3D = add_isolated_world()
	var fast: LightExposureProbe = _probe(world, 10.0)
	var slow: LightExposureProbe = _probe(world, 2.0)
	await wait_physics_frames(WINDOW_FRAMES)
	assert_true(fast.get_sample_count() >= 9 and fast.get_sample_count() <= 11, "10 Hz: cerca de 10 amostras por segundo (%d)" % fast.get_sample_count())
	assert_true(slow.get_sample_count() >= 1 and slow.get_sample_count() <= 3, "2 Hz: cerca de 2 amostras por segundo (%d)" % slow.get_sample_count())
	assert_true(fast.get_sample_count() > slow.get_sample_count(), "o probe mais rápido amostra mais")

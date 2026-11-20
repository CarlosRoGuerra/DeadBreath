extends TestCase
## F2-006b (COMPONENT_CONTRACTS §6.4, DATA_STRUCTURES §2.2): propagação provisória só por distância.
## Perda = 20·log10(max(d, 1)) + 0.1·d. Invariante NOI-INV-3: função pura e determinística; mais longe nunca soa mais alto.
## Autor: Audio Engineer (F2-006b).

const TOL: float = 0.0001


func _event(intensity_db: float, at: Vector3) -> NoiseEvent:
	return NoiseEvent.create(Enums.NoiseCategory.BREATHING, at, intensity_db, 2.0, &"player", &"breath_calm")


func test_loss_at_known_distances() -> void:
	assert_almost_eq(AcousticPropagation.distance_loss_db(0.5), 0.05, TOL, "d < 1 m: sem perda logarítmica, só 0,1·d")
	assert_almost_eq(AcousticPropagation.distance_loss_db(1.0), 0.1, TOL, "1 m: 0 + 0,1")
	assert_almost_eq(AcousticPropagation.distance_loss_db(10.0), 21.0, TOL, "10 m: 20 + 1")
	assert_almost_eq(AcousticPropagation.distance_loss_db(100.0), 50.0, TOL, "100 m: 40 + 10")


func test_perceived_drops_with_distance() -> void:
	var event: NoiseEvent = _event(40.0, Vector3.ZERO)
	var near: PropagationResult = AcousticPropagation.perceive(event, Vector3(0.0, 0.0, 2.0))
	var far: PropagationResult = AcousticPropagation.perceive(event, Vector3(0.0, 0.0, 10.0))
	assert_almost_eq(far.perceived_db, 40.0 - 21.0, TOL, "40 dB a 10 m = 19 dB")
	assert_true(near.perceived_db > far.perceived_db, "mais perto soa mais alto")


func test_perceive_is_deterministic_and_does_not_mutate_event() -> void:
	var event: NoiseEvent = _event(35.0, Vector3(1.0, 0.0, 0.0))
	var listener: Vector3 = Vector3(4.0, 0.0, 3.0)
	var first: PropagationResult = AcousticPropagation.perceive(event, listener)
	var second: PropagationResult = AcousticPropagation.perceive(event, listener)
	assert_almost_eq(first.perceived_db, second.perceived_db, TOL, "mesmo evento e ouvinte, mesmo resultado (NOI-INV-3)")
	assert_eq(event.intensity_db, 35.0, "o evento não é alterado")
	assert_eq(event.position, Vector3(1.0, 0.0, 0.0), "a posição do evento não é alterada")


func test_direct_path_entry_point_is_source() -> void:
	var event: NoiseEvent = _event(30.0, Vector3(2.0, 1.0, 0.0))
	var result: PropagationResult = AcousticPropagation.perceive(event, Vector3(2.0, 1.0, 5.0))
	assert_eq(result.entry_point, Vector3(2.0, 1.0, 0.0), "caminho direto: entry_point é a fonte (DATA §2)")
	assert_true(result.path_portals.is_empty(), "sem portais na F2")
	assert_false(result.through_wall, "sem paredes na F2")

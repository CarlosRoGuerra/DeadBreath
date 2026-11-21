extends TestCase
## Revisão F3-010, R3-01 (DATA §2, decisão D-07): HeardNoise.from_propagation. A posição estimada parte do entry_point
## (nunca da posição real), cai num disco horizontal de raio 0,05 m por dB perdido, uniforme na área; a confiança é
## clamp((perceived − limiar)/20; 0,1; 1). Determinística pela semente. Autor: Director (correção da revisão).

const CONFIG: AcousticConfig = preload("res://content/data/acoustics/acoustic_config.tres")
const SAMPLES: int = 2000
const TOL: float = 0.0001
const ENTRY: Vector3 = Vector3(4.0, 1.2, -3.0)
const SOURCE: Vector3 = Vector3(-6.0, 1.0, 5.0)


func _pair(intensity_db: float, perceived_db: float) -> Array:
	var event: NoiseEvent = NoiseEvent.create(Enums.NoiseCategory.DOOR, SOURCE, intensity_db, 0.0, &"enemy_test", &"door_normal")
	event.timestamp = 12.5
	var result: PropagationResult = PropagationResult.new()
	result.perceived_db = perceived_db
	result.entry_point = ENTRY
	return [event, result]


func test_confianca_pelo_excesso_sobre_o_limiar() -> void:
	assert_almost_eq(HeardNoise.confidence_for(30.0, 30.0), 0.1, TOL, "no limiar: mínimo 0,1")
	assert_almost_eq(HeardNoise.confidence_for(40.0, 30.0), 0.5, TOL, "10 dB acima: 0,5")
	assert_almost_eq(HeardNoise.confidence_for(50.0, 30.0), 1.0, TOL, "20 dB acima: 1")
	assert_almost_eq(HeardNoise.confidence_for(80.0, 30.0), 1.0, TOL, "nunca acima de 1")


func test_campos_copiados_e_posicao_parte_do_entry_point() -> void:
	var pair: Array = _pair(60.0, 40.0)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 7
	var heard: HeardNoise = HeardNoise.from_propagation(pair[0], pair[1], 30.0, CONFIG, rng)
	assert_eq(heard.category, Enums.NoiseCategory.DOOR, "categoria")
	assert_almost_eq(heard.perceived_db, 40.0, TOL, "nível percebido")
	assert_almost_eq(heard.timestamp, 12.5, TOL, "timestamp do evento")
	assert_almost_eq(heard.confidence, 0.5, TOL, "confiança (40 − 30)/20")
	var radius: float = CONFIG.position_error_per_db_lost * 20.0
	assert_true(heard.estimated_position.distance_to(ENTRY) <= radius + TOL, "dentro do disco em volta do entry_point")
	assert_true(heard.estimated_position.distance_to(SOURCE) > 5.0, "longe da posição real da fonte")


func test_disco_horizontal_uniforme_na_area() -> void:
	var pair: Array = _pair(70.0, 50.0)
	var radius: float = CONFIG.position_error_per_db_lost * 20.0
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 2026
	var inner: int = 0
	var sum: Vector3 = Vector3.ZERO
	var max_distance: float = 0.0
	var max_dy: float = 0.0
	for index: int in range(SAMPLES):
		var heard: HeardNoise = HeardNoise.from_propagation(pair[0], pair[1], 30.0, CONFIG, rng)
		var offset: Vector3 = heard.estimated_position - ENTRY
		max_dy = maxf(max_dy, absf(offset.y))
		var planar: float = Vector2(offset.x, offset.z).length()
		max_distance = maxf(max_distance, planar)
		if planar < radius / sqrt(2.0):
			inner += 1
		sum += offset
	var mean: Vector3 = sum / float(SAMPLES)
	note("raio %.2f m: máximo %.3f; fração no disco interno %.3f; média (%.3f, %.3f)" % [radius, max_distance,
		float(inner) / float(SAMPLES), mean.x, mean.z])
	assert_almost_eq(max_dy, 0.0, TOL, "o desvio é só horizontal (mesmo Y do entry_point)")
	assert_true(max_distance <= radius + TOL, "nenhum ponto fora do raio")
	assert_true(max_distance > radius * 0.95, "o disco é ocupado até a borda")
	var fraction: float = float(inner) / float(SAMPLES)
	assert_true(fraction > 0.45 and fraction < 0.55, "uniforme na área: metade dentro de R/√2 (%.3f)" % fraction)
	assert_true(Vector2(mean.x, mean.z).length() < radius * 0.06, "centrado no entry_point")


func test_sem_perda_sem_erro_e_mesma_semente_mesmo_ponto() -> void:
	var exact: Array = _pair(40.0, 40.0)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 3
	var heard: HeardNoise = HeardNoise.from_propagation(exact[0], exact[1], 30.0, CONFIG, rng)
	assert_true(heard.estimated_position.is_equal_approx(ENTRY), "0 dB perdidos: exatamente o entry_point")
	var pair: Array = _pair(65.0, 35.0)
	var first_rng: RandomNumberGenerator = RandomNumberGenerator.new()
	first_rng.seed = 99
	var second_rng: RandomNumberGenerator = RandomNumberGenerator.new()
	second_rng.seed = 99
	var first: HeardNoise = HeardNoise.from_propagation(pair[0], pair[1], 30.0, CONFIG, first_rng)
	var second: HeardNoise = HeardNoise.from_propagation(pair[0], pair[1], 30.0, CONFIG, second_rng)
	assert_true(first.estimated_position.is_equal_approx(second.estimated_position), "mesma semente, mesmo ponto")

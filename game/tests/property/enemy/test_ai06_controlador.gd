extends TestCase
## F4-004 (AI-06 no controlador; ENM-INV-2 e FW-INV-1; TEST_PLAN §2.5): 50 pares de execuções com a mesma semente de
## RNG do inimigo, o mesmo percurso de patrulha e o jogador em posições diferentes, ambas fora de visão (além do alcance
## de 16 m) e silenciosas. O EnemyIntent tem de ser idêntico em todos os ticks. Mundo de teste com navmesh (EnemyTestWorld):
## a navegação é a mesma nas duas execuções, então qualquer diferença viria do jogador. Autor: AI Engineer (F4-004).

const Fx := preload("res://tests/integration/enemy/fixtures/enemy_test_world.gd")
const PAIRS: int = 50
const TICKS: int = 150
const SETTLE_FRAMES: int = 3
const MAX_SETTLE_FRAMES: int = 60
## Alcance do Observer (16 m) mais a folga do percurso (até 5,7 m da origem): o alvo nunca entra em alcance.
const NEAR_M: float = 23.0
const FAR_M: float = 30.0
const BASE_SEED: int = 1000
## Percurso dentro de 6 m da origem: o inimigo nunca se aproxima de um alvo a 17 m ou mais.
const ROUTE_HALF_M: float = 4.0
const OBSERVER_SCENE_PATH: String = "res://content/enemies/observer.tscn"


## Uma execução: o Observer com a semente dada, o jogador (PerceivableTarget iluminado) em `player_at`. Devolve os intents
## dos ticks e se algum percept visual ou sonoro apareceu no lote (deveria ser nunca).
func _run(brain_seed: int, player_at: Vector3) -> Dictionary:
	var world: Node3D = add_isolated_world()
	Fx.navigation_floor(world, 40.0)
	var route: PackedVector3Array = PackedVector3Array([Vector3(-ROUTE_HALF_M, 0.0, -ROUTE_HALF_M),
		Vector3(ROUTE_HALF_M, 0.0, -ROUTE_HALF_M), Vector3(ROUTE_HALF_M, 0.0, ROUTE_HALF_M),
		Vector3(-ROUTE_HALF_M, 0.0, ROUTE_HALF_M)])
	Fx.add_route(world, &"observer", route)
	Fx.add_target(world, player_at, true)
	var enemy: EnemyController = (load(OBSERVER_SCENE_PATH) as PackedScene).instantiate() as EnemyController
	enemy.brain_seed = brain_seed
	world.add_child(enemy)
	await wait_physics_frames(SETTLE_FRAMES)
	# Grava só a partir do primeiro intent do cérebro (o tick só roda com a navmesh assentada): as duas execuções ficam
	# alinhadas tick a tick.
	var guard: int = 0
	while enemy.last_intent() == null and guard < MAX_SETTLE_FRAMES:
		await wait_physics_frames(1)
		guard += 1
	var intents: Array[EnemyIntent] = []
	var percepts_seen: bool = false
	for tick: int in range(TICKS):
		await wait_physics_frames(1)
		var batch: PerceptBatch = enemy.last_batch()
		if batch != null and (batch.visual.size() > 0 or batch.heard.size() > 0):
			percepts_seen = true
		intents.append(enemy.last_intent())
	var viewport: Node = world.get_parent()
	await release_and_flush(viewport)
	return {"intents": intents, "percepts": percepts_seen}


## Posição do jogador fora de visão: de NEAR_M a FAR_M da origem, direção sorteada.
func _far_position(rng: RandomNumberGenerator) -> Vector3:
	var angle: float = rng.randf() * TAU
	var distance: float = rng.randf_range(NEAR_M, FAR_M)
	return Vector3(cos(angle) * distance, 0.0, sin(angle) * distance)


## Índice do primeiro tick em que os dois intents diferem em algum campo; -1 se forem idênticos.
func _first_difference(a: Array[EnemyIntent], b: Array[EnemyIntent]) -> int:
	if a.size() != b.size():
		return 0
	for index: int in range(a.size()):
		var left: EnemyIntent = a[index]
		var right: EnemyIntent = b[index]
		if left == null or right == null:
			return index
		if left.move_target != right.move_target or left.move_speed != right.move_speed \
				or left.look_target != right.look_target or left.inspect_hideable != right.inspect_hideable \
				or left.voice_line != right.voice_line:
			return index
	return -1


func test_ai06_cinquenta_pares_fora_de_visao_dao_intent_identico() -> void:
	var placer: RandomNumberGenerator = RandomNumberGenerator.new()
	placer.seed = BASE_SEED
	var differing_pairs: int = 0
	var seen_percepts: int = 0
	var distinct_positions: int = 0
	for pair: int in range(PAIRS):
		var seed_value: int = BASE_SEED + pair
		var position_a: Vector3 = _far_position(placer)
		var position_b: Vector3 = _far_position(placer)
		if not position_a.is_equal_approx(position_b):
			distinct_positions += 1
		var run_a: Dictionary = await _run(seed_value, position_a)
		var run_b: Dictionary = await _run(seed_value, position_b)
		if run_a["percepts"] or run_b["percepts"]:
			seen_percepts += 1
		var intents_a: Array[EnemyIntent] = run_a["intents"]
		var intents_b: Array[EnemyIntent] = run_b["intents"]
		var difference: int = _first_difference(intents_a, intents_b)
		if difference >= 0:
			differing_pairs += 1
			note("par %d (semente %d) difere no tick %d" % [pair, seed_value, difference])
	assert_eq(seen_percepts, 0, "AI-06: nenhum percept visual ou sonoro em nenhuma das execuções")
	assert_eq(distinct_positions, PAIRS, "cada par usa posições diferentes do jogador")
	assert_eq(differing_pairs, 0, "AI-06: os %d pares dão EnemyIntent idêntico em todos os ticks" % PAIRS)


func test_controle_positivo_jogador_visivel_muda_o_intent() -> void:
	# Controle: o mesmo harness, com o jogador a 8 m e no FOV (visível), tem de dar intents diferentes. Assim, a igualdade
	# do teste acima não é vacuosa: o comparador enxerga diferença quando ela existe.
	var seed_value: int = BASE_SEED
	var seen: Dictionary = await _run(seed_value, Vector3(0.0, 0.0, -8.0))
	var hidden: Dictionary = await _run(seed_value, Vector3(0.0, 0.0, 30.0))
	assert_true(seen["percepts"], "controle: com o jogador visível há percept")
	var difference: int = _first_difference(seen["intents"], hidden["intents"])
	assert_true(difference >= 0, "controle: com o jogador visível o intent difere (primeiro tick %d)" % difference)

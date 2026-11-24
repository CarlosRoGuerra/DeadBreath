class_name AITestSupport
extends RefCounted
## Apoio aos testes de sim/ai (F4-003): RNG com semente, lotes de percepts e um passo de movimento.
## Só dado de teste; não é usado pela produção.


static func rng(seed_value: int) -> RandomNumberGenerator:
	var generator: RandomNumberGenerator = RandomNumberGenerator.new()
	generator.seed = seed_value
	return generator


static func empty_batch() -> PerceptBatch:
	return PerceptBatch.new()


## Lote com um percept visual de visibilidade visibility na posição at.
static func sight(visibility: float, at: Vector3, time_s: float) -> PerceptBatch:
	var batch: PerceptBatch = PerceptBatch.new()
	batch.visual.append(VisualPercept.create(visibility, at, time_s))
	return batch


## Anda de `from` até `to` no plano, no máximo speed * dt. Simula o NavigationAgent3D nos testes.
static func move_towards(from: Vector3, to: Vector3, speed: float, dt: float) -> Vector3:
	var delta: Vector3 = to - from
	delta.y = 0.0
	var distance: float = delta.length()
	var step: float = speed * dt
	if distance <= step or distance == 0.0:
		return Vector3(to.x, from.y, to.z)
	var moved: Vector3 = from + delta * (step / distance)
	return moved


static func horizontal_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


## Mundo com uma rota de patrulha longe da origem (a rota não é alcançada nos cenários de percepção).
static func world_with_route() -> FakeBrainWorld:
	var world: FakeBrainWorld = FakeBrainWorld.new()
	world.route = PackedVector3Array([Vector3(0.0, 0.0, -20.0), Vector3(0.0, 0.0, -40.0)])
	return world


## PATROL → SUSPICIOUS → INVESTIGATE no mesmo tick (visibilidade 1,0, dt 0,5: suspeita 1,6·1,0·0,5 = 0,8).
## Confirmação fica em 0,5 (< 0,6). O inimigo continua parado na origem, longe da pista.
static func drive_to_investigate(brain: EnemyBrain, world: FakeBrainWorld, lead: Vector3) -> void:
	brain.tick(0.5, sight(1.0, lead, 0.5), world)


## Leva a SEARCH: INVESTIGATE, inimigo parado na pista e 3 s sem visão (três ticks de 1,0 s depois da entrada).
static func drive_to_search(brain: EnemyBrain, world: FakeBrainWorld, lead: Vector3) -> void:
	drive_to_investigate(brain, world, lead)
	world.position = lead
	for _index: int in range(3):
		brain.tick(1.0, empty_batch(), world)


## Leva a RETURN: SEARCH e depois 60 s sem pista nova (ticks de 1,0 s).
static func drive_to_return(brain: EnemyBrain, world: FakeBrainWorld, lead: Vector3) -> void:
	drive_to_search(brain, world, lead)
	for _index: int in range(60):
		brain.tick(1.0, empty_batch(), world)


## Um episódio de AI-06: o cérebro roda `ticks` ticks de 1/60 s e devolve os intents. O inimigo anda até cada
## move_target (passo simples, sem navegação). Percepts:
##   mode 0 = o jogador só entra no percept se estiver dentro de sight_range_m (DATA §3.2, filtro de alcance);
##            com o jogador além do alcance, o lote fica vazio: fora de visão e silencioso.
##   mode 1 = percepts visuais sorteados com percept_seed. Não dependem do jogador: são iguais em qualquer execução.
##   mode 2 = como o mode 1, mais ruídos sorteados (HeardNoise com limiar efetivo 15 dB, alguns abaixo do limiar).
## O jogador (player_at) só existe aqui no teste: o cérebro nunca o recebe (FW-INV-1).
static func run_episode(brain_seed: int, percept_seed: int, ticks: int, mode: int, player_at: Vector3) -> Array[EnemyIntent]:
	var world: FakeBrainWorld = world_with_route()
	world.search_candidates = PackedVector3Array([Vector3(15.0, 0.0, 0.0), Vector3(16.0, 0.0, 0.0), Vector3(15.0, 0.0, 1.0)])
	world.hideables = [HideableInfo.create(&"hide_a", Vector3(15.5, 0.0, 0.0))]
	var profile: AIProfile = AIProfile.new()
	var brain: EnemyBrain = EnemyBrain.new(profile, rng(brain_seed))
	var percept_rng: RandomNumberGenerator = rng(percept_seed)
	var intents: Array[EnemyIntent] = []
	for index: int in range(ticks):
		var time_s: float = float(index) / 60.0
		var batch: PerceptBatch = empty_batch()
		if mode == 0:
			if horizontal_distance(world.position, player_at) <= profile.sight_range_m:
				batch = sight(0.5, player_at, time_s)
		else:
			if percept_rng.randf() < 0.1:
				var seen_at: Vector3 = Vector3(percept_rng.randf_range(-20.0, 20.0), 0.0, percept_rng.randf_range(-20.0, 20.0))
				batch.visual.append(VisualPercept.create(percept_rng.randf(), seen_at, time_s))
			if mode == 2 and percept_rng.randf() < 0.1:
				var noise: HeardNoise = HeardNoise.new()
				noise.perceived_db = percept_rng.randf_range(5.0, 45.0)
				noise.effective_threshold_db = 15.0
				noise.confidence = percept_rng.randf()
				noise.estimated_position = Vector3(percept_rng.randf_range(-20.0, 20.0), 0.0, percept_rng.randf_range(-20.0, 20.0))
				noise.timestamp = time_s
				batch.heard.append(noise)
		var intent: EnemyIntent = brain.tick(1.0 / 60.0, batch, world)
		intents.append(intent)
		world.position = move_towards(world.position, intent.move_target, intent.move_speed, 1.0 / 60.0)
	return intents


## Índice do primeiro tick em que os dois episódios diferem, ou -1 se forem idênticos em todos os campos do intent.
static func first_difference(a: Array[EnemyIntent], b: Array[EnemyIntent]) -> int:
	if a.size() != b.size():
		return 0
	for index: int in range(a.size()):
		var left: EnemyIntent = a[index]
		var right: EnemyIntent = b[index]
		if left.move_target != right.move_target or left.move_speed != right.move_speed \
				or left.look_target != right.look_target or left.inspect_hideable != right.inspect_hideable \
				or left.voice_line != right.voice_line:
			return index
	return -1


## Leva a CHASE (confirmação 0,5 + 0,2 = 0,7 ≥ 0,6) e depois a LOST_CONTACT (1,5 s sem visão, ticks de 0,1 s).
## O inimigo não se move: quem chega ou não chega à última posição é o teste.
static func drive_to_lost(brain: EnemyBrain, world: FakeBrainWorld, seen: Vector3) -> void:
	drive_to_investigate(brain, world, seen)
	brain.tick(0.2, sight(1.0, seen, 0.7), world)
	var guard: int = 0
	while brain.state != Enums.EnemyState.LOST_CONTACT and guard < 40:
		brain.tick(0.1, empty_batch(), world)
		guard += 1

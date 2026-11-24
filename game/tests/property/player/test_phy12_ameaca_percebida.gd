extends TestCase
## PHY-12 (TEST_PLAN §2, F4-006b; DATA §1.5 e §1.3): ameaça real alimenta o estresse. Cenários de propriedade (nível
## property, 60 ticks por segundo):
##   - inimigo visto a 3 m, no campo de visão e com linha de visão: estresse sobe 10 ou mais em 1 s;
##   - inimigo só audível (corrida de 30 dB ou mais percebidos, fonte enemy_*): estresse sobe;
##   - inimigo fora de percepção (atrás de parede, fora do campo de visão, silencioso, escuro além de 3 m): não sobe;
##   - a perseguição do grito vale 3 s (janela de DATA §6.1).
## Autor: Gameplay Engineer (F4-006b).

const PlayerWorld := preload("res://tests/integration/player/fixtures/player_world.gd")
const ThreatWorld := preload("res://tests/integration/player/fixtures/threat_world.gd")
const SETTLE_FRAMES: int = 6
const ONE_SECOND_FRAMES: int = 60
const EYE_LEVEL_Y: float = ThreatWorld.ENEMY_ORIGIN_EYE_LEVEL_Y
const MIN_PERCEIVED_DB: float = 30.0
const SILENT_TOLERANCE: float = 0.01


func before_all() -> void:
	Settings.autosave = false


func after_all() -> void:
	Settings.autosave = true


## Mundo isolado com acústica, piso e jogador na origem (olhando para -Z).
func _setup(root: Node3D) -> Dictionary:
	var world: AcousticWorld = AcousticWorld.new()
	root.add_child(world)
	ThreatWorld.add_floor(root)
	var player: PlayerRoot = PlayerWorld.spawn_player(root, Vector3.ZERO)
	return {"world": world, "player": player}


func _stress(player: PlayerRoot) -> float:
	return player.get_physiology().get_snapshot().stress


func test_inimigo_visto_a_3_m_sobe_o_estresse_em_10_em_1_s() -> void:
	var root: Node3D = add_isolated_world()
	var parts: Dictionary = _setup(root)
	var player: PlayerRoot = parts["player"] as PlayerRoot
	ThreatWorld.make_enemy(root, Vector3(0.0, EYE_LEVEL_Y, -3.0))
	await wait_physics_frames(SETTLE_FRAMES)
	var before: float = _stress(player)
	await wait_physics_frames(ONE_SECOND_FRAMES)
	var gain: float = _stress(player) - before
	var sample: ThreatSample = player.get_threat_source().sample()
	note("visto a 3 m: proximidade %.3f, estresse +%.3f em 1 s" % [sample.seen_proximity, gain])
	assert_true(sample.seen_proximity > 0.99, "o inimigo a 3 m é visto com proximidade 1 (%.3f)" % sample.seen_proximity)
	assert_true(gain >= 10.0, "visto a 3 m: o estresse sobe 10 ou mais em 1 s (+%.2f)" % gain)


func test_inimigo_so_audivel_com_passos_de_corrida_sobe_o_estresse() -> void:
	var root: Node3D = add_isolated_world()
	var parts: Dictionary = _setup(root)
	var world: AcousticWorld = parts["world"] as AcousticWorld
	var player: PlayerRoot = parts["player"] as PlayerRoot
	var body: CharacterBody3D = ThreatWorld.make_enemy(root, Vector3(0.0, EYE_LEVEL_Y, 4.0))
	var perceived: Array[float] = []
	var on_resolved: Callable = func(event: NoiseEvent, result: PropagationResult) -> void:
		if event.source_id == ThreatWorld.ENEMY_SOURCE:
			perceived.append(result.perceived_db)
	world.noise_resolved_for_player.connect(on_resolved)
	await wait_physics_frames(SETTLE_FRAMES)
	var before: float = _stress(player)
	ThreatWorld.emitter_of(body).emit_noise(Enums.NoiseCategory.RUNNING, 50.0, 0.0, &"footstep_wood")
	await wait_physics_frames(ONE_SECOND_FRAMES)
	world.noise_resolved_for_player.disconnect(on_resolved)
	var gain: float = _stress(player) - before
	var sample: ThreatSample = player.get_threat_source().sample()
	assert_true(perceived.size() == 1, "pré-condição: um passo de corrida do inimigo resolvido (%d)" % perceived.size())
	if perceived.size() >= 1:
		note("corrida de inimigo: %.1f dB percebidos" % perceived[0])
		assert_true(perceived[0] >= MIN_PERCEIVED_DB, "pré-condição: 30 dB ou mais percebidos (%.1f)" % perceived[0])
	assert_eq(sample.seen_proximity, 0.0, "atrás do jogador, o inimigo não é visto")
	assert_true(sample.in_chase, "corrida de inimigo ouvida vale perseguição")
	assert_true(gain > 0.0, "só audível (corrida), o estresse sobe (+%.2f em 1 s)" % gain)


## Fator de audição isolado: um passo de inimigo a 30 dB ou mais percebidos sobe o estresse sem perseguição.
func test_passo_de_inimigo_audivel_sobe_so_pelo_fator_de_audicao() -> void:
	var root: Node3D = add_isolated_world()
	var parts: Dictionary = _setup(root)
	var world: AcousticWorld = parts["world"] as AcousticWorld
	var player: PlayerRoot = parts["player"] as PlayerRoot
	var body: CharacterBody3D = ThreatWorld.make_enemy(root, Vector3(0.0, EYE_LEVEL_Y, 4.0))
	await wait_physics_frames(SETTLE_FRAMES)
	var before: float = _stress(player)
	ThreatWorld.emitter_of(body).emit_noise(Enums.NoiseCategory.FOOTSTEP, 50.0, 0.0, &"footstep_wood")
	await wait_physics_frames(ONE_SECOND_FRAMES)
	var sample: ThreatSample = player.get_threat_source().sample()
	var gain: float = _stress(player) - before
	assert_true(sample.heard_factor > 0.0, "o passo de inimigo entra no fator de audição (%.3f)" % sample.heard_factor)
	assert_false(sample.in_chase, "passo comum não é perseguição")
	assert_true(gain > 0.0, "o estresse sobe pelo fator de audição (+%.2f em 1 s)" % gain)


func test_inimigo_atras_de_parede_nao_sobe_o_estresse() -> void:
	var root: Node3D = add_isolated_world()
	var parts: Dictionary = _setup(root)
	var player: PlayerRoot = parts["player"] as PlayerRoot
	PlayerWorld.add_box(root, Vector3(0.0, 1.5, -1.5), Vector3(4.0, 3.0, 0.3))
	ThreatWorld.make_enemy(root, Vector3(0.0, EYE_LEVEL_Y, -3.0))
	await wait_physics_frames(SETTLE_FRAMES)
	var before: float = _stress(player)
	await wait_physics_frames(ONE_SECOND_FRAMES)
	var sample: ThreatSample = player.get_threat_source().sample()
	assert_eq(sample.seen_proximity, 0.0, "atrás de parede, o inimigo não é visto")
	assert_almost_eq(_stress(player), before, SILENT_TOLERANCE, "atrás de parede e em silêncio, o estresse não sobe")


func test_inimigo_fora_do_campo_de_visao_nao_sobe_o_estresse() -> void:
	var root: Node3D = add_isolated_world()
	var parts: Dictionary = _setup(root)
	var player: PlayerRoot = parts["player"] as PlayerRoot
	ThreatWorld.make_enemy(root, Vector3(2.0, EYE_LEVEL_Y, -0.5))
	await wait_physics_frames(SETTLE_FRAMES)
	var before: float = _stress(player)
	await wait_physics_frames(ONE_SECOND_FRAMES)
	var sample: ThreatSample = player.get_threat_source().sample()
	assert_eq(sample.seen_proximity, 0.0, "fora do campo de visão, o inimigo não é visto")
	assert_almost_eq(_stress(player), before, SILENT_TOLERANCE, "fora do campo de visão e em silêncio, o estresse não sobe")


func test_inimigo_silencioso_e_distante_nao_sobe_o_estresse() -> void:
	var root: Node3D = add_isolated_world()
	var parts: Dictionary = _setup(root)
	var player: PlayerRoot = parts["player"] as PlayerRoot
	ThreatWorld.make_enemy(root, Vector3(0.0, EYE_LEVEL_Y, -20.0))
	await wait_physics_frames(SETTLE_FRAMES)
	var before: float = _stress(player)
	await wait_physics_frames(ONE_SECOND_FRAMES)
	var sample: ThreatSample = player.get_threat_source().sample()
	assert_eq(sample.seen_proximity, 0.0, "a 20 m, além do alcance da fórmula (15 m), o inimigo não é visto")
	assert_almost_eq(_stress(player), before, SILENT_TOLERANCE, "distante e em silêncio, o estresse não sobe")


## COMPONENT §5: sem luz sobre o inimigo (exposição < 0,15) e além de 3 m, ele não é visto, mesmo em frente.
func test_inimigo_escuro_alem_de_3_m_nao_e_visto() -> void:
	var root: Node3D = add_isolated_world()
	var parts: Dictionary = _setup(root)
	var player: PlayerRoot = parts["player"] as PlayerRoot
	ThreatWorld.make_enemy(root, Vector3(0.0, EYE_LEVEL_Y, -6.0))
	await wait_physics_frames(SETTLE_FRAMES)
	var before: float = _stress(player)
	await wait_physics_frames(ONE_SECOND_FRAMES)
	var sample: ThreatSample = player.get_threat_source().sample()
	assert_eq(sample.seen_proximity, 0.0, "no escuro, a 6 m, o inimigo não é visto")
	assert_almost_eq(_stress(player), before, SILENT_TOLERANCE, "no escuro, a 6 m e em silêncio, o estresse não sobe")


## DATA §6.1: o grito de perseguição vale 3 s a partir do último som ouvido.
func test_grito_de_perseguicao_vale_por_3_s() -> void:
	var root: Node3D = add_isolated_world()
	var parts: Dictionary = _setup(root)
	var world: AcousticWorld = parts["world"] as AcousticWorld
	var player: PlayerRoot = parts["player"] as PlayerRoot
	var body: CharacterBody3D = ThreatWorld.make_enemy(root, Vector3(0.0, EYE_LEVEL_Y, 4.0))
	await wait_physics_frames(SETTLE_FRAMES)
	ThreatWorld.emitter_of(body).emit_noise(Enums.NoiseCategory.VOICE, 80.0, 0.0, &"voice_chase_shout")
	await wait_physics_frames(ONE_SECOND_FRAMES)
	assert_true(player.get_threat_source().sample().in_chase, "1 s depois do grito, a perseguição está ativa")
	await wait_physics_frames(90)
	assert_true(player.get_threat_source().sample().in_chase, "2,5 s depois do grito, a perseguição ainda está ativa")
	await wait_physics_frames(60)
	assert_false(player.get_threat_source().sample().in_chase, "3,5 s depois do grito, a perseguição já acabou")
	assert_true(world.pending_count() == 0, "a fila do mundo foi resolvida")


## Inimigo visto em CHASE (get_state, COMPONENT §8.1): a perseguição segue 3 s depois que ele sai de CHASE.
func test_visto_em_chase_vale_3_s_depois_de_sair_da_perseguicao() -> void:
	var root: Node3D = add_isolated_world()
	var parts: Dictionary = _setup(root)
	var player: PlayerRoot = parts["player"] as PlayerRoot
	var body: CharacterBody3D = ThreatWorld.make_enemy(root, Vector3(0.0, EYE_LEVEL_Y, -3.0))
	body.set_script(preload("res://tests/integration/player/fixtures/fake_chasing_enemy.gd"))
	await wait_physics_frames(SETTLE_FRAMES)
	assert_true(player.get_threat_source().sample().in_chase, "em CHASE e visto, perseguição ativa")
	body.set(&"state", Enums.EnemyState.PATROL)
	await wait_physics_frames(90)
	assert_true(player.get_threat_source().sample().in_chase, "1,5 s depois de sair de CHASE, ainda em perseguição")
	await wait_physics_frames(150)
	assert_false(player.get_threat_source().sample().in_chase, "4 s depois de sair de CHASE, a perseguição acabou")

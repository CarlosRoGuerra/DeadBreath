extends TestCase
## F2-011 (QA Engineer): exploits na crise, no sandbox_playable.tscn real. (1) Mudar opções de acessibilidade no meio
## da crise: a fisiologia não reseta e os efeitos mudam no quadro seguinte. (2) Spam de postura (agachar a cada quadro)
## contra um agachar único, medido como fração de quadros em repouso (is_resting, white-box via
## _build_physiology_inputs) e como queda da severidade. (3) Noclip na crise: ruído de passo e fisiologia.
## Escrito do zero pelo QA; usa o QaFixture de F1 só para instanciar a cena e achar o jogador.
##
## Nota de método: a queda da severidade em repouso fica limitada pelo alvo (esforço e estresse) quando a ameaça
## continua forçada; por isso a comparação decisiva é a fração de quadros em repouso, que é o que a postura controla.

const QaFixture := preload("res://tests/integration/qa/fixtures/qa_fixture.gd")
const PlayerWorld := preload("res://tests/integration/player/fixtures/player_world.gd")
const SETTLE_FRAMES: int = 12
const MAX_CRISIS_FRAMES: int = 1500
const EXTRA_FRAMES_AFTER_SYMPTOMATIC: int = 120
const REST_FRAMES: int = 180
const WALK_FRAMES: int = 120
## Cozinha de sandbox_playable.tscn (x 6..14, z -6..-1,4): a porta aberta fica em z -3,0. Corre-se em x entre as bordas.
const SPAWN: Vector3 = Vector3(9.0, 0.0, -4.5)
const WEST_BOUND_X: float = 7.2
const EAST_BOUND_X: float = 12.8

var _previous: Dictionary = {}
var _footsteps: int = 0


func before_all() -> void:
	Settings.autosave = false


func after_all() -> void:
	Settings.autosave = true


func before_each() -> void:
	_previous = PlayerWorld.override_settings({
		&"motion_reduction": 0.0, &"tremor_reduction": 0.0, &"effects_intensity": 1.0, &"respiratory_indicator": false,
	})
	_footsteps = 0


func after_each() -> void:
	PlayerWorld.restore_settings(_previous)


func test_mudar_acessibilidade_no_meio_da_crise_nao_reseta_e_vale_no_quadro_seguinte() -> void:
	var world: Node3D = add_isolated_world()
	var scene_root: Node = QaFixture.instantiate_scene(QaFixture.PLAYABLE_PATH, world)
	var player: PlayerRoot = QaFixture.find_player(scene_root)
	var camera_fx: CameraEffects = scene_root.get_node("CameraEffects") as CameraEffects
	await wait_physics_frames(SETTLE_FRAMES)
	_start_in_kitchen(player)
	var reached: bool = await _drive_to_symptomatic(player)
	assert_true(reached, "crise (SYMPTOMATIC) alcançada correndo sob ameaça")
	var before: PhysiologySnapshot = player.get_physiology().get_snapshot()
	var vignette_before: float = camera_fx.get_vignette_alpha()
	assert_true(vignette_before > 0.0, "com a intensidade em 1, a vinheta está ativa na crise (%.3f)" % vignette_before)
	Settings.set_value(&"effects_intensity", 0.0)
	Settings.set_value(&"motion_reduction", 1.0)
	Settings.set_value(&"tremor_reduction", 1.0)
	Settings.set_value(&"respiratory_indicator", true)
	await wait_physics_frames(2)
	var after: PhysiologySnapshot = player.get_physiology().get_snapshot()
	assert_almost_eq(after.stress, before.stress, 2.0, "mudar acessibilidade não zera nem altera o estresse")
	assert_true(after.respiratory_state != Enums.RespiratoryState.NORMAL,
		"o estado respiratório não volta a NORMAL por causa da troca de opção")
	assert_almost_eq(camera_fx.get_vignette_alpha(), 0.0, 0.0001, "intensidade 0: a vinheta cai a zero no quadro seguinte")
	assert_almost_eq(CameraEffects.tremor_amplitude_m(1.0, 1.0, 1.0), 0.0, 0.0001, "redução de tremor 1: amplitude zero")
	assert_almost_eq(CameraEffects.jolt_amplitude_deg(1.0, 1.0), 0.0, 0.0001, "redução de movimento 1: solavanco zero")
	var indicator: CanvasLayer = camera_fx.get_indicator()
	assert_not_null(indicator, "o indicador respiratório existe (criado por CameraEffects)")
	if indicator != null:
		assert_true(indicator.visible, "ligar o indicador na crise o mostra sem reiniciar")
	note("crise: estresse %.2f, severidade %.3f, vinheta %.3f -> %.3f" % [before.stress, before.symptom_severity, vignette_before, camera_fx.get_vignette_alpha()])
	release_and_flush(world)


func test_spam_de_postura_na_crise_nao_aumenta_o_repouso() -> void:
	var single: Dictionary = await _rest_probe(false)
	var spam: Dictionary = await _rest_probe(true)
	note("agachar uma vez: repouso em %.1f%% dos quadros, queda %.4f/s; a cada quadro: repouso em %.1f%%, queda %.4f/s" % [
		float(single["fracao"]) * 100.0, float(single["queda"]), float(spam["fracao"]) * 100.0, float(spam["queda"])])
	assert_true(float(single["fracao"]) > 0.95, "agachar uma vez: o repouso vale em (quase) todos os quadros")
	assert_true(float(spam["fracao"]) <= float(single["fracao"]),
		"agachar a cada quadro não aumenta a fração de repouso (spam não é atalho de recuperação)")


func test_noclip_na_crise_some_com_o_ruido_de_passo_e_a_fisiologia_segue() -> void:
	var world: Node3D = add_isolated_world()
	var scene_root: Node = QaFixture.instantiate_scene(QaFixture.PLAYABLE_PATH, world)
	var player: PlayerRoot = QaFixture.find_player(scene_root)
	await wait_physics_frames(SETTLE_FRAMES)
	_start_in_kitchen(player)
	player.get_motor().footstep.connect(_on_footstep)
	var reached: bool = await _drive_to_symptomatic(player)
	assert_true(reached, "crise alcançada antes do teste de noclip")
	await _walk(player, WALK_FRAMES)
	var footsteps_walking: int = _footsteps
	_footsteps = 0
	var stress_before: float = player.get_physiology().get_snapshot().stress
	player.set_noclip(true)
	await _walk(player, WALK_FRAMES)
	var footsteps_noclip: int = _footsteps
	var stress_after: float = player.get_physiology().get_snapshot().stress
	player.set_noclip(false)
	note("passos andando fora do noclip: %d; passos com noclip: %d; estresse %.2f -> %.2f" % [footsteps_walking, footsteps_noclip, stress_before, stress_after])
	assert_true(footsteps_walking > 0, "andando sem noclip o motor emite passos (ruído) — validade do teste")
	assert_eq(footsteps_noclip, 0, "com noclip não há passo, logo nenhum ruído de passo (atalho de debug)")
	assert_true(stress_after >= 0.0 and stress_after <= 100.0, "o estresse continua dentro de 0..100 com noclip")
	release_and_flush(world)


func _on_footstep(_surface: StringName, _gait: Enums.Gait, _stance: Enums.Stance) -> void:
	_footsteps += 1


func _start_in_kitchen(player: PlayerRoot) -> void:
	player.teleport_to(SPAWN)
	player.rotation.y = -PI / 2.0


## Vira o corpo ao chegar nas bordas da cozinha (o movimento é sempre para a frente do corpo).
func _turn_at_bounds(player: PlayerRoot) -> void:
	# Olhando para +X quando rotation.y = -PI/2 (a frente do corpo é -Z rotacionado).
	var facing_east: bool = absf(wrapf(player.rotation.y + PI / 2.0, -PI, PI)) < PI / 4.0
	if facing_east and player.global_position.x > EAST_BOUND_X:
		player.rotation.y += PI
	elif not facing_east and player.global_position.x < WEST_BOUND_X:
		player.rotation.y += PI


func _drive_to_symptomatic(player: PlayerRoot) -> bool:
	var sample: ThreatSample = ThreatSample.new()
	sample.seen_proximity = 1.0
	sample.in_chase = true
	sample.threat_level = 1.0
	var stub: StubThreatSource = StubThreatSource.new()
	stub.forced = sample
	player.set_threat_source(stub)
	var reached: bool = false
	var extra: int = 0
	for _i: int in MAX_CRISIS_FRAMES:
		_turn_at_bounds(player)
		player.get_motor().set_scripted_input(PlayerWorld.move_input(Vector2(0.0, 1.0), true))
		await wait_physics_frames(1)
		if not reached and player.get_physiology().get_snapshot().respiratory_state == Enums.RespiratoryState.SYMPTOMATIC:
			reached = true
		if reached:
			extra += 1
			if extra >= EXTRA_FRAMES_AFTER_SYMPTOMATIC:
				break
	player.get_motor().set_scripted_input(null)
	return reached


func _walk(player: PlayerRoot, frames: int) -> void:
	for _i: int in frames:
		_turn_at_bounds(player)
		player.get_motor().set_scripted_input(PlayerWorld.move_input(Vector2(0.0, 1.0), true))
		await wait_physics_frames(1)
	player.get_motor().set_scripted_input(null)


## Repouso na crise: agacha uma vez (spam = agacha a cada quadro) e fica parado. Mede a fração de quadros em que a
## fisiologia recebe is_resting (white-box: _build_physiology_inputs do PlayerRoot) e a queda da severidade por segundo.
func _rest_probe(spam: bool) -> Dictionary:
	var world: Node3D = add_isolated_world()
	var scene_root: Node = QaFixture.instantiate_scene(QaFixture.PLAYABLE_PATH, world)
	var player: PlayerRoot = QaFixture.find_player(scene_root)
	await wait_physics_frames(SETTLE_FRAMES)
	_start_in_kitchen(player)
	var reached: bool = await _drive_to_symptomatic(player)
	assert_true(reached, "crise alcançada para medir o repouso (spam=%s)" % str(spam))
	var start: float = player.get_physiology().get_snapshot().symptom_severity
	var resting_ticks: int = 0
	for i: int in REST_FRAMES:
		if spam or i == 0:
			player.get_motor().set_scripted_input(PlayerWorld.edge_input(true, false))
		else:
			player.get_motor().set_scripted_input(PlayerWorld.move_input(Vector2.ZERO))
		await wait_physics_frames(1)
		var built: PhysiologyInputs = player.call("_build_physiology_inputs") as PhysiologyInputs
		if built != null and built.is_resting:
			resting_ticks += 1
	var end: float = player.get_physiology().get_snapshot().symptom_severity
	player.get_motor().set_scripted_input(null)
	release_and_flush(world)
	return {"fracao": float(resting_ticks) / float(REST_FRAMES), "queda": (start - end) / (float(REST_FRAMES) / 60.0)}

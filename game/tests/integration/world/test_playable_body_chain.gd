extends TestCase
## Integration: cadeia dos sons e efeitos do corpo na cena jogável real (integração da onda B da F2).
## fisiologia → BreathEmitter → AcousticWorld → BreathingAudio; bombinha → puff; apresentação ligada ao jogador.
## Autor: Project Director.

const PLAYABLE_PATH: String = "res://content/levels/sandbox_playable.tscn"
## ~6,7 s de jogo: a respiração calma (ciclo de até 4,3 s) emite ao menos um evento.
const BREATH_WAIT_FRAMES: int = 400

var _root: Node = null
var _events: Array[NoiseEvent] = []


func before_all() -> void:
	var scene: PackedScene = load(PLAYABLE_PATH) as PackedScene
	_root = scene.instantiate()
	add_child(_root)
	await wait_physics_frames(2)
	_world().noise_resolved_for_player.connect(_on_noise)


func after_all() -> void:
	await release_and_flush(_root)
	_root = null


func _on_noise(event: NoiseEvent, _result: PropagationResult) -> void:
	_events.append(event)


func _world() -> AcousticWorld:
	return _root.get_node("AcousticWorld") as AcousticWorld


func _audio() -> BreathingAudio:
	return _root.get_node("BreathingAudio") as BreathingAudio


func _player() -> PlayerRoot:
	return get_tree().get_nodes_in_group(&"player")[0] as PlayerRoot


func _player_events(category: Enums.NoiseCategory) -> Array[NoiseEvent]:
	var out: Array[NoiseEvent] = []
	for e: NoiseEvent in _events:
		if e.source_id == &"player" and e.category == category:
			out.append(e)
	return out


func test_breathing_cycle_reaches_the_world_and_the_head_audio() -> void:
	_events.clear()
	var played_before: int = _audio().played_log.size()
	await wait_physics_frames(BREATH_WAIT_FRAMES)
	var breaths: int = _player_events(Enums.NoiseCategory.BREATHING).size() + _player_events(Enums.NoiseCategory.WHEEZING).size()
	assert_true(breaths >= 1, "eventos de respiração do jogador chegaram ao AcousticWorld: %d" % breaths)
	assert_true(_audio().played_log.size() > played_before, "o BreathingAudio tocou a respiração")


func test_inhaler_use_emits_medication_puff() -> void:
	_events.clear()
	assert_true(_player().try_use_inhaler(), "a bombinha inicial (3 doses) pode ser usada")
	await wait_physics_frames(3)
	var puffs: Array[NoiseEvent] = _player_events(Enums.NoiseCategory.MEDICATION)
	assert_eq(puffs.size(), 1, "um evento MEDICATION por uso")
	if puffs.size() == 1:
		assert_eq(puffs[0].sound_id, &"inhaler_puff")
		assert_almost_eq(puffs[0].intensity_db, 38.0, 0.001, "MEDICATION 38 dB (DATA §1.7)")


func test_startle_gasp_is_audible_body_sound() -> void:
	_events.clear()
	var physiology: PhysiologyComponent = _player().get_physiology()
	# O gasp exige estresse ≥ 50 antes do pico (DATA §1.3): dois sustos sobem o estresse, o terceiro gera o gasp.
	physiology.add_startle(25.0)
	physiology.add_startle(25.0)
	physiology.add_startle(25.0)
	await wait_physics_frames(3)
	var gasps: int = 0
	for e: NoiseEvent in _player_events(Enums.NoiseCategory.BREATHING):
		if e.sound_id == &"gasp":
			gasps += 1
	assert_true(gasps >= 1, "o susto com estresse alto gera o gasp pelo BreathEmitter")


func test_presentation_is_bound_to_the_player() -> void:
	await wait_process_frames(2)
	var fx: CameraEffects = _root.get_node("CameraEffects") as CameraEffects
	assert_true(fx.get_player() == _player(), "CameraEffects ligado ao jogador da cena")
	assert_not_null(fx.get_viewmodel(), "viewmodel criado na câmera")
	var panel: BalancePanel = _root.get_node("BalancePanel") as BalancePanel
	assert_not_null(panel, "painel de balanceamento presente (F4)")
	assert_false(panel.is_panel_open(), "o painel começa fechado")

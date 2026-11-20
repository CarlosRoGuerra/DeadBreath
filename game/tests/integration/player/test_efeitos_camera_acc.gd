extends TestCase
## F2-007 e F2-009 (ACC-01, ACC-02, ACC-03; TEST_PLAN §2.8): efeitos de câmera ao vivo, indicador respiratório e viewmodel
## (animação de uso, sobressalto da tosse, coerência com a câmera). Física em tick fixo. Autor: Gameplay Engineer.

const WorldScript := preload("res://tests/integration/player/fixtures/player_world.gd")
const SETTLE_FRAMES: int = 6
const LIVE_FRAMES: int = 40
const STRESS_FRAMES: int = 420
const STRESS_INJURY: float = 70.0
const ZERO_TOL: float = 0.000001

var _previous: Dictionary = {}


func before_all() -> void:
	Settings.autosave = false


func after_all() -> void:
	Settings.autosave = true


func before_each() -> void:
	_previous = WorldScript.override_settings({&"motion_reduction": 0.0, &"tremor_reduction": 0.0, &"effects_intensity": 1.0, &"respiratory_indicator": false, &"mouse_sensitivity": 0.12, &"invert_y": false, &"fov": 75.0})


func after_each() -> void:
	WorldScript.restore_settings(_previous)


func _setup(root: Node3D) -> Dictionary:
	WorldScript.add_box(root, Vector3(0.0, -0.5, -5.0), Vector3(6.0, 1.0, 16.0), &"wood")
	var player: PlayerRoot = WorldScript.spawn_player(root, Vector3.ZERO)
	var effects: CameraEffects = add_child_autofree(CameraEffects.new()) as CameraEffects
	effects.set_player(player)
	return {"player": player, "effects": effects}


func test_acc01_reducao_total_deixa_a_camera_parada_mesmo_com_estresse() -> void:
	var root: Node3D = add_child_autofree(Node3D.new()) as Node3D
	var parts: Dictionary = _setup(root)
	var player: PlayerRoot = parts["player"] as PlayerRoot
	player.get_physiology().add_injury(STRESS_INJURY)
	Settings.set_value(&"motion_reduction", 1.0)
	Settings.set_value(&"tremor_reduction", 1.0)
	await wait_physics_frames(LIVE_FRAMES)
	await wait_process_frames(2)
	assert_almost_eq(player.get_camera().position.length(), 0.0, ZERO_TOL, "sem balanço e sem tremor: câmera parada")
	assert_almost_eq(player.get_camera().rotation.z, 0.0, ZERO_TOL, "sem rolagem")


func test_acc01_sem_reducao_ha_tremor_com_estresse_alto() -> void:
	var root: Node3D = add_child_autofree(Node3D.new()) as Node3D
	var parts: Dictionary = _setup(root)
	var player: PlayerRoot = parts["player"] as PlayerRoot
	player.get_physiology().add_injury(STRESS_INJURY)
	await wait_physics_frames(LIVE_FRAMES)
	await wait_process_frames(2)
	assert_true(player.get_camera().position.length() > 0.0, "sem redução a câmera se move (balanço e tremor)")


func test_acc02_intensidade_zero_zera_os_efeitos() -> void:
	var root: Node3D = add_child_autofree(Node3D.new()) as Node3D
	var parts: Dictionary = _setup(root)
	var player: PlayerRoot = parts["player"] as PlayerRoot
	var effects: CameraEffects = parts["effects"] as CameraEffects
	player.get_physiology().add_injury(STRESS_INJURY)
	Settings.set_value(&"effects_intensity", 0.0)
	await wait_physics_frames(LIVE_FRAMES)
	await wait_process_frames(2)
	assert_almost_eq(player.get_camera().position.length(), 0.0, ZERO_TOL, "intensidade 0: nenhum efeito de câmera")
	assert_almost_eq(effects.get_vignette_alpha(), 0.0, ZERO_TOL, "intensidade 0: sem vinheta")


func test_acc03_indicador_desligado_por_padrao() -> void:
	var root: Node3D = add_child_autofree(Node3D.new()) as Node3D
	var parts: Dictionary = _setup(root)
	var effects: CameraEffects = parts["effects"] as CameraEffects
	await wait_process_frames(2)
	assert_false(effects.get_indicator().visible, "indicador respiratório desligado sem a opção")


func test_acc03_indicador_reflete_o_estado_no_frame_seguinte() -> void:
	var root: Node3D = add_child_autofree(Node3D.new()) as Node3D
	var parts: Dictionary = _setup(root)
	var player: PlayerRoot = parts["player"] as PlayerRoot
	var effects: CameraEffects = parts["effects"] as CameraEffects
	Settings.set_value(&"respiratory_indicator", true)
	await wait_process_frames(1)
	assert_true(effects.get_indicator().visible, "ligado pela opção")
	player.get_physiology().add_injury(STRESS_INJURY)
	var changes: Array[int] = [0]
	var mismatches: Array[int] = [0]
	var last_state: Enums.RespiratoryState = player.get_physiology().get_snapshot().respiratory_state
	for _frame: int in STRESS_FRAMES:
		await wait_physics_frames(1)
		await wait_process_frames(1)
		var state: Enums.RespiratoryState = player.get_physiology().get_snapshot().respiratory_state
		if state != last_state:
			changes[0] += 1
			last_state = state
		var expected: String = "respiração: " + RespiratoryModel.state_name(state)
		if effects.get_indicator().get_text() != expected:
			mismatches[0] += 1
	assert_true(changes[0] >= 1, "o estado respiratório mudou com o estresse (mudanças=%d)" % changes[0])
	assert_eq(mismatches[0], 0, "o indicador reflete o estado no frame seguinte (divergências=%d)" % mismatches[0])


func test_f2_009_viewmodel_uso_da_bombinha_anima() -> void:
	var root: Node3D = add_child_autofree(Node3D.new()) as Node3D
	var parts: Dictionary = _setup(root)
	var player: PlayerRoot = parts["player"] as PlayerRoot
	var effects: CameraEffects = parts["effects"] as CameraEffects
	var viewmodel: Viewmodel = effects.get_viewmodel()
	assert_not_null(viewmodel, "o viewmodel existe")
	assert_eq(viewmodel.get_parent(), player.get_camera(), "o viewmodel é filho da câmera (herda o balanço)")
	assert_true(player.try_use_inhaler(), "bombinha usada")
	assert_true(viewmodel.is_using(), "animação de uso ativa")
	var start: Vector3 = viewmodel.get_hand_position()
	await wait_process_frames(12)
	assert_true(viewmodel.get_hand_position().distance_to(start) > 0.001, "a mão se move durante o uso")
	await wait_process_frames(80)
	assert_false(viewmodel.is_using(), "a animação termina")


func test_f2_009_viewmodel_sobressalto_da_tosse() -> void:
	var root: Node3D = add_child_autofree(Node3D.new()) as Node3D
	var parts: Dictionary = _setup(root)
	var player: PlayerRoot = parts["player"] as PlayerRoot
	var effects: CameraEffects = parts["effects"] as CameraEffects
	var viewmodel: Viewmodel = effects.get_viewmodel()
	player.get_physiology().coughed.emit(false)
	assert_true(viewmodel.is_coughing(), "tosse dispara o sobressalto")
	await wait_process_frames(60)
	assert_false(viewmodel.is_coughing(), "o sobressalto termina")
	player.get_physiology().coughed.emit(true)
	assert_false(viewmodel.is_coughing(), "tosse cancelada não dispara o sobressalto")

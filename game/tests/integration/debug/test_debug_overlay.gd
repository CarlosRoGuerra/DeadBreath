extends TestCase
## F1-008 (card): overlay F3 com fps, postura, marcha, esforço, velocidade e foco; comandos noclip e teleporte;
## a flag de produção (GameState.is_production_build) desliga overlay e comandos. Física em tick fixo.
## Autor: Gameplay Engineer.

const PlayerWorld := preload("res://tests/integration/player/fixtures/player_world.gd")

const SETTLE_FRAMES: int = 6
const TEXT_FRAMES: int = 2
const WALK_FRAMES: int = 30
const NOCLIP_FRAMES: int = 60
const LOOK_DOWN_DEG: float = 40.0
const SENSITIVITY_DEG: float = 0.12
const AIM_FLOOR_Z_M: float = -1.967
const AIM_TOLERANCE_M: float = 0.1
const WALL_Z_M: float = -1.6
const THROUGH_WALL_Z_M: float = -2.5

var _previous: Dictionary = {}
var _previous_production: bool = false


func before_all() -> void:
	Settings.autosave = false


func after_all() -> void:
	Settings.autosave = true


func before_each() -> void:
	_previous = PlayerWorld.override_settings({&"motion_reduction": 0.0, &"mouse_sensitivity": SENSITIVITY_DEG, &"invert_y": false, &"fov": 75.0})
	_previous_production = GameState.is_production_build
	GameState.is_production_build = false


func after_each() -> void:
	PlayerWorld.restore_settings(_previous)
	GameState.is_production_build = _previous_production


func _world(root: Node3D) -> PlayerRoot:
	PlayerWorld.add_box(root, Vector3(0.0, -0.5, -5.0), Vector3(6.0, 1.0, 16.0), &"wood")
	return PlayerWorld.spawn_player(root, Vector3.ZERO)


func _walk(player: PlayerRoot, frames: int) -> void:
	player.get_motor().set_scripted_input(PlayerWorld.move_input(Vector2(0.0, 1.0)))
	await wait_physics_frames(frames)
	player.get_motor().set_scripted_input(MotorInput.new())


func test_producao_desliga_overlay_e_comandos() -> void:
	GameState.is_production_build = true
	var root: Node3D = add_child_autofree(Node3D.new()) as Node3D
	var player: PlayerRoot = _world(root)
	var overlay: DebugOverlay = DebugOverlay.new()
	root.add_child(overlay)
	overlay.set_player(player)
	await wait_physics_frames(SETTLE_FRAMES)
	assert_false(overlay.is_debug_enabled(), "em produção o overlay não está habilitado")
	assert_false(overlay.toggle_overlay(), "F3 em produção não mostra o overlay")
	assert_false(overlay.is_overlay_visible(), "overlay continua oculto em produção")
	assert_false(overlay.toggle_noclip(), "noclip recusado em produção")
	assert_false(player.is_noclip(), "o jogador não entra em noclip em produção")
	assert_false(overlay.teleport_to_aim(), "teleporte recusado em produção")
	assert_false(DebugCommands.set_noclip(player, true), "comando de noclip recusado em produção")
	assert_false(player.is_noclip(), "nenhum comando mudou o jogador em produção")


func test_overlay_mostra_postura_marcha_e_esforco() -> void:
	var root: Node3D = add_child_autofree(Node3D.new()) as Node3D
	var player: PlayerRoot = _world(root)
	var overlay: DebugOverlay = DebugOverlay.new()
	root.add_child(overlay)
	overlay.set_player(player)
	await wait_physics_frames(SETTLE_FRAMES)
	assert_true(overlay.toggle_overlay(), "fora de produção, F3 mostra o overlay")
	await wait_physics_frames(TEXT_FRAMES)
	var text: String = overlay.get_overlay_text()
	assert_true(text.contains("postura: em pé"), "postura em pé no texto: %s" % text)
	assert_true(text.contains("marcha: parado"), "marcha parado no texto")
	assert_true(text.contains("fps:"), "fps no texto")
	# Lê o texto enquanto o bot anda (o overlay atualiza a cada frame de processo).
	player.get_motor().set_scripted_input(PlayerWorld.move_input(Vector2(0.0, 1.0)))
	await wait_physics_frames(WALK_FRAMES + TEXT_FRAMES)
	text = overlay.get_overlay_text()
	player.get_motor().set_scripted_input(MotorInput.new())
	assert_true(text.contains("marcha: andando"), "marcha andando enquanto anda: %s" % text)
	assert_true(text.contains("esforço: 0.20"), "esforço 0,20 ao andar")
	assert_true(text.contains("velocidade:"), "velocidade no texto")


func test_f3_pela_acao_alterna_o_overlay() -> void:
	var root: Node3D = add_child_autofree(Node3D.new()) as Node3D
	var player: PlayerRoot = _world(root)
	var overlay: DebugOverlay = DebugOverlay.new()
	root.add_child(overlay)
	overlay.set_player(player)
	await wait_physics_frames(SETTLE_FRAMES)
	_push_action(overlay, &"debug_overlay", true)
	assert_true(overlay.is_overlay_visible(), "ação debug_overlay pressionada mostra o overlay")
	_push_action(overlay, &"debug_overlay", true)
	assert_false(overlay.is_overlay_visible(), "segunda vez esconde")


func test_noclip_atravessa_parede_e_desliga() -> void:
	var root: Node3D = add_child_autofree(Node3D.new()) as Node3D
	var player: PlayerRoot = _world(root)
	PlayerWorld.add_box(root, Vector3(0.0, 1.5, WALL_Z_M), Vector3(3.0, 3.0, 0.1))
	var overlay: DebugOverlay = DebugOverlay.new()
	root.add_child(overlay)
	overlay.set_player(player)
	await wait_physics_frames(SETTLE_FRAMES)
	overlay.toggle_overlay()
	await _walk(player, WALK_FRAMES)
	assert_true(player.global_position.z > WALL_Z_M, "sem noclip a parede segura o jogador (z = %f)" % player.global_position.z)
	# Tecla N (com o overlay visível) liga o noclip.
	_push_key(overlay, KEY_N)
	assert_true(player.is_noclip(), "tecla N liga o noclip")
	await _walk(player, NOCLIP_FRAMES)
	assert_true(player.global_position.z < THROUGH_WALL_Z_M, "com noclip o jogador atravessa a parede (z = %f)" % player.global_position.z)
	assert_true(overlay.toggle_noclip(), "segundo comando desliga o noclip")
	assert_false(player.is_noclip(), "noclip desligado")


func test_teleporte_para_o_chao_na_mira() -> void:
	var root: Node3D = add_child_autofree(Node3D.new()) as Node3D
	var player: PlayerRoot = _world(root)
	var overlay: DebugOverlay = DebugOverlay.new()
	root.add_child(overlay)
	overlay.set_player(player)
	await wait_physics_frames(SETTLE_FRAMES)
	# Olha 40° para baixo: a mira cai no chão a ~1,97 m à frente.
	var look: MotorInput = MotorInput.new()
	look.look_delta = Vector2(0.0, LOOK_DOWN_DEG / SENSITIVITY_DEG)
	player.get_motor().set_scripted_input(look)
	await wait_physics_frames(1)
	player.get_motor().set_scripted_input(MotorInput.new())
	assert_true(overlay.teleport_to_aim(), "mira no chão: teleporte aceito")
	await wait_physics_frames(SETTLE_FRAMES)
	assert_almost_eq(player.global_position.z, AIM_FLOOR_Z_M, AIM_TOLERANCE_M, "teleportado para o ponto do chão na mira")


func test_teleporte_recusado_sem_chao_na_mira() -> void:
	var root: Node3D = add_child_autofree(Node3D.new()) as Node3D
	var player: PlayerRoot = _world(root)
	var overlay: DebugOverlay = DebugOverlay.new()
	root.add_child(overlay)
	overlay.set_player(player)
	await wait_physics_frames(SETTLE_FRAMES)
	# Mira horizontal: nada no chão, então o teleporte é recusado e o jogador não se move.
	var before: Vector3 = player.global_position
	assert_false(overlay.teleport_to_aim(), "mira horizontal (sem chão) recusa o teleporte")
	assert_eq(player.global_position, before, "posição inalterada")


func _push_action(overlay: DebugOverlay, action: StringName, pressed: bool) -> void:
	var event: InputEventAction = InputEventAction.new()
	event.action = action
	event.pressed = pressed
	overlay.get_viewport().push_input(event)


func _push_key(overlay: DebugOverlay, keycode: Key) -> void:
	var event: InputEventKey = InputEventKey.new()
	event.physical_keycode = keycode
	event.pressed = true
	overlay.get_viewport().push_input(event)

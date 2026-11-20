extends TestCase
## F1-013: menu de pausa. Esc abre (pausa a árvore e solta o mouse); Controles abre a tela de remapeamento;
## Continuar despausa e devolve o controle ao jogador (on_menu_resumed no grupo "player" recaptura o mouse).
## Autor: Gameplay Engineer.

const PlayerWorld := preload("res://tests/integration/player/fixtures/player_world.gd")

const SETTLE_FRAMES: int = 4

var _previous: Dictionary = {}


func before_all() -> void:
	Settings.autosave = false


func after_all() -> void:
	Settings.autosave = true


func before_each() -> void:
	_previous = PlayerWorld.override_settings({&"motion_reduction": 0.0, &"mouse_sensitivity": 0.12, &"invert_y": false, &"fov": 75.0})


func after_each() -> void:
	get_tree().paused = false
	PlayerWorld.restore_settings(_previous)


func _push_pause(menu: PauseMenu) -> void:
	var event: InputEventAction = InputEventAction.new()
	event.action = &"pause"
	event.pressed = true
	menu.get_viewport().push_input(event)


func test_pausa_e_continuar_devolvem_o_controle_ao_jogador() -> void:
	var root: Node3D = add_child_autofree(Node3D.new()) as Node3D
	PlayerWorld.add_box(root, Vector3(0.0, -0.5, -5.0), Vector3(6.0, 1.0, 16.0), &"wood")
	var player: PlayerRoot = PlayerWorld.spawn_player(root, Vector3.ZERO)
	var menu: PauseMenu = add_child_autofree(PauseMenu.new()) as PauseMenu
	await wait_physics_frames(SETTLE_FRAMES)
	player.set_mouse_captured(false)
	assert_false(player.is_mouse_capture_requested(), "mouse solto antes de continuar")
	menu.open_menu()
	assert_true(menu.is_open(), "menu aberto")
	assert_true(get_tree().paused, "abrir o menu pausa a árvore")
	menu.continue_game()
	assert_false(menu.is_open(), "continuar fecha o menu")
	assert_false(get_tree().paused, "continuar despausa a árvore")
	assert_true(player.is_mouse_capture_requested(), "o jogador recaptura o mouse ao continuar")


func test_esc_abre_e_fecha_pela_acao_pause() -> void:
	var menu: PauseMenu = add_child_autofree(PauseMenu.new()) as PauseMenu
	await wait_physics_frames(2)
	_push_pause(menu)
	assert_true(menu.is_open(), "ação pause abre o menu")
	assert_true(get_tree().paused, "menu aberto pausa o jogo")
	_push_pause(menu)
	assert_false(menu.is_open(), "segunda ação pause fecha o menu")
	assert_false(get_tree().paused, "fechar o menu despausa")


func test_controles_abre_a_tela_e_pause_volta_ao_menu_principal() -> void:
	var menu: PauseMenu = add_child_autofree(PauseMenu.new()) as PauseMenu
	await wait_physics_frames(2)
	menu.open_menu()
	menu.show_controls()
	assert_true(menu.is_controls_visible(), "Controles mostra a tela de remapeamento")
	_push_pause(menu)
	assert_false(menu.is_controls_visible(), "pause na tela de controles volta ao menu principal")
	assert_true(menu.is_open(), "o menu continua aberto")
	menu.continue_game()

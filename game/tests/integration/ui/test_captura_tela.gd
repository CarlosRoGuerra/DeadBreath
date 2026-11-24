extends TestCase
## F4-005 (UI e fluxo da captura, D4-04): EventBus.player_captured mostra a tela "Capturado", trava a entrada do jogador
## (PlayerRoot) e reinicia a cena uma única vez, depois de 2,5 s. A captura repetida durante o fade não reinicia de novo.
## A tela funciona em pausa. O disparo é emitido direto no EventBus (a EnemyCaptureArea é do AI Engineer, F4-005).
## Autor: Gameplay Engineer.

const PlayerWorld := preload("res://tests/integration/player/fixtures/player_world.gd")
const SETTLE_FRAMES: int = 6
const FADE_CHECK_S: float = 0.5
const RESTART_DELAY_S: float = 2.5
const TOLERANCE: float = 0.01

var _restarts: int = 0


func _count_restart() -> void:
	_restarts += 1


func before_each() -> void:
	_restarts = 0


func _setup() -> Dictionary:
	var root: Node3D = add_isolated_world()
	PlayerWorld.add_box(root, Vector3(0.0, -0.5, -5.0), Vector3(6.0, 1.0, 16.0), &"wood")
	var player: PlayerRoot = PlayerWorld.spawn_player(root, Vector3.ZERO)
	var screen: CaptureScreen = CaptureScreen.new()
	screen.restart_callable = Callable(self, "_count_restart")
	root.add_child(screen)
	return {"player": player, "screen": screen}


func test_captura_mostra_a_tela_e_trava_a_entrada() -> void:
	var parts: Dictionary = _setup()
	var player: PlayerRoot = parts["player"] as PlayerRoot
	var screen: CaptureScreen = parts["screen"] as CaptureScreen
	await wait_physics_frames(SETTLE_FRAMES)
	assert_false(screen.is_capturing(), "antes da captura, a tela está quieta")
	assert_false(player.is_input_locked(), "antes da captura, a entrada está livre")
	EventBus.player_captured.emit(&"observer_test")
	assert_true(screen.is_capturing(), "o sinal ativa a tela")
	assert_true(player.is_input_locked(), "o sinal trava a entrada do jogador")
	assert_eq(screen.get_caption_text(), "Capturado", "o texto da tela é Capturado")
	screen.advance(FADE_CHECK_S)
	assert_almost_eq(screen.get_fade_alpha(), FADE_CHECK_S / CaptureScreen.FADE_S, TOLERANCE, "o fade sobe com o tempo")
	assert_eq(_restarts, 0, "antes de 2,5 s, nada reinicia")


func test_reinicio_e_chamado_uma_unica_vez_depois_de_2_5_s() -> void:
	var parts: Dictionary = _setup()
	var screen: CaptureScreen = parts["screen"] as CaptureScreen
	await wait_physics_frames(SETTLE_FRAMES)
	EventBus.player_captured.emit(&"observer_test")
	screen.advance(RESTART_DELAY_S - 0.1)
	assert_eq(_restarts, 0, "0,1 s antes do reinício, ainda não reinicia")
	screen.advance(0.2)
	assert_eq(_restarts, 1, "passados 2,5 s, reinicia uma vez")
	screen.advance(10.0)
	assert_eq(_restarts, 1, "continuar avançando não reinicia de novo")
	assert_eq(screen.get_restart_count(), 1, "o contador da tela também marca uma vez")


func test_captura_repetida_durante_o_fade_nao_reinicia_duas_vezes() -> void:
	var parts: Dictionary = _setup()
	var player: PlayerRoot = parts["player"] as PlayerRoot
	var screen: CaptureScreen = parts["screen"] as CaptureScreen
	await wait_physics_frames(SETTLE_FRAMES)
	EventBus.player_captured.emit(&"observer_test")
	screen.advance(1.0)
	EventBus.player_captured.emit(&"observer_test")
	EventBus.player_captured.emit(&"observer_test")
	screen.advance(RESTART_DELAY_S)
	assert_eq(_restarts, 1, "três capturas seguidas reiniciam uma vez só")
	assert_true(player.is_input_locked(), "a entrada continua travada")


func test_tela_funciona_em_pausa() -> void:
	var parts: Dictionary = _setup()
	var screen: CaptureScreen = parts["screen"] as CaptureScreen
	await wait_physics_frames(SETTLE_FRAMES)
	assert_eq(screen.process_mode, Node.PROCESS_MODE_ALWAYS, "a tela processa mesmo com a árvore em pausa")
	get_tree().paused = true
	EventBus.player_captured.emit(&"observer_test")
	await wait_process_frames(30)
	get_tree().paused = false
	assert_true(screen.get_fade_alpha() > 0.0, "o fade avança com a árvore em pausa (%.3f)" % screen.get_fade_alpha())

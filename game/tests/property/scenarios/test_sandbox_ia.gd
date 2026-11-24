extends TestCase
## Integração da onda B da F4 (Director): a sandbox_ia.tscn herda a sandbox jogável e acrescenta o Observer no
## surgimento, a tela de captura e a música adaptativa ligada ao monitor de ameaça. A sandbox jogável continua sem
## inimigo, para os testes das fases 1 a 3. Cenário de ponta a ponta: o jogador parado diante do Observer é visto,
## perseguido e capturado; a tela de captura aparece, a entrada trava e o reinício acontece uma vez.
## A cena é carregada uma vez; a estrutura é conferida antes do cenário, que muda o estado.

const SCENE_PATH: String = "res://content/levels/sandbox_ia.tscn"
const SETTLE_FRAMES: int = 12
const CAPTURE_MAX_FRAMES: int = 420
const RESTART_MAX_FRAMES: int = 240
const FRONT_DISTANCE_M: float = 1.4

var _root: Node = null
var _captures: Array[StringName] = []
var _restarts: int = 0


func before_all() -> void:
	var scene: PackedScene = load(SCENE_PATH) as PackedScene
	_root = scene.instantiate()
	add_child(_root)
	await wait_physics_frames(SETTLE_FRAMES)


func after_all() -> void:
	if EventBus.player_captured.is_connected(_on_captured):
		EventBus.player_captured.disconnect(_on_captured)
	await release_and_flush(_root)
	_root = null


func _on_captured(enemy_id: StringName) -> void:
	_captures.append(enemy_id)


func _observer() -> EnemyController:
	return _root.get_node("Observer") as EnemyController


func _player() -> PlayerRoot:
	return get_tree().get_first_node_in_group(&"player") as PlayerRoot


func test_a_estrutura_observer_captura_e_musica() -> void:
	var observer: EnemyController = _observer()
	assert_not_null(observer, "o Observer está na sandbox_ia")
	if observer == null:
		return
	assert_true(observer.is_in_group(&"enemy"), "grupo enemy")
	assert_eq(observer.enemy_id, &"observer", "enemy_id")
	assert_true(observer.global_position.distance_to(Vector3(23.0, 0.0, -1.0)) < 1.0,
		"nasce no surgimento do quintal (%s)" % observer.global_position)
	assert_true(observer.get_state() == Enums.EnemyState.PATROL or observer.get_state() == Enums.EnemyState.SUSPICIOUS,
		"começa patrulhando (estado %d)" % observer.get_state())
	var link: NavigationLink3D = _root.find_child("NavLink_door_cozinha_corredor", true, false) as NavigationLink3D
	assert_not_null(link, "o link da porta trancada existe")
	if link != null:
		assert_false(link.enabled, "porta trancada: link desligado pelo DoorLinkGate (D4-03)")
	assert_not_null(_root.get_node_or_null("CaptureScreen") as CaptureScreen, "tela de captura")
	var music: AdaptiveMusic = _root.get_node_or_null("AdaptiveMusic") as AdaptiveMusic
	assert_not_null(music, "música adaptativa")
	if music != null:
		assert_true(music.is_bound_to_monitor(), "a música ouve o monitor de ameaça do jogador")
	var playable_has_enemy: bool = false
	var playable: Node = (load("res://content/levels/sandbox_playable.tscn") as PackedScene).instantiate()
	for child: Node in playable.get_children():
		if child is EnemyController:
			playable_has_enemy = true
	playable.free()
	assert_false(playable_has_enemy, "a sandbox jogável continua sem inimigo (testes das fases 1 a 3)")


func test_b_jogador_parado_diante_do_observer_e_capturado() -> void:
	var observer: EnemyController = _observer()
	var player: PlayerRoot = _player()
	var screen: CaptureScreen = _root.get_node("CaptureScreen") as CaptureScreen
	assert_not_null(player, "pré-condição: há jogador")
	if observer == null or player == null or screen == null:
		return
	screen.restart_callable = func() -> void: _restarts += 1
	EventBus.player_captured.connect(_on_captured)
	var forward: Vector3 = -observer.global_transform.basis.z
	forward.y = 0.0
	forward = forward.normalized()
	player.global_position = observer.global_position + forward * FRONT_DISTANCE_M
	var chased: bool = false
	var frames: int = 0
	while _captures.is_empty() and frames < CAPTURE_MAX_FRAMES:
		await wait_physics_frames(1)
		frames += 1
		chased = chased or observer.get_state() == Enums.EnemyState.CHASE
	note("captura em %d ticks; perseguiu=%s; estado final %d" % [frames, chased, observer.get_state()])
	assert_true(chased, "o Observer viu o jogador e entrou em CHASE")
	assert_eq(_captures.size(), 1, "uma captura, pelo Observer")
	if _captures.size() >= 1:
		assert_eq(_captures[0], &"observer", "enemy_id da captura")
	assert_true(screen.is_capturing(), "a tela de captura aparece")
	assert_true(player.is_input_locked(), "a entrada do jogador trava")
	var waited: int = 0
	while _restarts == 0 and waited < RESTART_MAX_FRAMES:
		await wait_physics_frames(1)
		waited += 1
	assert_eq(_restarts, 1, "o reinício acontece uma vez (%d ticks depois)" % waited)

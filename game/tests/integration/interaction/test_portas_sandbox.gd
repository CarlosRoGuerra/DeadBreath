extends TestCase
## BUG-009 (critério de aceite): as portas da sandbox jogável abrem por inteiro sem corpo no arco. Cobre as quatro
## portas: corredor (sala-corredor), cozinha (nasce aberta), hall (corredor-hall) e a trancada (cozinha-corredor, após
## unlock()). Chama Door.interact direto (sem depender da mira). O jogador começa longe dos arcos (PlayerSpawn).
## Física em tick fixo de 1/60 s. Autor: Gameplay Engineer (F1-011).

const PLAYABLE_PATH: String = "res://content/levels/sandbox_playable.tscn"
const SETTLE_FRAMES: int = 8
const OPEN_FRAMES: int = 60
const FULLY_OPEN_MIN_DEG: float = 85.0
const DOORS_CLOSED: Array[String] = ["door_sala_corredor", "door_corredor_hall", "door_cozinha_corredor"]
const DOOR_BORN_OPEN: String = "door_sala_cozinha"

var _previous_production: bool = false


func before_all() -> void:
	Settings.autosave = false


func after_all() -> void:
	Settings.autosave = true


func before_each() -> void:
	_previous_production = GameState.is_production_build
	GameState.is_production_build = false


func after_each() -> void:
	GameState.is_production_build = _previous_production


func test_portas_da_sandbox_abrem_por_inteiro_sem_corpo_no_arco() -> void:
	var packed: PackedScene = load(PLAYABLE_PATH) as PackedScene
	assert_not_null(packed, "a cena jogável carrega")
	if packed == null:
		return
	var playable: Node = add_child_autofree(packed.instantiate())
	await wait_physics_frames(SETTLE_FRAMES)
	var player: PlayerRoot = playable.find_child("Player", true, false) as PlayerRoot
	assert_not_null(player, "a cena jogável tem o jogador")
	if player == null:
		return
	var context: InteractionContext = InteractionContext.new()
	context.actor = player
	for name: String in DOORS_CLOSED:
		var door: Door = playable.find_child(name, true, false) as Door
		assert_not_null(door, "a porta %s existe" % name)
		if door == null:
			continue
		if door.get_state() == Door.State.LOCKED:
			door.unlock()
		assert_eq(door.get_state(), Door.State.CLOSED, "%s começa fechada (ou destrancada)" % name)
		door.interact(context)
		await wait_physics_frames(OPEN_FRAMES)
		assert_true(door.get_panel_angle_deg() >= FULLY_OPEN_MIN_DEG, "%s abre por inteiro sem corpo no arco (ângulo %.1f°)" % [name, door.get_panel_angle_deg()])
		assert_false(door.is_blocked(), "%s não está bloqueada depois de abrir" % name)
	var born_open: Door = playable.find_child(DOOR_BORN_OPEN, true, false) as Door
	assert_not_null(born_open, "a porta %s existe" % DOOR_BORN_OPEN)
	if born_open != null:
		assert_eq(born_open.get_state(), Door.State.OPEN, "%s nasce aberta" % DOOR_BORN_OPEN)
		assert_true(born_open.get_panel_angle_deg() >= FULLY_OPEN_MIN_DEG, "%s nasce com o painel no ângulo de abertura (%.1f°)" % [DOOR_BORN_OPEN, born_open.get_panel_angle_deg()])

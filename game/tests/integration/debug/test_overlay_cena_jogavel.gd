extends TestCase
## R1-04 (F1-010): na cena jogável (content/levels/sandbox_playable.tscn, run/main_scene) o overlay de debug tem de
## achar o jogador sozinho pelo grupo "player". O teste carrega a cena SEM injetar o jogador e exige get_player()
## não nulo e o texto com a postura. Autor: Gameplay Engineer (F1-010).

const PLAYABLE_PATH: String = "res://content/levels/sandbox_playable.tscn"
const SETTLE_FRAMES: int = 4
const TEXT_FRAMES: int = 2

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


func test_overlay_da_cena_jogavel_acha_o_jogador_sem_injecao() -> void:
	var packed: PackedScene = load(PLAYABLE_PATH) as PackedScene
	assert_not_null(packed, "a cena jogável carrega")
	if packed == null:
		return
	var playable: Node = add_child_autofree(packed.instantiate())
	await wait_physics_frames(SETTLE_FRAMES)
	var overlay: DebugOverlay = playable.get_node("DebugOverlay") as DebugOverlay
	assert_not_null(overlay, "a cena jogável tem o DebugOverlay")
	if overlay == null:
		return
	assert_not_null(overlay.get_player(), "o overlay acha o jogador pelo grupo \"player\", sem set_player")
	assert_true(overlay.toggle_overlay(), "F3 mostra o overlay na cena jogável")
	await wait_physics_frames(TEXT_FRAMES)
	var text: String = overlay.get_overlay_text()
	assert_true(text.contains("postura:"), "o texto mostra a postura: %s" % text)
	assert_false(text.contains("sem jogador"), "o texto não diz que não há jogador")
	assert_true(overlay.toggle_noclip(), "N (noclip) age na cena jogável")
	overlay.toggle_noclip()

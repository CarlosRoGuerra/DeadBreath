extends SceneTree
## Probe F2-011 (QA): build de produção. Confere se o painel F4 (BalancePanel) e o overlay (DebugOverlay) ficam
## desligados, se a tecla F4 ainda é consumida (R2-13), se a ação debug_overlay liga o overlay, e se os comandos de
## debug (noclip e teleporte) são recusados. Roda em processo separado; o modo vem do argumento --production.
## Script principal -s: sem class_name no código (compilação antes dos autoloads); o jogador é achado pelo método.
## Uso (headless, sem janela):
##   godot --headless --path game -s res://tests/integration/qa/probes/f2011_probe_producao.gd -- --production
##   godot --headless --path game -s res://tests/integration/qa/probes/f2011_probe_producao.gd
## Saída: Docs/QA/EVIDENCE/F2-011_producao_<modo>.txt

const PLAYABLE_PATH: String = "res://content/levels/sandbox_playable.tscn"
const OUT_DIR: String = "D:/Dev/DeadBreath/Docs/QA/EVIDENCE/"
const SETTLE_FRAMES: int = 20
const AFTER_FRAMES: int = 10

var _frames: int = 0
var _lines: PackedStringArray = PackedStringArray()
var _scene_root: Node = null
var _player: Node = null
var _overlay: CanvasLayer = null
var _panel: CanvasLayer = null
var _production: bool = false


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames == 1:
		var game_state: Node = root.get_node("GameState")
		_production = bool(game_state.get("is_production_build"))
		_say("modo: " + ("PRODUCAO (is_production_build=true)" if _production else "DESENVOLVIMENTO (is_production_build=false)"))
		var packed: PackedScene = load(PLAYABLE_PATH) as PackedScene
		_scene_root = packed.instantiate()
		root.add_child(_scene_root)
	elif _frames == SETTLE_FRAMES:
		_player = _find_player(_scene_root)
		_panel = _scene_root.get_node("BalancePanel") as CanvasLayer
		_overlay = _scene_root.get_node("DebugOverlay") as CanvasLayer
		_say("jogador encontrado=%s" % str(_player != null))
		_say("inicial: BalancePanel.visible=%s DebugOverlay.visible=%s" % [str(_panel.visible), str(_overlay.visible)])
		var consumed: bool = _press_key(KEY_F4)
		_say("F4: BalancePanel.visible=%s; F4 consumida pelo jogo=%s" % [str(_panel.visible), str(consumed)])
		_press_action(&"debug_overlay")
		_say("acao debug_overlay: DebugOverlay.visible=%s" % str(_overlay.visible))
	elif _frames == SETTLE_FRAMES + AFTER_FRAMES:
		var noclip_before: bool = bool(_player.call("is_noclip"))
		var accepted: bool = bool(_overlay.call("toggle_noclip"))
		_say("overlay.toggle_noclip(): aceito=%s noclip antes=%s depois=%s" % [str(accepted), str(noclip_before), str(bool(_player.call("is_noclip")))])
		var position_before: Vector3 = (_player as Node3D).global_position
		var teleported: bool = bool(_overlay.call("teleport_to_aim"))
		var moved: bool = (_player as Node3D).global_position.distance_to(position_before) > 0.001
		_say("overlay.teleport_to_aim(): aceito=%s posicao mudou=%s" % [str(teleported), str(moved)])
	elif _frames == SETTLE_FRAMES + AFTER_FRAMES + 2:
		_write()
		quit(0)
	return false


## Devolve se o aperto foi consumido (set_input_as_handled) logo após o aperto, antes do solte.
func _press_key(keycode: Key) -> bool:
	var event: InputEventKey = InputEventKey.new()
	event.keycode = keycode
	event.physical_keycode = keycode
	event.pressed = true
	root.push_input(event)
	var consumed: bool = root.is_input_handled()
	var release: InputEventKey = InputEventKey.new()
	release.keycode = keycode
	release.physical_keycode = keycode
	release.pressed = false
	root.push_input(release)
	return consumed


func _press_action(action: StringName) -> void:
	var event: InputEventAction = InputEventAction.new()
	event.action = action
	event.pressed = true
	root.push_input(event)
	var release: InputEventAction = InputEventAction.new()
	release.action = action
	release.pressed = false
	root.push_input(release)


## Jogador pelo método característico (duck typing; sem class_name no script principal).
func _find_player(node: Node) -> Node:
	if node.has_method("get_physiology") and node.has_method("is_noclip"):
		return node
	for child: Node in node.get_children():
		var found: Node = _find_player(child)
		if found != null:
			return found
	return null


func _say(line: String) -> void:
	_lines.append(line)
	print("PRODUCAO_PROBE " + line)


func _write() -> void:
	var name_text: String = "producao" if _production else "desenvolvimento"
	var file: FileAccess = FileAccess.open(OUT_DIR + "F2-011_producao_" + name_text + ".txt", FileAccess.WRITE)
	file.store_string("\n".join(_lines) + "\n")
	file.close()

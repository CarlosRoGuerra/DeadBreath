extends SceneTree
## Sonda de processo do QA (F1-011): recursos de debug na cena jogável. Com `-- --production`, o overlay (F3), o
## noclip (N) e o teleporte (T) têm de estar desligados. Imprime linhas PROBE e encerra. Autor: QA Engineer (F1-011).
## Uso: godot --headless --path game -s res://tests/integration/qa/probes/f1011_probe_debug_flags.gd -- [--production]
## Não usa nomes de classe nem autoloads no script principal: eles só existem depois do primeiro _process (como
## no runner). Por isso as chamadas são dinâmicas (call/get).

const PLAYABLE_PATH: String = "res://content/levels/sandbox_playable.tscn"

var _started: bool = false


func _process(_delta: float) -> bool:
	if not _started:
		_started = true
		_run()
	return false


func _run() -> void:
	var scene: PackedScene = load(PLAYABLE_PATH) as PackedScene
	var playable: Node = scene.instantiate()
	root.add_child(playable)
	for index: int in 10:
		await process_frame
	var overlay: Node = playable.get_node("DebugOverlay")
	var player: Node = playable.find_child("Player", true, false)
	var game_state: Node = root.get_node("GameState")
	var production: bool = bool(game_state.get("is_production_build"))
	print("PROBE producao=%s overlay_habilitado=%s argumentos=%s" % [
		str(production), str(overlay.call("is_debug_enabled")), str(OS.get_cmdline_user_args())])
	# Olha para o chão para o teleporte ter um ponto de mira.
	var head: Node3D = player.get_node("Head") as Node3D
	head.rotation.x = -0.6
	await process_frame
	_push_key(KEY_F3)
	await process_frame
	await process_frame
	print("PROBE F3 overlay_visivel=%s" % str(overlay.call("is_overlay_visible")))
	var noclip_before: bool = bool(player.call("is_noclip"))
	_push_key(KEY_N)
	await process_frame
	await process_frame
	print("PROBE N noclip_antes=%s depois=%s" % [str(noclip_before), str(player.call("is_noclip"))])
	var position_before: Vector3 = (player as Node3D).global_position
	_push_key(KEY_T)
	await process_frame
	await process_frame
	await process_frame
	print("PROBE T posicao_mudou=%s" % str((player as Node3D).global_position.distance_to(position_before) > 0.01))
	print("PROBE API toggle_overlay=%s toggle_noclip=%s teleport_to_aim=%s" % [
		str(overlay.call("toggle_overlay")), str(overlay.call("toggle_noclip")), str(overlay.call("teleport_to_aim"))])
	print("PROBE FIM")
	quit(0)


func _push_key(code: Key) -> void:
	var event: InputEventKey = InputEventKey.new()
	event.physical_keycode = code
	event.pressed = true
	root.push_input(event)

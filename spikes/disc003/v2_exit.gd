extends SceneTree
## DISC-003 V2: script headless retorna 0 ou 1 conforme o resultado.
## Uso: godot --headless --path spikes/disc003 --script res://v2_exit.gd -- pass|fail

func _initialize() -> void:
	var want_fail: bool = OS.get_cmdline_user_args().has("fail")
	print("V2: script headless em execucao; want_fail=%s" % want_fail)
	quit(1 if want_fail else 0)

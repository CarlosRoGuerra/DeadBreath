extends SceneTree
## Sonda de persistência do QA (F1-011, ACC-06 e ACC-05 em processos reais). Dois processos em sequência, com o mesmo
## user://: o primeiro grava (`-- write`), o segundo só lê (`-- read`) e compara com o esperado. Não usa nomes de classe
## nem autoloads no script principal (eles só existem depois do primeiro _process). Autor: QA Engineer (F1-011).

const EXPECTED_FOV: float = 90.0
const EXPECTED_SENSITIVITY: float = 0.33
const EXPECTED_INTERACT_KEY: int = 70
const EXPECTED_SUBTITLE_SIZE: float = 1.5

var _started: bool = false


func _process(_delta: float) -> bool:
	if not _started:
		_started = true
		_run()
	return false


func _run() -> void:
	await process_frame
	var mode: String = "read"
	for arg: String in OS.get_cmdline_user_args():
		if arg == "write" or arg == "read":
			mode = arg
	var settings: Node = root.get_node("Settings")
	print("PERSIST modo=%s arquivo=%s" % [mode, str(settings.get("file_path"))])
	if mode == "write":
		settings.call("set_value", &"fov", EXPECTED_FOV)
		settings.call("set_value", &"mouse_sensitivity", EXPECTED_SENSITIVITY)
		settings.call("set_value", &"invert_y", true)
		settings.call("set_value", &"subtitles_size", EXPECTED_SUBTITLE_SIZE)
		settings.call("set_value", &"input_bindings", {"interact": [{"type": "key", "physical_keycode": EXPECTED_INTERACT_KEY}]})
		var err: int = int(settings.call("save_to_disk"))
		print("PERSIST gravado err=%d" % err)
	else:
		var fov: float = float(settings.call("get_value", &"fov"))
		var sensitivity: float = float(settings.call("get_value", &"mouse_sensitivity"))
		var invert: bool = bool(settings.call("get_value", &"invert_y"))
		var subtitles: float = float(settings.call("get_value", &"subtitles_size"))
		var bindings: Dictionary = settings.call("get_value", &"input_bindings") as Dictionary
		var interact_events: Array[InputEvent] = InputMap.action_get_events(&"interact")
		var interact_key: int = -1
		for event: InputEvent in interact_events:
			var key: InputEventKey = event as InputEventKey
			if key != null:
				interact_key = int(key.physical_keycode)
		print("PERSIST lido fov=%.1f sensibilidade=%.2f inverter_y=%s legenda=%.2f" % [fov, sensitivity, str(invert), subtitles])
		print("PERSIST lido input_bindings=%s interact_no_inputmap=%d" % [str(bindings), interact_key])
		var ok: bool = absf(fov - EXPECTED_FOV) < 0.001 and absf(sensitivity - EXPECTED_SENSITIVITY) < 0.001 and invert \
			and absf(subtitles - EXPECTED_SUBTITLE_SIZE) < 0.001 and interact_key == EXPECTED_INTERACT_KEY
		print("PERSIST resultado=%s" % ("OK" if ok else "FALHOU"))
	print("PERSIST FIM")
	quit(0)

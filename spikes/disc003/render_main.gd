extends SceneTree
## DISC-003 V3/V5. Uso (com janela, sem --headless):
##   godot --path spikes/disc003 --resolution 1920x1080 --script res://render_main.gd -- --mode=shot|bench --out=<dir>

const RoomBuilder := preload("res://room_builder.gd")
const BenchProbe := preload("res://bench_probe.gd")


func _initialize() -> void:
	var mode: String = "shot"
	var out_dir: String = ""
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--mode="):
			mode = a.substr(7)
		elif a.begins_with("--out="):
			out_dir = a.substr(6)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	root.add_child(RoomBuilder.build())
	var probe: Node = BenchProbe.new()
	probe.set("mode", mode)
	probe.set("out_dir", out_dir)
	root.add_child(probe)

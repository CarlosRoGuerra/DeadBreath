extends SceneTree
## Ponto de entrada da medição F4-007: `godot --headless --fixed-fps 60 --path game -s res://tests/perf/perf_main.gd --
## --inimigos=1 --run=1`. Não referencia classes do projeto pelo nome (o -s compila antes dos autoloads): carrega o
## harness por load() e passa a configuração por set().

func _initialize() -> void:
	var enemies: int = 1
	var run_index: int = 1
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--inimigos="):
			enemies = int(arg.trim_prefix("--inimigos="))
		elif arg.begins_with("--run="):
			run_index = int(arg.trim_prefix("--run="))
	var harness: Node = (load("res://tests/perf/perf_harness.gd") as GDScript).new() as Node
	harness.set("enemies", clampi(enemies, 1, 3))
	harness.set("run_index", run_index)
	root.add_child(harness)

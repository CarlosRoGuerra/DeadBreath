extends SceneTree
## F3-005 (RSK-13): entrada do spike de corpos dinâmicos. O motor vem de override.cfg (escrito pelo script de execução).
## Uso: godot --headless --fixed-fps 60 --path spikes/f3_physics --script res://physics_dyn_main.gd -- --out=<arquivo.json>

const RUNNER: GDScript = preload("res://dyn_runner.gd")


func _initialize() -> void:
	var runner: Node = RUNNER.new()
	root.add_child(runner)

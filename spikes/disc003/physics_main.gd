extends SceneTree
## DISC-003 V6: pistas de teste (rampa, escada, vão de 0,6 m, obstáculos) para comparar
## Jolt Physics e GodotPhysics3D. O motor vem de override.cfg, escrito pelo script de execução.
## Uso: godot --headless --fixed-fps 60 --path spikes/disc003 --script res://physics_main.gd -- --out=<arquivo.json>

const Mover := preload("res://mover.gd")
const Probe := preload("res://physics_probe.gd")

const STAND_H: float = 1.75
const CRAWL_H: float = 0.55
const RADIUS: float = 0.25


func _initialize() -> void:
	var out_path: String = ""
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out_path = a.substr(6)
	print("physics_engine setting=%s | server_class=%s" % [ProjectSettings.get_setting("physics/3d/physics_engine"), PhysicsServer3D.get_class()])
	var world: Node3D = Node3D.new()
	root.add_child(world)
	_static_box(world, Vector3(60, 1, 110), Vector3(20, -0.5, 33))

	var lanes: Array[Dictionary] = []
	# Rampa de 30 graus até plataforma a 1,5 m
	for z: float in [0.0, 4.0]:
		_ramp(world, 2.0, 1.5, 30.0, z)
	lanes.append(_lane("ramp_up", 0.0, 0.0, 0.0, STAND_H, 1.6, true, 1.0))
	lanes.append(_lane("ramp_idle", 4.0, 0.0, 0.0, STAND_H, 1.6, true, 1.0))
	# Escada de 8 degraus: espelho 0,18 m, piso 0,28 m, plataforma a 1,44 m
	for z: float in [8.0, 12.0, 16.0]:
		_stairs(world, 2.0, 8, 0.18, 0.28, z)
	lanes.append(_lane("stairs_up_stepup", 8.0, 0.0, 0.0, STAND_H, 1.6, true, 1.0))
	lanes.append(_lane("stairs_up_raw", 12.0, 0.0, 0.0, STAND_H, 1.6, false, 1.0))
	lanes.append(_lane("stairs_down", 16.0, 6.5, 1.44, STAND_H, 1.6, true, -1.0))
	# Vão: laje com face inferior a 0,6 m entre x=3 e x=5
	for z: float in [20.0, 24.0]:
		_static_box(world, Vector3(2, 0.2, 2), Vector3(4, 0.7, z))
	lanes.append(_lane("gap_crawl", 20.0, 0.0, 0.0, CRAWL_H, 0.5, true, 1.0))
	lanes.append(_lane("gap_stand", 24.0, 0.0, 0.0, STAND_H, 1.6, true, 1.0))
	# Obstáculos: 0,35 m (acima de step_height) e 0,29 m (abaixo)
	_static_box(world, Vector3(0.5, 0.35, 2), Vector3(3.25, 0.175, 28))
	_static_box(world, Vector3(0.5, 0.29, 2), Vector3(3.25, 0.145, 32))
	lanes.append(_lane("obstacle_035", 28.0, 0.0, 0.0, STAND_H, 1.6, true, 1.0))
	lanes.append(_lane("obstacle_029", 32.0, 0.0, 0.0, STAND_H, 1.6, true, 1.0))
	# Mesmas pistas com CylinderShape3D (alternativa à cápsula para o jogador)
	for z: float in [36.0, 40.0]:
		_ramp(world, 2.0, 1.5, 30.0, z)
	for z: float in [44.0, 48.0]:
		_stairs(world, 2.0, 8, 0.18, 0.28, z)
	_static_box(world, Vector3(0.5, 0.29, 2), Vector3(3.25, 0.145, 52))
	_static_box(world, Vector3(0.5, 0.35, 2), Vector3(3.25, 0.175, 56))
	_static_box(world, Vector3(2, 0.2, 2), Vector3(4, 0.7, 60))
	lanes.append(_lane("ramp_up", 36.0, 0.0, 0.0, STAND_H, 1.6, true, 1.0, "cylinder"))
	lanes.append(_lane("ramp_idle", 40.0, 0.0, 0.0, STAND_H, 1.6, true, 1.0, "cylinder"))
	lanes.append(_lane("stairs_up_stepup", 44.0, 0.0, 0.0, STAND_H, 1.6, true, 1.0, "cylinder"))
	lanes.append(_lane("stairs_down", 48.0, 6.5, 1.44, STAND_H, 1.6, true, -1.0, "cylinder"))
	lanes.append(_lane("obstacle_029", 52.0, 0.0, 0.0, STAND_H, 1.6, true, 1.0, "cylinder"))
	lanes.append(_lane("obstacle_035", 56.0, 0.0, 0.0, STAND_H, 1.6, true, 1.0, "cylinder"))
	lanes.append(_lane("gap_crawl", 60.0, 0.0, 0.0, CRAWL_H, 0.5, true, 1.0, "cylinder"))

	var bodies: Array[CharacterBody3D] = []
	for lane: Dictionary in lanes:
		bodies.append(_spawn(world, lane))
	var probe: Node = Probe.new()
	probe.set("lanes", lanes)
	probe.set("bodies", bodies)
	probe.set("out_path", out_path)
	probe.set("stand_shape_height", STAND_H)
	probe.set("radius", RADIUS)
	probe.process_physics_priority = 100
	world.add_child(probe)


func _lane(kind: String, z: float, start_x: float, start_y: float, h: float, spd: float, step: bool, dir: float, shape: String = "capsule") -> Dictionary:
	var prefix: String = "cyl_" if shape == "cylinder" else ""
	return {"name": prefix + kind, "kind": kind, "shape": shape, "z": z, "start_x": start_x, "start_y": start_y, "h": h, "speed": spd, "step": step, "dir": dir}


func _spawn(parent: Node3D, lane: Dictionary) -> CharacterBody3D:
	var body: CharacterBody3D = Mover.new()
	var h: float = lane["h"]
	var col: CollisionShape3D = CollisionShape3D.new()
	if lane["shape"] == "cylinder":
		var cyl: CylinderShape3D = CylinderShape3D.new()
		cyl.height = h
		cyl.radius = RADIUS
		col.shape = cyl
	else:
		var cap: CapsuleShape3D = CapsuleShape3D.new()
		cap.height = h
		cap.radius = RADIUS
		col.shape = cap
	col.position = Vector3(0, h * 0.5, 0)
	body.add_child(col)
	body.floor_max_angle = deg_to_rad(45.0)
	body.floor_snap_length = 0.3
	body.floor_stop_on_slope = true
	body.set("speed", lane["speed"])
	body.set("use_step_up", lane["step"])
	body.set("move_dir", Vector3(float(lane["dir"]), 0, 0))
	body.position = Vector3(float(lane["start_x"]), float(lane["start_y"]) + 0.02, float(lane["z"]))
	body.name = String(lane["name"])
	parent.add_child(body)
	return body


func _static_box(parent: Node3D, size: Vector3, center: Vector3) -> void:
	var sb: StaticBody3D = StaticBody3D.new()
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = size
	var col: CollisionShape3D = CollisionShape3D.new()
	col.shape = shape
	sb.add_child(col)
	sb.position = center
	parent.add_child(sb)


func _ramp(parent: Node3D, x0: float, h: float, angle_deg: float, z: float) -> void:
	var run: float = h / tan(deg_to_rad(angle_deg))
	var x1: float = x0 + run
	var sb: StaticBody3D = StaticBody3D.new()
	var shape: ConvexPolygonShape3D = ConvexPolygonShape3D.new()
	shape.points = PackedVector3Array([
		Vector3(x0, 0, z - 1), Vector3(x0, 0, z + 1), Vector3(x1, 0, z - 1), Vector3(x1, 0, z + 1),
		Vector3(x1, h, z - 1), Vector3(x1, h, z + 1)])
	var col: CollisionShape3D = CollisionShape3D.new()
	col.shape = shape
	sb.add_child(col)
	parent.add_child(sb)
	_static_box(parent, Vector3(4, h, 2), Vector3(x1 + 2, h * 0.5, z))


func _stairs(parent: Node3D, x0: float, steps: int, rise: float, tread: float, z: float) -> void:
	var x_end: float = x0 + steps * tread
	for i: int in steps:
		var x_start: float = x0 + i * tread
		var top: float = (i + 1) * rise
		_static_box(parent, Vector3(x_end - x_start, top, 2), Vector3((x_start + x_end) * 0.5, top * 0.5, z))
	var top_h: float = steps * rise
	_static_box(parent, Vector3(4, top_h, 2), Vector3(x_end + 2, top_h * 0.5, z))

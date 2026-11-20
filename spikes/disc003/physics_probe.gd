extends Node
## DISC-003 V6: coleta métricas por pista e avalia as expectativas.

const MAX_TICKS: int = 1500
const IDLE_TICKS: int = 120

var lanes: Array[Dictionary] = []
var bodies: Array[CharacterBody3D] = []
var out_path: String = ""
var stand_shape_height: float = 1.75
var radius: float = 0.25

var _tick: int = 0
var _stats: Array[Dictionary] = []
var _start_usec: int = 0


func _ready() -> void:
	_start_usec = Time.get_ticks_usec()
	for lane: Dictionary in lanes:
		_stats.append({"name": lane["name"], "done": false, "pass": false, "reached_tick": -1,
			"max_x": -INF, "min_x": INF, "max_dy_tick": 0.0, "airborne_ticks": 0, "moving_ticks": 0,
			"z_drift": 0.0, "last_y": INF, "idle_start": Vector3.ZERO, "idle_tick": -1, "idle_drift": -1.0,
			"ceil_checks_under": 0, "ceil_blocked_under": 0, "ceil_checks_out": 0, "ceil_blocked_out": 0})


func _physics_process(_dt: float) -> void:
	_tick += 1
	for i: int in bodies.size():
		_track(lanes[i], bodies[i], _stats[i])
	var all_done: bool = true
	for s: Dictionary in _stats:
		all_done = all_done and bool(s["done"])
	if all_done or _tick >= MAX_TICKS:
		set_physics_process(false)
		_finish()


func _track(lane: Dictionary, body: CharacterBody3D, s: Dictionary) -> void:
	if s["done"]:
		return
	var p: Vector3 = body.global_position
	var lane_name: String = lane["kind"]
	s["max_x"] = maxf(s["max_x"], p.x)
	s["min_x"] = minf(s["min_x"], p.x)
	s["z_drift"] = maxf(s["z_drift"], absf(p.z - float(lane["z"])))
	if float(s["last_y"]) != INF and _tick > 10:
		s["max_dy_tick"] = maxf(s["max_dy_tick"], absf(p.y - float(s["last_y"])))
	s["last_y"] = p.y
	if float(body.get("speed")) > 0.0 and _tick > 10:
		s["moving_ticks"] = int(s["moving_ticks"]) + 1
		if not body.is_on_floor():
			s["airborne_ticks"] = int(s["airborne_ticks"]) + 1
	match lane_name:
		"ramp_up":
			_goal(s, p.x >= 6.0 and p.y >= 1.45)
		"stairs_up_stepup":
			_goal(s, p.x >= 6.0 and p.y >= 1.40)
		"obstacle_029":
			_goal(s, p.x >= 4.5)
		"stairs_down":
			_goal(s, p.x <= 0.5 and p.y < 0.05)
		"gap_crawl":
			_ceiling_check(body, s, p)
			if p.x >= 6.0:
				s["done"] = true
				s["reached_tick"] = _tick
				s["pass"] = int(s["ceil_checks_under"]) > 0 and int(s["ceil_blocked_under"]) == int(s["ceil_checks_under"]) and int(s["ceil_blocked_out"]) == 0
		"ramp_idle":
			if int(s["idle_tick"]) < 0 and p.x >= 3.3:
				body.set("speed", 0.0)
				s["idle_tick"] = _tick
				s["idle_start"] = p
			elif int(s["idle_tick"]) >= 0 and _tick - int(s["idle_tick"]) >= IDLE_TICKS:
				s["idle_drift"] = p.distance_to(s["idle_start"])
				s["done"] = true
				s["pass"] = float(s["idle_drift"]) < 0.02
		"stairs_up_raw", "gap_stand", "obstacle_035":
			if _tick >= 300:
				s["done"] = true
				# stairs_up_raw é informativo (mostra se o motor sobe degraus sem step-up)
				s["pass"] = true if lane_name == "stairs_up_raw" else float(s["max_x"]) < 2.8


func _goal(s: Dictionary, reached: bool) -> void:
	if reached:
		s["done"] = true
		s["pass"] = true
		s["reached_tick"] = _tick


func _ceiling_check(body: CharacterBody3D, s: Dictionary, p: Vector3) -> void:
	var under: bool = p.x >= 3.3 and p.x <= 4.7
	var outside: bool = p.x <= 1.5 or p.x >= 5.6
	if not under and not outside:
		return
	var shape: CapsuleShape3D = CapsuleShape3D.new()
	shape.height = stand_shape_height
	shape.radius = radius
	var params: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
	params.shape = shape
	params.transform = Transform3D(Basis(), p + Vector3(0, stand_shape_height * 0.5 + 0.01, 0))
	params.exclude = [body.get_rid()]
	var hits: Array[Dictionary] = body.get_world_3d().direct_space_state.intersect_shape(params, 1)
	var blocked: bool = not hits.is_empty()
	if under:
		s["ceil_checks_under"] = int(s["ceil_checks_under"]) + 1
		if blocked:
			s["ceil_blocked_under"] = int(s["ceil_blocked_under"]) + 1
	else:
		s["ceil_checks_out"] = int(s["ceil_checks_out"]) + 1
		if blocked:
			s["ceil_blocked_out"] = int(s["ceil_blocked_out"]) + 1


func _finish() -> void:
	var wall_ms: float = (Time.get_ticks_usec() - _start_usec) / 1000.0
	var all_pass: bool = true
	for i: int in _stats.size():
		var s: Dictionary = _stats[i]
		s["final_pos"] = str(bodies[i].global_position)
		s["step_ups"] = bodies[i].get("step_ups")
		s.erase("last_y")
		s.erase("idle_start")
		all_pass = all_pass and bool(s["pass"])
		print("%-18s pass=%-5s reached_tick=%4d max_x=%.3f final=%s max_dy_tick=%.3f airborne=%d/%d z_drift=%.4f idle_drift=%.4f step_ups=%d ceil_under=%d/%d ceil_out=%d/%d" % [
			s["name"], s["pass"], s["reached_tick"], s["max_x"], s["final_pos"], s["max_dy_tick"],
			s["airborne_ticks"], s["moving_ticks"], s["z_drift"], s["idle_drift"], s["step_ups"],
			s["ceil_blocked_under"], s["ceil_checks_under"], s["ceil_blocked_out"], s["ceil_checks_out"]])
	print("ticks=%d | wall_ms=%.1f | ALL_PASS=%s" % [_tick, wall_ms, all_pass])
	if out_path != "":
		var f: FileAccess = FileAccess.open(out_path, FileAccess.WRITE)
		if f != null:
			f.store_string(JSON.stringify({"engine": ProjectSettings.get_setting("physics/3d/physics_engine"),
				"ticks": _tick, "wall_ms": wall_ms, "all_pass": all_pass, "lanes": _stats}, "  "))
			f.close()
	get_tree().quit(0 if all_pass else 1)

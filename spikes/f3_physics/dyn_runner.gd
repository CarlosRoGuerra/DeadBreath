extends Node
## F3-005 (RSK-13): corpos dinâmicos no motor escolhido por override.cfg (GodotPhysics3D ou Jolt Physics).
## Cada cenário roda num mundo próprio, a 60 ticks/s fixos (--fixed-fps 60), e as métricas vão para JSON.
## Descartável: não é o jogo. Autor: Gameplay Engineer (F3-005).

const PLAYER_SCRIPT: GDScript = preload("res://dyn_player.gd")
const SCENARIOS = [
	"stack_5", "throw_wall", "drop_floor",
	"tunnel_15_nocd", "tunnel_15_cd", "tunnel_40_nocd", "tunnel_40_cd",
	"player_push", "player_kick", "cost_30",
]
const STACK_TICKS: int = 600
const JITTER_FROM_TICK: int = 300
const THROW_TICKS: int = 240
const DROP_TICKS: int = 300
const TUNNEL_TICKS: int = 60
const PLAYER_TICKS: int = 120
const COST_TICKS: int = 300
const WALL_CONTACT_X: float = 1.75  ## face da parede (2,0 - 0,15) menos meia caixa (0,1)

var out_path: String = ""
var _index: int = -1
var _tick: int = 0
var _world: Node3D = null
var _bodies: Array[RigidBody3D] = []
var _initial: Array[Vector3] = []
var _last: Array[Vector3] = []
var _player: CharacterBody3D = null
var _m: Dictionary = {}
var _results: Dictionary = {}


func _ready() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_path = arg.substr(6)


func _physics_process(_delta: float) -> void:
	if _index < 0:
		_begin(0)
		return
	_tick += 1
	var scenario: String = SCENARIOS[_index]
	if _step(scenario):
		_results[scenario] = _finish(scenario)
		print("F3005 %s %s" % [scenario, JSON.stringify(_results[scenario])])
		if _index + 1 < SCENARIOS.size():
			_begin(_index + 1)
		else:
			_write_and_quit()


func _begin(i: int) -> void:
	_index = i
	_tick = 0
	_m = {}
	_bodies.clear()
	_initial.clear()
	_last.clear()
	_player = null
	_new_world()
	var scenario: String = SCENARIOS[i]
	if scenario == "stack_5":
		_setup_stack()
	elif scenario == "throw_wall":
		_setup_throw()
	elif scenario == "drop_floor":
		_setup_drop()
	elif scenario.begins_with("tunnel_"):
		_setup_tunnel(scenario)
	elif scenario.begins_with("player_"):
		_setup_player(scenario == "player_kick")
	else:
		_setup_cost()


func _new_world() -> void:
	if _world != null:
		remove_child(_world)
		_world.free()
	_world = Node3D.new()
	add_child(_world)
	_static_box(Vector3(0.0, -0.5, 0.0), Vector3(40.0, 1.0, 40.0), _mat(0.2, 0.2))


func _mat(bounce: float, friction: float) -> PhysicsMaterial:
	var material: PhysicsMaterial = PhysicsMaterial.new()
	material.bounce = bounce
	material.friction = friction
	return material


func _box_shape(size: Vector3) -> CollisionShape3D:
	var node: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = size
	node.shape = box
	return node


func _sphere_shape(radius: float) -> CollisionShape3D:
	var node: CollisionShape3D = CollisionShape3D.new()
	var sphere: SphereShape3D = SphereShape3D.new()
	sphere.radius = radius
	node.shape = sphere
	return node


func _static_box(pos: Vector3, size: Vector3, material: PhysicsMaterial) -> StaticBody3D:
	var body: StaticBody3D = StaticBody3D.new()
	body.position = pos
	body.physics_material_override = material
	body.add_child(_box_shape(size))
	_world.add_child(body)
	return body


func _rigid(pos: Vector3, shape: CollisionShape3D, mass: float, material: PhysicsMaterial) -> RigidBody3D:
	var body: RigidBody3D = RigidBody3D.new()
	body.position = pos
	body.mass = mass
	body.physics_material_override = material
	body.add_child(shape)
	_world.add_child(body)
	_bodies.append(body)
	return body


func _snapshot() -> void:
	_initial = _positions()
	_last = _positions()


func _positions() -> Array[Vector3]:
	var out: Array[Vector3] = []
	for body: RigidBody3D in _bodies:
		out.append(body.global_position)
	return out


func _setup_stack() -> void:
	for i: int in 5:
		_rigid(Vector3(-10.0, 0.2 + 0.4 * float(i), 0.0), _box_shape(Vector3(0.4, 0.4, 0.4)), 1.0, _mat(0.0, 0.5))
	_snapshot()
	_m["sleep_tick"] = -1


func _setup_throw() -> void:
	_static_box(Vector3(2.0, 1.5, 0.0), Vector3(0.3, 3.0, 4.0), _mat(0.3, 0.2))
	## Sem gravidade e fora do piso: só o impacto na parede decide o quique (sem atrito de piso).
	var box: RigidBody3D = _rigid(Vector3(-1.5, 0.5, 0.0), _box_shape(Vector3(0.2, 0.2, 0.2)), 1.0, _mat(0.3, 0.2))
	box.gravity_scale = 0.0
	box.linear_velocity = Vector3(6.0, 0.0, 0.0)
	_snapshot()


func _setup_drop() -> void:
	_rigid(Vector3(0.0, 1.0, 0.0), _sphere_shape(0.1), 1.0, _mat(0.5, 0.2))
	_snapshot()
	_m["state"] = 0
	_m["prev_y"] = 1.0


func _setup_tunnel(scenario: String) -> void:
	var speed: float = 15.0 if scenario.begins_with("tunnel_15") else 40.0
	var continuous: bool = scenario.ends_with("_cd")
	var ball: RigidBody3D = _rigid(Vector3(-2.0, 0.5, 0.0), _sphere_shape(0.02), 0.05, _mat(0.0, 0.0))
	ball.gravity_scale = 0.0
	ball.continuous_cd = continuous
	ball.linear_velocity = Vector3(speed, 0.0, 0.0)
	_static_box(Vector3(0.0, 0.5, 0.0), Vector3(0.01, 2.0, 4.0), _mat(0.0, 0.0))
	_m["speed_ms"] = speed
	_m["continuous_cd"] = continuous
	_snapshot()


func _setup_player(kick: bool) -> void:
	_rigid(Vector3(1.5, 0.15, 0.0), _box_shape(Vector3(0.3, 0.3, 0.3)), 0.5, _mat(0.0, 0.5))
	_player = CharacterBody3D.new()
	_player.set_script(PLAYER_SCRIPT)
	var node: CollisionShape3D = CollisionShape3D.new()
	var capsule: CapsuleShape3D = CapsuleShape3D.new()
	capsule.radius = 0.25
	capsule.height = 1.75
	node.shape = capsule
	_player.add_child(node)
	_player.position = Vector3(-1.0, 0.9, 0.0)
	_world.add_child(_player)
	_snapshot()
	_m["box_x0"] = 1.5
	_m["kick"] = kick
	_m["kicked"] = false


func _setup_cost() -> void:
	for i: int in 30:
		var col: int = i % 10
		var row: int = i / 10
		_rigid(Vector3(-1.575 + 0.35 * float(col), 0.6 + 0.02 * float(i), -0.35 + 0.35 * float(row)), _box_shape(Vector3(0.3, 0.3, 0.3)), 1.0, _mat(0.0, 0.5))
	_snapshot()


func _step(scenario: String) -> bool:
	if scenario == "stack_5":
		return _step_stack()
	if scenario == "throw_wall":
		return _step_throw()
	if scenario == "drop_floor":
		return _step_drop()
	if scenario.begins_with("tunnel_"):
		return _step_tunnel()
	if scenario.begins_with("player_"):
		return _step_player()
	return _step_cost()


func _step_stack() -> bool:
	var pos: Array[Vector3] = _positions()
	var max_drift: float = float(_m.get("max_drift_xz_m", 0.0))
	var max_tilt: float = float(_m.get("max_tilt_deg", 0.0))
	var all_sleep: bool = true
	for i: int in _bodies.size():
		var p: Vector3 = pos[i]
		max_drift = maxf(max_drift, Vector2(p.x - _initial[i].x, p.z - _initial[i].z).length())
		var cos_tilt: float = clampf(_bodies[i].global_transform.basis.y.dot(Vector3.UP), -1.0, 1.0)
		max_tilt = maxf(max_tilt, rad_to_deg(acos(cos_tilt)))
		if _tick >= JITTER_FROM_TICK:
			_m["jitter_sum_m"] = float(_m.get("jitter_sum_m", 0.0)) + (p - _last[i]).length()
			_m["jitter_n"] = int(_m.get("jitter_n", 0)) + 1
		all_sleep = all_sleep and _bodies[i].sleeping
	if all_sleep and int(_m["sleep_tick"]) < 0:
		_m["sleep_tick"] = _tick
	_m["max_drift_xz_m"] = max_drift
	_m["max_tilt_deg"] = max_tilt
	_m["top_center_sink_m"] = _initial[4].y - pos[4].y
	_m["all_sleeping_at_end"] = all_sleep
	_last = pos
	return _tick >= STACK_TICKS


func _step_throw() -> bool:
	var body: RigidBody3D = _bodies[0]
	var x: float = body.global_position.x
	var vx: float = body.linear_velocity.x
	if not _m.has("impact_vx") and x > WALL_CONTACT_X:
		_m["impact_vx"] = float(_m.get("vx_prev", vx))
		_m["impact_tick"] = _tick
	if _m.has("impact_vx"):
		_m["min_vx_after_impact"] = minf(float(_m.get("min_vx_after_impact", 0.0)), vx)
	_m["vx_prev"] = vx
	_m["max_x"] = maxf(float(_m.get("max_x", -INF)), x)
	_m["min_y"] = minf(float(_m.get("min_y", INF)), body.global_position.y)
	_m["final_x"] = x
	_m["final_speed"] = body.linear_velocity.length()
	_m["final_sleeping"] = body.sleeping
	return _tick >= THROW_TICKS


func _step_drop() -> bool:
	var body: RigidBody3D = _bodies[0]
	var y: float = body.global_position.y
	var prev: float = float(_m["prev_y"])
	var state: int = int(_m["state"])
	if state == 0 and y > prev:
		_m["state"] = 1
		_m["impact_y"] = prev
		_m["rise_apex_y"] = y
	elif state == 1:
		_m["rise_apex_y"] = maxf(float(_m["rise_apex_y"]), y)
		if y < prev:
			_m["state"] = 2
	_m["prev_y"] = y
	_m["min_y"] = minf(float(_m.get("min_y", INF)), y)
	_m["final_speed"] = body.linear_velocity.length()
	_m["final_sleeping"] = body.sleeping
	return _tick >= DROP_TICKS


func _step_tunnel() -> bool:
	var body: RigidBody3D = _bodies[0]
	var x: float = body.global_position.x
	_m["max_x"] = maxf(float(_m.get("max_x", -INF)), x)
	_m["final_x"] = x
	_m["final_speed"] = body.linear_velocity.length()
	return x > 0.5 or _tick >= TUNNEL_TICKS


func _step_player() -> bool:
	var box: RigidBody3D = _bodies[0]
	var bx: float = box.global_position.x
	var px: float = _player.global_position.x
	if bool(_m["kick"]) and not bool(_m["kicked"]) and px > bx - 0.6:
		box.apply_central_impulse(Vector3(box.mass * 4.0, 0.0, 0.0))
		_m["kicked"] = true
		_m["kick_tick"] = _tick
	_m["box_max_x"] = maxf(float(_m.get("box_max_x", -INF)), bx)
	_m["box_max_speed_ms"] = maxf(float(_m.get("box_max_speed_ms", 0.0)), box.linear_velocity.length())
	_m["gap_min_m"] = minf(float(_m.get("gap_min_m", INF)), bx - px)
	_m["player_x"] = px
	_m["box_x"] = bx
	_m["player_on_floor"] = _player.is_on_floor()
	return _tick >= PLAYER_TICKS


func _step_cost() -> bool:
	## Tempo do passo físico pelo monitor do motor (só vale com janela: em headless o monitor retorna 0).
	var ms: float = Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
	if _tick > 1:
		_m["step_ms_sum"] = float(_m.get("step_ms_sum", 0.0)) + ms
		_m["step_ms_max"] = maxf(float(_m.get("step_ms_max", 0.0)), ms)
		_m["step_samples"] = int(_m.get("step_samples", 0)) + 1
	var sleeping: int = 0
	for body: RigidBody3D in _bodies:
		if body.sleeping:
			sleeping += 1
	_m["sleeping_at_end"] = sleeping
	_m["active_bodies"] = _bodies.size()
	return _tick >= COST_TICKS


func _finish(scenario: String) -> Dictionary:
	if scenario == "stack_5":
		var n: int = int(_m.get("jitter_n", 0))
		_m["jitter_mm_per_tick_last5s"] = 1000.0 * float(_m.get("jitter_sum_m", 0.0)) / maxf(float(n), 1.0)
	elif scenario == "throw_wall":
		var impacted: bool = _m.has("impact_vx")
		_m["reached_wall"] = impacted
		_m["passed_through_wall"] = float(_m["max_x"]) > 2.15
		_m["rebound_ratio"] = -float(_m["min_vx_after_impact"]) / float(_m["impact_vx"]) if impacted else 0.0
		_m["penetrated_floor"] = float(_m["min_y"]) < -0.02
	elif scenario == "drop_floor":
		_m["bounce_rise_m"] = float(_m.get("rise_apex_y", 0.0)) - float(_m.get("impact_y", 0.0))
		_m["penetrated_floor"] = float(_m["min_y"]) < 0.05
	elif scenario.begins_with("tunnel_"):
		_m["passed_through_wall"] = float(_m["max_x"]) > 0.03
	elif scenario.begins_with("player_"):
		_m["box_displacement_m"] = float(_m["box_x"]) - float(_m["box_x0"])
		_m["player_passed_box"] = float(_m["player_x"]) > float(_m["box_x"])
	if scenario == "cost_30":
		_m["step_ms_avg"] = float(_m.get("step_ms_sum", 0.0)) / maxf(float(_m.get("step_samples", 0)), 1.0)
	return _m.duplicate()


func _write_and_quit() -> void:
	var doc: Dictionary = {
		"physics_engine_setting": str(ProjectSettings.get_setting("physics/3d/physics_engine")),
		"ticks_per_second": Engine.physics_ticks_per_second,
		"scenarios": _results,
	}
	if out_path != "":
		var file: FileAccess = FileAccess.open(out_path, FileAccess.WRITE)
		if file != null:
			file.store_string(JSON.stringify(doc, "  "))
			file.close()
	print("F3005_DONE engine=%s out=%s" % [doc["physics_engine_setting"], out_path])
	get_tree().quit(0)

extends TestCase
## BUG-001 (Docs/QA/BUG_REPORTS.md): o step-up não pode deixar o corpo sem chão numa escada real.
## Critério: 0 ticks com is_on_floor() == false subindo e descendo (a) uma escada de 8 degraus de 0,18 m com
## piso de 0,28 m e de 0,30 m e (b) a escada da sandbox (content/levels/sandbox.tscn, 6 degraus de 0,18 m, piso
## de 0,30 m), carregando a própria cena. Física em tick fixo de 1/60 s. Autor: Gameplay Engineer (F1-006).

const WorldScript := preload("res://tests/integration/player/fixtures/player_world.gd")
const SANDBOX_PATH: String = "res://content/levels/sandbox.tscn"

const STEPS: int = 8
const RISE_M: float = 0.18
const FIRST_NEAR_Z: float = -1.0
const SETTLE_FRAMES: int = 8
const MAX_FRAMES: int = 500
const PLATFORM_EXTRA_M: float = 1.5
const PLATFORM_WALK_FRAMES: int = 40
const FLOOR_Y_TOLERANCE_M: float = 0.02
const SANDBOX_SPAWN: Vector3 = Vector3(17.0, 0.0, -0.5)
const SANDBOX_STAIR_TOP_Y_M: float = 1.08
const SANDBOX_STAIR_END_Z_M: float = -3.1
const SANDBOX_STAIR_START_Z_M: float = -1.0
const SANDBOX_STAIR_X_M: float = 17.0

var _airborne: int = 0
var _airborne_up: int = 0
var _airborne_down: int = 0


func before_all() -> void:
	Settings.autosave = false


func after_all() -> void:
	Settings.autosave = true


func before_each() -> void:
	_airborne = 0
	_airborne_up = 0
	_airborne_down = 0


## Escada de STEPS degraus com espelho RISE_M e piso tread, ao longo de -Z, em x = 0.
func _build_stairs(root: Node3D, tread: float) -> float:
	WorldScript.add_box(root, Vector3(0.0, -0.5, -6.0), Vector3(2.4, 1.0, 16.0), &"wood")
	for index: int in STEPS:
		var top: float = RISE_M * float(index + 1)
		var near_z: float = FIRST_NEAR_Z - tread * float(index)
		var center_z: float = near_z - tread * 0.5
		WorldScript.add_box(root, Vector3(0.0, (top - 1.0) * 0.5, center_z), Vector3(2.4, top + 1.0, tread), &"wood")
	var platform_top: float = RISE_M * float(STEPS)
	var platform_start: float = FIRST_NEAR_Z - tread * float(STEPS)
	var platform_len: float = PLATFORM_EXTRA_M + 1.0
	WorldScript.add_box(root, Vector3(0.0, (platform_top - 1.0) * 0.5, platform_start - platform_len * 0.5),
		Vector3(2.4, platform_top + 1.0, platform_len), &"wood")
	return platform_start


## Conta ticks sem chão; direction > 0 subindo, < 0 descendo, 0 fora de escada.
func _count(player: PlayerRoot, direction: int) -> void:
	if player.is_on_floor():
		return
	_airborne += 1
	if direction > 0:
		_airborne_up += 1
	elif direction < 0:
		_airborne_down += 1


func _walk(player: PlayerRoot, move_y: float, done: Callable, direction: int) -> bool:
	player.get_motor().set_scripted_input(WorldScript.move_input(Vector2(0.0, move_y)))
	var frames: int = 0
	while frames < MAX_FRAMES:
		await wait_physics_frames(1)
		frames += 1
		_count(player, direction)
		if _reached(player, done):
			break
	player.get_motor().set_scripted_input(MotorInput.new())
	return _reached(player, done)


## done: "up" = z abaixo do patamar e y no patamar; "down" = de volta ao piso.
func _reached(player: PlayerRoot, done: Callable) -> bool:
	return done.call(player) as bool


func _is_up_done(player: PlayerRoot, limit_z: float) -> bool:
	return player.global_position.z < limit_z and player.global_position.y > RISE_M * float(STEPS) - FLOOR_Y_TOLERANCE_M


func _is_down_done(player: PlayerRoot) -> bool:
	return player.global_position.z > FIRST_NEAR_Z + 0.5 and player.global_position.y < 0.1


func _run_stairs(tread: float, start_z: float = 0.5) -> Dictionary:
	var root: Node3D = add_child_autofree(Node3D.new()) as Node3D
	var platform_start: float = _build_stairs(root, tread)
	var player: PlayerRoot = WorldScript.spawn_player(root, Vector3(0.0, 0.0, start_z))
	await wait_physics_frames(SETTLE_FRAMES)
	var limit_z: float = platform_start - PLATFORM_EXTRA_M * 0.5
	var up_ok: bool = await _walk(player, 1.0, Callable(self, "_done_up_factory").bind(limit_z), 1)
	await wait_physics_frames(PLATFORM_WALK_FRAMES)
	var down_ok: bool = await _walk(player, -1.0, Callable(self, "_done_down_factory"), -1)
	return {"up_ok": up_ok, "down_ok": down_ok, "airborne_up": _airborne_up, "airborne_down": _airborne_down}


func _done_up_factory(player: PlayerRoot, limit_z: float) -> bool:
	return _is_up_done(player, limit_z)


func _done_down_factory(player: PlayerRoot) -> bool:
	return _is_down_done(player)


func test_bug001_escada_piso_0_28_sem_ticks_no_ar() -> void:
	var result: Dictionary = await _run_stairs(0.28)
	assert_true(result["up_ok"] as bool, "subiu até o patamar")
	assert_true(result["down_ok"] as bool, "desceu até o piso")
	assert_eq(result["airborne_up"], 0, "subida: ticks sem chão (BUG-001)")
	assert_eq(result["airborne_down"], 0, "descida: ticks sem chão (BUG-001)")


func test_bug001_escada_piso_0_30_sem_ticks_no_ar() -> void:
	var result: Dictionary = await _run_stairs(0.30)
	assert_true(result["up_ok"] as bool, "subiu até o patamar")
	assert_true(result["down_ok"] as bool, "desceu até o piso")
	assert_eq(result["airborne_up"], 0, "subida: ticks sem chão (BUG-001)")
	assert_eq(result["airborne_down"], 0, "descida: ticks sem chão (BUG-001)")


## Varredura de fase: a falha depende de onde a borda do degrau cai no ciclo do passo. Cada teste varre
## PHASE_COUNT posições iniciais (PHASE_STEP_M de intervalo) num piso e exige 0 ticks no ar, subindo e descendo.
## Um teste por piso, para ficar abaixo do watchdog de 15 s.
const PHASE_STEP_M: float = 0.02
const PHASE_COUNT: int = 6


func _sweep(tread: float) -> PackedStringArray:
	var failures: PackedStringArray = PackedStringArray()
	for index: int in PHASE_COUNT:
		var start_z: float = 0.5 - PHASE_STEP_M * float(index)
		var result: Dictionary = await _run_stairs(tread, start_z)
		if not (result["up_ok"] as bool and result["down_ok"] as bool):
			failures.append("fase %d: não completou a escada" % index)
		if int(result["airborne_up"]) + int(result["airborne_down"]) > 0:
			failures.append("fase %d: ticks no ar subida=%d descida=%d" % [index, int(result["airborne_up"]), int(result["airborne_down"])])
	return failures


func test_bug001_varredura_de_fase_piso_0_28() -> void:
	var failures: PackedStringArray = await _sweep(0.28)
	assert_eq(failures.size(), 0, "varredura de fase, piso 0,28 (BUG-001): " + "; ".join(failures))


func test_bug001_varredura_de_fase_piso_0_30() -> void:
	var failures: PackedStringArray = await _sweep(0.30)
	assert_eq(failures.size(), 0, "varredura de fase, piso 0,30 (BUG-001): " + "; ".join(failures))


func test_bug001_escada_da_sandbox_sem_ticks_no_ar() -> void:
	var packed: PackedScene = load(SANDBOX_PATH) as PackedScene
	assert_not_null(packed, "a sandbox carrega")
	if packed == null:
		return
	var level: Node3D = add_child_autofree(packed.instantiate()) as Node3D
	var player: PlayerRoot = level.get_node("Player") as PlayerRoot
	assert_not_null(player, "a sandbox tem o Player")
	if player == null:
		return
	player.global_position = SANDBOX_SPAWN
	await wait_physics_frames(SETTLE_FRAMES)
	var up_ok: bool = await _walk(player, 1.0, Callable(self, "_done_sandbox_up"), 1)
	assert_true(up_ok, "subiu a escada da sandbox (z = %f, y = %f)" % [player.global_position.z, player.global_position.y])
	assert_eq(_airborne_up, 0, "sandbox, subida: ticks sem chão (BUG-001)")
	await wait_physics_frames(PLATFORM_WALK_FRAMES)
	var down_ok: bool = await _walk(player, -1.0, Callable(self, "_done_sandbox_down"), -1)
	assert_true(down_ok, "desceu a escada da sandbox (z = %f, y = %f)" % [player.global_position.z, player.global_position.y])
	assert_eq(_airborne_down, 0, "sandbox, descida: ticks sem chão (BUG-001)")


func _done_sandbox_up(player: PlayerRoot) -> bool:
	return player.global_position.z < SANDBOX_STAIR_END_Z_M and player.global_position.y > SANDBOX_STAIR_TOP_Y_M - FLOOR_Y_TOLERANCE_M


func _done_sandbox_down(player: PlayerRoot) -> bool:
	return player.global_position.z > SANDBOX_STAIR_START_Z_M + 0.5 and player.global_position.y < 0.1

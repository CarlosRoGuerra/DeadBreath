extends TestCase
## Propriedade do passo em escada (BUG-001 reaberto, BUG-002; F1-010 R1-01/R1-02). Para cada fase s (passo de 5 mm
## no ciclo do degrau), num mundo de física PRÓPRIO e descartado ao fim da fase: sobe da posição s e desce a partir
## do patamar deslocado pela mesma fase. Critério: 0 ticks com is_on_floor() == false (subida e descida) e nenhum
## landed numa fase em que o corpo não saiu do chão. Contadores zerados por fase (R1-09).
## Os testes são divididos em faixas de fases para caber no watchdog de 15 s. Autor: Gameplay Engineer (F1-010).

const Stair := preload("res://tests/integration/player/fixtures/stair_cycle.gd")
const WorldScript := preload("res://tests/integration/player/fixtures/player_world.gd")

const CHUNK_PHASES: int = 14

var _landed: int = 0
var _airborne_up: int = 0
var _airborne_down: int = 0
var _previous: Dictionary = {}


func before_all() -> void:
	Settings.autosave = false


func after_all() -> void:
	Settings.autosave = true


func before_each() -> void:
	_previous = WorldScript.override_settings({&"motion_reduction": 0.0, &"mouse_sensitivity": 0.12, &"invert_y": false, &"fov": 75.0})


func after_each() -> void:
	WorldScript.restore_settings(_previous)


func _on_landed(_fall_speed: float) -> void:
	_landed += 1


## Uma fase completa em um mundo próprio. sandbox == null: escada sintética de `geometry`; senão, a cena.
func _phase(geometry: Dictionary, phase_m: float, sandbox: PackedScene) -> Dictionary:
	_landed = 0
	_airborne_up = 0
	_airborne_down = 0
	var viewport: SubViewport = Stair.new_isolated_viewport(self)
	var root: Node3D = Node3D.new()
	viewport.add_child(root)
	var x: float = float(geometry["x"])
	var top: float = float(geometry["top"])
	var platform_start: float = float(geometry["platform_start"])
	var up_z: float = Stair.up_start_z(geometry, phase_m)
	var player: PlayerRoot = null
	if sandbox == null:
		Stair.build_synthetic(root, float(geometry["tread"]))
		player = WorldScript.spawn_player(root, Vector3(x, 0.0, up_z))
	else:
		var level: Node3D = sandbox.instantiate() as Node3D
		root.add_child(level)
		player = level.get_node("Player") as PlayerRoot
		player.global_position = Vector3(x, 0.0, up_z)
	player.get_motor().landed.connect(_on_landed)
	await wait_physics_frames(Stair.SETTLE_FRAMES)

	var motor: PlayerMotor = player.get_motor()
	motor.set_scripted_input(WorldScript.move_input(Vector2(0.0, 1.0)))
	var up_ok: bool = false
	for _frame: int in Stair.MAX_FRAMES:
		await wait_physics_frames(1)
		if not player.is_on_floor():
			_airborne_up += 1
		if player.global_position.z < platform_start - Stair.DESCENT_MARGIN_M and player.global_position.y > top - Stair.TOP_TOLERANCE_M:
			up_ok = true
			break
	motor.set_scripted_input(MotorInput.new())
	# Descida natural (como o experimento do revisor): para no patamar, espera e desce andando.
	await wait_physics_frames(Stair.PLATFORM_WAIT_FRAMES)
	var natural_ok: bool = await _descend(player, motor, Stair.FIRST_NEAR_Z + Stair.DESCENT_MARGIN_M)
	# Descida sistemática: volta ao patamar numa posição deslocada pela fase, e desce de novo.
	var down_z: float = Stair.down_start_z(geometry, phase_m)
	player.teleport_to(Vector3(x, top, down_z))
	await wait_physics_frames(Stair.SETTLE_FRAMES)
	var systematic_ok: bool = await _descend(player, motor, Stair.FIRST_NEAR_Z + Stair.DESCENT_MARGIN_M)
	var landed_total: int = _landed
	Stair.discard_viewport(viewport)
	return {"up_ok": up_ok, "down_ok": natural_ok and systematic_ok, "airborne_up": _airborne_up, "airborne_down": _airborne_down, "landed": landed_total}


## Anda para trás (+Z) até o piso, contando os ticks sem chão na descida. Devolve se chegou ao piso.
func _descend(player: PlayerRoot, motor: PlayerMotor, floor_z: float) -> bool:
	motor.set_scripted_input(WorldScript.move_input(Vector2(0.0, -1.0)))
	var reached: bool = false
	for _frame: int in Stair.MAX_FRAMES:
		await wait_physics_frames(1)
		if not player.is_on_floor():
			_airborne_down += 1
		if player.global_position.z > floor_z and player.global_position.y < Stair.FLOOR_Y_M:
			reached = true
			break
	motor.set_scripted_input(MotorInput.new())
	await wait_physics_frames(Stair.SETTLE_FRAMES)
	return reached


## Roda as fases de first (inclusive) a last (exclusive) e devolve as falhas, uma por fase, com o motivo.
func _run_range(label: String, geometry: Dictionary, sandbox: PackedScene, first: int, last: int) -> PackedStringArray:
	var failures: PackedStringArray = PackedStringArray()
	var step_m: float = Stair.PHASE_STEP_M
	for index: int in range(first, last):
		var phase_m: float = float(index) * step_m
		var result: Dictionary = await _phase(geometry, phase_m, sandbox)
		var up_ok: bool = result["up_ok"] as bool
		var down_ok: bool = result["down_ok"] as bool
		var up_air: int = result["airborne_up"] as int
		var down_air: int = result["airborne_down"] as int
		var landed: int = result["landed"] as int
		if not up_ok or not down_ok or up_air > 0 or down_air > 0 or landed > 0:
			failures.append("%s fase %d (s=%.3f): subida ok=%s ar=%d; descida ok=%s ar=%d landed=%d" % [
				label, index, phase_m, str(up_ok), up_air, str(down_ok), down_air, landed])
	return failures


func _synthetic(tread: float) -> Dictionary:
	return {"x": 0.0, "top": Stair.RISE_M * float(Stair.SYNTHETIC_STEPS), "platform_start": Stair.FIRST_NEAR_Z - tread * float(Stair.SYNTHETIC_STEPS), "tread": tread}


## Quantidade de fases de um ciclo: um período do degrau em passos de PHASE_STEP_M.
func _phases(tread: float) -> int:
	return int(round(tread / Stair.PHASE_STEP_M))


func test_ciclo_piso_0_28_fases_00_a_13() -> void:
	var f: PackedStringArray = await _run_range("piso 0,28", _synthetic(0.28), null, 0, CHUNK_PHASES)
	assert_eq(f.size(), 0, "\n".join(f))


func test_ciclo_piso_0_28_fases_14_a_27() -> void:
	var f: PackedStringArray = await _run_range("piso 0,28", _synthetic(0.28), null, CHUNK_PHASES, 2 * CHUNK_PHASES)
	assert_eq(f.size(), 0, "\n".join(f))


func test_ciclo_piso_0_28_fases_28_a_41() -> void:
	var f: PackedStringArray = await _run_range("piso 0,28", _synthetic(0.28), null, 2 * CHUNK_PHASES, 3 * CHUNK_PHASES)
	assert_eq(f.size(), 0, "\n".join(f))


func test_ciclo_piso_0_28_fases_42_a_55() -> void:
	var f: PackedStringArray = await _run_range("piso 0,28", _synthetic(0.28), null, 3 * CHUNK_PHASES, _phases(0.28))
	assert_eq(f.size(), 0, "\n".join(f))


func test_ciclo_piso_0_30_fases_00_a_14() -> void:
	var f: PackedStringArray = await _run_range("piso 0,30", _synthetic(0.30), null, 0, CHUNK_PHASES)
	assert_eq(f.size(), 0, "
".join(f))


func test_ciclo_piso_0_30_fases_15_a_29() -> void:
	var f: PackedStringArray = await _run_range("piso 0,30", _synthetic(0.30), null, CHUNK_PHASES, 2 * CHUNK_PHASES)
	assert_eq(f.size(), 0, "
".join(f))


func test_ciclo_piso_0_30_fases_30_a_44() -> void:
	var f: PackedStringArray = await _run_range("piso 0,30", _synthetic(0.30), null, 2 * CHUNK_PHASES, 3 * CHUNK_PHASES)
	assert_eq(f.size(), 0, "
".join(f))


func test_ciclo_piso_0_30_fases_45_a_59() -> void:
	var f: PackedStringArray = await _run_range("piso 0,30", _synthetic(0.30), null, 3 * CHUNK_PHASES, _phases(0.30))
	assert_eq(f.size(), 0, "
".join(f))


func test_ciclo_sandbox_fases_00_a_13() -> void:
	var f: PackedStringArray = await _run_range("sandbox", Stair.sandbox_geometry(), load(Stair.SANDBOX_PATH) as PackedScene, 0, CHUNK_PHASES)
	assert_eq(f.size(), 0, "
".join(f))


func test_ciclo_sandbox_fases_14_a_27() -> void:
	var f: PackedStringArray = await _run_range("sandbox", Stair.sandbox_geometry(), load(Stair.SANDBOX_PATH) as PackedScene, CHUNK_PHASES, 2 * CHUNK_PHASES)
	assert_eq(f.size(), 0, "
".join(f))


func test_ciclo_sandbox_fases_28_a_41() -> void:
	var f: PackedStringArray = await _run_range("sandbox", Stair.sandbox_geometry(), load(Stair.SANDBOX_PATH) as PackedScene, 2 * CHUNK_PHASES, 3 * CHUNK_PHASES)
	assert_eq(f.size(), 0, "
".join(f))


func test_ciclo_sandbox_fases_42_a_55() -> void:
	var f: PackedStringArray = await _run_range("sandbox", Stair.sandbox_geometry(), load(Stair.SANDBOX_PATH) as PackedScene, 3 * CHUNK_PHASES, _phases(Stair.SANDBOX_TREAD_M))
	assert_eq(f.size(), 0, "
".join(f))


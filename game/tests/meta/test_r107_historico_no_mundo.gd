extends TestCase
## Regressão do R1-07 (F1-010): a física de uma fase não pode depender do histórico do mundo.
##
## Caso reproduzido: escada de piso 0,28, início em z = 0,475, subida e descida completas. No código do
## revisor (F1-010, commit 5bb160c), o alvo montado depois de n fases anteriores no mesmo mundo, liberadas
## com free() direto (sem flush), tinha 16 ticks no ar na descida para n = 0..7, 0 para n = 8, 16 para
## n = 9..10, 0 para n = 11 e 16 para n = 12: o resultado depende do histórico exato do processo.
## Com add_isolated_world() ou release_and_flush() (esperar frames de física), o resultado é o do caso
## isolado para todo n. Medido com --fixed-fps 60 (run_tests.ps1), então não depende do relógio.
## No código atual o efeito não aparece mais nesta fase (o comportamento da descida mudou); o teste
## continua valendo como regressão. A sequência com free() direto é a reprodução (ver evidência F1-010_qa).

const PLAYER_SCENE: PackedScene = preload("res://components/player/player.tscn")
const STEPS: int = 8
const RISE_M: float = 0.18
const FIRST_NEAR_Z: float = -1.0
const TREAD: float = 0.28
const TARGET_Z: float = 0.475
const PREVIOUS_PHASES: int = 5
## Mapa de sensibilidade do revisor: n = 0..12 fases anteriores (n = 8 e n = 11 mudavam a descida).
const SENSITIVITY_MAX: int = 12
const SETTLE_FRAMES: int = 8
const MAX_FRAMES: int = 500
const PLATFORM_EXTRA_M: float = 1.5
const PLATFORM_WALK_FRAMES: int = 40
const FLOOR_Y_TOLERANCE_M: float = 0.02


func test_r107_mundo_isolado_por_fase_nao_depende_do_historico() -> void:
	var baseline: Dictionary = await _phase(add_isolated_world(), TARGET_Z)
	for k: int in PREVIOUS_PHASES:
		var world: Node3D = add_isolated_world()
		await _phase(world, 0.5 - 0.005 * float(k))
		await release_and_flush(world.get_parent())
	var target: Dictionary = await _phase(add_isolated_world(), TARGET_Z)
	_assert_same(target, baseline, "mundo isolado por fase")


func test_r107_mundo_compartilhado_com_flush_nao_depende_do_historico() -> void:
	var baseline: Dictionary = await _phase(add_isolated_world(), TARGET_Z)
	# Alvo no mesmo mundo compartilhado depois de n = 0..12 fases anteriores, cada uma liberada com flush.
	for n: int in range(0, SENSITIVITY_MAX + 1):
		var target_root: Node3D = add_child_autofree(Node3D.new()) as Node3D
		var target: Dictionary = await _phase(target_root, TARGET_Z)
		_assert_same(target, baseline, "alvo apos %d fases anteriores (mundo compartilhado com flush)" % n)
		await release_and_flush(target_root)
		var previous: Node3D = add_child_autofree(Node3D.new()) as Node3D
		await _phase(previous, 0.5 - 0.005 * float(n % 10))
		await release_and_flush(previous)


func _assert_same(actual: Dictionary, expected: Dictionary, label: String) -> void:
	assert_eq(actual["completou"], expected["completou"], "%s: a escada foi completa" % label)
	assert_eq(actual["up"], expected["up"], "%s: ticks no ar na subida" % label)
	assert_eq(actual["down"], expected["down"], "%s: ticks no ar na descida" % label)
	assert_almost_eq(float(actual["z_end"]), float(expected["z_end"]), 0.0001, "%s: posicao final" % label)


## Uma fase completa dentro de parent. Devolve completou, up, down (ticks no ar) e z_end.
func _phase(parent: Node3D, start_z: float) -> Dictionary:
	var counts: Dictionary = {"up": 0, "down": 0}
	var platform_start: float = _build_stairs(parent, TREAD)
	var player: PlayerRoot = PLAYER_SCENE.instantiate() as PlayerRoot
	player.position = Vector3(0.0, 0.0, start_z)
	parent.add_child(player)
	await wait_physics_frames(SETTLE_FRAMES)
	var limit_z: float = platform_start - PLATFORM_EXTRA_M * 0.5
	var up_ok: bool = await _walk(player, 1.0, true, limit_z, 1, counts)
	await wait_physics_frames(PLATFORM_WALK_FRAMES)
	var down_ok: bool = await _walk(player, -1.0, false, 0.0, -1, counts)
	return {"completou": up_ok and down_ok, "up": counts["up"], "down": counts["down"], "z_end": player.global_position.z}


func _walk(player: PlayerRoot, move_y: float, done_up: bool, limit_z: float, direction: int, counts: Dictionary) -> bool:
	var input: MotorInput = MotorInput.new()
	input.move = Vector2(0.0, move_y)
	player.get_motor().set_scripted_input(input)
	var frames: int = 0
	while frames < MAX_FRAMES:
		await wait_physics_frames(1)
		frames += 1
		if not player.is_on_floor():
			var key: String = "up" if direction > 0 else "down"
			counts[key] = int(counts[key]) + 1
		var reached: bool = false
		if done_up:
			reached = player.global_position.z < limit_z and player.global_position.y > RISE_M * float(STEPS) - FLOOR_Y_TOLERANCE_M
		else:
			reached = player.global_position.z > FIRST_NEAR_Z + 0.5 and player.global_position.y < 0.1
		if reached:
			break
	player.get_motor().set_scripted_input(MotorInput.new())
	return frames < MAX_FRAMES


## Escada da fase: piso, degraus e patamar, com a mesma geometria do sweep de F1-010.
func _build_stairs(parent: Node3D, tread: float) -> float:
	_box(parent, Vector3(0.0, -0.5, -6.0), Vector3(2.4, 1.0, 16.0))
	for index: int in STEPS:
		var top: float = RISE_M * float(index + 1)
		var near_z: float = FIRST_NEAR_Z - tread * float(index)
		var center_z: float = near_z - tread * 0.5
		_box(parent, Vector3(0.0, (top - 1.0) * 0.5, center_z), Vector3(2.4, top + 1.0, tread))
	var platform_top: float = RISE_M * float(STEPS)
	var platform_start: float = FIRST_NEAR_Z - tread * float(STEPS)
	var platform_len: float = PLATFORM_EXTRA_M + 1.0
	_box(parent, Vector3(0.0, (platform_top - 1.0) * 0.5, platform_start - platform_len * 0.5),
		Vector3(2.4, platform_top + 1.0, platform_len))
	return platform_start


func _box(parent: Node3D, center: Vector3, size: Vector3) -> void:
	var body: StaticBody3D = StaticBody3D.new()
	body.position = center
	var shape_node: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = size
	shape_node.shape = box
	body.add_child(shape_node)
	body.set_meta(&"surface", &"wood")
	parent.add_child(body)

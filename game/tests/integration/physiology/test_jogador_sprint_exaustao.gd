extends TestCase
## Integração no jogador (COMPONENT_CONTRACTS §1 e §4.3; PHY-01 no jogador; card F2-004): sprint até esgotar →
## LABORED ou pior; no tick em que a stamina esgota, o motor ainda sprintou (o limite vale no tick seguinte);
## no tick seguinte, com a tecla ainda apertada, não há sprint; e o sprint só volta com stamina >= 25.
## Física em passo fixo de 1/60 s. Autor: Physiological Systems Engineer.

const PlayerWorld := preload("res://tests/integration/player/fixtures/player_world.gd")
const SETTLE_FRAMES: int = 6
const MAX_SPRINT_FRAMES: int = 60 * 14
const MAX_RECOVERY_FRAMES: int = 60 * 10
const FRAME_S: float = 1.0 / 60.0
const REENABLE_THRESHOLD: float = 25.0

var _previous: Dictionary = {}
var _depleted_count: int = 0


func before_all() -> void:
	Settings.autosave = false


func after_all() -> void:
	Settings.autosave = true


func before_each() -> void:
	_previous = PlayerWorld.override_settings({&"motion_reduction": 0.0, &"mouse_sensitivity": 0.12, &"invert_y": false, &"fov": 75.0})
	_depleted_count = 0


func after_each() -> void:
	PlayerWorld.restore_settings(_previous)


func _on_depleted() -> void:
	_depleted_count += 1


func test_sprint_esgota_leva_a_laboured_e_o_limite_vale_no_tick_seguinte() -> void:
	var root: Node3D = add_isolated_world()
	PlayerWorld.add_box(root, Vector3(0.0, -0.5, -30.0), Vector3(6.0, 1.0, 80.0), &"wood")
	var player: PlayerRoot = PlayerWorld.spawn_player(root, Vector3.ZERO)
	var physiology: PhysiologyComponent = player.get_physiology()
	var motor: PlayerMotor = player.get_motor()
	physiology.stamina_depleted.connect(_on_depleted)
	await wait_physics_frames(SETTLE_FRAMES)
	motor.set_scripted_input(PlayerWorld.move_input(Vector2(0.0, 1.0), true))

	var gaits: Array[int] = []
	var allowed: Array[bool] = []
	var stamina: Array[float] = []
	var states: Array[String] = []
	var depleted_frame: int = -1
	var labored_frame: int = -1
	for frame: int in MAX_SPRINT_FRAMES:
		await wait_physics_frames(1)
		gaits.append(motor.get_gait())
		allowed.append(physiology.get_coupling().sprint_allowed)
		var snapshot: PhysiologySnapshot = physiology.get_snapshot()
		stamina.append(snapshot.stamina)
		states.append(RespiratoryModel.state_name(snapshot.respiratory_state))
		if labored_frame < 0 and (snapshot.respiratory_state == Enums.RespiratoryState.LABORED
				or snapshot.respiratory_state == Enums.RespiratoryState.SYMPTOMATIC):
			labored_frame = frame
		if depleted_frame < 0 and _depleted_count > 0:
			depleted_frame = frame
		if depleted_frame >= 0 and frame > depleted_frame:
			break

	assert_true(depleted_frame >= 0, "o sprint contínuo esgota a stamina")
	if depleted_frame < 0:
		return
	var s: int = depleted_frame
	note("jogador: esgotamento no quadro %d (%.3f s de sprint); LABORED no quadro %d (%.3f s); estado no esgotamento %s"
		% [s, (s + 1) * FRAME_S, labored_frame, (labored_frame + 1) * FRAME_S, states[s]])
	assert_true(labored_frame >= 0 and labored_frame <= s, "antes ou no esgotamento a respiração chega a LABORED")
	assert_eq(gaits[s], Enums.Gait.SPRINT, "no quadro do esgotamento o motor ainda sprintou (limite do tick anterior)")
	assert_false(allowed[s], "o acoplamento do tick do esgotamento já proíbe o sprint")
	assert_true(gaits[s + 1] != Enums.Gait.SPRINT, "no tick seguinte, com a tecla apertada, não há sprint")
	assert_true(states[s] == "LABORED" or states[s] == "SYMPTOMATIC", "estado no esgotamento: LABORED ou pior (obtido %s)" % states[s])

	# Recuperação: a stamina é levada a 24 (exaustão mantida) pelo caminho de persistência, para o teste não
	# esperar a recuperação natural de ~9 s. A recuperação natural é medida no modelo (test_f2001: histerese em 25).
	# Com a tecla ainda apertada, nenhum quadro sprinta enquanto a stamina estiver abaixo de 25.
	var data: Dictionary = physiology.to_dict()
	var stamina_data: Dictionary = data["stamina"]
	stamina_data["value"] = 24.0
	stamina_data["exhausted"] = true
	stamina_data["regen_delay_remaining"] = 0.0
	physiology.from_dict(data)
	var sprint_while_locked: int = 0
	var reenabled_frame: int = -1
	for frame: int in MAX_RECOVERY_FRAMES:
		await wait_physics_frames(1)
		var snapshot_now: PhysiologySnapshot = physiology.get_snapshot()
		var allowed_now: bool = physiology.get_coupling().sprint_allowed
		if not allowed_now and motor.get_gait() == Enums.Gait.SPRINT:
			sprint_while_locked += 1
		if allowed_now:
			reenabled_frame = frame
			note("jogador: sprint volta com stamina %.3f (após %.2f s de recuperação)" % [snapshot_now.stamina, (frame + 1) * FRAME_S])
			assert_true(snapshot_now.stamina >= REENABLE_THRESHOLD - 0.5, "o sprint só volta com stamina >= 25 (obtido %.3f)" % snapshot_now.stamina)
			break
	assert_eq(sprint_while_locked, 0, "sem sprint enquanto a stamina está abaixo de 25, mesmo com a tecla apertada")
	assert_true(reenabled_frame >= 0, "o sprint volta depois da recuperação")

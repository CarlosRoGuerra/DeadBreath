extends TestCase
## Ameaça no jogador (COMPONENT_CONTRACTS §4.3 e §5; card F2-004): o PlayerRoot monta PhysiologyInputs com a fonte
## de ameaça (StubThreatSource na F2) e a entrega à fisiologia a cada tick; uma ameaça forçada pelo teste sobe o
## estresse; a fonte padrão é zero. Autor: Physiological Systems Engineer.

const PlayerWorld := preload("res://tests/integration/player/fixtures/player_world.gd")
const SETTLE_FRAMES: int = 6
const SECONDS_FRAMES: int = 60
const TOLERANCE: float = 0.05

var _previous: Dictionary = {}


func before_all() -> void:
	Settings.autosave = false


func after_all() -> void:
	Settings.autosave = true


func before_each() -> void:
	_previous = PlayerWorld.override_settings({&"motion_reduction": 0.0, &"mouse_sensitivity": 0.12, &"invert_y": false, &"fov": 75.0})


func after_each() -> void:
	PlayerWorld.restore_settings(_previous)


func test_fonte_padrao_e_zero_e_stub_forcado_sobe_o_estresse() -> void:
	var root: Node3D = add_isolated_world()
	PlayerWorld.add_box(root, Vector3(0.0, -0.5, -5.0), Vector3(6.0, 1.0, 16.0), &"wood")
	var player: PlayerRoot = PlayerWorld.spawn_player(root, Vector3.ZERO)
	await wait_physics_frames(SETTLE_FRAMES)
	assert_true(player.get_threat_source() is StubThreatSource, "a fonte padrão da F2 é o StubThreatSource")
	assert_almost_eq(player.get_physiology().get_snapshot().stress, 0.0, TOLERANCE, "sem ameaça, sem estresse")
	var stub: StubThreatSource = StubThreatSource.new()
	stub.forced = _seen_threat(1.0)
	player.set_threat_source(stub)
	await wait_physics_frames(SECONDS_FRAMES)
	var stress: float = player.get_physiology().get_snapshot().stress
	note("ameaça forçada (inimigo visto a 3 m) durante 1 s: estresse %.3f (ganho 15/s)" % stress)
	assert_almost_eq(stress, 15.0, 1.0, "inimigo visto a 3 m: +15/s, entregue pelo PlayerRoot")
	player.set_threat_source(null)
	assert_true(player.get_threat_source() is StubThreatSource, "null volta ao stub com ameaça zero")


func _seen_threat(seen: float) -> ThreatSample:
	var sample: ThreatSample = ThreatSample.new()
	sample.seen_proximity = seen
	sample.threat_level = seen
	return sample

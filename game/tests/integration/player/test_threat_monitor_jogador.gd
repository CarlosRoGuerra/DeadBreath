extends TestCase
## F4-009 e F4-006b (COMPONENT_CONTRACTS §1, §5 e §7.1; D4-01): o PlayerRoot liga o PlayerThreatMonitor no lugar do
## StubThreatSource, a sonda de luz e os três pontos de amostra ao PerceivableTarget, e a postura do motor. Também confere
## que o grito de perseguição chega ao monitor pelo AcousticWorld e sai pelo sinal threat_changed.
## Autor: Gameplay Engineer.

const PlayerWorld := preload("res://tests/integration/player/fixtures/player_world.gd")
const ThreatWorld := preload("res://tests/integration/player/fixtures/threat_world.gd")
const SETTLE_FRAMES: int = 6
const LIGHT_FRAMES: int = 12
const TOLERANCE: float = 0.01
const STAND_EYE_Y: float = 1.65
const CROUCH_FACTOR: float = 0.6
const CRAWL_FACTOR: float = 0.35
const STAND_FACTOR: float = 1.0

var _changes: int = 0
var _last_chase: bool = false


func _on_threat_changed(_level: float, in_chase: bool) -> void:
	_changes += 1
	_last_chase = in_chase


func before_each() -> void:
	_changes = 0
	_last_chase = false


func test_fonte_padrao_e_a_do_monitor_por_composicao() -> void:
	var root: Node3D = add_isolated_world()
	PlayerWorld.add_box(root, Vector3(0.0, -0.5, -5.0), Vector3(6.0, 1.0, 16.0), &"wood")
	var player: PlayerRoot = PlayerWorld.spawn_player(root, Vector3.ZERO)
	await wait_physics_frames(SETTLE_FRAMES)
	var monitor: PlayerThreatMonitor = player.get_threat_monitor()
	assert_not_null(monitor, "o PlayerRoot tem o PlayerThreatMonitor")
	assert_true(player.get_threat_source() is MonitoredThreatSource, "a fonte padrão é a do monitor")
	assert_true(player.get_threat_source() == monitor.get_threat_source(), "a fonte é a que o monitor devolve")
	assert_true(monitor is Node, "o monitor é um Node (D4-01)")
	assert_false(is_instance_of(monitor, ThreatSource), "o monitor não estende ThreatSource (D4-01)")


func test_perceivable_tem_tres_pontos_cabeca_tronco_e_pes() -> void:
	var root: Node3D = add_isolated_world()
	PlayerWorld.add_box(root, Vector3(0.0, -0.5, -5.0), Vector3(6.0, 1.0, 16.0), &"wood")
	var player: PlayerRoot = PlayerWorld.spawn_player(root, Vector3.ZERO)
	await wait_physics_frames(SETTLE_FRAMES)
	var points: PackedVector3Array = player.get_perceivable_target().get_sample_points()
	assert_eq(points.size(), 3, "três pontos de amostra")
	if points.size() == 3:
		assert_almost_eq(points[0].y, STAND_EYE_Y, TOLERANCE, "o primeiro ponto é a cabeça, na altura dos olhos")
		assert_true(points[1].y > points[2].y and points[1].y < points[0].y, "o tronco fica entre a cabeça e os pés")
		assert_almost_eq(points[2].y, 0.1, TOLERANCE, "o último ponto é o pé")


func test_exposicao_de_luz_vem_da_sonda() -> void:
	var root: Node3D = add_isolated_world()
	PlayerWorld.add_box(root, Vector3(0.0, -0.5, -5.0), Vector3(6.0, 1.0, 16.0), &"wood")
	var player: PlayerRoot = PlayerWorld.spawn_player(root, Vector3.ZERO)
	await wait_physics_frames(LIGHT_FRAMES)
	var perceivable: PerceivableTarget = player.get_perceivable_target()
	assert_eq(player.get_light_probe().get_exposure(), 0.0, "no escuro, a sonda marca 0")
	assert_eq(perceivable.get_light_exposure(), player.get_light_probe().get_exposure(), "o alvo lê a exposição da sonda")
	ThreatWorld.add_light(root, Vector3(0.5, 1.2, -0.5), 6.0)
	await wait_physics_frames(LIGHT_FRAMES)
	var lit: float = perceivable.get_light_exposure()
	assert_true(lit > 0.1, "com luz perto, a exposição sobe (%.3f)" % lit)
	assert_eq(lit, player.get_light_probe().get_exposure(), "a exposição do alvo continua igual à da sonda")


func test_fator_de_postura_acompanha_agachar_e_rastejar() -> void:
	var root: Node3D = add_isolated_world()
	PlayerWorld.add_box(root, Vector3(0.0, -0.5, -5.0), Vector3(6.0, 1.0, 16.0), &"wood")
	var player: PlayerRoot = PlayerWorld.spawn_player(root, Vector3.ZERO)
	var motor: PlayerMotor = player.get_motor()
	var perceivable: PerceivableTarget = player.get_perceivable_target()
	await wait_physics_frames(SETTLE_FRAMES)
	assert_almost_eq(perceivable.get_stance_factor(), STAND_FACTOR, TOLERANCE, "em pé: fator 1,0")
	motor.set_scripted_input(PlayerWorld.edge_input(true, false))
	await wait_physics_frames(1)
	motor.set_scripted_input(null)
	assert_eq(motor.get_stance(), Enums.Stance.CROUCH, "pré-condição: agachou")
	assert_almost_eq(perceivable.get_stance_factor(), CROUCH_FACTOR, TOLERANCE, "agachado: fator 0,6")
	motor.set_scripted_input(PlayerWorld.edge_input(false, true))
	await wait_physics_frames(1)
	motor.set_scripted_input(null)
	assert_eq(motor.get_stance(), Enums.Stance.CRAWL, "pré-condição: rastejou")
	assert_almost_eq(perceivable.get_stance_factor(), CRAWL_FACTOR, TOLERANCE, "rastejando: fator 0,35")


func test_grito_de_perseguicao_chega_ao_monitor_e_sai_por_threat_changed() -> void:
	var root: Node3D = add_isolated_world()
	var world: AcousticWorld = AcousticWorld.new()
	root.add_child(world)
	ThreatWorld.add_floor(root)
	var player: PlayerRoot = PlayerWorld.spawn_player(root, Vector3.ZERO)
	var body: CharacterBody3D = ThreatWorld.make_enemy(root, Vector3(0.0, 0.75, 4.0))
	var monitor: PlayerThreatMonitor = player.get_threat_monitor()
	monitor.threat_changed.connect(_on_threat_changed)
	await wait_physics_frames(SETTLE_FRAMES)
	ThreatWorld.emitter_of(body).emit_noise(Enums.NoiseCategory.VOICE, 80.0, 0.0, &"voice_chase_shout")
	await wait_physics_frames(2)
	monitor.threat_changed.disconnect(_on_threat_changed)
	assert_true(_changes >= 1, "o monitor emite threat_changed ao ouvir o grito")
	assert_true(_last_chase, "o sinal indica perseguição")
	assert_true(player.get_threat_source().sample().in_chase, "a amostra da fonte está em perseguição")


## O monitor lê get_state() do inimigo (assinatura do EnemyController, COMPONENT §8.1): visto em CHASE liga a
## perseguição. Saindo de CHASE, a janela de 3 s continua ativa (o teste longo de expiração está em property).
func test_inimigo_visto_em_chase_liga_a_perseguicao() -> void:
	var root: Node3D = add_isolated_world()
	PlayerWorld.add_box(root, Vector3(0.0, -0.5, -5.0), Vector3(6.0, 1.0, 16.0), &"wood")
	var player: PlayerRoot = PlayerWorld.spawn_player(root, Vector3.ZERO)
	var body: CharacterBody3D = ThreatWorld.make_enemy(root, Vector3(0.0, 0.75, -3.0))
	body.set_script(preload("res://tests/integration/player/fixtures/fake_chasing_enemy.gd"))
	await wait_physics_frames(SETTLE_FRAMES)
	var sample: ThreatSample = player.get_threat_source().sample()
	assert_true(sample.seen_proximity > 0.99, "o inimigo em CHASE, a 3 m, está visto (%.3f)" % sample.seen_proximity)
	assert_true(sample.in_chase, "visto em CHASE liga a perseguição")
	body.set(&"state", Enums.EnemyState.PATROL)
	await wait_physics_frames(1)
	assert_true(player.get_threat_source().sample().in_chase, "logo depois de sair de CHASE, a janela de 3 s segue ativa")

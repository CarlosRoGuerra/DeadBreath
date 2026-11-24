extends TestCase
## Revisão F4-010, R4-02 (COMPONENT_CONTRACTS §5): o inimigo conta como visto pelo jogador com exposição à luz ≥ 0,15
## ou a até 3 m. O Observer de produção ganhou um LightExposureProbe; sem ele, o monitor só o via a até 3 m.
## Observer real (observer.tscn) a 8 m diante da câmera: iluminado, a proximidade vista sobe (DATA §1.5: 0,58 a 8 m);
## no escuro, fica em 0. Autor: Director (correção da revisão).

const PlayerWorld := preload("res://tests/integration/player/fixtures/player_world.gd")
const OBSERVER_SCENE: PackedScene = preload("res://content/enemies/observer.tscn")
const SETTLE_FRAMES: int = 12
const DISTANCE_M: float = 8.0


func _scene(lit: bool) -> Dictionary:
	var root: Node3D = add_child_autofree(Node3D.new()) as Node3D
	PlayerWorld.add_box(root, Vector3(0.0, -0.1, -4.0), Vector3(6.0, 0.2, 14.0), &"concrete")
	var player: PlayerRoot = PlayerWorld.spawn_player(root, Vector3.ZERO)
	var observer: Node3D = OBSERVER_SCENE.instantiate() as Node3D
	observer.position = Vector3(0.0, 0.0, -DISTANCE_M)
	root.add_child(observer)
	if lit:
		var lamp: OmniLight3D = OmniLight3D.new()
		lamp.position = Vector3(0.0, 2.4, -DISTANCE_M)
		lamp.omni_range = 5.0
		lamp.light_energy = 2.0
		root.add_child(lamp)
	return {"player": player, "observer": observer}


func _seen(player: PlayerRoot) -> float:
	return player.get_threat_monitor().get_threat_source().sample().seen_proximity


func test_observer_iluminado_a_8_m_e_visto() -> void:
	var parts: Dictionary = _scene(true)
	var player: PlayerRoot = parts["player"] as PlayerRoot
	await wait_physics_frames(SETTLE_FRAMES)
	var probe: LightExposureProbe = (parts["observer"] as Node3D).get_node_or_null("LightExposureProbe") as LightExposureProbe
	assert_not_null(probe, "o Observer de produção tem LightExposureProbe")
	if probe != null:
		assert_true(probe.get_exposure() >= 0.15, "o Observer está iluminado (%.2f)" % probe.get_exposure())
	var seen: float = _seen(player)
	note("proximidade vista a 8 m, iluminado: %.3f" % seen)
	assert_true(seen > 0.4, "iluminado a 8 m, o Observer conta como visto (%.3f)" % seen)


func test_observer_no_escuro_a_8_m_nao_e_visto() -> void:
	var parts: Dictionary = _scene(false)
	var player: PlayerRoot = parts["player"] as PlayerRoot
	await wait_physics_frames(SETTLE_FRAMES)
	assert_almost_eq(_seen(player), 0.0, 0.0001, "no escuro, além de 3 m, não conta como visto")

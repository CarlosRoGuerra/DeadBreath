extends TestCase
## F3-005 (LightExposureProbe, COMPONENT §7.1): exposição em mundo isolado, física a 60 ticks/s fixos.
## Escuro ≈ 0; luz direta alta; alcance; parede e vision_occluder (camada 7) bloqueiam; corpo de inimigo (camada 4)
## não bloqueia; cone do spot; piso ambiente; determinismo; sala iluminada da sandbox acima de um ponto escuro.
## Autor: Gameplay Engineer.

const SETTLE_FRAMES: int = 3
const TOL: float = 0.000001
const LAYER_WORLD_STATIC: int = 1
const LAYER_VISION_OCCLUDER: int = 64
const LAYER_ENEMY: int = 8
const SANDBOX_SCENE_PATH: String = "res://content/levels/sandbox.tscn"


func _probe(world: Node3D, pos: Vector3) -> LightExposureProbe:
	var holder: Node3D = Node3D.new()
	holder.position = pos
	world.add_child(holder)
	var probe: LightExposureProbe = LightExposureProbe.new()
	probe.update_hz = 60.0  ## uma amostra por tick: o teste não espera o período de 10 Hz
	holder.add_child(probe)
	return probe


func _omni(world: Node3D, pos: Vector3, energy: float, range_m: float) -> OmniLight3D:
	var light: OmniLight3D = OmniLight3D.new()
	light.position = pos
	light.light_energy = energy
	light.omni_range = range_m
	world.add_child(light)
	return light


func _spot(world: Node3D, pos: Vector3, target: Vector3, energy: float, range_m: float, angle_deg: float) -> SpotLight3D:
	var light: SpotLight3D = SpotLight3D.new()
	light.position = pos
	light.light_energy = energy
	light.spot_range = range_m
	light.spot_angle = angle_deg
	world.add_child(light)
	light.look_at(target, Vector3.BACK)
	return light


func _wall(world: Node3D, center: Vector3, size: Vector3, layer: int) -> StaticBody3D:
	var body: StaticBody3D = StaticBody3D.new()
	body.position = center
	body.collision_layer = layer
	var shape_node: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = size
	shape_node.shape = box
	body.add_child(shape_node)
	world.add_child(body)
	return body


func test_escuro_total_da_zero() -> void:
	var world: Node3D = add_isolated_world()
	var probe: LightExposureProbe = _probe(world, Vector3(0.0, 1.0, 0.0))
	await wait_physics_frames(SETTLE_FRAMES)
	assert_true(probe.get_sample_count() >= 1, "amostrou ao menos uma vez")
	assert_almost_eq(probe.get_exposure(), 0.0, TOL, "sem luz: escuro total")


func test_luz_apagada_nao_ilumina() -> void:
	var world: Node3D = add_isolated_world()
	_omni(world, Vector3(0.0, 2.0, 0.0), 0.0, 8.0)
	var probe: LightExposureProbe = _probe(world, Vector3(0.0, 1.0, 0.0))
	await wait_physics_frames(SETTLE_FRAMES)
	assert_almost_eq(probe.get_exposure(), 0.0, TOL, "energia 0: sem exposição")


func test_luz_direta_proxima_e_alta_e_longe_e_menor() -> void:
	var world: Node3D = add_isolated_world()
	_omni(world, Vector3(0.0, 2.5, 0.0), 1.6, 8.0)
	var near: LightExposureProbe = _probe(world, Vector3(0.0, 1.0, 0.0))
	var far: LightExposureProbe = _probe(world, Vector3(0.0, 1.0, 6.0))
	await wait_physics_frames(SETTLE_FRAMES)
	assert_true(near.get_exposure() > 0.9, "luz direta a 1,5 m: alta (%.3f)" % near.get_exposure())
	assert_true(far.get_exposure() > 0.0 and far.get_exposure() < near.get_exposure(), "a 6 m: menor, mas acesa (%.3f)" % far.get_exposure())


func test_alcance_zera_a_luz() -> void:
	var world: Node3D = add_isolated_world()
	_omni(world, Vector3(0.0, 2.0, 0.0), 1.6, 3.0)
	var probe: LightExposureProbe = _probe(world, Vector3(0.0, 1.0, 5.0))
	await wait_physics_frames(SETTLE_FRAMES)
	assert_almost_eq(probe.get_exposure(), 0.0, TOL, "fora do alcance da luz: 0")


func test_atras_de_parede_e_zero() -> void:
	var world: Node3D = add_isolated_world()
	_omni(world, Vector3(0.0, 2.0, 0.0), 1.6, 8.0)
	var probe: LightExposureProbe = _probe(world, Vector3(3.0, 1.0, 0.0))
	await wait_physics_frames(SETTLE_FRAMES)
	assert_true(probe.get_exposure() > 0.5, "sem parede a luz chega (%.3f)" % probe.get_exposure())
	var wall: StaticBody3D = _wall(world, Vector3(1.5, 1.5, 0.0), Vector3(0.2, 3.0, 4.0), LAYER_WORLD_STATIC)
	await wait_physics_frames(SETTLE_FRAMES)
	assert_almost_eq(probe.get_exposure(), 0.0, TOL, "atrás de parede (camada 1): 0")
	wall.collision_layer = LAYER_WORLD_STATIC


func test_vision_occluder_bloqueia_e_corpo_de_inimigo_nao() -> void:
	var world: Node3D = add_isolated_world()
	_omni(world, Vector3(0.0, 2.0, 0.0), 1.6, 8.0)
	var probe: LightExposureProbe = _probe(world, Vector3(3.0, 1.0, 0.0))
	var curtain: StaticBody3D = _wall(world, Vector3(1.5, 1.5, 0.0), Vector3(0.2, 3.0, 4.0), LAYER_VISION_OCCLUDER)
	await wait_physics_frames(SETTLE_FRAMES)
	assert_almost_eq(probe.get_exposure(), 0.0, TOL, "cortina (vision_occluder, camada 7) bloqueia a luz")
	curtain.collision_layer = LAYER_ENEMY
	await wait_physics_frames(SETTLE_FRAMES)
	assert_true(probe.get_exposure() > 0.5, "corpo de inimigo (camada 4) não bloqueia a luz (%.3f)" % probe.get_exposure())


func test_cone_do_spot_dentro_e_fora() -> void:
	var world: Node3D = add_isolated_world()
	_spot(world, Vector3(0.0, 3.0, 0.0), Vector3(0.0, 0.0, 0.0), 2.0, 8.0, 30.0)
	var inside: LightExposureProbe = _probe(world, Vector3(0.0, 1.0, 0.0))
	var outside: LightExposureProbe = _probe(world, Vector3(2.5, 1.0, 0.0))
	await wait_physics_frames(SETTLE_FRAMES)
	assert_true(inside.get_exposure() > 0.9, "dentro do cone, abaixo do spot (%.3f)" % inside.get_exposure())
	assert_almost_eq(outside.get_exposure(), 0.0, TOL, "51° do eixo, fora do cone de 30°: 0")


func test_piso_ambiente_sem_luz() -> void:
	var world: Node3D = add_isolated_world()
	var probe: LightExposureProbe = _probe(world, Vector3(0.0, 1.0, 0.0))
	probe.ambient_floor = 0.2
	await wait_physics_frames(SETTLE_FRAMES)
	assert_almost_eq(probe.get_exposure(), 0.2, TOL, "sem luz: piso ambiente")


func test_determinismo_com_cena_estatica() -> void:
	var world: Node3D = add_isolated_world()
	_omni(world, Vector3(0.0, 2.5, 0.0), 1.6, 8.0)
	_wall(world, Vector3(2.0, 1.5, 0.0), Vector3(0.2, 3.0, 4.0), LAYER_WORLD_STATIC)
	var first: LightExposureProbe = _probe(world, Vector3(0.0, 1.0, 0.0))
	var second: LightExposureProbe = _probe(world, Vector3(0.0, 1.0, 0.0))
	await wait_physics_frames(SETTLE_FRAMES)
	var value: float = first.get_exposure()
	assert_eq(second.get_exposure(), value, "dois probes idênticos dão o mesmo valor")
	await wait_physics_frames(SETTLE_FRAMES)
	assert_almost_eq(first.get_exposure(), value, TOL, "cena parada: a exposição não deriva")


func test_sandbox_sala_iluminada_acima_do_ponto_escuro() -> void:
	var world: Node3D = add_isolated_world()
	var scene: PackedScene = load(SANDBOX_SCENE_PATH) as PackedScene
	assert_not_null(scene, "a sandbox carrega")
	if scene == null:
		return
	world.add_child(scene.instantiate())
	var lit: LightExposureProbe = _probe(world, Vector3(1.5, 1.2, -4.5))
	var dark: LightExposureProbe = _probe(world, Vector3(-6.0, 1.2, 6.0))
	await wait_physics_frames(SETTLE_FRAMES)
	assert_true(lit.get_exposure() > 0.3, "sob a lâmpada da sala: iluminado (%.3f)" % lit.get_exposure())
	assert_almost_eq(dark.get_exposure(), 0.0, TOL, "fora do alcance de todas as lâmpadas: escuro")
	assert_true(lit.get_exposure() > dark.get_exposure(), "sala iluminada acima do ponto escuro")

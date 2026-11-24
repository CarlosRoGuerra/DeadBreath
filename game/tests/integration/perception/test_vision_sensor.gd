extends TestCase
## F4-001 (COMPONENT_CONTRACTS §7.1 e §7.2; DATA_STRUCTURES §3.2 e §3.3): VisionSensor com física real, em mundo isolado.
## Cenário padrão: olho em (0, 1, 0), virado para −Z. Alvo em (0, 0, z), com três marcadores (cabeça, tronco e pés) em
## y = 1,5; 1,0; 0,5 locais. O centro fica em y = 1,0 (a altura do olho), então, para z = −8, a distância é 8,0 exatos.
## Lâmpada de teste (OmniLight3D, energia 2, alcance 8) 3 m acima do alvo: exposição 1,0 (1,25 limitado a 1).
## Sem lâmpada nem sonda: escuro (exposição 0).
## Parede parcial (0, 0,45, −4), 4 × 0,9 × 0,2: bloqueia o pé (raio em y = 0,75 em z = −4) e deixa o tronco (y = 1,0)
## e a cabeça (y = 1,25) livres: linha de visão 2/3. Parede total: 4 × 3 × 0,2 em (0, 1,5, −4).
## Autor: AI Engineer (F4-001).

const EYE: Vector3 = Vector3(0.0, 1.0, 0.0)
const SETTLE_FRAMES: int = 3
const TOL: float = 0.0001
const LAYER_WORLD_STATIC: int = 1
const LAYER_WORLD_DYNAMIC: int = 2
const LAYER_PLAYER_BODY: int = 4
const LAYER_ENEMY_BODY: int = 8
const LAYER_VISION_OCCLUDER: int = 64
const PARTIAL_WALL_CENTRE: Vector3 = Vector3(0.0, 0.45, -4.0)
const PARTIAL_WALL_SIZE: Vector3 = Vector3(4.0, 0.9, 0.2)
const FULL_WALL_CENTRE: Vector3 = Vector3(0.0, 1.5, -4.0)
const FULL_WALL_SIZE: Vector3 = Vector3(4.0, 3.0, 0.2)


func _sensor(world: Node3D) -> VisionSensor:
	var sensor: VisionSensor = VisionSensor.new()
	sensor.position = EYE
	world.add_child(sensor)
	return sensor


## Alvo em `at` com os três marcadores (cabeça, tronco e pés). Centro: média dos três, em y = 1,0 local.
func _target(world: Node3D, at: Vector3) -> PerceivableTarget:
	var target: PerceivableTarget = PerceivableTarget.new()
	target.position = at
	world.add_child(target)
	_attach_markers(target)
	return target


func _attach_markers(target: PerceivableTarget) -> void:
	var head: Marker3D = _marker(target, Vector3(0.0, 1.5, 0.0))
	var torso: Marker3D = _marker(target, Vector3(0.0, 1.0, 0.0))
	var feet: Marker3D = _marker(target, Vector3(0.0, 0.5, 0.0))
	var typed: Array[Marker3D] = [head, torso, feet]
	target.sample_points = typed


func _marker(parent: Node3D, local: Vector3) -> Marker3D:
	var marker: Marker3D = Marker3D.new()
	marker.position = local
	parent.add_child(marker)
	return marker


## Lâmpada acima do alvo e sonda de luz no alvo: exposição 1,0.
func _lamp(target: PerceivableTarget) -> void:
	var lamp: OmniLight3D = OmniLight3D.new()
	lamp.position = Vector3(0.0, 3.0, 0.0)
	lamp.light_energy = 2.0
	lamp.omni_range = 8.0
	target.add_child(lamp)
	var probe: LightExposureProbe = LightExposureProbe.new()
	probe.update_hz = 60.0
	target.add_child(probe)
	target.set_light_probe(probe)


func _wall(world: Node3D, centre: Vector3, size: Vector3, layer: int) -> StaticBody3D:
	var body: StaticBody3D = StaticBody3D.new()
	body.position = centre
	body.collision_layer = layer
	var shape_node: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = size
	shape_node.shape = box
	body.add_child(shape_node)
	world.add_child(body)
	return body


func test_ai03_em_pe_iluminado_a_8_m_vale_0_75() -> void:
	# DATA §3.3: 1 × (1 − (8/16)²) × 1 × 1 = 0,75.
	var world: Node3D = add_isolated_world()
	var sensor: VisionSensor = _sensor(world)
	var target: PerceivableTarget = _target(world, Vector3(0.0, 0.0, -8.0))
	_lamp(target)
	await wait_physics_frames(SETTLE_FRAMES)
	var percept: VisualPercept = sensor.evaluate(target)
	assert_almost_eq(percept.visibility, 0.75, TOL, "AI-03: 0,75")
	assert_true(percept.position.is_equal_approx(Vector3(0.0, 1.0, -8.0)), "posição do percept é o centro do alvo")
	assert_true(percept.timestamp > 0.0, "o tempo do percept vem dos frames de física")


func test_ocultacao_de_0_5_reduz_pela_metade() -> void:
	# C8 com física: 0,75 × (1 − 0,5) = 0,375.
	var world: Node3D = add_isolated_world()
	var sensor: VisionSensor = _sensor(world)
	var target: PerceivableTarget = _target(world, Vector3(0.0, 0.0, -8.0))
	_lamp(target)
	target.set_concealment(0.5)
	await wait_physics_frames(SETTLE_FRAMES)
	assert_almost_eq(sensor.evaluate(target).visibility, 0.375, TOL, "ocultação 0,5: 0,75 × 0,5")


func test_agachado_e_rastejando_multiplicam_a_visibilidade() -> void:
	# C2 e C3: 0,75 × 0,6 = 0,45; 0,75 × 0,35 = 0,2625.
	var world: Node3D = add_isolated_world()
	var sensor: VisionSensor = _sensor(world)
	var target: PerceivableTarget = _target(world, Vector3(0.0, 0.0, -8.0))
	_lamp(target)
	target.set_stance(Enums.Stance.CROUCH)
	await wait_physics_frames(SETTLE_FRAMES)
	assert_almost_eq(sensor.evaluate(target).visibility, 0.45, TOL, "C2 agachado")
	target.set_stance(Enums.Stance.CRAWL)
	assert_almost_eq(sensor.evaluate(target).visibility, 0.2625, TOL, "C3 rastejando")


func test_c4_no_escuro_a_8_m_usa_o_piso_de_luz() -> void:
	# C4: sem lâmpada nem sonda, exposição 0: 0,75 × 0,1 = 0,075.
	var world: Node3D = add_isolated_world()
	var sensor: VisionSensor = _sensor(world)
	var target: PerceivableTarget = _target(world, Vector3(0.0, 0.0, -8.0))
	await wait_physics_frames(SETTLE_FRAMES)
	assert_almost_eq(sensor.evaluate(target).visibility, 0.075, TOL, "C4: escuro a 8 m")


func test_c5_no_escuro_a_1_m_tem_o_minimo_de_0_6() -> void:
	# C5: 0,99609375 × 0,6 = 0,59765625.
	var world: Node3D = add_isolated_world()
	var sensor: VisionSensor = _sensor(world)
	var target: PerceivableTarget = _target(world, Vector3(0.0, 0.0, -1.0))
	await wait_physics_frames(SETTLE_FRAMES)
	assert_almost_eq(sensor.evaluate(target).visibility, 0.59765625, TOL, "C5: escuro a 1 m")


func test_fora_do_fov_zera_e_o_percept_nao_vaza_a_posicao() -> void:
	# Cone de 110°: metade = 55°. Alvos a 90° (lado) e 180° (atrás), iluminados: mesmo assim, zero.
	var world: Node3D = add_isolated_world()
	var sensor: VisionSensor = _sensor(world)
	var side: PerceivableTarget = _target(world, Vector3(8.0, 0.0, 0.0))
	var behind: PerceivableTarget = _target(world, Vector3(0.0, 0.0, 8.0))
	_lamp(side)
	_lamp(behind)
	await wait_physics_frames(SETTLE_FRAMES)
	var side_percept: VisualPercept = sensor.evaluate(side)
	var behind_percept: VisualPercept = sensor.evaluate(behind)
	assert_almost_eq(side_percept.visibility, 0.0, TOL, "a 90°: fora do cone")
	assert_almost_eq(behind_percept.visibility, 0.0, TOL, "a 180°: fora do cone")
	assert_true(side_percept.position.is_equal_approx(Vector3.ZERO), "sem visibilidade, posição zerada")
	assert_true(behind_percept.position.is_equal_approx(Vector3.ZERO), "sem visibilidade, posição zerada")


func test_borda_do_cone_50_dentro_60_fora() -> void:
	# 50° < 55° (visto: 0,75); 60° > 55° (zero). Centro a 8 m do olho, na mesma altura.
	var world: Node3D = add_isolated_world()
	var sensor: VisionSensor = _sensor(world)
	var inside: PerceivableTarget = _target(world, Vector3(8.0 * sin(deg_to_rad(50.0)), 0.0, -8.0 * cos(deg_to_rad(50.0))))
	var outside: PerceivableTarget = _target(world, Vector3(8.0 * sin(deg_to_rad(60.0)), 0.0, -8.0 * cos(deg_to_rad(60.0))))
	_lamp(inside)
	_lamp(outside)
	await wait_physics_frames(SETTLE_FRAMES)
	assert_almost_eq(sensor.evaluate(inside).visibility, 0.75, TOL, "50°: dentro do cone")
	assert_almost_eq(sensor.evaluate(outside).visibility, 0.0, TOL, "60°: fora do cone")


func test_alcance_12_m_vale_0_4375_e_16_m_zera() -> void:
	# Distância 12 m: 1 − (12/16)² = 0,4375 (com luz 1). No alcance de 16 m, zero; além, zero.
	var world: Node3D = add_isolated_world()
	var sensor: VisionSensor = _sensor(world)
	var near: PerceivableTarget = _target(world, Vector3(0.0, 0.0, -12.0))
	var edge: PerceivableTarget = _target(world, Vector3(0.0, 0.0, -16.0))
	var beyond: PerceivableTarget = _target(world, Vector3(0.0, 0.0, -17.0))
	_lamp(near)
	_lamp(edge)
	_lamp(beyond)
	await wait_physics_frames(SETTLE_FRAMES)
	assert_almost_eq(sensor.evaluate(near).visibility, 0.4375, TOL, "12 m: 0,4375")
	assert_almost_eq(sensor.evaluate(edge).visibility, 0.0, TOL, "16 m (no limite): 0")
	assert_almost_eq(sensor.evaluate(beyond).visibility, 0.0, TOL, "17 m: fora do alcance")


func test_parede_total_bloqueia_qualquer_camada_de_oclusao() -> void:
	# Parede que cobre os três pontos, em cada camada que o firewall de visão deve respeitar: 0.
	for layer: int in [LAYER_WORLD_STATIC, LAYER_WORLD_DYNAMIC, LAYER_VISION_OCCLUDER]:
		var world: Node3D = add_isolated_world()
		var sensor: VisionSensor = _sensor(world)
		var target: PerceivableTarget = _target(world, Vector3(0.0, 0.0, -8.0))
		_lamp(target)
		_wall(world, FULL_WALL_CENTRE, FULL_WALL_SIZE, layer)
		await wait_physics_frames(SETTLE_FRAMES)
		var percept: VisualPercept = sensor.evaluate(target)
		assert_almost_eq(percept.visibility, 0.0, TOL, "parede total na camada %d: 0" % layer)
		assert_true(percept.position.is_equal_approx(Vector3.ZERO), "camada %d: posição zerada sem visibilidade" % layer)


func test_oclusao_parcial_por_parede_e_por_vision_occluder() -> void:
	# Parede parcial: 2 de 3 pontos com linha livre → 2/3 × 0,75 = 0,5. Vale para mundo estático, dinâmico e
	# vision_occluder (camada 7).
	for layer: int in [LAYER_WORLD_STATIC, LAYER_WORLD_DYNAMIC, LAYER_VISION_OCCLUDER]:
		var world: Node3D = add_isolated_world()
		var sensor: VisionSensor = _sensor(world)
		var target: PerceivableTarget = _target(world, Vector3(0.0, 0.0, -8.0))
		_lamp(target)
		_wall(world, PARTIAL_WALL_CENTRE, PARTIAL_WALL_SIZE, layer)
		await wait_physics_frames(SETTLE_FRAMES)
		assert_almost_eq(sensor.evaluate(target).visibility, 0.5, TOL, "camada %d: 2/3 × 0,75" % layer)


func test_corpos_de_jogador_e_de_inimigo_nao_ocluem() -> void:
	# Camadas 3 (jogador) e 4 (inimigo) fora da máscara de visão: a parede total não bloqueia. Vale 0,75.
	for layer: int in [LAYER_PLAYER_BODY, LAYER_ENEMY_BODY]:
		var world: Node3D = add_isolated_world()
		var sensor: VisionSensor = _sensor(world)
		var target: PerceivableTarget = _target(world, Vector3(0.0, 0.0, -8.0))
		_lamp(target)
		_wall(world, FULL_WALL_CENTRE, FULL_WALL_SIZE, layer)
		await wait_physics_frames(SETTLE_FRAMES)
		assert_almost_eq(sensor.evaluate(target).visibility, 0.75, TOL, "corpo na camada %d não bloqueia" % layer)


func test_corpo_do_alvo_nao_se_oclui_mas_uma_parede_com_o_mesmo_volume_bloqueia() -> void:
	# O alvo fica dentro de um corpo de 0,6 × 2 × 0,6 m. Na camada do jogador (3), o corpo não bloqueia: 0,75.
	# Controle: o mesmo corpo na camada 1 (mundo estático) bloqueia tudo: 0. Assim o teste não passa por vacuidade.
	for layer: int in [LAYER_PLAYER_BODY, LAYER_WORLD_STATIC]:
		var world: Node3D = add_isolated_world()
		var sensor: VisionSensor = _sensor(world)
		var body: StaticBody3D = StaticBody3D.new()
		body.position = Vector3(0.0, 0.0, -8.0)
		body.collision_layer = layer
		var shape_node: CollisionShape3D = CollisionShape3D.new()
		var box: BoxShape3D = BoxShape3D.new()
		box.size = Vector3(0.6, 2.0, 0.6)
		shape_node.shape = box
		shape_node.position = Vector3(0.0, 1.0, 0.0)
		body.add_child(shape_node)
		world.add_child(body)
		var target: PerceivableTarget = PerceivableTarget.new()
		body.add_child(target)
		_attach_markers(target)
		_lamp(target)
		await wait_physics_frames(SETTLE_FRAMES)
		var expected: float = 0.75 if layer == LAYER_PLAYER_BODY else 0.0
		assert_almost_eq(sensor.evaluate(target).visibility, expected, TOL, "corpo na camada %d" % layer)

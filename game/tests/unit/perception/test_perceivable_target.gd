extends TestCase
## F4-001 (COMPONENT_CONTRACTS §7.1): PerceivableTarget. Grupo "perceivable", pontos de amostra em coordenadas globais,
## fatores de postura (em pé 1,0; agachado 0,6; rastejando 0,35), ocultação limitada a 0..1 e exposição 0 sem sonda.
## Autor: AI Engineer (F4-001).

const TOL: float = 0.0001


func _target(at: Vector3) -> PerceivableTarget:
	var target: PerceivableTarget = PerceivableTarget.new()
	target.position = at
	add_child_autofree(target)
	return target


func _marker(parent: Node3D, local: Vector3) -> Marker3D:
	var marker: Marker3D = Marker3D.new()
	marker.position = local
	parent.add_child(marker)
	return marker


func test_entra_no_grupo_perceivable() -> void:
	var target: PerceivableTarget = _target(Vector3.ZERO)
	assert_eq(PerceivableTarget.GROUP, &"perceivable", "nome do grupo (§7.1)")
	assert_true(target.is_in_group(&"perceivable"), "o alvo está no grupo perceivable")


func test_fatores_de_postura() -> void:
	var target: PerceivableTarget = _target(Vector3.ZERO)
	assert_almost_eq(target.get_stance_factor(), 1.0, TOL, "em pé: 1,0 (padrão)")
	target.set_stance(Enums.Stance.CROUCH)
	assert_almost_eq(target.get_stance_factor(), 0.6, TOL, "agachado: 0,6")
	target.set_stance(Enums.Stance.CRAWL)
	assert_almost_eq(target.get_stance_factor(), 0.35, TOL, "rastejando: 0,35")
	target.set_stance(Enums.Stance.STAND)
	assert_almost_eq(target.get_stance_factor(), 1.0, TOL, "volta a em pé: 1,0")


func test_ocultacao_fica_entre_zero_e_um() -> void:
	var target: PerceivableTarget = _target(Vector3.ZERO)
	assert_almost_eq(target.get_concealment(), 0.0, TOL, "exposto por padrão (até a F5)")
	target.set_concealment(0.4)
	assert_almost_eq(target.get_concealment(), 0.4, TOL, "valor dentro da faixa")
	target.set_concealment(1.7)
	assert_almost_eq(target.get_concealment(), 1.0, TOL, "acima de 1 vira 1")
	target.set_concealment(-0.3)
	assert_almost_eq(target.get_concealment(), 0.0, TOL, "abaixo de 0 vira 0")


func test_exposicao_sem_sonda_e_zero() -> void:
	var target: PerceivableTarget = _target(Vector3.ZERO)
	assert_almost_eq(target.get_light_exposure(), 0.0, TOL, "sem sonda de luz: escuro")


func test_pontos_de_amostra_em_coordenadas_globais() -> void:
	# Alvo em (3, 0, 2) girado 90° em Y: (x, y, z) vira (z, y, −x). Marcador local (1, 0, 0) → (3, 0, 1).
	var target: PerceivableTarget = _target(Vector3(3.0, 0.0, 2.0))
	target.rotation_degrees = Vector3(0.0, 90.0, 0.0)
	var head: Marker3D = _marker(target, Vector3(0.0, 1.0, 0.0))
	var feet: Marker3D = _marker(target, Vector3(1.0, 0.0, 0.0))
	var typed: Array[Marker3D] = [head, feet]
	target.sample_points = typed
	var points: PackedVector3Array = target.get_sample_points()
	assert_eq(points.size(), 2, "dois pontos de amostra")
	if points.size() == 2:
		assert_true(points[0].is_equal_approx(Vector3(3.0, 1.0, 2.0)), "cabeça: %s" % [str(points[0])])
		assert_true(points[1].is_equal_approx(Vector3(3.0, 0.0, 1.0)), "pés: %s" % [str(points[1])])


func test_marcador_nulo_e_ignorado() -> void:
	var target: PerceivableTarget = _target(Vector3.ZERO)
	var torso: Marker3D = _marker(target, Vector3(0.0, 1.0, 0.0))
	var typed: Array[Marker3D] = [null, torso]
	target.sample_points = typed
	var points: PackedVector3Array = target.get_sample_points()
	assert_eq(points.size(), 1, "o marcador nulo não entra na lista")


func test_sem_marcadores_usa_a_origem() -> void:
	var target: PerceivableTarget = _target(Vector3(0.0, 0.0, -4.0))
	var points: PackedVector3Array = target.get_sample_points()
	assert_eq(points.size(), 1, "um ponto de fallback")
	if points.size() == 1:
		assert_true(points[0].is_equal_approx(Vector3(0.0, 0.0, -4.0)), "fallback é a origem global")

extends TestCase
## PHY-04 e PHY-05 pelo componente (TEST_PLAN §2.2; card F2-004: "PHY-04/05 via componente"). A bombinha entra pelo
## PhysiologyComponent.apply_medication; a stamina é lida pelo get_snapshot. Autor: Physiological Systems Engineer.

const Fx := preload("res://tests/unit/physiology/fixtures/physio_fixture.gd")
const DT: float = 1.0 / 60.0
const REDUCTION_LIMIT: float = 0.30
const TOLERANCE: float = 0.0001

var _instances: Array[Node] = []


func after_each() -> void:
	for node: Node in _instances:
		if is_instance_valid(node):
			node.free()
	_instances.clear()


func _component(seed_value: int) -> PhysiologyComponent:
	var component: PhysiologyComponent = PhysiologyComponent.new()
	component.stamina_config = load(Fx.DIR + "stamina_config.tres") as StaminaConfig
	component.stress_config = load(Fx.DIR + "stress_config.tres") as StressConfig
	component.respiratory_config = load(Fx.DIR + "respiratory_config.tres") as RespiratoryConfig
	component.coupling_config = load(Fx.DIR + "coupling_config.tres") as CouplingConfig
	component.rng_seed = seed_value
	add_child_autofree(component)
	return component


## Estado com severidade 0,6 em SYMPTOMATIC, pelo caminho de persistência do componente.
func _symptomatic(component: PhysiologyComponent, stamina_value: float = 100.0) -> void:
	var data: Dictionary = component.to_dict()
	var resp: Dictionary = data["respiratory"]
	resp["severity"] = 0.6
	resp["peak_severity"] = 0.6
	resp["state"] = "SYMPTOMATIC"
	resp["state_dwell"] = 5.0
	resp["exertion_ema"] = 0.0
	var stamina: Dictionary = data["stamina"]
	stamina["value"] = stamina_value
	stamina["exhausted"] = stamina_value <= 0.0
	component.from_dict(data)


func test_phy04_componente_bombinha_reduz_0_30_em_ate_3_s() -> void:
	var component: PhysiologyComponent = _component(401)
	_symptomatic(component)
	var before: float = component.get_snapshot().symptom_severity
	assert_true(component.apply_medication(load(Fx.DIR + "medication_inhaler.tres") as MedicationProfile), "primeira dose")
	var standing: PhysiologyInputs = Fx.inputs(0.0, Enums.Gait.IDLE, false)
	for _i: int in int(round(3.0 / DT)):
		component.step(DT, standing)
	var reduction: float = before - component.get_snapshot().symptom_severity
	note("PHY-04 pelo componente: redução absoluta em 3 s = %.4f" % reduction)
	assert_true(reduction >= REDUCTION_LIMIT, "redução absoluta ≥ 0,30 em ≤ 3 s (obtido %.4f)" % reduction)


func test_phy05_componente_bombinha_nao_mexe_na_stamina() -> void:
	var component: PhysiologyComponent = _component(501)
	_symptomatic(component, 42.0)
	var before: float = component.get_snapshot().stamina
	component.apply_medication(load(Fx.DIR + "medication_inhaler.tres") as MedicationProfile)
	assert_almost_eq(component.get_snapshot().stamina, before, TOLERANCE, "aplicar a bombinha não altera a stamina (PHY-INV-2)")


func test_phy05_componente_stamina_zerada_nao_altera_a_severidade() -> void:
	var full: PhysiologyComponent = _component(502)
	var empty: PhysiologyComponent = _component(502)
	_symptomatic(full, 100.0)
	_symptomatic(empty, 0.0)
	var walk: PhysiologyInputs = Fx.inputs(0.6, Enums.Gait.WALK)
	full.step(DT, walk)
	empty.step(DT, walk)
	assert_almost_eq(full.get_snapshot().symptom_severity, empty.get_snapshot().symptom_severity, TOLERANCE,
		"no mesmo tick, stamina 100 e stamina 0 dão a mesma severidade (PHY-INV-2)")
	assert_true(full.get_coupling().sprint_allowed and not empty.get_coupling().sprint_allowed,
		"o acoplamento do sprint é o único efeito da stamina zerada")

extends TestCase
## F1-007 (COMPONENT_CONTRACTS §3): tempo de segurar. Com requires_steady_hands, o tempo é
## hold_time × (1 + 1,5 × (1 − steadiness)). Unit: função pura sobre um Interactable fora da árvore.
## Autor: Gameplay Engineer.

const TOLERANCE: float = 0.0001
const HOLD_S: float = 0.5

var _instances: Array[Node] = []


func after_each() -> void:
	for node: Node in _instances:
		if is_instance_valid(node):
			node.free()
	_instances.clear()


func _target(steady: bool) -> Interactable:
	var target: Interactable = Interactable.new()
	target.hold_time = HOLD_S
	target.requires_steady_hands = steady
	_instances.append(target)
	return target


func test_sem_maos_firmes_o_tempo_e_o_hold_time() -> void:
	assert_almost_eq(InteractionComponent.required_hold_time(_target(false), 0.0), HOLD_S, TOLERANCE, "steadiness não importa sem requires_steady_hands")


func test_com_maos_firmes_e_steadiness_um_o_tempo_e_o_hold_time() -> void:
	assert_almost_eq(InteractionComponent.required_hold_time(_target(true), 1.0), HOLD_S, TOLERANCE, "mãos firmes: sem multiplicador")


func test_com_steadiness_zero_o_tempo_e_duas_vezes_e_meia() -> void:
	assert_almost_eq(InteractionComponent.required_hold_time(_target(true), 0.0), HOLD_S * 2.5, TOLERANCE, "1 + 1,5 × 1 = 2,5")


func test_com_steadiness_meio_o_multiplicador_e_um_e_tres_quartos() -> void:
	assert_almost_eq(InteractionComponent.required_hold_time(_target(true), 0.5), HOLD_S * 1.75, TOLERANCE, "1 + 1,5 × 0,5 = 1,75")


func test_steadiness_fora_da_faixa_e_limitada() -> void:
	assert_almost_eq(InteractionComponent.required_hold_time(_target(true), 5.0), HOLD_S, TOLERANCE, "acima de 1 vira 1")
	assert_almost_eq(InteractionComponent.required_hold_time(_target(true), -3.0), HOLD_S * 2.5, TOLERANCE, "abaixo de 0 vira 0")

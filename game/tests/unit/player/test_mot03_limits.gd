extends TestCase
## MOT-03 (TEST_PLAN §2.1, MOT-INV-3): apply_limits só reduz velocidade e sprint. Unit: o motor não
## entra na árvore; apply_limits só guarda o estado, então não há física aqui.
## Autor: Gameplay Engineer (F1-006).

const SPRINT_TOLERANCE: float = 0.0001

var _instances: Array[Node] = []


func after_each() -> void:
	for node: Node in _instances:
		if is_instance_valid(node):
			node.free()
	_instances.clear()


func _new_motor() -> PlayerMotor:
	var motor: PlayerMotor = PlayerMotor.new()
	motor.config = PlayerMotorConfig.new()
	_instances.append(motor)
	return motor


func _coupling(max_sprint_multiplier: float, sprint_allowed: bool = true) -> CouplingFactors:
	var coupling: CouplingFactors = CouplingFactors.new()
	coupling.max_sprint_multiplier = max_sprint_multiplier
	coupling.sprint_allowed = sprint_allowed
	return coupling


func test_mot03_multiplicador_acima_de_um_nao_aumenta_o_sprint() -> void:
	var motor: PlayerMotor = _new_motor()
	var config_sprint: float = motor.config.sprint_speed
	motor.apply_limits(_coupling(1.5))
	assert_almost_eq(motor.get_sprint_speed_limit(), config_sprint, SPRINT_TOLERANCE, "multiplicador 1,5 não pode passar de sprint_speed")
	motor.apply_limits(_coupling(10.0))
	assert_almost_eq(motor.get_sprint_speed_limit(), config_sprint, SPRINT_TOLERANCE, "multiplicador 10 não pode passar de sprint_speed")


func test_mot03_multiplicador_abaixo_de_um_reduz_o_sprint() -> void:
	var motor: PlayerMotor = _new_motor()
	motor.apply_limits(_coupling(0.5))
	assert_almost_eq(motor.get_sprint_speed_limit(), motor.config.sprint_speed * 0.5, SPRINT_TOLERANCE, "multiplicador 0,5 reduz pela metade")


func test_mot03_multiplicador_negativo_nao_gera_velocidade_negativa() -> void:
	var motor: PlayerMotor = _new_motor()
	motor.apply_limits(_coupling(-2.0))
	assert_almost_eq(motor.get_sprint_speed_limit(), 0.0, SPRINT_TOLERANCE, "multiplicador negativo vira zero")


func test_mot03_sprint_proibido_pelo_acoplamento_fica_proibido() -> void:
	var motor: PlayerMotor = _new_motor()
	motor.apply_limits(_coupling(1.0, false))
	assert_false(motor.is_sprint_allowed(), "sprint_allowed = false tem de valer")
	# O acoplamento é reenviado a cada tick (contrato §1): o estado anterior não é acumulado.
	motor.apply_limits(_coupling(1.0, true))
	assert_true(motor.is_sprint_allowed(), "o limite vale só enquanto o acoplamento o pede")


func test_mot03_neutro_mantem_a_config() -> void:
	var motor: PlayerMotor = _new_motor()
	motor.apply_limits(CouplingFactors.neutral())
	assert_almost_eq(motor.get_sprint_speed_limit(), motor.config.sprint_speed, SPRINT_TOLERANCE, "neutro = config inteira")
	assert_true(motor.is_sprint_allowed(), "neutro permite sprint")


func test_mot03_limites_nao_mudam_a_velocidade_de_caminhada() -> void:
	var motor: PlayerMotor = _new_motor()
	motor.apply_limits(_coupling(0.0, false))
	# O multiplicador do sprint não entra na caminhada: passar 0,0 prova isso.
	var walk: float = PlayerMotor.speed_for(Enums.Gait.WALK, Enums.Stance.STAND, motor.config, 0.0)
	assert_almost_eq(walk, motor.config.walk_speed, SPRINT_TOLERANCE, "a caminhada não é afetada pelo acoplamento de sprint")

extends TestCase
## Unit: PlayerMotorConfig (DATA_STRUCTURES §1.1 e acréscimos da F1-006) e o fallback de config ausente
## (COMPONENT_CONTRACTS §2: sem config, usa os padrões e registra Log.error). Autor: Gameplay Engineer (F1-006).

const CONFIG_PATH: String = "res://content/data/player_motor_config.tres"
const FLOAT_TOLERANCE: float = 0.0001

## Valores da tabela de DATA_STRUCTURES §1.1 e da tabela de acréscimos da F1-006. Mudou a config, revalida.
const TABLE: Dictionary = {
	"walk_speed": 1.6, "slow_walk_speed": 0.9, "crouch_speed": 1.0, "crawl_speed": 0.5, "sprint_speed": 4.8,
	"acceleration": 10.0, "deceleration": 14.0, "stand_height": 1.75, "crouch_height": 1.10,
	"crawl_height": 0.55, "capsule_radius": 0.25, "step_height": 0.30, "fall_injury_height": 2.5,
	"head_bob_amplitude": 0.03,
	"eye_offset": 0.10, "stance_transition_time_s": 0.25, "gravity": 9.8, "floor_snap_length": 0.30,
	"pitch_limit_deg": 85.0, "camera_step_smoothing": 12.0,
	"stride_slow": 0.5, "stride_walk": 0.7, "stride_sprint": 1.1, "stride_crouch": 0.5, "stride_crawl": 0.4,
	"head_bob_frequency_per_stride": 0.5,
}

var _instances: Array[Node] = []
var _errors: PackedStringArray = PackedStringArray()


func after_each() -> void:
	for node: Node in _instances:
		if is_instance_valid(node):
			node.free()
	_instances.clear()
	if Log.message_logged.is_connected(_on_logged):
		Log.message_logged.disconnect(_on_logged)
	_errors = PackedStringArray()


func _on_logged(level: int, category: StringName, message: String) -> void:
	if level == Log.ERROR and category == &"player":
		_errors.append(message)


func test_config_do_arquivo_tem_os_valores_da_tabela() -> void:
	var config: PlayerMotorConfig = load(CONFIG_PATH) as PlayerMotorConfig
	assert_not_null(config, "player_motor_config.tres deve carregar como PlayerMotorConfig")
	if config == null:
		return
	for key: String in TABLE.keys():
		var expected: float = float(TABLE[key])
		var actual: float = float(config.get(key))
		assert_almost_eq(actual, expected, FLOAT_TOLERANCE, "parâmetro '%s' do .tres" % key)


func test_config_padrao_do_codigo_tem_os_valores_da_tabela() -> void:
	var config: PlayerMotorConfig = PlayerMotorConfig.new()
	for key: String in TABLE.keys():
		var expected: float = float(TABLE[key])
		var actual: float = float(config.get(key))
		assert_almost_eq(actual, expected, FLOAT_TOLERANCE, "padrão de código de '%s'" % key)


func test_config_ausente_usa_padroes_e_registra_erro() -> void:
	Log.message_logged.connect(_on_logged)
	var motor: PlayerMotor = PlayerMotor.new()
	_instances.append(motor)
	motor.config = null
	assert_almost_eq(motor.get_sprint_speed_limit(), 4.8, FLOAT_TOLERANCE, "sem config, o sprint usa o padrão de 4,8 m/s")
	assert_not_null(motor.config, "o motor cria a config padrão")
	assert_eq(_errors.size(), 1, "exatamente um Log.error de config ausente (obtido %d)" % _errors.size())

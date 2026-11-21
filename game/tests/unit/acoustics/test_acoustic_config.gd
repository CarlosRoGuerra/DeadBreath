extends TestCase
## AcousticConfig (DATA_STRUCTURES §2.2 e §9): o .tres de produção tem os valores da tabela §2.2 e é igual aos
## padrões do código. Autor: AI Engineer (F3-001).

const CONFIG_PATH: String = "res://content/data/acoustics/acoustic_config.tres"
const TOL: float = 0.0001


func test_tres_de_producao_tem_os_valores_da_tabela_2_2() -> void:
	var config: AcousticConfig = load(CONFIG_PATH) as AcousticConfig
	assert_not_null(config, "acoustic_config.tres carrega como AcousticConfig")
	if config == null:
		return
	assert_almost_eq(config.portal_open_loss_db, 3.0, TOL, "portal aberto 3 dB")
	assert_almost_eq(config.portal_closed_loss_db, 18.0, TOL, "portal fechado 18 dB")
	assert_almost_eq(config.wall_transmission_loss_db, 25.0, TOL, "parede 25 dB")
	assert_almost_eq(config.floor_transmission_loss_db, 30.0, TOL, "piso 30 dB")
	assert_almost_eq(config.extra_loss_per_m_db, 0.1, TOL, "0,1 dB por metro")
	assert_almost_eq(config.min_distance_m, 1.0, TOL, "distância mínima 1 m")
	assert_almost_eq(config.position_error_per_db_lost, 0.05, TOL, "erro de posição 0,05 m por dB")


func test_tres_de_producao_igual_aos_padroes_do_codigo() -> void:
	var loaded: AcousticConfig = load(CONFIG_PATH) as AcousticConfig
	var defaults: AcousticConfig = AcousticConfig.new()
	assert_not_null(loaded, "o .tres carrega")
	if loaded == null:
		return
	assert_almost_eq(loaded.portal_open_loss_db, defaults.portal_open_loss_db, TOL, "portal aberto")
	assert_almost_eq(loaded.portal_closed_loss_db, defaults.portal_closed_loss_db, TOL, "portal fechado")
	assert_almost_eq(loaded.wall_transmission_loss_db, defaults.wall_transmission_loss_db, TOL, "parede")
	assert_almost_eq(loaded.floor_transmission_loss_db, defaults.floor_transmission_loss_db, TOL, "piso")
	assert_almost_eq(loaded.extra_loss_per_m_db, defaults.extra_loss_per_m_db, TOL, "perda por metro")
	assert_almost_eq(loaded.min_distance_m, defaults.min_distance_m, TOL, "distância mínima")
	assert_almost_eq(loaded.position_error_per_db_lost, defaults.position_error_per_db_lost, TOL, "erro de posição")

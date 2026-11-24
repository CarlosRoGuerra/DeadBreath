extends TestCase
## F4-006b (DATA_STRUCTURES §1.5; COMPONENT_CONTRACTS §5): fórmulas puras da ameaça percebida pelo jogador, com valores
## calculados à mão, e o susto do monitor (COMPONENT_CONTRACTS §6.5; DATA §1.3). Autor: Gameplay Engineer.

const TOL: float = 0.000001


func test_proximidade_de_inimigo_visto_segue_1_em_3_m_e_0_em_15_m() -> void:
	assert_almost_eq(PlayerThreatMonitor.seen_proximity_for(3.0), 1.0, TOL, "a 3 m: 1")
	assert_almost_eq(PlayerThreatMonitor.seen_proximity_for(9.0), 0.5, TOL, "a 9 m: (1 − 6/12) = 0,5")
	assert_almost_eq(PlayerThreatMonitor.seen_proximity_for(15.0), 0.0, TOL, "a 15 m: 0")
	assert_almost_eq(PlayerThreatMonitor.seen_proximity_for(20.0), 0.0, TOL, "além de 15 m: 0")
	assert_almost_eq(PlayerThreatMonitor.seen_proximity_for(1.0), 1.0, TOL, "mais perto que 3 m: limitado a 1")


func test_fator_de_audicao_segue_0_em_15_db_e_1_em_45_db() -> void:
	assert_almost_eq(PlayerThreatMonitor.heard_factor_for(10.0), 0.0, TOL, "10 dB: 0")
	assert_almost_eq(PlayerThreatMonitor.heard_factor_for(15.0), 0.0, TOL, "15 dB: 0")
	assert_almost_eq(PlayerThreatMonitor.heard_factor_for(30.0), 0.5, TOL, "30 dB: (30 − 15)/30 = 0,5")
	assert_almost_eq(PlayerThreatMonitor.heard_factor_for(45.0), 1.0, TOL, "45 dB: 1")
	assert_almost_eq(PlayerThreatMonitor.heard_factor_for(70.0), 1.0, TOL, "70 dB: limitado a 1")


func test_nivel_de_ameaca_e_o_maximo_com_perseguicao_em_1() -> void:
	assert_almost_eq(PlayerThreatMonitor.threat_level_for(0.6, 0.4, false), 0.6, TOL, "visão domina: 0,6")
	assert_almost_eq(PlayerThreatMonitor.threat_level_for(0.2, 0.8, false), 0.4, TOL, "audição pesa 0,5: 0,4")
	assert_almost_eq(PlayerThreatMonitor.threat_level_for(0.2, 0.2, true), 1.0, TOL, "perseguição vale 1")
	assert_almost_eq(PlayerThreatMonitor.threat_level_for(0.0, 0.0, false), 0.0, TOL, "sem ameaça: 0")


func test_susto_do_monitor_segue_a_formula_e_so_passa_de_55_db() -> void:
	var monitor: PlayerThreatMonitor = add_child_autofree(PlayerThreatMonitor.new()) as PlayerThreatMonitor
	var amounts: Array[float] = []
	var on_startled: Callable = func(amount: float) -> void: amounts.append(amount)
	monitor.startled.connect(on_startled)
	monitor.receive_heard(_heard(Enums.NoiseCategory.DOOR, 75.0, &"door_slam", false))
	monitor.receive_heard(_heard(Enums.NoiseCategory.DOOR, 40.0, &"door_slam", true))
	monitor.receive_heard(_heard(Enums.NoiseCategory.DOOR, 55.0, &"door_slam", false))
	assert_eq(amounts.size(), 2, "dois sons chegam a 55 dB ou mais")
	if amounts.size() == 2:
		assert_almost_eq(amounts[0], 20.0, TOL, "75 dB: (75 − 55)/2 + 10 = 20")
		assert_almost_eq(amounts[1], 10.0, TOL, "55 dB: 10 (piso)")


## Dado mínimo de um PlayerHeardNoise para o monitor.
func _heard(category: Enums.NoiseCategory, db: float, sound: StringName, from_enemy: bool) -> PlayerHeardNoise:
	var heard: PlayerHeardNoise = PlayerHeardNoise.new()
	heard.category = category
	heard.perceived_db = db
	heard.sound_id = sound
	heard.source_is_enemy = from_enemy
	return heard

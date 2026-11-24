extends TestCase
## F4-006b (DATA_STRUCTURES §6.1): janelas de 3 s do PlayerThreatMonitor. Sons de inimigo envelhecem e saem da janela; o
## grito de perseguição vale 3 s; to_dict e from_dict fazem a volta completa (também por JSON, como no checkpoint).
## Sem câmera e fora da cena de jogo: o monitor só avança o tempo e a janela. Autor: Gameplay Engineer.

const TOL: float = 0.0001
const WINDOW_S: float = 3.0


func test_grito_de_perseguicao_vale_3_s_e_depois_acaba() -> void:
	var monitor: PlayerThreatMonitor = add_child_autofree(PlayerThreatMonitor.new()) as PlayerThreatMonitor
	monitor.receive_heard(_enemy_heard(Enums.NoiseCategory.VOICE, 70.0, &"voice_chase_shout"))
	monitor.step(0.1)
	assert_true(monitor.get_threat_source().sample().in_chase, "logo após o grito, perseguição")
	monitor.step(2.8)
	assert_true(monitor.get_threat_source().sample().in_chase, "2,9 s depois, ainda em perseguição")
	monitor.step(0.5)
	assert_false(monitor.get_threat_source().sample().in_chase, "3,4 s depois, a perseguição acabou")


func test_corrida_de_inimigo_tambem_vale_perseguicao_pela_janela() -> void:
	var monitor: PlayerThreatMonitor = add_child_autofree(PlayerThreatMonitor.new()) as PlayerThreatMonitor
	monitor.receive_heard(_enemy_heard(Enums.NoiseCategory.RUNNING, 50.0, &"footstep_wood"))
	monitor.step(0.1)
	assert_true(monitor.get_threat_source().sample().in_chase, "corrida de inimigo ouvida: perseguição")
	monitor.step(3.0)
	assert_false(monitor.get_threat_source().sample().in_chase, "passados 3 s, a corrida sai da janela")


func test_fator_de_audicao_envelhece_e_some_depois_de_3_s() -> void:
	var monitor: PlayerThreatMonitor = add_child_autofree(PlayerThreatMonitor.new()) as PlayerThreatMonitor
	monitor.receive_heard(_enemy_heard(Enums.NoiseCategory.FOOTSTEP, 30.0, &"footstep_wood"))
	monitor.step(0.1)
	assert_almost_eq(monitor.get_threat_source().sample().heard_factor, 0.5, TOL, "30 dB: fator 0,5")
	assert_almost_eq(monitor.get_threat_source().sample().threat_level, 0.25, TOL, "audição pesa 0,5: nível 0,25")
	monitor.step(3.0)
	assert_almost_eq(monitor.get_threat_source().sample().heard_factor, 0.0, TOL, "passados 3 s, o som saiu da janela")


func test_som_de_outra_fonte_nao_entra_na_janela_de_inimigo() -> void:
	var monitor: PlayerThreatMonitor = add_child_autofree(PlayerThreatMonitor.new()) as PlayerThreatMonitor
	monitor.receive_heard(_heard(Enums.NoiseCategory.VOICE, 70.0, &"voice_chase_shout", false))
	monitor.step(0.1)
	assert_false(monitor.get_threat_source().sample().in_chase, "fonte que não é inimigo não gera perseguição")
	var window: Array = monitor.to_dict()["recent_enemy_heard"]
	assert_eq(window.size(), 0, "a janela de inimigo fica vazia")


func test_to_dict_e_from_dict_fazem_a_volta_completa_pelo_json() -> void:
	var monitor: PlayerThreatMonitor = add_child_autofree(PlayerThreatMonitor.new()) as PlayerThreatMonitor
	monitor.receive_heard(_enemy_heard(Enums.NoiseCategory.FOOTSTEP, 42.0, &"footstep_wood"))
	monitor.step(0.5)
	monitor.receive_heard(_enemy_heard(Enums.NoiseCategory.VOICE, 66.0, &"voice_chase_shout"))
	monitor.step(0.25)
	var saved: Dictionary = monitor.to_dict()
	var text: String = JSON.stringify(saved)
	var parsed: Dictionary = JSON.parse_string(text)
	var restored: PlayerThreatMonitor = add_child_autofree(PlayerThreatMonitor.new()) as PlayerThreatMonitor
	restored.from_dict(parsed)
	var again: Dictionary = restored.to_dict()
	assert_almost_eq(float(again["last_seen_chase_s"]), float(saved["last_seen_chase_s"]), TOL, "tempo da perseguição vista")
	var before_list: Array = saved["recent_enemy_heard"]
	var after_list: Array = again["recent_enemy_heard"]
	assert_eq(after_list.size(), before_list.size(), "mesmo número de sons na janela")
	for index: int in range(mini(before_list.size(), after_list.size())):
		var a: Dictionary = before_list[index]
		var b: Dictionary = after_list[index]
		assert_eq(int(b["category"]), int(a["category"]), "categoria do som %d" % index)
		assert_almost_eq(float(b["perceived_db"]), float(a["perceived_db"]), TOL, "dB do som %d" % index)
		assert_eq(String(b["sound_id"]), String(a["sound_id"]), "sound_id do som %d" % index)
		assert_almost_eq(float(b["age_s"]), float(a["age_s"]), TOL, "idade do som %d" % index)
	restored.step(0.0)
	assert_true(restored.get_threat_source().sample().in_chase, "a perseguição restaurada continua ativa")


func test_from_dict_sem_janela_volta_ao_repouso() -> void:
	var monitor: PlayerThreatMonitor = add_child_autofree(PlayerThreatMonitor.new()) as PlayerThreatMonitor
	monitor.from_dict({})
	monitor.step(0.0)
	var sample: ThreatSample = monitor.get_threat_source().sample()
	assert_almost_eq(sample.threat_level, 0.0, TOL, "sem dados salvos, ameaça 0")
	assert_false(sample.in_chase, "sem dados salvos, sem perseguição")


## PlayerHeardNoise de inimigo (source_is_enemy) para o monitor.
func _enemy_heard(category: Enums.NoiseCategory, db: float, sound: StringName) -> PlayerHeardNoise:
	return _heard(category, db, sound, true)


func _heard(category: Enums.NoiseCategory, db: float, sound: StringName, from_enemy: bool) -> PlayerHeardNoise:
	var heard: PlayerHeardNoise = PlayerHeardNoise.new()
	heard.category = category
	heard.perceived_db = db
	heard.sound_id = sound
	heard.source_is_enemy = from_enemy
	return heard

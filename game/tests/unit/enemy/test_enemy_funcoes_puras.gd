extends TestCase
## F4-004 (AI-08 e contrato do controlador): funções puras do EnemyController, sem cena. A inspeção (ENM-INV-2) vira
## exatamente um VisualPercept na posição do esconderijo se achou, e nenhum se não achou. Marcha e passo seguem o perfil
## e o NoiseLevels. A paridade de superfície com o PlayerNoiseMap é conferida aqui (teste pode ler o código do jogador;
## o componente do inimigo não pode). Autor: AI Engineer (F4-004).

const SURFACES: Array[StringName] = [&"wood", &"carpet", &"tile", &"concrete", &"default", &"desconhecida"]


func test_ai08_inspecao_que_achou_gera_um_percept_na_posicao_do_esconderijo() -> void:
	var at: Vector3 = Vector3(2.0, 0.0, -3.0)
	var percepts: Array[VisualPercept] = EnemyController.percepts_from_inspection(true, at, 4.5)
	assert_eq(percepts.size(), 1, "achou: exatamente um VisualPercept")
	if percepts.size() == 1:
		assert_true(percepts[0].position.is_equal_approx(at), "posição do percept é a do esconderijo")
		assert_almost_eq(percepts[0].visibility, 1.0, 0.0001, "visibilidade da inspeção de perto: 1,0")
		assert_almost_eq(percepts[0].timestamp, 4.5, 0.0001, "tempo do percept é o da inspeção")


func test_ai08_inspecao_que_nao_achou_nao_gera_percept() -> void:
	var percepts: Array[VisualPercept] = EnemyController.percepts_from_inspection(false, Vector3(2.0, 0.0, -3.0), 4.5)
	assert_eq(percepts.size(), 0, "não achou: nenhum percept")


func test_marcha_segue_a_velocidade_do_perfil() -> void:
	var enemy: EnemyController = EnemyController.new()
	enemy.profile = AIProfile.new()
	var patrol: float = enemy.profile.patrol_speed
	var investigate: float = enemy.profile.investigate_speed
	var chase: float = enemy.profile.chase_speed
	assert_eq(enemy.gait_for_speed(chase), &"run", "velocidade de perseguição: correr")
	assert_eq(enemy.gait_for_speed(investigate), &"walk", "investigação (acima da patrulha): andar")
	assert_eq(enemy.gait_for_speed(patrol), &"slow", "patrulha: marcha devagar")
	assert_eq(enemy.gait_for_speed(0.0), &"slow", "parado: devagar (sem passo, pela distância zero)")
	enemy.free()


func test_distancia_entre_passos_por_marcha() -> void:
	assert_almost_eq(EnemyController.stride_for_gait(&"run"), 1.1, 0.0001, "passo de corrida: 1,1 m")
	assert_almost_eq(EnemyController.stride_for_gait(&"walk"), 0.7, 0.0001, "passo de andar: 0,7 m")
	assert_almost_eq(EnemyController.stride_for_gait(&"slow"), 0.6, 0.0001, "passo devagar: 0,6 m")


func test_superficie_do_inimigo_bate_com_a_do_jogador() -> void:
	# O mesmo piso tem de gerar o mesmo som para o inimigo e para o jogador (o nível do ruído e o sound_id).
	for surface: StringName in SURFACES:
		var normalised: StringName = EnemyController.normalise_surface(surface)
		assert_eq(EnemyController._level_surface(normalised), PlayerNoiseMap.level_surface(surface),
			"nível do ruído para '%s' igual ao do jogador" % surface)
		assert_eq(StringName("footstep_" + String(normalised)), PlayerNoiseMap.footstep_sound(surface),
			"sound_id de passo para '%s' igual ao do jogador" % surface)

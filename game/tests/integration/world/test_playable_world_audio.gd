extends TestCase
## Integração da F3-003b na sandbox jogável (Director): o NoiseAudioRouter e a RainAmbience estão na cena e ligados
## ao AcousticWorld dela; um som do mundo perto do jogador toca no router com a regra de ganho compartilhada; a camada
## de chuva segue o piso da sala do ouvinte; o trovão está ligado no nível (contrato da F3-002) e chega à ambiência.
## Integração da F3-006: a mesma porta gera a legenda na UI de legendas da cena (ACC-04).
## Integração da F3-008: a visão de debug acústica está na cena, desligada por padrão e lendo as 6 salas do nível.
## A cena é carregada uma vez: os testes só emitem eventos e leem registros (orçamento da suíte < 10 s).

const PLAYABLE_PATH: String = "res://content/levels/sandbox_playable.tscn"
const TOL: float = 0.0001

var _root: Node = null


func before_all() -> void:
	var scene: PackedScene = load(PLAYABLE_PATH) as PackedScene
	_root = scene.instantiate()
	add_child(_root)
	await wait_physics_frames(3)


func after_all() -> void:
	await release_and_flush(_root)
	_root = null


func _world() -> AcousticWorld:
	return _root.get_node("AcousticWorld") as AcousticWorld


func _router() -> NoiseAudioRouter:
	return _root.get_node("NoiseAudioRouter") as NoiseAudioRouter


func _rain() -> RainAmbience:
	return _root.get_node("RainAmbience") as RainAmbience


func _ear_position() -> Vector3:
	var camera: Camera3D = get_viewport().get_camera_3d()
	return camera.global_position if camera != null else Vector3.ZERO


func test_router_e_ambiencia_estao_ligados_ao_mundo_da_cena() -> void:
	assert_not_null(_router(), "a cena tem o NoiseAudioRouter")
	assert_not_null(_rain(), "a cena tem a RainAmbience")
	if _router() == null or _rain() == null:
		return
	assert_true(_world().noise_resolved_for_player.is_connected(_router()._on_noise_resolved),
		"o router ouve o AcousticWorld da cena")
	assert_true(_world().thunder_started.is_connected(_rain()._on_thunder_started),
		"a ambiência ouve o trovão do AcousticWorld da cena")
	assert_true(_world().thunder_enabled, "trovão ligado na sandbox (o nível liga; contrato da F3-002)")
	assert_not_null(get_viewport().get_camera_3d(), "pré-condição: a câmera do jogador é o ouvido")


func test_porta_do_mundo_perto_do_jogador_toca_no_router_com_a_regra_de_ganho() -> void:
	var before: int = _router().played_log.size()
	var at: Vector3 = _ear_position() + Vector3(0.0, 0.3, 0.0)
	var event: NoiseEvent = NoiseEvent.create(Enums.NoiseCategory.DOOR, at, 50.0, 1.0, &"enemy_door", &"door_normal")
	_world().emit_noise(event)
	_world().flush()
	assert_eq(_router().played_log.size(), before + 1, "a porta do mundo tocou uma voz no router")
	if _router().played_log.size() != before + 1:
		return
	var entry: Dictionary = _router().played_log.back()
	assert_eq(entry["sound_id"], &"door_normal", "arquivo da porta normal")
	assert_almost_eq(float(entry["gain_db"]), NoiseGain.gain_for_db(float(entry["perceived_db"])), TOL,
		"volume = regra de ganho do nível percebido (NOI-04)")
	assert_true(float(entry["gain_db"]) > 0.0, "50 dB a 30 cm: acima da referência, ganho positivo (não satura em 0)")
	var subtitles: Subtitles = _root.get_node("Subtitles") as Subtitles
	assert_not_null(subtitles, "a cena tem a UI de legendas")
	if subtitles != null:
		assert_true(subtitles.get_visible_texts().has(subtitles.text_for(&"subtitle.door_normal")),
			"a porta do mundo aparece na legenda (ACC-04): %s" % [subtitles.get_visible_texts()])


func test_visao_de_debug_acustica_na_cena_desligada_por_padrao() -> void:
	var view: AcousticDebugView = _root.get_node_or_null("AcousticDebugView") as AcousticDebugView
	assert_not_null(view, "a cena tem a AcousticDebugView")
	if view == null:
		return
	assert_false(view.is_view_visible(), "nasce desligada")
	assert_eq(view.get_ring_count(), 0, "desligada não acumula anéis")
	if view.toggle_view():
		assert_eq(view.get_room_count(), 6, "ligada, mostra as 6 salas da sandbox")
		view.toggle_view()
	assert_false(view.is_view_visible(), "volta a desligar")


func test_camada_de_chuva_segue_o_piso_da_sala_do_ouvinte() -> void:
	_rain().tick(0.0)
	var floor_db: float = _world().get_graph().ambient_floor_at(_ear_position())
	assert_almost_eq(_rain().current_floor_db(), floor_db, TOL, "piso da sala do ouvinte")
	assert_eq(_rain().active_layer(), RainAmbience.layer_for_floor(floor_db), "camada pelo piso (DATA §2.3)")


func test_trovao_do_mundo_chega_a_ambiencia() -> void:
	var before: int = _rain().played_log.size()
	_world().thunder_started.emit(2.5)
	assert_true(_rain().played_log.size() > before, "o trovão tocou na ambiência")
	if _rain().played_log.size() <= before:
		return
	var entry: Dictionary = _rain().played_log[before]
	assert_eq(entry["sound_id"], RainAmbience.THUNDER_RUMBLE, "o ronco sempre toca")
	assert_almost_eq(float(entry["gain_db"]), RainAmbience.thunder_gain_for_floor(_rain().current_floor_db()), TOL,
		"ganho do trovão pelo piso da sala")

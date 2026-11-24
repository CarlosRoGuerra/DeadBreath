extends TestCase
## F4-006a: AdaptiveMusic com as três camadas reais (game/content/audio/music/). Sincronia (mesmo quadro, mesma duração),
## repetição direta, crossfade por tick() até o alvo (CROSSFADE_S = 2 s) e volume em dB seguindo a amplitude. O _process
## fica desligado: o teste chama tick() com o delta que quer.
## Autor: Audio Engineer (F4-006a).

const TOL: float = 0.001
const LOOP_SECONDS: float = 12.0

var _music: AdaptiveMusic = null


func before_each() -> void:
	_music = AdaptiveMusic.new()
	add_child_autofree(_music)
	_music.set_process(false)


func test_tres_camadas_tocam_juntas_desde_o_inicio() -> void:
	assert_true(_music.is_synced(), "três camadas tocando, com stream e a mesma duração")
	for layer: StringName in AdaptiveMusic.LAYERS:
		var player: AudioStreamPlayer = _music.layer_player(layer)
		assert_not_null(player, "camada %s existe" % String(layer))
		if player != null:
			assert_true(player.playing, "camada %s toca desde o início" % String(layer))


func test_camadas_tem_a_mesma_duracao_e_repeticao_direta() -> void:
	for layer: StringName in AdaptiveMusic.LAYERS:
		var player: AudioStreamPlayer = _music.layer_player(layer)
		if player == null or player.stream == null:
			fail("sem stream: " + String(layer))
			continue
		var stream: AudioStreamWAV = player.stream as AudioStreamWAV
		assert_eq(stream.loop_mode, AudioStreamWAV.LOOP_FORWARD, "camada %s: repetição direta" % String(layer))
		assert_almost_eq(stream.get_length(), LOOP_SECONDS, TOL, "camada %s: 12 s (4 compassos a 80 BPM)" % String(layer))


func test_sem_ameaca_so_o_volume_da_calma_sobe() -> void:
	_music.set_threat(0.0, false)
	_music.tick(10.0)
	assert_almost_eq(_music.layer_gain(&"calm"), 1.0, TOL, "calma em 1 sem ameaça")
	assert_almost_eq(_music.layer_gain(&"tension"), 0.0, TOL, "tensão em 0 sem ameaça")
	assert_almost_eq(_music.layer_gain(&"chase"), 0.0, TOL, "perseguição em 0 sem perseguição")
	assert_almost_eq(_music.layer_volume_db(&"calm"), 0.0, TOL, "calma em 0 dB")
	assert_eq(_music.layer_volume_db(&"chase"), AdaptiveMusic.MIN_DB, "perseguição no piso")


func test_crossfade_avanca_no_tempo_ate_o_alvo() -> void:
	_music.set_threat(1.0, false)
	_music.tick(1.0)
	assert_almost_eq(_music.layer_gain(&"tension"), 0.5, TOL, "após 1 s (de 2 s), tensão em 0,5")
	assert_almost_eq(_music.layer_gain(&"calm"), 0.5, TOL, "após 1 s, calma em 0,5")
	_music.tick(1.0)
	assert_almost_eq(_music.layer_gain(&"tension"), 1.0, TOL, "após 2 s, tensão em 1")
	assert_almost_eq(_music.layer_gain(&"calm"), 0.0, TOL, "após 2 s, calma em 0")


func test_meia_ameaca_e_depois_perseguicao() -> void:
	_music.set_threat(0.5, false)
	_music.tick(5.0)
	assert_almost_eq(_music.layer_gain(&"calm"), sqrt(0.5), TOL, "meia ameaça: calma √0,5")
	assert_almost_eq(_music.layer_gain(&"tension"), sqrt(0.5), TOL, "meia ameaça: tensão √0,5")
	_music.set_threat(0.5, true)
	_music.tick(5.0)
	assert_almost_eq(_music.layer_gain(&"chase"), 1.0, TOL, "perseguição: perseguição em 1")
	assert_almost_eq(_music.layer_gain(&"calm"), 0.0, TOL, "perseguição: calma em 0")
	assert_almost_eq(_music.layer_gain(&"tension"), 0.0, TOL, "perseguição: tensão em 0")
	assert_true(_music.in_chase(), "in_chase guardado")


func test_trocar_o_volume_nao_para_nem_dessincroniza() -> void:
	_music.set_threat(1.0, true)
	_music.tick(5.0)
	assert_true(_music.is_synced(), "as camadas continuam juntas depois da troca de volume")
	assert_almost_eq(_music.layer_volume_db(&"chase"), 0.0, TOL, "perseguição em 0 dB")

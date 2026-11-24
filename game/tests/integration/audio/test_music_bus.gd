extends TestCase
## F4-006a: barramento "music" (game/default_bus_layout.tres). Envia ao Master e não tem efeito: a música não é
## diegética, então não passa pela reverb das salas nem pela regra de ganho dos sons. As camadas do AdaptiveMusic tocam
## nele.
## Autor: Audio Engineer (F4-006a).

const MUSIC: String = "music"


func test_barramento_music_existe_e_envia_ao_master() -> void:
	var index: int = AudioServer.get_bus_index(MUSIC)
	assert_true(index > 0, "barramento music existe (índice %d)" % index)
	if index <= 0:
		return
	assert_eq(AudioServer.get_bus_send(index), "Master", "music envia ao Master")
	assert_almost_eq(AudioServer.get_bus_volume_db(index), 0.0, 0.0001, "volume do barramento music em 0 dB")


func test_barramento_music_nao_e_diegetico_sem_efeitos_nem_reverb() -> void:
	var index: int = AudioServer.get_bus_index(MUSIC)
	if index <= 0:
		fail("barramento music ausente")
		return
	assert_eq(AudioServer.get_bus_effect_count(index), 0, "music sem efeito (sem reverb das salas)")
	for room_bus: String in ["reverb_small", "reverb_large"]:
		var room_index: int = AudioServer.get_bus_index(room_bus)
		assert_true(room_index > 0, "barramento %s existe" % room_bus)
		if room_index > 0:
			assert_ne(AudioServer.get_bus_send(room_index), MUSIC, "%s não envia ao music" % room_bus)


func test_camadas_da_musica_tocam_no_barramento_music() -> void:
	var music: AdaptiveMusic = AdaptiveMusic.new()
	add_child_autofree(music)
	music.set_process(false)
	for layer: StringName in AdaptiveMusic.LAYERS:
		var player: AudioStreamPlayer = music.layer_player(layer)
		if player == null:
			fail("camada %s ausente" % String(layer))
			continue
		assert_eq(player.bus, MUSIC, "camada %s toca no barramento music" % String(layer))

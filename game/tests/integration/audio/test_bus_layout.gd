extends TestCase
## F3-003b: layout de barramentos (game/default_bus_layout.tres). Os nomes são os que o Level Designer usa em
## RoomVolume.reverb_bus: reverb_small e reverb_large. Cada um tem um efeito AudioEffectReverb e envia ao Master.
## Autor: Audio Engineer (F3-003b).

const SMALL: String = "reverb_small"
const LARGE: String = "reverb_large"


func test_master_bus_is_present() -> void:
	assert_true(AudioServer.get_bus_index("Master") == 0, "Master é o barramento 0")


## Decisão do Director (integração da F3-003b): limitador no Master, porque a regra de ganho passa de 0 dB.
func test_master_has_a_hard_limiter_below_full_scale() -> void:
	var limiter: AudioEffectHardLimiter = null
	for index: int in range(AudioServer.get_bus_effect_count(0)):
		var effect: AudioEffect = AudioServer.get_bus_effect(0, index)
		if effect is AudioEffectHardLimiter and AudioServer.is_bus_effect_enabled(0, index):
			limiter = effect as AudioEffectHardLimiter
	assert_not_null(limiter, "o Master tem um AudioEffectHardLimiter ligado")
	if limiter != null:
		assert_true(limiter.ceiling_db <= -0.5, "teto do limitador abaixo de 0 dBFS (%.1f)" % limiter.ceiling_db)


func test_reverb_buses_exist_with_reverb_effects() -> void:
	for bus_name: String in [SMALL, LARGE]:
		var index: int = AudioServer.get_bus_index(bus_name)
		assert_true(index > 0, "barramento %s existe (índice %d)" % [bus_name, index])
		if index <= 0:
			continue
		assert_true(AudioServer.get_bus_effect_count(index) >= 1, "%s tem efeito" % bus_name)
		var effect: AudioEffect = AudioServer.get_bus_effect(index, 0)
		assert_true(effect is AudioEffectReverb, "%s: efeito é AudioEffectReverb" % bus_name)


func test_reverb_buses_send_to_master() -> void:
	for bus_name: String in [SMALL, LARGE]:
		var index: int = AudioServer.get_bus_index(bus_name)
		if index <= 0:
			fail("barramento %s ausente" % bus_name)
			continue
		assert_eq(AudioServer.get_bus_send(index), "Master", "%s envia ao Master" % bus_name)


func test_large_room_reverb_is_longer_than_small() -> void:
	var small: AudioEffectReverb = AudioServer.get_bus_effect(AudioServer.get_bus_index(SMALL), 0) as AudioEffectReverb
	var large: AudioEffectReverb = AudioServer.get_bus_effect(AudioServer.get_bus_index(LARGE), 0) as AudioEffectReverb
	if small == null or large == null:
		fail("efeitos de reverb ausentes")
		return
	assert_true(large.room_size > small.room_size, "sala grande tem room_size maior (%.2f > %.2f)" % [large.room_size, small.room_size])
	assert_true(large.wet > small.wet, "sala grande tem mais reverberação (wet)")

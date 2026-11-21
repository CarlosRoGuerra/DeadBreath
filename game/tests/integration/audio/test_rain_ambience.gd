extends TestCase
## F3-003b: ambiência de chuva e trovão (COMPONENT_CONTRACTS §14; DATA_STRUCTURES §2.3).
## A camada segue o piso da sala do ouvinte; a troca de camada é um crossfade contínuo de potência constante; a saída de
## cada camada é o piso (mesma escala dos eventos); o trovão toca no sinal thunder_started do AcousticWorld, sem posição.
## Autor: Audio Engineer (F3-003b).

const Rooms := preload("res://tests/integration/audio/fixtures/acoustic_rooms.gd")
const TOL: float = 0.01
const SETTLE_STEPS: int = 300
const STEP_S: float = 1.0 / 60.0

var _level: Node3D = null
var _world: AcousticWorld = null
var _ambience: RainAmbience = null
var _listener: Node3D = null


func before_each() -> void:
	_level = Node3D.new()
	add_child_autofree(_level)
	var rooms: Dictionary = Rooms.build_two_rooms(_level)
	_world = rooms["world"]
	_listener = Node3D.new()
	_level.add_child(_listener)
	_listener.global_position = Vector3(0.0, 1.0, 0.0)
	_world.set_player_ear(_listener)
	_ambience = RainAmbience.new()
	_level.add_child(_ambience)
	_ambience.bind_world(_world)
	_ambience.set_listener(_listener)
	_ambience.set_random_seed(5)


func _run(seconds: float) -> void:
	var steps: int = int(round(seconds / STEP_S))
	for i in range(steps):
		_ambience.tick(STEP_S)


func test_layer_follows_the_listener_room_floor() -> void:
	_run(0.1)
	assert_eq(_ambience.active_layer(), RainAmbience.LAYER_INTERIOR, "sala A (22 dB): interna")
	_listener.global_position = Vector3(10.0, 1.0, 0.0)
	_run(0.1)
	assert_eq(_ambience.active_layer(), RainAmbience.LAYER_EXTERIOR, "sala B (38 dB): exterior")


func test_outside_every_room_is_the_exterior_layer() -> void:
	_listener.global_position = Vector3(5.0, 1.0, 0.0)
	_run(0.1)
	assert_eq(_ambience.active_layer(), RainAmbience.LAYER_EXTERIOR, "fora das salas: piso exterior de 38 dB")


func test_output_level_equals_the_room_floor_minus_69() -> void:
	_run(SETTLE_STEPS * STEP_S)
	var interior_out: float = _ambience.layer_volume_db(RainAmbience.LAYER_INTERIOR) + _ambience.layer_clip_db(RainAmbience.LAYER_INTERIOR)
	assert_almost_eq(interior_out, 22.0 - 69.0, TOL, "sala interna: clip + ganho = 22 − 69 dBFS")
	_listener.global_position = Vector3(10.0, 1.0, 0.0)
	_run(SETTLE_STEPS * STEP_S)
	var exterior_out: float = _ambience.layer_volume_db(RainAmbience.LAYER_EXTERIOR) + _ambience.layer_clip_db(RainAmbience.LAYER_EXTERIOR)
	assert_almost_eq(exterior_out, 38.0 - 69.0, TOL, "sala exterior: clip + ganho = 38 − 69 dBFS")


func test_crossfade_between_layers_is_continuous_and_complete() -> void:
	_run(SETTLE_STEPS * STEP_S)
	assert_almost_eq(_ambience.layer_fade(RainAmbience.LAYER_INTERIOR), 1.0, 0.0001, "interna ativa no início")
	_listener.global_position = Vector3(10.0, 1.0, 0.0)
	_run(0.1)
	var interior: float = _ambience.layer_fade(RainAmbience.LAYER_INTERIOR)
	var exterior: float = _ambience.layer_fade(RainAmbience.LAYER_EXTERIOR)
	assert_true(interior > 0.9 and interior < 1.0, "0,1 s depois a interna ainda está saindo (%.3f)" % interior)
	assert_true(exterior > 0.0 and exterior < 0.1, "0,1 s depois a exterior está entrando (%.3f)" % exterior)
	_run(1.0)
	assert_true(_ambience.layer_fade(RainAmbience.LAYER_INTERIOR) > 0.4 and _ambience.layer_fade(RainAmbience.LAYER_INTERIOR) < 0.6,
		"no meio do crossfade as duas camadas estão na metade")
	_run(2.0)
	assert_almost_eq(_ambience.layer_fade(RainAmbience.LAYER_INTERIOR), 0.0, 0.0001, "interna saiu por completo")
	assert_almost_eq(_ambience.layer_fade(RainAmbience.LAYER_EXTERIOR), 1.0, 0.0001, "exterior entrou por completo")
	assert_eq(_ambience.layer_volume_db(RainAmbience.LAYER_INTERIOR), RainAmbience.MIN_LAYER_DB,
		"camada que saiu fica em silêncio")


func test_crossfade_is_power_constant() -> void:
	# Potência das duas camadas (amplitudes sin e cos da mesma fase) soma 1 em qualquer ponto da transição.
	_run(SETTLE_STEPS * STEP_S)
	_listener.global_position = Vector3(10.0, 1.0, 0.0)
	for i in range(60):
		_run(STEP_S * 2.0)
		var a: float = _ambience.layer_fade(RainAmbience.LAYER_INTERIOR)
		var b: float = _ambience.layer_fade(RainAmbience.LAYER_EXTERIOR)
		var power: float = pow(sin(0.5 * PI * a), 2.0) + pow(sin(0.5 * PI * b), 2.0)
		if a > 0.0 and b > 0.0:
			assert_almost_eq(power, 1.0, 0.05, "potência total constante durante o crossfade")


func test_thunder_plays_on_the_world_signal() -> void:
	_world.thunder_enabled = true
	_world.thunder_interval_min_s = 1.0
	_world.thunder_interval_max_s = 1.0
	var before: int = _ambience.played_log.size()
	for i in range(12):
		_world.advance(0.5)
	assert_true(_ambience.played_log.size() > before, "trovão tocou quando o AcousticWorld emitiu thunder_started")
	var rumbles: int = 0
	for entry: Dictionary in _ambience.played_log:
		if entry["sound_id"] == RainAmbience.THUNDER_RUMBLE:
			rumbles += 1
	assert_true(rumbles >= 1, "ao menos um thunder_rumble")


func test_thunder_voices_are_not_positional() -> void:
	_world.thunder_enabled = true
	_world.thunder_interval_min_s = 1.0
	_world.thunder_interval_max_s = 1.0
	for i in range(6):
		_world.advance(0.5)
	var checked: int = 0
	for child: Node in _ambience.get_children():
		if child is AudioStreamPlayer and not (child is AudioStreamPlayer3D):
			checked += 1
	assert_true(checked >= 3, "três leitos de chuva (não 3D)")
	for entry: Dictionary in _ambience.played_log:
		assert_true(float(entry["gain_db"]) <= NoiseGain.MAX_GAIN_DB and float(entry["gain_db"]) >= RainAmbience.MIN_LAYER_DB,
			"ganho do trovão entre o piso e o teto de NoiseGain")


func test_thunder_stays_silent_when_disabled() -> void:
	_world.thunder_enabled = false
	for i in range(40):
		_world.advance(1.0)
	assert_eq(_ambience.played_log.size(), 0, "sem trovão habilitado, nada toca")

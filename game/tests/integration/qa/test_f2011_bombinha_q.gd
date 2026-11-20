extends TestCase
## F2-011 (QA Engineer): exploits da bombinha (tecla Q) no jogador real (player.tscn). Spam de Q na janela de
## cooldown, Q real pela entrada de janela (push_input), cooldown de 10 s medido em quadros de física, 3 doses por
## unidade e motivos de recusa (cooldown, no_doses). Escrito do zero pelo QA; usa só o fixture de mundo do jogador.

const PlayerWorld := preload("res://tests/integration/player/fixtures/player_world.gd")
const SETTLE_FRAMES: int = 6
const SPAM_PRESSES: int = 30
const REAL_Q_PRESSES: int = 10
## medication_inhaler.tres: cooldown_s = 10 (600 quadros a 60 ticks/s). 9 s e 11 s em torno da fronteira.
const BEFORE_COOLDOWN_FRAMES: int = 540
const AFTER_COOLDOWN_FRAMES: int = 660
const DOSES_START: int = 3

var _previous: Dictionary = {}
var _refusals: Array[StringName] = []


func before_all() -> void:
	Settings.autosave = false


func after_all() -> void:
	Settings.autosave = true


func before_each() -> void:
	_previous = PlayerWorld.override_settings({&"motion_reduction": 0.0, &"tremor_reduction": 0.0, &"effects_intensity": 1.0})
	_refusals = []


func after_each() -> void:
	PlayerWorld.restore_settings(_previous)


func test_spam_de_q_dentro_do_cooldown_gasta_uma_dose() -> void:
	var player: PlayerRoot = await _player_with_inhaler()
	assert_eq(player.get_inventory().get_doses(&"inhaler"), DOSES_START, "1 unidade inicial = 3 doses")
	var accepted: int = 0
	for _i: int in SPAM_PRESSES:
		if player.try_use_inhaler():
			accepted += 1
	assert_eq(accepted, 1, "30 chamadas seguidas no mesmo quadro: só a primeira é aceita")
	assert_eq(player.get_inventory().get_doses(&"inhaler"), DOSES_START - 1, "exatamente uma dose gasta")
	assert_eq(_count(&"cooldown"), SPAM_PRESSES - 1, "as 29 recusas restantes são por cooldown")
	assert_eq(_count(&"no_doses"), 0, "nenhuma recusa por falta de dose enquanto há doses")


func test_q_real_pela_entrada_de_janela_gasta_uma_dose() -> void:
	var player: PlayerRoot = await _player_with_inhaler()
	for _i: int in REAL_Q_PRESSES:
		var event: InputEventAction = InputEventAction.new()
		event.action = &"use_item"
		event.pressed = true
		player.get_viewport().push_input(event)
	assert_eq(player.get_inventory().get_doses(&"inhaler"), DOSES_START - 1, "10 Q reais em sequência: uma dose")
	assert_eq(_count(&"cooldown"), REAL_Q_PRESSES - 1, "os demais Q viram recusa por cooldown")


func test_cooldown_de_10_s_e_tres_doses_por_unidade() -> void:
	var player: PlayerRoot = await _player_with_inhaler()
	assert_true(player.try_use_inhaler(), "dose 1 aceita")
	await wait_physics_frames(BEFORE_COOLDOWN_FRAMES)
	assert_false(player.try_use_inhaler(), "9 s depois da dose 1: ainda em cooldown")
	await wait_physics_frames(AFTER_COOLDOWN_FRAMES - BEFORE_COOLDOWN_FRAMES)
	assert_true(player.try_use_inhaler(), "11 s depois da dose 1: dose 2 aceita")
	await wait_physics_frames(AFTER_COOLDOWN_FRAMES)
	assert_true(player.try_use_inhaler(), "dose 3 aceita (última da unidade)")
	await wait_physics_frames(AFTER_COOLDOWN_FRAMES)
	assert_false(player.try_use_inhaler(), "sem doses: recusa")
	assert_eq(_count(&"no_doses"), 1, "a recusa final tem motivo no_doses")
	assert_eq(_count(&"cooldown"), 1, "a única recusa por cooldown foi a dos 9 s")
	assert_eq(player.get_inventory().get_doses(&"inhaler"), 0, "zero doses, nunca negativo")


func test_sem_unidades_nao_ha_dose_e_nada_negativo() -> void:
	var player: PlayerRoot = await _player_with_inhaler()
	player.get_inventory().consume_dose(&"inhaler")
	player.get_inventory().consume_dose(&"inhaler")
	player.get_inventory().consume_dose(&"inhaler")
	assert_false(player.try_use_inhaler(), "inventário zerado: Q não faz nada")
	assert_eq(_count(&"no_doses"), 1, "motivo no_doses")
	assert_eq(player.get_inventory().get_doses(&"inhaler"), 0, "continua zero")


func _on_refused(reason: StringName) -> void:
	_refusals.append(reason)


func _count(reason: StringName) -> int:
	var count: int = 0
	for item: StringName in _refusals:
		if item == reason:
			count += 1
	return count


func _player_with_inhaler() -> PlayerRoot:
	var root: Node3D = add_isolated_world()
	PlayerWorld.add_box(root, Vector3(0.0, -0.5, 0.0), Vector3(20.0, 1.0, 20.0), &"wood")
	var player: PlayerRoot = PlayerWorld.spawn_player(root, Vector3.ZERO)
	player.item_use_failed.connect(_on_refused)
	await wait_physics_frames(SETTLE_FRAMES)
	return player

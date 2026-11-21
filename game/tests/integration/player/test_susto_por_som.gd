extends TestCase
## F3-004 (BUG-014, COMPONENT_CONTRACTS §6.5): ponte de susto. Um som de outra fonte com 55 dB percebidos ou mais, perto
## do ouvido do jogador, sobe o estresse por add_startle(clamp((dB - 55)/2 + 10, 10, 25)) e, com estresse de 50 ou mais,
## gera o gasp. Som do próprio jogador não assusta; som fraco não assusta. Autor: Gameplay Engineer.

const PlayerWorld := preload("res://tests/integration/player/fixtures/player_world.gd")
const SETTLE_FRAMES: int = 2
const EAR_POSITION: Vector3 = Vector3(0.0, 1.65, -1.0)

var _gasps: int = 0


func before_all() -> void:
	Settings.autosave = false


func after_all() -> void:
	Settings.autosave = true


func before_each() -> void:
	_gasps = 0


func _on_gasp() -> void:
	_gasps += 1


func _setup(root: Node3D) -> Dictionary:
	var world: AcousticWorld = AcousticWorld.new()
	root.add_child(world)
	var player: PlayerRoot = PlayerWorld.spawn_player(root, Vector3.ZERO)
	return {"world": world, "player": player}


func _send(world: AcousticWorld, category: Enums.NoiseCategory, level_db: float, source: StringName) -> void:
	world.emit_noise(NoiseEvent.create(category, EAR_POSITION, level_db, 0.0, source, &"door_slam"))
	world.flush()


func test_som_forte_de_outra_fonte_sobe_o_estresse_e_faz_gasp() -> void:
	var root: Node3D = add_child_autofree(Node3D.new()) as Node3D
	var parts: Dictionary = _setup(root)
	var world: AcousticWorld = parts["world"] as AcousticWorld
	var player: PlayerRoot = parts["player"] as PlayerRoot
	await wait_physics_frames(SETTLE_FRAMES)
	player.get_physiology().add_injury(70.0)
	await wait_physics_frames(1)
	player.get_physiology().startle_gasp.connect(_on_gasp)
	var before: float = player.get_physiology().get_snapshot().stress
	assert_true(before >= 50.0, "estresse de partida alto o bastante para o gasp (%.1f)" % before)
	_send(world, Enums.NoiseCategory.DOOR, 75.0, &"enemy_test")
	var after: float = player.get_physiology().get_snapshot().stress
	assert_true(after > before, "o som de 75 dB sobe o estresse (%.1f -> %.1f)" % [before, after])
	assert_true(_gasps >= 1, "o susto dispara o gasp")


func test_som_do_proprio_jogador_nao_assusta() -> void:
	var root: Node3D = add_child_autofree(Node3D.new()) as Node3D
	var parts: Dictionary = _setup(root)
	var world: AcousticWorld = parts["world"] as AcousticWorld
	var player: PlayerRoot = parts["player"] as PlayerRoot
	await wait_physics_frames(SETTLE_FRAMES)
	var before: float = player.get_physiology().get_snapshot().stress
	_send(world, Enums.NoiseCategory.DOOR, 75.0, &"player")
	assert_almost_eq(player.get_physiology().get_snapshot().stress, before, 0.0001, "o próprio som não assusta")


func test_som_fraco_nao_assusta() -> void:
	var root: Node3D = add_child_autofree(Node3D.new()) as Node3D
	var parts: Dictionary = _setup(root)
	var world: AcousticWorld = parts["world"] as AcousticWorld
	var player: PlayerRoot = parts["player"] as PlayerRoot
	await wait_physics_frames(SETTLE_FRAMES)
	var before: float = player.get_physiology().get_snapshot().stress
	_send(world, Enums.NoiseCategory.DOOR, 40.0, &"enemy_test")
	assert_almost_eq(player.get_physiology().get_snapshot().stress, before, 0.0001, "40 dB percebidos não assustam")

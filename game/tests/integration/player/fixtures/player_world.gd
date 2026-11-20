extends RefCounted
## Fixture dos testes do jogador (F1-006): monta geometria por código e instancia o jogador a partir de
## components/player/player.tscn. Pasta "fixtures" não é descoberta pelo runner (nunca executada direto).
## Observação: a física headless roda a ~60 ticks/s reais (Engine.time_scale só altera o delta), então
## os testes mantêm sequências curtas e usam faixas paralelas (jogadores não colidem entre si).
## Autor: Gameplay Engineer.

const PLAYER_SCENE: PackedScene = preload("res://components/player/player.tscn")

## Corredor do MOT-04 (todas as medidas em metros; corredor de 2,4 m entre paredes em x = ±1,3).
const CORRIDOR_HALF_WIDTH: float = 1.2
## Face inferior da laje: vão livre de 0,6 m entre o piso e a laje.
const SLAB_UNDERSIDE: float = 0.6
const SLAB_Z_NEAR: float = -1.5
const SLAB_Z_FAR: float = -1.9
const STAIR_START_Z: float = -3.5
const STAIR_STEPS: int = 8
const STAIR_RISE: float = 0.18
const STAIR_TREAD: float = 0.3
## Topo do patamar = 8 × 0,18 = 1,44 m.
const LANDING_TOP: float = 1.44
const LANDING_START_Z: float = -5.9
const WALL_FACE_Z: float = -7.9


## Caixa estática na camada world_static (1). surface é o metadado lido pelos passos ("" = sem metadado).
static func add_box(parent: Node3D, center: Vector3, size: Vector3, surface: StringName = &"") -> StaticBody3D:
	var body: StaticBody3D = StaticBody3D.new()
	body.position = center
	var shape_node: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = size
	shape_node.shape = box
	body.add_child(shape_node)
	if not surface.is_empty():
		body.set_meta(&"surface", surface)
	parent.add_child(body)
	return body


## Piso de uma faixa de teste: 3 m de largura, topo em y = 0, de z = +4 a z = -10.
static func add_lane_floor(parent: Node3D, x: float, surface: StringName = &"") -> StaticBody3D:
	return add_box(parent, Vector3(x, -0.5, -3.0), Vector3(3.0, 1.0, 14.0), surface)


## Degrau de altura step_height (topo nessa altura), face em z = -1,0 e 5 m de patamar, na faixa x.
static func add_lane_step(parent: Node3D, x: float, step_height: float) -> StaticBody3D:
	return add_box(parent, Vector3(x, step_height - 0.5, -3.5), Vector3(3.0, 1.0, 5.0))


## Corredor completo do MOT-04: piso, paredes laterais, laje baixa (vão 0,6 m), escada de 8 degraus de
## 0,18 m, patamar a 1,44 m e uma parede que não pode ser atravessada.
static func build_route(parent: Node3D) -> void:
	add_box(parent, Vector3(0.0, -0.5, -4.0), Vector3(CORRIDOR_HALF_WIDTH * 2.0, 1.0, 14.0), &"wood")
	add_box(parent, Vector3(CORRIDOR_HALF_WIDTH + 0.1, 1.25, -4.0), Vector3(0.2, 2.5, 13.0))
	add_box(parent, Vector3(-CORRIDOR_HALF_WIDTH - 0.1, 1.25, -4.0), Vector3(0.2, 2.5, 13.0))
	var slab_depth: float = SLAB_Z_NEAR - SLAB_Z_FAR
	add_box(parent, Vector3(0.0, SLAB_UNDERSIDE + 0.025, (SLAB_Z_NEAR + SLAB_Z_FAR) * 0.5),
		Vector3(CORRIDOR_HALF_WIDTH * 2.0, 0.05, slab_depth), &"wood")
	for i: int in range(1, STAIR_STEPS + 1):
		var top: float = STAIR_RISE * float(i)
		var center_z: float = STAIR_START_Z - STAIR_TREAD * float(i) + STAIR_TREAD * 0.5
		add_box(parent, Vector3(0.0, (top - 1.0) * 0.5, center_z),
			Vector3(CORRIDOR_HALF_WIDTH * 2.0, top + 1.0, STAIR_TREAD), &"wood")
	var landing_len: float = LANDING_START_Z - WALL_FACE_Z
	add_box(parent, Vector3(0.0, (LANDING_TOP - 1.0) * 0.5, (LANDING_START_Z + WALL_FACE_Z) * 0.5),
		Vector3(CORRIDOR_HALF_WIDTH * 2.0, LANDING_TOP + 1.0, landing_len), &"wood")
	add_box(parent, Vector3(0.0, 1.25, WALL_FACE_Z - 0.1), Vector3(CORRIDOR_HALF_WIDTH * 2.0, 2.5, 0.2))


## Instancia o jogador na posição indicada (coordenadas do pai). Sem orientação: olha para -Z.
static func spawn_player(parent: Node3D, position: Vector3) -> PlayerRoot:
	var player: PlayerRoot = PLAYER_SCENE.instantiate() as PlayerRoot
	player.position = position
	parent.add_child(player)
	return player


## Entrada de um tick com um único comando de borda (o bot injeta e depois zera).
static func edge_input(crouch: bool, crawl: bool) -> MotorInput:
	var input: MotorInput = MotorInput.new()
	input.crouch_pressed = crouch
	input.crawl_pressed = crawl
	return input


## Entrada de movimento contínuo (move em x/y, sem bordas).
static func move_input(move: Vector2, sprint: bool = false, slow_walk: bool = false) -> MotorInput:
	var input: MotorInput = MotorInput.new()
	input.move = move
	input.sprint = sprint
	input.slow_walk = slow_walk
	return input


## Aplica overrides em Settings e devolve os valores anteriores (para restaurar). Não grava em disco
## porque os testes desligam o autosave antes de chamar.
static func override_settings(overrides: Dictionary) -> Dictionary:
	var previous: Dictionary = {}
	for key: StringName in overrides.keys():
		previous[key] = Settings.get_value(key)
		Settings.set_value(key, overrides[key])
	return previous


static func restore_settings(previous: Dictionary) -> void:
	for key: StringName in previous.keys():
		Settings.set_value(key, previous[key])

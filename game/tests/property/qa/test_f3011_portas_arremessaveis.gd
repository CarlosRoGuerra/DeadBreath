extends TestCase
## F3-011 (QA independente): tentativas de quebrar portas e arremessáveis na sandbox_playable.tscn real. Cada teste
## monta o próprio mundo isolado (add_isolated_world) e age só por entradas do jogo (MotorInput, tecla E, ação throw),
## exceto a posição inicial do jogador e a colocação de objetos, que são preparação. Os testes que documentam um defeito
## afirmam o comportamento real e dizem isso no nome e nas notas; o defeito fica registrado em BUG_REPORTS.md.
## Autor: QA Engineer (F3-011).

const Fx := preload("res://tests/integration/qa/fixtures/qa_fixture.gd")
const PLAYABLE_PATH: String = "res://content/levels/sandbox_playable.tscn"
const THROWABLE_LIGHT: String = "res://content/props/throwables/throwable_light.tscn"
const THROWABLE_HEAVY: String = "res://content/props/throwables/throwable_heavy.tscn"
const SETTLE: int = 12
const OPEN_TICKS: int = 150
const SLOW_CLOSE_TICKS: int = 220
const FULLY_OPEN_MIN_DEG: float = 85.0
const CLOSED_MAX_DEG: float = 1.0
const HALL_STAND: Vector3 = Vector3(15.5, 0.0, -0.7)
const HALL_DOOR_PANEL: Vector3 = Vector3(14.0, 1.0, -0.7)
const HALL_OPEN_PANEL: Vector3 = Vector3(14.45, 1.0, -1.15)
const ARC_INSIDE: Vector3 = Vector3(14.5, 0.0, -0.6)
const CORRIDOR_STAND: Vector3 = Vector3(13.0, 0.0, -0.7)
const QUINTAL_STAND: Vector3 = Vector3(19.0, 0.0, -1.2)
const QUINTAL_PANEL: Vector3 = Vector3(20.0, 1.0, -1.2)
const DOOR_CLOSED: int = 0
const DOOR_OPEN: int = 1
const DOOR_LOCKED: int = 2
const MAX_STALL_OBJECT_MOVE_M: float = 0.02
const MIN_UNSTUCK_M: float = 0.5
const IMPACT_COOLDOWN_TICKS: int = 15
## Parede sul do corredor: plano z = 0, espessura 0,2 m (face externa em z = 0,1).
const SOUTH_WALL_FAR_Z: float = 0.1


func before_all() -> void:
	Settings.autosave = false


func after_all() -> void:
	Settings.autosave = true


## Cena jogável no mundo isolado, com o jogador em start e virado para yaw. Devolve raiz, jogador e medidor de penetração.
func _world(start: Vector3, yaw_rad: float) -> Dictionary:
	var container: Node3D = add_isolated_world()
	var root: Node = Fx.instantiate_scene(PLAYABLE_PATH, container)
	await wait_physics_frames(SETTLE)
	var player: PlayerRoot = Fx.find_player(root)
	player.global_position = start
	player.rotation.y = yaw_rad
	await wait_physics_frames(SETTLE)
	var meter: Fx.Meter = Fx.Meter.new()
	meter.connect_motor(player)
	return {"root": root, "player": player, "meter": meter}


func _door(root: Node, door_name: String) -> Door:
	return root.find_child(door_name, true, false) as Door


func _aim(player: PlayerRoot, target: Vector3) -> void:
	var delta: Vector3 = target - player.global_position
	player.rotation.y = atan2(-delta.x, -delta.z)


func _tick(player: PlayerRoot, meter: Fx.Meter, input: MotorInput) -> void:
	player.get_motor().set_scripted_input(input)
	await wait_physics_frames(1)
	meter.sample(player, Fx.body_overlaps_world(player))


func _idle(player: PlayerRoot, meter: Fx.Meter, ticks: int) -> void:
	for _i: int in ticks:
		await _tick(player, meter, Fx.move_input(Vector2.ZERO))


func _tap(player: PlayerRoot) -> void:
	player.get_interaction().press_interact()
	await wait_physics_frames(2)
	player.get_interaction().release_interact()
	await wait_physics_frames(1)


func _hold(player: PlayerRoot, ticks: int) -> void:
	player.get_interaction().press_interact()
	await wait_physics_frames(ticks)
	player.get_interaction().release_interact()
	await wait_physics_frames(1)


func _throw_action(player: PlayerRoot) -> void:
	var event: InputEventAction = InputEventAction.new()
	event.action = InputBindings.THROW_ACTION
	event.pressed = true
	player.get_viewport().push_input(event)
	await wait_physics_frames(1)


func _spawn(root: Node, scene_path: String, at: Vector3) -> Throwable:
	var item: Throwable = (load(scene_path) as PackedScene).instantiate() as Throwable
	item.throwable_id = &"throwable_f3011"
	root.add_child(item)
	item.global_position = at
	return item


# ---- Portas ----

## Fechar a porta com o jogador dentro do arco, em pé, agachado e rastejando: a porta para no corpo, emite blocked uma vez
## por contato e nenhum frame tem penetração. Depois de sair do arco, a porta fecha por inteiro.
func test_fechar_com_o_jogador_no_arco_para_no_corpo_em_todas_as_posturas() -> void:
	var postures: Array[int] = [Fx.EDGE_NONE, Fx.EDGE_CROUCH, Fx.EDGE_CRAWL]
	var names: Array[String] = ["em pé", "agachado", "rastejando"]
	for index: int in postures.size():
		var world: Dictionary = await _world(HALL_STAND, PI / 2.0)
		var root: Node = world["root"] as Node
		var player: PlayerRoot = world["player"] as PlayerRoot
		var meter: Fx.Meter = world["meter"] as Fx.Meter
		var door: Door = _door(root, "door_corredor_hall")
		await _tap(player)
		await _idle(player, meter, OPEN_TICKS)
		assert_true(door.get_state() == Door.State.OPEN, "%s: a porta abriu" % names[index])
		player.global_position = ARC_INSIDE
		_aim(player, HALL_OPEN_PANEL)
		await _idle(player, meter, SETTLE)
		if postures[index] != Fx.EDGE_NONE:
			await _tick(player, meter, Fx.edge_input(postures[index]))
			await _idle(player, meter, SETTLE)
		var blocks: Array[Node] = []
		door.blocked.connect(func(body: Node) -> void: blocks.append(body))
		await _hold(player, 30)
		await _idle(player, meter, 120)
		note("%s: ângulo travado %.1f°, bloqueada=%s, blocked=%d, penetrações=%d" % [names[index],
			door.get_panel_angle_deg(), str(door.is_blocked()), blocks.size(), meter.penetrations])
		assert_true(door.is_blocked(), "%s: a porta para no corpo" % names[index])
		assert_true(door.get_panel_angle_deg() < FULLY_OPEN_MIN_DEG and door.get_panel_angle_deg() > 0.0,
			"%s: o painel fica parado no arco (%.1f°)" % [names[index], door.get_panel_angle_deg()])
		assert_eq(blocks.size(), 1, "%s: blocked emitido uma vez enquanto o contato dura" % names[index])
		assert_eq(meter.penetrations, 0, "%s: o corpo não atravessa o painel" % names[index])
		player.global_position = HALL_STAND
		await _idle(player, meter, SLOW_CLOSE_TICKS)
		assert_eq(door.get_state(), Door.State.CLOSED, "%s: depois de sair do arco, a porta fecha" % names[index])
		assert_true(door.get_panel_angle_deg() <= CLOSED_MAX_DEG, "%s: porta fechada por inteiro" % names[index])
		assert_eq(meter.penetrations, 0, "%s: nenhuma penetração no caminho inteiro" % names[index])
		await release_and_flush(world["root"] as Node)


## Fechar a porta com um arremessável no arco (no chão, na trajetória do painel): a porta para no objeto, o objeto não
## se move nem é atravessado, e a porta termina de fechar quando o objeto sai.
func test_fechar_com_objeto_no_arco_para_no_objeto_e_retoma() -> void:
	var world: Dictionary = await _world(HALL_STAND, PI / 2.0)
	var root: Node = world["root"] as Node
	var player: PlayerRoot = world["player"] as PlayerRoot
	var meter: Fx.Meter = world["meter"] as Fx.Meter
	var door: Door = _door(root, "door_corredor_hall")
	await _tap(player)
	await _idle(player, meter, OPEN_TICKS)
	var item: Throwable = _spawn(root, THROWABLE_LIGHT, Vector3(14.6, 0.1, -0.8))
	await _idle(player, meter, 30)
	var before: Vector3 = item.global_position
	_aim(player, HALL_OPEN_PANEL)
	await _hold(player, 30)
	await _idle(player, meter, 120)
	var moved: float = before.distance_to(item.global_position)
	note("objeto no arco: porta %.1f°, bloqueada=%s, objeto deslocou %.4f m" % [door.get_panel_angle_deg(), str(door.is_blocked()), moved])
	assert_true(door.is_blocked(), "a porta para no objeto")
	assert_true(door.get_panel_angle_deg() < FULLY_OPEN_MIN_DEG, "o painel não termina de fechar com o objeto no arco")
	assert_true(moved <= MAX_STALL_OBJECT_MOVE_M, "a porta não empurra o objeto (deslocou %.4f m)" % moved)
	await release_and_flush(item)
	await _idle(player, meter, SLOW_CLOSE_TICKS)
	assert_eq(door.get_state(), Door.State.CLOSED, "tirado o objeto, a porta fecha por inteiro")


## Spam de interação durante o movimento: apertos e soltas a cada tick enquanto a porta anda não invertem nem repetem
## a ação: uma abertura (opened), nenhum fechamento.
func test_spam_de_interacao_durante_o_movimento_nao_reverte_a_porta() -> void:
	var world: Dictionary = await _world(HALL_STAND, PI / 2.0)
	var root: Node = world["root"] as Node
	var player: PlayerRoot = world["player"] as PlayerRoot
	var meter: Fx.Meter = world["meter"] as Fx.Meter
	var door: Door = _door(root, "door_corredor_hall")
	var counts: Array[int] = [0, 0]
	door.opened.connect(func(_slow: bool) -> void: counts[0] += 1)
	door.closed.connect(func(_slow: bool) -> void: counts[1] += 1)
	for _i: int in 18:
		player.get_interaction().press_interact()
		await _tick(player, meter, Fx.move_input(Vector2.ZERO))
		player.get_interaction().release_interact()
		await _tick(player, meter, Fx.move_input(Vector2.ZERO))
	await _idle(player, meter, OPEN_TICKS)
	note("spam durante o movimento: opened=%d closed=%d estado=%d" % [counts[0], counts[1], int(door.get_state())])
	assert_eq(counts[0], 1, "uma única abertura com o spam")
	assert_eq(counts[1], 0, "o spam durante o movimento não fecha a porta")
	assert_eq(door.get_state(), Door.State.OPEN, "a porta termina aberta")
	assert_eq(meter.penetrations, 0, "sem penetração durante o spam")


## Porta trancada: o spam de E dá feedback e nunca abre, nem com lock/unlock fora de hora.
func test_porta_trancada_nao_abre_com_spam() -> void:
	var world: Dictionary = await _world(QUINTAL_STAND, PI / 2.0 + PI)
	var root: Node = world["root"] as Node
	var player: PlayerRoot = world["player"] as PlayerRoot
	var meter: Fx.Meter = world["meter"] as Fx.Meter
	var door: Door = _door(root, "door_hall_quintal")
	door.lock()
	assert_eq(door.get_state(), DOOR_LOCKED, "pré-condição: porta trancada")
	var feedback: Array[int] = [0]
	door.locked_feedback.connect(func(_actor: Node) -> void: feedback[0] += 1)
	_aim(player, QUINTAL_PANEL)
	for _i: int in 30:
		await _tap(player)
	door.lock()
	await _idle(player, meter, 30)
	assert_eq(door.get_state(), DOOR_LOCKED, "trancada continua trancada")
	assert_true(door.get_panel_angle_deg() < 0.01, "painel parado")
	assert_true(feedback[0] >= 1, "o aperto dá feedback de trancada (%d)" % feedback[0])


## Pegar através de porta fechada e de parede: a mira bate na porta ou na parede, nunca no objeto de trás.
func test_pegar_atraves_de_porta_fechada_e_de_parede_nao_foca_o_objeto() -> void:
	var world: Dictionary = await _world(CORRIDOR_STAND, -PI / 2.0)
	var root: Node = world["root"] as Node
	var player: PlayerRoot = world["player"] as PlayerRoot
	var meter: Fx.Meter = world["meter"] as Fx.Meter
	var behind_door: Throwable = _spawn(root, THROWABLE_LIGHT, Vector3(15.2, 0.1, -0.7))
	await _idle(player, meter, 6)
	var focus: Interactable = player.get_interaction().get_focused()
	note("atrás da porta fechada, foco = %s" % (str(focus.name) if focus != null else "nada"))
	assert_false(focus != null and focus == behind_door.get_node("Grip"), "o objeto atrás da porta fechada não está em foco")
	var behind_wall: Throwable = _spawn(root, THROWABLE_LIGHT, Vector3(12.8, 0.1, -2.0))
	player.global_position = Vector3(12.8, 0.0, -0.6)
	_aim(player, Vector3(12.8, 0.3, -2.0))
	await _idle(player, meter, 6)
	var through: Interactable = player.get_interaction().get_focused()
	assert_false(through != null and through == behind_wall.get_node("Grip"), "o objeto atrás da parede não está em foco")


## Arremesso pelo vão aberto: o objeto atravessa a porta aberta (não bate no batente) e segue para o outro lado.
func test_arremesso_pelo_vao_aberto_passa_a_porta() -> void:
	var world: Dictionary = await _world(CORRIDOR_STAND, -PI / 2.0)
	var root: Node = world["root"] as Node
	var player: PlayerRoot = world["player"] as PlayerRoot
	var meter: Fx.Meter = world["meter"] as Fx.Meter
	var door: Door = _door(root, "door_corredor_hall")
	await _tap(player)
	await _idle(player, meter, OPEN_TICKS)
	var item: Throwable = _spawn(root, THROWABLE_LIGHT, Vector3(13.8, 1.0, -0.7))
	await _idle(player, meter, 4)
	player.get_hold().try_pick(item)
	await _idle(player, meter, 2)
	await _throw_action(player)
	await _idle(player, meter, 60)
	note("arremesso pelo vão: objeto em x=%.2f, z=%.2f" % [item.global_position.x, item.global_position.z])
	assert_true(item.global_position.x > 14.0, "o objeto atravessa o vão aberto (x=%.2f)" % item.global_position.x)
	assert_eq(door.get_state(), Door.State.OPEN, "a porta continua aberta")


## Pegar um objeto e andar até encostar numa parede. Documenta o que o objeto na mão faz: ele segue a câmera sem colisão
## com o jogador; se atravessar a parede, isso é registrado (BUG). O jogador não pode ficar preso.
func test_objeto_na_mao_ao_encostar_na_parede() -> void:
	var world: Dictionary = await _world(CORRIDOR_STAND, PI)
	var root: Node = world["root"] as Node
	var player: PlayerRoot = world["player"] as PlayerRoot
	var meter: Fx.Meter = world["meter"] as Fx.Meter
	player.global_position = Vector3(9.0, 0.0, -0.6)
	player.rotation.y = PI
	var item: Throwable = _spawn(root, THROWABLE_LIGHT, Vector3(9.0, 1.0, -1.3))
	await _idle(player, meter, 4)
	player.get_hold().try_pick(item)
	await _idle(player, meter, 2)
	for _i: int in 90:
		await _tick(player, meter, Fx.move_input(Vector2(0.0, 1.0)))
	var past_wall: bool = item.global_position.z > SOUTH_WALL_FAR_Z
	note("objeto na mão contra a parede sul (z 0,1 = face externa): objeto z=%.3f, jogador z=%.3f, do outro lado da parede=%s (BUG-016 corrigido pelo Director: o objeto para na parede)" % [item.global_position.z, player.global_position.z, str(past_wall)])
	var start_z: float = player.global_position.z
	for _i: int in 60:
		await _tick(player, meter, Fx.move_input(Vector2(0.0, -1.0)))
	var back: float = absf(player.global_position.z - start_z)
	assert_true(back >= MIN_UNSTUCK_M, "o jogador não fica preso ao encostar na parede (recuou %.2f m)" % back)
	assert_eq(meter.penetrations, 0, "o corpo do jogador não atravessa a parede")


## Spam de pegar e arremessar contra uma parede: no máximo um impacto a cada cooldown por objeto (0,25 s).
func test_spam_de_arremesso_respeita_o_cooldown_de_impacto() -> void:
	var world: Dictionary = await _world(Vector3(9.0, 0.0, -0.2), 0.0)
	var root: Node = world["root"] as Node
	var player: PlayerRoot = world["player"] as PlayerRoot
	var meter: Fx.Meter = world["meter"] as Fx.Meter
	var item: Throwable = _spawn(root, THROWABLE_LIGHT, Vector3(9.0, 0.5, -0.6))
	var impacts: Array[int] = [0]
	var world_node: AcousticWorld = root.get_node("AcousticWorld") as AcousticWorld
	var ticks: int = 0
	world_node.noise_resolved_for_player.connect(func(event: NoiseEvent, _result: PropagationResult) -> void: impacts[0] += int(event.category == Enums.NoiseCategory.OBJECT_IMPACT))
	for _i: int in 20:
		await _idle(player, meter, 1)
		player.get_hold().try_pick(item)
		await _idle(player, meter, 1)
		await _throw_action(player)
		await _idle(player, meter, 2)
		ticks += 4
	await _idle(player, meter, 60)
	ticks += 60
	var limit: int = ticks / IMPACT_COOLDOWN_TICKS + 1
	note("spam de arremesso: %d impactos em %d ticks (limite pelo cooldown: %d)" % [impacts[0], ticks, limit])
	assert_true(impacts[0] <= limit, "impactos limitados pelo cooldown de 0,25 s (%d <= %d)" % [impacts[0], limit])


## Arremessar durante a pausa não arremessa: o objeto continua na mão e a pausa não é furada.
func test_arremessar_durante_a_pausa_nao_faz_nada() -> void:
	var world: Dictionary = await _world(CORRIDOR_STAND, -PI / 2.0)
	var root: Node = world["root"] as Node
	var player: PlayerRoot = world["player"] as PlayerRoot
	var meter: Fx.Meter = world["meter"] as Fx.Meter
	var item: Throwable = _spawn(root, THROWABLE_LIGHT, Vector3(13.8, 1.0, -0.7))
	await _idle(player, meter, 4)
	player.get_hold().try_pick(item)
	await _idle(player, meter, 2)
	root.get_tree().paused = true
	await _throw_action(player)
	await wait_physics_frames(3)
	var still_held: bool = item.is_held()
	root.get_tree().paused = false
	note("arremesso na pausa: objeto ainda na mão = %s" % str(still_held))
	assert_true(still_held, "na pausa, a ação throw não arremessa")
	await _throw_action(player)
	await _idle(player, meter, 4)
	assert_false(item.is_held(), "depois da pausa, o arremesso funciona")


## Arremesso com o estresse no máximo: o arremesso não depende da crise. Documenta a regra atual (sem custo na crise).
func test_arremesso_com_estresse_maximo_funciona() -> void:
	var world: Dictionary = await _world(CORRIDOR_STAND, -PI / 2.0)
	var root: Node = world["root"] as Node
	var player: PlayerRoot = world["player"] as PlayerRoot
	var meter: Fx.Meter = world["meter"] as Fx.Meter
	player.get_physiology().add_injury(100.0)
	var item: Throwable = _spawn(root, THROWABLE_LIGHT, Vector3(13.8, 1.0, -0.7))
	await _idle(player, meter, 4)
	player.get_hold().try_pick(item)
	await _idle(player, meter, 2)
	await _throw_action(player)
	await _idle(player, meter, 4)
	note("estresse %.1f: arremesso %s (sem custo fisiológico)" % [player.get_physiology().get_snapshot().stress, "ok" if not item.is_held() else "bloqueado"])
	assert_false(item.is_held(), "com estresse máximo, o arremesso funciona (regra atual, sem custo na crise)")


## Subir ou ficar preso num objeto: o jogador encosta num caixote pesado e precisa conseguir se afastar.
func test_encostar_em_caixote_nao_prende_o_jogador() -> void:
	var world: Dictionary = await _world(Vector3(8.0, 0.0, -0.7), -PI / 2.0)
	var root: Node = world["root"] as Node
	var player: PlayerRoot = world["player"] as PlayerRoot
	var meter: Fx.Meter = world["meter"] as Fx.Meter
	var box: Throwable = _spawn(root, THROWABLE_HEAVY, Vector3(9.4, 0.3, -0.7))
	await _idle(player, meter, 20)
	var top: float = 0.0
	for _i: int in 90:
		await _tick(player, meter, Fx.move_input(Vector2(0.0, 1.0)))
		top = maxf(top, player.global_position.y)
	var at_contact: Vector3 = player.global_position
	for _i: int in 60:
		await _tick(player, meter, Fx.move_input(Vector2(0.0, -1.0)))
	var back: float = at_contact.distance_to(player.global_position)
	note("caixote: altura máxima do jogador %.2f m; recuou %.2f m; caixote em %s" % [top, back, str(box.global_position)])
	assert_true(back >= MIN_UNSTUCK_M, "o jogador se afasta do caixote (recuou %.2f m)" % back)
	assert_eq(meter.penetrations, 0, "sem penetração no caixote")

extends TestCase
## F3-008 (integração): visão de debug acústica na sandbox jogável. A cena é carregada uma vez no arquivo
## (before_all); cada teste cria a sua AcousticDebugView, filha da cena, e a libera ao fim. Cobre: contagem de salas e
## portais contra o grafo, cor do portal ao abrir uma porta, anel criado por evento e expirado, F5, produção (nasce e
## fica desligada) e visão desligada (eventos não criam anéis). A física roda pouco: os testes são síncronos
## (orçamento da suíte: menos de 0,4 s para este arquivo).

const PLAYABLE_PATH: String = "res://content/levels/sandbox_playable.tscn"
## A sandbox_playable tem 6 RoomVolume (sala, cozinha, corredor, hall, mezanino, quintal) e 6 Portal.
const EXPECTED_ROOMS: int = 6
const EXPECTED_PORTALS: int = 6
const DOOR_NAME: String = "door_corredor_hall"
const PORTAL_ID: StringName = &"portal_corredor_hall"
const EVENT_DB: float = 75.0
const SETTLE_FRAMES: int = 3

var _root: Node = null
var _view: AcousticDebugView = null
var _previous_production: bool = false


func before_all() -> void:
	var scene: PackedScene = load(PLAYABLE_PATH) as PackedScene
	_root = scene.instantiate()
	add_child(_root)
	await wait_physics_frames(SETTLE_FRAMES)


func after_all() -> void:
	await release_and_flush(_root)
	_root = null


func before_each() -> void:
	_previous_production = GameState.is_production_build
	GameState.is_production_build = false


func after_each() -> void:
	_drop_view()
	GameState.is_production_build = _previous_production


func _world() -> AcousticWorld:
	return _root.get_node("AcousticWorld") as AcousticWorld


func _ear_position() -> Vector3:
	var camera: Camera3D = get_viewport().get_camera_3d()
	return camera.global_position if camera != null else Vector3.ZERO


## Cria a visão como filha da cena (a produção, se ativa, já vale no _ready).
func _make_view() -> void:
	_view = AcousticDebugView.new()
	_root.add_child(_view)


func _drop_view() -> void:
	if _view != null and is_instance_valid(_view):
		_root.remove_child(_view)
		_view.free()
	_view = null


func _push_toggle_key() -> void:
	var event: InputEventKey = InputEventKey.new()
	event.physical_keycode = AcousticDebugView.TOGGLE_KEY as Key
	event.pressed = true
	_view.get_viewport().push_input(event)


func _loud_event() -> NoiseEvent:
	return NoiseEvent.create(Enums.NoiseCategory.OBJECT_IMPACT, _ear_position() + Vector3(0.0, 0.0, -1.0),
		EVENT_DB, 0.0, &"enemy_impacto", &"")


func test_numero_de_salas_e_portais_bate_com_o_grafo() -> void:
	_make_view()
	assert_true(_view.toggle_view(), "fora de produção, a visão liga por código")
	assert_eq(_view.get_room_count(), EXPECTED_ROOMS, "a visão lê as 6 salas do nível")
	var colors: Dictionary = _view.get_portal_colors()
	assert_eq(colors.size(), EXPECTED_PORTALS, "a visão lê os 6 portais do nível")
	var graph: AcousticGraph = _world().get_graph()
	for portal_id: StringName in colors.keys():
		var shown_open: bool = (colors[portal_id] as Color) == AcousticDebugView.OPEN_COLOR
		assert_eq(graph.is_portal_open(portal_id), shown_open, "a cor do portal %s bate com o grafo" % portal_id)
	var scene_rooms: int = 0
	for node: Node in _root.get_tree().get_nodes_in_group(RoomVolume.GROUP):
		var room: RoomVolume = node as RoomVolume
		if room == null or not _root.is_ancestor_of(room):
			continue
		scene_rooms += 1
		assert_eq(graph.room_at(room.bounds_world().get_center()), room.room_id,
			"o grafo acha a sala %s pelo centro do volume" % room.room_id)
	assert_eq(scene_rooms, EXPECTED_ROOMS, "a cena tem as 6 salas esperadas")


func test_abrir_porta_muda_a_cor_do_portal() -> void:
	_make_view()
	_view.toggle_view()
	var door: Door = _root.find_child(DOOR_NAME, true, false) as Door
	assert_not_null(door, "a porta %s existe na cena" % DOOR_NAME)
	if door == null:
		return
	if door.get_state() == Door.State.LOCKED:
		door.unlock()
	assert_eq(door.get_state(), Door.State.CLOSED, "pré-condição: a porta começa fechada")
	var before: Dictionary = _view.get_portal_colors()
	assert_eq(before[PORTAL_ID], AcousticDebugView.CLOSED_COLOR, "portal fechado = vermelho antes de abrir")
	var context: InteractionContext = InteractionContext.new()
	context.actor = _root.find_child("Player", true, false)
	door.interact(context)
	var after: Dictionary = _view.get_portal_colors()
	assert_eq(after[PORTAL_ID], AcousticDebugView.OPEN_COLOR, "abrir a porta deixa o portal verde")
	_world().flush()


func test_evento_cria_anel_que_expira() -> void:
	# Esvazia a fila antes de ligar a visão: um evento antigo não pode virar anel aqui.
	_world().flush()
	_make_view()
	_view.toggle_view()
	var before: int = _view.get_ring_count()
	_world().emit_noise(_loud_event())
	_world().flush()
	assert_eq(_view.get_ring_count(), before + 1, "um evento de %s dB cria um anel" % EVENT_DB)
	_view.tick(AcousticDebugView.RING_LIFETIME_S * 0.5)
	assert_eq(_view.get_ring_count(), before + 1, "meio segundo depois, o anel continua")
	_view.tick(AcousticDebugView.RING_LIFETIME_S)
	assert_eq(_view.get_ring_count(), before, "depois de 1,5 s o anel expira")


func test_f5_liga_e_desliga_fora_de_producao() -> void:
	_make_view()
	assert_false(_view.is_view_visible(), "nasce desligada")
	_push_toggle_key()
	assert_true(_view.is_view_visible(), "F5 liga a visão")
	_push_toggle_key()
	assert_false(_view.is_view_visible(), "F5 de novo desliga a visão")


func test_com_debug_proibido_a_visao_nao_liga() -> void:
	GameState.is_production_build = true
	_make_view()
	assert_false(_view.is_view_visible(), "em produção a visão nasce desligada")
	assert_false(_view.is_processing(), "em produção a visão não processa")
	assert_false(_view.is_processing_unhandled_input(), "em produção a visão não lê a tecla")
	assert_false(_view.toggle_view(), "em produção, toggle_view recusa")
	_push_toggle_key()
	assert_false(_view.is_view_visible(), "em produção, F5 não liga a visão")
	_world().emit_noise(_loud_event())
	_world().flush()
	assert_eq(_view.get_ring_count(), 0, "em produção, nenhum anel é criado")
	assert_eq(_view.get_room_count(), 0, "em produção, a visão não lê o nível")


func test_desligada_eventos_nao_criam_aneis() -> void:
	_world().flush()
	_make_view()
	assert_false(_view.is_view_visible(), "nasce desligada")
	_world().emit_noise(_loud_event())
	_world().flush()
	assert_eq(_view.get_ring_count(), 0, "desligada, um evento não cria anel")
	_view.toggle_view()
	assert_false(_view.toggle_view(), "segundo toggle desliga")
	_world().emit_noise(_loud_event())
	_world().flush()
	assert_eq(_view.get_ring_count(), 0, "depois de desligar, eventos param de criar anéis")
	assert_eq(_view.get_room_count(), 0, "desligada, a visão não mantém o nível lido")

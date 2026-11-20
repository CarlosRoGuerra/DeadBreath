class_name DebugOverlay
extends CanvasLayer
## Overlay de debug (L3, F1-008). F3 (ação debug_overlay) mostra fps, tempo de frame, postura, marcha,
## esforço, velocidade e foco da interação. Com o overlay visível: N liga e desliga o noclip; T teleporta
## para o ponto do chão na mira. Tudo desligado quando GameState.is_production_build.
## É observador: lê o PlayerRoot e só envia os comandos de DebugCommands.

const KEY_NOCLIP: int = KEY_N
const KEY_TELEPORT: int = KEY_T
const STANCE_NAMES: PackedStringArray = ["em pé", "agachado", "rastejando"]
const GAIT_NAMES: PackedStringArray = ["parado", "devagar", "andando", "correndo"]
const OVERLAY_LAYER: int = 100
const MS_PER_S: float = 1000.0

var _player: PlayerRoot = null
var _label: Label = null
var _frame_ms: float = 0.0


func _ready() -> void:
	layer = OVERLAY_LAYER
	_label = Label.new()
	_label.position = Vector2(12.0, 12.0)
	add_child(_label)
	visible = false
	if not is_debug_enabled():
		set_process(false)
		set_process_unhandled_input(false)


func is_debug_enabled() -> bool:
	return DebugCommands.is_allowed()


## Injeção explícita (testes e cenas que já têm a referência). Sem injeção, o overlay acha o jogador sozinho.
func set_player(player: PlayerRoot) -> void:
	_player = player


## Jogador do overlay: o injetado, ou o primeiro no grupo "player" (R1-04: a cena jogável não injeta).
func get_player() -> PlayerRoot:
	if _player == null or not is_instance_valid(_player):
		_player = _find_player_in_group()
	return _player


func _find_player_in_group() -> PlayerRoot:
	if not is_inside_tree():
		return null
	return get_tree().get_first_node_in_group(PlayerRoot.PLAYER_GROUP) as PlayerRoot


func is_overlay_visible() -> bool:
	return visible


func get_overlay_text() -> String:
	if _label == null:
		return ""
	return _label.text


## Alterna a visibilidade. Em produção recusa e devolve false.
func toggle_overlay() -> bool:
	if not is_debug_enabled():
		visible = false
		return false
	visible = not visible
	return visible


func toggle_noclip() -> bool:
	var player: PlayerRoot = get_player()
	if player == null:
		return false
	return DebugCommands.set_noclip(player, not player.is_noclip())


func teleport_to_aim() -> bool:
	var player: PlayerRoot = get_player()
	if player == null:
		return false
	return DebugCommands.teleport_to_aim(player)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"debug_overlay"):
		toggle_overlay()
		get_viewport().set_input_as_handled()
		return
	if not visible:
		return
	var key: InputEventKey = event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	if key.physical_keycode == KEY_NOCLIP:
		toggle_noclip()
		get_viewport().set_input_as_handled()
	elif key.physical_keycode == KEY_TELEPORT:
		teleport_to_aim()
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	_frame_ms = delta * MS_PER_S
	if visible and _label != null:
		_label.text = _build_text()


func _build_text() -> String:
	var player: PlayerRoot = get_player()
	if player == null:
		return "debug: sem jogador"
	var motor: PlayerMotor = player.get_motor()
	var lines: PackedStringArray = PackedStringArray()
	lines.append("fps: %d   frame: %.2f ms" % [int(Engine.get_frames_per_second()), _frame_ms])
	lines.append("postura: %s" % STANCE_NAMES[int(motor.get_stance())])
	lines.append("marcha: %s" % GAIT_NAMES[int(motor.get_gait())])
	lines.append("esforço: %.2f" % motor.get_exertion())
	lines.append("velocidade: %.2f m/s" % motor.get_horizontal_speed())
	lines.append("foco: %s" % _focus_text())
	lines.append("noclip: %s" % ("ligado" if player.is_noclip() else "desligado"))
	lines.append("[N] noclip   [T] teleporte para a mira   [F3] fecha")
	return "\n".join(lines)


func _focus_text() -> String:
	var target: Interactable = get_player().get_interaction().get_focused()
	if target == null:
		return "nenhum"
	if not target.prompt_key.is_empty():
		return String(target.prompt_key)
	return target.name

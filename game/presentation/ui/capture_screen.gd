class_name CaptureScreen
extends CanvasLayer
## CaptureScreen (L3, presentation/ui; F4-005, decisão D4-04): tela "Capturado" provisória até os checkpoints da F5.
## Ouve EventBus.player_captured: escurece a tela em FADE_S e, passados RESTART_DELAY_S, reinicia a cena atual, uma
## única vez. Captura repetida durante o fade não reinicia de novo. A entrada do jogador é travada pelo PlayerRoot, que
## ouve o mesmo sinal: esta tela não conhece o jogador (PLR-INV-1). Funciona em pausa (PROCESS_MODE_ALWAYS).
## Testes: advance(delta) dirige o tempo; restart_callable substitui o reload_current_scene.
## Autor: Gameplay Engineer (F4-005, parte de UI e fluxo).

const FADE_S: float = 1.0
const RESTART_DELAY_S: float = 2.5
const CAPTION: String = "Capturado"
const LAYER_ORDER: int = 100
const CAPTION_FONT_SIZE: int = 48

## Chamado uma única vez ao reiniciar. Vazio: get_tree().reload_current_scene().
var restart_callable: Callable = Callable()

var _shade: ColorRect = null
var _caption: Label = null
var _capturing: bool = false
var _elapsed_s: float = 0.0
var _restart_count: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = LAYER_ORDER
	_shade = ColorRect.new()
	_shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_shade.color = Color(0.0, 0.0, 0.0, 0.0)
	_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_shade)
	_caption = Label.new()
	_caption.text = CAPTION
	_caption.set_anchors_preset(Control.PRESET_CENTER)
	_caption.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_caption.grow_vertical = Control.GROW_DIRECTION_BOTH
	_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_caption.add_theme_font_size_override(&"font_size", CAPTION_FONT_SIZE)
	_caption.modulate = Color(1.0, 1.0, 1.0, 0.0)
	_caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_caption)
	EventBus.player_captured.connect(_on_player_captured)


func _exit_tree() -> void:
	if EventBus.player_captured.is_connected(_on_player_captured):
		EventBus.player_captured.disconnect(_on_player_captured)


func _process(delta: float) -> void:
	advance(delta)


## Avança o fade e o temporizador de reinício. Chamado a cada quadro; os testes chamam direto.
func advance(delta: float) -> void:
	if not _capturing:
		return
	_elapsed_s += delta
	var fade: float = clampf(_elapsed_s / FADE_S, 0.0, 1.0)
	_shade.color = Color(0.0, 0.0, 0.0, fade)
	_caption.modulate = Color(1.0, 1.0, 1.0, fade)
	if _elapsed_s >= RESTART_DELAY_S and _restart_count == 0:
		_restart_count += 1
		_restart()


func is_capturing() -> bool:
	return _capturing


## Opacidade atual do escurecimento (0 a 1).
func get_fade_alpha() -> float:
	return _shade.color.a


func get_caption_text() -> String:
	return _caption.text


func get_restart_count() -> int:
	return _restart_count


func _on_player_captured(_enemy_id: StringName) -> void:
	if _capturing:
		return
	_capturing = true
	_elapsed_s = 0.0


func _restart() -> void:
	if restart_callable.is_valid():
		restart_callable.call()
	else:
		get_tree().reload_current_scene()

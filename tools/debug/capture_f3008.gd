extends SceneTree
## F3-008: captura com janela da visão acústica de debug na sandbox jogável (salas em arame, portais e um anel de
## ruído no hall). Ferramenta de QA, fora do jogo. Não é carregada pelo jogo.
##
## Como o arquivo fica em game/ só durante a captura (o Godot só lê res:// dentro do projeto):
##   copy tools\debug\capture_f3008.gd game\tmp_f3008_capture.gd
##   & "<godot console exe>" --path D:\Dev\DeadBreath\game --resolution 1920x1080 -s res://tmp_f3008_capture.gd -- --out=D:\Dev\DeadBreath\Docs\QA\EVIDENCE
##   del game\tmp_f3008_capture.gd   (e o .uid, se aparecer)
## Usa -s (como o runner e o capture_f3007). Classes do projeto são carregadas com load() em tempo de execução:
## referenciá-las pelo nome no código deste script faz o Godot compilar as classes antes dos autoloads (Log, Settings),
## e a compilação falha. Por isso as chamadas usam call().
##
## Painéis de depuração (CanvasLayer) ficam ocultos; o teto do hall fica oculto para ver as salas por dentro.
## Imprime o caminho e a fração de pixels com luminância > 0,05, para registro.

const PLAYABLE_PATH: String = "res://content/levels/sandbox_playable.tscn"
const VIEW_SCRIPT_PATH: String = "res://presentation/debug/acoustic_debug_view.gd"
const EVENT_SCRIPT_PATH: String = "res://sim/acoustics/noise_event.gd"
## Enums.NoiseCategory.DOOR (core/enums.gd, posição 5 do enum).
const CATEGORY_DOOR: int = 5
const SETTLE_FRAMES: int = 30
const LUM_THRESHOLD: float = 0.05
const SAMPLE_STEP: int = 8
const OVERLAY_NAMES: Array[String] = ["PauseMenu", "DebugOverlay", "BalancePanel", "Subtitles"]
## Centro do hall (RoomVolume_hall: position 17, 1.5, -1.34), um pouco abaixo do centro para cair no piso.
const HALL_EVENT_AT: Vector3 = Vector3(17.0, 1.0, -1.34)

var _out_dir: String = ""
var _root: Node = null
var _started: bool = false


func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out_dir = arg.substr(6)


## Começa no primeiro frame: os autoloads só existem depois de _initialize.
func _process(_delta: float) -> bool:
	if not _started:
		_started = true
		_run()
	return false


func _run() -> void:
	var packed: PackedScene = load(PLAYABLE_PATH) as PackedScene
	_root = packed.instantiate()
	get_root().add_child(_root)
	for overlay: String in OVERLAY_NAMES:
		var layer: CanvasLayer = _root.get_node_or_null(overlay) as CanvasLayer
		if layer != null:
			layer.visible = false
	var view_script: GDScript = load(VIEW_SCRIPT_PATH) as GDScript
	var view: Node3D = view_script.new() as Node3D
	_root.add_child(view)
	view.call("toggle_view")
	var ceilings: Node3D = _root.get_node("Level/Geometry/Ceilings") as Node3D
	ceilings.visible = false
	await _settle()

	var cam: Camera3D = Camera3D.new()
	cam.fov = 55.0
	get_root().add_child(cam)
	cam.global_position = Vector3(9.0, 16.0, 10.0)
	cam.look_at(Vector3(14.0, 0.0, -2.0), Vector3.UP)
	cam.current = true
	await _settle()

	# Porta normal (50 dB, door_normal) no hall: o anel nasce no piso e some em 1,5 s, então a foto sai logo depois.
	var world: Node = _root.get_node("AcousticWorld")
	var event_script: GDScript = load(EVENT_SCRIPT_PATH) as GDScript
	var event: Variant = event_script.call("create", CATEGORY_DOOR, HALL_EVENT_AT, 50.0, 0.0,
		&"enemy_porta", &"door_normal")
	world.call("emit_noise", event)
	for _frame: int in range(3):
		await process_frame
	var ok: bool = await _shoot("F3-008_visao_acustica_debug.png")
	print("F3-008 anéis ativos na captura: %s; salas: %s; portais: %s" % [str(view.call("get_ring_count")),
		str(view.call("get_room_count")), str((view.call("get_portal_colors") as Dictionary).size())])
	print("F3-008 captura: %s" % ("OK" if ok else "FALHOU"))
	quit(0 if ok else 1)


func _settle() -> void:
	for i: int in range(SETTLE_FRAMES):
		await process_frame
	await RenderingServer.frame_post_draw


func _shoot(file_name: String) -> bool:
	await RenderingServer.frame_post_draw
	var img: Image = get_root().get_texture().get_image()
	var path_out: String = _out_dir.path_join(file_name)
	var err: Error = img.save_png(path_out)
	var lit: int = 0
	var samples: int = 0
	var lum_sum: float = 0.0
	for y: int in range(0, img.get_height(), SAMPLE_STEP):
		for x: int in range(0, img.get_width(), SAMPLE_STEP):
			var lum: float = img.get_pixel(x, y).get_luminance()
			lum_sum += lum
			samples += 1
			if lum > LUM_THRESHOLD:
				lit += 1
	print("shot=%s err=%d size=%s mean_lum=%.4f lit_fraction=%.3f" % [path_out, err, img.get_size(), lum_sum / float(samples), float(lit) / float(samples)])
	return err == OK

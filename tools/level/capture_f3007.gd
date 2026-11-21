extends SceneTree
## F3-007: captura com janela das áreas acústicas novas, na sandbox jogável (portas instanciadas pelo LevelSlots).
## Ferramenta de level design, fora do jogo. Não é carregada pelo jogo.
##
## Como o arquivo fica em game/ só durante a captura (o Godot só lê res:// dentro do projeto):
##   copy tools\level\capture_f3007.gd game\tmp_f3007_capture.gd
##   & (Get-GodotPath) --path D:\Dev\DeadBreath\game --resolution 1920x1080 -s res://tmp_f3007_capture.gd -- --out=D:\Dev\DeadBreath\Docs\QA\EVIDENCE
##   del game\tmp_f3007_capture.gd   (e o .uid, se aparecer)
## Usa -s (como o runner): com --script, o PlayerRoot não compila (Settings ainda não existe).
##
## Painéis de depuração (CanvasLayer) ficam ocultos nas capturas. Imprime, por imagem, a fração de pixels com
## luminância > 0,05 (amostragem a cada 8 px), para registro.

const PLAYABLE_PATH: String = "res://content/levels/sandbox_playable.tscn"
const SETTLE_FRAMES: int = 30
const LUM_THRESHOLD: float = 0.05
const SAMPLE_STEP: int = 8
const OVERLAY_NAMES: Array[String] = ["PauseMenu", "DebugOverlay", "BalancePanel"]

var _out_dir: String = ""
var _root: Node = null
var _player: Node3D = null
var _started: bool = false


func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out_dir = arg.substr(6)


## Começa no primeiro frame: os autoloads (Settings etc.) só existem depois de _initialize.
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
	_player = _root.get_node("Level/Player") as Node3D
	await _settle()

	# Quintal visto do hall: a porta door_hall_quintal (x = 20, z = -1,2) fica à frente, a 5 m.
	_player.global_position = Vector3(15.0, 0.0, -1.2)
	_player.rotation.y = -PI / 2.0
	await _settle()
	var ok: bool = await _shoot("F3-007_quintal_porta.png")

	# Mezanino: sobre a laje (y 1,08), olhando de volta para a escada e o hall.
	_player.global_position = Vector3(17.0, 1.08, -4.5)
	_player.rotation.y = PI
	await _settle()
	ok = await _shoot("F3-007_mezanino.png") and ok

	# Vista geral acústica: teto oculto, câmera alta sobre a casa e o quintal.
	var ceilings: Node3D = _root.get_node("Level/Geometry/Ceilings") as Node3D
	ceilings.visible = false
	var cam: Camera3D = Camera3D.new()
	cam.fov = 55.0
	get_root().add_child(cam)
	cam.global_position = Vector3(-4.0, 17.0, 12.0)
	cam.look_at(Vector3(11.0, 0.0, -3.0), Vector3.UP)
	cam.current = true
	await _settle()
	ok = await _shoot("F3-007_visao_acustica.png") and ok
	ceilings.visible = true

	print("F3-007 capturas: %s" % ("OK" if ok else "FALHOU"))
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

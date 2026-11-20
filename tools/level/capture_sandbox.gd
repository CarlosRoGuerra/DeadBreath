extends SceneTree
## F1-009: captura da sandbox com janela (POV do jogador em três pontos e vista geral).
## Ferramenta de level design, fora do jogo. Não é carregada pelo jogo.
##
## Como o arquivo fica em game/ só durante a captura (o Godot só lê res:// dentro do projeto):
##   copy tools\level\capture_sandbox.gd game\tmp_f1009_capture.gd
##   & (Get-GodotPath) --path D:\Dev\DeadBreath\game --resolution 1920x1080 `
##       --script res://tmp_f1009_capture.gd -- --out=D:\Dev\DeadBreath\Docs\QA\EVIDENCE
##   del game\tmp_f1009_capture.gd   (e o .uid, se aparecer)
##
## Sai com código 0 só se as 3 imagens foram gravadas. Imprime, para cada imagem, a fração de pixels
## com luminância > 0,05 (mesma métrica de spikes/disc003/bench_probe.gd, amostragem a cada 8 px).

const LEVEL_PATH: String = "res://content/levels/sandbox.tscn"
const SETTLE_FRAMES: int = 20
const LUM_THRESHOLD: float = 0.05
const SAMPLE_STEP: int = 8
const SHOTS: Array[String] = [
	"F1-009_sandbox_pov_sala.png",
	"F1-009_sandbox_pov_escada.png",
	"F1-009_sandbox_visao_geral.png",
]

var _out_dir: String = ""
var _level: Node3D = null
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
	var packed: PackedScene = load(LEVEL_PATH) as PackedScene
	_level = packed.instantiate() as Node3D
	get_root().add_child(_level)
	_player = _level.get_node("Player") as Node3D
	await _settle()
	var ok: bool = await _shoot(SHOTS[0])

	# POV da escada: pé da escada, olhando para o mezanino (yaw 0 = olha para -Z).
	_player.global_position = Vector3(17.0, 0.0, -0.5)
	await _settle()
	ok = await _shoot(SHOTS[1]) and ok

	# Vista geral: câmera alta, teto oculto para ver as salas por dentro.
	var ceilings: Node3D = _level.get_node("Geometry/Ceilings") as Node3D
	ceilings.visible = false
	var cam: Camera3D = Camera3D.new()
	cam.fov = 55.0
	get_root().add_child(cam)
	cam.global_position = Vector3(-3.5, 15.0, 11.0)
	cam.look_at(Vector3(10.0, 0.0, -3.0), Vector3.UP)
	cam.current = true
	await _settle()
	ok = await _shoot(SHOTS[2]) and ok
	ceilings.visible = true

	print("F1-009 capturas: %s" % ("OK" if ok else "FALHOU"))
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

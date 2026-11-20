extends SceneTree
## Captura visual do QA (F1-011), COM janela. Carrega a cena jogável, posiciona o jogador, opcionalmente abre a porta
## door_sala_corredor com o botão de interação (toque), espera o quadro assentar e grava um PNG. Imprime CAPTURE e encerra.
## Uso: godot --path game --resolution 1280x720 --quit-after 2000 -s res://tests/integration/qa/probes/f1011_capture.gd --
##        <saida.png> <x> <y> <z> <yaw_graus> <pitch_graus> <abrir_porta: 0|1>
## Autor: QA Engineer (F1-011).

const PLAYABLE_PATH: String = "res://content/levels/sandbox_playable.tscn"
const SETTLE_FRAMES: int = 90
const OPEN_FRAMES: int = 90

var _started: bool = false


func _process(_delta: float) -> bool:
	if not _started:
		_started = true
		_run()
	return false


func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var out_path: String = args[0] if args.size() > 0 else "user://f1011_capture.png"
	var pos: Vector3 = Vector3(float(args[1]), float(args[2]), float(args[3])) if args.size() > 3 else Vector3(3.0, 0.0, -1.0)
	var yaw_deg: float = float(args[4]) if args.size() > 4 else 0.0
	var pitch_deg: float = float(args[5]) if args.size() > 5 else 0.0
	var open_door: bool = args.size() > 6 and args[6] == "1"
	var scene: PackedScene = load(PLAYABLE_PATH) as PackedScene
	var playable: Node = scene.instantiate()
	root.add_child(playable)
	for index: int in 10:
		await process_frame
	var player: Node3D = playable.find_child("Player", true, false) as Node3D
	player.global_position = pos
	player.rotation.y = deg_to_rad(yaw_deg)
	var head: Node3D = player.get_node("Head") as Node3D
	head.rotation.x = deg_to_rad(pitch_deg)
	for index: int in SETTLE_FRAMES:
		await process_frame
	if open_door:
		var interaction: Node = player.get_node("InteractionComponent")
		var focused: Node = interaction.call("get_focused") as Node
		print("CAPTURE foco antes de abrir=%s" % (str(focused.name) if focused != null else "nenhum"))
		interaction.call("press_interact")
		await process_frame
		await process_frame
		interaction.call("release_interact")
		for index: int in OPEN_FRAMES:
			await process_frame
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	var err: int = int(image.save_png(out_path))
	print("CAPTURE %s err=%d tamanho=%s posicao=%s" % [out_path, err, str(image.get_size()), str(player.global_position)])
	quit(0 if err == OK else 1)

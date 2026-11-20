extends SceneTree
## Captura de tela da cena jogável (Director, integração F1-009). Uso, COM janela:
##   godot --path game --resolution 1920x1080 --quit-after 900 -s <caminho>/capture_playable.gd -- <saida.png> <yaw_graus>
## Carrega content/levels/sandbox_playable.tscn, gira o jogador para o yaw pedido, espera a cena
## assentar, grava o PNG e sai. --quit-after é a rede de segurança contra janela presa.

const PLAYABLE_PATH: String = "res://content/levels/sandbox_playable.tscn"
const SETTLE_FRAMES: int = 90


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var out_path: String = args[0] if args.size() > 0 else "user://capture_playable.png"
	var yaw_deg: float = float(args[1]) if args.size() > 1 else 0.0
	var scene: PackedScene = load(PLAYABLE_PATH) as PackedScene
	if scene == null:
		printerr("CAPTURE falhou: cena não carregou")
		quit(1)
		return
	root.add_child(scene.instantiate())
	for i: int in 10:
		await process_frame
	var players: Array[Node] = get_nodes_in_group(&"player")
	if players.is_empty():
		printerr("CAPTURE falhou: sem jogador")
		quit(1)
		return
	var player: Node3D = players[0] as Node3D
	player.rotation.y = deg_to_rad(yaw_deg)
	for i: int in SETTLE_FRAMES:
		await process_frame
	await RenderingServer.frame_post_draw
	var img: Image = root.get_texture().get_image()
	var err: Error = img.save_png(out_path)
	print("CAPTURE %s err=%d size=%s portas=%d" % [out_path, err, img.get_size(), get_nodes_in_group(&"door_slot").size()])
	quit(0 if err == OK else 1)

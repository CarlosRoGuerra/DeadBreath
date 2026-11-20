extends SceneTree
## F1-D03: captura de verificação dos 5 materiais CC0 (4 pisos + 1 parede) sob luz pontual e névoa.
## Ferramenta de arte, fora do jogo. Não é carregada pelo jogo.
##
## Como o arquivo fica em game/ só durante a captura (o Godot só lê res:// dentro do projeto):
##   copy tools\art\material_preview\material_preview.gd game\tmp_f1d03_material_preview.gd
##   & (Get-GodotPath) --path D:\Dev\DeadBreath\game --resolution 1920x1080 `
##       --script res://tmp_f1d03_material_preview.gd -- --out=D:\Dev\DeadBreath\Docs\QA\EVIDENCE
##   del game\tmp_f1d03_material_preview.gd   (e o .uid, se aparecer)
##
## Sai com código 0 só se os 5 materiais carregaram com albedo e a imagem foi gravada.

const MATERIALS: Array[String] = [
	"res://content/materials/mat_floor_wood.tres",
	"res://content/materials/mat_floor_carpet.tres",
	"res://content/materials/mat_floor_tile.tres",
	"res://content/materials/mat_floor_concrete.tres",
	"res://content/materials/mat_wall_plaster.tres",
]
const LABELS: Array[String] = ["wood", "carpet", "tile", "concrete", "plaster (parede)"]


func _initialize() -> void:
	var out_dir: String = ""
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out_dir = a.substr(6)
	_capture(out_dir)


func _capture(out_dir: String) -> void:
	var ok: bool = true
	var mats: Array[StandardMaterial3D] = []
	for path: String in MATERIALS:
		var m: StandardMaterial3D = load(path) as StandardMaterial3D
		var has_albedo: bool = m != null and m.albedo_texture != null
		var has_normal: bool = m != null and m.normal_enabled and m.normal_texture != null
		var has_rough: bool = m != null and m.roughness_texture != null
		print("MAT %s | albedo=%s normal=%s roughness=%s" % [path, has_albedo, has_normal, has_rough])
		if not has_albedo or not has_normal or not has_rough:
			ok = false
		mats.append(m)

	var root: Node3D = Node3D.new()
	root.name = "PreviewRoom"
	get_root().add_child(root)

	var env: Environment = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.01, 0.01, 0.015)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.05, 0.05, 0.07)
	env.ambient_light_energy = 0.3
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = 0.04
	env.volumetric_fog_albedo = Color(0.8, 0.8, 0.85)
	env.ssao_enabled = true
	var world_env: WorldEnvironment = WorldEnvironment.new()
	world_env.environment = env
	root.add_child(world_env)

	# Quatro pisos (2 x 2 m cada) lado a lado, e uma parede de reboco atrás.
	var xs: Array[float] = [-3.0, -1.0, 1.0, 3.0]
	for i: int in range(4):
		_box(root, Vector3(2.0, 0.1, 2.0), Vector3(xs[i], -0.05, 0.0), mats[i])
		_label(root, LABELS[i], Vector3(xs[i], 0.6, 0.6))
	_box(root, Vector3(10.0, 3.0, 0.2), Vector3(0.0, 1.5, -1.6), mats[4])
	_label(root, LABELS[4], Vector3(0.0, 2.6, -1.4))

	var light: OmniLight3D = OmniLight3D.new()
	light.position = Vector3(0.0, 2.3, 1.2)
	light.light_color = Color(1.0, 0.75, 0.5)
	light.light_energy = 3.0
	light.omni_range = 9.0
	light.shadow_enabled = true
	root.add_child(light)

	var cam: Camera3D = Camera3D.new()
	cam.fov = 60.0
	cam.current = true
	cam.look_at_from_position(Vector3(0.0, 1.7, 5.0), Vector3(0.0, 0.2, -0.8), Vector3.UP)
	root.add_child(cam)

	await process_frame
	await RenderingServer.frame_post_draw
	var img: Image = get_root().get_texture().get_image()
	var path_out: String = out_dir.path_join("F1-D03_materials.png")
	var err: Error = img.save_png(path_out)
	print("F1-D03 shot=%s err=%d size=%s ok_materials=%s" % [path_out, err, img.get_size(), ok])
	quit(0 if (ok and err == OK) else 1)


func _box(parent: Node3D, size: Vector3, center: Vector3, mat: Material) -> void:
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = size
	var inst: MeshInstance3D = MeshInstance3D.new()
	inst.mesh = mesh
	inst.material_override = mat
	inst.position = center
	parent.add_child(inst)


func _label(parent: Node3D, text: String, pos: Vector3) -> void:
	var l: Label3D = Label3D.new()
	l.text = text
	l.font_size = 48
	l.pixel_size = 0.004
	l.position = pos
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	parent.add_child(l)

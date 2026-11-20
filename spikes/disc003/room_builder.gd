extends RefCounted
## DISC-003 V3/V5: sala greybox com névoa volumétrica e 3 luzes pontuais com sombra.

static func build() -> Node3D:
	var root: Node3D = Node3D.new()
	root.name = "Room"

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
	env.glow_enabled = true
	var world_env: WorldEnvironment = WorldEnvironment.new()
	world_env.environment = env
	root.add_child(world_env)

	var wall: StandardMaterial3D = StandardMaterial3D.new()
	wall.albedo_color = Color(0.45, 0.43, 0.40)
	wall.roughness = 0.9
	var wood: StandardMaterial3D = StandardMaterial3D.new()
	wood.albedo_color = Color(0.35, 0.25, 0.18)
	wood.roughness = 0.7

	# Sala 10 x 3 x 8 m
	_box(root, Vector3(10, 0.2, 8), Vector3(0, -0.1, 0), wall)
	_box(root, Vector3(10, 0.2, 8), Vector3(0, 3.1, 0), wall)
	_box(root, Vector3(0.2, 3, 8), Vector3(-5, 1.5, 0), wall)
	_box(root, Vector3(0.2, 3, 8), Vector3(5, 1.5, 0), wall)
	_box(root, Vector3(10, 3, 0.2), Vector3(0, 1.5, -4), wall)
	_box(root, Vector3(10, 3, 0.2), Vector3(0, 1.5, 4), wall)
	# Móveis em greybox
	_box(root, Vector3(1.6, 0.75, 0.9), Vector3(-2, 0.375, -1), wood)
	_box(root, Vector3(0.5, 2.0, 1.2), Vector3(4.5, 1.0, 2), wood)
	_box(root, Vector3(2.0, 0.5, 0.9), Vector3(1.5, 0.25, -3.2), wood)
	_box(root, Vector3(0.6, 1.2, 0.6), Vector3(-4.3, 0.6, 3.0), wood)
	_box(root, Vector3(0.3, 3.0, 0.3), Vector3(2.0, 1.5, 0.5), wall)

	_omni(root, Vector3(-3.0, 2.6, -2.0), Color(1.0, 0.75, 0.5), 2.0)
	_omni(root, Vector3(2.5, 2.4, 1.5), Color(0.6, 0.7, 1.0), 1.5)
	_omni(root, Vector3(0.0, 1.0, -3.5), Color(1.0, 0.4, 0.3), 1.2)

	var cam: Camera3D = Camera3D.new()
	cam.name = "Camera"
	cam.fov = 75.0
	cam.transform = Transform3D(Basis(), Vector3(0, 1.6, 3.4)).looking_at(Vector3(0, 1.0, -2), Vector3.UP)
	cam.current = true
	root.add_child(cam)
	return root


static func _box(parent: Node3D, size: Vector3, center: Vector3, mat: Material) -> void:
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = size
	var inst: MeshInstance3D = MeshInstance3D.new()
	inst.mesh = mesh
	inst.material_override = mat
	inst.position = center
	parent.add_child(inst)


static func _omni(parent: Node3D, pos: Vector3, color: Color, energy: float) -> void:
	var light: OmniLight3D = OmniLight3D.new()
	light.position = pos
	light.light_color = color
	light.light_energy = energy
	light.omni_range = 7.0
	light.shadow_enabled = true
	parent.add_child(light)

#!/usr/bin/env python3
"""Gera game/content/levels/sandbox.tscn (F1-009, Level Designer).

Ferramenta de level design, fora do jogo. A cena é texto (.tscn format=3); este script só
escreve a planta. Para mudar a sandbox, edite as constantes abaixo e rode de novo:

    python tools/level/gen_sandbox.py

Convenções:
- 1 unidade = 1 m; y = 0 é o topo do piso; paredes com 3,0 m de altura e 0,2 m de espessura.
- Linhas de parede (eixos) são as bordas das salas; o piso vai de eixo a eixo.
- Colisores de piso (StaticBody3D) levam o metadado `surface` (StringName) lido pelo PlayerMotor.
- Colisão de geometria na camada 1 (world_static). Áreas de sala na camada 8 (trigger), máscara 4 (jogador).
- Portas e pickups não existem ainda: aqui entram só Marker3D de encaixe (grupos door_slot, pickup_slot).
"""

import os
import sys

ROOT: str = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT_PATH: str = os.path.join(ROOT, "game", "content", "levels", "sandbox.tscn")

WALL_T: float = 0.2
WALL_H: float = 3.0
DOOR_W: float = 0.9
DOOR_H: float = 2.0
CEIL_Y: float = 3.05
CEIL_T: float = 0.1

MAT_PATHS: dict[str, str] = {
	"wood": "res://content/materials/mat_floor_wood.tres",
	"carpet": "res://content/materials/mat_floor_carpet.tres",
	"tile": "res://content/materials/mat_floor_tile.tres",
	"concrete": "res://content/materials/mat_floor_concrete.tres",
	"plaster": "res://content/materials/mat_wall_plaster.tres",
}


# Aberturas (vãos de 0,9 m). axis "x": parede em x = fixed, o centro varia em z. axis "z": o contrário.
OPENINGS: list[dict[str, object]] = [
	{"door_id": "door_sala_corredor", "axis": "x", "fixed": 6.0, "center": -0.7, "state": "closed", "room_a": "sala", "room_b": "corredor"},
	{"door_id": "door_sala_cozinha", "axis": "x", "fixed": 6.0, "center": -3.0, "state": "open", "room_a": "sala", "room_b": "cozinha"},
	{"door_id": "door_cozinha_corredor", "axis": "z", "fixed": -1.4, "center": 8.5, "state": "locked", "room_a": "cozinha", "room_b": "corredor"},
	{"door_id": "door_corredor_hall", "axis": "x", "fixed": 14.0, "center": -0.7, "state": "closed", "room_a": "corredor", "room_b": "hall"},
	{"door_id": "door_hall_quintal", "axis": "x", "fixed": 20.0, "center": -1.2, "state": "closed", "room_a": "hall", "room_b": "quintal"},
]
OPENING_CENTER: dict[str, float] = {str(o["door_id"]): float(o["center"]) for o in OPENINGS}  # type: ignore[arg-type]

# Escada: 6 degraus, espelho 0,18 m, piso 0,28 m, largura 1,2 m, subindo para -Z até o mezanino a 1,08 m.
# Com 8 degraus (1,44 m) a cabeça ficaria a 1,56 m do teto de 3,0 m: menos que a altura em pé (1,75 m).
STAIR_X: float = 17.0
STAIR_W: float = 1.2
STAIR_STEPS: int = 6
STAIR_RISE: float = 0.18
STAIR_TREAD: float = 0.28
STAIR_NEAR_Z: float = -1.0
MEZZ_TOP: float = STAIR_RISE * STAIR_STEPS  # 1,08 m (6 × 0,18)
MEZZ_SLAB_T: float = 0.06
MEZZ_Z0: float = -6.0
MEZZ_Z1: float = STAIR_NEAR_Z - STAIR_TREAD * STAIR_STEPS  # -2,68 (-1,0 - 6 × 0,28)

# Salas: id -> (x0, x1, z0, z1, superficie do piso). Eixos de parede.
# hall e so o terreo (a partir do pe da escada); mezanino e o vao sob a laje e a laje (sala propria).
ROOMS: dict[str, tuple[float, float, float, float, str]] = {
	"sala": (0.0, 6.0, -6.0, 0.0, "wood"),
	"cozinha": (6.0, 14.0, -6.0, -1.4, "tile"),
	"corredor": (6.0, 14.0, -1.4, 0.0, "concrete"),
	"hall": (14.0, 20.0, MEZZ_Z1, 0.0, "carpet"),
	"mezanino": (14.0, 20.0, -6.0, MEZZ_Z1, "carpet"),
	"quintal": (20.0, 24.0, -6.0, 0.0, "concrete"),
}
# Acustica por sala (DATA 2.3, madrugada com chuva): piso de ruido e barramento de reverb (sugestao do
# Director; o Audio Engineer cria os barramentos). Quintal: exterior, sem reverb.
ROOM_ACOUSTICS: dict[str, tuple[float, str]] = {
	"sala": (28.0, "reverb_small"),
	"cozinha": (22.0, "reverb_small"),
	"corredor": (22.0, "reverb_large"),
	"hall": (22.0, "reverb_large"),
	"mezanino": (22.0, "reverb_small"),
	"quintal": (38.0, ""),
}
NO_CEILING: set[str] = {"quintal"}

# Mesa com vão de 0,6 m: tampo em 0,60..0,65 m; pernas nos cantos (passagem livre de 0,7 m entre pernas).
TABLE_X: float = 3.0
TABLE_Z: float = -3.5
TABLE_TOP_Y: float = 0.6
TABLE_TOP_T: float = 0.05
TABLE_L: float = 1.4
TABLE_W: float = 1.0
TABLE_LEG: float = 0.1

PLAYER_SPAWN: tuple[float, float, float] = (3.0, 0.0, -1.0)

# Luzes: (nome, sala, posição, cor, energia, alcance em m, sombra)
LIGHTS: list[tuple[str, str, tuple[float, float, float], tuple[float, float, float], float, float, bool]] = [
	("Lamp_sala", "sala", (1.5, 2.6, -4.5), (0.91, 0.72, 0.48), 1.6, 8.0, True),
	("Lamp_cozinha", "cozinha", (10.0, 2.6, -4.2), (0.50, 0.58, 0.66), 1.3, 7.0, True),
	("Lamp_corredor", "corredor", (10.0, 2.5, -0.7), (0.91, 0.72, 0.48), 0.6, 4.0, False),
	("Lamp_hall", "hall", (16.0, 2.6, -1.2), (0.91, 0.72, 0.48), 1.5, 8.0, True),
	("Lamp_quintal", "quintal", (22.0, 2.4, -3.0), (0.91, 0.72, 0.48), 0.8, 6.0, False),
	("Accent_sob_mezanino", "mezanino", (15.0, 0.8, -4.5), (0.50, 0.58, 0.66), 0.5, 3.0, False),
]

FOG_DENSITY: float = 0.03
FOG_ALBEDO: tuple[float, float, float] = (0.55, 0.57, 0.62)


def f(value: float) -> str:
	text: str = ("%.4f" % value).rstrip("0").rstrip(".")
	if text in ("", "-0"):
		return "0"
	return text


def vec(x: float, y: float, z: float) -> str:
	return "Vector3(%s, %s, %s)" % (f(x), f(y), f(z))


def color(rgb: tuple[float, float, float]) -> str:
	return "Color(%s, %s, %s, 1)" % (f(rgb[0]), f(rgb[1]), f(rgb[2]))


def sname(text: str) -> str:
	return "&\"%s\"" % text


class Scene:
	def __init__(self) -> None:
		self.ext: list[tuple[str, str, str]] = []
		self.subs: list[str] = []
		self.nodes: list[str] = []
		self._ids: int = 0
		self._node_paths: set[str] = set()

	def _new_id(self, prefix: str) -> str:
		self._ids += 1
		return "%s_%d" % (prefix, self._ids)

	def ext_res(self, res_type: str, path: str) -> str:
		for kind, existing_path, existing_id in self.ext:
			if existing_path == path and kind == res_type:
				return existing_id
		res_id: str = self._new_id("ext")
		self.ext.append((res_type, path, res_id))
		return res_id

	def sub_res(self, res_type: str, props: list[str]) -> str:
		res_id: str = self._new_id(res_type)
		lines: list[str] = ["[sub_resource type=\"%s\" id=\"%s\"]" % (res_type, res_id)]
		lines.extend(props)
		self.subs.append("\n".join(lines))
		return res_id

	def node(self, name: str, node_type: str, parent: str, props: list[str] | None = None,
			groups: list[str] | None = None, instance_ext: str | None = None) -> str:
		"""parent é o caminho relativo à raiz; '' = filho direto da raiz ("Sandbox").
		Devolve o caminho relativo do próprio nó, para servir de parent dos filhos."""
		full: str = (parent + "/" + name) if parent else name
		if full in self._node_paths:
			raise ValueError("nó duplicado: " + full)
		self._node_paths.add(full)
		if name == "Sandbox":
			header: str = "[node name=\"Sandbox\" type=\"Node3D\"]"
		else:
			parent_attr: str = "." if parent == "" else parent
			if instance_ext is not None:
				header = "[node name=\"%s\" parent=\"%s\" instance=ExtResource(\"%s\")]" % (name, parent_attr, instance_ext)
			else:
				header = "[node name=\"%s\" type=\"%s\" parent=\"%s\"" % (name, node_type, parent_attr)
				if groups:
					header += " groups=[%s]" % ", ".join("\"%s\"" % g for g in groups)
				header += "]"
		lines: list[str] = [header]
		lines.extend(props or [])
		self.nodes.append("\n".join(lines))
		return full

	def text(self) -> str:
		load_steps: int = len(self.ext) + len(self.subs) + 1
		parts: list[str] = ["[gd_scene load_steps=%d format=3]" % load_steps, ""]
		for kind, path, res_id in self.ext:
			parts.append("[ext_resource type=\"%s\" path=\"%s\" id=\"%s\"]" % (kind, path, res_id))
		parts.append("")
		for sub in self.subs:
			parts.append(sub)
			parts.append("")
		for node_text in self.nodes:
			parts.append(node_text)
			parts.append("")
		return "\n".join(parts).rstrip("\n") + "\n"


def static_box(scene: Scene, parent: str, name: str, center: tuple[float, float, float], size: tuple[float, float, float],
		mat_key: str | None, surface: str | None = None) -> None:
	"""StaticBody3D na camada 1 com colisor de caixa e malha de caixa. surface vai para o metadado do corpo."""
	props: list[str] = ["position = %s" % vec(*center)]
	if surface is not None:
		props.append("metadata/surface = %s" % sname(surface))
	body: str = scene.node(name, "StaticBody3D", parent, props)
	shape_id: str = scene.sub_res("BoxShape3D", ["size = %s" % vec(*size)])
	scene.node("Collision", "CollisionShape3D", body, ["shape = SubResource(\"%s\")" % shape_id])
	mesh_id: str = scene.sub_res("BoxMesh", ["size = %s" % vec(*size)])
	mesh_props: list[str] = ["mesh = SubResource(\"%s\")" % mesh_id]
	if mat_key is not None:
		mat_id: str = scene.ext_res("Material", MAT_PATHS[mat_key])
		mesh_props.append("material_override = ExtResource(\"%s\")" % mat_id)
	scene.node("Mesh", "MeshInstance3D", body, mesh_props)


def wall_segments(a: float, b: float, open_center: float | None, ext_a: bool, ext_b: bool) -> list[tuple[float, float]]:
	"""Intervalos [início, fim] de uma parede de a até b, com um vão de DOOR_W em open_center (se houver).
	As pontas externas recebem meia espessura de extensão para fechar os cantos."""
	start: float = a - (WALL_T / 2 if ext_a else 0.0)
	end: float = b + (WALL_T / 2 if ext_b else 0.0)
	if open_center is None:
		return [(start, end)]
	half: float = DOOR_W / 2
	return [(start, open_center - half), (open_center + half, end)]


def wall_v(scene: Scene, parent: str, name: str, x: float, z0: float, z1: float, door_id: str | None = None,
		ext0: bool = True, ext1: bool = True) -> None:
	"""Parede em x = const, de z0 a z1 (z0 < z1). Com door_id, abre o vão e põe a verga."""
	open_center: float | None = OPENING_CENTER[door_id] if door_id is not None else None
	for index, (start, end) in enumerate(wall_segments(z0, z1, open_center, ext0, ext1)):
		static_box(scene, parent, "%s_%d" % (name, index), (x, WALL_H / 2, (start + end) / 2),
			(WALL_T, WALL_H, end - start), "plaster")
	if open_center is not None:
		static_box(scene, parent, name + "_verga", (x, (DOOR_H + WALL_H) / 2, open_center),
			(WALL_T, WALL_H - DOOR_H, DOOR_W), "plaster")


def wall_h(scene: Scene, parent: str, name: str, z: float, x0: float, x1: float, door_id: str | None = None,
		ext0: bool = True, ext1: bool = True) -> None:
	"""Parede em z = const, de x0 a x1 (x0 < x1). Com door_id, abre o vão e põe a verga."""
	open_center: float | None = OPENING_CENTER[door_id] if door_id is not None else None
	for index, (start, end) in enumerate(wall_segments(x0, x1, open_center, ext0, ext1)):
		static_box(scene, parent, "%s_%d" % (name, index), ((start + end) / 2, WALL_H / 2, z),
			(end - start, WALL_H, WALL_T), "plaster")
	if open_center is not None:
		static_box(scene, parent, name + "_verga", (open_center, (DOOR_H + WALL_H) / 2, z),
			(DOOR_W, WALL_H - DOOR_H, WALL_T), "plaster")


def build_geometry(scene: Scene) -> None:
	scene.node("Geometry", "Node3D", "")
	scene.node("Floors", "Node3D", "Geometry")
	for room_id, (x0, x1, z0, z1, surface) in ROOMS.items():
		static_box(scene, "Geometry/Floors", "Floor_" + room_id, ((x0 + x1) / 2, -0.5, (z0 + z1) / 2),
			(x1 - x0, 1.0, z1 - z0), surface, surface)

	scene.node("Walls", "Node3D", "Geometry")
	wall_h(scene, "Geometry/Walls", "Wall_norte", -6.0, 0.0, 24.0)
	wall_h(scene, "Geometry/Walls", "Wall_sul", 0.0, 0.0, 24.0)
	wall_v(scene, "Geometry/Walls", "Wall_oeste", 0.0, -6.0, 0.0)
	wall_v(scene, "Geometry/Walls", "Div_hall_quintal", 20.0, -6.0, 0.0, "door_hall_quintal")
	wall_v(scene, "Geometry/Walls", "Wall_quintal_leste", 24.0, -6.0, 0.0)
	wall_v(scene, "Geometry/Walls", "Div_sala_cozinha", 6.0, -6.0, -1.4, "door_sala_cozinha")
	wall_v(scene, "Geometry/Walls", "Div_sala_corredor", 6.0, -1.4, 0.0, "door_sala_corredor")
	wall_h(scene, "Geometry/Walls", "Div_cozinha_corredor", -1.4, 6.0, 14.0, "door_cozinha_corredor")
	wall_v(scene, "Geometry/Walls", "Div_cozinha_hall", 14.0, -6.0, -1.4)
	wall_v(scene, "Geometry/Walls", "Div_corredor_hall", 14.0, -1.4, 0.0, "door_corredor_hall")

	scene.node("Ceilings", "Node3D", "Geometry")
	for room_id, (x0, x1, z0, z1, _surface) in ROOMS.items():
		if room_id in NO_CEILING:
			continue
		static_box(scene, "Geometry/Ceilings", "Ceil_" + room_id, ((x0 + x1) / 2, CEIL_Y, (z0 + z1) / 2),
			(x1 - x0, CEIL_T, z1 - z0), "plaster")

	scene.node("Furniture", "Node3D", "Geometry")
	static_box(scene, "Geometry/Furniture", "Mesa_tampo", (TABLE_X, TABLE_TOP_Y + TABLE_TOP_T / 2, TABLE_Z),
		(TABLE_W, TABLE_TOP_T, TABLE_L), "wood")
	leg_x: float = TABLE_W / 2 - TABLE_LEG / 2 - 0.05
	leg_z: float = TABLE_L / 2 - TABLE_LEG / 2 - 0.05
	for index, (sx, sz) in enumerate([(-1, -1), (1, -1), (-1, 1), (1, 1)]):
		static_box(scene, "Geometry/Furniture", "Mesa_perna_%d" % (index + 1),
			(TABLE_X + sx * leg_x, TABLE_TOP_Y / 2, TABLE_Z + sz * leg_z),
			(TABLE_LEG, TABLE_TOP_Y, TABLE_LEG), "wood")

	scene.node("Stairs", "Node3D", "Geometry")
	for index in range(STAIR_STEPS):
		near_z: float = STAIR_NEAR_Z - STAIR_TREAD * index
		far_z: float = near_z - STAIR_TREAD
		top: float = STAIR_RISE * (index + 1)
		static_box(scene, "Geometry/Stairs", "Degrau_%02d" % (index + 1),
			(STAIR_X, top / 2, (near_z + far_z) / 2), (STAIR_W, top, STAIR_TREAD), "carpet", "carpet")

	scene.node("Mezzanine", "Node3D", "Geometry")
	static_box(scene, "Geometry/Mezzanine", "Mezanino_laje",
		(17.0, MEZZ_TOP - MEZZ_SLAB_T / 2, (MEZZ_Z0 + MEZZ_Z1) / 2), (6.0, MEZZ_SLAB_T, MEZZ_Z1 - MEZZ_Z0),
		"carpet", "carpet")
	for index, pz in enumerate([-4.4, -5.6]):
		static_box(scene, "Geometry/Mezzanine", "Mezanino_pilar_%d" % (index + 1),
			(19.5, (MEZZ_TOP - MEZZ_SLAB_T) / 2, pz), (0.2, MEZZ_TOP - MEZZ_SLAB_T, 0.2), "plaster")
	static_box(scene, "Geometry/Mezzanine", "Mezanino_guarda_1", (15.2, MEZZ_TOP + 0.5, MEZZ_Z1), (2.4, 1.0, 0.08), "plaster")
	static_box(scene, "Geometry/Mezzanine", "Mezanino_guarda_2", (18.8, MEZZ_TOP + 0.5, MEZZ_Z1), (2.4, 1.0, 0.08), "plaster")


def build_lights(scene: Scene) -> None:
	scene.node("Lights", "Node3D", "")
	for name, _room, pos, rgb, energy, rng, shadow in LIGHTS:
		props: list[str] = [
			"position = %s" % vec(*pos),
			"light_color = %s" % color(rgb),
			"light_energy = %s" % f(energy),
			"omni_range = %s" % f(rng),
			"shadow_enabled = %s" % ("true" if shadow else "false"),
		]
		scene.node(name, "OmniLight3D", "Lights", props)


def build_fog(scene: Scene) -> None:
	"""Névoa por sala (FogVolume), nunca global: a densidade global do ambiente fica em zero."""
	scene.node("Fog", "Node3D", "")
	for room_id, (x0, x1, z0, z1, _surface) in ROOMS.items():
		mat_id: str = scene.sub_res("FogMaterial", ["density = %s" % f(FOG_DENSITY), "albedo = %s" % color(FOG_ALBEDO)])
		props: list[str] = [
			"position = %s" % vec((x0 + x1) / 2, WALL_H / 2, (z0 + z1) / 2),
			"shape = 3",
			"size = %s" % vec(x1 - x0, WALL_H, z1 - z0),
			"material = SubResource(\"%s\")" % mat_id,
		]
		scene.node("Fog_" + room_id, "FogVolume", "Fog", props)


def build_rooms(scene: Scene) -> None:
	"""RoomVolume (components/acoustics/room_volume.gd): volume piso a teto de cada sala, com piso de ruído e reverb."""
	script_id: str = scene.ext_res("Script", "res://components/acoustics/room_volume.gd")
	scene.node("RoomVolumes", "Node3D", "")
	for room_id, (x0, x1, z0, z1, _surface) in ROOMS.items():
		floor_db, reverb = ROOM_ACOUSTICS[room_id]
		props: list[str] = [
			"position = %s" % vec((x0 + x1) / 2, WALL_H / 2, (z0 + z1) / 2),
			"collision_layer = 128",
			"collision_mask = 4",
			"script = ExtResource(\"%s\")" % script_id,
			"room_id = %s" % sname(room_id),
			"ambient_floor_db = %s" % f(floor_db),
			"reverb_bus = %s" % sname(reverb),
		]
		area: str = scene.node("RoomVolume_" + room_id, "Area3D", "RoomVolumes", props, ["room_volume"])
		shape_id: str = scene.sub_res("BoxShape3D", ["size = %s" % vec(x1 - x0, WALL_H, z1 - z0)])
		scene.node("Shape", "CollisionShape3D", area, ["shape = SubResource(\"%s\")" % shape_id])


def build_markers(scene: Scene) -> None:
	"""door_slot (Openings), portal (Portals; door aponta para o nó da porta dentro do slot, criada pelo LevelSlots
	com nome = door_id), pickup_slot e throwable_slot."""
	portal_script: str = scene.ext_res("Script", "res://components/acoustics/portal.gd")
	scene.node("Openings", "Node3D", "")
	scene.node("Portals", "Node3D", "")
	for opening in OPENINGS:
		door_id: str = str(opening["door_id"])
		axis: str = str(opening["axis"])
		fixed: float = float(opening["fixed"])  # type: ignore[arg-type]
		center: float = float(opening["center"])  # type: ignore[arg-type]
		if axis == "x":
			pos: tuple[float, float, float] = (fixed, DOOR_H / 2, center)
			rot_y: float = 0.0
		else:
			pos = (center, DOOR_H / 2, fixed)
			rot_y = 90.0
		# door_slot: local +Z aponta ao longo da parede (direção da largura do vão).
		door_props: list[str] = [
			"position = %s" % vec(*pos),
			"rotation_degrees = %s" % vec(0.0, rot_y, 0.0),
			"metadata/door_id = %s" % sname(door_id),
			"metadata/start_state = %s" % sname(str(opening["state"])),
			"metadata/opening_width_m = %s" % f(DOOR_W),
		]
		scene.node("DoorSlot_" + door_id, "Marker3D", "Openings", door_props, ["door_slot"])
		portal_id: str = "portal_" + door_id[len("door_"):]
		portal_props: list[str] = [
			"position = %s" % vec(*pos),
			"script = ExtResource(\"%s\")" % portal_script,
			"portal_id = %s" % sname(portal_id),
			"room_a = %s" % sname(str(opening["room_a"])),
			"room_b = %s" % sname(str(opening["room_b"])),
			"door = NodePath(\"../../Openings/DoorSlot_%s/%s\")" % (door_id, door_id),
		]
		scene.node("Portal_" + portal_id, "Node3D", "Portals", portal_props, ["portal"])
	# Vão físico sem porta entre o hall (térreo) e o mezanino: portal aberto (sem door).
	scene.node("Portal_portal_hall_mezanino", "Node3D", "Portals", [
		"position = %s" % vec(17.0, 1.2, MEZZ_Z1),
		"script = ExtResource(\"%s\")" % portal_script,
		"portal_id = &\"portal_hall_mezanino\"",
		"room_a = &\"hall\"",
		"room_b = &\"mezanino\"",
	], ["portal"])
	scene.node("Pickups", "Node3D", "")
	pickups: list[tuple[str, str, str, tuple[float, float, float]]] = [
		("PickupSlot_kitchen_inhaler", "pickup_inhaler_kitchen", "inhaler", (12.5, 0.05, -4.6)),
		("PickupSlot_hall_water", "pickup_water_hall", "water", (19.0, MEZZ_TOP + 0.05, -4.5)),
	]
	for node_name, persist_id, item_id, pos in pickups:
		props: list[str] = [
			"position = %s" % vec(*pos),
			"metadata/persist_id = %s" % sname(persist_id),
			"metadata/item_id = %s" % sname(item_id),
		]
		scene.node(node_name, "Marker3D", "Pickups", props, ["pickup_slot"])
	# Objetos arremessáveis (F3-004 instancia). size: light / medium / heavy.
	scene.node("Throwables", "Node3D", "")
	throwables: list[tuple[str, str, str, tuple[float, float, float]]] = [
		("ThrowableSlot_chair_sala", "throwable_chair_sala", "medium", (1.2, 0.1, -4.8)),
		("ThrowableSlot_bottle_cozinha", "throwable_bottle_cozinha", "light", (9.0, 0.1, -4.8)),
		("ThrowableSlot_pot_cozinha", "throwable_pot_cozinha", "medium", (12.6, 0.1, -2.6)),
		("ThrowableSlot_stool_hall", "throwable_stool_hall", "light", (15.2, 0.1, -1.6)),
		("ThrowableSlot_crate_quintal", "throwable_crate_quintal", "heavy", (22.0, 0.1, -4.5)),
	]
	for node_name, throwable_id, size, pos in throwables:
		props: list[str] = [
			"position = %s" % vec(*pos),
			"metadata/throwable_id = %s" % sname(throwable_id),
			"metadata/size = %s" % sname(size),
		]
		scene.node(node_name, "Marker3D", "Throwables", props, ["throwable_slot"])


def build_player(scene: Scene) -> None:
	scene.node("PlayerSpawn", "Marker3D", "", ["position = %s" % vec(*PLAYER_SPAWN)])
	player_ext: str = scene.ext_res("PackedScene", "res://components/player/player.tscn")
	scene.node("Player", "", "", ["position = %s" % vec(*PLAYER_SPAWN)], None, player_ext)


def build_environment(scene: Scene) -> None:
	env_id: str = scene.sub_res("Environment", [
		"background_mode = 1",
		"background_color = Color(0.0549, 0.0549, 0.0706, 1)",
		"ambient_light_source = 2",
		"ambient_light_color = Color(0.05, 0.05, 0.07, 1)",
		"ambient_light_energy = 0.3",
		"tonemap_mode = 3",
		"ssao_enabled = true",
		"volumetric_fog_enabled = true",
		"volumetric_fog_density = 0.0",
		"volumetric_fog_albedo = %s" % color(FOG_ALBEDO),
	])
	scene.node("World", "WorldEnvironment", "", ["environment = SubResource(\"%s\")" % env_id])


def build() -> str:
	scene: Scene = Scene()
	scene.node("Sandbox", "Node3D", "")
	build_environment(scene)
	build_geometry(scene)
	build_lights(scene)
	build_fog(scene)
	build_rooms(scene)
	build_markers(scene)
	build_player(scene)
	return scene.text()


def main() -> int:
	text: str = build()
	os.makedirs(os.path.dirname(OUT_PATH), exist_ok=True)
	with open(OUT_PATH, "w", encoding="utf-8", newline="\n") as handle:
		handle.write(text)
	print("escrito: " + OUT_PATH + " (%d bytes)" % len(text.encode("utf-8")))
	return 0


if __name__ == "__main__":
	sys.exit(main())

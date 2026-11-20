extends RefCounted
## Fixture da propriedade do passo em escada (BUG-001, BUG-002, F1-010 R1-01/R1-02). Cada fase roda num mundo
## de física PRÓPRIO (SubViewport com own_world_3d = true), descartado ao fim da fase, para não haver histórico
## entre fases. Escadas sintéticas são montadas por código; a escada da sandbox vem de content/levels/sandbox.tscn.
## Pasta "fixtures": não é descoberta pelo runner. Autor: Gameplay Engineer.

const WorldScript := preload("res://tests/integration/player/fixtures/player_world.gd")
const SANDBOX_PATH: String = "res://content/levels/sandbox.tscn"

## Passo da propriedade (5 mm): cobre o ciclo do passo com resolução que o revisor pediu.
const PHASE_STEP_M: float = 0.005
const RISE_M: float = 0.18
const FIRST_NEAR_Z: float = -1.0
const SYNTHETIC_STEPS: int = 8
const SYNTHETIC_WIDTH: float = 2.4
const PLATFORM_LEN_M: float = 2.0
const SANDBOX_X: float = 17.0
const SANDBOX_STEPS: int = 6
const SANDBOX_TREAD_M: float = 0.28
## Distância do início da subida até o primeiro espelho, na fase s = 0 (a fase desloca esse ponto).
const APPROACH_M: float = 0.5
const DESCENT_MARGIN_M: float = 0.5
const TOP_TOLERANCE_M: float = 0.02
const FLOOR_Y_M: float = 0.1
const MAX_FRAMES: int = 600
const SETTLE_FRAMES: int = 3
## Espera no patamar antes da descida natural (igual ao experimento do revisor).
const PLATFORM_WAIT_FRAMES: int = 40


## Escada sintética ao longo de -Z, em x = 0. Devolve { "x", "top", "platform_start", "tread" }.
static func build_synthetic(root: Node3D, tread: float) -> Dictionary:
	WorldScript.add_box(root, Vector3(0.0, -0.5, -6.0), Vector3(SYNTHETIC_WIDTH, 1.0, 16.0), &"wood")
	for index: int in SYNTHETIC_STEPS:
		var top: float = RISE_M * float(index + 1)
		var near_z: float = FIRST_NEAR_Z - tread * float(index)
		var center_z: float = near_z - tread * 0.5
		WorldScript.add_box(root, Vector3(0.0, (top - 1.0) * 0.5, center_z), Vector3(SYNTHETIC_WIDTH, top + 1.0, tread), &"wood")
	var top_all: float = RISE_M * float(SYNTHETIC_STEPS)
	var platform_start: float = FIRST_NEAR_Z - tread * float(SYNTHETIC_STEPS)
	WorldScript.add_box(root, Vector3(0.0, (top_all - 1.0) * 0.5, platform_start - PLATFORM_LEN_M * 0.5),
		Vector3(SYNTHETIC_WIDTH, top_all + 1.0, PLATFORM_LEN_M), &"wood")
	return {"x": 0.0, "top": top_all, "platform_start": platform_start, "tread": tread}


## Geometria da escada da sandbox (ver tools/level/gen_sandbox.py: STAIR_X, STAIR_NEAR_Z, STAIR_TREAD).
static func sandbox_geometry() -> Dictionary:
	var top_all: float = RISE_M * float(SANDBOX_STEPS)
	var platform_start: float = FIRST_NEAR_Z - SANDBOX_TREAD_M * float(SANDBOX_STEPS)
	return {"x": SANDBOX_X, "top": top_all, "platform_start": platform_start, "tread": SANDBOX_TREAD_M}


## Mundo de física isolado para uma fase. A viewport precisa estar na árvore para o mundo ficar ativo.
static func new_isolated_viewport(parent: Node) -> SubViewport:
	var viewport: SubViewport = SubViewport.new()
	viewport.own_world_3d = true
	viewport.size = Vector2i(64, 64)
	parent.add_child(viewport)
	return viewport


static func discard_viewport(viewport: SubViewport) -> void:
	var parent: Node = viewport.get_parent()
	if parent != null:
		parent.remove_child(viewport)
	viewport.free()


## Posição de partida da subida na fase s (metros, deslocamento a partir de APPROACH_M).
static func up_start_z(geometry: Dictionary, phase_m: float) -> float:
	return FIRST_NEAR_Z + APPROACH_M - phase_m


## Posição de partida da descida na fase s: sobre o patamar, deslocada da borda pela mesma fase.
static func down_start_z(geometry: Dictionary, phase_m: float) -> float:
	return float(geometry["platform_start"]) - DESCENT_MARGIN_M - phase_m

extends Node
## Harness da medição de desempenho F4-007 (SYSTEM_ARCHITECTURE §13). Carrega a sandbox_ia (cena principal), com 1 ou 3
## inimigos, e mede o tempo de script por quadro entre pares de marcadores (perf_bracket.gd):
##   total_fisica  : todos os _physics_process do jogo (prioridade −1000 a +1000)
##   jogador       : PlayerRoot (−90): motor, fisiologia, respiração, interação, monitor de ameaça
##   acustica      : AcousticWorld (−60): resolução da fila (propagação a jogador e sensores, áudio, legendas)
##   inimigos      : EnemyController (−40): sensores, cérebro, navegação
##   captura       : EnemyCaptureArea (−30)
##   total_processo: todos os _process do jogo
## No fim, microbenchmarks: propagação de um NoiseEvent a todos os ouvintes, LightExposureProbe e fisiologia.
## Headless: os monitores de tempo do Godot devolvem 0, por isso os marcadores. Mede CPU de script, não GPU.
## Ferramenta (tests/perf/ não é nível do runner). Uso: tools/perf/run_perf.ps1.

const SCENE_PATH: String = "res://content/levels/sandbox_ia.tscn"
const OBSERVER_PATH: String = "res://content/enemies/observer.tscn"
const BRACKET_SCRIPT: String = "res://tests/perf/perf_bracket.gd"
const PHYSICS_BUCKETS: Dictionary = {
	"total_fisica": [-1000, 1000], "jogador": [-91, -89], "acustica": [-61, -59],
	"inimigos": [-41, -39], "captura": [-31, -29],
}
const EXTRA_ENEMIES: Array = [
	{"id": &"observer_b", "seed": 2, "position": Vector3(16.0, 0.0, -0.5)},
	{"id": &"observer_c", "seed": 3, "position": Vector3(9.5, 0.0, -3.5)},
]

var enemies: int = 1
var run_index: int = 1
var warmup_frames: int = 120
var measure_frames: int = 600

var _scene: Node = null
var _starts: Dictionary = {}
var _samples: Dictionary = {}
var _frame: int = 0
var _states: Dictionary = {}
var _done: bool = false


func _ready() -> void:
	_scene = (load(SCENE_PATH) as PackedScene).instantiate()
	get_tree().root.add_child.call_deferred(_scene)
	call_deferred("_setup")


func _setup() -> void:
	var screen: Node = _scene.get_node_or_null("CaptureScreen")
	if screen != null:
		screen.set("restart_callable", Callable(self, "_no_restart"))
	for index: int in range(enemies - 1):
		var spec: Dictionary = EXTRA_ENEMIES[index]
		var extra: EnemyController = (load(OBSERVER_PATH) as PackedScene).instantiate() as EnemyController
		extra.enemy_id = spec["id"]
		extra.brain_seed = int(spec["seed"])
		extra.position = spec["position"]
		_scene.add_child(extra)
	var bracket_script: GDScript = load(BRACKET_SCRIPT) as GDScript
	for bucket: String in PHYSICS_BUCKETS.keys():
		var priorities: Array = PHYSICS_BUCKETS[bucket]
		_add_bracket(bracket_script, bucket, true, false, int(priorities[0]))
		_add_bracket(bracket_script, bucket, false, false, int(priorities[1]))
	_add_bracket(bracket_script, "total_processo", true, true, -1000)
	_add_bracket(bracket_script, "total_processo", false, true, 1000)


func _add_bracket(script: GDScript, bucket: String, is_start: bool, use_process: bool, priority: int) -> void:
	var node: Node = script.new() as Node
	node.set("bucket", bucket)
	node.set("is_start", is_start)
	node.set("use_process", use_process)
	node.set("harness", self)
	if use_process:
		node.process_priority = priority
	else:
		node.process_physics_priority = priority
	add_child(node)


func _no_restart() -> void:
	pass


func mark(bucket: String, is_start: bool) -> void:
	if _done:
		return
	var now: int = Time.get_ticks_usec()
	if is_start:
		_starts[bucket] = now
		return
	if not _starts.has(bucket):
		return
	if _frame >= warmup_frames:
		if not _samples.has(bucket):
			_samples[bucket] = PackedFloat64Array()
		var list: PackedFloat64Array = _samples[bucket]
		list.append(float(now - int(_starts[bucket])) / 1000.0)
		_samples[bucket] = list
	if bucket == "total_fisica":
		_frame += 1
		_count_state()
		if _frame >= warmup_frames + measure_frames:
			_done = true
			call_deferred("_finish")


func _count_state() -> void:
	if _frame < warmup_frames:
		return
	for node: Node in get_tree().get_nodes_in_group(&"enemy"):
		var enemy: EnemyController = node as EnemyController
		if enemy != null and enemy.enemy_id == &"observer":
			var key: int = int(enemy.get_state())
			_states[key] = int(_states.get(key, 0)) + 1


func _finish() -> void:
	for bucket: String in ["total_fisica", "jogador", "acustica", "inimigos", "captura", "total_processo"]:
		var list: PackedFloat64Array = _samples.get(bucket, PackedFloat64Array())
		print("PERF run=%d inimigos=%d bucket=%s %s" % [run_index, enemies, bucket, _stats(list)])
	print("PERF run=%d inimigos=%d estados_observer=%s" % [run_index, enemies, JSON.stringify(_states)])
	_micro_propagation()
	_micro_probe()
	_micro_physiology()
	get_tree().quit(0)


func _stats(list: PackedFloat64Array) -> String:
	if list.is_empty():
		return "n=0"
	var sorted: Array = Array(list)
	sorted.sort()
	var total: float = 0.0
	for value: float in sorted:
		total += value
	var p95: float = float(sorted[mini(sorted.size() - 1, int(ceil(0.95 * sorted.size())) - 1)])
	return "n=%d media_ms=%.4f p95_ms=%.4f max_ms=%.4f" % [sorted.size(), total / sorted.size(), p95, float(sorted.back())]


## Propagação de um NoiseEvent a TODOS os ouvintes (jogador, sensores dos inimigos, áudio, legendas): 5 lotes de 100.
func _micro_propagation() -> void:
	var world: AcousticWorld = _scene.get_node("AcousticWorld") as AcousticWorld
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 404
	var per_event: PackedFloat64Array = PackedFloat64Array()
	for batch: int in range(5):
		for index: int in range(100):
			var at: Vector3 = Vector3(rng.randf_range(0.5, 23.5), 0.2, rng.randf_range(-5.5, -0.5))
			world.emit_noise(NoiseEvent.create(Enums.NoiseCategory.FOOTSTEP, at, 45.0, 0.0, &"perf_fonte", &"footstep_concrete"))
		var start: int = Time.get_ticks_usec()
		world.flush()
		per_event.append(float(Time.get_ticks_usec() - start) / 1000.0 / 100.0)
	print("PERF run=%d inimigos=%d micro=propagacao_por_evento %s" % [run_index, enemies, _stats(per_event)])


func _micro_probe() -> void:
	var player: PlayerRoot = get_tree().get_first_node_in_group(&"player") as PlayerRoot
	var probes: Array = []
	if player != null and player.get_light_probe() != null:
		probes.append(["jogador", player.get_light_probe()])
	var observer: Node = _scene.get_node_or_null("Observer")
	if observer != null and observer.get_node_or_null("LightExposureProbe") != null:
		probes.append(["observer", observer.get_node("LightExposureProbe")])
	for pair: Array in probes:
		var probe: LightExposureProbe = pair[1] as LightExposureProbe
		var times: PackedFloat64Array = PackedFloat64Array()
		for index: int in range(300):
			var start: int = Time.get_ticks_usec()
			probe.sample_now()
			times.append(float(Time.get_ticks_usec() - start) / 1000.0)
		print("PERF run=%d inimigos=%d micro=sonda_%s %s" % [run_index, enemies, pair[0], _stats(times)])


func _micro_physiology() -> void:
	var player: PlayerRoot = get_tree().get_first_node_in_group(&"player") as PlayerRoot
	if player == null:
		return
	var physiology: PhysiologyComponent = player.get_physiology()
	var inputs: PhysiologyInputs = PhysiologyInputs.new()
	var times: PackedFloat64Array = PackedFloat64Array()
	for index: int in range(1000):
		var start: int = Time.get_ticks_usec()
		physiology.step(1.0 / 60.0, inputs)
		times.append(float(Time.get_ticks_usec() - start) / 1000.0)
	print("PERF run=%d inimigos=%d micro=fisiologia_tick %s" % [run_index, enemies, _stats(times)])

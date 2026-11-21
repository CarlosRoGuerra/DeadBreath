extends TestCase
## F2-006b (COMPONENT_CONTRACTS §6.2 e §6.4): AcousticWorld mínimo da F2.
## Grupo "acoustic_world", fila resolvida no tick de prioridade -60, sinal noise_resolved_for_player em toda
## emissão, propagação por distância até o ouvido do jogador. Invariantes medidas na F2:
## NOI-INV-1 (o único caminho para emitir é AcousticWorld.emit_noise, com varredura do código) e
## NOI-INV-3 (propagação pura e determinística).
## Autor: Audio Engineer (F2-006b).

const TOL: float = 0.0001
## F3-002: NoiseEmitter (COMPONENT_CONTRACTS §6.3) é o emissor das fontes do mundo; cria o NoiseEvent e o entrega
## ao AcousticWorld, que é o único caminho para a IA (NOI-INV-1).
const ALLOWED_EMITTER_FILES: Array[String] = [
	"res://components/player/breath_emitter.gd",
	"res://components/acoustics/acoustic_world.gd",
	"res://components/acoustics/noise_emitter.gd",
]
## A fábrica NoiseEvent.create usa NoiseEvent.new() por dentro (revisão F3-010, R3-02).
const EVENT_FACTORY_FILE: String = "res://sim/acoustics/noise_event.gd"
const ALLOWED_EVENT_CREATORS: Array[String] = [
	"res://components/player/breath_emitter.gd",
	"res://components/acoustics/noise_emitter.gd",
]

var _world: AcousticWorld = null
var _ear: Node3D = null
var _seen: Array[NoiseEvent] = []
var _results: Array[PropagationResult] = []


func before_each() -> void:
	_seen = []
	_results = []
	_world = AcousticWorld.new()
	add_child_autofree(_world)
	_ear = Node3D.new()
	add_child_autofree(_ear)
	_world.set_player_ear(_ear)
	_world.noise_resolved_for_player.connect(_collect)


func after_each() -> void:
	if _world.noise_resolved_for_player.is_connected(_collect):
		_world.noise_resolved_for_player.disconnect(_collect)


func _collect(event: NoiseEvent, result: PropagationResult) -> void:
	_seen.append(event)
	_results.append(result)


func _event(intensity_db: float, at: Vector3) -> NoiseEvent:
	return NoiseEvent.create(Enums.NoiseCategory.BREATHING, at, intensity_db, 1.0, &"player", &"breath_calm")


func test_world_is_in_group_with_physics_priority_minus_60() -> void:
	assert_true(_world.is_in_group(AcousticWorld.GROUP), "grupo acoustic_world")
	assert_eq(_world.process_physics_priority, -60, "fila processada na prioridade -60 (§6.2)")


func test_event_is_resolved_on_the_physics_tick_not_on_emit() -> void:
	_ear.global_position = Vector3(0.0, 0.0, 10.0)
	_world.emit_noise(_event(40.0, Vector3.ZERO))
	assert_eq(_seen.size(), 0, "emit_noise só enfileira")
	assert_eq(_world.pending_count(), 1, "um evento na fila")
	await wait_physics_frames(2)
	assert_eq(_seen.size(), 1, "resolvido no tick de física")
	assert_eq(_world.pending_count(), 0, "fila vazia depois do tick")


func test_resolution_uses_listener_distance() -> void:
	_ear.global_position = Vector3(0.0, 0.0, 10.0)
	_world.emit_noise(_event(40.0, Vector3.ZERO))
	_world.advance(0.0)
	assert_eq(_results.size(), 1, "um resultado")
	if _results.size() == 1:
		assert_almost_eq(_results[0].perceived_db, 19.0, TOL, "40 dB a 10 m = 19 dB")


func test_ids_and_timestamps_are_assigned_in_order() -> void:
	_world.emit_noise(_event(30.0, Vector3.ZERO))
	_world.advance(0.5)
	_world.emit_noise(_event(30.0, Vector3.ZERO))
	_world.advance(0.25)
	assert_eq(_seen.size(), 2, "dois eventos")
	if _seen.size() == 2:
		assert_eq(_seen[0].id, 1, "primeiro id")
		assert_eq(_seen[1].id, 2, "segundo id")
		assert_almost_eq(_seen[0].timestamp, 0.0, TOL, "primeiro no relógio zero")
		assert_almost_eq(_seen[1].timestamp, 0.5, TOL, "segundo no relógio 0,5 s")


func test_every_event_is_reported_in_emission_order() -> void:
	for i in range(5):
		var event: NoiseEvent = _event(20.0 + i, Vector3.ZERO)
		_world.emit_noise(event)
	_world.advance(0.0)
	assert_eq(_seen.size(), 5, "todo evento é resolvido")
	for i in range(_seen.size()):
		assert_almost_eq(_seen[i].intensity_db, 20.0 + i, TOL, "ordem de emissão preservada")


func test_propagation_is_deterministic_and_farther_is_quieter() -> void:
	# NOI-INV-3: mesmo evento e mesmo ouvinte dão o mesmo resultado; mais longe nunca soa mais alto.
	var event: NoiseEvent = _event(35.0, Vector3.ZERO)
	var previous: float = INF
	for d: float in [1.0, 2.0, 4.0, 8.0, 16.0]:
		_ear.global_position = Vector3(0.0, 0.0, d)
		var first: PropagationResult = AcousticPropagation.perceive(event, _ear.global_position)
		var second: PropagationResult = AcousticPropagation.perceive(event, _ear.global_position)
		assert_almost_eq(first.perceived_db, second.perceived_db, TOL, "determinístico a %.0f m" % d)
		assert_true(first.perceived_db < previous, "mais longe (%.0f m) soa menos" % d)
		previous = first.perceived_db


func test_noi_inv_1_only_listed_scripts_emit_or_create_body_noise() -> void:
	# NOI-INV-1 (na F2): o som do corpo só nasce no BreathEmitter e só chega à IA por AcousticWorld.emit_noise.
	# Varre o código de game/ (sem testes) à procura de chamadas e criações fora da lista.
	# Director, integração da F3-004: fontes do mundo (porta, arremessável, passos e queda do jogador) emitem pelo
	# NoiseEmitter (§6.3), o caminho autorizado. Fora da lista, emit_noise só vale com receptor declarado como
	# NoiseEmitter; qualquer outro receptor (o AcousticWorld direto, um get_node(...), uma variável sem tipo) viola.
	var violations: PackedStringArray = PackedStringArray()
	var scanned: int = 0
	for path: String in SourceScan.list_gd_files("res://"):
		if path.begins_with("res://tests/"):
			continue
		scanned += 1
		var code: String = SourceScan.code_of(SourceScan.read(path), true)
		if not ALLOWED_EMITTER_FILES.has(path):
			for receiver: String in _emit_noise_receivers(code):
				if not _declared_as_noise_emitter(code, receiver):
					violations.append("%s chama emit_noise em '%s' (fora da lista, só em NoiseEmitter)" % [path, receiver])
		if not SourceScan.find_all(code, "NoiseEvent\\.create\\(").is_empty() and not ALLOWED_EVENT_CREATORS.has(path):
			violations.append("%s cria NoiseEvent" % path)
		# Revisão F3-010, R3-02: formas indiretas. NoiseEvent.new() fora dos criadores; "emit_noise" como texto
		# (call, callv, Callable) fora da lista de emissores.
		if not SourceScan.find_all(code, "NoiseEvent\\.new\\(").is_empty() and not ALLOWED_EVENT_CREATORS.has(path) \
				and path != EVENT_FACTORY_FILE:
			violations.append("%s cria NoiseEvent com new()" % path)
		var with_strings: String = SourceScan.code_of(SourceScan.read(path), false)
		if not SourceScan.find_all(with_strings, "[\"']emit_noise[\"']").is_empty() and not ALLOWED_EMITTER_FILES.has(path):
			violations.append("%s cita \"emit_noise\" como texto (chamada indireta)" % path)
	note("arquivos de game/ varridos (sem testes): %d" % scanned)
	assert_eq(violations.size(), 0, "violações de NOI-INV-1: " + "; ".join(violations))


## Receptor de cada chamada ".emit_noise(" (identificador logo antes do ponto; vazio se for outra expressão).
func _emit_noise_receivers(code: String) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	var regex: RegEx = RegEx.new()
	regex.compile("(\\w*)\\s*\\.emit_noise\\(")
	for found: RegExMatch in regex.search_all(code):
		out.append(found.get_string(1))
	return out


func _declared_as_noise_emitter(code: String, receiver: String) -> bool:
	if receiver.is_empty():
		return false
	var regex: RegEx = RegEx.new()
	regex.compile("var\\s+" + receiver + "\\s*:\\s*NoiseEmitter\\b")
	return regex.search(code) != null

extends TestCase
## Revisão F3-010, R3-02 (NOI-05, COMPONENT_CONTRACTS §6.3): o NoiseEmitter recusa categoria corporal de fonte que não
## seja inimiga. O som do corpo do jogador só nasce no BreathEmitter; respiração e tosse de inimigos (F4) passam.
## Autor: Director (correção da revisão).

var _errors: Array[String] = []


func _on_logged(log_level: int, category: StringName, message: String) -> void:
	if log_level == Log.ERROR and category == &"acoustics":
		_errors.append(message)


func _emitter(root: Node3D, source: StringName) -> NoiseEmitter:
	var emitter: NoiseEmitter = NoiseEmitter.new()
	emitter.source_id = source
	root.add_child(emitter)
	return emitter


func test_porta_e_jogador_nao_emitem_som_do_corpo_pelo_noise_emitter() -> void:
	var root: Node3D = add_child_autofree(Node3D.new()) as Node3D
	var world: AcousticWorld = AcousticWorld.new()
	root.add_child(world)
	_errors.clear()
	Log.message_logged.connect(_on_logged)
	for source: StringName in [&"door_test", &"player", &"throwable_test"]:
		var emitter: NoiseEmitter = _emitter(root, source)
		for category: Enums.NoiseCategory in [Enums.NoiseCategory.BREATHING, Enums.NoiseCategory.WHEEZING,
				Enums.NoiseCategory.COUGHING, Enums.NoiseCategory.MEDICATION]:
			emitter.emit_noise(category, 60.0, 0.0, &"cough")
	Log.message_logged.disconnect(_on_logged)
	assert_eq(world.pending_count(), 0, "nenhum som do corpo enfileirado por fonte não inimiga")
	assert_eq(_errors.size(), 12, "um Log.error por recusa (3 fontes × 4 categorias)")


func test_som_do_mundo_e_corpo_de_inimigo_passam() -> void:
	var root: Node3D = add_child_autofree(Node3D.new()) as Node3D
	var world: AcousticWorld = AcousticWorld.new()
	root.add_child(world)
	_emitter(root, &"door_test").emit_noise(Enums.NoiseCategory.DOOR, 50.0, 0.0, &"door_normal")
	assert_eq(world.pending_count(), 1, "porta emite DOOR")
	_emitter(root, &"enemy_01").emit_noise(Enums.NoiseCategory.COUGHING, 65.0, 0.0, &"cough")
	assert_eq(world.pending_count(), 2, "inimigo pode emitir tosse (F4)")

class_name NoiseEmitter
extends Node3D
## NoiseEmitter (L2, COMPONENT_CONTRACTS §6.3; F3-002): emissor de som de fontes do mundo (portas, objetos, fala de
## inimigos). Cria o NoiseEvent na posição global do nó e o entrega ao AcousticWorld do nível. Continua sendo caminho
## único para o som chegar à IA (NOI-INV-1): nada chama o HearingSensor diretamente. Sem AcousticWorld: Log.warn uma vez.

const LOG_CATEGORY: StringName = &"acoustics"

@export var source_id: StringName = &""

var _warned_no_world: bool = false


## Emite um som da fonte deste nó. A sala do evento é preenchida pelo AcousticWorld (room_at).
func emit_noise(category: Enums.NoiseCategory, intensity_db: float, duration: float = 0.0,
		sound_id: StringName = &"") -> void:
	var world: AcousticWorld = _find_world()
	if world == null:
		_warn_no_world()
		return
	var event: NoiseEvent = NoiseEvent.create(category, global_position, intensity_db, duration, source_id, sound_id)
	world.emit_noise(event)


## O AcousticWorld mais próximo na árvore: o que é irmão de um ancestral deste nó.
func _find_world() -> AcousticWorld:
	if not is_inside_tree():
		return null
	var fallback: AcousticWorld = null
	for node: Node in get_tree().get_nodes_in_group(AcousticWorld.GROUP):
		var world: AcousticWorld = node as AcousticWorld
		if world == null:
			continue
		if fallback == null:
			fallback = world
		var scope: Node = world.get_parent() if world.get_parent() != null else world
		if scope.is_ancestor_of(self):
			return world
	return fallback


func _warn_no_world() -> void:
	if _warned_no_world:
		return
	_warned_no_world = true
	Log.warn(LOG_CATEGORY, "NoiseEmitter '%s' sem AcousticWorld no nível; o som não é emitido" % [name])

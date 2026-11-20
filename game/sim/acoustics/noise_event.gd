class_name NoiseEvent
extends RefCounted
## NoiseEvent (L1, DATA_STRUCTURES §2): um som de gameplay. Sai do emissor e entra no AcousticWorld,
## que é o único caminho para a IA (NOI-INV-1). O id e o timestamp são preenchidos por AcousticWorld.emit_noise.

var id: int = 0
var category: Enums.NoiseCategory = Enums.NoiseCategory.BREATHING
var position: Vector3 = Vector3.ZERO
var room_id: StringName = &""
## Nível a 1 m da fonte.
var intensity_db: float = 0.0
var duration: float = 0.0
var source_id: StringName = &""
## Identifica o arquivo de áudio (ex.: breath_calm, gasp). A apresentação escolhe a variação.
var sound_id: StringName = &""
var timestamp: float = 0.0


static func create(category_value: Enums.NoiseCategory, at: Vector3, level_db: float, length_s: float,
		source: StringName, sound: StringName) -> NoiseEvent:
	var event: NoiseEvent = NoiseEvent.new()
	event.category = category_value
	event.position = at
	event.intensity_db = level_db
	event.duration = length_s
	event.source_id = source
	event.sound_id = sound
	return event

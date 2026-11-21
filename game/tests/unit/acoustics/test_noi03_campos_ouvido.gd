extends TestCase
## NOI-03 (TEST_PLAN §2.3; NOI-INV-4; DATA_STRUCTURES §2): HeardNoise e PlayerHeardNoise têm exatamente os campos
## permitidos, com os tipos da §2. Sem posição real, id nem sala da fonte. Reflexão sobre as propriedades de script
## (usage PROPERTY_USAGE_SCRIPT_VARIABLE). Autor: AI Engineer (F3-001).

const FORBIDDEN_SOURCE_FIELDS: Array = [
	"position", "source_position", "source_id", "source", "room_id", "room", "id", "source_room",
]


## Campos de script como "nome:tipo", ordenados.
func _script_fields(instance: Object) -> PackedStringArray:
	var fields: PackedStringArray = PackedStringArray()
	var properties: Array = instance.get_property_list()
	for prop: Dictionary in properties:
		if (int(prop.get("usage", 0)) & PROPERTY_USAGE_SCRIPT_VARIABLE) != 0:
			fields.append("%s:%s" % [prop.get("name"), type_string(int(prop.get("type", 0)))])
	fields.sort()
	return fields


func _sorted(items: PackedStringArray) -> PackedStringArray:
	var copy: PackedStringArray = items.duplicate()
	copy.sort()
	return copy


func test_heard_noise_tem_exatamente_os_campos_permitidos() -> void:
	var fields: PackedStringArray = _script_fields(HeardNoise.new())
	var expected: PackedStringArray = _sorted(PackedStringArray([
		"category:int", "perceived_db:float", "estimated_position:Vector3", "confidence:float", "timestamp:float",
	]))
	assert_eq(fields, expected, "HeardNoise: campos e tipos de DATA §2")
	for name: String in FORBIDDEN_SOURCE_FIELDS:
		for field: String in fields:
			assert_false(field.begins_with(name + ":"), "HeardNoise não pode ter o campo '%s' (NOI-INV-4)" % [name])


func test_player_heard_noise_tem_exatamente_os_campos_permitidos() -> void:
	var fields: PackedStringArray = _script_fields(PlayerHeardNoise.new())
	var expected: PackedStringArray = _sorted(PackedStringArray([
		"category:int", "perceived_db:float", "source_is_enemy:bool", "sound_id:StringName", "timestamp:float",
	]))
	assert_eq(fields, expected, "PlayerHeardNoise: campos e tipos de DATA §2")
	for name: String in FORBIDDEN_SOURCE_FIELDS:
		for field: String in fields:
			assert_false(field.begins_with(name + ":"),
				"PlayerHeardNoise não pode ter o campo '%s' (NOI-INV-4)" % [name])


func test_campos_sao_os_unicos_com_variavel_de_script() -> void:
	# Garante que a varredura por reflexão não deixou de fora nenhuma variável de script.
	assert_eq(_script_fields(HeardNoise.new()).size(), 5, "HeardNoise: 5 campos")
	assert_eq(_script_fields(PlayerHeardNoise.new()).size(), 5, "PlayerHeardNoise: 5 campos")

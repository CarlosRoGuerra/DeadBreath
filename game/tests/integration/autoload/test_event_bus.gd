extends TestCase
## Integration: autoload EventBus contra o catálogo de COMPONENT_CONTRACTS §16.
## Autor: Software Architect (F1-004).

## Nome do sinal -> tipos dos argumentos, na ordem do contrato.
const EXPECTED: Dictionary = {
	"player_captured": [TYPE_STRING_NAME],
	"checkpoint_reached": [TYPE_STRING_NAME],
	"objective_updated": [TYPE_STRING_NAME, TYPE_INT],
	"item_picked": [TYPE_STRING_NAME, TYPE_INT, TYPE_STRING_NAME],
	"chapter_changed": [TYPE_STRING_NAME],
	"chase_started": [TYPE_STRING_NAME],
	"chase_ended": [TYPE_STRING_NAME],
	"subtitle_requested": [TYPE_STRING_NAME, TYPE_FLOAT],
}


func _declared_signals() -> Dictionary:
	var out: Dictionary = {}
	var script: Script = EventBus.get_script()
	for sig: Dictionary in script.get_script_signal_list():
		var types: Array = []
		for arg: Dictionary in sig["args"]:
			types.append(int(arg["type"]))
		out[String(sig["name"])] = types
	return out


func test_catalog_matches_contract() -> void:
	var declared: Dictionary = _declared_signals()
	assert_eq(declared.size(), EXPECTED.size(), "quantidade de sinais")
	for signal_name: String in EXPECTED.keys():
		assert_true(declared.has(signal_name), "sinal ausente: " + signal_name)
		if declared.has(signal_name):
			assert_eq(declared[signal_name], EXPECTED[signal_name], "argumentos de " + signal_name)
	assert_eq(Array(EventBus.CATALOG), EXPECTED.keys(), "CATALOG na ordem do contrato")


func test_payloads_use_only_native_types() -> void:
	var declared: Dictionary = _declared_signals()
	for signal_name: String in declared.keys():
		for t: int in declared[signal_name]:
			assert_true(EventBus.ALLOWED_ARG_TYPES.has(t), "%s usa tipo não permitido: %s" % [signal_name, type_string(t)])


func test_emit_reaches_listener_with_payload() -> void:
	var got: Array = []
	var listener: Callable = func(item_id: StringName, quantity: int, persist_id: StringName) -> void:
		got.append([item_id, quantity, persist_id])
	EventBus.item_picked.connect(listener)
	EventBus.item_picked.emit(&"inhaler", 2, &"pickup_kitchen_01")
	EventBus.item_picked.disconnect(listener)
	assert_eq(got.size(), 1)
	if got.size() == 1:
		assert_eq(got[0], [&"inhaler", 2, &"pickup_kitchen_01"])


func test_enum_payload_round_trip() -> void:
	var got: Array[int] = []
	var listener: Callable = func(_objective_id: StringName, status: Enums.ObjectiveStatus) -> void:
		got.append(status)
	EventBus.objective_updated.connect(listener)
	EventBus.objective_updated.emit(&"find_keys", Enums.ObjectiveStatus.COMPLETED)
	EventBus.objective_updated.disconnect(listener)
	var expected: Array[int] = [Enums.ObjectiveStatus.COMPLETED]
	assert_eq(got, expected)

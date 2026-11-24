extends TestCase
## AI-PROFILE (F4-003; DATA_STRUCTURES §3.1 e §9): os 3 .tres batem com a tabela por reflexão.
## Esperado por perfil: valores da tabela; search_duration_multiplier = 1,0 (F6). Nomes de campo como DATA §9.
## Autor: AI Engineer (F4-003).

const OBSERVER_PATH: String = "res://content/data/ai/observer.tres"
const AGGRESSIVE_PATH: String = "res://content/data/ai/aggressive.tres"
const LEADER_PATH: String = "res://content/data/ai/leader.tres"

## Campos de AIProfile (DATA §9, mais search_duration_multiplier da F6). Conjunto exato.
const EXPORTED_FIELDS: Array[String] = [
	"sight_range_m", "fov_deg", "hearing_threshold_db", "masking_margin_db",
	"vision_suspicion_gain_per_s", "hearing_suspicion_per_db", "hearing_suspicion_cap_per_event",
	"suspicion_decay_per_s", "suspicious_threshold", "investigate_threshold",
	"visual_confirm_time_s", "min_visibility_for_confirm",
	"patrol_speed", "investigate_speed", "chase_speed",
	"lost_contact_pursuit_s", "search_duration_s", "search_duration_multiplier",
	"inspect_hideable_chance", "memory_confidence_decay_per_s",
	"squad_latency_s", "squad_obedience",
]


func _observer_table() -> Dictionary:
	return {
		"sight_range_m": 16.0, "fov_deg": 110.0, "hearing_threshold_db": 15.0, "masking_margin_db": -3.0,
		"vision_suspicion_gain_per_s": 1.6, "hearing_suspicion_per_db": 0.04, "hearing_suspicion_cap_per_event": 0.6,
		"suspicion_decay_per_s": 0.05, "suspicious_threshold": 0.25, "investigate_threshold": 0.5,
		"visual_confirm_time_s": 0.6, "min_visibility_for_confirm": 0.4,
		"patrol_speed": 1.2, "investigate_speed": 1.8, "chase_speed": 4.2,
		"lost_contact_pursuit_s": 6.0, "search_duration_s": 60.0, "search_duration_multiplier": 1.0,
		"inspect_hideable_chance": 0.6, "memory_confidence_decay_per_s": 0.02,
		"squad_latency_s": 1.5, "squad_obedience": 1.0,
	}


func _aggressive_table() -> Dictionary:
	return {
		"sight_range_m": 12.0, "fov_deg": 90.0, "hearing_threshold_db": 24.0, "masking_margin_db": 3.0,
		"vision_suspicion_gain_per_s": 1.0, "hearing_suspicion_per_db": 0.02, "hearing_suspicion_cap_per_event": 0.4,
		"suspicion_decay_per_s": 0.15, "suspicious_threshold": 0.25, "investigate_threshold": 0.5,
		"visual_confirm_time_s": 1.0, "min_visibility_for_confirm": 0.4,
		"patrol_speed": 1.5, "investigate_speed": 2.5, "chase_speed": 5.0,
		"lost_contact_pursuit_s": 12.0, "search_duration_s": 30.0, "search_duration_multiplier": 1.0,
		"inspect_hideable_chance": 0.3, "memory_confidence_decay_per_s": 0.05,
		"squad_latency_s": 1.5, "squad_obedience": 0.5,
	}


func _leader_table() -> Dictionary:
	return {
		"sight_range_m": 14.0, "fov_deg": 100.0, "hearing_threshold_db": 20.0, "masking_margin_db": 0.0,
		"vision_suspicion_gain_per_s": 1.3, "hearing_suspicion_per_db": 0.03, "hearing_suspicion_cap_per_event": 0.5,
		"suspicion_decay_per_s": 0.10, "suspicious_threshold": 0.25, "investigate_threshold": 0.5,
		"visual_confirm_time_s": 0.8, "min_visibility_for_confirm": 0.4,
		"patrol_speed": 1.3, "investigate_speed": 2.0, "chase_speed": 4.5,
		"lost_contact_pursuit_s": 8.0, "search_duration_s": 45.0, "search_duration_multiplier": 1.0,
		"inspect_hideable_chance": 0.45, "memory_confidence_decay_per_s": 0.03,
		"squad_latency_s": 1.0, "squad_obedience": 1.0,
	}


func _check_profile(path: String, table: Dictionary) -> void:
	var profile: AIProfile = ResourceLoader.load(path) as AIProfile
	assert_not_null(profile, "carrega %s como AIProfile" % path)
	if profile == null:
		return
	for key: String in table.keys():
		var actual: Variant = profile.get(key)
		assert_almost_eq(float(actual), float(table[key]), 0.000001, "%s: %s" % [path, key])


func test_observer_tres_bate_com_data_3_1() -> void:
	_check_profile(OBSERVER_PATH, _observer_table())


func test_aggressive_tres_bate_com_data_3_1() -> void:
	_check_profile(AGGRESSIVE_PATH, _aggressive_table())


func test_leader_tres_bate_com_data_3_1() -> void:
	_check_profile(LEADER_PATH, _leader_table())


func test_ai_profile_tem_exatamente_os_campos_de_data_9() -> void:
	var names: PackedStringArray = PackedStringArray()
	var probe: AIProfile = AIProfile.new()
	for prop: Dictionary in probe.get_property_list():
		if (int(prop.get("usage", 0)) & PROPERTY_USAGE_SCRIPT_VARIABLE) != 0:
			names.append(str(prop.get("name")))
	names.sort()
	var expected: PackedStringArray = PackedStringArray(EXPORTED_FIELDS)
	expected.sort()
	assert_eq(names, expected, "AIProfile: campos exportados (DATA §9 + search_duration_multiplier)")


func test_tres_tem_os_mesmos_campos_do_script() -> void:
	# Um .tres com campo sobrando ou faltando passaria despercebido pela tabela acima.
	var profile: AIProfile = ResourceLoader.load(LEADER_PATH) as AIProfile
	assert_not_null(profile, "leader.tres carrega")
	if profile == null:
		return
	var count: int = 0
	for prop: Dictionary in profile.get_property_list():
		if (int(prop.get("usage", 0)) & PROPERTY_USAGE_SCRIPT_VARIABLE) != 0:
			count += 1
	assert_eq(count, EXPORTED_FIELDS.size(), "leader.tres: número de campos exportados")

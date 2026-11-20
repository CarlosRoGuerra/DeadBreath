extends TestCase
## Meta-teste do ARC-03 (F1-010, R1-11): injeta cada dependência dinâmica proibida em um script de L1 e
## confere que L1Rules a pega; também confere os controles negativos (comentários, strings e acesso por
## colchetes não contam). A varredura real de sim/ passa a ter valor de prova com isso.

## [texto do script injetado, trecho que a violação precisa citar]
const POSITIVE_CASES: Array = [
	["extends RefCounted\n\nfunc f() -> void:\n\tvar r = Engine.get_main_loop()\n", "get_main_loop"],
	["extends RefCounted\n\nfunc f() -> void:\n\tvar c = ClassDB.get_class_list()\n", "ClassDB"],
	["extends RefCounted\n\nfunc f(o: Object) -> void:\n\to.call(\"get_tree\")\n", "call"],
	["extends RefCounted\n\nfunc f(o: Object) -> void:\n\to.callv(\"x\", [])\n", "callv"],
	["extends RefCounted\n\nfunc f(o: Object) -> void:\n\tvar v = o.get(\"root\")\n", "get com string"],
	["extends RefCounted\n\nfunc f() -> void:\n\tvar s = load(\"res://x.gd\")\n", "load"],
	["extends RefCounted\n\nconst P = preload(\"res://x.gd\")\n", "preload"],
	["extends RefCounted\n\nfunc f(n: Node) -> void:\n\tpass\n", "Node"],
	["extends RefCounted\n\nfunc f() -> void:\n\tvar n = $Hud\n", "$"],
	["extends RefCounted\n\nfunc f() -> void:\n\tget_tree().create_timer(1.0)\n", "get_tree"],
	["extends RefCounted\n\nfunc f() -> void:\n\tcall_deferred(\"x\")\n", "call_deferred"],
]

## Scripts que não contêm violação (controles negativos): nenhum achado é aceito.
const NEGATIVE_CASES: Array = [
	"extends RefCounted\n\n# Engine.get_main_loop(), ClassDB e call(\"x\") só em comentário\nvar a: int = 1\n",
	"extends RefCounted\n\nconst TEXTO := \"call(get_tree) e ClassDB e load(x)\"\n",
	"extends RefCounted\n\nfunc f(d: Dictionary) -> int:\n\treturn d[\"chave\"]\n",
	"extends RefCounted\n\nfunc f(x: float) -> float:\n\treturn x * 2.0\n",
]


func test_cada_dependencia_dinamica_e_pega() -> void:
	var missed: PackedStringArray = PackedStringArray()
	for case: Array in POSITIVE_CASES:
		var source: String = case[0]
		var token: String = case[1]
		var violations: PackedStringArray = L1Rules.scan("amostra", source, PackedStringArray())
		var found: bool = false
		for violation: String in violations:
			if violation.contains(token) or (token == "get com string" and violation.contains("get com string")):
				found = true
				break
		if not found:
			missed.append(token)
	assert_eq(missed.size(), 0, "violacoes injetadas que nao foram pegas: " + ", ".join(missed))


func test_controles_negativos_nao_geram_achado() -> void:
	var false_positives: PackedStringArray = PackedStringArray()
	for source: String in NEGATIVE_CASES:
		var violations: PackedStringArray = L1Rules.scan("controle", source, PackedStringArray())
		if not violations.is_empty():
			false_positives.append("; ".join(violations))
	assert_eq(false_positives.size(), 0, "falsos positivos: " + " | ".join(false_positives))


func test_autoload_injetado_e_pego() -> void:
	var violations: PackedStringArray = L1Rules.scan("amostra", "extends RefCounted\n\nvar x = EventBus\n", PackedStringArray(["EventBus"]))
	assert_eq(violations.size(), 1, "autoload EventBus usado em L1 deve ser pego")

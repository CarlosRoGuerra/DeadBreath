extends TestCase
## F2-008 (TASK_BOARD §4b): regras puras do painel de balanceamento. Faixa dos sliders, ameaça a partir dos
## sliders (mesma regra de DATA §1.5), destino de exportação (só user://balance) e padrões dentro das faixas.
## Unit: sem cena e sem jogador. Autor: Physiological Systems Engineer.

const TOLERANCE: float = 0.0001


func test_valor_do_slider_e_limitado_a_faixa() -> void:
	assert_almost_eq(BalancePanel.clamped_value("sprint_drain_per_s", 100.0), 24.0, TOLERANCE, "acima do máximo vira o máximo")
	assert_almost_eq(BalancePanel.clamped_value("sprint_drain_per_s", -5.0), 6.0, TOLERANCE, "abaixo do mínimo vira o mínimo")
	assert_almost_eq(BalancePanel.clamped_value("sprint_drain_per_s", 12.0), 12.0, TOLERANCE, "dentro da faixa não muda")
	assert_almost_eq(BalancePanel.clamped_value("id_que_nao_existe", 3.0), 3.0, TOLERANCE, "id desconhecido não é limitado")


func test_ameaca_vem_dos_sliders_pela_regra_de_data_1_5() -> void:
	var seen: ThreatSample = BalancePanel.threat_from(0.5, 0.8, false)
	assert_almost_eq(seen.seen_proximity, 0.5, TOLERANCE, "visto")
	assert_almost_eq(seen.heard_factor, 0.8, TOLERANCE, "ouvido")
	assert_almost_eq(seen.threat_level, 0.5, TOLERANCE, "nível = max(visto 0,5; 0,5 × ouvido 0,4) = 0,5")
	var heard: ThreatSample = BalancePanel.threat_from(0.1, 1.0, false)
	assert_almost_eq(heard.threat_level, 0.5, TOLERANCE, "ouvido 1,0 vale 0,5 no nível")
	var chase: ThreatSample = BalancePanel.threat_from(0.0, 0.0, true)
	assert_true(chase.in_chase, "perseguição ligada")
	assert_almost_eq(chase.threat_level, 1.0, TOLERANCE, "perseguição vale 1 no nível")
	var clamped: ThreatSample = BalancePanel.threat_from(3.0, -1.0, false)
	assert_almost_eq(clamped.seen_proximity, 1.0, TOLERANCE, "visto acima de 1 é limitado")
	assert_almost_eq(clamped.heard_factor, 0.0, TOLERANCE, "ouvido abaixo de 0 é limitado")


func test_exportacao_so_para_user_balance() -> void:
	assert_true(BalancePanel.is_export_dir_allowed("user://balance"), "a raiz user://balance é permitida")
	assert_true(BalancePanel.is_export_dir_allowed("user://balance/ensaio_1"), "subpasta de user://balance é permitida")
	assert_false(BalancePanel.is_export_dir_allowed("res://content/data/physiology"), "content/data nunca é destino")
	assert_false(BalancePanel.is_export_dir_allowed("res://content/data/physiology/"), "content/data com barra também não")
	assert_false(BalancePanel.is_export_dir_allowed("user://balance_outro"), "prefixo parecido não conta como subpasta")
	assert_false(BalancePanel.is_export_dir_allowed("user://balance/../settings"), "subida de pasta é recusada")
	assert_false(BalancePanel.is_export_dir_allowed("user://"), "a raiz do usuário é recusada")
	assert_false(BalancePanel.is_export_dir_allowed(""), "destino vazio é recusado")


func test_padroes_dos_tres_estao_dentro_das_faixas_e_as_propriedades_existem() -> void:
	var verified: int = 0
	for definition: Dictionary in BalancePanel.PARAMS:
		var group: String = String(definition["group"])
		var path: String = String(BalancePanel.CONFIG_PATHS[group])
		var fresh: Resource = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as Resource
		assert_not_null(fresh, "%s deve carregar" % path)
		if fresh == null:
			continue
		var prop: String = String(definition["prop"])
		var value: Variant = fresh.get(prop)
		assert_true(value is float, "%s.%s existe e é float" % [group, prop])
		if value is float:
			var number: float = float(value)
			assert_true(number >= float(definition["min"]) and number <= float(definition["max"]),
				"padrão de %s (%.4f) dentro de [%.4f, %.4f]" % [prop, number, float(definition["min"]), float(definition["max"])])
			verified += 1
	assert_eq(verified, BalancePanel.PARAMS.size(), "todos os parâmetros da tabela foram conferidos")
	assert_true(BalancePanel.PARAMS.size() >= 10, "a tabela cobre os principais parâmetros das quatro configs")

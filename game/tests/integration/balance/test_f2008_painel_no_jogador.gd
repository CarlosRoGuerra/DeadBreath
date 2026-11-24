extends TestCase
## F2-008 (TASK_BOARD §4b): painel de balanceamento com um jogador real. Produção desliga tudo; o slider de ameaça
## altera o estresse; o parâmetro em memória altera o dreno do sprint e volta com "restaurar padrões"; a exportação
## recarrega os mesmos valores e não toca em content/data/; F4 (toggle) solta e recaptura o mouse.
## Os recursos de configuração são compartilhados pelo processo: cada teste restaura os padrões no fim.
## Autor: Physiological Systems Engineer.

const PlayerWorld := preload("res://tests/integration/player/fixtures/player_world.gd")
const SETTLE_FRAMES: int = 6
const SECOND_FRAMES: int = 60
const HALF_SECOND_FRAMES: int = 30
const TOLERANCE: float = 0.05
const STAMINA_CONFIG_PATH: String = "res://content/data/physiology/stamina_config.tres"

var _previous: Dictionary = {}
var _previous_production: bool = false
var _panel: BalancePanel = null


func before_all() -> void:
	Settings.autosave = false


func after_all() -> void:
	Settings.autosave = true


func before_each() -> void:
	_previous = PlayerWorld.override_settings({&"motion_reduction": 0.0, &"mouse_sensitivity": 0.12, &"invert_y": false, &"fov": 75.0})
	_previous_production = GameState.is_production_build
	GameState.is_production_build = false
	_panel = null


func after_each() -> void:
	if _panel != null and is_instance_valid(_panel):
		_panel.restore_defaults()
	GameState.is_production_build = _previous_production
	PlayerWorld.restore_settings(_previous)


func _world(root: Node3D) -> PlayerRoot:
	PlayerWorld.add_box(root, Vector3(0.0, -0.5, -10.0), Vector3(6.0, 1.0, 30.0), &"wood")
	return PlayerWorld.spawn_player(root, Vector3.ZERO)


func _panel_for(root: Node3D, player: PlayerRoot) -> BalancePanel:
	var panel: BalancePanel = BalancePanel.new()
	root.add_child(panel)
	panel.set_player(player)
	_panel = panel
	return panel


func test_producao_desliga_o_painel_e_recusa_tudo() -> void:
	GameState.is_production_build = true
	var root: Node3D = add_child_autofree(Node3D.new()) as Node3D
	var player: PlayerRoot = _world(root)
	var panel: BalancePanel = _panel_for(root, player)
	await wait_physics_frames(SETTLE_FRAMES)
	var config: StaminaConfig = ResourceLoader.load(STAMINA_CONFIG_PATH, "", ResourceLoader.CACHE_MODE_IGNORE) as StaminaConfig
	var before: float = player.get_physiology().stamina_config.sprint_drain_per_s
	assert_false(panel.is_debug_enabled(), "em produção o painel não está habilitado")
	assert_false(panel.toggle_panel(), "F4 em produção não abre o painel")
	assert_false(panel.is_panel_open(), "o painel continua fechado")
	assert_false(panel.set_param("sprint_drain_per_s", 24.0), "parâmetro recusado em produção")
	assert_false(panel.set_threat("seen_proximity", 1.0), "ameaça recusada em produção")
	assert_false(panel.restore_defaults(), "restaurar recusado em produção")
	assert_eq(panel.export_configs("user://balance/producao_f2008").size(), 0, "exportação recusada em produção")
	assert_almost_eq(player.get_physiology().stamina_config.sprint_drain_per_s, before, 0.0001, "a config viva não mudou")
	assert_almost_eq(config.sprint_drain_per_s, 12.0, 0.0001, "o .tres de produção continua com 12")


func test_slider_de_ameaca_altera_o_estresse_efetivo() -> void:
	var root: Node3D = add_child_autofree(Node3D.new()) as Node3D
	var player: PlayerRoot = _world(root)
	var panel: BalancePanel = _panel_for(root, player)
	await wait_physics_frames(SETTLE_FRAMES)
	assert_true(player.get_threat_source() is MonitoredThreatSource, "a fonte padrão é a do PlayerThreatMonitor (F4-009)")
	assert_true(panel.set_threat("seen_proximity", 1.0), "o slider de inimigo visto aplica")
	var stub: StubThreatSource = player.get_threat_source() as StubThreatSource
	assert_not_null(stub, "aplicar a ameaça põe o StubThreatSource do painel no lugar do monitor")
	assert_almost_eq(stub.forced.seen_proximity, 1.0, 0.0001, "a amostra forçada recebeu o valor do slider")
	await wait_physics_frames(SECOND_FRAMES)
	var stress: float = player.get_physiology().get_snapshot().stress
	note("slider de inimigo visto em 1,0 por 1 s: estresse %.3f (ganho 15/s)" % stress)
	assert_almost_eq(stress, 15.0, 1.0, "o estresse sobe 15 em 1 s com o inimigo visto a 3 m")
	assert_true(panel.set_threat("seen_proximity", 0.0), "o slider volta a zero")
	assert_true(panel.set_threat("in_chase", 1.0), "a perseguição liga pelo interruptor")
	assert_true(stub.forced.in_chase, "a amostra forçada está em perseguição")
	assert_almost_eq(stub.forced.threat_level, 1.0, 0.0001, "perseguição vale 1 no nível")


## F4-009 + F2-008: a ameaça do painel é provisória. Restaurar padrões e fechar o painel devolvem a fonte que o jogador
## tinha antes (o MonitoredThreatSource do PlayerThreatMonitor), e não um stub.
func test_restaurar_e_fechar_devolvem_o_monitor() -> void:
	var root: Node3D = add_child_autofree(Node3D.new()) as Node3D
	var player: PlayerRoot = _world(root)
	var panel: BalancePanel = _panel_for(root, player)
	await wait_physics_frames(SETTLE_FRAMES)
	var monitor_source: ThreatSource = player.get_threat_source()
	panel.toggle_panel()
	assert_true(panel.set_threat("seen_proximity", 0.5), "o slider aplica com o painel aberto")
	assert_true(player.get_threat_source() is StubThreatSource, "o painel põe o stub no lugar do monitor")
	assert_true(panel.restore_defaults(), "restaurar padrões funciona com o debug ligado")
	assert_true(player.get_threat_source() == monitor_source, "restaurar devolve a fonte guardada")
	assert_true(player.get_threat_source() is MonitoredThreatSource, "a fonte devolvida é o MonitoredThreatSource")
	panel.set_threat("heard_factor", 0.3)
	assert_true(player.get_threat_source() is StubThreatSource, "um novo ajuste volta a usar o stub")
	panel.toggle_panel()
	assert_false(panel.is_panel_open(), "fechar o painel")
	assert_true(player.get_threat_source() == monitor_source, "fechar o painel devolve o MonitoredThreatSource")


func test_parametro_em_memoria_muda_o_dreno_do_sprint_e_volta_com_restaurar() -> void:
	var root: Node3D = add_child_autofree(Node3D.new()) as Node3D
	var player: PlayerRoot = _world(root)
	var panel: BalancePanel = _panel_for(root, player)
	await wait_physics_frames(SETTLE_FRAMES)
	var physiology: PhysiologyComponent = player.get_physiology()
	player.get_motor().set_scripted_input(PlayerWorld.move_input(Vector2(0.0, 1.0), true))
	var start: float = physiology.get_snapshot().stamina
	await wait_physics_frames(HALF_SECOND_FRAMES)
	var drop_default: float = start - physiology.get_snapshot().stamina
	assert_true(panel.set_param("sprint_drain_per_s", 24.0), "o parâmetro muda pelo painel")
	assert_almost_eq(physiology.stamina_config.sprint_drain_per_s, 24.0, 0.0001, "a config viva recebeu o valor")
	var mid: float = physiology.get_snapshot().stamina
	await wait_physics_frames(HALF_SECOND_FRAMES)
	var drop_changed: float = mid - physiology.get_snapshot().stamina
	player.get_motor().set_scripted_input(MotorInput.new())
	note("dreno do sprint em 0,5 s: padrão %.3f; com 24/s %.3f (proporção %.2f)"
		% [drop_default, drop_changed, drop_changed / maxf(drop_default, 0.0001)])
	assert_almost_eq(drop_changed / maxf(drop_default, 0.0001), 2.0, 0.1, "dobrar o dreno dobra a queda por tick")
	assert_true(panel.restore_defaults(), "restaurar padrões aceito")
	assert_almost_eq(physiology.stamina_config.sprint_drain_per_s, 12.0, 0.0001, "restaurar volta ao valor do .tres")
	assert_almost_eq(panel.get_param("sprint_drain_per_s"), 12.0, 0.0001, "o painel lê o valor restaurado")


func test_exportacao_recarrega_os_mesmos_valores_e_nao_toca_em_content_data() -> void:
	var root: Node3D = add_child_autofree(Node3D.new()) as Node3D
	var player: PlayerRoot = _world(root)
	var panel: BalancePanel = _panel_for(root, player)
	await wait_physics_frames(SETTLE_FRAMES)
	panel.set_param("rise_rate_per_s", 0.123)
	panel.set_param("sprint_drain_per_s", 18.5)
	var target: String = "user://balance/teste_f2008_%d" % Time.get_ticks_usec()
	var written: PackedStringArray = panel.export_configs(target)
	assert_eq(written.size(), 4, "exporta as quatro configs")
	if written.size() == 4:
		var respiratory: RespiratoryConfig = ResourceLoader.load(target.path_join("respiratory_config.tres"), "",
			ResourceLoader.CACHE_MODE_IGNORE) as RespiratoryConfig
		var stamina: StaminaConfig = ResourceLoader.load(target.path_join("stamina_config.tres"), "",
			ResourceLoader.CACHE_MODE_IGNORE) as StaminaConfig
		assert_not_null(respiratory, "o .tres exportado recarrega como RespiratoryConfig")
		assert_not_null(stamina, "o .tres exportado recarrega como StaminaConfig")
		if respiratory != null and stamina != null:
			assert_almost_eq(respiratory.rise_rate_per_s, 0.123, 0.0001, "subida recarregada")
			assert_almost_eq(stamina.sprint_drain_per_s, 18.5, 0.0001, "dreno recarregado")
			var mismatches: int = 0
			for definition: Dictionary in BalancePanel.PARAMS:
				var reloaded: float = _reloaded_value(target, definition)
				if absf(reloaded - panel.get_param(String(definition["id"]))) > 0.0001:
					mismatches += 1
			assert_eq(mismatches, 0, "todos os parâmetros recarregados batem com os valores vivos")
	var production_text: String = FileAccess.get_file_as_string(STAMINA_CONFIG_PATH)
	var refused: PackedStringArray = panel.export_configs("res://content/data/physiology")
	assert_eq(refused.size(), 0, "destino em content/data é recusado")
	assert_eq(FileAccess.get_file_as_string(STAMINA_CONFIG_PATH), production_text, "o .tres de produção não mudou")
	_clear_export_dir(target)
	panel.restore_defaults()


func test_f4_solta_e_recaptura_o_mouse() -> void:
	var root: Node3D = add_child_autofree(Node3D.new()) as Node3D
	var player: PlayerRoot = _world(root)
	var panel: BalancePanel = _panel_for(root, player)
	await wait_physics_frames(SETTLE_FRAMES)
	assert_true(panel.toggle_panel(), "F4 abre o painel fora de produção")
	assert_false(player.is_mouse_capture_requested(), "com o painel aberto o mouse fica livre")
	assert_false(panel.toggle_panel(), "F4 de novo fecha o painel")
	assert_true(player.is_mouse_capture_requested(), "ao fechar, o mouse volta a ser capturado")


func test_telemetria_mostra_estado_e_ameaca() -> void:
	var root: Node3D = add_child_autofree(Node3D.new()) as Node3D
	var player: PlayerRoot = _world(root)
	var panel: BalancePanel = _panel_for(root, player)
	await wait_physics_frames(SETTLE_FRAMES)
	var text: String = panel.telemetry_text()
	for word: String in ["estamina", "estresse", "severidade", "estado", "frequência", "risco de tosse", "regeneração", "ameaça"]:
		assert_true(text.contains(word), "a telemetria mostra '%s'" % word)


## Valor de um parâmetro no .tres exportado (lido sem cache).
func _reloaded_value(dir: String, definition: Dictionary) -> float:
	var group: String = String(definition["group"])
	var file: String = dir.path_join(group + "_config.tres")
	var loaded: Resource = ResourceLoader.load(file, "", ResourceLoader.CACHE_MODE_IGNORE) as Resource
	if loaded == null:
		return -1.0
	return float(loaded.get(String(definition["prop"])))


func _clear_export_dir(dir: String) -> void:
	var access: DirAccess = DirAccess.open(dir)
	if access == null:
		return
	access.list_dir_begin()
	var entry: String = access.get_next()
	while entry != "":
		if not access.current_is_dir():
			access.remove(entry)
		entry = access.get_next()
	access.list_dir_end()
	var parent: DirAccess = DirAccess.open(dir.get_base_dir())
	if parent != null:
		parent.remove(dir.get_file())

class_name BalancePanel
extends CanvasLayer
## Painel de balanceamento (L3, F2-008). Abre e fecha com F4 (tecla fixa de debug, como F3 no overlay).
## Mostra o estado fisiológico do jogador (estamina, estresse, faixa, severidade, estado, frequência, chiado,
## risco de tosse e acoplamento) e controla:
##   - a ameaça do StubThreatSource (visto, ouvido, perseguição), pelo PlayerRoot.get_threat_source();
##   - parâmetros das configs da fisiologia EM MEMÓRIA: são os recursos vivos que os modelos leem a cada tick,
##     então valem na hora. Os recursos são compartilhados pelo processo (ResourceCache), então a mudança vale
##     para todas as instâncias que os usam nesta sessão. "Restaurar padrões" volta aos valores dos .tres;
##   - exportação das configs ajustadas para .tres em user://balance/ (nunca em content/data/).
## Desligado em produção (GameState.is_production_build): não reage a F4, recusa mudanças e exportação.
## Só lê o jogador (grupo "player"). Não altera cenas, content/data/, nem o PlayerRoot além do mouse.

const TOGGLE_KEY: int = KEY_F4
const PANEL_LAYER: int = 101
const PANEL_POSITION: Vector2 = Vector2(560.0, 12.0)
const SLIDER_WIDTH: float = 220.0
const NAME_WIDTH: float = 220.0
const EXPORT_ROOT: String = "user://balance"
const EXPORT_SUFFIX: String = "_config.tres"
const STRESS_NAMES: PackedStringArray = ["calmo", "tenso", "assustado", "pânico"]
const HEARD_SCALE: float = 0.5
const CHASE_LEVEL: float = 1.0

## Caminho do .tres de cada grupo (valores de produção) e nome do arquivo exportado.
const CONFIG_PATHS: Dictionary = {
	"stamina": "res://content/data/physiology/stamina_config.tres",
	"stress": "res://content/data/physiology/stress_config.tres",
	"respiratory": "res://content/data/physiology/respiratory_config.tres",
	"coupling": "res://content/data/physiology/coupling_config.tres",
}
const CONFIG_GROUPS: PackedStringArray = ["stamina", "stress", "respiratory", "coupling"]

## Ameaça do StubThreatSource: id, rótulo, faixa e passo. in_chase é um interruptor (ver _build_ui).
const THREAT_PARAMS: Array = [
	{"id": "seen_proximity", "label": "inimigo visto (proximidade)", "min": 0.0, "max": 1.0, "step": 0.01},
	{"id": "heard_factor", "label": "inimigo ouvido (fator)", "min": 0.0, "max": 1.0, "step": 0.01},
]

## Parâmetros principais das configs: id, grupo, propriedade, rótulo, faixa e passo. Faixas contêm o padrão.
const PARAMS: Array = [
	{"id": "sprint_drain_per_s", "group": "stamina", "prop": "sprint_drain_per_s", "label": "dreno do sprint (/s)", "min": 6.0, "max": 24.0, "step": 0.5},
	{"id": "regen_walk_per_s", "group": "stamina", "prop": "regen_walk_per_s", "label": "regeneração andando (/s)", "min": 1.0, "max": 10.0, "step": 0.25},
	{"id": "regen_rest_per_s", "group": "stamina", "prop": "regen_rest_per_s", "label": "regeneração em repouso (/s)", "min": 4.0, "max": 30.0, "step": 0.5},
	{"id": "rise_rate_per_s", "group": "respiratory", "prop": "rise_rate_per_s", "label": "subida da severidade (/s)", "min": 0.02, "max": 0.2, "step": 0.005},
	{"id": "fall_rate_per_s", "group": "respiratory", "prop": "fall_rate_per_s", "label": "queda da severidade (/s)", "min": 0.01, "max": 0.1, "step": 0.005},
	{"id": "cough_warning_time_s", "group": "respiratory", "prop": "cough_warning_time_s", "label": "aviso antes da tosse (s)", "min": 0.5, "max": 3.0, "step": 0.1},
	{"id": "cough_cooldown_s", "group": "respiratory", "prop": "cough_cooldown_s", "label": "intervalo entre tosses (s)", "min": 1.0, "max": 10.0, "step": 0.5},
	{"id": "enemy_seen_gain_per_s", "group": "stress", "prop": "enemy_seen_gain_per_s", "label": "ganho do estresse, inimigo visto (/s)", "min": 5.0, "max": 30.0, "step": 0.5},
	{"id": "decay_delay_s", "group": "stress", "prop": "decay_delay_s", "label": "atraso até o estresse cair (s)", "min": 1.0, "max": 10.0, "step": 0.5},
	{"id": "decay_per_s", "group": "stress", "prop": "decay_per_s", "label": "queda do estresse (/s)", "min": 1.0, "max": 10.0, "step": 0.25},
	{"id": "regen_severity_penalty", "group": "coupling", "prop": "regen_severity_penalty", "label": "penalidade da severidade na regeneração", "min": 0.0, "max": 1.0, "step": 0.05},
	{"id": "sprint_limit_start_severity", "group": "coupling", "prop": "sprint_limit_start_severity", "label": "severidade em que o sprint é limitado", "min": 0.3, "max": 0.9, "step": 0.05},
]

var _player: PlayerRoot = null
var _root: PanelContainer = null
var _telemetry: Label = null
var _status: Label = null
var _export_status: Label = null
var _sliders: Dictionary = {}
var _value_labels: Dictionary = {}
var _chase_toggle: CheckButton = null
var _defaults: Dictionary = {}
var _threat_seen: float = 0.0
var _threat_heard: float = 0.0
var _threat_chase: bool = false


func _ready() -> void:
	layer = PANEL_LAYER
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	visible = false


## Verdadeiro fora de produção (mesma regra do overlay F3 e dos comandos de debug).
func is_debug_enabled() -> bool:
	return DebugCommands.is_allowed()


func is_panel_open() -> bool:
	return visible


## Injeção explícita (testes e cenas que já têm a referência). Sem injeção, o painel acha o jogador sozinho.
func set_player(player: PlayerRoot) -> void:
	_player = player


func get_player() -> PlayerRoot:
	if _player == null or not is_instance_valid(_player):
		_player = _find_player_in_group()
	return _player


func _find_player_in_group() -> PlayerRoot:
	if not is_inside_tree():
		return null
	return get_tree().get_first_node_in_group(PlayerRoot.PLAYER_GROUP) as PlayerRoot


## Abre ou fecha o painel. Em produção não abre e devolve false.
func toggle_panel() -> bool:
	if not is_debug_enabled():
		visible = false
		return false
	visible = not visible
	var player: PlayerRoot = get_player()
	if visible:
		_ensure_defaults()
		_sync_all_sliders()
		if player != null:
			player.set_mouse_captured(false)
	elif player != null:
		player.set_mouse_captured(true)
	return visible


## Valor de um parâmetro (chave de PARAMS) limitado à faixa. Sem alteração de estado.
static func clamped_value(id: String, value: float) -> float:
	var definition: Dictionary = _definition_of(id)
	if definition.is_empty():
		return value
	return clampf(value, float(definition["min"]), float(definition["max"]))


## Altera um parâmetro da config em memória, limitado à faixa. Falso em produção ou para id desconhecido.
func set_param(id: String, value: float) -> bool:
	var definition: Dictionary = _definition_of(id)
	if definition.is_empty() or not is_debug_enabled():
		return false
	var config: Resource = _live_config(String(definition["group"]))
	if config == null:
		return false
	var applied: float = clamped_value(id, value)
	config.set(String(definition["prop"]), applied)
	_sync_slider(id, applied)
	return true


## Valor atual de um parâmetro, lido da config viva. -1 se não há jogador.
func get_param(id: String) -> float:
	var definition: Dictionary = _definition_of(id)
	if definition.is_empty():
		return -1.0
	var config: Resource = _live_config(String(definition["group"]))
	if config == null:
		return -1.0
	return float(config.get(String(definition["prop"])))


## Altera a ameaça do stub: "seen_proximity", "heard_factor" (0..1) ou "in_chase" (valor >= 0,5 liga).
func set_threat(id: String, value: float) -> bool:
	if not is_debug_enabled():
		return false
	match id:
		"seen_proximity":
			_threat_seen = clampf(value, 0.0, 1.0)
		"heard_factor":
			_threat_heard = clampf(value, 0.0, 1.0)
		"in_chase":
			_threat_chase = value >= 0.5
		_:
			return false
	return _apply_threat()


## Amostra de ameaça para os valores do painel (mesma regra de DATA §1.5 que o ThreatSample usa).
static func threat_from(seen: float, heard: float, chase: bool) -> ThreatSample:
	var sample: ThreatSample = ThreatSample.new()
	sample.seen_proximity = clampf(seen, 0.0, 1.0)
	sample.heard_factor = clampf(heard, 0.0, 1.0)
	sample.in_chase = chase
	sample.threat_level = maxf(sample.seen_proximity, HEARD_SCALE * sample.heard_factor)
	if chase:
		sample.threat_level = maxf(sample.threat_level, CHASE_LEVEL)
	return sample


## Volta todos os parâmetros aos valores dos .tres de produção (lidos do disco, sem o cache).
func restore_defaults() -> bool:
	if not is_debug_enabled():
		return false
	_ensure_defaults()
	for definition: Dictionary in PARAMS:
		var id: String = String(definition["id"])
		if _defaults.has(id):
			set_param(id, float(_defaults[id]))
	return true


## Exporta as configs vivas (duplicadas) para .tres no diretório dado. Recusa destinos fora de user://balance
## e qualquer destino em produção. Devolve os caminhos gravados (vazio se recusou ou falhou).
func export_configs(dir_path: String) -> PackedStringArray:
	var written: PackedStringArray = PackedStringArray()
	if not is_debug_enabled() or not is_export_dir_allowed(dir_path):
		_set_export_status("exportação recusada: destino fora de %s ou modo de produção" % EXPORT_ROOT)
		return written
	if not DirAccess.dir_exists_absolute(dir_path):
		DirAccess.make_dir_recursive_absolute(dir_path)
	var failed: int = 0
	for group: String in CONFIG_GROUPS:
		var live: Resource = _live_config(group)
		if live == null:
			failed += 1
			continue
		var file: String = dir_path.path_join(group + EXPORT_SUFFIX)
		if ResourceSaver.save(live.duplicate(), file) == OK:
			written.append(file)
		else:
			failed += 1
	_set_export_status("exportado %d arquivo(s) em %s%s" % [written.size(), dir_path, "" if failed == 0 else " (falhas: %d)" % failed])
	return written


## Verdadeiro se o destino fica dentro de user://balance (sem subir de pasta).
static func is_export_dir_allowed(path: String) -> bool:
	if path == EXPORT_ROOT:
		return true
	if not path.begins_with(EXPORT_ROOT + "/"):
		return false
	return not path.contains("..")


## Texto do painel: estado fisiológico e ameaça atual. Usado pelo rótulo e pelos testes.
func telemetry_text() -> String:
	var physiology: PhysiologyComponent = _physiology()
	if physiology == null:
		return "balanceamento: sem jogador"
	var snapshot: PhysiologySnapshot = physiology.get_snapshot()
	var coupling: CouplingFactors = physiology.get_coupling()
	var lines: PackedStringArray = PackedStringArray()
	lines.append("estamina %.1f  |  sprint %s (máx x%.2f)" % [snapshot.stamina,
		"sim" if coupling.sprint_allowed else "não", coupling.max_sprint_multiplier])
	lines.append("estresse %.1f (%s)  |  tremor %.2f" % [snapshot.stress,
		STRESS_NAMES[int(snapshot.stress_band)], coupling.tremor_amplitude])
	lines.append("severidade %.3f  |  estado %s  |  recuperação %.2f" % [snapshot.symptom_severity,
		RespiratoryModel.state_name(snapshot.respiratory_state), snapshot.recovery_progress])
	lines.append("frequência %.1f irpm  |  chiado %.2f  |  risco de tosse %.3f/s" % [snapshot.breathing_rate,
		snapshot.wheezing_intensity, snapshot.cough_probability])
	lines.append("regeneração x%.2f  |  firmeza %.2f" % [coupling.stamina_regen_multiplier, coupling.steadiness])
	lines.append("ameaça: visto %.2f, ouvido %.2f, perseguição %s" % [_threat_seen, _threat_heard,
		"sim" if _threat_chase else "não"])
	return "\n".join(lines)


func _unhandled_input(event: InputEvent) -> void:
	var key: InputEventKey = event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	# Em produção o painel não existe para o jogador: F4 não é consumida (BUG-012, revisão F2-010 R2-13).
	if key.keycode == TOGGLE_KEY and is_debug_enabled():
		toggle_panel()
		get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	if visible and _telemetry != null:
		_telemetry.text = telemetry_text()


func _physiology() -> PhysiologyComponent:
	var player: PlayerRoot = get_player()
	if player == null:
		return null
	return player.get_physiology()


## Config viva de um grupo (o próprio recurso que os modelos leem).
func _live_config(group: String) -> Resource:
	var physiology: PhysiologyComponent = _physiology()
	if physiology == null:
		return null
	match group:
		"stamina":
			return physiology.stamina_config
		"stress":
			return physiology.get_stress_config()
		"respiratory":
			return physiology.respiratory_config
		"coupling":
			return physiology.coupling_config
	return null


## Lê os padrões dos .tres do disco (CACHE_MODE_IGNORE), uma vez por painel.
func _ensure_defaults() -> void:
	if not _defaults.is_empty():
		return
	for group: String in CONFIG_GROUPS:
		var fresh: Resource = ResourceLoader.load(String(CONFIG_PATHS[group]), "", ResourceLoader.CACHE_MODE_IGNORE) as Resource
		if fresh == null:
			continue
		for definition: Dictionary in PARAMS:
			if String(definition["group"]) == group:
				_defaults[String(definition["id"])] = float(fresh.get(String(definition["prop"])))


func _apply_threat() -> bool:
	var player: PlayerRoot = get_player()
	if player == null:
		_set_status("sem jogador: ameaça não aplicada")
		return false
	var stub: StubThreatSource = player.get_threat_source() as StubThreatSource
	if stub == null:
		_set_status("a fonte de ameaça não é o StubThreatSource: só leitura")
		return false
	stub.forced = threat_from(_threat_seen, _threat_heard, _threat_chase)
	return true


static func _definition_of(id: String) -> Dictionary:
	for definition: Dictionary in PARAMS:
		if String(definition["id"]) == id:
			return definition
	return {}


func _set_status(text: String) -> void:
	if _status != null:
		_status.text = text


func _set_export_status(text: String) -> void:
	if _export_status != null:
		_export_status.text = text


func _sync_slider(id: String, value: float) -> void:
	if _sliders.has(id):
		var slider: HSlider = _sliders[id] as HSlider
		slider.set_value_no_signal(value)
		_set_value_label(id, value)


func _set_value_label(id: String, value: float) -> void:
	if _value_labels.has(id):
		var label: Label = _value_labels[id] as Label
		label.text = "%.3f" % value


func _sync_all_sliders() -> void:
	for definition: Dictionary in PARAMS:
		var id: String = String(definition["id"])
		var live: float = get_param(id)
		if live >= 0.0:
			_sync_slider(id, live)
	for definition: Dictionary in THREAT_PARAMS:
		var id: String = String(definition["id"])
		_sync_slider(id, _threat_seen if id == "seen_proximity" else _threat_heard)
	if _chase_toggle != null:
		_chase_toggle.set_pressed_no_signal(_threat_chase)


func _build_ui() -> void:
	_root = PanelContainer.new()
	_root.position = PANEL_POSITION
	add_child(_root)
	var column: VBoxContainer = VBoxContainer.new()
	_root.add_child(column)
	_telemetry = Label.new()
	column.add_child(_telemetry)
	_status = Label.new()
	column.add_child(_status)
	column.add_child(_section_title("Ameaça (StubThreatSource)"))
	for definition: Dictionary in THREAT_PARAMS:
		column.add_child(_slider_row(definition, true))
	_chase_toggle = CheckButton.new()
	_chase_toggle.text = "perseguição ativa (in_chase)"
	_chase_toggle.toggled.connect(_on_chase_toggled)
	column.add_child(_chase_toggle)
	column.add_child(_section_title("Parâmetros em memória (padrão dos .tres)"))
	for definition: Dictionary in PARAMS:
		column.add_child(_slider_row(definition, false))
	var buttons: HBoxContainer = HBoxContainer.new()
	column.add_child(buttons)
	var restore: Button = Button.new()
	restore.text = "Restaurar padrões"
	restore.pressed.connect(restore_defaults)
	buttons.add_child(restore)
	var export_button: Button = Button.new()
	export_button.text = "Exportar .tres (user://balance)"
	export_button.pressed.connect(_on_export_pressed)
	buttons.add_child(export_button)
	_export_status = Label.new()
	column.add_child(_export_status)


func _section_title(text: String) -> Label:
	var label: Label = Label.new()
	label.text = text
	return label


func _slider_row(definition: Dictionary, is_threat: bool) -> HBoxContainer:
	var id: String = String(definition["id"])
	var row: HBoxContainer = HBoxContainer.new()
	var name_label: Label = Label.new()
	name_label.text = String(definition["label"])
	name_label.custom_minimum_size = Vector2(NAME_WIDTH, 0.0)
	row.add_child(name_label)
	var slider: HSlider = HSlider.new()
	slider.min_value = float(definition["min"])
	slider.max_value = float(definition["max"])
	slider.step = float(definition["step"])
	slider.custom_minimum_size = Vector2(SLIDER_WIDTH, 0.0)
	slider.value_changed.connect(_on_slider_changed.bind(id, is_threat))
	row.add_child(slider)
	var value_label: Label = Label.new()
	value_label.text = "0.000"
	row.add_child(value_label)
	_sliders[id] = slider
	_value_labels[id] = value_label
	return row


func _on_slider_changed(value: float, id: String, is_threat: bool) -> void:
	if is_threat:
		set_threat(id, value)
	else:
		set_param(id, value)
	_set_value_label(id, value)


func _on_chase_toggled(pressed: bool) -> void:
	set_threat("in_chase", 1.0 if pressed else 0.0)


func _on_export_pressed() -> void:
	export_configs(EXPORT_ROOT)

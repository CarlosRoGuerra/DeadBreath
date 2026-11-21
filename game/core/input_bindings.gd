class_name InputBindings
extends RefCounted
## Ligações de controle (L0, F1-013). Formato de Settings.input_bindings (DATA_STRUCTURES §10):
##   { "<acao>": [ {"type": "key", "physical_keycode": int} | {"type": "mouse_button", "button_index": int} ] }
## Só usa InputMap e eventos nativos. apply() sempre parte dos padrões do project.godot: as ligações
## do usuário são sobreposições. Ações "ui_*" não são remapeáveis pela tela de controles.

const TYPE_KEY: String = "key"
const TYPE_MOUSE: String = "mouse_button"
const UI_PREFIX: String = "ui_"
const MAX_MOUSE_BUTTON: int = 9

## Padrões do project.godot, capturados na primeira vez (antes de qualquer sobreposição). ação -> Array de dicts.
static var _defaults: Dictionary = {}
static var _captured: bool = false


## Captura as ligações padrão das ações do jogo. Idempotente; chamada pelo Settings antes de carregar o arquivo.
## As ações ui_* ficam fora de tudo isto: têm ligações por keycode (não physical_keycode) que o formato não
## representa, então nunca são lidas, gravadas nem reaplicadas.
static func capture_defaults() -> void:
	if _captured:
		return
	_captured = true
	_defaults = {}
	ensure_throw_action()
	for action: StringName in InputMap.get_actions():
		if not String(action).begins_with(UI_PREFIX):
			_defaults[String(action)] = _serialize_action(action)


## Ação "throw" (F3-004: arremessar objeto), com padrão botão esquerdo do mouse. Fica fora do project.godot de
## propósito: o arquivo de projeto não é deste escopo; a ação é criada aqui se ainda não existe. Idempotente.
const THROW_ACTION: StringName = &"throw"
const THROW_DEFAULT_BUTTON: int = MOUSE_BUTTON_LEFT

static func ensure_throw_action() -> void:
	if InputMap.has_action(THROW_ACTION):
		return
	InputMap.add_action(THROW_ACTION, 0.2)
	var button: InputEventMouseButton = InputEventMouseButton.new()
	button.button_index = THROW_DEFAULT_BUTTON
	InputMap.action_add_event(THROW_ACTION, button)


## Ações que o jogador pode remapear (sem ui_*), em ordem alfabética.
static func rebindable_actions() -> PackedStringArray:
	capture_defaults()
	var out: PackedStringArray = PackedStringArray()
	for key: String in _defaults.keys():
		if not key.begins_with(UI_PREFIX):
			out.append(key)
	out.sort()
	return out


## Aplica os padrões e depois as sobreposições. Sobreposição inválida ou de ação desconhecida (inclui ui_*)
## é ignorada com Log.warn.
static func apply(overrides: Dictionary) -> void:
	capture_defaults()
	for key: String in _defaults.keys():
		_set_action(StringName(key), _defaults[key] as Array)
	for raw_key: Variant in overrides.keys():
		var action: String = str(raw_key)
		if not _defaults.has(action):
			Log.warn(&"settings", "input_bindings: ação desconhecida '%s' ignorada" % action)
			continue
		var entries: Variant = overrides[raw_key]
		if not validate(entries):
			Log.warn(&"settings", "input_bindings: ligações inválidas para '%s' ignoradas" % action)
			continue
		_set_action(StringName(action), entries as Array)


## Sobreposições atuais: só as ações cuja ligação difere do padrão.
static func current_overrides() -> Dictionary:
	capture_defaults()
	var out: Dictionary = {}
	for key: String in _defaults.keys():
		var current: Array = _serialize_action(StringName(key))
		if not current.is_empty() and current != (_defaults[key] as Array):
			out[key] = current
	return out


## Ligações atuais de uma ação (já aplicadas no InputMap), serializadas.
static func action_entries(action: StringName) -> Array:
	return _serialize_action(action)


## Troca a ligação de uma ação por um único evento serializado (sem salvar; quem chama persiste).
## Devolve false, sem alterar nada, se o evento não for válido (R1-06).
static func rebind(action: StringName, entry: Dictionary) -> bool:
	if not is_valid_entry(entry):
		return false
	_set_action(action, [entry])
	return true


## True se entry é um evento serializado válido.
static func is_valid_entry(entry: Variant) -> bool:
	if typeof(entry) != TYPE_DICTIONARY:
		return false
	var dict: Dictionary = entry as Dictionary
	if dict.get("type") == TYPE_KEY:
		return typeof(dict.get("physical_keycode")) == TYPE_INT and int(dict["physical_keycode"]) > 0
	if dict.get("type") == TYPE_MOUSE:
		return typeof(dict.get("button_index")) == TYPE_INT \
			and int(dict["button_index"]) >= 1 and int(dict["button_index"]) <= MAX_MOUSE_BUTTON
	return false


## True se value é um Array não vazio só com eventos válidos. Lista vazia é inválida: gravar uma ação sem ligação
## deixaria o jogador sem o controle (R1-06).
static func validate(value: Variant) -> bool:
	if typeof(value) != TYPE_ARRAY or (value as Array).is_empty():
		return false
	for entry: Variant in value as Array:
		if not is_valid_entry(entry):
			return false
	return true


## Ações (exceto a própria) que já usam o mesmo evento. Vazio = sem conflito.
static func find_conflicts(entry: Dictionary, except_action: StringName) -> PackedStringArray:
	capture_defaults()
	var out: PackedStringArray = PackedStringArray()
	for key: String in rebindable_actions():
		if StringName(key) == except_action:
			continue
		for other: Variant in _serialize_action(StringName(key)):
			if other == entry:
				out.append(key)
				break
	return out


## Texto legível de um evento serializado, para a tela de controles.
static func describe(entry: Dictionary) -> String:
	if entry.get("type") == TYPE_KEY:
		var code: int = int(entry.get("physical_keycode", 0))
		return OS.get_keycode_string(code as Key)
	if entry.get("type") == TYPE_MOUSE:
		return "Mouse botão %d" % int(entry.get("button_index", 0))
	return "(vazio)"


## Evento serializado a partir de um InputEvent de tecla ou botão do mouse; null se não for suportado.
static func entry_from_event(event: InputEvent) -> Dictionary:
	var key: InputEventKey = event as InputEventKey
	if key != null:
		return {"type": TYPE_KEY, "physical_keycode": int(key.physical_keycode)}
	var button: InputEventMouseButton = event as InputEventMouseButton
	if button != null:
		return {"type": TYPE_MOUSE, "button_index": int(button.button_index)}
	return {}


static func _serialize_action(action: StringName) -> Array:
	var out: Array = []
	for event: InputEvent in InputMap.action_get_events(action):
		var entry: Dictionary = entry_from_event(event)
		if not entry.is_empty():
			out.append(entry)
	return out


static func _set_action(action: StringName, entries: Array) -> void:
	if not InputMap.has_action(action):
		return
	InputMap.action_erase_events(action)
	for entry: Variant in entries:
		var event: InputEvent = _event_from_entry(entry)
		if event != null:
			InputMap.action_add_event(action, event)


static func _event_from_entry(entry: Variant) -> InputEvent:
	if not is_valid_entry(entry):
		return null
	var dict: Dictionary = entry as Dictionary
	if dict.get("type") == TYPE_KEY:
		var key: InputEventKey = InputEventKey.new()
		key.physical_keycode = int(dict["physical_keycode"]) as Key
		return key
	var button: InputEventMouseButton = InputEventMouseButton.new()
	button.button_index = int(dict["button_index"]) as MouseButton
	return button

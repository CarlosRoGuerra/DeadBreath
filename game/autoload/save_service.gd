extends Node
## SaveService (L0, autoload "SaveService"): I/O genérico de JSON com escrita atômica.
## Não conhece tipos de jogo. Contrato: COMPONENT_CONTRACTS §15.
##
## Observação: o JSON do Godot devolve todo número como float. Quem precisa de inteiros
## exatos (ex.: estado do RNG) grava como string (DATA_STRUCTURES §6).

const DEFAULT_BASE_DIR: String = "user://saves"
const LOG_CATEGORY: StringName = &"save"

## Pasta dos slots. Testes apontam para um diretório temporário.
var base_dir: String = DEFAULT_BASE_DIR


## Grava o slot de forma atômica. Slots válidos: letras minúsculas, dígitos e "_".
func write_json(slot: StringName, data: Dictionary) -> Error:
	if not is_valid_slot(slot):
		Log.error(LOG_CATEGORY, "nome de slot inválido: '%s'" % slot)
		return ERR_INVALID_PARAMETER
	var err: Error = AtomicFile.write_text(get_slot_path(slot), JSON.stringify(data, "\t", true))
	if err != OK:
		Log.error(LOG_CATEGORY, "falha ao gravar o slot '%s': %s" % [slot, error_string(err)])
	return err


## Devolve {} se o slot estiver ausente ou inválido (com log).
func read_json(slot: StringName) -> Dictionary:
	if not is_valid_slot(slot):
		Log.error(LOG_CATEGORY, "nome de slot inválido: '%s'" % slot)
		return {}
	var path: String = get_slot_path(slot)
	var result: AtomicFile.ReadResult = AtomicFile.read_text(path, _is_json_object)
	if not result.ok:
		if _any_copy_exists(path):
			Log.error(LOG_CATEGORY, "slot '%s' inválido ou corrompido; nenhuma cópia legível" % slot)
		else:
			Log.info(LOG_CATEGORY, "slot '%s' ausente" % slot)
		return {}
	if result.source != "main":
		Log.warn(LOG_CATEGORY, "slot '%s' recuperado da cópia '%s'" % [slot, result.source])
	var json: JSON = JSON.new()
	json.parse(result.text)
	return json.data as Dictionary


func has_slot(slot: StringName) -> bool:
	return is_valid_slot(slot) and FileAccess.file_exists(get_slot_path(slot))


func get_slot_path(slot: StringName) -> String:
	return base_dir.path_join(String(slot) + ".json")


func is_valid_slot(slot: StringName) -> bool:
	var s: String = String(slot)
	if s.is_empty() or s.length() > 64:
		return false
	for i: int in s.length():
		var c: int = s.unicode_at(i)
		var ok: bool = (c >= 97 and c <= 122) or (c >= 48 and c <= 57) or c == 95
		if not ok:
			return false
	return true


func _is_json_object(text: String) -> bool:
	var json: JSON = JSON.new()
	return json.parse(text) == OK and json.data is Dictionary


func _any_copy_exists(path: String) -> bool:
	return FileAccess.file_exists(path) or FileAccess.file_exists(path + AtomicFile.TMP_SUFFIX) or FileAccess.file_exists(path + AtomicFile.BAK_SUFFIX)

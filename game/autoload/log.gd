extends Node
## Log (L0, autoload "Log"): mensagens por categoria e nível, no console e em
## user://logs/game.log (a execução anterior fica em game.prev.log).
## Contrato: COMPONENT_CONTRACTS §15.

## Emitido para toda mensagem que passa no filtro de nível (usado por testes e pelo overlay).
signal message_logged(level: int, category: StringName, message: String)

const DEBUG: int = 0
const INFO: int = 1
const WARN: int = 2
const ERROR: int = 3
const LEVEL_NAMES: PackedStringArray = ["DEBUG", "INFO", "WARN", "ERROR"]

const LOG_DIR: String = "user://logs"
const LOG_FILE: String = "game.log"
const PREV_LOG_FILE: String = "game.prev.log"

## Nível mínimo para categorias sem nível próprio.
var default_level: int = INFO
## Desligue antes de entrar na árvore para não gravar arquivo (ex.: instâncias de teste).
var file_enabled: bool = true
## Pasta do arquivo de log. Testes apontam para um diretório temporário.
var log_dir: String = LOG_DIR

var _levels: Dictionary = {}
var _file: FileAccess = null


func _ready() -> void:
	if file_enabled:
		_open_file()


func _exit_tree() -> void:
	if _file != null:
		_file.flush()
		_file.close()
		_file = null


func debug(category: StringName, message: String) -> void:
	_log(DEBUG, category, message)


func info(category: StringName, message: String) -> void:
	_log(INFO, category, message)


func warn(category: StringName, message: String) -> void:
	_log(WARN, category, message)


func error(category: StringName, message: String) -> void:
	_log(ERROR, category, message)


func set_level(category: StringName, level: int) -> void:
	_levels[category] = clampi(level, DEBUG, ERROR)


func get_level(category: StringName) -> int:
	return int(_levels.get(category, default_level))


## Caminho do arquivo de log atual ("" se a gravação em arquivo estiver desligada).
func get_file_path() -> String:
	return log_dir.path_join(LOG_FILE) if _file != null else ""


func _log(level: int, category: StringName, message: String) -> void:
	if level < get_level(category):
		return
	var line: String = "%s [%s] [%s] %s" % [Time.get_datetime_string_from_system(false, true), LEVEL_NAMES[level], category, message]
	if level >= WARN:
		printerr(line)
	else:
		print(line)
	if _file != null:
		_file.store_line(line)
		if level >= WARN:
			_file.flush()
	message_logged.emit(level, category, message)


func _open_file() -> void:
	if not DirAccess.dir_exists_absolute(log_dir):
		DirAccess.make_dir_recursive_absolute(log_dir)
	var path: String = log_dir.path_join(LOG_FILE)
	var prev: String = log_dir.path_join(PREV_LOG_FILE)
	# Rotação simples; falhas (outro processo usando o arquivo) não impedem o log no console.
	if FileAccess.file_exists(path):
		if FileAccess.file_exists(prev):
			DirAccess.remove_absolute(prev)
		DirAccess.rename_absolute(path, prev)
	_file = FileAccess.open(path, FileAccess.WRITE)
	if _file == null:
		printerr("[Log] não foi possível abrir %s (erro %d); seguindo só no console" % [path, FileAccess.get_open_error()])

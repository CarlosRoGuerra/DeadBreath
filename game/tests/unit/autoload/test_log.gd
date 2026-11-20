extends TestCase
## Unit: autoload/log.gd (instâncias próprias; não mexe no autoload real). Autor: Software Architect (F1-004).

const LogScript := preload("res://autoload/log.gd")

## Nós geridos aqui (e não por add_child_autofree) para fechar o arquivo de log
## antes de o framework apagar o diretório temporário.
var _nodes: Array[Node] = []


func after_each() -> void:
	for n: Node in _nodes:
		if is_instance_valid(n):
			n.free()
	_nodes.clear()


func _make(with_file: bool, dir: String = "") -> LogScript:
	var logger: LogScript = LogScript.new()
	logger.file_enabled = with_file
	logger.log_dir = dir if not dir.is_empty() else tmp_dir()
	_nodes.append(logger)
	add_child(logger)
	return logger


func test_filters_by_category_level() -> void:
	var logger: LogScript = _make(false)
	var received: Array[String] = []
	logger.message_logged.connect(func(level: int, category: StringName, message: String) -> void:
		received.append("%d|%s|%s" % [level, category, message]))
	logger.set_level(&"ai", LogScript.WARN)
	logger.info(&"ai", "filtrada")
	logger.warn(&"ai", "passa")
	logger.debug(&"core", "filtrada pelo padrão INFO")
	logger.info(&"core", "passa também")
	logger.error(&"core", "erro")
	var expected: Array[String] = ["2|ai|passa", "1|core|passa também", "3|core|erro"]
	assert_eq(received, expected)


func test_set_level_is_clamped() -> void:
	var logger: LogScript = _make(false)
	logger.set_level(&"x", 99)
	assert_eq(logger.get_level(&"x"), LogScript.ERROR)
	logger.set_level(&"x", -5)
	assert_eq(logger.get_level(&"x"), LogScript.DEBUG)
	assert_eq(logger.get_level(&"sem_nivel"), logger.default_level)


func test_writes_log_file() -> void:
	var logger: LogScript = _make(true)
	assert_ne(logger.get_file_path(), "", "arquivo de log aberto")
	logger.warn(&"teste", "linha gravada no arquivo")
	var path: String = logger.get_file_path()
	logger.free()
	var text: String = FileAccess.get_file_as_string(path)
	assert_true(text.contains("[WARN] [teste] linha gravada no arquivo"), "conteúdo: " + text)


func test_rotates_previous_file() -> void:
	var dir: String = tmp_dir()
	var first: LogScript = _make(true, dir)
	first.warn(&"teste", "execução anterior")
	first.free()
	var second: LogScript = _make(true, dir)
	second.free()
	var prev: String = FileAccess.get_file_as_string(dir.path_join(LogScript.PREV_LOG_FILE))
	assert_true(prev.contains("execução anterior"), "game.prev.logger guarda a execução anterior")

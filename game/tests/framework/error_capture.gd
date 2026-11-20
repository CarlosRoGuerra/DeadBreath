class_name ErrorCapture
extends Logger
## Captura de erros do engine e de script para o runner (F1-005, TEST_PLAN §4).
## Registrado com OS.add_logger() no início do runner. Verificado no Godot 4.7.2:
##   - ERROR_TYPE_SCRIPT (2): erro de execução ou de parse de GDScript. Reprova o teste em execução.
##   - ERROR_TYPE_ERROR (0): push_error, ConfigFile e falha de load. Não reprova; o teste declara
##     o esperado com expect_engine_error(), e erro não declarado vira nota.
##   - ERROR_TYPE_WARNING (1): push_warning. Ignorado.
## Os erros chegam na thread que os gerou. O buffer é protegido por Mutex.
## O runner usa begin_window()/take_window() em torno de cada fase de cada teste.


## Um erro capturado. message é a rationale do engine ou, se vazia, o código do erro.
class CapturedError:
	extends RefCounted
	var kind: int = 0
	var message: String = ""
	var file: String = ""
	var line: int = 0
	var function: String = ""


var _mutex: Mutex = Mutex.new()
var _window: Array[CapturedError] = []


func _log_error(function: String, file: String, line: int, code: String, rationale: String,
		_editor_notify: bool, error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
	var entry: CapturedError = CapturedError.new()
	entry.kind = error_type
	entry.message = rationale if not rationale.is_empty() else code
	entry.file = file
	entry.line = line
	entry.function = function
	_mutex.lock()
	_window.append(entry)
	_mutex.unlock()


## Abre uma janela: descarta o que foi capturado antes (carga de arquivo, fase anterior).
func begin_window() -> void:
	_mutex.lock()
	_window.clear()
	_mutex.unlock()


## Fecha a janela e devolve os erros capturados nela.
func take_window() -> Array[CapturedError]:
	_mutex.lock()
	var taken: Array[CapturedError] = []
	taken.assign(_window)
	_window.clear()
	_mutex.unlock()
	return taken

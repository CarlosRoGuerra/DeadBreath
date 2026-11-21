extends SceneTree
## Gravacao do roteiro "atravessar a casa em silencio" (F3-011, QA). Script principal leve: o nucleo
## (f3011_cenario_core.gd) carrega uma unica vez, no primeiro _process, quando os autoloads ja existem.
## Uso (headless, APPDATA isolado, mesmo modo da suite):
##   godot --headless --fixed-fps 60 --path game -s res://tests/integration/qa/probes/f3011_cenario.gd
## Saida: Docs/QA/EVIDENCE/F3-011_cenario_log.txt e F3-011_cenario_telemetria.csv

const CORE_PATH: String = "res://tests/integration/qa/probes/f3011_cenario_core.gd"

var _started: bool = false
## Mantido em membro: a corrotina do nucleo precisa do objeto vivo enquanto aguarda os quadros.
var _core: RefCounted = null


func _process(_delta: float) -> bool:
	if not _started:
		_started = true
		var core_script: GDScript = load(CORE_PATH) as GDScript
		_core = core_script.new() as RefCounted
		if _core == null:
			push_error("F3-011: nucleo da gravacao nao carregou")
			quit(2)
			return false
		_core.call("start", self)
	return false

extends SceneTree
## Probe F2-011 (QA): pausa no meio da crise (ver f2011_pausa_core.gd). Script principal leve; o núcleo é carregado
## no primeiro _process. Uso (com janela, APPDATA isolado, rede de segurança --quit-after):
##   godot --path game --resolution 1280x720 --quit-after 30000 -s res://tests/integration/qa/probes/f2011_pausa.gd

const CORE_PATH: String = "res://tests/integration/qa/probes/f2011_pausa_core.gd"

## Mantido em membro: a corrotina do núcleo precisa do objeto vivo enquanto aguarda os quadros.
var _core: RefCounted = null


func _process(_delta: float) -> bool:
	if _core == null:
		var core_script: GDScript = load(CORE_PATH) as GDScript
		_core = core_script.new() as RefCounted
		_core.call("start", self)
	return false

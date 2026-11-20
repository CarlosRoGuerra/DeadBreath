extends SceneTree
## Gravação do cenário "correr até a crise e se recuperar" (F2-011, QA). Script principal leve: o núcleo
## (f2011_cenario_core.gd) é carregado no primeiro _process, quando os autoloads já existem.
## Uso (COM janela, com --quit-after como rede de segurança e APPDATA isolado):
##   godot --path game --resolution 1280x720 --quit-after 12000 -s res://tests/integration/qa/probes/f2011_cenario.gd

const CORE_PATH: String = "res://tests/integration/qa/probes/f2011_cenario_core.gd"

## Mantido em membro: a corrotina do núcleo precisa do objeto vivo enquanto aguarda os quadros.
var _core: RefCounted = null


func _process(_delta: float) -> bool:
	if _core == null:
		var core_script: GDScript = load(CORE_PATH) as GDScript
		_core = core_script.new() as RefCounted
		_core.call("start", self)
	return false

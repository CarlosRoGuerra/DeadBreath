extends TestCase
## NOI-01 (TEST_PLAN §2.3; COMPONENT_CONTRACTS §6.5 e §7.2; F4-002): só o AcousticWorld chama HearingSensor.receive.
## Varredura de texto no código do jogo (res:// sem res://tests/, a mesma convenção da varredura NOI-INV-1: testes
## dirigem os sensores direto, e o caminho de produção é coberto pelos testes do AcousticWorld). Um acesso ".receive"
## (chamada ou referência) fora de components/acoustics/acoustic_world.gd viola quando o receptor é do tipo
## HearingSensor, quando não tem tipo declarado (expressão, subscrito, variável sem tipo) ou quando "receive" aparece
## como texto (call, Callable). Receptor declarado com outro tipo não viola. Não vacuidade: o AcousticWorld tem a
## chamada num HearingSensor, e a detecção pega os casos sintéticos abaixo. Arquivos sem o texto "receive" são
## pulados antes da limpeza de código, o que mantém o teste rápido.
## Autor: AI Engineer (F4-002).

const ALLOWED_FILE: String = "res://components/acoustics/acoustic_world.gd"
const METHOD: String = "receive"
const SENSOR_TYPE: String = "HearingSensor"
## Receptor (identificador logo antes do ponto; vazio se for expressão ou subscrito), ponto e nome do método.
const ACCESS_PATTERN: String = "(\\w*)\\s*\\.\\s*receive\\b"
const STRING_PATTERN: String = "[\"']receive[\"']"


func test_so_o_acoustic_world_chama_receive_de_hearing_sensor() -> void:
	var violations: PackedStringArray = PackedStringArray()
	var scanned: int = 0
	var with_text: int = 0
	var paths: PackedStringArray = PackedStringArray()
	_game_scripts("res://", paths)
	paths.sort()
	for path: String in paths:
		scanned += 1
		if path == ALLOWED_FILE:
			continue
		var raw: String = SourceScan.read(path)
		if raw.find(METHOD) >= 0:
			with_text += 1
		for finding: String in violations_in(raw):
			violations.append("%s %s" % [path, finding])
	note("arquivos de game/ varridos (sem tests/): %d; com o texto 'receive': %d" % [scanned, with_text])
	assert_eq(violations.size(), 0, "violações de NOI-01: " + "; ".join(violations))
	var sensor_calls: int = _sensor_call_count(SourceScan.read(ALLOWED_FILE))
	assert_true(sensor_calls >= 1, "vacuidade: o AcousticWorld chama receive num HearingSensor (%d)" % sensor_calls)


func test_a_deteccao_pega_os_casos_que_deve_pegar() -> void:
	assert_eq(violations_in("var s: HearingSensor = n\ns.receive(h)\n").size(), 1, "receptor tipado como HearingSensor")
	assert_eq(violations_in("var t := node as HearingSensor\nt.receive(h)\n").size(), 1, "tipo inferido por 'as'")
	assert_eq(violations_in("get_node(\"x\").receive(h)\n").size(), 1, "receptor expressão (get_node)")
	assert_eq(violations_in("var u = thing\nu.receive(h)\n").size(), 1, "receptor sem tipo declarado")
	assert_eq(violations_in("var c = thing\nvar f = c.sensor_list[0]\nf.receive(h)\n").size(), 1, "subscrito sem tipo")
	var quoted: String = "c.call(\"" + METHOD + "\", h)\n"
	assert_eq(violations_in(quoted).size(), 1, "receive como texto (chamada indireta)")


func test_a_deteccao_nao_pega_o_que_nao_deve() -> void:
	assert_eq(violations_in("var o: Other\no.receive(h)\n").size(), 0, "receptor de outro tipo declarado")
	assert_eq(violations_in("var s: HearingSensor\ns.receive_all(h)\n").size(), 0, "outro método com prefixo igual")
	assert_eq(violations_in("# sensor.receive(h)\n").size(), 0, "comentário não é código")
	assert_eq(violations_in("var t = \"sensor.receive(x)\"\n").size(), 0, "texto dentro de string não é chamada")


## Scripts .gd do código do jogo (res:// sem tests/ e sem pastas ocultas). Usa DirAccess.get_*_at: SourceScan.list_gd_files
## faz um stat por entrada de res:// e custa ~0,4 s só para listar.
static func _game_scripts(dir_path: String, out: PackedStringArray) -> void:
	for file_name: String in DirAccess.get_files_at(dir_path):
		if file_name.ends_with(".gd"):
			out.append(dir_path.path_join(file_name))
	for sub_dir: String in DirAccess.get_directories_at(dir_path):
		if sub_dir.begins_with(".") or (dir_path == "res://" and sub_dir == "tests"):
			continue
		_game_scripts(dir_path.path_join(sub_dir), out)


## Violações de um texto de código, uma por linha: acesso indevido ou receive como texto. Vazio se não há nada.
static func violations_in(raw: String) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	if raw.find(METHOD) < 0:
		return out
	var code: String = SourceScan.code_of(raw, true)
	for access: Dictionary in _accesses(code):
		if _is_sensor_access(code, access["receiver"]):
			out.append("linha %d: receive num receptor '%s' (só o AcousticWorld chama)" % [access["line"], access["receiver"]])
	for hit: String in SourceScan.find_all(SourceScan.code_of(raw, false), STRING_PATTERN):
		out.append("%s (receive como texto)" % hit)
	return out


## Chamadas de receive em receptor declarado como HearingSensor no texto. Linha a linha, só nas linhas com "receive"
## (limpar o arquivo inteiro custa ~300 ms; a checagem de vacuidade não precisa disso). Os tipos vêm do texto bruto.
static func _sensor_call_count(raw: String) -> int:
	var count: int = 0
	for line: String in raw.split("\n"):
		if line.find(METHOD) < 0:
			continue
		for access: Dictionary in _accesses(SourceScan.code_of(line, true)):
			var receiver: String = access["receiver"]
			if not receiver.is_empty() and _declared_types(raw, receiver).has(SENSOR_TYPE):
				count += 1
	return count


## Acessos ".receive" do código (já sem comentários e com strings vazias): receptor e linha.
static func _accesses(code: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var regex: RegEx = RegEx.new()
	regex.compile(ACCESS_PATTERN)
	for found: RegExMatch in regex.search_all(code):
		var line: int = code.substr(0, found.get_start()).count("\n") + 1
		out.append({"receiver": found.get_string(1), "line": line})
	return out


## Receptor sem tipo declarado (ou expressão) ou declarado como HearingSensor: pode ser um sensor, então conta.
static func _is_sensor_access(code: String, receiver: String) -> bool:
	if receiver.is_empty():
		return true
	var types: PackedStringArray = _declared_types(code, receiver)
	return types.is_empty() or types.has(SENSOR_TYPE)


## Tipos declarados para o identificador: "nome: Tipo" (var, parâmetro, for) e "nome := ... as Tipo".
static func _declared_types(code: String, identifier: String) -> PackedStringArray:
	var types: PackedStringArray = PackedStringArray()
	var annotated: RegEx = RegEx.new()
	annotated.compile("\\b" + identifier + "\\s*:\\s*(\\w+)")
	for found: RegExMatch in annotated.search_all(code):
		types.append(found.get_string(1))
	var inferred: RegEx = RegEx.new()
	inferred.compile("\\b" + identifier + "\\s*:=\\s*[^\\n]*\\bas\\s+(\\w+)")
	for found: RegExMatch in inferred.search_all(code):
		types.append(found.get_string(1))
	return types

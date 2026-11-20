class_name TestCase
extends Node
## Base dos testes headless do DEAD BREATH (F1-005, contrato TEST_PLAN §4 v1.0).
##
## Cada arquivo test_*.gd estende TestCase. Cada método test_<nome>() sem argumentos é um teste.
## Ganchos opcionais (podem usar await): before_all, after_all, before_each, after_each.
## Asserts registram a falha e seguem; o teste falha se houver ao menos uma.
## Erros de script (tipo SCRIPT) que o teste declara como esperados, com expect_script_error().
## Erros de engine (tipo ERROR, ex.: push_error) declarados com expect_engine_error().
## Um erro de script NÃO declarado reprova o teste em execução; um erro de engine não declarado
## vira nota. Um erro declarado que não ocorre reprova o teste.
## Os campos failures, assert_count, notes e os expected_* são lidos pelo runner
## (tests/run_all.gd). Os testes não devem alterá-los diretamente.

## Mensagens de falha do teste atual (vazio = nenhuma falha).
var failures: PackedStringArray = PackedStringArray()
## Quantos asserts o teste atual executou (inclui os que passaram).
var assert_count: int = 0
## Notas informativas do teste atual (ex.: quantos arquivos foram varridos). Aparecem na saída.
var notes: PackedStringArray = PackedStringArray()
## Trechos de mensagens de erro de script esperados neste teste.
var expected_script_errors: PackedStringArray = PackedStringArray()
## Trechos de mensagens de erro de engine esperados neste teste.
var expected_engine_errors: PackedStringArray = PackedStringArray()

var _test_label: String = ""
var _autofree_nodes: Array[Node] = []
var _tmp_dir_path: String = ""
static var _tmp_seq: int = 0


# ---- Ganchos (o padrão não faz nada; sobrescreva nos testes) ----

func before_all() -> void:
	pass


func after_all() -> void:
	pass


func before_each() -> void:
	pass


func after_each() -> void:
	pass


# ---- Asserts ----

func assert_true(cond: bool, msg: String = "") -> bool:
	assert_count += 1
	if cond:
		return true
	_record_failure("assert_true: esperado verdadeiro", msg)
	return false


func assert_false(cond: bool, msg: String = "") -> bool:
	assert_count += 1
	if not cond:
		return true
	_record_failure("assert_false: esperado falso", msg)
	return false


func assert_eq(actual: Variant, expected: Variant, msg: String = "") -> bool:
	assert_count += 1
	if actual == expected:
		return true
	_record_failure("assert_eq: esperado %s, obtido %s" % [str(expected), str(actual)], msg)
	return false


func assert_ne(actual: Variant, expected: Variant, msg: String = "") -> bool:
	assert_count += 1
	if actual != expected:
		return true
	_record_failure("assert_ne: esperado diferente de %s" % str(expected), msg)
	return false


func assert_almost_eq(actual: float, expected: float, tolerance: float, msg: String = "") -> bool:
	assert_count += 1
	if absf(actual - expected) <= tolerance:
		return true
	_record_failure("assert_almost_eq: esperado %s +/- %s, obtido %s" % [str(expected), str(tolerance), str(actual)], msg)
	return false


func assert_null(value: Variant, msg: String = "") -> bool:
	assert_count += 1
	if value == null:
		return true
	_record_failure("assert_null: esperado null, obtido %s" % str(value), msg)
	return false


func assert_not_null(value: Variant, msg: String = "") -> bool:
	assert_count += 1
	if value != null:
		return true
	_record_failure("assert_not_null: esperado um valor, obtido null", msg)
	return false


func fail(msg: String = "") -> void:
	assert_count += 1
	_record_failure("fail() chamado", msg)


## Nota informativa: aparece na saída do runner, não afeta o resultado.
func note(text: String) -> void:
	notes.append(text)


## Declara um erro de script (tipo SCRIPT) esperado: o trecho deve aparecer na mensagem.
## Sem essa declaração, qualquer erro de script durante o teste reprova o teste.
func expect_script_error(substring: String) -> void:
	expected_script_errors.append(substring)


## Declara um erro de engine (tipo ERROR, ex.: push_error) esperado: o trecho deve aparecer
## na mensagem. Se o erro não ocorrer, o teste reprova.
func expect_engine_error(substring: String) -> void:
	expected_engine_errors.append(substring)


# ---- Utilidades ----

## Adiciona o nó ao teste; ele é liberado ao fim do teste.
func add_child_autofree(node: Node) -> Node:
	add_child(node)
	_autofree_nodes.append(node)
	return node


## Espera n frames de física (o teste precisa estar na árvore de cena).
func wait_physics_frames(n: int) -> void:
	var tree: SceneTree = get_tree()
	if tree == null:
		fail("wait_physics_frames: o teste nao esta na arvore de cena")
		return
	for _i: int in n:
		await tree.physics_frame


## Espera n frames de processo (o teste precisa estar na árvore de cena).
func wait_process_frames(n: int) -> void:
	var tree: SceneTree = get_tree()
	if tree == null:
		fail("wait_process_frames: o teste nao esta na arvore de cena")
		return
	for _i: int in n:
		await tree.process_frame


## Diretório vazio exclusivo do teste em user://test_tmp/. Apagado ao fim do teste.
func tmp_dir() -> String:
	if _tmp_dir_path.is_empty():
		TestCase._tmp_seq += 1
		_tmp_dir_path = "user://test_tmp/%03d_%s" % [TestCase._tmp_seq, _sanitize(_test_label)]
		var err: Error = DirAccess.make_dir_recursive_absolute(_tmp_dir_path)
		if err != OK:
			fail("tmp_dir: nao foi possivel criar '%s' (erro %d)" % [_tmp_dir_path, err])
	return _tmp_dir_path


# ---- Interface do runner (não usar nos testes) ----

## Prepara o estado para o próximo teste.
func harness_begin_test(label: String) -> void:
	_test_label = label
	failures = PackedStringArray()
	assert_count = 0
	notes = PackedStringArray()
	expected_script_errors = PackedStringArray()
	expected_engine_errors = PackedStringArray()


## Libera os nós do teste e apaga o diretório temporário.
func harness_end_test() -> void:
	for node: Node in _autofree_nodes:
		if is_instance_valid(node):
			var parent: Node = node.get_parent()
			if parent != null:
				parent.remove_child(node)
			node.free()
	_autofree_nodes.clear()
	if not _tmp_dir_path.is_empty():
		_remove_tree(_tmp_dir_path)
		_tmp_dir_path = ""


# ---- Internos ----

func _record_failure(kind: String, detail: String) -> void:
	var text: String = kind
	if not detail.is_empty():
		text += " | " + detail
	var location: String = _caller_location()
	if not location.is_empty():
		text = location + " -> " + text
	failures.append(text)


func _caller_location() -> String:
	for frame: Dictionary in get_stack():
		var source: String = str(frame.get("source", ""))
		if source.is_empty() or source.ends_with("test_case.gd"):
			continue
		return "%s:%d" % [source, int(frame.get("line", 0))]
	return ""


static func _sanitize(text: String) -> String:
	var regex: RegEx = RegEx.new()
	regex.compile("[^A-Za-z0-9_]")
	return regex.sub(text, "_", true)


static func _remove_tree(path: String) -> void:
	var dir: DirAccess = DirAccess.open(path)
	if dir == null:
		return
	var entries: PackedStringArray = PackedStringArray()
	dir.list_dir_begin()
	var entry: String = dir.get_next()
	while entry != "":
		if entry != "." and entry != "..":
			entries.append(entry)
		entry = dir.get_next()
	dir.list_dir_end()
	for child: String in entries:
		if DirAccess.dir_exists_absolute(path.path_join(child)):
			_remove_tree(path.path_join(child))
		else:
			dir.remove(child)
	var parent: DirAccess = DirAccess.open(path.get_base_dir())
	if parent != null:
		parent.remove(path.get_file())

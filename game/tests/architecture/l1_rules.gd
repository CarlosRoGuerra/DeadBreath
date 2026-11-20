class_name L1Rules
extends RefCounted
## Regras de L1 (sim/) do ARC-03 (F1-005; R1-11, F1-010). Funções puras, usadas pelo teste de
## arquitetura (test_arc03_l1_purity.gd) e pelo meta-teste de injeção (meta/test_arc03_regras_dinamicas.gd).
##
## Proibido em L1, estático ou dinâmico:
##   - cena: Node, SceneTree, get_node, get_node_or_null, get_tree, $ (caminho de nó);
##   - acesso ao scene tree por fora: get_main_loop, get_nodes_in_group, call_group;
##   - reflexão de classes: ClassDB;
##   - chamadas dinâmicas: call, callv, call_deferred;
##   - carga de recursos: load, preload;
##   - get(...) com string literal (acesso dinâmico por nome);
##   - autoloads (lista lida de project.godot).
## Comentários e strings não contam como código, exceto na regra de get(...) com string, que olha strings.
## Limite: call/callv também pegam Callable.call; se L1 precisar de callable injetado, abrir exceção documentada.

const IDENTIFIER_RULES: String = "\\b(get_node|get_node_or_null|get_tree|get_main_loop|get_nodes_in_group|call_group|Node|SceneTree|ClassDB|callv|call_deferred|call|load|preload)\\b|\\$"
const LITERAL_RULES: String = "\\bget\\s*\\(\\s*[\"']"


## Violações de um script de L1. label identifica o arquivo na mensagem; raw é o texto do script;
## autoloads são os nomes registrados (vazio = sem verificação de autoload).
static func scan(label: String, raw: String, autoloads: PackedStringArray) -> PackedStringArray:
	var violations: PackedStringArray = PackedStringArray()
	var pattern: String = IDENTIFIER_RULES
	if not autoloads.is_empty():
		pattern += "|\\b(" + "|".join(autoloads) + ")\\b"
	for hit: String in SourceScan.find_all(SourceScan.code_of(raw, true), pattern):
		violations.append("%s %s" % [label, hit])
	for hit: String in SourceScan.find_all(SourceScan.code_of(raw, false), LITERAL_RULES):
		violations.append("%s %s (get com string: use dicionario[chave] ou propriedade tipada)" % [label, hit])
	return violations

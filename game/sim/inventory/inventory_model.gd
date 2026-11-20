class_name InventoryModel
extends RefCounted
## InventoryModel (L1, F2-005): contagem de cargas por item, sem Node (ARC-03). A bombinha é contada em doses:
## cada unidade vale DOSES_PER_UNIT doses (3). Itens sem entrada na tabela valem 1 dose por unidade.
## Fonte de verdade das cargas de medicação (COMPONENT_CONTRACTS §4.2): o PhysiologyComponent só lê o número.

const DOSES_PER_UNIT: Dictionary = {&"inhaler": 3}
const DEFAULT_DOSES_PER_UNIT: int = 1

var _doses: Dictionary = {}


## Quantas doses uma unidade do item vale.
static func doses_per_unit(item_id: StringName) -> int:
	return int(DOSES_PER_UNIT.get(item_id, DEFAULT_DOSES_PER_UNIT))


## Soma unidades (doses = unidades × doses_per_unit). Devolve as doses adicionadas; unidades <= 0 não fazem nada.
func add_units(item_id: StringName, units: int) -> int:
	if units <= 0 or item_id.is_empty():
		return 0
	var added: int = units * doses_per_unit(item_id)
	_doses[item_id] = doses(item_id) + added
	return added


func doses(item_id: StringName) -> int:
	return int(_doses.get(item_id, 0))


## Consome 1 dose. false, sem mudar nada, se não há doses.
func consume_dose(item_id: StringName) -> bool:
	if doses(item_id) <= 0:
		return false
	_doses[item_id] = doses(item_id) - 1
	return true


func to_dict() -> Dictionary:
	var out: Dictionary = {}
	for key: Variant in _doses.keys():
		out[str(key)] = int(_doses[key])
	return out


func from_dict(data: Dictionary) -> void:
	_doses = {}
	for key: Variant in data.keys():
		var value: int = int(data[key])
		if value > 0:
			_doses[StringName(str(key))] = value

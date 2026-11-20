extends TestCase
## F2-005 (InventoryModel L1): contagem de doses por item. Bombinha = 3 doses por unidade; item sem entrada = 1 dose.
## Autor: Gameplay Engineer (F2-005).


func test_bombinha_vale_tres_doses_por_unidade() -> void:
	var inv: InventoryModel = InventoryModel.new()
	assert_eq(inv.add_units(&"inhaler", 1), 3, "uma unidade de bombinha soma 3 doses")
	assert_eq(inv.doses(&"inhaler"), 3, "contagem de doses")
	inv.add_units(&"inhaler", 2)
	assert_eq(inv.doses(&"inhaler"), 9, "três unidades no total somam 9 doses")


func test_item_sem_entrada_vale_uma_dose() -> void:
	var inv: InventoryModel = InventoryModel.new()
	assert_eq(inv.add_units(&"water", 2), 2, "item padrão: 1 dose por unidade")
	assert_eq(inv.doses(&"water"), 2, "contagem")


func test_consumir_dose_nao_fica_negativo() -> void:
	var inv: InventoryModel = InventoryModel.new()
	assert_false(inv.consume_dose(&"inhaler"), "sem doses não consome")
	assert_eq(inv.doses(&"inhaler"), 0, "continua zero")
	inv.add_units(&"inhaler", 1)
	for index: int in 3:
		assert_true(inv.consume_dose(&"inhaler"), "consome dose %d" % index)
	assert_false(inv.consume_dose(&"inhaler"), "a quarta não existe")
	assert_eq(inv.doses(&"inhaler"), 0, "nunca negativo")


func test_unidades_invalidas_nao_mudam_nada() -> void:
	var inv: InventoryModel = InventoryModel.new()
	assert_eq(inv.add_units(&"inhaler", 0), 0, "zero unidades")
	assert_eq(inv.add_units(&"inhaler", -2), 0, "unidades negativas")
	assert_eq(inv.add_units(&"", 1), 0, "item sem nome")
	assert_eq(inv.doses(&"inhaler"), 0, "nada entrou")


func test_serializacao_round_trip() -> void:
	var inv: InventoryModel = InventoryModel.new()
	inv.add_units(&"inhaler", 2)
	inv.add_units(&"water", 1)
	inv.consume_dose(&"inhaler")
	var copy: InventoryModel = InventoryModel.new()
	copy.from_dict(inv.to_dict())
	assert_eq(copy.doses(&"inhaler"), 5, "doses da bombinha")
	assert_eq(copy.doses(&"water"), 1, "doses da água")

extends TestCase
## Sonda do nível property (F1-010, decisão do Director): prova que tests/property/ é descoberto
## recursivamente com --level=property e que a execução padrão não o descobre. Fica nesta subpasta de
## propósito: o meta-teste meta/test_property_level.gd confere a recursão. O teste em si é trivial.


func test_property_probe_descoberto() -> void:
	assert_true(true, "vacuo: sonda de descoberta do nivel property; o resultado prova a descoberta")

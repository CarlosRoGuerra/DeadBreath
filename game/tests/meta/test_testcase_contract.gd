extends TestCase
## Contrato do TestCase (TEST_PLAN §4): asserts registram a falha e seguem; utilidades funcionam.
## As falhas de propósito ficam numa instância separada (probe), para não contarem como falhas
## deste teste.


func test_asserts_registram_falhas_e_seguem() -> void:
	var probe: TestCase = TestCase.new()
	probe.assert_true(true)
	probe.assert_true(false, "a")
	probe.assert_false(true, "b")
	probe.assert_false(false)
	probe.assert_eq(1, 1)
	probe.assert_eq(1, 2, "c")
	probe.assert_ne(1, 1, "d")
	probe.assert_ne(1, 2)
	probe.assert_almost_eq(1.004, 1.0, 0.01)
	probe.assert_almost_eq(1.02, 1.0, 0.01, "e")
	probe.assert_null(null)
	probe.assert_null(1, "f")
	probe.assert_not_null(1)
	probe.assert_not_null(null, "g")
	probe.fail("h")
	assert_eq(probe.assert_count, 15, "asserts executados (incluindo fail)")
	assert_eq(probe.failures.size(), 8, "falhas registradas")
	assert_true(probe.failures[0].contains("a"), "mensagem da primeira falha")
	probe.free()


func test_utilitarios_tmp_dir_autofree_e_frames() -> void:
	var probe: TestCase = TestCase.new()
	get_tree().root.add_child(probe)
	probe.harness_begin_test("probe_utilitarios")
	var dir: String = probe.tmp_dir()
	assert_true(dir.begins_with("user://test_tmp/"), "tmp_dir fica em user://test_tmp/")
	assert_true(DirAccess.dir_exists_absolute(dir), "tmp_dir existe")
	assert_eq(probe.tmp_dir(), dir, "tmp_dir é o mesmo dentro do teste")
	var file: FileAccess = FileAccess.open(dir.path_join("x.txt"), FileAccess.WRITE)
	assert_not_null(file, "grava arquivo no tmp_dir")
	if file != null:
		file.store_string("x")
		file.close()
	var child: Node = probe.add_child_autofree(Node.new())
	var frames_before: int = Engine.get_physics_frames()
	await probe.wait_physics_frames(3)
	assert_true(Engine.get_physics_frames() - frames_before >= 3, "wait_physics_frames espera 3 frames de física")
	probe.note("nota de teste")
	assert_eq(probe.notes.size(), 1, "note registra a nota")
	probe.harness_end_test()
	assert_false(DirAccess.dir_exists_absolute(dir), "tmp_dir é apagado ao fim do teste")
	assert_false(is_instance_valid(child), "add_child_autofree libera o nó ao fim do teste")
	get_tree().root.remove_child(probe)
	probe.free()

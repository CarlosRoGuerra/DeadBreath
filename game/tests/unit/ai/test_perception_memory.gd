extends TestCase
## PerceptionMemory (F4-003; COMPONENT_CONTRACTS §8.2): decaimento, fusão, capacidade e critério do best_lead.
## Taxa de decaimento de teste: 0,05/s. Contas à mão nos comentários.


func _record_at(at: Vector3, confidence: float, time_s: float, source: StringName) -> PerceptionRecord:
	return PerceptionRecord.create(at, time_s, confidence, source)


func test_decaimento_subtrai_taxa_vezes_dt_e_remove_a_pista_zerada() -> void:
	# Pista com confiança 0,5. Taxa 0,05/s. 4 s: 0,5 − 0,05·4 = 0,3 (fica). Mais 7 s: 0,3 − 0,35 = −0,05 (sai).
	var memory: PerceptionMemory = PerceptionMemory.new(0.05)
	memory.record(_record_at(Vector3(10.0, 0.0, 0.0), 0.5, 0.0, &"vision"))
	memory.decay(4.0)
	assert_eq(memory.count(), 1, "após 4 s a pista continua")
	assert_almost_eq(memory.best_lead().confidence, 0.3, 0.000001, "confiança 0,3 após 4 s")
	memory.decay(7.0)
	assert_eq(memory.count(), 0, "após 11 s a pista foi removida")
	assert_null(memory.best_lead(), "sem pista depois de removida")


func test_best_lead_vazio_e_nulo() -> void:
	var memory: PerceptionMemory = PerceptionMemory.new(0.02)
	assert_null(memory.best_lead(), "memória vazia não tem pista")


func test_best_lead_ignora_pistas_abaixo_do_minimo_util() -> void:
	# Confiança 0,09 < 0,1 (USEFUL_MIN_CONFIDENCE): não é pista útil, mesmo sendo a única.
	var memory: PerceptionMemory = PerceptionMemory.new(0.02)
	memory.record(_record_at(Vector3(5.0, 0.0, 5.0), 0.09, 1.0, &"vision"))
	assert_null(memory.best_lead(), "0,09 não é útil")
	assert_eq(memory.count(), 1, "mas continua guardada até decair a zero")


func test_best_lead_escolhe_a_de_maior_confianca() -> void:
	var memory: PerceptionMemory = PerceptionMemory.new(0.02)
	memory.record(_record_at(Vector3(0.0, 0.0, 0.0), 0.6, 5.0, &"vision"))
	memory.record(_record_at(Vector3(30.0, 0.0, 0.0), 0.9, 1.0, &"vision"))
	var lead: PerceptionRecord = memory.best_lead()
	assert_eq(lead.position, Vector3(30.0, 0.0, 0.0), "confiança 0,9 vence 0,6, mesmo sendo mais antiga")


func test_best_lead_empate_de_confianca_vence_a_mais_recente() -> void:
	# Duas pistas com 0,6 em pontos distintos (≥ 1 m, não se fundem). Vence a de t = 7 s.
	var memory: PerceptionMemory = PerceptionMemory.new(0.02)
	memory.record(_record_at(Vector3(0.0, 0.0, 0.0), 0.6, 2.0, &"vision"))
	memory.record(_record_at(Vector3(20.0, 0.0, 0.0), 0.6, 7.0, &"vision"))
	assert_eq(memory.best_lead().position, Vector3(20.0, 0.0, 0.0), "empate: a mais recente")


func test_pista_da_mesma_origem_a_ate_1_metro_funde() -> void:
	# Mesma origem a 0,5 m: substitui. Origem diferente no mesmo ponto: não funde.
	var memory: PerceptionMemory = PerceptionMemory.new(0.02)
	memory.record(_record_at(Vector3(4.0, 0.0, 4.0), 0.4, 1.0, &"vision"))
	memory.record(_record_at(Vector3(4.5, 0.0, 4.0), 0.7, 2.0, &"vision"))
	assert_eq(memory.count(), 1, "fundidas")
	assert_eq(memory.best_lead().position, Vector3(4.5, 0.0, 4.0), "posição da pista mais nova")
	assert_almost_eq(memory.best_lead().confidence, 0.7, 0.000001, "confiança da pista mais nova")
	memory.record(_record_at(Vector3(4.5, 0.0, 4.0), 0.5, 3.0, &"hearing"))
	assert_eq(memory.count(), 2, "origem diferente não funde")


func test_capacidade_descarta_a_de_menor_confianca() -> void:
	# 10 pistas a 10 m uma da outra, confiança 0,1..1,0. Capacidade 8: ao entrar a de 0,9 sai a de 0,1;
	# ao entrar a de 1,0 sai a de 0,2. Ficam 0,3..1,0.
	var memory: PerceptionMemory = PerceptionMemory.new(0.02)
	for index: int in range(10):
		memory.record(_record_at(Vector3(10.0 * index, 0.0, 0.0), 0.1 * (index + 1), float(index), &"vision"))
	assert_eq(memory.count(), PerceptionMemory.MAX_RECORDS, "limite de 8 pistas")
	assert_eq(memory.best_lead().position, Vector3(90.0, 0.0, 0.0), "a de 1,0 continua")
	memory.decay(0.5)
	assert_eq(memory.count(), PerceptionMemory.MAX_RECORDS, "decaimento curto não remove nenhuma")


func test_clear_esvazia_a_memoria() -> void:
	var memory: PerceptionMemory = PerceptionMemory.new(0.02)
	memory.record(_record_at(Vector3.ONE, 0.8, 1.0, &"vision"))
	memory.clear()
	assert_eq(memory.count(), 0, "vazia após clear")
	assert_null(memory.best_lead(), "sem pista após clear")

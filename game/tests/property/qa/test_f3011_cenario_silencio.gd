extends TestCase
## F3-011 (QA independente): roteiro "atravessar a casa em silêncio" na sandbox_playable.tscn real. O roteiro
## (integration/qa/fixtures/f3011_roteiro.gd) roda uma vez em before_all, com entradas simuladas; os testes conferem
## os registros de cada evento de ruído: o que o ouvido recebe, o roteador de áudio, a legenda e o salto de estresse.
## Coerências verificadas: porta fechada corta ~15 dB no ouvido; porta batida tem atenuação audível comprimida (medida);
## correr soa mais que andar; o próprio arremesso não assusta; outra fonte a 75 dB assusta (BUG-014); o trovão eleva o
## limiar; a camada de chuva muda ao entrar no quintal; todo som tocado vem de um evento (NOI-05, NOI-04).
## Cena inteira: nível property (fora da suíte padrão). Autor: QA Engineer (F3-011).

const ROTEIRO_FIXTURE: String = "res://tests/integration/qa/fixtures/f3011_roteiro.gd"
const DOOR_CLOSED: int = 0
const DOOR_OPEN: int = 1
const OPEN_MIN_DEG: float = 85.0
const CLOSED_MAX_DEG: float = 1.0
const CUT_EXPECTED_DB: float = 15.0
const CUT_TOL_DB: float = 0.5
const SLAM_CUT_MIN_DB: float = 3.0
const SLAM_CUT_MAX_DB: float = 5.0
const RUN_MINUS_WALK_MIN_DB: float = 10.0
const STARTLE_JUMP_MIN: float = 10.0
const STARTLE_JUMP_MAX: float = 25.0
const NO_STARTLE_JUMP_MAX: float = 5.0
const SPRINT_PHASE: String = "05_hall_correr"
const WALK_PHASE: String = "02_corredor_ate_porta_hall"
const THROW_PHASES: Array[String] = ["07_pegar_e_arremessar", "08_rota_quintal"]
const GAIN_TOL_DB: float = 0.0001
const LAYER_IDS: Array[String] = ["rain_interior", "rain_window", "rain_exterior"]
const BODY_CATEGORIES: Array[String] = ["BREATHING", "WHEEZING", "COUGHING", "MEDICATION"]

const EXPECTED_MARKS: Array[String] = ["silencio_inicial", "porta_sala_corredor_aberta_tocar", "porta_hall_aberta_segurando",
	"porta_hall_fechada_segurando", "hall_depois_da_corrida", "porta_hall_aberta_tocar_volta", "objeto_na_mao",
	"arremesso_pote", "porta_quintal_aberta_tocar", "quintal_antes_trovao", "trovao_forcado", "apos_trovao",
	"apos_susto_outra_fonte"]

var _roteiro: F3011Roteiro = null


func before_all() -> void:
	Settings.autosave = false
	var container: Node3D = add_isolated_world()
	_roteiro = F3011Roteiro.new()
	await _roteiro.run(get_tree(), container, self)


func after_all() -> void:
	Settings.autosave = true


func _mark(mark_name: String) -> Dictionary:
	for row: Dictionary in _roteiro.marks:
		if String(row["nome"]) == mark_name:
			return row
	return {}


func _control(label: String) -> Dictionary:
	for row: Dictionary in _roteiro.events:
		if String(row["controle"]) == label:
			return row
	return {}


func _events_of(category: String, phase_name: String = "") -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for row: Dictionary in _roteiro.events:
		if String(row["categoria"]) != category:
			continue
		if not phase_name.is_empty() and String(row["fase"]) != phase_name:
			continue
		out.append(row)
	return out


func _mean_perceived(rows: Array[Dictionary]) -> float:
	var total: float = 0.0
	for row: Dictionary in rows:
		total += float(row["perceived_db"])
	return total / float(maxi(rows.size(), 1))


func _mean_gain(rows: Array[Dictionary]) -> float:
	var total: float = 0.0
	for row: Dictionary in rows:
		total += float(row["ganho_db"])
	return total / float(maxi(rows.size(), 1))


func _event_by_id(event_id: int) -> Dictionary:
	for row: Dictionary in _roteiro.events:
		if int(row["id"]) == event_id:
			return row
	return {}


## Roteiro: executou sem desvios e passou pelos pontos planejados.
func test_roteiro_executou_como_planejado() -> void:
	assert_true(_roteiro.deviations.is_empty(), "sem desvios do roteiro: %s" % [str(_roteiro.deviations)])
	for mark_name: String in EXPECTED_MARKS:
		assert_false(_mark(mark_name).is_empty(), "marca '%s' registrada" % mark_name)
	assert_true(_roteiro.events.size() > 50, "o roteiro gerou eventos de ruído (%d)" % _roteiro.events.size())
	assert_true(_roteiro.telemetry.size() > 50, "telemetria gravada (%d linhas)" % _roteiro.telemetry.size())


## Portas: a sala-corredor abre ao toque, a do hall abre devagar (segurar) e fecha atrás do jogador, a do quintal abre.
func test_portas_abrem_e_fecham_como_planejado() -> void:
	var sala: Dictionary = _mark("porta_sala_corredor_aberta_tocar")
	assert_eq(int(sala.get("estado", -1)), DOOR_OPEN, "sala-corredor aberta ao toque")
	assert_true(float(sala.get("angulo", 0.0)) >= OPEN_MIN_DEG, "sala-corredor abre por inteiro")
	var hall_open: Dictionary = _mark("porta_hall_aberta_segurando")
	assert_eq(int(hall_open.get("estado", -1)), DOOR_OPEN, "porta do hall aberta segurando")
	assert_true(float(hall_open.get("angulo", 0.0)) >= OPEN_MIN_DEG, "porta do hall abre por inteiro")
	assert_false(bool(hall_open.get("movendo", true)), "porta do hall parada ao fim da abertura lenta")
	var hall_closed: Dictionary = _mark("porta_hall_fechada_segurando")
	assert_eq(int(hall_closed.get("estado", -1)), DOOR_CLOSED, "porta do hall fecha atrás do jogador")
	assert_true(float(hall_closed.get("angulo", 99.0)) <= CLOSED_MAX_DEG, "porta do hall fechada (ângulo %.2f)" % float(hall_closed.get("angulo", 99.0)))
	var quintal: Dictionary = _mark("porta_quintal_aberta_tocar")
	assert_eq(int(quintal.get("estado", -1)), DOOR_OPEN, "porta do quintal aberta ao toque")


## Furtividade (ROADMAP F3-011): a porta fechada corta ~15 dB no ouvido, no caminho pelo portal do hall (sem parede).
func test_porta_fechada_corta_15_db_no_ouvido() -> void:
	var open_row: Dictionary = _control("porta_aberta")
	var closed_row: Dictionary = _control("porta_fechada")
	assert_false(open_row.is_empty() or closed_row.is_empty(), "controles da porta registrados")
	if open_row.is_empty() or closed_row.is_empty():
		return
	assert_true(String(open_row["portais"]).contains("portal_corredor_hall"), "controle aberto passa pelo portal do hall")
	assert_true(String(closed_row["portais"]).contains("portal_corredor_hall"), "controle fechado passa pelo portal do hall")
	assert_false(bool(open_row["parede"]) or bool(closed_row["parede"]), "nenhum dos dois caminhos atravessa parede")
	var cut: float = float(open_row["perceived_db"]) - float(closed_row["perceived_db"])
	note("corte percebido da porta (50 dB): %.2f dB (aberta %.2f, fechada %.2f)" % [cut, float(open_row["perceived_db"]), float(closed_row["perceived_db"])])
	assert_almost_eq(cut, CUT_EXPECTED_DB, CUT_TOL_DB, "a porta fechada corta ~15 dB no que o ouvido recebe")


## Coerência de volume (achado documentado): o corte percebido é 15 dB também para a porta batida, mas o volume tocado
## é comprimido acima de 45 dB (DATA §2.4). O teste fixa o comportamento medido; se o Director mudar a regra, ele falha.
func test_porta_batida_tem_corte_audivel_comprimido() -> void:
	var open_row: Dictionary = _control("porta_aberta_batida")
	var closed_row: Dictionary = _control("porta_fechada_batida")
	assert_false(open_row.is_empty() or closed_row.is_empty(), "controles da porta batida registrados")
	if open_row.is_empty() or closed_row.is_empty():
		return
	assert_true(bool(open_row["roteador"]) and bool(closed_row["roteador"]), "as duas versões da batida tocam no roteador")
	var perceived_cut: float = float(open_row["perceived_db"]) - float(closed_row["perceived_db"])
	var audible_cut: float = float(open_row["ganho_db"]) - float(closed_row["ganho_db"])
	note("batida 75 dB: corte percebido %.2f dB; corte do volume tocado %.2f dB" % [perceived_cut, audible_cut])
	assert_almost_eq(perceived_cut, CUT_EXPECTED_DB, CUT_TOL_DB, "o corte percebido da batida também é ~15 dB")
	assert_true(audible_cut >= SLAM_CUT_MIN_DB and audible_cut <= SLAM_CUT_MAX_DB,
		"volume tocado: corte de %.2f dB (comprimido; documenta o comportamento de NoiseGain acima de 45 dB)" % audible_cut)


## Furtividade: correr soa mais que andar (medido pelo que o ouvido recebe e pelo volume tocado).
func test_corrida_soa_mais_que_caminhada() -> void:
	var running: Array[Dictionary] = _events_of("RUNNING", SPRINT_PHASE)
	var walking: Array[Dictionary] = _events_of("FOOTSTEP", WALK_PHASE)
	assert_true(running.size() >= 3 and walking.size() >= 3, "há passos de corrida (%d) e de caminhada (%d)" % [running.size(), walking.size()])
	if running.size() < 3 or walking.size() < 3:
		return
	var run_db: float = _mean_perceived(running)
	var walk_db: float = _mean_perceived(walking)
	note("corrida: %.2f dB percebidos, ganho %.2f; caminhada: %.2f dB, ganho %.2f" % [run_db, _mean_gain(running), walk_db, _mean_gain(walking)])
	assert_true(run_db - walk_db >= RUN_MINUS_WALK_MIN_DB, "corrida percebida pelo menos 10 dB acima da caminhada (diferença %.2f)" % (run_db - walk_db))
	assert_true(_mean_gain(running) > _mean_gain(walking), "o volume tocado da corrida é maior que o da caminhada")


## Arremesso: o próprio impacto do objeto que o jogador arremessou não assusta. Precondição: o impacto chega ao ouvido
## acima de 55 dB (senão o teste seria vacuo).
func test_arremesso_do_proprio_jogador_nao_assusta() -> void:
	var impacts: Array[Dictionary] = []
	for row: Dictionary in _roteiro.events:
		if String(row["categoria"]) == "OBJECT_IMPACT" and String(row["fonte"]).begins_with("player_thrown_"):
			impacts.append(row)
	assert_true(impacts.size() >= 1, "o objeto arremessado bateu e fez ruído de impacto (%d)" % impacts.size())
	for row: Dictionary in impacts:
		assert_true(float(row["perceived_db"]) >= 55.0, "precondição: impacto percebido a %.2f dB (>= 55, faria susto se não fosse do jogador)" % float(row["perceived_db"]))
		assert_true(float(row["salto_estresse"]) < NO_STARTLE_JUMP_MAX, "o impacto do arremesso não sobe o estresse (salto %.2f)" % float(row["salto_estresse"]))


## Ruído do próprio corpo do jogador (passos, corrida) não assusta o próprio jogador (regra de F3-010, R3-06).
func test_passos_do_proprio_jogador_nao_assustam() -> void:
	var count: int = 0
	for row: Dictionary in _roteiro.events:
		if String(row["fonte"]) != "player":
			continue
		count += 1
		assert_true(float(row["salto_estresse"]) < NO_STARTLE_JUMP_MAX,
			"evento do jogador %s (%s, id %d) não sobe o estresse (salto %.2f)" % [String(row["categoria"]), String(row["som"]), int(row["id"]), float(row["salto_estresse"])])
	assert_true(count >= 20, "a amostra tem eventos do próprio jogador (%d)" % count)


## BUG-014 (ponte de susto de produção): outra fonte a 75 dB, perceived >= 55, sobe o estresse entre 10 e 25.
func test_outra_fonte_a_75_db_assusta_pelo_caminho_de_producao() -> void:
	var row: Dictionary = _control("susto_outra_fonte")
	assert_false(row.is_empty(), "controle de susto registrado")
	if row.is_empty():
		return
	assert_true(float(row["perceived_db"]) >= 55.0, "precondição: percebido %.2f dB (>= 55)" % float(row["perceived_db"]))
	var jump: float = float(row["salto_estresse"])
	assert_true(jump >= STARTLE_JUMP_MIN and jump <= STARTLE_JUMP_MAX, "susto por outra fonte sobe o estresse entre 10 e 25 (salto %.2f)" % jump)


## Trovão (ROADMAP F3-011): o trovão eleva o limiar do jogador de 38 para 58 no quintal; o som de 50 dB que era audível
## deixa de ser tocado e sem legenda.
func test_trovao_eleva_o_limiar_e_o_som_fraco_some() -> void:
	var before: Dictionary = _mark("quintal_antes_trovao")
	var during: Dictionary = _mark("trovao_forcado")
	assert_almost_eq(float(before.get("limiar", 0.0)), 38.0, 0.01, "limiar do quintal sem trovão = piso 38 dB")
	assert_almost_eq(float(during.get("limiar", 0.0)), 58.0, 0.01, "limiar com trovão = 38 + 20 dB")
	var audible: Dictionary = _control("antes_trovao")
	var masked: Dictionary = _control("durante_trovao")
	assert_false(audible.is_empty() or masked.is_empty(), "controles do trovão registrados")
	if audible.is_empty() or masked.is_empty():
		return
	assert_true(bool(audible["audivel"]) and bool(audible["roteador"]), "antes do trovão, a porta de 50 dB é ouvida e tocada")
	assert_false(bool(masked["audivel"]) or bool(masked["roteador"]) or bool(masked["legenda"]),
		"com o trovão, a mesma porta de 50 dB não é ouvida, não toca e não tem legenda")


## Chuva: a camada muda ao entrar no quintal (interna no hall, exterior no quintal). Piso 22 e 38 (DATA §2.3).
func test_camada_de_chuva_muda_ao_entrar_no_quintal() -> void:
	var hall: Dictionary = _mark("hall_depois_da_corrida")
	var yard: Dictionary = _mark("quintal_antes_trovao")
	assert_eq(String(hall.get("layer", "")), "rain_interior", "no hall (piso 22) a camada é a interna")
	assert_eq(String(yard.get("layer", "")), "rain_exterior", "no quintal (piso 38) a camada é a exterior")
	assert_almost_eq(float(yard.get("floor", 0.0)), 38.0, 0.01, "piso do quintal = 38 dB")
	var switched: bool = false
	var previous: String = ""
	for row: Dictionary in _roteiro.telemetry:
		var layer: String = String(row["camada_chuva"])
		if previous == "rain_interior" and layer == "rain_exterior":
			switched = true
		previous = layer
	assert_true(switched, "a telemetria mostra a troca de rain_interior para rain_exterior ao atravessar a porta do quintal")


## NOI-05 / NOI-INV-1 no roteiro: todo som tocado pelo roteador vem de um NoiseEvent registrado, e nenhum som do corpo
## do jogador passa pelo roteador.
func test_todo_som_tocado_vem_de_um_evento() -> void:
	var played_ids: Array[int] = []
	for entry: Dictionary in _roteiro.router_log:
		var event_id: int = int(entry["event_id"])
		played_ids.append(event_id)
		assert_false(_event_by_id(event_id).is_empty(), "o som tocado (evento %d) existe no registro de eventos" % event_id)
	var routed: int = 0
	for row: Dictionary in _roteiro.events:
		if bool(row["roteador"]):
			routed += 1
		if BODY_CATEGORIES.has(String(row["categoria"])) and String(row["fonte"]) == "player":
			assert_false(bool(row["roteador"]), "som do corpo (%s, id %d) não passa pelo roteador" % [String(row["categoria"]), int(row["id"])])
	assert_eq(routed, _roteiro.router_log.size(), "cada entrada do roteador corresponde a um evento marcado como tocado")
	assert_eq(played_ids.size(), _roteiro.router_log.size(), "o registro do roteador não perdeu entradas")


## NOI-04 no roteiro: o volume tocado é a regra de NoiseGain sobre o nível percebido, para cada som do mundo.
func test_volume_tocado_segue_a_regra_de_ganho() -> void:
	var checked: int = 0
	for row: Dictionary in _roteiro.events:
		if not bool(row["roteador"]):
			continue
		checked += 1
		var expected: float = NoiseGain.gain_for_db(float(row["perceived_db"]))
		assert_almost_eq(float(row["ganho_db"]), expected, GAIN_TOL_DB,
			"ganho do evento %d (%s) = NoiseGain(perceived_db)" % [int(row["id"]), String(row["som"])])
	assert_true(checked >= 10, "há sons tocados para conferir (%d)" % checked)


## NOI-05: a respiração tem um produtor só. Cada evento de respiração/chiado tem uma inspiração tocada pelo BreathingAudio.
func test_respiracao_tem_produtor_unico_no_roteiro() -> void:
	var body_events: int = 0
	for row: Dictionary in _roteiro.events:
		if String(row["fonte"]) == "player" and (String(row["categoria"]) == "BREATHING" or String(row["categoria"]) == "WHEEZING"):
			body_events += 1
	var inhales: int = 0
	for entry: Dictionary in _roteiro.breathing_log:
		if String(entry["role"]) == "inhale":
			inhales += 1
	note("respirações: %d eventos, %d inspirações tocadas" % [body_events, inhales])
	assert_true(body_events >= 5, "o roteiro gerou respirações (%d)" % body_events)
	assert_true(absi(body_events - inhales) <= 1, "cada respiração tem uma inspiração tocada (eventos %d, inspirações %d)" % [body_events, inhales])


## Legendas (ACC-04): a porta gera a legenda na cena; cada pedido aponta para um evento marcado com legenda.
func test_legendas_de_porta_aparecem() -> void:
	var door_requests: int = 0
	for request: Dictionary in _roteiro.subtitle_requests:
		if String(request["chave"]) == "subtitle.door_normal":
			door_requests += 1
	assert_true(door_requests >= 1, "a porta gerou pedido de legenda (%d)" % door_requests)
	for request: Dictionary in _roteiro.subtitle_requests:
		var event_row: Dictionary = _event_by_id(int(request["evento"]))
		if not event_row.is_empty():
			assert_true(bool(event_row["legenda"]), "pedido %s ligado ao evento %d marcado com legenda" % [String(request["chave"]), int(request["evento"])])


## Telemetria: valores dentro dos limites e sem NaN em todo o roteiro.
func test_telemetria_dentro_dos_limites() -> void:
	for row: Dictionary in _roteiro.telemetry:
		var stress: float = float(row["estresse"])
		var severity: float = float(row["severidade"])
		assert_false(is_nan(stress) or is_nan(severity), "sem NaN no estresse e na severidade (t=%s)" % str(row["t"]))
		assert_true(stress >= 0.0 and stress <= 100.0, "estresse em [0; 100] (%.2f)" % stress)
		assert_true(severity >= 0.0 and severity <= 1.0, "severidade em [0; 1] (%.3f)" % severity)
		assert_true(LAYER_IDS.has(String(row["camada_chuva"])), "camada de chuva conhecida (%s)" % String(row["camada_chuva"]))

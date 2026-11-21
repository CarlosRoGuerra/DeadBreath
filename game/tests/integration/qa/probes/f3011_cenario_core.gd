extends RefCounted
## Nucleo da gravacao F3-011: roda o roteiro (fixtures/f3011_roteiro.gd) e escreve o log de evidencia.

const OUT_DIR: String = "D:/Dev/DeadBreath/Docs/QA/EVIDENCE/"
const PREFIX: String = "F3-011_cenario_"


func start(tree: SceneTree) -> void:
	Settings.autosave = false
	var roteiro: F3011Roteiro = F3011Roteiro.new()
	var container: Node3D = Node3D.new()
	tree.root.add_child(container)
	await roteiro.run(tree, container)
	_write_log(roteiro)
	_write_telemetry(roteiro)
	print("F3-011 cenario: eventos=%d telemetria=%d marcas=%d desvios=%d" % [
		roteiro.events.size(), roteiro.telemetry.size(), roteiro.marks.size(), roteiro.deviations.size()])
	container.queue_free()
	await tree.process_frame
	tree.quit(0)


func _write_log(roteiro: F3011Roteiro) -> void:
	var lines: PackedStringArray = PackedStringArray()
	lines.append("# F3-011 - log do roteiro \"atravessar a casa em silencio\" (sandbox_playable.tscn)")
	lines.append("# Gerado por tests/integration/qa/probes/f3011_cenario.gd (headless, --fixed-fps 60). Tempo = relogio do AcousticWorld.")
	lines.append("# Legenda das colunas de eventos:")
	lines.append("#   t: tempo (s); tick: tick de fisica; fase: etapa do roteiro; controle: rotulo do evento de controle (vazio = do jogo)")
	lines.append("#   categoria/fonte/som: NoiseEvent; sala: room_id na emissao; dB_1m: intensidade a 1 m (DATA 2.1)")
	lines.append("#   perceived_db: nivel no ouvido do jogador (propagate); limiar_db: limiar efetivo do jogador no ouvido")
	lines.append("#   audivel: perceived >= limiar; parede: caminho com parede; portais: portas no caminho")
	lines.append("#   roteador: o NoiseAudioRouter tocou o evento; ganho_db: volume aplicado (NoiseGain); arquivo: clip")
	lines.append("#   legenda: subtitle_requested emitido para o evento; salto_estresse: variacao do estresse no tick do evento")
	lines.append("")
	lines.append("EVENTOS")
	lines.append("t\ttick\tfase\tcontrole\tid\tcategoria\tfonte\tsom\tsala\tdB_1m\tperceived_db\tlimiar_db\taudivel\tparede\tportais\troteador\tganho_db\tarquivo\tlegenda\tsalto_estresse\tpos")
	for row: Dictionary in roteiro.events:
		lines.append("%.3f\t%d\t%s\t%s\t%d\t%s\t%s\t%s\t%s\t%.1f\t%.2f\t%.2f\t%s\t%s\t%s\t%s\t%.2f\t%s\t%s\t%.2f\t%s" % [
			float(row["t"]), int(row["tick"]), str(row["fase"]), str(row["controle"]), int(row["id"]),
			str(row["categoria"]), str(row["fonte"]), str(row["som"]), str(row["sala"]), float(row["dB_1m"]),
			float(row["perceived_db"]), float(row["limiar_db"]), str(row["audivel"]), str(row["parede"]),
			str(row["portais"]), str(row["roteador"]), float(row["ganho_db"]), str(row["arquivo"]),
			str(row["legenda"]), float(row["salto_estresse"]), str(row["pos"])])
	lines.append("")
	lines.append("MARCAS (estado do jogo e do mundo em pontos do roteiro)")
	for mark: Dictionary in roteiro.marks:
		lines.append(JSON.stringify(mark))
	lines.append("")
	lines.append("PEDIDOS DE LEGENDA")
	for request: Dictionary in roteiro.subtitle_requests:
		lines.append(JSON.stringify(request))
	lines.append("")
	lines.append("DESVIOS DO ROTEIRO")
	if roteiro.deviations.is_empty():
		lines.append("nenhum")
	for text: String in roteiro.deviations:
		lines.append(text)
	_save(OUT_DIR + PREFIX + "log.txt", "\n".join(lines) + "\n")


func _write_telemetry(roteiro: F3011Roteiro) -> void:
	var lines: PackedStringArray = PackedStringArray()
	lines.append("t,fase,pos,sala,marcha,postura,estresse,faixa_estresse,severidade,estado_resp,estamina,camada_chuva,piso_db,limiar_ouvido_db,offset_trovao_db,portas")
	for row: Dictionary in roteiro.telemetry:
		lines.append("%.3f,%s,%s,%s,%d,%d,%.2f,%d,%.3f,%d,%.2f,%s,%.1f,%.2f,%.1f,%s" % [
			float(row["t"]), str(row["fase"]), str(row["pos"]), str(row["sala"]), int(row["marcha"]), int(row["postura"]),
			float(row["estresse"]), int(row["faixa"]), float(row["severidade"]), int(row["estado_resp"]),
			float(row["estamina"]), str(row["camada_chuva"]), float(row["piso_db"]), float(row["limiar_ouvido_db"]),
			float(row["offset_trovao_db"]), str(row["portas"])])
	_save(OUT_DIR + PREFIX + "telemetria.csv", "\n".join(lines) + "\n")


func _save(path: String, text: String) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("F3-011: nao foi possivel gravar %s (erro %d)" % [path, FileAccess.get_open_error()])
		return
	file.store_string(text)
	file.close()

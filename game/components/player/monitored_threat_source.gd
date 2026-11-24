class_name MonitoredThreatSource
extends ThreatSource
## MonitoredThreatSource (RefCounted, F4-006b; decisão D4-01): fonte de ameaça que o PlayerRoot usa com o monitor ligado.
## Lê o ThreatSample que o PlayerThreatMonitor atualiza a cada tick. É composição: a fonte não guarda referência ao
## monitor (Node) nem a outro componente do jogador (PLR-INV-1).

var _state: ThreatSample = null


func _init(state: ThreatSample) -> void:
	_state = state if state != null else ThreatSample.new()


## Amostra atual do monitor (só para leitura; a fisiologia não a altera).
func sample() -> ThreatSample:
	return _state

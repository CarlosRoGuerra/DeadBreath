class_name ThreatSource
extends RefCounted
## ThreatSource (COMPONENT_CONTRACTS §5 e §4.3, F2-004): fonte da ameaça percebida pelo jogador.
## Base dos fornecedores de ThreatSample: StubThreatSource (F2/F3) e PlayerThreatMonitor (F4).
##
## DESVIO DO CONTRATO (relatório F2-004, para ratificação do Software Architect): o contrato §5 diz
## `extends Node`. Com base Node, esta classe seria um componente do jogador, e StubThreatSource, que a estende,
## referenciaria outro componente, o que ARC-06 reprova. Por isso a base é RefCounted (dado + método, sem cena).
## A F4 (PlayerThreatMonitor é Node) precisará de decisão de arquitetura sobre a base.


## Ameaça atual. Chamado pelo PlayerRoot uma vez por tick.
func sample() -> ThreatSample:
	return ThreatSample.new()

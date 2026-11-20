class_name StubThreatSource
extends ThreatSource
## StubThreatSource (COMPONENT_CONTRACTS §4.3, F2-004): ameaça definida por quem chama (testes e, na F2-008,
## o overlay de balanceamento). Sem `forced`, a ameaça é zero. Ver ThreatSource sobre a base RefCounted.
## A amostra devolvida é só para leitura (a fisiologia não a altera); a amostra zero é reutilizada a cada tick.

## Amostra devolvida em todo tick. null = ameaça zero.
var forced: ThreatSample = null

var _neutral: ThreatSample = null


func sample() -> ThreatSample:
	if forced != null:
		return forced
	if _neutral == null:
		_neutral = ThreatSample.new()
	return _neutral

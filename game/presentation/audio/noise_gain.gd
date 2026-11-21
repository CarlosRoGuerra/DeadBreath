class_name NoiseGain
extends RefCounted
## NoiseGain (L3, F3-003b; DATA_STRUCTURES §2.4 e §2.1): regra de ganho compartilhada pelo BreathingAudio (corpo do
## jogador) e pelo NoiseAudioRouter (sons do mundo). O ganho é uma função do nível percebido (PropagationResult.
## perceived_db), não da distância ao emissor: é o que torna o volume tocado coerente com o que a IA ouve (NOI-INV-2).
## Regra (decisão do Director na integração da F3-003b):
##   - até a referência (45 dB): ganho = perceived_db − 45, com piso MIN_GAIN_DB (1:1; a mixagem do corpo da F2 não muda);
##   - acima: o ganho sobe 1 dB a cada COMPRESSION_RATIO dB percebidos, até MAX_GAIN_DB.
## Antes, acima de 45 dB tudo saía em 0 dB: porta normal (50), corrida (60), tosse (65) e porta batida (75) soavam
## iguais. Agora a ordem do que a IA ouve se mantém no que o jogador ouve até 69 dB. Acima disso o timbre do clip
## (batida, queda, impacto pesado) diferencia. Os picos dos clips ficam entre −10 e −4 dBFS; o limitador do Master
## (default_bus_layout.tres, teto −1 dBFS) segura o que passar. Constantes ajustáveis no playtest.

## Percepção (dB) que toca em 0 dB de ganho.
const BODY_REFERENCE_DB: float = 45.0
## Piso do ganho (dB): abaixo disso o som fica praticamente mudo.
const MIN_GAIN_DB: float = -45.0
## Acima da referência: dB percebidos por 1 dB de ganho.
const COMPRESSION_RATIO: float = 4.0
## Teto do ganho (dB), alcançado em BODY_REFERENCE_DB + COMPRESSION_RATIO × MAX_GAIN_DB = 69 dB.
const MAX_GAIN_DB: float = 6.0


## Ganho (dB) a partir do nível percebido.
static func gain_for_db(perceived_db: float) -> float:
	var over: float = perceived_db - BODY_REFERENCE_DB
	if over <= 0.0:
		return maxf(over, MIN_GAIN_DB)
	return minf(over / COMPRESSION_RATIO, MAX_GAIN_DB)

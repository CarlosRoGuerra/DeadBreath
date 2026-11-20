class_name BreathParams
extends RefCounted
## BreathParams (L1, DATA_STRUCTURES §1.4 e §2.4; F2-006b). Funções puras: o snapshot da fisiologia entra,
## o período, o nível, a categoria e a família de som saem. Sem cena, sem autoload, sem reflexão.
##
## Decisão sobre sound_id (DATA §2.4 diz "... | wheeze"): sound_id é sempre a família de respiração
## (breath_calm | breath_fast | breath_labored), porque o chiado é uma camada tocada junto do corpo, não o
## lugar do corpo. Com sound_id = wheeze, a inspiração e a expiração sumiriam justamente no chiado.
## O chiado é marcado por category = WHEEZING e wheeze_layer = true.
##
## Encaixe no período (chain_timing): a família é a de maior ciclo nominal com ciclo <= 1,15 × período.
## Assim o pitch fica em [1/1.15, 1.15] (tolerância de ~15 %) e a expiração nunca é cortada. Quando o
## período é mais longo que o ciclo do arquivo, sobra silêncio; o pitch não vai abaixo de 1/1.15.

const RATE_MIN_RPM: float = 14.0
const RATE_MAX_RPM: float = 40.0
const INTENSITY_MIN_DB: float = 20.0
const INTENSITY_MAX_DB: float = 35.0
const WHEEZE_THRESHOLD: float = 0.1
const WHEEZE_MIN_DB: float = 30.0
const WHEEZE_MAX_DB: float = 42.0
## Aviso de tosse: 1,5 s antes da tosse (DATA §1.4, RespiratoryConfig.cough_warning_time_s).
const COUGH_WARNING_S: float = 1.5
const PITCH_MAX: float = 1.15
const PITCH_MIN: float = 1.0 / 1.15
const FIT_MAX_RATIO: float = 1.15

## Famílias de respiração: duração nominal de inspiração e expiração (s), iguais a
## game/content/audio/body/manifest.json. O teste test_breath_chain_manifest confere os valores.
const FAMILY_TABLE: Dictionary = {
	&"breath_calm": {"inhale_s": 1.9, "exhale_s": 2.3},
	&"breath_fast": {"inhale_s": 0.75, "exhale_s": 0.95},
	&"breath_labored": {"inhale_s": 0.8, "exhale_s": 1.4},
}
## Ordem de desempate: a família de maior ciclo que cabe no período vem primeiro.
const FAMILY_ORDER: Array[StringName] = [&"breath_calm", &"breath_labored", &"breath_fast"]

var period_s: float = 0.0
var intensity_db: float = 0.0
var category: Enums.NoiseCategory = Enums.NoiseCategory.BREATHING
var sound_id: StringName = &"breath_calm"
var wheeze_layer: bool = false
var wheezing_intensity: float = 0.0
var respiratory_state: Enums.RespiratoryState = Enums.RespiratoryState.NORMAL


## Parâmetros do ciclo atual. snapshot nulo usa os valores padrão do snapshot (repouso, 14 rpm).
static func from_snapshot(snapshot: PhysiologySnapshot) -> BreathParams:
	var source: PhysiologySnapshot = snapshot if snapshot != null else PhysiologySnapshot.new()
	var params: BreathParams = BreathParams.new()
	var rate: float = clampf(source.breathing_rate, RATE_MIN_RPM, RATE_MAX_RPM)
	params.period_s = 60.0 / rate
	params.intensity_db = lerpf(INTENSITY_MIN_DB, INTENSITY_MAX_DB, (rate - RATE_MIN_RPM) / (RATE_MAX_RPM - RATE_MIN_RPM))
	params.wheezing_intensity = clampf(source.wheezing_intensity, 0.0, 1.0)
	params.respiratory_state = source.respiratory_state
	var prefer_labored: bool = params.respiratory_state == Enums.RespiratoryState.LABORED \
		or params.respiratory_state == Enums.RespiratoryState.SYMPTOMATIC
	params.sound_id = family_for_period(params.period_s, prefer_labored)
	if params.wheezing_intensity > WHEEZE_THRESHOLD:
		params.category = Enums.NoiseCategory.WHEEZING
		params.wheeze_layer = true
		params.intensity_db = maxf(params.intensity_db,
			lerpf(WHEEZE_MIN_DB, WHEEZE_MAX_DB, params.wheezing_intensity))
	return params


## Família que cabe no período: a de maior ciclo nominal com ciclo <= FIT_MAX_RATIO × período.
## Com prefer_labored (estado LABORED ou SYMPTOMATIC), a família ofegante vence se também couber.
static func family_for_period(period_s_value: float, prefer_labored: bool) -> StringName:
	var fits: Array[StringName] = []
	for family: StringName in FAMILY_ORDER:
		if cycle_nominal_s(family) <= period_s_value * FIT_MAX_RATIO:
			fits.append(family)
	if fits.is_empty():
		return &"breath_fast"
	if prefer_labored and fits.has(&"breath_labored"):
		return &"breath_labored"
	return fits[0]


## Ciclo nominal (inspiração + expiração) de uma família; 0.0 se o sound_id não for de respiração.
static func cycle_nominal_s(sound_id_value: StringName) -> float:
	if not FAMILY_TABLE.has(sound_id_value):
		return 0.0
	var family: Dictionary = FAMILY_TABLE[sound_id_value]
	return float(family["inhale_s"]) + float(family["exhale_s"])


## Encaixe de uma família no período. Chaves:
##   inhale_s, exhale_s: duração tocada de cada fase (nominal / pitch_scale);
##   pitch_scale: nominal / período, limitado a [1/1.15, 1.15];
##   silence_s: silêncio até o próximo ciclo (>= 0);
##   overlap_s: quanto a expiração passaria do período (0 quando a família cabe; só ocorre se o período
##   for menor que nominal / 1.15, o que a escolha de família evita).
## Vazio se o sound_id não for de respiração ou se o período não for positivo.
static func chain_timing(sound_id_value: StringName, period_s_value: float) -> Dictionary:
	if not FAMILY_TABLE.has(sound_id_value) or period_s_value <= 0.0:
		return {}
	var family: Dictionary = FAMILY_TABLE[sound_id_value]
	var nominal: float = cycle_nominal_s(sound_id_value)
	var pitch: float = clampf(nominal / period_s_value, PITCH_MIN, PITCH_MAX)
	var inhale: float = float(family["inhale_s"]) / pitch
	var exhale: float = float(family["exhale_s"]) / pitch
	return {
		"inhale_s": inhale,
		"exhale_s": exhale,
		"pitch_scale": pitch,
		"silence_s": maxf(0.0, period_s_value - inhale - exhale),
		"overlap_s": maxf(0.0, inhale + exhale - period_s_value),
	}

class_name PlayerNoiseMap
extends RefCounted
## PlayerNoiseMap (L2, F3-004): traduz o estado do jogador e dos objetos em chaves de NoiseLevels (DATA §2.1) e em
## sound_id. Funções puras, sem cena (testáveis direto).
## Marcha (contrato F3-003b): rastejar = crawl, agachado = crouch, andando devagar = slow, andando = walk.
## Superfície: o metadado do nível é "wood", "carpet", "tile" ou "concrete"; "wood" é madeira solta para o nível de
## ruído (wood_loose, +6 dB, o mesmo offset do roteador de áudio). Sem metadado ("default") ou desconhecida: concrete
## (0 dB, mesmo que o roteador já usa para a superfície desconhecida). sound_id = footstep_<superfície do nível>.

const DEFAULT_SURFACE: StringName = &"default"
const FALLBACK_SURFACE: StringName = &"concrete"
## Susto (COMPONENT_CONTRACTS §6.5): a partir de 55 dB percebidos, add_startle(clamp((dB - 55)/2 + 10, 10, 25)).
const STARTLE_THRESHOLD_DB: float = 55.0
const STARTLE_BASE: float = 10.0
const STARTLE_DIVISOR: float = 2.0
const STARTLE_MIN: float = 10.0
const STARTLE_MAX: float = 25.0
## Impacto de objeto: abaixo de MIN_SPEED não faz ruído; acima de MAX a velocidade já está no teto da faixa.
const IMPACT_MIN_SPEED_MS: float = 0.8
const IMPACT_MAX_SPEED_MS: float = 8.0
const IMPACT_COOLDOWN_S: float = 0.25
const SIZE_LIGHT: StringName = &"light"
const SIZE_MEDIUM: StringName = &"medium"
const SIZE_HEAVY: StringName = &"heavy"


## Chave de marcha do NoiseLevels para um passo. Stance tem prioridade: rastejar e agachado valem em qualquer marcha.
static func footstep_gait(gait: Enums.Gait, stance: Enums.Stance) -> StringName:
	if stance == Enums.Stance.CRAWL:
		return &"crawl"
	if stance == Enums.Stance.CROUCH:
		return &"crouch"
	if gait == Enums.Gait.SLOW:
		return &"slow"
	return &"walk"


## Superfície do nível para o NoiseLevels (intensidade).
static func level_surface(surface: StringName) -> StringName:
	if surface == &"wood":
		return &"wood_loose"
	if surface == &"carpet" or surface == &"tile" or surface == &"concrete":
		return surface
	return FALLBACK_SURFACE


## Superfície para o sound_id (nomes dos arquivos de footstep_<superfície>_<marcha>).
static func sound_surface(surface: StringName) -> StringName:
	if surface == &"wood" or surface == &"carpet" or surface == &"tile" or surface == &"concrete":
		return surface
	return FALLBACK_SURFACE


static func footstep_sound(surface: StringName) -> StringName:
	return StringName("footstep_" + String(sound_surface(surface)))


## Intensidade do susto (COMPONENT_CONTRACTS §6.5). Só faz sentido para perceived_db >= STARTLE_THRESHOLD_DB.
static func startle_amount(perceived_db: float) -> float:
	return clampf((perceived_db - STARTLE_THRESHOLD_DB) / STARTLE_DIVISOR + STARTLE_BASE, STARTLE_MIN, STARTLE_MAX)


## Fator do tamanho do objeto: 0 leve, 0,5 médio, 1 pesado. Tamanho desconhecido: médio.
static func size_factor(size: StringName) -> float:
	if size == SIZE_LIGHT:
		return 0.0
	if size == SIZE_HEAVY:
		return 1.0
	return 0.5


## Intensidade do impacto (dB a 1 m) pela velocidade e pelo tamanho, dentro de range_db (NoiseLevels.object_impact_range_db).
static func impact_db(speed_ms: float, size: StringName, range_db: Vector2) -> float:
	var speed_t: float = clampf((speed_ms - IMPACT_MIN_SPEED_MS) / (IMPACT_MAX_SPEED_MS - IMPACT_MIN_SPEED_MS), 0.0, 1.0)
	var t: float = 0.5 * speed_t + 0.5 * size_factor(size)
	return lerpf(range_db.x, range_db.y, t)


static func impact_is_audible(speed_ms: float) -> bool:
	return speed_ms >= IMPACT_MIN_SPEED_MS

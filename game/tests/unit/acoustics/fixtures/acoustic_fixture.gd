extends RefCounted
## Fixture do AcousticGraph (F3-001): geometria, eventos e medição de alcance para os testes de acústica.
## Pasta fixtures: o runner não a descobre. Os testes a carregam por preload. Autor: AI Engineer (F3-001).

const CONFIG_PATH: String = "res://content/data/acoustics/acoustic_config.tres"
## Perfil Observer (AIProfile, DATA §3.1): hearing_threshold_db 15, masking_margin_db −3.
const OBSERVER_HEARING_DB: float = 15.0
const OBSERVER_MARGIN_DB: float = -3.0
## Ouvinte do jogador (DATA §2.3): hearing_threshold_db 10, margem 0.
const PLAYER_HEARING_DB: float = 10.0
const PLAYER_MARGIN_DB: float = 0.0
const BISECTION_STEPS: int = 60


## Config de produção (content/data/acoustics/acoustic_config.tres).
static func production_config() -> AcousticConfig:
	return load(CONFIG_PATH) as AcousticConfig


## AABB pelos limites de cada eixo.
static func box(x0: float, x1: float, y0: float, y1: float, z0: float, z1: float) -> AABB:
	return AABB(Vector3(x0, y0, z0), Vector3(x1 - x0, y1 - y0, z1 - z0))


## NoiseEvent de teste: categoria BREATHING, fonte &"test_source".
static func event(intensity_db: float, at: Vector3) -> NoiseEvent:
	return NoiseEvent.create(Enums.NoiseCategory.BREATHING, at, intensity_db, 1.0, &"test_source", &"breath_calm")


## Perda por distância escrita de novo no teste, independente da implementação (DATA §2.2):
## 20·log10(max(d; 1)) + 0,1·d.
static func distance_loss_db(length_m: float) -> float:
	return 20.0 * log(maxf(length_m, 1.0)) / log(10.0) + 0.1 * length_m


## Audível ⇔ nível percebido ≥ limiar efetivo do ouvinte (DATA §2.3).
static func audible_at(graph: AcousticGraph, sound: NoiseEvent, listener: Vector3,
		hearing_db: float, margin_db: float) -> bool:
	var perceived: float = graph.propagate(sound, listener).perceived_db
	return perceived >= graph.effective_threshold_db(listener, hearing_db, margin_db)


## Maior distância (m) em linha reta a partir da fonte, na direção +X, em que o som é audível.
## 0,0 se nem na própria fonte; limit_m se ainda audível nesse limite. Bisseção de BISECTION_STEPS passos.
static func max_audible_m(graph: AcousticGraph, sound: NoiseEvent, hearing_db: float, margin_db: float,
		limit_m: float) -> float:
	var source: Vector3 = sound.position
	if not audible_at(graph, sound, source, hearing_db, margin_db):
		return 0.0
	if audible_at(graph, sound, source + Vector3(limit_m, 0.0, 0.0), hearing_db, margin_db):
		return limit_m
	var low: float = 0.0
	var high: float = limit_m
	for _step: int in range(BISECTION_STEPS):
		var middle: float = 0.5 * (low + high)
		if audible_at(graph, sound, source + Vector3(middle, 0.0, 0.0), hearing_db, margin_db):
			low = middle
		else:
			high = middle
	return low

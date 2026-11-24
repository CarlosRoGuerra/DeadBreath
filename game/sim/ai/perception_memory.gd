class_name PerceptionMemory
extends RefCounted
## PerceptionMemory (L1, COMPONENT_CONTRACTS §8.2; F4-003): pistas que o inimigo guarda enquanto investiga e procura.
##
## Decaimento: todas as pistas perdem confiança à mesma taxa (memory_confidence_decay_per_s do AIProfile).
## Uma pista com confiança ≤ 0 sai da memória.
## Fusão: uma pista nova da mesma origem a até MERGE_RADIUS_M de uma existente substitui a antiga (posição, instante
## e confiança). Assim, uma visão contínua do jogador ocupa uma só entrada, não uma por tick.
## Capacidade: MAX_RECORDS. Ao estourar, sai a de menor confiança.
##
## best_lead (critério): pistas com confiança ≥ USEFUL_MIN_CONFIDENCE são úteis. Entre as úteis, vence a de maior
## confiança; em empate, a mais recente. A confiança já incorpora a idade (o decaimento é uniforme), então esse critério
## é "mais confiável e recente" sem pesos extras.

const MAX_RECORDS: int = 8
const MERGE_RADIUS_M: float = 1.0
const USEFUL_MIN_CONFIDENCE: float = 0.1

var _records: Array[PerceptionRecord] = []
var _decay_per_s: float = 0.0


func _init(confidence_decay_per_s: float) -> void:
	_decay_per_s = maxf(confidence_decay_per_s, 0.0)


## Guarda uma pista (ou funde com a existente, da mesma origem, a até MERGE_RADIUS_M).
func record(entry: PerceptionRecord) -> void:
	for index: int in range(_records.size()):
		var existing: PerceptionRecord = _records[index]
		if existing.source == entry.source and _horizontal_distance(existing.position, entry.position) <= MERGE_RADIUS_M:
			_records[index] = entry
			return
	_records.append(entry)
	if _records.size() > MAX_RECORDS:
		_drop_weakest()


## Passa dt segundos: subtrai a confiança de todas as pistas e remove as que chegaram a zero.
func decay(dt: float) -> void:
	var loss: float = _decay_per_s * maxf(dt, 0.0)
	for index: int in range(_records.size() - 1, -1, -1):
		var entry: PerceptionRecord = _records[index]
		entry.confidence -= loss
		if entry.confidence <= 0.0:
			_records.remove_at(index)


## A pista útil mais confiável e, em empate, a mais recente. null se não houver pista útil.
func best_lead() -> PerceptionRecord:
	var best: PerceptionRecord = null
	for entry: PerceptionRecord in _records:
		if entry.confidence < USEFUL_MIN_CONFIDENCE:
			continue
		if best == null or entry.confidence > best.confidence \
				or (entry.confidence == best.confidence and entry.timestamp > best.timestamp):
			best = entry
	return best


func clear() -> void:
	_records.clear()


func count() -> int:
	return _records.size()


func _drop_weakest() -> void:
	var weakest: int = 0
	for index: int in range(1, _records.size()):
		if _records[index].confidence < _records[weakest].confidence:
			weakest = index
	_records.remove_at(weakest)


static func _horizontal_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()

class_name BreathEmitter
extends Node3D
## BreathEmitter (L2, COMPONENT_CONTRACTS §6.3, F2-006b): produtor único dos sons do corpo do jogador. Cada ciclo
## respiratório vira um NoiseEvent (BREATHING, ou WHEEZING quando há chiado); tosse, aviso de tosse, gasp de susto
## e o puff da bombinha também passam por aqui. Ninguém mais emite som do corpo (NOI-INV-1 e §14).
## Não conhece outros componentes do jogador (ARC-06): recebe o PhysiologySnapshot como argumento de step().
## Acha o AcousticWorld pelo grupo "acoustic_world". Sem mundo, não emite e registra Log.warn uma vez.
## Ordem no tick do PlayerRoot: physiology.step → breath_emitter.step(dt, physiology.get_snapshot()).

const LOG_CATEGORY: StringName = &"acoustics"
const SOURCE_ID: StringName = &"player"
const WORLD_GROUP: StringName = &"acoustic_world"

## Gasp de susto: respiração de 42 dB (DATA §2.1, BREATHING; COMPONENT_CONTRACTS §6.3).
const GASP_DB: float = 42.0
const GASP_DURATION_S: float = 1.2
const GASP_SOUND: StringName = &"gasp"
## Aviso de tosse: 32 dB. É pigarro e garganta fechando, não a tosse. Fica perto do ofegar (30 a 35 dB, §2.4),
## então se ouve de perto mas não chama a atenção de longe (a tosse, 65 dB, chama). Duração = seconds_until.
const COUGH_WARNING_DB: float = 32.0
const COUGH_WARNING_SOUND: StringName = &"cough_warning"
## Tosse: 65 dB (DATA §2.1, COUGHING). Tosse cancelada no aviso não faz som (ver emit_cough).
const COUGH_DB: float = 65.0
const COUGH_DURATION_S: float = 1.0
const COUGH_SOUND: StringName = &"cough"

var _cycle_phase_s: float = 0.0
var _period_s: float = 0.0
var _has_cycle: bool = false
var _cycles_emitted: int = 0
var _warned_no_world: bool = false


## Um tick. A fase avança com dt; quando chega ao período do ciclo atual, emite um NoiseEvent e segue com o resto.
## O primeiro tick sempre emite (início do ciclo). A fase carrega o período novo quando a fisiologia muda.
func step(dt: float, snapshot: PhysiologySnapshot) -> void:
	var params: BreathParams = BreathParams.from_snapshot(snapshot)
	_period_s = params.period_s
	if not _has_cycle:
		_has_cycle = true
		_cycle_phase_s = 0.0
		_emit_cycle(params)
		return
	_cycle_phase_s += dt
	if _cycle_phase_s >= params.period_s:
		_cycle_phase_s -= params.period_s
		_emit_cycle(params)


## Gasp de susto (PhysiologyComponent.startle_gasp). Não altera a fase do ciclo.
func emit_gasp() -> void:
	_emit(Enums.NoiseCategory.BREATHING, GASP_DB, GASP_DURATION_S, GASP_SOUND)


## Aviso de tosse (PhysiologyComponent.cough_warning(seconds_until)).
func emit_cough_warning(seconds_until: float = BreathParams.COUGH_WARNING_S) -> void:
	_emit(Enums.NoiseCategory.COUGHING, COUGH_WARNING_DB, seconds_until, COUGH_WARNING_SOUND)


## Tosse (PhysiologyComponent.coughed(suppressed)). suppressed = true significa que a tosse foi cancelada no aviso
## (a severidade caiu); então não há som, porque a tosse não aconteceu. A versão abafada de 48 dB depende de P-01.
func emit_cough(suppressed: bool = false) -> void:
	if suppressed:
		Log.debug(LOG_CATEGORY, "tosse cancelada no aviso; nenhum som do corpo")
		return
	_emit(Enums.NoiseCategory.COUGHING, COUGH_DB, COUGH_DURATION_S, COUGH_SOUND)


## Som pontual do corpo com categoria e nível explícitos (ex.: puff da bombinha, MEDICATION 38 dB).
func emit_body_sound(category: Enums.NoiseCategory, intensity_db: float, sound_id: StringName,
		duration_s: float = 0.0) -> void:
	_emit(category, intensity_db, duration_s, sound_id)


## Segundos até o próximo ciclo (0 antes do primeiro tick).
func next_event_in_s() -> float:
	if not _has_cycle:
		return 0.0
	return maxf(0.0, _period_s - _cycle_phase_s)


func cycle_phase_s() -> float:
	return _cycle_phase_s


func cycles_emitted() -> int:
	return _cycles_emitted


func to_dict() -> Dictionary:
	return {
		"cycle_phase_s": _cycle_phase_s,
		"next_event_in_s": next_event_in_s(),
		"period_s": _period_s,
		"has_cycle": _has_cycle,
	}


## Restaura a fase e o período sem emitir (estado carregado não é um acontecimento).
func from_dict(data: Dictionary) -> void:
	_cycle_phase_s = float(data.get("cycle_phase_s", 0.0))
	_period_s = float(data.get("period_s", 0.0))
	_has_cycle = bool(data.get("has_cycle", false))


func _emit_cycle(params: BreathParams) -> void:
	var category: Enums.NoiseCategory = Enums.NoiseCategory.WHEEZING if params.wheeze_layer \
		else Enums.NoiseCategory.BREATHING
	if _emit(category, params.intensity_db, params.period_s, params.sound_id):
		_cycles_emitted += 1


## Cria o NoiseEvent e o entrega ao AcousticWorld. Retorna false se não há mundo.
func _emit(category: Enums.NoiseCategory, intensity_db: float, duration_s: float, sound_id: StringName) -> bool:
	var world: AcousticWorld = _find_world()
	if world == null:
		_warn_no_world()
		return false
	var event: NoiseEvent = NoiseEvent.create(category, global_position, intensity_db, duration_s, SOURCE_ID, sound_id)
	world.emit_noise(event)
	return true


func _find_world() -> AcousticWorld:
	if not is_inside_tree():
		return null
	return get_tree().get_first_node_in_group(WORLD_GROUP) as AcousticWorld


func _warn_no_world() -> void:
	if _warned_no_world:
		return
	_warned_no_world = true
	Log.warn(LOG_CATEGORY, "BreathEmitter sem AcousticWorld no grupo 'acoustic_world'; sons do corpo não são emitidos")

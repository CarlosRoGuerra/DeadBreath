class_name HearingSensor
extends Node3D
## HearingSensor (L2, COMPONENT_CONTRACTS §7.2; DATA_STRUCTURES §2.3; F4-002): audição da IA. Grupo "hearing_sensor".
## Só o AcousticWorld entrega sons (receive; NOI-01). O EnemyController os retira no seu tick (drain).
## O limiar efetivo é calculado pelo AcousticWorld com hearing_threshold_db e masking_margin_db (DATA §2.3, com o piso
## da sala e o clima). Os valores padrão são os do OBSERVER (DATA §3.1); o controlador os copia do perfil (F4-004).
## A fila é limitada: se ninguém drena, descarta o som mais antigo e avisa uma vez.
## Autor: AI Engineer (F4-002).

const GROUP: StringName = &"hearing_sensor"
const LOG_CATEGORY: StringName = &"perception"
const MAX_PENDING: int = 64

## Dono do sensor. O AcousticWorld não entrega a este sensor os sons cuja fonte tem este id (o próprio som).
@export var owner_id: StringName = &""
@export var hearing_threshold_db: float = 15.0
@export var masking_margin_db: float = -3.0

var _pending: Array[HeardNoise] = []
var _warned_overflow: bool = false


func _ready() -> void:
	add_to_group(GROUP)


## Entrega um som audível para este sensor. Chamado somente pelo AcousticWorld (NOI-01).
func receive(heard: HeardNoise) -> void:
	if heard == null:
		return
	_pending.append(heard)
	if _pending.size() > MAX_PENDING:
		_pending.remove_at(0)
		if not _warned_overflow:
			_warned_overflow = true
			Log.warn(LOG_CATEGORY, "HearingSensor '%s': fila cheia; sons mais antigos descartados" % [name])


## Devolve os sons recebidos desde o último drain, na ordem de chegada, e esvazia a fila.
func drain() -> Array[HeardNoise]:
	var out: Array[HeardNoise] = _pending
	_pending = []
	_warned_overflow = false
	return out

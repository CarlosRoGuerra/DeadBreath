class_name AcousticWorld
extends Node
## AcousticWorld (L2, COMPONENT_CONTRACTS §6.2 e §6.4, F2-006b): mundo acústico do nível, um por nível, no grupo
## "acoustic_world". Recebe NoiseEvents por emit_noise, resolve cada um no tick de prioridade -60 e emite
## noise_resolved_for_player(event, result) para todo evento. Na F2 a propagação é só por distância até o ouvido
## do jogador (AcousticPropagation.perceive). Não há HearingSensor nem PlayerThreatMonitor até a F3.
## Invariantes desta fase: NOI-INV-1 (o único caminho para a IA é emit_noise; o NoiseEvent não é entregue
## fora daqui) e NOI-INV-3 (a propagação é pura e determinística).

signal noise_resolved_for_player(event: NoiseEvent, result: PropagationResult)

const GROUP: StringName = &"acoustic_world"
const PROCESS_PRIORITY: int = -60
const LOG_CATEGORY: StringName = &"acoustics"

var _queue: Array[NoiseEvent] = []
var _ear: Node3D = null
var _clock_s: float = 0.0
var _next_id: int = 1
var _warned_no_listener: bool = false


func _ready() -> void:
	add_to_group(GROUP)
	process_physics_priority = PROCESS_PRIORITY


func _physics_process(delta: float) -> void:
	advance(delta)


## Um tick do mundo: avança o relógio e resolve a fila. O tick de física chama isto; os testes chamam direto.
func advance(delta: float) -> void:
	_clock_s += delta
	flush()


## Tempo do mundo (s), avançado no tick de física. Os timestamps dos eventos usam este relógio.
func now() -> float:
	return _clock_s


## Ouvido do jogador: o ponto onde os sons são percebidos (a câmera). Sem ouvido definido, usa a câmera ativa da
## viewport; sem câmera, a origem, com um aviso.
func set_player_ear(ear: Node3D) -> void:
	_ear = ear


## Enfileira um NoiseEvent. O id e o timestamp são atribuídos aqui. Resolvido no próximo tick (-60).
func emit_noise(event: NoiseEvent) -> void:
	if event == null:
		Log.error(LOG_CATEGORY, "emit_noise sem NoiseEvent; nada enfileirado")
		return
	if event.id == 0:
		event.id = _next_id
		_next_id += 1
	event.timestamp = _clock_s
	_queue.append(event)


func pending_count() -> int:
	return _queue.size()


## Resolve a fila agora. Chamado pelo tick de física; os testes podem chamar direto para determinismo.
func flush() -> void:
	if _queue.is_empty():
		return
	var listener: Vector3 = _listener_position()
	var batch: Array[NoiseEvent] = []
	batch.append_array(_queue)
	_queue.clear()
	for event: NoiseEvent in batch:
		var result: PropagationResult = AcousticPropagation.perceive(event, listener)
		noise_resolved_for_player.emit(event, result)


func _listener_position() -> Vector3:
	if _ear != null and is_instance_valid(_ear):
		return _ear.global_position
	if is_inside_tree() and get_viewport() != null:
		var camera: Camera3D = get_viewport().get_camera_3d()
		if camera != null:
			return camera.global_position
	if not _warned_no_listener:
		_warned_no_listener = true
		Log.warn(LOG_CATEGORY, "AcousticWorld sem ouvido do jogador nem câmera ativa; propagando a partir da origem")
	return Vector3.ZERO

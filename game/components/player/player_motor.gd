class_name PlayerMotor
extends Node
## PlayerMotor (L2, Gameplay Engineer, F1-006): movimento, posturas, colisor cilíndrico, step-up,
## mouse look, head bob, footstep e landed.
## Contrato: COMPONENT_CONTRACTS §2 (com o Complemento v1.0). Parâmetros: DATA_STRUCTURES §1.1.
## O PlayerRoot chama step(dt) e depois apply_limits(); o motor não tem _physics_process próprio.
## Dependências proibidas: fisiologia, IA, áudio e PlayerRoot (PLR-INV-1, ARC-06).
## Só conhece o corpo e a cabeça recebidos em setup().

signal stance_changed(old: Enums.Stance, new: Enums.Stance)
signal footstep(surface: StringName, gait: Enums.Gait, stance: Enums.Stance)
signal landed(fall_speed: float)

const LOG_CATEGORY: StringName = &"player"
const DEFAULT_SURFACE: StringName = &"default"
## Metadado no nó do piso (StaticBody3D etc.) que informa a superfície para os passos.
const SURFACE_META: StringName = &"surface"
## Normal mínima para tratar a superfície como chão (cos 45°, igual ao floor_max_angle padrão).
const FLOOR_NORMAL_MIN_Y: float = 0.7
## Camadas de mundo com que o corpo colide: world_static (1) e world_dynamic (2).
const WORLD_MASK: int = 3
## Sondagem curta para saber se o corpo começa apoiado.
const FLOOR_PROBE_M: float = 0.05
## Folga para o corpo passar por cima de um degrau de exatamente step_height: sem ela, o topo do
## degrau toca a base elevada e a sondagem horizontal acusa colisão. Degraus de 0,31 m continuam bloqueados.
const STEP_CLEARANCE_M: float = 0.002
## Sondagem do degrau: o corpo é cilíndrico (base plana), então basta alcançar a borda do degrau seguinte
## com uma folga pequena além do deslocamento do tick. Sondar 0,27 m à frente pegava degraus de dois níveis.
const STEP_PROBE_EXTRA_M: float = 0.03
## Velocidade de aderência usada no move_and_slide de assentamento (m/s, para baixo, sem movimento horizontal).
const GROUND_STICK_SPEED_MS: float = 1.0
## Deslocamento da sondagem do assentamento no sentido do movimento (m). Ver _settle_on_ground.
const SETTLE_PROBE_SHIFT_M: float = 0.0025
## Avanço horizontal extra no instante em que o degrau é subido. O movimento do tick termina exatamente com a borda
## frontal sobre a quina do degrau novo; sem folga, a sobreposição é zero e o tick fica sem chão (BUG-001).
## A sondagem já garante que este trecho está livre na altura de subida.
const STEP_FORWARD_EXTRA_M: float = 0.03
## Folga para consultas de teto e de piso (evita contato com o próprio chão).
const MOVE_EPSILON: float = 0.0001
## Velocidade com que o head bob acompanha a velocidade (1/s).
const BOB_RATE_PER_S: float = 4.0
## Movimento para a frente acima deste valor conta como "para a frente" (exigido pelo sprint).
const FORWARD_THRESHOLD: float = 0.5
## Esforço por marcha e postura (MOT-INV-2; DATA_STRUCTURES §1.1).
const EXERTION_SLOW: float = 0.1
const EXERTION_WALK: float = 0.2
const EXERTION_SPRINT: float = 1.0
const EXERTION_CROUCH_MOVING: float = 0.15
const EXERTION_CRAWL_MOVING: float = 0.25

## Parâmetros. Sem config, usa os padrões do código e registra Log.error.
@export var config: PlayerMotorConfig

var _body: CharacterBody3D = null
var _head: Node3D = null
var _shape_node: CollisionShape3D = null
var _shape: CylinderShape3D = null
var _stance: Enums.Stance = Enums.Stance.STAND
var _gait: Enums.Gait = Enums.Gait.IDLE
var _exertion: float = 0.0
var _horizontal_speed: float = 0.0
var _scripted: MotorInput = null
var _input_locked: bool = false
var _sprint_multiplier: float = 1.0
var _sprint_allowed: bool = true
var _pending_crouch: bool = false
var _pending_crawl: bool = false
var _pending_look: Vector2 = Vector2.ZERO
var _pitch_deg: float = 0.0
var _was_on_floor: bool = false
var _first_step: bool = true
var _stride_distance: float = 0.0
var _bob_phase: float = 0.0
var _bob_strength: float = 0.0
var _eye_height: float = 0.0
var _step_visual_offset: float = 0.0
var _config_warned: bool = false
var _default_mask: int = 0
var _noclip: bool = false


func _ready() -> void:
	_cfg()


# ---- Funções puras (testáveis sem cena) ----

## Esforço instantâneo por marcha e postura (MOT-INV-2). Parado = 0.
static func exertion_for(gait: Enums.Gait, stance: Enums.Stance) -> float:
	if gait == Enums.Gait.IDLE:
		return 0.0
	if stance == Enums.Stance.CRAWL:
		return EXERTION_CRAWL_MOVING
	if stance == Enums.Stance.CROUCH:
		return EXERTION_CROUCH_MOVING
	if gait == Enums.Gait.SLOW:
		return EXERTION_SLOW
	if gait == Enums.Gait.SPRINT:
		return EXERTION_SPRINT
	return EXERTION_WALK


## Velocidade-alvo em m/s. O multiplicador do sprint só vale para o sprint.
static func speed_for(gait: Enums.Gait, stance: Enums.Stance, cfg: PlayerMotorConfig, sprint_multiplier: float) -> float:
	if gait == Enums.Gait.IDLE:
		return 0.0
	if stance == Enums.Stance.CRAWL:
		return cfg.crawl_speed
	if stance == Enums.Stance.CROUCH:
		return cfg.crouch_speed
	if gait == Enums.Gait.SLOW:
		return cfg.slow_walk_speed
	if gait == Enums.Gait.SPRINT:
		return cfg.sprint_speed * sprint_multiplier
	return cfg.walk_speed


## Distância de uma passada em metros.
static func stride_for(gait: Enums.Gait, stance: Enums.Stance, cfg: PlayerMotorConfig) -> float:
	if stance == Enums.Stance.CRAWL:
		return cfg.stride_crawl
	if stance == Enums.Stance.CROUCH:
		return cfg.stride_crouch
	if gait == Enums.Gait.SLOW:
		return cfg.stride_slow
	if gait == Enums.Gait.SPRINT:
		return cfg.stride_sprint
	return cfg.stride_walk


# ---- API do contrato ----

## Injetado pelo PlayerRoot. Cria o colisor próprio (a cena compartilha sub-recursos) e posiciona a cabeça.
func setup(body: CharacterBody3D, head: Node3D) -> void:
	var cfg: PlayerMotorConfig = _cfg()
	var shape_node: CollisionShape3D = _find_collision_shape(body)
	if shape_node == null:
		Log.error(LOG_CATEGORY, "o corpo '%s' não tem CollisionShape3D; PlayerMotor fica inerte" % body.name)
		return
	var shape: CylinderShape3D = null
	var declared: CylinderShape3D = shape_node.shape as CylinderShape3D
	if declared != null:
		shape = declared.duplicate() as CylinderShape3D
	else:
		shape = CylinderShape3D.new()
		Log.warn(LOG_CATEGORY, "o colisor de '%s' não é CylinderShape3D; substituído por um cilindro" % body.name)
	shape.radius = cfg.capsule_radius
	shape.height = cfg.stand_height
	shape_node.shape = shape
	_body = body
	_head = head
	_shape_node = shape_node
	_shape = shape
	_stance = Enums.Stance.STAND
	_apply_collider_height(cfg.stand_height)
	_body.floor_snap_length = cfg.floor_snap_length
	_body.up_direction = Vector3.UP
	_default_mask = _body.collision_mask
	_eye_height = _eye_target()
	_first_step = true
	_was_on_floor = false
	if _head != null:
		_head.position.y = _eye_height


## Um tick de movimento. Amostra o input, aplica look, posturas, física, passos e visual.
func step(dt: float) -> void:
	if _body == null or not _body.is_inside_tree():
		return
	var cfg: PlayerMotorConfig = _cfg()
	if _first_step:
		_first_step = false
		_was_on_floor = _probe_floor()
	var input: MotorInput = _sample_input()
	_apply_look(input.look_delta)
	_apply_stance_commands(input)
	var move: Vector2 = input.move.limit_length(1.0)
	var gait: Enums.Gait = _resolve_gait(input, move)
	_gait = gait
	if _noclip:
		_step_noclip(dt, move, gait, cfg)
		return
	var grounded: bool = _was_on_floor
	var start: Vector3 = _body.global_position
	var target: Vector3 = _target_velocity(move, gait, cfg)
	var velocity: Vector3 = _body.velocity
	var planar: Vector2 = Vector2(velocity.x, velocity.z)
	var target_planar: Vector2 = Vector2(target.x, target.z)
	var rate: float = cfg.acceleration if target_planar.length_squared() > MOVE_EPSILON else cfg.deceleration
	planar = planar.move_toward(target_planar, rate * dt)
	velocity.x = planar.x
	velocity.z = planar.y
	if grounded:
		velocity.y = 0.0
	else:
		velocity.y -= cfg.gravity * dt
	var fall_speed: float = maxf(0.0, -velocity.y)
	if grounded and planar.length_squared() > MOVE_EPSILON:
		_try_step_up(Vector3(velocity.x, 0.0, velocity.z) * dt)
	_body.velocity = velocity
	_body.move_and_slide()
	var now_grounded: bool = _body.is_on_floor()
	if grounded and not now_grounded:
		_settle_on_ground(Vector3(velocity.x, 0.0, velocity.z).normalized() if planar.length_squared() > MOVE_EPSILON else Vector3.ZERO)
		now_grounded = _body.is_on_floor()
	var dy: float = _body.global_position.y - start.y
	if grounded and now_grounded:
		# Só o resíduo que não vem da inclinação do piso é absorvido pela câmera (BUG-003). Em rampa, a altura
		# muda de acordo com o plano do chão e a cabeça acompanha; só degraus (step-up e snap) são suavizados.
		var floor_normal: Vector3 = _body.get_floor_normal()
		var planar_move: Vector3 = _body.global_position - start
		planar_move.y = 0.0
		var expected_dy: float = 0.0
		if floor_normal.y > MOVE_EPSILON:
			expected_dy = -(planar_move.x * floor_normal.x + planar_move.z * floor_normal.z) / floor_normal.y
		_step_visual_offset += dy - expected_dy
	if not grounded and now_grounded:
		landed.emit(fall_speed)
	_was_on_floor = now_grounded
	var moved: Vector2 = Vector2(_body.global_position.x - start.x, _body.global_position.z - start.z)
	var distance: float = moved.length()
	_horizontal_speed = Vector2(_body.velocity.x, _body.velocity.z).length()
	_exertion = exertion_for(gait, _stance)
	_update_footsteps(distance, now_grounded, gait)
	_update_visuals(dt, distance, now_grounded, cfg)


## Acréscimo da F1-008 (comando de debug): voo sem colisão na direção do olhar. Desliga a máscara de colisão.
func set_noclip(enabled: bool) -> void:
	_noclip = enabled
	if _body != null:
		_body.collision_mask = 0 if enabled else _default_mask
		_body.velocity = Vector3.ZERO
	_first_step = true


func is_noclip() -> bool:
	return _noclip


## Acréscimo da F1-008: teleporte. Zera a velocidade e o deslocamento visual, sem suavizar o salto.
func notify_teleported() -> void:
	_body.velocity = Vector3.ZERO
	_step_visual_offset = 0.0
	_stride_distance = 0.0
	_first_step = true


func get_stance() -> Enums.Stance:
	return _stance


func get_gait() -> Enums.Gait:
	return _gait


func get_exertion() -> float:
	return _exertion


func get_horizontal_speed() -> float:
	return _horizontal_speed


## Altura atual do colisor (m). Usada pelos testes e pelo overlay de debug (F1-008).
func get_collider_height() -> float:
	if _shape == null:
		return 0.0
	return _shape.height


## Velocidade máxima do sprint depois dos limites da fisiologia (nunca acima de sprint_speed).
func get_sprint_speed_limit() -> float:
	return _cfg().sprint_speed * _sprint_multiplier


func is_sprint_allowed() -> bool:
	return _sprint_allowed


## Só reduz: o multiplicador é limitado a [0, 1] e sprint_allowed pode apenas desligar o sprint.
func apply_limits(coupling: CouplingFactors) -> void:
	if coupling == null:
		_sprint_multiplier = 1.0
		_sprint_allowed = true
		return
	_sprint_multiplier = clampf(coupling.max_sprint_multiplier, 0.0, 1.0)
	_sprint_allowed = coupling.sprint_allowed


## Captura, esconderijo e transições: enquanto travado, o input vira zero (a gravidade continua).
func set_input_locked(locked: bool) -> void:
	_input_locked = locked
	if locked:
		_clear_pending()


## Injeta comandos (bots e testes). Passe null para voltar aos dispositivos.
## As bordas (crouch_pressed, crawl_pressed) são de quem injeta: verdadeiro só no tick do aperto.
func set_scripted_input(input: MotorInput) -> void:
	_scripted = input
	_clear_pending()


# ---- Input ----

func _unhandled_input(event: InputEvent) -> void:
	if _scripted != null or _input_locked:
		return
	var motion: InputEventMouseMotion = event as InputEventMouseMotion
	if motion != null:
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			_pending_look += motion.relative
		return
	if event.is_action_pressed(&"crouch"):
		_pending_crouch = true
	elif event.is_action_pressed(&"crawl"):
		_pending_crawl = true


func _sample_input() -> MotorInput:
	if _input_locked:
		_clear_pending()
		return MotorInput.new()
	if _scripted != null:
		return _scripted
	var input: MotorInput = MotorInput.new()
	input.move = Input.get_vector(&"move_left", &"move_right", &"move_back", &"move_forward")
	input.sprint = Input.is_action_pressed(&"sprint")
	input.slow_walk = Input.is_action_pressed(&"slow_walk")
	input.crouch_pressed = _pending_crouch
	input.crawl_pressed = _pending_crawl
	input.look_delta = _pending_look
	_clear_pending()
	return input


func _clear_pending() -> void:
	_pending_crouch = false
	_pending_crawl = false
	_pending_look = Vector2.ZERO


func _resolve_gait(input: MotorInput, move: Vector2) -> Enums.Gait:
	if move.length_squared() <= MOVE_EPSILON:
		return Enums.Gait.IDLE
	if input.sprint and _stance == Enums.Stance.STAND and _sprint_allowed and move.y > FORWARD_THRESHOLD:
		return Enums.Gait.SPRINT
	if input.slow_walk:
		return Enums.Gait.SLOW
	return Enums.Gait.WALK


# ---- Look ----

## Graus por pixel (Settings.mouse_sensitivity). Mouse para cima = olhar para cima, salvo invert_y.
func _apply_look(look: Vector2) -> void:
	if look == Vector2.ZERO or _body == null:
		return
	var cfg: PlayerMotorConfig = _cfg()
	var sensitivity: float = Settings.get_float(&"mouse_sensitivity")
	var invert: float = -1.0 if Settings.get_bool(&"invert_y") else 1.0
	_body.rotate_y(-deg_to_rad(look.x * sensitivity))
	_pitch_deg = clampf(_pitch_deg - look.y * sensitivity * invert, -cfg.pitch_limit_deg, cfg.pitch_limit_deg)
	if _head != null:
		_head.rotation.x = deg_to_rad(_pitch_deg)


# ---- Posturas ----

func _apply_stance_commands(input: MotorInput) -> void:
	if input.crawl_pressed:
		if _stance == Enums.Stance.CRAWL:
			_try_set_stance(Enums.Stance.CROUCH)
		else:
			_set_stance(Enums.Stance.CRAWL)
		return
	if input.crouch_pressed:
		if _stance == Enums.Stance.STAND:
			_set_stance(Enums.Stance.CROUCH)
		elif _stance == Enums.Stance.CROUCH:
			_try_set_stance(Enums.Stance.STAND)


## Subir de postura só com espaço livre acima (MOT-INV-1). Sem espaço, o comando é ignorado.
func _try_set_stance(new_stance: Enums.Stance) -> void:
	var target: float = _height_for(new_stance)
	if target > _shape.height and not _has_headroom(target):
		return
	_set_stance(new_stance)


func _set_stance(new_stance: Enums.Stance) -> void:
	if new_stance == _stance:
		return
	var old_stance: Enums.Stance = _stance
	_stance = new_stance
	_apply_collider_height(_height_for(new_stance))
	stance_changed.emit(old_stance, new_stance)


func _height_for(stance: Enums.Stance) -> float:
	var cfg: PlayerMotorConfig = _cfg()
	if stance == Enums.Stance.CRAWL:
		return cfg.crawl_height
	if stance == Enums.Stance.CROUCH:
		return cfg.crouch_height
	return cfg.stand_height


## Altura dos olhos da postura atual (topo do colisor menos eye_offset).
func _eye_target() -> float:
	return _height_for(_stance) - _cfg().eye_offset


## Os pés ficam na origem do corpo; o colisor cresce para cima.
func _apply_collider_height(height: float) -> void:
	_shape.height = height
	_shape_node.position.y = height * 0.5


## Verdadeiro se o volume acima do topo atual até target_height estiver livre.
## Consulta só a faixa nova: obstáculos rentes ao chão não bloqueiam a troca de postura.
func _has_headroom(target_height: float) -> bool:
	var current: float = _shape.height
	if target_height <= current:
		return true
	var volume: CylinderShape3D = CylinderShape3D.new()
	volume.radius = _cfg().capsule_radius
	volume.height = target_height - current
	var query: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
	query.shape = volume
	var feet: Vector3 = _body.global_position
	query.transform = Transform3D(Basis.IDENTITY, feet + Vector3.UP * (current + volume.height * 0.5))
	query.collision_mask = WORLD_MASK
	query.exclude = [_body.get_rid()]
	var hits: Array[Dictionary] = _body.get_world_3d().direct_space_state.intersect_shape(query, 1)
	return hits.is_empty()


# ---- Movimento e degraus ----

func _target_velocity(move: Vector2, gait: Enums.Gait, cfg: PlayerMotorConfig) -> Vector3:
	var frame: Basis = _body.global_transform.basis
	var direction: Vector3 = frame.x * move.x - frame.z * move.y
	direction.y = 0.0
	return direction * speed_for(gait, _stance, cfg, _sprint_multiplier)


## Sobe um degrau de até step_height (spike V6): o movimento horizontal precisa ser bloqueado por
## uma face não horizontal, a altura seguinte precisa estar livre e o piso do degrau precisa ser chão.
func _try_step_up(motion: Vector3) -> void:
	var cfg: PlayerMotorConfig = _cfg()
	var start: Transform3D = _body.global_transform
	var blocked: KinematicCollision3D = KinematicCollision3D.new()
	if not _body.test_move(start, motion, blocked):
		return
	if blocked.get_normal().y >= FLOOR_NORMAL_MIN_Y:
		return
	var up: Vector3 = Vector3.UP * (cfg.step_height + STEP_CLEARANCE_M)
	var up_hit: KinematicCollision3D = KinematicCollision3D.new()
	var raised: Transform3D = start.translated(up)
	if _body.test_move(start, up, up_hit):
		raised = start.translated(up_hit.get_travel())
	var probe: Vector3 = motion.normalized() * (motion.length() + STEP_PROBE_EXTRA_M)
	if _body.test_move(raised, probe):
		return
	var forward: Transform3D = raised.translated(probe)
	var down_hit: KinematicCollision3D = KinematicCollision3D.new()
	if not _body.test_move(forward, -up - Vector3.UP * FLOOR_PROBE_M, down_hit):
		return
	if down_hit.get_normal().y < FLOOR_NORMAL_MIN_Y:
		return
	var landing_y: float = forward.translated(down_hit.get_travel()).origin.y
	var rise: float = landing_y - start.origin.y
	if rise <= 0.01 or rise > cfg.step_height + STEP_CLEARANCE_M + 0.001:
		return
	# Elevação exata até o topo do degrau de destino e um pequeno avanço já na altura nova (ver STEP_FORWARD_EXTRA_M).
	var landing: Transform3D = start.translated(Vector3.UP * rise)
	landing = landing.translated(motion.normalized() * STEP_FORWARD_EXTRA_M)
	_body.global_transform = landing


## BUG-002: quando o tick termina no ar mas há superfície voltada para cima até floor_snap_length abaixo, leva o
## corpo até ela e faz um move_and_slide parado para o contato de piso ser registrado. O snap do move_and_slide
## falha quando a base do cilindro está na quina do degrau (contato lateral), e o corpo cai pelos degraus.
func _settle_on_ground(move_dir: Vector3) -> void:
	var cfg: PlayerMotorConfig = _cfg()
	# A sondagem sai 2,5 mm à frente do corpo: a borda do cilindro não pode ficar no plano de uma face de degrau
	# (contato tangente dá normal lateral). 2,5 mm não é múltiplo do passo de 5 mm da propriedade, então não cai em
	# nenhuma fase exata. O corpo não sai da posição: só desce até a superfície achada.
	var origin: Transform3D = _body.global_transform.translated(move_dir * SETTLE_PROBE_SHIFT_M)
	var hit: KinematicCollision3D = KinematicCollision3D.new()
	if not _body.test_move(origin, Vector3.DOWN * cfg.floor_snap_length, hit):
		return
	if hit.get_normal().y <= 0.0:
		return
	_body.global_transform = _body.global_transform.translated(hit.get_travel())
	_body.velocity = Vector3(0.0, -GROUND_STICK_SPEED_MS, 0.0)
	_body.move_and_slide()


func _probe_floor() -> bool:
	var hit: KinematicCollision3D = KinematicCollision3D.new()
	if not _body.test_move(_body.global_transform, Vector3.DOWN * FLOOR_PROBE_M, hit):
		return false
	return hit.get_normal().y >= FLOOR_NORMAL_MIN_Y


# ---- Passos, superfície e visual ----

func _update_footsteps(distance: float, grounded: bool, gait: Enums.Gait) -> void:
	if not grounded or gait == Enums.Gait.IDLE or distance <= 0.0:
		return
	_stride_distance += distance
	var stride: float = stride_for(gait, _stance, _cfg())
	if _stride_distance >= stride:
		_stride_distance -= stride
		footstep.emit(_surface_under(), gait, _stance)


## Superfície do piso sob o corpo: metadado "surface" do nó colidido; sem metadado, "default".
func _surface_under() -> StringName:
	var origin: Vector3 = _body.global_position
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
		origin + Vector3.UP * 0.05, origin + Vector3.DOWN * 0.15, WORLD_MASK, [_body.get_rid()])
	var hit: Dictionary = _body.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return DEFAULT_SURFACE
	var collider: Object = hit.get("collider") as Object
	if collider == null or not collider.has_meta(SURFACE_META):
		return DEFAULT_SURFACE
	return StringName(str(collider.get_meta(SURFACE_META)))


func _update_visuals(dt: float, distance: float, grounded: bool, cfg: PlayerMotorConfig) -> void:
	var speed_ratio: float = 0.0
	if grounded:
		speed_ratio = clampf(_horizontal_speed / cfg.walk_speed, 0.0, 1.0)
	_bob_strength = move_toward(_bob_strength, speed_ratio, BOB_RATE_PER_S * dt)
	if distance > 0.0:
		var stride: float = stride_for(_gait, _stance, cfg)
		_bob_phase = fposmod(_bob_phase + distance * cfg.head_bob_frequency_per_stride / stride, 1.0)
	var reduction: float = Settings.get_float(&"motion_reduction")
	var bob: float = cfg.head_bob_amplitude * (1.0 - reduction) * sin(TAU * _bob_phase) * _bob_strength
	_eye_height = move_toward(_eye_height, _eye_target(), dt * _eye_rate(cfg))
	_step_visual_offset *= exp(-cfg.camera_step_smoothing * dt)
	if _head != null:
		_head.position.y = _eye_height - _step_visual_offset + bob


## Noclip: anda na direção do olhar (inclui o pitch), na velocidade de corrida da config.
func _step_noclip(dt: float, move: Vector2, gait: Enums.Gait, cfg: PlayerMotorConfig) -> void:
	var frame: Basis = _head.global_transform.basis if _head != null else _body.global_transform.basis
	var direction: Vector3 = frame.x * move.x - frame.z * move.y
	var length: float = direction.length()
	if length > 1.0:
		direction = direction / length
	var travel: Vector3 = direction * cfg.sprint_speed * dt
	_body.global_position += travel
	_body.velocity = Vector3.ZERO
	_horizontal_speed = Vector2(travel.x, travel.z).length() / maxf(dt, MOVE_EPSILON)
	_exertion = exertion_for(gait, _stance)
	_update_visuals(dt, 0.0, false, cfg)


## Velocidade (m/s) com que os olhos mudam de altura entre posturas.
func _eye_rate(cfg: PlayerMotorConfig) -> float:
	return (cfg.stand_height - cfg.crawl_height) / maxf(cfg.stance_transition_time_s, 0.001)


# ---- Utilidades ----

func _cfg() -> PlayerMotorConfig:
	if config == null:
		config = PlayerMotorConfig.new()
		if not _config_warned:
			_config_warned = true
			Log.error(LOG_CATEGORY, "PlayerMotorConfig ausente; usando os padrões do código")
	return config


func _find_collision_shape(body: CharacterBody3D) -> CollisionShape3D:
	for child: Node in body.get_children():
		var shape_node: CollisionShape3D = child as CollisionShape3D
		if shape_node != null:
			return shape_node
	return null

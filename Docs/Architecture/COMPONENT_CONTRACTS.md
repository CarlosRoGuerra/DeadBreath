# Contratos de Componentes — DEAD BREATH

| Campo | Valor |
|---|---|
| Versão | 0.3: §1–§3, §3.1, §15 e §16 **congelados (v1.0) no Gate F1**, 2026-11-20; demais seções em draft até a fase de cada sistema |
| Status | Proposta. Cada contrato é congelado (v1.0) antes da implementação do sistema na sua fase. |
| Responsável | Software Architect |

**Regras gerais**
- O contrato define API pública, sinais, invariantes e dependências proibidas. A implementação interna pode mudar desde que o contrato e seus testes continuem válidos.
- Alterar um contrato aprovado exige: proposta → revisão do Software Architect → atualização deste documento → regressão completa (AGENT_ASSIGNMENTS §6).
- Cada componente pertence a **uma única camada** (SYSTEM_ARCHITECTURE §2).
- Tipos de dados estão em [DATA_STRUCTURES.md](DATA_STRUCTURES.md).
- GDScript tipado, uma declaração por linha. GDScript **não tem interfaces**: contratos de "papel" são implementados por **componentes-filho** (composição), nunca por herança múltipla.
- Enums compartilhados ficam em `core/enums.gd` (`class_name Enums`, L0) e são referenciados como `Enums.X`.
- O mapeamento de cada invariante para o seu teste está no §17.

---

## 1. PlayerRoot (L2) — composição e mediação do jogador — Gameplay Engineer — Fase 1/2

O nó raiz do jogador (`CharacterBody3D`) é o **único** script que conhece todos os componentes do jogador. Ele executa o tick em ordem fixa e passa dados entre eles. Os componentes não se conhecem.

```gdscript
class_name PlayerRoot extends CharacterBody3D
## Ordem do tick (process_physics_priority = -90):
## 1. motor.step(dt)                                  -> movimento e esforço
## 2. inputs = threat_monitor.sample() + motor.get_exertion() + hiding.is_hidden()
## 3. physiology.step(dt, inputs)
## 4. motor.apply_limits(physiology.get_coupling())   -> vale a partir do próximo tick
## 5. breath_emitter.step(dt, physiology.get_snapshot())
## 6. interaction.step(dt, context)                   -> InteractionContext montado pelo PlayerRoot (F1)
```

**Ligações feitas pelo PlayerRoot em `_ready()`**
- Injeta no motor o corpo e a cabeça: `motor.setup(self, $Head)`.
- Conecta `physiology.startle_gasp` → `breath_emitter.emit_gasp()`.
- Define a fonte de ameaça: `PlayerThreatMonitor` quando existe (a partir da F4) ou `StubThreatSource` (F2/F3: ameaça controlada pelo overlay de debug e pelos testes). As duas classes estendem `ThreatSource` e expõem `sample() -> ThreatSample`.

**Invariante PLR-INV-1:** PlayerMotor, PhysiologyComponent, BreathEmitter, PlayerThreatMonitor e HidingComponent não têm referência entre si; toda troca de dados e toda conexão de sinal entre eles é feita pelo PlayerRoot. "Componente" é script com base `Node` (ou derivada). As classes de dados de um componente (`RefCounted`/`Resource`, ex.: `MotorInput`, `PlayerMotorConfig`) podem ser usadas por ele; o ARC-06 verifica só referências entre componentes (decisão do Director, 2026-11-20).

## 2. PlayerMotor (L2) — Gameplay Engineer — Fase 1

```gdscript
class_name PlayerMotor extends Node
signal stance_changed(old: Enums.Stance, new: Enums.Stance)
signal footstep(surface: StringName, gait: Enums.Gait, stance: Enums.Stance)
signal landed(fall_speed: float)

func setup(body: CharacterBody3D, head: Node3D) -> void   ## injetado pelo PlayerRoot
func step(dt: float) -> void
func get_stance() -> Enums.Stance
func get_gait() -> Enums.Gait
func get_exertion() -> float                  ## 0..1, esforço instantâneo
func get_horizontal_speed() -> float
func apply_limits(coupling: CouplingFactors) -> void
func set_input_locked(locked: bool) -> void   ## captura, esconderijo, transições
```

- Parâmetros em `PlayerMotorConfig` (DATA_STRUCTURES §1.1).
- O input é **amostrado** dentro de `step()` (`Input.is_action_pressed`). O movimento do mouse é acumulado em `_unhandled_input` e consumido em `step()`.

**Complemento v1.0 (congelado para a F1-006, 2026-11-20)**

```gdscript
class_name MotorInput extends RefCounted      ## comandos de um tick
var move: Vector2                             ## x = direita, y = frente; comprimento ≤ 1
var sprint: bool
var slow_walk: bool
var crouch_pressed: bool                      ## borda (só no tick em que foi apertado)
var crawl_pressed: bool                       ## borda
var look_delta: Vector2                       ## pixels de mouse acumulados no tick

## PlayerMotor (acréscimos)
func set_scripted_input(input: MotorInput) -> void   ## testes e bots; null = volta aos dispositivos
```

- **Colisor:** `CylinderShape3D` com raio `capsule_radius` (o nome do parâmetro fica por compatibilidade) e altura da postura. Motivo: spike V6 (ENGINE_DECISION §7.1); a cápsula perde o chão em ~28% dos ticks ao descer escadas.
- **Step-up:** implementado pelo motor até `step_height`, com sondagem horizontal ≥ raio do colisor. A elevação brusca é compensada na câmera (a altura visual converge suavemente; a física não).
- **Posturas:** `crouch` alterna STAND ↔ CROUCH; `crawl` alterna CROUCH/STAND → CRAWL e CRAWL → CROUCH. Subir de postura só acontece com espaço livre (MOT-INV-1); sem espaço, o comando é ignorado. Sprint só em pé, andando para a frente, e se `sprint_allowed`.
- **Passos:** `footstep` a cada passada (distância por marcha/postura na config), só no chão. A superfície vem do metadado `surface` (StringName: `wood`, `carpet`, `tile`, `concrete`) do colisor sob o jogador; sem metadado, `default`.
- **`landed(fall_speed)`:** emitido na transição ar → chão, com a velocidade vertical do impacto (m/s, positiva).
- **Head bob:** amplitude `head_bob_amplitude × (1 − Settings.motion_reduction)`.
- **Config ausente:** sem `PlayerMotorConfig`, usa os padrões e registra `Log.error` (o comportamento de debug do ARC-07 fica para quando o ARC-07 for implementado).
- **Sem fisiologia (F1):** o PlayerRoot chama `apply_limits` com `CouplingFactors` neutros (multiplicadores 1, sprint permitido).

**Invariantes**
- MOT-INV-1: não fica em pé (nem agachado) se não houver espaço livre acima.
- MOT-INV-2: `get_exertion()` = 0 parado; ≈ 0.2 andando; 1.0 em sprint; agachado ≤ 0.15; rastejando ≤ 0.25.
- MOT-INV-3: `apply_limits` só reduz velocidade e sprint; nunca aumenta além da config.

**Dependências proibidas:** fisiologia, IA, áudio, PlayerRoot.

## 3. Interação (L2) — Gameplay Engineer — Fase 1

```gdscript
class_name Interactable extends Node3D
@export var prompt_key: StringName
@export var hold_time: float = 0.0
@export var requires_steady_hands: bool = false
signal interacted(actor: Node)
func can_interact(context: InteractionContext) -> bool
func interact(context: InteractionContext) -> void

class_name InteractionComponent extends Node
signal focus_changed(target: Interactable)    ## null = nada em foco
func get_focused() -> Interactable
```

- `InteractionContext` (DATA_STRUCTURES §5) leva `steadiness` e `is_hidden`. Com `requires_steady_hands`, o tempo de segurar é multiplicado por `1 + 1.5·(1 − steadiness)`. Uma falha (soltar antes) gera ruído do objeto.
- **Door:** estados `CLOSED`, `OPEN`, `LOCKED`. Segurar = abertura lenta (30 dB); toque = normal (50 dB). Atualiza o `Portal` acústico associado. É `Saveable`.
- **Pickup:** tem `persist_id`, emite `EventBus.item_picked` e se remove. É `Saveable` (consumido ou não).
- **Door (F1):** começa no estado `initial_state`; se for `OPEN`, o painel já nasce no ângulo de abertura.
- **Door, painel que não empurra (F1-011, BUG-006 e BUG-009):** o painel avança no tick de física. Um incremento só vale se a caixa do painel, crescida em 2 cm por lado, não encosta em corpo móvel: objetos dinâmicos (camada 2), jogador (camada 3) ou inimigos (camada 4). O próprio painel não conta. Se o próximo passo encostaria em um desses corpos, o painel fica parado no ângulo atual, emite `blocked(body)` uma vez por bloqueio e retoma quando o caminho está livre. O estado continua `OPEN` durante o bloqueio. A porta nunca empurra o jogador. **Geometria estática (camada 1) não bloqueia o giro:** o arco livre (sem paredes ou quinas dentro do giro) é responsabilidade do level design. Um painel de 2,0 m de altura casa com o vão de `DOOR_H` do gerador.
- **Interação e pausa (F1-011, BUG-005):** `InteractionComponent` usa `PROCESS_MODE_ALWAYS`, então recebe a soltura do botão mesmo com a árvore pausada. Aperto com a árvore pausada é ignorado. Pausar no meio do segurar cancela o segurar (`interaction_failed`). Para tentar de novo, é preciso apertar outra vez depois de continuar; o progresso não é guardado. O estado do segurar vem dos eventos de aperto e soltura, não do singleton `Input`, para que a entrada injetada pelos testes (`push_input`) funcione.
- **LevelSlots (L2, `components/world/level_slots.gd`, integração F1-009):** instancia Door e Pickup nos marcadores do Level Designer. `door_slot` = `Marker3D` no centro do vão, 1,0 m acima do piso, +Z local ao longo da largura; metadados `door_id`, `start_state` (`closed`/`open`/`locked`), `opening_width_m`. `pickup_slot` = `Marker3D` na posição do item; metadados `persist_id`, `item_id`. `persist_id` repetido gera `Log.error`.

### 3.1 API pública acrescentada na Fase 1 (revisão F1-010, R1-12) — v1.0

Acréscimos feitos durante a implementação e aceitos pelo Director. Mudanças posteriores seguem a regra geral de alteração de contrato.

```gdscript
## PlayerRoot (mediador; grupo "player")
func apply_limits(coupling: CouplingFactors) -> void
func get_motor() -> PlayerMotor
func get_interaction() -> InteractionComponent
func get_camera() -> Camera3D
func set_mouse_captured(captured: bool) -> void
func is_mouse_capture_requested() -> bool
func on_menu_resumed() -> void           ## contrato de GRUPO: o PauseMenu chama em "player" ao continuar
func teleport_to(position: Vector3) -> void   ## só debug (F1-008)
func set_noclip(enabled: bool) -> void        ## só debug (F1-008)
func is_noclip() -> bool

## PlayerMotor (além do §2)
@export var config: PlayerMotorConfig
static func exertion_for(gait: Enums.Gait, stance: Enums.Stance) -> float
static func speed_for(gait: Enums.Gait, stance: Enums.Stance, cfg: PlayerMotorConfig, sprint_multiplier: float) -> float
static func stride_for(gait: Enums.Gait, stance: Enums.Stance, cfg: PlayerMotorConfig) -> float
func set_noclip(enabled: bool) -> void
func is_noclip() -> bool
func notify_teleported() -> void         ## zera velocidade e a compensação visual
func get_collider_height() -> float
func get_sprint_speed_limit() -> float
func is_sprint_allowed() -> bool

## InteractionComponent (além do §3)
signal interaction_failed(target: Interactable)   ## soltou antes do tempo ou perdeu o foco; base do ruído na F3
@export var reach_m: float = 2.0
func setup(camera: Camera3D, body: CollisionObject3D) -> void
func step(delta: float, context: InteractionContext) -> void   ## chamado pelo PlayerRoot (§1, passo 6)
func press_interact() -> void
func release_interact() -> void
func is_holding() -> bool
func get_hold_progress() -> float
static func required_hold_time(target: Interactable, steadiness: float) -> float

## Interactable: @export var tap_completes: bool   ## toque completa a ação mesmo com hold_time > 0 (porta)
## InteractionContext: var actor: Node; var steadiness: float; var is_hidden: bool; var held: bool

## Door
enum State { CLOSED, OPEN, LOCKED }
signal state_changed(old_state: State, new_state: State)
signal opened(slow: bool)                ## a F3 liga o NoiseEmitter aqui
signal locked_feedback(actor: Node)
signal blocked(body: Node)               ## F1-011: o painel parou antes de encostar em corpo móvel (jogador, inimigo ou objeto dinâmico); uma vez por bloqueio
## @export: initial_state, open_time_fast_s, open_time_slow_s, open_angle_deg
func get_state() -> State
func is_moving() -> bool
func is_blocked() -> bool                ## true enquanto o painel está parado por um corpo
func get_panel_angle_deg() -> float
func lock() -> void
func unlock() -> void

## Pickup: @export var persist_id: StringName; item_id: StringName; quantity: int

## L3 (presentation)
## DebugOverlay: is_debug_enabled, set_player, get_player (acha o grupo "player"), is_overlay_visible,
##   get_overlay_text, toggle_overlay, toggle_noclip, teleport_to_aim. Desligado em produção.
## DebugCommands (estático): is_allowed, set_noclip, teleport_to_aim, floor_point_under_aim.
## PauseMenu: signal resumed; is_open, is_controls_visible, open_menu, continue_game, show_controls, show_main.
## ControlsMenu: signal closed; is_capturing, get_status_text, get_button_text, begin_capture,
##   capture_event(event) -> String (status; STATUS_INVALID para tecla sem código ou botão fora de 1..9).

## L0 core/input_bindings.gd (InputBindings, estático)
## Formato de Settings.input_bindings: { "<acao>": [ {"type": "key", "physical_keycode": int}
##   | {"type": "mouse_button", "button_index": int (1..9)} ] }. Ações ui_* ficam fora. Lista vazia é inválida.
static func capture_defaults() -> void
static func rebindable_actions() -> PackedStringArray
static func apply(overrides: Dictionary) -> void        ## padrões + sobreposições; chamado pelo Settings
static func current_overrides() -> Dictionary
static func action_entries(action: StringName) -> Array
static func rebind(action: StringName, entry: Dictionary) -> bool   ## false e nada muda se a entrada for inválida
static func is_valid_entry(entry: Variant) -> bool
static func validate(value: Variant) -> bool
static func find_conflicts(entry: Dictionary, except_action: StringName) -> PackedStringArray
static func describe(entry: Dictionary) -> String
static func entry_from_event(event: InputEvent) -> Dictionary
```

## 4. Fisiologia — Physiological Systems Engineer — Fase 2 — **v1.0 (congelado na abertura da F2)**

### 4.1 PhysiologyComponent (L2)

```gdscript
class_name PhysiologyComponent extends Node
signal respiratory_state_changed(old: Enums.RespiratoryState, new: Enums.RespiratoryState)
signal cough_warning(seconds_until: float)
signal coughed(suppressed: bool)
signal stamina_depleted()
signal stamina_recovered()
signal stress_band_changed(old: Enums.StressBand, new: Enums.StressBand)
signal startle_gasp()                           ## ruído involuntário por susto

func step(dt: float, inputs: PhysiologyInputs) -> void
func get_snapshot() -> PhysiologySnapshot
func get_coupling() -> CouplingFactors
func apply_medication(profile: MedicationProfile) -> bool   ## false em cooldown
func add_startle(amount: float) -> void
func add_injury(amount: float) -> void                       ## queda/captura: pico de estresse
```

### 4.2 Modelos L1 (sem Node)

```gdscript
class_name StaminaModel extends RefCounted
var value: float
func _init(config: StaminaConfig) -> void
func tick(dt: float, inputs: PhysiologyInputs, coupling: CouplingFactors) -> void

class_name StressModel extends RefCounted
var value: float
func _init(config: StressConfig) -> void
func tick(dt: float, inputs: PhysiologyInputs) -> void
func add_spike(amount: float) -> void
func get_band() -> Enums.StressBand

class_name RespiratoryModel extends RefCounted
var symptom_severity: float
var breathing_rate: float
var wheezing_intensity: float
var cough_probability: float
var recovery_progress: float
var state: Enums.RespiratoryState
func _init(config: RespiratoryConfig, rng: RandomNumberGenerator) -> void
func tick(dt: float, inputs: PhysiologyInputs, stress_value: float) -> void
func apply_medication(profile: MedicationProfile) -> bool

class_name PhysiologyCoupling extends RefCounted
static func compute(stamina: StaminaModel, stress: StressModel, resp: RespiratoryModel, config: CouplingConfig) -> CouplingFactors
```

Os três modelos implementam também `to_dict() -> Dictionary` e `from_dict(data: Dictionary) -> void`, cobrindo **todo campo que afeta ticks futuros** (timers, cooldowns, flags de histerese, tosse agendada, pico de recuperação). Lista completa em DATA_STRUCTURES §6.1. Teste PER-07.

As fórmulas de estados, tosse, acoplamento e `recovery_progress` estão em DATA_STRUCTURES §1.

**Invariantes**
- PHY-INV-1: valores sempre dentro dos intervalos (stamina e estresse 0..100; severidade 0..1).
- PHY-INV-2: medicação nunca altera `StaminaModel.value`.
- PHY-INV-3: com entradas zeradas, severidade e estresse voltam ao basal em tempo finito.
- PHY-INV-4: transições de estado respeitam histerese e tempo mínimo de permanência.
- PHY-INV-5: toda tosse involuntária é precedida por `cough_warning` com antecedência ≥ `cough_warning_time_s`.
- PHY-INV-6: mesmo estado do RNG + mesmas entradas = mesmos resultados.

**Fonte de verdade das cargas de medicação:** o Inventory. O `PhysiologySnapshot.medication_charges` é só leitura.

**Dependências proibidas:** PlayerMotor, IA, acústica, áudio.

### 4.3 Acréscimos congelados para a Fase 2 (v1.0, 2026-11-20)

```gdscript
## Configs (Resources) em game/content/data/physiology/*.tres; classes em game/sim/physiology/
class_name StaminaConfig extends Resource      ## DATA_STRUCTURES §1.2
class_name StressConfig extends Resource       ## §1.3
class_name RespiratoryConfig extends Resource  ## §1.4
class_name CouplingConfig extends Resource     ## §1.6
class_name MedicationProfile extends Resource  ## §1.7

## PhysiologyComponent (além do §4.1)
@export var stamina_config: StaminaConfig
@export var stress_config: StressConfig
@export var respiratory_config: RespiratoryConfig
@export var coupling_config: CouplingConfig
@export var rng_seed: int = 0                  ## 0 = semente aleatória no _ready; testes fixam
func to_dict() -> Dictionary                   ## modelos + RNG (estado como string) + timers
func from_dict(data: Dictionary) -> void

## ThreatSource / StubThreatSource (§5): na F2 o PlayerRoot usa StubThreatSource
class_name StubThreatSource extends ThreatSource
var forced: ThreatSample                       ## testes e overlay de balanceamento ajustam
```

- **Tick do PlayerRoot na F2** (§1): `motor.step` → `inputs` (`exertion` e `gait` do motor, `threat = threat_source.sample()`, `is_resting` = parado e agachado/rastejando, `in_safe_zone = false`, `is_hidden = false`) → `physiology.step` → `apply_limits(physiology.get_coupling())` (vale no tick seguinte) → `breath_emitter.step` (F2-006b) → `interaction.step` com `steadiness` do acoplamento.
- **RNG:** o PhysiologyComponent tem o seu próprio `RandomNumberGenerator` (injetado no RespiratoryModel). O estado vai no `to_dict` como **string** (DATA §6).
- **Sem config:** padrões do código + `Log.error` (mesma regra do motor).
- **Medicação:** `apply_medication` falha (false) em cooldown; as cargas são do inventário (F2-005), não da fisiologia.

### 4.4 API pública acrescentada na Fase 2 (revisão F2-010, R2-06) — v1.0

```gdscript
## PhysiologyComponent (além de §4.1/§4.3)
func get_stress_config() -> StressConfig
func set_medication_charges(count: int) -> void      ## o inventário informa; o snapshot só lê

## RespiratoryModel (L1, além de §4.2)
func apply_consumable(...)                           ## comprimido e água (DATA §1.7); ligação ao jogo na F5

## InventoryComponent (L2, jogador) e InventoryModel (L1, sim/inventory)
signal doses_changed(item_id: StringName, doses: int)
@export var starting_inhaler_units: int = 1          ## bombinha = 3 doses por unidade
func get_doses(item_id: StringName) -> int
func consume_dose(item_id: StringName) -> bool
func add_units(item_id: StringName, units: int) -> void   ## alimentado por EventBus.item_picked
func to_dict() -> Dictionary / from_dict(data: Dictionary) -> void
## InventoryModel: static doses_per_unit(item_id), add_units, doses, consume_dose, to_dict, from_dict

## BreathEmitter (além de §6.3)
const GASP_DB := 42.0, COUGH_WARNING_DB := 32.0, COUGH_DB := 65.0
func emit_cough_warning(seconds_until: float = 1.5) -> void   ## COUGHING 32 dB, sound_id cough_warning
func emit_cough(suppressed: bool = false) -> void             ## suppressed = cancelada no aviso: sem som
func emit_body_sound(category: Enums.NoiseCategory, intensity_db: float, sound_id: StringName, duration_s: float = 0.0) -> void
func next_event_in_s() -> float
func cycle_phase_s() -> float
func cycles_emitted() -> int

## AcousticWorld (F2 mínimo, além de §6.4)
func advance(delta: float) -> void      ## relógio próprio (testes)
func now() -> float
func set_player_ear(ear: Node3D) -> void   ## sem ouvido: câmera ativa da viewport
func pending_count() -> int
func flush() -> void

## PlayerRoot (além de §1/§3.1)
signal item_use_failed(reason: StringName)   ## &"no_doses", &"cooldown", &"no_profile"
signal inhaler_used()
@export var inhaler_profile: MedicationProfile
func try_use_inhaler() -> bool              ## tecla use_item (Q)
func get_inventory() -> InventoryComponent
func get_breath_emitter() -> BreathEmitter
func get_physiology() -> PhysiologyComponent
func get_threat_source() -> ThreatSource
func set_threat_source(source: ThreatSource) -> void   ## null volta ao StubThreatSource
```

**Ponte de susto (revisão F2-010, R2-01):** o `PhysiologyComponent.add_startle` e o gasp funcionam e estão testados. O que liga um ruído externo (não causado pelo jogador, `perceived_db ≥ 55`, DATA §1.3) a `add_startle` ainda não existe, porque na F2 não há fonte de ruído externa. Entra na F3 com os ruídos do mundo (backlog F3-002).

## 5. PlayerThreatMonitor (L2) — Physiological Systems Engineer — Fase 4

Calcula a ameaça **percebida pelo jogador**, que alimenta o estresse e a música. É a percepção do jogador, não da IA.

```gdscript
class_name ThreatSource extends RefCounted        ## base (F2: RefCounted; ver nota abaixo); StubThreatSource é usado na F2/F3
func sample() -> ThreatSample                     ## campos em DATA_STRUCTURES §5

class_name PlayerThreatMonitor extends ThreatSource
signal threat_changed(level: float, in_chase: bool)
func receive_heard(heard: PlayerHeardNoise) -> void   ## chamado somente pelo AcousticWorld
func to_dict() -> Dictionary                          ## janelas de 3 s (DATA_STRUCTURES §6.1)
func from_dict(data: Dictionary) -> void
```

- Inimigo **visto:** dentro do campo de visão da câmera do jogador, com linha de visada até o inimigo e, ou a exposição à luz **sobre o inimigo** ≥ 0.15 (medida pelo `LightExposureProbe` do próprio inimigo, o mesmo componente usado no jogador), ou distância ≤ 3 m.
- Inimigo **ouvido:** `PlayerHeardNoise` com `source_is_enemy == true`, entregue pelo `AcousticWorld` (§6.2). Ele não tem posição nem id da fonte.
- `in_chase` = algum inimigo **visto** em CHASE nos últimos 3 s, **ou** algum `PlayerHeardNoise` de inimigo nos últimos 3 s com categoria RUNNING ou com `sound_id` de grito de perseguição (`voice_chase_*`).
- O PlayerRoot lê `sample()` na prioridade -90. Os ruídos entregues em -60 no tick anterior entram com latência de 1 tick (SYSTEM_ARCHITECTURE §6).
- Fórmula em DATA_STRUCTURES §1.5.

**Decisão F2 (Architect, ratificada):** `ThreatSource` é `RefCounted`, não `Node`. Como Node, ele seria um componente do jogador, e a herança `StubThreatSource extends ThreatSource` violaria o ARC-06. O PlayerRoot guarda a fonte por `set_threat_source()`. **Pendente para a F4:** o `PlayerThreatMonitor` precisa de Node (recebe ruídos, tem janelas de tempo). A opção preferida é o monitor (Node) expor um `ThreatSource` RefCounted via composição; decidir ao abrir a F4.

**Decisão D4-01 (Director, abertura da F4):** o `PlayerThreatMonitor` é um componente `Node` do jogador (`components/player/player_threat_monitor.gd`) e **não** estende `ThreatSource`. Ele expõe `get_threat_source() -> ThreatSource`, um RefCounted que lê o estado do monitor (composição). O PlayerRoot faz `set_threat_source(monitor.get_threat_source())` e registra o monitor no `AcousticWorld.register_player_listener(monitor.receive_heard, ouvido)`, no lugar da ponte de susto da F3. O monitor emite `startled(amount)`, e o PlayerRoot liga esse sinal a `physiology.add_startle`. A interface acima vale com essa leitura: `receive_heard`, `threat_changed`, `to_dict` e `from_dict` ficam no monitor; `sample()` fica na fonte.

**Invariante TMN-INV-1:** nenhuma informação do PlayerThreatMonitor nem `PlayerHeardNoise` é lida por scripts de IA (ARC-01).

## 6. Acústica — AI Engineer + Audio Engineer (contrato conjunto) — Fase 3

### 6.1 AcousticGraph (L1)

```gdscript
class_name AcousticGraph extends RefCounted
func _init(config: AcousticConfig) -> void
func add_room(room_id: StringName, bounds: AABB, ambient_floor_db: float) -> void
func add_portal(portal_id: StringName, room_a: StringName, room_b: StringName, position: Vector3) -> void
func set_portal_open(portal_id: StringName, open: bool) -> void
func set_weather_floor_offset(offset_db: float) -> void       ## trovão, chuva forte
func room_at(position: Vector3) -> StringName
func propagate(event: NoiseEvent, listener_position: Vector3) -> PropagationResult
```

### 6.2 AcousticWorld (L2, um por nível)

Substitui o antigo autoload "NoiseBus" (achado R-03 da revisão: o L0 não pode depender de tipos de L1/L2).

```gdscript
class_name AcousticWorld extends Node        ## grupo "acoustic_world"
signal noise_resolved_for_player(event: NoiseEvent, result: PropagationResult)  ## somente para L3/debug
func emit_noise(event: NoiseEvent) -> void
func register_listener(listener: HearingSensor) -> void
func unregister_listener(listener: HearingSensor) -> void
func register_player_listener(monitor: PlayerThreatMonitor, ear: Node3D) -> void
func get_graph() -> AcousticGraph
```

- **Ouvinte do jogador:** para cada evento cuja fonte não é o jogador, calcula `propagate()` até `ear` e, se audível, entrega um `PlayerHeardNoise` (categoria, nível, `source_is_enemy`, `sound_id`, timestamp) ao monitor. É o único canal de som com informação de origem fora do AcousticWorld, e só diz "é inimigo ou não".

- Constrói o grafo a partir dos nós `RoomVolume` e `Portal` do nível.
- Para cada listener: calcula `propagate()`, aplica o limiar de audibilidade (DATA_STRUCTURES §2.3), constrói um `HeardNoise` **sem** dados reais da fonte e entrega via `HearingSensor.receive()`.
- Não entrega a um listener os ruídos emitidos pelo seu próprio dono (`event.source_id == listener.owner_id`).
- A fila de eventos é processada no tick do AcousticWorld (prioridade -60). Um ruído emitido depois disso no mesmo frame é processado no tick seguinte (latência máxima de 1 tick, ≈ 16,7 ms).

### 6.3 NoiseEmitter e BreathEmitter (L2)

```gdscript
class_name NoiseEmitter extends Node3D
@export var source_id: StringName
func emit_noise(category: Enums.NoiseCategory, intensity_db: float, duration: float = 0.0, sound_id: StringName = &"") -> void

class_name BreathEmitter extends Node3D        ## componente do jogador
func step(dt: float, snapshot: PhysiologySnapshot) -> void
func emit_gasp() -> void                       ## gasp de susto (BREATHING 42 dB); conectado pelo PlayerRoot
func to_dict() -> Dictionary                   ## fase do ciclo (DATA_STRUCTURES §6.1)
func from_dict(data: Dictionary) -> void
```

- `BreathEmitter` é o produtor único de BREATHING, WHEEZING e COUGHING do jogador, inclusive do gasp de susto. Agenda **um `NoiseEvent` por ciclo respiratório** (categoria BREATHING, ou WHEEZING quando há chiado) e um evento COUGHING por tosse. Intensidade e `sound_id` vêm de `BreathParams.from_snapshot()` (função pura L1, DATA_STRUCTURES §2.4).
- **Esse evento é a única origem do som de respiração**, tanto para a IA quanto para o jogador (§14). Fim do produtor duplicado apontado no achado R-12.

**Invariantes**
- NOI-INV-1: todo som de gameplay chega à IA somente via `AcousticWorld.emit_noise`.
- NOI-INV-2: o volume que o jogador ouve deriva de `propagate()`. A atenuação nativa do `AudioStreamPlayer3D` fica **desligada** (`ATTENUATION_DISABLED`); só o *panning* espacial é usado.
- NOI-INV-3: `propagate()` é pura e determinística. Fechar uma porta nunca aumenta o nível percebido.
- NOI-INV-4: `HeardNoise` nunca contém a posição real da fonte, o id da fonte ou a sala da fonte. `PlayerHeardNoise` nunca contém posição, id nem sala.

### 6.4 AcousticWorld mínimo da Fase 2 (v1.0 para a F2)

Até a F3, o `AcousticWorld` existe só com o necessário para o produtor único da respiração:
- `emit_noise(event: NoiseEvent)` enfileira; a fila é processada na prioridade −60.
- **Propagação provisória:** só a perda por distância do ADR-004, `perceived_db = intensity_db − (20·log10(max(d, 1)) + 0.1·d)`, até a posição do ouvinte do jogador (a câmera). Sem grafo, paredes nem portas. A F3 troca por `AcousticGraph.propagate()` sem mudar a interface.
- Emite `noise_resolved_for_player(event, result)` para todo evento; não há `HearingSensor` nem `PlayerThreatMonitor` na F2.
- `source_id` do jogador: `&"player"`.

### 6.5 Acréscimos congelados para a Fase 3 (v1.0, 2026-11-20)

```gdscript
## AcousticWorld (substitui a §6.4 a partir da F3; interface da F2 mantida)
func register_player_listener(on_heard: Callable, ear: Node3D) -> void
## on_heard(heard: PlayerHeardNoise) é chamado para cada evento de OUTRA fonte audível no ouvido do jogador.
## F3: o PlayerRoot registra a ponte de susto. F4: o PlayerThreatMonitor registra-se no lugar, sem mudar a interface.
func get_graph() -> AcousticGraph
func get_weather_offset() -> float          ## trovão ativo: +20 dB por 2,5 s
signal thunder_started(duration_s: float)   ## para a ambiência (NoiseAudioRouter) e para o level design
```

- **Grafo a partir do nível:** o AcousticWorld lê os `RoomVolume` e `Portal` (DATA §2.5) do nível em que está. Portal com `door` atualiza o estado aberto/fechado pelo `Door.state_changed` (OPEN = aberto; CLOSED/LOCKED = fechado; porta em movimento conta como aberta).
- **Ponte de susto (DATA §1.3):** o PlayerRoot recebe o `PlayerHeardNoise` e, se `perceived_db ≥ 55` e a fonte não é o jogador, chama `physiology.add_startle(clamp((dB − 55)/2 + 10, 10, 25))`.
- **Legendas:** o AcousticWorld emite `EventBus.subtitle_requested(text_key, duration)` para os sons relevantes audíveis pelo jogador (F3-006). A chave vem do `sound_id` (`subtitle.<sound_id>`).
- **NOI-01** (só o AcousticWorld chama `HearingSensor.receive`) tem alvo real a partir da F4.
- **Decisões ratificadas na F3-002:**
  - `source_is_enemy` = `source_id` começa com `enemy` (convenção; rever na F4).
  - Trovão desligado por padrão (`thunder_enabled`), com intervalo de 60 a 180 s (RNG próprio, `weather_seed`); o level design liga por nível.
  - Legendas: a tosse (não o pigarro), as portas e a fala, sempre que audíveis; passos ou corrida de outra fonte só quando `perceived_db ≥ limiar do jogador + 10 dB`. O mesmo `sound_id` não repete antes de 2 s, e a duração mínima é 1,5 s.
  - Sem `RoomVolume` no nível, o AcousticWorld volta à propagação provisória da F2.
  - `RoomVolume` usa o AABB do `BoxShape3D` filho: as salas ficam alinhadas aos eixos.
- **Porta que fecha (F3-004, decisão do Director na F3-002):** interagir com a porta OPEN e parada começa o fechamento; segurar fecha devagar. Durante o movimento o estado continua OPEN (o portal segue aberto) e vira CLOSED no fim. O fechamento usa o mesmo bloqueio com histerese da abertura: para no corpo, emite `blocked` e não empurra.
- **Ponte de susto implementada (F3-004):** o PlayerRoot registra-se com `register_player_listener` e o ouvido é a câmera.
- **Correções da revisão F3-010 (Director):**
  - O que o jogador causa não o assusta: fonte `player` ou `player_<...>` (`AcousticWorld.is_player_source`) não chega ao ouvinte do jogador. Um Throwable solto ou arremessado pelo jogador emite como `player_thrown_<id>` até repousar, ser pego ou passar 3 s (N3 da verificação). A IA (F4) ouve normalmente (R3-04).
  - O NoiseEmitter recusa categoria corporal (respiração, chiado, tosse, medicação) de fonte que não comece com `enemy`: o corpo do jogador tem produtor único, o BreathEmitter (R3-02).
  - A posição estimada D-07 está pronta em L1 (`HeardNoise.from_propagation`), para o HearingSensor da F4 (R3-01).
- **Decisões da F3-003b (Director):**
  - Posição da voz 3D = `PropagationResult.entry_point`. No caminho direto é a fonte; por portal, é o portal por onde o som entra na sala do ouvinte.
  - Reverb = barramento da sala do **ouvinte** (`RoomVolume.reverb_bus`: `reverb_small`, `reverb_large` ou vazio = Master).
  - Regra de ganho comprimida acima de 45 dB, com limitador no Master (DATA §2.4).
  - **Contrato dos passos (para a F3-004):** o `NoiseEvent` de passo usa `sound_id = footstep_<superfície>` e `intensity_db = NoiseLevels.footstep_level(marcha, superfície)` sem outro modificador; corrida usa a categoria RUNNING. O router recupera a marcha descontando o modificador da superfície. A F3-004 testa, para cada marcha e superfície, que o arquivo tocado é o da marcha certa.
- **Categoria VOICE:** aprovada (P-03), DATA §2.1 (fala 55 / grito 75 dB).

### 6.6 API pública acrescentada na Fase 3 (revisão F3-010, R3-08) — v1.0

Os métodos que só servem a testes ou ferramentas de depuração estão marcados com `## teste`.

```gdscript
## AcousticGraph (L1, sim/acoustics; além de §6.1)
func add_room(room_id: StringName, bounds: AABB, ambient_floor_db: float) -> void
func add_portal(portal_id: StringName, room_a: StringName, room_b: StringName, position: Vector3) -> void
func set_portal_open(portal_id: StringName, open: bool) -> void
func is_portal_open(portal_id: StringName) -> bool
func set_weather_floor_offset(offset_db: float) -> void
func weather_floor_offset_db() -> float
func room_at(position: Vector3) -> StringName
func ambient_floor_at(position: Vector3) -> float
func effective_threshold_db(listener_position: Vector3, hearing_threshold_db: float, masking_margin_db: float) -> float

## HeardNoise (L1; D-07, revisão F3-010 R3-01). O HearingSensor da F4 recebe o resultado desta função.
static func from_propagation(event: NoiseEvent, result: PropagationResult, threshold_db: float,
		config: AcousticConfig, rng: RandomNumberGenerator) -> HeardNoise
static func confidence_for(perceived_db: float, threshold_db: float) -> float
static func disk_offset(radius: float, rng: RandomNumberGenerator) -> Vector3

## AcousticWorld (L2; além de §6.3–§6.5)
@export var config: AcousticConfig                 ## vazio: content/data/acoustics/acoustic_config.tres
@export var thunder_enabled: bool = false          ## o nível liga
@export var thunder_interval_min_s: float = 60.0
@export var thunder_interval_max_s: float = 180.0
@export var weather_seed: int = 1
const PLAYER_CAUSED_PREFIX: String = "player_"     ## fonte causada pelo jogador (R3-04)
static func is_player_source(source_id: StringName) -> bool
func set_player_ear(ear: Node3D) -> void
func unregister_player_listener() -> void
func has_geometry() -> bool
func rebuild_graph() -> void
func player_threshold_db(position: Vector3) -> float
func advance(delta: float) -> void                 ## teste: avança o relógio e resolve a fila
func now() -> float                                ## teste
func pending_count() -> int                        ## teste
func flush() -> void                               ## teste: resolve a fila agora

## RoomVolume e Portal (L2, nós de nível; DATA §2.5)
RoomVolume: @export room_id, ambient_floor_db, reverb_bus; func bounds_world() -> AABB
Portal: @export portal_id, room_a, room_b, door (NodePath da Door)

## NoiseEmitter (L2; §6.3). Recusa categoria corporal de fonte que não seja inimiga (R3-02).
static func is_body_category(category: Enums.NoiseCategory) -> bool

## Door (L2; além de §3): fecha pela interação (F3-004)
signal closed(slow: bool)
func is_closing() -> bool

## Throwable (L2) e PlayerHold (L2, jogador)
signal picked_up(actor: Node)
signal released()
@export var throwable_id: StringName
func is_held() -> bool
func get_held_by() -> Node
func get_size() -> StringName
func is_player_caused() -> bool                    ## solto ou arremessado pelo jogador, até repousar ou ser pego
func get_noise_source() -> StringName
func can_place_at(target: Transform3D, player: CollisionObject3D) -> bool
PlayerHold: func try_pick(item) -> bool; func throw_held() -> bool; func drop_held() -> bool; func get_held() -> Throwable
PlayerRoot: func get_hold() -> PlayerHold
LevelSlots: func get_throwables() -> Array[Throwable]

## LightExposureProbe (L2, perception; DATA §9). O PerceivableTarget da F4 (§7.1) lê get_exposure().
@export var update_hz: float = 10.0
@export var ambient_floor: float = 0.0
@export var sample_offsets: PackedVector3Array
func get_exposure() -> float
func sample_now() -> float
func get_sample_count() -> int                     ## teste

## Áudio e UI (L3)
NoiseGain: static func gain_for_db(perceived_db: float) -> float
NoiseAudioRouter: func bind_world(world); func set_listener(listener); func set_random_seed(seed) ## teste
                  static func choose_sound(event: NoiseEvent) -> Dictionary
                  var played_log                   ## teste
RainAmbience: func bind_world(world); func set_listener(listener); func active_layer() -> StringName
              static func layer_for_floor(floor_db) -> StringName; static func thunder_gain_for_floor(floor_db) -> float
              func tick(delta) e func layer_output_db(layer)   ## teste
Subtitles: func text_for(text_key) -> String; func show_subtitle(text_key, duration_s) -> bool
           func get_visible_texts() -> PackedStringArray; func advance(delta)   ## teste
```

## 7. Percepção da IA (L2) — AI Engineer — Fase 4

### 7.1 PerceivableTarget — componente-filho do jogador

```gdscript
class_name PerceivableTarget extends Node3D    ## filho do PlayerRoot; grupo "perceivable"
@export var sample_points: Array[Marker3D]     ## cabeça, tronco, pés
func get_sample_points() -> PackedVector3Array
func get_light_exposure() -> float             ## 0..1, vindo do LightExposureProbe
func get_stance_factor() -> float              ## em pé 1.0 · agachado 0.6 · rastejando 0.35
func get_concealment() -> float                ## 0 exposto .. 1 dentro de esconderijo com proteção total
```

Os dados vêm de componentes irmãos do jogador, ligados pelo PlayerRoot. O VisionSensor só conhece esta classe.

### 7.2 Sensores

```gdscript
class_name VisionSensor extends Node3D
func evaluate(target: PerceivableTarget) -> VisualPercept

class_name HearingSensor extends Node3D
@export var owner_id: StringName
var threshold_db: float                         ## definido pelo AIProfile
func receive(heard: HeardNoise) -> void         ## chamado somente pelo AcousticWorld
func drain() -> Array[HeardNoise]               ## consumido pelo EnemyController no seu tick
```

A fórmula de visibilidade está em DATA_STRUCTURES §3.2.

**Invariante FW-INV-1 (firewall):** o único caminho de informação do jogador para a IA é `VisionSensor.evaluate(PerceivableTarget)` e `HearingSensor.receive(HeardNoise)`. Verificado pelo teste estático ARC-01 e pelo teste de invariância AI-06.

## 8. IA inimiga — AI Engineer — Fase 4/6

### 8.1 EnemyController (L2)

```gdscript
class_name EnemyController extends CharacterBody3D   ## grupo "enemy"
@export var enemy_id: StringName
@export var profile: AIProfile
@export var patrol_route: NodePath
signal state_changed(old: Enums.EnemyState, new: Enums.EnemyState)
signal player_caught()

func get_state() -> Enums.EnemyState
func reset_to(initial: EnemyInitialState) -> void   ## usado pelo CheckpointManager
```

**Tick (process_physics_priority = -40):**
1. Coleta percepts: `vision.evaluate()` para cada nó do grupo `perceivable`, `hearing.drain()` e `squad.messages_for()`.
2. Monta o `PerceptBatch` e chama `brain.tick(dt, batch, world_query)`, onde `world_query` é o adaptador `EnemyWorldQuery` (§8.2).
3. Aplica o `EnemyIntent`: alvo de navegação (NavigationAgent3D), velocidade, olhar, inspeção de esconderijo e fala. A fala é emitida pelo **`NoiseEmitter` filho** (`components/acoustics/`) com `emit_noise(Enums.NoiseCategory.VOICE, ...)`. O controlador nunca constrói `NoiseEvent`.

**Captura (componente filho `EnemyCaptureArea`, Area3D, prioridade -30):** emite `player_caught` (e o controlador repassa `EventBus.player_captured`) quando sobrepõe o corpo do jogador **e** o estado do controlador é CHASE.

**Squad (L2, `components/enemy/squad.gd`, grupo `squad`, prioridade -50, dono: AI Engineer):** um por nível. Contém o `SquadCoordinator` (L1), recebe `post()` dos controladores e libera mensagens com `deliver_at` vencido.

**BrainWorldQuery** (implementado pelo controlador; DATA_STRUCTURES §3):
`is_reachable(point)`, `search_points_near(center, radius)`, `hideables_near(center, radius)`, `patrol_points()`. **Nenhum método retorna dado do jogador.**

**Invariantes**
- ENM-INV-1: a `EnemyCaptureArea` só dispara a captura; o resultado nunca entra no `PerceptBatch`.
- ENM-INV-2: a inspeção de esconderijo (`Hideable.inspect`) entra no brain apenas como `VisualPercept` na posição do esconderijo, e somente se encontrou o jogador.

**Dependências proibidas:** PlayerRoot, PlayerMotor, PhysiologyComponent, PlayerThreatMonitor, grupo `player`, caminhos de nó do jogador.

### 8.2 EnemyBrain, PerceptionMemory, SquadCoordinator (L1)

```gdscript
class_name EnemyBrain extends RefCounted
var state: Enums.EnemyState
var suspicion: float
func _init(profile: AIProfile, rng: RandomNumberGenerator) -> void
func tick(dt: float, percepts: PerceptBatch, world: BrainWorldQuery) -> EnemyIntent

class_name PerceptionMemory extends RefCounted
func record(record: PerceptionRecord) -> void
func decay(dt: float) -> void
func best_lead() -> PerceptionRecord          ## null se não houver pista útil
func clear() -> void

class_name SquadCoordinator extends RefCounted
func post(message: SquadMessage) -> void
func messages_for(enemy_id: StringName, now: float) -> Array[SquadMessage]
```

`BrainWorldQuery` é declarado em L1 como classe base abstrata com métodos que falham se não forem sobrescritos. O EnemyController a fornece por meio de um objeto adaptador (`EnemyWorldQuery extends BrainWorldQuery`), já que o controlador não pode herdar de duas classes.

Transições e limiares numéricos: DATA_STRUCTURES §3.

**Decisões de abertura da F4 (Director):** D4-07, `BrainWorldQuery.self_position()` (o cérebro precisa saber quando chegou a um destino; é a posição do próprio inimigo, não do jogador); `VisualPercept` criado pelo Director em `sim/ai/visual_percept.gd` para os dois agentes da onda A; D4-02, um inimigo na F4 e o `SquadCoordinator` na F6 (`PerceptBatch.squad` vazio); D4-03, o inimigo abre a porta fechada e destrancada na rota (`Door.interact` com o inimigo como ator) e porta trancada nunca é rota; D4-04, captura provisória (tela e reinício da sandbox) até a F5.

**SquadCoordinator:** só aceita mensagens criadas a partir de percepts do próprio remetente. A entrega respeita latência (`deliver_at`). Toda mensagem é acompanhada de fala (VOICE) audível ao jogador.

## 9. Esconderijos (L2) — Gameplay Engineer + AI Engineer — Fase 5

```gdscript
class_name Hideable extends Interactable
@export var hide_type: StringName
@export var visual_protection: float = 1.0
@export var enter_noise_db: float
@export var exit_noise_db: float
@export var muffle_db: float                   ## atenuação dos ruídos do jogador escondido (guarda-roupa ≈ 6, cama ≈ 3)
@export var inspectable: bool = true
func is_occupied() -> bool
func inspect(by_enemy_id: StringName) -> bool

class_name HidingComponent extends Node
signal hidden_changed(is_hidden: bool, spot: Hideable)
func enter(spot: Hideable) -> void
func exit() -> void
func is_hidden() -> bool
```

**Regras**
- Dentro do esconderijo o jogador continua emitindo respiração, chiado e tosse.
- A IA inspeciona por decisão própria, baseada em pistas, nunca por conhecimento da ocupação.
- Entrar ou sair dentro do campo de visão de um inimigo resulta em descoberta (o VisionSensor vê o jogador antes da ocultação).

## 10. Inventory (L1/L2) — Gameplay Engineer — Fase 5

```gdscript
class_name InventoryModel extends RefCounted      ## L1
signal changed()
func _init(capacity: int, catalog: ItemCatalog) -> void
func add(item_id: StringName, quantity: int = 1) -> int
func remove(item_id: StringName, quantity: int = 1) -> bool
func count(item_id: StringName) -> int
func use(item_id: StringName) -> ItemUseResult
func to_dict() -> Dictionary
func from_dict(data: Dictionary) -> void

class_name Inventory extends Node                 ## L2, adaptador; é Saveable
```

**Invariantes:** INV-INV-1 quantidade nunca negativa; INV-INV-2 capacidade nunca excedida; INV-INV-3 `from_dict(to_dict())` é idempotente.

## 11. Objetivos (L1/L2) — Gameplay Engineer — Fase 5

```gdscript
class_name ObjectiveGraph extends RefCounted       ## L1
func _init(definitions: Array[ObjectiveDefinition]) -> void
func notify(event_id: StringName) -> Array[StringName]
func status(objective_id: StringName) -> Enums.ObjectiveStatus
func active_objectives() -> Array[StringName]
func to_dict() -> Dictionary
func from_dict(data: Dictionary) -> void

class_name ObjectiveManager extends Node           ## L2; é Saveable
```

Rotas alternativas: um objetivo tem várias condições de conclusão (OR); cada uma tem pré-requisitos (AND).

## 12. Checkpoint e persistência — Software Architect — Fase 5

```gdscript
## Papel "Saveable": qualquer nó do grupo "saveable" deve ter
@export var persist_id: StringName
func save_state() -> Dictionary
func load_state(data: Dictionary) -> void

class_name CheckpointManager extends Node     ## L2 (usa SaveService L0 e SnapshotSchema L1)
signal checkpoint_saved(checkpoint_id: StringName)
signal restore_started()
signal restore_finished()
func reach(checkpoint_id: StringName) -> void
func restore_last() -> void
```

**Sequência de captura (MASTER §9.10), em ordem obrigatória (teste PER-06):**
1. `PlayerMotor.set_input_locked(true)`
2. `CaptureSequence` (animação)
3. Transição (fade)
4. Carregar o último snapshot
5. Restaurar inventário
6. Restaurar objetivos
7. Restaurar mundo (portas, luzes, props, pickups consumidos, `EnvironmentState`)
8. `EnemyController.reset_to()` para cada inimigo; restaurar o estado do RNG; liberar o input

O tratamento de erros (snapshot inválido, versão desconhecida, falha de gravação) está em SYSTEM_ARCHITECTURE §14.

## 13. Dificuldade (L1/L2) — AI Engineer — Fase 6

```gdscript
class_name DifficultyModel extends RefCounted
func record(metric: StringName, value: float) -> void
func compute() -> DifficultyModifiers
```

**Saídas permitidas:** recursos opcionais, janelas de fuga, duração e intensidade de buscas, frequência de patrulha. **Proibido:** qualquer saída que revele ou aproxime a posição do jogador.

## 14. Apresentação (L3) — Audio Engineer — Fase 2/3

| Componente | Consome | Regra |
|---|---|---|
| `BreathingAudio` | `AcousticWorld.noise_resolved_for_player` com `source_id == &"player"` e categoria BREATHING, WHEEZING, COUGHING ou MEDICATION (acréscimo da F2: o puff da bombinha é som do próprio corpo) | Toca os sons do corpo do jogador em 2D (som "dentro da cabeça"), com sons procedurais de `content/audio/body/` escolhidos por `sound_id`. **Nunca dispara som por conta própria.** |
| `NoiseAudioRouter` | `noise_resolved_for_player` para todos os outros eventos | Toca o som no espaço com `volume_db` derivado de `PropagationResult` (mesma regra de ganho do BreathingAudio, NOI-04 ≤ 0,5 dB) e reverb da sala. Ignora os eventos tratados pelo BreathingAudio. Também toca a ambiência de chuva e trovão a partir do estado de clima do AcousticWorld (F3-003b). |
| `AdaptiveMusic` | `PlayerThreatMonitor.threat_changed` | Usa **apenas** a ameaça percebida pelo jogador. Não assina estados reais de inimigos. |
| `CameraEffects` | Sinais do PhysiologyComponent | Tremor, balanço respiratório e efeitos de tosse, escalados pelas opções de acessibilidade. |

## 15. Serviços L0 (autoloads) — **v1.0, congelado na F1-004 (2026-11-20)**

Os scripts de autoload não declaram `class_name` (o Godot proíbe nome igual ao do autoload). Testes criam instâncias próprias com `const X := preload("res://autoload/<arquivo>.gd")`.

```gdscript
## Log — console + user://logs/game.log (execução anterior em game.prev.log)
signal message_logged(level: int, category: StringName, message: String)   ## acrescentado na F1-004
const DEBUG := 0, INFO := 1, WARN := 2, ERROR := 3
var default_level: int          ## INFO
var file_enabled: bool          ## desligar antes de entrar na árvore (instâncias de teste)
var log_dir: String             ## "user://logs"
func debug(category: StringName, message: String) -> void
func info(category: StringName, message: String) -> void
func warn(category: StringName, message: String) -> void
func error(category: StringName, message: String) -> void
func set_level(category: StringName, level: int) -> void
func get_level(category: StringName) -> int
func get_file_path() -> String

## Settings — persistido em user://settings.cfg; esquema em DATA_STRUCTURES §10
signal changed(key: StringName)
var file_path: String           ## padrão "user://settings.cfg"
var autosave: bool              ## grava no fim do frame após set_value (só dentro da árvore)
func get_value(key: StringName) -> Variant      ## cópia (coleções duplicadas)
func set_value(key: StringName, value: Variant) -> void   ## valida tipo e faixa; rejeita com Log.warn
func get_float(key: StringName) -> float
func get_bool(key: StringName) -> bool
func keys() -> Array[StringName]
func has_key(key: StringName) -> bool
func get_default(key: StringName) -> Variant
func reset_to_defaults(emit_changes: bool = true) -> void
func save_to_disk() -> Error
func load_from_disk() -> Error

## SaveService — I/O genérico; não conhece tipos de jogo
var base_dir: String            ## padrão "user://saves"
func write_json(slot: StringName, data: Dictionary) -> Error    ## escrita atômica (core/atomic_file.gd)
func read_json(slot: StringName) -> Dictionary                  ## {} se ausente ou inválido (com log)
func has_slot(slot: StringName) -> bool
func get_slot_path(slot: StringName) -> String
func is_valid_slot(slot: StringName) -> bool    ## [a-z0-9_], 1–64 caracteres

## GameState
var chapter_id: StringName
var is_production_build: bool   ## build de release ou argumento de usuário --production
func set_chapter(id: StringName) -> void        ## emite EventBus.chapter_changed se mudar

## EventBus — ver §16 (CATALOG e ALLOWED_ARG_TYPES expostos para o teste de reflexão)
```

**`core/atomic_file.gd` (`AtomicFile`)**: `write_text(path, text) -> Error` grava `.tmp`, confere os bytes, move o atual para `.bak` e renomeia. `read_text(path, validator) -> ReadResult` usa o principal; se faltar ou for inválido, usa o `.tmp` e depois o `.bak`. Em build de debug, `simulate_failure_after_bytes` simula uma queda no meio da gravação (PER-09).

**Regra L0:** autoloads só dependem de tipos nativos do Godot e de `core/`. Nunca de `sim/`, `components/` ou `presentation/` (teste ARC-05).

## 16. Catálogo de sinais do EventBus

Payloads apenas com tipos nativos ou `Enums` (L0).

| Sinal | Payload | Emissor | Consumidores permitidos |
|---|---|---|---|
| `player_captured` | `enemy_id: StringName` | EnemyController | CheckpointManager, DifficultyManager, PhysiologyComponent (via PlayerRoot) |
| `checkpoint_reached` | `checkpoint_id: StringName` | CheckpointManager | UI, DifficultyManager |
| `objective_updated` | `objective_id: StringName, status: Enums.ObjectiveStatus` | ObjectiveManager | UI |
| `item_picked` | `item_id: StringName, quantity: int, persist_id: StringName` | Pickup | Inventory, ObjectiveManager |
| `chapter_changed` | `chapter_id: StringName` | GameState | sistemas de nível |
| `chase_started` / `chase_ended` | `enemy_id: StringName` | EnemyController | **somente** DifficultyManager (métricas). Proibido em L3. |
| `subtitle_requested` | `text_key: StringName, duration: float` | AcousticWorld (sons relevantes), falas | UI de legendas |

## 17. Invariantes → testes

| Invariante | Teste (TEST_PLAN) |
|---|---|
| PLR-INV-1 | ARC-06 |
| MOT-INV-1..3 | MOT-01..03 |
| PHY-INV-1 | PHY-09 |
| PHY-INV-2 | PHY-05 |
| PHY-INV-3 | PHY-06 |
| PHY-INV-4 | PHY-10 |
| PHY-INV-5 | PHY-07 |
| PHY-INV-6 | PHY-08, PER-07 |
| TMN-INV-1 | ARC-01 |
| NOI-INV-1..4 | NOI-01..04 |
| FW-INV-1 | ARC-01 + AI-06 |
| ENM-INV-1..2 | AI-07, AI-08 |
| INV-INV-1..3 | INV-01..03 |
| Regras de objetivo (OR/AND, recompensas) | OBJ-01..03 |
| Sequência de captura | PER-06 |

# Estruturas de Dados — DEAD BREATH

| Campo | Valor |
|---|---|
| Versão | 0.2 (DRAFT — Fase 0, revisado após DISC-006) |
| Status | Proposta |
| Responsável | Software Architect |

> Os valores numéricos são **pontos de partida para balanceamento**. Ficam em Resources `.tres` e serão ajustados nas Fases 2–7. Os testes referenciam a config padrão. Mudou a config, revalida os testes.

---

## 0. Enums compartilhados (`core/enums.gd`, L0)

```gdscript
class_name Enums
enum Stance { STAND, CROUCH, CRAWL }
enum Gait { IDLE, SLOW, WALK, SPRINT }
enum RespiratoryState { NORMAL, ACCELERATED, LABORED, SYMPTOMATIC, RECOVERING }
enum StressBand { CALM, TENSE, AFRAID, PANIC }
enum NoiseCategory { FOOTSTEP, RUNNING, BREATHING, WHEEZING, COUGHING, DOOR, OBJECT_IMPACT, MEDICATION, FURNITURE, FALL, VOICE }
enum EnemyState { PATROL, SUSPICIOUS, INVESTIGATE, SEARCH, CHASE, LOST_CONTACT, RETURN }
enum ObjectiveStatus { LOCKED, ACTIVE, COMPLETED, FAILED }
```

`VOICE` vai além das 10 categorias da seção 9.5 e depende da aprovação da proposta P-03.

## 1. Jogador e fisiologia

```gdscript
class_name PhysiologyInputs extends RefCounted
var exertion: float           ## 0..1, PlayerMotor.get_exertion()
var gait: Enums.Gait
var threat: ThreatSample      ## PlayerThreatMonitor.sample()
var is_resting: bool          ## parado e agachado, ou escondido
var in_safe_zone: bool
var is_hidden: bool

class_name CouplingFactors extends RefCounted
var stamina_regen_multiplier: float
var max_sprint_multiplier: float
var sprint_allowed: bool
var steadiness: float          ## 0..1
var tremor_amplitude: float    ## 0..1 (a apresentação escala pela acessibilidade)

class_name PhysiologySnapshot extends RefCounted
var stamina: float
var stress: float
var stress_band: Enums.StressBand
var symptom_severity: float
var breathing_rate: float
var wheezing_intensity: float
var cough_probability: float   ## risco por segundo (hazard)
var recovery_progress: float
var respiratory_state: Enums.RespiratoryState
var medication_charges: int    ## leitura do inventário
var medication_relief_remaining: float
```

### 1.1 PlayerMotorConfig

| Parâmetro | Valor | | Parâmetro | Valor |
|---|---|---|---|---|
| `walk_speed` | 1.6 m/s | | `stand_height` | 1.75 m |
| `slow_walk_speed` | 0.9 m/s | | `crouch_height` | 1.10 m |
| `crouch_speed` | 1.0 m/s | | `crawl_height` | 0.55 m |
| `crawl_speed` | 0.5 m/s | | `capsule_radius` | 0.25 m |
| `sprint_speed` | 4.8 m/s | | `step_height` | 0.30 m |
| `acceleration` | 10 m/s² | | `fall_injury_height` | 2.5 m |
| `deceleration` | 14 m/s² | | `head_bob_amplitude` | 0.03 m |

Esforço por marcha/postura (MOT-INV-2): IDLE 0 · SLOW 0.1 · WALK 0.2 · SPRINT 1.0 · agachado andando 0.15 · rastejando 0.25.

Parâmetros acrescentados na F1-006 (pontos de partida, ajustáveis no `.tres`):

| Parâmetro | Valor | | Parâmetro | Valor |
|---|---|---|---|---|
| `eye_offset` | 0.10 m (topo do colisor → olhos) | | `gravity` | 9.8 m/s² |
| `stance_transition_time_s` | 0.25 s | | `floor_snap_length` | 0.30 m |
| ~~`step_probe_distance`~~ | removido (F1-010): a sondagem do step-up é o movimento do tick + 0,03 m (constante do motor; colisor de base plana) | | `pitch_limit_deg` | 85° |
| `camera_step_smoothing` | 12 /s (decaimento exponencial da altura visual) | | `stride_slow` / `stride_walk` / `stride_sprint` | 0.5 / 0.7 / 1.1 m |
| `stride_crouch` / `stride_crawl` | 0.5 / 0.4 m | | `head_bob_frequency_per_stride` | 0.5 ciclo por passada |

### 1.2 StaminaConfig

| Parâmetro | Valor |
|---|---|
| `max_value` | 100 |
| `sprint_drain_per_s` / `climb_drain_per_s` / `push_furniture_drain_per_s` | 12 / 15 / 10 |
| `regen_delay_s` | 1.2 |
| (nota F2) | `climb_drain_per_s` e `push_furniture_drain_per_s` estão na config, mas reservados: `PhysiologyInputs` ainda não tem entrada de escalar ou empurrar (entra com a mecânica, F5/F6) |
| `regen_walk_per_s` / `regen_slow_per_s` / `regen_idle_per_s` / `regen_rest_per_s` | 4 / 7 / 10 / 14 |
| `safe_zone_regen_multiplier` | 1.3 |
| `sprint_reenable_threshold` | 25 (histerese após esgotar) |

Regeneração efetiva = base × `CouplingFactors.stamina_regen_multiplier` (× 1,3 em local seguro). Com tanque cheio, o sprint dura 100/12 ≈ 8,3 s.

### 1.3 StressConfig

| Parâmetro | Valor |
|---|---|
| `enemy_seen_gain_per_s` | 15 × `seen_proximity` |
| `enemy_heard_gain_per_s` | 5 × `heard_factor` |
| `chase_gain_per_s` | 20 |
| `startle_spike` | `clamp((db − 55)/2 + 10, 10, 25)` para ruído não causado pelo jogador com `perceived_db ≥ 55` |
| `injury_spike` | 20 (queda acima de `fall_injury_height`) |
| `capture_spike` | 40 (durante a CaptureSequence; o estado restaurado vem do snapshot) |
| `decay_delay_s` / `decay_per_s` / `safe_zone_decay_per_s` | 4 / 3 / 8 |
| Faixas | CALM < 25 ≤ TENSE < 50 ≤ AFRAID < 75 ≤ PANIC |

**Esclarecimentos ratificados na F2 (implementação):** os ganhos de visto, ouvido e perseguição se **somam** por segundo. Qualquer ameaça > 0 ou pico zera o contador de `decay_delay_s`. O gasp de susto usa o estresse **antes** do pico (`gasp_min_stress` = 50, `gasp_min_spike` = 15). No início do jogo, o atraso já está vencido.

**Ferimentos (MASTER §9.3):** não há sistema de vida (pilar: sem combate). Um ferimento é um evento (`add_injury`) que gera pico de estresse. Mancar ou sangrar ficam como proposta P-06.

**Consequências do estresse (MASTER §9.3):**

| Consequência | Mecanismo |
|---|---|
| Respiração acelerada | `stress_term` na severidade-alvo (§1.4) |
| Tremores | `tremor_amplitude = smoothstep(50, 100, stress)` |
| Ruídos involuntários | **Gasp de susto:** `startle_spike ≥ 15` com `stress ≥ 50` → evento BREATHING de 42 dB imediato. É sempre causado por um ruído que o jogador também ouviu. |
| Dificuldade em interações delicadas | `steadiness` (§1.6) multiplica o tempo de segurar |

### 1.4 RespiratoryConfig e modelo

```
exertion_ema  = EMA do esforço, τ = 8 s
stress_term   = max(0, stress/100 − 0.3) / 0.7
target        = clamp(0.7·exertion_ema + 0.4·stress_term, 0, 1) · (1 − relief)
severity     += (target > severity ? rise_rate : fall_rate·(is_resting ? 2 : 1)) · dt   (sem ultrapassar o alvo)
breathing_rate     = lerp(14, 40, max(exertion_ema, severity))
wheezing_intensity = smoothstep(0.35, 0.9, severity)
cough_probability  = severity > 0.55 ? 0.25 · ((severity − 0.55)/0.45)² : 0      (por segundo)
```

| Parâmetro | Valor |
|---|---|
| `exertion_time_constant_s` | 8 |
| `rise_rate_per_s` / `fall_rate_per_s` | 0.08 / 0.03 |
| `cough_warning_time_s` | 1.5 |
| `cough_cooldown_s` | 4 |
| `state_min_dwell_s` | 1.0 (vale para toda transição, inclusive a entrada em SYMPTOMATIC; ratificado na F2) |

**Tosse:** a cada tick, se não há tosse pendente nem cooldown e `rng.randf() < cough_probability·dt`, a tosse é agendada para daqui a `cough_warning_time_s` e `cough_warning` é emitido. No momento agendado, se a severidade caiu abaixo de 0.55 (por exemplo, bombinha usada durante o aviso), a tosse é cancelada.

**Transições de estado** (histerese embutida nos limiares; cada transição exige `state_min_dwell_s` no estado atual):

| De | Para | Condição |
|---|---|---|
| NORMAL | ACCELERATED | `ema ≥ 0.40` ou `sev ≥ 0.20` |
| NORMAL, ACCELERATED, RECOVERING | LABORED | `sev ≥ 0.35` |
| qualquer | SYMPTOMATIC | `sev ≥ 0.60` |
| SYMPTOMATIC | LABORED | `sev < 0.55` |
| LABORED | RECOVERING | `sev < 0.30` |
| RECOVERING | NORMAL | `sev < 0.20` e `ema < 0.40` |
| RECOVERING | ACCELERATED | `sev < 0.20` e `ema ≥ 0.40` |
| ACCELERATED | NORMAL | `ema < 0.35` e `sev < 0.15` |

**`recovery_progress`:** em RECOVERING = `clamp((peak − sev)/(peak − 0.20), 0, 1)`, onde `peak` é a maior severidade desde a saída de NORMAL. Em NORMAL = 1. Nos demais estados = 0.

**Verificação dos valores contra o TEST_PLAN** (conferida de forma independente na revisão DISC-006):
- PHY-01: um sprint de 8,33 s leva o EMA a 0,647 → alvo 0,453. A severidade cruza 0,35 em ≈ 5,5 s → LABORED.
- PHY-03: de 0,6 em repouso → < 0,2 em **6,67 s** com EMA inicial entre 0 e 0,65, e em **8,80 s** com EMA 0,857 (medido na F2 e recalculado na revisão F2-010).
- PHY-06: após 60 s de repouso, EMA ≈ 0 e estresse zerado (em 37,3 s a partir de 100) → severidade < 0,2.

### 1.5 Ameaça percebida (PlayerThreatMonitor)

```
seen_proximity = max sobre inimigos vistos de clamp(1 − (d − 3)/12, 0, 1)          ## 1 a ≤ 3 m, 0 a ≥ 15 m
heard_factor   = max sobre PlayerHeardNoise com source_is_enemy (últimos 3 s) de clamp((perceived_db − 15)/30, 0, 1)
threat_level   = max(seen_proximity, 0.5·heard_factor, in_chase ? 1 : 0)
```

### 1.6 CouplingConfig e fórmulas de acoplamento

```
stamina_regen_multiplier = (1 − 0.6·severity) · (1 − 0.3·stress/100)
max_sprint_multiplier    = severity < 0.6 ? 1 : lerp(1.0, 0.75, (severity − 0.6)/0.4)
sprint_allowed           = StaminaModel não está em exaustão (histerese de 25)
steadiness               = clamp(1 − 0.7·smoothstep(40, 100, stress) − 0.3·wheezing_intensity, 0, 1)
tremor_amplitude         = smoothstep(50, 100, stress)
```

A stamina **não** entra na fórmula de severidade (PHY-05).

### 1.7 MedicationProfile (bombinha) e consumíveis

```gdscript
class_name MedicationProfile extends Resource
@export var immediate_reduction: float = 0.35   ## redução ABSOLUTA de severidade, aplicada em 3 s
@export var reduction_time_s: float = 3.0
@export var relief_strength: float = 0.7        ## decai linearmente
@export var relief_duration_s: float = 90.0
@export var cooldown_s: float = 10.0
@export var noise_db: float = 38.0
## efeito em stamina: inexistente por contrato (PHY-INV-2)
```

| Item | Efeito (proposta inicial, detalhar no GDD) |
|---|---|
| Bombinha (`inhaler`) | MedicationProfile acima; 3 doses por unidade |
| Comprimido (`medication_tablet`) | `rise_rate` × 0,7 por 180 s (preventivo); 25 dB ao tomar |
| Água (`water`) | `cough_probability` × 0,5 por 60 s (garganta aliviada); 30 dB ao beber; não altera severidade nem stamina |

## 2. Ruído e acústica

```gdscript
class_name NoiseEvent extends RefCounted      ## NUNCA sai do AcousticWorld para a IA
var id: int
var category: Enums.NoiseCategory
var position: Vector3
var room_id: StringName
var intensity_db: float        ## nível a 1 m da fonte
var duration: float
var source_id: StringName
var sound_id: StringName
var timestamp: float

class_name PropagationResult extends RefCounted
var perceived_db: float
var path_portals: Array[StringName]
var through_wall: bool
var entry_point: Vector3       ## último portal do caminho, ou a fonte se o caminho é direto

class_name HeardNoise extends RefCounted      ## o que a IA recebe; sem dados reais da fonte (NOI-INV-4)
var category: Enums.NoiseCategory
var perceived_db: float
var estimated_position: Vector3
var confidence: float          ## 0..1
var timestamp: float
var effective_threshold_db: float  ## limiar efetivo do OUVINTE (§2.3) neste som; decisão D4-08 (F4), para a suspeita de §3.3
```

```gdscript
class_name PlayerHeardNoise extends RefCounted   ## o que o PlayerThreatMonitor recebe; proibido na IA (ARC-01)
var category: Enums.NoiseCategory
var perceived_db: float
var source_is_enemy: bool
var sound_id: StringName       ## ex.: voice_chase_shout (para in_chase e legendas)
var timestamp: float
```

**Posição estimada:** parte de `entry_point` (o som parece vir da porta por onde entrou na sala) e soma um desvio aleatório de raio `position_error_per_db_lost × (intensity_db − perceived_db)`, usando o RNG do AcousticWorld. **Decisão D-07 (F3):** ponto uniforme num **disco horizontal** (plano XZ) de raio r centrado em `entry_point`, com o mesmo Y. `confidence = clamp((perceived_db − limiar)/20, 0.1, 1)`. Implementado em `HeardNoise.from_propagation` (revisão F3-010, R3-01; o HearingSensor da F4 chama).

**Decisões ratificadas na F3-001:** `through_wall` é verdadeiro quando o caminho escolhido é o direto com ao menos uma **parede** (piso não liga o campo; D-08). Um `Portal` nasce **aberto** e o AcousticWorld sincroniza o estado com a porta ligada (D-09). `NoiseEvent.room_id` é preenchido pelo AcousticWorld com `graph.room_at(position)` na emissão; a propagação usa a posição (observação da F3-001).

### 2.1 Intensidades iniciais (dB a 1 m)

| Categoria | Valor |
|---|---|
| FOOTSTEP rastejando / agachado / andando devagar / andando | 18 / 25 / 32 / 40 |
| RUNNING | 60 |
| BREATHING | 20–35 (§2.4) |
| WHEEZING | 30–42 (§2.4) |
| COUGHING | 65 (abafada: 48, proposta P-01) |
| DOOR lenta / normal / batida | 30 / 50 / 75 |
| OBJECT_IMPACT (inclui objeto de distração arremessado) | 50–80 |
| MEDICATION | 38 |
| FURNITURE | 55–70 |
| FALL | 80 |
| VOICE (fala / grito) | 55 / 75 |

Superfícies: madeira solta +6, tapete −8, azulejo +3, concreto 0. Jogador escondido: −`Hideable.muffle_db`.

**Acréscimos da F3-004 (decisões do Director):**
- Porta trancada sacudida: DOOR 45 dB (`door_locked`).
- Painel batendo num corpo: DOOR 40 dB (`door_normal`).
- Fechar a porta usa os mesmos níveis da abertura: segurar 30, tocar 50. Porta batida (75) fica para os inimigos (F4).
- Queda: FALL só com velocidade de aterrissagem ≥ 2,5 m/s (`content/data/player/fall_noise.tres`). Escada e degrau não geram queda.
- Objeto arremessado: OBJECT_IMPACT de 50 a 80 dB, metade pela velocidade (0,8 a 8 m/s) e metade pelo tamanho (leve, médio, pesado). Silêncio abaixo de 0,8 m/s; no máximo 1 evento a cada 0,25 s por objeto.
- No nível, o piso `wood` é madeira solta (+6).

### 2.2 AcousticConfig

| Parâmetro | Valor |
|---|---|
| `portal_open_loss_db` / `portal_closed_loss_db` | 3 / 18 |
| `wall_transmission_loss_db` / `floor_transmission_loss_db` | 25 / 30 |
| `extra_loss_per_m_db` | 0.1 (ar e obstáculos) |
| `min_distance_m` | 1.0 |
| `position_error_per_db_lost` | 0.05 m |
| Perda por distância | `20·log10(max(d, 1)) + 0.1·d` |

### 2.3 Audibilidade e ruído ambiente (chuva)

```
effective_threshold = max(hearing_threshold_db, ambient_floor_db(sala do ouvinte) + weather_offset + masking_margin_db)
audível  ⇔  perceived_db ≥ effective_threshold
```

`masking_margin_db` vem do AIProfile (§3.1): o Observer, atento, distingue sons 3 dB abaixo do ruído de fundo; o Aggressive precisa de 3 dB acima. O ouvinte do jogador usa `hearing_threshold_db` 10 e margem 0. Como o piso ambiente quase sempre supera 10, na prática o limiar efetivo do jogador é o piso da sala (12 a 38 dB).

| Ambiente (madrugada com chuva) | `ambient_floor_db` |
|---|---|
| Porão e cômodos sem contato com o exterior | 12 (a chuva quase não chega; ambiente perigosamente silencioso) |
| Cômodo interno do térreo/1º andar | 22 |
| Cômodo com janela para fora | 28 |
| Exterior (quintal, garagem aberta) | 38 |
| Trovão | `weather_offset` +20 dB por 2,5 s. Janela de oportunidade para se mover. |
| Fora de qualquer sala | 38 (equivale ao exterior; decisão D-06 da F3-001) |

Limiar efetivo por perfil:

| Ambiente | Observer | Leader | Aggressive |
|---|---|---|---|
| Porão (12) | 15 | 20 | 24 |
| Interno (22) | 19 | 22 | 25 |
| Com janela (28) | 25 | 28 | 31 |
| Exterior (38) | 35 | 38 | 41 |

Exemplos com a config padrão, Observer em cômodo interno (limiar efetivo 19). Perda = `20·log10(d) + 0.1·d`:
- Respiração calma no guarda-roupa: 20 − 6 = 14 dB a 1 m → inaudível a qualquer distância.
- Respiração ofegante no guarda-roupa: 30 − 6 = 24 dB a 1 m → audível até ≈ 1,7 m (o inimigo precisa estar colado).
- Chiado forte no guarda-roupa: 42 − 6 = 36 dB → audível até ≈ 6,6 m. É o perigo real.
- Tosse através de uma parede: 65 − 25 = 40 dB → audível até ≈ 10 m. Através de duas paredes: 15 dB → inaudível.
- Tosse no quintal (exterior, limiar 35): audível até ≈ 24 m.
- No porão (limiar 15), a mesma respiração ofegante no esconderijo é audível até ≈ 2,7 m.

Esses alcances são verificados pelo teste STL-07.

### 2.4 BreathParams (função pura L1)

```
period_s     = 60 / breathing_rate
intensity_db = lerp(20, 35, (breathing_rate − 14)/26)
se wheezing_intensity > 0.1: categoria = WHEEZING, intensity_db = max(intensity_db, lerp(30, 42, wheezing_intensity))
sound_id     = família da respiração: breath_calm | breath_fast | breath_labored
               (a de maior ciclo nominal que cabe em 1,15 × period_s; LABORED/SYMPTOMATIC preferem breath_labored quando cabe)
chiado       = marcado por categoria WHEEZING; o BreathingAudio toca a camada `wheeze` a partir da expiração
               (decisão do Architect na F2-006b: com sound_id = wheeze, a inspiração e a expiração sumiriam justamente na crise)
```

`sound_id` dos sons do corpo fora do ciclo (F2-006a, confirmados pelo Architect): `cough_warning` (pigarro de 1,5 s que antecede a tosse; COUGHING **32 dB**: ouvido de perto, não chama atenção de longe), `cough` (COUGHING, intensidade de §2.1), `gasp` (susto, BREATHING 42 dB), `inhaler_puff` (MEDICATION 38 dB). Tosse cancelada no aviso não gera som (a versão abafada depende de P-01).

**Volume ouvido pelo jogador (F2-006b; revisto na F3-003b):** até a referência de 45 dB, `ganho_db = max(perceived_db − 45, −45)`; acima dela, `ganho_db = min((perceived_db − 45)/4, +6)`. A mesma regra vale para o corpo (BreathingAudio) e para o mundo (NoiseAudioRouter), em `NoiseGain`. **Decisão do Director (integração da F3-003b):** a regra antiga saturava em 0 dB acima de 45, e porta normal (50), corrida (60), tosse (65) e porta batida (75) soavam iguais. Agora a ordem se mantém até 69 dB, onde o ganho chega ao teto; acima disso, o timbre do clip diferencia. Abaixo de 45 nada muda. O Master tem um limitador com teto de −1 dBFS (`default_bus_layout.tres`), porque os picos dos clips ficam entre −10 e −4 dBFS. A chuva usa o trecho 1:1 com compensação do RMS do clip. O trovão soa no nível do limiar que impõe, `piso + 20 dB`, pela mesma regra: +3,25 dB ao ar livre e −3 dB num cômodo interno (revisão F3-010, R3-07). Referência, razão e teto: calibrar no playtest. **Encadeamento:** `pitch = clamp(nominal/period, 0,87, 1,15)`; o que sobra do período é silêncio; a expiração nunca é cortada. Arquivos e variações: `game/content/audio/body/manifest.json` (papéis inhale, exhale, layer, one_shot).

### 2.5 Nós de nível

```gdscript
class_name RoomVolume extends Area3D
@export var room_id: StringName
@export var ambient_floor_db: float = 12.0
@export var reverb_bus: StringName

class_name Portal extends Node3D
@export var portal_id: StringName
@export var room_a: StringName
@export var room_b: StringName
@export var door: NodePath     ## opcional; a porta atualiza o estado aberto/fechado
```

## 3. IA

```gdscript
class_name VisualPercept extends RefCounted
var visibility: float
var position: Vector3          ## válido somente se visibility > 0
var timestamp: float

class_name PerceptBatch extends RefCounted
var visual: Array[VisualPercept]
var heard: Array[HeardNoise]
var squad: Array[SquadMessage]

class_name PerceptionRecord extends RefCounted
var position: Vector3
var timestamp: float
var confidence: float
var source: StringName         ## &"vision", &"hearing", &"squad"

class_name SquadMessage extends RefCounted
var sender_id: StringName
var kind: StringName           ## &"spotted", &"heard", &"search_sector", &"all_clear"
var position: Vector3
var sent_at: float
var deliver_at: float

class_name EnemyIntent extends RefCounted
var move_target: Vector3
var move_speed: float
var look_target: Vector3
var inspect_hideable: StringName
var voice_line: StringName

class_name BrainWorldQuery extends RefCounted   ## base abstrata; implementada por EnemyWorldQuery
func self_position() -> Vector3                 ## posição do próprio inimigo (acréscimo D4-07; não é dado do jogador)
func is_reachable(point: Vector3) -> bool
func search_points_near(center: Vector3, radius: float) -> PackedVector3Array
func hideables_near(center: Vector3, radius: float) -> Array[HideableInfo]
func patrol_points() -> PackedVector3Array

class_name HideableInfo extends RefCounted
var persist_id: StringName
var position: Vector3

class_name EnemyInitialState extends Resource
@export var spawn_position: Vector3
@export var patrol_route: NodePath
@export var state: Enums.EnemyState = Enums.EnemyState.PATROL
```

### 3.1 AIProfile

| Parâmetro | OBSERVER | AGGRESSIVE | LEADER |
|---|---|---|---|
| `sight_range_m` | 16 | 12 | 14 |
| `fov_deg` | 110 | 90 | 100 |
| `hearing_threshold_db` | 15 | 24 | 20 |
| `masking_margin_db` | −3 | +3 | 0 |
| `vision_suspicion_gain_per_s` | 1.6 | 1.0 | 1.3 |
| `hearing_suspicion_per_db` | 0.04 | 0.02 | 0.03 |
| `hearing_suspicion_cap_per_event` | 0.6 | 0.4 | 0.5 |
| `suspicion_decay_per_s` (após 2 s sem estímulo) | 0.05 | 0.15 | 0.10 |
| `suspicious_threshold` / `investigate_threshold` | 0.25 / 0.5 | 0.25 / 0.5 | 0.25 / 0.5 |
| `visual_confirm_time_s` | 0.6 | 1.0 | 0.8 |
| `min_visibility_for_confirm` | 0.4 | 0.4 | 0.4 |
| Velocidade patrulha / investigação / perseguição (m/s) | 1.2 / 1.8 / 4.2 | 1.5 / 2.5 / 5.0 | 1.3 / 2.0 / 4.5 |
| `lost_contact_pursuit_s` | 6 | 12 | 8 |
| `search_duration_s` | 60 | 30 | 45 |
| `inspect_hideable_chance` | 0.6 | 0.3 | 0.45 |
| `memory_confidence_decay_per_s` | 0.02 | 0.05 | 0.03 |
| `squad_latency_s` | 1.5 | 1.5 | 1.0 |
| Papel no esquadrão | relata pistas | obedece parcialmente (50%) | atribui setores de busca |

O jogador corre a 4,8 m/s. Só o Aggressive é mais rápido: contra ele, quebrar a linha de visão é obrigatório.

### 3.2 Visibilidade

```
se ângulo > fov/2 ou d > sight_range: visibility = 0
los_fraction    = pontos de amostragem visíveis / total            (raycast contra mundo e props)
distance_factor = 1 − (d / sight_range)²
light_factor    = lerp(0.1, 1.0, light_exposure);  se d ≤ 1.5: max(light_factor, 0.6)
visibility      = los_fraction · distance_factor · light_factor · stance_factor · (1 − concealment)
```

### 3.3 Suspeita, confirmação e transições

```
suspicion += vision_suspicion_gain · visibility · dt
suspicion += min(cap, hearing_suspicion_per_db · (perceived_db − effective_threshold))  por HeardNoise (§2.3)
suspicion −= suspicion_decay · dt                                                     após 2 s sem estímulo
confirm   += visibility · dt   se visibility ≥ min_visibility_for_confirm;  senão confirm = max(0, confirm − 2·dt)
```

| De | Para | Condição |
|---|---|---|
| qualquer | CHASE | `confirm ≥ visual_confirm_time_s` |
| PATROL | SUSPICIOUS | `suspicion ≥ 0.25` (para e olha para o estímulo) |
| SUSPICIOUS | INVESTIGATE | `suspicion ≥ 0.5` (vai até `best_lead`) |
| SUSPICIOUS | PATROL | `suspicion < 0.15` |
| INVESTIGATE | SEARCH | chegou à pista e passou 3 s sem visibilidade |
| CHASE | LOST_CONTACT | visibilidade 0 por 1,5 s contínuos |
| LOST_CONTACT | SEARCH | chegou à última posição conhecida ou passaram `lost_contact_pursuit_s` |
| SEARCH | RETURN | `search_duration_s × search_duration_multiplier` sem nova pista |
| RETURN | PATROL | chegou ao ponto de patrulha mais próximo |
| PATROL, SUSPICIOUS, SEARCH, RETURN | INVESTIGATE | novo ruído leva `suspicion ≥ 0.5` |

Transições em cascata no mesmo tick são permitidas (PATROL → SUSPICIOUS → INVESTIGATE).

**Decisão D4-08 (F4):** o limiar efetivo usado na suspeita por audição vem do próprio `HeardNoise.effective_threshold_db`, preenchido pelo AcousticWorld na entrega. Se a pista de INVESTIGATE não for alcançável (`is_reachable` falso) ou se passarem 15 s sem chegar a ela, o estado passa a SEARCH a partir da posição atual (evita travar com navegação impossível).

**Falas do Observer (D4-06, F4):** `EnemyIntent.voice_line` é o `sound_id` da fala, posto uma vez na transição (não a cada tick). O controlador emite VOICE pelo NoiseEmitter filho com a intensidade de §2.1.

| Transição | `voice_line` | Intensidade | Legenda |
|---|---|---|---|
| → SUSPICIOUS | `voice_suspicious` | 55 (fala) | murmúrio |
| → INVESTIGATE | `voice_investigate` | 55 (fala) | "Quem está aí?" |
| → CHASE | `voice_chase_shout` | 75 (grito) | grito; o PlayerThreatMonitor usa este id para `in_chase` |
| → SEARCH | `voice_search` | 55 (fala) | "Cadê você?" |

Os textos das legendas são provisórios até as respostas de narrativa (N-01..N-05).

Conferência AI-03 (Observer, jogador em pé, iluminado, a 8 m, no FOV): visibilidade = 1 × 0,75 × 1 × 1 = 0,75 → `confirm` chega a 0,6 em 0,8 s → CHASE (limite do teste: 1,5 s).

## 4. Inventário e objetivos

```gdscript
class_name ItemDefinition extends Resource
@export var id: StringName
@export var name_key: StringName
@export var category: StringName      ## medication, consumable, key, tool, document, distraction
@export var stackable: bool
@export var max_stack: int
@export var charges: int
@export var use_noise_db: float

class_name ItemCatalog extends Resource
@export var items: Array[ItemDefinition]

class_name ItemUseResult extends RefCounted
var success: bool
var consumed: int
var reason: StringName                ## &"ok", &"cooldown", &"empty", &"not_usable"

class_name ObjectiveDefinition extends Resource
@export var id: StringName
@export var kind: StringName          ## main, secondary
@export var prerequisites: Array[StringName]
@export var completion_events: Array[StringName]
@export var reward_items: Array[StringName]
```

## 5. Interação e ameaça

`InteractionContext` fica em `components/interaction/` (L2), porque referencia `Node`. `ThreatSample` fica em `sim/physiology/` (L1).

```gdscript
class_name InteractionContext extends RefCounted
var actor: Node
var steadiness: float
var is_hidden: bool

class_name ThreatSample extends RefCounted
var threat_level: float
var seen_proximity: float
var heard_factor: float
var in_chase: bool
```

## 6. Snapshot de checkpoint (JSON, `schema_version` 1)

```json
{
  "schema_version": 1,
  "chapter_id": "ch1_intrusion",
  "checkpoint_id": "ch1_cp_kitchen",
  "timestamp_utc": "2026-11-20T03:12:00Z",
  "rng_states": { "physiology": "8817263540012345", "acoustics": "1029384756", "ai_observer": "5647382910" },
  "player": {
    "position": [0.0, 0.0, 0.0], "rotation_y": 0.0, "stance": "STAND",
    "physiology": {
      "stamina": { "value": 80.0, "exhausted": false, "regen_delay_remaining": 0.0 },
      "stress": { "value": 20.0, "time_since_threat": 6.0 },
      "respiratory": {
        "severity": 0.1, "exertion_ema": 0.05, "state": "NORMAL", "state_dwell": 12.0, "peak_severity": 0.1,
        "pending_cough_in": -1.0, "cough_cooldown_remaining": 0.0,
        "relief_strength": 0.0, "relief_remaining": 0.0, "reduction_remaining": 0.0, "medication_cooldown_remaining": 0.0,
        "consumable_effects": { "medication_tablet": 0.0, "water": 0.0 }
      }
    }
  },
  "inventory": [ { "item_id": "inhaler", "quantity": 1, "charges": 3 } ],
  "objectives": { "find_car_keys": "ACTIVE", "check_phone_line": "COMPLETED" },
  "world": { "door_kitchen_back": { "state": "LOCKED" }, "light_hall_1": { "on": false } },
  "environment_state": { "blocked_doors": ["door_front"], "lights_off": ["light_hall_1"], "route_overrides": {} },
  "consumed_pickups": [ "pickup_inhaler_bathroom" ],
  "enemies_initial_state": { "observer": "res://content/levels/ch1/observer_cp_kitchen.tres" },
  "difficulty_metrics": { "captures": 2, "chapter_time_s": 840.0 }
}
```

O estado de cada RNG (`RandomNumberGenerator.state`, inteiro de 64 bits) é gravado como **string**. O JSON do Godot lê números como float (53 bits) e corromperia o valor.

### 6.1 Regra de completude do snapshot

Todo campo que afeta um tick futuro precisa estar no snapshot. Para a fisiologia:

| Modelo | Campos obrigatórios |
|---|---|
| StaminaModel | `value`, `exhausted` (histerese de 25), `regen_delay_remaining` |
| StressModel | `value`, `time_since_threat` (para `decay_delay_s`) |
| RespiratoryModel | `severity`, `exertion_ema`, `state`, `state_dwell`, `peak_severity`, `pending_cough_in` (−1 = nenhuma), `cough_cooldown_remaining`, `relief_strength`, `relief_remaining`, `reduction_remaining`, `medication_cooldown_remaining`, `consumable_effects` |
| BreathEmitter | `cycle_phase_s`, `next_event_in_s` |
| PlayerThreatMonitor | `last_seen_chase_s` (tempo desde o último inimigo visto em CHASE), `recent_enemy_heard` (lista de `{category, perceived_db, sound_id, age_s}` dos últimos 3 s) |

A mesma regra vale para cada `Saveable` e para o estado interno dos inimigos quando a F6 introduzir estados persistentes. O teste PER-07 compara **campo a campo** e depois confirma a continuação idêntica.

## 7. Dificuldade

```gdscript
class_name DifficultyModifiers extends RefCounted
var optional_resource_bonus: float      ## 0..1
var escape_window_bonus_s: float        ## 0..3
var search_duration_multiplier: float   ## 0.7..1.2
var patrol_frequency_multiplier: float  ## 0.8..1.2
```

Métricas: capturas, falhas por objetivo, tempo de progressão, recursos disponíveis, perseguições vencidas e perdidas.

## 8. EnvironmentState (mudanças ambientais, MASTER §10.1)

Estado nomeado por capítulo, persistido no snapshot: `blocked_doors`, `lights_off`, `moved_objects`, `route_overrides` (rotas de IA alteradas), `danger_zones`, `unlocked_paths`. É alterado por eventos de objetivo ou de roteiro. O contrato completo é congelado na Fase 6.

## 9. Declarações complementares

```gdscript
## L1 — sim/physiology/
class_name CouplingConfig extends Resource
@export var regen_severity_penalty: float = 0.6
@export var regen_stress_penalty: float = 0.3
@export var sprint_limit_start_severity: float = 0.6
@export var sprint_limit_min_multiplier: float = 0.75
@export var steadiness_stress_weight: float = 0.7
@export var steadiness_stress_range: Vector2 = Vector2(40, 100)
@export var steadiness_wheeze_weight: float = 0.3
@export var tremor_stress_range: Vector2 = Vector2(50, 100)

class_name BreathParams extends RefCounted
var period_s: float
var category: Enums.NoiseCategory
var intensity_db: float
var sound_id: StringName
static func from_snapshot(s: PhysiologySnapshot) -> BreathParams

## L1 — sim/ai/
class_name AIProfile extends Resource
@export var sight_range_m: float
@export var fov_deg: float
@export var hearing_threshold_db: float
@export var masking_margin_db: float
@export var vision_suspicion_gain_per_s: float
@export var hearing_suspicion_per_db: float
@export var hearing_suspicion_cap_per_event: float
@export var suspicion_decay_per_s: float
@export var suspicious_threshold: float
@export var investigate_threshold: float
@export var visual_confirm_time_s: float
@export var min_visibility_for_confirm: float
@export var patrol_speed: float
@export var investigate_speed: float
@export var chase_speed: float
@export var lost_contact_pursuit_s: float
@export var search_duration_s: float
@export var inspect_hideable_chance: float
@export var memory_confidence_decay_per_s: float
@export var squad_latency_s: float
@export var squad_obedience: float          ## 1.0 = sempre segue ordens do Leader

## L1 — sim/persistence/
class_name SnapshotSchema extends RefCounted
const CURRENT_VERSION: int = 1
static func validate(data: Dictionary) -> PackedStringArray     ## lista de erros; vazia = válido
static func migrate(data: Dictionary) -> Dictionary             ## aplica migrações até CURRENT_VERSION; {} se impossível

## L2 — components/enemy/
class_name EnemyWorldQuery extends BrainWorldQuery
func _init(controller: EnemyController, navigation_map: RID) -> void

## L2 — components/perception/ (usado pelo jogador e pelos inimigos)
class_name LightExposureProbe extends Node3D
@export var update_hz: float = 10.0
func get_exposure() -> float      ## 0..1: soma das luzes do grupo "gameplay_light", com atenuação por distância e oclusão por raycast

## L2 — components/player/
class_name StubThreatSource extends ThreatSource   ## F2/F3: ameaça definida pelo overlay de debug ou pelo teste
var forced: ThreatSample

## L2 — components/interaction/
class_name Pickup extends Interactable
@export var persist_id: StringName
@export var item_id: StringName
@export var quantity: int = 1
func save_state() -> Dictionary    ## { "consumed": bool }
func load_state(data: Dictionary) -> void
```

As configs das §1–2 (`PlayerMotorConfig`, `StaminaConfig`, `StressConfig`, `RespiratoryConfig`, `AcousticConfig`) seguem o mesmo padrão de `CouplingConfig`: `class_name <Nome> extends Resource`, com um `@export` por linha das tabelas, mesmo nome e mesmo valor padrão. Elas ficam em `sim/physiology/`, `sim/acoustics/` e `components/player/` (PlayerMotorConfig). `ThreatSource` está declarado em COMPONENT_CONTRACTS §5.

```gdscript
## L2 — components/enemy/
class_name EnemyCaptureArea extends Area3D
signal player_caught()
@export var controller: NodePath     ## EnemyController dono; a captura só vale em CHASE
```

## 10. Esquema do Settings (F1-004, 2026-11-20)

Persistido em `user://settings.cfg` (ConfigFile, seção `settings`) com escrita atômica (`core/atomic_file.gd`). Valor de tipo errado, número não finito (NaN, ±INF) ou chave desconhecida → rejeitado com `Log.warn`. Número finito fora da faixa → limitado à faixa. `int` é aceito onde se espera `float`.

| Chave | Tipo | Padrão | Faixa | Significado |
|---|---|---|---|---|
| `mouse_sensitivity` | float | 0.12 | 0.02–0.6 | Graus de rotação por pixel de mouse |
| `invert_y` | bool | false | — | Inverte o eixo vertical da câmera |
| `fov` | float | 75.0 | 60–100 | Campo de visão vertical (graus) |
| `motion_reduction` | float | 0.0 | 0–1 | Redução do movimento de câmera (head bob, balanço). **1 = sem movimento** |
| `tremor_reduction` | float | 0.0 | 0–1 | Redução de tremores (crise, pânico). **1 = sem tremor** |
| `effects_intensity` | float | 1.0 | 0–1 | Escala linear de todos os efeitos de câmera e tela (ACC-02) |
| `respiratory_indicator` | bool | false | — | Indicador visual de condição respiratória (ACC-03, desligado por padrão) |
| `subtitles_enabled` | bool | true | — | Legendas de sons relevantes e falas |
| `subtitles_size` | float | 1.0 | 0.75–2.0 | Escala do texto das legendas |
| `master_volume` | float | 1.0 | 0–1 | Volume linear do barramento Master (0 = mudo). Aplicado pelo próprio Settings no AudioServer |
| `input_bindings` | Dictionary | `{}` | — | Ligações do usuário por ação; `{}` = padrões do `project.godot`. Formato definido na F1-013 |

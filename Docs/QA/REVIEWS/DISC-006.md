# DISC-006 — Revisão técnica independente da Fase 0

| Campo | Valor |
|---|---|
| Data | 2026-11-20 |
| Revisor | Technical Reviewer (Agente 10), em contexto independente. Não participou da escrita dos documentos. |
| Tarefa | DISC-006 (TASK_BOARD §3) |
| Fonte de verdade | Docs/MASTER_PROMPT.md (V4.0) |
| Escopo | Docs/Architecture/ENGINE_DECISION.md, SYSTEM_ARCHITECTURE.md, COMPONENT_CONTRACTS.md, DATA_STRUCTURES.md; Docs/Development/ROADMAP.md, TASK_BOARD.md, AGENT_ASSIGNMENTS.md, KNOWN_ISSUES.md, CHANGELOG.md; Docs/QA/TEST_PLAN.md; README.md |
| Método | Leitura integral dos documentos. Cruzamento por busca textual (IDs, nomes de tipos, termos de requisito). Recalculo da matriz ponderada e da sensibilidade. Simulação numérica da fisiologia com os valores de DATA_STRUCTURES §1 (passo de 1 ms). Análise de precisão das APIs do Godot 4 por conhecimento próprio, com grau de confiança. |
| Limitações | Sem acesso à internet: versões, datas e preços de terceiros não foram reverificados. Godot não foi executado nem baixado (conforme restrição da tarefa). Os valores de confiança das APIs do Godot são indicados caso a caso. |

---

## 1. Veredito geral

**REPROVADO na forma atual.**

A escolha de engine (Godot 4.7.2 + GDScript tipado) não é reprovada, e a aritmética da matriz está correta. O que reprovo é o pacote de contratos como base para congelamento. Há:

- 1 achado CRÍTICO: o contrato de `HeardNoise` vaza a posição real do jogador para a IA (R-01), quebrando o firewall de percepção, que é requisito explícito (MASTER §6.5 e §9.6).
- 11 achados ALTO: contradições de gate (ADR-001 §7 × Gate F0), violações da própria regra de camadas, contratos que não compilam em GDScript, requisitos obrigatórios sem tarefa (acessibilidade, objetivos da Fase 0) e parâmetros de IA não executáveis.

**Condição de reavaliação:** correção de R-01 a R-12, e revisão dos MÉDIOS que alteram contratos (R-13 a R-22). Não é necessário reabrir a escolha da engine para isso.

## 2. Contagem de achados

| Severidade | Quantidade | IDs |
|---|---|---|
| CRÍTICO | 1 | R-01 |
| ALTO | 11 | R-02 a R-12 |
| MÉDIO | 23 | R-13 a R-35 |
| BAIXO | 13 | R-36 a R-48 |
| **Total** | **48** | |

---

## 3. Verificações numéricas

### 3.1 Matriz de engine (ENGINE_DECISION §4–5)

| Item | Resultado |
|---|---|
| Soma dos pesos | 100. Confere. |
| Totais Σ(nota × peso) / 5 | UE5 = 61, Unity 6 = 69, Godot = 86, Engine própria = 69. **Confere com a ADR.** |
| Sensibilidade (pesos de estúdio) | UE5 = 81, Unity = 73, Godot = 75, Própria = 52. **Confere.** |
| Robustez (extra desta revisão, pesos iguais de 10) | UE5 = 68, Unity = 74, Godot = 84, Própria = 68. Godot continua em 1.º. Vale citar isso na ADR. |
| Observação | Unity e Engine própria empatam em 69 com os pesos declarados. A ADR não menciona o empate ao escolher Unity como runner-up. |

### 3.2 Fisiologia (DATA_STRUCTURES §1 × TEST_PLAN §2.1)

Simulação com EMA τ = 8 s, alvo = 0,7·EMA (estresse 0), subida 0,08/s, descida 0,03/s (0,06/s em repouso), passo de 1 ms.

| Teste | Resultado da verificação |
|---|---|
| PHY-01 | Sprint de 8,33 s: EMA = 0,647, alvo = 0,453, severidade = 0,453. Cruza 0,35 (LABORED) em t ≈ 5,5 s. **Passa.** O texto diz "alvo ≈ 0,46"; o correto é 0,45 (R-48). |
| PHY-02 | Estresse 80 adiciona 0,4 × 0,714 = 0,286 ao alvo. **Passa.** |
| PHY-03 | De 0,6 em repouso, cai abaixo de 0,2 em 6,7 s (EMA inicial de 0 a 0,5), 7,7 s (0,75) e 10,0 s (1,0). Limite de 25 s. **Passa.** |
| PHY-04 | Redução absoluta de 0,35 ≥ 0,30. **Passa.** Se "0,35 de severidade" for relativo (35% de 0,6 = 0,21), **falha** (R-21). |
| PHY-05 | Independência garantida por construção (PHY-INV-2). Passa, desde que stamina não entre na fórmula de severidade (ver R-20). |
| PHY-06 | Após 60 s, EMA ≈ 0,0006 × E0. Estresse zera em 37,3 s (texto diz "≤ 37 s"). Severidade de 1,0 chega abaixo de 0,2 em ≈ 13 s. **Passa.** |
| PHY-07, PHY-08 | Não verificáveis por cálculo: o modelo de probabilidade de tosse e o estado do RNG não estão especificados (R-20, R-24). |

### 3.3 Furtividade e stamina

| Teste ou parâmetro | Resultado |
|---|---|
| STL-01 | Ordem 18 < 25 < 40 < 60 < 65 < 80 dB. **Passa.** |
| STL-02 | Parede de 25 dB ≥ 20 dB exigidos. **Passa.** |
| STL-03 | 18 − 3 = 15 dB, exatamente o limite. **Passa no limite** (R-37). |
| StaminaConfig | 100 / 12 = 8,33 s, coerente com "≈ 8 s". |

---

## 4. Cobertura de requisitos (MASTER §9, §11, §12, §15, §16, §19)

| Seção | Situação | Lacunas (IDs) |
|---|---|---|
| §9.1 Player Controller | Coberta por contrato e tarefas. | Sem PlayerMotorConfig (R-28). Sem contrato de EnemyController, que integra IA (R-10). |
| §9.2 Respiratory | Estados e variáveis presentes. `MedicationCharges` foi movido para o Inventory, com desvio declarado (aceitável). | `recovery_progress` sem fórmula (R-20). Transição 0,20–0,35 sem regra (R-20). |
| §9.3 Stress | Fontes e bandas presentes. | "Ferimentos" ausente em todos os documentos (R-11). Produtores das entradas indefinidos (R-11). Consequências sem mecanismo (R-11). |
| §9.4 Stamina | Ações consumidoras e recuperação parcialmente presentes. | "Locais seguros" sem parâmetro (R-28). "Esforço físico" genérico. |
| §9.5 Noise | Dez categorias presentes, e VOICE declarado como proposta. | Modificadores ambientais limitados a superfície. Sem piso de ruído de chuva (R-13). |
| §9.6 Enemy AI | Sete estados e três perfis presentes. | Parâmetros qualitativos (R-09). Sem contrato de EnemyController (R-10). |
| §9.7 Hideable | Entrada, saída, ruído e inspeção presentes. | Sem teste de entrada/saída (R-22). |
| §9.8 Inventory | Tipos de item presentes. | "Água" sem definição (R-43). Invariantes sem teste (R-22). |
| §9.9 Difficulty | Métricas e saídas presentes, e saídas proibidas declaradas. | Sem teste de dificuldade adaptativa. |
| §9.10 Checkpoint | Sequência de 8 passos presente no contrato. | Ordem da sequência sem teste (R-22). "Sem perda indevida" sem teste (R-22). |
| §9.11 Objectives | Estrutura e prerrequisitos presentes. | `ObjectiveStatus` indefinido (R-19). Sem teste de OR/AND (R-22). |
| §11 Interface e acessibilidade | Redução de movimento e tremor presentes. | Legendas, remapeamento e indicadores respiratórios sem tarefa (R-07). Intensidade de efeitos vaga (R-07). |
| §12 Plano por fase | Fases 0–8 planejadas no ROADMAP. | Objetivos da Fase 0 sem evidência (R-08). "Animações" da Fase 2 ausente (R-30). Localização e Steam sem proposta (R-31). |
| §15 Testes obrigatórios | As seis categorias têm IDs. | Invariantes sem ID (R-22). Gate F2 omite PHY-07 e PHY-08 (R-23). |
| §16 Documentação | Os 8 documentos de Gameplay, 5 de Design e 4 de QA estão no calendário. | Deferimento não formalizado como decisão (R-46). ADRs 002–010 sem corpo (R-33). |
| §19 Primeira execução | Os 12 passos têm artefato. | Evidências de DISC-001/002 não gravadas (R-34). |

Fora dos seis itens pedidos, mas obrigatórios: §10.1 (mudanças ambientais) e §5.2 (progressão mecânica por capítulo) sem tarefa (R-32).

---

## 5. Tabela de achados

| ID | Severidade | Arquivo e seção | Problema | Recomendação |
|---|---|---|---|---|
| R-01 | CRÍTICO | DATA_STRUCTURES §2 (`HeardNoise.event`, `NoiseEvent`); COMPONENT_CONTRACTS §5 (`HearingSensor.noise_heard`); SYSTEM_ARCHITECTURE §5 | `HeardNoise` carrega o `NoiseEvent` completo, com `position` real da fonte, `room_id` e `source_id = &"player"`. O EnemyBrain recebe a posição exata do jogador a cada passo ou respiração audível. Isso quebra o firewall (§5), MASTER §6.5 ("não possuam conhecimento global") e o teste AI-06. | Restringir `HeardNoise` a `category`, `perceived_db`, `estimated_position`, `confidence` e `timestamp`. Proibir que `NoiseEvent` cruze a fronteira do NoiseBus/AcousticGraph/Router. Estender ARC-01 para verificar que nenhum campo de `HeardNoise` contém posição real. Registrar a regra na ADR-003. |
| R-02 | ALTO | ENGINE_DECISION §7 × ROADMAP "Gate F0" × TASK_BOARD DISC-003 e F1-002 | ENGINE §7 diz que a ADR só vira APPROVED após o spike. O Gate F0 exige apenas aprovação de D-01 a D-04, sem spike. DISC-003 (spike V1–V5, em F0, BLOCKED) e F1-002 (mesmo spike V1–V5, em F1) estão duplicados. Não está claro quando a ADR é aprovada nem quem é dono do spike. | Escolher uma opção. (a) Spike DISC-003 como critério do Gate F0, desbloqueado por D-04, e remover F1-002 ou reduzi-lo a integração. (b) Aprovar a ADR no Gate F0, com spike como primeiro critério da F1 e reabertura explícita se falhar. Alinhar ROADMAP, TASK_BOARD e ENGINE §7. |
| R-03 | ALTO | SYSTEM_ARCHITECTURE §2 (regra de camadas) e §3 (tabela de módulos); COMPONENT_CONTRACTS §4 | A camada mais baixa (L0, autoloads) depende de tipos de camadas superiores: `NoiseBusService.set_acoustic_graph(AcousticGraph)` (L1) e `register_listener(HearingSensor)` (L2). A §3 ainda classifica NoiseBus, NoiseEmitter e CheckpointManager como "L0/L1/L2", o que torna a regra inverificável. | Tirar do L0 a lógica do NoiseBus. Ele vira nó de cena L2, que recebe grafo e listeners por injeção, ou fica no L0 apenas como barramento genérico de sinais. Reclassificar NoiseBus, NoiseEmitter e CheckpointManager com uma única camada cada. Criar verificação ARC para dependências ascendentes. |
| R-04 | ALTO | SYSTEM_ARCHITECTURE §3 (diagrama: `Motor --> PhysComp`, `PhysComp --> Emitter`); COMPONENT_CONTRACTS §1 (dependências proibidas), §3 e §4 | O diagrama faz o PlayerMotor depender do PhysiologyComponent, o que o §1 proíbe. O contrato também cria acoplamento de mão dupla: PhysComp lê `get_exertion()` e chama `set_speed_multiplier()` no Motor. O diagrama liga PhysComp direto ao Emitter, enquanto COMPONENT §3 diz que o Emitter observa sinais. | Fluxo unidirecional. O Motor emite `exertion` e `gait` por sinal. O PhysComp publica `CouplingFactors` por sinal, e o Motor aplica os limites. O Emitter observa sinais de PhysComp e Motor, sem chamada direta. Corrigir diagrama e contratos. |
| R-05 | ALTO | COMPONENT_CONTRACTS §5 (`PerceivableTarget`) e §1 (`PlayerMotor` sobre CharacterBody3D) | O contrato diz que "o jogador implementa a interface PerceivableTarget", mas declara `class_name PerceivableTarget extends Node`. GDScript não tem interfaces nem herança múltipla, e o jogador já estende CharacterBody3D. Escrito assim, o contrato não compila. | Definir `PerceivableTarget` como componente-filho do jogador (composição), que o VisionSensor consome. Alternativa: contrato por duck typing (`has_method`), com teste ARC que valide os métodos. Escolher uma e registrar na ADR-003. |
| R-06 | ALTO | ENGINE_DECISION §4 (C2 = 5, com "captura de viewport via script" como recurso headless) e §7 (V3) | Em `--headless` o Godot usa drivers de vídeo e render dummy, sem framebuffer para capturar. Screenshot exige execução com janela e GPU. O TEST_PLAN §2 ("Visual: Com janela") diz isso, e a ADR contradiz. Confiança alta (~85%). | Remover "captura de viewport" da lista de recursos headless em C2. Especificar V3 como execução com janela (sem `--headless`). Reavaliar a nota C2 se a captura exigir janela no pipeline. |
| R-07 | ALTO | MASTER §11 × ROADMAP (F1–F7) × TASK_BOARD | Itens obrigatórios de acessibilidade sem tarefa: legendas, remapeamento de controles e indicadores visuais de condição respiratória. "Ajuste de intensidade dos efeitos" aparece só de forma vaga (F2-007) e não está na lista de Settings (F1-004). Nenhum documento cita legendas ou remapeamento. | Incluir no TASK_BOARD: F1-004 (Settings com intensidade de efeitos e legendas), uma tarefa de UI de remapeamento sobre o input map, e F2-007 (indicadores visuais de respiração). Definir critérios e testes para cada um. |
| R-08 | ALTO | ENGINE_DECISION §5 × MASTER §12 (Fase 0) | Dos nove objetivos da Fase 0, quatro não têm análise dedicada: comparar arquitetura, comparar desempenho (só nota C8), avaliar ferramentas de áudio (FMOD, Wwise e MetaSounds não são avaliados para Godot nem Unity) e avaliar requisitos de hardware da engine. "Facilidade de implementação da IA" aparece só como nota em C3. O gate F0 depende desses objetivos. | Acrescentar seção na ENGINE_DECISION com um item por objetivo de §12 e sua evidência, ou marcar como "não avaliado" com a pendência no gate. Para áudio, comparar pelo menos Godot com a alternativa escolhida para áudio adaptativo. |
| R-09 | ALTO | DATA_STRUCTURES §3.1 (AIProfile); COMPONENT_CONTRACTS §6; TEST_PLAN AI-02, AI-03, AI-06 | Os parâmetros de personalidade são qualitativos ("alto", "baixo", "médio", "lento", "rápido"). Não há limiar de suspeita, tempo de confirmação visual, taxa de decaimento nem ganho numérico. Por isso AI-03 ("CHASE em ≤ 1,5 s") e a transição SUSPICIOUS → INVESTIGATE não são executáveis. AI-06 pede que o destino "não se correlacione", sem critério estatístico. | Substituir por valores numéricos no AIProfile: ganho, decaimento, limiar de suspeita e tempo de confirmação visual. Em AI-03, especificar o perfil. Em AI-06, definir o teste operacional (por exemplo, |r| < 0,1 em 100 rodadas, ou teste de distribuição com nível de significância explícito). |
| R-10 | ALTO | COMPONENT_CONTRACTS (ausente); SYSTEM_ARCHITECTURE §3 e §6 (prioridade -30) | O EnemyController não tem contrato, embora integre a IA: fornece o BrainWorldQuery, emite `player_captured`, `chase_started` e `enemy_alert_changed`, e controla navegação e captura. É o componente onde o firewall é mais fácil de quebrar, e não há API, invariantes nem dependências proibidas escritas. | Criar a seção de contrato do EnemyController: API, sinais, invariantes (inclui que BrainWorldQuery não expõe posição do jogador), dependências proibidas e ordem de tick. Congelar antes da F4. |
| R-11 | ALTO | DATA_STRUCTURES §1 (PhysiologyInputs: `threat_level`, `in_chase`, `is_hidden`; StressConfig); COMPONENT_CONTRACTS §3; MASTER §9.3 | Não há produtor definido para as entradas do estresse. `threat_level` é "ameaça percebida pelo jogador", mas nenhum componente do lado do jogador calcula se ele vê ou ouve inimigos, e `enemy_seen_gain` e `enemy_heard_gain` dependem disso. A fonte "Ferimentos" (MASTER §9.3) está ausente em todos os documentos. As consequências (tremor, ruídos involuntários, dificuldade em interações) não têm mecanismo nem números. | Definir um componente L2 do lado do jogador (por exemplo, PlayerThreatMonitor), com fórmula e contrato. Registrar ferimentos como fora de escopo, por decisão do Director, ou incluí-los com parâmetros. Dar fórmula para cada consequência de §9.3 e para `steadiness`. |
| R-12 | ALTO | COMPONENT_CONTRACTS §12 (BreathingAudio e NoiseEmitter "com os mesmos parâmetros"); SYSTEM_ARCHITECTURE §1.4 e §6 (prioridade -70) | A respiração tem dois produtores independentes. BreathingAudio (L3) toca o som, e NoiseEmitter (L2) emite o NoiseEvent BREATHING, com "os mesmos parâmetros". Isso contraria o princípio "um evento, dois consumidores" e pode causar dupla reprodução ou dessincronia. Não está claro se o jogador ouve a própria respiração pelo BreathingAudio, pelo NoiseAudioRouter ou pelos dois. | Gerar um único NoiseEvent BREATHING e deixar o áudio consumir esse evento, ou extrair função pura compartilhada em L1 (`breath_params(state)`) usada pelos dois. Decidir e documentar qual caminho toca o som para o jogador, e impedir que os dois toquem. |
| R-13 | MÉDIO | DATA_STRUCTURES §2.1, §2.2, §3.1; SYSTEM_ARCHITECTURE §7; MASTER §4.2 e §9.5 | O modelo acústico não tem piso de ruído ambiental (chuva da madrugada e "modificadores ambientais" de §9.5) nem alcance máximo. Com limiares absolutos: tosse de 65 dB é audível a ~316 m pelo Observer (15 dB) em campo aberto; respiração de 35 dB é audível a 10 m (Observer) e 3,5 m (Aggressive); atrás de parede, cai para 0,56 m. Os números são iniciais, mas a falta do termo é estrutural. | Adicionar `ambient_floor_db` (chuva e clima) e modificadores por sala. Definir alcance máximo ou atenuação extra por distância. Recalibrar com cenário de referência para STL-04. |
| R-14 | MÉDIO | ENGINE_DECISION §5 (C3: "AudioStreamPlayer3D com atenuação"); COMPONENT_CONTRACTS §4 (NOI-INV-2) e §12 | A atenuação nativa do AudioStreamPlayer3D é citada como vantagem, mas NOI-INV-2 exige que o volume tocado derive só de `propagate()`. Com as duas atenuações ativas, áudio e IA divergem. | Declarar que a atenuação nativa fica desligada e que o NoiseAudioRouter calcula `volume_db` a partir de `PropagationResult`. Incluir teste de paridade entre áudio e IA. |
| R-15 | MÉDIO | SYSTEM_ARCHITECTURE §6 (ordem de física) | (a) "Input" em -100 não funciona se for event-driven (`_input`/`_unhandled_input`), que roda fora do ciclo de física. (b) HearingSensor, SquadCoordinator e detecção de captura não têm prioridade. (c) Ruído de porta (prioridade 0) chega ao NoiseBus (-60) só no tick seguinte, sem documentação. | Amostrar input em `_physics_process` ou enfileirar. Completar a tabela com todos os participantes. Documentar a latência de um tick para ruídos do mundo. |
| R-16 | MÉDIO | ENGINE_DECISION §6 (Física: "Jolt ... integrado desde a 4.4", "mais estável") | A ADR não diz se Jolt é padrão ou opção, nem como ativá-lo. Pelo que conheço, na 4.4 era opção (Project Settings > Physics > 3D > Physics Engine). Não sei se isso mudou nas versões seguintes. Confiança média (~70%). A justificativa "mais estável para CharacterBody" não tem evidência. | Confirmar na documentação da 4.7.2 e citar a configuração exata. No spike, testar CharacterBody3D (escada, rampa, vão) com Jolt e com o motor padrão, para justificar a escolha. |
| R-17 | MÉDIO | ENGINE_DECISION §4 (C9), §7 (V4) e §8 (mitigação); TEST_PLAN ARC-04; TASK_BOARD F1-003 | (a) `--check-only` (com `--script`) depende do cache global de `class_name`, gerado por importação (`--headless --import`). Sem importação, scripts que usam classes de outros arquivos podem falhar falsamente. (b) V4 e ARC-04 não exigem exit code. (c) Parse não detecta chamada de método inexistente em objeto sem tipo estático, então a mitigação para erros de API Godot 3/4 é mais fraca do que a ADR descreve. Confiança média. | Pipeline de ARC-04 com importação prévia, `--check-only` por arquivo com exit code verificado e warnings de tipagem tratados como erro. Acrescentar exit code ao V4. Reconhecer na ADR que parse não substitui teste. |
| R-18 | MÉDIO | DATA_STRUCTURES §1 (RespiratoryState, StressBand), §2 (NoiseCategory), §3 (EnemyState) | Os enums são declarados como blocos soltos, sem classe dona. Em GDScript, um enum só é acessível de fora do arquivo como membro de uma classe (`Classe.Enum`) ou via preload. Os contratos usam os nomes como tipos globais, por exemplo `signal respiratory_state_changed(old: RespiratoryState, ...)`. | Declarar cada enum dentro da classe dona ou em classe utilitária nomeada (por exemplo, `class_name Enums`). Padronizar a notação nos contratos. |
| R-19 | MÉDIO | COMPONENT_CONTRACTS §4, §5, §8, §9; DATA_STRUCTURES | Tipos citados sem definição: `ObjectiveStatus`, `ItemUseResult`, `ItemCatalog`, `PerceptBatch`. `BrainWorldQuery`, `InteractionContext`, `RoomVolume` e `Portal` aparecem só em prosa. `MedicationProfile` só existe como tabela. A API de SaveService, EventBus, Log, Settings e GameState não está escrita. | Adicionar ao DATA_STRUCTURES uma declaração por tipo (campos e valores de enum) e uma seção de API para os autoloads de L0. |
| R-20 | MÉDIO | DATA_STRUCTURES §1 (CouplingFactors, PhysiologySnapshot) e §1.3; COMPONENT_CONTRACTS §3 | (a) `CouplingFactors` tem `respiratory_load`, `stamina_regen_multiplier`, `max_sprint_multiplier` e `steadiness`, mas nenhuma fórmula os define; `respiratory_load` não entra na fórmula de severidade. (b) `recovery_progress` não tem definição. (c) Entre 0,20 e 0,35 não há regra de estado sem esforço (NORMAL < 0,2; ACCELERATED só com esforço). (d) A escala de probabilidade de tosse entre 0,55 e 1,0 não é dada. (e) `cough_warning_time_s` (DATA) × `cough_warning_time` (COMPONENT PHY-INV-5). Sem essas fórmulas, PHY-INV-4 não é testável. | Escrever a fórmula de cada campo de CouplingFactors e de `recovery_progress`. Completar a tabela de transições de estado. Definir a escala da tosse. Unificar o nome do parâmetro. |
| R-21 | MÉDIO | DATA_STRUCTURES §1.4 (`immediate_reduction` = 0,35 de severidade); TEST_PLAN PHY-04 | "0,35 de severidade" pode ser absoluto ou relativo. Absoluto: 0,6 vai para 0,25 (redução de 0,35, passa com margem de 0,05). Relativo (35% de 0,6 = 0,21): reduz só 0,21, e PHY-04 (≥ 0,30) falha. | Escrever "redução absoluta de 0,35" e expressar o critério de PHY-04 na mesma unidade. |
| R-22 | MÉDIO | COMPONENT_CONTRACTS §3 ("cada um com teste em TEST_PLAN"), §4 (NOI-INV), §8, §9; ROADMAP Gate F3; TEST_PLAN | A frase "cada invariante tem teste" é falsa: PHY-INV-1 e PHY-INV-4 não têm ID. NOI-INV-1 a 3 são exigidos pelo Gate F3 e não têm ID no TEST_PLAN. Não têm teste: invariantes de inventário (quantidade, capacidade, idempotência de from_dict), regras de ObjectiveGraph (pré-requisitos, rotas OR, recompensas), ordem da sequência de captura (MASTER §9.10), "sem perda indevida de progresso" e entrada/saída de esconderijo (§9.7). | Mapear cada invariante a um ID no TEST_PLAN (por exemplo PHY-09, NOI-01 a 03, INV-01 a 03, OBJ-01 a 03, PER-06). Corrigir a frase de COMPONENT §3 até que o mapeamento exista. |
| R-23 | MÉDIO | ROADMAP Gate F2 × TEST_PLAN §2.1 × MASTER §15 | O gate exige PHY-01 a PHY-06, mas omite PHY-07 (aviso de tosse, que sustenta "crises não parecem aleatórias") e PHY-08 (determinismo, PHY-INV-6). | Incluir PHY-07 e PHY-08 no Gate F2. |
| R-24 | MÉDIO | DATA_STRUCTURES §5 (`rng_seed` no snapshot); COMPONENT_CONTRACTS PHY-INV-6 | O checkpoint salva `rng_seed`, não o estado do RNG. Ao restaurar, a sequência recomeça do seed, e o resultado depois de carregar não é o mesmo da execução contínua. Além disso, Godot lê números de JSON como float (53 bits de precisão), então seeds de 64 bits podem ser corrompidos. Confiança alta. | Salvar `RandomNumberGenerator.state` como string no snapshot. Incluir teste: salvar no meio de uma sequência, carregar e comparar com a execução contínua. |
| R-25 | MÉDIO | TEST_PLAN ARC-01 × SYSTEM_ARCHITECTURE §5 | Escopos divergentes: SYSTEM §5 cobre sim/ai e components/enemy. TEST_PLAN inclui sim/difficulty e uma exceção em components/perception. ARC-01 é varredura textual pelo nome da classe e não pega lookup dinâmico (`get_tree().get_nodes_in_group("player")`, caminhos em string). | Unificar o escopo nos dois documentos. Acrescentar teste em runtime (estendendo AI-06) e lista de padrões proibidos (grupos, caminhos, nomes de nó). Declarar que ARC-01 sozinho não prova o firewall. |
| R-26 | MÉDIO | COMPONENT_CONTRACTS §12 (AdaptiveMusic) e §13 (`chase_started`, `enemy_alert_changed`) | AdaptiveMusic deve usar "o que o jogador percebe", mas os sinais são globais, carregam o estado real do inimigo, e o documento não diz como o filtro acontece. A música pode subir por uma perseguição que o jogador não percebeu, revelando estado oculto. | Publicar no EventBus somente estados percebidos, por meio de um agregador de percepção do jogador, e fazer a música depender desse agregador. Documentar a regra. |
| R-27 | MÉDIO | ROADMAP F1-004 × TASK_BOARD × SYSTEM_ARCHITECTURE §2 e §3 | SaveService é autoload de L0, mas nenhuma tarefa o cria. F1-004 lista Log, EventBus, Settings e GameState. F5-005 cita só o CheckpointManager. | Incluir SaveService em F1-004 ou F5-005, com contrato de API e teste de gravação em `user://saves/`. |
| R-28 | MÉDIO | DATA_STRUCTURES (ausente); COMPONENT_CONTRACTS §1; MASTER §9.4 | Não existe PlayerMotorConfig: velocidades de caminhada, agachado e rastejar, altura da cápsula e tetos. A velocidade de sprint (4,8 m/s) aparece só numa nota. "Locais seguros" (MASTER §9.4) não tem parâmetro de recuperação de resistência. `Gait.SLOW` não é mapeado a nenhuma recuperação. | Adicionar PlayerMotorConfig ao DATA_STRUCTURES. Definir qual recuperação usa SLOW e como locais seguros recuperam resistência. |
| R-29 | MÉDIO | TASK_BOARD §5 × MASTER §14 | O backlog das Fases 2–5 (cerca de 25 tarefas) não tem Status, Critérios de aceitação, Testes nem Evidências, que §14 exige ("Cada tarefa deverá possuir"). A dispensa é implícita. | Completar os cards antes de abrir cada fase, ou registrar a dispensa no ROADMAP. |
| R-30 | MÉDIO | MASTER §12 (Fase 2) × ROADMAP F2 × TASK_BOARD | "Animações" é entregável da Fase 2 no MASTER, mas não aparece no ROADMAP F2 nem em nenhuma tarefa F2 (só na F7). | Incluir tarefa de animações de respiração e recuperação na F2, ou justificar a mudança no ROADMAP. |
| R-31 | MÉDIO | ROADMAP F7 e F8 × MASTER §18 | Localização EN/PT-BR (F7) e distribuição na Steam (F8) entram como escopo comprometido, sem a avaliação de impacto e custo que §18 exige. Devem ser propostas. | Registrar em TASK_BOARD §2 como propostas (P-04 e P-05) com custo e risco. |
| R-32 | MÉDIO | MASTER §10.1 e §5.2 × ROADMAP F6 | Fora dos seis itens pedidos, mas obrigatórios: mudanças ambientais (portas bloqueadas, objetos deslocados, rotas de IA alteradas, áreas mais perigosas, caminhos novos) e progressão mecânica por capítulo (§5.2) não têm tarefa, contrato nem teste. Só portas e luzes aparecem, no snapshot. | Acrescentar em ROADMAP F6 um contrato EnvironmentState e um item por capítulo, com a mecânica nova de cada um. |
| R-33 | MÉDIO | SYSTEM_ARCHITECTURE §15 × CHANGELOG × MASTER §6.2 | ADR-002 a ADR-010 existem só como linha de tabela, sem contexto, alternativas e consequências. O CHANGELOG as lista como entregues. MASTER §6.2 pede Architecture Decision Records. | Escrever registros curtos para as ADRs que alteram contrato (004, 007, 008, 009). Enquanto não houver registro, listar as ADRs 002–010 como propostas no CHANGELOG. |
| R-34 | MÉDIO | TASK_BOARD DISC-001 e DISC-002; ENGINE_DECISION §2 e §9 | DISC-001 e DISC-002 citam saídas de Get-Command, vswhere, WMI, API do GitHub e buscas web, mas o repositório não guarda nenhuma dessas saídas. A versão 4.7.2 (18/08/2026), as datas e os preços de Unity e UE 5.8 não puderam ser verificados nesta revisão, sem acesso à internet. | Gravar comando e saída resumida em Docs/Development ou Docs/QA, seguindo a regra de evidência do TEST_PLAN §1. Marcar as fontes externas como não reverificadas até a data da revisão. |
| R-35 | MÉDIO | KNOWN_ISSUES × ENGINE_DECISION §8 × TASK_BOARD D-05 e D-06 | Riscos citados nas ADRs e ausentes do KNOWN_ISSUES: fallback Vulkan/D3D12 em RDNA4; export templates com versão exata (ENGINE §8); ASSET_LICENSES.md (D-06) sem tarefa; pipeline Blender (D-05) sem contingência; drift de API Godot 3/4 (C9); determinismo de ponto flutuante entre máquinas (PHY-08); orçamentos de desempenho sem medição até a F7; dependência de playtest humano; migração de schema de save; V5 e vsync. | Incluir cada item no KNOWN_ISSUES com severidade e ação. Criar tarefa para ASSET_LICENSES.md. |
| R-36 | BAIXO | TEST_PLAN PHY-06; TASK_BOARD F1-005 | 1000 sequências de 60 s a 60 Hz são cerca de 3,6 milhões de ticks. Em GDScript isso pode passar do limite de < 10 s da suíte (F1-005). | Definir dt de simulação para testes de propriedade (por exemplo, 0,1 s), com teste de invariância a dt. |
| R-37 | BAIXO | TEST_PLAN STL-03; DATA_STRUCTURES §2.2 | O critério "≥ 15 dB" é exatamente 18 − 3. Erro de ponto flutuante pode reprovar um comportamento correto. | Usar ≥ 14,5 dB ou declarar tolerância. |
| R-38 | BAIXO | ENGINE_DECISION §7 (V5); SYSTEM_ARCHITECTURE §13 | V5 exige ≥ 144 fps, mas o alvo do projeto é 60 fps. Vsync e o limite de quadros do monitor não estão especificados e podem reprovar o critério por motivo alheio à engine. | Especificar vsync desligado e medir frame time (média e p95) com número de amostras definido. |
| R-39 | BAIXO | MASTER §7.1 × TASK_BOARD e ROADMAP | Esforço diferente da matriz, sem justificativa registrada: Esconderijos (HIGH → F5-002 EXTRA HIGH), Checkpoints (HIGH → F5-005 EXTRA HIGH), Level design (HIGH → F1-009 MEDIUM, sandbox), Direção de arte (HIGH → F1-D03 MEDIUM). Dificuldade adaptativa (HIGH) não tem card. | Anotar a justificativa de cada desvio no TASK_BOARD e criar card para dificuldade adaptativa. |
| R-40 | BAIXO | ROADMAP F5 × ROADMAP F6 × MASTER §12 | F5 diz "Inventário e objetivos completos"; F6 diz "Inventário completo". | Trocar em F5 por "inventário básico". |
| R-41 | BAIXO | COMPONENT_CONTRACTS §4 (NoiseBusService; chamadas `NoiseBus.emit`); SYSTEM_ARCHITECTURE §2–3 (CheckpointManager em L0/L2) | Nome do autoload (NoiseBus) difere do nome da classe (NoiseBusService), sem regra explícita. CheckpointManager aparece em duas camadas. | Padronizar: autoload e classe com nomes e papéis definidos, e uma camada por componente. |
| R-42 | BAIXO | COMPONENT_CONTRACTS §3 (declarações com `var ..., ...`) | Linhas como `var symptom_severity: float, breathing_rate: float, ...` não são GDScript válido. Estão num bloco marcado como "GDScript tipado". | Uma declaração por linha. |
| R-43 | BAIXO | MASTER §9.8 × todos os documentos | "Água" (item de inventário) não tem definição de item nem efeito em nenhum documento. | Definir o item e seu efeito, ou registrar como fora de escopo. |
| R-44 | BAIXO | MASTER §13.6 × contratos | Não há política de tratamento de erro: `load_state` com dados inválidos, `schema_version` desconhecido, .tres ausente, falha de gravação. | Seção curta em SYSTEM_ARCHITECTURE com o comportamento esperado de cada caso e teste correspondente. |
| R-45 | BAIXO | AGENT_ASSIGNMENTS §5 × MASTER §17 | O modelo de entrega não tem "Quais testes passaram", exigido por §17. | Adicionar o campo ao modelo. |
| R-46 | BAIXO | ROADMAP (calendário de documentação) × MASTER §16 | Oito documentos de Gameplay e cinco de Design estão deferidos para o calendário. É razoável, mas não há decisão do Director registrada. | Registrar a decisão no ROADMAP. |
| R-47 | BAIXO | AGENT_ASSIGNMENTS §2 (Technical Reviewer: "general-purpose (somente leitura)") | A restrição de leitura é apenas textual; general-purpose tem Edit e Write. | Para revisões, usar tipo de agente sem Edit e Write (Explore ou Plan), ou registrar que a restrição é por convenção. |
| R-48 | BAIXO | DATA_STRUCTURES §1.3 (PHY-01, PHY-06) | Pequenas diferenças de texto: alvo em PHY-01 é ≈ 0,45 (texto diz 0,46); estresse de 100 a 0 leva 37,3 s (texto diz ≤ 37 s). Não alteram o resultado dos testes. | Corrigir os números. |

---

## 6. Precisão técnica sobre Godot 4

Avaliação feita por conhecimento próprio, sem executar a engine. Confiança indicada por item.

| Item citado | Avaliação | Confiança |
|---|---|---|
| `process_physics_priority` (propriedade de Node) | Existe. Valores menores rodam antes. Vale só para `_physics_process`. | Alta |
| `--check-only` | Existe, usado com `--script`. Depende do cache de `class_name` (R-17). Exit code a confirmar. | Média |
| `--headless` | Existe. Renderização dummy, portanto captura de viewport não funciona (R-06). | Alta (~85%) |
| `-s` / `--script` | Existe (forma curta de `--script`). | Alta |
| `--export-release` | Existe. Exige preset em `export_presets.cfg` e export templates da versão exata. | Alta |
| `--version` → `4.7.2.stable` | A saída real traz sufixos (`.official.<hash>`). O V1 deve comparar por prefixo. | Alta |
| `RefCounted`, `class_name`, `.tres` e `.tscn` como texto | Corretos. | Alta |
| Interfaces em GDScript (`PerceivableTarget`) | Não existem. Herança é simples (R-05). | Alta |
| Jolt Physics | Disponível como opção desde a 4.4. Padrão não confirmado (R-16). | Média |
| Volumetric fog e SDFGI | Exigem Forward+. A escolha do renderer está coerente. | Média-alta |
| `Area3D` com reverb bus; `AudioStreamPlayer3D` com atenuação | Existem. A atenuação nativa conflita com NOI-INV-2 (R-14). | Alta |
| `NavigationServer3D` e `NavigationAgent3D` | Existem. | Alta |
| Warnings de tipagem como erro (`untyped_declaration`) | Configuração de projeto disponível nas versões 4.2 em diante. | Média-alta |
| D3D12 como driver do Forward+ no Windows | Configurável por `rendering/rendering_device/driver.windows`. | Média-alta |
| `RandomNumberGenerator.state` | Existe. Deve ser salvo no checkpoint (R-24). | Alta |
| JSON e números | Godot lê números como float (R-24). | Média-alta |
| Versão 4.7.2, data 18/08/2026, preços de Unity e UE 5.8 | Não verificável nesta revisão (sem internet). | — |

---

## 7. Pontos fortes

1. **Simulação separada da cena.** L1 em RefCounted, configuração em .tres e BrainWorldQuery sem posição do jogador: boa base para testes headless.
2. **Honestidade de status.** ENGINE marcada como PROPOSTA, spike marcado BLOQUEADO, SYSTEM afirma que nada está implementado, TEST_PLAN diz que nenhum teste foi executado, CHANGELOG lista o que não foi realizado.
3. **Aritmética conferida.** Pesos somam 100. Matriz (61 / 69 / 86 / 69) e sensibilidade (81 / 73 / 75 / 52) conferem. O modelo fisiológico com EMA, histerese e tempo mínimo de permanência passa em PHY-01, 03, 05 e 06 na simulação.
4. **Cobertura de §15 e regras de evidência.** As seis categorias do §15 têm IDs de teste. Estão explícitas a independência do QA, a exigência de saída real e a regra de que teste instável é bug.
5. **Rastreabilidade de decisões.** D-01 a D-07 com recomendação e impacto; propostas P-01 a P-03 separadas do escopo; a categoria VOICE é declarada como proposta, não como fato.

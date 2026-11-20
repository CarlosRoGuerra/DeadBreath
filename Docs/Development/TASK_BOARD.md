# Task Board — DEAD BREATH

| Campo | Valor |
|---|---|
| Atualizado | 2026-11-20 |
| Fase atual | **FASE 1 — Foundation: concluída; Gate F1 aguardando aprovação do usuário** |
| Estados | BACKLOG · READY · IN_PROGRESS · REVIEW · TESTING · APPROVED · BLOCKED |

Uma tarefa só fica **APPROVED** com: implementação concluída, critérios atendidos, testes executados (com saída registrada), revisão técnica concluída e documentação atualizada.

---

## 1. Decisões do usuário

| ID | Decisão | Recomendação | Situação |
|---|---|---|---|
| D-01 | Aprovar a engine | **Godot 4.7.2 + GDScript tipado** (ENGINE_DECISION.md) | **APROVADA** (2026-11-20) |
| D-02 | Local do projeto | **Mover para `D:\Dev\DeadBreath`** (fora do OneDrive; D: tem 249 GB livres) | **APROVADA e executada** (2026-11-20) |
| D-03 | Controle de versão | **`git init` local agora**; remoto privado opcional depois | **APROVADA**. O usuário já tinha criado o repositório com remoto `origin` no GitHub. Commits são locais; push só quando o usuário pedir |
| D-04 | Instalação do Godot | Autorizar o download do binário oficial (GitHub, 82 MB) para `D:\DevTools\Godot\4.7.2\`, **ou** baixar manualmente e informar o caminho | **APROVADA e executada** (SHA-512 conferido) |
| D-05 | Personagens 3D e animações | Instalar o **Blender** (gratuito, scriptável por Python) + bases CC0; freelancer pontual para os 3 criminosos na F6/F7 | Pendente; bloqueia a partir da F4 (até lá, cápsulas) |
| D-06 | Assets externos | Permitir assets **CC0** (Poly Haven, ambientCG, Quaternius, Kenney), registrados em `ASSET_LICENSES.md` | **APROVADA** (2026-11-20). CC0 entra com registro; outras licenças exigem aprovação do Director e do usuário |
| D-07 | Áudio de respiração | Opcional: gravar respiração, chiado e tosse reais com microfone. Alternativa: síntese procedural + CC0 | Pendente; bloqueia a partir da F2 |

## 2. Propostas de funcionalidade (MASTER §18)

| ID | Proposta | Benefício | Custo/risco | Recomendação |
|---|---|---|---|---|
| P-01 | **Abafar a tosse**: segurar uma tecla durante o aviso (65 → 48 dB), ao custo de stamina e de aumento da severidade | Agência na crise; reforça o tema sem aleatoriedade | Baixo | Avaliar na F2 |
| P-02 | **Prender a respiração** por poucos segundos (silencia BREATHING/WHEEZING; recuperação mais ruidosa depois) | Mecânica de esconderijo coerente com o tema | Médio (balanceamento com a asma) | Avaliar na F2 |
| P-03 | Categoria de ruído **VOICE** (falas e gritos dos criminosos) | Comunicação do esquadrão audível e justa; base das legendas de fala | Baixo | Aprovar com a F3 |
| P-04 | **Localização EN + PT-BR** | Alcance de mercado; o usuário é falante de PT-BR | Médio (textos, legendas, testes). As chaves de tradução desde a F1 reduzem o custo. | Decidir na F6 |
| P-05 | **Distribuição na Steam** (Steamworks: conquistas opcionais, página) | Canal principal para indie horror no PC | Médio (taxa de publicação, requisitos de build, testes) | Decidir antes da F8 |
| P-06 | **Ferimentos com efeito físico** (mancar por 30 s após queda) | Consequência física mais tangível | Médio (movimento, animação, balanceamento). Hoje ferimento = pico de estresse. | Avaliar na F6 |

---

## 3. FASE 0 — Discovery

| ID | Tarefa | Responsável | Esforço | Depende de | Status | Evidência |
|---|---|---|---|---|---|---|
| DISC-001 | Inventário do ambiente | Project Director | HIGH | — | APPROVED | Docs/QA/EVIDENCE/DISC-001_environment.txt |
| DISC-002 | Avaliação de engines, matriz, sensibilidade e avaliação por objetivo | Software Architect | EXTRA HIGH | DISC-001 | APPROVED | ENGINE_DECISION §3–5.1; aritmética conferida em DISC-006 |
| DISC-003 | Spike de verificação da engine (V1–V6), critério do Gate F0 | Project Director + QA | HIGH | D-04 | **DONE** (V1–V6 passaram). A reexecução independente pelo QA entra na F1-011 | Docs/QA/TEST_RESULTS.md §DISC-003; Docs/QA/EVIDENCE/DISC-003/; ENGINE_DECISION §7.1 |
| DISC-004 | Arquitetura, contratos e estruturas de dados | Software Architect | EXTRA HIGH | DISC-002 | APPROVED (v0.2 draft; congelamento v1.0 por sistema) | v0.2 dos três documentos |
| DISC-005 | Roadmap, backlog, agentes e plano de testes | Project Director | HIGH | DISC-004 | APPROVED | ROADMAP, TASK_BOARD, AGENT_ASSIGNMENTS, TEST_PLAN |
| DISC-006 | Revisão técnica independente (3 rodadas) | Technical Reviewer | HIGH | DISC-002..005 | APPROVED | DISC-006.md (rodada 1: REPROVADO, 48 achados); DISC-006_VERIFICATION.md (rodada 2: REPROVADO, 2 ALTO novos; rodada 3: **APROVADO COM RESSALVAS**, 0 CRÍTICO/ALTO) |
| DISC-007 | Correção dos achados da DISC-006 | Software Architect + Director | EXTRA HIGH | DISC-006 | APPROVED (com ressalvas) | DISC-006_RESOLUTION.md. As ressalvas da rodada 3 (N-04, N-19 a N-23) foram corrigidas depois dela e **não foram reverificadas**; a conferência entra no congelamento v1.0 de cada contrato |

---

**Gate F0: APROVADO em 2026-11-20.** D-01 a D-04 aprovados pelo usuário; DISC-003 passou em V1–V6; DISC-006 sem achado CRÍTICO ou ALTO em aberto.

---

## 4. FASE 1 — Foundation (detalhada)

### F1-001 · Repositório e local do projeto
- **Responsável:** Project Director · **Esforço:** MEDIUM · **Depende de:** D-02, D-03, Gate F0 · **Status:** APPROVED (Gate F1: revisão F1-010 e validação F1-011). Antes: REVIEW. Repositório em `D:\Dev\DeadBreath`, `.gitignore`/`.gitattributes`, commits `57ce276` e seguintes; `git status` limpo após cada commit e `.godot/` ignorado (conferido)
- **Descrição:** mover para o local aprovado, `git init`, `.gitignore` padrão do Godot 4 (ignora `.godot/` e builds; versiona arquivos `.import`), `.gitattributes` (LF para texto) e README.
- **Aceitação:** `git status` limpo após o commit inicial; `.godot/` ignorado.
- **Testes:** saída dos comandos git registrada.

### F1-002 · Integração do Godot às ferramentas
- **Responsável:** Project Director · **Esforço:** LOW · **Depende de:** DISC-003 · **Status:** APPROVED (Gate F1: revisão F1-010 e validação F1-011). Antes: REVIEW. Evidência: Docs/QA/EVIDENCE/F1-002_godot_wrapper.txt (caminho válido → exit 0; inexistente e versão errada → exit 2)
- **Descrição:** registrar o caminho do Godot em `tools/godot_path.txt` (lido pelos scripts) e criar `tools/godot.ps1` (wrapper com caminho e versão verificados).
- **Aceitação:** `tools/godot.ps1 --version` imprime 4.7.2 e falha com mensagem clara se o caminho estiver errado.
- **Testes:** execução com caminho válido e inválido.

### F1-003 · Esqueleto do projeto Godot
- **Responsável:** Software Architect · **Esforço:** HIGH · **Depende de:** F1-002 · **Status:** APPROVED (Gate F1: revisão F1-010 e validação F1-011). Antes: REVIEW. `project.godot`, pastas, input map e camadas conferidos por script; ARC-03, ARC-04 e ARC-05 verdes no pipeline (Docs/QA/EVIDENCE/F1-005_run_tests.txt)
- **Descrição:** `game/project.godot` (Forward+, motor de física escolhido em V6, física a 60 Hz), estrutura de pastas (SYSTEM_ARCHITECTURE §11), camadas de física nomeadas, input map (move, slow_walk, sprint, crouch, crawl, interact, use_item, debug) e warnings `untyped_declaration`, `unsafe_method_access` e `unsafe_property_access` como erro.
- **Aceitação:** importação headless sem erros; input map completo; ARC-04 verde.
- **Testes:** ARC-03, ARC-04, ARC-05.

### F1-004 · Núcleo L0
- **Responsável:** Software Architect · **Esforço:** HIGH · **Depende de:** F1-003 · **Status:** APPROVED (Gate F1: revisão F1-010 e validação F1-011). Antes: REVIEW. 29 testes (unit + integration, incluindo ACC-06 e PER-09 versão L0) verdes no pipeline, execução própria do Director em 2026-11-20
- **Descrição:** `Enums`, `Log` (categorias, níveis, arquivo em `user://logs/`), `EventBus` (catálogo de COMPONENT_CONTRACTS §16), `Settings` com todas as chaves de COMPONENT_CONTRACTS §15 (inclui `effects_intensity`, `tremor_reduction`, `motion_reduction`, `respiratory_indicator`, `subtitles_enabled`, `subtitles_size`, `input_bindings`), `SaveService` (JSON com escrita atômica) e `GameState`.
- **Aceitação:** settings sobrevivem a reiniciar; o log grava arquivo; o EventBus só aceita payloads nativos; SaveService passa no teste de escrita atômica.
- **Testes:** ACC-06, PER-09 (versão L0), unit de Log e integration do EventBus.

### F1-005 · Framework de testes headless
- **Responsável:** QA Engineer · **Esforço:** EXTRA HIGH · **Depende de:** F1-003 · **Status:** APPROVED (Gate F1: revisão F1-010 e validação F1-011). Antes: REVIEW, com ajuste em andamento: o runner passa a reprovar o teste quando há erro de script durante ele. Entrega: runner, TestCase, ARC-01/03/04/05/06, 15 meta-testes, `tools/run_tests.ps1` (pipeline 10,8 s; runner < 1 s). ARC-02 e ARC-07 pendentes (dependem de níveis e configs)
- **Descrição:** runner `game/tests/run_all.gd` (descobre `test_*.gd`, asserts com tolerância, isolamento, resumo, código de saída 0/1); suporte a integração com frames de física simulados; testes de arquitetura (varredura de texto e reflexão); `tools/run_tests.ps1` (importação → parse por arquivo → testes).
- **Aceitação:** teste propositalmente falho → código 1; resumo com nome, status e tempo; suíte da F1 em < 10 s.
- **Testes:** meta-testes do runner (passa, falha, erro de script).

### F1-006 · PlayerRoot e PlayerMotor
- **Responsável:** Gameplay Engineer · **Esforço:** HIGH · **Depende de:** F1-004 · **Status:** APPROVED (Gate F1: revisão F1-010 e validação F1-011). Antes: REVIEW. 26 testes do jogador (MOT-01..04, step-up, landed, footstep, controles, config) verdes em 5 execuções seguidas; 7 mutações provaram que os testes reprovam quando o comportamento quebra (EVIDENCE/F1-006_*.txt)
- **Descrição:** PlayerRoot (mediador, COMPONENT_CONTRACTS §1) e PlayerMotor (§2) com `PlayerMotorConfig`: mouse look, andar, andar devagar, correr, agachar, rastejar, checagem de teto, aceleração, head bob (desligável), `footstep` por superfície e `get_exertion()`.
- **Aceitação:** critérios de MOT-01..04.
- **Testes:** MOT-01..04, ARC-06.

### F1-007 · Interação, porta e pickup
- **Responsável:** Gameplay Engineer · **Esforço:** MEDIUM · **Depende de:** F1-006 · **Status:** APPROVED (Gate F1: revisão F1-010 e validação F1-011). Antes: REVIEW. 20 testes de interação (3× estáveis); ARC-02 aguarda nível com portas/pickups
- **Descrição:** InteractionComponent, Interactable (instantâneo e segurar, com `InteractionContext`), Door (lenta, normal, trancada) e Pickup (`persist_id`, `item_picked`).
- **Aceitação:** a porta abre devagar ao segurar e rápido ao tocar; porta trancada dá feedback; o pickup some e emite o evento; não há interação através de paredes.
- **Testes:** integration por interação; ARC-02.

### F1-008 · Overlay e comandos de debug
- **Responsável:** Gameplay Engineer · **Esforço:** MEDIUM · **Depende de:** F1-004 · **Status:** APPROVED (Gate F1: revisão F1-010 e validação F1-011). Antes: REVIEW. 6 testes, incluindo a flag de produção. Acréscimos de contrato: `PlayerMotor.set_noclip/is_noclip/notify_teleported`, `PlayerRoot.teleport_to/set_noclip/get_camera/get_interaction`
- **Descrição:** overlay F3 (fps, frame time, postura, marcha, esforço, velocidade, foco) e comandos (noclip, teleporte), desligados em produção.
- **Aceitação:** a flag de produção desliga overlay e comandos.
- **Testes:** integration da flag de produção.

### F1-009 · Sandbox greybox
- **Responsável:** Level Designer · **Esforço:** MEDIUM · **Depende de:** F1-006 · **Status:** APPROVED (Gate F1: revisão F1-010 e validação F1-011). Antes: REVIEW. `sandbox.tscn` (gerada por `tools/level/gen_sandbox.py`), 8 testes MOT-04 na sandbox, capturas inspecionadas. Integração do Director: `LevelSlots` (portas e pickups nos marcadores), `sandbox_playable.tscn` como cena principal (com menu de pausa e overlay), 5 testes de integração; achado e corrigido: porta que começa aberta nascia com o painel fechado
- **Descrição:** `content/levels/sandbox.tscn` com 4 salas, corredor estreito, escada para mezanino, mesa para rastejar, portas e superfícies (madeira, tapete, azulejo, concreto) com metadado. Iluminação escura com névoa volumétrica. `RoomVolume` e `Portal` já posicionados para a F3.
- **Aceitação:** todas as mecânicas da F1 são exercitáveis; screenshot por script (com janela) anexado.
- **Testes:** MOT-04 roda nesta cena.

### F1-013 · Remapeamento de controles
- **Responsável:** Gameplay Engineer · **Esforço:** MEDIUM · **Depende de:** F1-004 · **Status:** APPROVED (Gate F1: revisão F1-010 e validação F1-011). Antes: REVIEW. 17 testes (ACC-05: remapear → reiniciar → persiste; conflito avisado e não aplicado); menu de pausa mínimo; `core/input_bindings.gd`
- **Descrição:** tela mínima para remapear as ações do input map, com aviso de conflito e persistência em `Settings.input_bindings`.
- **Aceitação:** critérios de ACC-05.
- **Testes:** ACC-05.

### F1-014 · Registro de licenças de assets
- **Responsável:** Art & Environment · **Esforço:** LOW · **Depende de:** D-06 · **Status:** APPROVED (Gate F1: revisão F1-010 e validação F1-011). Antes: REVIEW. Feito pelo Director: `ASSET_LICENSES.md` + regra no checklist do Reviewer (AGENT_ASSIGNMENTS §2). D-06 aprovada em 2026-11-20: CC0 permitido com registro
- **Descrição:** `ASSET_LICENSES.md` (asset, fonte, licença, data, URL) + regra: nenhum asset externo entra sem registro.
- **Aceitação:** arquivo criado; regra adicionada ao checklist do Technical Reviewer.

### F1-010 · Revisão técnica da Fase 1
- **Responsável:** Technical Reviewer · **Esforço:** HIGH · **Depende de:** F1-003..F1-009, F1-013 · **Status:** APPROVED (com ressalvas). Revisão REPROVADA (2 ALTO, 5 MÉDIO); correções; nova verificação APROVADO COM RESSALVAS. Ressalvas tratadas ou aceitas em `Docs/QA/REVIEWS/F1-010_RESOLUTION.md`
- **Aceitação:** relatório com achados classificados; críticos e altos resolvidos ou aceitos pelo Director com justificativa.

### F1-011 · Validação de QA da Fase 1
- **Responsável:** QA Engineer · **Esforço:** EXTRA HIGH · **Depende de:** F1-010 · **Status:** APPROVED (com ressalvas). Três rodadas: 5 bugs novos na 1ª (BUG-004..008), regressão BUG-009 na 2ª, BUG-010/011 na 3ª; todos fechados ou aceitos. Relatório: `Docs/QA/F1-011_VALIDATION.md`
- **Aceitação:** suíte completa executada pelo QA, com saída em TEST_RESULTS.md; tentativas de exploit documentadas (prender-se na geometria, levantar no vão, interagir através de paredes).

### F1-012 · Documentação da Fase 1
- **Responsável:** Project Director · **Esforço:** LOW · **Depende de:** F1-011 · **Status:** APPROVED. PLAYER_CONTROLLER.md v1.0, CHANGELOG, KNOWN_ISSUES, TEST_RESULTS (seção Gate F1) e ROADMAP atualizados
- **Descrição:** PLAYER_CONTROLLER.md, CHANGELOG, KNOWN_ISSUES, TEST_RESULTS e ROADMAP atualizados.

**Paralelismo na F1:** depois de F1-004, F1-005 ∥ F1-006 ∥ F1-008 ∥ F1-013. F1-009 começa com F1-006 em andamento. Os documentos de design rodam em paralelo, sem dependência de código:

| ID | Tarefa de design | Responsável | Esforço | Status |
|---|---|---|---|---|
| F1-D01 | GAME_DESIGN_DOCUMENT v0.1 (pilares, loop, mecânicas, capítulos, itens) | Project Director | MEDIUM | APPROVED como v0.1. Antes: REVIEW (Docs/Design/GAME_DESIGN_DOCUMENT.md) |
| F1-D02 | NARRATIVE v0.1 (mistério, objeto procurado, moradores anteriores, pistas por capítulo) | Level Designer | MEDIUM | REVIEW (Docs/Design/NARRATIVE.md; questões N-01..N-05 em aberto) |
| F1-D03 | ART_DIRECTION v0.1 (paleta, luz, materiais, orçamento de polígonos) | Art & Environment | MEDIUM | APPROVED como v0.1. Antes: REVIEW (Docs/Design/ART_DIRECTION.md; 5 materiais CC0 em game/content/materials/, licenças conferidas; captura em EVIDENCE/F1-D03_materials.png) |

**Desvios de esforço em relação à matriz do MASTER §7.1 (justificados):**
- F1-009 sandbox: MEDIUM (level design é HIGH). É uma cena de teste descartável, não level design de produção.
- F1-D03 direção de arte: MEDIUM (HIGH na matriz). É um rascunho; a direção de arte de produção (F5-006) é HIGH.
- F5-002 esconderijos e F5-005 checkpoints: EXTRA HIGH (HIGH na matriz). Integram o firewall da IA e a persistência, que o MASTER §7 classifica como EXTRA HIGH.

---

## 5. Backlog das Fases 2–6 (resumo; cards completos ao abrir cada fase — DIR-02)

| ID | Tarefa | Responsável | Esforço | Depende de |
|---|---|---|---|---|
| F2-001 | StaminaModel (L1) + testes | Physiological Eng. | HIGH | F1 |
| F2-002 | StressModel (L1) + testes (inclui startle e injury) | Physiological Eng. | HIGH | F1 |
| F2-003 | RespiratoryModel (L1): estados, tosse com aviso, `recovery_progress` | Physiological Eng. | EXTRA HIGH | F2-001, F2-002 |
| F2-004 | PhysiologyCoupling + PhysiologyComponent + integração via PlayerRoot + `StubThreatSource` | Physiological Eng. | EXTRA HIGH | F2-003 |
| F2-005 | Bombinha, comprimido e água + inventário mínimo de cargas | Physiological Eng. + Gameplay | MEDIUM | F2-004 |
| F2-006 | BreathEmitter + AcousticWorld mínimo + BreathingAudio (produtor único) | Physiological Eng. + Audio Eng. | EXTRA HIGH | F2-004 |
| F2-007 | Efeitos de câmera + indicador respiratório + intensidade de efeitos (acessibilidade) | Gameplay Eng. | MEDIUM | F2-004 |
| F2-008 | Ferramenta de balanceamento (sliders + simulação headless com curvas) | Physiological Eng. | HIGH | F2-004 |
| F2-009 | Animações procedurais em primeira pessoa (respiração, tosse, bombinha com viewmodel provisório) | Gameplay Eng. | MEDIUM | F2-004 |
| F3-001 | AcousticGraph (L1) + testes (pode rodar em paralelo com a F2) | AI Eng. | EXTRA HIGH | F1 |
| F3-002 | AcousticWorld completo, NoiseEmitter, RoomVolume, Portal, piso de chuva e trovão | AI Eng. | HIGH | F3-001, F2-006 |
| F3-003 | NoiseAudioRouter (atenuação nativa desligada, reverb por sala) | Audio Eng. | EXTRA HIGH | F3-002 |
| F3-004 | Ruídos do jogador e do mundo; objetos de distração arremessáveis | Gameplay + Audio | HIGH | F3-002 |
| F3-005 | Exposição à luz do jogador (LightExposureProbe) | Gameplay Eng. | MEDIUM | F1 |
| F3-006 | Legendas de sons relevantes | Gameplay + Audio | MEDIUM | F3-002 |
| F4-001 | PerceivableTarget + VisionSensor | AI Eng. | EXTRA HIGH | F3-005 |
| F4-002 | HearingSensor | AI Eng. | HIGH | F3-002 |
| F4-003 | EnemyBrain (FSM) + PerceptionMemory (L1) | AI Eng. | EXTRA HIGH | F4-001, F4-002 |
| F4-004 | EnemyController + EnemyWorldQuery + navegação + THE OBSERVER | AI Eng. | EXTRA HIGH | F4-003 |
| F4-005 | Captura básica (`EnemyCaptureArea` → `player_captured`) | AI Eng. + Gameplay | MEDIUM | F4-004 |
| F4-006 | PlayerThreatMonitor (`PlayerHeardNoise`) + AdaptiveMusic básica; PHY-12 | Physiological Eng. + Audio | HIGH | F4-004 |
| F5-001 | Planta e greybox do térreo parcial (2 rotas, 3 esconderijos) | Level Designer | HIGH | F4 |
| F5-002 | Hideable + HidingComponent + inspeção pela IA | Gameplay + AI | EXTRA HIGH | F4-004 |
| F5-003 | InventoryModel básico + UI mínima | Gameplay Eng. | MEDIUM | F2-005 |
| F5-004 | ObjectiveGraph + ObjectiveManager | Gameplay Eng. | HIGH | F1 |
| F5-005 | CheckpointManager + Saveable + sequência de captura + estado do RNG | Software Architect | EXTRA HIGH | F5-003, F5-004 |
| F5-006 | Arte básica do slice, após aprovação do greybox | Art & Environment | HIGH | F5-001 aprovado |
| F5-007 | Sequência de fuga completa e playtest | Director + QA | EXTRA HIGH | todas F5 |
| F6-001 | DifficultyModel + DifficultyManager | AI Eng. | HIGH | F5 |
| F6-002 | EnvironmentState (contrato + persistência + eventos) | Software Architect | HIGH | F5-005 |
| F6-003 | THE AGGRESSIVE, THE LEADER e SquadCoordinator | AI Eng. | EXTRA HIGH | F5 |
| F6-004 | Casa completa e mecânicas por capítulo (ROADMAP F6) | Level Designer + Director | HIGH | F6-002 |

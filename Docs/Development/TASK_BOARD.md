# Task Board — DEAD BREATH

| Campo | Valor |
|---|---|
| Atualizado | 2026-11-20 |
| Fase atual | **FASE 3 — Furtividade e áudio** (Gate F2 aprovado pelo usuário em 2026-11-20) |
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
| D-07 | Áudio de respiração | Opcional: gravar respiração, chiado e tosse reais com microfone. Alternativa: síntese procedural + CC0 | **DECIDIDA** (2026-11-20): **síntese procedural** (+ CC0 se preciso). Se o resultado não ficar bom, o usuário grava |

## 2. Propostas de funcionalidade (MASTER §18)

| ID | Proposta | Benefício | Custo/risco | Recomendação |
|---|---|---|---|---|
| P-01 | **Abafar a tosse**: segurar uma tecla durante o aviso (65 → 48 dB), ao custo de stamina e de aumento da severidade | Agência na crise; reforça o tema sem aleatoriedade | Baixo | Avaliar na F2 |
| P-02 | **Prender a respiração** por poucos segundos (silencia BREATHING/WHEEZING; recuperação mais ruidosa depois) | Mecânica de esconderijo coerente com o tema | Médio (balanceamento com a asma) | Avaliar na F2 |
| P-03 | Categoria de ruído **VOICE** (falas e gritos dos criminosos) | Comunicação do esquadrão audível e justa; base das legendas de fala | Baixo | **APROVADA** pelo Director na abertura da F3 (2026-11-20) |
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

## 4b. FASE 2 — Fisiologia (detalhada, aberta em 2026-11-20)

Contratos congelados para a fase: COMPONENT_CONTRACTS §4 (v1.0) e §4.3 (acréscimos da F2), §6.3 (BreathEmitter), §6.4 (AcousticWorld mínimo da F2) e §14 (BreathingAudio). Fórmulas em DATA_STRUCTURES §1.2–1.7 e §2.4. Sons: síntese procedural (D-07).

**Ondas e escritores**
- **Onda A (paralela):** F2-001..F2-004 (Physiological Eng.) ∥ F2-006a (Audio Eng.).
- **Onda B:** F2-006b (Audio) ∥ F2-005, F2-007, F2-009 (Gameplay) ∥ F2-008 (Physio). Na onda B, só o Gameplay Engineer altera `player_root.gd` e `player.tscn`; o Director integra os componentes entregues pelos demais.
- **Onda C:** F2-010 revisão, F2-011 QA, F2-012 documentação.

### F2-001 · StaminaModel (L1)
- **Responsável:** Physiological Eng. · **Esforço:** HIGH · **Depende de:** Gate F1 · **Status:** APPROVED (Gate F2: revisão F2-010 e validação F2-011). Antes: REVIEW (entregue; pipeline verde na execução do Director)
- **Descrição:** `sim/physiology/stamina_model.gd` + `StaminaConfig` (Resource, DATA §1.2) + `content/data/physiology/stamina_config.tres`. Dreno de sprint, atraso de regeneração, regeneração por marcha/repouso, multiplicador do acoplamento, histerese de exaustão (reabilita o sprint em 25). `to_dict/from_dict`.
- **Aceitação:** sprint de tanque cheio dura 8,3 s ± 0,1; sem regeneração durante `regen_delay_s`; PHY-INV-1.
- **Testes:** unit (dreno, regeneração, histerese, limites), parte do PHY-09.

### F2-002 · StressModel (L1)
- **Responsável:** Physiological Eng. · **Esforço:** HIGH · **Depende de:** Gate F1 · **Status:** APPROVED (Gate F2: revisão F2-010 e validação F2-011). Antes: REVIEW (entregue; pipeline verde na execução do Director)
- **Descrição:** `stress_model.gd` + `StressConfig` (DATA §1.3): ganhos por ameaça (`ThreatSample`), picos (`add_spike`: susto, ferimento, captura), decaimento com atraso, faixas CALM..PANIC. `to_dict/from_dict`.
- **Aceitação:** faixas nos limiares de §1.3; decaimento de 100 a 0 sem ameaça em ≈ 37,3 s (4 s de atraso + 3/s).
- **Testes:** unit, PHY-02 (parte), PHY-06/09.

### F2-003 · RespiratoryModel (L1)
- **Responsável:** Physiological Eng. · **Esforço:** EXTRA HIGH · **Depende de:** F2-001, F2-002 · **Status:** APPROVED (Gate F2: revisão F2-010 e validação F2-011). Antes: REVIEW (entregue; pipeline verde na execução do Director)
- **Descrição:** `respiratory_model.gd` + `RespiratoryConfig` (DATA §1.4): EMA do esforço, severidade com subida/descida, frequência respiratória, chiado, hazard de tosse com aviso de 1,5 s e cooldown, cancelamento, máquina de estados com histerese e permanência mínima, `recovery_progress`, medicação (`MedicationProfile`, §1.7). RNG injetado. `to_dict/from_dict` completo (DATA §6.1).
- **Aceitação:** PHY-01..PHY-11 verdes.
- **Testes:** PHY-01..PHY-11 (propriedade em `tests/property/` quando > 1 s), PER-07 no nível dos modelos.

### F2-004 · PhysiologyCoupling + PhysiologyComponent + integração
- **Responsável:** Physiological Eng. · **Esforço:** EXTRA HIGH · **Depende de:** F2-003 · **Status:** APPROVED (Gate F2: revisão F2-010 e validação F2-011). Antes: REVIEW (entregue; pipeline verde na execução do Director)
- **Descrição:** `PhysiologyCoupling.compute` (DATA §1.6, `CouplingConfig`); `components/player/physiology_component.gd` (§4.1: sinais, RNG próprio com semente exportável, gasp de susto); `ThreatSource`/`StubThreatSource` (§5, ameaça controlável por teste e overlay); integração no `PlayerRoot` (tick §1: motor → inputs → physiology → `apply_limits(coupling)` → interaction com `steadiness`).
- **Aceitação:** correr até esgotar deixa o jogador sem sprint até 25 de stamina; a crise reduz o sprint máximo (§1.6); `steadiness` alonga o "segurar" (contrato §3); ARC-06 continua verde.
- **Testes:** integration no jogador (sprint → exaustão → LABORED; limites aplicados no tick seguinte; firmeza da mão), ARC-03/05/06.

### F2-005 · Bombinha, comprimido e água + inventário mínimo de cargas
- **Responsável:** Physiological Eng. + Gameplay Eng. · **Esforço:** MEDIUM · **Depende de:** F2-004 · **Status:** APPROVED (Gate F2: revisão F2-010 e validação F2-011). Antes: REVIEW (bombinha + inventário mínimo entregues; puff ligado pelo Director). **Decisão do Director:** comprimido e água ficam para a F5, junto da tela de inventário, porque exigem escolher o item a usar; a fisiologia já tem `apply_consumable` no modelo
- **Descrição:** `use_item` (Q) aplica a bombinha (`apply_medication`, cooldown 10 s, ruído MEDICATION 38 dB); `InventoryModel` mínimo (contagem por item; bombinha = 3 doses por unidade) alimentado por `EventBus.item_picked`; o jogador começa com 1 bombinha. Comprimido e água: efeito conforme DATA §1.7 (detalhar no card ao abrir a onda B).
- **Aceitação:** sem cargas ou em cooldown, nada acontece (feedback); pickup da sandbox soma cargas; PHY-04/05 no jogador.
- **Testes:** integration (uso, cooldown, carga, pickup).

### F2-006 · Respiração audível: produtor único + sons procedurais
- **F2-006a (Audio Eng., onda A, HIGH, APPROVED (Gate F2; audição do usuário pendente). Antes: REVIEW: entregue; 41 sons, 4,8 MB, determinismo verificado pelo Director; aguarda a audição do usuário com `tools/audio/audition.ps1`):** gerador determinístico e versionado em `tools/audio/` que sintetiza respiração (calma, rápida, ofegante), chiado, aviso de tosse, tosse, gasp e puff da bombinha, com variações, em `game/content/audio/body/`. Assets próprios (sem licença externa). Aceitação: arquivos gerados de novo são idênticos (bit a bit) com a mesma semente; amostras inspecionadas (espectro e envelope) e audição pelo usuário no playtest da F2.
- **F2-006b (Audio Eng. + Physio, onda B, EXTRA HIGH, APPROVED (Gate F2). Antes: REVIEW: componentes entregues e testados; ligados ao jogador e à cena jogável pelo Director, commit `63dca84`, com teste da cadeia completa):** `BreathEmitter` (§6.3), `BreathParams` (L1, DATA §2.4), `AcousticWorld` mínimo (§6.4) e `BreathingAudio` (L3, §14). Aceitação: um `NoiseEvent` por ciclo respiratório e por tosse; o som que o jogador ouve vem só desses eventos (NOI-INV-1/2); gasp a partir do susto.

### F2-007 · Efeitos de câmera, indicador respiratório e intensidade de efeitos
- **Responsável:** Gameplay Eng. · **Esforço:** MEDIUM · **Depende de:** F2-004 · **Status:** APPROVED (Gate F2: revisão F2-010 e validação F2-011). Antes: REVIEW (ACC-01..03 verdes)
- **Descrição:** `CameraEffects` (L3): balanço respiratório, tremor, solavanco da tosse e escurecimento discreto na crise, escalados por `motion_reduction`, `tremor_reduction` e `effects_intensity`; indicador respiratório opcional (desligado por padrão).
- **Testes:** ACC-01, ACC-02, ACC-03.

### F2-008 · Ferramenta de balanceamento
- **Responsável:** Physiological Eng. · **Esforço:** HIGH · **Depende de:** F2-004 · **Status:** APPROVED (Gate F2: revisão F2-010 e validação F2-011). Antes: REVIEW (painel F4 + simulação determinística)
- **Descrição:** sliders no overlay de debug (ameaça do `StubThreatSource`, parâmetros principais) e simulação headless que exporta curvas (CSV) de cenários padrão (sprint, susto, crise e recuperação, bombinha).

### F2-009 · Animações procedurais em primeira pessoa
- **Responsável:** Gameplay Eng. · **Esforço:** MEDIUM · **Depende de:** F2-007 · **Status:** APPROVED (Gate F2: revisão F2-010 e validação F2-011). Antes: REVIEW (viewmodel provisório; aparência a melhorar na F7)
- **Descrição:** viewmodel provisório (mão e bombinha em primitivas), animação de uso da bombinha, sobressalto da tosse.

### F2-010 · Revisão técnica da Fase 2 — Technical Reviewer · HIGH · APPROVED (com ressalvas)
`Docs/QA/REVIEWS/F2-010.md`: 0 CRÍTICO, 0 ALTO. R2-01 (ponte de susto) → F3-002; R2-02 (PER-07 só em memória) → ARCH-001, antes da F5; BAIXO tratados ou registrados em KNOWN_ISSUES.
### F2-011 · Validação de QA da Fase 2 — QA Engineer · EXTRA HIGH · APPROVED (com ressalvas)
`Docs/QA/F2-011_VALIDATION.md`: pipeline 2× verde (padrão 293, property 99, meta 26); cenário "correr até a crise e se recuperar" gravado com janela; BUG-012..015 (012 fechado, 015 aceito, 013 aguarda a escuta do usuário, 014 vai para a F3-002).
Inclui o playtest "correr até a crise e se recuperar" com gravação e o exame de exploits (abusar da bombinha, cancelar a tosse, prender a crise).
### F2-012 · Documentação — Director · LOW · APPROVED
RESPIRATORY_SYSTEM.md, STRESS_SYSTEM.md, STAMINA_SYSTEM.md, CHANGELOG, TEST_RESULTS.

**Propostas P-01 (abafar a tosse) e P-02 (prender a respiração):** ficam fora do escopo inicial. Serão avaliadas com o jogo rodando, depois da F2-007, e submetidas ao usuário.

---

## 4c. FASE 3 — Furtividade e áudio (detalhada, aberta em 2026-11-20)

Contratos congelados para a fase: COMPONENT_CONTRACTS §6.1–§6.5 e §14 (NoiseAudioRouter, legendas); DATA_STRUCTURES §2–§2.5. Decisões de abertura: **P-03 (VOICE) aprovada**; ponte de susto pelo ouvinte do jogador (§6.5); NOI-01 fica sem alvo real até a F4 (precisa do HearingSensor); a física é reavaliada com corpos dinâmicos (RSK-13).

**Ondas e escritores**
- **Onda A (paralela):** F3-001 (AI Eng.) ∥ F3-003a (Audio Eng.) ∥ F3-005 + reavaliação da física (Gameplay Eng.).
- **Onda B:** F3-002 (AI) ∥ F3-003b (Audio) ∥ F3-004 e F3-006 (Gameplay) ∥ F3-007 (Level Designer). Só o Gameplay Engineer altera `player_root.gd`/`player.tscn`; só o Level Designer altera `sandbox.tscn` e `tools/level/`; o Director integra a cena jogável.
- **Onda C:** F3-010 revisão, F3-011 QA, F3-012 documentação (STEALTH_SYSTEM.md, AUDIO_DESIGN.md).

### F3-001 · AcousticGraph (L1) + tipos de dados
- **Responsável:** AI Engineer · **Esforço:** EXTRA HIGH · **Depende de:** Gate F2 · **Status:** DONE (revisão F3-010 e QA F3-011). Entregue com STL-07 dentro de ±0,2 m nos 7 casos e NOI-02 sem nenhuma subida em 1 000 grafos. Divergências D-01..D-09 decididas pelo Director (TEST_PLAN, SYSTEM §7/§14, DATA §2/§2.3)
- **Descrição:** `sim/acoustics/acoustic_graph.gd` (§6.1): salas, portais com posição e estado aberto/fechado, Dijkstra pelo grafo, caminho através de paredes (perda por parede) e de pisos, `room_at`, `weather_offset`, regra de audibilidade (DATA §2.3). `AcousticConfig` (Resource, §2.2) + `.tres`. `HeardNoise` e `PlayerHeardNoise` (§2) em L1. Determinístico; fechar porta nunca aumenta o nível.
- **Aceitação/Testes:** STL-01 (ordem das intensidades), STL-02, STL-03, STL-07 (7 exemplos de DATA §2.3, ±0,2 m), NOI-02, NOI-03 (reflexão dos campos permitidos). A assinatura de `propagate` é a mesma do `AcousticPropagation.perceive` da F2.

### F3-002 · AcousticWorld completo, RoomVolume, Portal, chuva e trovão, ponte de susto
- **Responsável:** AI Engineer · **Esforço:** HIGH · **Depende de:** F3-001 · **Status:** DONE (revisão F3-010 e QA F3-011). Pipeline verde (363/363). Porta real sincroniza o portal (15 dB), trovão (limiar 19 → 39 dB), ouvinte do jogador, `room_id`, legendas, NOI-05; decisões em COMPONENT_CONTRACTS §6.5
- **Descrição:** a tabela de intensidades de DATA §2.1 passa a ser um Resource (`NoiseLevels` + `.tres`), substituindo as constantes provisórias de `AcousticLevels` (decisão D-03). O AcousticWorld troca a propagação provisória pelo grafo, construído a partir dos nós `RoomVolume`/`Portal` do nível. As portas atualizam o portal ligado (`Door.state_changed`). Clima com chuva por sala (`ambient_floor_db`) e trovão (+20 dB por 2,5 s, agendado por RNG próprio). Entrega de `PlayerHeardNoise` ao ouvinte do jogador (§6.5) para eventos de outra fonte. `NoiseEmitter` (§6.3) para fontes do mundo. A interface da F2 continua compatível.
- **Testes:** integração (porta fechando reduz o nível percebido; trovão eleva o limiar; o ouvinte do jogador só recebe eventos de outras fontes, sem posição nem id), NOI-05.

### F3-003 · Som do mundo
- **F3-003a (Audio Eng., onda A, HIGH, DONE):** biblioteca de sons do mundo em `game/content/audio/world/` com manifesto: passos por superfície (madeira, tapete, azulejo, concreto) e marcha, corrida, porta (lenta, normal, batida, trancada), impactos de objeto (leve, médio, pesado), arrasto de móvel, queda, chuva (camadas: interna abafada, janela, externa) e trovões. Procedural quando soar bem; CC0 (D-06) com registro em `ASSET_LICENSES.md` quando a síntese não convencer. Gerador determinístico para o que for procedural.
- **F3-003b (Audio Eng., onda B, EXTRA HIGH, DONE; integrada pelo Director na `sandbox_playable.tscn`, com trovão ligado):** `NoiseAudioRouter` (L3, §14): toca os eventos que não são do corpo do jogador em 3D (só panning), com `volume_db` derivado de `perceived_db` (NOI-04: ≤ 0,5 dB), atenuação nativa desligada (NOI-INV-2) e reverb por sala (barramento do `RoomVolume`). Ambiência de chuva e trovão guiada pelo estado de clima do AcousticWorld.

### F3-004 · Ruídos do jogador e do mundo; objetos de distração
- **Responsável:** Gameplay Eng. (+ Audio) · **Esforço:** HIGH · **Depende de:** F3-002 · **Status:** DONE (revisão F3-010 e QA F3-011). Pipeline verde (padrão 446/446 em 8,9 s, propriedade 117/117). Porta que fecha (fechada pela interação: −15 dB do corredor ao hall), passos e corrida pelo contrato da F3-003b, queda (acima de 2,5 m/s), ruídos de porta, 5 arremessáveis, ponte de susto (BUG-014) e STL-01 no jogo. Três conflitos resolvidos pelo Director: varredura do NOI-INV-1 precisa (só receptor NoiseEmitter), `throw` no botão esquerdo (teste de remapeamento usa botão livre) e porta aberta que fecha ao toque (teste de QA atualizado)
- **Descrição:** **porta que fecha** (decisão do Director na F3-002: hoje a Door só abre; acrescentar OPEN → CLOSED por interação, segurar = fechar devagar 30 dB, tocar = normal 50 dB, e o teste "porta fechando reduz o percebido"); passos e corrida (sinal `footstep` → evento FOOTSTEP/RUNNING com modificador de superfície, DATA §2.1), queda (`landed` → FALL), portas (`opened`, `blocked`, `locked_feedback`, `interaction_failed` → DOOR), objetos arremessáveis (RigidBody3D; pegar, arremessar, impacto → OBJECT_IMPACT 50–80 dB por velocidade). Ponte de susto no PlayerRoot (§6.5).
- **Testes:** STL-01 no jogo (rastejar < agachado < andar < correr < tosse < queda), integração de cada fonte; reavaliação da física (abaixo).

### F3-005 · LightExposureProbe + reavaliação da física
- **Responsável:** Gameplay Eng. · **Esforço:** MEDIUM · **Depende de:** F1 · **Status:** DONE (revisão F3-010 e QA F3-011). Probe entregue (17 testes padrão e 2 de propriedade). Spike de física nos dois motores: V6 ALL_PASS em ambos; a pilha de caixas afunda 35,7 mm no GodotPhysics3D e 2,1 mm no Jolt. **Decisão do Director: manter o GodotPhysics3D.** Com o Jolt, a suíte completa tem 30 falhas de escada (ENGINE_DECISION §7.2)
- **Descrição:** `LightExposureProbe` (L2): exposição 0..1 em pontos de amostra a partir das luzes (alcance, atenuação, cone e oclusão por raio), para a F4 (visão do inimigo e PerceivableTarget). **RSK-13:** rodar de novo o spike V6 e um teste de corpos dinâmicos (pilha, arremesso, repouso, colisão com o jogador) em GodotPhysics3D e Jolt; registrar a decisão.
- **Testes:** exposição no escuro ≈ 0, sob luz direta alta, atrás de parede ≈ 0; resultados do spike.

### F3-006 · Legendas (ACC-04)
- **Responsável:** Gameplay Eng. + Audio · **Esforço:** MEDIUM · **Depende de:** F3-002 · **Status:** DONE (revisão F3-010 e QA F3-011). UI `Subtitles` na sandbox jogável; tabela pt-BR própria (`content/data/subtitles/subtitles_pt_br.json`), sem infraestrutura de tradução por enquanto
- **Descrição:** o AcousticWorld emite `EventBus.subtitle_requested(text_key, duration)` para sons relevantes ouvidos pelo jogador (tosse, porta, passos próximos, falas); UI de legendas com `subtitles_enabled` e `subtitles_size`.
- **Testes:** ACC-04.

### F3-007 · Sandbox acústica
- **Responsável:** Level Designer · **Esforço:** MEDIUM · **Depende de:** F3-001 · **Status:** DONE (revisão F3-010 e QA F3-011). Seis `RoomVolume` (sala 28 dB com janela; cozinha, corredor, hall e mezanino 22; quintal exterior 38, sem teto), seis `Portal` (cinco com porta real do `LevelSlots`, um vão aberto hall–mezanino), porta nova `door_hall_quintal`, cinco `throwable_slot`. Porta corredor–hall muda 15,0 dB no nível real. Achados: a janela só muda o piso de ruído (não há abertura para fora); o vão do mezanino conta como portal aberto
- **Descrição:** trocar os marcadores de sala e portal da sandbox por `RoomVolume`/`Portal`, com `ambient_floor_db` coerente (DATA §2.3) e portas ligadas aos portais; uma área com janela/exterior para testar a chuva; pontos de objetos arremessáveis.

### F3-008 · Visão de debug acústica (anéis de ruído e grafo)
- **Responsável:** Tools Programmer · **Esforço:** MEDIUM · **Depende de:** F3-002 · **Status:** DONE (revisão F3-010 e QA F3-011). Integrada na `sandbox_playable` pelo Director; 13 testes (raio pela fórmula com 4 casos calculados à mão, salas e portais iguais aos do grafo, cor acompanhando a porta, anel que expira, nada liga em produção); captura em `Docs/QA/EVIDENCE/F3-008_visao_acustica_debug.png`. A revisão técnica F3-010 foi anterior a este card: ele é validado pelo QA na F3-011
- **Origem:** item do escopo da Fase 3 no ROADMAP ("Debug: anéis de ruído e grafo") que ficou sem card na abertura. O Director notou antes da F3-011 e abriu o card.
- **Descrição:** `AcousticDebugView` (L3), tecla F5, só em build de desenvolvimento. Mostra as salas em arame com cor pelo piso de ruído, os portais verdes ou vermelhos acompanhando as portas, e anéis de ruído no chão. O raio do anel é o alcance em campo livre até o limiar da sala (DATA §2.2) e o anel some em cerca de 1,5 s. Sem custo quando desligada.
- **Testes:** raio pela fórmula; salas e portais iguais aos do grafo; a cor acompanha a porta; o anel aparece e expira; nada liga em produção.

### F3-010 · Revisão técnica — Technical Reviewer · HIGH · DONE (revisão e nova verificação: APROVADO COM RESSALVAS, sem CRÍTICO, ALTO ou MÉDIO em aberto; rastreio em `Docs/QA/REVIEWS/F3-010_RESOLUTION.md`)
### F3-011 · Validação de QA — QA Engineer · EXTRA HIGH · DONE (APROVADO COM RESSALVAS; BUG-014 e BUG-016 fechados pelo QA; fechamento em `Docs/QA/F3-011_VALIDATION.md`)
### F3-012 · Documentação — Director · LOW · DONE
STEALTH_SYSTEM.md e AUDIO_DESIGN.md.

---

## 4d. FASE 4 — IA inimiga (detalhada, aberta em 2026-11-24)

Contratos congelados para a fase: COMPONENT_CONTRACTS §5 (com a decisão D4-01), §6.5–§6.6, §7, §8 e §16; DATA_STRUCTURES §2.3, §3–§3.3 e §5. Critério do gate (ROADMAP): AI-01..08, PHY-12 e ARC-01 verdes; medição de desempenho registrada; playtest curto na sandbox; ENEMY_AI.md escrito.

**Decisões de abertura (Director)**
- **D4-01 (pendente desde a F2):** o `PlayerThreatMonitor` é um componente `Node` do jogador e expõe a fonte de ameaça por composição: `get_threat_source() -> ThreatSource` (RefCounted). O PlayerRoot faz `set_threat_source(monitor.get_threat_source())`. O monitor substitui a ponte de susto da F3 no `register_player_listener` (o susto vira sinal do monitor, ligado pelo PlayerRoot à fisiologia).
- **D4-02:** um inimigo na F4 (THE OBSERVER). `SquadCoordinator` e fala de esquadrão ficam para a F6; o `PerceptBatch.squad` vem vazio.
- **D4-03:** portas na rota: o inimigo abre a porta fechada e destrancada que está no caminho (`Door.interact` com o inimigo como ator; ruído normal de 50 dB). Porta trancada nunca é rota.
- **D4-04:** captura provisória até os checkpoints da F5: tela "capturado" e reinício da sandbox.
- **D4-05:** o Observer é greybox (cápsula com cabeça e lanterna, se o GDD pedir). Blender (D-05) fica para quando houver arte de personagem.
- **D4-06:** falas (VOICE) do Observer com voz procedural provisória e legenda; a escuta do usuário decide se troca por gravação ou CC0.
- **Pendências da F3 tratadas aqui:** NOI-01 com alvo real (HearingSensor), D-07 em uso (`HeardNoise.from_propagation`), custo do LightExposureProbe (GAME-010), falas e legendas de fala (R3-11).

**Ondas e escritores**
- **Onda A (paralela):** F4-001/002 (AI Engineer "percepção") ∥ F4-003 (AI Engineer "cérebro") ∥ F4-008 (Level Designer) ∥ F4-006a (Audio Engineer). Só o Level Designer altera `sandbox.tscn`/`tools/level/`; só o AI Engineer "percepção" altera `acoustic_world.gd`.
- **Onda B:** F4-004 (AI Engineer) ∥ F4-009 integração do jogador + F4-006b monitor (Gameplay e Physiological Eng.; só o Gameplay altera `player_root.gd`/`player.tscn`).
- **Onda C:** F4-005 captura, F4-007 desempenho; depois F4-010 revisão, F4-011 QA (com playtest curto), F4-012 documentação (ENEMY_AI.md).

### F4-001 · PerceivableTarget + VisionSensor
- **Responsável:** AI Engineer (percepção) · **Esforço:** EXTRA HIGH · **Depende de:** F3-005 · **Status:** REVIEW. `PerceivableTarget` e `VisionSensor` (DATA §3.2 em funções puras; linha de visão contra as camadas 1, 2 e 7; percept sem visibilidade sai com posição zero). 6 mutações pegas pelos testes
- **Descrição:** `PerceivableTarget` (§7.1; filho do jogador, grupo `perceivable`, pontos de amostra cabeça, tronco e pés; exposição do LightExposureProbe, fator de postura, ocultação 0 até a F5). `VisionSensor` (§7.2) com a fórmula de DATA §3.2 (FOV, alcance, fração de linha de visão contra mundo e props, distância, luz, postura, ocultação). A ligação no `player.tscn` é da F4-009.
- **Testes:** fórmula com casos calculados à mão; oclusão por parede e `vision_occluder`; fora do FOV e do alcance = 0; ARC-01 (só `vision_sensor.gd` conhece o alvo).

### F4-002 · HearingSensor + entrega do AcousticWorld
- **Responsável:** AI Engineer (percepção) · **Esforço:** HIGH · **Depende de:** F3-002 · **Status:** REVIEW. `HearingSensor` e entrega pelo AcousticWorld (limiar efetivo com clima, D-07, RNG acústico semeado, sem o próprio som). NOI-01 com alvo real (varredura de receptor único). Falta para a F5: acessor do estado do RNG acústico (snapshot)
- **Descrição:** `HearingSensor` (§7.2; limiar do AIProfile). O AcousticWorld entrega a cada sensor (grupo) um `HeardNoise` criado por `HeardNoise.from_propagation` com o limiar efetivo do perfil (DATA §2.3: `max(hearing_threshold, piso + clima + masking_margin)`) e o RNG do mundo. NOI-01 passa a ter alvo real.
- **Testes:** NOI-01 (só o AcousticWorld chama `receive`); o sensor só recebe o que é audível para ele; posição estimada e confiança chegam conforme D-07; NOI-03 continua.

### F4-003 · EnemyBrain (FSM) + PerceptionMemory (L1)
- **Responsável:** AI Engineer (cérebro) · **Esforço:** EXTRA HIGH · **Depende de:** contratos §8.2 e DATA §3 · **Status:** REVIEW. Tipos de DATA §3, `AIProfile` com os 3 `.tres`, `PerceptionMemory` e `EnemyBrain` com a tabela de transições completa (inclui audição pela D4-08 e o timeout de 15 s de INVESTIGATE). AI-02..06 em L1; AI-06 com 50 pares, visão e ruídos. Decisões no relatório: raio de chegada 1 m, critério do `best_lead`, velocidades de SEARCH/RETURN/LOST_CONTACT
- **Descrição:** `sim/ai/`: tipos de DATA §3 (VisualPercept, PerceptBatch, PerceptionRecord, EnemyIntent, BrainWorldQuery abstrata, HideableInfo, EnemyInitialState, SquadMessage só como tipo), `AIProfile` (Resource) com os 3 perfis de DATA §3.1 em `.tres`, `PerceptionMemory`, `EnemyBrain` com a tabela de transições e as fórmulas de DATA §3.3. Determinístico pelo RNG injetado.
- **Testes:** cada transição da tabela; cascata no mesmo tick; conferência AI-03 em L1 (CHASE em 0,8 s); AI-06 em L1 (percepts iguais → intent idêntico); AI-08 em L1 (inspeção como percept); ARC-01 e ARC-03.

### F4-004 · EnemyController + EnemyWorldQuery + navegação + THE OBSERVER
- **Responsável:** AI Engineer · **Esforço:** EXTRA HIGH · **Depende de:** F4-001..003, F4-008 · **Status:** REVIEW. `EnemyController` (tick −40), `EnemyWorldQuery` (`is_reachable` com cache por célula), `EnemyDoorLinkGate` (link de porta trancada desligado), portas pelo `link_reached` com recuo se o painel bate, passos do inimigo audíveis, Observer greybox. AI-01 na sandbox real; AI-02..06 em mundo de teste com navmesh própria; AI-08 com esconderijo falso. Ponto para a revisão: prontidão do mapa de navegação (AI-02 falhava 3 em 6 antes da correção; 11/11 depois)
- **Descrição:** `EnemyController` (§8.1, prioridade −40): coleta os percepts, chama o brain e aplica o intent com `NavigationAgent3D`; `EnemyWorldQuery` sem dado do jogador; portas pela D4-03; falas pelo `NoiseEmitter` filho. Cena do Observer (greybox) com o perfil OBSERVER, colocada na sandbox jogável pelo Director.
- **Testes:** AI-01 (rota em ordem), AI-02, AI-03, AI-04, AI-05 (cenários), AI-06 no controlador (invariância com o jogador em posições diferentes fora de percepção), porta destrancada aberta na rota e trancada evitada.

### F4-005 · Captura básica
- **Responsável:** AI Engineer + Gameplay · **Esforço:** MEDIUM · **Depende de:** F4-004 · **Status:** REVIEW. `EnemyCaptureArea` (−30; só sobreposição na camada 3 e CHASE; AI-07) e `CaptureScreen` (escurece, "Capturado", trava a entrada, reinicia uma vez). Limitação provisória: o mundo não pausa durante a captura
- **Descrição:** `EnemyCaptureArea` (Area3D, prioridade −30) emite `player_caught` só com sobreposição **e** estado CHASE; o controlador repassa `EventBus.player_captured`; tela "capturado" e reinício (D4-04).
- **Testes:** AI-07 (a captura não entra no `PerceptBatch`); captura só em CHASE.

### F4-006 · PlayerThreatMonitor + AdaptiveMusic básica + falas
- **F4-006a (Audio Engineer, onda A, HIGH, REVIEW: 4 falas × 3 variações e 3 camadas de música procedurais, `AdaptiveMusic` com crossfade de potência constante, barramento `music`; legendas das falas no formato "[Falante] texto", regra do teste ajustada pelo Director):** música adaptativa básica (camadas procedurais calma, tensão e perseguição, com crossfade guiado por `ThreatSample`) e biblioteca de falas provisórias do Observer (VOICE: murmúrio, "quem está aí?", grito de perseguição) com legendas.
- **F4-006b (Physiological Eng., onda B, HIGH):** `PlayerThreatMonitor` (D4-01): ameaça percebida pelo jogador, por visão (inimigo na tela com linha de visão, distância) e por audição (`PlayerHeardNoise`; `in_chase` pelo grito de perseguição), em janelas de 3 s (DATA §5 e §6.1). Alimenta o estresse e a música.
- **Testes:** PHY-12 (visível a 3 m → +10 de estresse em 1 s; só audível ≥ 30 dB → sobe; fora de percepção → não sobe); TMN-INV-1 (ARC-01).

### F4-007 · Medição de desempenho
- **Responsável:** Director + QA · **Esforço:** MEDIUM · **Depende de:** F4-004 · **Status:** BACKLOG
- **Descrição:** primeira medição contra SYSTEM_ARCHITECTURE §13 na sandbox (1 Observer real e um teste de carga com 3 inimigos): sensores + cérebro + navegação, propagação de um `NoiseEvent`, fisiologia, LightExposureProbe (GAME-010). Ao menos 3 execuções (RSK-14). Registro em `Docs/QA/PERFORMANCE.md`.

### F4-008 · Sandbox para a IA
- **Responsável:** Level Designer · **Esforço:** MEDIUM · **Depende de:** F3-007 · **Status:** REVIEW. Navmesh assada em headless (`tools/level/bake_navmesh.gd` → `sandbox_navmesh.tres`, célula 0,05 m, agente 0,35 × 1,8 m, degrau 0,3 m), vãos de porta fechados na malha e atravessados por `NavLink_<door_id>`, rota do Observer com 8 pontos em 5 salas (3 portas fechadas no caminho, nunca a trancada), surgimento no quintal, corredor escurecido. Mapa do projeto alinhado à célula de 0,05 m pelo Director
- **Descrição:** `NavigationRegion3D` com navmesh da sandbox (gerada pelo `gen_sandbox.py`), rota de patrulha do Observer (marcadores ordenados), ponto de surgimento do inimigo, e a navegação coerente com as portas (D4-03).
- **Testes:** pontos da rota alcançáveis pela navmesh; caminho entre as salas pelas portas; nenhuma rota pela porta trancada.

### F4-009 · Integração do jogador
- **Responsável:** Gameplay Engineer · **Esforço:** MEDIUM · **Depende de:** F4-001, F4-006b · **Status:** BACKLOG
- **Descrição:** `LightExposureProbe` e `PerceivableTarget` no `player.tscn` (fator de postura pelo motor), `PlayerThreatMonitor` no lugar do `StubThreatSource` (D4-01) e da ponte de susto.

### F4-010 · Revisão técnica — Technical Reviewer · HIGH · BACKLOG
### F4-011 · Validação de QA (com playtest curto) — QA Engineer · EXTRA HIGH · BACKLOG
### F4-012 · Documentação — Director · LOW · BACKLOG
ENEMY_AI.md.

---

## 5. Backlog das Fases 5–6 (resumo; cards completos ao abrir cada fase — DIR-02)

| ID | Tarefa | Responsável | Esforço | Depende de |
|---|---|---|---|---|
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

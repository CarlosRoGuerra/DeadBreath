# Roadmap Técnico — DEAD BREATH

| Campo | Valor |
|---|---|
| Atualizado | 2026-11-20 |
| Fase atual | **FASE 3 — Furtividade e áudio** (Gate F2 aprovado em 2026-11-20) |
| Responsável | Project Director |

Cada fase termina num **gate**. A fase seguinte só começa com o gate aprovado: critérios cumpridos, testes executados com evidência, revisão técnica concluída, documentação atualizada e aprovação do usuário.

Tamanhos relativos: P, M, G, GG. Não há datas, porque o ritmo depende das sessões de trabalho.

**Decisões do Director registradas aqui**
- **DIR-01 (calendário de documentos):** os documentos de Gameplay e Design da seção 16 do MASTER são criados na fase em que o sistema correspondente é implementado. Criar documentos vazios antes violaria a regra "a documentação deve refletir o estado real do código".
- **DIR-02 (cards do backlog):** os cards das Fases 2+ são detalhados (critérios, testes, evidências), no formato da seção 14 do MASTER, **ao abrir a fase**. Até lá ficam como resumo no TASK_BOARD §5.

---

## Visão geral

```mermaid
graph LR
  F0[F0 Discovery] --> F1[F1 Foundation]
  F1 --> F2[F2 Fisiologia]
  F1 --> F3[F3 Furtividade e Áudio]
  F2 --> F3
  F3 --> F4[F4 IA Inimiga]
  F4 --> F5[F5 Vertical Slice]
  F5 --> F6[F6 Expansão]
  F6 --> F7[F7 Polimento]
  F7 --> F8[F8 Release]
```

O `AcousticGraph` (L1 puro, F3-001) pode avançar em paralelo com a F2. A respiração (F2) e o `BreathEmitter`/`AcousticWorld` (F3) exigem coordenação.

---

## FASE 0 — Discovery e seleção de engine · EXTRA HIGH · P

| Entregável | Status |
|---|---|
| Inventário do ambiente | Feito, com evidência em Docs/QA/EVIDENCE/DISC-001_environment.txt |
| Matriz UE5 / Unity / Godot / engine própria + sensibilidade + avaliação por objetivo | Feito (ENGINE_DECISION §3–5.1) |
| Arquitetura, contratos e estruturas de dados | Feito, v0.2 após revisão |
| Roadmap, backlog, agentes e plano de testes | Feito |
| Revisão técnica independente (DISC-006) | Feita em 3 rodadas: REPROVADO → REPROVADO → **APROVADO COM RESSALVAS** (0 CRÍTICO/ALTO em aberto). Critério 3 do gate cumprido. |
| Spike de verificação da engine (DISC-003, V1–V6) | **Passou** em V1–V6 (ENGINE_DECISION §7.1). Física: GodotPhysics3D |

**Gate F0: APROVADO (2026-11-20).**
1. Usuário aprova D-01 a D-04 (TASK_BOARD §1). ✔
2. Spike DISC-003 passa em V1–V6. ✔
3. A nova verificação da revisão técnica não encontra achado CRÍTICO ou ALTO em aberto. ✔

## FASE 1 — Foundation · EXTRA HIGH · M

Protótipo controlável em primeira pessoa numa sandbox greybox.

- Repositório git e projeto Godot (`game/`): input map, camadas de física, warnings de tipagem como erro.
- Núcleo L0: Log, EventBus, Settings (incluindo opções de acessibilidade), SaveService (I/O atômico), GameState, Enums.
- Runner de testes headless + `tools/run_tests.ps1` (importação, parse e testes).
- PlayerRoot + PlayerMotor: andar, andar devagar, correr, agachar, rastejar, câmera e passos por superfície.
- Interação: `Interactable`, porta e pickup.
- Remapeamento de controles (UI mínima) e opções de câmera.
- Overlay de debug (F3).
- Sandbox greybox.

**Gate F1:** cards F1 em APPROVED; MOT-01..04, ACC-05, ACC-06 e ARC-01..06 verdes; screenshot da sandbox; PLAYER_CONTROLLER.md escrito.

**Gate F1: APROVADO pelo usuário em 2026-11-20** (critérios abaixo cumpridos, com as ressalvas registradas).
1. Cards F1 em APPROVED: ✔ (F1-D02 NARRATIVE fica em REVIEW: aguarda as respostas N-01..N-05 do usuário; não bloqueia).
2. MOT-01..04, ACC-05, ACC-06 verdes: ✔. ARC-03..06 verdes com alvo real. **ARC-01 passa por vacuidade** (pastas de IA ainda vazias; alvo real na F4). **ARC-02 parcial** (unicidade dos pickups da sandbox; versão completa na F5). Ver TEST_RESULTS, "Cobertura pendente de fase".
3. Screenshots da sandbox inspecionados: ✔ (`EVIDENCE/F1-009_*`, `F1-011_captura_*`).
4. PLAYER_CONTROLLER.md v1.0: ✔.
5. Revisão técnica F1-010 APROVADA COM RESSALVAS e validação QA F1-011 APROVADA COM RESSALVAS; pipeline 2× com código 0 (`EVIDENCE/F1-GATE_pipeline_run1.txt`, `_run2.txt`).

## FASE 2 — Fisiologia · EXTRA HIGH · G

- StaminaModel, StressModel, RespiratoryModel e PhysiologyCoupling (L1).
- PhysiologyComponent integrado via PlayerRoot.
- Bombinha (efeito, cooldown, ruído), com inventário mínimo de cargas.
- Áudio respiratório (respiração, chiado, aviso de tosse, tosse) como consumidor dos eventos do BreathEmitter. Antes da F3, o BreathEmitter usa um AcousticWorld mínimo (só o ouvinte do jogador).
- **Animações (MASTER §12, Fase 2):** animações procedurais em primeira pessoa: balanço respiratório da câmera, sobressalto da tosse e uso da bombinha com *viewmodel* provisório (mão e bombinha).
- Efeitos de câmera, indicador visual de condição respiratória e intensidade de efeitos (acessibilidade).
- Ferramenta de balanceamento: sliders no overlay + simulação headless com export de curvas.

**Gate F2:** PHY-01..PHY-11 verdes (com `ThreatSample` injetado ou `StubThreatSource`; as fontes reais de ameaça só existem na F4), ACC-01..03 verdes; cenário "correr até a crise e se recuperar" gravado; RESPIRATORY, STRESS e STAMINA_SYSTEM.md escritos.

**Gate F2: APROVADO pelo usuário em 2026-11-20** (critérios abaixo cumpridos, com as ressalvas registradas).
1. PHY-01..PHY-11 verdes (com `StubThreatSource`): ✔ (propriedades com 200 sequências).
2. ACC-01..03 verdes: ✔.
3. Cenário "correr até a crise e se recuperar" gravado: ✔ (`EVIDENCE/F2-011_cenario_*`: 6 capturas, telemetria CSV, log de sons).
4. RESPIRATORY, STRESS e STAMINA_SYSTEM.md: ✔ (v1.0).
5. Revisão F2-010 e validação F2-011 APROVADAS COM RESSALVAS; pipeline verde. Ressalvas: ponte de susto na F3-002; precisão do save (ARCH-001) antes da F5; timbre dos sons depende da escuta do usuário.

## FASE 3 — Furtividade e áudio · EXTRA HIGH · G

- AcousticGraph, AcousticWorld, NoiseEmitter, RoomVolume e Portal; piso de ruído de chuva e trovão.
- NoiseAudioRouter (atenuação nativa desligada, volume pelo grafo, reverb por sala).
- Ruídos do jogador e do mundo; objetos de distração arremessáveis.
- Legendas de sons relevantes (`subtitle_requested`).
- Exposição à luz do jogador (para a F4).
- Debug: anéis de ruído e grafo.

**Gate F3:** NOI-01..05, STL-01..03, STL-07 e ACC-04 verdes; STEALTH_SYSTEM.md e AUDIO_DESIGN.md escritos.

## FASE 4 — IA inimiga · EXTRA HIGH · G

- PerceivableTarget, VisionSensor e HearingSensor.
- EnemyBrain (FSM de 7 estados), PerceptionMemory, EnemyController e navegação.
- PlayerThreatMonitor (estresse por ameaça percebida) e AdaptiveMusic básica.
- THE OBSERVER funcional na sandbox. Primeira medição de desempenho (orçamentos de SYSTEM_ARCHITECTURE §13).

**Gate F4:** AI-01..08, PHY-12 e ARC-01 verdes; medição de desempenho registrada; playtest curto na sandbox; ENEMY_AI.md escrito.

## FASE 5 — Vertical slice · EXTRA HIGH · GG

- Primeiro ambiente (térreo parcial da casa): greybox aprovado e depois arte básica.
- 3 esconderijos, 1 inimigo, recursos, 2 objetivos, 2 rotas alternativas.
- Inventário **básico** (itens do slice) e objetivos.
- Checkpoints com a sequência de captura completa.
- Sequência de fuga completa. Demo de 15 a 25 minutos.

**Gate F5:** PER-01..10, INV-01..03, OBJ-01..03, STL-04..06 verdes; playtest com o usuário (EXP-01..06); LEVEL_DESIGN, INVENTORY_SYSTEM e CHECKPOINT_SYSTEM.md escritos.

## FASE 6 — Expansão · HIGH · GG

- Casa completa: 2 pavimentos, sótão, porão, garagem e quintal.
- THE AGGRESSIVE e THE LEADER; SquadCoordinator.
- Inventário completo; puzzles; dificuldade adaptativa.
- Contrato `EnvironmentState` congelado; mudanças ambientais (MASTER §10.1).
- Progressão por capítulo: cada um introduz uma situação nova, não só mais inimigos (MASTER §5.2). Proposta inicial, a detalhar no GDD:

| Capítulo | Mecânica ou situação nova |
|---|---|
| 1 — THE INTRUSION | Introdução: esconder-se, ruído e primeiro contato com um criminoso (Observer) |
| 2 — NO WAY OUT | Saídas bloqueadas pelos invasores (`blocked_doors`); procurar chaves e ferramentas; segundo inimigo |
| 3 — THE BASEMENT | Corte de energia (`lights_off`): escuridão e reverberação forte (o som "carrega" mais); o Leader começa a coordenar buscas |
| 4 — LAST BREATH | Remédios escassos e pico de pressão fisiológica; buscas coordenadas por setores com os três inimigos |
| 5 — OUTSIDE | Exterior com chuva (piso de ruído alto) e trovões como janelas de movimento; regras acústicas abertas; fuga final |

## FASE 7 — Polimento · EXTRA HIGH · GG

Otimização, balanceamento, IA, animações, áudio final, iluminação, UI, acessibilidade completa e definição da especificação mínima. Localização: proposta P-04.

## FASE 8 — Preparação de release · EXTRA HIGH · M

Export templates da versão exata, build de produção, testes de instalação, save, desempenho e compatibilidade, documentação e preparação para distribuição. Plataforma de distribuição: proposta P-05.

---

## Calendário de documentação (DIR-01)

| Documento | Fase |
|---|---|
| ENGINE_DECISION, SYSTEM_ARCHITECTURE, COMPONENT_CONTRACTS, DATA_STRUCTURES | F0 (draft) → congelados por sistema |
| ROADMAP, TASK_BOARD, AGENT_ASSIGNMENTS, CHANGELOG, KNOWN_ISSUES, TEST_PLAN | F0, mantidos sempre |
| GAME_DESIGN_DOCUMENT, NARRATIVE, ART_DIRECTION | F1 (em paralelo) |
| PLAYER_CONTROLLER | F1 |
| RESPIRATORY, STRESS, STAMINA_SYSTEM | F2 |
| STEALTH_SYSTEM, AUDIO_DESIGN | F3 |
| ENEMY_AI | F4 |
| LEVEL_DESIGN, INVENTORY_SYSTEM, CHECKPOINT_SYSTEM | F5 |
| TEST_RESULTS, BUG_REPORTS, ACCEPTANCE_REPORT | a partir da primeira execução de testes (DISC-003) |

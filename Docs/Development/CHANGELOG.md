# Changelog — DEAD BREATH

Formato baseado em [Keep a Changelog](https://keepachangelog.com/pt-BR/1.1.0/).

## [Não lançado]

### Fase 2 — Fisiologia (2026-11-20; Gate F2 aguardando aprovação do usuário)

#### Adicionado
- Estamina, estresse e asma como modelos separados (L1 puros, determinísticos, com `to_dict`/`from_dict`), acoplamento (sprint e firmeza das mãos) e PhysiologyComponent no jogador.
- Crise respiratória com estados, histerese e tosse sempre avisada 1,5 s antes; bombinha (Q, 3 doses, cooldown, pickup soma doses) que alivia a crise sem devolver estamina.
- Sons do corpo por síntese procedural (41 WAV determinísticos) e produtor único: BreathEmitter → AcousticWorld mínimo → BreathingAudio "dentro da cabeça".
- Efeitos de câmera (balanço, tremor, solavanco da tosse, vinheta) com redução de movimento e tremor e intensidade ajustável; indicador respiratório opcional; viewmodel provisório.
- Painel de balanceamento (F4) e simulação headless com curvas de referência.
- RESPIRATORY_SYSTEM, STRESS_SYSTEM e STAMINA_SYSTEM.md.

#### Corrigido
- F4 consumida em produção (BUG-012). Documentação de fórmulas e contratos alinhada ao código (revisão F2-010).

#### Decisões
- D-07: síntese procedural. ThreatSource RefCounted. Testes lentos em `property`. Comprimido e água para a F5. Precisão de float no save (ARCH-001) decidida antes da F5.


### Fase 1 — Foundation (2026-11-20; Gate F1 aprovado pelo usuário)

#### Adicionado
- Projeto Godot em `game/`: Forward+, GodotPhysics3D a 60 Hz, warnings de tipagem como erro, input map (12 ações), 8 camadas de física.
- Núcleo L0: Log, EventBus, Settings (11 opções de jogo e acessibilidade, com validação), SaveService com escrita atômica, GameState, Enums, AtomicFile, InputBindings.
- Jogador: PlayerRoot (mediador), PlayerMotor (andar, devagar, correr, agachar, rastejar, step-up até 0,30 m com colisor cilíndrico, câmera com compensação de degrau, head bob, passos por superfície, aterrissagem).
- Interação por raio da câmera (tocar e segurar), porta (lenta/normal/trancada, para sem empurrar) e pickup.
- Overlay de debug (F3, noclip, teleporte; desligado em produção), menu de pausa e remapeamento de controles.
- Sandbox greybox jogável (4 salas, corredor, escada, mezanino, mesa para rastejar, 4 pisos com materiais CC0) como cena principal.
- Framework de testes headless próprio (runner, níveis padrão/property/meta, captura de erros de script, isolamento de física) e `tools/run_tests.ps1`.
- Documentos: GDD v0.1, NARRATIVE v0.1, ART_DIRECTION v0.1, PLAYER_CONTROLLER v1.0, BUG_REPORTS, ASSET_LICENSES.

#### Corrigido (achados de revisão e QA)
- BUG-001/002: perda de chão e queda ao subir/descer escadas, em qualquer fase do passo (testes de propriedade a 5 mm).
- BUG-003: câmera afundando em rampas. BUG-004: travar no canto de pilar. BUG-005: "segurar" atravessando a pausa. BUG-006/009/010: porta empurrando o jogador, regressão no batente e sinal duplicado.
- Settings aceitava NaN; remapeamento podia deixar ação sem tecla; overlay sem jogador na cena real; porta "aberta" nascia fechada.

#### Decisões
- Física GodotPhysics3D (spike V6); colisor cilíndrico; nível de teste `property`; runner com `--fixed-fps 60`; porta só para diante de corpos móveis.


### Fase 0 — Discovery (2026-11-20)

#### Adicionado
- `Docs/MASTER_PROMPT.md`: cópia literal dos requisitos, fonte de verdade para todos os agentes.
- Inventário do ambiente com evidência gravada (`Docs/QA/EVIDENCE/DISC-001_environment.txt`).
- `ENGINE_DECISION.md` (ADR-001, **proposta**): Godot 4.7.2 + GDScript tipado; matriz ponderada, sensibilidade e avaliação por objetivo da Fase 0.
- `SYSTEM_ARCHITECTURE.md`, `COMPONENT_CONTRACTS.md` e `DATA_STRUCTURES.md` (v0.2, draft), com ADRs 002–010 em formato curto (**propostas**).
- `ROADMAP.md`, `TASK_BOARD.md`, `AGENT_ASSIGNMENTS.md`, `KNOWN_ISSUES.md` e `TEST_PLAN.md` (v0.2).
- Revisão técnica independente em 3 rodadas (`Docs/QA/REVIEWS/DISC-006.md`, `DISC-006_VERIFICATION.md`), com resultado final APROVADO COM RESSALVAS, e rastreio das correções (`DISC-006_RESOLUTION.md`).

#### Alterado (após a revisão DISC-006, v0.1 → v0.2)
- `HeardNoise` não carrega mais dados reais da fonte (achado crítico R-01).
- O autoload "NoiseBus" foi substituído pelo componente de nível `AcousticWorld` (L2). L0 sem dependências ascendentes.
- `PlayerRoot` passa a mediar todos os componentes do jogador (sem acoplamento entre motor e fisiologia).
- `PerceivableTarget` virou componente-filho (GDScript não tem interfaces).
- Respiração com produtor único (`BreathEmitter` → `NoiseEvent` → áudio e IA).
- Parâmetros de IA numéricos; teste AI-06 por invariância; fórmulas completas de fisiologia e acoplamento; piso de ruído de chuva; estado do RNG no snapshot.
- O spike da engine virou critério do Gate F0. Novas tarefas de acessibilidade, remapeamento, legendas, SaveService e licenças de assets.

#### Gate F0 (2026-11-20)
- Usuário aprovou D-01 a D-04. Projeto copiado para `D:\Dev\DeadBreath` (repositório git com remoto no GitHub; commits só locais).
- Godot 4.7.2 oficial instalado em `D:\DevTools\Godot\4.7.2\` (SHA-512 conferido).
- Spike DISC-003 executado: V1–V6 passaram (`spikes/disc003/`, `Docs/QA/TEST_RESULTS.md`). Física escolhida: GodotPhysics3D. ADR-001 → **APROVADA**.
- Nenhum código de jogo na Fase 0 (regra de gate).

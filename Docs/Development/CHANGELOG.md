# Changelog — DEAD BREATH

Formato baseado em [Keep a Changelog](https://keepachangelog.com/pt-BR/1.1.0/).

## [Não lançado]

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

#### Não realizado
- Spike de verificação da engine (DISC-003): bloqueado pela política de permissões para download e execução de binários.
- Nenhum código de jogo foi escrito (regra de gate da Fase 0).

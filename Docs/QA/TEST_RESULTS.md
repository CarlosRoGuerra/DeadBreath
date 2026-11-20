# Resultados de Testes — DEAD BREATH

| Campo | Valor |
|---|---|
| Atualizado | 2026-11-20 |
| Regra | Só entram resultados com saída real registrada (arquivo em `Docs/QA/EVIDENCE/` ou bloco copiado da execução) |

---

## DISC-003 — Spike de verificação da engine (Gate F0)

| Campo | Valor |
|---|---|
| Data | 2026-11-20 |
| Executor | Project Director (sessão principal) |
| Engine | `4.7.2.stable.official.ed1daf0bf`, binário oficial do GitHub; SHA-512 do zip igual ao de `SHA512-SUMS.txt` do release |
| Máquina | i7-14700KF, RX 9070 XT, 32 GB, Windows 11 Pro 26300 |
| Projeto | `spikes/disc003/` (descartável; não é o jogo) |
| Reexecução | `bash spikes/disc003/run_spike.sh D:/DevTools/Godot/4.7.2/Godot_v4.7.2-stable_win64_console.exe` (executado 1 vez com sucesso; gera os logs abaixo) |
| Verificação independente | Pendente: o QA reexecuta na F1-011 |

| # | Critério (ENGINE_DECISION §7) | Resultado | Evidência |
|---|---|---|---|
| V1 | Versão começa com `4.7.2.stable` | **PASSOU**: `4.7.2.stable.official.ed1daf0bf` | `EVIDENCE/DISC-003/V1_V2_V4.log` |
| V2 | Script headless retorna 0/1 | **PASSOU**: `pass` → 0; `fail` → 1 | `V1_V2_V4.log` |
| V3 | Forward+ com névoa volumétrica e luz pontual renderiza com janela | **PASSOU**: Vulkan 1.4.359, Forward+, RX 9070 XT, 1920×1080; luminância média 0,207; 98,8% das amostras acima de 0,05; imagem inspecionada | `V3_default.log`, `V3_screenshot.png` |
| V4 | `--check-only` após `--import` falha com erro proposital | **PASSOU**: `parse_error.gd` → 1; `untyped.gd` → 1 (warning tratado como erro); `unsafe.gd` → 1; `ok.gd` → 0 | `V1_V2_V4.log` |
| V5 | p95 ≤ 6,9 ms (vsync off, 1080p, 600 frames após 120) | **PASSOU**. Execução 1: Vulkan 1,921 ms, D3D12 0,902 ms. Execução 2 (logs gravados): Vulkan 1,206 ms, D3D12 0,962 ms | `V5_vulkan.log`, `V5_d3d12.log`, `V5_frametimes_*.csv` |
| V6 | CharacterBody3D em escada, rampa e vão de 0,6 m com Jolt e GodotPhysics3D | **PASSOU**: 16/16 pistas nos dois motores; resultados idênticos em execução repetida | `V6_JoltPhysics.*`, `V6_GodotPhysics3D.*` |

### V6 — comparação dos motores (execução final)

Controlador mínimo do spike (`spikes/disc003/mover.gd`), 60 Hz, `floor_snap_length` 0,3 m, `floor_max_angle` 45°, step-up de até 0,30 m. "Sem chão" = ticks em movimento com `is_on_floor() == false`.

| Pista | Jolt | GodotPhysics3D |
|---|---|---|
| Cápsula · rampa 30° (sobe até 1,5 m) | passou, tick 258 | passou, tick 258 |
| Cápsula · parado na rampa por 2 s | deslocamento 0,0000 m | 0,0000 m |
| Cápsula · sobe escada (8 × 0,18 m) | passou; 8 step-ups; sem chão 40/220 | passou; 8 step-ups; sem chão 40/220 |
| Cápsula · escada sem step-up | bloqueia em x = 1,760 (informativo) | idem |
| Cápsula · desce escada | passou; sem chão **59/215** | passou; sem chão **60/215** |
| Cápsula 0,55 m · vão de 0,6 m rastejando | passou; teto bloqueado 168/168 sob a laje, 0/230 fora | idem |
| Cápsula 1,75 m · vão de 0,6 m em pé | bloqueia em x = 2,747 | idem |
| Cápsula · obstáculo 0,35 m (acima do step) | bloqueia | bloqueia |
| Cápsula · obstáculo 0,29 m (abaixo do step) | sobe (1 step-up) | sobe (1 step-up) |
| Cilindro · rampa 30° | passou; **1 step-up espúrio** na base | passou; 0 step-up |
| Cilindro · sobe escada | passou; sem chão 2/218 | passou; sem chão **0/216** |
| Cilindro · desce escada | passou; sem chão **60/215** | passou; sem chão **0/216** |
| Cilindro · obstáculos e vão | iguais à cápsula | iguais à cápsula |
| Tempo de parede (721 ticks, 16 corpos), 2 execuções; o log gravado é o da 2ª | 381,6 e 370,5 ms | 387,2 e 405,9 ms |

**Execução 1 (descartada para a escolha):** o step-up do controlador do spike não disparava (sondagem de 1 tick = 2,7 cm; a base arredondada da cápsula batia na quina). Essa execução mostrou que `DEFAULT` = GodotPhysics3D no 4.7.2 (números idênticos). Logs preservados em `V6_run1_*`.

**Decisão:** GodotPhysics3D (ENGINE_DECISION §6). Achados para o PlayerMotor em ENGINE_DECISION §7.1.

---

## F1-004 / F1-005 — Núcleo L0 e framework de testes

| Campo | Valor |
|---|---|
| Data | 2026-11-20 |
| Commit | `b3598d8` |
| Comando | `powershell -NoProfile -ExecutionPolicy Bypass -File tools/run_tests.ps1` |
| Execuções | QA Engineer (evidência completa em `EVIDENCE/F1-005_run_tests.txt`) e, de forma independente, o Project Director |

| Etapa | Resultado (execução do Director) |
|---|---|
| Importação headless | código 0, sem `SCRIPT ERROR` |
| ARC-04 (compilação de todos os scripts no processo, com autoloads) | 1/1 |
| Runner (unit, integration, scenarios, architecture) | **35/35**, código 0, 287 ms internos |
| Runner meta (passa, falha, erro de parse, warning como erro, raiz vazia, filtro, contexto, detectores) | **15/15**, código 0 |

- Testes do L0 (29): Log 4, Settings 7 (inclui **ACC-06**), GameState 2, AtomicFile 6, EventBus 4 (catálogo e tipos por reflexão), SaveService 6 (inclui **PER-09 versão L0**).
- Arquitetura: ARC-03, ARC-04 e ARC-05 com alvo real. ARC-01 passou por vacuidade (pastas-alvo vazias), o que é dito na própria saída. ARC-06 já varre `components/player/` (arquivos da F1-006 em andamento).
- As linhas `[ERROR]` e o `ConfigFile parse error` na saída vêm de testes que provocam erros de propósito.
- Prova de sensibilidade feita pelo QA (`EVIDENCE/F1-005_mutation_check.txt`): violações injetadas em cópia fizeram ARC-01, 03, 04, 05 e 06 reprovarem (pipeline código 1).
- **Complemento do framework (mesmo dia):** o runner registra um `Logger` (Godot 4.5+, verificado no 4.7.2 em `EVIDENCE/F1-005_logger_verification.txt`) e reprova o teste em que ocorre um erro de script não declarado. Erros de engine esperados são declarados com `expect_engine_error()`. O runner passou a rodar com `--fixed-fps 60` (suíte com os testes do jogador: 28 s → 1,2 s, resultados idênticos). Execução do Director: meta **17/17**, arquitetura **6/6**, testes do L0 **24/24** (filtro `autoload`) + AtomicFile, todos com código 0.

---

## F1-006 — PlayerRoot e PlayerMotor

| Campo | Valor |
|---|---|
| Data | 2026-11-20 |
| Comando | `tools/run_tests.ps1` (pipeline) e `godot --headless --fixed-fps 60 --path game -s res://tests/run_all.gd -- --filter=player` |
| Execuções | Gameplay Engineer (3× a suíte do jogador + pipeline; `EVIDENCE/F1-006_tests.txt`, `F1-006_estabilidade.txt`) e Project Director (pipeline + 2× a suíte do jogador) |

| Etapa | Resultado (execução do Director) |
|---|---|
| Pipeline completo | código 0: runner **62/62**, meta **17/17**, ARC-04 verde |
| Suíte do jogador, 2 repetições | **26/26** nas duas (423 e 441 ms) |

- Cobertura: MOT-01 (não levanta sob laje de 0,6 m; agachado não entra), MOT-02 (esforço por marcha e postura), MOT-03 (limites só reduzem), MOT-04 (bot por input roteirizado: vão rastejando, escada de 8 degraus, parede intransponível, descida), step-up até 0,30 m e bloqueio a 0,31 e 0,35 m, `landed`, `footstep` por metadado `surface`, mouse look, head bob com redução total, FOV das opções, config ausente → padrões + `Log.error`. ARC-06 com alvo real: 2 componentes em `components/player/`.
- Bug achado e corrigido durante a tarefa: degrau de exatamente 0,30 m travava o step-up (topo encostava na sondagem). Folga de 2 mm.
- Mutações (`EVIDENCE/F1-006_mutacoes.txt`): 7 alterações do código (sem checagem de teto, sem step-up, superfície fixa etc.), cada uma reprovou ao menos um teste.
- Sem verificação visual ainda: depende da sandbox (F1-009).

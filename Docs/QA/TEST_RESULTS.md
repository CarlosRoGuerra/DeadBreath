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

---

## F1-007 / F1-008 / F1-013 / BUG-001 / F1-009 — Interação, debug, remapeamento, escada e sandbox

| Campo | Valor |
|---|---|
| Data | 2026-11-20 |
| Comando | `tools/run_tests.ps1` |
| Execução do Director (após a integração da sandbox) | importação OK; ARC-04 OK; runner **123/123**; meta **17/17**; código 0 |

| Área | Testes | Observação |
|---|---|---|
| Interação (F1-007) | 20 | Foco e oclusão, toque/segurar, porta lenta/normal/trancada, pickup; 3× estáveis (Gameplay) |
| Debug (F1-008) | 6 | Inclui a flag de produção |
| Input (F1-013) | 17 | **ACC-05**: remapear → reiniciar → persiste; conflito avisado; regressão das ações `ui_*` |
| Escada (BUG-001) | 5 | 0 ticks sem chão; varredura de 12 fases; a mutação com a folga de 5 mm reprova |
| Sandbox MOT-04 (F1-009) | 8 | Rasteja sob a mesa, não levanta sob ela, sobe ao mezanino com 0 ticks no ar, não atravessa paredes, vãos |
| LevelSlots (integração) | 5 | 4 portas nos estados dos slots, porta aberta nasce aberta, portas fechadas bloqueiam o vão, persist_id único (ARC-02 parcial), cena com jogador/pausa/overlay. Mutação "painel sempre fechado" → 2 testes reprovam |

- Evidências visuais inspecionadas: `EVIDENCE/F1-009_sandbox_pov_sala.png`, `F1-009_sandbox_pov_escada.png`, `F1-009_playable_portas.png` (porta aberta para a cozinha e porta fechada para o corredor, renderizadas na cena jogável).
- Achado visual (ART_DIRECTION §3): a sandbox está mais clara do que o alvo (87–90% das amostras acima de 0,05 contra 40–70%). Ajuste previsto para a F5.

---

## Cobertura pendente de fase (registrada na revisão F1-010, R1-16)

| Teste | Situação na F1 |
|---|---|
| ARC-01 (firewall de percepção) | Passa por **vacuidade**: as pastas de IA e percepção ainda não existem. Ganha alvo real na F4 |
| ARC-02 (`persist_id` único) | Parcial: `test_level_slots.gd` confere unicidade dos pickups da sandbox. A versão completa (grupo `saveable` de cada nível) depende do Saveable (F5) |
| ARC-07 (config ausente) | Parcial: config ausente do motor → padrões + `Log.error`. O comportamento de falha imediata em debug ainda não existe |
| ACC-01 | Coberto na F2 (balanço, tremor e solavanco zeram com redução total) |
| ACC-02, ACC-03 | Cobertos na F2 (escala linear de `effects_intensity`; indicador desligado por padrão e atualizado no frame seguinte) |
| ACC-04 | Sem cobertura: legendas são da F3 |
| PER-07 | **Só em memória** na F2: o ida e volta por JSON altera floats (ARCH-001). A versão com arquivo depende da decisão de formato antes da F5 |

---

## Gate F1 — execução consolidada

| Campo | Valor |
|---|---|
| Data | 2026-11-20 |
| Comando | `powershell -NoProfile -ExecutionPolicy Bypass -File tools/run_tests.ps1` (2 execuções seguidas, Director) |
| Evidência | `EVIDENCE/F1-GATE_pipeline_run1.txt`, `F1-GATE_pipeline_run2.txt` |
| Resultado | **APROVADO nas duas** (código 0; ~99 s de parede) |

| Etapa | Execução 1 | Execução 2 |
|---|---|---|
| Importação | OK | OK |
| ARC-04 (compilação de todos os scripts) | 1/1 | 1/1 |
| Suíte padrão (unit, integration, scenarios, architecture) | **146/146**, 8,7 s | **146/146**, 8,7 s |
| Propriedade (varreduras de escada e exploits do QA) | **63/63**, 75 s | **63/63**, 75 s |
| Meta (framework) | **26/26** | **26/26** |

Validações independentes da fase:
- **Revisão técnica F1-010** (`REVIEWS/F1-010.md`, `F1-010_VERIFICATION.md`): REPROVADA (2 ALTO) → correções → APROVADA COM RESSALVAS.
- **Validação QA F1-011** (`F1-011_VALIDATION.md`): 3 rodadas; 33 tentativas de exploit; BUG-001..007 e 009/010 fechados por quem não corrigiu (BUG-010 pelo teste de reprodução do QA); BUG-008 e BUG-011 aceitos.

---

## Fase 2 — ondas A e B e revisão técnica (2026-11-20)

| Execução | Resultado |
|---|---|
| Director, após a integração da onda B (commit `63dca84`; `EVIDENCE/F2-waveB_integracao_pipeline.txt`) | padrão **285/285** (7,5 s), property **84/84**, meta **26/26**, código 0 |
| Revisor técnico F2-010, commit `083d308` (APPDATA isolado) | padrão 285/285, property 84/84, meta 26/26, código 0 |

- **Fisiologia:** PHY-01..PHY-11 verdes (PHY-06/07/09 com 200 sequências na property). Calibração recalculada pelo revisor: sprint 8,333 s; LABORED 5,550 s; PHY-03 6,67 s; bombinha −0,440 em 3 s; estresse 100 → 0 em 37,333 s. PHY-INV-5: 1 043 tosses com aviso ≥ 1,5 s, 0 violações.
- **PER-07:** continuação de 240 s após restaurar, sem divergência (em memória).
- **Sons do corpo:** 41 WAV determinísticos (42/42 idênticos em regeneração). Produtor único verificado: `NoiseEvent` só é criado no BreathEmitter e `AudioStreamPlayer` só no BreathingAudio.
- **Integração:** cadeia completa na cena jogável (`test_playable_body_chain.gd`, 4/4). A mutação sem o step do emissor reprova.
- **Acessibilidade:** ACC-01..ACC-03 verdes.
- **Revisão técnica F2-010:** APROVADO COM RESSALVAS (`REVIEWS/F2-010.md`).

---

## F2-011 — validação independente da Fase 2 (QA)

| Campo | Valor |
|---|---|
| Relatório | `Docs/QA/F2-011_VALIDATION.md` |
| Pipeline (QA, 2×) | padrão **293/293**, property **99/99**, meta **26/26**, código 0 (`EVIDENCE/F2-011_suite_1.txt`, `_2.txt`) |
| Veredito | **APROVADO COM RESSALVAS** |

- PHY-01..11 refeitos pelo QA com configs de produção: PHY-01 8,333 s; PHY-03 6,667 s; PHY-04 −0,531 em 3 s; PHY-06 severidade final máx. 0,0003; PHY-07 530 tosses, aviso mínimo 1,5 s; PHY-11 diferença 0,0000.
- Cenário gravado com janela: SYMPTOMATIC em 9,0 s, exaustão em 9,83 s, aviso de tosse em 13,88 s, tosse em 15,38 s, bombinha em 16,40 s, NORMAL em 22,12 s.
- Exploits sem quebra: spam de Q, pausa no meio da crise (fisiologia e áudio param; tosse agendada dispara 1,5 s após retomar; inspirações e expirações pareadas), acessibilidade alterada na crise, estresse máximo por 10 min, salvar e restaurar no aviso (em memória).
- Bugs: BUG-012 (F4 em produção) corrigido e fechado pelo probe do QA; BUG-015 aceito; BUG-013 (sobreposição do chiado a 40 rpm) aguarda a escuta; BUG-014 (ponte de susto) vai para a F3-002.

---

## F3-011 — validação independente da Fase 3 (QA)

| Campo | Valor |
|---|---|
| Relatório | `Docs/QA/F3-011_VALIDATION.md` |
| Data e commit | 2026-11-21, base `c32de8a` |
| Pipeline (QA, 2×) | padrão **472/472** (9,8 s e 8,5 s), propriedade **156/156**, meta **26/26**, código 0 (`EVIDENCE/F3-011_suite_1.txt`, `_2.txt`). Testes `f3011`: 38/38 nas duas execuções (4 no padrão, 34 na propriedade) |
| Comando | `powershell -NoProfile -ExecutionPolicy Bypass -File tools/run_tests.ps1` |
| Regeneração do áudio | `python -I tools/audio/check_regen.py --set world` e `--set body`: PASS bit a bit (`EVIDENCE/F3-011_regen_world.txt`, `_body.txt`) |
| Filtro usado nos testes novos | `godot --headless --fixed-fps 60 --path game -s res://tests/run_all.gd -- --level=property --filter=f3011` (e sem `--level`, para o padrão) |
| Veredito | **APROVADO COM RESSALVAS**. BUG-014 fechado; BUG-016 aberto (BAIXO) |

- **Cenário gravado** na `sandbox_playable.tscn` (roteiro "atravessar a casa em silêncio", `EVIDENCE/F3-011_cenario_log.txt`, 126 eventos, 0 desvios): porta fechada 15,00 dB no ouvido; corrida 47,4 dB contra caminhada 35,5 dB; impacto do próprio arremesso a 72,4 dB sem susto; trovão eleva o limiar de 38 para 58 no quintal; camada de chuva muda de `rain_interior` para `rain_exterior` ao entrar no quintal; outra fonte a 75 dB sobe o estresse em 16,7.
- **Achado de coerência (decisão do Director, DATA §2.4):** a porta batida (75 dB) tem corte perceptivo de 15 dB, mas o volume tocado cai só 3,75 dB (compressão acima de 45 dB). Fixado no teste `test_porta_batida_tem_corte_audivel_comprimido`.
- **Achado de cobertura de nível:** o mezanino da sandbox não tem queda alcançável por entradas (guardas, paredes e degraus de 1,2 m). Queda de altura de 1,5 m gera FALL (4,90 m/s).
- **Defeito novo:** BUG-016 (BAIXO): objeto segurado atravessa parede quando o jogador encosta nela (`test_objeto_na_mao_ao_encostar_na_parede`, registrado por nota).
- **Testes que falham de propósito:** nenhum.
- **Revisão do pipeline:** o `--import` regravou `game/default_bus_layout.tres` (só formato, sem mudança de comportamento); não revertido, para o Director decidir.


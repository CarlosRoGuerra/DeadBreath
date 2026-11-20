# Relatórios de Bugs — DEAD BREATH

| Campo | Valor |
|---|---|
| Atualizado | 2026-11-20 |
| Severidades | CRÍTICO (bloqueia o jogo ou corrompe dados) · ALTO (quebra mecânica central ou gera informação falsa para a IA) · MÉDIO · BAIXO |
| Estados | ABERTO · EM CORREÇÃO · CORRIGIDO (aguarda verificação) · FECHADO (verificado por quem não corrigiu) |

## Abertos

### BUG-001: o step-up deixa o jogador sem chão por 1–2 ticks em escadas reais
| Campo | Valor |
|---|---|
| Severidade | **ALTO**: cada tick sem chão pode gerar `landed` e quebrar a cadência de passos. Na F3, isso vira ruído falso para a IA (pilar "inimigos justos") |
| Estado | **REABERTO** em 2026-11-20 pela revisão F1-010 (R1-01): a correção cobre só as 12 fases testadas. No ciclo completo do passo, a escada da sandbox ainda perde o chão por 2–3 ticks em 6 de 72 fases, e a escada sintética de piso 0,30 m por 1 tick em 4 de 60. Em correção (Gameplay Engineer) |
| Encontrado por | `scenarios/test_mot04_sandbox.gd` (Level Designer, F1-009); diagnóstico do Gameplay Engineer em 2026-11-20 |
| Componente | `game/components/player/player_motor.gd` (step-up, F1-006) |
| Reprodução | Escada da sandbox (espelho 0,18 m, piso ~0,28 m), bot subindo e descendo com `--fixed-fps 60`: 2 ticks seguidos com `is_on_floor() == false` |
| Causa raiz (medida tick a tick) | A folga `STEP_LIFT_EPSILON_M` (5 mm, herdada do spike) elevava o corpo acima do topo do degrau. Com só a borda frontal sobre o degrau novo, o corpo ficava suspenso por 1 tick e caía 4 mm no seguinte. O efeito depende do alinhamento do passo com a borda; no spike, a fase não o reproduziu. A hipótese inicial (sondagem de 0,27 m) foi testada e descartada |
| Correção | Elevação exata até o topo do degrau (`player_motor.gd`). Novo `tests/integration/player/test_escada_sem_chao.gd`: 0 ticks sem chão subindo e descendo escadas 0,18/0,28 e 0,18/0,30, a escada da sandbox e uma varredura de 12 fases iniciais. Com a folga reintroduzida, a varredura reprova (`EVIDENCE/F1-006_bug001_mutante.txt`) |
| Critério de correção | 0 ticks sem chão subindo e descendo a escada da sandbox e a escada de 8 × 0,18/0,28 m; testes de step-up (0,10/0,25/0,30 m sobem; 0,31/0,35 m bloqueiam) continuam verdes |
| Observação | O teste da sandbox chegou a ser afrouxado para aceitar 2 ticks. O Level Designer restaurou a asserção de 0 ticks. Execução do Director: suíte completa 118/118 em 3 repetições |

### BUG-002: queda de degrau ao descer escada de piso 0,28 m
| Campo | Valor |
|---|---|
| Severidade | **ALTO**: 16 ticks (~0,27 s) sem chão, queda de ~0,33 m com vy até −2,45 m/s; gera `landed` falso |
| Estado | ABERTO, em correção (Gameplay Engineer) |
| Encontrado por | Revisão F1-010 (R1-02), varredura do ciclo completo na descida (3 de 56 fases; ex.: `start_z=0.395`) |
| Componente | `player_motor.gd` (step-up e snap ao descer) |
| Critério de correção | Teste de propriedade sobre o ciclo inteiro do passo (passo de 5 mm), subida e descida, escadas 0,18/0,28, 0,18/0,30 e a da sandbox: 0 ticks sem chão |

### BUG-003: câmera afunda em rampa
| Campo | Valor |
|---|---|
| Severidade | MÉDIO: a compensação visual do step-up é aplicada a toda variação vertical; em rampa de 30° correndo, a câmera fica até 18,7 cm abaixo da altura dos olhos |
| Estado | ABERTO, em correção (Gameplay Engineer) |
| Encontrado por | Revisão F1-010 (R1-03) |
| Critério de correção | Teste de câmera em rampa (10°, 20°, 30°; andando e correndo; subindo e descendo): erro ≤ 1 cm |

## Fechados

Nenhum.

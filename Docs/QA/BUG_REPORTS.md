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
| Estado | **CORRIGIDO** em 2026-11-20 (aguarda verificação independente do QA na F1-011) |
| Encontrado por | `scenarios/test_mot04_sandbox.gd` (Level Designer, F1-009); diagnóstico do Gameplay Engineer em 2026-11-20 |
| Componente | `game/components/player/player_motor.gd` (step-up, F1-006) |
| Reprodução | Escada da sandbox (espelho 0,18 m, piso ~0,28 m), bot subindo e descendo com `--fixed-fps 60`: 2 ticks seguidos com `is_on_floor() == false` |
| Causa raiz (medida tick a tick) | A folga `STEP_LIFT_EPSILON_M` (5 mm, herdada do spike) elevava o corpo acima do topo do degrau. Com só a borda frontal sobre o degrau novo, o corpo ficava suspenso por 1 tick e caía 4 mm no seguinte. O efeito depende do alinhamento do passo com a borda; no spike, a fase não o reproduziu. A hipótese inicial (sondagem de 0,27 m) foi testada e descartada |
| Correção | Elevação exata até o topo do degrau (`player_motor.gd`). Novo `tests/integration/player/test_escada_sem_chao.gd`: 0 ticks sem chão subindo e descendo escadas 0,18/0,28 e 0,18/0,30, a escada da sandbox e uma varredura de 12 fases iniciais. Com a folga reintroduzida, a varredura reprova (`EVIDENCE/F1-006_bug001_mutante.txt`) |
| Critério de correção | 0 ticks sem chão subindo e descendo a escada da sandbox e a escada de 8 × 0,18/0,28 m; testes de step-up (0,10/0,25/0,30 m sobem; 0,31/0,35 m bloqueiam) continuam verdes |
| Observação | O teste da sandbox chegou a ser afrouxado para aceitar 2 ticks. O Level Designer restaurou a asserção de 0 ticks. Execução do Director: suíte completa 118/118 em 3 repetições |

## Fechados

Nenhum.

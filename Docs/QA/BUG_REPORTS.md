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
| Estado | EM CORREÇÃO (Gameplay Engineer) |
| Encontrado por | `scenarios/test_mot04_sandbox.gd` (Level Designer, F1-009); diagnóstico do Gameplay Engineer em 2026-11-20 |
| Componente | `game/components/player/player_motor.gd` (step-up, F1-006) |
| Reprodução | Escada da sandbox (espelho 0,18 m, piso ~0,28 m), bot subindo e descendo com `--fixed-fps 60`: 2 ticks seguidos com `is_on_floor() == false` |
| Causa provável | A sondagem horizontal de 0,27 m alcança o 2º degrau enquanto o pé ainda está no 1º; o corpo é elevado demais e cai. No spike V6, o controlador mínimo com cilindro teve **0** ticks sem chão na mesma geometria (`spikes/disc003/mover.gd`) |
| Critério de correção | 0 ticks sem chão subindo e descendo a escada da sandbox e a escada de 8 × 0,18/0,28 m; testes de step-up (0,10/0,25/0,30 m sobem; 0,31/0,35 m bloqueiam) continuam verdes |
| Observação | O teste da sandbox foi afrouxado para aceitar 2 ticks (`MAX_AIR_RUN = 2`) antes de o Director pedir o contrário. O limite volta a 0 com a correção |

## Fechados

Nenhum.

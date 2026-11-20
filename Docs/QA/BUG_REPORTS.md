# Relatórios de Bugs — DEAD BREATH

| Campo | Valor |
|---|---|
| Atualizado | 2026-11-20 (F1-011, terceira rodada: correção da porta pelo Gameplay Engineer, verificada pelo QA) |
| Severidades | CRÍTICO (bloqueia o jogo ou corrompe dados) · ALTO (quebra mecânica central ou gera informação falsa para a IA) · MÉDIO · BAIXO |
| Estados | ABERTO · EM CORREÇÃO · CORRIGIDO (aguarda verificação) · FECHADO (verificado por quem não corrigiu) · ACEITO (decisão do Director, com reavaliação marcada) · REABERTO (verificação falhou) |

## Abertos

### BUG-010: a porta oscila ao sair do arco: libera e bloqueia de novo no tick seguinte, emitindo blocked duas vezes
| Campo | Valor |
|---|---|
| Severidade | BAIXO. O corpo não se desloca nem penetra. Afeta o sinal `blocked` (gancho de batida da F3) e a aparência do giro no instante da liberação. Vira MÉDIO se o `blocked` for usado para ruído ou para a IA antes da correção |
| Estado | **FECHADO** em 2026-11-20. Correção do Director: histerese na liberação (bloqueada, a porta só volta a andar quando dois incrementos seguidos estão livres). Verificação independente da correção: o teste de reprodução escrito pelo QA antes da correção (`test_porta_sala_corredor_corpo_entra_no_arco_no_meio_da_abertura`) passa com a correção e reprova sem ela (`blocked` 2×); pipeline completo 2× com código 0 |
| Componente | `game/components/world/door.gd` (`_physics_process`: sem histerese entre liberar e bloquear; a folga de 2 cm libera o avanço de um passo e o passo seguinte volta a encostar no corpo ainda próximo) |
| Reprodução | Cena jogável, `door_sala_corredor`. Corpo começa em (7,3; 0; −0,7), olhando para −X. Segurar E por 25 ticks andando para −X (corpo entra no arco), soltar, esperar o bloqueio. Depois, andar para +X: no tick 228 `is_blocked()` vira `false` (corpo em 6,959, porta em 48,8°), no tick 229 volta a `true` (corpo em 6,970, porta em 48,8°), no tick 230 `false` de novo (49,7°). `blocked(Player)` emitido 2 vezes |
| Critério de correção | Na saída do arco, `is_blocked()` vai a `false` uma única vez e a porta completa; `blocked` emitido uma vez por contato. Sugestão do QA: histerese (liberar só com folga maior que o passo do tick) |
| Teste que reproduz | `game/tests/property/qa/test_f1011_portas_quatro.gd::test_porta_sala_corredor_corpo_entra_no_arco_no_meio_da_abertura` (asserção `blocks.size() == 1`) |
| Evidência | `Docs/QA/EVIDENCE/F1-011_diag_blocked_duplo.txt` (tick a tick); `F1-011_suite_final_3.txt` e `_4.txt` |

### BUG-011: o eixo do painel entra no volume do batente (intrusão de até ~2,5 cm na dobradiça; oculta; sem brecha)
| Campo | Valor |
|---|---|
| Severidade | BAIXO (level design). Consequência da regra 1 aceita pelo Director: geometria estática não bloqueia o giro, e o arco livre é responsabilidade do level design. Não é brecha de passagem, não tem efeito de colisão e não aparece nas capturas |
| Estado | **ACEITO** pelo Director: consequência da regra "geometria estática não bloqueia o giro". A intrusão fica oculta no volume da parede e não abre brecha (verificado pelo QA). Regra de level design: o arco da porta precisa estar livre |
| Medição | Encolhimento da caixa do painel que libera a sobreposição com o batente estático (bisseção, aproximação de profundidade): 0° → 0 mm; 10° → 4,5 mm; 20° → 8,0 mm; 27° → 10,1 mm; 35° → 12,4 mm; 45° → 15,0 mm; 60° → 19,0 mm; 75° → 23,7 mm; 90° → ≥ 25 mm (no limite da busca). **Não é "milímetros": são centímetros, dentro do volume da parede**, na quina do eixo |
| Brecha | Não existe: nenhum corpo atravessa o trecho de parede estática (z = −1,32, sala → corredor) com o painel em 0°, 15°, 27°, 45°, 60° e 90° (teste `test_brecha_no_encontro_do_painel_com_o_batente_nao_existe`). A sobreposição fica dentro de parede sólida, então não abre espaço livre |
| Visual | Verificado com janela (`F1-011_captura_dobradica_90_nivel_olhos.png` e `F1-011_captura_dobradica_90_chao.png`, porta aberta a 90°, vista da sala): sem fresta, sem z-fighting e sem quina visível. A sobreposição é oculta pelo volume da parede |
| Critério de correção (LD) | Eixo da dobradiça alinhado à face do batente, ou recorte do batente no vão. Recomendado revisar os dois vãos de passagem (`door_sala_corredor`, `door_corredor_hall`). Confirmar a medição depois da mudança |
| Evidência | `Docs/QA/EVIDENCE/F1-011_v5_portas_quatro.txt` (medição por ângulo e teste de brecha); capturas acima |

### BUG-008: clique do mouse durante a captura de remapeamento grava a ligação
| Campo | Valor |
|---|---|
| Severidade | BAIXO (UX). A captura aceita qualquer clique do mouse como nova ligação, inclusive sobre "Voltar". A ação antiga é substituída (o jogador pode perder a tecla sem perceber). Esc cancela |
| Estado | **ACEITO** pelo Director: aceitar clique do mouse como nova ligação é o comportamento esperado da captura, e Esc cancela. Reavaliar no polimento de UI (F7): botão de cancelar fora da captura e confirmação ao substituir ligação |
| Componente | `game/presentation/ui/controls_menu.gd` (`_input` consome todo clique durante `is_capturing()`) |
| Reprodução | Menu de controles, "Remapear" em crouch, clique esquerdo: `capture_event` devolve `applied` e crouch passa a usar o botão 1 |
| Teste de observação | `game/tests/integration/qa/test_f1011_remap.gd::test_remap_clique_durante_captura_vira_ligacao_observacao` (passa; documenta o comportamento) |

## Fechados

### BUG-006: painel da porta empurra o corpo ao abrir devagar
| Campo | Valor |
|---|---|
| Severidade (original) | MÉDIO, reaberto na segunda rodada (o segurar ainda empurrava o corpo 7,6 cm) |
| Estado | **FECHADO** em 2026-11-20 pelo QA (terceira rodada, F1-011). Correção do Gameplay Engineer: o painel só para por corpos móveis (camadas 2, 3 e 4) e avança só com folga de 2 cm do corpo; bloqueio contínuo emite `blocked` uma vez; liberação observada por `is_blocked() == false` (regras do Director) |
| Verificação do QA (experimentos próprios, as quatro portas da sandbox jogável) | Corpo no arco, toque e segurar, corredor-hall e sala-corredor: **deslocamento do corpo 0,0000 m, penetração 0, `blocked` uma vez, para no arco (12,9° a 17,1° no toque; 15,9° no segurar)**. Corpo que entra no arco no meio da abertura lenta: para em 47,8°, deslocamento 0,0000 m, depois de sair completa 90°. Os testes de (a) e (b1) de `test_exploit_porta_com_corpo_no_arco_*` passam; (b2) passa (90°) |
| Evidência | `Docs/QA/EVIDENCE/F1-011_v4_portas.txt` (4 de 4); `F1-011_v5_portas_quatro.txt`; `F1-011_suite_final_3.txt` e `_4.txt` |

### BUG-009: porta de passagem não abre por inteiro sem corpo no arco
| Campo | Valor |
|---|---|
| Severidade (original) | ALTO: regressão introduzida pela checagem de bloqueio (correção do BUG-006): a porta de passagem parava em 27° sem nenhum corpo no arco |
| Estado | **FECHADO** em 2026-11-20 pelo QA (terceira rodada). Causa: o batente estático era tratado como obstáculo do giro. Correção (regra 1 do Director): a porta só para por corpos móveis |
| Verificação do QA | Sem corpo no arco, as portas de passagem abrem por inteiro: **sala-corredor toque 90°, segurar 90°; corredor-hall toque 90°, segurar 90°**; sem `blocked` e sem bloqueio no fim. Teste de integração do Gameplay (`integration/interaction/test_portas_sandbox.gd`, 17 asserções) passa. Porta de cozinha aberta: não bloqueia (estado OPEN, zero `blocked`). Porta trancada: `locked_feedback` uma vez, nada se move. Consequência da regra 1 (geometria estática no arco não bloqueia o giro): experimento com caixa estática no arco mostra a porta completar 90° atravessando a caixa. Aceito pelo Director como responsabilidade do level design (ver BUG-011) |
| Evidência | `Docs/QA/EVIDENCE/F1-011_v4_portas.txt`; `F1-011_v5_portas_quatro.txt`; `F1-011_suite_final_3.txt` e `_4.txt` |

### BUG-004: canto de pilar prende o colisor enquanto a tecla de saída diagonal está apertada
| Campo | Valor |
|---|---|
| Severidade (original) | MÉDIO: parado 5 s com a tecla pressionada; sai ao soltar a tecla ou apertar outra direção |
| Estado | **FECHADO** em 2026-11-20 pelo QA (verificação F1-011, segunda rodada). **Contorno verificado; a causa raiz não foi identificada** (contato dentro da margem de segurança do piso, segundo o Gameplay Engineer). Dívida técnica: identificar a causa antes da F2, porque o contorno pode esconder outro problema de física |
| Componente | `game/components/player/player_motor.gd`: levanta 1 cm e refaz o movimento horizontal quando o tick trava no chão com comando de andar; zera a velocidade até o deslocamento realizado; faixa morta de 2 mm na compensação visual |
| Verificação do QA | (1) Reprodução: após 240 ticks no canto NE do hall (rastejando) e reversão diagonal, o corpo anda **2,491 m em 300 ticks** (antes: parado). (2) Teste de cantos com limite relativo (80% de velocidade × tempo): sala SO, sala NO, hall SE, cozinha NE e cozinha SE afastam 2,293 m (mínimo 1,920); hall NE sob o mezanino, rastejando, afasta 0,724 m (mínimo 0,600). (3) Efeitos colaterais, 11 empurrões contra a parede norte (em pé andando, em pé correndo, agachado e rastejando, em 0°, 30° e 60°): **sem penetração, sem ar, sem landed; altura do corpo varia no máximo 1 mm depois de assentar; erro da câmera 0,0000 m; footsteps sempre dentro do limite coerente com o deslocamento realizado**. Empurrões oblíquos deslizam ao longo da parede (até 1,5 m em correr a 30°), o que é movimento legítimo. (4) Escada com parede lateral: seis degraus, a altura final é sempre uma altura de degrau, sem penetração, sem ar, sem landed. (5) Porta parcial com o corpo parado encostado: sem penetração e sem deslocamento |
| Evidência | `Docs/QA/EVIDENCE/F1-011_suite_final_1.txt` e `_2.txt` (notas "efeitos do contorno" e "reversão"); `F1-011_v3_verificacao.txt`; `F1-011_diag_reversao.txt`, `F1-011_diag_diagonal_240.txt` (reprodução original) |

### BUG-005: segurar E durante o menu de pausa deixa a interação "segurada" depois de continuar
| Campo | Valor |
|---|---|
| Severidade (original) | MÉDIO na F1 (ALTO antes da F3: o ruído da porta lenta sairia sem a tecla) |
| Estado | **FECHADO** em 2026-11-20 pelo QA (verificação F1-011, segunda rodada) |
| Componente | `game/components/interaction/interaction_component.gd`: `PROCESS_MODE_ALWAYS`, pausa cancela o segurar com `interaction_failed`, aperto durante a pausa é ignorado |
| Verificação do QA | Segurar E, abrir o menu, soltar E com o menu aberto, continuar, esperar 90 ticks: `interaction_failed` emitido 1 vez, porta continua CLOSED, nenhuma abertura, nada segurando. Aperto de E durante a pausa é ignorado (porta continua fechada). Depois da pausa, um toque abre a porta rápido (`opened(slow = false)`). Controle sem pausa: abertura rápida. 6 de 6 testes de interação passam |
| Evidência | `Docs/QA/EVIDENCE/F1-011_v2_interacao.txt` (6 de 6); `F1-011_suite_final_1.txt` e `_2.txt` (runner: 145 de 145) |

### BUG-007: comentários da planta da sandbox divergem do cálculo (documentação)
| Campo | Valor |
|---|---|
| Severidade (original) | BAIXO: não afeta o jogo. Confunde quem mudar a planta |
| Estado | **FECHADO** em 2026-11-20 pelo QA. Correção do Director conferida |
| Verificação do QA | `tools/level/gen_sandbox.py` regenerado pelo QA num arquivo do scratchpad (sem gravar no repositório): o conteúdo é **idêntico** ao de `game/content/levels/sandbox.tscn` (ignorando fim de linha). Os comentários de `MEZZ_TOP` (1,08 m) e `MEZZ_Z1` (−2,68) batem com os cálculos |

### BUG-001: o step-up deixa o jogador sem chão por 1–2 ticks em escadas reais
| Campo | Valor |
|---|---|
| Severidade (original) | ALTO: cada tick sem chão pode gerar `landed` e quebrar a cadência de passos. Na F3, isso vira ruído falso para a IA (pilar "inimigos justos") |
| Estado | **FECHADO** em 2026-11-20 pelo QA (F1-011). Reconfirmado na segunda rodada, com o motor alterado (contorno do BUG-004 e faixa morta de câmera): 15 de 15 testes de escada passam |
| Verificação do QA | Subida, 20 fases de 1 cm: andando devagar (0,9 m/s), agachado, correndo (4,8 m/s), rastejando (10 fases de 2 cm). Subida e descida: **0 ticks sem chão, 0 landed espúrio, 0 penetração** em todas. Diagonal de 14°; entrada deslocada em x dentro da abertura; troca de postura no meio; paradas de 60 ticks em três degraus (queda 0 mm). Entrada pela borda da escada: a guarda do mezanino bloqueia (sem queda) e o corpo sobe depois de recentrar |
| Evidência | `Docs/QA/EVIDENCE/F1-011_exp_bug001_002_run2.txt`; `F1-011_suite_final_1.txt` e `_2.txt` |

### BUG-002: queda de degrau ao descer escada de piso 0,28 m
| Campo | Valor |
|---|---|
| Severidade (original) | ALTO: 16 ticks (~0,27 s) sem chão, queda de ~0,33 m com vy até −2,45 m/s; gera `landed` falso |
| Estado | **FECHADO** em 2026-11-20 pelo QA (F1-011). Reconfirmado na segunda rodada |
| Verificação do QA | Descida a partir do mezanino: 20 fases de 1 cm andando devagar; 20 agachado; 10 rastejando (2 cm). **0 ticks sem chão, 0 landed, 0 penetração.** Parada de 60 ticks em três degraus da descida (queda 0 mm após assentar). Saída lateral do degrau de 0,18 m (sem queda nem landed) |
| Evidência | `Docs/QA/EVIDENCE/F1-011_exp_bug001_002_run2.txt`; `F1-011_suite_final_1.txt` e `_2.txt` |

### BUG-003: câmera afunda em rampa
| Campo | Valor |
|---|---|
| Severidade (original) | MÉDIO: em rampa de 30° correndo, a câmera ficava até 18,7 cm abaixo da altura dos olhos |
| Estado | **FECHADO** em 2026-11-20 pelo QA (F1-011). Reconfirmado na segunda rodada (8 de 8) |
| Verificação do QA (critério: erro ≤ 1 cm em regime, contra a altura de olhos da postura atual) | Andando devagar a 10°, 20°, 30° (subida e descida): erro máximo 5,9 mm. Agachado a 30°: 7,1 mm (subida). Rastejando a 20°: 1,8 mm. Diagonal a 20°: 0,2 mm. Parada a 30° depois de assentar: 0 mm e deslize 0 mm. Inversão no meio da rampa: 1,3 mm. Troca de postura no meio: 0 mm. Saída para plano no topo: 0 mm. **Pior caso: 7,1 mm (agachado, subindo a 30°), margem de 2,9 mm.** Nota: o desvio de 5 a 7 mm com postura baixa é ruído da compensação, abaixo do limite; acompanhar na câmera de efeitos (F2) |
| Evidência | `Docs/QA/EVIDENCE/F1-011_exp_bug003_run2.txt`; `F1-011_suite_final_1.txt` e `_2.txt` |

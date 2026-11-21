# Validação independente da Fase 3 — F3-011

| Campo | Valor |
|---|---|
| Data | 2026-11-21 |
| Responsável | QA Engineer (contexto novo; não implementou nada da F3) |
| Base | commit `c32de8a` (`main`), árvore limpa no início. Só foram criados arquivos QA (`game/tests/*/qa/`, `game/tests/integration/qa/fixtures/f3011_roteiro.gd`, `game/tests/integration/qa/probes/f3011_cenario*.gd`, `Docs/QA/`). Nenhum arquivo de produção, cena ou teste de outro autor foi alterado. Sem git (ver seção 12) |
| Ambiente | Windows 11, Godot 4.7.2.stable (`D:\DevTools\Godot\4.7.2`), `--headless --fixed-fps 60`. Áudio não ouvido: a evidência de som vem de logs e cálculo |
| Isolamento | `APPDATA` isolado nas execuções do cenário (`$TEMP\f3011_appdata`). Pipeline oficial com o perfil padrão (os testes usam `Settings.autosave = false`) |

## 1. Veredito

**APROVADO COM RESSALVAS.** Critério do F2-011 (e F3-010): REPROVADO se houver CRÍTICO ou ALTO em aberto; APROVADO COM RESSALVAS se houver só MÉDIO ou menor.

- **Nenhum defeito ALTO ou CRÍTICO.** Defeito novo: **BUG-016** (BAIXO): o objeto segurado atravessa a parede quando o jogador encosta nela.
- **Pipeline oficial aprovado nas duas execuções** (`tools/run_tests.ps1`, código 0, sem `SCRIPT ERROR`): padrão 472/472, propriedade 156/156, meta 26/26 (`EVIDENCE/F3-011_suite_1.txt` e `_2.txt`). Os 38 testes com prefixo `f3011` passaram nas duas.
- **BUG-014 (ponte de susto) verificado e fechado.** O caminho de produção funciona: outra fonte a 75 dB sobe o estresse em 16,7 (faixa 10 a 25).
- **Ressalvas que impedem um APROVADO limpo:**
  1. NOI-01 não tem alvo real até a F4 (o `HearingSensor` não existe; busca vazia em `game/`). Hoje só a parte estática é verificável, e ela passa.
  2. ACC-04: as falas (`VOICE`) não têm emissor na F3 (R3-11). Tosse, porta e passos próximos estão cobertos; falas, não.
  3. BUG-016 (BAIXO).
  4. Escuta do usuário pendente (timbre, volume, limitador, trovão): ver seção 10.
  5. O padrão está em 8,5 s a 9,8 s, perto do limite de 10 s (ver seção 2).

## 2. Pipeline completo (2 execuções)

| Etapa | Execução 1 | Execução 2 | Observação |
|---|---|---|---|
| importacao | OK (código 0, 3101 ms) | OK (código 0, 3024 ms) | |
| arc04 (parse/compilação, ARC-04) | OK (2493 ms) | OK (2538 ms) | |
| runner (unit, integration, scenarios, architecture) | **472/472** em 9833 ms (etapa 10125 ms) | **472/472** em 8527 ms (etapa 9027 ms) | alvo < 10 s; ERROR do engine 9 nas duas (são os negativos declarados `expect_engine_error` do F3-010) |
| runner-property | **156/156** em 159,8 s | **156/156** em 109,9 s | ERROR do engine 1 nas duas: `15 resources still in use at exit` (R3-13, já conhecido) |
| runner-meta | **26/26** | **26/26** | |
| Tempo total | 193,84 s | 139,05 s | a variação de tempo vem da carga da máquina |
| Veredito | **APROVADO** | **APROVADO** | |

**Orçamento da suíte padrão.** A suíte padrão ficou em 9,8 s na execução 1 e em 8,5 s na execução 2. O F3-010 mediu 7,7 s em 451 testes. O crescimento não foi investigado a fundo; a folga para os 10 s é de 0,2 a 1,5 s. Os testes deste QA no nível padrão são 4, com 28 ms somados (remapeamento e legendas).

**Testes deste QA por nível.**
- Padrão: `integration/qa/test_f3011_remap_legendas.gd`, 4 testes, 28 ms somados (orçamento de 0,5 s: cumprido).
- Propriedade: 34 testes em `property/qa/` (`test_f3011_cenario_silencio.gd` 15, `test_f3011_portas_arremessaveis.gd` 11, `test_f3011_queda_som_clima.gd` 8), cerca de 7 s somados, cena inteira.

## 3. Matriz de aceitação do Gate F3 (ROADMAP)

"Reexecutado" significa que o teste rodou nas duas execuções do pipeline deste QA (independente de quem escreveu) e, quando indicado, no filtro desta validação.

| Critério | Teste que cobre | Reexecutado | Resultado | Observação |
|---|---|---|---|---|
| NOI-01 (único caminho para a IA) | varredura `test_noi_inv_1_only_listed_scripts_emit_or_create_body_noise` (F3-010, endurecida em R3-02) | sim (pipeline 2×) | **atende com ressalva** | Alvo real só na F4: `HearingSensor` não existe (`grep` em `game/` vazio). Hoje passa a varredura estática e o teste de trava do `NoiseEmitter` |
| NOI-02 (propagação pura; fechar porta não aumenta) | `test_noi02_propagacao_pura.gd` e property `test_noi02_porta_nunca_aumenta.gd` | sim (pipeline 2×) | **atende** | No cenário: porta fechada reduz 15,00 dB no ouvido, nunca aumenta |
| NOI-03 (HeardNoise/PlayerHeardNoise sem dados da fonte) | `test_noi03_campos_ouvido.gd` (reflexão) | sim (pipeline 2×) | **atende** | |
| NOI-04 (paridade áudio × IA ≤ 0,5 dB) | teste de integração F3 + `test_volume_tocado_segue_a_regra_de_ganho` (F3-011, 101 asserções) | sim (pipeline 2×) | **atende** | 103 sons tocados no cenário; ganho igual a `NoiseGain.gain_for_db(perceived)` em todos (teto de +6 dB atingido pelo impacto de 72,4 dB) |
| NOI-05 (produtor único da respiração) | `test_noi05_respiracao_produtor_unico.gd` + `test_respiracao_tem_produtor_unico_no_roteiro` (F3-011) | sim (pipeline 2×) | **atende** | Cenário: 17 eventos de respiração, 18 inspirações tocadas (diferença de 1 é o último ciclo ainda tocando). Nenhum som do corpo passa pelo roteador |
| STL-01 (intensidades diferentes) | `test_stl01_intensidades.gd` + F3-004 | sim (pipeline 2×) | **atende** | No cenário, só correr × andar foi medido (47,4 dB contra 35,5 dB percebidos). Rastejar e agachado não foram medidos no cenário |
| STL-02 (paredes ≥ 20 dB) | `test_stl02_03_parede_porta.gd` | sim (pipeline 2×) | **atende** | |
| STL-03 (porta fechada ≥ 14,5 dB) | `test_stl02_03_parede_porta.gd` + `test_porta_fechada_corta_15_db_no_ouvido` (F3-011) | sim (pipeline 2×) | **atende** | 15,00 dB medidos no cenário com o caminho pelo portal do hall |
| STL-07 (7 alcances de referência, ±0,2 m) | `test_stl07_alcances.gd` | sim (pipeline 2×) | **atende** | Conferido pelo F3-010 por bisseção analítica |
| ACC-04 (legendas: sons relevantes, tamanho configurável) | `test_legendas_ui.gd` + `test_legendas_*` (F3-011) + `test_legendas_de_porta_aparecem` | sim (pipeline 2×) | **atende com ressalva** | Tosse, porta e passos próximos: verdes. Falas: **sem emissor** (`VOICE` só existe no enum; R3-11), então o critério "falas" não é atendido na F3 |

## 4. Cards F3-001 a F3-008

| Card | Resultado | Evidência e ressalvas |
|---|---|---|
| F3-001 AcousticGraph (L1) | **atende** | STL-01/02/03/07, NOI-02/03 no pipeline 2×; cenário: portal aberto 3 dB, fechado 18 dB (15 dB de corte) |
| F3-002 AcousticWorld, RoomVolume, Portal, chuva, trovão, ponte de susto | **atende com ressalva** | Trovão eleva o limiar de 38 para 58 no quintal; camada de chuva muda (interior, janela, exterior); ponte de susto (BUG-014, fechado). Ressalva: falas sem produtor (R3-11) |
| F3-003a Biblioteca de sons do mundo | **atende com ressalva** | `check_regen.py --set world` PASS bit a bit (`EVIDENCE/F3-011_regen_world.txt`). Ressalva: a audição é do usuário |
| F3-003b NoiseAudioRouter e ambiência | **atende com ressalva** | NOI-04 verde; ganho segue `NoiseGain` no roteiro; teto de +6 dB atingido pelo impacto a 72 dB. Ressalva: a atenuação de porta batida é comprimida (seção 6.1) e o limitador do Master (R3-03, aceito GAME-009) depende da escuta |
| F3-004 Ruídos do jogador, objetos, porta que fecha | **atende com ressalva** | Porta fecha em 15 dB; passos e corrida sem susto próprio; arremesso sem susto próprio (perceived 72,4 dB, salto 0,00); queda ≥ 2,5 m/s gera FALL. Ressalva: BUG-016 (objeto na mão atravessa parede, BAIXO); a queda do mezanino não é alcançável por entradas (seção 7) |
| F3-005 LightExposureProbe e física | **atende** | Testes do probe e do spike no pipeline 2×. Não reexaminado além da suíte, por escopo |
| F3-006 Legendas (ACC-04) | **atende com ressalva** | Ver ACC-04 acima. Inundação de 500 pedidos mantém 3 linhas; tamanho e desligar valem ao vivo |
| F3-007 Sandbox acústica | **atende** | 6 salas com piso correto (28, 22, 22, 22, 22, 38); 6 portais; trovão ligado no nível; grafo consistente nos testes do cenário |
| F3-008 Visão de debug acústica | **atende com ressalva** | F5 liga a visão em desenvolvimento; 300 eventos em 23 ms criam 32 anéis (limite), 6 salas, anéis expiram (teste F3-011). Ressalva: "não liga em produção" é coberto pelo teste in-process do F3-008 (`GameState.is_production_build = true`), não por processo separado com `--production` |

## 5. Cenário gravado: "atravessar a casa em silêncio" (sandbox_playable.tscn)

Roteiro executado pelo jogador com entradas simuladas (MotorInput, tecla E, ação `throw` pelo viewport). Duração de simulação: 55,7 s. Desvios do roteiro: 0 (final).

**Ordem:** silêncio na sala; porta sala → corredor (toque); porta corredor → hall **segurada** (abertura lenta) e fechada atrás do jogador (segurada); corrida de 3 m no hall; volta à cozinha pela porta do hall; pote pego na cozinha e arremessado contra a parede norte da cozinha; volta ao hall e porta hall → quintal (toque); espera de 120 ticks no quintal; trovão forçado; susto de outra fonte (controle).

**Arquivos:** `EVIDENCE/F3-011_cenario_log.txt` (126 eventos, legenda das colunas, marcas, pedidos de legenda, desvios) e `EVIDENCE/F3-011_cenario_telemetria.csv` (222 linhas: estresse, severidade, estado respiratório, camada de chuva, piso, limiar, offset do trovão e portas a cada 15 ticks).

**Log resumido (126 eventos):**

| Categoria | Eventos | Tocados pelo roteador | Observação |
|---|---|---|---|
| FOOTSTEP | 92 | 89 | passos do jogador e do mundo; sons do próprio jogador |
| BREATHING | 17 | 0 | tocados pelo BreathingAudio, nunca pelo roteador |
| DOOR | 11 | 8 | inclui os controles da porta e da batida |
| RUNNING | 3 | 3 | corrida no hall |
| OBJECT_IMPACT | 3 | 3 | pote contra a parede (72,40 e 61,05 dB ao ouvido) e susto de controle (68,33 dB) |

Pedidos de legenda: 7. Eventos com salto de estresse acima de 5 vindos do próprio jogador: 0.

**Coerências pedidas.** Cada linha foi conferida por teste; números de `F3-011_cenario_log.txt` e das notas da suíte.

| Verificação | Medido | Resultado |
|---|---|---|
| Porta fechada corta ~15 dB | 36,55 dB (aberta) → 21,56 dB (fechada), mesmo ouvinte e mesma fonte, pelo portal do hall, sem parede | **atende**: corte de 15,00 dB |
| Corrida soa mais que a caminhada | corrida 47,44 dB percebidos, ganho +0,61; caminhada 35,47 dB, ganho −9,53 | **atende**: +12 dB no que chega ao ouvido |
| O próprio arremesso não assusta | impacto do pote a 72,40 dB ao ouvido (≥ 55), salto de estresse 0,00 | **atende** |
| Trovão eleva o limiar | quintal: limiar 38 → 58 com trovão (offset +20); porta de 50 dB (42,92 dB ao ouvido) era audível e tocada antes, e some depois | **atende**: sem toque, sem legenda |
| Camada de chuva muda ao entrar no quintal | hall e corredor: `rain_interior` (piso 22); sala: `rain_window` (piso 28); quintal: `rain_exterior` (piso 38), com crossfade de 2 s | **atende** |
| Estresse e camada de chuva registrados | telemetria a cada 15 ticks | **atende** (estresse entre 0 e 100, severidade entre 0 e 1, sem NaN) |

### 5.1 Achado de coerência: atenuação audível de porta batida

A porta fechada corta 15 dB no que o ouvido recebe, para qualquer fonte. Mas o volume tocado é comprimido acima de 45 dB, conforme `NoiseGain` (DATA §2.4):

- porta de 50 dB: corte audível de 15,00 dB (abaixo da referência, 1:1);
- porta batida de 75 dB (controle no mesmo ouvinte): perceptivo 15,00 dB, **tocado 3,75 dB** (61,55 → 46,56 dB, ganho 4,14 → 0,39).

Isso não é defeito pela regra escrita; é a decisão do Director de manter a ordem até 69 dB. Mas o jogador ouve uma batida atrás de porta fechada quase do mesmo jeito. O teste `test_porta_batida_tem_corte_audivel_comprimido` fixa o valor medido (entre 3 e 5 dB); se a regra mudar, o teste acusa. **Para o Director decidir** se o efeito de porta fechada deve valer 15 dB também acima de 45 dB.

## 6. Exploits e casos de borda

| # | Caso | Resultado | Quebrou? | Teste |
|---|---|---|---|---|
| 1 | Fechar a porta do hall com o jogador no arco, em pé, agachado e rastejando | a porta para em 66,6° nas três posturas; `blocked` emitido 1 vez; 0 penetrações; fecha por inteiro depois que o jogador sai | não | `test_fechar_com_o_jogador_no_arco_para_no_corpo_em_todas_as_posturas` |
| 2 | Fechar a porta com um arremessável no arco | a porta para em 75°; o objeto não se desloca (0,0000 m); a porta termina de fechar quando o objeto sai | não | `test_fechar_com_objeto_no_arco_para_no_objeto_e_retoma` |
| 3 | Spam de E durante o movimento da porta (18 apertos em ticks alternados) | 1 abertura, 0 fechamentos; porta termina aberta | não | `test_spam_de_interacao_durante_o_movimento_nao_reverte_a_porta` |
| 4 | Spam de E numa porta trancada; lock/unlock | nunca abre; feedback de trancada; estado mantido | não | `test_porta_trancada_nao_abre_com_spam` (corrigido: a falha inicial era do próprio teste, que chamava `unlock()`) |
| 5 | Pegar através de porta fechada | a mira bate na porta (`door_corredor_hall`), não no objeto de trás | não | `test_pegar_atraves_de_porta_fechada_e_de_parede_nao_foca_o_objeto` |
| 6 | Pegar através de parede | sem foco no objeto atrás da parede da cozinha | não | idem |
| 7 | Arremessar pelo vão aberto | objeto passa o vão e chega ao hall (x = 19,81) | não | `test_arremesso_pelo_vao_aberto_passa_a_porta` |
| 8 | Pegar e andar até encostar numa parede | **BUG-016**: o objeto atravessa a parede (z = +0,348, além da face externa em z = 0,1); o corpo do jogador não penetra e recua | **sim** (BUG-016, BAIXO) | `test_objeto_na_mao_ao_encostar_na_parede` (o defeito fica em nota; o teste assere só o jogador) |
| 9 | Spam de pegar e arremessar contra parede | 6 impactos em 140 ticks, limite do cooldown 10 | não | `test_spam_de_arremesso_respeita_o_cooldown_de_impacto` |
| 10 | Arremessar durante a pausa | a ação não arremessa; o objeto segue na mão; depois da pausa, funciona | não | `test_arremessar_durante_a_pausa_nao_faz_nada` |
| 11 | Arremessar com estresse no máximo (crise) | arremesso funciona, sem custo fisiológico (**observação de design**: a crise não limita o arremesso) | não (regra atual) | `test_arremesso_com_estresse_maximo_funciona` |
| 12 | Encostar num caixote pesado | não sobe nem prende: recuou 1,49 m | não | `test_encostar_em_caixote_nao_prende_o_jogador` |
| 13 | Queda pela escada do mezanino (andando e correndo) | nenhum FALL; a descida é pelos degraus (ver 7) | não | `test_mezanino_so_se_desce_pela_escada_sem_fall` |
| 14 | Queda de altura (1,5 m, fora da escada) | FALL; pouso de 4,90 m/s | não | `test_queda_de_altura_gera_fall` |
| 15 | Descer a escada correndo | sem FALL, sem pouso acima de 2,5 m/s; sem penetração | não | `test_descer_a_escada_correndo_nao_gera_fall` |
| 16 | Bombinha (Q) | puff MEDICATION, 38 dB, do jogador; tocado pelo BreathingAudio; não passa pelo roteador; uma dose consumida | não | `test_bombinha_gera_puff_do_corpo_e_nao_passa_pelo_roteador` |
| 17 | Som fora de qualquer sala | `room_id` vazio; piso do exterior (38 dB, D-06); nível calculado | não | `test_evento_fora_de_qualquer_sala_usa_o_exterior` |
| 18 | 300 eventos num único flush | 12 vozes ativas; registro limitado a 256; 19,6 ms (orçamento de 2 s) | não | `test_muitos_eventos_simultaneos_respeitam_o_limite_de_vozes` |
| 19 | Passar pelo portal do quintal durante o crossfade da chuva | camadas `rain_interior` → `rain_exterior`; fade sempre em [0; 1]; saída sem NaN | não | `test_portal_durante_o_crossfade_da_chuva` |
| 20 | Inundação de legendas (500 pedidos) | 500 aceitos, 3 linhas na tela; somem após a duração | não | `test_legendas_inundacao_respeita_o_limite_de_linhas` |
| 21 | Desligar legendas com linhas na tela; mudar o tamanho | linhas saem; pedidos recusados; tamanho 2,0 passa a valer ao vivo | não | `test_legendas_desligar_e_tamanho_ao_vivo` |
| 22 | Remapear `throw` para G e restaurar; conflito com E | G arremessa; o botão antigo deixa de arremessar; restaurado volta ao padrão; E avisa conflito com `interact` | não | `test_remap_throw_aplica_e_restaura`, `test_remap_throw_para_tecla_em_uso_e_avisado` |
| 23 | F5 com 300 eventos em massa (desenvolvimento) | 32 anéis (limite do `MAX_RINGS`), 23 ms, 6 salas; anéis expiram | não | `test_visao_de_debug_com_eventos_em_massa` |
| 24 | Regressões das fases 1 e 2 tocadas pela F3 | portas (BUG-006/009/010), escada (BUG-001/002), bombinha e respiração: todos os testes QA das fases 1 e 2 e da F3 rodaram no pipeline 2× e passaram | não | suíte completa |

**Não foi exploitado:** o jogador com o objeto na mão dentro de uma porta fechada (não se aproximou o suficiente para gerar a situação; coberto indiretamente pelo caso 2).

## 7. Queda do mezanino e a escada

O ROADMAP pede "queda do mezanino gera FALL". **Na sandbox, essa queda não é alcançável por entradas.** Medido pela geometria do nível:

- as bordas oeste, norte e leste do mezanino são paredes; a borda sul tem guardas de 1,0 m com um vão de 1,2 m (x 16,4 a 17,6);
- o vão é exatamente a largura da escada (1,2 m); o degrau de cima está no nível do mezanino (topo em 1,08 m), então não há borda de queda ali;
- andando, a descida é pelos degraus (y final 0,36, FALL 0); correndo, também (y final 0,00, FALL 0); a borda oeste, correndo, não deixa cair (y = 1,08).

A queda de 1,5 m fora da escada gera FALL e um pouso de 4,90 m/s, pelo mesmo caminho do `landed` (teste `test_queda_de_altura_gera_fall`). **Achado de level design, não de código**, para o Director e o Level Designer: não há queda do mezanino por entradas. Se o ROADMAP exige essa queda, falta uma abertura real no nível.

## 8. Áudio

- **Todo som tocado vem de um evento (NOI-05).** Teste `test_todo_som_tocado_vem_de_um_evento`: cada entrada do roteador corresponde a um `NoiseEvent` registrado (103 de 103), e nenhum som do corpo do jogador passa pelo roteador.
- **Ganho segue `NoiseGain` (DATA §2.4).** Teste `test_volume_tocado_segue_a_regra_de_ganho`: 101 asserções, tolerância de 0,0001 dB. O teto de +6 dB aparece no impacto a 72,4 dB.
- **Regeneração determinística.** `python -I tools/audio/check_regen.py --set world` → **PASS** (bit a bit); `--set body` → **PASS** (bit a bit). Evidência: `EVIDENCE/F3-011_regen_world.txt` e `F3-011_regen_body.txt`.
- **Não ouvi nada.** O que fica para a escuta do usuário está na seção 10.

## 9. BUG-014 (ponte de susto de produção): fechado

Verificado pelo QA:
1. Cenário gravado: evento de outra fonte (`enemy_teste`, impacto a 75 dB, 2 m do ouvido, 68,33 dB percebidos) sobe o estresse em 16,66. Teste `test_outra_fonte_a_75_db_assusta_pelo_caminho_de_producao` (faixa 10 a 25).
2. Sons do próprio jogador (passos, corrida, queda, arremesso) não sobem o estresse.
3. Gasp: `test_susto_por_som.gd` (F3-004), no pipeline, faz o gasp quando há estresse prévio; o QA não reexercitou o gasp no cenário, só o pico.

**BUG-014 foi movido para Fechados em `Docs/QA/BUG_REPORTS.md`**, com a evidência.

## 10. Itens para a escuta do usuário (não ouvidos pelo QA)

1. Volume da porta batida e do corte audível (seção 5.1): o corte de 3,75 dB soa suficiente?
2. Limitador do Master com soma de 2 a 3 sons do mundo (R3-03, GAME-009).
3. Trovão no quintal: o ganho de +3,25 dB e o limiar de 58 dB.
4. Passos de corrida contra caminhada no hall e na corredor (diferença de 12 dB no ouvido).
5. Chiado sobreposto (BUG-013, GAME-006), que segue aberto.
6. Timbre dos sons de porta, impacto, queda e chuva (F3-003a/b).

## 11. Testes que falham de propósito

**Nenhum.** Todos os testes deste QA passam no pipeline 2×. Os dois casos em que o defeito real aparece (BUG-016 e a atenuação da porta batida) são documentados por nota e por assertiva de comportamento real: o teste de BUG-016 assere o que o jogador faz (recua e não penetra), e o de atenuação assere o valor medido (entre 3 e 5 dB).

## 12. O que ficou sem verificar

- Escuta (seção 10). Sem medição de áudio no Master.
- Processo separado com `--production` para a visão F5: coberto só pelo teste in-process do F3-008.
- Gasp ao vivo no cenário (só o pico de estresse foi medido).
- Rastejar e agachado contra andar no cenário (STL-01 completo na sandbox).
- Queda do mezanino por entradas (não existe no nível; seção 7).
- Falas (`VOICE`): sem emissor; nada a verificar na F3.
- Tempo de quadro e frequência de quadros do jogo completo (não medidos).
- Visão do objeto atravessando a parede (BUG-016): medido por posição, não por captura de tela.
- O trovão do cenário foi forçado (`AcousticWorld._start_thunder`, mesmo caminho do sorteio, sem o sorteio). O sorteio natural (60 a 180 s) não foi exercitado.
- NOI-01: alvo real só na F4.

## 13. Limpeza e artefatos desta validação

- Processos: as sondas do cenário travaram duas vezes (a sonda carregava o núcleo como variável local, que era liberado); encerrei **apenas** os processos cujo caminho de linha de comando continha `f3011_cenario`. Houve uma tentativa de encerrar todos os processos Godot, que foi recusada pelo classificador; não insisti e não reexecutei a ação.
- Logs de execução isolados (`$TEMP\f3011_appdata`): removi um log de 1,4 GB de execução antiga, que era meu.
- Roteiro: a primeira versão do roteiro saiu da trajetória na fase 08 (rota diagonal que bateu na ombreira da porta da cozinha). Corrigido no roteiro, não no jogo; as fases 08 e 09 da primeira gravação foram descartadas. A segunda versão arremessava de 3,4 m e o impacto chegava a 51,66 dB, abaixo do limiar de susto: corrigido (arremesso de 1,2 m, impacto de 72,40 dB). Os resultados finais são da última gravação.

## 14. Estado dos arquivos (`git status`)

Saída de `git status --short` ao fim da validação:

```
 M Docs/QA/BUG_REPORTS.md                                  (QA: BUG-016 aberto, BUG-014 fechado)
 M Docs/QA/TEST_RESULTS.md                                   (QA: seção F3-011 no fim)
 M game/default_bus_layout.tres                            (NÃO é do QA; ver nota abaixo)
?? Docs/QA/F3-011_VALIDATION.md
?? Docs/QA/EVIDENCE/F3-011_*  (cenário log e telemetria, suítes 1 e 2, regeneração world e body)
?? game/tests/integration/qa/fixtures/f3011_roteiro.gd (+ .uid)
?? game/tests/integration/qa/probes/f3011_cenario.gd and f3011_cenario_core.gd (+ .uid)
?? game/tests/integration/qa/test_f3011_remap_legendas.gd (+ .uid)
?? game/tests/property/qa/test_f3011_cenario_silencio.gd (+ .uid)
?? game/tests/property/qa/test_f3011_portas_arremessaveis.gd (+ .uid)
?? game/tests/property/qa/test_f3011_queda_som_clima.gd (+ .uid)
```

**Nota sobre `game/default_bus_layout.tres`.** O arquivo não foi editado pelo QA. O `--import` do Godot, rodado pelo pipeline (que faz importação em toda execução), regravou o recurso: removeu valores iguais ao padrão (`dry = 1.0`, `spread = 1.0`, `bus/0/name = "Master"` e demais campos do bus 0) e acrescentou um `uid`. A mudança é só de formato, sem efeito de comportamento (o teste de barramento e o limitador passam nas duas execuções). Não foi revertida, porque é arquivo de produção e a regra desta validação proíbe alterá-lo. **Para o Director decidir** se o arquivo volta ao commit, ou se o formato regravado é aceito.

### Arquivos criados ou alterados pelo QA nesta validação

- Testes: `game/tests/property/qa/test_f3011_cenario_silencio.gd`, `game/tests/property/qa/test_f3011_portas_arremessaveis.gd`, `game/tests/property/qa/test_f3011_queda_som_clima.gd`, `game/tests/integration/qa/test_f3011_remap_legendas.gd`.
- Roteiro compartilhado e sonda de evidência (auxiliares de QA, prefixo `f3011_`): `game/tests/integration/qa/fixtures/f3011_roteiro.gd`, `game/tests/integration/qa/probes/f3011_cenario.gd`, `game/tests/integration/qa/probes/f3011_cenario_core.gd`.
- Relatórios: `Docs/QA/F3-011_VALIDATION.md` (este), `Docs/QA/TEST_RESULTS.md` (seção F3-011), `Docs/QA/BUG_REPORTS.md` (BUG-016 aberto; BUG-014 fechado).
- Evidência: `Docs/QA/EVIDENCE/F3-011_*` (cenário log e telemetria; suítes 1 e 2; regeneração world e body).
- Artefatos do import do Godot para os scripts novos: `*.gd.uid` dos arquivos acima (artefatos normais do motor, como nas fases anteriores).

## Fechamento pelo Project Director

Decisões sobre as ressalvas (2026-11-21):

| Item | Decisão |
|---|---|
| BUG-016 (BAIXO), objeto na mão atravessa a parede | **Corrigido pelo Director.** `Throwable.safe_hold_transform` varre a forma do objeto da câmera até a mão e para no primeiro contato com o mundo; o `PlayerHold.step` usa essa posição. Teste novo `test_objeto_na_mao_para_na_parede` (objeto em z = −0,298, antes da face em −0,400). Os dois testes da R3-05 passaram a pôr o objeto dentro do bloco no mesmo tick do arremesso ou da soltura, porque a mão não entra mais na parede sozinha. O medidor de penetração do fixture do QA (`qa_fixture.gd`) passou a ignorar o objeto na mão: ele para diante da câmera e pode sobrepor o volume do próprio jogador, mas não é geometria de mundo. A 1ª verificação do QA reabriu o bug para o objeto pesado, e o Director corrigiu de novo: a varredura parte de um ponto recuado e nunca de dentro do mundo. A 2ª verificação achou um resto visual (de costas para a parede, o objeto pesado ficava no ponto antigo) e o Director corrigiu com o avanço guardado por raio. Estado: CORRIGIDO, aguardando a 3ª verificação |
| Queda do mezanino inalcançável na sandbox | **Aceito como achado de nível** (KNOWN_ISSUES GAME-011). A queda é validada com 1,5 m sintéticos (FALL a 4,90 m/s). O vertical slice da F5 precisa de pelo menos um ponto de queda alcançável |
| Porta batida: −15 dB no ouvido viram −3,75 dB no volume | **Aceito, troca consciente** (AUDIO_DESIGN §3): a regra é 1:1 até 45 dB, onde se decide entre audível e inaudível. Acima, a compressão preserva a ordem sem clipar. A visão de debug (F5) mostra os números exatos |
| `default_bus_layout.tres` regravado pelo `--import` | **Aceito**: é a serialização canônica do Godot (acrescenta `uid` e omite valores padrão). O conteúdo não muda; o teste do barramento e o do limitador passam |
| Suíte padrão entre 8,5 e 9,8 s | Os dois cenários de cena inteira mais pesados da F1 (`test_camera_rampa`, `test_portas_sandbox`) foram para a suíte lenta (`tests/property/`), com o conteúdo inalterado |
| ACC-04 sem falas, NOI-01 sem alvo real | Previstos: F4 (KNOWN_ISSUES GAME-010) |
| Escuta | Fica com o usuário (seção 10): BUG-013, GAME-006 e GAME-009 |

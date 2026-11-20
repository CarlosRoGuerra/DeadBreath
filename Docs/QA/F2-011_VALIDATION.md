# Validação independente da Fase 2 — F2-011

| Campo | Valor |
|---|---|
| Data | 2026-11-20 |
| Responsável | QA Engineer (contexto novo; não implementou nada da F2) |
| Base | commit `d706a7b` (`main`) mais a árvore de trabalho atual, sem commit. Só foram criados arquivos QA (`game/tests/*/qa/`, `game/tests/integration/qa/probes/`, `Docs/QA/`). Nenhum arquivo do jogo, nem em `tools/`, foi alterado. Sem git |
| Ambiente | Windows 11, Godot 4.7.2.stable (`D:\DevTools\Godot\4.7.2`), GPU AMD Radeon RX 9070 XT (Vulkan, Forward+), 60 Hz de física, `--fixed-fps 60` nos testes |
| Isolamento | `APPDATA` isolado para gravações e probes (`scratchpad\appdata_iso`). O perfil real não tem `settings.cfg` (verificado ao fim). Áudio mudo (`master_volume = 0`) nas gravações: a evidência de som vem dos logs, não dos alto-falantes |

## 1. Veredito final

**APROVADO COM RESSALVAS.**

- **Nenhum defeito ALTO ou CRÍTICO.** Defeitos abertos: BUG-012 (BAIXO), BUG-013 (BAIXO), BUG-014 (MÉDIO, dependência da F3), BUG-015 (BAIXO, só em build de desenvolvimento).
- **Pipeline oficial APROVADO nas duas execuções** (`tools/run_tests.ps1`, código 0; `Docs/QA/EVIDENCE/F2-011_suite_1.txt` e `_2.txt`).
- **Gate F2 atendido** nos critérios técnicos: PHY-01..11 verdes, ACC-01..03 verdes, cenário "correr até a crise e se recuperar" gravado com janela. Os documentos `STAMINA_SYSTEM.md`, `RESPIRATORY_SYSTEM.md` e `STRESS_SYSTEM.md` existem em `Docs/Gameplay/`; o conteúdo não foi avaliado pelo QA.
- Ressalvas que permanecem: escuta do usuário (F2-006a e GAME-006), decisão sobre o chiado sobreposto (BUG-013), ponte de susto na F3 (BUG-014), e a persistência em JSON (ARCH-001, F5).

## 2. Pipeline completo (2 execuções)

| Etapa | Execução 1 | Execução 2 | Observação |
|---|---|---|---|
| importacao | OK (código 0) | OK (código 0) | |
| arc04 (parse/compilação, ARC-04) | OK | OK | 157 scripts em `res://` |
| runner (unit, integration, scenarios, architecture) | **293/293** | **293/293** | antes: 285 (F2-010) + 8 QA |
| runner-property | **99/99** | **99/99** | antes: 84 (F2-010) + 15 QA |
| runner-meta | **26/26** | **26/26** | |
| Veredito | **APROVADO** | **APROVADO** | |

Aviso do motor no encerramento, presente nas duas execuções: `ERROR: 15 resources still in use at exit` (etapas runner e runner-property). É mensagem do motor no encerramento; não é `SCRIPT ERROR` e o código de saída é 0. Não foi investigado a fundo.

**Histórico de execução (transparência):** a primeira versão do teste de áudio (`test_f2011_audio_corpo.gd`) reprovou na suíte completa por corrida de ordem: o `BreathingAudio` liga-se ao `AcousticWorld` por `call_deferred`, e o contador de eventos começava em momento diferente do áudio. Foram três ajustes de medição do próprio teste (ordem de conexão, janela após a ligação e comparação por janelas). A versão final passa isolada e na suíte completa. Não houve alteração no jogo para isso.

## 3. Matriz de aceitação: critérios do Gate F2 (ROADMAP)

| Critério | Resultado | Evidência |
|---|---|---|
| PHY-01..PHY-11 verdes (com `StubThreatSource` ou `ThreatSample` injetado) | **atende** (11/11 do QA, com configs de produção) | `game/tests/property/qa/test_f2011_fisiologia.gd`; suítes 1 e 2 |
| ACC-01..03 verdes | **atende** | `test_f2011_fisiologia.gd` (acc01–03); `test_f2011_crise_opcoes.gd` (efeito ao vivo na crise); suítes 1 e 2 |
| Cenário "correr até a crise e se recuperar" gravado | **atende** | `F2-011_cenario_*` (seção 5) |
| `RESPIRATORY_SYSTEM.md`, `STRESS_SYSTEM.md`, `STAMINA_SYSTEM.md` escritos | **atende na existência** (34, 64 e 34 linhas); conteúdo não avaliado pelo QA | `Docs/Gameplay/` |

Parâmetros PHY medidos pelo QA (configs de produção, `.tres`):

| PHY | Critério do TEST_PLAN | Medido | Resultado |
|---|---|---|---|
| PHY-01 | Sprint de tanque cheio esgota em ≈ 8,3 s, estado LABORED ou pior | 8,333 s; LABORED | atende |
| PHY-02 | Estresse 80 eleva o alvo ≥ 0,25 | 0,425 vs 0,140 (diferença 0,285) | atende |
| PHY-03 | 0,6 em repouso → < 0,2 em ≤ 25 s | 6,667 s | atende |
| PHY-04 | Bombinha em SYMPTOMATIC: redução absoluta ≥ 0,30 em ≤ 3 s | 0,599 → 0,068 em 3 s (0,531) | atende |
| PHY-05 | Bombinha não altera estamina; estamina zero não altera severidade no tick | verificado | atende |
| PHY-06 | 200 sequências de 120 s ativo + 60 s repouso → severidade < 0,2 e estresse < 25 | 200 sequências; severidade final máx. 0,0003; estresse final máx. 0,000 | atende |
| PHY-07 | Toda tosse precedida de aviso ≥ 1,5 s | 530 tosses; menor intervalo aviso→tosse 1,5000 s | atende |
| PHY-08 | Mesmo RNG e mesmas entradas → snapshots idênticos | verificado | atende |
| PHY-09 | Nenhum valor fora do intervalo nas sequências | estamina [0,00; 100,00]; estresse [0,00; 100,00]; severidade [0; 0,9483] | atende |
| PHY-10 | Nenhuma transição antes de `state_min_dwell_s` | menor permanência 1,000 s | atende |
| PHY-11 | dt 1/60 e 0,1 → diferença ≤ 0,02 | diferença 0,0000 | atende |
| ACC-01 | Redução 1,0 zera balanço, tremor e solavanco | 0,0000 m; 0,0000 m; 0,000° | atende |
| ACC-02 | Intensidade escala linearmente | balanço 1,0 = 0,0130; 0,5 = 0,0065; 0 = 0 | atende |
| ACC-03 | Indicador segue o estado em ≤ 1 quadro; desligado por padrão | indicador `CanvasLayer`, visível ao ligar a opção na crise, na hora | atende |

Nota: o TEST_PLAN fala em 200 sequências para PHY-06/07/09. A versão inicial deste teste usava 30 (por tempo); foi ampliada para 200 e reexecutada antes das suítes finais.

### Cards F2-001 a F2-009

| Card | Resultado | Evidência e ressalvas |
|---|---|---|
| F2-001 StaminaModel | **atende** | Suíte: `test_tanque_cheio_sprint_dura_8_3_s`, `test_sem_regeneracao_durante_regen_delay`, `test_histerese_de_exaustao_reabilita_em_25`. QA: PHY-01 (8,333 s). Ressalva: na gravação o sprint só foi recusado abaixo de 25 (ver seção 5), a reabilitação em 25 com sprint pedido não foi exercitada pelo QA |
| F2-002 StressModel | **atende** | Suíte: `test_decaimento_de_100_a_0_em_37_3_s`, `test_faixas_nos_limiares`. QA: estresse sustentado em 100 por 10 min (seção 6) |
| F2-003 RespiratoryModel | **atende com ressalva** | PHY-01..11 verdes (QA e suíte); PER-07 em memória (`test_per07_*` e persistência do QA, exata). Ressalva: JSON diverge (ARCH-001, R2-02 MÉDIO, gatilho F5). Ressalva de texto: R2-04 (PHY-03 em DATA §1.4 diz 6,7–10 s; medido 6,667 s), para a F2-012 |
| F2-004 PhysiologyComponent + integração | **atende** | Suíte: `test_exaustao_proibe_o_sprint`, `test_limite_de_sprint_so_depois_de_0_6`, `test_firmeza_*`, `test_jogador_sprint_exaustao` (integração), `test_firmeza_alonga_segurar` (integração), ARC-06 verde. Gravação: sem sprint enquanto estamina < 25 (ver seção 5); `estabilidade` cai a 0,028 na crise |
| F2-005 Bombinha + inventário | **atende** | QA: `test_f2011_bombinha_q.gd` (spam de Q, cooldown de 10 s medido em quadros, 3 doses por unidade, motivo `no_doses`). Suíte: `test_bombinha_vale_tres_doses_por_unidade`, `test_medicacao_inventario`, `test_pickup_e_toque` (este último não reexecutado pelo QA). Comprimido e água ficam para a F5 (decisão do Director) |
| F2-006a Gerador de sons | **atende com pendência** | 41 arquivos WAV no manifesto (contagem conferida pelo QA). Determinismo bit a bit: medido pelo revisor (42/42, F2-010), não reexecutado pelo QA. Pendente: audição pelo usuário (`tools/audio/audition.ps1`) |
| F2-006b Produtor único de respiração | **atende com ressalvas** | QA: 10 eventos respiratórios e 10 inspirações casadas; sons pontuais casados; zero sons sem evento (seção 7). Ressalvas: BUG-013 (chiado sobreposto) e BUG-014 (gasp de susto sem chamador de produção, MÉDIO) |
| F2-007 Efeitos de câmera e indicador | **atende** | ACC-01..03 (acima). Na crise com intensidade 1: vinheta 0,139; após intensidade 0, 0,000 no quadro seguinte. Tremor visível só no CSV (amplitude 1,0 no máximo) |
| F2-008 Ferramenta de balanceamento | **atende com ressalva** | Painel invisível em produção e comandos recusados (probe de produção). Ressalva: BUG-012 (F4 consumida em produção, BAIXO). Simulação determinística: medida pelo revisor (6 arquivos idênticos). Ressalva conhecida: TEST-005 (painel altera `Resource` compartilhado) |
| F2-009 Animações em primeira pessoa | **parcial** | Viewmodel existe (`game/presentation/camera/viewmodel.gd`). Animação de uso da bombinha e sobressalto da tosse não foram avaliados visualmente pelo QA. Nas capturas 05 e 06 aparece uma sombra escura na borda inferior do quadro, origem não identificada. Aparência a melhorar na F7, conforme o card |

## 4. Defeitos (registrados em `Docs/QA/BUG_REPORTS.md`)

| ID | Severidade | Título | Estado |
|---|---|---|---|
| BUG-012 | BAIXO | Em produção, a F4 é consumida pelo painel de balanceamento mesmo com o painel desligado (R2-13) | ABERTO |
| BUG-013 | BAIXO | Camada de chiado (2,1–2,6 s) dura mais que o ciclo em respiração rápida: vozes se sobrepõem (R2-03 / GAME-006). Vira MÉDIO se a escuta mostrar acúmulo audível | ABERTO (escuta do usuário) |
| BUG-014 | MÉDIO | Gasp de susto sem chamador de produção: `add_startle` não é chamado no jogo (R2-01) | ABERTO (F3-002) |
| BUG-015 | BAIXO | Noclip de desenvolvimento suprime o ruído de passo (atalho de debug; recusado em produção) | ABERTO (decisão F4/F5) |

## 5. Cenário gravado: "correr até a crise e se recuperar"

Gravado com janela (1280×720, `--quit-after 30000` como rede de segurança, processo terminou com código 0). Roteiro: parado 1,5 s; correr sob ameaça (`StubThreatSource` forçado, perseguição) até esgotar; seguir com sprint pedido sob ameaça até a primeira tosse em SYMPTOMATIC; bombinha 1 s depois da tosse; descanso agachado sem ameaça até NORMAL.

Linha do tempo (tempo de simulação):

| Tempo | Evento |
|---|---|
| 1,52 s | ameaça ligada |
| 2,2 / 2,9 / 3,7 s | CALM → TENSE → AFRAID → PANIC (estresse 100 em torno de 5,5 s) |
| 4,0 s | NORMAL → ACCELERATED |
| 5,9 s | ACCELERATED → LABORED |
| 9,0 s | LABORED → SYMPTOMATIC (severidade 0,600) |
| 9,83 s | estamina esgotou (0,00) |
| 10,0 s | captura da crise (1 s em SYMPTOMATIC) |
| 13,88 s | aviso de tosse (1,50 s) |
| 15,38 s | tosse: severidade 0,6964; vinheta 0,084; tremor 1,000; estabilidade 0,093 |
| 16,40 s | bombinha usada: doses 3 → 2 |
| 17,27 s | SYMPTOMATIC → LABORED |
| 18,97 s | LABORED → RECOVERING |
| 20,42 s | ameaça desligada (descanso agachado) |
| 22,12 s | RECOVERING → NORMAL |

Sprint: depois do esgotamento, o esforço ficou em 0,2 (andar) até a tosse, com estamina entre 0 e 6,73; a estamina só atingiu 25 em 21,37 s, já em repouso. A recusa abaixo de 25 foi observada; a reabilitação do sprint em 25 com sprint pedido não foi observada na gravação (coberta pelos testes unitários da suíte).

Máximos da telemetria: vinheta 0,171; tremor 1,000; estabilidade mínima 0,028.

Capturas (inspecionadas uma a uma):

| Arquivo | Tempo | O que se vê |
|---|---|---|
| `F2-011_cenario_01_inicio.png` | 0,02 s | cozinha, parado, sem efeitos |
| `F2-011_cenario_02_esgotamento.png` | 9,85 s | corredor com portas abertas, sem efeito visível de exaustão |
| `F2-011_cenario_03_crise.png` | 10,00 s | corredor; escurecimento discreto de borda, vinheta fraca (0,07) |
| `F2-011_cenario_04_tosse.png` | 15,40 s | cozinha; vinheta discreta (0,084). O solavanco não aparece em imagem fixa |
| `F2-011_cenario_05_bombinha.png` | 16,42 s | corredor com porta aberta; sombra escura na borda inferior |
| `F2-011_cenario_06_recuperacao.png` | 22,15 s | porta da cozinha aberta; sombra escura na borda inferior |

A vinheta é discreta, o que está de acordo com o card F2-007 ("escurecimento discreto"). Tremor e solavanco não são legíveis em imagem fixa; o tremor está no CSV e o solavanco não está registrado (ver limites).

Arquivos da gravação:
- Telemetria: `Docs/QA/EVIDENCE/F2-011_cenario_telemetria.csv` (1449 linhas de dados; colunas: tempo, fase, estamina, estresse, faixa, severidade, estado, frequência, chiado, probabilidade de tosse, recuperação, doses, vinheta, estabilidade, tremor, esforço, postura, eventos).
- Log de sons (`played_log`): `Docs/QA/EVIDENCE/F2-011_cenario_played_log.json` (31 entradas).
- Eventos com tempo: `Docs/QA/EVIDENCE/F2-011_cenario_eventos.json` (34 entradas).
- Log de execução: `Docs/QA/EVIDENCE/F2-011_cenario_run.log`.

## 6. Exploits e casos de borda

| # | Caso | Resultado | Quebrou algo? | Evidência |
|---|---|---|---|---|
| 1 | Spam de Q: 30 chamadas no mesmo quadro; 10 Q reais pela entrada | exatamente 1 dose gasta; 29 recusas `cooldown` | não | `test_f2011_bombinha_q.gd` (4 testes) |
| 2 | Cooldown de 10 s | recusa a 9 s, aceita a 11 s; 3 doses por unidade; `no_doses` depois; nunca negativo | não | idem |
| 3 | Bombinha durante o aviso de tosse | cancela a tosse só pela severidade no vencimento (abaixo de 0,55): caso sem bombinha 0,773 → tosse; com bombinha 0,433 → suprimida. Regra consistente nos dois ramos | não | `test_f2011_persistencia_aviso.gd` |
| 4 | "Nunca tossir" com bombinha em cada aviso (doses ilimitadas, cooldown de 10 s), 10 min de estresse máximo | sem tratamento: 66 avisos, 66 tosses. Com bombinha a cada aviso: 10 avisos, 6 tosses, 4 suprimidas, 10 aplicações. A bombinha reduz muito, mas não zera; com 3 doses por unidade o abuso é limitado | não (observação de balanceamento para o Director, não defeito) | `test_f2011_estresse_10min.gd` |
| 5 | Pausa no meio da crise (`tree.paused = true` no aviso de tosse, 5 s) | fisiologia sem alteração em 300 quadros; played_log sem crescimento; tosse agendada disparou 90 quadros de física depois da retomada (1,50 s sem contar a pausa); 17 inspirações, 17 expirações pareadas, nenhuma sobrando | não | `F2-011_pausa_probe.txt`, `F2-011_pausa_played_log.json` |
| 5b | Pausa: `AudioStreamPlayer.stream_paused` | **inconclusivo**: nenhum player aparecia tocando durante a pausa, nem o som de aviso de 1,5 s, que deveria estar tocando. Não foi confirmado no nível do player; a evidência de pausa é o log | não confirmado | `F2-011_pausa_probe.txt` (linhas RESUMO) |
| 6 | Mudar acessibilidade no meio da crise (intensidade 0, redução de movimento e tremor 1, indicador ligado) | estresse não reseta (tolerância 2 pontos); vinheta 0,139 → 0,000 no quadro seguinte; amplitude de tremor e solavanco zero; indicador visível na hora | não | `test_f2011_crise_opcoes.gd` |
| 7 | Modo `--production`: painel F4, overlay e comandos de debug | painel e overlay invisíveis; ação `debug_overlay` não abre o overlay; `toggle_noclip` e `teleport_to_aim` recusados (sem mudança de estado). A tecla F4 continua sendo consumida pelo jogo | **sim**: BUG-012 (BAIXO) | `F2-011_producao_producao.txt`; desenvolvimento para comparação em `F2-011_producao_desenvolvimento.txt` (painel abre com F4) |
| 8 | Spam de postura na crise: agachar uma vez e ficar parado × agachar a cada quadro | repouso em 100% dos quadros × 50%; queda da severidade igual (0,0254/s × 0,0253/s), limitada pelo alvo. Spam não ajuda | não | `test_f2011_crise_opcoes.gd` |
| 9 | Noclip na crise (com sprint) | estresse segue (100 → 100); passos 37 sem noclip × 0 com noclip | **sim (só desenvolvimento)**: BUG-015 (BAIXO) | idem |
| 10 | Salvar (`to_dict`) e restaurar (`from_dict`) no meio de um aviso, em memória | restaurado repete a mesma história: diferença máxima 0,0 em estamina, estresse, severidade e estado; eventos seguintes idênticos (3 × 3). JSON não é coberto aqui (ARCH-001) | não | `test_f2011_persistencia_aviso.gd` |
| 11 | Estresse máximo constante por 10 min (36000 quadros, configs de produção) | limites 0..100 e 0..1 e sem NaN em todas as amostras; estresse final 100; 1 exaustão (esforço constante) | não | `test_f2011_estresse_10min.gd` |

Não foi testado: acúmulo de eventos de tosse em memória ao longo de horas (não medido); comprimido e água (F5).

## 7. Áudio do corpo

Medições (script `Docs/QA/EVIDENCE/F2-011_audio_analise.txt`, lendo os logs gravados e o manifesto):

- **Sem som sem evento.** Teste de integração (`test_f2011_audio_corpo.gd`): em repouso e depois de uma corrida, zero sons com `sound_id` fora dos eventos do jogador; inspirações iguais aos eventos respiratórios dentro de cada janela; expirações e camadas de chiado com no máximo uma pendente na borda. Na gravação: 13 eventos resolvidos (10 respiratórios, 6 com chiado, 3 pontuais); 31 entradas no log (11 inspirações, 11 expirações, 6 camadas, 3 pontuais). Os 2 sons "sem evento" da análise são a inspiração e a expiração do primeiro ciclo, emitido antes do hook do cenário; por construção, o cenário começou a contar depois.
- **Relógio do áudio.** O relógio do `BreathingAudio` (de quadro) fica 0,416 s adiantado em relação ao tempo da simulação, constante nos eventos gravados. Na pausa, o relógio do áudio para e o intervalo aviso→tosse fica em 1,486 s, correto.
- **Sobreposição, medida na corrida gravada (até 34,7 rpm):** máximo de 2 chiados simultâneos (2,76 s com dois chiados); máximo de 4 vozes simultâneas contando tosse e puff; 5,17 s com 3 ou mais vozes. Duração efetiva da camada de chiado: 2,13 a 2,62 s.
- **Sobreposição a 40 rpm (cálculo, não escuta):** período 1,5 s, família rápida, pitch 1,133, inspiração 0,662 s, expiração 0,838 s, chiado 2,118 s. Resultado: até 3 vozes simultâneas (2 chiados e 1 expiração) em 40% do tempo. Confirma o alerta do R2-03 por cálculo. Registrado como BUG-013 (BAIXO), a decidir após a escuta (GAME-006).
- **Número de vozes simultâneas:** no máximo 4 (corrida gravada) e 3 (40 rpm, cálculo). Não há limite especificado no TEST_PLAN; a escuta decide.
- **Pausa:** nenhuma entrada nova no log durante a pausa; inspirações e expirações continuam pareadas depois da retomada.

## 8. Suíte e execuções

| Execução | Arquivo | Resultado |
|---|---|---|
| Pipeline 1 | `Docs/QA/EVIDENCE/F2-011_suite_1.txt` | APROVADO (código 0): runner 293/293, property 99/99, meta 26/26 |
| Pipeline 2 | `Docs/QA/EVIDENCE/F2-011_suite_2.txt` | APROVADO (código 0): runner 293/293, property 99/99, meta 26/26 |
| Fisiologia (versão antiga, 30 sequências) | `Docs/QA/EVIDENCE/F2-011_fisiologia_run1.txt` | superada pela suíte com 200 sequências |

Testes novos do QA (todos com prefixo `test_f2011_`, em `game/tests/*/qa/`):
- `game/tests/property/qa/test_f2011_fisiologia.gd` (11 testes: PHY-01..11, ACC-01..03)
- `game/tests/property/qa/test_f2011_persistencia_aviso.gd` (2 testes)
- `game/tests/property/qa/test_f2011_estresse_10min.gd` (2 testes)
- `game/tests/integration/qa/test_f2011_bombinha_q.gd` (4 testes)
- `game/tests/integration/qa/test_f2011_crise_opcoes.gd` (3 testes)
- `game/tests/integration/qa/test_f2011_audio_corpo.gd` (1 teste)

Probes (fora do runner, rodados em processo próprio): `game/tests/integration/qa/probes/f2011_cenario.gd` e `f2011_cenario_core.gd` (gravação), `f2011_pausa.gd` e `f2011_pausa_core.gd` (pausa), `f2011_probe_producao.gd` (modo `--production`).

Os arquivos `.gd.uid` criados pelo import do Godot para os scripts novos são artefatos normais do motor.

## 9. Evidências

- Imagens: `Docs/QA/EVIDENCE/F2-011_cenario_01_inicio.png`, `..._02_esgotamento.png`, `..._03_crise.png`, `..._04_tosse.png`, `..._05_bombinha.png`, `..._06_recuperacao.png`
- CSV de telemetria: `Docs/QA/EVIDENCE/F2-011_cenario_telemetria.csv`
- Played log e eventos da gravação: `Docs/QA/EVIDENCE/F2-011_cenario_played_log.json`, `Docs/QA/EVIDENCE/F2-011_cenario_eventos.json`
- Pausa: `Docs/QA/EVIDENCE/F2-011_pausa_probe.txt`, `F2-011_pausa_played_log.json`, `F2-011_pausa_eventos.json`
- Produção: `Docs/QA/EVIDENCE/F2-011_producao_producao.txt`, `F2-011_producao_desenvolvimento.txt`
- Análise de áudio: `Docs/QA/EVIDENCE/F2-011_audio_analise.txt`
- Suítes: `Docs/QA/EVIDENCE/F2-011_suite_1.txt`, `F2-011_suite_2.txt`

## 10. Limites desta validação

- O cenário usa ameaça simulada (`StubThreatSource` forçado); a ameaça real é da F4. O volume foi zerado: a evidência de som vem dos logs, e a escuta é do usuário.
- A gravação não atingiu 40 rpm (máximo ~34,7 rpm); a sobreposição a 40 rpm é cálculo sobre `chain_timing` e os WAVs do manifesto, não escuta.
- Tremor e solavanco não aparecem em imagens fixas. O solavanco da tosse não tem coluna no CSV (sem ângulo de câmera registrado); verificado só pelo código (`jolt_amplitude_deg`) e pelo teste ACC-01/02.
- `AudioStreamPlayer.stream_paused` não foi confirmado durante a pausa (sem player tocando observado). A evidência de pausa é o log.
- A reabilitação do sprint em 25 com sprint pedido não foi exercitada pela gravação (só a recusa abaixo de 25).
- PER-07 vale em memória; o caminho JSON diverge (ARCH-001). Não coberto no QA.
- Frequência de quadros e tempo de quadro não foram medidos.
- Sombra escura na borda inferior das capturas 05 e 06: origem não identificada.
- Não foi feita escuta; o áudio é avaliado por logs e cálculo.

## 11. Pendências para o Director

1. **BUG-013 (chiado sobreposto):** aguarda a escuta do usuário (GAME-006). Decidir se o chiado precisa de regra de não-sobreposição.
2. **BUG-014 (gasp):** rastreado em F3-002 (ponte de susto); a aceitação "gasp a partir do susto" do card F2-006b fica pendente até lá.
3. **BUG-012 (F4 em produção):** correção do dono de `balance_panel.gd`.
4. **BUG-015 (noclip):** decidir se é atalho de debug documentado ou se noclip deve emitir passo.
5. **F2-012 (documentação):** R2-04 (texto de PHY-03 em DATA §1.4), R2-07 (TEST_RESULTS desatualizado: ACC-02/03 agora cobertos) e revisão do conteúdo dos três `*_SYSTEM.md`.
6. **Balanceamento (observação):** a bombinha reduz tosses de 66 para 6 em 10 min de abuso com doses ilimitadas. Não é defeito; entra na avaliação de P-01/P-02 pelo Director.
7. **Escuta do usuário:** F2-006a (`tools/audio/audition.ps1`) e playtest (GAME-006).

## Fechamento pelo Project Director

_Pendente._

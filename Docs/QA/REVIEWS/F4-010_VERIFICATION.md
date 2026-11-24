# Verificação focada F4-010 — correções da revisão

| Campo | Valor |
|---|---|
| Data | 2026-11-24 |
| Commit verificado | `019a893` (árvore limpa no início; `git status` vazio antes da verificação) |
| Base da revisão original | `69d382c` (revisão `Docs/QA/REVIEWS/F4-010.md`: REPROVADO, 0 CRÍTICO, 1 ALTO, 3 MÉDIO, 4 BAIXO, 4 INFO) |
| Escopo | R4-01..R4-12 (correções e decisões D4-09) + achados novos introduzidos pelas correções |
| Método | Leitura do diff `69d382c..019a893` (código, testes e contratos). Pipeline oficial rodado uma vez. Cópia nova de `game/` por `git archive HEAD`, fora do repositório, com importação. Probes do cérebro isolado (L1): `exp_chase.gd`, `exp_chase2.gd`, `exp_return.gd`, `exp_return2.gd`. Dez burlas ao ARC-01 novo, cada uma num arquivo de sonda. Mutações: M9 e M10 (as da revisão), F1..F7 (uma por correção). Falsos positivos do ARC-01 com código legítimo. Simulação do crossfade com o mesmo algoritmo do GDScript. Os relatórios de correção e as mensagens de commit não foram usados como evidência. |
| Revisor | Technical Reviewer (contexto independente) |
| **Resultado** | **APROVADO COM RESSALVAS** (0 CRÍTICO, 0 ALTO, 1 MÉDIO aberto, 1 BAIXO novo, 3 INFO novos) |

Critério: REPROVADO se houver CRÍTICO ou ALTO em aberto; APROVADO COM RESSALVAS se houver só MÉDIO ou menor. O ALTO (R4-01) está resolvido e reproduzido. O R4-04 (MÉDIO) foi corrigido só em parte: a correção cobre as burlas que o Director listou, e o revisor achou outras nove que continuam passando (N1).

---

## 1. Resumo

- **R4-01 (ALTO) resolvido.** O `exp_chase.gd` deu `LOST_CONTACT` em 1,500 s, com 1 grito (antes: 4,53 s e 2 gritos extras). A volta a CHASE exige visão nova (0,8 s), e visibilidade abaixo do mínimo (0,3) não reabre a perseguição (`exp_chase2.gd`). Teste novo `test_perseguicao_longa_perde_contato_em_1_5_s_com_um_grito` pega F1 (sem teto).
- **R4-02 resolvido.** `observer.tscn` tem `LightExposureProbe`. Teste `test_observer_iluminado_a_8_m_e_visto` pega F7 (sem a sonda).
- **R4-03 resolvido, sem laço sem fim.** RETURN com destino inalcançável vai a PATROL em 60 s (`exp_return.gd`); rota inteira inalcançável fica parada em PATROL (`exp_return2.gd` S1); corpo parado com rota alcançável troca de ponto a cada 30 s (S2 e S3). Os laços são limitados por `range(route.size())` e por temporizadores; nenhum laço sem fim no mesmo tick. Testes `test_return_inalcancavel_volta_a_patrulha` (F3) e `test_patrulha_passa_ao_ponto_seguinte_depois_do_tempo_limite` (F4) pegam as mutações.
- **R4-04 parcial (MÉDIO aberto, N1).** M9 (grupo `&"player_body"`) agora reprova em arquitetura (`FAIL test_firewall_sem_acesso_indireto`). Mas das dez burlas que o revisor testou, só uma é pega (b03, pelo identificador `player_stress_changed`, não pelo alias do `EventBus`). Nove passam, incluindo a leitura direta de `global_position` pelo grupo `perceivable`, que a lista permite.
- **R4-05 resolvido.** A normalização dos pesos mantém a soma de potências em 1 (erro máximo 2,2e-16 na simulação); o mínimo do total de pesos foi 0,50, então a divisão por zero não acontece na prática. F5 (sem normalização) é pega por `test_meia_ameaca_e_depois_perseguicao`.
- **R4-06, R4-07 e R4-08 resolvidos.** `reset_to` drena o `HearingSensor` (F6 pega por `test_reset_descarta_os_sons_pendentes`); a docstring do `HeardNoise` foi corrigida; COMPONENT_CONTRACTS §8.3 existe, e o cabeçalho do cérebro e GAME-013 foram alinhados.
- **Pipeline oficial verde** em `019a893`: estático 10/10, padrão 660/660 (8,414 s), propriedade 208/208, meta 26/26, `APROVADO` em 208,89 s.
- **Mutação F2 (não zerar a confirmação ao entrar em LOST) não é pega.** É equivalente: com o teto de 0,6 e o decaimento de 2/s, a confirmação já está em zero quando o LOST acontece. A linha é redundante, não um teste faltando.

---

## 2. Tabela por achado da revisão original

Situação: RESOLVIDO / PARCIAL / ACEITO / INFO aberto. Os NOVO estão na seção 4.

| ID | Sev. orig. | Situação | Evidência (diff, probe ou mutação) | Comentário |
|---|---|---|---|---|
| R4-01 | ALTO | **RESOLVIDO** | `exp_chase.gd`: `EXP resumo_fase2 shouts=0 entradas_LOST=1 primeira_LOST_apos_s=1.500 chase_ticks_apos_perda=90 (1.50 s)`. `exp_chase2.gd`: `A_visao_nova ... estado=4 gritos=1`; `B_visao_fraca fim estado=5 gritos=0`. F1 pega. | Antes: 4,53 s e 2 gritos. Teto em `_add_confirmation` e zeragem em `_enter(LOST_CONTACT)`. |
| R4-02 | MÉDIO | **RESOLVIDO** | `observer.tscn:106-109` (nó `LightExposureProbe` com `sample_offsets`). F7 (sem o nó) pega por `test_observer_iluminado_a_8_m_e_visto`. | Visto a 8 m em luz conta para a ameaça; no escuro, não (teste do Director). |
| R4-03 | MÉDIO | **RESOLVIDO** | `exp_return.gd`: SEARCH em 0,02 s, PATROL em 60,02 s, ficou em PATROL. `exp_return2.gd`: S1 rota inteira inalcançável → PATROL em 60 s, parado; S2 corpo parado → RETURN em 75 s, PATROL em 105 s, depois troca de ponto a cada 30 s; S3 primeiro ponto inalcançável → pula. F3 e F4 pegas. | Antes: 140 s presos em RETURN. Ver N4 sobre o temporizador contar tempo, não progresso. |
| R4-04 | MÉDIO | **PARCIAL** (N1) | M9 em `copy2`: `FAIL test_firewall_sem_acesso_indireto`. M10: `FAIL test_firewall_sem_referencias_ao_jogador`. Dez burlas (seção 4.2): só b03 pega. | Ver N1. O commit diz que "as 4 burlas testadas reprovam": essas quatro passam, e nove outras passam também. |
| R4-05 | BAIXO | **RESOLVIDO** | Simulação do algoritmo novo (200 trechos de 10 s com alvos aleatórios): `min_total_pesos=0.502867 erro_max_soma_potencia=2.22e-16`. F5 pega por `test_meia_ameaca_e_depois_perseguicao`. | Potência constante também no meio da transição. |
| R4-06 | BAIXO | **RESOLVIDO** | Diff de `heard_noise.gd` (comentário com a condição sem perda). | Só documentação; o comportamento (estimativa = real sem perda) foi mantido e agora está descrito. |
| R4-07 | BAIXO | **RESOLVIDO** | `enemy_controller.gd:204` (`_hearing.drain()` em `reset_to`). F6 (sem o drain) pega por `test_reset_descarta_os_sons_pendentes`. | |
| R4-08 | BAIXO | **RESOLVIDO** | `COMPONENT_CONTRACTS.md:657` (§8.3 "API pública acrescentada na Fase 4"); `DATA_STRUCTURES.md` (+2 linhas); `GAME-013` reescrito (leitura do diff). | Conferido por existência e leitura, não por revisão de texto completa. |
| R4-09 | INFO | INFO aberto (GAME-014) | Pipeline: `runner ERROR_engine=16`, `runner-property ERROR_engine=1`, igual à revisão. | Não reprova. |
| R4-10 | INFO | ACEITO | M10 no modo padrão: `codigo=0`; no modo de arquitetura: reprova. | Decisão de F4; etapa `estatico` cobre. |
| R4-11 | INFO | INFO aberto (GAME-014) | `capture_screen.gd` sem alteração. | Seguro enquanto a tela estiver na cena do nível. |
| R4-12 | INFO | Status das F3 | Sem alteração nesta rodada. | R3-04 e R3-06 seguem resolvidos. |

---

## 3. Verificação de regressão e de pipeline

### 3.1 Pipeline oficial (`tools/run_tests.ps1`, 1 execução, `019a893`)

Saída completa em `C:\Users\crrob\AppData\Local\Temp\claude\revF4\pipeline2.txt`.

```
importacao       codigo=0  SCRIPT_ERROR=0 ERROR_engine=0   tempo_ms=3540  OK
estatico         RESUMO: total=10  passou=10  falhou=0  tempo_total_ms=4207   OK
runner           RESUMO: total=660 passou=660 falhou=0  tempo_total_ms=8414   ERROR_engine=16  OK
runner-property  RESUMO: total=208 passou=208 falhou=0  tempo_total_ms=176110 ERROR_engine=1   OK
runner-meta      RESUMO: total=26  passou=26  falhou=0  tempo_total_ms=13441  OK
Tempo total do pipeline: 208.89 s
RESULTADO DO PIPELINE: APROVADO (codigo de saida 0)
```

A etapa `estatico` passou de 9 para 10 testes (o da ARC-01 de acesso indireto). A suíte padrão ficou em 8,414 s (meta: menos de 10 s).

### 3.2 Repetições dos probes

- `exp_chase.gd` (R4-01): resultado na seção 2.
- `exp_return.gd` (R4-03): `EXP t=0.02 estado=3`, `EXP t=60.02 estado=0`, `EXP fim t=200.0 s estado_final=0 (RETURN=6)`.
- `exp_return2.gd` (R4-03, três cenários): ver seção 2.

---

## 4. Mutações e achados novos

### 4.1 Mutações (cópia de `game/` em `019a893`; original restaurado após cada uma)

Driver `mut2.py` (cópia `copy2`, espelho `pristine2` gerado por `git archive HEAD`). Modo `standard` = `--level=unit --level=integration --level=scenarios`; `architecture` = `--level=architecture --level=arc04`.

| Mutação | Modo | Resultado | Pega? |
|---|---|---|---|
| F1: confirmação sem teto (`enemy_brain.gd`) | standard | `total=660 passou=659 falhou=1` (`test_perseguicao_longa_perde_contato_em_1_5_s_com_um_grito`) | sim |
| F2: não zerar confirmação ao entrar em LOST | standard | `total=660 passou=660 falhou=0` | não (equivalente, ver seção 1) |
| F3: RETURN sem checagem de alcance | standard | `total=660 passou=659 falhou=1` (`test_return_inalcancavel_volta_a_patrulha`) | sim |
| F4: PATROL sem timeout de perna | standard | `total=660 passou=659 falhou=1` (`test_patrulha_passa_ao_ponto_seguinte_depois_do_tempo_limite`) | sim |
| F5: música sem normalização | standard | `total=660 passou=659 falhou=1` (`test_meia_ameaca_e_depois_perseguicao`) | sim |
| F6: `reset_to` sem drenar o sensor | standard | `total=660 passou=659 falhou=1` (`test_reset_descarta_os_sons_pendentes`) | sim |
| F7: observer sem `LightExposureProbe` | standard | `total=660 passou=659 falhou=1` (`test_observer_iluminado_a_8_m_e_visto`) | sim |
| M9: leitura de `&"player_body"` em `_build_batch` | architecture | `total=10 passou=9 falhou=1` (`test_firewall_sem_acesso_indireto`) | sim |
| M10: `var _leak_type: PlayerRoot` | architecture | `total=10 passou=9 falhou=1` (`test_firewall_sem_referencias_ao_jogador`) | sim |

Todas as mutações restauradas: `diff` do arquivo original e da cópia = iguais (verificado em M9 e M10).

### 4.2 Burlas ao ARC-01 novo (dez sondas, `components/enemy/zz_b*.gd`, modo `architecture`)

Saída: `RESUMO: total=10 passou=8 falhou=2`. A segunda falha é `arc04/test_arc04_parse.gd` (as sondas não compilam, o que não interessa aqui). A violação listada pelo teste de acesso indireto foi só uma: `zz_b03_eventbus_alias.gd identificador 'player_stress_changed'` (`obtido 1`).

| Burla | Descrição | Pega? |
|---|---|---|
| b01 | `get_tree().get_root()` (raiz via método, não `.root`) | não |
| b02 | `Engine.get_main_loop()` | não |
| b03 | alias `var _bus = EventBus` e uso de `player_stress_changed` | **sim** (pelo identificador, não pelo alias) |
| b04 | `get_node_or_null(NodePath("/root/EventBus"))` | não (o padrão só pega `"/` literal) |
| b05 | `get_tree().get_nodes_in_group(&"perceivable")` e leitura de `global_position` | não (o grupo está na lista permitida) |
| b06 | raycast com máscara `4` (camada do jogador) | não |
| b07 | constante maiúscula `AcousticWorld.PLAYER_SOURCE_ID` | não (o padrão é `Player` com P maiúsculo e `player` minúsculo) |
| b08 | `Engine.get_singleton("EventBus")` | não |
| b09 | `get_parent().get_node("Pla" + "yer")` (literal partido) | não |
| b10 | `get_parent().get_child(3)` (índice de irmão) | não |

### 4.3 Falsos positivos (código legítimo)

Três sondas (`zz_fp*.gd`) em `components/enemy/`:
- `zz_fp2_legitimo.gd` (`get_tree().get_nodes_in_group(&"perceivable")` e `EventBus.player_captured.emit(...)`): **passa**, correto.
- `zz_fp1_texto.gd` (`Log.warn(&"enemy", "perseguicao sem player visivel")`): **reprova** (`literal com player`).
- `zz_fp3_variavel.gd` (`var player_hint: Vector3`): **reprova** (`identificador 'player_hint'`), duas vezes.

Falso positivo é fail-closed (reprova sem ter acesso ao jogador). Não há hoje nenhum caso no código do repositório (pipeline 10/10). Ver N2.

### 4.4 Achados novos

| ID | Sev. | Arquivo:linha | Descrição | Evidência | Recomendação |
|---|---|---|---|---|---|
| N1 | **MÉDIO** | `game/tests/architecture/test_arc01_perception_firewall.gd:63-90` (`test_firewall_sem_acesso_indireto`) e `:40-42` (`TREE_ESCAPE`) | R4-04 fica parcial. A varredura nova ainda deixa passar nove das dez burlas da seção 4.2. A mais relevante é b05: o grupo `perceivable` está na lista permitida (`ALLOWED_GROUPS`), e nada proíbe ler `global_position` ou os métodos do `PerceivableTarget` diretamente. Isso é justamente o que FW-INV-1 proíbe (dado do jogador só pelos sensores). Hoje não há uso desse caminho no código (verificado por `grep`); a proteção restante é o AI-06 comportamental, que só pega se a leitura mudar a intenção. Também b06 (raycast na camada 4) e b01/b04 (raiz e caminho absoluto) passam. | Seção 4.2; `copy2` em `019a893`. | Proibir leitura de propriedades de `PerceivableTarget` e de nós por caminho/índice no firewall, em vez de só listar grupos. Tratar raycast com máscara que inclua a camada 3 (jogador) como acesso. Tratar `Engine.*`, `get_root()`, `get_child(n)` e `NodePath` absoluto como fora do escopo. Acrescentar b05 como mutação de meta-teste. |
| N2 | BAIXO | `test_arc01_perception_firewall.gd:31` (`ANY_CASE_PLAYER_LITERAL`) e `:28` (`LOWER_PLAYER_IDENTIFIER`) | Falsos positivos de código legítimo: qualquer texto com "player" (inclusive em mensagem de log) e qualquer variável `player_*` reprovam. Fail-closed, então não é brecha, mas o próximo a escrever uma mensagem de log na pasta da IA vai bater nisso. | Seção 4.3. | Documentar a convenção; ou restringir o literal a `"player"` e `"Player"` exatos como grupo/caminho, e não em texto livre. |
| N3 | INFO | `game/components/perception/light_exposure_probe.gd` (`TREE_ESCAPE_EXEMPT`); `game/content/enemies/observer.tscn` | A sonda de luz está na lista de exceção do acesso à raiz (`get_tree().root`, para achar luzes). Agora ela também está no Observer. Isso não dá ao inimigo nenhum dado do jogador (a sonda só coleta `Light3D`), mas o arquivo tem acesso à árvore inteira, e a exceção é por arquivo, não por uso. A sonda também passa a rodar no inimigo com o custo de R3-10 (percorre a árvore a cada nó criado), ainda não medido. | Diff de `observer.tscn`; leitura de `light_exposure_probe.gd:157`. | Abrir a exceção por método, não por arquivo; medir o custo da sonda no Observer (GAME-010, R3-10). |
| N4 | INFO | `game/sim/ai/enemy_brain.gd:396` (`_patrol_leg_s >= PATROL_LEG_TIMEOUT_S`) | O temporizador de perna conta tempo, não progresso. Um corpo parado 30 s (porta que não abre, trava na navmesh) pula o ponto mesmo com rota alcançável. Na sandbox não acontece no trajeto normal: as 8 pernas da rota têm no máximo 7,5 m em linha reta (`sandbox.tscn`, marcadores `PatrolPoint_00..07`), e 30 s a 1,2 m/s cobrem 36 m. | Cálculo a partir das posições dos marcadores. | Aceitar; se a rota crescer, medir o tempo por perna no playtest. |
| N5 | INFO | `game/sim/ai/enemy_brain.gd:300` (zeragem em `_enter`, LOST_CONTACT) | Mutação F2 (não zerar a confirmação ao entrar em LOST) é equivalente. Não é defeito: a zeragem é defensiva, e a linha fica redundante com o teto. | Seção 4.1. | Manter a linha e documentar que ela é redundante com o teto (ou remover e registrar). |

---

## 5. Orçamento de suíte

| Medida | Valor | Meta |
|---|---|---|
| Padrão (pipeline, `runner`) | 8 414 ms | menos de 10 s; OK |
| Padrão, em cópias de mutação (F1..F7, M9, M10) | 7 750 a 8 687 ms | OK |
| `estatico` | 4 207 ms (10 testes) | — |

---

## 6. Itens para o Director decidir

1. **N1 (MÉDIO, R4-04 parcial):** fechar as burlas da seção 4.2 (principalmente b05, leitura direta do `perceivable`) ou aceitar o risco com o AI-06 como rede final, registrado em KNOWN_ISSUES. Esta é a única ressalva que impede o APROVADO limpo.
2. **N2 (BAIXO):** decidir a convenção para texto com "player" e nomes de variável; hoje o falso positivo é certo para quem escrever esses textos na pasta da IA.
3. **N3 e N4 (INFO):** medir o custo da sonda no Observer (GAME-010), e registrar que o temporizador de perna conta tempo.

---

## Conclusão

As correções do R4-01 (o ALTO), do R4-02 e do R4-03 (os MÉDIO de comportamento), e dos BAIXO R4-05..R4-08 estão resolvidas e cobertas por testes que pegam a desfeita. O R4-01 foi reproduzido de novo: a perseguição sai em 1,50 s com um grito. Não há CRÍTICO nem ALTO em aberto.

O R4-04 (ARC-01) fica parcial. O endurecimento pega M9 e M10 e os falsos positivos passam no código real, mas nove de dez burlas novas continuam passando, a mais grave a leitura direta de `perceivable` (N1, MÉDIO). Resultado: **APROVADO COM RESSALVAS**.

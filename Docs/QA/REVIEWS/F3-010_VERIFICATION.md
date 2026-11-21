# Verificação focada F3-010 — correções da revisão

| Campo | Valor |
|---|---|
| Data | 2026-11-21 |
| Commit verificado | `6b84b40` (árvore limpa no início; `git status` vazio antes da verificação) |
| Base da revisão original | `5b5a82b` (revisão `Docs/QA/REVIEWS/F3-010.md`: APROVADO COM RESSALVAS, 0 CRÍTICO, 0 ALTO, 4 MÉDIO, 5 BAIXO, 5 INFO) |
| Escopo | R3-01..R3-14 (correções e decisões) + achados novos introduzidos pelas correções |
| Método | Leitura do diff `5b5a82b..6b84b40` (código, testes, contratos e documentos). Pipeline oficial rodado uma vez. Mutações pontuais numa cópia nova de `game/` (commit `6b84b40`) fora do repositório, com restauração após cada uma: M6, M7 e M9 pedidas, mais as que testam cada correção e as brechas que a correção pode ter aberto. |
| **Resultado** | **APROVADO COM RESSALVAS** |

Critério (mesmo da revisão original): REPROVADO se houver CRÍTICO ou ALTO em aberto; APROVADO COM RESSALVAS se houver só MÉDIO ou menor. Não há CRÍTICO nem ALTO em aberto. Há um MÉDIO aceito (R3-03, KNOWN_ISSUES GAME-009) e quatro achados novos, todos BAIXO ou INFO. Nenhum achado novo é MÉDIO.

---

## 1. Resumo

- **Todas as correções resolvem o achado original**, com uma ressalva em R3-02. Cada uma tem teste que falha quando a correção é desfeita (M6, M9, M10, M11, M13, M14, M15 e M16 reprovam pelo teste certo).
- **R3-02 fica parcial.** A trava do `NoiseEmitter` e a varredura nova pegam os casos pedidos. Duas brechas continuam: a porta tentando emitir som corporal é recusada em silêncio, sem teste que reprove (M7, N1); e a trava aceita qualquer fonte cujo id comece com `enemy` (M12, N2).
- **Nova brecha de R3-04 (N3).** O objeto que o jogador solta ou arremessa tem a causa "do jogador" até repousar, sem prazo. Um impacto causado por um inimigo antes do repouso não assusta o jogador. Um objeto que não repousa mantém a causa indefinidamente. A IA (F4) ouve normalmente, então o efeito fica restrito ao susto do jogador. Severidade BAIXO.
- **Pipeline oficial verde**: padrão 451/451 (7,693 s), propriedade 122/122, meta 26/26, `EXIT=0`. Os dois arquivos movidos para `tests/property/qa/` mantêm conteúdo (rename com 0 linhas alteradas).
- **Documentação**: §6.6 de COMPONENT_CONTRACTS cita as funções novas; GAME-009 e GAME-010 existem com gatilho de reabertura.

---

## 2. Tabela por achado da revisão original

Situação: RESOLVIDO / ACEITO / PARCIAL / INFO→F4. Os NOVO estão na seção 4.

| ID | Sev. orig. | Situação | Evidência (diff e mutação, saída real) | Comentário |
|---|---|---|---|---|
| R3-01 | MÉDIO | **RESOLVIDO** | `game/sim/acoustics/heard_noise.gd`: `from_propagation` (posição = `entry_point` + disco de raio `position_error_per_db_lost × (intensidade − percebido)`), `confidence_for` (clamp de `(percebido − limiar)/20` em [0,1; 1]) e `disk_offset` (`r = R·√u`, ângulo uniforme). Mutação M15 (`R·u` no lugar de `R·√u`): `test_heard_noise_estimativa.gd::test_disco_horizontal_uniforme_na_area` reprova (`total=4 passou=3 falhou=1`). | Funções puras, com o RNG do chamador (ARC-03 passou: `arquivos varridos em res://sim/: 23`). Ainda sem chamador de produção: quem usa é o HearingSensor da F4, como o plano previa. |
| R3-02 | MÉDIO | **PARCIAL** (ver N1 e N2) | Trava: `noise_emitter.gd` (`is_body_category` + recusa com `Log.error` quando `source_id` não começa com `enemy`). Mutação M10 (trava desligada): `test_noise_emitter_corpo.gd::test_porta_e_jogador_nao_emitem_som_do_corpo_pelo_noise_emitter` reprova (`total=5 passou=4 falhou=1`). Varredura: M9 (`NoiseEvent.new()` + `call("emit_noise")` numa porta, COUGHING) agora reprova `test_noi_inv_1_only_listed_scripts_emit_or_create_body_noise` (`total=1 passou=0 falhou=1`). M16 (`NoiseEvent.new()` de COUGHING do jogador dentro de `noise_emitter.gd`, antes da trava) reprova o teste da trava (`total=55 passou=53 falhou=2`). | A varredura e a trava pegam o que foram desenhadas para pegar. Não pegam M7 (N1) nem M12 (N2). |
| R3-03 | MÉDIO | **ACEITO** (KNOWN_ISSUES GAME-009) | Não houve correção de teto. O trovão ao ar livre caiu de +6 para +3,25 dB (efeito de R3-07), o que reduz a soma. Gatilho de reabertura registrado: limitador audível na escuta. | Decisão do Director, dentro do critério. Não verifiquei a audição (sem medição de áudio nesta verificação). |
| R3-04 | MÉDIO | **RESOLVIDO** (com N3 e N4) | `acoustic_world.gd`: `is_player_source` (`player` ou prefixo `player_`) usado em `_deliver_to_player` e em `_maybe_subtitle`. `throwable.gd`: `set_held(false)` troca o `source_id` para `player_thrown_<id>`; `set_held(true)` restaura o id; `_on_sleeping_state_changed` restaura ao repousar. Mutação M11 (filtro antigo, só `source_id == player`): `test_susto_por_som.gd::test_impacto_do_objeto_arremessado_pelo_jogador_nao_assusta` reprova (`total=8 passou=7 falhou=1`). | O impacto do próprio arremesso não assusta; o mesmo impacto sem causa assusta (o teste tem as duas partes). Repouso observado: o objeto dormiu depois de 61 ticks (`notas do pipeline`). Ver N3 para o caso sem repouso. |
| R3-05 | BAIXO | **RESOLVIDO** | `player_hold.gd:40-47`: `throw_held` chama `item.can_place_at(item.global_transform, _body)` e não arremessa se não couber. Mutação M13 (checagem retirada): `test_arremessavel.gd::test_arremessar_com_a_mao_dentro_de_parede_continua_segurando` reprova (`total=7 passou=6 falhou=1`). | Igual à soltura. Sem outro efeito: o jogador continua segurando e pode afastar-se da parede. |
| R3-06 | BAIXO | **RESOLVIDO** | `test_susto_por_som.gd::test_corrida_e_queda_do_proprio_jogador_nao_assustam`: 6 passadas de corrida e 1 queda pelos sinais reais do motor, com pré-condição de 7 eventos ≥ 60 dB. Mutação M6 (`FootNoise.source_id` = `footnoise`): reprova (`total=8 passou=7 falhou=1`). | Teste pega a regressão que antes passava (`total=6 passou=6`). |
| R3-07 | BAIXO | **RESOLVIDO** | `rain_ambience.gd:129-130`: `thunder_gain_for_floor` = `NoiseGain.gain_for_db(piso + AcousticWorld.THUNDER_OFFSET_DB)`. Ao ar livre: 58 dB → +3,25 dB; cômodo interno (22): 42 dB → −3 dB. Mutação M14 (fórmula antiga): `test_noise_selection.gd::test_thunder_gain_is_muffled_inside_rooms` reprova (`total=13 passou=12 falhou=1`). | O trovão agora soa no mesmo nível que o mascaramento que impõe. Efeito colateral positivo: o trovão ao ar livre não encosta mais no teto (+6), o que reduz a exposição de R3-03. |
| R3-08 | BAIXO | **RESOLVIDO** | COMPONENT_CONTRACTS §6.6 (linha 474, "API pública acrescentada na Fase 3 (revisão F3-010, R3-08) — v1.0"). Conferido por busca: `from_propagation`, `is_player_source`, `can_place_at`, `disk_offset`, `confidence_for`, `thunder_gain_for_floor`, `get_noise_source`, `is_player_caused`, `throw_held`, `is_closing`, `show_subtitle`, `layer_output_db`, `played_log` aparecem na seção. | Documentação alinhada. |
| R3-09 | BAIXO | **ACEITO** | Sem mudança no teste (`BRUTE_FORCE_MAX_PORTALS = 7`). Minha verificação independente cobriu até 25 portais (8 844 consultas, 0 divergências), registrada na F3-011 pelo Director. | Dentro do critério. |
| R3-10 | INFO | INFO→F4 | KNOWN_ISSUES GAME-010. | Sem alteração de código. |
| R3-11 | INFO | INFO→F4 | KNOWN_ISSUES GAME-010. | Sem alteração de código. |
| R3-12 | INFO | Acompanhado | Padrão agora: 451 testes em 7,693 s (soma dos testes) e 7,962 s na etapa; na revisão anterior: 446 testes em 8,865 s. A causa da diferença não foi investigada. | Dentro da meta de 10 s (ver seção 5). |
| R3-13 | INFO | F5 | Sem mudança. ERROR do engine na etapa property continua em 1. | Sem alteração. |
| R3-14 | INFO | INFO→F4 | KNOWN_ISSUES GAME-010. | Sem alteração de código. |

---

## 3. Verificação de regressão e de pipeline

Pipeline oficial (`tools/run_tests.ps1`, commit `6b84b40`, 1 execução, `EXIT=0`, 126,1 s). Saída completa em `scratchpad\f3010v2\pipeline_6b84b40.txt`:

```
importacao       codigo=0 SCRIPT_ERROR=0 ERROR_engine=0 tempo_ms=3248 -> OK
arc04            codigo=0 SCRIPT_ERROR=0 ERROR_engine=0 tempo_ms=2241 -> OK
runner           codigo=0 SCRIPT_ERROR=0 ERROR_engine=9 tempo_ms=7962 -> OK   (RESUMO total=451 passou=451 tempo_total_ms=7693)
runner-property  codigo=0 SCRIPT_ERROR=0 ERROR_engine=1 tempo_ms=99822 -> OK  (RESUMO total=122 passou=122 tempo_total_ms=99612)
runner-meta      codigo=0 SCRIPT_ERROR=0 ERROR_engine=0 tempo_ms=11922 -> OK  (RESUMO total=26 passou=26 tempo_total_ms=11659)
RESULTADO DO PIPELINE: APROVADO (codigo de saida 0)
```

ERROR do engine: 9 no padrão e 1 na propriedade, os mesmos da revisão anterior. Os 9 são os negativos declarados (`expect_engine_error`); o da propriedade é o aviso de recursos já registrado como R3-13. O novo `Log.error` da trava do `NoiseEmitter` não aparece como ERROR do engine (é `Log`, não `push_error`), e o teste que o provoca confere a recusa.

Arquitetura na saída: `arquivos varridos em res://sim/: 23` (ARC-03 passa com o código novo de `heard_noise.gd`).

Movimento de pastas: `test_f2011_audio_corpo.gd` e `test_f2011_bombinha_q.gd` foram para `tests/property/qa/` com rename 100% (0 linhas alteradas no diff). Contagens: padrão 446 → 451 e propriedade 117 → 122 (esta última com os +5 do movimento, conforme o commit). Não contei individualmente os testes movidos nem os novos.

---

## 4. Mutações e achados novos

### 4.1 Mutações (cópia de `game/` em `6b84b40`; original restaurado após cada uma)

| Mutação | Filtro / nível | Resultado | Pega? |
|---|---|---|---|
| M6: `FootNoise.source_id` = `footnoise` (passos e queda do próprio jogador) | `susto` / padrão | `total=8 passou=7 falhou=1` (`test_corrida_e_queda_do_proprio_jogador_nao_assustam`) | sim |
| M7: porta emite `COUGHING` pelo `NoiseEmitter` em `_begin_opening` | `noi_inv` / padrão | `total=1 passou=1 falhou=0` | **não** (N1) |
| M7b: a mesma M7 com o filtro de porta | `porta` / padrão | `total=31 passou=31 falhou=0` | **não** (N1) |
| M9: `NoiseEvent.new()` + `call("emit_noise")` numa porta, COUGHING | `noi_inv` / padrão | `total=1 passou=0 falhou=1` (`test_noi_inv_1_only_listed_scripts_emit_or_create_body_noise`) | sim |
| M10: trava do `NoiseEmitter` removida | `corpo` / padrão | `total=5 passou=4 falhou=1` (`test_porta_e_jogador_nao_emitem_som_do_corpo_pelo_noise_emitter`) | sim |
| M11: filtro antigo do ouvinte (só `source_id == player`) | `susto` / padrão | `total=8 passou=7 falhou=1` (`test_impacto_do_objeto_arremessado_pelo_jogador_nao_assusta`) | sim |
| M12: porta usa `source_id` = `enemy_porta` e emite `COUGHING` | `noi_inv` / padrão | `total=1 passou=1 falhou=0` | **não** (N2) |
| M13: `throw_held` sem `can_place_at` | `arremess` / padrão | `total=7 passou=6 falhou=1` (`test_arremessar_com_a_mao_dentro_de_parede_continua_segurando`) | sim |
| M14: fórmula antiga do trovão | `noise_selection` / padrão | `total=13 passou=12 falhou=1` (`test_thunder_gain_is_muffled_inside_rooms`) | sim |
| M15: raio `R·u` no disco de R3-01 | `estimativa` / padrão | `total=4 passou=3 falhou=1` (`test_disco_horizontal_uniforme_na_area`) | sim |
| M16: `NoiseEvent.new()` de COUGHING do jogador em `noise_emitter.gd`, antes da trava | `noi` / padrão | `total=55 passou=53 falhou=2` (`test_noise_emitter_corpo.gd`, 2 testes) | sim |

Notas:
- M6, M9, M10, M11, M13, M14 e M15 reprovam pelo teste que a correção pretendia cobrir. M16 foi pega por um teste da trava, por ter contado o evento indevido de `NoiseEmitter`. Ou seja, `noise_emitter.gd` na lista de confiáveis não é uma brecha prática.
- M7 e M12 não reprovam nada. Analisadas em N1 e N2.

### 4.2 Achados novos

**N1 — BAIXO — M7 é recusada em silêncio.** `game/components/world/door.gd:114` (`_begin_opening`) poderia emitir `COUGHING` pelo `NoiseEmitter`. A trava (`noise_emitter.gd`, `emit_noise`) recusa com `Log.error` e não emite evento, então o comportamento observável não muda e nenhum teste falha: a mutação passa em `noi_inv` e em `porta`. A varredura NOI-INV-1 não olha categoria em chamada de receptor declarado como `NoiseEmitter`. Efeito: uma chamada indevida na porta só aparece como linha de log, que o runner não reprova. Recomendação: teste que execute a porta e confirme que nenhum evento corporal foi recusado (conta de `Log.error` por categoria, ou um sinal de recusa), ou fazer a trava incrementar um contador que o teste confere.

**N2 — BAIXO — o prefixo `enemy` é a única condição da trava.** `noise_emitter.gd` (`emit_noise`) aceita categoria corporal de qualquer `source_id` que comece com `enemy`. M12 (porta com `source_id = enemy_porta` emitindo `COUGHING`) passa. O efeito é o que a F3 já prevê para `source_is_enemy` (COMPONENT §6.5, "convenção; rever na F4"): um som corporal de porta chega como de inimigo ao ouvinte do jogador (`PlayerHeardNoise.source_is_enemy = true`). Na F3 não há consequência audível relevante, mas na F4 isso mudaria a leitura de perseguição. Recomendação: trocar a convenção por um campo explícito de origem (ex.: `NoiseEmitter.is_enemy` exportado) ou pela lista de fontes inimigas declarada no nível, e registrar na F4.

**N3 — BAIXO — a causa "do jogador" não tem prazo, e vale também para impactos de inimigos.** `game/components/world/throwable.gd:127-131` (`_on_sleeping_state_changed`) só restaura a fonte própria quando o objeto repousa (`sleeping`) ou é pego de novo (`set_held(true)`). Consequências, por leitura do código (não há inimigo na F3 para exercitar):
- um objeto solto pelo jogador, que um inimigo derruba antes de repousar, gera impacto com `source_id` `player_thrown_<id>`; o ouvinte do jogador não recebe o evento (sem susto); a IA recebe normalmente, porque o HeardNoise não carrega a fonte. O custo é que o jogador não se assusta com esse impacto enquanto o objeto estiver acordado;
- um objeto que não repousa (apoiado em outro que se move, ou em pilha que não estabiliza) mantém a causa do jogador indefinidamente, e o jogador deixa de se assustar com qualquer impacto dele.
O primeiro caso é de baixo impacto. O segundo é uma assimetria sem limite. O repouso observado foi de 61 ticks no chão (`o objeto dormiu depois de 61 ticks`), então o caso comum é curto. Recomendação: um prazo independente do repouso (ex.: 3 s desde a última soltura ou impacto), e um teste de objeto que não repousa.

**N4 — INFO — prefixo `player_` aceito de qualquer id.** `acoustic_world.gd:26` e `is_player_source`: qualquer `source_id` que comece com `player_` é tratado como causado pelo jogador. Hoje só o Throwable usa o prefixo (`grep` nas fontes: sem outro uso). Um arremessável com `throwable_id` iniciado por `player_` no nível seria tratado assim. Recomendação: checar o formato exato (`player_thrown_` ou id de ator) ou validar o `throwable_id` na colocação do nível.

### 4.3 Cada correção resolve o achado?

- R3-01: sim. A estimativa existe em L1 e a função de uniformidade pega a mutação. A consumidora é a F4.
- R3-02: parcialmente (N1, N2). A trava recusa o som corporal de fonte não inimiga; a varredura pega `NoiseEvent.new(` e `"emit_noise"` como texto.
- R3-03: aceito, como decidido pelo Director. Reabrir se a escuta mostrar limitador audível.
- R3-04: sim, com N3 e N4 como consequências.
- R3-05: sim.
- R3-06: sim. O teste pega M6, que o anterior não pegava.
- R3-07: sim. Trovão no nível do mascaramento, com M14 pega.
- R3-08: sim. §6.6 cita as funções novas.
- R3-09: aceito.

---

## 5. Orçamento de suíte

Padrão: 451 testes em 7,693 s (7,962 s na etapa), abaixo da meta de 10 s. Propriedade: 122 em 99,6 s. Não medi o efeito isolado do movimento dos dois arquivos para a propriedade. Se um teste de cena inteira voltar à padrão, a meta de 10 s volta a ser o limite (R3-12).

---

## 6. Itens para o Director decidir

1. **N1 (BAIXO):** dar a M7 um teste que falhe (conta de recusas da trava ou sinal). Antes da F3-011 se for barato.
2. **N3 (BAIXO):** prazo para a causa "do jogador" (ex.: 3 s desde a última soltura ou impacto), além do repouso. Decidir se entra na F3-011 ou vai para GAME-010.
3. **N2 (BAIXO):** trocar a convenção `enemy` por campo explícito na F4, antes de o HearingSensor ler `source_is_enemy`.
4. **N4 (INFO):** validar o prefixo `player_` no nível ou no arremessável.

Nenhum desses itens bloqueia a F3-011 pela regra. Os itens 1 e 2 são baratos e tocam a mesma área das correções.

---

## Conclusão

As correções de F3-010 resolvem os achados MÉDIO e BAIXO, com as provas pedidas: cada uma é reprovada por um teste quando desfeita. R3-02 fica parcial, com duas brechas BAIXO (N1, N2). A correção de R3-04 abriu uma assimetria sem prazo (N3), de baixo impacto hoje e com teste de repouso já incluído. O pipeline oficial passa (451/451, 122/122, 26/26). Resultado: **APROVADO COM RESSALVAS**, com R3-03 aceito até o playtest e quatro achados novos, todos BAIXO ou INFO.

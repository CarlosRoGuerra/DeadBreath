# Verificação focada F1-010 — correções da revisão

| Campo | Valor |
|---|---|
| Data | 2026-11-20 |
| Commit verificado | `784360e` (árvore limpa no início; `git status` mostra só `Docs/Gameplay/` não rastreado, criado pela equipe às 13:31, fora do escopo) |
| Base da revisão original | `5bb160c` (revisão `Docs/QA/REVIEWS/F1-010.md`: REPROVADO, 2 ALTO) |
| Escopo | R1-01..R1-16 (correções) + achados novos introduzidos pelas correções |
| Método | Só leitura do repositório. Experimentos num projeto em cópia de `game/` fora do repositório, rodados de novo sobre o código novo, com os mesmos roteiros da revisão original. Linha de base A/B: commit `340dbb6` (antes das correções), extraído com `git archive` para diretório temporário. |
| **Resultado** | **APROVADO COM RESSALVAS** |

Critério (mesmo da revisão original): REPROVADO se houver CRÍTICO ou ALTO em aberto; APROVADO COM RESSALVAS se houver só MÉDIO ou menor. Não há CRÍTICO ou ALTO em aberto. Há um MÉDIO em aberto (R1-07, PARCIAL).

---

## 1. Resumo

- **Os dois ALTO estão resolvidos.** Varri o ciclo completo do passo com a minha própria varredura (que não usa os testes novos): escada sintética de 0,28 e 0,30 m e a escada da sandbox, subida e descida natural, com passo de 5 mm (116 + 72 fases), com grid fino de 1,7 mm (345 fases) e com subida em sprint (116 fases). Nenhuma fase tem tick sem chão nem `landed` espúrio. As fases que antes falhavam também passam isoladas.
- **A causa foi atacada, não só os casos testados.** O grid de 1,7 mm não coincide com o passo de 2,5 mm do próprio fix nem com o passo de 5 mm do teste da equipe.
- **Sem regressão de movimento** na bateria A/B (12 casos: plano, rampas 10/20/30°, degraus 0,29/0,30/0,31/0,35, queda de 1,5 m, bordas de 0,2 e 0,6 m, vão de 0,6 m rastejando). Os resultados são idênticos antes e depois, salvo o que a correção pretendia mudar.
- **Achados MÉDIO corrigidos:** R1-03 (câmera em rampa: erro em regime cai a zero), R1-04 (overlay acha o jogador na cena), R1-05 (NaN rejeitado), R1-06 (rebind inválido não grava nada). Verifiquei cada um com o experimento original.
- **Em aberto:** R1-07 (MÉDIO, PARCIAL: sintoma não reproduzido, causa não identificada), R1-09 (BAIXO, PARCIAL), R1-15 (BAIXO, PARCIAL). Achados novos, todos BAIXO: N1 a N4 (seção 4).

---

## 2. Tabela por achado da revisão original

Situação: RESOLVIDO / PARCIAL / NÃO RESOLVIDO. Os NOVO estão na seção 4.

| ID | Sev. orig. | Situação | Evidência (experimento novo, saída real) | Comentário |
|---|---|---|---|---|
| R1-01 | ALTO | **RESOLVIDO** | Ciclo completo (`exp2/game/exp_tests/test_sweep_full.gd`): piso 0,28 em 4 testes (fases 0–55) e piso 0,30 em 4 testes (0–59): `falhas=0` em todos. Sandbox (`test_sweep_sandbox.gd`, fases 0–71): `falhas=0` nos 4 testes. Grid fino 1,7 mm (`exp_tests4/test_fino_sprint.gd`): 0–164 e 0–179 fases por piso, `falhas=0`. Isoladas: `z0=-0.505` e `-0.545` passam (antes: subida 3 e 2 ticks). | Atacada a causa: a sondagem passou a `movimento + 0,03 m`, o pouso é limitado a `step_height` (`player_motor.gd:476-478`), e há avanço de 0,03 m na altura nova (`:478-479`). Ver também R1-02 para a descida. |
| R1-02 | ALTO | **RESOLVIDO** | Traço da fase 0,395 (piso 0,28), rodada isolada: descida `descida_no_ar=0`, `frames_descida=139`, `z_fim=-0.483` (antes: 16 ticks no ar, queda de 0,33 m). Varredura de descida natural (é a mesma varredura acima): `descida=0` em todas as fases. Com o grid fino: 0 ticks no ar e 0 `landed`. | Atacada por `_settle_on_ground` (`player_motor.gd:487-505`): após um tick que termina no ar, assenta o corpo no piso até `floor_snap_length` (0,30 m) abaixo. Descer em sprint não existe no jogo (sprint só para a frente), então não há caso de sprint na descida. |
| R1-03 | MÉDIO | **RESOLVIDO** (com ressalva de transitório) | Experimento de rampa, com bob desligado (`exp2/game/exp/exp_slope_nobob.gd`, `motion_reduction=1.0`): erro final de 0,00 m em todos os casos. Pico durante a subida: 10° 0,0 cm; 20° 0,8 cm; 30° andando 1,2 cm; 30° correndo **3,8 cm**; descida 30° 0,0 cm. Antes: até 18,7 cm, com erro em regime. Com o bob de fábrica (0,03 m) o pico aparenta ser maior porque o bob entra na medição. | Erro em regime eliminado. O pico de 3,8 cm ocorre na entrada da rampa em sprint, fora da janela de regime do teste da equipe (`test_camera_rampa.gd`, z ∈ [−6, −1]). Ressalva de R1-03; não é regressão, o erro não cresce mais com a velocidade. |
| R1-04 | MÉDIO | **RESOLVIDO** | Experimento na cena jogável (`exp2/game/exp/exp_overlay.gd`, sem `set_player`): `jogador encontrado na cena: true`; F3 `visivel: true`; `toggle_noclip (N) retorna: true`; texto: `fps: 1 frame: 16.67 ms \| postura: em pé \| marcha: parado \| ... \| noclip: ligado`. Antes: `get_player` nulo, texto "debug: sem jogador". | `get_player()` acha o jogador no grupo `player` (`debug_overlay.gd:40-47`). Teste novo `test_overlay_cena_jogavel.gd` existe. T (teleporte) devolve falso aqui porque a mira não atinge chão naquele ponto; isso não é defeito. |
| R1-05 | MÉDIO | **RESOLVIDO** (INF ver N2) | Experimento de Settings (`exp_settings_nan.gd`): `fov apos set_value(NAN): 75.0`; `mouse_sensitivity` 0,12; arquivo sem `nan`; recarregado com 75,0 e 0,12. Experimento de jogador (`exp_nan_player.gd`): `basis ... x=(0.996493, 0.0, 0.083678)`; `posicao apos 0.5 s andando: (0.043931, 0.0, -0.523159)`; `velocidade horizontal: 1.6`. Antes: base e posição `(nan, nan, nan)`. | `is_finite` antes do `clampf` (`settings.gd:99-104`). A correção vale também para `INF` (ver N2). |
| R1-06 | MÉDIO | **RESOLVIDO** | Experimento de rebind (`exp_bindings.gd`): tecla com `physical_keycode=0` → `status: invalid`; `interact depois: 1 evento(s)`; `overrides gravados: {  }`; `validate([])` → false. Botão 10 → `status: invalid`; `use_item` com 1 evento; nada gravado. Antes: `applied`, 0 eventos, `"interact": []` gravado. | `ControlsMenu.capture_event` valida antes (`controls_menu.gd:77-79`) e `rebind` devolve bool (`input_bindings.gd:77-80`). Lista vazia é inválida (`:98-101`). |
| R1-07 | MÉDIO | **PARCIAL** | Mesmo arranjo que reproduzia o problema (sandbox single antes da varredura, mesmo processo, sem flush): `exp2/game/exp_tests2`: as 3 fases da sandbox passam, e `ciclo_piso_028_a` passa com `falhas=0`, inclusive a fase 0,475 que antes falhava (`descida=16`). Isolada: 0,395 passa. | Sintoma não reproduz mais nesta configuração. A causa do GodotPhysics3D não foi identificada, então não sei se o sintoma sumiu por causa da correção do motor ou se ele só não aparece neste arranjo. O framework isola a física por teste (`add_isolated_world`, `release_and_flush`, flush de 2 frames) e há teste de regressão (`test_r107_historico_no_mundo.gd`). Pendência: investigar a causa antes da F4. |
| R1-08 | BAIXO | **RESOLVIDO** | Ramo de falha forçado (`exp2/game/exp/exp_log_holder.gd` + `exp_log_intruder.gd`, com diretório `game.prev.log` criado para o `rename` falhar): `game.log` com 64 linhas, inclui `A-linha-001` e `A-fim`; sem truncamento. | `log.gd:95-101`: se `rename` falhar, abre em `READ_WRITE` e `seek_end()`. Ver N4 quanto à remoção de `game.prev.log` antes do `rename`. |
| R1-09 | BAIXO | **PARCIAL** | O teste novo `test_escada_propriedade.gd` zera os contadores em `_phase` (linhas 40–43), e o `_run_range` reporta por fase. Mas o `test_escada_sem_chao.gd` (ainda na suíte padrão) não foi alterado (`git diff` vazio desde `340dbb6`): `_sweep` continua sem zerar `_airborne_*` (verificado por leitura). | Corrigido no teste novo; o antigo continua com a atribuição cumulativa. Corrigir ou remover o `_sweep` antigo (ele é superado pela propriedade). |
| R1-10 | BAIXO | **RESOLVIDO** (com NOVO N3) | Teste sem assert (`exp_tests5/test_a_zero.gd`): `FAIL ... (asserts: 0)`, mensagem "teste sem nenhum assert". Await parado (`test_b_parado.gd`): `FAIL ... sem progresso por 601 frames de fisica`. Teste lento (`test_c_lento.gd`, 2100 ms com `--wall-ms=1500`): `FAIL ... teto de tempo de parede de 1500 ms excedido`. | Watchdog agora conta frames (`harness_progress`, `test_case.gd:174-188`). O watchdog por progresso encerra a execução inteira; ver N3. |
| R1-11 | BAIXO | **RESOLVIDO** | Injeção em `sim/zz_injecao_arc03.gd` (cópia): `Engine.get_main_loop`, `ClassDB.instantiate`, `load(...)`, `call(...)`. ARC-03 reprova com `obtido 4`: `linha 4: get_main_loop; linha 5: ClassDB; linha 6: load; linha 7: call`. | Regras em `tests/architecture/l1_rules.gd`. Não injetei `get("...")` com string (a regra existe no código, `l1_rules.gd:18`). |
| R1-12 | BAIXO | **RESOLVIDO** | `COMPONENT_CONTRACTS.md` §3.1 (linhas adicionadas no diff) lista PlayerRoot, PlayerMotor, InteractionComponent, Door, Pickup, DebugOverlay, DebugCommands, PauseMenu, ControlsMenu e InputBindings. Conferi por amostra: `set_noclip`, `notify_teleported`, `interaction_failed`, `press_interact`, `Door.lock`, `InputBindings.rebind -> bool` estão no contrato e no código. | Documentação alinhada. |
| R1-13 | BAIXO | **RESOLVIDO** | `SYSTEM_ARCHITECTURE.md` §6: linha -90 com "**interação**" e decisão F1 registrada; `COMPONENT_CONTRACTS.md` §1 passo 6 (`interaction.step`). Código: `player_root.gd:40-47` roda a interação em -90. | Coerente. |
| R1-14 | BAIXO | **RESOLVIDO** | Pipeline (`verif_run1.txt`): uma linha `[ERROR] [level] vão de 1.20 m ... painel da porta tem 0.90 m` (é o caso negativo do teste `WideLevel`, esperado). As 8 portas da sandbox têm `opening_width_m = 0.9` (`sandbox.tscn:846-903`) e não geram erro. | Validação por `Log.error` (`level_slots.gd:61-62`), que é a alternativa que a revisão original aceitava. |
| R1-15 | BAIXO | **PARCIAL** | `KNOWN_ISSUES.md` GAME-001 registra a durabilidade sem fsync. Não há teste com o destino bloqueado (`test_atomic_file.gd` não mudou). | Documentado; o teste de falha de `rename` não foi acrescentado. |
| R1-16 | INFO | **RESOLVIDO** | `TEST_RESULTS.md`: seção "Cobertura pendente de fase" com ARC-01 (vacuidade), ARC-02 (parcial), ARC-07 (parcial), ACC-01 (só head bob), ACC-02..04 (sem cobertura). Conferido com o código: `effects_intensity` não é lido pelo motor. | Documentação alinhada. |
| R1-17 | INFO | aceito | — | Sem ação, como na revisão original. |

---

## 3. Verificação de regressão (correções de movimento)

Bateria A/B (`exp2/game/exp_tests4/test_regressao.gd`), mesma ordem e mesmo filtro em `340dbb6` (antes) e `784360e` (agora). Saída real, resumida:

| Caso | Antes (340dbb6) | Agora (784360e) |
|---|---|---|
| plano andando | ar=0, landed=0, andou | ar=0, landed=0, andou |
| rampa 10° / 20° / 30° (sobe e desce) | ar=0, landed=0 | ar=0, landed=0 |
| degrau 0,29 / 0,30 | sobe | sobe |
| degrau 0,31 / 0,35 | bloqueia | bloqueia |
| queda real de 1,5 m | landed=1, 5,390 m/s (esperado 5,422) | landed=1, 5,390 m/s |
| borda 0,6 m | landed=1, 3,430 m/s | landed=1, 3,430 m/s |
| borda 0,2 m | landed=1, 1,960 m/s | landed=1, 1,960 m/s (igual; não é regressão) |
| vão 0,6 m rastejando | passa | passa |

Resultado: 12/12 nos dois lados. A queda real continua disparando `landed` (1 evento, velocidade correta).

Grids de escada (todos sobre `784360e`): piso 0,28 com passo de 1,7 mm (80 + 85 fases) e piso 0,30 com passo de 1,7 mm (90 + 90 fases): 0 falhas. Subida em sprint, piso 0,28 (56 fases) e 0,30 (60 fases): 0 falhas.

---

## 4. Achados NOVOS introduzidos pelas correções

| ID | Sev. | Arquivo:linha | Descrição | Evidência | Recomendação |
|---|---|---|---|---|---|
| N1 | BAIXO | `game/tests/property/player/test_escada_propriedade.gd:152-153` e mais 7 ocorrências (`:158-159`, `:164-165`, `:170-171`, `:176-177`, `:182-183`, `:188-189`, `:194-195`) | Literal `assert_eq(f.size(), 0, "` com quebra de linha real dentro das aspas, seguida de `".join(f))`. O arquivo está gravado assim em `784360e`. O parser do Godot 4.7.2 aceita e a etapa property passa, mas é uma forma frágil: um formatador ou leitor estrito quebra a compilação. | Bytes verificados: `\n` literal aparece só nos 4 primeiros casos; 8 ocorrências de quebra real antes de `".join`. Etapa `runner-property` passa 13/13 (`verif_run1.txt`). | Restaurar a sequência de escape `"\n".join(f)` nas 8 ocorrências. |
| N2 | BAIXO | `game/autoload/settings.gd:99-104` | Com a correção, `INF` é rejeitado (com `Log.warn`), não limitado à faixa. DATA_STRUCTURES §10 diz que número fora da faixa é limitado. Medido: `subtitles_size apos set_value(INF): 1.0` (padrão), antes era `2.0`. | Experimento `exp_settings_nan.gd`. | Limitar `±INF` à faixa e rejeitar só `NaN`; ou atualizar §10 para dizer que INF é rejeitado. |
| N3 | BAIXO | `game/tests/run_all.gd` (watchdog por progresso) | Um teste parado encerra a execução inteira. Os testes restantes não rodam e não aparecem no resumo, embora a saída tenha código 1. Medido: com 3 testes (`test_a_zero`, `test_b_parado`, `test_c_lento`), só 2 foram listados; `test_c_lento` não rodou. | `exp_tests5` (saída em `scratchpad\r10_out.txt`). | Ao disparar o watchdog, listar os testes não executados como `NAO EXECUTADO` no resumo. |
| N4 | BAIXO | `game/autoload/log.gd:92-95` | `remove_absolute(prev)` ainda ocorre antes do `rename`. Se o `rename` falhar com `prev` existente, o log da sessão anterior é apagado e o atual passa a ser anexado. Verificado por leitura; o experimento forçado usou `prev` como diretório (`file_exists` falso), então este caminho não foi exercido. | Leitura de `log.gd:92-101`. | Renomear `prev` para um nome com timestamp, ou só remover `prev` depois do `rename` bem-sucedido. |

Observações que não são achados novos: `DebugOverlay.get_player()` passou a procurar no grupo mesmo em produção, mas o overlay e os comandos continuam recusados por `DebugCommands.is_allowed()`; não há regressão. O desligamento de `_settle_on_ground` quando a escada perde o chão é intencional e não mudou o caso da borda de 0,2 m.

---

## 5. Ressalvas e o que não está RESOLVIDO

- **R1-07 (MÉDIO, PARCIAL):** sintoma não reproduzido com a configuração original; causa do estado residual do GodotPhysics3D não identificada.
- **R1-09 (BAIXO, PARCIAL):** `test_escada_sem_chao.gd::_sweep` ainda acumula contadores entre fases.
- **R1-15 (BAIXO, PARCIAL):** sem teste de falha de `rename` com destino bloqueado.
- **R1-03 (ressalva):** pico transitório de 3,8 cm na entrada da rampa em sprint, fora da janela de regime do teste da equipe.
- **N1 a N4 (BAIXO):** ver seção 4.

---

## 6. Correção de minha própria revisão

Na revisão original escrevi que a escada da sandbox tinha ciclo de 0,35 m. Isso veio das constantes antigas do teste de escada (2,1 m dividido por 6). O ciclo real é 0,28 m (`tools/level/gen_sandbox.py`, `STAIR_TREAD = 0.28`), e a fixture nova (`stair_cycle.gd`) está correta. As contagens de falhas por fase continuam valendo, porque foram medidas diretamente. A fração de falha que eu citei (6 de 72) não é uma fração de ciclo e deve ser lida só como número de fases.

---

## 7. Saídas reais (resumo)

Pipeline oficial no commit `784360e` (`tools/run_tests.ps1`, `APPDATA` isolado, `EXIT=0`, saída em `scratchpad\verif_run1.txt`):

```
importacao        codigo=0 SCRIPT_ERROR=0 ERROR_engine=0 -> OK
arc04             PASS test_todos_os_scripts_compilam (asserts: 2)   RESUMO: total=1 passou=1
runner            RESUMO: total=133 passou=133 falhou=0 sem_assert=0  codigo=0 ERROR_engine=1 -> OK
runner-property   RESUMO: total=13 passou=13 falhou=0 sem_assert=0   codigo=0 -> OK
runner-meta       RESUMO: total=26 passou=26 falhou=0 sem_assert=0   codigo=0 -> OK
RESULTADO DO PIPELINE: APROVADO (codigo de saida 0)
```

Varreduras da verificação (`exp2/game/exp_tests`, comando `--root=res://exp_tests --filter=ciclo`): `RESUMO: total=12 passou=12 falhou=0 sem_assert=0`.

Fases isoladas e histórico (`exp2/game/exp_tests3`): `RESUMO: total=7 passou=7 falhou=0`, inclusive `test_trace_028_fase_395` com `descida_no_ar=0`.

Bateria A/B: 12/12 em `784360e` e 12/12 em `340dbb6`, com os mesmos números (seção 3).

Arquivos de experimento (fora do repositório): `C:\Users\crrob\AppData\Local\Temp\claude\719382d52c74f652\0492a466-b7ea-4ad4-afc8-9754b2365002\scratchpad\exp2\game\exp_tests\test_sweep_full.gd`, `...\exp2\game\exp_tests\test_sweep_sandbox.gd`, `...\exp2\game\exp_tests4\test_fino_sprint.gd`, `...\exp2\game\exp_tests4\test_regressao.gd`, `...\exp2\game\exp\exp_slope_nobob.gd`, `...\exp2\game\exp\exp_overlay.gd`, `...\exp2\game\exp\exp_bindings.gd`, `...\exp2\game\exp\exp_settings_nan.gd`, `...\exp2\game\exp\exp_nan_player.gd`, `...\exp2\game\exp_tests5\` (watchdog e teste sem assert).

---

## 8. Processos e repositório

- Nenhum processo de experimento meu ficou aberto (verificado no fim da revisão). As janelas do outro agente não foram tocadas. Não havia nenhum processo Godot ativo quando comecei esta rodada.
- Nenhum arquivo do repositório foi alterado por mim. Não usei escrita no git (só `status`, `log`, `diff`, `rev-parse` e `archive` para extrair o commit antigo para um diretório temporário).
- Este relatório é o único arquivo novo que criei no repositório.

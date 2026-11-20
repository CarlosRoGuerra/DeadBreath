# Validação independente da Fase 1 — F1-011

| Campo | Valor |
|---|---|
| Data | 2026-11-20 (terceira rodada: correção da porta pelo Gameplay Engineer, regras do Director) |
| Responsável | QA Engineer (contexto novo; não implementou nada da F1) |
| Base | commit `dcb58b9` (`main`) **mais a árvore de trabalho atual, sem commit** (correções de BUG-004/005/006/009, painel de 2,0 m, comentários da planta, teste de portas do Gameplay). Os testes rodaram contra os arquivos atuais |
| Ambiente | Windows 11, Godot 4.7.2.stable.official (`D:\DevTools\Godot\4.7.2`), GodotPhysics3D, 60 Hz, `--fixed-fps 60` |
| Regras da porta (Director) | (1) a porta só para por corpos móveis (camadas 2, 3 e 4); geometria estática não bloqueia o giro, e o arco livre é responsabilidade do level design. (2) o painel avança só com folga de 2 cm do corpo. (3) bloqueio contínuo emite `blocked` uma vez; liberação = `is_blocked() == false` |

## 1. Veredito final

**APROVADO COM RESSALVAS**, condicionado a uma decisão sobre o BUG-010.

- Nenhum defeito ALTO ou CRÍTICO em aberto. O BUG-009 (ALTO) está fechado: sem corpo no arco, as portas de passagem abrem por inteiro. O BUG-006 (MÉDIO) está fechado: nem toque nem segurar empurram o corpo.
- Defeitos abertos, ambos BAIXO: **BUG-010** (a porta oscila na saída do arco e emite `blocked` duas vezes) e **BUG-011** (level design: o eixo do painel entra até ~2,5 cm no volume do batente, oculto, sem brecha e sem efeito visual).
- **Pipeline: REPROVADO nas duas execuções** (código 1). A única falha é o teste que reproduz o BUG-010 (`test_porta_sala_corredor_corpo_entra_no_arco_no_meio_da_abertura`, asserção "emite blocked uma vez"). Todo o resto passa.
- **Condição para o gate da F1**: o Director decide entre (a) corrigir o BUG-010 (QA recomenda histerese na liberação; ver §4.5), ou (b) aceitar formalmente o comportamento e ajustar a regra 3 para permitir uma nova emissão após liberação real. Sem uma das duas, a suíte padrão do pipeline não fica verde.
- Ressalvas que permanecem: BUG-008 aceito (reavaliar na F7); BUG-011 para o level design; ARC-07 pendente (F2); causa raiz do BUG-004 em aberto (dívida técnica); etapa padrão do runner em 8,6 a 8,9 s (abaixo de 10 s, com pouca margem).

## 2. O que mudou nesta rodada

- Teste de porta (b1) trocado conforme a decisão do Director: depois de sair do arco, `assert_false(door.is_blocked())` (liberação observada). (b2) mantido (≥ 85°). Passa: 4 de 4 em `test_f1011_exploits_portas.gd`.
- Novo arquivo de experimentos: `game/tests/property/qa/test_f1011_portas_quatro.gd` (10 testes): as quatro portas da sandbox, toque e segurar, com e sem corpo no arco, corpo entrando no arco no meio da abertura, medição de intrusão no batente, brecha no encontro painel-batente e caixa estática no arco.
- Teste de integração do Gameplay Engineer (`integration/interaction/test_portas_sandbox.gd`, 17 asserções): passa.

## 3. Matriz de critérios de aceitação (cards F1)

Legenda: **atende** · **atende com ressalva** · **parcial** · **não atende** · **não avaliado**.

| Card | Critérios do TASK_BOARD | Resultado | Evidência |
|---|---|---|---|
| F1-001 | `git status` limpo após o commit inicial; `.godot/` ignorado | **atende** (`.godot/` ignorado; os artefatos de QA não estão commitados) | `git check-ignore -v game/.godot/` |
| F1-002 | `godot.ps1 --version` imprime 4.7.2; caminho errado falha | **atende** (imprime `4.7.2.stable.official.ed1daf0bf`; caminho inexistente → código 2) | execução do QA |
| F1-003 | Importação headless sem erros; input map completo; ARC-04 verde | **atende** | `F1-011_suite_final_3.txt`, `_4.txt` |
| F1-004 | Settings sobrevivem a reiniciar; log grava arquivo; EventBus só payloads nativos; escrita atômica | **atende** (reinício real: `fov`, sensibilidade, inverter Y, legenda e remapeamento voltam em outro processo; `user://logs/game.log`; `test_atomic_file` e `test_save_service` passam) | `F1-011_persist_write.txt`, `F1-011_persist_read.txt` |
| F1-005 | Teste propositalmente falho → código 1; resumo com nome, status e tempo; suíte da F1 < 10 s; ARC-02 e ARC-07 pendentes | **atende com ressalva**. Meta 26/26; resumo ok; etapa padrão **8,6 a 8,9 s** (abaixo de 10 s, pouca margem). ARC-02 parcial (persist_id único nos slots da sandbox; grupo `saveable` é da F5). ARC-07 **não atende** (o próprio card declara pendente para F2) | `F1-011_suite_final_3.txt`, `_4.txt` |
| F1-006 | MOT-01..04; ARC-06; step-up e escada sem chão | **atende com ressalva** (BUG-004 fechado pelo contorno; causa raiz não identificada, dívida registrada) | `F1-011_suite_final_*`; `F1-011_v3_verificacao.txt` |
| F1-007 | Porta lenta ao segurar e rápida ao tocar; trancada dá feedback; pickup some e emite evento; sem interação através de paredes | **atende com ressalva**. Toque e segurar abrem a porta por inteiro sem corpo (90°); com corpo no arco, param sem empurrar e completam ao sair; trancada dá feedback; **0 vazamentos em 1076 raios**; pickup atrás da porta trancada não é alcançado. Ressalva: BUG-010 (oscilação na saída, BAIXO) | `F1-011_v4_portas.txt`; `F1-011_v5_portas_quatro.txt`; `F1-011_suite_final_3.txt`, `_4.txt` |
| F1-008 | Flag de produção desliga overlay e comandos | **atende**. Build de debug: F3, N e T funcionam. Com `-- --production`: nada funciona, e as chamadas diretas da API devolvem `false` | `F1-011_probe_debug_normal.txt`, `F1-011_probe_debug_production.txt` |
| F1-009 | Mecânicas da F1 exercitáveis na sandbox; screenshot por script com janela | **atende com ressalva**: escada, mesa, vãos, pickups, superfícies e portas exercitados. Ressalva: BUG-011 (encontro painel-batente, level design). Planta documentada (BUG-007 fechado) | `F1-011_captura_*.png` |
| F1-010 | Revisão da F1 com achados classificados | **não avaliado diretamente** (fora do escopo do QA). R1-01, R1-02 e R1-03 verificados (BUG-001..003 fechados) | §4.6 |
| F1-013 | ACC-05: remapear, reiniciar, persiste; conflito avisado e não aplicado | **atende com ressalva** (BUG-008 aceito pelo Director). Persistência entre processos OK; conflitos recusados; tecla sem código e botão 10 recusados; Esc cancela | `F1-011_persist_read.txt`; `F1-011_exp_remap_run1.txt` |
| F1-014 | `ASSET_LICENSES.md` criado; regra no checklist do revisor | **atende** (7 entradas CC0; checklist de licenças em AGENT_ASSIGNMENTS §2) | `ASSET_LICENSES.md` |

### 3.1 Critérios de TEST_PLAN usados pela F1

| ID | Resultado | Onde |
|---|---|---|
| MOT-01 | atende | `integration/player/test_mot01_low_ceiling.gd`; QA: `property/qa/test_f1011_exploits_geometria.gd` |
| MOT-02, MOT-03 | atende | `unit/player/test_mot02_exertion.gd`, `test_mot03_limits.gd` |
| MOT-04 | atende | `scenarios/test_mot04_sandbox.gd`, `scenarios/test_mot04_route.gd` |
| ACC-01 | parcial (só head bob nesta fase; CameraEffects é F2) | — |
| ACC-05 | atende | `integration/input/test_acc05_remap.gd`; QA: `integration/qa/test_f1011_remap.gd` (6 testes) |
| ACC-06 | atende | `unit/autoload/test_settings.gd`; reinício real (5 chaves) em `F1-011_persist_read.txt` |
| PER-09 | atende | `unit/core/test_atomic_file.gd`, `integration/autoload/test_save_service.gd` |
| ARC-01, 03, 04, 05, 06 | atende | `architecture/*` |
| ARC-02 | parcial | `integration/world/test_level_slots.gd` (ids únicos na sandbox) |
| ARC-07 | não atende (pendente, F2) | — |

## 4. Verificação das correções

### 4.1 BUG-004 (canto de pilar prende): fechado, com contorno

- Reprodução original: após 240 ticks no canto NE do hall (rastejando) e reversão diagonal, o corpo ficava parado 300 ticks. Agora anda **2,491 m em 300 ticks**.
- Cantos (6): sala SO, sala NO, hall SE, cozinha NE e cozinha SE afastam **2,293 m** (mínimo 1,920); hall NE sob o mezanino, rastejando, afasta **0,724 m** (mínimo 0,600). Sem penetração e sem ar.
- **Efeitos colaterais do contorno** (empurrões contra a parede norte da sala, 11 casos: em pé andando, em pé correndo, agachado e rastejando, em 0°, 30° e 60°): penetração 0; ar 0; `landed` 0; altura do corpo varia no máximo **1 mm** depois de assentar; erro da câmera **0,0000 m**; `footstep` dentro do limite coerente com o deslocamento. Empurrões oblíquos deslizam ao longo da parede (até 1,5 m, correndo a 30°): movimento legítimo.
- Escada com parede lateral (6 degraus): altura final sempre uma altura de degrau, sem penetração, ar ou `landed`.
- **Dívida técnica**: a causa raiz não foi identificada. O contorno está verificado, mas pode esconder outro problema de física; investigar antes da F2.

### 4.2 BUG-005 (segurar com pausa): fechado

Segurar E, abrir o menu, soltar E com o menu aberto, continuar e esperar 90 ticks: `interaction_failed` emitido **1 vez**, porta **CLOSED**, nenhuma abertura, nada segurando. Aperto durante a pausa é ignorado. Depois da pausa, um toque abre a porta rápido. 6 de 6 testes de interação passam.

### 4.3 BUG-006 (painel empurra o corpo): fechado

Experimentos do QA nas portas da sandbox jogável (corpo parado no arco, depois de sair):

| Porta | Entrada | Para em | Deslocamento do corpo | `blocked` | Penetração | Depois de sair |
|---|---|---|---|---|---|---|
| `door_sala_corredor` | toque | 12,9° a 17,1° | **0,0000 m** | 1 | 0 | 90° |
| `door_sala_corredor` | segurar | 15,9° | **0,0000 m** | 1 | 0 | 90° |
| `door_corredor_hall` | toque | 12,9° | **0,0000 m** | 1 | 0 | 90° |
| `door_corredor_hall` | segurar | 15,9° | **0,0000 m** | 1 | 0 | 90° |

Antes da correção: o segurar deslocava o corpo 7,6 cm (ticks alternados livre/bloqueado). Com a folga de 2 cm (regra 2), o tick alternado não acontece mais.

### 4.4 BUG-009 (porta de passagem parava em 27°): fechado

| Porta | Sem corpo no arco | Resultado |
|---|---|---|
| `door_sala_corredor` | toque | 90°, sem `blocked` |
| `door_sala_corredor` | segurar | 90°, sem `blocked` |
| `door_corredor_hall` | toque | 90° |
| `door_corredor_hall` | segurar | 90° |
| `door_sala_cozinha` (aberta no início) | — | estado OPEN, zero `blocked` |
| `door_cozinha_corredor` (trancada) | toque | `locked_feedback` uma vez, estado LOCKED, nada se move |

Experimento com caixa estática no arco (consequência da regra 1): a porta completa 90° e o painel passa por dentro da caixa. Comportamento aceito pelo Director como responsabilidade do level design.

### 4.5 BUG-010 (oscilação na saída): aberto, BAIXO

Corpo entrando no arco no meio da abertura lenta (segurar): começa em x = 7,3, anda 25 ticks para dentro do arco e fica parado. A porta para em 47,8°, sem deslocar o corpo, e completa 90° depois que o corpo sai. Mas na saída, tick a tick (`F1-011_diag_blocked_duplo.txt`):

- tick 228: porta **liberada** (corpo em x = 6,959; porta em 48,8°);
- tick 229: porta **bloqueada de novo** (corpo em 6,970; porta em 48,8°);
- tick 230: liberada outra vez (49,7°).

Causa provável: sem histerese. Quando a folga de 2 cm libera o avanço, o painel dá um passo (~1 cm por tick na abertura lenta), e no tick seguinte o corpo ainda está dentro da folga. Efeito: `blocked` emitido duas vezes, e `is_blocked()` oscila. O corpo não se desloca nem penetra. Não é brecha. Recomendação do QA: histerese (liberar só com folga maior que o passo do tick). Decisão do Director (ver §1).

Observação de interpretação: pela letra da regra 3, a liberação seguida de um novo bloqueio pode ser vista como um novo contato. O QA considera a oscilação de um tick como defeito, porque o contato não foi realmente desfeito. Se o Director aceitar a outra leitura, o teste deve ser ajustado para aceitar uma nova emissão somente após liberação estável.

### 4.6 BUG-011 (encontro painel-batente): aberto, BAIXO (level design)

Consequência da regra 1. O eixo do painel está no plano do batente. Medido (bisseção; encolhimento da caixa do painel que libera a sobreposição com o batente estático):

| Ângulo | 0° | 10° | 20° | 27° | 35° | 45° | 60° | 75° | 90° |
|---|---|---|---|---|---|---|---|---|---|
| Intrusão | 0 mm | 4,5 mm | 8,0 mm | 10,1 mm | 12,4 mm | 15,0 mm | 19,0 mm | 23,7 mm | ≥ 25 mm (limite da busca) |

- **Não são milímetros, são centímetros.** Mas a sobreposição fica dentro do volume da parede: não é brecha de passagem (teste `test_brecha_no_encontro_do_painel_com_o_batente_nao_existe`: nenhum corpo atravessa o trecho de parede estática com o painel em 0°, 15°, 27°, 45°, 60° e 90°), não tem efeito de colisão (o corpo não alcança o volume) e não aparece nas capturas.
- Capturas com janela, porta aberta a 90°, vista da sala: `F1-011_captura_dobradica_90_nivel_olhos.png` (ao nível dos olhos) e `F1-011_captura_dobradica_90_chao.png` (inclinada para o chão). Sem fresta, sem z-fighting e sem quina visível.
- Classificação: **BAIXO, level design**. Correção recomendada: alinhar o eixo à face do batente ou recortar o batente no vão; revisar os dois vãos de passagem.

### 4.7 BUG-007 (comentários da planta): fechado

Regenerei `sandbox.tscn` com `tools/level/gen_sandbox.py` num arquivo do scratchpad (sem gravar no repositório). O conteúdo é **idêntico** ao da cena commitada (ignorando fim de linha). Os comentários de `MEZZ_TOP` (1,08 m) e `MEZZ_Z1` (−2,68) batem com os cálculos.

### 4.8 BUG-008 (clique na captura): aceito pelo Director

### 4.9 BUG-001, 002 e 003: continuam fechados

Reconfirmados depois das mudanças de motor e de porta: escadas 15 de 15 passam; câmera em rampa 8 de 8 passam (pior erro 7,1 mm).

### 4.10 Limites deste experimento de porta

- Entrada no meio da abertura só foi feita com segurar (abertura lenta, 1,6 s). Com toque (0,35 s), a porta completa antes de o corpo chegar ao arco; por isso o cenário não se aplica ao toque.
- O deslize do corpo ao longo do painel parcial (que numa rodada anterior produziu 1 tick de penetração de 1 cm) não está no teste final.

## 5. Defeitos

| ID | Severidade | Estado | Resumo |
|---|---|---|---|
| BUG-004 | MÉDIO | **FECHADO** (contorno verificado; causa raiz aberta) | Canto de pilar prende a diagonal com a tecla apertada |
| BUG-005 | MÉDIO (ALTO antes da F3) | **FECHADO** | Segurar com pausa deixava a porta abrir devagar sem a tecla |
| BUG-006 | MÉDIO | **FECHADO** | Painel empurrava o corpo ao abrir devagar (7,6 cm) |
| BUG-007 | BAIXO | **FECHADO** | Comentários da planta (correção do Director conferida) |
| BUG-008 | BAIXO (UX) | **ACEITO** pelo Director (reavaliar na F7) | Clique do mouse durante a captura grava a ligação |
| BUG-009 | ALTO | **FECHADO** | Portas de passagem paravam em 27° sem corpo no arco (regressão da checagem de bloqueio) |
| BUG-010 | BAIXO | **ABERTO** (decisão do Director pendente; reprova o pipeline) | Oscilação na saída do arco: `blocked` emitido duas vezes |
| BUG-011 | BAIXO (level design) | **ABERTO** | Eixo do painel entra até ~2,5 cm no volume do batente, oculto; sem brecha |

Registro completo em `Docs/QA/BUG_REPORTS.md`.

## 6. Tentativas de exploit

Legenda: **passou** = o exploit não quebrou o jogo; **quebrou** = o exploit gerou defeito.

| # | Tentativa | Resultado | Evidência |
|---|---|---|---|
| E1 | Cantos SO e NO da sala, SE do hall, cozinha NE e SE: andar contra o canto e voltar | **passou** (afastam 2,293 m; penetração 0) | `F1-011_suite_final_3.txt`, `_4.txt` |
| E2 | Canto NE do hall, sob o mezanino, rastejando; reversão diagonal sem soltar a tecla (240 + 300 ticks) | **passou** (antes: **quebrou**, BUG-004; agora anda 2,491 m) | idem |
| E3 | Pilares do mezanino (0,2 m), rastejando, 4 aproximações | **passou** (penetração 0) | idem |
| E4 | Vão aberto da cozinha (0,9 m): 5 posições × em pé, agachado e rastejando | **passou** (15 de 15) | idem |
| E5 | Sob a mesa de 0,6 m: entrar rastejando e spam de postura por 240 ticks | **passou** (0 postura errada, 0 penetração) | idem |
| E6 | Sob o mezanino de 1,02 m: agachado e correndo são barrados; rastejando entra e fica rastejando com spam | **passou** | idem |
| E7 | Entrada do vão correndo com spam de agachar e rastejar (300 ticks) | **passou** | idem |
| E8 | Spam de postura em espaço aberto (600 ticks) | **passou** (0 ar, 0 landed, 0 penetração) | idem |
| E9 | Parado na borda do mezanino com spam de postura (300 ticks) | **passou** (queda 0) | idem |
| E10 | Entrada pela borda da escada (x = 16,3; 16,45; 17,55; 17,7) | **passou** (guarda bloqueia sem queda; recentrar e subir chega ao topo) | `F1-011_exp_bug001_002_run2.txt` |
| E11 | Encostar de lado na face de degrau de 0,72 m | **passou** (para antes; sem penetração) | idem |
| E12 | Empurrões contra parede (11 casos: 4 posturas × 3 ângulos) | **passou** (sem penetração, ar ou landed; altura ≤ 1 mm; câmera 0 m; footsteps coerentes) | `F1-011_suite_final_3.txt`, `_4.txt` |
| E13 | Escada com parede lateral, empurrão de lado em cada um dos 6 degraus | **passou** (altura final sempre de degrau; sem penetração ou ar) | idem |
| E14 | Porta com o corpo no arco, **toque** | **passou**: para no arco (12,9° a 17,1°), 0 m de deslocamento, 0 penetração, completa 90° depois de sair. Antes: quebrou (BUG-009 e BUG-006) | `F1-011_v4_portas.txt`; `F1-011_v5_portas_quatro.txt` |
| E15 | Porta com o corpo no arco, **segurando** | **passou**: para em 15,9°, 0 m de deslocamento, completa 90°. Antes: quebrou (BUG-006: 7,6 cm). Ressalva: o `blocked` repetido aparece no cenário de entrada no meio (E29) | `F1-011_v4_portas.txt` |
| E16 | Porta de passagem **sem corpo por perto** (toque e segurar, sala-corredor e corredor-hall) | **passou** (90° nas quatro). Antes: quebrou (BUG-009, parava em 27°) | `F1-011_v5_portas_quatro.txt`; `F1-011_v5_caixa.txt` |
| E17 | Porta parcial (parada no arco) com o corpo encostado e parado 60 ticks | **passou** (sem penetração, sem deslocamento, primeiro bloqueio é o jogador) | `F1-011_suite_final_*` |
| E18 | Painel aberto como parede: andar contra ele | **passou** (para em z = −1,05; penetração 0) | idem |
| E19 | Porta fechada com spam de postura (300 ticks) | **passou** (para em x = 6,28; penetração 0) | idem |
| E20 | Interação através de paredes e portas fechadas: 1076 raios em 4 pares de salas e na parede externa | **passou** (0 vazamentos; 124 pelo vão aberto, legítimos) | `F1-011_v2_interacao.txt` |
| E21 | Mira no pickup da cozinha através da porta trancada | **passou** (a mira acerta a porta; nenhum item apanhado) | idem |
| E22 | Segurar E, abrir a pausa, soltar E com o menu aberto, continuar | **passou** (antes: **quebrou**, BUG-005). Cancela, porta CLOSED | `F1-011_v2_interacao.txt` |
| E23 | Aperto de E durante a pausa | **passou** (ignorado) | idem |
| E24 | Toque logo depois da pausa | **passou** (abre rápido) | idem |
| E25 | `--production`: F3, N, T e chamadas diretas da API | **passou** (desligados) | `F1-011_probe_debug_production.txt` |
| E26 | Remapeamento: tecla sem código, botão 10, conflito com pausa e com `interact`, Esc | **passou** (todas recusadas ou canceladas) | `F1-011_exp_remap_run1.txt` |
| E27 | Remapeamento: clique do mouse durante a captura | **aceito** (BUG-008) | idem |
| E28 | Persistência real: processo 1 grava, processo 2 lê (APPDATA isolado) | **passou** | `F1-011_persist_write.txt`, `F1-011_persist_read.txt` |
| E29 | Corpo entra no arco no meio da abertura lenta (segurar): para sem deslocar, completa depois | **passou** no essencial (parada 47,8°, 0 m, 0 penetração, completa 90°). **Quebrou** de leve: `blocked` emitido 2 vezes (BUG-010, BAIXO) | `F1-011_v5_portas_quatro.txt`; `F1-011_diag_blocked_duplo.txt` |
| E30 | Caixa estática no arco da porta | **passou** (porta completa 90°; regra 1 aceita; LD) | `F1-011_v5_caixa.txt` |
| E31 | Brecha pelo encontro painel-batente, com o painel de 0° a 90° | **passou** (nenhum corpo atravessa; BUG-011 é só geometria oculta) | `F1-011_v5_portas_quatro.txt` |
| E32 | Porta de cozinha já aberta, corpo no arco dela | **passou** (estado OPEN, zero `blocked`) | idem |
| E33 | Porta trancada: toque | **passou** (`locked_feedback` uma vez, nada se move) | idem |

Observação de desenho (não é defeito): o gate de produção fica só em `DebugCommands`/`DebugOverlay`; `PlayerRoot.set_noclip` e `teleport_to` são públicos, mas nenhuma entrada do jogador chega até eles.

## 7. Suíte e execuções (árvore de trabalho atual)

Comando: `powershell -NoProfile -ExecutionPolicy Bypass -File D:\Dev\DeadBreath\tools\run_tests.ps1`.

| Etapa | Execução 1 | Execução 2 | Evidência |
|---|---|---|---|
| importação / arc04 | OK / OK | OK / OK | `F1-011_suite_final_3.txt`, `_4.txt` |
| runner (padrão) | **146/146**, 8,9 s no resumo (etapa 9,1 s; inclui `test_portas_sandbox.gd` do Gameplay, PASS) | **146/146**, 8,6 s no resumo (etapa 8,8 s) | idem |
| runner-property | **62/63**, 75,6 s (etapa). Única falha: `porta_sala_corredor_corpo_entra_no_arco_no_meio_da_abertura` (BUG-010) | **62/63**, 73,9 s (mesma falha) | idem |
| runner-meta | 26/26, 10,1 s | 26/26, 10,2 s | idem |
| Pipeline | **REPROVADO** (código 1), 98,8 s | **REPROVADO** (código 1), 96,5 s | idem |

Testes de propriedade do QA: escadas 15/15, câmera em rampa 8/8, exploits de geometria 8/8, exploits de portas 4/4, verificação das correções 5/5, portas quatro 9/10 (falha BUG-010). Interação (scenarios): 6/6. Remapeamento (integration): 6/6.

Histórico: primeira rodada, padrão 142/143 e property 45/48; segunda rodada, padrão 145/145 e property 50/53 (3 falhas de BUG-006 e BUG-009). Linha de base sem testes do QA: 173/173 (`F1-011_run_tests_1.txt`, `_2.txt`).

## 8. Evidências

Pasta `Docs/QA/EVIDENCE/`, prefixo `F1-011_`.

- Suíte: `F1-011_suite_final_3.txt`, `_4.txt` (terceira rodada, atual); `F1-011_suite_final_1.txt`, `_2.txt` (segunda rodada); `F1-011_suite_completa_1.txt`, `_2.txt` (primeira rodada); `F1-011_run_tests_1.txt`, `_2.txt` (linha de base).
- Portas, terceira rodada: `F1-011_v4_portas.txt` (4 de 4 com (b1) trocado); `F1-011_v4_portas_quatro.txt` e `F1-011_v5_portas_quatro.txt` (experimentos das quatro portas, medição de intrusão, brecha); `F1-011_v5_caixa.txt` (caixa estática no arco, 1 passa).
- Diagnósticos (de scripts temporários, removidos após o uso): `F1-011_diag_blocked_duplo.txt` (BUG-010, tick a tick); `F1-011_diag_primeiro_bloqueio.txt`, `F1-011_diag_porta_sem_corpo.txt`, `F1-011_diag_painel_geometria.txt`, `F1-011_diag_segurar_deslocamento.txt` (rodadas anteriores, BUG-006 e BUG-009); `F1-011_diag_reversao.txt`, `F1-011_diag_diagonal_240.txt`, `F1-011_diag_varredura_pilar.txt`, `F1-011_diag_mais_z.txt` (BUG-004).
- Processo: `F1-011_probe_debug_normal.txt`, `F1-011_probe_debug_production.txt`, `F1-011_persist_write.txt`, `F1-011_persist_read.txt`.
- Visual com janela: `F1-011_captura_porta_aberta.png`, `F1-011_captura_mesa.png`, `F1-011_captura_escada.png`, `F1-011_captura_escada_do_mezanino.png`, `F1-011_captura_dobradica_90_nivel_olhos.png`, `F1-011_captura_dobradica_90_chao.png`.

## 9. Limites desta validação

- Testes de física determinísticos com `--fixed-fps 60`; não cobrem variação de máquina (RSK-06).
- Entrada injetada (`set_scripted_input`, `push_input`); não há jogo com teclado ou mouse reais, nem playtest.
- Mesmo com a folga de 2 cm, o comportamento na saída do arco (BUG-010) depende de velocidade e passo do painel; só foi medido nas velocidades de teste.
- ARC-07 e o grupo `saveable` dependem de F2 e F5.
- A regra "a porta não empurra" e a regra 1 são tratadas como decisões do Director. O BUG-010 é defeito contra a regra 3 na leitura do QA; o BUG-011 é consequência aceita da regra 1, registrada para o level design.


---

## Fechamento pelo Project Director (2026-11-20)

- **BUG-010:** corrigido pelo Director com histerese na liberação da porta. O teste de reprodução deste relatório (`test_porta_sala_corredor_corpo_entra_no_arco_no_meio_da_abertura`) passa com a correção e reprova sem ela (`blocked` emitido 2×), verificado por mutação. Por isso o BUG-010 foi FECHADO pelo teste do QA.
- **BUG-011:** aceito (intrusão oculta, sem brecha; regra de level design).
- Com isso, a condição do veredito ("condicionado à decisão sobre BUG-010") foi cumprida. Pipeline completo 2×, código 0: padrão 146/146, property 63/63, meta 26/26 (`EVIDENCE/F1-GATE_pipeline_run*.txt`).
- **Veredito final da F1-011: APROVADO COM RESSALVAS** (BUG-008 e BUG-011 aceitos; causa raiz do BUG-004 e mecanismo do R1-07 como dívidas registradas; ARC-01 vacuo e ARC-02/07 parciais até as fases dos sistemas).

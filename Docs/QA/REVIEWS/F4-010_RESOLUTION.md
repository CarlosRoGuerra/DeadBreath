# F4-010 — Rastreio da resolução dos achados

| Campo | Valor |
|---|---|
| Revisão | `Docs/QA/REVIEWS/F4-010.md` (commit revisado `69d382c`): **REPROVADO** (1 ALTO, 3 MÉDIO, 4 BAIXO, 4 INFO) |
| Decisão do Director (2026-11-24) | Corrigir o ALTO, os 3 MÉDIO e os 4 BAIXO antes da F4-007 (desempenho) e da F4-011 (QA). Os INFO vão para KNOWN_ISSUES (GAME-014) ou já estão tratados. Depois, nova verificação focada pelo mesmo revisor |
| Correções | Feitas pelo Director, com teste para cada uma; mutações de verificação quando cabem |

| ID | Sev. | Decisão | Situação |
|---|---|---|---|
| R4-01 | ALTO | D4-09: a confirmação tem teto em `visual_confirm_time_s` e zera ao entrar em LOST_CONTACT | **Corrigido** em `enemy_brain.gd`. `tests/unit/ai/test_enemy_brain_d409.gd`: depois de 10 s de perseguição, LOST_CONTACT em 1,517 s com um grito só; voltar a CHASE exige 0,8 s de visão nova. DATA §3.3 registra a regra |
| R4-02 | MÉDIO | O Observer de produção ganha `LightExposureProbe` | **Corrigido** em `observer.tscn`. `tests/integration/player/test_monitor_ve_observer.gd`: Observer real a 8 m, iluminado, dá proximidade vista 0,580 (DATA §1.5); no escuro, 0 |
| R4-03 | MÉDIO | D4-09: RETURN e PATROL desistem de destino inalcançável ou depois de 30 s | **Corrigido** em `enemy_brain.gd`. 5 testes em `test_enemy_brain_d409.gd`: ponto inalcançável pulado, sem ponto alcançável fica parado, tempo limite da patrulha, RETURN inalcançável e RETURN sem chegar passam a PATROL. GAME-013 corrigido |
| R4-04 | MÉDIO | ARC-01 endurecido | **Corrigido**: `test_firewall_sem_acesso_indireto` proíbe identificadores `player*` em minúsculo (exceto os sinais de captura que a IA emite), literais com "player" em qualquer caixa, grupos fora da lista (literal ou constante do próprio arquivo), `GameState`/`Settings`/`SaveService`, EventBus que não seja emitir e acesso à raiz, ao viewport e a caminhos absolutos (exceto a sonda de luz). Mutações M9 (grupo `player_body`), conexão ao EventBus, `GameState` e grupo por variável: as 4 reprovam |
| R4-05 | BAIXO | Crossfade de potência constante | **Corrigido** em `adaptive_music.gd`: os pesos deslizam e são normalizados; a amplitude é a raiz. O teste do crossfade, que asseria a queda de 3 dB, passou a exigir potência 1 no meio de duas transições |
| R4-06 | BAIXO | Comentário corrigido | **Corrigido** em `heard_noise.gd`: sem perda, a estimativa é a posição real (a IA ouve com precisão o que está colado nela) |
| R4-07 | BAIXO | `reset_to` descarta os sons pendentes | **Corrigido** em `enemy_controller.gd`. `tests/integration/enemy/test_reset_descarta_sons.gd` |
| R4-08 | BAIXO | Documentação | **Feito**: COMPONENT_CONTRACTS §8.3 (API da F4, com os desvios de `EnemyWorldQuery._init` e a interface do esconderijo para a F5), cabeçalho do cérebro alinhado ao código, GAME-013 corrigido |
| R4-09 | INFO | Negativos sem `expect_engine_error` | GAME-014 (F5) |
| R4-10 | INFO | Suíte padrão sem ARC-xx | Mantido; documentado em TEST_PLAN §4 (etapa `estatico`) |
| R4-11 | INFO | Tela de captura sem rearme | GAME-014 (F5, com o `reset_to`) |
| R4-12 | INFO | Status da F3 | Registrado; nada a fazer |

# F3-010 — Rastreio da resolução dos achados

| Campo | Valor |
|---|---|
| Revisão | `Docs/QA/REVIEWS/F3-010.md` (commit revisado `5b5a82b`): **APROVADO COM RESSALVAS** (0 CRÍTICO, 0 ALTO, 4 MÉDIO, 5 BAIXO, 5 INFO) |
| Decisão do Director (2026-11-21) | Corrigir R3-01, R3-02, R3-04, R3-05, R3-06, R3-07 e R3-08 antes da F3-011. Aceitar R3-03 até o playtest com escuta; R3-09 aceito; os INFO vão para a F4 ou a F5. Depois das correções, o revisor faz nova verificação focada |
| Correções | Feitas pelo Director; pipeline completo e 7 mutações (uma por correção, todas pegas por um teste) |
| Nova verificação | `Docs/QA/REVIEWS/F3-010_VERIFICATION.md` (commit `6b84b40`): **APROVADO COM RESSALVAS**. R3-01, R3-04..R3-08 resolvidos; R3-02 parcial (N1, N2); 3 BAIXO novos e 1 INFO. Pipeline do revisor: 451/451, 122/122, 26/26 |

| ID | Sev. | Destino | Situação |
|---|---|---|---|
| R3-01 | MÉDIO | Implementar D-07 em L1 já na F3 | **Corrigido**: `HeardNoise.from_propagation`, `confidence_for` e `disk_offset`, funções puras com o RNG do chamador. Teste `tests/unit/acoustics/test_heard_noise_estimativa.gd`: confiança nos limites; disco horizontal; uniforme na área (metade dentro de R/√2); centrado no `entry_point`; longe da posição real; determinismo. Mutação: raio `R·u` em vez de `R·√u` reprova o teste de uniformidade |
| R3-02 | MÉDIO | Trava em tempo de execução e varredura mais forte | **Corrigido**: o `NoiseEmitter` recusa categoria corporal de fonte que não comece com `enemy`, com `Log.error` e sem evento (`tests/integration/acoustics/test_noise_emitter_corpo.gd`, 3 fontes × 4 categorias). A varredura NOI-INV-1 agora também pega `NoiseEvent.new()` fora da fábrica e `"emit_noise"` como texto (`call`, `callv`, `Callable`). Mutações: desligar a trava reprova o teste da trava; `NoiseEvent.new()` em `door.gd` reprova a varredura |
| R3-03 | MÉDIO | Aceito até o playtest | **Aceito** (KNOWN_ISSUES GAME-009): é uma estimativa, não uma medição; o limitador existe para isso. A R3-07 baixou o trovão ao ar livre de +6 para +3,25 dB. Reabrir se o limitador for audível na escuta |
| R3-04 | MÉDIO | O arremesso do próprio jogador não assusta | **Corrigido**: convenção `player_<...>` = causado pelo jogador (`AcousticWorld.is_player_source`); o ouvinte do jogador não recebe esses eventos (nem susto, nem legenda). O Throwable solto ou arremessado emite como `player_thrown_<id>` até repousar ou ser pego. A IA (F4) ouve normalmente. Testes: impacto do próprio arremesso não assusta, o mesmo impacto sem causa assusta; a causa vale até o repouso natural ou a nova pega. Mutação: voltar ao filtro antigo reprova |
| R3-05 | BAIXO | Arremesso checa espaço como a soltura | **Corrigido**: `throw_held` não arremessa se a forma não couber; continua segurando. Teste com a mão dentro de uma parede. Mutação: tirar a checagem reprova |
| R3-06 | BAIXO | Teste de que o próprio barulho não assusta | **Corrigido**: 6 passadas de corrida e 1 queda pelos sinais reais do motor, com pré-condição de que foram emitidas; o estresse não muda. Mutação: `FootNoise` com outro `source_id` reprova |
| R3-07 | BAIXO | Trovão no nível do mascaramento | **Corrigido**: ganho = `NoiseGain.gain_for_db(piso + 20)`. Cômodo interno −3 dB (era −10), ao ar livre +3,25 dB (era +6). Testes por piso. Mutação: a fórmula antiga reprova |
| R3-08 | BAIXO | Registrar a API pública da F3 | **Feito**: COMPONENT_CONTRACTS §6.6 |
| R3-09 | BAIXO | Enumeração do NOI-02 até 7 portais | **Aceito**: a verificação independente do revisor foi até 25 portais (8 844 consultas, 0 divergências). Registrado na F3-011 |
| R3-10 | INFO | Custo do probe | F4 (KNOWN_ISSUES GAME-010) |
| R3-11 | INFO | Falas sem emissor | F4 (KNOWN_ISSUES GAME-010) |
| R3-12 | INFO | Suíte padrão em 8,9 s | Acompanhado a cada fase |
| R3-13 | INFO | Recursos em uso na saída | F5 (já registrado na F2) |
| R3-14 | INFO | Som corporal de inimigo no router | F4 (KNOWN_ISSUES GAME-010) |
| N1 | BAIXO | A recusa da trava não tinha teste que a contasse (a mutação M7 passava) | **Corrigido**: `tests/integration/acoustics/test_fontes_do_mundo_sem_corpo.gd` roda o ciclo inteiro da porta e um impacto de arremessável sem nenhuma recusa, com cada evento na categoria da fonte. A M7 (porta emitindo tosse) agora reprova |
| N2 | BAIXO | A trava depende só do prefixo `enemy` | **F4**: campo explícito de origem junto com os inimigos (KNOWN_ISSUES GAME-010) |
| N3 | BAIXO | A causa do jogador não tinha prazo | **Corrigido**: vale até o repouso ou até `Throwable.PLAYER_CAUSED_MAX_S` (3 s) depois da soltura, o que vier primeiro. Teste `test_causa_do_jogador_expira_sem_repouso`. Mutação: tirar o prazo reprova |
| N4 | INFO | Qualquer `player_<...>` conta como causado pelo jogador | Convenção registrada em COMPONENT_CONTRACTS §6.5 e §6.6; hoje só o Throwable usa |

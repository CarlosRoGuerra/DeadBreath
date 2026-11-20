# F1-010 — Rastreio da resolução dos achados

| Campo | Valor |
|---|---|
| Revisão | `Docs/QA/REVIEWS/F1-010.md` (commit revisado `5bb160c`): **REPROVADO** (2 ALTO) |
| Decisão do Director (2026-11-20) | Corrigir todos os ALTO e MÉDIO antes da F1-011. Os BAIXO entram onde forem baratos; os demais vão para KNOWN_ISSUES. Depois das correções, o revisor faz nova verificação focada nos achados |

| ID | Sev. | Responsável | Destino | Situação |
|---|---|---|---|---|
| R1-01 | ALTO | Gameplay Engineer | BUG-001 reaberto: corrigir a causa no step-up; teste de propriedade no ciclo completo (passo de 5 mm) | Em correção |
| R1-02 | ALTO | Gameplay Engineer | BUG-002: descida sem perda de chão no ciclo completo | Em correção |
| R1-03 | MÉDIO | Gameplay Engineer | BUG-003: compensação só para degraus; teste de câmera em rampa ≤ 1 cm | Em correção |
| R1-04 | MÉDIO | Gameplay Engineer | Overlay encontra o jogador sozinho; teste na cena jogável sem injeção | Em correção |
| R1-05 | MÉDIO | Software Architect (Director) | `Settings.set_value` rejeita não finitos; testes NaN/INF | **Corrigido**: `is_finite` antes do `clampf`; 2 testes (set e carga de arquivo com `nan`); a mutação que desliga a checagem reprova os 2 |
| R1-06 | MÉDIO | Gameplay Engineer | Validar a entrada antes de `rebind`; nunca gravar ação vazia | Em correção |
| R1-07 | MÉDIO | QA Engineer | Investigar a dependência de histórico; isolar a física por teste (mundo próprio) | Em investigação |
| R1-08 | BAIXO | Director | Conferir o retorno do `rename` na rotação; restante para KNOWN_ISSUES | **Corrigido/aceito**: retorno conferido (anexa se falhar); comportamento com `rename` bem-sucedido em KNOWN_ISSUES GAME-002 |
| R1-09 | BAIXO | Gameplay Engineer | Contadores por fase na varredura (entra na nova varredura) | Em correção |
| R1-10 | BAIXO | QA Engineer | Teste sem assert reprova; watchdog por frames | Em correção |
| R1-11 | BAIXO | QA Engineer | ARC-03 com padrões dinâmicos + meta-teste | Em correção |
| R1-12 | BAIXO | Director | Atualizar COMPONENT_CONTRACTS com a API acrescentada (depois das correções do motor) | Pendente |
| R1-13 | BAIXO | Director | Documentar a interação como passo do mediador (-90) em §6 e §1 | **Feito**: SYSTEM_ARCHITECTURE §6 e COMPONENT_CONTRACTS §1 |
| R1-14 | BAIXO | Director | LevelSlots valida `opening_width_m` contra o painel de 0,9 m | **Corrigido**: `Log.error` para vão fora da medida + teste |
| R1-15 | BAIXO | Director | KNOWN_ISSUES: durabilidade sem fsync | **Feito**: KNOWN_ISSUES GAME-001 |
| R1-16 | INFO | Director | TEST_RESULTS: ARC-01 e ACC-02..04 pendentes de fase | **Feito**: seção "Cobertura pendente de fase" |
| R1-17 | INFO | — | Sem ação até haver orçamento medido (F4) | Aceito |

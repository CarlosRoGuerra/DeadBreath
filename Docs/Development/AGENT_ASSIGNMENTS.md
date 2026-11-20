# Distribuição de Agentes — DEAD BREATH

| Campo | Valor |
|---|---|
| Atualizado | 2026-11-20 |
| Responsável | Project Director |

## 1. O que o ambiente realmente oferece

Verificado nesta sessão (Claude Code, extensão VS Code):

| Recurso | Disponível | Uso no projeto |
|---|---|---|
| Ferramenta `Agent` (subagentes) | Sim | Executar papéis especializados por tarefa |
| Tipos de subagente | `general-purpose`, `Plan`, `Explore`, `fork` | Implementação (general-purpose), revisão de design (Plan), busca no código (Explore) |
| Nível de esforço por subagente | `low`, `medium`, `high`, `xhigh`, `max` | Mapeado da matriz de esforço (§3) |
| Execução em segundo plano | Sim | Tarefas paralelas independentes |
| Isolamento `worktree` | Sim, **requer repositório git** | Agentes paralelos sem conflito de arquivos |
| Continuar um subagente (`SendMessage`) | Sim | Correções após revisão, sem perder contexto |
| Agentes persistentes com memória própria | **Não** | Cada subagente começa sem contexto. A "memória" de cada papel são os documentos do repositório (contratos, task cards, este arquivo). |

**Consequência:** os 10 papéis do prompt mestre são **funções**, não processos permanentes. Cada tarefa é executada por um subagente instanciado com: (1) o charter do papel (§2), (2) o task card do TASK_BOARD, (3) os contratos relevantes e (4) as regras do §17 do prompt mestre.

**Custo:** cada subagente começa do zero e relê o contexto, o que é caro. Política:
- Subagente **sim** para trabalho independente com contrato aprovado, trabalho paralelo e **todas** as revisões e QA (a independência exige contexto separado).
- Subagente **não** para ajustes pequenos, integração e decisões arquiteturais críticas. Esses o Project Director executa diretamente.

## 2. Papéis

| # | Papel | Execução | Esforço | Pode modificar | Não pode |
|---|---|---|---|---|---|
| 1 | Project Director | Sessão principal | EXTRA HIGH | Tudo; integra branches | Aprovar a própria entrega sem QA independente |
| 2 | Software Architect | Sessão principal; `Plan` para segunda opinião | EXTRA HIGH | `Docs/Architecture/`, `game/autoload/`, `game/core/`, `game/sim/persistence/` | Implementar gameplay fora do núcleo |
| 3 | Gameplay Engineer | `general-purpose` | HIGH | `game/components/` (player, interaction, world), `game/sim/` (inventory, objectives) | Alterar contratos sem aprovação |
| 4 | Physiological Systems Engineer | `general-purpose` | EXTRA HIGH | `game/sim/physiology/`, `game/components/player/physiology_*`, `game/content/data/physiology/` | Tocar em IA ou áudio diretamente |
| 5 | AI Engineer | `general-purpose` | EXTRA HIGH | `game/sim/` (ai, acoustics, difficulty), `game/components/` (enemy, perception, acoustics — este em conjunto com o Audio Engineer) | Ler o estado do jogador fora de `PerceivableTarget` |
| 6 | Audio Engineer | `general-purpose` | HIGH | `game/presentation/audio/`, `game/content/audio/`, `tools/audio/`, `game/components/acoustics/` (com o AI Engineer), `breath_emitter.gd` (com o Physiological Eng.) | Emitir ruído de gameplay fora do `AcousticWorld`; tocar som de gameplay (respiração, passos, portas, objetos) que não venha de um `NoiseEvent` (música e ambiente estão fora dessa regra) |
| 7 | Level Designer | `general-purpose` | HIGH | `game/content/levels/`, `Docs/Design/LEVEL_DESIGN.md` | Alterar scripts de sistemas |
| 8 | Art & Environment | `general-purpose` | HIGH | `game/content/` (props, materials, textures), `tools/art/`, `Docs/Design/ART_DIRECTION.md` | Produzir assets detalhados antes da aprovação do greybox |
| 9 | QA Engineer | `general-purpose`, **contexto novo** | EXTRA HIGH | `game/tests/`, `Docs/QA/` | Corrigir o código testado; aprovar sem executar |
| 10 | Technical Reviewer | `general-purpose` restrito por instrução a criar só o relatório, ou skill `code-review` | HIGH | Apenas relatórios em `Docs/QA/REVIEWS/` | Alterar código sem autorização do Director |

**Nota sobre a restrição de escrita (achado R-47):** o subagente `general-purpose` tem ferramentas de edição. A restrição "só criar o relatório" é **por instrução**, não técnica. `Plan` e `Explore` não têm Edit/Write, mas mantêm Bash, que também pode escrever; não há garantia técnica completa. Nesse caso o Director grava o relatório devolvido. Depois de cada revisão, o Director confere com `git status` (a partir da F1) que nenhum outro arquivo foi alterado. Na DISC-006, o revisor criou apenas o próprio relatório.

## 3. Mapeamento de esforço

| Prompt mestre | Parâmetro `effort` | Observação |
|---|---|---|
| LOW | `low` | Ajustes, documentação auxiliar |
| MEDIUM | `medium` | Funcionalidades isoladas |
| HIGH | `high` | Sistemas com dependências |
| EXTRA HIGH | `xhigh` | Arquitetura, fisiologia, IA, persistência, QA crítico |
| — | `max` | Só se o usuário pedir explicitamente |

## 4. Fluxo por tarefa (seção 8 do prompt mestre)

| # | Etapa | Executor | Artefato |
|---|---|---|---|
| 1–3 | Analisar, identificar sistemas e dependências | Director | Task card em TASK_BOARD |
| 4–6 | Contrato de integração e aprovação | Architect (Director revisa) | COMPONENT_CONTRACTS atualizado, status do contrato → v1.0 |
| 7 | Implementação | Especialista (subagente, worktree se paralelo) | Branch `task/<ID>` + relatório de entrega (§5) |
| 8 | Revisão técnica | Technical Reviewer (contexto novo) | Relatório em `Docs/QA/REVIEWS/<ID>.md` |
| 9 | Testes independentes | QA Engineer (contexto novo) | Saída real dos testes em TEST_RESULTS.md |
| 10 | Integração | Director | Merge na `main`, suíte completa verde |
| 11 | Documentação | Director / especialista | Docs do sistema, CHANGELOG |
| 12 | Aprovar ou rejeitar | Director | Status no TASK_BOARD com evidências |

## 5. Modelo de relatório de entrega (obrigatório)

```markdown
## Entrega <TASK-ID> — <papel>
- Implementado:
- Arquivos criados:
- Arquivos modificados:
- Testes executados (comando exato):
- Resultado (saída resumida, copiada da execução real):
- Testes que passaram:
- Testes que falharam:
- Dependências pendentes:
- Decisões técnicas tomadas:
- Limitações conhecidas:
```

Resultados de teste sem a saída real da execução são rejeitados.

## 6. Paralelização e conflitos

**Pode rodar em paralelo** (módulos independentes, contratos aprovados):
- Modelos L1 de fisiologia ∥ AcousticGraph L1 ∥ InventoryModel L1
- Documentação de narrativa e direção de arte ∥ qualquer código
- Geração de biblioteca de sons ∥ código
- QA de módulos estabilizados ∥ novas implementações

**Exige coordenação** (um agente por vez ou contrato conjunto aprovado antes):
- RespiratoryModel ↔ BreathEmitter ↔ BreathingAudio
- AcousticWorld ↔ HearingSensor ↔ EnemyBrain
- PlayerMotor ↔ HidingComponent
- CheckpointManager ↔ Inventory ↔ ObjectiveManager

**Regras**
- Um arquivo tem **um único escritor por vez**. Agentes paralelos usam worktrees separadas, e o Director faz os merges.
- Em conflito: interromper a integração → identificar a origem → consultar o Architect → atualizar o contrato → regressão completa.
- Nunca resolver conflito removendo funcionalidade sem autorização do usuário.

## 7. Prompt-base para instanciar um especialista

```
Você é o <PAPEL> do projeto DEAD BREATH (Godot 4.7.2, GDScript tipado).
Leia antes de agir: Docs/Development/AGENT_ASSIGNMENTS.md (seu papel e limites),
Docs/Architecture/SYSTEM_ARCHITECTURE.md, os contratos <SEÇÕES> em COMPONENT_CONTRACTS.md
e o task card <ID> em Docs/Development/TASK_BOARD.md.
Implemente somente o escopo do card. Execute os testes indicados e entregue o
relatório no formato do §5 com a saída real dos comandos. Não declare nada como
funcionando sem ter executado.
```

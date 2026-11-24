# Plano de Testes — DEAD BREATH

| Campo | Valor |
|---|---|
| Versão | 0.2 (Fase 0, revisado após DISC-006) |
| Responsável | QA Engineer |
| Estado | Nenhum teste executado. Não existe código. |

## 1. Estratégia

| Nível | O que cobre | Execução | Frequência |
|---|---|---|---|
| Unit | Modelos L1 | Headless | Toda alteração |
| Integration | Componentes L2 em cenas mínimas, física em passo fixo | Headless | Toda alteração em L2 |
| Scenario | Bots com inputs roteirizados | Headless | Antes de REVIEW |
| Architecture | Regras estáticas e de reflexão | Headless | Toda alteração |
| Visual | Screenshot gerado por script | **Com janela** | Mudanças visuais |
| Performance | Frame time médio e p95, vsync desligado, 600 frames após 120 de aquecimento | Com janela | A partir da F4, em todo gate |
| Playtest | Testes de experiência | Usuário + questionário + métricas automáticas | Fim das F5 e F7 |

**Níveis desde a F4 (Director):** a suíte padrão é só de comportamento (unit, integration, scenarios). As verificações estáticas do código (nível `architecture` e o ARC-04 no nível próprio `arc04`) rodam na etapa `estatico` do pipeline: passavam de 2 s na suíte padrão e não precisam rodar a cada iteração. O pipeline continua rodando todas. A listagem de scripts das varreduras de arquitetura é feita uma vez por processo (cache em `SourceScan`).

**Comando padrão (criado em F1-005):** `tools/run_tests.ps1` → importação headless → ARC-04 (compilação de todos os scripts no processo, com autoloads; `--check-only` não enxerga autoloads) → `<godot> --headless --fixed-fps 60 --path game -s res://tests/run_all.gd` → mesma chamada com `--level=meta`. Sai com código 0 ou 1.

**Regras de evidência**
- Toda execução vai para TEST_RESULTS.md com data, commit, comando exato e resumo copiado da saída real.
- O QA executa os testes por conta própria. O relatório do implementador não é evidência.
- Teste instável (resultado diferente com o mesmo estado de RNG) é bug.
- Testes de propriedade (muitas rodadas) usam `dt = 0.1 s`. Um teste de invariância a dt (PHY-11) garante que 0,1 s e 1/60 s produzem resultados equivalentes dentro da tolerância.
- Comparações de ponto flutuante usam tolerância explícita (padrão 0,5 dB e 0,01 de severidade).

## 2. Matriz de testes

### 2.1 Movimento (Fase 1)

| ID | Requisito | Nível | Critério |
|---|---|---|---|
| MOT-01 | Não levanta sob teto baixo (MOT-INV-1) | Integration | Rastejando sob uma mesa de 0,6 m, o comando de levantar não altera a postura |
| MOT-02 | Esforço por marcha (MOT-INV-2) | Unit | Valores da tabela de DATA_STRUCTURES §1.1, com tolerância de 0,01 |
| MOT-03 | Limites só reduzem (MOT-INV-3) | Unit | `apply_limits` com multiplicador > 1 não aumenta a velocidade |
| MOT-04 | Navegação básica | Scenario | O bot passa por vão de 0,6 m rastejando, sobe a escada e não atravessa paredes |

### 2.2 Fisiológicos (Fase 2)

| ID | Requisito | Nível | Critério (config padrão) |
|---|---|---|---|
| PHY-01 | Correr provoca esforço respiratório | Scenario | Sprint com tanque cheio até esgotar a stamina (≈ 8,3 s) → estado LABORED ou pior no esgotamento |
| PHY-02 | Estresse influencia a respiração | Unit | Mesmo esforço: alvo com estresse 80 ≥ alvo com estresse 0 + 0,25 |
| PHY-03 | Descanso permite recuperação | Unit | Severidade 0,6 em repouso → < 0,2 em ≤ 25 s |
| PHY-04 | Medicamentos aliviam sintomas | Unit | Bombinha em SYMPTOMATIC (severidade 0,6) → redução **absoluta** ≥ 0,30 em ≤ 3 s |
| PHY-05 | Resistência e respiração independentes (PHY-INV-2) | Unit | Bombinha não altera stamina; zerar a stamina não altera a severidade no mesmo tick |
| PHY-06 | Sintomas não ficam presos (PHY-INV-3) | Unit (propriedade) | 200 sequências aleatórias de 120 s de entradas, seguidas de 60 s de repouso → severidade < 0,2 e estresse < 25 em todas |
| PHY-07 | Crises têm aviso (PHY-INV-5) | Unit | Em 200 sequências, toda tosse involuntária é precedida de `cough_warning` ≥ 1,5 s antes |
| PHY-08 | Determinismo (PHY-INV-6) | Unit | Mesmo estado de RNG + mesmas entradas → snapshots idênticos em todos os ticks |
| PHY-09 | Limites (PHY-INV-1) | Unit (propriedade) | Nas sequências do PHY-06, nenhum valor sai do intervalo |
| PHY-10 | Histerese e permanência (PHY-INV-4) | Unit | Severidade oscilando ±0,02 em torno de cada limiar → nenhuma transição antes de `state_min_dwell_s`; sem oscilação de estado |
| PHY-11 | Invariância a dt | Unit | Mesmas entradas com dt 1/60 e 0,1 → severidade final com diferença ≤ 0,02 |
| PHY-12 | Ameaça real alimenta o estresse (Fase 4) | Integration | Inimigo visível a 3 m → estresse sobe ≥ 10 em 1 s; inimigo correndo, só audível (≥ 30 dB) → estresse sobe; inimigo fora de percepção → estresse não sobe |

Na F2 e na F3, os testes PHY usam `ThreatSample` construído no próprio teste ou `StubThreatSource`. `add_startle` e `add_injury` são chamados diretamente. As fontes reais (PlayerThreatMonitor e ruídos) entram na F4 e são cobertas pelo PHY-12.

### 2.3 Acústica (Fase 3)

| ID | Requisito | Nível | Critério |
|---|---|---|---|
| NOI-01 | Único caminho de som para a IA (NOI-INV-1) | Architecture | Nenhum script chama `HearingSensor.receive` fora do `AcousticWorld` |
| NOI-02 | Propagação pura (NOI-INV-3) | Unit | Mesmo grafo e evento → mesmo resultado; fechar porta nunca aumenta o nível |
| NOI-03 | HeardNoise e PlayerHeardNoise sem dados da fonte (NOI-INV-4) | Architecture | Reflexão: os campos de `HeardNoise` e de `PlayerHeardNoise` são exatamente as listas permitidas (sem posição real, id ou sala) |
| NOI-04 | Paridade áudio × IA (NOI-INV-2) | Integration | Para 20 eventos, o `volume_db` aplicado pelo router difere ≤ 0,5 dB do `perceived_db` calculado para o ouvinte do jogador; a atenuação nativa está desligada |
| NOI-05 | Respiração com produtor único | Integration | Com o PhysiologyComponent em LABORED por 10 s, cada som de respiração tocado tem um `NoiseEvent` correspondente, e vice-versa |

### 2.4 Furtividade (Fases 3–5)

| ID | Requisito | Nível | Critério |
|---|---|---|---|
| STL-01 | Sons têm intensidades diferentes | Unit | Com os valores base: rastejar < agachado < andar < correr < tosse < queda. Em cada superfície: rastejar < agachado < andar < correr. (Decisão D-01: o modificador de superfície pode reordenar categorias de propósito; correr em madeira solta, 66 dB, soa mais que a tosse, 65 dB) |
| STL-02 | Paredes modificam a percepção | Unit | Mesma distância: através de parede ≥ 20 dB a menos que em linha livre |
| STL-03 | Portas modificam a propagação | Unit | Com a porta na rota de menor perda, fechada reduz ≥ 14,5 dB em relação a aberta (tolerância sobre os 15 dB nominais). Com a porta longe da rota, o caminho pela parede pode vencer nos dois estados (redução 0; D-02) |
| STL-04 | Esconderijos funcionam | Scenario | Jogador escondido, respiração calma, fora da visão → o inimigo passa a 2 m sem detectar (20 rodadas) |
| STL-05 | É possível despistar | Scenario | Perseguição + quebra de linha de visão + esconderijo → RETURN sem captura em pelo menos uma rota da sandbox |
| STL-06 | Entrada e saída de esconderijo | Integration | Entrar à vista do inimigo resulta em descoberta; fora da visão, não; ruídos de entrada e saída são emitidos |
| STL-07 | Alcances de referência | Unit | Com a config padrão, os 7 exemplos de DATA_STRUCTURES §2.3 (respiração calma e ofegante, chiado, tosse com 1 e 2 paredes, quintal, porão) dão os alcances documentados, com ±0,2 m |

### 2.5 IA (Fase 4)

| ID | Requisito | Nível | Critério |
|---|---|---|---|
| AI-01 | Inimigos patrulham | Integration | Percorre todos os pontos da rota em ordem, sem estímulos |
| AI-02 | Investigam ruídos | Scenario | Observer em sala de teste com piso ambiente 12 dB (limiar efetivo 15): passo de 40 dB a 1 m da fonte, ouvinte a 3,05 m (30 dB percebidos) → suspeita +0,6 → INVESTIGATE e chega a ≤ 2 m da posição estimada |
| AI-03 | Identificam o jogador visualmente | Scenario | **Observer**, jogador em pé, `light_exposure` 1, no FOV, sem oclusão, a 8 m → CHASE em ≤ 1,5 s |
| AI-04 | Perdem contato | Scenario | Linha de visão quebrada por 1,5 s → LOST_CONTACT → SEARCH |
| AI-05 | Procuram na última posição conhecida | Scenario | O primeiro destino de LOST_CONTACT fica a ≤ 1 m da última posição vista |
| AI-06 | Não conhecem posições não observadas | Scenario (invariância) | 50 pares de execuções com mesmo estado de RNG e mesmos percepts, jogador em posições diferentes, ambas fora de visão e silenciosas → `EnemyIntent` **idêntico** em todos os ticks |
| AI-07 | Captura não informa a IA (ENM-INV-1) | Unit | A `EnemyCaptureArea` disparando não adiciona nada ao `PerceptBatch` |
| AI-08 | Inspeção como percept (ENM-INV-2) | Unit | Inspeção bem-sucedida gera exatamente um `VisualPercept` na posição do esconderijo; inspeção vazia não gera nenhum |

### 2.6 Persistência (Fase 5)

| ID | Requisito | Nível | Critério |
|---|---|---|---|
| PER-01 | Checkpoint restaura o jogador | Integration | Posição, postura e fisiologia iguais ao snapshot |
| PER-02 | Inventário preservado | Integration | Itens e cargas iguais |
| PER-03 | Objetivos preservados | Integration | Status iguais |
| PER-04 | Mundo restaurado | Integration | Portas, luzes, props e `EnvironmentState` iguais |
| PER-05 | Sem duplicação de itens | Scenario | 10 ciclos de pegar item → captura → carregar: contagem total constante |
| PER-06 | Ordem da sequência de captura | Integration | Os 8 passos de COMPONENT_CONTRACTS §12 ocorrem na ordem, verificados por log instrumentado |
| PER-07 | Reprodutibilidade após carregar | Unit | Salvar no meio de uma sequência em dois pontos: (a) com tosse agendada (aviso em curso) e bombinha em cooldown; (b) com cooldown de tosse ativo e stamina em exaustão. Carregar e comparar **campo a campo** com DATA_STRUCTURES §6.1; depois continuar → resultados idênticos à execução contínua. (Tosse agendada e cooldown de tosse não coexistem pela §1.4; ajuste de redação na F2.) |
| PER-08 | Tratamento de snapshot inválido | Unit | Os casos de SYSTEM_ARCHITECTURE §14 se comportam como especificado |
| PER-09 | Escrita atômica | Integration | Falha simulada no meio da gravação → o arquivo anterior continua legível |
| PER-10 | Sem perda indevida de progresso | Scenario | Objetivo concluído antes do checkpoint continua concluído após 3 capturas |

### 2.7 Inventário e objetivos (Fase 5)

| ID | Requisito | Critério |
|---|---|---|
| INV-01 | Quantidade nunca negativa | `remove` além do disponível retorna false e não altera o estado |
| INV-02 | Capacidade respeitada | `add` acima da capacidade aceita só o que cabe e retorna a quantidade |
| INV-03 | Serialização idempotente | `from_dict(to_dict())` produz estado igual |
| OBJ-01 | Pré-requisitos (AND) | Objetivo não conclui com pré-requisito pendente |
| OBJ-02 | Rotas alternativas (OR) | Qualquer evento de conclusão conclui o objetivo |
| OBJ-03 | Recompensas | Concluir entrega os `reward_items` exatamente uma vez |

### 2.8 Acessibilidade e interface (Fases 1, 2, 3 e 7)

| ID | Requisito (MASTER §11) | Critério |
|---|---|---|
| ACC-01 | Redução de tremores e de movimento da câmera | Com `motion_reduction` e `tremor_reduction` em 1,0 (redução total), `CameraEffects` aplica amplitude 0; em 0,0, amplitude normal (DATA_STRUCTURES §10) |
| ACC-02 | Ajuste de intensidade dos efeitos | `effects_intensity` escala todos os efeitos de câmera e tela linearmente |
| ACC-03 | Indicador visual de condição respiratória | Com a opção ligada, o indicador reflete `respiratory_state` em ≤ 1 frame; desligado por padrão |
| ACC-04 | Legendas | Sons relevantes (tosse, porta, passos próximos, falas) geram `subtitle_requested`; tamanho configurável |
| ACC-05 | Remapeamento de controles | Remapear, reiniciar o jogo e confirmar que a ligação persiste; conflitos são avisados |
| ACC-06 | Settings persistem | Todas as chaves de COMPONENT_CONTRACTS §15 sobrevivem a reiniciar o jogo |

### 2.9 Experiência (playtest, Fases 5 e 7)

| ID | Pergunta | Método |
|---|---|---|
| EXP-01 | O jogador entende os perigos? | Questionário + tempo até a primeira detecção |
| EXP-02 | A corrida tem utilidade? | % de fugas bem-sucedidas que usaram sprint |
| EXP-03 | A furtividade funciona? | Detecções vs. tentativas furtivas |
| EXP-04 | As crises não parecem aleatórias? | Questionário: o jogador antecipou a tosse? |
| EXP-05 | O jogo não depende só de sustos? | Questionário + contagem de sustos roteirizados |
| EXP-06 | Perseguições desafiadoras e justas | Taxa de captura por perseguição (alvo 30–60%) + questionário |

### 2.10 Arquitetura (contínuo desde a Fase 1)

| ID | Regra | Verificação |
|---|---|---|
| ARC-01 | Firewall de percepção | Varredura em `sim/ai/`, `sim/difficulty/`, `components/enemy/` e `components/perception/` (exceto `vision_sensor.gd`): proibidas as referências a `PlayerRoot`, `PlayerMotor`, `PhysiologyComponent`, `PlayerThreatMonitor`, `PlayerHeardNoise`, `NoiseEvent`, ao grupo `"player"` e a caminhos com `Player`. Complementado por NOI-03 e AI-06. |
| ARC-02 | `persist_id` único e não vazio | Carrega cada nível e valida o grupo `saveable` |
| ARC-03 | L1 não depende da cena | Scripts em `sim/` não usam `get_node`, `get_tree`, autoloads nem estendem `Node` |
| ARC-04 | Todos os scripts fazem parse | `--headless --import`, depois `--check-only` por arquivo, com código de saída verificado; warnings de tipagem configurados como erro |
| ARC-05 | Sem dependência ascendente | `autoload/` e `core/` não referenciam classes de `sim/`, `components/` ou `presentation/`; `sim/` não referencia `components/` nem `presentation/`; `components/` não referencia `presentation/` |
| ARC-06 | Mediador do jogador (PLR-INV-1) | Os scripts de componentes do jogador não referenciam uns aos outros |
| ARC-07 | Config ausente | Em build de debug, um `.tres` obrigatório ausente gera falha imediata; em modo de produção simulado, o sistema usa os padrões e registra `Log.error` |

## 3. Riscos de teste

- Física pode tornar testes de cenário instáveis. Mitigação: passo fixo, RNG com estado fixo e tolerâncias explícitas.
- Ponto flutuante pode variar entre máquinas. Mitigação: determinismo exigido só na mesma máquina e build (KNOWN_ISSUES RSK-06).
- Testes de experiência são subjetivos. Mitigação: métricas automáticas + questionário padronizado.
- Testes visuais dependem da GPU. Servem como evidência de inspeção, não como comparação pixel a pixel.

## 4. Contrato do framework de testes (F1-005, v1.0, 2026-11-20)

Contrato de integração definido pelo Director antes da implementação, para que o QA (framework) e os implementadores (testes dos seus módulos) trabalhem em paralelo.

**Arquivos e escritores**

| Arquivo | Escritor |
|---|---|
| `game/tests/framework/*`, `game/tests/run_all.gd`, `game/tests/architecture/*`, `game/tests/meta/*`, `tools/run_tests.ps1` | QA Engineer |
| `game/tests/unit/<área>/test_*.gd`, `game/tests/integration/<área>/test_*.gd` | Implementador do módulo (o QA pode acrescentar testes próprios em arquivos separados) |

**Como escrever um teste**
- Arquivo `test_<nome>.gd` em `tests/unit`, `tests/integration`, `tests/scenarios` ou `tests/architecture` (busca recursiva), com `extends TestCase`. Nível `property` (varreduras longas): `tests/property/` (recursivo). Meta-testes do runner: `tests/meta/`.
- Cada teste é um método `func test_<nome>() -> void`, sem argumentos; pode usar `await`.
- Ganchos opcionais (`-> void`, podem usar `await`): `before_all()`, `after_all()`, `before_each()`, `after_each()`.

**Asserts** (registram a falha e seguem; o teste falha se houver ao menos uma):
`assert_true(cond, msg := "")`, `assert_false(cond, msg := "")`, `assert_eq(actual, expected, msg := "")`, `assert_ne(actual, expected, msg := "")`, `assert_almost_eq(actual: float, expected: float, tolerance: float, msg := "")`, `assert_null(value, msg := "")`, `assert_not_null(value, msg := "")`, `fail(msg)`.
**Teste sem nenhum assert reprova** (F1-010, R1-10). Vacuidade justificada usa um assert explícito, por exemplo `assert_true(true, "vacuo: <motivo>")`.

**Utilidades**
- `add_child_autofree(node: Node) -> Node`: adiciona à árvore; liberado ao fim do teste.
- `await wait_physics_frames(n: int)` e `await wait_process_frames(n: int)`.
- `tmp_dir() -> String`: diretório vazio exclusivo do teste em `user://test_tmp/...`, apagado ao fim.
- `add_isolated_world() -> Node3D`: mundo 3D próprio (`SubViewport` com `own_world_3d`), liberado ao fim do teste; devolve o nó de cenário dentro dele. Use uma fase por mundo quando um teste repete fases (F1-010, R1-07).
- `await release_and_flush(node)`: remove da árvore, libera e espera `FLUSH_PHYSICS_FRAMES` (2) frames de física. Use em vez de `free()` direto quando o nó tem corpos físicos e o teste monta outro cenário em seguida.

**Runner**
- `godot --headless --fixed-fps 60 --path game -s res://tests/run_all.gd -- [--filter=<texto>] [--level=unit|integration|scenarios|architecture|property|meta]`
- **Níveis e alvo de tempo** (decisão do Director, F1-010): a execução padrão (sem `--level`) roda `unit`, `integration`, `scenarios` e `architecture`, com alvo de **menos de 10 s**. `property` (suíte lenta: varreduras longas e determinísticas, como a de degrau a 5 mm, e cenários que carregam a cena inteira, como o MOT-04 na sandbox; decisão do Director na F2) não entra na padrão: roda com `--level=property`, com etapa própria no pipeline. `meta` (meta-testes do runner) roda com `--level=meta`.
- **`--fixed-fps 60` é obrigatório** (decisão do Director, 2026-11-20): cada frame avança exatamente 1/60 s sem esperar o relógio. A suíte com os testes do jogador caiu de 28 s para 1,2 s, com resultados idênticos. Testes nunca dependem de tempo real.
- Uma linha por teste (`PASS` ou `FAIL`, `<arquivo>::<teste>`, tempo em ms, mensagens das falhas) e um resumo final.
- Código de saída 0 só se houver ≥ 1 teste e nenhuma falha; 1 nos demais casos.
- Erro de script (tipo SCRIPT: execução ou parse de GDScript) durante um teste reprova esse teste, com mensagem e `arquivo:linha`, via `Logger` (`OS.add_logger`, `tests/framework/error_capture.gd`); a não ser que o teste o declare com `expect_script_error(trecho)`. Erro de engine (`push_error`, `ConfigFile`) não reprova: vira nota, a não ser que o teste o declare com `expect_engine_error(trecho)`; um erro declarado que não ocorre reprova. O `tools/run_tests.ps1` ainda trata qualquer linha `SCRIPT ERROR` da saída como falha (segunda linha de defesa).
- Os autoloads (F1-004) precisam estar disponíveis quando os testes rodam.

- **Watchdog por progresso** (R1-10, F1-010): o teste é reprovado após `STALL_PHYSICS_FRAMES` (600 = 10 s de física) sem `wait_*` nem fim de fase. Há um teto de tempo de parede de 300 s por fase, como rede de segurança. Opções para meta-testes: `--stall-frames=<n>` e `--wall-ms=<n>`. Uma corrotina travada não pode ser cancelada em GDScript, então o disparo encerra a execução. Um laço síncrono sem `await` não é pego.
- **Isolamento de física** (R1-07, F1-010): entre dois testes o runner espera `FLUSH_PHYSICS_FRAMES` (2) frames de física, para que os nós do teste anterior saiam do espaço de física. Dentro de um teste, fases que compartilham o mesmo mundo sem flush mudam de resultado: medido com `--fixed-fps 60`, 5 fases antes da fase 0,475 (piso 0,28) mudam a descida no tick 108. Use `add_isolated_world()` ou `release_and_flush()`. Regressão: `tests/meta/test_r107_historico_no_mundo.gd`.

**Pipeline `tools/run_tests.ps1`:** importação headless → arc04 (parse de todos os scripts de `game/`) → runner (padrão) → runner-property → runner-meta. Cada etapa reprova com código diferente de 0 ou com linha `SCRIPT ERROR`. Sai com 0 ou 1 e imprime o comando exato de cada etapa.

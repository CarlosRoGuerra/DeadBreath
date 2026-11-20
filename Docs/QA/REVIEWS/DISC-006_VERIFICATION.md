# DISC-006 — Re-verificação da v0.2 dos documentos da Fase 0

| Campo | Valor |
|---|---|
| Data | 2026-11-20 |
| Revisor | Technical Reviewer (Agente 10), contexto independente |
| Base | Docs/QA/REVIEWS/DISC-006.md (v0.1, 48 achados) e Docs/QA/REVIEWS/DISC-006_RESOLUTION.md (rastreio da v0.2) |
| Lidos integralmente | COMPONENT_CONTRACTS.md v0.2, DATA_STRUCTURES.md v0.2, SYSTEM_ARCHITECTURE.md v0.2, TEST_PLAN.md v0.2, ROADMAP.md, TASK_BOARD.md, ENGINE_DECISION.md, KNOWN_ISSUES.md, AGENT_ASSIGNMENTS.md, CHANGELOG.md, Docs/QA/EVIDENCE/DISC-001_environment.txt |
| Método | Leitura de cada trecho indicado no RESOLUTION. Busca textual por IDs, nomes de tipos e termos antigos. Recontagem dos exemplos de DATA §2.3 e do AI-03 em awk. Conferência cruzada §17 × TEST_PLAN, nomes CONTRACTS × DATA e ordem de tick SYSTEM §6 × CONTRACTS. |
| Limitações | Sem internet. Godot não foi executado. Não se verificou a versão 4.7.2 nem fontes externas. Nenhum arquivo existente foi alterado. |

---

## 1. Veredito

**REPROVADO, com escopo reduzido.**

A v0.2 resolveu o achado CRÍTICO (R-01) e quase todos os ALTO e MÉDIO de contrato. Dos 48 achados da v0.1, 44 estão RESOLVIDOS, 4 PARCIAIS e nenhum NÃO RESOLVIDO. Porém a própria correção abriu contradições, e três itens ALTO continuam abertos:

- **R-11 (PARCIAL, ALTO):** o ramo "ouvido" do estresse depende de uma origem de ruído que o R-01 removeu do `HeardNoise`.
- **N-01 (ALTO):** o mesmo problema, visto pelo lado da ameaça percebida e da música.
- **N-02 (ALTO):** o EnemyController deve emitir um `NoiseEvent`, mas ARC-01 proíbe `NoiseEvent` em `components/enemy/`.

Pelo critério 3 do Gate F0 ("nenhum achado CRÍTICO ou ALTO em aberto"), o gate ainda não pode fechar. As três correções são locais (COMPONENT §5 e §8.1, DATA §1.5 e §2, ARC-01). Depois delas, uma reavaliação curta deve dar **APROVADO COM RESSALVAS**.

A escolha da engine não está em questão.

## 2. Contagem

| Status | Quantidade | Itens |
|---|---|---|
| RESOLVIDO | 44 | Todos, exceto os listados abaixo |
| PARCIAL | 4 | R-11 (ALTO), R-13 (MÉDIO), R-19 (MÉDIO), R-47 (BAIXO) |
| NÃO RESOLVIDO | 0 | — |

Regressões e contradições novas introduzidas pela v0.2: **18** (2 ALTO, 3 MÉDIO, 13 BAIXO).

ALTO em aberto no total: **3** (R-11, N-01, N-02).

---

## 3. Status dos achados R-01 a R-22

| ID | Sev. original | Status | Justificativa |
|---|---|---|---|
| R-01 | CRÍTICO | RESOLVIDO | DATA §2: `HeardNoise` tem só categoria, `perceived_db`, `estimated_position`, `confidence` e `timestamp`. NOI-INV-4 e NOI-03 cobrem o campo. O vazamento para a IA foi fechado. A correção abriu N-01. |
| R-02 | ALTO | RESOLVIDO | ENGINE §7 e ROADMAP Gate F0 item 2 usam o spike como critério. DISC-003 é o dono. F1-002 virou integração. |
| R-03 | ALTO | RESOLVIDO | Autoload NoiseBus removido (SYSTEM §2 e §3). `AcousticWorld` é L2. CheckpointManager é L2. ARC-05 cobre a regra de camadas. |
| R-04 | ALTO | RESOLVIDO | `PlayerRoot` é mediador (CONTRACTS §1, PLR-INV-1). O diagrama não tem mais Motor → PhysComp. Motor e fisiologia não se referenciam. ARC-06. |
| R-05 | ALTO | RESOLVIDO | `PerceivableTarget` é componente-filho (CONTRACTS §7.1). `BrainWorldQuery` é atendido por adaptador (§8.2). Ressalva: o PlayerMotor não diz como obtém o corpo (N-08, BAIXO). |
| R-06 | ALTO | RESOLVIDO | ENGINE §4 (C2) e §7 (V3) exigem janela. SYSTEM §12 diz que o screenshot é "Com janela". |
| R-07 | ALTO | RESOLVIDO | Chaves em CONTRACTS §15 (`subtitles_enabled`, `respiratory_indicator`, `effects_intensity`, `input_bindings`). F1-013, F2-007, F3-006 e ACC-01 a ACC-06 no TEST_PLAN. |
| R-08 | ALTO | RESOLVIDO | ENGINE §5.1 tem uma linha por objetivo de §12 e declara lacunas ("sem medição", "não verificado"). Ressalva: algumas afirmações sem fonte (N-15). |
| R-09 | ALTO | RESOLVIDO | AIProfile numérico (DATA §3.1). Fórmulas de visibilidade, suspeita e confirmação (§3.2 e §3.3). AI-03 e AI-06 operacionais. Contas conferidas na seção 6. |
| R-10 | ALTO | RESOLVIDO | Contrato do EnemyController (CONTRACTS §8.1) com API, sinais, ordem de tick e ENM-INV-1 e 2. Ressalvas: captura fora de ordem (N-03) e VOICE com NoiseEvent (N-02). |
| R-11 | ALTO | **PARCIAL** | Monitor, ferimento (`add_injury`, `injury_spike` 20), tabela de consequências e `steadiness` estão definidos. Porém o `heard_factor` do monitor usa ruídos "de inimigos" (DATA §1.5, CONTRACTS §5). O R-01 removeu a origem do `HeardNoise`, então esse ramo não é implementável como escrito (N-01). A regra "exposição à luz ≥ 0,15" do inimigo visto é ambígua (N-09). |
| R-12 | ALTO | RESOLVIDO | `BreathEmitter` é o produtor único (CONTRACTS §6.3). BreathingAudio só consome (§14). NOI-05 cobre. Ressalva: produtor do gasp não atribuído (N-10). |
| R-13 | MÉDIO | **PARCIAL** | Piso por sala, offset de clima e perda `0,1·d` foram adicionados (DATA §2.2 e §2.3). Mas o piso interno de 12 dB, somado a 3, dá 15 dB, igual ao limiar do Observer. Para todos os perfis o limiar efetivo é o próprio limiar, então o piso interno não mascara nada. Além disso, uma tosse ainda é audível a ~100 m em campo aberto e a ~15 m através de uma parede (Observer). Ver seção 6. |
| R-14 | MÉDIO | RESOLVIDO | Atenuação nativa em `ATTENUATION_DISABLED` (CONTRACTS NOI-INV-2, SYSTEM §7). Teste NOI-04. |
| R-15 | MÉDIO | RESOLVIDO | Tabela completa de ticks (SYSTEM §6). Input amostrado em `step()`. Latência de 1 tick documentada. Ressalva: latência do monitor não documentada (N-11). |
| R-16 | MÉDIO | RESOLVIDO | Motor de física decidido no V6 (ENGINE §6 e §7). Afirmação de estabilidade removida; ENGINE §6 declara que a versão padrão não foi confirmada. |
| R-17 | MÉDIO | RESOLVIDO | `--import` antes de `--check-only` (SYSTEM §12, ARC-04). V4 com código de saída (ENGINE §7). Warnings `untyped_declaration`, `unsafe_method_access` e `unsafe_property_access` como erro. |
| R-18 | MÉDIO | RESOLVIDO | `core/enums.gd` com `class_name Enums` (DATA §0). Uso como `Enums.X` em todos os contratos. Busca por nomes sem prefixo: nenhum uso restante. |
| R-19 | MÉDIO | **PARCIAL** | Declarados agora: ItemCatalog, ItemUseResult, ObjectiveStatus (enum), PerceptBatch, BrainWorldQuery, InteractionContext, RoomVolume, Portal, MedicationProfile, EnvironmentState, HideableInfo, EnemyInitialState. Faltam: `EnemyWorldQuery` (CONTRACTS §8.2, F4-004), `SnapshotSchema` (SYSTEM §3, CONTRACTS §12), parâmetros de `CouplingConfig` (CONTRACTS §4.2 usa a classe, DATA §1.6 só tem fórmulas), `AIProfile` como classe (só tabela), `LightExposureProbe`, `Pickup`, assinatura de `BreathParams.from_snapshot`, e o campo `last_seen_enemy_distance` (N-06). |
| R-20 | MÉDIO | RESOLVIDO | Fórmulas de `CouplingFactors` e de `recovery_progress` (DATA §1.4 e §1.6). Tabela completa de transições, com histerese. `respiratory_load` removido. Escala da tosse. `cough_warning_time_s` unificado. |
| R-21 | MÉDIO | RESOLVIDO | "Redução absoluta de 0,35" (DATA §1.7). PHY-04 com redução absoluta ≥ 0,30 (TEST_PLAN). |
| R-22 | MÉDIO | RESOLVIDO | CONTRACTS §17 mapeia todos os invariantes. Os IDs citados existem no TEST_PLAN: ARC-06, MOT-01..03, PHY-05..10, ARC-01, NOI-01..04, AI-06..08, INV-01..03, OBJ-01..03, PER-06. |

---

## 4. Itens R-23 a R-48

Apenas um item não está resolvido:

| ID | Sev. original | Status | Justificativa |
|---|---|---|---|
| R-47 | BAIXO | PARCIAL | AGENT_ASSIGNMENTS §2 diz que Plan e Explore "não têm Edit/Write", o que é verdade, mas esses agentes mantêm Bash, que também escreve arquivos. A frase "garantia técnica" é exagerada. Recomendação: dizer "sem Edit e Write; Bash ainda permite escrita; conferir `git status` após cada revisão", ou restringir Bash. |

Os demais estão RESOLVIDOS. Destaques:

- R-24: `rng_states` como string e PER-07 existem. Ver N-04 para a completude do snapshot.
- R-29: resolvido por decisão DIR-02. Ressalva: MASTER §14 diz "cada tarefa deverá possuir" critérios e testes. O usuário deve ratificar a dispensa.
- R-44: a política de erros existe (SYSTEM §14). Ressalva: o caso ".tres ausente" aponta para ARC-04, que só faz parse (N-13).
- R-34: DISC-001 está gravado em Docs/QA/EVIDENCE, com a versão 4.7.2 e a data vindas da API do GitHub. Divergência de 19,5 GB para 19,6 GB (N-14).
- R-35: RSK-01 a RSK-12 cobrem os riscos citados nas ADRs. A entrada de licenças existe (F1-014).

---

## 5. Regressões e contradições novas

| ID | Sev. | Arquivo e seção | Problema | Recomendação |
|---|---|---|---|---|
| N-01 | ALTO | COMPONENT_CONTRACTS §5 (PlayerThreatMonitor: "HeardNoise com origem em inimigo"); DATA_STRUCTURES §1.5 (`heard_factor`); DATA §2 (HeardNoise); COMPONENT §6.2 (`noise_resolved_for_player` "somente para L3/debug") | Ao remover a origem do `HeardNoise` (R-01), o monitor perdeu o dado que usa. O ramo auditivo do estresse, o `in_chase` por som e a música por ameaça não têm fonte definida. O único canal com a origem é restrito a L3 e debug. | Criar um tipo para o ouvinte do jogador, por exemplo `PlayerHeardNoise` com `category`, `perceived_db`, `source_is_enemy: bool` e `timestamp`, sem posição e sem id. O AcousticWorld entrega esse tipo só ao PlayerThreatMonitor. Acrescentar o tipo à proibição de ARC-01 em `sim/ai/` e `components/enemy/`. Atualizar §5, §6.2 e NOI-03. |
| N-02 | ALTO | COMPONENT_CONTRACTS §8.1 passo 3 (EnemyController "emite NoiseEvent VOICE") × SYSTEM §5 e TEST_PLAN ARC-01 (proíbe `NoiseEvent` em `components/enemy/`) | Contradição normativa. O contrato manda o EnemyController criar um `NoiseEvent`, e a verificação estática proíbe isso no mesmo diretório. ARC-01 reprovaria o contrato na F4. | O EnemyController chama um `NoiseEmitter` filho (em `components/acoustics/`, fora do escopo de ARC-01) com `emit_noise(Enums.NoiseCategory.VOICE, intensidade, duração, sound_id)`. Corrigir o texto do passo 3. |
| N-03 | MÉDIO | COMPONENT §8.1 passo 4 (captura dentro do tick de -40) × SYSTEM §6 linha 6 (captura em -30, etapa própria). Nó `Squad` (SYSTEM §6, prioridade -50) sem dono no CONTRACTS. | Duas ordens para a captura. O nó Squad não tem contrato. | Manter SYSTEM §6 como fonte: captura em etapa própria em -30. Declarar o nó Squad e seu dono. |
| N-04 | MÉDIO | DATA_STRUCTURES §6 (snapshot) × TEST PER-07 × DATA §1.2, §1.4, §1.5 | O snapshot não contém todo o estado que afeta ticks futuros. Faltam: estado e tempo mínimo de permanência do respiratório, pico para `recovery_progress`, tosse agendada e cooldown, flag de exaustão da stamina (histerese de 25), timer de decaimento do estresse, cooldown da bombinha. Com o snapshot atual, PER-07 não passa. | Listar no snapshot cada campo que influencia tick futuro. PER-07 compara o estado campo a campo antes e depois de carregar. |
| N-05 | MÉDIO | ROADMAP Gate F2 (PHY-01 a PHY-11) × TASK F2-004 e F2-006 × COMPONENT §4.2 e §5 | Os testes da F2 precisam de `PhysiologyInputs.threat` (PlayerThreatMonitor, F4) e de startle e injury (dependem de ruído, F3). A F2 não define stub nem injeção para esses dados, mas o gate exige PHY-01 a PHY-11 verdes. | Declarar na F2 um `ThreatSample` injetável. Marcar os testes que usam stub. Registrar que o estresse real entra na F4. |
| N-06 | BAIXO | COMPONENT §5 (`sample()` retorna `last_seen_enemy_distance`) × DATA §5 (ThreatSample: `seen_proximity`, `heard_factor`) | Campo citado só num dos documentos. | Usar os campos de DATA §5 ou acrescentar `last_seen_enemy_distance` à DATA. |
| N-07 | BAIXO | DATA §5 (`InteractionContext`, `var actor: Node`) × SYSTEM §2 (L1 nunca referencia Node) | Se o tipo estiver em `sim/`, viola a regra de camada. | Mover para `components/interaction/` ou trocar `actor` por um id. |
| N-08 | BAIXO | COMPONENT §2 (PlayerMotor extends Node; `step()` move o corpo) × PLR-INV-1 | O contrato não diz como o PlayerMotor obtém o CharacterBody3D. Não pode referenciar o PlayerRoot. | Declarar injeção: o PlayerRoot passa a referência do corpo ao motor. |
| N-09 | BAIXO | COMPONENT §5 (inimigo visto: "exposição à luz ≥ 0,15") | Não se diz se é a luz sobre o inimigo ou sobre o jogador. O LightExposureProbe é do jogador. | Especificar a luz que atinge o alvo e como ela é medida. |
| N-10 | BAIXO | COMPONENT §4.1 (`startle_gasp`) × DATA §1.3 (gasp: evento BREATHING de 42 dB) | Não se diz quem cria o `NoiseEvent` do gasp. Se for outro produtor, quebra o produtor único (R-12). | Atribuir ao BreathEmitter, que escuta `startle_gasp`. |
| N-11 | BAIXO | SYSTEM §6 (latência documentada só para ruído emitido após a etapa 3) × COMPONENT §1 (passo 2 do PlayerRoot usa o `sample()` de -90) | O `sample()` lê `HeardNoise` entregue em -60 do tick anterior. Essa latência não está documentada. | Acrescentar a latência de 1 tick do monitor à nota de SYSTEM §6. |
| N-12 | BAIXO | TEST_PLAN AI-02 ("passo de 40 dB percebido a 30 dB") | Sem distância. Pela fórmula, um passo de 40 dB a 1 m chega a 30 dB a ~3,1 m. | Reescrever: "passo de 40 dB a 1 m, ouvinte a 3,1 m (30 dB percebidos)". |
| N-13 | BAIXO | SYSTEM §14 (".tres ausente" aponta para ARC-04) | ARC-04 só faz parse. Não há teste de config ausente. | Criar teste próprio (ARC-07 ou PER-08 estendido). |
| N-14 | BAIXO | ENGINE §2 e KNOWN_ISSUES ENV-002 (C: com 19,6 GB) × DISC-001_environment.txt (C: livre 19,5 GB) | Divergência pequena entre documento e evidência. | Usar 19,5 GB, valor da evidência. |
| N-15 | BAIXO | ENGINE §5.1 ("Guias de 2026 recomendam CPU de 8 núcleos, 32 GB..."; "AudioStreamInteractive... desde a 4.3") × ENGINE §9 | Afirmações sem fonte listada. A §9 cita apenas releases e preços. | Marcar como "não verificado" ou citar a fonte na §9. |
| N-16 | BAIXO | COMPONENT §7.2 (`PER-INV-1`, firewall) × TEST_PLAN (`PER-01` a `PER-10`, persistência) | Prefixo PER usado para dois assuntos. | Renomear o invariante de firewall (por exemplo FW-INV-1). |
| N-17 | BAIXO | AGENT_ASSIGNMENTS §2 e SYSTEM §11 | `components/acoustics/` (AcousticWorld, NoiseEmitter, BreathEmitter) não tem dono na tabela de papéis. | Atribuir AI Engineer e Audio Engineer. |
| N-18 | BAIXO | SYSTEM §3 (BreathEmitter: AI + Audio) × TASK_BOARD F2-006 (BreathEmitter: Audio + Physio) | Dono divergente do mesmo componente. | Alinhar os dois documentos. |

---

## 6. Conferências pedidas

### 6.1 §17 do CONTRACTS × IDs do TEST_PLAN

Todos os IDs citados em §17 existem no TEST_PLAN: ARC-06, MOT-01, MOT-02, MOT-03, PHY-09, PHY-05, PHY-06, PHY-10, PHY-07, PHY-08, ARC-01, NOI-01, NOI-02, NOI-03, NOI-04, AI-06, AI-07, AI-08, INV-01, INV-02, INV-03, OBJ-01, OBJ-02, OBJ-03, PER-06. Nenhuma regressão de mapeamento. O TEST_PLAN usa `PER-INV-1` no CONTRACTS para o firewall, o que é o problema N-16.

### 6.2 Nomes: CONTRACTS × DATA

- Enums: todos com prefixo `Enums.`. Nenhuma ocorrência sem prefixo.
- Campos de `PhysiologyInputs`, `CouplingFactors`, `PhysiologySnapshot`, `PerceptBatch`, `PropagationResult`: consistentes.
- Divergências: `ThreatSample.last_seen_enemy_distance` (N-06); `CouplingConfig`, `EnemyWorldQuery`, `SnapshotSchema`, `LightExposureProbe`, `AIProfile` como classe (R-19 PARCIAL).

### 6.3 Ordem de tick (SYSTEM §6) × CONTRACTS

| Etapa | Prioridade | SYSTEM §6 | CONTRACTS | Resultado |
|---|---|---|---|---|
| PlayerRoot | -90 | Motor, ameaça, fisiologia, limites, BreathEmitter | §1 mesmo ordem | Consistente |
| AcousticWorld | -60 | Fila de ruídos | §6.2 -60 | Consistente |
| Squad | -50 | Libera mensagens | Sem contrato de nó | N-03 |
| EnemyController | -40 | Percepts, cérebro, navegação | §8.1 -40 | Consistente |
| Captura | -30 | Etapa própria | §8.1 passo 4, dentro de -40 | Contradição (N-03) |

### 6.4 Números de DATA §2.3 (recalculados)

Fórmula de perda: `20·log10(max(d,1)) + 0,1·d`. Limiar de audibilidade: `max(limiar do ouvinte, piso da sala + offset de clima + 3)`.

| Exemplo | Recalculado | Conclusão |
|---|---|---|
| Respiração calma no guarda-roupa, 1 m / 2 m | 13,9 dB / 7,8 dB | Inaudível (limiar 15). Confere com o texto (14 e ≈8). |
| Respiração ofegante (30 dB), 1 m / 2 m | 23,9 dB / 17,8 dB | Audível a 2 m. Confere (24 e ≈18). |
| Tosse 65 dB, 5 m, uma parede | 65 − 13,98 − 0,5 − 25 = 25,5 dB | Audível. Confere. |
| Tosse 65 dB, 5 m, duas paredes | 0,5 dB | Inaudível. Confere. |
| Piso interno 12 dB | limiar efetivo = max(limiar, 15) | Para Observer (15), Leader (20) e Aggressive (24) o piso não altera o limiar. Não mascara nenhum perfil. |
| Alcance da tosse (Observer), campo aberto | ~100 m | Não consta no texto. Confirma R-13 PARCIAL. |
| Alcance da tosse (Observer), uma parede | ~15 m | Em casa pequena, a tosse ainda é ouvida em quase toda a casa. |
| Alcance da tosse (Observer), um piso (30 dB) | ~9 m | Idem. |
| Alcance de respiração 35 dB (Observer), campo aberto | ~9 m | Consistente com "respiração ofegante denuncia". |

Conclusão: a correção do piso foi feita, mas o piso interno não tem efeito prático. Recomendação: piso interno de casa com chuva na faixa de 25 a 30 dB (ou piso de janela para os cômodos com janela), e um teste de alcance no cenário de referência.

### 6.5 AI-03 (DATA §3.3)

- `distance_factor` = 1 − (8/16)² = 0,75.
- `light_factor` = 1,0 (exposição 1). Postura 1,0. Ocultação 0. Oclusão 0 (los = 1).
- `visibility` = 0,75. Acima de 0,4, então `confirm` cresce 0,75 por segundo.
- `confirm` chega a 0,6 em 0,6 / 0,75 = **0,80 s**. CHASE em 0,80 s, dentro de 1,5 s. **Confere** com o texto.

### 6.6 Outras contas de DATA

- AI-02: suspeita por som = (30 − 15) × 0,04 = 0,60, limitada a 0,60. Cruza 0,5 (INVESTIGATE) no mesmo tick. **Confere** (N-12 quanto à distância).
- STL-03: 18 − 3 = 15 dB; tolerância 14,5. **Confere.**
- PHY-02: 0,4 × (80 − 30)/70 = 0,286 ≥ 0,25. **Confere.**
- PHY-01 e PHY-03 (já recalculados na revisão anterior): PHY-01 severidade 0,453 e cruzamento de 0,35 em 5,5 s; PHY-03 de 0,6 abaixo de 0,2 em 6,7 a 10,0 s. **Conferem.**
- Estresse de 100 a 0: 4 + 100/3 = 37,3 s. **Confere** com DATA §1.4.

---

## 7. Ordem sugerida de correção

1. N-02 e N-01 (COMPONENT §5, §8.1, §6.2; DATA §1.5 e §2; ARC-01 e NOI-03). Fecham os dois ALTO novos e R-11.
2. N-04 (snapshot completo para PER-07) e N-03 (ordem da captura).
3. R-13 (piso interno) e R-19 (declarações faltantes).
4. Os BAIXO.

Depois das correções 1 e 2, pedir nova verificação curta, restrita a R-11, R-13, R-19, N-01, N-02, N-03, N-04. Com isso, o critério 3 do Gate F0 pode ser cumprido.

---

## 8. Observações

- Não foram verificadas, por falta de internet: versão 4.7.2, datas e preços de terceiros, afirmações de N-15.
- Godot não foi executado. As contas foram feitas por recálculo (awk) e por leitura.
- Nenhum arquivo existente foi alterado. Este relatório é o único arquivo criado nesta verificação.

---

## Rodada 3 — verificação curta dos itens abertos (após a Rodada 2)

Escopo: apenas os itens que ficaram abertos e os trechos alterados na Rodada 2. Os documentos não foram relidos integralmente. Nenhum arquivo existente foi alterado; esta seção é a única escrita desta rodada.

### 1. Veredito

**APROVADO COM RESSALVAS.** Não há CRÍTICO nem ALTO em aberto, então o critério 3 do Gate F0 está cumprido. As ressalvas são um MÉDIO parcial (N-04), um MÉDIO novo (N-19) e quatro BAIXOS, todos de completude e de texto. Devem ser corrigidos antes do congelamento dos contratos (v1.0) e, no caso de N-04, antes do Gate F2.

### 2. Contagem

| Item | Status | Observação |
|---|---|---|
| R-11 / N-01 | RESOLVIDO | `PlayerHeardNoise` declarado (DATA §2); entregue só ao monitor (CONTRACTS §6.2); proibido na IA (ARC-01, NOI-03). |
| N-02 | RESOLVIDO | Fala por `NoiseEmitter` filho (CONTRACTS §8.1 passo 3); ARC-01 não proíbe `NoiseEmitter`. |
| N-03 | RESOLVIDO | Captura em `EnemyCaptureArea` (-30), igual em CONTRACTS §8.1 e SYSTEM §6; nó `Squad` com dono (SYSTEM §3). Resíduo de nome: N-20. |
| N-04 | **PARCIAL** | Regra de completude (DATA §6.1) cobre Stamina, Stress e Respiratory. Faltam BreathEmitter e PlayerThreatMonitor (ver seção 5). |
| N-05 | RESOLVIDO | `ThreatSource` e `StubThreatSource` (CONTRACTS §1 e §5; DATA §9); PHY-12 na F4 (ROADMAP Gates F2 e F4; TASK_BOARD F2-004 e F4-006). |
| R-13 | RESOLVIDO | Pisos de chuva com `masking_margin_db` (DATA §2.3 e §3.1); os sete alcances de STL-07 conferidos (seção 3). |
| R-19 | RESOLVIDO | Declarados em DATA §9. Resíduo BAIXO: N-22. |
| R-47 | RESOLVIDO | Texto corrigido em AGENT_ASSIGNMENTS §2 (Bash ainda permite escrita, dito explicitamente). |
| N-06 a N-18 (BAIXOS) | RESOLVIDOS | Todos verificados; ver seção 4. |

Contagem desta rodada: **RESOLVIDO** 13 (R-11/N-01, N-02, N-03, N-05, R-13, R-19, R-47 e N-06 a N-18, exceto N-04); **PARCIAL** 1 (N-04); **NÃO RESOLVIDO** 0. Novos: N-19 (MÉDIO) e N-20 a N-23 (BAIXO).

ALTO em aberto: **0**. MÉDIO em aberto: **2** (N-04 e N-19).

### 3. Contas dos alcances (DATA §2.3 com a fórmula de §2.2)

Fórmula: perda = `20·log10(max(d,1)) + 0,1·d`. Limiar efetivo do Observer em cômodo interno = max(15; 22 + 0 − 3) = **19 dB**. Demais exemplos: porão (limiar 15) e exterior (limiar 35).

| Exemplo (DATA §2.3) | Orçamento (dB) | Alcance recalculado | Alcance no texto | Diferença |
|---|---|---|---|---|
| Calma no guarda-roupa: 20 − 6 = 14 | 14 < 19 | inaudível | inaudível | OK |
| Ofegante no guarda-roupa: 30 − 6 − 19 = 5 | 5 | 1,74 m | ≈ 1,7 m | 0,04 m |
| Chiado no guarda-roupa: 42 − 6 − 19 = 17 | 17 | 6,57 m | ≈ 6,6 m | 0,03 m |
| Tosse, 1 parede: 65 − 25 − 19 = 21 | 21 | 10,00 m | ≈ 10 m | 0 |
| Tosse, 2 paredes: 65 − 50 = 15 | 15 < 19 | inaudível | inaudível | OK |
| Tosse no quintal (limiar 35): 65 − 35 = 30 | 30 | 23,99 m | ≈ 24 m | 0,01 m |
| Ofegante no porão (limiar 15): 30 − 6 − 15 = 9 | 9 | 2,73 m | ≈ 2,7 m | 0,03 m |

Todos dentro de ±0,2 m. STL-07 descreve os mesmos sete exemplos com a mesma tolerância. As contas conferem.

Nota de conta: na primeira tentativa do ofegante eu subtraí o abafamento duas vezes e obtive 0 m. A conta correta parte do nível emitido (30 dB), subtrai o abafamento (6) e o limiar (19), o que dá 5 dB de orçamento.

Conferência de AI-02 (TEST): 40 − 20·log10(3,05) − 0,1·3,05 = 30,0 dB percebidos. Suspeita = (30 − 15) × 0,04 = 0,60, limitada a 0,60. Cruza 0,5 e vai a INVESTIGATE. Confere. O limiar efetivo é 15 porque o piso de 12 dB com margem −3 dá 9, abaixo do limiar de 15.

Conferência de PHY-12 (TEST): inimigo visível a 3 m → `seen_proximity` = 1 → estresse +15/s, então sobe ≥ 10 em 1 s. Inimigo só audível a 30 dB → `heard_factor` = (30 − 15)/30 = 0,5 → +2,5/s. Confere.

### 4. Itens BAIXOS (N-06 a N-18 e R-47)

Todos resolvidos. Verificações feitas:

- N-06: CONTRACTS §5 usa os campos de DATA §5.
- N-07: `InteractionContext` em `components/interaction/` (DATA §5).
- N-08: `PlayerMotor.setup(body, head)` injetado pelo PlayerRoot (CONTRACTS §1 e §2).
- N-09: luz medida sobre o inimigo pelo `LightExposureProbe` dele (CONTRACTS §5).
- N-10: `emit_gasp()` no BreathEmitter, conectado pelo PlayerRoot (CONTRACTS §1 e §6.3).
- N-11: latência de 1 tick documentada (SYSTEM §6).
- N-12: AI-02 com distância de 3,05 m e piso de 12 dB (TEST AI-02).
- N-13: ARC-07 existe (TEST §2.10; SYSTEM §14).
- N-14: ENGINE §2 e KNOWN_ISSUES ENV-002 com ≈ 19,5 GB e nota sobre as duas leituras.
- N-15: ENGINE §5.1 cita fontes não oficiais e marca AudioStreamInteractive como não verificado.
- N-16: CONTRACTS §7.2 e §17 usam FW-INV-1. Não sobrou PER-INV em nenhum documento.
- N-17: AGENT_ASSIGNMENTS §2 atribui `components/acoustics/` aos AI e Audio Engineers.
- N-18: BreathEmitter com Physiological Eng. + Audio Eng. em SYSTEM §3 e TASK_BOARD F2-006.
- R-47: AGENT §2 agora diz que Bash permite escrita.

### 5. Contradições novas e item parcial

#### N-04 (PARCIAL, MÉDIO) — DATA_STRUCTURES §6.1 (regra de completude)

A regra exige que todo campo que afeta tick futuro esteja no snapshot. A tabela cobre StaminaModel, StressModel e RespiratoryModel. Faltam:

- **BreathEmitter:** fase do ciclo respiratório e instante do próximo NoiseEvent. Sem isso, o evento de respiração após carregar cai em outro instante e o estado da IA diverge.
- **PlayerThreatMonitor:** janelas de 3 s de `in_chase` e de `PlayerHeardNoise` recentes. Sem isso, o estresse e a música divergem nos 3 s após carregar.

PER-07 ("campo a campo", com tosse agendada e cooldowns) não passa com o snapshot atual.

Recomendação: acrescentar a DATA §6.1 uma linha para BreathEmitter (`cycle_phase_s`, `next_event_in_s`) e outra para PlayerThreatMonitor (`in_chase_remaining_s`, `recent_enemy_heard_s`), com `to_dict`/`from_dict` correspondentes em CONTRACTS §4.2 e §5.

#### N-19 (MÉDIO, novo) — dependência circular entre PlayerThreatMonitor e AcousticWorld

- SYSTEM §3 (diagrama, linha 89): `Threat --> World`, ou seja, o monitor depende do AcousticWorld.
- COMPONENT §6.2 (linha 203): `register_player_listener(monitor: PlayerThreatMonitor, ear)`, ou seja, o AcousticWorld depende do monitor.

Os dois sentidos formam um ciclo de dependência, que MASTER §13 proíbe ("evitar dependências circulares"). A aresta `Threat --> World` não tem justificativa no contrato, porque o monitor só recebe dados (`receive_heard`).

Recomendação: remover a aresta `Threat --> World` do diagrama e manter `World --> Threat`, a entrega por `receive_heard`. Confirmar que o monitor não chama métodos do AcousticWorld.

#### N-20 (BAIXO, novo) — nome `CaptureArea` ainda presente

- COMPONENT §8.1 (ENM-INV-1, linha 296): "a `CaptureArea` só dispara a captura".
- TEST AI-07 (linha 92): "A `CaptureArea` disparando".
- TASK_BOARD F4-005 (linha 169): "Captura básica (`CaptureArea` → `player_captured`)".

O componente se chama `EnemyCaptureArea` em COMPONENT §8.1 e SYSTEM §3 e §6.

Recomendação: trocar `CaptureArea` por `EnemyCaptureArea` nesses três lugares.

#### N-21 (BAIXO, novo) — "limiar 10" do ouvinte do jogador não aparece na fórmula

- DATA §2.3 (linha 267): "O ouvinte do jogador usa margem 0 e limiar 10."
- A fórmula da mesma seção (linha 263): `effective_threshold = max(hearing_threshold_db, piso + offset + margem)`.

Com piso de 22 dB em cômodo interno, o limiar efetivo do jogador é 22, e o 10 nunca se aplica. O texto sugere o contrário.

Recomendação: escrever "limiar efetivo = max(10; piso + 0)" ou explicar que, onde há piso, o piso prevalece.

#### N-22 (BAIXO, residual de R-19) — classes sem declaração

- Configs `StaminaConfig`, `StressConfig`, `RespiratoryConfig`, `AcousticConfig` e `PlayerMotorConfig` existem só como tabelas em DATA §1 e §2. ARC-03 e ARC-04 supõem classes `class_name`.
- `ThreatSource` e `EnemyCaptureArea` aparecem só em CONTRACTS §5 e §8.1.

Recomendação: declarar cada uma com `class_name` e `@export` em DATA §9, ou apontar onde está declarada.

#### N-23 (BAIXO, novo) — mapeamento incompleto de PER-07

CONTRACTS §17 mapeia PHY-INV-6 apenas a PHY-08. PER-07 (reprodutibilidade após carregar) é a verificação de persistência do mesmo invariante e não aparece no mapa.

Recomendação: mapear PHY-INV-6 a PHY-08 e PER-07.

### 6. Demais verificações da Rodada 3

- ARC-01 (TEST §2.10 e SYSTEM §5): as listas coincidem, incluindo `PlayerHeardNoise`. A exceção de `vision_sensor.gd` aparece nos dois. Sem contradição.
- NOI-03 (TEST): os campos de `HeardNoise` e `PlayerHeardNoise` coincidem com DATA §2.
- STL-07 (TEST): sete exemplos, ±0,2 m, conferidos (seção 3).
- PER-07 (TEST): cita tosse agendada, cooldowns e exaustão, que estão em DATA §6.1, com a ressalva de N-04.
- Ordem de tick (SYSTEM §6 × CONTRACTS): PlayerRoot -90, AcousticWorld -60, Squad -50, EnemyController -40 e EnemyCaptureArea -30 coincidem. Sem contradição.
- Enums (CONTRACTS × DATA): sem uso sem prefixo.

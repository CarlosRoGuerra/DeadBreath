# DISC-006 — Rastreio das correções (DISC-007)

| Campo | Valor |
|---|---|
| Data | 2026-11-20 |
| Autor | Project Director + Software Architect |
| Base | Docs/QA/REVIEWS/DISC-006.md (v0.1 dos documentos: REPROVADO, 48 achados) |
| Resultado | 48 de 48 tratados nos documentos v0.2. **Aguarda nova verificação do Technical Reviewer.** |

| Achado | Sev. | Tratamento | Onde |
|---|---|---|---|
| R-01 | CRÍTICO | `HeardNoise` restrito (categoria, nível, posição estimada, confiança, timestamp); `NoiseEvent` não sai do AcousticWorld | DATA §2; CONTRACTS §6.2, NOI-INV-4; SYSTEM §5; TEST NOI-03, ARC-01 |
| R-02 | ALTO | Spike DISC-003 virou critério do Gate F0; F1-002 reduzido a integração de ferramentas | ENGINE §7; ROADMAP F0; TASK_BOARD DISC-003, F1-002 |
| R-03 | ALTO | Autoload NoiseBus removido; `AcousticWorld` (L2); uma camada por componente; regra L0 | SYSTEM §2–3; CONTRACTS §6.2, §15; TEST ARC-05 |
| R-04 | ALTO | `PlayerRoot` como mediador; motor e fisiologia sem referência mútua | CONTRACTS §1–4; SYSTEM §3, §4, §6; TEST ARC-06 |
| R-05 | ALTO | `PerceivableTarget` como componente-filho; `BrainWorldQuery` via adaptador | CONTRACTS §7.1, §8.2 |
| R-06 | ALTO | C2 corrigido (screenshot exige janela); V3 com janela | ENGINE §4, §5, §7; SYSTEM §12 |
| R-07 | ALTO | Settings de acessibilidade (F1-004), remapeamento (F1-013), indicador respiratório (F2-007), legendas (F3-006) | TASK_BOARD; TEST ACC-01..06 |
| R-08 | ALTO | Avaliação por objetivo da Fase 0, com lacunas marcadas como "sem medição" ou "não verificado" | ENGINE §5.1 |
| R-09 | ALTO | AIProfile numérico; fórmulas de visibilidade, suspeita e confirmação; AI-03 com perfil; AI-06 por invariância | DATA §3.1–3.3; TEST §2.5 |
| R-10 | ALTO | Contrato do EnemyController | CONTRACTS §8.1 |
| R-11 | ALTO | `PlayerThreatMonitor`; ferimento como evento de estresse (+ P-06); tabela de consequências; fórmula de `steadiness` | CONTRACTS §5; DATA §1.3, §1.5, §1.6; TASK_BOARD P-06 |
| R-12 | ALTO | `BreathEmitter` como produtor único; BreathingAudio só consome | CONTRACTS §6.3, §14; TEST NOI-05 |
| R-13 | MÉDIO | Piso de ruído por sala, trovão, perda extra por metro | DATA §2.2–2.3; SYSTEM §7 |
| R-14 | MÉDIO | Atenuação nativa desligada; teste de paridade | CONTRACTS NOI-INV-2; SYSTEM §7; TEST NOI-04 |
| R-15 | MÉDIO | Tabela de ordem completa; input amostrado; latência de 1 tick documentada | SYSTEM §6; CONTRACTS §6.2 |
| R-16 | MÉDIO | Motor de física decidido no spike (V6); afirmação de estabilidade removida | ENGINE §6, §7 |
| R-17 | MÉDIO | `--import` antes do `--check-only`; código de saída; warnings unsafe como erro; parse ≠ teste | ENGINE §5, §7; SYSTEM §12; TEST ARC-04 |
| R-18 | MÉDIO | Enums em `core/enums.gd` | DATA §0 |
| R-19 | MÉDIO | Tipos faltantes declarados; API dos autoloads | DATA §2.5, §3, §4, §5; CONTRACTS §15 |
| R-20 | MÉDIO | Tabela completa de estados, modelo de tosse, `recovery_progress`, fórmulas de acoplamento; `respiratory_load` removido; nome unificado | DATA §1.4, §1.6 |
| R-21 | MÉDIO | "Redução absoluta" explícita | DATA §1.7; TEST PHY-04 |
| R-22 | MÉDIO | Mapeamento invariante → teste; novos IDs | CONTRACTS §17; TEST §2 |
| R-23 | MÉDIO | Gate F2 com PHY-01..11 | ROADMAP F2 |
| R-24 | MÉDIO | `rng_states` como string; PER-07 | DATA §6; TEST PER-07 |
| R-25 | MÉDIO | Escopo do ARC-01 unificado; verificação comportamental AI-06 | SYSTEM §5; TEST ARC-01 |
| R-26 | MÉDIO | Música via PlayerThreatMonitor; sinais de perseguição só para dificuldade; `enemy_alert_changed` removido | CONTRACTS §14, §16 |
| R-27 | MÉDIO | SaveService em F1-004 | TASK_BOARD F1-004 |
| R-28 | MÉDIO | PlayerMotorConfig; regeneração em SLOW; multiplicador de local seguro | DATA §1.1–1.2 |
| R-29 | MÉDIO | Decisão DIR-02 | ROADMAP |
| R-30 | MÉDIO | F2-009 (animações procedurais) | ROADMAP F2; TASK_BOARD |
| R-31 | MÉDIO | P-04 (localização), P-05 (Steam) | TASK_BOARD §2; ROADMAP F7–F8 |
| R-32 | MÉDIO | EnvironmentState; mecânica por capítulo; F6-002/004 | ROADMAP F6; DATA §8; TASK_BOARD |
| R-33 | MÉDIO | ADRs 002–010 em formato curto; CHANGELOG marca como propostas | SYSTEM §15; CHANGELOG |
| R-34 | MÉDIO | Evidência gravada; nota sobre fontes não reverificadas | QA/EVIDENCE/DISC-001_environment.txt; ENGINE §9 |
| R-35 | MÉDIO | RSK-01..12; F1-014 (licenças) | KNOWN_ISSUES; TASK_BOARD |
| R-36 | BAIXO | dt 0,1 s em testes de propriedade; PHY-11; 200 sequências | TEST §1, PHY-06, PHY-11 |
| R-37 | BAIXO | STL-03 ≥ 14,5 dB | TEST STL-03 |
| R-38 | BAIXO | V5 com vsync desligado e p95 | ENGINE §7 |
| R-39 | BAIXO | Desvios de esforço justificados; card de dificuldade (F6-001) | TASK_BOARD §4–5 |
| R-40 | BAIXO | F5: "inventário básico" | ROADMAP F5 |
| R-41 | BAIXO | NoiseBus removido; CheckpointManager só em L2 | SYSTEM §3 |
| R-42 | BAIXO | Uma declaração por linha | CONTRACTS, DATA |
| R-43 | BAIXO | Item água definido | DATA §1.7 |
| R-44 | BAIXO | Política de tratamento de erros | SYSTEM §14; TEST PER-08, PER-09 |
| R-45 | BAIXO | Campo "Testes que passaram" | AGENT_ASSIGNMENTS §5 |
| R-46 | BAIXO | Decisão DIR-01 | ROADMAP |
| R-47 | BAIXO | Restrição por convenção documentada; alternativa técnica (Plan/Explore) | AGENT_ASSIGNMENTS §2 |
| R-48 | BAIXO | Números corrigidos (0,453; 37,3 s) | DATA §1.4 |

Itens adicionais da seção 3.1 da revisão: robustez com pesos iguais e justificativa do runner-up no empate Unity × engine própria → ENGINE §5.

---

## Rodada 2 — achados da verificação (DISC-006_VERIFICATION.md)

| Achado | Sev. | Tratamento | Onde |
|---|---|---|---|
| R-11 / N-01 | ALTO | Novo tipo `PlayerHeardNoise` (categoria, nível, `source_is_enemy`, `sound_id`, timestamp; sem posição, id ou sala), entregue pelo AcousticWorld só ao PlayerThreatMonitor; proibido na IA | CONTRACTS §5, §6.2, NOI-INV-4; DATA §1.5, §2; SYSTEM §5–6; TEST NOI-03, ARC-01 |
| N-02 | ALTO | Fala do inimigo via `NoiseEmitter` filho; o controlador nunca constrói `NoiseEvent` | CONTRACTS §8.1; SYSTEM §5–6 |
| N-03 | MÉDIO | Captura em `EnemyCaptureArea` (-30); nó `Squad` declarado (dono: AI Engineer) | CONTRACTS §8.1; SYSTEM §3, §6 |
| N-04 | MÉDIO | Regra de completude do snapshot + campos internos da fisiologia; `to_dict`/`from_dict` nos modelos; PER-07 campo a campo | DATA §6, §6.1; CONTRACTS §4.2; TEST PER-07 |
| N-05 | MÉDIO | `ThreatSource` + `StubThreatSource` na F2/F3; PHY-12 com fontes reais na F4 | CONTRACTS §1, §5; DATA §9; TEST PHY-12; ROADMAP Gates F2/F4; TASK_BOARD F2-004, F4-006 |
| R-13 | MÉDIO | Pisos de chuva realistas (porão 12, interno 22, janela 28, exterior 38) + `masking_margin_db` por perfil; alcances recalculados (conferidos numericamente); STL-07 | DATA §2.3, §3.1, §3.3; TEST STL-07 |
| R-19 | MÉDIO | Declarados: CouplingConfig, BreathParams, AIProfile, SnapshotSchema, EnemyWorldQuery, LightExposureProbe, StubThreatSource, Pickup | DATA §9 |
| R-47 | BAIXO | Texto corrigido: Plan/Explore mantêm Bash; sem garantia técnica completa | AGENT_ASSIGNMENTS §2 |
| N-06 | BAIXO | `sample()` usa os campos de DATA §5 | CONTRACTS §5 |
| N-07 | BAIXO | `InteractionContext` em `components/interaction/` (L2) | DATA §5 |
| N-08 | BAIXO | `PlayerMotor.setup(body, head)` injetado pelo PlayerRoot | CONTRACTS §1–2 |
| N-09 | BAIXO | Luz medida sobre o inimigo pelo `LightExposureProbe` dele | CONTRACTS §5 |
| N-10 | BAIXO | Gasp produzido pelo BreathEmitter (`emit_gasp`, conectado pelo PlayerRoot) | CONTRACTS §1, §6.3 |
| N-11 | BAIXO | Latência de 1 tick do monitor documentada | SYSTEM §6; CONTRACTS §5 |
| N-12 | BAIXO | AI-02 com distância (3,05 m) e sala de teste com piso 12 | TEST AI-02 |
| N-13 | BAIXO | Novo teste ARC-07 | SYSTEM §14; TEST ARC-07 |
| N-14 | BAIXO | ≈ 19,5 GB, com nota sobre as duas leituras | ENGINE §2; KNOWN_ISSUES ENV-002 |
| N-15 | BAIXO | Fontes citadas (guias não oficiais) e AudioStreamInteractive marcado como não verificado | ENGINE §5.1 |
| N-16 | BAIXO | Invariante do firewall renomeado para FW-INV-1 | CONTRACTS §7.2, §17 |
| N-17 | BAIXO | `components/acoustics/` com donos (AI + Audio) | AGENT_ASSIGNMENTS §2 |
| N-18 | BAIXO | BreathEmitter: Physiological Eng. + Audio Eng. nos dois documentos | SYSTEM §3; TASK_BOARD F2-006 |

---

## Rodada 3 — ressalvas (aplicadas após o veredito APROVADO COM RESSALVAS; não reverificadas)

| Achado | Sev. | Tratamento | Onde |
|---|---|---|---|
| N-04 | MÉDIO | BreathEmitter e PlayerThreatMonitor incluídos na regra de completude, com `to_dict`/`from_dict` | DATA §6.1; CONTRACTS §5, §6.3 |
| N-19 | MÉDIO | Aresta `Threat → World` removida; fica só `World → Threat` (sem ciclo) | SYSTEM §3 |
| N-20 | BAIXO | `CaptureArea` → `EnemyCaptureArea` | CONTRACTS §8.1; TEST AI-07; TASK_BOARD F4-005 |
| N-21 | BAIXO | Texto do limiar efetivo do jogador corrigido | DATA §2.3 |
| N-22 | BAIXO | Padrão de declaração das configs + EnemyCaptureArea | DATA §9 |
| N-23 | BAIXO | PHY-INV-6 → PHY-08 e PER-07 | CONTRACTS §17 |

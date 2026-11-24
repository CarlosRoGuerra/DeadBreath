# Problemas Conhecidos — DEAD BREATH

| Campo | Valor |
|---|---|
| Atualizado | 2026-11-20 |

## Ambiente

| ID | Problema | Severidade | Impacto | Ação recomendada | Status |
|---|---|---|---|---|---|
| ENV-001 | Projeto está dentro do **OneDrive** (`Área de Trabalho` sincronizada) | Alta | O OneDrive sincroniza `.git/` e o cache `.godot/` (milhares de arquivos, alterados a todo momento). Risco de conflito, corrupção de repositório e consumo de banda | Mover para `D:\Dev\DeadBreath` (decisão D-02) | **Resolvido** em 2026-11-20: projeto copiado para `D:\Dev\DeadBreath` (repositório git). A cópia no OneDrive ficou como estava, só com um aviso de mudança. |
| ENV-002 | Disco C: com **≈ 19,5 GB** livres | Alta para UE5, baixa para Godot | Inviabiliza UE5 + Visual Studio no C:. Limita caches | Manter projeto, ferramentas e caches no D: | Aberto |
| ENV-003 | Download e execução de binários externos bloqueados pela política de permissões desta sessão do Claude Code | Alta | Impede instalar o Godot e executar o spike DISC-003 | Usuário autoriza (regra de permissão ou aprovação explícita) ou instala o Godot manualmente e informa o caminho (decisão D-04) | **Resolvido** em 2026-11-20: usuário aprovou D-04; binário oficial baixado com SHA-512 conferido |
| ENV-004 | Sem toolchain C++ (Visual Studio sem instâncias) | Baixa | Bloqueia GDExtension e UE5 C++; não é necessário para a decisão proposta | Instalar só se o profiling exigir GDExtension | Aceito |
| ENV-005 | Sem ferramenta de modelagem 3D (Blender) | Média (a partir da F4) | Pipeline de personagens e props indefinido | Decisão D-05 | Aberto |
| ENV-006 | `.vscode/mcp.json` configura o AppMap, que não suporta GDScript | Informativo | Nenhum para o jogo | Manter sem alterações; não faz parte do projeto | Aceito |
| ENV-007 | O nome da pasta é `DeathBreath`; o jogo é `DEAD BREATH` | Baixa | Inconsistência de nomes em caminhos e no repositório | Renomear para `DeadBreath` na mudança de local (D-02) | **Resolvido**: o novo local se chama `DeadBreath` |

## Arquitetura

| ID | Problema | Severidade | Situação |
|---|---|---|---|
| ARCH-001 | **Precisão de float no save** (achado da F2-004): o JSON do Godot 4.7 grava floats com 15 dígitos. Medido: 96% de 200 mil doubles mudam no ida e volta pelo JSON; `var_to_str` muda 34% (1 ulp); `var_to_bytes`/base64 é exato. Sem tratamento, o PER-07 (reprodutibilidade após carregar) quebra no transporte. | Alta para a F5 | **Decisão até a abertura da F5** (ADR de persistência). Recomendação: o snapshot guarda o estado de simulação em base64 de `var_to_bytes`, ou codifica floats por bits. Hoje o PER-07 valida o ida e volta em memória (exato) |

## Riscos do projeto

| ID | Risco | Severidade | Mitigação | Gatilho de ação |
|---|---|---|---|---|
| RSK-01 | Vulkan com problema na RDNA4 (RX 9070 XT) | Baixa (spike passou com Vulkan 1.4.359 e D3D12) | Renderer D3D12 como fallback, verificado no V5 | Falha em driver futuro |
| RSK-02 | Export templates precisam corresponder exatamente à versão da engine | Baixa | Baixar os templates da 4.7.2 com a engine; versão fixada | F8 |
| RSK-03 | Pipeline de personagens sem solução definida (D-05) | Alta (a partir da F4) | Contingências: humanoides CC0 com rig; escuridão e silhuetas reduzem a exigência de detalhe; freelancer pontual | Fim da F4 sem decisão D-05 |
| RSK-04 | LLMs geram API do Godot 3 | Média | Warnings de tipagem como erro, testes, revisão técnica, documentação oficial da classe | Contínuo |
| RSK-05 | Desempenho do GDScript em IA e acústica | Média | Orçamentos medidos a partir da F4; plano B: C# ou GDExtension no trecho crítico | Orçamento excedido em medição |
| RSK-06 | Determinismo de ponto flutuante entre máquinas | Baixa | Determinismo exigido só na mesma máquina e build (PHY-08, PER-07) | — |
| RSK-07 | Testes de experiência dependem de playtest humano | Média | Playtests marcados nos gates F5 e F7; métricas automáticas | Gate F5 |
| RSK-08 | Migração de esquema de save | Média | `schema_version`, migrações sequenciais, PER-08 | Primeira mudança de esquema |
| RSK-09 | Medição V5 afetada por vsync ou limite do monitor | Baixa | Vsync desligado e p95 especificados. No spike: `vsync_mode=0`, `max_fps=0`, janela 1920×1080 confirmados no log | — |
| RSK-10 | Áudio nativo insuficiente para música adaptativa | Baixa | Reavaliar FMOD (licença e compatibilidade não verificadas) | F3/F7 |
| RSK-11 | Licenciamento de assets externos | Média | `ASSET_LICENSES.md` (F1-014); D-06 aprovada: só CC0 sem aprovação extra; checklist do Technical Reviewer confere | Primeiro asset externo |
| RSK-12 | Custo e perda de contexto entre subagentes | Média | Documentos como memória do projeto; política de custo em AGENT_ASSIGNMENTS §1 | Contínuo |
| RSK-13 | Física reavaliada com corpos dinâmicos | Baixa | **Reavaliada na F3-005 (ENGINE_DECISION §7.2): mantido o GodotPhysics3D.** Com o Jolt, 30 testes de escada falham (corpo no ar na descida). O Jolt só ganha em pilhas de caixas (35,7 mm contra 2,1 mm de afundamento); arremesso e túnel são equivalentes. Level design evita pilhas com mais de 2 corpos dinâmicos | Reabrir se a F4+ precisar de pilhas dinâmicas ou se o custo de física passar do orçamento (medida sem janela) |
| RSK-14 | Variação entre execuções do V5 | Baixa | p95 variou de 1,21 a 1,92 ms (Vulkan) em 2 execuções; margem grande frente ao limite de 6,9 ms. Medições de desempenho futuras usam ao menos 3 execuções | Medição perto do limite |

## Jogo

| ID | Problema | Severidade | Situação |
|---|---|---|---|
| GAME-001 | **Durabilidade do save sem fsync** (F1-010, R1-15): o `AtomicFile` grava `.tmp`, confere os bytes e renomeia, mas o Godot não expõe `FlushFileBuffers`. Numa queda de energia logo depois do `rename`, o arquivo novo pode não estar em disco. A leitura com validador cai para o `.tmp` ou o `.bak`, então não há corrupção silenciosa, mas a última gravação pode se perder | Baixa | Aceito; reavaliar na F5 (checkpoints) |
| GAME-002 | **Rotação do log com outro processo vivo** (F1-010, R1-08): no Windows, o `rename` do `game.log` aberto por outra instância funciona, e essa instância passa a escrever no `game.prev.log`. Sem perda de linhas. Agora o retorno do `rename` é conferido: se falhar, o arquivo é aberto em modo de anexar | Baixa | Mitigado; aceito |
| GAME-003 | **Iluminação da sandbox mais clara que o alvo** (ART_DIRECTION §3): 87–90% das amostras acima de 0,05, alvo de 40–70% | Baixa | Ajuste na F5 |
| GAME-004 | **Câmera com pico transitório na entrada de rampa em sprint** (verificação F1-010, ressalva do R1-03): até 3,8 cm por alguns ticks; em regime o erro é zero | Baixa | Aceito; reavaliar com a câmera de efeitos (F2) |

| GAME-005 | **Pickup de água sem efeito até a F5** (F2-010, R2-08): o item entra no inventário, mas não há como usá-lo (comprimido e água ficam com a tela de inventário) | Baixa | Aceito |
| GAME-007 | **O jogador não empurra objetos com o corpo** (F3-004): o CharacterBody3D só bloqueia o RigidBody3D (spike F3-005). Esbarrar num objeto não o derruba nem faz ruído | Baixa | Aceito na F3. Se o design pedir, o impulso é aplicado pelo código (ENGINE_DECISION §7.2) |
| GAME-008 | **Clique do mouse durante a captura de tecla vira ligação** (achado de QA da F1-011): o clique esquerdo agora é recusado por conflito com o `throw` (F3-004), mas o direito e os demais botões livres continuam virando ligação, inclusive sobre o botão "Voltar" | Baixa | Aberto; rever com a UI de opções (F7) |
| GAME-009 | **Sons altos sobrepostos dependem do limitador do Master** (revisão F3-010, R3-03): um som no teto de ganho fica em −3 a −5 dBFS; dois ou três sobrepostos passam de −1 dBFS na maioria das janelas (estimativa do revisor com os WAVs reais, não medição) e o limitador atua. O trovão caiu para +3,25 dB ao ar livre (R3-07), o que reduz o caso mais comum | Média | Aceito até o playtest: ouvir (BUG-013 e `audition.ps1 -Set world`) e, se o limitador for audível, baixar o teto de ganho ou pôr um compressor no barramento do mundo |
| GAME-010 | **Itens para a F4 vindos da revisão F3-010:** o custo do LightExposureProbe, que percorre a árvore a cada nó criado (R3-10); falas (VOICE) sem emissor nem chave de legenda (R3-11); som corporal de inimigo sem destino no router (R3-14); a trava de som corporal do NoiseEmitter depende só do prefixo `enemy` (N2 da verificação) | Baixa | Tratar na F4 junto com a percepção e os inimigos |
| GAME-011 | **Sandbox sem queda alcançável** (QA F3-011): guarda-corpos, paredes e degraus de 1,2 m cobrem todas as bordas do mezanino; não há queda por entradas de jogo. A queda (FALL 80 dB a partir de 2,5 m/s) foi validada com 1,5 m sintéticos | Baixa | Level design da F5: pelo menos um ponto de queda alcançável no vertical slice |
| GAME-012 | **Sem volume de música nas opções** (F4-006a): o Settings (DATA §10) só tem `master_volume`; o barramento `music` responde só ao volume mestre | Baixa | Acrescentar `music_volume` com a tela de opções (F7) ou antes, se o playtest pedir |
| GAME-013 | **Pontos da onda B da F4 para revisão:** prontidão do mapa de navegação (o AI-02 falhava 3 em 6 antes da correção da prontidão; mecanismo não caracterizado por completo, possivelmente `navigation/3d/use_threads`); o corpo do inimigo gira sem limite de velocidade; porta trancada durante a passagem: o inimigo desiste do destino depois de 30 s (D4-09; antes da revisão F4-010 não havia tempo limite em PATROL, RETURN nem CHASE); o mundo não pausa na captura; a interface do esconderijo para a F5 (grupo `hideable`, meta `persist_id`, `inspect(by_enemy_id)`) não está no contrato | Média | F4-010 (revisão) e F5 |
| GAME-014 | **Itens INFO da revisão F4-010:** a tela de captura não se rearma sozinha (`_capturing` fica verdadeiro; hoje é seguro porque o reinício recarrega a cena; rearmar junto com o `reset_to` na F5, R4-11); os negativos esperados da suíte padrão (`BrainWorldQuery` abstrata, rota vazia) ainda não usam `expect_engine_error` (R4-09) | Baixa | F5 |
| GAME-015 | **Resíduo do firewall por texto (ARC-01)** (verificação F4-010, N1): alias de autoload, concatenação de texto e raio com a máscara da camada do jogador ainda passam pela varredura. A leitura direta do alvo foi fechada na estrutura (só o `VisionSensor` conhece o `PerceivableTarget`) | Baixa | Aceito: o AI-06 (invariância comportamental) é a prova do FW-INV-1; revisar a varredura se um caso real aparecer |
| GAME-006 | **Áudio do corpo a conferir no playtest** (F2-010, R2-03/R2-05): a camada de chiado de 2,4 s pode sobrepor duas vozes a 40 rpm; as vozes são agendadas pelo relógio de quadro, não pelo de física | Baixa | A F2-011 mediu até 3 vozes simultâneas de chiado a 40 rpm (BUG-013). Decisão depois da escuta do usuário |

## Testes e ferramentas

| ID | Problema | Severidade | Situação |
|---|---|---|---|
| TEST-001 | **Dependência de histórico no GodotPhysics3D** (R1-07, PARCIAL): no código revisado, uma fase de escada dava resultado diferente depois de outro cenário no mesmo processo. O sintoma não reproduz no código atual e o mecanismo interno não foi identificado | Média | Mitigado: flush de 2 frames entre testes, `add_isolated_world()` e `release_and_flush()`; regressão em `tests/meta/test_r107_historico_no_mundo.gd`. Regra: testes que repetem cenários de física usam um mundo isolado por fase. Gatilho para reabrir: falha que muda com a ordem dos testes |
| TEST-002 | **Watchdog encerra a execução inteira** (verificação F1-010, N3): um teste parado faz o runner sair; os testes seguintes não rodam e não aparecem no resumo. Uma corrotina travada não pode ser cancelada em GDScript | Baixa | Aceito; o código de saída é 1, então o pipeline reprova. Melhoria futura: listar os restantes como NAO EXECUTADO |
| TEST-003 | **Sem teste de destino bloqueado no AtomicFile** (R1-15, PARCIAL) | Baixa | Aceito; o comportamento está documentado em GAME-001 |
| TEST-005 | **Painel de balanceamento altera Resources compartilhados** (F2-010, R2-09): os ajustes valem para todo usuário do `.tres` na sessão até "Restaurar padrões" ou o fim do processo. O painel consome a tecla F4 mesmo desligado (R2-13) | Baixa | Aceito para ferramenta de debug; testes restauram os padrões |
| TEST-004 | **Rotação do log apaga o `game.prev.log` antes do `rename`** (verificação F1-010, N4): se o `rename` falhar, perde-se o log da penúltima sessão; o log atual é preservado (modo anexar) | Baixa | Aceito |

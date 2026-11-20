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
| RSK-11 | Licenciamento de assets externos | Média | `ASSET_LICENSES.md` (F1-014); só CC0 sem aprovação extra | Primeiro asset externo |
| RSK-12 | Custo e perda de contexto entre subagentes | Média | Documentos como memória do projeto; política de custo em AGENT_ASSIGNMENTS §1 | Contínuo |
| RSK-13 | Física reavaliada com corpos dinâmicos | Baixa | GodotPhysics3D escolhido pelo comportamento do CharacterBody3D (V6). Objetos arremessáveis (F3) podem favorecer o Jolt | F3-004: rodar de novo o spike V6 + teste com RigidBody3D |
| RSK-14 | Variação entre execuções do V5 | Baixa | p95 variou de 1,21 a 1,92 ms (Vulkan) em 2 execuções; margem grande frente ao limite de 6,9 ms. Medições de desempenho futuras usam ao menos 3 execuções | Medição perto do limite |

## Jogo

Nenhum, porque ainda não há código.

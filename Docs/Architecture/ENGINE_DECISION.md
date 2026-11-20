# ADR-001 — Seleção de Engine

| Campo | Valor |
|---|---|
| Status | **PROPOSTA — aguardando aprovação do usuário** |
| Data | 2026-11-20 |
| Responsáveis | Project Director, Software Architect |
| Esforço | EXTRA HIGH |
| Decisão proposta | **Godot 4.7.2-stable (build padrão, sem .NET) + GDScript tipado** |
| Verificação prática na máquina | **PENDENTE.** O download e a execução do binário foram bloqueados pela política de permissões desta sessão (KNOWN_ISSUES ENV-003). O spike DISC-003 é **critério do Gate F0** (§7). |
| Revisão técnica | DISC-006 em 3 rodadas: escolha de engine mantida em todas; documentos de arquitetura APROVADOS COM RESSALVAS na rodada 3 (Docs/QA/REVIEWS/) |

---

## 1. Contexto

DEAD BREATH será desenvolvido por **uma pessoa assistida por agentes de IA**. Esse modelo muda o que importa numa engine:

- Agentes de IA trabalham por **texto e terminal**. Eles não operam editores gráficos de forma interativa, não "veem" a viewport e não editam Blueprints ou assets binários de forma confiável.
- Toda entrega precisa ser **verificável sem intervenção humana**: testes headless, parse de scripts, builds por linha de comando e captura de screenshots para inspeção visual.
- Não há artistas no time. Assets virão de geração procedural, bibliotecas CC0 e, eventualmente, freelancers.

Por isso a engine "mais poderosa" não é automaticamente a melhor para este projeto. O critério dominante é: **o quanto do jogo um agente consegue criar, revisar e testar sozinho**.

## 2. Inventário do ambiente (verificado em 2026-11-20)

| Item | Resultado |
|---|---|
| SO | Windows 11 Pro 10.0.26300 |
| CPU | Intel Core i7-14700KF (20 núcleos / 28 threads) |
| GPU | AMD Radeon RX 9070 XT (RDNA4, 16 GB)¹ |
| RAM | 31,8 GB |
| Disco C: | **≈ 19,5 GB livres** (crítico; 19,6 na primeira leitura e 19,5 na evidência gravada) |
| Disco D: | 249,6 GB livres (recomendado para projeto e ferramentas) |
| Outros discos | E: 78 GB, F: 128 GB, G: 94 GB livres |
| Unreal Engine | **Não instalado** (`C:\Program Files\Epic Games` existe, vazio) |
| Unity / Unity Hub | **Não instalado** |
| Godot | **Não instalado** |
| Visual Studio (C++) | Instalador presente, **nenhuma instância instalada** → sem toolchain C++ |
| Blender | Não instalado |
| Node.js / npm | v22.17.0 / 10.9.2 |
| Python | 3.13.5 (numpy e Pillow disponíveis; scipy ausente) |
| .NET SDK | 10.0.400 e 10.0.404 |
| Go / Java | 1.24.4 / OpenJDK 17.0.19 |
| git | 2.51.0 |
| ffmpeg | 7.1 (essentials) |
| Navegadores | Chrome, Edge |
| Projeto | Pasta vazia, exceto `.vscode/mcp.json` (configuração AppMap, sem relação com o jogo). **Não é repositório git.** Pasta dentro do **OneDrive**. |

¹ O WMI informa `AdapterRAM` = 4 GB por limitação de campo de 32 bits; a placa tem 16 GB.

**Conclusões do inventário**

1. Nenhuma engine está instalada; qualquer escolha exige instalação.
2. O hardware é muito superior ao necessário para qualquer opção.
3. O disco C: inviabiliza o Unreal Engine 5 sem reorganização (engine + Visual Studio + Derived Data Cache ocupam dezenas de GB).
4. Não há toolchain C++: UE5 com C++ exigiria instalar o Visual Studio 2022 com workloads de C++ (dezenas de GB adicionais).
5. A pasta atual no OneDrive é inadequada para repositório git e cache de engine (ver KNOWN_ISSUES ENV-001).

## 3. Candidatas avaliadas

| Candidata | Versão de referência | Licença / custo |
|---|---|---|
| Unreal Engine 5 | 5.8 (anunciada pela Epic em jun/2026) | Grátis; royalty de 5% sobre receita bruta acima de US$ 1 mi por produto (receita via Epic Games Store isenta) |
| Unity 6 | Unity 6 | Personal grátis até US$ 200 mil de receita + financiamento; Pro US$ 2.310/assento/ano acima disso; splash opcional no Unity 6 Personal |
| Godot 4 | 4.7.2-stable (GitHub oficial, 18/08/2026) | MIT, sem royalties |
| Engine própria | TypeScript + Three.js + Electron | Sem custo; todo o resto precisa ser construído |

O prompt mestre exige avaliar UE5 e Unity. O usuário autorizou explicitamente alternativas ("criar do zero ou qualquer coisa do tipo"), por isso Godot e uma engine própria também foram avaliadas.

## 4. Critérios e pesos

Pesos definidos para o modelo **1 pessoa + agentes de IA** (soma = 100):

| ID | Critério | Peso |
|---|---|---|
| C1 | Autoria por texto (cenas, configs e lógica como texto legível e versionável) | 20 |
| C2 | Automação por linha de comando (testes, parse e builds em headless; screenshots por script com janela) | 15 |
| C3 | Recursos nativos para os pilares (navegação, áudio 3D, percepção de IA, iluminação/névoa) | 15 |
| C4 | Qualidade visual alcançável em interiores escuros | 10 |
| C5 | Custo de setup neste ambiente (instalação, toolchain, contas, disco) | 10 |
| C6 | Velocidade de iteração (compilação, import, abertura do editor) | 10 |
| C7 | Risco de licença/custo | 5 |
| C8 | Desempenho no PC alvo | 5 |
| C9 | Ecossistema, documentação e familiaridade dos LLMs | 5 |
| C10 | Viabilidade comercial de longo prazo (Steam, futuros portes) | 5 |

## 5. Matriz comparativa (notas 1–5)

| Critério (peso) | UE5 | Unity 6 | Godot 4.7 | Engine própria |
|---|---|---|---|---|
| C1 Autoria por texto (20) | 1 | 3 | **5** | 5 |
| C2 Automação headless (15) | 3 | 4 | **5** | 4 |
| C3 Recursos nativos (15) | **5** | 3 | 3 | 1 |
| C4 Qualidade visual (10) | **5** | 4 | 3 | 2 |
| C5 Custo de setup (10) | 1 | 2 | **5** | 4 |
| C6 Iteração (10) | 2 | 3 | **5** | 4 |
| C7 Licença (5) | 4 | 4 | **5** | 5 |
| C8 Desempenho (5) | 4 | 4 | 4 | 3 |
| C9 Ecossistema/LLM (5) | 4 | **5** | 3 | 4 |
| C10 Viabilidade comercial (5) | **5** | **5** | 4 | 2 |
| **Total ponderado (0–100)** | **61** | **69** | **86** | **69** |

Fórmula: `Σ (nota × peso) / 5`.

### Justificativa das notas

**Unreal Engine 5**
- C1 = 1: Blueprints, níveis (`.umap`) e assets (`.uasset`) são binários. C++ é texto, mas o fluxo real depende do editor. Agentes não conseguem revisar diffs de Blueprints.
- C3 = 5: tem `AIPerceptionComponent` com visão e audição, StateTree e Behavior Trees, NavMesh, MetaSounds e Lumen. É o melhor pacote nativo para este gênero.
- C4 = 5: maior teto visual do mercado.
- C5 = 1: exige Epic Games Launcher, conta, dezenas de GB de engine e Visual Studio 2022 com C++, que não está instalado. O C: tem ≈ 19,5 GB livres.
- C6 = 2: compilação de C++, compilação de shaders e editor pesado.

**Unity 6**
- C1 = 3: C# é texto. Cenas e prefabs são YAML, mas cheios de `fileID`/GUID, o que é frágil de escrever à mão; na prática exigem o editor.
- C2 = 4: `-batchmode`, Unity Test Framework com `-runTests` e build por CLI. Exige licença ativada.
- C3 = 3: tem NavMesh e áudio 3D básico. Não tem percepção de IA nativa.
- C5 = 2: Unity Hub, login, ativação de licença (interativa) e editor de vários GB.

**Godot 4.7.2**
- C1 = 5: `.tscn`, `.tres` e `.gd` são texto puro, projetados para controle de versão. Um agente consegue criar cenas inteiras sem o editor.
- C2 = 5: executável único com `--headless`, `-s <script>`, `--check-only` (parse), `--import` e `--export-release`. Testes, parse e builds rodam em headless. **Screenshots exigem execução com janela**, porque em `--headless` o renderer é dummy. Mesmo assim é um único comando sem editor, e Unity (`-batchmode -nographics`) tem a mesma limitação, o que mantém a nota relativa.
- C3 = 3: tem NavigationServer3D/NavigationAgent3D, AudioStreamPlayer3D com atenuação, Area3D com reverb por barramento, névoa volumétrica, SDFGI, VoxelGI, LightmapGI e Jolt Physics integrado. **Não tem** percepção de IA nativa. O projeto precisaria de percepção e propagação sonora próprias de qualquer forma, porque o design exige regras específicas (paredes, portas, esconderijos).
- C4 = 3: interiores escuros com lightmaps, névoa volumétrica e pós-processamento são o ponto forte. O teto fotorrealista fica abaixo do UE5; a direção de arte compensa (escuridão, granulação, iluminação limitada).
- C5 = 5: cerca de 80 MB, sem instalador, sem conta, sem compilador.
- C9 = 3: ecossistema menor. LLMs às vezes geram API do Godot 3. Mitigação: versão fixada; warnings `untyped_declaration`, `unsafe_method_access` e `unsafe_property_access` configurados como erro (pegam chamadas a métodos inexistentes); parse com `--check-only` após `--import` (o cache de `class_name` precisa existir); referência à documentação oficial da classe. **O parse não substitui testes**: erros de comportamento só aparecem na execução.

**Engine própria (TypeScript + Three.js + Electron)**
- C1/C2 altos: tudo é código.
- C3 = 1: física/colisão, navmesh, oclusão sonora, persistência e ferramentas de nível teriam de ser construídos do zero. Isso consumiria o orçamento do projeto em infraestrutura em vez de nos pilares de gameplay.
- C10 = 2: polimento comercial e ferramentas de conteúdo seriam um projeto paralelo inteiro.

### Análise de sensibilidade

Com pesos de um **estúdio tradicional com artistas** (C1=5, C2=5, C3=25, C4=25, C5=5, C6=10, C7=5, C8=5, C9=5, C10=10):

| | UE5 | Unity 6 | Godot | Própria |
|---|---|---|---|---|
| Total | **81** | 73 | 75 | 52 |

Com **pesos iguais** (10 para cada critério), o resultado é UE5 68, Unity 74, Godot 84 e engine própria 68 (conferido na revisão DISC-006). Godot continua em primeiro.

**Empate Unity × engine própria (69):** Unity é o runner-up porque a engine própria tem nota 1 em C3 e 2 em C10. Ela obrigaria a construir física, navegação e ferramentas antes de qualquer gameplay, que é exatamente o risco que esta decisão quer evitar.

**Interpretação:** UE5 vence quando há artistas e o editor é operado por humanos. Godot vence quando a maior parte do trabalho é feita por agentes que escrevem texto e precisam verificar o próprio resultado. A decisão depende do modelo de desenvolvimento, não de qual engine é "melhor" em abstrato. Se o modelo mudar (por exemplo, entrada de artistas de UE5 em tempo integral), esta ADR deve ser revista.

### 5.1 Avaliação por objetivo da Fase 0 (MASTER §12)

| Objetivo | UE5 | Unity 6 | Godot 4.7 | Evidência / status |
|---|---|---|---|---|
| **Arquitetura** | Gameplay Framework (Actor/Component, GameMode, Controller); lógica em C++ e Blueprints | GameObject/MonoBehaviour em C#; cenas e prefabs em YAML | Árvore de nós e cenas instanciáveis; sinais; Resources; scripts por nó | As três suportam composição. Só no Godot a cena inteira é texto autorável sem editor, o que permite as camadas L0–L4 e o mediador da SYSTEM_ARCHITECTURE sem depender de ferramenta gráfica. Avaliação por documentação e conhecimento técnico, sem protótipo comparativo. |
| **Desempenho** | Maior custo base (Lumen, Nanite e shaders pesados); maior teto | Intermediário; C# compilado rápido para lógica | Custo base baixo; GDScript interpretado é mais lento que C#/C++ para lógica pesada | O escopo (uma casa, ≤ 3 IAs, poucas luzes) está muito abaixo do limite das três nesta máquina. O risco do GDScript fica coberto pelos orçamentos de SYSTEM_ARCHITECTURE §13 e pelo plano B (C#/GDExtension em trechos críticos). **Sem medição comparativa**: o critério V5 mede o Godot nesta máquina. |
| **Facilidade de implementar a IA** | A melhor nativa: AIPerception (visão e audição), StateTree/BT, EQS, NavMesh | NavMesh nativo; percepção e decisão próprias ou via asset | NavigationServer3D/NavigationAgent3D nativos; percepção e decisão próprias | O design exige percepção própria em qualquer engine (salas e portais, esconderijos, firewall testável). A audição nativa do UE5 não modela portas e paredes como o design pede. A vantagem do UE5 aqui é real, mas parcial. |
| **Ferramentas de áudio** | MetaSounds nativo; integrações oficiais com FMOD e Wwise | Áudio nativo básico; integrações oficiais com FMOD e Wwise | Barramentos com efeitos (reverb, filtros), AudioStreamPlayer3D e, para música adaptativa, AudioStreamInteractive / Playlist / Synchronized (desde a 4.3, por conhecimento técnico; não verificado nesta sessão); FMOD e Wwise só por integrações da comunidade | Para respiração dinâmica, oclusão por grafo e música por camadas, o áudio nativo do Godot basta (o volume é calculado pelo próprio jogo, ADR-004). FMOD é reavaliado só se a música adaptativa exigir mais. Licença e compatibilidade do FMOD com Godot 4.7 **não verificadas**. |
| **Requisitos de hardware** | Guias não oficiais de 2026 ([issoh.co.jp](https://www.issoh.co.jp/?p=7495), [Corsair](https://www.corsair.com/explorer/glossary/what-is-unreal-engine-5/)) recomendam CPU de 8 núcleos, 32 GB de RAM, GPU DX12 com 8 GB e SSD NVMe; dezenas de GB de disco (não confirmado em fonte oficial para a 5.8) | Editor moderado; alguns GB de disco | ≈ 80 MB; GPU com Vulkan 1.x ou D3D12 | A máquina (i7-14700KF, 32 GB, RX 9070 XT 16 GB) atende as três. O disco C: (≈ 19,5 GB livres) é o único limitador, e só para o UE5. |
| Comparar e escolher a engine | — | — | — | §5 (matriz e sensibilidade) e §6 (decisão) |
| Inspecionar ferramentas disponíveis | — | — | — | §2 e Docs/QA/EVIDENCE/DISC-001_environment.txt |

## 6. Decisão proposta

**Godot 4.7.2-stable, build padrão (sem .NET), linguagem GDScript com tipagem estática obrigatória.**

| Aspecto | Escolha | Motivo |
|---|---|---|
| Versão | 4.7.2-stable, fixada | Estabilidade. Atualizações de patch (4.7.x) são permitidas após a suíte de regressão passar. Migrar para 4.8 exige nova ADR. |
| Build | Padrão (não-.NET) | Sem acoplamento com versões do .NET; o SDK instalado é o 10 e a compatibilidade com o Godot .NET não foi verificada. Executável menor. |
| Linguagem | GDScript tipado | Sem etapa de build, iteração imediata, testes headless triviais. Warnings de variáveis não tipadas tratados como erro. |
| Renderer | Forward+ (Vulkan) | Necessário para névoa volumétrica e GI. **D3D12** como fallback se Vulkan apresentar problema na RDNA4. |
| Física | **A decidir no spike** entre Jolt Physics (opção integrada desde a 4.4; se é o padrão na 4.7 não foi confirmado) e GodotPhysics3D | Configuração `physics/3d/physics_engine`. O spike compara os dois com CharacterBody3D em escada, rampa e vão de 0,6 m. A suposta maior estabilidade do Jolt é hipótese, não evidência. |
| Plano B de desempenho | C# ou GDExtension só para trechos críticos | Ativado apenas se o profiling mostrar GDScript acima do orçamento (ver SYSTEM_ARCHITECTURE §13). GDExtension exige instalar um compilador C++. |
| Runner-up | Unity 6 | Se Godot falhar no spike (renderização na RDNA4 ou bloqueio técnico grave), reabrir esta ADR com Unity como alternativa. |

## 7. Condições de validação (spike DISC-003 — critério do Gate F0)

O spike pertence à **Fase 0**. A ADR passa a **APPROVED** quando o usuário aprova D-01 **e** o spike passa em V1–V6. Se o spike falhar, a ADR é reaberta com Unity 6 como alternativa, e a Fase 1 não começa.

| # | Critério | Evidência exigida |
|---|---|---|
| V1 | `godot --version` começa com `4.7.2.stable` (a saída real tem sufixo `.official.<hash>`) | Saída do comando |
| V2 | Script headless executa e retorna código de saída 0 ou 1 conforme o resultado | Saída + código de saída |
| V3 | Cena 3D com Forward+, névoa volumétrica e luz pontual renderiza na RX 9070 XT (**com janela**, sem `--headless`) | Screenshot PNG gerado por script e inspecionado. Se Vulkan falhar, repetir com D3D12. |
| V4 | Após `--import`, `--check-only` detecta um erro de parse proposital **com código de saída ≠ 0** | Saída + código de saída |
| V5 | Sala greybox com 3 luzes dinâmicas e névoa, 1080p, **vsync desligado**: p95 do frame time ≤ 6,9 ms (≈ 144 fps) em 600 frames após 120 de aquecimento | Log de frame time |
| V6 | CharacterBody3D em escada, rampa e vão de 0,6 m com Jolt e com GodotPhysics3D | Resultado comparativo e escolha registrada |

Instalação recomendada: `D:\DevTools\Godot\4.7.2\` (fora do OneDrive e do C:).

## 8. Consequências

**Positivas**
- Todo o jogo pode ser escrito, revisado (diff) e testado por agentes.
- Setup em minutos, sem contas nem licenças.
- MIT: sem royalties e sem risco de mudança de licença.
- Iteração rápida: sem compilação.

**Negativas e mitigações**

| Consequência | Mitigação |
|---|---|
| Percepção de IA e propagação sonora são próprias | Já eram necessárias pelo design. Ficam em módulos puros e testáveis (ADR-003, ADR-004). |
| Teto visual menor que o UE5 | Direção de arte baseada em escuridão, lightmaps, névoa, materiais CC0 de qualidade e pós-processamento discreto. |
| Pipeline de personagens e animações é o ponto fraco | Decisão pendente D-05: Blender (scriptável via Python), personagens CC0 ou freelancer. |
| LLMs confundem API do Godot 3 e 4 | Versão fixada, `--check-only` em todo script, revisão técnica obrigatória. |
| Exportação exige *export templates* (download separado) | Tarefa na Fase 8; baixar a versão exatamente correspondente. |
| Consoles exigem porte por terceiros | Fora de escopo (plataforma inicial: PC Windows). |

## 9. Fontes consultadas (2026-11-20)

- Godot — releases oficiais no GitHub (API `repos/godotengine/godot/releases/latest`): 4.7.2-stable, publicada em 2026-08-18.
- [Godot 4.7 lançado (GamingOnLinux, jun/2026)](https://gamingonlinux.com/2026/06/godot-engine-4-7-is-out-bringing-a-new-asset-store-hdr-support-steam-frame-support)
- [Godot 4.6 lançado (GamingOnLinux, jan/2026)](https://www.gamingonlinux.com/2026/01/the-free-and-open-source-godot-engine-4-6-is-out-now-with-major-upgrades)
- [Unity — mudanças de planos e preços](https://unity.com/en/products/pricing-updates)
- [Unity — cancelamento da Runtime Fee (CGPress)](https://cgpress.org/archives/unity-cancels-runtime-fee-and-reverts-to-subscription-model-for-game-developers.html)
- [Unreal Engine — atualização de preços](https://www.unrealengine.com/blog/we-are-updating-unreal-engine-twinmotion-and-realitycapture-pricing-in-late-april?lang=en-US)
- [Unreal Engine — página oficial (anúncio do UE 5.8)](https://www.unrealengine.com/?lang=en-US)

Estas fontes **não foram reverificadas** pela revisão DISC-006 (o revisor não tinha acesso à internet). A versão do Godot foi reconfirmada pela API do GitHub ao gravar a evidência DISC-001. Requisitos de disco do UE 5.8 **não foram confirmados** em fonte oficial nesta sessão. A afirmação "dezenas de GB" é baseada em versões anteriores.

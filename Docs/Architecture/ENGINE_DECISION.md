# ADR-001 — Seleção de Engine

| Campo | Valor |
|---|---|
| Status | **APROVADA** em 2026-11-20 (usuário aprovou D-01; spike DISC-003 passou em V1–V6) |
| Data | 2026-11-20 |
| Responsáveis | Project Director, Software Architect |
| Esforço | EXTRA HIGH |
| Decisão | **Godot 4.7.2-stable (build padrão, sem .NET) + GDScript tipado + GodotPhysics3D** |
| Verificação prática na máquina | **FEITA** (DISC-003, 2026-11-20). Binário oficial com SHA-512 conferido, instalado em `D:\DevTools\Godot\4.7.2\`. Resultados em §7.1 e em Docs/QA/TEST_RESULTS.md. |
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

## 6. Decisão

**Godot 4.7.2-stable, build padrão (sem .NET), linguagem GDScript com tipagem estática obrigatória.**

| Aspecto | Escolha | Motivo |
|---|---|---|
| Versão | 4.7.2-stable, fixada | Estabilidade. Atualizações de patch (4.7.x) são permitidas após a suíte de regressão passar. Migrar para 4.8 exige nova ADR. |
| Build | Padrão (não-.NET) | Sem acoplamento com versões do .NET; o SDK instalado é o 10 e a compatibilidade com o Godot .NET não foi verificada. Executável menor. |
| Linguagem | GDScript tipado | Sem etapa de build, iteração imediata, testes headless triviais. Warnings de variáveis não tipadas tratados como erro. |
| Renderer | Forward+ (Vulkan) | Necessário para névoa volumétrica e GI. Verificado no spike: Vulkan 1.4.359 é o driver padrão na RX 9070 XT; **D3D12** também funciona e fica como fallback. |
| Física | **GodotPhysics3D** (definida explicitamente em `physics/3d/physics_engine`) | Spike V6 (§7.1): com cápsula, os dois motores deram resultados praticamente iguais. Com cilindro, o GodotPhysics3D manteve contato com o chão em 100% dos ticks na escada (Jolt: 28% dos ticks sem chão ao descer) e não gerou step-up espúrio na base da rampa. Ticks "no ar" gerariam eventos falsos de aterrissagem e passos, ou seja, ruído falso para a IA. **Reavaliar na F3** (objetos arremessáveis com RigidBody3D), rodando de novo o spike V6 mais um teste de corpos dinâmicos. |
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

### 7.1 Resultado do spike (2026-11-20)

Projeto descartável em `spikes/disc003/`; evidência bruta em `Docs/QA/EVIDENCE/DISC-003/`; reexecução com `bash spikes/disc003/run_spike.sh`.

| # | Resultado | Valor medido |
|---|---|---|
| V1 | **PASSOU** | `4.7.2.stable.official.ed1daf0bf` |
| V2 | **PASSOU** | `-- pass` → exit 0; `-- fail` → exit 1 |
| V3 | **PASSOU** | Vulkan 1.4.359, Forward+, RX 9070 XT; screenshot 1920×1080 inspecionado (3 luzes coloridas, sombras, halos de névoa volumétrica) |
| V4 | **PASSOU** | Erro de parse → exit 1. Os warnings `untyped_declaration`, `unsafe_method_access` e `unsafe_property_access` configurados como erro também dão exit 1 em `--check-only`; script válido → exit 0 |
| V5 | **PASSOU** | p95 em 2 execuções: Vulkan 1,92 e 1,21 ms; D3D12 0,90 e 0,96 ms (limite 6,9 ms). Os logs gravados são da 2ª execução. Ressalva: sala simples; o orçamento real é medido de novo na F4 |
| V6 | **PASSOU** | 16 pistas, todas aprovadas nos dois motores depois de corrigir a sondagem do step-up do controlador do spike. Resultados determinísticos (2 execuções idênticas por motor). Escolha: GodotPhysics3D (§6) |

**Achados do V6 que entram no PlayerMotor (F1-006):**
- `move_and_slide()` não sobe degraus sozinho: sem step-up, o corpo para em x = 1,76 diante de um degrau de 0,18 m. É preciso um step-up próprio. A sondagem horizontal precisa ser ≥ raio do colisor; com 1 tick de movimento (2,7 cm), a base arredondada da cápsula bate na quina e a normal não parece chão.
- **A cápsula perde o chão em ~28% dos ticks ao descer a escada** nos dois motores, mesmo com `floor_snap_length` = 0,3 m. **Cilindro + GodotPhysics3D: 0%.** Recomendação: colisor do jogador = `CylinderShape3D`.
- O step-up eleva o corpo de uma vez (até 0,29 m num tick). A câmera precisa suavizar a altura.
- Em `DEFAULT`, o 4.7.2 usa GodotPhysics3D (números idênticos aos da execução com GodotPhysics3D explícito).
- Rampa de 30°: parado, deslocamento = 0 nos dois motores. Vão de 0,6 m: rastejando (0,55 m) passa; em pé é bloqueado; a checagem de teto acusou bloqueio em 168/168 amostras sob a laje e 0/230 fora dela.

### 7.2 Reavaliação da física com corpos dinâmicos (F3-005, RSK-13; 2026-11-21)

Spike em `spikes/f3_physics/`; evidência em `Docs/QA/EVIDENCE/F3-005_physics_*` (resumo em `F3-005_physics_resumo.txt`) e `F3-005_rerun_V6_*`.

| Cenário | GodotPhysics3D | Jolt Physics |
|---|---|---|
| Pilha de 5 caixas (10 s) | topo afunda 35,7 mm; inclinação 0,35° | topo afunda 2,1 mm; inclinação 0,19° |
| Arremesso contra parede, queda de esfera | bate, quica e repousa | equivalente |
| Túnel a 15 e 40 m/s (parede de 1 cm) | não atravessa | não atravessa |
| Jogador contra caixa de 0,5 kg | o CharacterBody3D fica bloqueado; a caixa não se move | idem |
| Custo com 30 caixas | 45,2 ms (medida com janela, pouco confiável) | 32,3 ms (idem) |
| V6 da F0 (reexecutado) | ALL_PASS | ALL_PASS |
| **Suíte completa do jogo** (Director, `F3-005_pipeline_jolt_director.txt`) | **verde** | **30 falhas**: todas de escada (BUG-001/002, MOT-04). Na descida o corpo fica no ar (12 ticks) |

**Decisão do Director: manter o GodotPhysics3D.** O controlador do jogador foi validado nele (achado do V6: cilindro + GodotPhysics3D perde o chão em 0% dos ticks na escada), e as correções de escada da F1 dependem disso. O ganho do Jolt é a estabilidade de pilhas, que não é mecânica central. Arremesso, quique, repouso e túnel deram resultados equivalentes. **Consequências:**
- Level design evita pilhas com mais de 2 corpos dinâmicos (móveis grandes são estáticos).
- O jogador não empurra RigidBody3D sozinho: se esbarrar em objetos derrubar coisas (F3-004), o impulso é aplicado pelo código.
- **Reabrir** se a F4+ precisar de pilhas dinâmicas ou se o custo de física passar do orçamento numa medida sem janela. Trocar exigiria refazer as correções de escada no Jolt.

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

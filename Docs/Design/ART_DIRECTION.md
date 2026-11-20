# Direção de Arte — DEAD BREATH

| Campo | Valor |
|---|---|
| Versão | 0.1 (F1-D03, 2026-11-20) |
| Responsável | Art & Environment |
| Estado | **Rascunho · proposta; validar na F5 com o greybox.** Nenhum número aqui foi medido em jogo; onde há medição, ela está citada. |
| Fontes | MASTER_PROMPT §3.1, §4, §4.1, §6.8, §11; GAME_DESIGN_DOCUMENT §2, §4, §5, §7; ENGINE_DECISION (Forward+, névoa volumétrica); SYSTEM_ARCHITECTURE §13; COMPONENT_CONTRACTS §2 (metadado `surface`); ASSET_LICENSES.md |
| Evidência | `Docs/QA/EVIDENCE/F1-D03_materials.png` (captura dos 5 materiais); `Docs/QA/EVIDENCE/DISC-003/V3_screenshot.png` (referência de luz e névoa do spike) |

## 1. Princípio

O terror vem do que o jogador **não vê direito**, mas o que ele precisa ver para decidir tem de ficar legível. Por isso a regra central é:

> **Escuro, mas legível.** A tela deve ser escura na maior parte do tempo, e a informação para a decisão (rota de fuga, esconderijo, silhueta de inimigo, passo de porta) deve sobreviver ao escuro: por contraste de valor, por luz pontual e por som. Escuridão nunca pode esconder o caminho até a saída.

Consequência: a luz é uma ferramenta de jogo (lanterna, lâmpada que pode ser cortada, luz de emergência), não só cenário.

## 2. Paleta

Paleta dessaturada (MASTER §4.1). Os valores abaixo são **pontos de partida em sRGB**, para validar na F5.

| Papel | Exemplo (hex) | Uso |
|---|---|---|
| Escuridão (fundo, ambiente) | `#0E0E12` | Fundo da cena e luz ambiente |
| Madeira envelhecida | `#4A3A2E` | Pisos de madeira, móveis |
| Tapete | `#6B5E50` | Tapetes e estofados |
| Azulejo sujo | `#8A8478` | Banheiro, cozinha |
| Concreto | `#5C5B57` | Porão, garagem, rejuntes |
| Reboco / pintura gasta | `#7A7266` | Paredes |
| Luz quente (lâmpada) | `#E8B77A` | Luz principal dos cômodos, baixa intensidade |
| Luz fria (janela, lua, lanterna) | `#7F93A8` | Contraste com a luz quente |
| Sinal de perigo (luz de emergência) | `#A33A3A` | Único acento saturado; pouca área |

**Regras:**
- Superfícies: saturação HSL ≤ 35%. Acentos: até 60%, e ocupam ≤ 2% da tela.
- Um cômodo tem **uma temperatura dominante** (quente ou fria). O contraste entre cômodos e entre luz e sombra é de temperatura, não de cor viva.
- Vermelho não é usado como recompensa, dica ou indicador de vida. Ele aparece como sinal de ameaça (luz de emergência, sangue de cena) e nunca como interface.

**Achado da captura F1-D03:** sob a luz quente de teste, o azulejo e o tapete ficaram mais saturados do que a paleta permite. Hipótese de correção, a testar na F5: `albedo_color` mais dessaturado por material e/ou correção de cor pós-processada leve. Não aplicado agora porque os materiais de F1 são só para greybox.

## 3. Regras de luz

1. **Poucas fontes.** Por cômodo: 1 luz principal (lâmpada de teto, abajur ou janela) e no máximo 2 luzes de acento. Luz de acento não tem sombra.
2. **Sombra só nas luzes principais.** Sombras são o custo mais caro (ver §7). Máximo de 3 luzes com sombra simultâneas por cômodo.
3. **Cortes de luz (F3, capítulo 3 "a luz cortada") deixam sempre uma fonte de salvação:** lanterna do jogador, luz de emergência ou janela. Nenhum caminho obrigatório pode ficar sem luz nenhuma.
4. **Escuridão legível (proposta de métrica):** medir a fração de pixels com luminância > 0,05 (mesma métrica de `bench_probe.gd`):
   - cena normal: **40% a 70%** do frame;
   - cena com corte de luz: **≥ 15%**, e a rota de fuga na faixa de 0,03 a 0,10 de luminância.
   - Referência: o V3 do spike (`DISC-003/V3_screenshot.png`) tem **98,8%** de pixels acima de 0,05. Está claro demais para o alvo; a F5 precisa reduzir isso. A captura F1-D03 tem 42,6%, mas o fundo preto desta cena pesa na conta, então os números não são comparáveis diretamente.
5. **Contraste por valor.** Piso navegável, obstáculo e porta devem diferir em valor (claro/escuro), não só em cor. Teste: em tons de cinza, o caminho continua legível.
6. **Brilho pontual, não difuso.** Preferir luz concentrada (abajur, lanterna, janela) a luz ambiente alta. Luz ambiente baixa (o spike usou 0,3 de energia).

## 4. Névoa volumétrica e efeitos

- Névoa **discreta** (MASTER §4.1). Ponto de partida: `volumetric_fog_density` 0,02 a 0,04 (o spike usou 0,04), albedo neutro-frio.
- A névoa existe **por cômodo** (um volume por sala, para a F3 usar `RoomVolume`), nunca como névoa global. A névoa não pode esconder o piso navegável nem a silhueta de um inimigo a 5 m.
- Efeitos de tela, por padrão: sem lens flare, sem motion blur, bloom baixo, grão e vinheta leves e **ajustáveis** nas opções de acessibilidade (MASTER §11: "ajuste de intensidade dos efeitos").
- Limite de efeitos: nenhum efeito que tire visibilidade (MASTER §4.1). Se um efeito piora a legibilidade, ele sai.

**Achado da captura F1-D03:** na cena de teste a névoa não se distingue como volume na imagem; só há um halo leve perto da luz. Com a densidade usada (0,04), ela não cumpre o papel de atmosfera visível. Valor a ajustar na F5 com o greybox real, e não nesta cena de materiais.

## 5. Materiais e envelhecimento

### 5.1 Regras
- Toda superfície tem um material PBR (albedo, normal GL, rugosidade e, quando existir, AO).
- Envelhecimento em **três níveis**, aplicados por cômodo: **uso** (zonas de passagem gastas, marcas de pé), **abandono** (manchas, pintura descascada, umidade nos cantos) e **limpo** (só em áreas de vida recente, para contar a história da casa).
- Tecidos e reboco têm rugosidade alta (≥ 0,7). Superfícies brilhantes (azulejo, metal) são exceção e limitadas.
- Relevo vem de normal map, não de geometria extra (ver §7).

### 5.2 Superfícies e metadado `surface` (COMPONENT_CONTRACTS §2)

Os passos leem o metadado `surface` do colisor (`wood`, `carpet`, `tile`, `concrete`); sem metadado, `default`. Os materiais de F1 correspondem a esses valores:

| `surface` | Material (`game/content/materials/`) | Asset CC0 (ambientCG) | Observação |
|---|---|---|---|
| `wood` | `mat_floor_wood.tres` | WoodFloor041 | Tábuas, madeira envelhecida |
| `carpet` | `mat_floor_carpet.tres` | Carpet016 | Lã bege; abafa passos (ruído menor) |
| `tile` | `mat_floor_tile.tres` | Tiles142 | Azulejo creme e sujo; ruído alto |
| `concrete` | `mat_floor_concrete.tres` | Concrete036 | Porão e corredores; ruído médio |
| (parede) | `mat_wall_plaster.tres` | Plaster007 | Reboco com pintura gasta. **Não é superfície de passo**; não usa `surface` |

Se a F3 precisar de `surface` para parede (ex.: som de batida), a proposta vai ao Software Architect como mudança de contrato, não aqui.

### 5.3 Escala e UV
- Escala de referência: **1 unidade = 1 m**. Porta 2,0 × 0,9 m; teto 2,6 a 3,0 m; corredor estreito ~1,2 m (MASTER §4.1, GDD §5).
- Mapeamento: **triplanar em coordenadas de mundo** (`uv1_triplanar`, `uv1_world_triplanar`), `uv1_scale` 0,5 (tile de 2 m) nos cinco materiais de F1. Motivo: o greybox é feito de caixas, e o triplanar evita desdobramento de UV. Os valores de escala ambientCG (190, 170, 200) não têm unidade confirmada e Concrete036 e Plaster007 vêm sem dimensão; por isso o 2 m é um valor único de partida a conferir visualmente na F5.
- Na captura F1-D03, cada peça de 2 m × 2 m mostra o material sem padrão de repetição evidente. A verificação de repetição em áreas maiores fica para a F5.

## 6. Silhueta dos inimigos no escuro

O jogador precisa reconhecer um inimigo com pouca luz, porque a IA é justa e a informação visual é parte do jogo.

- **Silhueta por proporção:** ombros, cabeça e postura devem diferir da mobília (cadeira, guarda-roupa, mesa). Teste: a silhueta preta do inimigo, sem textura, deve ser distinguível da de um móvel na mesma distância.
- **Valor, não cor:** a roupa do inimigo fica em tom de valor diferente do piso e das paredes do cômodo em que ele aparece. Cor de roupa é secundária.
- **Contorno de luz (rim) fraco e sem brilho próprio.** Nunca usar brilho ou contorno para marcar a IA (isso vira HUD disfarçado e quebra o firewall de percepção do jogador).
- **Agachado e rastejando:** a silhueta encolhe (GDD §5). Ela ainda precisa ser legível a 3 m com lanterna.
- **Critério de aceitação (F4, com o inimigo real):** captura com só a lanterna acesa, a 5 m, em cômodo escuro: o inimigo ocupa ≥ 15% da altura da tela e a silhueta é reconhecível em tons de cinza.

## 7. Escala e orçamento inicial

Os valores são **propostas**. Não há medição de polígonos ou VRAM neste projeto ainda; a F5 mede.

| Item | Proposta inicial | Base |
|---|---|---|
| Greybox por cômodo | ≤ 500 triângulos | Caixas e rampas |
| Cômodo final, pior ângulo | ≤ 15 000 triângulos visíveis | Não medido |
| Prop principal (mesa, armário) | ≤ 3 000 triângulos | Não medido |
| Textura de piso e parede | **1K** (já escolhido em F1-D03) | Custo baixo; 2K só para props de destaque |
| Textura de prop de destaque | até 2K | Só se a câmera ficar perto |
| Materiais únicos por cômodo | ≤ 8 | Reduz trocas de material |
| Luzes com sombra simultâneas por cômodo | ≤ 3 | Spike V5: 3 luzes com sombra, p95 de 1,21 a 1,92 ms em greybox (RX 9070 XT, Vulkan) |
| Luzes sem sombra simultâneas | ≤ 6 | Acentos |
| Alcance das luzes | 7 a 9 m | Spike: 7 m; F1-D03: 9 m |
| Volumes de névoa | 1 por cômodo | §4 |

**Como medir na F5:** frame time com vsync desligado, p95 em 600 frames após aquecimento (método V5 do DISC-003); contagem de triângulos e VRAM no cômodo mais carregado; teto de frame time alinhado a SYSTEM_ARCHITECTURE §13 (60 fps estáveis em 1080p, alvo a definir na F7).

Observação do spike: 1,21 a 1,92 ms de p95 está muito abaixo do teto de 6,9 ms do critério V5. Isso mostra folga para o cômodo de greybox, não para a cena final.

## 8. O que é proibido

Base: MASTER §4 ("não reproduzir elementos de jogos de referência") e §4.1 ("evitar excesso de efeitos gráficos que prejudiquem a visibilidade ou o desempenho").

**Não fazer:**
- Copiar personagens, mapas, mobília de cenas, interfaces, ícones, fontes ou símbolos de Amnesia, Outlast, Alien: Isolation, Resident Evil 7 ou Visage. A referência serve para ritmo e atmosfera, não para forma.
- HUD permanente: sem barras de vida, estamina ou estresse na tela (MASTER §11; GDD §4). Indicador visual só como opção de acessibilidade.
- Marcas, logotipos, textos legíveis de terceiros em cenários. Texto de documentos do jogo é conteúdo próprio (F1-D02).
- Assets que não sejam CC0 sem a aprovação da regra 2 de ASSET_LICENSES.md; nenhum executável baixado.
- Efeitos que escondem o piso ou a silhueta: lens flare, bloom alto, grão intenso por padrão, motion blur.
- Iluminação que não tem fonte visível ou justificativa de cena (luz "mágica" sem lâmpada, janela ou lanterna).
- Detalhe excessivo antes do greybox aprovado (AGENT_ASSIGNMENTS §2, papel 8; MASTER §6.8). Props finais só depois da F5.
- Sangue, vísceras ou violência gráfica como recompensa ou como forma de dar feedback de dano. Feedback do corpo é som, respiração e câmera (MASTER §11).

## 9. Itens para validar (F5)

1. Redução de brilho da cena de referência para a faixa da §3, item 4 (a V3 está clara demais).
2. Dessaturação de azulejo e tapete (§2) e se ela basta sem pós-processamento.
3. Densidade da névoa por cômodo (§4) com a luz real.
4. Escala de tile 2 m (§5.3) nas peças de greybox reais; corrigir por material se necessário.
5. Orçamentos de §7 com medição de frame time, triângulos e VRAM.
6. Silhueta dos inimigos (§6) com captura por script e critério de 15% da altura da tela.

## 10. Registro desta versão

- F1-D03 (2026-11-20): paleta e regras de luz propostas; cinco materiais CC0 de 1K (4 pisos e 1 parede) em `game/content/materials/`; captura `Docs/QA/EVIDENCE/F1-D03_materials.png`, inspecionada.
- Captura feita com `tools/art/material_preview/material_preview.gd` (cena de teste fora do jogo; script copiado temporariamente para `game/` só durante a execução e removido depois).

# Desempenho — DEAD BREATH

| Campo | Valor |
|---|---|
| Medição | F4-007, primeira medição com IA (2026-11-24, commit `540c9a7`) |
| Orçamentos | SYSTEM_ARCHITECTURE §13 (iniciais) |
| Máquina | Intel Core i7-14700KF (28 threads), Windows 11; RX 9070 XT (não usada: headless). A especificação mínima ainda não foi definida (F7); a margem real precisa ser medida nela |
| Ferramenta | `tools/perf/run_perf.ps1` → `game/tests/perf/perf_main.gd` (harness `perf_harness.gd`, marcadores `perf_bracket.gd`) |
| Evidência | `Docs/QA/EVIDENCE/F4-007_perf.txt` (saída bruta das 6 execuções) |

## 1. Método

- **Cena:** `sandbox_ia.tscn` (a cena principal), headless, 60 ticks/s fixos. São 120 quadros de aquecimento e 600 medidos (10 s). O jogador fica parado no surgimento; o reinício da captura é desligado.
- **Configurações:** com 1 inimigo (o Observer) e, como teste de carga, com 3. Os dois extras são Observers com outra semente, que surgem no hall e na cozinha. Foram 3 execuções de cada configuração (RSK-14).
- **Tempo por sistema:** em headless, os monitores de tempo do Godot devolvem 0. Por isso, pares de nós marcadores cercam cada sistema no tick de física, pela prioridade:
  - jogador: −91/−89 em volta do PlayerRoot (−90);
  - acústica: −61/−59 em volta do AcousticWorld (−60);
  - inimigos: −41/−39 em volta do EnemyController (−40);
  - captura: −31/−29 em volta da EnemyCaptureArea (−30);
  - total: −1000/+1000, que mede todos os `_physics_process` do jogo.
  
  O `_process` tem um par próprio. O que se mede é CPU de script por quadro, não a simulação de física do motor nem a GPU.
- **Microbenchmarks no fim de cada execução:**
  - propagação de um `NoiseEvent` a **todos** os ouvintes (jogador, sensores dos inimigos, roteador de áudio e legendas), em 5 lotes de 100 eventos;
  - `LightExposureProbe.sample_now()` 300 vezes, na sonda do jogador e na do Observer;
  - `PhysiologyComponent.step` 1000 vezes.

## 2. Resultados (média das 3 execuções; ms)

**Por quadro**

| Sistema | 1 inimigo: média / p95 / máx. | 3 inimigos: média / p95 / máx. |
|---|---|---|
| Inimigos (sensores, cérebro, navegação) | 0,060 / 0,095 / 0,187 | 0,148 / 0,231 / 0,504 |
| Jogador (motor, fisiologia, respiração, interação, monitor) | 0,094 / 0,126 / 0,166 | 0,101 / 0,148 / 0,265 |
| Acústica (resolução da fila do quadro) | 0,006 / 0,003 / 0,398 | 0,025 / 0,245 / 0,920 |
| Captura | 0,002 / 0,003 / 0,005 | 0,003 / 0,004 / 0,045 |
| Total `_physics_process` | 0,184 / 0,305 / 0,717 | 0,314 / 0,582 / 1,319 |
| Total `_process` | 0,060 / 0,079 / 0,125 | 0,063 / 0,084 / 0,183 |

**Microbenchmarks**

| Medida | 1 inimigo | 3 inimigos |
|---|---|---|
| Propagação de um evento a todos os ouvintes | 0,149 | **0,291** |
| `LightExposureProbe.sample_now()` (jogador / Observer) | 0,016 / 0,022 | 0,016 / 0,022 |
| `PhysiologyComponent.step` | 0,006 | 0,006 |

As 3 execuções de cada configuração variaram menos de 2 % na média.

## 3. Comparação com os orçamentos (SYSTEM_ARCHITECTURE §13)

| Orçamento | Limite | Medido | Situação |
|---|---|---|---|
| 3 inimigos (sensores + cérebro + navegação) | ≤ 1,0 ms/quadro | 0,148 média; 0,504 máx. | ✔ |
| Propagação de um `NoiseEvent` (todos os ouvintes) | ≤ 0,2 ms | 0,149 com 1 inimigo; **0,291 com 3** | ✔ com 1; **✗ com 3** (PERF-001) |
| Fisiologia (tick completo) | ≤ 0,1 ms | 0,006 | ✔ |
| Total de scripts de gameplay | ≤ 3,0 ms/quadro | ≈ 0,38 média (física 0,31 + processo 0,06); ≈ 0,67 p95; máx. 1,50 | ✔ |

## 4. Achados

- **PERF-001: propagação acima do orçamento com 3 inimigos** (KNOWN_ISSUES GAME-016).
  - Cada ouvinte custa cerca de 0,07 ms, porque a busca multicritério roda uma vez por ouvinte.
  - Com o jogador e 3 sensores, um evento custa 0,29 ms.
  - No jogo isso é pouco: a fila de acústica do quadro fica em 0,025 ms na média e 0,92 ms no pior quadro, e o total de scripts tem folga de mais de 2 ms.
  - Mas o orçamento por evento é violado, e o esquadrão da F6 multiplica os ouvintes.
  - **Plano:** uma busca por evento, a partir da fonte, compartilhada por todos os ouvintes, e corte por limite inferior (com a distância em linha reta, o nível já fica abaixo do limiar). Fazer antes da F6.
- **Inimigos ouvem os passos uns dos outros** (KNOWN_ISSUES GAME-017).
  - Com 3 Observers, o principal passou os 10 s medidos em INVESTIGATE: investiga os passos dos colegas.
  - Na F4 só há um inimigo, então não afeta o jogo.
  - O esquadrão da F6 precisa decidir como o sensor trata os ruídos de colegas (o `HeardNoise` não carrega a fonte, por desenho).
- **Sonda de luz (R3-10, N3 da verificação F4-010).**
  - Cada amostra custa 0,016 a 0,022 ms; a 10 Hz, isso dá menos de 0,001 ms por quadro por sonda.
  - A invalidação da lista de luzes a cada nó criado não apareceu como custo relevante nesta cena.

## 5. Limites desta medição

- CPU de desenvolvimento muito acima do mínimo provável. Os números servem de base, não de prova para a especificação mínima.
- Headless, sem renderização: o custo de GPU (névoa volumétrica, sombras) fica para a medição com janela na F7.
- A sandbox é pequena (6 salas). Os níveis da F5 em diante têm mais salas e portais, e a busca cresce com o grafo.
- O jogador ficou parado. Corrida, arremessos e perseguição longa não foram exercitados em todas as execuções: os estados do Observer ficaram em PATROL/SUSPICIOUS com 1 inimigo e em INVESTIGATE/SEARCH com 3.

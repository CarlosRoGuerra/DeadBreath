# Stealth System — DEAD BREATH

| Campo | Valor |
|---|---|
| Versão | 1.0 (F3-012, 2026-11-21) |
| Estado | **Validado**: revisão F3-010 (APROVADO COM RESSALVAS, nova verificação sem MÉDIO em aberto) e validação independente F3-011 (APROVADO COM RESSALVAS; cenário "atravessar a casa em silêncio" com 126 eventos e 0 desvios) |
| Código | `game/sim/acoustics/` (AcousticGraph, NoiseLevels, AcousticConfig, HeardNoise, PlayerHeardNoise); `game/components/acoustics/` (AcousticWorld, RoomVolume, Portal, NoiseEmitter); `game/components/player/` (player_root, player_noise_map, player_hold, fall_noise_config, breath_emitter); `game/components/world/` (door, throwable, level_slots); `game/components/perception/light_exposure_probe.gd` |
| Config | `game/content/data/acoustics/acoustic_config.tres`, `noise_levels.tres`; `game/content/data/player/fall_noise.tres` |
| Fonte das fórmulas | DATA_STRUCTURES §2–§2.5; contratos COMPONENT_CONTRACTS §6.1–§6.6 |

## 1. O que o jogador sente

Não há combate. Na Fase 3 o perigo é ser **ouvido**: cada passo, porta, objeto e respiração vira um som com intensidade em dB. O som se propaga pela casa (salas, portas e paredes) e é comparado com o ruído de fundo da chuva na sala de quem escuta. Os inimigos chegam na F4 e usam exatamente esses números.

O jogador tem ferramentas para isso:
- **Marcha e postura:** rastejar e agachar soam menos que andar. Correr soa muito mais.
- **Piso:** tapete abafa (−8 dB), madeira solta denuncia (+6 dB).
- **Portas:** fechar a porta atrás de si corta 15 dB entre as duas salas. Segurar E fecha devagar (30 dB); tocar fecha no tempo normal (50 dB).
- **Chuva:** cômodos com janela (28 dB) e o exterior (38 dB) escondem mais que o porão (12 dB), que é perigosamente silencioso.
- **Trovão:** soma +20 dB ao ruído de fundo por 2,5 s. É a janela para se mover.
- **Distração:** objetos arremessados fazem barulho onde caem, de 50 a 80 dB conforme a velocidade e o tamanho.

O próprio corpo também denuncia: respiração ofegante, chiado e tosse (RESPIRATORY_SYSTEM). Sons altos de outras fontes assustam o jogador e sobem o estresse.

## 2. Modelo acústico

**Salas e portais.** Cada nível declara `RoomVolume` (caixa alinhada aos eixos, `ambient_floor_db`, `reverb_bus`) e `Portal` (entre duas salas, com a `Door` opcional). O `AcousticWorld` monta o `AcousticGraph` a partir desses nós. Sem `RoomVolume`, ele volta à propagação provisória da F2.

**Nível percebido.** Prevalece o caminho de maior nível percebido entre:
- o **direto**, atravessando paredes (25 dB cada) e pisos (30 dB cada);
- os caminhos **por portais**, com o portal aberto custando 3 dB e o fechado 18 dB.

```
perda_por_distância(d) = 20·log10(max(d, 1)) + 0,1·d
percebido = intensidade − perda_por_distância(comprimento do caminho) − perdas de paredes/pisos/portais
```

A busca por portais é **multicritério** (Dijkstra com rótulos não dominados de comprimento e perda; D-05), porque a perda por distância é logarítmica e não soma. Fechar uma porta nunca aumenta o nível (NOI-02).

**Audibilidade.**

```
limiar_efetivo = max(hearing_threshold_db, piso_da_sala_do_ouvinte + offset_do_trovão + margem)
audível ⇔ percebido ≥ limiar_efetivo
```

O jogador usa `hearing_threshold_db` 10 e margem 0, então o limiar dele é o piso da sala. Os perfis dos inimigos (F4) têm margem própria (DATA §2.3).

| Ambiente | Piso de ruído (dB) |
|---|---|
| Porão, cômodo sem contato com o exterior | 12 |
| Cômodo interno | 22 |
| Cômodo com janela | 28 |
| Exterior, ou fora de qualquer sala | 38 |
| Trovão | +20 por 2,5 s, em todas as salas |

**O que a IA vai receber (F4).** `HeardNoise.from_propagation` (L1) já calcula:
- a posição estimada: um ponto uniforme num disco horizontal em volta do ponto de entrada do caminho, de raio 0,05 m por dB perdido (D-07). Nunca é a posição real.
- a confiança: `clamp((percebido − limiar)/20; 0,1; 1)`.

## 3. Ruídos do jogador e do mundo

| Fonte | Categoria | Intensidade (dB a 1 m) | Observação |
|---|---|---|---|
| Passo rastejando / agachado / devagar / andando | FOOTSTEP | 18 / 25 / 32 / 40 | + modificador da superfície |
| Corrida | RUNNING | 60 | + modificador da superfície |
| Superfície | — | madeira solta +6, tapete −8, azulejo +3, concreto 0 | `wood` no nível = madeira solta |
| Queda | FALL | 80 | só com aterrissagem ≥ 2,5 m/s; escada e degrau não geram |
| Porta lenta (segurar) / normal (tocar) | DOOR | 30 / 50 | vale para abrir e fechar |
| Porta trancada sacudida | DOOR | 45 | |
| Painel batendo num corpo | DOOR | 40 | o painel para; não empurra |
| Porta batida | DOOR | 75 | reservada para os inimigos (F4) |
| Objeto arremessado ou solto | OBJECT_IMPACT | 50–80 | metade pela velocidade (0,8 a 8 m/s), metade pelo tamanho; silêncio abaixo de 0,8 m/s; no máximo 1 evento a cada 0,25 s por objeto |
| Respiração, chiado, tosse, bombinha | BREATHING, WHEEZING, COUGHING, MEDICATION | 20–65 | RESPIRATORY_SYSTEM; produtor único: BreathEmitter |

Na mesma superfície, a ordem é sempre rastejar < agachado < andar < correr (STL-01). Entre categorias o piso pode reordenar de propósito: correr em madeira solta (66 dB) soa mais que a tosse (65 dB; D-01).

**Exemplos de alcance** (Observer em cômodo interno, limiar 19; STL-07):

| Som | Alcance |
|---|---|
| Respiração calma escondido | inaudível |
| Respiração ofegante escondido | ≈ 1,7 m |
| Chiado forte escondido | ≈ 6,6 m |
| Tosse através de uma parede | ≈ 10 m |
| Tosse através de duas paredes | inaudível |
| Tosse no quintal (limiar 35) | ≈ 24 m |

## 4. Portas, objetos e o próprio barulho

- **Porta.**
  - Interagir com a porta fechada abre; com a aberta e parada, fecha.
  - Durante o movimento o estado continua OPEN, e o portal acústico segue aberto até o fim.
  - Abrir e fechar param em qualquer corpo em movimento no caminho, com histerese (BUG-006/009/010), e nunca empurram o jogador.
  - Trancada só dá retorno.
- **Arremessáveis** (`throwable_slot` no nível):
  - pegar com E e segurar diante da câmera;
  - arremessar com a ação `throw` (botão esquerdo, remapeável);
  - soltar com E, só onde a forma couber. Arremessar com a mão dentro de uma parede também não solta.
  - O objeto na mão para na parede, mais perto da câmera, e nunca a atravessa (BUG-016).
  - O corpo do jogador não empurra objetos (GAME-007).
- **O próprio barulho não assusta.** Fonte `player`, ou `player_<...>` para algo que o jogador causou, não chega ao ouvinte dele. Objeto solto ou arremessado vale como `player_thrown_<id>` até repousar, ser pego ou passar 3 s. A IA ouve normalmente.

## 5. Susto por som

Um som de outra fonte com 55 dB percebidos ou mais, no ouvido do jogador, chama `add_startle(clamp((dB − 55)/2 + 10; 10; 25))` (COMPONENT_CONTRACTS §6.5). Com estresse alto, isso dispara o gasp (42 dB), que também é ruído. Um susto pode denunciar o jogador.

## 6. Exposição à luz (base da F4)

O `LightExposureProbe` (filho do jogador) mede a exposição de 0 a 1 em pontos de amostra a 10 Hz:
- contribuições das `OmniLight3D` e `SpotLight3D` do mundo, por alcance, atenuação e cone;
- oclusão por raio contra o mundo e os `vision_occluder`.

A visão dos inimigos (F4) lê `get_exposure()` pelo `PerceivableTarget`.

## 7. Invariantes

| ID | Regra | Onde é garantida |
|---|---|---|
| NOI-INV-1 | Todo som chega à IA só pelo `AcousticWorld.emit_noise`; eventos nascem no BreathEmitter ou no NoiseEmitter | varredura em `test_acoustic_world.gd` (receptor `NoiseEmitter`, `NoiseEvent.new`, `"emit_noise"` como texto) |
| NOI-INV-2 | O volume tocado vem do nível percebido; sem atenuação nativa | NOI-04, AUDIO_DESIGN |
| NOI-INV-3 | Propagação pura e determinística | NOI-02 |
| NOI-INV-4 | `HeardNoise` e `PlayerHeardNoise` sem posição real, id ou sala da fonte | NOI-03 (reflexão) |
| NOI-05 | O som do corpo do jogador tem produtor único | o NoiseEmitter recusa categoria corporal de fonte não inimiga; `test_fontes_do_mundo_sem_corpo.gd` |

## 8. Testes

| Critério | Arquivos |
|---|---|
| STL-01 | `tests/unit/acoustics/` (valores base e ordem por superfície); `tests/property/player/test_ruido_stl01_queda.gd` (no jogo) |
| STL-02, STL-03 | `tests/unit/acoustics/`; porta real na sandbox: `tests/integration/level/test_f3007_porta_playable.gd`, `tests/property/interaction/test_porta_fechar_sandbox.gd` |
| STL-07 | `tests/unit/acoustics/` (7 exemplos, ±0,2 m) |
| NOI-01..05 | `tests/unit/acoustics/`, `tests/property/acoustics/test_noi02_porta_nunca_aumenta.gd`, `tests/integration/acoustics/`, `tests/integration/audio/` |
| D-07 | `tests/unit/acoustics/test_heard_noise_estimativa.gd` |
| Porta, arremessáveis, susto | `tests/integration/interaction/test_porta_fechar.gd`, `tests/integration/world/test_arremessavel.gd`, `tests/integration/player/test_susto_por_som.gd` |

Resultados: `Docs/QA/TEST_RESULTS.md` e `Docs/QA/F3-011_VALIDATION.md`.

## 9. Debug

F5 (só em build de desenvolvimento) mostra a visão acústica (F3-008):
- salas em arame, com cor pelo piso de ruído;
- portais verdes (abertos) ou vermelhos (fechados);
- um anel no chão para cada som, com o raio do alcance em campo livre até o limiar da sala.

## 10. Limitações e pendências

- Falas (VOICE) não têm emissor nem legenda até a F4. Esconderijos (STL-04..06) entram na F5.
- A janela da sala da sandbox só muda o piso de ruído; não há abertura acústica para fora.
- A trava de som corporal reconhece inimigo só pelo prefixo `enemy` (GAME-010, F4).
- Calibrar no playtest os valores de DATA §2.1–§2.3 e o limiar de queda.

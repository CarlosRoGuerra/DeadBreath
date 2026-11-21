# Audio Design — DEAD BREATH

| Campo | Valor |
|---|---|
| Versão | 1.0 (F3-012, 2026-11-21) |
| Estado | **Validado por testes**: revisão F3-010 e validação F3-011 (APROVADO COM RESSALVAS). **O som final ainda não foi ouvido pelo usuário** (BUG-013, GAME-006, GAME-009) |
| Código | `game/presentation/audio/` (BreathingAudio, NoiseAudioRouter, RainAmbience, WorldClips, NoiseGain); `game/presentation/ui/subtitles.gd`; `game/default_bus_layout.tres` |
| Conteúdo | `game/content/audio/body/` (41 WAV) e `game/content/audio/world/` (98 WAV), cada um com `manifest.json`; `game/content/data/subtitles/subtitles_pt_br.json` |
| Ferramentas | `tools/audio/body_synth.py`, `world_synth.py`, `check_regen.py`, `audition.ps1` |
| Fontes | DATA_STRUCTURES §2.1–§2.4; COMPONENT_CONTRACTS §6.5, §6.6 e §14 |

## 1. Princípios

1. **O que o jogador ouve é o que a IA calcula.** O volume de todo som vem do nível percebido (`PropagationResult.perceived_db`) no ouvido do jogador, nunca da distância ao emissor. A atenuação nativa do Godot fica desligada (NOI-INV-2). Se o jogador ouve a própria respiração alta, um inimigo perto também ouve.
2. **Nenhum som sem evento.** Respiração, chiado e tosse do jogador nascem num único produtor, o BreathEmitter. O áudio só toca o que passou pelo AcousticWorld (NOI-05).
3. **O corpo fica dentro da cabeça.** Os sons do corpo do jogador não têm posição 3D. Os do mundo são 3D, só com panning.
4. **Procedural e determinístico.** Os 139 arquivos foram sintetizados por geradores com semente fixa e conferidos bit a bit (`check_regen.py`). Se a escuta reprovar, troca-se por gravação ou CC0 (`ASSET_LICENSES.md`).

## 2. Cadeias

| Cadeia | Produtor | Caminho | Quem toca |
|---|---|---|---|
| Corpo do jogador | BreathEmitter (respiração, chiado, tosse, gasp, bombinha) | AcousticWorld → `noise_resolved_for_player` | BreathingAudio (sem posição) |
| Mundo | NoiseEmitter (portas, objetos, passos e queda do jogador) | AcousticWorld → `noise_resolved_for_player` | NoiseAudioRouter (3D) |
| Ambiente | estado do clima do AcousticWorld (piso da sala, `thunder_started`) | — | RainAmbience |

O router ignora o corpo do jogador e o BreathingAudio ignora o mundo; os dois sentidos têm teste. Passos e portas do próprio jogador são sons do mundo.

## 3. Regra de ganho (NoiseGain)

```
até 45 dB percebidos:  ganho = max(percebido − 45, −45)      (1:1)
acima de 45 dB:         ganho = min((percebido − 45)/4, +6)   (4:1 até o teto, em 69 dB)
```

| Percebido (dB) | 20 | 30 | 40 | 45 | 50 | 60 | 65 | ≥ 69 |
|---|---|---|---|---|---|---|---|---|
| Ganho (dB) | −25 | −15 | −5 | 0 | +1,25 | +3,75 | +5 | +6 |

- A mesma regra serve ao corpo e ao mundo: no mesmo nível percebido, os dois soam igual.
- A regra antiga saturava em 0 dB acima de 45, e porta normal, corrida, tosse e porta batida soavam iguais. A compressão mantém a ordem até 69 dB; acima disso, o timbre do arquivo diferencia.
- Os clips têm RMS de referência de −24 dBFS e picos entre −10 e −4 dBFS.
- O Master tem um `AudioEffectHardLimiter` com teto de −1 dBFS. Sons altos sobrepostos dependem dele (GAME-009): conferir na escuta.
- **Troca consciente:** acima de 45 dB, a diferença de nível percebido chega comprimida ao volume. Por exemplo, a porta batida atrás de uma porta fechada perde 15 dB no ouvido e 3,75 dB no volume. A decisão entre audível e inaudível acontece na faixa 1:1, abaixo de 45 dB; acima, a compressão preserva a ordem sem clipar. Os números exatos aparecem na visão de debug (F5).

## 4. Biblioteca e escolha de arquivo

| Família | Arquivos | Variações |
|---|---|---|
| Corpo: respiração calma, rápida, ofegante (inspira e expira); chiado; tosse; aviso de tosse; gasp; bombinha | 41 | 3 a 8 por som |
| Passos: madeira, tapete, azulejo, concreto × rastejar, agachado, devagar, andando, corrida | 60 | 3 |
| Portas: lenta, normal, batida, trancada | 12 | 3 |
| Impactos leve, médio, pesado; queda; arrasto de móvel | 15 | 3 |
| Chuva: interna, janela, exterior (loops) | 3 | 1 |
| Trovão: ronco e estalo | 8 | 4 |

**Escolha** (NoiseAudioRouter):
- **Passos:** `sound_id = footstep_<superfície>`. A marcha sai da intensidade menos o modificador da superfície, com fronteiras no ponto médio entre os níveis vizinhos. Contrato: quem emite passos usa `NoiseLevels.footstep_level` sem outro modificador.
- **Impacto:** abaixo de 60 dB leve, até 70 médio, acima pesado.
- **Variação e pitch:** sorteia sem repetir a variação anterior; pitch ±4 %.
- **Vozes:** no máximo 12 simultâneas; a mais antiga sai.

**Corpo** (BreathingAudio): inspiração e expiração encadeadas pelo período respiratório. `pitch = clamp(nominal/período; 0,87; 1,15)`; o que sobra é silêncio, e a expiração nunca é cortada. O chiado é uma camada.

## 5. Espaço e reverb

- **Posição da voz 3D:** o ponto de entrada do caminho. No caminho direto é a fonte. Por um portal, é o portal por onde o som entra na sala do ouvinte, então a direção percebida é a da passagem.
- **Reverb:** o barramento da sala de quem ouve (`RoomVolume.reverb_bus`).

| Barramento | Uso | Reverb |
|---|---|---|
| `reverb_small` | cômodos | room_size 0,25, wet 0,2 |
| `reverb_large` | corredor, hall | room_size 0,75, wet 0,35 |
| Master | exterior, sem sala | limitador −1 dBFS |

## 6. Chuva e trovão

- **Camada pelo piso da sala do ouvinte:** abaixo de 25 dB interna, de 25 a 33 janela, a partir de 33 exterior.
- A troca de camada é um crossfade de potência constante de 2 s.
- **Nível:** a saída de qualquer camada fica em `piso − 69 dBFS`, a mesma escala de um passo com o mesmo nível percebido. O que a IA usa como mascaramento é o que o jogador ouve.
- **Trovão:**
  - no `thunder_started`, toca o ronco (sempre) e o estalo (50 %);
  - o nível é o limiar que ele impõe (piso + 20 dB) pela regra de ganho: porão −13 dB, cômodo interno −3 dB, janela +0,75 dB, exterior +3,25 dB;
  - fica desligado por padrão; o nível liga (`AcousticWorld.thunder_enabled`) e o intervalo é de 60 a 180 s.

## 7. Legendas (ACC-04)

- **O que gera legenda** (AcousticWorld):
  - a tosse (não o aviso), as portas e as falas, sempre que audíveis;
  - passos ou corrida de outra fonte, só a partir do limiar + 10 dB;
  - o barulho do próprio jogador, nunca.
- **Repetição e duração:** o mesmo som não repete antes de 2 s; duração mínima de 1,5 s.
- **UI `Subtitles`:** até 3 linhas na base da tela, com tamanho (`subtitles_size`, de 0,75 a 2) e liga/desliga (`subtitles_enabled`) aplicados na hora.
- **Textos:** tabela pt-BR em `subtitles_pt_br.json`, entre colchetes ("[tosse]", "[porta]", "[porta rangendo]", "[passos próximos]"). Chave sem texto não aparece e gera um aviso.

## 8. Testes

| Critério | Arquivos |
|---|---|
| NOI-04 (paridade áudio × IA, 20 eventos, ≤ 0,5 dB) | `tests/integration/audio/test_noise_audio_router.gd` |
| NOI-05 (produtor único) | `tests/integration/audio/`, `tests/property/qa/test_f2011_audio_corpo.gd`, `tests/integration/acoustics/test_noise_emitter_corpo.gd` |
| Regra de ganho, chuva e trovão | `tests/unit/audio/test_noise_selection.gd`, `tests/integration/audio/test_rain_ambience.gd`, `test_bus_layout.gd` |
| Integração na cena jogável | `tests/integration/world/test_playable_world_audio.gd` |
| Legendas (ACC-04) | `tests/unit/ui/`, `tests/integration/ui/` |
| Picos e regeneração | `tests/property/audio/`, `python tools/audio/check_regen.py --set world` |

## 9. Pendências

- **Escuta pelo usuário:** `tools\audio\audition.ps1` (corpo) e `tools\audio\audition.ps1 -Set world` (mundo). Decide BUG-013 (som do corpo), GAME-006 (sobreposição do chiado) e GAME-009 (limitador).
- **F4:** música adaptativa, falas dos inimigos (VOICE) e sons corporais de inimigos no router (GAME-010).

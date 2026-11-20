# Sons procedurais do corpo (F2-006a)

Biblioteca de sons do corpo do jogador (respiração, chiado, aviso de tosse, tosse, gasp e puff da bombinha), feita por síntese procedural (decisão D-07 do TASK_BOARD: sem gravação e sem licença externa). Os sons ficam em `game/content/audio/body/`.

| Arquivo | Função |
|---|---|
| `body_synth.py` | Gerador. Sintetiza os WAV, normaliza e grava `manifest.json`. Só biblioteca padrão do Python. |
| `check_regen.py` | Verificador de determinismo. Gera de novo em pastas temporárias e compara os SHA-256. |
| `analyze_body.py` | Análise objetiva (envelope, espectro, planura, inclinação, alertas). Gera `Docs/QA/EVIDENCE/F2-006a_analise.txt`. |
| `audition.ps1` | Toca os sons com o player nativo do Windows, na ordem do manifesto, com o nome na tela. |
| `game/content/audio/body/` | 41 WAV (16 bits, mono, 44,1 kHz), `manifest.json` e os `.wav.import` (PCM). |

## Como regenerar

```
python tools/audio/body_synth.py
```

Grava em `game/content/audio/body/` (ou em outra pasta com `--out <pasta>`). Leva cerca de 8 s. A saída lista cada arquivo com duração, RMS e pico.

Depois de regenerar, rode `python tools/audio/check_regen.py` e o `--import` do Godot (ver "Importação no Godot").

## Como verificar o determinismo

```
python tools/audio/check_regen.py
```

O script gera duas vezes em pastas temporárias, compara bit a bit com os arquivos commitados e com os hashes do `manifest.json`, e sai com código 0 somente se tudo bater. As pastas temporárias são apagadas ao fim.

Nota: a identidade bit a bit vale para a mesma versão do Python e a mesma plataforma. Entre sistemas, a biblioteca matemática (`math.sin`, `math.exp`) pode arredondar o último bit de algum ponto; o verificador acusa isso se acontecer.

## Como analisar

```
python tools/audio/analyze_body.py
```

Lê os WAV de `game/content/audio/body/` e escreve `Docs/QA/EVIDENCE/F2-006a_analise.txt`. Inclui as referências de ruído branco e rosa, medidas pelo mesmo analisador. Os alertas (clipping, DC, espectro quase plano em respiração) aparecem por arquivo.

## Como ouvir (playtest)

```
powershell -ExecutionPolicy Bypass -File tools\audio\audition.ps1
powershell -ExecutionPolicy Bypass -File tools\audio\audition.ps1 -Filter cough
powershell -ExecutionPolicy Bypass -File tools\audio\audition.ps1 -Filter breath_calm -Pause 1.5
powershell -ExecutionPolicy Bypass -File tools\audio\audition.ps1 -ListOnly
```

`-Filter` casa com o nome do arquivo ou com o `sound_id`. `-Pause` é o silêncio entre dois sons, em segundos. `-ListOnly` só lista. Ctrl+C interrompe. O script usa `System.Media.SoundPlayer`, que aceita WAV PCM.

## Técnica

Todos os sons são sintetizados a partir de uma semente fixa por arquivo (SHA-256 do nome, mais a semente base `DEADBREATH|F2-006a|v1`). O PRNG é um SplitMix64 próprio, para não depender de como cada versão do Python implementa `random`.

### Respiração (inspiração e expiração)

Cada fase é um modelo de fluxo de ar:

1. **Fonte:** ruído rosa (filtro de Kellet) somado a um chiado de passa-banda (`hiss`) e modulado por turbulência (dois LFOs de ruído suave, em 11 Hz e 43 Hz).
2. **Trato vocal:** duas ou três ressonâncias passa-faixa cujas frequências centrais deslizam de início a fim da fase (`formants`). Mistura de 45 a 55 % com um ramo de banda larga passa-baixa (`lp`).
3. **Voz (só nas fases ofegantes):** fonte glotal de 10 harmônicos (amplitude 1/k^1,2) com f0 em deslize, filtrada pelas ressonâncias de 700 e 1250 Hz.
4. **Envelope de fluxo:** curva cosenoidal com pontos em fração da duração. A inspiração sobe, atinge o pico no meio e cai. A expiração sobe rápido e cai de forma prolongada. Na ofegante, a inspiração tem um "degrau" no meio (hitch) em duas das quatro variações.
5. **Cor de cabeça (`body_eq`):** corte abaixo de 55 Hz, realce de +3 dB em 170 Hz e corte acima de 8,5 kHz. Dá a sensação de som conduzido pelo corpo, "dentro da cabeça".

Diferenças por família: calm é a mais escura e suave (passa-baixa em 2,6 kHz na inspiração, sem voz); fast tem chiado maior e um toque de glote em uma variação; labored tem mais turbulência, voz de esforço e expiração em "huff".

### Chiado (camada `wheeze`)

Três parciais de um sibilo (f0 entre 900 e 1180 Hz, harmônicos em 2× com 0,42 e em 3× com 0,16), com jitter de frequência (ruído suave em 4 e 12 Hz, e desafinação de até ±1,2 % em cada parcial). Soma um ruído passa-faixa estreito (Q 12) em volta da frequência do sibilo, com peso `air` de 30 a 45 %, para dar a turbulência do estreitamento. Tremolo de 25 a 40 %, envelope expiratório (pico no final). Duração 2,4 s, para tocar junto de uma respiração.

### Aviso de tosse (1,5 s)

Duração fixa de 1,5 s, igual ao aviso de DATA_STRUCTURES §1.4. Sequência: inspiração áspera, "garganta fechando" (voz glotal com rangido, envelope que cai a quase zero em 0,84 a 0,92 s, com um clique de fechamento) e pressão crescente até o fim, quando a tosse começa. A v2 tem duas gargantas fechando, a v3 é um pigarro sem pausa.

### Tosse (1 s)

Explosão de glote (ruído passa-baixa com decaimento de 10 a 20 ms, mais um "thump" de 110 Hz em 30 ms), seguida de ar com decaimento longo (0,5 s) e voz curta com f0 caindo de ~200 para ~110 Hz. Variações: seca (v1), dupla (v2), molhada com grave de secreção (v3) e tripla (v4). A crista (pico/RMS) é alta, então a tosse passa por um limitador de joelho antes de normalizar (ver "Normalização").

### Gasp de susto (1,2 s)

Inspiração rápida (subida em ~0,12 s), voz breathy de f0 caindo de ~290 para ~240 Hz e ressonâncias em 900 e 2100 Hz. A v1 tem tremor leve (14 Hz) no fim, a v2 é um gasp duplo, a v3 engasga (glote fecha por um instante no início).

### Puff da bombinha (1,0 s)

Clique mecânico do acionador (ruído de passa-banda em 3 kHz com decaimento de 2,5 ms, mais um tom de 900 Hz), um jato de aerossol (ruído passa-alta em 2,2 kHz e passa-baixa em 3,6 kHz, envelope de ~0,35 s) e uma inspiração curta logo depois (0,5 s). Variações: clique simples (v1), clique duplo (v2), jato mais longo (v3).

## Parâmetros

| Parâmetro | Valor |
|---|---|
| Taxa de amostragem | 44 100 Hz |
| Formato | PCM 16 bits, mono (`wave` do Python) |
| Semente base | `DEADBREATH\|F2-006a\|v1` (SHA-256 com o nome do arquivo) |
| Fade de entrada / saída | 3 ms / 10 ms (cosseno) |
| Referência de nível | RMS da clip inteira = -24 dBFS para respiração |
| Desvios por classe | camada (wheeze) -6 dB; aviso de tosse 0; tosse +5; gasp +3; puff +2 |
| Teto de pico | -3 dBFS (a exigência do teste é abaixo de -1 dBFS) |
| Limitador de joelho | só em tosse e gasp: linear até 3 × RMS, tende a 5 × RMS |

**Normalização.** Cada clip vai ao RMS da sua classe e depois é limitada ao teto de pico. Assim o volume relativo entre sons vem do desenho e fica documentado. O volume de jogo vem do `NoiseEvent` (`intensity_db`), não destes valores. Se o pico passar do teto, o ganho cai até o teto, e o RMS final fica abaixo do alvo. Por isso o manifesto registra o RMS e o pico medidos, não só o alvo.

**Limitador de joelho.** Tosse e gasp têm crista de 18 a 22 dB, o que faria o pico bater no teto e o RMS cair abaixo do alvo de classe. O limitador só age acima de 3 × RMS e tende a 5 × RMS (crista de ~14 a 15 dB, perda de RMS abaixo de 1 dB). Foi testado antes de entrar; uma saturação global achatava o corpo do sinal e foi descartada.

### Famílias de respiração

| Família (`sound_id`) | Inspiração (s) | Expiração (s) | Ciclo nominal (s) | Ritmo nominal (rpm) |
|---|---|---|---|---|
| `breath_calm` | 1,90 | 2,30 | 4,20 | 14,3 |
| `breath_fast` | 0,75 | 0,95 | 1,70 | 35,3 |
| `breath_labored` | 0,80 | 1,40 | 2,20 | 27,3 |

Os três ciclos cabem na faixa de 1,5 a 4,3 s (DATA_STRUCTURES §1.4). Cada fase tem duração fixa, com as 4 variações de mesmo comprimento. Para o `BreathingAudio` (F2-006b): quando o período real diferir do nominal, escolha a família mais próxima e complete com silêncio (período maior) ou comprima com `pitch_scale` (período menor, até uns 15 %). Não corte a expiração no meio.

## Catálogo (41 arquivos)

| `sound_id` | Papel | Variações | Duração (s) | Arquivos |
|---|---|---|---|---|
| `breath_calm` | inhale | 4 | 1,90 | `breath_calm_inhale_v1..v4` |
| `breath_calm` | exhale | 4 | 2,30 | `breath_calm_exhale_v1..v4` |
| `breath_fast` | inhale | 4 | 0,75 | `breath_fast_inhale_v1..v4` |
| `breath_fast` | exhale | 4 | 0,95 | `breath_fast_exhale_v1..v4` |
| `breath_labored` | inhale | 4 | 0,80 | `breath_labored_inhale_v1..v4` |
| `breath_labored` | exhale | 4 | 1,40 | `breath_labored_exhale_v1..v4` |
| `wheeze` | layer | 4 | 2,40 | `wheeze_layer_v1..v4` |
| `cough_warning` | one_shot | 3 | 1,50 | `cough_warning_v1..v3` |
| `cough` | one_shot | 4 | 1,00 | `cough_v1..v4` |
| `gasp` | one_shot | 3 | 1,20 | `gasp_v1..v3` |
| `inhaler_puff` | one_shot | 3 | 1,00 | `inhaler_puff_v1..v3` |

Tamanho total dos WAV: 5,04 MB (limite de 15 MB). O `manifest.json` traz, por arquivo, `sound_id`, papel, família, variação, duração, número de amostras, RMS, pico, a classe de nível e o SHA-256.

## Importação no Godot

Cada `.wav.import` desta pasta tem `compress/mode=0` (PCM). O padrão do Godot para WAV é Quite OK Audio, que é com perda, e o teste de integração reprova esse caso (o formato deixa de ser 16 bits e o número de amostras muda). Não reverta esse campo. Se um `.import` for regenerado, ajuste o campo de novo.

Após criar ou mudar um WAV:

```
& $g --headless --path D:\Dev\DeadBreath\game --import
& $g --headless --fixed-fps 60 --path D:\Dev\DeadBreath\game -s res://tests/run_all.gd -- --filter=audio
```

O teste está em `game/tests/integration/audio/test_body_sounds_manifest.gd`. Ele confere a importação de cada item como `AudioStreamWAV`, a duração, o formato, a presença dos `sound_id` exigidos com variações, o pico abaixo de -1 dBFS e a duração de 1,5 s do aviso.

## Limitações conhecidas

- **Não foi ouvido pelo autor.** A avaliação é objetiva (espectro, envelope, níveis). Se soa como respiração humana, só o playtest responde. Se não soar, o usuário pode gravar os sons (D-07).
- **Síntese.** Os detalhes de turbulência e as ressonâncias são aproximações. Algum timbre pode soar sintético, principalmente a voz glotal das fases ofegantes e o chiado.
- **Variações fixas.** São quatro por fase, com desvios pequenos e controlados. Não é um espaço contínuo de variações.
- **Durações fixas por família.** O `BreathingAudio` precisa lidar com períodos diferentes do nominal (ver "Famílias de respiração").
- **Puff mais brilhante.** O espectro do puff é mais agudo que o da respiração, por causa do clique mecânico e do aerossol. É esperado; o alerta de espectro plano vale só para as fases de respiração.
- **Tosse e gasp com limitador de joelho.** O efeito é pequeno (RMS abaixo de 1 dB), mas altera a forma da onda nos picos.
- **Determinismo entre plataformas.** Ver "Como verificar o determinismo".

## Mudanças nos parâmetros

Edite `body_synth.py` (tabelas `BREATH_BASE`, `BREATH_VARIANT_FEATURES`, os `*_presets` por tipo, `CLASS_OFFSET_DB`, `KNEE_*`). Depois: regenerar, `check_regen.py` (vai passar, porque o arquivo commitado mudou junto), `analyze_body.py`, `--import`, teste de áudio. Atualize também a evidência em `Docs/QA/EVIDENCE/F2-006a_*`.

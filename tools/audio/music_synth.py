#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""DEAD BREATH - camadas procedurais da música adaptativa básica (F4-006a).

Três camadas em loop, com a mesma duração (LOOP_SECONDS) e o mesmo tempo (BPM), para tocarem juntas e
sincronizadas. O AdaptiveMusic (game/presentation/audio/adaptive_music.gd) só muda o volume de cada uma:
  - calm    : drone grave (36, 54, 72 e 109 Hz), com respiração lenta de volume (0,25 Hz);
  - tension : pulsação dissonante (98/104 Hz, segunda menor; 110/156 Hz, trítono) com um pulso por tempo;
  - chase   : percussão e ritmo (bumbo nas batidas, caixa, chimbal e baixo em colcheias).

Regras:
  - só biblioteca padrão e as primitivas de body_synth.py (mesma biblioteca da F2-006a);
  - PRNG SplitMix64 e semente por camada (SHA-256 com a base "DEADBREATH|F4-006a|music|v1");
  - loop sem emenda: toda frequência contínua é múltiplo inteiro de 1/LOOP_SECONDS (aqui, inteiro em Hz), e o
    pulso (16 no loop) também; os eventos rítmicos entram em módulo LOOP, então a cauda que passa do fim volta ao
    início. Sem fade: um fade mudaria a emenda. Cada evento tem rampa de 2 ms para não estalar;
  - WAV 16 bits mono 44,1 kHz, PCM (o .wav.import deve ter compress/mode=0 e edit/loop_mode=2);
  - RMS-alvo por camada (TARGET_RMS_DBFS), pico final abaixo de -3 dBFS.

Uso:
    python tools/audio/music_synth.py                 (grava em game/content/audio/music)
    python tools/audio/music_synth.py --out <pasta>   (outra pasta, p. ex. temporaria)
    python tools/audio/music_synth.py --patch-imports (ajusta os .wav.import criados pelo Godot)
"""

import argparse
import hashlib
import json
import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import body_synth as bs  # noqa: E402

GENERATOR_VERSION = "f4-006a.1"
SEED_BASE = "DEADBREATH|F4-006a|music|v1"
SR = bs.SR
TWO_PI = 2.0 * math.pi
BPM = 80.0
BEATS_PER_BAR = 4
BARS = 4
BEAT_S = 60.0 / BPM                      # 0,75 s
STEP_S = BEAT_S / 4.0                    # colcheia de 16 avos: 0,1875 s
STEPS = 16 * BARS                        # 64 passos de 16 avos no loop
LOOP_SECONDS = BARS * BEATS_PER_BAR * BEAT_S   # 12,0 s
N = int(round(LOOP_SECONDS * SR))        # 529200 amostras (inteiro: o loop fecha em amostra exata)
TARGET_RMS_DBFS = -20.0
PEAK_CEILING_DBFS = -3.0
RAMP_S = 0.002
LAYERS = ("calm", "tension", "chase")
REPO_ROOT = bs.REPO_ROOT
DEFAULT_OUT = os.path.join(REPO_ROOT, "game", "content", "audio", "music")

# Chase: padrão de um compasso (16 avos). O último compasso ganha um bumbo extra no 15º avo (passo 62).
KICK_POS = (0, 4, 8, 12)
SNARE_POS = (4, 12)
HAT_POS = (2, 6, 10, 14)
BASS_POS = (0, 2, 4, 6, 8, 10, 12, 14)
BASS_HZ_BY_BAR = (55, 55, 49, 65)       # um valor inteiro por compasso (periodicidade exata)
EXTRA_KICK_STEP = 62

sha256_file = bs.sha256_file


def seed_for(name):
    """Semente de 64 bits derivada do nome da camada (SHA-256; independe da versão do Python)."""
    digest = hashlib.sha256((SEED_BASE + "|" + name).encode("utf-8")).digest()
    return int.from_bytes(digest[:8], "little")


def _place(out, t0, samples):
    """Soma `samples` em `out` a partir de t0 (segundos), com módulo LOOP: a cauda que passa do fim volta ao início."""
    i0 = int(round(t0 * SR))
    for j, v in enumerate(samples):
        out[(i0 + j) % N] += v


def _ramp(n):
    m = max(1, int(RAMP_S * SR))
    return [min(1.0, j / float(m)) for j in range(n)]


# ---------------------------------------------------------------------------
# Camadas
# ---------------------------------------------------------------------------

def calm_layer(rng):
    """Drone grave. Frequências inteiras em Hz e respiração de 0,25 Hz (3 ciclos no loop): periódico."""
    tones = ((36.0, 1.00, 0.0), (54.0, 0.45, 0.7), (72.0, 0.30, 1.9), (109.0, 0.08, 2.6))
    out = [0.0] * N
    for i in range(N):
        t = i / float(SR)
        s = 0.0
        for f, w, p in tones:
            s += w * math.sin(TWO_PI * f * t + p)
        out[i] = (0.75 + 0.25 * math.sin(TWO_PI * 0.25 * t)) * s
    return out


def tension_layer(rng):
    """Pulsação dissonante: 98/104 Hz (segunda menor) e 110/156 Hz (trítono), com um pulso por tempo.
    O pulso é cos^6 (suave e periódico): 16 pulsos no loop, 80 BPM (16 / 12 Hz = 4/3 Hz)."""
    tones = ((98.0, 1.00, 0.0), (104.0, 0.90, 1.0), (110.0, 0.55, 0.3), (156.0, 0.35, 2.2))
    pulse_hz = (BEATS_PER_BAR * BARS) / LOOP_SECONDS
    out = [0.0] * N
    for i in range(N):
        t = i / float(SR)
        g = max(0.0, math.cos(TWO_PI * pulse_hz * t)) ** 6
        s = 0.0
        for f, w, p in tones:
            s += w * math.sin(TWO_PI * f * t + p)
        out[i] = (0.30 + 0.70 * g) * s
    return out


def _kick_samples():
    n = int(0.30 * SR)
    out = []
    ph = 0.0
    ramp = _ramp(n)
    for j in range(n):
        t = j / float(SR)
        f = 45.0 + 60.0 * math.exp(-t / 0.025)
        ph += TWO_PI * f / SR
        out.append(ramp[j] * math.exp(-t / 0.13) * math.sin(ph))
    return out


def _snare_samples(rng):
    n = int(0.22 * SR)
    nb = bs.blocks(n)
    noise = bs.unit(bs.biquad(bs.white(rng, n), "bp", bs.const(1800.0, nb), 0.9))
    ramp = _ramp(n)
    out = []
    for j in range(n):
        t = j / float(SR)
        body = 0.30 * math.sin(TWO_PI * 190.0 * t) * math.exp(-t / 0.05)
        out.append(ramp[j] * (0.8 * noise[j] * math.exp(-t / 0.07) + body))
    return out


def _hat_samples(rng):
    n = int(0.06 * SR)
    nb = bs.blocks(n)
    noise = bs.unit(bs.biquad(bs.white(rng, n), "hp", bs.const(7000.0, nb), 0.7))
    ramp = _ramp(n)
    return [0.25 * ramp[j] * noise[j] * math.exp(-j / float(SR) / 0.02) for j in range(n)]


def _bass_samples(hz):
    n = int(0.25 * SR)
    ramp = _ramp(n)
    out = []
    for j in range(n):
        t = j / float(SR)
        s = math.sin(TWO_PI * hz * t) + 0.35 * math.sin(TWO_PI * 2.0 * hz * t)
        out.append(ramp[j] * math.exp(-t / 0.14) * s)
    return out


def chase_layer(rng):
    """Percussão e ritmo: bumbo nas batidas, caixa nos tempos 2 e 4, chimbal nas contratempos e baixo em colcheias."""
    out = [0.0] * N
    kick = _kick_samples()
    for step in range(STEPS):
        t0 = step * STEP_S
        bar = step // 16
        pos = step % 16
        if pos in KICK_POS or step == EXTRA_KICK_STEP:
            _place(out, t0, kick)
        if pos in SNARE_POS:
            _place(out, t0, _snare_samples(rng))
        if pos in HAT_POS:
            _place(out, t0, _hat_samples(rng))
        if pos in BASS_POS:
            _place(out, t0, _bass_samples(BASS_HZ_BY_BAR[bar]))
    return out


LAYER_BUILDERS = (("calm", calm_layer), ("tension", tension_layer), ("chase", chase_layer))


# ---------------------------------------------------------------------------
# Normalização, emenda e escrita
# ---------------------------------------------------------------------------

def normalize(x):
    """Limitador suave de crista (bs.knee_limit, o mesmo dos transientes do corpo: função pontual, então o loop
    continua periódico) e depois leva o RMS da camada inteira ao alvo. Se o pico passar do teto, reduz o ganho.
    Sem fade: um fade mudaria a emenda."""
    x = bs.knee_limit(x)
    n = len(x)
    rms = math.sqrt(sum(v * v for v in x) / float(n))
    peak = max(abs(v) for v in x)
    if rms <= 0.0 or peak <= 0.0:
        return x
    gain = (10.0 ** (TARGET_RMS_DBFS / 20.0)) / rms
    ceiling = 10.0 ** (PEAK_CEILING_DBFS / 20.0)
    if peak * gain > ceiling:
        gain = ceiling / peak
    return [v * gain for v in x]


def seam_ratio(ints):
    """Salto na emenda (última amostra contra a primeira) dividido pela maior diferença entre vizinhos do próprio
    loop. Até 1 = a emenda não sai do que o sinal faz em qualquer outro ponto. Uma razão média (como no mundo) dá
    falso alarme em sinal tonal de inclinação variável, que é periódico e sem estalo."""
    n = len(ints)
    max_diff = 0
    for i in range(1, n):
        d = abs(ints[i] - ints[i - 1])
        if d > max_diff:
            max_diff = d
    jump = abs(ints[0] - ints[n - 1])
    return jump / float(max_diff) if max_diff > 0 else 0.0


def generate(out_dir, verbose=True):
    """Gera as três camadas em WAV e o manifest.json em out_dir. Retorna o manifesto (dict)."""
    os.makedirs(out_dir, exist_ok=True)
    files = []
    for layer, build in LAYER_BUILDERS:
        rng = bs.Rng(seed_for("music_" + layer))
        ints = bs.to_int16(normalize(build(rng)))
        fname = "music_%s.wav" % layer
        path = os.path.join(out_dir, fname)
        bs.write_wav(path, ints)
        rms_db, peak_db = bs.measure(ints)
        n = len(ints)
        files.append(dict(
            file=fname,
            sound_id="music_" + layer,
            role="layer",
            layer=layer,
            variation=1,
            loop=True,
            bpm=BPM,
            duration_s=round(n / float(SR), 6),
            samples=n,
            rms_dbfs=rms_db,
            peak_dbfs=peak_db,
            seam_ratio=round(seam_ratio(ints), 3),
            sha256=sha256_file(path),
        ))
        if verbose:
            print("%-22s %-14s %6.3f s  RMS %7.2f  pico %7.2f  emenda %.3f" % (
                fname, "music_" + layer, n / float(SR), rms_db, peak_db, files[-1]["seam_ratio"]))
    manifest = dict(
        generator="tools/audio/music_synth.py",
        generator_version=GENERATOR_VERSION,
        seed_base=SEED_BASE,
        sample_rate=SR,
        bit_depth=16,
        channels=1,
        bpm=BPM,
        beats_per_bar=BEATS_PER_BAR,
        bars=BARS,
        loop_seconds=round(LOOP_SECONDS, 6),
        layers=list(LAYERS),
        sync=("As tres camadas tem a mesma duracao e o mesmo tempo. Tocam juntas desde o inicio em loop; "
              "so o volume muda (AdaptiveMusic)."),
        normalization=dict(target_rms_dbfs=TARGET_RMS_DBFS, peak_ceiling_dbfs=PEAK_CEILING_DBFS,
                           measure="RMS da camada inteira; pico sobre as amostras int16 (divisor 32768)"),
        files=files,
    )
    text = json.dumps(manifest, indent=2, sort_keys=True, ensure_ascii=True) + "\n"
    with open(os.path.join(out_dir, "manifest.json"), "w", encoding="ascii", newline="\n") as f:
        f.write(text)
    return manifest


def patch_imports(out_dir):
    """Ajusta os .wav.import criados pelo Godot: PCM (compress/mode=0) e repetição direta (edit/loop_mode=2)."""
    changed = 0
    for name in sorted(os.listdir(out_dir)):
        if not name.endswith(".wav.import"):
            continue
        path = os.path.join(out_dir, name)
        with open(path, "r", encoding="utf-8", newline="") as f:
            lines = f.read().split("\n")
        new_lines = []
        for line in lines:
            if line.startswith("compress/mode="):
                line = "compress/mode=0"
            elif line.startswith("edit/loop_mode="):
                line = "edit/loop_mode=2"
            new_lines.append(line)
        with open(path, "w", encoding="utf-8", newline="") as f:
            f.write("\n".join(new_lines))
        changed += 1
    return changed


def main(argv=None):
    ap = argparse.ArgumentParser(description="Gera as camadas da música adaptativa (F4-006a).")
    ap.add_argument("--out", default=DEFAULT_OUT, help="pasta de saida (padrao: game/content/audio/music)")
    ap.add_argument("--quiet", action="store_true")
    ap.add_argument("--patch-imports", action="store_true",
                    help="ajusta os .wav.import da pasta (PCM e repeticao direta) e sai")
    args = ap.parse_args(argv)
    out_dir = os.path.abspath(args.out)
    if args.patch_imports:
        print("imports ajustados: %d" % patch_imports(out_dir))
        return 0
    manifest = generate(out_dir, verbose=not args.quiet)
    total = sum(f["samples"] for f in manifest["files"]) * 2
    print("camadas: %d | bytes de audio: %d (%.2f MB)" % (len(manifest["files"]), total, total / 1e6))
    return 0


if __name__ == "__main__":
    sys.exit(main())

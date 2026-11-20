#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""DEAD BREATH - biblioteca procedural de sons do corpo (F2-006a).

Sintetiza, a partir de sementes fixas, os WAV de respiracao (inspiracao e expiracao
das familias calm, fast e labored), chiado (wheeze), aviso de tosse, tosse, gasp e
puff da bombinha, e grava game/content/audio/body/ junto com manifest.json.

Regras:
  - somente biblioteca padrao do Python (sem numpy, sem pacotes, sem download);
  - PRNG proprio (SplitMix64) e semente por arquivo (SHA-256 do nome): a mesma versao
    e a mesma semente geram os mesmos bytes;
  - WAV 16 bits, mono, 44100 Hz; pico final sempre abaixo de -3 dBFS.

Uso:
    python tools/audio/body_synth.py                 (grava em game/content/audio/body)
    python tools/audio/body_synth.py --out <pasta>   (grava em outra pasta, p. ex. temporaria)

Documentacao da tecnica e dos parametros: tools/audio/README.md.
"""

import argparse
import hashlib
import json
import math
import os
import struct
import sys
import wave

GENERATOR_VERSION = "f2-006a.1"
SEED_BASE = "DEADBREATH|F2-006a|v1"
SR = 44100
BLOCK = 64
PEAK_CEILING_DBFS = -3.0
REFERENCE_RMS_DBFS = -24.0
KNEE_CLASSES = ("cough", "gasp")  # transientes com crista alta: limitador suave antes de normalizar
KNEE_THRESHOLD_RMS = 3.0
KNEE_CEILING_RMS = 5.0
TWO_PI = 2.0 * math.pi
MASK64 = (1 << 64) - 1
REPO_ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
DEFAULT_OUT = os.path.join(REPO_ROOT, "game", "content", "audio", "body")

# Deslocamento de nivel por classe, em dB, em relacao a REFERENCE_RMS_DBFS.
# Respiracao sustentada e a referencia. Camadas ficam abaixo; transientes ficam acima
# (eles tem fator de crista alto e, se fossem medidos pelo RMS da respiracao, soariam fracos).
# O nivel de jogo vem do NoiseEvent (intensity_db), nao destes valores.
CLASS_OFFSET_DB = {
    "breath": 0.0,
    "layer": -6.0,
    "cough_warning": 0.0,
    "cough": 5.0,
    "gasp": 3.0,
    "puff": 2.0,
}

# Familias de respiracao: duracao nominal de inspiracao e expiracao (segundos).
# O ciclo nominal (inspiracao + expiracao) define o periodo que cada familia representa.
BREATH_FAMILIES = {
    "calm": {"sound_id": "breath_calm", "inhale_s": 1.9, "exhale_s": 2.3},
    "fast": {"sound_id": "breath_fast", "inhale_s": 0.75, "exhale_s": 0.95},
    "labored": {"sound_id": "breath_labored", "inhale_s": 0.8, "exhale_s": 1.4},
}
WHEEZE_DUR_S = 2.4
COUGH_WARNING_DUR_S = 1.5  # DATA_STRUCTURES 1.4: aviso 1,5 s antes da tosse.
COUGH_DUR_S = 1.0
GASP_DUR_S = 1.2
PUFF_DUR_S = 1.0


# ---------------------------------------------------------------------------
# Aleatoriedade determinista
# ---------------------------------------------------------------------------

def seed_for(name):
    """Semente de 64 bits derivada do nome do arquivo (SHA-256; independe da versao do Python)."""
    digest = hashlib.sha256((SEED_BASE + "|" + name).encode("utf-8")).digest()
    return int.from_bytes(digest[:8], "little")


class Rng(object):
    """SplitMix64. Saida em [0, 1) e (-1, 1), sempre reproduzivel."""

    def __init__(self, seed):
        self.state = seed & MASK64

    def next_u64(self):
        self.state = (self.state + 0x9E3779B97F4A7C15) & MASK64
        z = self.state
        z = ((z ^ (z >> 30)) * 0xBF58476D1CE4E5B9) & MASK64
        z = ((z ^ (z >> 27)) * 0x94D049BB133111EB) & MASK64
        return z ^ (z >> 31)

    def uniform(self):
        return (self.next_u64() >> 11) * (1.0 / 9007199254740992.0)

    def bipolar(self):
        return 2.0 * self.uniform() - 1.0


def jitter(rng, value, rel):
    """Varia um parametro em +-rel (proporcao), com o RNG do clipe."""
    return value * (1.0 + rel * rng.bipolar())


# ---------------------------------------------------------------------------
# Geradores de ruido e curvas
# ---------------------------------------------------------------------------

def white(rng, n):
    return [rng.bipolar() for _ in range(n)]


def pink(rng, n):
    """Ruido rosa (filtro de Paul Kellet, 7 polos)."""
    b0 = b1 = b2 = b3 = b4 = b5 = b6 = 0.0
    out = [0.0] * n
    for i in range(n):
        w = rng.bipolar()
        b0 = 0.99886 * b0 + w * 0.0555179
        b1 = 0.99332 * b1 + w * 0.0750759
        b2 = 0.96900 * b2 + w * 0.1538520
        b3 = 0.86650 * b3 + w * 0.3104856
        b4 = 0.55000 * b4 + w * 0.5329522
        b5 = -0.7616 * b5 - w * 0.0168980
        out[i] = (b0 + b1 + b2 + b3 + b4 + b5 + b6 + w * 0.5362) * 0.11
        b6 = w * 0.115926
    return out


def smooth_noise(rng, n, rate_hz):
    """Ruido de variacao lenta: valores aleatorios em pontos espacados por 1/rate_hz, com interpolacao cosenoidal."""
    step = max(2, int(round(SR / rate_hz)))
    npts = n // step + 2
    vals = [rng.bipolar() for _ in range(npts)]
    out = [0.0] * n
    for i in range(n):
        k = i // step
        s = (i - k * step) / float(step)
        s = (1.0 - math.cos(math.pi * s)) * 0.5
        out[i] = vals[k] + (vals[k + 1] - vals[k]) * s
    return out


def curve(points, count):
    """`count` valores igualmente espacados em [0, 1], interpolados (cosseno) entre pontos (u, valor)."""
    out = [0.0] * count
    if count <= 0:
        return out
    denom = (count - 1) if count > 1 else 1
    last = len(points) - 1
    seg = 0
    for i in range(count):
        u = i / float(denom)
        while seg < last - 1 and u > points[seg + 1][0]:
            seg += 1
        u0, v0 = points[seg]
        u1, v1 = points[seg + 1]
        s = (u - u0) / (u1 - u0) if u1 > u0 else 1.0
        if s < 0.0:
            s = 0.0
        elif s > 1.0:
            s = 1.0
        out[i] = v0 + (v1 - v0) * (1.0 - math.cos(math.pi * s)) * 0.5
    return out


def tcurve(points_s, dur_s, n):
    """Curva por amostra; pontos (segundo, valor). Os segundos sao convertidos para fracao da duracao."""
    pts = [(min(max(t / dur_s, 0.0), 1.0), v) for (t, v) in points_s]
    return curve(pts, n)


def track_s(points_s, dur_s, n):
    """Trilha por bloco (valor no inicio de cada bloco de 64 amostras), usada por filtros."""
    full = tcurve(points_s, dur_s, n)
    return [full[min(n - 1, b * BLOCK)] for b in range(blocks(n))]


def lin(a, b, n):
    if n <= 1:
        return [a] * n
    return [a + (b - a) * i / float(n - 1) for i in range(n)]


def track_lin(a, b, nb):
    if nb <= 1:
        return [a] * nb
    return [a + (b - a) * i / float(nb - 1) for i in range(nb)]


def const(value, nb):
    return [value] * nb


def blocks(n):
    return (n + BLOCK - 1) // BLOCK


def unit(x):
    """Escala para RMS 1 (mantem o formato; nao muda o pico relativo dentro do sinal)."""
    n = len(x)
    if n == 0:
        return x
    ms = sum(v * v for v in x) / float(n)
    if ms <= 1e-18:
        return x
    g = 1.0 / math.sqrt(ms)
    return [v * g for v in x]


def add_scaled(acc, x, w):
    for i in range(len(acc)):
        acc[i] += w * x[i]


# ---------------------------------------------------------------------------
# Filtros biquad (RBJ cookbook), com frequencia de corte variando por bloco
# ---------------------------------------------------------------------------

def _coeffs(kind, f, q, gain_db):
    f = min(max(f, 20.0), SR * 0.45)
    w0 = TWO_PI * f / SR
    cw = math.cos(w0)
    sw = math.sin(w0)
    alpha = sw / (2.0 * q)
    if kind == "lp":
        b0 = (1.0 - cw) * 0.5
        b1 = 1.0 - cw
        b2 = b0
        a0 = 1.0 + alpha
        a1 = -2.0 * cw
        a2 = 1.0 - alpha
    elif kind == "hp":
        b0 = (1.0 + cw) * 0.5
        b1 = -(1.0 + cw)
        b2 = b0
        a0 = 1.0 + alpha
        a1 = -2.0 * cw
        a2 = 1.0 - alpha
    elif kind == "bp":
        b0 = alpha
        b1 = 0.0
        b2 = -alpha
        a0 = 1.0 + alpha
        a1 = -2.0 * cw
        a2 = 1.0 - alpha
    elif kind == "peak":
        A = 10.0 ** (gain_db / 40.0)
        b0 = 1.0 + alpha * A
        b1 = -2.0 * cw
        b2 = 1.0 - alpha * A
        a0 = 1.0 + alpha / A
        a1 = -2.0 * cw
        a2 = 1.0 - alpha / A
    else:
        raise ValueError(kind)
    return (b0 / a0, b1 / a0, b2 / a0, a1 / a0, a2 / a0)


def biquad(x, kind, freqs, q=0.707, gain_db=0.0):
    """Filtra x. `freqs` tem um valor por bloco de 64 amostras (ver blocks())."""
    n = len(x)
    y = [0.0] * n
    z1 = 0.0
    z2 = 0.0
    nb = blocks(n)
    last_f = freqs[-1]
    for bi in range(nb):
        f = freqs[bi] if bi < len(freqs) else last_f
        b0, b1, b2, a1, a2 = _coeffs(kind, f, q, gain_db)
        start = bi * BLOCK
        end = min(n, start + BLOCK)
        for i in range(start, end):
            xi = x[i]
            yi = b0 * xi + z1
            z1 = b1 * xi - a1 * yi + z2
            z2 = b2 * xi - a2 * yi
            y[i] = yi
    return y


def body_eq(x):
    """Coloracao 'dentro da cabeca': corta grave abaixo de 55 Hz, realca 170 Hz (+3 dB), corta agudo acima de 8,5 kHz."""
    nb = blocks(len(x))
    y = biquad(x, "hp", const(55.0, nb), 0.7)
    y = biquad(y, "peak", const(170.0, nb), 1.0, 3.0)
    y = biquad(y, "lp", const(8500.0, nb), 0.7)
    return y


def harmonic_source(f_s, n_h, rng, exponent=1.2):
    """Fonte glotal aproximada: soma de n_h harmonicos com amplitude 1/k^exponent, frequencia por amostra."""
    n = len(f_s)
    out = [0.0] * n
    ph = rng.uniform() * TWO_PI
    weights = [1.0 / ((k + 1) ** exponent) for k in range(n_h)]
    for i in range(n):
        ph += TWO_PI * f_s[i] / SR
        if ph >= TWO_PI:
            ph -= TWO_PI
        s = 0.0
        for k in range(n_h):
            s += weights[k] * math.sin((k + 1) * ph)
        out[i] = s
    return out


def formant_mix(src, nb, formants):
    """Soma de ressonancias passa-faixa. formants: lista de (freq_inicio, freq_fim, q, peso)."""
    n = len(src)
    acc = [0.0] * n
    for f0, f1, q, w in formants:
        add_scaled(acc, biquad(src, "bp", track_lin(f0, f1, nb), q), w)
    return unit(acc)


# ---------------------------------------------------------------------------
# Respiracao: inspiracao e expiracao
# ---------------------------------------------------------------------------

def synth_breath(rng, dur_s, p):
    """Fase de respiracao. Ruido rosa + chiado de fluxo, modelado por ressonancias de trato vocal,
    voz de glote opcional, envelope de fluxo e coloracao de cabeca. Parametros em `p` (ver BREATH_BASE)."""
    n = int(round(dur_s * SR))
    nb = blocks(n)
    env = curve(p["env"], n)
    turb1 = smooth_noise(rng, n, 11.0)
    turb2 = smooth_noise(rng, n, 43.0)
    pk = unit(pink(rng, n))
    hiss = unit(biquad(white(rng, n), "bp", const(p["hiss_f"], nb), 0.8))
    turb = p["turb"]
    src = [(pk[i] + p["hiss"] * hiss[i]) * (1.0 + turb * (turb1[i] + 0.5 * turb2[i])) for i in range(n)]
    broad = unit(biquad(src, "lp", const(p["lp"], nb), 0.7))
    form = formant_mix(src, nb, [(f0, f1, p["fq"], w) for (f0, f1, w) in p["formants"]])
    m = p["mix"]
    out = [(1.0 - m) * broad[i] + m * form[i] for i in range(n)]
    if p["voice"] > 0.0:
        f_s = lin(p["f0"][0], p["f0"][1], n)
        glot = unit(harmonic_source(f_s, 10, rng))
        vf = formant_mix(glot, nb, [(700.0, 700.0, 5.0, 1.0), (1250.0, 1250.0, 5.0, 0.6)])
        add_scaled(out, vf, p["voice"])
    if p.get("click", 0.0) > 0.0:
        # Pequeno toque da glote no inicio da inspiracao (algumas variacoes).
        nc = int(0.012 * SR)
        cl = unit(biquad(white(rng, nc), "bp", const(2200.0, blocks(nc)), 1.2))
        for i in range(min(nc, n)):
            out[i] += p["click"] * cl[i] * math.exp(-i / (0.0025 * SR))
    trem = p.get("trem", 0.0)
    if trem > 0.0:
        w = TWO_PI * p.get("trem_hz", 14.0) / SR
        for i in range(n):
            out[i] *= 1.0 + trem * math.sin(w * i)
    out = [out[i] * env[i] for i in range(n)]
    return body_eq(out)


# Base por (familia, fase). Tempos em fracao da duracao da fase. `formants`: (f_ini, f_fim, peso).
BREATH_BASE = {
    ("calm", "inhale"): dict(
        env=[(0.0, 0.0), (0.22, 0.55), (0.5, 1.0), (0.8, 0.55), (0.95, 0.08), (1.0, 0.0)],
        hiss=0.12, hiss_f=3000.0, turb=0.16, lp=2600.0, mix=0.45, fq=2.5,
        formants=[(1100.0, 1300.0, 1.0), (2400.0, 2700.0, 0.45)], voice=0.0, f0=(0.0, 0.0)),
    ("calm", "exhale"): dict(
        env=[(0.0, 0.0), (0.12, 0.8), (0.35, 1.0), (0.7, 0.5), (0.9, 0.12), (1.0, 0.0)],
        hiss=0.06, hiss_f=2500.0, turb=0.20, lp=2800.0, mix=0.50, fq=2.2,
        formants=[(560.0, 480.0, 1.0), (1250.0, 1000.0, 0.5), (2600.0, 2400.0, 0.2)], voice=0.0, f0=(0.0, 0.0)),
    ("fast", "inhale"): dict(
        env=[(0.0, 0.0), (0.10, 0.75), (0.35, 1.0), (0.65, 0.6), (0.90, 0.15), (1.0, 0.0)],
        hiss=0.20, hiss_f=3200.0, turb=0.25, lp=3600.0, mix=0.50, fq=3.0,
        formants=[(1300.0, 1500.0, 1.0), (2700.0, 3100.0, 0.5)], voice=0.0, f0=(0.0, 0.0)),
    ("fast", "exhale"): dict(
        env=[(0.0, 0.0), (0.05, 0.9), (0.22, 1.0), (0.50, 0.6), (0.80, 0.15), (1.0, 0.0)],
        hiss=0.10, hiss_f=2800.0, turb=0.25, lp=3400.0, mix=0.50, fq=2.8,
        formants=[(650.0, 560.0, 1.0), (1400.0, 1200.0, 0.5), (2600.0, 2500.0, 0.2)], voice=0.03, f0=(150.0, 120.0)),
    ("labored", "inhale"): dict(
        # Inspiracao em dois tempos (hitch no meio), com sopro de esforco.
        env=[(0.0, 0.0), (0.14, 0.5), (0.30, 0.22), (0.42, 0.85), (0.62, 1.0), (0.86, 0.45), (1.0, 0.0)],
        hiss=0.18, hiss_f=2600.0, turb=0.35, lp=2800.0, mix=0.50, fq=2.4,
        formants=[(900.0, 1000.0, 1.0), (2100.0, 2300.0, 0.5)], voice=0.10, f0=(125.0, 110.0)),
    ("labored", "exhale"): dict(
        # Expiracao prolongada, com 'huff' de esforco e leve voz.
        env=[(0.0, 0.0), (0.04, 1.0), (0.30, 0.85), (0.55, 0.55), (0.80, 0.25), (0.95, 0.05), (1.0, 0.0)],
        hiss=0.12, hiss_f=2400.0, turb=0.35, lp=2600.0, mix=0.55, fq=2.2,
        formants=[(480.0, 420.0, 1.0), (1100.0, 900.0, 0.45)], voice=0.18, f0=(140.0, 100.0)),
}

# Caracteristicas fixas de cada variacao (v1..v4). Alem disso, cada parametro recebe um
# desvio pequeno e deterministico do RNG do clipe.
BREATH_VARIANT_FEATURES = {
    1: dict(form_k=1.00, hiss_k=1.00, turb_k=1.00, lp_k=1.00, hitch=True, click=0.0),
    2: dict(form_k=1.08, hiss_k=1.20, turb_k=1.00, lp_k=1.00, hitch=False, click=0.25),
    3: dict(form_k=0.95, hiss_k=1.00, turb_k=1.30, lp_k=1.00, hitch=True, click=0.0),
    4: dict(form_k=1.00, hiss_k=0.80, turb_k=1.00, lp_k=0.85, hitch=False, click=0.0),
}
LABORED_INHALE_SMOOTH = [(0.0, 0.0), (0.20, 0.6), (0.50, 1.0), (0.85, 0.4), (1.0, 0.0)]


def breath_params(rng, family, phase, var):
    base = BREATH_BASE[(family, phase)]
    feat = BREATH_VARIANT_FEATURES[var]
    p = {}
    p["env"] = [(u, v) for (u, v) in base["env"]]
    if family == "labored" and phase == "inhale" and not feat["hitch"]:
        p["env"] = LABORED_INHALE_SMOOTH
    # Pequenas variacoes de tempo nos pontos internos do envelope (sem mudar inicio e fim).
    p["env"] = [(u, v) if i in (0, len(p["env"]) - 1) else (min(0.97, max(0.03, jitter(rng, u, 0.03))), v)
                for i, (u, v) in enumerate(p["env"])]
    p["hiss"] = jitter(rng, base["hiss"] * feat["hiss_k"], 0.08)
    p["hiss_f"] = jitter(rng, base["hiss_f"], 0.05)
    p["turb"] = jitter(rng, base["turb"] * feat["turb_k"], 0.08)
    p["lp"] = jitter(rng, base["lp"] * feat["lp_k"], 0.05)
    p["mix"] = base["mix"]
    p["fq"] = base["fq"]
    p["formants"] = [(jitter(rng, f0 * feat["form_k"], 0.03), jitter(rng, f1 * feat["form_k"], 0.03), w)
                     for (f0, f1, w) in base["formants"]]
    p["voice"] = base["voice"]
    p["f0"] = (jitter(rng, base["f0"][0], 0.04), jitter(rng, base["f0"][1], 0.04)) if base["voice"] > 0 else (0.0, 0.0)
    p["click"] = feat["click"] if (family == "fast" and phase == "inhale") else 0.0
    return p


# ---------------------------------------------------------------------------
# Chiado (camada de wheeze)
# ---------------------------------------------------------------------------

def synth_wheeze(rng, dur_s, p):
    """Sibilo agudo e instavel: 3 parciais com jitter de frequencia (tom), somado a ruido passa-faixa
    estreito em volta da frequencia do sibilo (turbulencia no estreitamento)."""
    n = int(round(dur_s * SR))
    nb = blocks(n)
    env = tcurve(p["env"], dur_s, n)
    glide = tcurve(p["glide"], dur_s, n)
    j1 = smooth_noise(rng, n, 4.0)
    j2 = smooth_noise(rng, n, 12.0)
    f = [p["f0"] * glide[i] * (1.0 + p["jitter"] * (0.7 * j1[i] + 0.3 * j2[i])) for i in range(n)]
    parts = ((1, 1.0), (2, 0.42), (3, 0.16))
    det = [smooth_noise(rng, n, 2.0 + 1.7 * k) for (k, _) in parts]
    tone = [0.0] * n
    ph = [0.0, 0.0, 0.0]
    for i in range(n):
        s = 0.0
        for idx in range(3):
            k, w = parts[idx]
            ph[idx] += TWO_PI * k * f[i] * (1.0 + 0.012 * det[idx][i]) / SR
            if ph[idx] >= TWO_PI:
                ph[idx] -= TWO_PI
            s += w * math.sin(ph[idx])
        tone[i] = s
    ftrack = [f[min(n - 1, b * BLOCK)] for b in range(nb)]
    whistle = unit(biquad(white(rng, n), "bp", ftrack, 12.0))
    air = p["air"]
    tone_u = unit(tone)
    sig = [(1.0 - air) * tone_u[i] + air * whistle[i] for i in range(n)]
    tr = smooth_noise(rng, n, 6.5)
    out = [sig[i] * (1.0 + p["trem"] * tr[i]) * env[i] for i in range(n)]
    out = biquad(out, "hp", const(220.0, nb), 0.7)
    out = biquad(out, "lp", const(6000.0, nb), 0.7)
    return body_eq(out)


# ---------------------------------------------------------------------------
# Aviso de tosse (1,5 s): pigarro, garganta fechando, pressao antes da tosse
# ---------------------------------------------------------------------------

def synth_cough_warning(rng, p):
    dur = COUGH_WARNING_DUR_S
    n = int(round(dur * SR))
    nb = blocks(n)
    ev = tcurve(p["env_voice"], dur, n)
    en = tcurve(p["env_noise"], dur, n)
    f0 = tcurve(p["f0"], dur, n)
    glot = unit(harmonic_source(f0, 10, rng))
    voice = formant_mix(glot, nb, [(600.0, 600.0, 3.0, 1.0), (1300.0, 1300.0, 4.0, 0.5)])
    rasp = unit(biquad(white(rng, n), "bp", const(p["rasp_f"], nb), 1.5))
    nz = unit(biquad(pink(rng, n), "lp", track_s(p["lp"], dur, n), 0.8))
    sig = [ev[i] * (voice[i] + p["rasp"] * rasp[i]) + en[i] * nz[i] for i in range(n)]
    # Clique da garganta no fechamento, se houver.
    for (t, amp) in p.get("gaps", []):
        i0 = int(t * SR)
        for i in range(i0, min(n, i0 + int(0.008 * SR))):
            sig[i] += amp * math.exp(-(i - i0) / (0.002 * SR)) * rng.bipolar()
    return body_eq(sig)


# ---------------------------------------------------------------------------
# Tosse: explosao de glote + ar + voz curta + pico grave opcional
# ---------------------------------------------------------------------------

def synth_cough(rng, p):
    dur = COUGH_DUR_S
    n = int(round(dur * SR))
    nb = blocks(n)
    air = unit(biquad(pink(rng, n), "lp", track_s(p["lp"], dur, n), 0.8))
    ea = tcurve(p["env_air"], dur, n)
    ev = tcurve(p["env_voice"], dur, n)
    f0 = tcurve(p["f0"], dur, n)
    glot = unit(harmonic_source(f0, 9, rng))
    voice = formant_mix(glot, nb, [(p["f1"], p["f1"], 3.0, 1.0), (p["f2"], p["f2"], 4.0, 0.5)])
    burst_env = [0.0] * n
    thump = [0.0] * n
    for (tb, amp, tau) in p["bursts"]:
        i0 = int(tb * SR)
        for i in range(i0, min(n, i0 + int(6.0 * tau * SR) + 1)):
            t = (i - i0) / float(SR)
            burst_env[i] += amp * math.exp(-t / tau)
            thump[i] += 0.6 * amp * math.sin(TWO_PI * 110.0 * t) * math.exp(-t / 0.03)
    burst_src = unit(biquad(white(rng, n), "lp", const(p["burst_lp"], nb), 0.7))
    sig = [burst_env[i] * burst_src[i] + thump[i] for i in range(n)]
    sig = [sig[i] + ea[i] * air[i] * p["air_gain"] + ev[i] * voice[i] * p["voice_gain"] for i in range(n)]
    if p.get("rumble", 0.0) > 0.0:
        rum = unit(biquad(pink(rng, n), "lp", const(300.0, nb), 0.8))
        er = tcurve(p["env_rumble"], dur, n)
        for i in range(n):
            sig[i] += p["rumble"] * er[i] * rum[i]
    return body_eq(sig)


# ---------------------------------------------------------------------------
# Gasp de susto e puff da bombinha
# ---------------------------------------------------------------------------

def synth_gasp(rng, p):
    u_env = [(t / GASP_DUR_S, v) for (t, v) in p["env"]]
    bp = dict(env=u_env, hiss=0.25, hiss_f=2400.0, turb=0.30, lp=3800.0, mix=0.55, fq=1.6,
              formants=[(900.0, 880.0, 1.0), (2100.0, 2000.0, 0.5)], voice=0.45,
              f0=(p["f0"][0], p["f0"][1]), click=0.0, trem=p.get("trem", 0.0), trem_hz=14.0)
    return synth_breath(rng, GASP_DUR_S, bp)


def _place_click(out, rng, t0, amp):
    nc = int(0.014 * SR)
    i0 = int(t0 * SR)
    raw = unit(biquad(white(rng, nc), "bp", const(3000.0, blocks(nc)), 2.0))
    for i in range(nc):
        if i0 + i >= len(out):
            break
        t = i / float(SR)
        out[i0 + i] += amp * raw[i] * math.exp(-t / 0.0025)
        out[i0 + i] += 0.5 * amp * math.sin(TWO_PI * 900.0 * t) * math.exp(-t / 0.006)


def synth_puff(rng, p):
    n = int(round(PUFF_DUR_S * SR))
    out = [0.0] * n
    for (t0, amp) in p["clicks"]:
        _place_click(out, rng, t0, amp)
    # Jato do aerossol: ruido passa-alta, envelope curto.
    pn = unit(biquad(biquad(white(rng, n), "hp", const(2200.0, blocks(n)), 0.7), "lp", const(3600.0, blocks(n)), 0.7))
    pe = tcurve(p["puff_env"], PUFF_DUR_S, n)
    for i in range(n):
        out[i] += p["puff_gain"] * pe[i] * pn[i]
    # Inspiracao curta logo depois do jato.
    off = int(p["inhale_at"] * SR)
    br = synth_breath(rng, p["inhale_dur"], dict(
        env=[(0.0, 0.0), (0.15, 0.8), (0.5, 1.0), (0.85, 0.3), (1.0, 0.0)],
        hiss=0.12, hiss_f=3000.0, turb=0.20, lp=3000.0, mix=0.5, fq=2.6,
        formants=[(1200.0, 1400.0, 1.0), (2500.0, 2600.0, 0.4)], voice=0.0, f0=(0.0, 0.0), click=0.0))
    for i in range(len(br)):
        if off + i < n:
            out[off + i] += p["inhale_gain"] * br[i]
    return body_eq(out)


# ---------------------------------------------------------------------------
# Catalogo: cada arquivo, seu sound_id, papel, variacao e construtor
# ---------------------------------------------------------------------------

def _breath_builder(family, phase, var):
    def build(rng):
        p = breath_params(rng, family, phase, var)
        dur = BREATH_FAMILIES[family]["%s_s" % phase]
        return synth_breath(rng, dur, p)
    return build


def _wheeze_builder(var):
    presets = {
        1: dict(f0=1000.0, air=0.35, jitter=0.03, trem=0.30,
                env=[(0.0, 0.0), (0.2, 0.3), (0.7, 0.55), (1.2, 0.8), (1.8, 1.0), (2.2, 0.7), (2.4, 0.0)],
                glide=[(0.0, 1.0), (0.6, 1.08), (1.4, 0.97), (2.4, 1.03)]),
        2: dict(f0=1100.0, air=0.45, jitter=0.04, trem=0.40,
                env=[(0.0, 0.0), (0.15, 0.4), (0.5, 0.7), (1.1, 1.0), (1.7, 0.85), (2.1, 0.4), (2.4, 0.0)],
                glide=[(0.0, 1.0), (0.9, 1.12), (2.4, 0.94)]),
        3: dict(f0=920.0, air=0.30, jitter=0.05, trem=0.25,
                env=[(0.0, 0.0), (0.25, 0.2), (0.8, 0.6), (1.3, 0.95), (1.9, 0.95), (2.25, 0.5), (2.4, 0.0)],
                glide=[(0.0, 1.0), (1.2, 0.92), (2.4, 1.05)]),
        4: dict(f0=1180.0, air=0.40, jitter=0.035, trem=0.35,
                env=[(0.0, 0.0), (0.3, 0.25), (0.9, 0.7), (1.5, 1.0), (2.0, 0.6), (2.3, 0.2), (2.4, 0.0)],
                glide=[(0.0, 1.0), (0.4, 1.05), (1.2, 0.98), (2.0, 1.10), (2.4, 1.0)]),
    }
    preset = presets[var]

    def build(rng):
        p = dict(preset)
        p["f0"] = jitter(rng, p["f0"], 0.03)
        return synth_wheeze(rng, WHEEZE_DUR_S, p)
    return build


def _cough_warning_builder(var):
    presets = {
        # v1: pigarro com garganta fechando (uma pausa) e pressao antes da tosse.
        1: dict(f0=[(0.0, 128.0), (0.5, 146.0), (1.5, 118.0)],
                env_voice=[(0.0, 0.0), (0.05, 0.12), (0.30, 0.35), (0.55, 0.70), (0.78, 0.60), (0.84, 0.02),
                           (0.92, 0.02), (1.05, 0.50), (1.45, 0.90), (1.5, 0.0)],
                env_noise=[(0.0, 0.0), (0.12, 0.60), (0.30, 0.30), (0.50, 0.25), (0.78, 0.45), (0.84, 0.0),
                           (0.92, 0.0), (1.10, 0.35), (1.45, 0.95), (1.5, 0.0)],
                lp=[(0.0, 3000.0), (0.5, 1800.0), (0.9, 1200.0), (1.5, 700.0)],
                rasp_f=900.0, rasp=0.45, gaps=[(0.80, 0.25)]),
        # v2: duas gargantas fechando (pigarro duplo).
        2: dict(f0=[(0.0, 140.0), (0.5, 120.0), (1.5, 132.0)],
                env_voice=[(0.0, 0.0), (0.06, 0.2), (0.20, 0.55), (0.36, 0.05), (0.44, 0.05), (0.60, 0.55),
                           (0.78, 0.55), (0.84, 0.02), (0.92, 0.02), (1.10, 0.55), (1.45, 0.9), (1.5, 0.0)],
                env_noise=[(0.0, 0.0), (0.10, 0.5), (0.36, 0.0), (0.44, 0.0), (0.60, 0.25), (0.82, 0.0),
                           (0.92, 0.0), (1.10, 0.4), (1.45, 0.9), (1.5, 0.0)],
                lp=[(0.0, 2600.0), (0.6, 1500.0), (1.5, 800.0)],
                rasp_f=1100.0, rasp=0.35, gaps=[(0.36, 0.20), (0.80, 0.25)]),
        # v3: pigarro sem pausa, com rangido alto e pressao crescente.
        3: dict(f0=[(0.0, 112.0), (0.8, 124.0), (1.5, 150.0)],
                env_voice=[(0.0, 0.0), (0.10, 0.25), (0.45, 0.55), (0.90, 0.65), (1.20, 0.80), (1.45, 0.95), (1.5, 0.0)],
                env_noise=[(0.0, 0.0), (0.10, 0.35), (0.50, 0.30), (0.95, 0.40), (1.45, 0.85), (1.5, 0.0)],
                lp=[(0.0, 3400.0), (1.0, 1400.0), (1.5, 900.0)],
                rasp_f=1400.0, rasp=0.60, gaps=[]),
    }
    preset = presets[var]

    def build(rng):
        p = dict(preset)
        p["f0"] = [(t, jitter(rng, v, 0.03)) for (t, v) in preset["f0"]]
        p["rasp_f"] = jitter(rng, preset["rasp_f"], 0.05)
        return synth_cough_warning(rng, p)
    return build


def _cough_builder(var):
    presets = {
        # v1: tosse seca, uma explosao.
        1: dict(bursts=[(0.0, 1.0, 0.012)], burst_lp=5000.0,
                f0=[(0.0, 200.0), (0.03, 190.0), (0.40, 120.0), (1.0, 110.0)],
                f1=640.0, f2=1200.0,
                env_voice=[(0.0, 0.0), (0.03, 0.0), (0.05, 0.5), (0.12, 0.6), (0.35, 0.25), (0.5, 0.0), (1.0, 0.0)],
                env_air=[(0.0, 0.0), (0.03, 0.8), (0.13, 0.45), (0.30, 0.20), (0.50, 0.06), (0.70, 0.0), (1.0, 0.0)],
                lp=[(0.0, 3000.0), (0.5, 1300.0), (1.0, 1000.0)], air_gain=0.30, voice_gain=0.30,
                rumble=0.0, env_rumble=[(0.0, 0.0), (1.0, 0.0)]),
        # v2: dupla (duas explosoes).
        2: dict(bursts=[(0.0, 1.0, 0.012), (0.42, 0.70, 0.012)], burst_lp=4500.0,
                f0=[(0.0, 180.0), (0.03, 175.0), (0.36, 115.0), (0.47, 165.0), (0.80, 105.0), (1.0, 100.0)],
                f1=700.0, f2=1250.0,
                env_voice=[(0.0, 0.0), (0.03, 0.0), (0.05, 0.5), (0.25, 0.35), (0.38, 0.1), (0.47, 0.45),
                           (0.70, 0.2), (0.85, 0.0), (1.0, 0.0)],
                env_air=[(0.0, 0.0), (0.03, 0.8), (0.20, 0.5), (0.36, 0.25), (0.47, 0.6), (0.70, 0.2),
                         (0.90, 0.02), (1.0, 0.0)],
                lp=[(0.0, 2800.0), (0.6, 1400.0), (1.0, 900.0)], air_gain=0.28, voice_gain=0.28,
                rumble=0.0, env_rumble=[(0.0, 0.0), (1.0, 0.0)]),
        # v3: tosse molhada, com grave de secrecao.
        3: dict(bursts=[(0.0, 1.0, 0.020)], burst_lp=1800.0,
                f0=[(0.0, 150.0), (0.04, 140.0), (0.45, 100.0), (1.0, 95.0)],
                f1=520.0, f2=1000.0,
                env_voice=[(0.0, 0.0), (0.03, 0.0), (0.06, 0.45), (0.22, 0.4), (0.40, 0.15), (0.55, 0.0), (1.0, 0.0)],
                env_air=[(0.0, 0.0), (0.03, 0.7), (0.15, 0.5), (0.35, 0.25), (0.55, 0.05), (0.75, 0.0), (1.0, 0.0)],
                lp=[(0.0, 1500.0), (0.5, 900.0), (1.0, 700.0)], air_gain=0.35, voice_gain=0.25,
                rumble=0.55, env_rumble=[(0.0, 0.0), (0.03, 0.9), (0.30, 0.6), (0.50, 0.1), (0.65, 0.0), (1.0, 0.0)]),
        # v4: tosse seca em tres explosoes curtas.
        4: dict(bursts=[(0.0, 1.0, 0.010), (0.25, 0.80, 0.010), (0.50, 0.40, 0.010)], burst_lp=5500.0,
                f0=[(0.0, 210.0), (0.03, 200.0), (0.25, 170.0), (0.50, 140.0), (1.0, 110.0)],
                f1=680.0, f2=1300.0,
                env_voice=[(0.0, 0.0), (0.03, 0.0), (0.05, 0.4), (0.22, 0.3), (0.30, 0.2), (0.48, 0.2), (0.60, 0.05),
                           (1.0, 0.0)],
                env_air=[(0.0, 0.0), (0.03, 0.6), (0.12, 0.3), (0.25, 0.4), (0.37, 0.1), (0.50, 0.25), (0.62, 0.05),
                         (0.80, 0.0), (1.0, 0.0)],
                lp=[(0.0, 3400.0), (0.5, 1600.0), (1.0, 1000.0)], air_gain=0.22, voice_gain=0.25,
                rumble=0.0, env_rumble=[(0.0, 0.0), (1.0, 0.0)]),
    }
    preset = presets[var]

    def build(rng):
        p = dict(preset)
        p["f1"] = jitter(rng, preset["f1"], 0.05)
        p["f2"] = jitter(rng, preset["f2"], 0.05)
        p["f0"] = [(t, jitter(rng, v, 0.03)) for (t, v) in preset["f0"]]
        return synth_cough(rng, p)
    return build


def _gasp_builder(var):
    presets = {
        # v1: susto simples, com tremor leve no fim.
        1: dict(env=[(0.0, 0.0), (0.06, 0.9), (0.12, 1.0), (0.30, 0.6), (0.50, 0.3), (0.75, 0.08), (0.90, 0.0),
                     (1.2, 0.0)], f0=(290.0, 240.0), trem=0.15),
        # v2: susto duplo (segunda inspiracao menor).
        2: dict(env=[(0.0, 0.0), (0.06, 0.9), (0.12, 1.0), (0.26, 0.5), (0.40, 0.08), (0.50, 0.0), (0.58, 0.0),
                     (0.64, 0.6), (0.72, 0.6), (0.85, 0.12), (0.95, 0.0), (1.2, 0.0)], f0=(300.0, 250.0), trem=0.0),
        # v3: susto engasgado (glote fecha por um instante no inicio).
        3: dict(env=[(0.0, 0.0), (0.05, 0.6), (0.10, 0.12), (0.15, 0.10), (0.20, 0.95), (0.32, 0.6), (0.52, 0.25),
                     (0.78, 0.05), (0.92, 0.0), (1.2, 0.0)], f0=(260.0, 220.0), trem=0.10),
    }
    preset = presets[var]

    def build(rng):
        p = dict(preset)
        p["f0"] = (jitter(rng, preset["f0"][0], 0.03), jitter(rng, preset["f0"][1], 0.03))
        return synth_gasp(rng, p)
    return build


def _puff_builder(var):
    presets = {
        1: dict(clicks=[(0.0, 1.0)], puff_env=[(0.02, 0.0), (0.04, 1.0), (0.16, 0.7), (0.35, 0.25), (0.42, 0.0), (1.0, 0.0)],
                puff_gain=0.30, inhale_at=0.30, inhale_dur=0.55, inhale_gain=0.45),
        2: dict(clicks=[(0.0, 1.0), (0.07, 0.35)], puff_env=[(0.02, 0.0), (0.04, 1.0), (0.14, 0.6), (0.30, 0.2), (0.38, 0.0), (1.0, 0.0)],
                puff_gain=0.28, inhale_at=0.32, inhale_dur=0.50, inhale_gain=0.40),
        3: dict(clicks=[(0.0, 0.9)], puff_env=[(0.02, 0.0), (0.05, 0.9), (0.20, 0.8), (0.40, 0.35), (0.50, 0.0), (1.0, 0.0)],
                puff_gain=0.32, inhale_at=0.36, inhale_dur=0.55, inhale_gain=0.35),
    }
    preset = presets[var]

    def build(rng):
        return synth_puff(rng, dict(preset))
    return build


def catalog():
    """Lista de entradas do catalogo, na ordem de geracao (os nomes sao unicos)."""
    items = []
    for family in ("calm", "fast", "labored"):
        for phase in ("inhale", "exhale"):
            for var in (1, 2, 3, 4):
                name = "%s_%s_v%d" % (BREATH_FAMILIES[family]["sound_id"], phase, var)
                items.append(dict(name=name, sound_id=BREATH_FAMILIES[family]["sound_id"], role=phase,
                                  family=family, variation=var, cls="breath", build=_breath_builder(family, phase, var)))
    for var in (1, 2, 3, 4):
        items.append(dict(name="wheeze_layer_v%d" % var, sound_id="wheeze", role="layer", family=None,
                          variation=var, cls="layer", build=_wheeze_builder(var)))
    for var in (1, 2, 3):
        items.append(dict(name="cough_warning_v%d" % var, sound_id="cough_warning", role="one_shot", family=None,
                          variation=var, cls="cough_warning", build=_cough_warning_builder(var)))
    for var in (1, 2, 3, 4):
        items.append(dict(name="cough_v%d" % var, sound_id="cough", role="one_shot", family=None,
                          variation=var, cls="cough", build=_cough_builder(var)))
    for var in (1, 2, 3):
        items.append(dict(name="gasp_v%d" % var, sound_id="gasp", role="one_shot", family=None,
                          variation=var, cls="gasp", build=_gasp_builder(var)))
    for var in (1, 2, 3):
        items.append(dict(name="inhaler_puff_v%d" % var, sound_id="inhaler_puff", role="one_shot", family=None,
                          variation=var, cls="puff", build=_puff_builder(var)))
    return items


# ---------------------------------------------------------------------------
# Normalizacao, quantizacao, medidas e escrita
# ---------------------------------------------------------------------------

def fade_edges(x, fade_in_s, fade_out_s):
    n = len(x)
    fi = int(fade_in_s * SR)
    fo = int(fade_out_s * SR)
    for i in range(min(fi, n)):
        x[i] *= 0.5 * (1.0 - math.cos(math.pi * i / float(fi)))
    for j in range(min(fo, n)):
        x[n - 1 - j] *= 0.5 * (1.0 - math.cos(math.pi * j / float(fo)))
    return x


def knee_limit(x, threshold_rms=KNEE_THRESHOLD_RMS, ceiling_rms=KNEE_CEILING_RMS):
    """Limitador suave de crista: abaixo de threshold_rms (em multiplos do RMS) nada muda; acima, a curva
    tende a ceiling_rms por tangente hiperbolica. Usado so em transientes (tosse, gasp), cuja crista
    alta faria o pico bater no teto e o RMS cair abaixo do alvo da classe."""
    n = len(x)
    rms = math.sqrt(sum(v * v for v in x) / float(n))
    if rms <= 0.0:
        return x
    T = threshold_rms
    A = ceiling_rms
    out = [0.0] * n
    for i in range(n):
        u = x[i] / rms
        a = abs(u)
        if a > T:
            a = T + (A - T) * math.tanh((a - T) / (A - T))
            u = math.copysign(a, u)
        out[i] = u * rms
    return out


def normalize(x, cls):
    """Leva o RMS da clip inteira ao alvo da classe; se o pico passar do teto, reduz o ganho para o teto."""
    n = len(x)
    target_db = REFERENCE_RMS_DBFS + CLASS_OFFSET_DB[cls]
    ms = sum(v * v for v in x) / float(n)
    rms = math.sqrt(ms)
    peak = max(abs(v) for v in x)
    gain = (10.0 ** (target_db / 20.0)) / rms if rms > 0 else 1.0
    ceiling = 10.0 ** (PEAK_CEILING_DBFS / 20.0)
    if peak * gain > ceiling:
        gain = ceiling / peak
    return [v * gain for v in x]


def to_int16(x):
    out = []
    for v in x:
        q = int(round(v * 32767.0))
        if q > 32767:
            q = 32767
        elif q < -32767:
            q = -32767
        out.append(q)
    return out


def db_of(lin_value):
    if lin_value <= 0.0:
        return -120.0
    return 20.0 * math.log10(lin_value)


def measure(ints):
    n = len(ints)
    rms = math.sqrt(sum(v * v for v in ints) / float(n)) / 32768.0
    peak = max(abs(v) for v in ints) / 32768.0
    return round(db_of(rms), 2), round(db_of(peak), 2)


def write_wav(path, ints):
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(struct.pack("<%dh" % len(ints), *ints))


def sha256_file(path):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(65536), b""):
            h.update(chunk)
    return h.hexdigest()


def generate(out_dir, verbose=True):
    """Gera todos os WAV e o manifest.json em out_dir. Retorna o manifesto (dict)."""
    os.makedirs(out_dir, exist_ok=True)
    files = []
    for item in catalog():
        rng = Rng(seed_for(item["name"]))
        raw = item["build"](rng)
        raw = fade_edges(raw, 0.003, 0.010)
        if item["cls"] in KNEE_CLASSES:
            raw = knee_limit(raw)
        raw = normalize(raw, item["cls"])
        ints = to_int16(raw)
        fname = item["name"] + ".wav"
        path = os.path.join(out_dir, fname)
        write_wav(path, ints)
        rms_db, peak_db = measure(ints)
        n = len(ints)
        files.append(dict(
            file=fname,
            sound_id=item["sound_id"],
            role=item["role"],
            family=item["family"],
            variation=item["variation"],
            **{"class": item["cls"]},
            duration_s=round(n / float(SR), 6),
            samples=n,
            rms_dbfs=rms_db,
            peak_dbfs=peak_db,
            sha256=sha256_file(path),
        ))
        if verbose:
            print("%-34s %-14s %-7s %6.3f s  RMS %7.2f  pico %7.2f" % (
                fname, item["sound_id"], item["role"], n / float(SR), rms_db, peak_db))
    manifest = dict(
        generator="tools/audio/body_synth.py",
        generator_version=GENERATOR_VERSION,
        seed_base=SEED_BASE,
        sample_rate=SR,
        bit_depth=16,
        channels=1,
        normalization=dict(
            reference_rms_dbfs=REFERENCE_RMS_DBFS,
            class_offsets_db=CLASS_OFFSET_DB,
            peak_ceiling_dbfs=PEAK_CEILING_DBFS,
            transient_knee=dict(classes=list(KNEE_CLASSES), threshold_rms=KNEE_THRESHOLD_RMS,
                                ceiling_rms=KNEE_CEILING_RMS),
            measure="RMS da clip inteira; pico sobre as amostras int16 (divisor 32768)",
        ),
        families=dict(
            [(k, dict(sound_id=v["sound_id"], inhale_s=v["inhale_s"], exhale_s=v["exhale_s"],
                      cycle_s=round(v["inhale_s"] + v["exhale_s"], 3),
                      rate_rpm=round(60.0 / (v["inhale_s"] + v["exhale_s"]), 1)))
             for k, v in BREATH_FAMILIES.items()]),
        files=files,
    )
    text = json.dumps(manifest, indent=2, sort_keys=True, ensure_ascii=True) + "\n"
    with open(os.path.join(out_dir, "manifest.json"), "w", encoding="ascii", newline="\n") as f:
        f.write(text)
    return manifest


def main(argv=None):
    ap = argparse.ArgumentParser(description="Gera os sons procedurais do corpo (F2-006a).")
    ap.add_argument("--out", default=DEFAULT_OUT, help="pasta de saida (padrao: game/content/audio/body)")
    ap.add_argument("--quiet", action="store_true")
    args = ap.parse_args(argv)
    manifest = generate(os.path.abspath(args.out), verbose=not args.quiet)
    total = sum(f["samples"] for f in manifest["files"]) * 2
    print("arquivos: %d | bytes de audio: %d (%.2f MB)" % (len(manifest["files"]), total, total / 1e6))
    return 0


if __name__ == "__main__":
    sys.exit(main())

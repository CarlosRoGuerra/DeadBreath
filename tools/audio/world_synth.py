#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""DEAD BREATH - biblioteca procedural de sons do mundo (F3-003a).

Sintetiza, a partir de sementes fixas, os sons do mundo que não são do corpo do jogador:
passos por superfície e marcha, portas (lenta, normal, batida, trancada), impactos de objeto
(leve, médio, pesado), arrasto de móvel, queda do corpo, três loops de chuva (interna, janela,
externa) e trovões (rolagem longa e estalo próximo). Grava game/content/audio/world/ junto com
manifest.json, no mesmo formato de body/.

F4-006a (D4-06): falas do Observer (VOICE), quatro sound_id com três variações cada: voice_suspicious
(murmúrio), voice_investigate (pergunta), voice_chase_shout (grito) e voice_search (resmungo de busca).
São síntese PROVISÓRIA, com caráter de voz humana (fonte glotal com contorno de altura, formantes que
deslizam entre vogais, aspiração e consoantes em rajada). Não precisam ser inteligíveis: a legenda dá o
texto. O manifesto marca essas entradas com provisional=true.

Regras:
  - usa as primitivas DSP de body_synth.py (mesma biblioteca da F2-006a); só biblioteca padrão;
  - PRNG SplitMix64 e semente por arquivo (SHA-256 com a base "DEADBREATH|F3-003a|v1");
  - WAV 16 bits mono 44,1 kHz (PCM: o .wav.import deve ter compress/mode=0);
  - one-shots: RMS de referência -24 dBFS (o nível de jogo vem do evento, DATA §2.1);
  - loops: RMS-alvo por camada, costurados por cross-fade de potência constante (sem estalo);
  - pico final sempre abaixo de -3 dBFS.
  - Os arquivos antigos não mudam: cada um tem a própria semente, e as falas só acrescentam entradas.

Uso:
    python tools/audio/world_synth.py                 (grava em game/content/audio/world)
    python tools/audio/world_synth.py --out <pasta>   (outra pasta, p. ex. temporária)
    python tools/audio/world_synth.py --patch-imports (ajusta os .wav.import já criados pelo Godot)
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
SEED_BASE = "DEADBREATH|F3-003a|v1"
SR = bs.SR
TWO_PI = 2.0 * math.pi
REPO_ROOT = bs.REPO_ROOT
DEFAULT_OUT = os.path.join(REPO_ROOT, "game", "content", "audio", "world")

PEAK_CEILING_DBFS = -3.0
ONE_SHOT_RMS_DBFS = -24.0
LOOP_TARGET_RMS_DBFS = {"rain_interior": -34.0, "rain_window": -28.0, "rain_exterior": -24.0}
LOOP_SECONDS = 10.0
LOOP_CROSSFADE_S = 1.5
RUMBLE_SECONDS = 8.0
CRACK_SECONDS = 3.0


sha256_file = bs.sha256_file


def wseed(name):
    """Semente de 64 bits do arquivo (independe da semente da F2)."""
    digest = hashlib.sha256((SEED_BASE + "|" + name).encode("utf-8")).digest()
    return int.from_bytes(digest[:8], "little")


def n_of(seconds):
    return int(round(seconds * SR))


def add_at(out, sig, t0_s, gain=1.0):
    """Soma `sig` em `out` a partir do instante t0_s (corta no fim de `out`)."""
    i0 = int(round(t0_s * SR))
    limit = len(out)
    for j, v in enumerate(sig):
        k = i0 + j
        if k >= limit:
            break
        out[k] += gain * v


def ring(n, freq, tau_s, amp=1.0, phase=0.0):
    """Modo ressonante: senoide amortecida exp(-t/tau)."""
    w = TWO_PI * freq / SR
    k = 1.0 / (tau_s * SR)
    return [amp * math.sin(w * i + phase) * math.exp(-i * k) for i in range(n)]


def decay(sig, tau_s):
    k = 1.0 / (tau_s * SR)
    return [v * math.exp(-i * k) for i, v in enumerate(sig)]


def colored(rng, n, kind, freq, q=0.7):
    """Ruido branco filtrado (normalizado para RMS 1)."""
    return bs.unit(bs.biquad(bs.white(rng, n), kind, bs.const(freq, bs.blocks(n)), q))


def hump(n):
    return [math.sin(math.pi * i / float(max(1, n - 1))) ** 2 for i in range(n)]


def stick_slip(rng, n, rate_hz, jitter=0.12):
    """Pulsos de atrito (stick-slip) com taxa levemente irregular; valores em [0, 1]."""
    j = bs.smooth_noise(rng, n, 2.0)
    ph = 0.0
    out = [0.0] * n
    for i in range(n):
        ph += TWO_PI * rate_hz * (1.0 + jitter * j[i]) / SR
        s = math.sin(ph)
        out[i] = max(0.0, s) ** 3
    return out


# ---------------------------------------------------------------------------
# Passos
# ---------------------------------------------------------------------------

SURFACES = {
    "wood": dict(modes=[(118.0, 0.060, 1.00), (262.0, 0.035, 0.55), (655.0, 0.020, 0.30)],
                 click_lp=2600.0, click_hp=600.0, click_gain=1.10, body=0.70, grit=0.0, rustle=0.60),
    "carpet": dict(modes=[(88.0, 0.028, 0.70)], click_lp=900.0, click_hp=90.0, click_gain=0.40, body=0.35,
                   grit=0.0, rustle=0.40),
    "tile": dict(modes=[(1450.0, 0.012, 0.45), (2480.0, 0.007, 0.28), (365.0, 0.022, 0.35)],
                 click_lp=4200.0, click_hp=1400.0, click_gain=0.80, body=0.45, grit=0.0, rustle=0.70),
    "concrete": dict(modes=[(172.0, 0.020, 0.90), (432.0, 0.012, 0.35)], click_lp=3800.0, click_hp=300.0,
                     click_gain=1.30, body=0.65, grit=0.30, rustle=0.80),
}
GAITS = {
    "crawl": dict(dur=0.40, contacts=[(0.00, 0.55, 0.012)], rustle=0.85, scale=0.35),
    "crouch": dict(dur=0.34, contacts=[(0.00, 0.70, 0.010)], rustle=0.30, scale=0.50),
    "slow": dict(dur=0.36, contacts=[(0.00, 0.85, 0.009), (0.23, 0.30, 0.008)], rustle=0.10, scale=0.65),
    "walk": dict(dur=0.32, contacts=[(0.00, 1.00, 0.008), (0.19, 0.40, 0.007)], rustle=0.00, scale=0.85),
    "run": dict(dur=0.26, contacts=[(0.00, 1.00, 0.006), (0.12, 0.55, 0.005)], rustle=0.00, scale=1.20),
}


def footstep(rng, surface, gait):
    s = SURFACES[surface]
    g = GAITS[gait]
    n = n_of(g["dur"])
    out = [0.0] * n
    for (t, amp, tau) in g["contacts"]:
        t_j = t + 0.003 * rng.bipolar()
        amp_j = amp * (0.85 + 0.30 * rng.uniform())
        m = n_of(0.05)
        click = bs.unit(bs.biquad(bs.biquad(bs.white(rng, m), "lp", bs.const(s["click_lp"], bs.blocks(m)), 0.7),
                                  "hp", bs.const(s["click_hp"], bs.blocks(m)), 0.7))
        add_at(out, decay(click, tau), t_j, amp_j * s["click_gain"] * g["scale"])
        for (f, mt, w) in s["modes"]:
            f_j = f * (1.0 + 0.04 * rng.bipolar())
            mt_j = mt * (1.0 + 0.10 * rng.bipolar())
            add_at(out, ring(n_of(min(0.25, 5.0 * mt_j)), f_j, mt_j, amp_j * w * s["body"] * g["scale"]), t_j)
        if s["grit"] > 0.0:
            grit = decay(colored(rng, n_of(0.08), "bp", 2000.0, 1.2), 0.02)
            add_at(out, grit, t_j, amp_j * s["grit"] * g["scale"])
    if g["rustle"] > 0.0:
        rust = colored(rng, n, "bp", 700.0 + 300.0 * rng.uniform(), 1.0)
        env = hump(n)
        for i in range(n):
            out[i] += 0.35 * g["rustle"] * s["rustle"] * rust[i] * env[i]
    return out


# ---------------------------------------------------------------------------
# Portas
# ---------------------------------------------------------------------------

def door_slow(rng, v):
    """Rangido de dobradiça: pulsos de atrito sobre uma fundamental que desliza. Fecha com a lingueta."""
    dur = 2.2
    n = n_of(dur)
    f0 = bs.tcurve([(0.0, 300.0 + 30.0 * v), (0.6, 470.0), (1.2, 360.0), (1.9, 430.0), (dur, 380.0)], dur, n)
    rate = 10.5 + 1.5 * v
    ss = stick_slip(rng, n, rate)
    glot = bs.unit(bs.harmonic_source(f0, 6, rng))
    env = bs.tcurve([(0.0, 0.25), (0.3, 0.9), (1.6, 1.0), (dur, 0.15)], dur, n)
    sig = [(0.9 * glot[i] * ss[i] + 0.10 * ss[i]) * env[i] for i in range(n)]
    add_at(sig, decay(colored(rng, n_of(0.04), "bp", 2600.0, 2.0), 0.008), dur - 0.22, 0.8)
    add_at(sig, ring(n_of(0.05), 1900.0, 0.006, 0.5), dur - 0.22)
    return sig


def door_normal(rng, v):
    """Porta comum: passagem de ar pela fresta, um rangido curto e a lingueta."""
    dur = 0.9
    n = n_of(dur)
    sig = [0.0] * n
    swing = bs.unit(bs.biquad(bs.pink(rng, n), "lp", bs.const(1100.0 + 150.0 * v, bs.blocks(n)), 0.7))
    env = bs.tcurve([(0.0, 0.0), (0.2, 0.7), (0.55, 0.5), (0.8, 0.1), (dur, 0.0)], dur, n)
    for i in range(n):
        sig[i] += 0.35 * swing[i] * env[i]
    squeak_n = n_of(0.25)
    squeak = bs.harmonic_source(bs.lin(850.0 - 60.0 * v, 620.0, squeak_n), 5, rng)
    sq_env = hump(squeak_n)
    add_at(sig, [0.3 * squeak[i] * sq_env[i] for i in range(squeak_n)], 0.08)
    add_at(sig, decay(colored(rng, n_of(0.03), "bp", 3000.0, 2.0), 0.005), 0.62, 0.7)
    add_at(sig, ring(n_of(0.04), 1400.0, 0.004, 0.35), 0.62)
    return sig


def door_slam(rng, v):
    """Porta batida: estouro de impacto, folha de madeira ressoando, reverberação da sala e a lingueta."""
    dur = 0.7
    n = n_of(dur)
    sig = [0.0] * n
    scale = 1.0 - 0.15 * (v == 3)
    bang = decay(colored(rng, n_of(0.08), "lp", 2500.0, 0.7), 0.015)
    add_at(sig, bang, 0.0, 1.0)
    for (f, mt, w) in [(110.0, 0.13, 1.0), (230.0, 0.09, 0.6), (520.0, 0.05, 0.3)]:
        add_at(sig, ring(n_of(0.30), f * scale * (1.0 + 0.03 * rng.bipolar()), mt, w), 0.0, 0.8)
    tail_n = n_of(dur - 0.02)
    tail = decay(bs.unit(bs.biquad(bs.pink(rng, tail_n), "lp", bs.const(900.0, bs.blocks(tail_n)), 0.7)), 0.2)
    add_at(sig, tail, 0.02, 0.35)
    for k in range(3):
        add_at(sig, decay(colored(rng, n_of(0.01), "bp", 2800.0, 3.0), 0.002), 0.20 + 0.03 * k, 0.25)
    if v == 2:
        add_at(sig, decay(colored(rng, n_of(0.05), "lp", 1800.0, 0.7), 0.01), 0.12, 0.4)
    return sig


def door_locked(rng, v):
    """Porta trancada: maçaneta sacudida (cliques irregulares) e o trinco que não corre."""
    dur = 0.9
    n = n_of(dur)
    sig = [0.0] * n
    clicks = {1: 4, 2: 6, 3: 3}[v]
    t = 0.08
    for k in range(clicks):
        t += 0.05 + 0.02 * rng.uniform() + 0.01 * k
        amp = 0.4 + 0.4 * rng.uniform()
        add_at(sig, decay(colored(rng, n_of(0.006), "bp", 3200.0, 3.0), 0.002), t, amp)
        add_at(sig, ring(n_of(0.012), 1600.0 * (1.0 + 0.05 * rng.bipolar()), 0.004, 0.3 * amp), t)
    add_at(sig, ring(n_of(0.25), 180.0, 0.04, 0.8), 0.62)
    add_at(sig, decay(colored(rng, n_of(0.01), "lp", 1800.0, 0.7), 0.006), 0.62, 0.7)
    add_at(sig, ring(n_of(0.20), 1200.0, 0.05, 0.12), 0.62)
    return sig


# ---------------------------------------------------------------------------
# Impactos, arrasto, queda
# ---------------------------------------------------------------------------

IMPACTS = {
    "light": dict(dur=0.45, modes=[(1800.0, 0.05, 0.5), (3100.0, 0.03, 0.35), (4600.0, 0.02, 0.2)],
                  click=(4000.0, 0.003, 0.9), bounces=[]),
    "medium": dict(dur=0.70, modes=[(380.0, 0.09, 0.6), (820.0, 0.05, 0.5), (1500.0, 0.03, 0.3)],
                   click=(2000.0, 0.005, 0.8), bounces=[(0.18, 0.4)]),
    "heavy": dict(dur=1.00, modes=[(190.0, 0.25, 0.9), (520.0, 0.14, 0.5), (1150.0, 0.07, 0.3)],
                  click=(900.0, 0.008, 0.9), bounces=[(0.28, 0.5), (0.52, 0.25)]),
}


def impact(rng, level, v):
    spec = IMPACTS[level]
    n = n_of(spec["dur"])
    sig = [0.0] * n
    contacts = [(0.0, 1.0)] + [(t, a) for (t, a) in spec["bounces"]]
    cf, ctau, camp = spec["click"]
    for (t, a) in contacts:
        a_j = a * (0.9 + 0.2 * rng.uniform())
        t_j = t + 0.002 * rng.bipolar()
        m = n_of(0.03)
        add_at(sig, decay(colored(rng, m, "bp", cf * (1.0 + 0.06 * rng.bipolar()), 2.0), ctau), t_j, camp * a_j)
        for (f, mt, w) in spec["modes"]:
            add_at(sig, ring(n_of(min(0.4, 5.0 * mt)), f * (1.0 + 0.05 * rng.bipolar()), mt, w * a_j), t_j)
    if level == "heavy":
        add_at(sig, ring(n_of(0.25), 110.0, 0.08, 0.9), 0.0)
    if v == 3:
        tail_n = n_of(spec["dur"] - 0.05)
        add_at(sig, decay(colored(rng, tail_n, "bp", 1800.0, 2.0), 0.15), 0.05, 0.2)
    return sig


def furniture_drag(rng, v):
    """Arrasto de móvel: atrito irregular (stick-slip) sobre uma banda de ruído, com um toque no início e no fim."""
    dur = 1.6
    n = n_of(dur)
    center = 950.0 + 250.0 * v
    ss = stick_slip(rng, n, 19.0 + 3.0 * v, 0.2)
    band = colored(rng, n, "bp", center, 2.5)
    env = bs.tcurve([(0.0, 0.0), (0.15, 0.8), (1.3, 0.8), (dur, 0.0)], dur, n)
    sig = [band[i] * (0.4 + 0.6 * ss[i]) * env[i] for i in range(n)]
    add_at(sig, ring(n_of(0.1), 130.0, 0.05, 0.5), 0.02)
    add_at(sig, ring(n_of(0.1), 130.0, 0.05, 0.4), 1.45)
    return sig


def fall_body(rng, v):
    """Queda do corpo ao chão: impacto, um quique, roupa e um gemido curto (sem violência gráfica)."""
    dur = 1.2
    n = n_of(dur)
    sig = [0.0] * n
    add_at(sig, ring(n_of(0.25), 85.0, 0.08, 1.0), 0.0)
    add_at(sig, decay(colored(rng, n_of(0.03), "lp", 1500.0, 0.7), 0.012), 0.0, 0.9)
    add_at(sig, ring(n_of(0.15), 120.0, 0.05, 0.4), 0.35)
    add_at(sig, decay(colored(rng, n_of(0.2), "bp", 2000.0, 1.0), 0.2), 0.0, 0.25)
    gn = n_of(0.65)
    groan = bs.harmonic_source(bs.lin(170.0 - 5.0 * v, 130.0, gn), 6, rng)
    gh = hump(gn)
    add_at(sig, [0.30 * groan[i] * gh[i] for i in range(gn)], 0.45)
    return sig


# ---------------------------------------------------------------------------
# Trovões
# ---------------------------------------------------------------------------

RUMBLE = {
    1: dict(lp=150.0, pts=[(0.0, 0.0), (1.2, 1.0), (3.0, 0.7), (4.5, 0.95), (6.5, 0.45), (8.0, 0.0)], mid=0.30),
    2: dict(lp=180.0, pts=[(0.0, 0.0), (0.9, 0.9), (2.2, 0.35), (3.4, 1.0), (5.2, 0.6), (8.0, 0.0)], mid=0.40),
    3: dict(lp=120.0, pts=[(0.0, 0.0), (1.8, 0.8), (3.6, 0.55), (5.5, 0.35), (8.0, 0.0)], mid=0.15),
    4: dict(lp=160.0, pts=[(0.0, 0.0), (2.0, 1.0), (3.6, 0.8), (5.8, 0.5), (8.0, 0.0)], mid=0.35),
}


def thunder_rumble(rng, v):
    cfg = RUMBLE[v]
    n = n_of(RUMBLE_SECONDS)
    nb = bs.blocks(n)
    base = bs.unit(bs.biquad(bs.pink(rng, n), "lp", bs.const(cfg["lp"], nb), 0.7))
    env = bs.tcurve(cfg["pts"], RUMBLE_SECONDS, n)
    und = bs.smooth_noise(rng, n, 0.7)
    mid = bs.unit(bs.biquad(bs.pink(rng, n), "lp", bs.const(420.0, nb), 0.7))
    mid_env = bs.tcurve([(t + 0.4, a) for (t, a) in cfg["pts"]], RUMBLE_SECONDS, n)
    und2 = bs.smooth_noise(rng, n, 1.3)
    sig = [base[i] * env[i] * (1.0 + 0.25 * und[i]) + cfg["mid"] * mid[i] * mid_env[i] * (1.0 + 0.2 * und2[i])
           for i in range(n)]
    return sig


CRACK = {
    1: dict(snap_hp=1200.0, second=None, tail_tau=0.6, hiss=0.0),
    2: dict(snap_hp=1200.0, second=0.25, tail_tau=0.6, hiss=0.0),
    3: dict(snap_hp=900.0, second=None, tail_tau=0.9, hiss=0.0),
    4: dict(snap_hp=1500.0, second=None, tail_tau=0.5, hiss=0.5),
}


def thunder_crack(rng, v):
    cfg = CRACK[v]
    n = n_of(CRACK_SECONDS)
    sig = [0.0] * n
    snap_n = n_of(0.15)
    snap = decay(bs.unit(bs.biquad(bs.white(rng, snap_n), "hp", bs.const(cfg["snap_hp"], bs.blocks(snap_n)), 0.7)), 0.02)
    add_at(sig, snap, 0.0, 1.0)
    add_at(sig, ring(n_of(0.05), 900.0, 0.02, 0.4), 0.0)
    if cfg["second"] is not None:
        add_at(sig, decay(bs.unit(bs.white(rng, n_of(0.1))), 0.015), cfg["second"], 0.6)
    tail_n = n - n_of(0.05)
    tail = decay(bs.unit(bs.biquad(bs.pink(rng, tail_n), "lp", bs.const(300.0, bs.blocks(tail_n)), 0.7)),
                 cfg["tail_tau"])
    add_at(sig, tail, 0.05, 0.6)
    for k in range(12):
        t = 0.1 + 0.4 * rng.uniform()
        add_at(sig, decay(colored(rng, n_of(0.01), "bp", 2200.0, 2.0), 0.003), t, 0.15 + 0.15 * rng.uniform())
    if cfg["hiss"] > 0.0:
        hs_n = n_of(0.3)
        add_at(sig, decay(colored(rng, hs_n, "hp", 3000.0, 0.7), 0.1), 0.0, cfg["hiss"])
    return sig


# ---------------------------------------------------------------------------
# Chuva (loops)
# ---------------------------------------------------------------------------

RAIN = {
    "rain_interior": dict(lp=750.0, bed_hp=None, drop_rate=8.0, drop_band=(1800.0, 4200.0), drop_gain=0.25,
                          puddle_rate=0.0),
    "rain_window": dict(lp=3600.0, bed_hp=2500.0, drop_rate=55.0, drop_band=(2500.0, 6000.0), drop_gain=0.45,
                        puddle_rate=0.0),
    "rain_exterior": dict(lp=7000.0, bed_hp=2500.0, drop_rate=220.0, drop_band=(2000.0, 6000.0), drop_gain=0.70,
                          puddle_rate=6.0),
}


def _poisson_times(rng, rate, length_s):
    times = []
    t = 0.0
    while True:
        u = rng.uniform()
        t += -math.log(max(u, 1e-12)) / rate
        if t >= length_s:
            break
        times.append(t)
    return times


def rain_stream(rng, name, length_s):
    """Fluxo de chuva de `length_s` segundos: leito de ruído filtrado, gotas e (no exterior) poças."""
    cfg = RAIN[name]
    n = n_of(length_s)
    nb = bs.blocks(n)
    bed = bs.unit(bs.biquad(bs.white(rng, n), "lp", bs.const(cfg["lp"], nb), 0.7))
    if cfg["bed_hp"] is not None:
        hi = bs.unit(bs.biquad(bs.white(rng, n), "hp", bs.const(cfg["bed_hp"], nb), 0.7))
        bed = [bed[i] + 0.35 * hi[i] for i in range(n)]
    sig = [0.6 * v for v in bed]
    lo_f, hi_f = cfg["drop_band"]
    for t in _poisson_times(rng, cfg["drop_rate"], length_s):
        f = lo_f + (hi_f - lo_f) * rng.uniform()
        tau = 0.0008 + 0.002 * rng.uniform()
        amp = cfg["drop_gain"] * (0.3 + 0.7 * rng.uniform())
        burst = ring(n_of(0.012), f, tau, amp)
        add_at(sig, burst, t)
    for t in _poisson_times(rng, cfg["puddle_rate"], length_s) if cfg["puddle_rate"] > 0 else []:
        f = 350.0 + 300.0 * rng.uniform()
        add_at(sig, ring(n_of(0.05), f, 0.012, 0.5 + 0.3 * rng.uniform()), t)
    return sig


def rain_loop(rng, name):
    """Loop de L segundos: gera L + X, e o início é cross-fadado com a cauda (potência constante).

    r[i] = s[L+i] * cos(pi/2 * u) + s[i] * sin(pi/2 * u), u = i/X, para i < X; r[i] = s[i] para X <= i < L.
    Assim r[L-1] = s[L-1] e r[0] = s[L] são vizinhos reais da mesma corrente, e a emenda não tem salto.
    """
    L = n_of(LOOP_SECONDS)
    X = n_of(LOOP_CROSSFADE_S)
    s = rain_stream(rng, name, (L + X) / float(SR))
    r = s[:L]
    for i in range(X):
        u = i / float(X)
        r[i] = s[L + i] * math.cos(0.5 * math.pi * u) + s[i] * math.sin(0.5 * math.pi * u)
    return r


# ---------------------------------------------------------------------------
# Falas do Observer (VOICE, F4-006a; D4-06): PROVISÓRIAS
# ---------------------------------------------------------------------------
# Caráter de voz humana, não inteligibilidade: fonte glotal com contorno de altura (f0), formantes de vogal que
# deslizam entre um segmento e outro, aspiração (sopro) e consoantes como rajadas curtas de ruído. O texto vem da
# legenda (subtitles_pt_br.json, chaves subtitle.voice_*). Trocar por gravação ou CC0 se a escuta reprovar.

VOICE_FORMANTS = {  # (F1, F2, F3) em Hz, valores típicos de voz adulta
    "a": (730.0, 1090.0, 2440.0),
    "e": (530.0, 1840.0, 2480.0),
    "i": (270.0, 2290.0, 3010.0),
    "o": (570.0, 840.0, 2410.0),
    "u": (300.0, 870.0, 2240.0),
    "m": (250.0, 1000.0, 2300.0),  # nasal: boca fechada, ressonância grave
}
VOICE_FORMANT_WEIGHTS = (1.0, 0.6, 0.3)
VOICE_HARMONICS = 9

# Cada fala: tokens ("v", duração, altura inicial × base, altura final × base, vogal inicial, vogal final,
# fator de aspiração, saturação) | ("k", frequência da rajada, amplitude) | ("g", duração de silêncio).
# Por variação: base de altura (Hz), tempo (×), aspiração e corte do agudo (Hz).
VOICE_PHRASES = {
    "voice_suspicious": dict(  # murmúrio de desconfiança: "Hm?"
        tokens=[("v", 0.34, 1.00, 1.04, "m", "m", 0.4, 0.0),
                ("g", 0.04),
                ("v", 0.30, 1.04, 1.34, "m", "i", 1.0, 0.0)],
        base=(128.0, 112.0, 142.0), tempo=(1.00, 1.15, 0.90), asp=(0.05, 0.20, 0.10), lp=(3800.0, 3200.0, 4200.0)),
    "voice_investigate": dict(  # pergunta: "Quem está aí?"
        tokens=[("k", 1600.0, 0.35),
                ("v", 0.09, 1.00, 1.00, "u", "e", 0.3, 0.0),
                ("v", 0.10, 1.00, 1.02, "e", "e", 0.2, 0.0),
                ("v", 0.11, 1.02, 1.00, "m", "m", 0.2, 0.0),
                ("g", 0.07),
                ("v", 0.10, 1.04, 1.02, "e", "e", 0.3, 0.0),
                ("k", 2600.0, 0.40),
                ("v", 0.30, 1.10, 1.22, "a", "a", 0.2, 0.0),
                ("v", 0.10, 1.20, 1.10, "a", "a", 0.3, 0.0),
                ("v", 0.28, 1.12, 1.40, "a", "i", 0.4, 0.0)],
        base=(118.0, 140.0, 160.0), tempo=(1.00, 0.92, 1.08), asp=(0.10, 0.16, 0.08), lp=(3600.0, 4200.0, 3200.0)),
    "voice_chase_shout": dict(  # grito de perseguição: "Ali!"
        tokens=[("v", 0.40, 1.00, 1.18, "a", "a", 0.5, 3.0),
                ("v", 0.08, 1.18, 1.25, "a", "i", 0.5, 3.0),
                ("v", 0.46, 1.25, 0.90, "i", "i", 0.4, 3.0)],
        base=(230.0, 260.0, 290.0), tempo=(1.00, 0.95, 1.05), asp=(0.20, 0.25, 0.15), lp=(4500.0, 5000.0, 4200.0)),
    "voice_search": dict(  # resmungo de busca, abafado: "Cadê você?"
        tokens=[("k", 1500.0, 0.30),
                ("v", 0.12, 1.00, 1.00, "a", "a", 0.3, 0.0),
                ("v", 0.08, 1.00, 0.98, "a", "e", 0.3, 0.0),
                ("k", 1100.0, 0.25),
                ("v", 0.22, 0.98, 0.92, "e", "e", 0.5, 0.0),
                ("g", 0.05),
                ("v", 0.12, 0.96, 0.96, "o", "o", 0.5, 0.0),
                ("v", 0.30, 1.00, 1.22, "e", "i", 0.4, 0.0)],
        base=(104.0, 118.0, 132.0), tempo=(1.00, 1.10, 0.95), asp=(0.25, 0.30, 0.20), lp=(2200.0, 1900.0, 2400.0)),
}
VOICE_SOUND_IDS = ("voice_suspicious", "voice_investigate", "voice_chase_shout", "voice_search")
VOICE_VARIATIONS = (1, 2, 3)


def _vseg(rng, dur, f0a, f0b, va, vb, asp, drive):
    """Trecho sonoro: fonte glotal com altura de f0a a f0b, formantes de vogal va a vb (deslizam), sopro `asp`
    (fração) e, se drive > 0, saturação (grito). Envelope de ataque e liberação de 15 ms."""
    n = n_of(dur)
    nb = bs.blocks(n)
    glot = bs.unit(bs.harmonic_source(bs.lin(f0a, f0b, n), VOICE_HARMONICS, rng, 1.1))
    fa = VOICE_FORMANTS[va]
    fb = VOICE_FORMANTS[vb]
    forms = [(fa[k], fb[k], 4.0, VOICE_FORMANT_WEIGHTS[k]) for k in range(3)]
    vowel = bs.formant_mix(glot, nb, forms)
    hiss = bs.unit(bs.biquad(bs.white(rng, n), "bp", bs.const(1800.0, nb), 1.0))
    sig = [(1.0 - asp) * vowel[i] + asp * hiss[i] for i in range(n)]
    if drive > 0.0:
        k = math.tanh(drive)
        sig = [math.tanh(drive * v) / k for v in sig]
    env = bs.tcurve([(0.0, 0.0), (0.015, 1.0), (dur - 0.02, 1.0), (dur, 0.0)], dur, n)
    return [sig[i] * env[i] for i in range(n)]


def _vstop(rng, freq, amp):
    """Consoante oclusiva: rajada curta de ruído filtrado."""
    n = n_of(0.03)
    burst = bs.unit(bs.biquad(bs.white(rng, n), "bp", bs.const(freq, bs.blocks(n)), 1.5))
    return [amp * v for v in decay(burst, 0.006)]


def _vfinish(sig, lp_hz):
    """Banda de voz à distância: corta o grave abaixo de 110 Hz e o agudo acima de lp_hz."""
    nb = bs.blocks(len(sig))
    y = bs.biquad(sig, "hp", bs.const(110.0, nb), 0.707)
    return bs.biquad(y, "lp", bs.const(lp_hz, nb), 0.707)


def voice_clip(rng, sound_id, variation):
    """Uma fala do Observer (provisória). Variação 1..3: altura base, tempo, aspiração e corte do agudo mudam."""
    spec = VOICE_PHRASES[sound_id]
    i = variation - 1
    base = spec["base"][i] * (1.0 + 0.03 * rng.bipolar())
    tempo = spec["tempo"][i] * (1.0 + 0.02 * rng.bipolar())
    asp = spec["asp"][i]
    parts = []
    for tok in spec["tokens"]:
        if tok[0] == "v":
            _, dur, m0, m1, va, vb, af, drive = tok
            parts.append(_vseg(rng, dur * tempo, base * m0, base * m1, va, vb, asp * af, drive))
        elif tok[0] == "k":
            parts.append(_vstop(rng, tok[1] * (1.0 + 0.03 * rng.bipolar()), tok[2]))
        else:
            parts.append([0.0] * n_of(tok[1] * tempo))
    sig = []
    for part in parts:
        sig.extend(part)
    return _vfinish(sig, spec["lp"][i])


# ---------------------------------------------------------------------------
# Catálogo, normalização e escrita
# ---------------------------------------------------------------------------

def _entry(name, sound_id, role, variation, cls, build, surface=None, gait=None, loop=False):
    return dict(name=name, sound_id=sound_id, role=role, variation=variation, cls=cls, build=build,
                surface=surface, gait=gait, loop=loop)


def catalog():
    items = []
    for surface in ("wood", "carpet", "tile", "concrete"):
        for gait in ("crawl", "crouch", "slow", "walk", "run"):
            for var in (1, 2, 3):
                name = "footstep_%s_%s_v%d" % (surface, gait, var)
                items.append(_entry(name, "footstep_" + surface, "step", var, "one_shot",
                                    (lambda sf, gt: lambda rng: footstep(rng, sf, gt))(surface, gait),
                                    surface=surface, gait=gait))
    for v in (1, 2, 3):
        items.append(_entry("door_slow_v%d" % v, "door_slow", "one_shot", v, "one_shot",
                            (lambda vv: lambda rng: door_slow(rng, vv))(v)))
        items.append(_entry("door_normal_v%d" % v, "door_normal", "one_shot", v, "one_shot",
                            (lambda vv: lambda rng: door_normal(rng, vv))(v)))
        items.append(_entry("door_slam_v%d" % v, "door_slam", "one_shot", v, "one_shot",
                            (lambda vv: lambda rng: door_slam(rng, vv))(v)))
        items.append(_entry("door_locked_v%d" % v, "door_locked", "one_shot", v, "one_shot",
                            (lambda vv: lambda rng: door_locked(rng, vv))(v)))
    for level in ("light", "medium", "heavy"):
        for v in (1, 2, 3):
            items.append(_entry("impact_%s_v%d" % (level, v), "impact_" + level, "one_shot", v, "one_shot",
                                (lambda lv, vv: lambda rng: impact(rng, lv, vv))(level, v)))
    for v in (1, 2, 3):
        items.append(_entry("furniture_drag_v%d" % v, "furniture_drag", "one_shot", v, "one_shot",
                            (lambda vv: lambda rng: furniture_drag(rng, vv))(v)))
        items.append(_entry("fall_body_v%d" % v, "fall_body", "one_shot", v, "one_shot",
                            (lambda vv: lambda rng: fall_body(rng, vv))(v)))
    for name in ("rain_interior", "rain_window", "rain_exterior"):
        items.append(_entry(name + "_v1", name, "loop", 1, name,
                            (lambda nm: lambda rng: rain_loop(rng, nm))(name), loop=True))
    for v in (1, 2, 3, 4):
        items.append(_entry("thunder_rumble_v%d" % v, "thunder_rumble", "one_shot", v, "one_shot",
                            (lambda vv: lambda rng: thunder_rumble(rng, vv))(v)))
        items.append(_entry("thunder_crack_v%d" % v, "thunder_crack", "one_shot", v, "one_shot",
                            (lambda vv: lambda rng: thunder_crack(rng, vv))(v)))
    for sound_id in VOICE_SOUND_IDS:
        for v in VOICE_VARIATIONS:
            items.append(_entry("%s_v%d" % (sound_id, v), sound_id, "voice", v, "one_shot",
                                (lambda sd, vv: lambda rng: voice_clip(rng, sd, vv))(sound_id, v)))
    return items


def dc_block(x):
    """Passa-alta de 25 Hz: tira o deslocamento de componente contínua que o ruído grave deixa no clip."""
    return bs.biquad(x, "hp", bs.const(25.0, bs.blocks(len(x))), 0.707)


def _normalize_one_shot(x):
    x = dc_block(bs.fade_edges(x, 0.002, 0.010))
    x = bs.knee_limit(x)
    return _rms_to(x, ONE_SHOT_RMS_DBFS)


def _rms_to(x, target_db):
    n = len(x)
    rms = math.sqrt(sum(v * v for v in x) / float(n))
    peak = max(abs(v) for v in x)
    if rms <= 0.0 or peak <= 0.0:
        return x
    gain = (10.0 ** (target_db / 20.0)) / rms
    ceiling = 10.0 ** (PEAK_CEILING_DBFS / 20.0)
    if peak * gain > ceiling:
        gain = ceiling / peak
    return [v * gain for v in x]


def loop_seam(samples):
    """Métricas da emenda de um loop (sobre floats): salto entre a última e a primeira amostra,
    diferença média entre vizinhos e razão salto / diferença média. Razão alta = estalo na emenda."""
    n = len(samples)
    total = 0.0
    for i in range(1, n):
        total += abs(samples[i] - samples[i - 1])
    mean_diff = total / float(max(1, n - 1))
    jump = abs(samples[0] - samples[n - 1])
    ratio = jump / mean_diff if mean_diff > 0 else 0.0
    return jump, mean_diff, ratio


def generate(out_dir, verbose=True):
    """Gera todos os WAV e o manifest.json em out_dir. Retorna o manifesto (dict)."""
    os.makedirs(out_dir, exist_ok=True)
    files = []
    for item in catalog():
        rng = bs.Rng(wseed(item["name"]))
        raw = item["build"](rng)
        if item["loop"]:
            raw = _rms_to(dc_block(raw), LOOP_TARGET_RMS_DBFS[item["cls"]])
        else:
            raw = _normalize_one_shot(raw)
        ints = bs.to_int16(raw)
        fname = item["name"] + ".wav"
        path = os.path.join(out_dir, fname)
        bs.write_wav(path, ints)
        rms_db, peak_db = bs.measure(ints)
        n = len(ints)
        entry = dict(
            file=fname,
            sound_id=item["sound_id"],
            role=item["role"],
            family=None,
            variation=item["variation"],
            surface=item["surface"],
            gait=item["gait"],
            loop=item["loop"],
            provisional=(item["role"] == "voice"),
            **{"class": item["cls"]},
            duration_s=round(n / float(SR), 6),
            samples=n,
            rms_dbfs=rms_db,
            peak_dbfs=peak_db,
            sha256=bs.sha256_file(path),
        )
        if item["loop"]:
            jump, mean_diff, ratio = loop_seam([v / 32768.0 for v in ints])
            entry["seam_ratio"] = round(ratio, 3)
        files.append(entry)
        if verbose:
            print("%-34s %-16s %-8s %6.3f s  RMS %7.2f  pico %7.2f" % (
                fname, item["sound_id"], item["role"], n / float(SR), rms_db, peak_db))
    manifest = dict(
        generator="tools/audio/world_synth.py",
        generator_version=GENERATOR_VERSION,
        seed_base=SEED_BASE,
        sample_rate=SR,
        bit_depth=16,
        channels=1,
        normalization=dict(
            one_shot_rms_dbfs=ONE_SHOT_RMS_DBFS,
            loop_target_rms_dbfs=LOOP_TARGET_RMS_DBFS,
            peak_ceiling_dbfs=PEAK_CEILING_DBFS,
            transient_knee=dict(threshold_rms=bs.KNEE_THRESHOLD_RMS, ceiling_rms=bs.KNEE_CEILING_RMS,
                                classes="one_shot"),
            loop_crossfade_s=LOOP_CROSSFADE_S,
            loop_seconds=LOOP_SECONDS,
            measure="RMS da clip inteira; pico sobre as amostras int16 (divisor 32768)",
        ),
        provisional=dict(
            roles=["voice"],
            sound_ids=list(VOICE_SOUND_IDS),
            note=("D4-06 (F4-006a): falas do Observer sintetizadas, PROVISORIAS. Ficam ate a escuta do usuario "
                  "decidir se trocam por gravacao ou CC0 (ASSET_LICENSES.md). Legendas em subtitles_pt_br.json."),
        ),
        files=files,
    )
    text = json.dumps(manifest, indent=2, sort_keys=True, ensure_ascii=True) + "\n"
    with open(os.path.join(out_dir, "manifest.json"), "w", encoding="ascii", newline="\n") as f:
        f.write(text)
    return manifest


def patch_imports(out_dir):
    """Ajusta os .wav.import criados pelo Godot: PCM (compress/mode=0) e loop direto nos loops."""
    changed = 0
    for name in sorted(os.listdir(out_dir)):
        if not name.endswith(".wav.import"):
            continue
        path = os.path.join(out_dir, name)
        is_loop = name.startswith("rain_")
        with open(path, "r", encoding="utf-8", newline="") as f:
            lines = f.read().split("\n")
        new_lines = []
        for line in lines:
            if line.startswith("compress/mode="):
                line = "compress/mode=0"
            elif is_loop and line.startswith("edit/loop_mode="):
                line = "edit/loop_mode=2"
            new_lines.append(line)
        text = "\n".join(new_lines)
        with open(path, "w", encoding="utf-8", newline="") as f:
            f.write(text)
        changed += 1
    return changed


def main(argv=None):
    ap = argparse.ArgumentParser(description="Gera os sons do mundo (F3-003a).")
    ap.add_argument("--out", default=DEFAULT_OUT, help="pasta de saida (padrao: game/content/audio/world)")
    ap.add_argument("--quiet", action="store_true")
    ap.add_argument("--patch-imports", action="store_true",
                    help="ajusta os .wav.import da pasta (PCM e loop) e sai")
    args = ap.parse_args(argv)
    out_dir = os.path.abspath(args.out)
    if args.patch_imports:
        print("imports ajustados: %d" % patch_imports(out_dir))
        return 0
    manifest = generate(out_dir, verbose=not args.quiet)
    total = sum(f["samples"] for f in manifest["files"]) * 2
    print("arquivos: %d | bytes de audio: %d (%.2f MB)" % (len(manifest["files"]), total, total / 1e6))
    return 0


if __name__ == "__main__":
    sys.exit(main())

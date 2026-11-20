#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""DEAD BREATH - analise objetiva dos sons procedurais do corpo (F2-006a).

Le os WAV listados em game/content/audio/body/manifest.json e, para cada um, calcula:
  - envelope: pico, tempo de ataque (10 a 90 %), queda ate -20 dB, duracao ativa (> -40 dB
    do pico), cauda (ultimos 50 ms) e perfil em 10 segmentos iguais (dB relativos ao pico);
  - espectro (media das janelas com energia): centroide, rolloff de 85 %, inclinacao em
    dB/oitava (300 a 8000 Hz), planura espectral (dB; ruido branco ~ -2,5 dB), distribuicao
    de energia por faixa e pico tonal dominante;
  - alertas: planura acima de -6 dB em respiracao (espectro proximo de ruido branco),
    clipping (pico acima de -1 dBFS) e DC.

Usa somente a biblioteca padrao (FFT radix-2 propria). Saida: texto em
Docs/QA/EVIDENCE/F2-006a_analise.txt (ou o caminho passado em --out).

Uso:
    python tools/audio/analyze_body.py [--dir DIR] [--out ARQUIVO]
"""

import argparse
import json
import math
import os
import struct
import sys
import wave

REPO_ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
DEFAULT_DIR = os.path.join(REPO_ROOT, "game", "content", "audio", "body")
DEFAULT_OUT = os.path.join(REPO_ROOT, "Docs", "QA", "EVIDENCE", "F2-006a_analise.txt")
FFT_N = 2048
HOP = 1024
BAND_EDGES = [0, 300, 1000, 2500, 5000, 8000, 1e9]
BAND_LABELS = ["<300", "300-1k", "1k-2.5k", "2.5k-5k", "5k-8k", ">8k"]


def read_wav(path):
    with wave.open(path, "rb") as w:
        sr = w.getframerate()
        ch = w.getnchannels()
        sw = w.getsampwidth()
        n = w.getnframes()
        raw = w.readframes(n)
    if ch != 1 or sw != 2:
        raise ValueError("%s: esperado mono 16 bits" % path)
    ints = struct.unpack("<%dh" % n, raw)
    return sr, [v / 32768.0 for v in ints]


def make_fft_tables(n):
    rev = [0] * n
    bits = n.bit_length() - 1
    for i in range(n):
        r = 0
        x = i
        for _ in range(bits):
            r = (r << 1) | (x & 1)
            x >>= 1
        rev[i] = r
    cos_t = [math.cos(-2.0 * math.pi * k / n) for k in range(n // 2)]
    sin_t = [math.sin(-2.0 * math.pi * k / n) for k in range(n // 2)]
    return rev, cos_t, sin_t


FFT_TABLES = make_fft_tables(FFT_N)
HANN = [0.5 - 0.5 * math.cos(2.0 * math.pi * i / FFT_N) for i in range(FFT_N)]


def power_spectrum(frame):
    """Potencia (|X|^2) das FFT_N//2+1 faixas de uma janela ja multiplicada por Hann."""
    rev, cos_t, sin_t = FFT_TABLES
    n = FFT_N
    re = [frame[rev[i]] for i in range(n)]
    im = [0.0] * n
    size = 2
    while size <= n:
        half = size // 2
        step = n // size
        for start in range(0, n, size):
            for k in range(half):
                a = start + k
                b = a + half
                tr = cos_t[k * step]
                ti = sin_t[k * step]
                xr = re[b] * tr - im[b] * ti
                xi = re[b] * ti + im[b] * tr
                re[b] = re[a] - xr
                im[b] = im[a] - xi
                re[a] += xr
                im[a] += xi
        size <<= 1
    return [re[k] * re[k] + im[k] * im[k] for k in range(n // 2 + 1)]


def spectral_stats(x, sr):
    n_frames = 0
    acc = None
    for start in range(0, len(x) - FFT_N + 1, HOP):
        seg = x[start:start + FFT_N]
        ms = sum(v * v for v in seg) / FFT_N
        if ms <= 1e-9:  # ~ -90 dBFS: ignora silencio
            continue
        frame = [seg[i] * HANN[i] for i in range(FFT_N)]
        p = power_spectrum(frame)
        if acc is None:
            acc = [0.0] * len(p)
        for k in range(len(p)):
            acc[k] += p[k]
        n_frames += 1
    if acc is None or n_frames == 0:
        return None
    bin_hz = sr / float(FFT_N)
    freqs = [k * bin_hz for k in range(len(acc))]
    tot = sum(acc[k] for k in range(1, len(acc)) if 50.0 <= freqs[k] <= 12000.0)
    centroid = sum(freqs[k] * acc[k] for k in range(1, len(acc)) if 50.0 <= freqs[k] <= 12000.0) / tot
    cum = 0.0
    rolloff = None
    for k in range(1, len(acc)):
        if freqs[k] < 50.0 or freqs[k] > 12000.0:
            continue
        cum += acc[k]
        if cum >= 0.85 * tot:
            rolloff = freqs[k]
            break
    # Bandas de 1/6 de oitava (150 a 8000 Hz): potencia media por bin em cada banda. Assim cada oitava
    # pesa o mesmo; com bins lineares o agudo domina e a inclinacao sai enviesada.
    centers = []
    means = []
    lo = 150.0
    ratio = 2.0 ** (1.0 / 6.0)
    while lo < 8000.0:
        hi = lo * ratio
        ks = [k for k in range(1, len(acc)) if lo <= freqs[k] < hi]
        if ks:
            m = sum(acc[k] for k in ks) / len(ks)
            if m > 0.0:
                centers.append(math.sqrt(lo * hi))
                means.append(m)
        lo = hi
    log_f = [math.log10(c) for c in centers]
    log_p = [10.0 * math.log10(m) for m in means]
    mf = sum(log_f) / len(log_f)
    mp = sum(log_p) / len(log_p)
    sxx = sum((f - mf) ** 2 for f in log_f)
    sxy = sum((f - mf) * (p - mp) for f, p in zip(log_f, log_p))
    slope_per_oct = (sxy / sxx) * math.log10(2.0)
    geo = math.exp(sum(math.log(m) for m in means) / len(means))
    ari = sum(means) / len(means)
    flatness_db = 10.0 * math.log10(geo / ari)
    bands = [0.0] * len(BAND_LABELS)
    for k in range(1, len(acc)):
        if freqs[k] < 50.0 or freqs[k] > 12000.0:
            continue
        for b in range(len(BAND_LABELS)):
            if BAND_EDGES[b] <= freqs[k] < BAND_EDGES[b + 1]:
                bands[b] += acc[k]
                break
    band_share = [100.0 * v / tot for v in bands]
    # Pico tonal: maior bin entre 150 e 4000 Hz, em relacao a mediana da mesma faixa.
    tonal_idx = [k for k in range(1, len(acc)) if 150.0 <= freqs[k] <= 4000.0]
    peak_k = max(tonal_idx, key=lambda k: acc[k])
    med = sorted(acc[k] for k in tonal_idx)[len(tonal_idx) // 2]
    tonal_db = 10.0 * math.log10(acc[peak_k] / med) if med > 0 else 0.0
    return dict(centroid=centroid, rolloff85=rolloff, slope_db_oct=slope_per_oct, flatness_db=flatness_db,
                band_share=band_share, peak_hz=freqs[peak_k], tonal_db=tonal_db, frames=n_frames)


def envelope_stats(x, sr):
    win = max(1, int(0.010 * sr))
    env = []
    for start in range(0, len(x), win):
        seg = x[start:start + win]
        env.append(math.sqrt(sum(v * v for v in seg) / len(seg)))
    peak = max(env)
    peak_i = env.index(peak)
    dt = win / float(sr)

    def first_cross_before(level):
        for i in range(peak_i, -1, -1):
            if env[i] < level:
                return i
        return 0

    def first_cross_after(level):
        for i in range(peak_i, len(env)):
            if env[i] < level:
                return i
        return len(env) - 1

    a10 = first_cross_before(0.10 * peak)
    a90 = peak_i
    for i in range(peak_i, -1, -1):
        if env[i] >= 0.9 * peak:
            a90 = i
            break
    attack_s = (a90 - a10) * dt
    d20_i = first_cross_after(0.10 * peak)
    decay_s = (d20_i - peak_i) * dt
    active = [i for i, v in enumerate(env) if v > 0.01 * peak]
    active_s = (active[-1] - active[0] + 1) * dt if active else 0.0
    tail_n = max(1, int(0.05 * sr / win))
    tail = env[-tail_n:]
    tail_db = 20.0 * math.log10(max(sum(tail) / len(tail), 1e-12) / peak)
    seg_profile = []
    nseg = 10
    for s in range(nseg):
        a = s * len(env) // nseg
        b = max(a + 1, (s + 1) * len(env) // nseg)
        m = sum(env[a:b]) / (b - a)
        seg_profile.append(20.0 * math.log10(max(m, 1e-12) / peak))
    return dict(peak_t=peak_i * dt, attack_s=attack_s, decay20_s=decay_s, active_s=active_s,
                tail_db=tail_db, profile=seg_profile)


def level_stats(x):
    n = len(x)
    rms = math.sqrt(sum(v * v for v in x) / n)
    peak = max(abs(v) for v in x)
    dc = sum(x) / n
    return dict(rms_db=20.0 * math.log10(max(rms, 1e-12)), peak_db=20.0 * math.log10(max(peak, 1e-12)),
                crest_db=20.0 * math.log10(max(peak, 1e-12) / max(rms, 1e-12)), dc=dc,
                first=x[0], last=x[-1])


def analyze(path):
    sr, x = read_wav(path)
    out = dict(sr=sr, samples=len(x), duration_s=len(x) / float(sr))
    out.update(level_stats(x))
    out.update(envelope_stats(x, sr))
    spec = spectral_stats(x, sr)
    out.update(spec or {})
    return out


def fmt_block(name, entry, a):
    alerts = []
    if a["peak_db"] > -1.0:
        alerts.append("CLIPPING")
    if abs(a["dc"]) > 0.005:
        alerts.append("DC %.4f" % a["dc"])
    if entry["role"] in ("inhale", "exhale") and "slope_db_oct" in a and a["slope_db_oct"] > -2.0:
        alerts.append("ESPECTRO QUASE PLANO (tende a ruido branco)")
    lines = []
    lines.append("%s" % name)
    lines.append("  papel %s | variacao %s | duracao %.3f s (%d amostras)" % (
        entry["role"] if entry["family"] is None else "%s %s" % (entry["family"], entry["role"]),
        entry["variation"], a["duration_s"], a["samples"]))
    lines.append("  nivel: RMS %6.2f dBFS | pico %6.2f dBFS | crista %5.2f dB | DC %+.5f" % (
        a["rms_db"], a["peak_db"], a["crest_db"], a["dc"]))
    lines.append("  envelope: pico em %.3f s | ataque 10-90%% %.3f s | queda ate -20 dB %.3f s | ativo (>-40 dB) %.3f s | "
                 "cauda 50 ms %6.1f dB rel. pico" % (a["peak_t"], a["attack_s"], a["decay20_s"], a["active_s"], a["tail_db"]))
    lines.append("  perfil 10 segmentos (dB rel. pico): " + " ".join("%6.1f" % v for v in a["profile"]))
    if "centroid" in a:
        lines.append("  espectro: centroide %6.0f Hz | rolloff85 %6.0f Hz | inclinacao %6.2f dB/oitava | planura %6.2f dB"
                     % (a["centroid"], a["rolloff85"] or 0.0, a["slope_db_oct"], a["flatness_db"]))
        lines.append("  energia por faixa (%): " + " | ".join("%s %5.1f" % (lbl, s)
                                                       for lbl, s in zip(BAND_LABELS, a["band_share"])))
        lines.append("  pico tonal 150-4000 Hz: %6.0f Hz (%5.1f dB sobre a mediana da faixa)" % (a["peak_hz"], a["tonal_db"]))
    lines.append("  alertas: " + (", ".join(alerts) if alerts else "nenhum"))
    return lines, alerts


def reference_rows():
    """Ruido branco e rosa gerados pelo mesmo gerador e medidos por esta mesma analise: a escala de referencia."""
    sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
    import body_synth as bs
    n = 3 * SR_REF
    refs = []
    for label, make in (("ruido branco", lambda r: bs.white(r, n)), ("ruido rosa", lambda r: bs.pink(r, n))):
        x = make(bs.Rng(bs.seed_for("ref_" + label.replace(" ", "_"))))
        x = [v * 0.3 for v in x]
        s = spectral_stats(x, SR_REF)
        refs.append((label, s))
    return refs


SR_REF = 44100


def main(argv=None):
    ap = argparse.ArgumentParser(description="Analise objetiva dos sons do corpo (F2-006a).")
    ap.add_argument("--dir", default=DEFAULT_DIR)
    ap.add_argument("--out", default=DEFAULT_OUT)
    args = ap.parse_args(argv)
    with open(os.path.join(args.dir, "manifest.json"), "r", encoding="ascii") as f:
        manifest = json.load(f)
    results = []
    for entry in manifest["files"]:
        a = analyze(os.path.join(args.dir, entry["file"]))
        results.append((entry, a))
        print("analisado %s" % entry["file"])
    refs = reference_rows()

    out = []
    out.append("ANALISE OBJETIVA - SONS PROCEDURAIS DO CORPO (F2-006a)")
    out.append("Gerador: %s versao %s | semente base %s" % (manifest["generator"], manifest["generator_version"],
                                                       manifest["seed_base"]))
    out.append("Metodo: RMS e pico em dBFS sobre int16; envelope por RMS de 10 ms; espectro = media de janelas Hann de %d "
               "amostras (salto %d) com energia. Inclinacao e planura usam bandas de 1/6 de oitava (150 a 8000 Hz), para "
               "que cada oitava pese o mesmo. Planura: media geometrica / aritmetica das bandas (dB; ruido branco ~ 0 dB)."
               % (FFT_N, HOP))
    out.append("Escuta humana nao foi feita por esta analise; os numeros sao evidencia de forma, nao de qualidade percebida.")
    out.append("")
    out.append("REFERENCIAS (mesmo analisador, ruido de 3 s gerado pelo body_synth)")
    for label, s in refs:
        out.append("  %-14s inclinacao %6.2f dB/oitava | planura %6.2f dB | centroide %6.0f Hz" % (
            label, s["slope_db_oct"], s["flatness_db"], s["centroid"]))
    out.append("  Alerta de respiracao: inclinacao acima de -2,0 dB/oitava (mais plano que o rosa, perto do branco).")
    out.append("")
    out.append("RESUMO POR SOUND_ID (medias das variacoes)")
    out.append("%-16s %-9s %5s %8s %8s %10s %9s %8s" % ("sound_id", "papel", "n", "dur(s)", "RMS", "centroide", "planura", "pico"))
    groups = {}
    for entry, a in results:
        key = (entry["sound_id"], entry["role"] if entry["family"] is None else entry["role"])
        groups.setdefault(key, []).append((entry, a))
    for key in sorted(groups.keys()):
        items = groups[key]
        n = len(items)
        dur = sum(a["duration_s"] for _, a in items) / n
        rms = sum(a["rms_db"] for _, a in items) / n
        cen = sum(a.get("centroid", 0.0) for _, a in items) / n
        flat = sum(a.get("flatness_db", 0.0) for _, a in items) / n
        peak = max(a["peak_db"] for _, a in items)
        out.append("%-16s %-9s %5d %8.3f %8.2f %9.0f %9.2f %8.2f" % (key[0], key[1], n, dur, rms, cen, flat, peak))
    out.append("")
    out.append("ARQUIVOS")
    out.append("")
    alert_count = 0
    for entry, a in results:
        lines, alerts = fmt_block(entry["file"], entry, a)
        alert_count += len(alerts)
        out.extend(lines)
        out.append("")
    out.append("Total de alertas: %d" % alert_count)
    text = "\n".join(out) + "\n"
    os.makedirs(os.path.dirname(os.path.abspath(args.out)), exist_ok=True)
    with open(args.out, "w", encoding="utf-8", newline="\n") as f:
        f.write(text)
    print("gravado: %s" % args.out)
    return 0


if __name__ == "__main__":
    sys.exit(main())

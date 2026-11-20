#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""DEAD BREATH - verificador de determinismo dos sons procedurais (F2-006a).

Gera de novo todos os sons do corpo em diretorios temporarios (um por execucao), calcula o
SHA-256 de cada arquivo e compara com:
  - os arquivos commitados em game/content/audio/body/ (bytes e hash);
  - o sha256 registrado em manifest.json para cada WAV;
  - as outras execucoes entre si.
Sai com 0 somente se tudo for identico bit a bit. Os diretorios temporarios sao apagados ao fim.

Uso:
    python tools/audio/check_regen.py [--target DIR] [--runs N]
"""

import argparse
import json
import os
import shutil
import sys
import tempfile
import time

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import body_synth as bs  # noqa: E402


def list_names(folder):
    return sorted(n for n in os.listdir(folder) if n.endswith(".wav") or n == "manifest.json")


def main(argv=None):
    ap = argparse.ArgumentParser(description="Regera os sons do corpo e compara os hashes (F2-006a).")
    ap.add_argument("--target", default=bs.DEFAULT_OUT, help="pasta commitada (padrao: game/content/audio/body)")
    ap.add_argument("--runs", type=int, default=2, help="numero de geracoes independentes (padrao: 2)")
    args = ap.parse_args(argv)
    target = os.path.abspath(args.target)

    committed_names = list_names(target)
    committed_hash = {}
    for name in committed_names:
        committed_hash[name] = bs.sha256_file(os.path.join(target, name))
    print("pasta commitada: %s" % target)
    print("arquivos commitados: %d (WAV + manifest.json)" % len(committed_names))

    with open(os.path.join(target, "manifest.json"), "r", encoding="ascii") as f:
        manifest = json.load(f)
    ok = True
    manifest_problems = []
    for entry in manifest["files"]:
        if committed_hash.get(entry["file"]) != entry["sha256"]:
            manifest_problems.append(entry["file"])
    if manifest_problems:
        ok = False
        print("ERRO: sha256 do manifest difere do arquivo commitado: %s" % ", ".join(manifest_problems))
    else:
        print("manifest.json: sha256 de todos os WAV conferem com os arquivos commitados")

    run_hashes = []
    for run in range(1, args.runs + 1):
        tmp = tempfile.mkdtemp(prefix="deadbreath_regen_")
        try:
            t0 = time.time()
            bs.generate(tmp, verbose=False)
            elapsed = time.time() - t0
            names = list_names(tmp)
            hashes = dict((n, bs.sha256_file(os.path.join(tmp, n))) for n in names)
            run_hashes.append(hashes)
            print("execucao %d: %d arquivos gerados em %.1f s (pasta temporaria apagada ao fim)" % (run, len(names), elapsed))
            if names != committed_names:
                ok = False
                print("  ERRO: conjunto de arquivos difere: faltam %s, sobram %s" % (
                    sorted(set(committed_names) - set(names)), sorted(set(names) - set(committed_names))))
            diffs = [n for n in names if n in committed_hash and hashes[n] != committed_hash[n]]
            if diffs:
                ok = False
                print("  DIFERENTES do commitado: %s" % ", ".join(diffs))
            else:
                print("  identicos ao commitado (bytes): %d/%d" % (len(names), len(committed_names)))
        finally:
            shutil.rmtree(tmp, ignore_errors=True)

    if len(run_hashes) > 1:
        first = run_hashes[0]
        for k, other in enumerate(run_hashes[1:], start=2):
            mismatched = [n for n in first if other.get(n) != first[n]]
            if mismatched:
                ok = False
                print("ERRO: execucao 1 e execucao %d diferem: %s" % (k, ", ".join(mismatched)))
            else:
                print("execucao 1 e execucao %d: identicas (%d arquivos)" % (k, len(other)))

    print("")
    print("SHA-256 (arquivos commitados):")
    for name in committed_names:
        print("  %s  %s" % (committed_hash[name], name))
    print("")
    print("RESULTADO: %s" % ("PASS - geracao deterministica, bit a bit" if ok else "FAIL"))
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())

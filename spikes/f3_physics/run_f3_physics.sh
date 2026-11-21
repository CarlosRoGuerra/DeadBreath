#!/usr/bin/env bash
# F3-005 (RSK-13): roda o spike de corpos dinâmicos em Jolt Physics e GodotPhysics3D e grava em Docs/QA/EVIDENCE/.
# Uso (Git Bash, na raiz do repositório): bash spikes/f3_physics/run_f3_physics.sh [caminho/do/godot_console.exe]
set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd -W)"
GODOT="${1:-$(head -n 1 "$ROOT/tools/godot_path.txt" 2>/dev/null)}"
P="$ROOT/spikes/f3_physics"
E="$ROOT/Docs/QA/EVIDENCE"
mkdir -p "$E"
[ -x "$GODOT" ] || { echo "Godot não encontrado: '$GODOT'"; exit 2; }
cd "$P" || exit 2
# Compilação antes de tudo: erro de script deixa o motor pendurado (sem quit), então aborta aqui.
timeout 60 "$GODOT" --headless --path "$P" --check-only --script res://dyn_runner.gd > "$E/F3-005_physics_compile.log" 2>&1
if grep -q "Parse Error\|Compile Error" "$E/F3-005_physics_compile.log"; then echo "falha de compilação (ver F3-005_physics_compile.log)"; exit 3; fi
# F3_WINDOWED=1 roda com janela (o monitor de física só mede o passo fora de headless); o sufixo separa a evidência.
MODE="--headless"; SUF=""
if [ "${F3_WINDOWED:-0}" = "1" ]; then MODE=""; SUF="_windowed"; fi
for eng in "Jolt Physics" "GodotPhysics3D"; do
  tag="$(echo "$eng" | tr -d ' ')"
  printf '[physics]\n3d/physics_engine="%s"\n' "$eng" > override.cfg
  timeout 900 "$GODOT" $MODE --fixed-fps 60 --path "$P" --script res://physics_dyn_main.gd -- "--out=$E/F3-005_physics_$tag$SUF.json" > "$E/F3-005_physics_$tag$SUF.log" 2>&1
  echo "$eng exit=$?"
done
rm -f override.cfg
grep -h "F3005" "$E"/F3-005_physics_*$SUF.log

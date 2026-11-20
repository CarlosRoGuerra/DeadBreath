#!/usr/bin/env bash
# DISC-003: reexecuta o spike V1–V6 e grava a evidência em Docs/QA/EVIDENCE/DISC-003/.
# Uso (Git Bash, na raiz do repositório): bash spikes/disc003/run_spike.sh [caminho/do/godot_console.exe]
# V3 e V5 abrem uma janela (renderização real); não rode em sessão sem desktop.
set -u
# pwd -W (Git Bash) devolve o caminho no formato do Windows (D:/...), que o Godot aceita.
ROOT="$(cd "$(dirname "$0")/../.." && pwd -W)"
GODOT="${1:-$(head -n 1 "$ROOT/tools/godot_path.txt" 2>/dev/null)}"
P="$ROOT/spikes/disc003"
E="$ROOT/Docs/QA/EVIDENCE/DISC-003"
mkdir -p "$E"
[ -x "$GODOT" ] || { echo "Godot não encontrado: '$GODOT'"; exit 2; }

{
  echo "== V1 =="; "$GODOT" --version; echo "exit=$?"
  echo "== V2 =="
  "$GODOT" --headless --path "$P" --script res://v2_exit.gd -- pass 2>&1; echo "exit=$? (esperado 0)"
  "$GODOT" --headless --path "$P" --script res://v2_exit.gd -- fail 2>&1; echo "exit=$? (esperado 1)"
  echo "== V4 =="
  "$GODOT" --headless --path "$P/v4" --import > /dev/null 2>&1; echo "import exit=$?"
  for f in ok parse_error untyped unsafe; do
    "$GODOT" --headless --path "$P/v4" --check-only --script "res://$f.gd" 2>&1; echo "$f exit=$? (esperado: ok=0, demais=1)"
  done
} > "$E/V1_V2_V4.log" 2>&1

"$GODOT" --path "$P" --resolution 1920x1080 --script res://render_main.gd -- --mode=shot "--out=$E" > "$E/V3_default.log" 2>&1
for drv in vulkan d3d12; do
  "$GODOT" --path "$P" --rendering-driver "$drv" --resolution 1920x1080 --script res://render_main.gd -- --mode=bench "--out=$E" > "$E/V5_$drv.log" 2>&1
done

cd "$P" || exit 2
for eng in "Jolt Physics" "GodotPhysics3D"; do
  tag="$(echo "$eng" | tr -d ' ')"
  printf '[physics]\n3d/physics_engine="%s"\n' "$eng" > override.cfg
  "$GODOT" --headless --fixed-fps 60 --path "$P" --script res://physics_main.gd -- "--out=$E/V6_$tag.json" > "$E/V6_$tag.log" 2>&1
  echo "V6 $eng exit=$?"
done
rm -f override.cfg
grep -h -E "exit=|V3 screenshot|V5 frames|ALL_PASS" "$E"/V1_V2_V4.log "$E"/V3_default.log "$E"/V5_*.log "$E"/V6_[JG]*.log

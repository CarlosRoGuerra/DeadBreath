# F4-007: medicao de desempenho da IA (SYSTEM_ARCHITECTURE secao 13).
# Roda o harness (game/tests/perf/perf_main.gd) 3 vezes com 1 inimigo e 3 vezes com 3 inimigos, headless,
# 60 ticks/s fixos, e grava a saida em Docs/QA/EVIDENCE/F4-007_perf.txt.
# Uso: powershell -NoProfile -ExecutionPolicy Bypass -File tools/perf/run_perf.ps1

$Root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
. (Join-Path $Root 'tools\godot.ps1') -LoadOnly
$Godot = Get-GodotPath
$GamePath = Join-Path $Root 'game'
$Out = Join-Path $Root 'Docs\QA\EVIDENCE\F4-007_perf.txt'

$lines = @()
$lines += "F4-007 medicao de desempenho - $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
$lines += "Godot: $Godot"
foreach ($enemies in @(1, 3)) {
    foreach ($run in 1..3) {
        $output = & $Godot --headless --fixed-fps 60 --path $GamePath -s 'res://tests/perf/perf_main.gd' '--' "--inimigos=$enemies" "--run=$run" 2>&1
        $lines += ($output | Where-Object { "$_" -match '^PERF' } | ForEach-Object { "$_" })
    }
}
$lines | Out-File -FilePath $Out -Encoding utf8
$lines

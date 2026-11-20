# DEAD BREATH - audicao dos sons procedurais do corpo (F2-006a).
# Toca cada WAV de game/content/audio/body (ou de -Dir), na ordem do manifest.json, com o nome
# e os metadados na tela. Usa o player nativo do Windows (System.Media.SoundPlayer).
#
# Uso:
#   powershell -ExecutionPolicy Bypass -File tools\audio\audition.ps1
#   powershell -ExecutionPolicy Bypass -File tools\audio\audition.ps1 -Filter cough
#   powershell -ExecutionPolicy Bypass -File tools\audio\audition.ps1 -Filter breath_calm -Pause 1.5
#   powershell -ExecutionPolicy Bypass -File tools\audio\audition.ps1 -ListOnly
#
# -Filter  : trecho do nome do arquivo ou do sound_id (padrao: todos)
# -Pause   : segundos de silencio entre dois sons (padrao: 0.8)
# -ListOnly: so mostra a lista, sem tocar nada
# Ctrl+C interrompe a audicao a qualquer momento.
#
# Arquivo mantido em ASCII: o Windows PowerShell 5.1 le UTF-8 sem BOM como ANSI.

[CmdletBinding()]
param(
    [string]$Dir = '',
    [string]$Filter = '',
    [double]$Pause = 0.8,
    [switch]$ListOnly
)

$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($Dir)) {
    $repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
    $Dir = Join-Path $repoRoot 'game\content\audio\body'
}

$manifestPath = Join-Path $Dir 'manifest.json'
if (-not (Test-Path -LiteralPath $manifestPath)) {
    throw "manifest.json nao encontrado em '$Dir'. Gere os sons com: python tools\audio\body_synth.py"
}

$manifest = Get-Content -LiteralPath $manifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
$items = @($manifest.files)

if (-not [string]::IsNullOrWhiteSpace($Filter)) {
    $pattern = '*' + $Filter + '*'
    $items = @($items | Where-Object { ($_.file -like $pattern) -or ($_.sound_id -like $pattern) })
}

if ($items.Count -eq 0) {
    Write-Host "Nenhum som corresponde ao filtro '$Filter'."
    exit 1
}

$total = $items.Count
$index = 0
Write-Host ''
Write-Host "Audicao DEAD BREATH - sons do corpo ($total arquivo(s))"
Write-Host "Pasta: $Dir"
if ($ListOnly) { Write-Host '(modo -ListOnly: nada sera tocado)' }

foreach ($item in $items) {
    $index++
    $path = Join-Path $Dir $item.file
    $duration = [double]$item.duration_s
    $line = '[{0}/{1}] {2}   sound_id={3}   papel={4}   variacao={5}   duracao={6:N3} s' -f `
        $index, $total, $item.file, $item.sound_id, $item.role, $item.variation, $duration
    Write-Host ''
    Write-Host $line -ForegroundColor Cyan

    if ($ListOnly) { continue }

    if (-not (Test-Path -LiteralPath $path)) {
        Write-Host "  ARQUIVO AUSENTE: $path" -ForegroundColor Red
        continue
    }

    $player = New-Object System.Media.SoundPlayer $path
    try {
        $player.Load()
        $player.PlaySync()
    } finally {
        $player.Dispose()
    }

    if ($Pause -gt 0) {
        Start-Sleep -Milliseconds ([int][math]::Round($Pause * 1000))
    }
}

Write-Host ''
Write-Host 'Fim da audicao.'

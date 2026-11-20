# DEAD BREATH - simulacao de balanceamento headless (F2-008).
#
# Roda tools/balance/balance_sim.gd com o Godot (modelos L1 da fisiologia, semente fixa) e grava um CSV por
# cenario e um resumo. Com -Determinism, roda uma segunda vez em outra pasta e compara o SHA-256 de cada arquivo:
# execucoes com a mesma semente e as mesmas entradas devem gerar arquivos identicos.
#
# Uso:
#   tools\balance\run_balance.ps1                       (grava em Docs\QA\EVIDENCE, prefixo F2-008_)
#   tools\balance\run_balance.ps1 -OutDir <pasta> -Determinism
#   tools\balance\run_balance.ps1 -ConfigDir user://balance   (usa as configs exportadas pelo painel F4)
#
# Caminho do Godot: tools/godot_path.txt ou DEADBREATH_GODOT_PATH (via tools/godot.ps1).
# Sai com 0 se gravou (e, com -Determinism, se os arquivos batem); 1 caso contrario.
#
# Arquivo mantido em ASCII: o Windows PowerShell 5.1 le UTF-8 sem BOM como ANSI.

param(
    [string]$OutDir = '',
    [string]$ConfigDir = '',
    [string]$Prefix = 'F2-008_',
    [switch]$Determinism
)

$ErrorActionPreference = 'Continue'
$RepoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$GamePath = Join-Path $RepoRoot 'game'
$ToolPath = (Join-Path $PSScriptRoot 'balance_sim.gd') -replace '\\', '/'

. (Join-Path $RepoRoot 'tools\godot.ps1') -LoadOnly
try {
    $Godot = Get-GodotPath
} catch {
    Write-Host ('[run_balance] ERRO: ' + $_.Exception.Message)
    exit 1
}

if ($OutDir -eq '') {
    $OutDir = Join-Path $RepoRoot 'Docs\QA\EVIDENCE'
}

function Invoke-Sim {
    param([string]$Target)
    $simArgs = @('--headless', '--path', $GamePath, '-s', $ToolPath, '--', ('--out=' + $Target), ('--prefix=' + $Prefix))
    if ($ConfigDir -ne '') {
        $simArgs += ('--config=' + $ConfigDir)
    }
    Write-Host ('Comando: "' + $Godot + '" ' + ($simArgs -join ' '))
    & $Godot @simArgs | Out-Host
    return [int]$LASTEXITCODE
}

$code = Invoke-Sim -Target $OutDir
if ($code -ne 0) {
    Write-Host ('[run_balance] FALHOU: codigo ' + $code)
    exit 1
}
Write-Host ('[run_balance] gravado em ' + $OutDir)

if (-not $Determinism) {
    exit 0
}

$second = Join-Path ([System.IO.Path]::GetTempPath()) ('balance_run2_' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $second | Out-Null
$code2 = Invoke-Sim -Target $second
if ($code2 -ne 0) {
    Write-Host ('[run_balance] FALHOU na segunda execucao: codigo ' + $code2)
    exit 1
}

$files = @(Get-ChildItem -LiteralPath $OutDir -Filter ($Prefix + '*') -File)
$same = 0
$diff = 0
foreach ($file in $files) {
    $other = Join-Path $second $file.Name
    if (-not (Test-Path -LiteralPath $other)) {
        $diff++
        Write-Host ('  ausente na segunda execucao: ' + $file.Name)
        continue
    }
    $h1 = (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash
    $h2 = (Get-FileHash -LiteralPath $other -Algorithm SHA256).Hash
    if ($h1 -eq $h2) {
        $same++
    } else {
        $diff++
        Write-Host ('  DIFERENTE: ' + $file.Name)
    }
}
Remove-Item -LiteralPath $second -Recurse -Force
Write-Host ('[run_balance] determinismo: ' + $same + ' arquivo(s) identico(s), ' + $diff + ' diferente(s)')
if ($diff -eq 0 -and $same -gt 0) {
    Write-Host 'RESULTADO DETERMINISMO: APROVADO'
    exit 0
}
Write-Host 'RESULTADO DETERMINISMO: REPROVADO'
exit 1

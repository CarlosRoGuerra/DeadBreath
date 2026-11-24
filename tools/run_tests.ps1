# DEAD BREATH - pipeline de testes (F1-005; contrato em Docs/QA/TEST_PLAN.md, secao 4).
#
# Etapas, na ordem:
#   1. importacao  : godot --headless --path game --import
#   2. arc04       : parse e compilacao de todos os scripts de game/ (ARC-04), num processo
#   3. runner          : godot --headless --fixed-fps 60 --path game -s res://tests/run_all.gd
#                        (unit, integration, scenarios, architecture; alvo: menos de 10 s)
#   4. runner-property : o mesmo runner com -- --level=property (varreduras longas e deterministicas)
#   5. runner-meta     : o mesmo runner com -- --level=meta (meta-testes do proprio runner)
#
# Uma etapa falha se o codigo de saida for diferente de 0 ou se "SCRIPT ERROR" aparecer na saida
# (erro de script em tempo de execucao, erro de parse ou aviso tratado como erro).
# Linhas "ERROR:" do engine sao exibidas e contadas, mas nao reprovam a etapa.
# Sai com 0 se todas as etapas passarem; 1 caso contrario.
#
# Uso:   tools\run_tests.ps1
# Caminho do Godot: tools/godot_path.txt ou DEADBREATH_GODOT_PATH (via tools/godot.ps1).
#
# Arquivo mantido em ASCII: o Windows PowerShell 5.1 le UTF-8 sem BOM como ANSI.

$ErrorActionPreference = 'Continue'
$RepoRoot = Split-Path -Parent $PSScriptRoot
$GamePath = Join-Path $RepoRoot 'game'
$AnsiPattern = ([string][char]27) + '\[[0-9;]*m'
$PipelineTimer = [System.Diagnostics.Stopwatch]::StartNew()

. (Join-Path $PSScriptRoot 'godot.ps1') -LoadOnly
try {
    $Godot = Get-GodotPath
} catch {
    Write-Host ('[run_tests] ERRO: ' + $_.Exception.Message)
    exit 1
}

$StepResults = New-Object System.Collections.ArrayList

function Invoke-Step {
    param(
        [string]$Name,
        [string[]]$Arguments
    )
    $commandLine = '"' + $Godot + '" ' + ($Arguments -join ' ')
    Write-Host ''
    Write-Host ('=== Etapa [' + $Name + '] ===')
    Write-Host ('Comando: ' + $commandLine)

    $timer = [System.Diagnostics.Stopwatch]::StartNew()
    $raw = @(& $Godot @Arguments 2>&1 | ForEach-Object { $_.ToString() })
    $exitCode = $LASTEXITCODE
    $timer.Stop()

    $lines = @()
    foreach ($line in $raw) {
        $lines += ($line -replace $AnsiPattern, '')
    }
    foreach ($line in $lines) {
        Write-Host $line
    }

    $scriptErrors = @($lines | Where-Object { $_ -cmatch 'SCRIPT ERROR' })
    $engineErrors = @($lines | Where-Object { $_ -cmatch '^\s*ERROR:' })
    $passed = ($exitCode -eq 0) -and ($scriptErrors.Count -eq 0)
    $label = 'FALHOU'
    if ($passed) { $label = 'OK' }
    Write-Host ('--- Etapa [' + $Name + ']: codigo=' + $exitCode + ' SCRIPT_ERROR=' + $scriptErrors.Count + ' ERROR_engine=' + $engineErrors.Count + ' tempo_ms=' + $timer.ElapsedMilliseconds + ' -> ' + $label)

    [void]$StepResults.Add([pscustomobject]@{
        Name         = $Name
        Code         = $exitCode
        ScriptErrors = $scriptErrors.Count
        EngineErrors = $engineErrors.Count
        Ms           = $timer.ElapsedMilliseconds
        Passed       = $passed
    })
    return [bool]$passed
}

Write-Host ('Godot: ' + $Godot)
Write-Host ('Projeto: ' + $GamePath)

$ok1 = Invoke-Step -Name 'importacao' -Arguments @('--headless', '--path', $GamePath, '--import')
$ok2 = Invoke-Step -Name 'arc04' -Arguments @('--headless', '--fixed-fps', '60', '--path', $GamePath, '-s', 'res://tests/run_all.gd', '--', '--level=arc04')
$ok3 = Invoke-Step -Name 'runner' -Arguments @('--headless', '--fixed-fps', '60', '--path', $GamePath, '-s', 'res://tests/run_all.gd')
$ok4 = Invoke-Step -Name 'runner-property' -Arguments @('--headless', '--fixed-fps', '60', '--path', $GamePath, '-s', 'res://tests/run_all.gd', '--', '--level=property')
$ok5 = Invoke-Step -Name 'runner-meta' -Arguments @('--headless', '--fixed-fps', '60', '--path', $GamePath, '-s', 'res://tests/run_all.gd', '--', '--level=meta')
$allOk = $ok1 -and $ok2 -and $ok3 -and $ok4 -and $ok5

Write-Host ''
Write-Host '=== Resumo do pipeline ==='
foreach ($result in $StepResults) {
    $resultLabel = 'FALHOU'
    if ($result.Passed) { $resultLabel = 'OK' }
    Write-Host ('  {0,-12} codigo={1,-4} SCRIPT_ERROR={2} ERROR_engine={3} tempo_ms={4,7}  {5}' -f $result.Name, $result.Code, $result.ScriptErrors, $result.EngineErrors, $result.Ms, $resultLabel)
}
Write-Host ('Tempo total do pipeline: ' + [math]::Round($PipelineTimer.Elapsed.TotalSeconds, 2) + ' s')

if ($allOk) {
    Write-Host 'RESULTADO DO PIPELINE: APROVADO (codigo de saida 0)'
    exit 0
}
Write-Host 'RESULTADO DO PIPELINE: REPROVADO (codigo de saida 1)'
exit 1

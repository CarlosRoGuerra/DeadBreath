# DEAD BREATH - wrapper do Godot (F1-002).
# Le o caminho de tools/godot_path.txt (ou da variavel DEADBREATH_GODOT_PATH),
# confere que o executavel existe e que a versao e 4.7.2.stable, e repassa os
# argumentos. Sai com o codigo de saida do Godot, ou 2 se o caminho/versao falhar.
#
# Uso:   tools/godot.ps1 --version
#        tools/godot.ps1 --headless --path game --import
# Em outro script:  . tools/godot.ps1 -LoadOnly ; $exe = Get-GodotPath
#
# ATENCAO: o PowerShell remove o "--" nu ao chamar um .ps1. Para passar argumentos
# de usuario ao Godot pelo wrapper, use '--' entre aspas:
#        tools/godot.ps1 --headless --path game -s res://tests/run_all.gd '--' --filter=x
# Em scripts, prefira a chamada nativa:  & (Get-GodotPath) ... -- --filter=x
#
# Arquivo mantido em ASCII: o Windows PowerShell 5.1 le UTF-8 sem BOM como ANSI.

$ExpectedVersionPrefix = '4.7.2.stable'

function Get-GodotPath {
    $path = $env:DEADBREATH_GODOT_PATH
    if ([string]::IsNullOrWhiteSpace($path)) {
        $cfg = Join-Path $PSScriptRoot 'godot_path.txt'
        if (-not (Test-Path -LiteralPath $cfg)) {
            throw "godot_path.txt nao encontrado em '$cfg'."
        }
        $path = (Get-Content -LiteralPath $cfg -TotalCount 1).Trim()
    }
    if ([string]::IsNullOrWhiteSpace($path)) {
        throw 'Caminho do Godot vazio (tools/godot_path.txt ou DEADBREATH_GODOT_PATH).'
    }
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        throw "Executavel do Godot nao encontrado: '$path'. Corrija tools/godot_path.txt ou DEADBREATH_GODOT_PATH."
    }
    $version = (Get-Item -LiteralPath $path).VersionInfo.ProductVersion
    if ($null -eq $version -or -not $version.StartsWith($ExpectedVersionPrefix)) {
        throw "Versao do Godot inesperada: '$version' em '$path'. Esperado: $ExpectedVersionPrefix (ENGINE_DECISION)."
    }
    return $path
}

if ($args.Count -ge 1 -and $args[0] -eq '-LoadOnly') {
    return
}

try {
    $godot = Get-GodotPath
} catch {
    [Console]::Error.WriteLine("[godot.ps1] ERRO: $($_.Exception.Message)")
    exit 2
}

& $godot @args
exit $LASTEXITCODE

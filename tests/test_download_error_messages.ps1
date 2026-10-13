$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
$tokens = $null
$parseErrors = $null
$ast = [System.Management.Automation.Language.Parser]::ParseFile(
    (Join-Path $repoRoot 'AppleMusic-Auto-Enrich-Import.ps1'), [ref]$tokens, [ref]$parseErrors)
if ($parseErrors.Count) { throw 'Main script has parse errors.' }
foreach ($name in @('Decode-Utf8', 'Get-DownloadFailureMessage', 'Download-VideoUrls')) {
    $definition = $ast.Find({ param($node)
        $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq $name
    }, $true)
    . ([scriptblock]::Create($definition.Extent.Text))
}
function Write-Log { param([string]$Text) $script:LastDownloadLog = $Text }
function Run-Python {
    param([string]$Code, [string[]]$PyArgs)
    @{files=@(); errors=@($script:TerminalFailure)} | ConvertTo-Json |
        Set-Content -LiteralPath $PyArgs[1] -Encoding UTF8
    throw 'Could not copy Chrome cookie database; earlier recovered failure'
}
$Script:LogFile = 'test-download.log'
foreach ($case in @(
    @{ Error='[SSL: UNEXPECTED_EOF_WHILE_READING] EOF occurred in violation of protocol'; Expected='HTTPS' },
    @{ Error='HTTP Error 403: Forbidden'; Expected='HTTP 403' },
    @{ Error='Video has been removed'; Expected='Video has been removed' }
)) {
    $script:TerminalFailure = $case.Error
    $caught = ''
    try { Download-VideoUrls -Urls @('https://www.bilibili.com/video/BV1334BzCEMo') | Out-Null }
    catch { $caught = $_.Exception.Message }
    if (-not $caught.Contains($case.Expected)) { throw "Wrong final error: $caught" }
    if (-not $caught.Contains($Script:LogFile)) { throw 'Log location missing.' }
    if (-not $script:LastDownloadLog.Contains($case.Error)) { throw 'Terminal error was not logged.' }
}
Write-Output 'Download terminal error message regression tests passed.'

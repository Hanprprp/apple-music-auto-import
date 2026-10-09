param(
    [string]$OutputPath
)

$ErrorActionPreference = "Stop"
$repoRoot = [System.IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
if ([string]::IsNullOrWhiteSpace($OutputPath)) {
    $OutputPath = Join-Path $repoRoot "release\AppleMusicAutoImportPortable.zip"
}
$OutputPath = [System.IO.Path]::GetFullPath($OutputPath)

$packageFiles = @(
    "AppleMusic-Auto-Enrich-Import.ps1",
    "Start-AppleMusic-Auto-Import.vbs",
    "Check-Environment.vbs",
    "requirements.txt",
    "README.md",
    "README.zh-CN.md",
    "RELEASE_NOTES.md",
    "LICENSE"
)

foreach ($file in $packageFiles) {
    $source = Join-Path $repoRoot $file
    if (-not (Test-Path -LiteralPath $source -PathType Leaf)) {
        throw "Missing package file: $file"
    }
}

$tempRoot = [System.IO.Path]::GetFullPath([System.IO.Path]::GetTempPath())
$stage = [System.IO.Path]::GetFullPath((Join-Path $tempRoot ("apple-music-auto-import-package-" + [guid]::NewGuid().ToString("N"))))
if (-not $stage.StartsWith($tempRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw "Unsafe staging path: $stage"
}

try {
    New-Item -ItemType Directory -Path $stage -Force | Out-Null
    foreach ($file in $packageFiles) {
        Copy-Item -LiteralPath (Join-Path $repoRoot $file) -Destination (Join-Path $stage $file)
    }

    $outputDirectory = Split-Path -Parent $OutputPath
    New-Item -ItemType Directory -Path $outputDirectory -Force | Out-Null
    if (Test-Path -LiteralPath $OutputPath) {
        Remove-Item -LiteralPath $OutputPath -Force
    }
    Compress-Archive -Path (Join-Path $stage "*") -DestinationPath $OutputPath -CompressionLevel Optimal

    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $archive = [System.IO.Compression.ZipFile]::OpenRead($OutputPath)
    try {
        $entries = @($archive.Entries | ForEach-Object { $_.FullName.Replace("\", "/") })
    }
    finally {
        $archive.Dispose()
    }

    $unexpected = @($entries | Where-Object {
        $_ -match '(^|/)(python|tests)(/|$)' -or
        $_ -match '\.(log|config\.json)$'
    })
    if ($unexpected.Count -gt 0) {
        throw "Unexpected private/runtime content in package: $($unexpected -join ', ')"
    }
    foreach ($file in $packageFiles) {
        if ($entries -notcontains $file) {
            throw "Package validation failed; missing: $file"
        }
    }

    [PSCustomObject]@{
        OutputPath = $OutputPath
        SizeBytes = (Get-Item -LiteralPath $OutputPath).Length
        Entries = $entries
    }
}
finally {
    if ((Test-Path -LiteralPath $stage) -and $stage.StartsWith($tempRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
        Remove-Item -LiteralPath $stage -Recurse -Force
    }
}

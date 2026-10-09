param(
    [Parameter(Mandatory = $true)][string]$ScriptPath,
    [Parameter(Mandatory = $true)][string]$AudioPath,
    [Parameter(Mandatory = $true)][string]$PythonPath,
    [Parameter(Mandatory = $true)][string]$ExpectedTitle,
    [Parameter(Mandatory = $true)][string]$ExpectedArtist,
    [string]$ExpectedComposer = "",
    [string]$ExpectedLyricist = "",
    [string]$ExpectedArranger = "",
    [switch]$ForceCacheRestore
)

$ErrorActionPreference = "Stop"
$raw = Get-Content -LiteralPath $ScriptPath -Raw -Encoding UTF8
$marker = '$processor = @'''
$markerIndex = $raw.IndexOf($marker)
if ($markerIndex -lt 0) {
    throw "Embedded processor marker not found."
}
$prefix = $raw.Substring(0, $markerIndex)
$processorStart = $markerIndex + $marker.Length
$processorEnd = $raw.IndexOf("`n'@", $processorStart)
if ($processorEnd -lt 0) {
    throw "Embedded processor terminator not found."
}
$env:AM_REAL_PREVIEW_AUDIO = [System.IO.Path]::GetFullPath($AudioPath)
$env:AM_REAL_PREVIEW_PYTHON = [System.IO.Path]::GetFullPath($PythonPath)
$env:AM_REAL_PREVIEW_TITLE = $ExpectedTitle
$env:AM_REAL_PREVIEW_ARTIST = $ExpectedArtist
$env:AM_REAL_PREVIEW_FORCE_CACHE = if ($ForceCacheRestore) { "1" } else { "0" }
$processor = $raw.Substring($processorStart, $processorEnd - $processorStart)

$testBody = @'
function Resolve-Python {
    return $env:AM_REAL_PREVIEW_PYTHON
}

$utf8 = New-Object System.Text.UTF8Encoding($false)
$OutputEncoding = $utf8
[Console]::OutputEncoding = $utf8
$hint = "title: $env:AM_REAL_PREVIEW_TITLE`r`nartist: $env:AM_REAL_PREVIEW_ARTIST"
$previewArgs = @(
    $env:AM_REAL_PREVIEW_AUDIO,
    $hint,
    "",
    "",
    "__NO_COVER_ARTIST__",
    "--preview-full",
    "--fast-probe",
    "__AUTO_COVER_DETECT__"
)
$preview = (Run-Python -Code $processor -PyArgs $previewArgs) | ConvertFrom-Json
if ($env:AM_REAL_PREVIEW_FORCE_CACHE -eq "1") {
    $preview.lyrics = ""
    $preview.composer = ""
    $preview.lyricist = ""
    $preview.arranger = ""
}

Add-Type -AssemblyName System.Windows.Forms | Out-Null
$script:InspectedPreview = $null
$timer = New-Object System.Windows.Forms.Timer
$timer.Interval = 200
$timer.Add_Tick({
    $form = @([System.Windows.Forms.Application]::OpenForms) |
        Where-Object { $_.Text -like "*0.3.0-rc.23" } |
        Select-Object -First 1
    if (-not $form) {
        return
    }
    $split = @($form.Controls) |
        Where-Object { $_ -is [System.Windows.Forms.SplitContainer] } |
        Select-Object -First 1
    $read = {
        param([string]$Name)
        $box = @($split.Panel2.Controls.Find("preview_" + $Name, $true)) | Select-Object -First 1
        if ($box) { return [string]$box.Text }
        return ""
    }
    $script:InspectedPreview = [PSCustomObject]@{
        WindowTitle = $form.Text
        Title = (& $read "title")
        Artist = (& $read "artist")
        Composer = (& $read "composer")
        Lyricist = (& $read "lyricist")
        Arranger = (& $read "arranger")
        Lyrics = (& $read "lyrics")
    }
    $timer.Stop()
    $form.Close()
})

$timer.Start()
$null = Show-MetadataPreview -FileName ([System.IO.Path]::GetFileName($env:AM_REAL_PREVIEW_AUDIO)) -Metadata $preview
$timer.Dispose()
if (-not $script:InspectedPreview) {
    throw "The rc.23 preview window could not be inspected."
}
$script:InspectedPreview
'@

try {
    $inspected = & ([scriptblock]::Create($prefix + [Environment]::NewLine + $testBody))
    $normalize = {
        param([string]$Value)
        Add-Type -AssemblyName Microsoft.VisualBasic | Out-Null
        $simplified = [Microsoft.VisualBasic.Strings]::StrConv($Value, [Microsoft.VisualBasic.VbStrConv]::SimplifiedChinese, 0x0804)
        return [regex]::Replace($simplified.ToLowerInvariant(), "[^\p{L}\p{Nd}]", "")
    }
    if ((& $normalize $inspected.Title) -ne (& $normalize $ExpectedTitle) -or (& $normalize $inspected.Artist) -ne (& $normalize $ExpectedArtist)) {
        throw "The real preview identity '$($inspected.Title)' - '$($inspected.Artist)' does not match '$ExpectedTitle' - '$ExpectedArtist'."
    }
    if ([string]::IsNullOrWhiteSpace($inspected.Lyrics)) {
        throw "The real preview lyric box is blank."
    }
    foreach ($field in @("Composer", "Lyricist", "Arranger")) {
        $expected = [string](Get-Variable -Name ("Expected" + $field) -ValueOnly)
        if ($expected -and (& $normalize ([string]$inspected.$field)) -ne (& $normalize $expected)) {
            throw "The real preview $field field is '$($inspected.$field)', expected '$expected'."
        }
    }
    [PSCustomObject]@{
        WindowTitle = $inspected.WindowTitle
        Title = $inspected.Title
        Artist = $inspected.Artist
        Composer = $inspected.Composer
        Lyricist = $inspected.Lyricist
        Arranger = $inspected.Arranger
        LyricsChars = $inspected.Lyrics.Length
        LyricsLines = @($inspected.Lyrics -split "`r`n|`r|`n").Count
    } | ConvertTo-Json -Depth 3
}
finally {
    Remove-Item Env:AM_REAL_PREVIEW_AUDIO -ErrorAction SilentlyContinue
    Remove-Item Env:AM_REAL_PREVIEW_PYTHON -ErrorAction SilentlyContinue
    Remove-Item Env:AM_REAL_PREVIEW_TITLE -ErrorAction SilentlyContinue
    Remove-Item Env:AM_REAL_PREVIEW_ARTIST -ErrorAction SilentlyContinue
    Remove-Item Env:AM_REAL_PREVIEW_FORCE_CACHE -ErrorAction SilentlyContinue
}

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$scriptPath = Join-Path $repoRoot "AppleMusic-Auto-Enrich-Import.ps1"
$raw = Get-Content -LiteralPath $scriptPath -Raw -Encoding UTF8
$marker = '$processor = @'''
$prefix = $raw.Substring(0, $raw.IndexOf($marker))

$testBody = @'
Add-Type -AssemblyName System.Windows.Forms | Out-Null
$script:PreviewLayout = $null
$timer = New-Object System.Windows.Forms.Timer
$timer.Interval = 200
$timer.Add_Tick({
    $previewTitle = Decode-Utf8 "5a+85YWl5YmN5a6M5pW06aKE6KeI"
    $previewForm = @([System.Windows.Forms.Application]::OpenForms) |
        Where-Object { $_.Text.StartsWith($previewTitle, [System.StringComparison]::Ordinal) } |
        Select-Object -First 1
    if (-not $previewForm) {
        return
    }
    $split = @($previewForm.Controls) |
        Where-Object { $_ -is [System.Windows.Forms.SplitContainer] } |
        Select-Object -First 1
    $note = @($previewForm.Controls) |
        Where-Object { $_ -is [System.Windows.Forms.Label] -and $_.Dock -eq [System.Windows.Forms.DockStyle]::Top } |
        Select-Object -First 1
    $titleBox = @($split.Panel2.Controls.Find("preview_title", $true)) | Select-Object -First 1
    $albumBox = @($split.Panel2.Controls.Find("preview_album", $true)) | Select-Object -First 1
    $lyricsBox = @($split.Panel2.Controls.Find("preview_lyrics", $true)) | Select-Object -First 1
    $script:PreviewLayout = [PSCustomObject]@{
        SplitTop = $split.Top
        NoteBottom = $note.Bottom
        TitleTop = $titleBox.Top
        AlbumTop = $albumBox.Top
        TitleText = $titleBox.Text
        LyricsLineCount = @($lyricsBox.Lines).Count
        LyricsText = $lyricsBox.Text
    }
    $timer.Stop()
    $previewForm.Close()
})

$metadata = [PSCustomObject]@{
    title = "Editable Song"
    artist = "Current Singer"
    album = "Official Album"
    album_artist = "Original Singer"
    year = "2001"
    release_date = "2001-01-01"
    genre = "Pop"
    composer = ""
    lyricist = ""
    arranger = ""
    track_number = "1"
    track_count = "10"
    disc_number = "1"
    disc_count = "1"
    isrc = ""
    musicbrainz_recording_id = ""
    lyrics = "First lyric line`nSecond lyric line"
    artwork_url = ""
    artwork_data = ""
    artwork_mime = ""
    original_artist = ""
    original_album = ""
    source = "Layout regression test"
}

$timer.Start()
$null = Show-MetadataPreview -FileName "test.m4a" -Metadata $metadata
$timer.Dispose()

if (-not $script:PreviewLayout) {
    throw "Preview form layout could not be inspected."
}
if ($script:PreviewLayout.SplitTop -lt $script:PreviewLayout.NoteBottom) {
    throw "The preview content is hidden behind the top instruction bar."
}
if ($script:PreviewLayout.TitleTop -ge $script:PreviewLayout.AlbumTop) {
    throw "The editable song-title row is not above the album row."
}
if ($script:PreviewLayout.TitleText -ne "Editable Song") {
    throw "The editable song-title value is missing from the preview."
}
if ($script:PreviewLayout.LyricsLineCount -ne 2) {
    throw "The preview collapsed lyric line breaks."
}
if ($script:PreviewLayout.LyricsText -ne ("First lyric line" + [Environment]::NewLine + "Second lyric line")) {
    throw "The preview did not normalize lyric line breaks for WinForms."
}
Write-Output "Metadata preview layout regression test passed."
'@

& ([scriptblock]::Create($prefix + [Environment]::NewLine + $testBody))

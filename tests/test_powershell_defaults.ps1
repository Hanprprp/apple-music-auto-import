$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$scriptPath = Join-Path $repoRoot "AppleMusic-Auto-Enrich-Import.ps1"
$raw = Get-Content -LiteralPath $scriptPath -Raw -Encoding UTF8
$marker = '$processor = @'''
$prefix = $raw.Substring(0, $raw.IndexOf($marker))
$tempRoot = Join-Path $env:TEMP ("am-defaults-test-" + [guid]::NewGuid().ToString("N"))
$env:AM_DEFAULTS_TEST_TEMP = $tempRoot
$oldStateRoot = [string]$env:APPLE_MUSIC_AUTO_IMPORT_STATE_ROOT
$env:APPLE_MUSIC_AUTO_IMPORT_STATE_ROOT = Join-Path $tempRoot "state"

$testBody = @'
$tempRoot = $env:AM_DEFAULTS_TEST_TEMP
New-Item -ItemType Directory -Path $tempRoot -Force | Out-Null
$D = { param([string]$Value) Decode-Utf8 $Value }

$cacheDir = Join-Path $Script:StateRoot "lyrics-cache"
New-Item -ItemType Directory -Path $cacheDir -Force | Out-Null
$cacheRecord = [PSCustomObject]@{
    title = (& $D "57a75pS+")
    artist = (& $D "6YSt5r2k5r6k")
    lyrics = "First cached lyric`nSecond cached lyric"
    composer = (& $D "6YOR5ram5rO9")
    lyricist = (& $D "6YOR5ram5rO9")
    arranger = "Leezidi"
}
[System.IO.File]::WriteAllText(
    (Join-Path $cacheDir "matching.json"),
    ($cacheRecord | ConvertTo-Json),
    [System.Text.UTF8Encoding]::new($false)
)
$previewRecord = [PSCustomObject]@{
    title = (& $D "57u95pS+")
    artist = (& $D "6YOR5ram5rO9")
    album_artist = (& $D "6YOR5ram5rO9")
    original_artist = ""
    lyrics = ""
    composer = ""
    lyricist = ""
    arranger = ""
}
$previewRecord = Restore-PreviewLyricsFromCache -Metadata $previewRecord
if ($previewRecord.lyrics -notmatch "First cached lyric" -or $previewRecord.lyricist -ne (& $D "6YOR5ram5rO9") -or $previewRecord.arranger -ne "Leezidi") {
    throw "The PowerShell preview fallback did not restore matching cached lyrics and credits."
}
$wrongArtist = $previewRecord.PSObject.Copy()
$wrongArtist.artist = "Different Artist"
$wrongArtist.album_artist = "Different Artist"
$wrongArtist.lyrics = ""
$wrongArtist.composer = ""
$wrongArtist.lyricist = ""
$wrongArtist.arranger = ""
$wrongArtist = Restore-PreviewLyricsFromCache -Metadata $wrongArtist
if (-not [string]::IsNullOrWhiteSpace([string]$wrongArtist.lyrics)) {
    throw "The PowerShell preview fallback crossed artists for an identical title."
}

$coverFile = Join-Path $tempRoot "cover.webm"
$coverInfo = @{
    title = (& $D "5pu55qC8R2FyeS3pu5HoibLlub3pu5g=")
    fulltitle = (& $D "5pu55qC8R2FyeS3pu5HoibLlub3pu5g=")
    description = (& $D "5pu55qC8R2FyeS3pu5HoibLlub3pu5g=")
    channel = "uploader"
}
[System.IO.File]::WriteAllText(
    "$coverFile.aminfo.json",
    ($coverInfo | ConvertTo-Json),
    [System.Text.UTF8Encoding]::new($false)
)
$cover = Get-TrackDefaultsFromVideoInfo -AudioFile $coverFile
if ($cover.Title -or $cover.Artist -or $cover.IsLive) {
    throw "An unlabelled hyphen pair must not determine artist/title direction."
}

$officialFile = Join-Path $tempRoot "official.webm"
$officialInfo = @{
    title = (& $D "5ZGo5p2w5YCrIEpheSBDaG9144CQ6buR6Imy5bm96buYIERhcmsgSHVtb3LjgJEtT2ZmaWNpYWwgTXVzaWMgVmlkZW8=")
    fulltitle = (& $D "5ZGo5p2w5YCrIEpheSBDaG9144CQ6buR6Imy5bm96buYIERhcmsgSHVtb3LjgJEtT2ZmaWNpYWwgTXVzaWMgVmlkZW8=")
    description = (& $D "5puyOiDlkajmnbDlgKsgLyDoqZ46IOWRqOadsOWAqw==")
    channel = (& $D "5ZGo5p2w5YCrIEpheSBDaG91")
}
[System.IO.File]::WriteAllText(
    "$officialFile.aminfo.json",
    ($officialInfo | ConvertTo-Json),
    [System.Text.UTF8Encoding]::new($false)
)
$official = Get-TrackDefaultsFromVideoInfo -AudioFile $officialFile
if ($official.Title -ne (& $D "6buR6Imy5bm96buY") -or $official.Artist -ne (& $D "5ZGo5p2w5YCr") -or $official.IsLive) {
    throw "Official video title defaults were parsed incorrectly."
}
if ($official.Extra -notmatch [regex]::Escape((& $D "5L2c6K+NOiDlkajmnbDlgKs=")) -or $official.Extra -notmatch [regex]::Escape((& $D "5L2c5puyOiDlkajmnbDlgKs="))) {
    throw "Slash-separated credits were parsed incorrectly."
}

$showFile = Join-Path $tempRoot "attributed-show.webm"
$showInfo = @{
    title = (& $D "6IG95rW3LeabueagvEDpgLHml6Xni4LnhrHlpJw=")
    fulltitle = (& $D "6IG95rW3LeabueagvEDpgLHml6Xni4LnhrHlpJw=")
    description = (& $D "6YCx5pel54uC54ax5aSc")
    channel = "Fooly Cooly"
}
[System.IO.File]::WriteAllText(
    "$showFile.aminfo.json",
    ($showInfo | ConvertTo-Json),
    [System.Text.UTF8Encoding]::new($false)
)
$show = Get-TrackDefaultsFromVideoInfo -AudioFile $showFile
if ($show.Title -ne (& $D "6IG95rW3") -or $show.Artist -ne (& $D "5pu55qC8")) {
    throw "Song-performer-at-show title defaults were parsed incorrectly."
}
if ($show.IsCover -or -not [string]::IsNullOrWhiteSpace($show.CoverArtist) -or -not $show.IsLive) {
    throw "Attributed show performance should defer the cover decision to metadata comparison."
}

$collaborationFile = Join-Path $tempRoot "collaboration.webm"
$collaborationInfo = @{
    title = (& $D "5Yi75Zyo5oiR5b+D5bqV55qE5ZCN5a2XIOaxpOS7pOWxsSZUeXNvbiBZb3NoaQ==")
    fulltitle = (& $D "5Yi75Zyo5oiR5b+D5bqV55qE5ZCN5a2XIOaxpOS7pOWxsSZUeXNvbiBZb3NoaQ==")
    description = ""
    channel = "uploader"
}
[System.IO.File]::WriteAllText("$collaborationFile.aminfo.json", ($collaborationInfo | ConvertTo-Json), [System.Text.UTF8Encoding]::new($false))
$collaboration = Get-TrackDefaultsFromVideoInfo -AudioFile $collaborationFile
if ($collaboration.Title -ne (& $D "5Yi75Zyo5oiR5b+D5bqV55qE5ZCN5a2X") -or $collaboration.Artist -ne (& $D "5rGk5Luk5bGxJlR5c29uIFlvc2hp")) {
    throw "Trailing collaboration performers were not separated from the song title."
}

$qualityBookFile = Join-Path $tempRoot "quality-book.webm"
$qualityBookInfo = @{
    title = (& $D "44CQNEvpobbnuqfkv67lpI3jgJHlkajmnbDkvKbjgIrmib7oh6rlt7HjgItMaXZlIDIwMDJUaGUgT25l5ryU5ZSx5Lya546w5Zy677yB")
    fulltitle = (& $D "44CQNEvpobbnuqfkv67lpI3jgJHlkajmnbDkvKbjgIrmib7oh6rlt7HjgItMaXZlIDIwMDJUaGUgT25l5ryU5ZSx5Lya546w5Zy677yB")
    description = ""
    channel = "uploader"
}
[System.IO.File]::WriteAllText("$qualityBookFile.aminfo.json", ($qualityBookInfo | ConvertTo-Json), [System.Text.UTF8Encoding]::new($false))
$qualityBook = Get-TrackDefaultsFromVideoInfo -AudioFile $qualityBookFile
if ($qualityBook.Title -ne (& $D "5om+6Ieq5bex") -or $qualityBook.Artist -ne (& $D "5ZGo5p2w5Lym") -or -not $qualityBook.IsLive) {
    throw "Quality-prefix book-title performance defaults were parsed incorrectly."
}

$postTitleArtistFile = Join-Path $tempRoot "post-title-artist.m4a"
$postTitleArtistInfo = @{
    title = (& $D "44CQ8J2Qh/CdkKIt8J2QkfCdkJ7wnZCs5peg5o2f6Z+z6LSo44CR772c44CK556s44CLLSDpg5Hmtqbms70gLeKAmOivtOi/h+imgeS4gOi1t+eci+eahOa1tyAg546w5Zyo5oiR54us6Ieq562J5b6F4oCZ")
    fulltitle = (& $D "44CQ8J2Qh/CdkKIt8J2QkfCdkJ7wnZCs5peg5o2f6Z+z6LSo44CR772c44CK556s44CLLSDpg5Hmtqbms70gLeKAmOivtOi/h+imgeS4gOi1t+eci+eahOa1tyAg546w5Zyo5oiR54us6Ieq562J5b6F4oCZ")
    description = ""
    uploader = "uploader"
}
[System.IO.File]::WriteAllText("$postTitleArtistFile.aminfo.json", ($postTitleArtistInfo | ConvertTo-Json), [System.Text.UTF8Encoding]::new($false))
$postTitleArtist = Get-TrackDefaultsFromVideoInfo -AudioFile $postTitleArtistFile
if ($postTitleArtist.Title -ne (& $D "556s") -or $postTitleArtist.Artist -ne (& $D "6YOR5ram5rO9") -or $postTitleArtist.IsLive) {
    throw "Artist after a book-title song name was not parsed correctly."
}

$simplifiedLiveFile = Join-Path $tempRoot "simplified-live.webm"
$simplifiedLiveInfo = @{
    title = (& $D "44CQ6auY5riF44CRIOmZtuWWhuOAiumjnuacuuWcuueahOWNgeeCueWNiuOAi+WPsuS4iuacgOW8uueOsOWcuueJiA==")
    fulltitle = (& $D "44CQ6auY5riF44CRIOmZtuWWhuOAiumjnuacuuWcuueahOWNgeeCueWNiuOAi+WPsuS4iuacgOW8uueOsOWcuueJiA==")
    description = ""
    channel = "uploader"
}
[System.IO.File]::WriteAllText("$simplifiedLiveFile.aminfo.json", ($simplifiedLiveInfo | ConvertTo-Json), [System.Text.UTF8Encoding]::new($false))
$simplifiedLive = Get-TrackDefaultsFromVideoInfo -AudioFile $simplifiedLiveFile
if ($simplifiedLive.Title -ne (& $D "6aOe5py65Zy655qE5Y2B54K55Y2K") -or $simplifiedLive.Artist -ne (& $D "6Zm25ZaG") -or -not $simplifiedLive.IsLive) {
    throw "Simplified-Chinese live performance defaults were parsed incorrectly."
}

$namedCoverFile = Join-Path $tempRoot "named-cover.webm"
$namedCoverInfo = @{
    title = (& $D "5rGk5Luk5bGx57+75ZSx44CK6JC95Y+25b2S5qC544CL6Ie05pWs5Lyg5aWH5q2M5omL546L5Yqb5a6P")
    fulltitle = (& $D "5rGk5Luk5bGx57+75ZSx44CK6JC95Y+25b2S5qC544CL6Ie05pWs5Lyg5aWH5q2M5omL546L5Yqb5a6P")
    description = ""
    channel = "uploader"
}
[System.IO.File]::WriteAllText("$namedCoverFile.aminfo.json", ($namedCoverInfo | ConvertTo-Json), [System.Text.UTF8Encoding]::new($false))
$namedCover = Get-TrackDefaultsFromVideoInfo -AudioFile $namedCoverFile
if ($namedCover.Title -ne (& $D "6JC95Y+25b2S5qC5") -or $namedCover.Artist -ne (& $D "5rGk5Luk5bGx")) {
    throw "Named cover performer marker was not removed from the artist."
}

$tourFile = Join-Path $tempRoot "tour-context.webm"
$tourInfo = @{
    title = (& $D "44CQ5Lyg5LiW57uP5YW444CR44CQ55av54uC5Y+Y6LCD44CR5ZGo5p2w5Lym5LiW55WM5beh5Zue5ryU5ZSx5Lya6aaZ5riv56uZMTIwNeOAiuWuiemdmeOAi+eOsOWcuueJiOmfs+mrmOa1i+mHj+WPiue7n+iuoQ==")
    fulltitle = (& $D "44CQ5Lyg5LiW57uP5YW444CR44CQ55av54uC5Y+Y6LCD44CR5ZGo5p2w5Lym5LiW55WM5beh5Zue5ryU5ZSx5Lya6aaZ5riv56uZMTIwNeOAiuWuiemdmeOAi+eOsOWcuueJiOmfs+mrmOa1i+mHj+WPiue7n+iuoQ==")
    description = (& $D "MTIwNeWuiemdmg==")
    uploader = "uploader"
    upload_date = "20240406"
}
[System.IO.File]::WriteAllText("$tourFile.aminfo.json", ($tourInfo | ConvertTo-Json), [System.Text.UTF8Encoding]::new($false))
$tour = Get-TrackDefaultsFromVideoInfo -AudioFile $tourFile
if ($tour.Title -ne (& $D "5a6J6Z2Z") -or $tour.Artist -ne (& $D "5ZGo5p2w5Lym") -or -not $tour.IsLive) {
    throw "Tour and venue context must not become part of the performer name."
}
if (-not [string]::IsNullOrWhiteSpace($tour.Year)) {
    throw "Tour upload year must not be used as the song release year."
}

$uploadFile = Join-Path $tempRoot "plain-upload.webm"
$uploadInfo = @{
    title = "A Song - Cover Singer"
    release_year = 2026
    release_date = "20260303"
    upload_date = "20260303"
    artist = ""
    track = ""
    album = ""
}
[System.IO.File]::WriteAllText(
    "$uploadFile.aminfo.json",
    ($uploadInfo | ConvertTo-Json),
    [System.Text.UTF8Encoding]::new($false)
)
$upload = Get-TrackDefaultsFromVideoInfo -AudioFile $uploadFile
if (-not [string]::IsNullOrWhiteSpace($upload.Year)) {
    throw "YouTube upload year must not be used as the song release year."
}
'@

try {
    & ([scriptblock]::Create($prefix + [Environment]::NewLine + $testBody))
    Write-Output "PowerShell defaults regression tests passed."
}
finally {
    Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item Env:AM_DEFAULTS_TEST_TEMP -ErrorAction SilentlyContinue
    if ([string]::IsNullOrWhiteSpace($oldStateRoot)) {
        Remove-Item Env:APPLE_MUSIC_AUTO_IMPORT_STATE_ROOT -ErrorAction SilentlyContinue
    }
    else {
        $env:APPLE_MUSIC_AUTO_IMPORT_STATE_ROOT = $oldStateRoot
    }
}

param(
    [string[]]$PrefetchUrls,
    [string]$PrefetchResultFile,
    [switch]$PrefetchPlaylistMode,
    [int]$PrefetchMaxPlaylistItems = 0,
    [switch]$SelfTest,
    [switch]$SelfTestJson,
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$InputFiles
)

$ErrorActionPreference = "Stop"
$Script:AppVersion = "0.3.0"
$requestedStateRoot = [string]$env:APPLE_MUSIC_AUTO_IMPORT_STATE_ROOT
if ([string]::IsNullOrWhiteSpace($requestedStateRoot)) {
    $userProfileRoot = [Environment]::GetFolderPath("UserProfile")
    if (-not [string]::IsNullOrWhiteSpace($userProfileRoot)) {
        # LocalAppData is virtualized when launched by packaged desktop apps.
        # A profile-root folder resolves identically from Explorer and Codex.
        $requestedStateRoot = Join-Path $userProfileRoot ".apple-music-auto-import"
    }
    else {
        $requestedStateRoot = Join-Path ([Environment]::GetFolderPath("LocalApplicationData")) "AppleMusicAutoImport"
    }
}
$Script:StateRoot = [System.IO.Path]::GetFullPath($requestedStateRoot)
try {
    New-Item -ItemType Directory -Path $Script:StateRoot -Force | Out-Null
}
catch {
    $Script:StateRoot = $PSScriptRoot
}

if ([string]::IsNullOrWhiteSpace([string]$env:APPLE_MUSIC_AUTO_IMPORT_STATE_ROOT)) {
    $legacyStateRoots = New-Object System.Collections.Generic.List[string]
    $localAppDataRoot = [Environment]::GetFolderPath("LocalApplicationData")
    if (-not [string]::IsNullOrWhiteSpace($localAppDataRoot)) {
        $legacyStateRoots.Add((Join-Path $localAppDataRoot "AppleMusicAutoImport"))
        $packagesRoot = Join-Path $localAppDataRoot "Packages"
        if (Test-Path -LiteralPath $packagesRoot -PathType Container) {
            Get-ChildItem -LiteralPath $packagesRoot -Directory -Filter "OpenAI.Codex_*" -ErrorAction SilentlyContinue | ForEach-Object {
                $legacyStateRoots.Add((Join-Path $_.FullName "LocalCache\Local\AppleMusicAutoImport"))
            }
        }
    }
    foreach ($legacyRoot in @($legacyStateRoots | Select-Object -Unique)) {
        try {
            $legacyFullPath = [System.IO.Path]::GetFullPath($legacyRoot)
            if ($legacyFullPath.Equals($Script:StateRoot, [System.StringComparison]::OrdinalIgnoreCase) -or -not (Test-Path -LiteralPath $legacyFullPath -PathType Container)) {
                continue
            }
            $legacyConfig = Join-Path $legacyFullPath "AppleMusic-Auto-Enrich-Import.config.json"
            $newConfig = Join-Path $Script:StateRoot "AppleMusic-Auto-Enrich-Import.config.json"
            if ((Test-Path -LiteralPath $legacyConfig -PathType Leaf) -and -not (Test-Path -LiteralPath $newConfig -PathType Leaf)) {
                Copy-Item -LiteralPath $legacyConfig -Destination $newConfig -Force
            }
            $legacyCache = Join-Path $legacyFullPath "lyrics-cache"
            $newCache = Join-Path $Script:StateRoot "lyrics-cache"
            if (Test-Path -LiteralPath $legacyCache -PathType Container) {
                New-Item -ItemType Directory -Path $newCache -Force | Out-Null
                Get-ChildItem -LiteralPath $legacyCache -File -Filter "*.json" -ErrorAction SilentlyContinue | ForEach-Object {
                    $destination = Join-Path $newCache $_.Name
                    if (-not (Test-Path -LiteralPath $destination -PathType Leaf) -or $_.LastWriteTimeUtc -gt (Get-Item -LiteralPath $destination).LastWriteTimeUtc) {
                        Copy-Item -LiteralPath $_.FullName -Destination $destination -Force
                    }
                }
            }
        }
        catch {
            # A legacy cache is optional; the new state directory remains usable.
        }
    }
}
$env:APPLE_MUSIC_AUTO_IMPORT_STATE_ROOT = $Script:StateRoot
$Script:LogFile = Join-Path $Script:StateRoot "AppleMusic-Auto-Enrich-Import.log"

function Write-Log {
    param([string]$Text)
    try {
        $stamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        Add-Content -LiteralPath $Script:LogFile -Value "[$stamp] $Text" -Encoding UTF8
    }
    catch {
        try {
            $fallbackLog = Join-Path $env:TEMP "AppleMusic-Auto-Enrich-Import-emergency.log"
            Add-Content -LiteralPath $fallbackLog -Value "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] $Text`r`nLog target failed: $Script:LogFile" -Encoding UTF8
        }
        catch {
            # Logging must never prevent an import.
        }
    }
}

function Decode-Utf8 {
    param([string]$B64)
    return [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($B64))
}

function Show-Message {
    param([string]$Text, [string]$Title = "Apple Music Auto Import")
    Add-Type -AssemblyName System.Windows.Forms | Out-Null
    [System.Windows.Forms.MessageBox]::Show($Text, $Title, "OK", "Information") | Out-Null
}

function Ask-Text {
    param([string]$Prompt, [string]$Default = "")
    Add-Type -AssemblyName Microsoft.VisualBasic | Out-Null
    return [Microsoft.VisualBasic.Interaction]::InputBox($Prompt, "Apple Music Auto Import", $Default)
}

function Ask-Confirm {
    param([string]$Text, [string]$Title = "Apple Music Auto Import")
    Add-Type -AssemblyName System.Windows.Forms | Out-Null
    return [System.Windows.Forms.MessageBox]::Show($Text, $Title, "YesNoCancel", "Question")
}

function Ask-TrackInfo {
    param(
        [string]$FileName,
        [string]$DefaultSongTitle = "",
        [string]$DefaultArtist = "",
        [string]$DefaultAlbum = "",
        [string]$DefaultYear = "",
        [string]$DefaultExtra = "",
        [bool]$DefaultLive = $false,
        [bool]$DefaultCover = $false,
        [string]$DefaultCoverArtist = "",
        [string]$Message = ""
    )

    Add-Type -AssemblyName System.Windows.Forms | Out-Null
    Add-Type -AssemblyName System.Drawing | Out-Null
    $D = { param([string]$B64) Decode-Utf8 $B64 }

    $form = New-Object System.Windows.Forms.Form
    $form.Text = (& $D "5aGr5YaZ5q2M5puy5L+h5oGv")
    $form.StartPosition = "CenterScreen"
    $form.FormBorderStyle = "FixedDialog"
    $form.MaximizeBox = $false
    $form.MinimizeBox = $false
    $form.ClientSize = New-Object System.Drawing.Size(560, 470)

    $font = New-Object System.Drawing.Font("Microsoft YaHei UI", 9)
    $form.Font = $font

    $note = New-Object System.Windows.Forms.Label
    $note.AutoSize = $false
    $note.Location = New-Object System.Drawing.Point(18, 14)
    $note.Size = New-Object System.Drawing.Size(520, 38)
    $note.Text = if ([string]::IsNullOrWhiteSpace($Message)) { (& $D "5LiA5qyh5aGr5a6M77yb5LiN56Gu5a6a55qE5Y+v5Lul55WZ56m677yM6K+G5Yir6ZSZ5LqG54K54oCc5ZCm4oCd5Lya5Zue5Yiw6L+Z6YeM5L+u5pS544CC") } else { $Message }
    $form.Controls.Add($note)

    $fileLabel = New-Object System.Windows.Forms.Label
    $fileLabel.AutoSize = $false
    $fileLabel.Location = New-Object System.Drawing.Point(18, 54)
    $fileLabel.Size = New-Object System.Drawing.Size(520, 22)
    $fileLabel.Text = (& $D "5paH5Lu277ya") + $FileName
    $form.Controls.Add($fileLabel)

    function Add-Label {
        param([string]$Text, [int]$Y)
        $label = New-Object System.Windows.Forms.Label
        $label.AutoSize = $false
        $label.Location = New-Object System.Drawing.Point(20, $Y)
        $label.Size = New-Object System.Drawing.Size(140, 24)
        $label.Text = $Text
        $form.Controls.Add($label)
        return $label
    }

    function Add-TextBox {
        param([string]$Text, [int]$Y, [int]$Height = 25, [bool]$Multiline = $false)
        $box = New-Object System.Windows.Forms.TextBox
        $box.Location = New-Object System.Drawing.Point(168, $Y)
        $box.Size = New-Object System.Drawing.Size(370, $Height)
        $box.Text = $Text
        $box.ImeMode = [System.Windows.Forms.ImeMode]::On
        $box.Multiline = $Multiline
        if ($Multiline) {
            $box.ScrollBars = "Vertical"
        }
        $form.Controls.Add($box)
        return $box
    }

    Add-Label (& $D "5q2M5ZCN") 90 | Out-Null
    $titleBox = Add-TextBox $DefaultSongTitle 88
    Add-Label (& $D "5q2M5omLIC8g5b2T5YmN5ryU5ZSx6ICF") 128 | Out-Null
    $artistBox = Add-TextBox $DefaultArtist 126
    Add-Label (& $D "5LiT6L6R5ZCN77yI5Y+v6YCJ77yJ") 166 | Out-Null
    $albumBox = Add-TextBox $DefaultAlbum 164
    Add-Label (& $D "5bm05Lu977yI5Y+v6YCJ77yJ") 204 | Out-Null
    $yearBox = Add-TextBox $DefaultYear 202
    Add-Label (& $D "5YW25LuW57q/57Si77yI6K+t6KiA44CB55S15b2xL+eUteinhuWJp+OAgeW5s+WPsOWQjeetie+8iQ==") 244 | Out-Null
    $extraBox = Add-TextBox $DefaultExtra 242 60 $true

    $liveBox = New-Object System.Windows.Forms.CheckBox
    $liveBox.Location = New-Object System.Drawing.Point(168, 318)
    $liveBox.Size = New-Object System.Drawing.Size(180, 24)
    $liveBox.Text = (& $D "6L+Z5pivIExpdmUgLyDnjrDlnLrniYg=")
    $liveBox.Checked = $DefaultLive
    $form.Controls.Add($liveBox)

    $coverBox = New-Object System.Windows.Forms.CheckBox
    $coverBox.Location = New-Object System.Drawing.Point(168, 348)
    $coverBox.Size = New-Object System.Drawing.Size(180, 24)
    $coverBox.Text = (& $D "6L+Z5piv57+75ZSx54mI")
    $coverBox.Checked = $DefaultCover
    $form.Controls.Add($coverBox)

    Add-Label (& $D "57+75ZSx6ICFIC8g5b2T5YmN5ryU5ZSx6ICF") 386 | Out-Null
    $coverArtistBox = Add-TextBox $DefaultCoverArtist 384
    $coverArtistBox.Enabled = $coverBox.Checked
    $coverBox.Add_CheckedChanged({
        $coverArtistBox.Enabled = $coverBox.Checked
        if ($coverBox.Checked -and [string]::IsNullOrWhiteSpace($coverArtistBox.Text)) {
            $coverArtistBox.Text = $artistBox.Text
        }
    })

    $okButton = New-Object System.Windows.Forms.Button
    $okButton.Location = New-Object System.Drawing.Point(338, 430)
    $okButton.Size = New-Object System.Drawing.Size(90, 28)
    $okButton.Text = (& $D "56Gu5a6a")
    $form.Controls.Add($okButton)

    $cancelButton = New-Object System.Windows.Forms.Button
    $cancelButton.Location = New-Object System.Drawing.Point(448, 430)
    $cancelButton.Size = New-Object System.Drawing.Size(90, 28)
    $cancelButton.Text = (& $D "5Y+W5raI")
    $cancelButton.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
    $form.Controls.Add($cancelButton)
    $form.CancelButton = $cancelButton

    $result = $null
    $okButton.Add_Click({
        if ([string]::IsNullOrWhiteSpace($titleBox.Text)) {
            [System.Windows.Forms.MessageBox]::Show((& $D "5q2M5ZCN5LiN6IO95Li656m644CC"), $form.Text, "OK", "Warning") | Out-Null
            $titleBox.Focus()
            return
        }
        $script:AskTrackInfoResult = [PSCustomObject]@{
            Cancelled = $false
            SongTitle = $titleBox.Text.Trim()
            ArtistName = $artistBox.Text.Trim()
            AlbumName = $albumBox.Text.Trim()
            YearText = $yearBox.Text.Trim()
            ExtraText = $extraBox.Text.Trim()
            IsLive = [bool]$liveBox.Checked
            UseLiveLyrics = $false
            IsCover = [bool]$coverBox.Checked
            CoverArtist = $coverArtistBox.Text.Trim()
        }
        $form.DialogResult = [System.Windows.Forms.DialogResult]::OK
        $form.Close()
    })

    $titleBox.Select()
    $dialogResult = $form.ShowDialog()
    if ($dialogResult -ne [System.Windows.Forms.DialogResult]::OK -or -not $script:AskTrackInfoResult) {
        return [PSCustomObject]@{ Cancelled = $true }
    }
    $result = $script:AskTrackInfoResult
    $script:AskTrackInfoResult = $null
    return $result
}

function ConvertFrom-PreviewImageBase64 {
    param([string]$Data)
    if ([string]::IsNullOrWhiteSpace($Data)) {
        return $null
    }
    try {
        $bytes = [System.Convert]::FromBase64String($Data)
        $stream = [System.IO.MemoryStream]::new($bytes, $false)
        try {
            $loaded = [System.Drawing.Image]::FromStream($stream)
            try {
                return [System.Drawing.Bitmap]::new($loaded)
            }
            finally {
                $loaded.Dispose()
            }
        }
        finally {
            $stream.Dispose()
        }
    }
    catch {
        return $null
    }
}

function Copy-PreviewImageFromFile {
    param([string]$Path)
    try {
        $loaded = [System.Drawing.Image]::FromFile($Path)
        try {
            return [System.Drawing.Bitmap]::new($loaded)
        }
        finally {
            $loaded.Dispose()
        }
    }
    catch {
        return $null
    }
}

function Show-MetadataPreview {
    param(
        [string]$FileName,
        [object]$Metadata,
        [bool]$IsLive = $false,
        [bool]$IsCover = $false
    )

    Add-Type -AssemblyName System.Windows.Forms | Out-Null
    Add-Type -AssemblyName System.Drawing | Out-Null
    $lyricsBeforeBoundaryRestore = ([string]$Metadata.lyrics).Length
    try {
        $Metadata = Restore-PreviewLyricsFromCache -Metadata $Metadata
    }
    catch {
        Write-Log ("Preview-boundary lyric restore failed for $($Metadata.title) - $($Metadata.artist): $($_.Exception.Message)")
    }
    Write-Log ("Preview boundary for $($Metadata.title) - $($Metadata.artist): lyrics $lyricsBeforeBoundaryRestore -> $(([string]$Metadata.lyrics).Length); composer=$($Metadata.composer); lyricist=$($Metadata.lyricist); arranger=$($Metadata.arranger)")
    $D = { param([string]$B64) Decode-Utf8 $B64 }

    function Get-PreviewValue {
        param([string]$Name)
        $property = $Metadata.PSObject.Properties[$Name]
        if ($null -eq $property -or $null -eq $property.Value) {
            return ""
        }
        return [string]$property.Value
    }

    function ConvertTo-PreviewMultilineText {
        param([string]$Text)
        if ([string]::IsNullOrEmpty($Text)) {
            return ""
        }
        return [regex]::Replace($Text, "`r`n|`r|`n", [Environment]::NewLine)
    }

    $form = New-Object System.Windows.Forms.Form
    $form.Text = (& $D "5a+85YWl5YmN5a6M5pW06aKE6KeI") + " - " + $Script:AppVersion
    $form.StartPosition = "CenterScreen"
    $form.FormBorderStyle = "Sizable"
    $form.MinimizeBox = $false
    $form.ClientSize = New-Object System.Drawing.Size(1080, 720)
    $form.MinimumSize = New-Object System.Drawing.Size(940, 650)
    $form.Font = New-Object System.Drawing.Font("Microsoft YaHei UI", 9)

    $note = New-Object System.Windows.Forms.Label
    $note.Dock = "Top"
    $note.Height = 43
    $note.Padding = New-Object System.Windows.Forms.Padding(14, 10, 14, 6)
    $note.Text = (& $D "5Lul5LiL5YaF5a655Lya55u05o6l5YaZ5YWlIEFwcGxlIE11c2lj44CC5L+u5pS55ZCO55qE5a2X5q615LyY5YWI77yb5LiN56Gu5a6a5bCx5LiN6KaB5a+85YWl44CC")

    $footer = New-Object System.Windows.Forms.Panel
    $footer.Dock = "Bottom"
    $footer.Height = 52

    $split = New-Object System.Windows.Forms.SplitContainer
    $split.Dock = "Fill"
    $split.FixedPanel = "Panel1"
    $split.SplitterDistance = 292
    $split.Panel1.Padding = New-Object System.Windows.Forms.Padding(12)
    $split.Panel2.Padding = New-Object System.Windows.Forms.Padding(12, 8, 12, 8)
    # WinForms applies docking in reverse z-order. Add the fill control first
    # so the header and footer reserve their space instead of covering it.
    $form.Controls.Add($split)
    $form.Controls.Add($footer)
    $form.Controls.Add($note)

    $fileLabel = New-Object System.Windows.Forms.Label
    $fileLabel.AutoSize = $false
    $fileLabel.Location = New-Object System.Drawing.Point(0, 0)
    $fileLabel.Size = New-Object System.Drawing.Size(266, 42)
    $fileLabel.Text = (& $D "5paH5Lu277ya") + $FileName
    $split.Panel1.Controls.Add($fileLabel)

    $coverBox = New-Object System.Windows.Forms.PictureBox
    $coverBox.Location = New-Object System.Drawing.Point(0, 46)
    $coverBox.Size = New-Object System.Drawing.Size(266, 266)
    $coverBox.SizeMode = "Zoom"
    $coverBox.BackColor = [System.Drawing.Color]::FromArgb(245, 245, 245)
    $coverBox.BorderStyle = "FixedSingle"
    $coverBox.Anchor = "Top, Left, Right"
    $split.Panel1.Controls.Add($coverBox)

    $coverStatus = New-Object System.Windows.Forms.Label
    $coverStatus.AutoSize = $false
    $coverStatus.Location = New-Object System.Drawing.Point(0, 317)
    $coverStatus.Size = New-Object System.Drawing.Size(266, 22)
    $coverStatus.TextAlign = "MiddleCenter"
    $split.Panel1.Controls.Add($coverStatus)

    $replaceCoverButton = New-Object System.Windows.Forms.Button
    $replaceCoverButton.Location = New-Object System.Drawing.Point(0, 346)
    $replaceCoverButton.Size = New-Object System.Drawing.Size(84, 28)
    $replaceCoverButton.Text = (& $D "5pu05o2i5bCB6Z2i")
    $split.Panel1.Controls.Add($replaceCoverButton)

    $removeCoverButton = New-Object System.Windows.Forms.Button
    $removeCoverButton.Location = New-Object System.Drawing.Point(91, 346)
    $removeCoverButton.Size = New-Object System.Drawing.Size(84, 28)
    $removeCoverButton.Text = (& $D "56e76Zmk5bCB6Z2i")
    $split.Panel1.Controls.Add($removeCoverButton)

    $restoreCoverButton = New-Object System.Windows.Forms.Button
    $restoreCoverButton.Location = New-Object System.Drawing.Point(182, 346)
    $restoreCoverButton.Size = New-Object System.Drawing.Size(84, 28)
    $restoreCoverButton.Text = (& $D "5oGi5aSN6K+G5Yir5bCB6Z2i")
    $split.Panel1.Controls.Add($restoreCoverButton)

    $originalLabel = New-Object System.Windows.Forms.Label
    $originalLabel.AutoSize = $false
    $originalLabel.Location = New-Object System.Drawing.Point(0, 392)
    $originalLabel.Size = New-Object System.Drawing.Size(266, 42)
    $originalArtist = Get-PreviewValue "original_artist"
    $originalAlbum = Get-PreviewValue "original_album"
    $originalValue = if ($originalArtist) { $originalArtist + $(if ($originalAlbum) { " / " + $originalAlbum } else { "" }) } else { (& $D "5peg") }
    $originalLabel.Text = (& $D "5Y6f5ZSx6LWE5paZ77ya") + $originalValue
    $split.Panel1.Controls.Add($originalLabel)

    $sourceLabel = New-Object System.Windows.Forms.Label
    $sourceLabel.AutoSize = $false
    $sourceLabel.Location = New-Object System.Drawing.Point(0, 440)
    $sourceLabel.Size = New-Object System.Drawing.Size(266, 22)
    $sourceLabel.Text = (& $D "6K+G5Yir5p2l5rqQ77ya")
    $split.Panel1.Controls.Add($sourceLabel)

    $sourceBox = New-Object System.Windows.Forms.TextBox
    $sourceBox.Location = New-Object System.Drawing.Point(0, 464)
    $sourceBox.Size = New-Object System.Drawing.Size(266, 120)
    $sourceBox.Multiline = $true
    $sourceBox.ScrollBars = "Vertical"
    $sourceBox.ReadOnly = $true
    $sourceBox.TabStop = $false
    $sourceBox.Text = ConvertTo-PreviewMultilineText (Get-PreviewValue "source")
    $sourceBox.Anchor = "Top, Bottom, Left, Right"
    $split.Panel1.Controls.Add($sourceBox)

    $right = $split.Panel2
    $fieldBoxes = @{}
    function Add-PreviewField {
        param([string]$Name, [string]$LabelText, [int]$X, [int]$Y, [int]$Width)
        $label = New-Object System.Windows.Forms.Label
        $label.AutoSize = $false
        $label.Location = [System.Drawing.Point]::new($X, ($Y + 3))
        $label.Size = New-Object System.Drawing.Size(100, 22)
        $label.Text = $LabelText
        $right.Controls.Add($label)
        $box = New-Object System.Windows.Forms.TextBox
        $box.Location = [System.Drawing.Point]::new(($X + 104), $Y)
        $box.Size = New-Object System.Drawing.Size($Width, 25)
        $box.Name = "preview_" + $Name
        $box.Text = Get-PreviewValue $Name
        $box.ImeMode = [System.Windows.Forms.ImeMode]::On
        $box.Anchor = "Top, Left"
        $right.Controls.Add($box)
        $fieldBoxes[$Name] = $box
    }

    Add-PreviewField "title" (& $D "5q2M5puy5ZCN") 0 4 252
    Add-PreviewField "artist" (& $D "5q2M5omLIC8g5b2T5YmN5ryU5ZSx6ICF") 370 4 252
    Add-PreviewField "album" (& $D "5LiT6L6R5ZCN") 0 39 252
    Add-PreviewField "album_artist" (& $D "5LiT6L6R6Im65Lq6") 370 39 252
    Add-PreviewField "year" (& $D "5Y+R6KGM5bm05Lu9") 0 74 252
    Add-PreviewField "genre" (& $D "5rWB5rS+") 370 74 252
    Add-PreviewField "composer" (& $D "5L2c5puy") 0 109 252
    Add-PreviewField "lyricist" (& $D "5L2c6K+N") 370 109 252
    Add-PreviewField "arranger" (& $D "57yW5puy") 0 144 252
    Add-PreviewField "track_number" (& $D "5puy5bqP") 370 144 252
    Add-PreviewField "track_count" (& $D "5oC75puy5pWw") 0 179 252
    Add-PreviewField "disc_number" (& $D "56Kf5bqP") 370 179 252
    Add-PreviewField "disc_count" (& $D "5oC756Kf5pWw") 0 214 252
    Add-PreviewField "release_date" (& $D "5Y+R6KGM5pel5pyf") 370 214 252

    $lyricsLabel = New-Object System.Windows.Forms.Label
    $lyricsLabel.AutoSize = $false
    Add-PreviewField "isrc" "ISRC" 0 249 252
    Add-PreviewField "musicbrainz_recording_id" "MusicBrainz ID" 370 249 252

    $lyricsLabel.Location = New-Object System.Drawing.Point(0, 287)
    $lyricsLabel.Size = New-Object System.Drawing.Size(120, 22)
    $lyricsLabel.Text = (& $D "5q2M6K+N")
    $right.Controls.Add($lyricsLabel)

    $lyricsBox = New-Object System.Windows.Forms.TextBox
    $lyricsBox.Location = New-Object System.Drawing.Point(0, 311)
    $lyricsBox.Size = New-Object System.Drawing.Size(726, 271)
    $lyricsBox.Name = "preview_lyrics"
    $lyricsBox.Multiline = $true
    $lyricsBox.ScrollBars = "Vertical"
    $lyricsBox.AcceptsReturn = $true
    $lyricsBox.ImeMode = [System.Windows.Forms.ImeMode]::On
    $lyricsBox.Text = ConvertTo-PreviewMultilineText (Get-PreviewValue "lyrics")
    $lyricsBox.Anchor = "Top, Bottom, Left, Right"
    $right.Controls.Add($lyricsBox)

    $autoArtworkData = Get-PreviewValue "artwork_data"
    $autoArtworkUrl = Get-PreviewValue "artwork_url"
    $autoArtworkFile = ""
    if (-not [string]::IsNullOrWhiteSpace($autoArtworkData)) {
        try {
            $autoArtworkBytes = [System.Convert]::FromBase64String($autoArtworkData)
            $autoArtworkExtension = if ((Get-PreviewValue "artwork_mime") -match "png") { ".png" } else { ".jpg" }
            $autoArtworkFile = Join-Path $env:TEMP ("am-preview-artwork-" + [guid]::NewGuid().ToString() + $autoArtworkExtension)
            [System.IO.File]::WriteAllBytes($autoArtworkFile, $autoArtworkBytes)
        }
        catch {
            $autoArtworkFile = ""
        }
    }
    $coverState = @{ Mode = "auto"; File = ""; AutoData = $autoArtworkData; AutoFile = $autoArtworkFile }
    $artworkClient = $null
    $setCover = {
        param($Image, [string]$Caption)
        if ($coverBox.Image) {
            $coverBox.Image.Dispose()
        }
        $coverBox.Image = $Image
        $coverStatus.Text = $Caption
    }
    $autoImage = ConvertFrom-PreviewImageBase64 $coverState.AutoData
    if ($autoImage) {
        & $setCover $autoImage (& $D "5bCB6Z2i")
    }
    elseif (-not [string]::IsNullOrWhiteSpace($autoArtworkUrl)) {
        & $setCover $null (& $D "5q2j5Zyo6L295YWl5bCB6Z2iLi4u")
        try {
            $previewArtworkUrl = $autoArtworkUrl -replace '/1200x1200bb\.', '/600x600bb.'
            $artworkClient = New-Object System.Net.WebClient
            $artworkClient.Headers[[System.Net.HttpRequestHeader]::UserAgent] = "CodexAppleMusicAutoImport/1.0"
            $artworkClient.Add_DownloadDataCompleted({
                param($sender, $eventArgs)
                if ($form.IsDisposed -or $coverState.Mode -ne "auto") {
                    return
                }
                if ($eventArgs.Cancelled -or $eventArgs.Error) {
                    & $setCover $null (& $D "5bCB6Z2i6L295YWl5aSx6LSl")
                    return
                }
                try {
                    $bytes = [byte[]]$eventArgs.Result
                    if (-not $bytes -or $bytes.Length -eq 0) {
                        throw "Empty artwork response"
                    }
                    $extension = if ($previewArtworkUrl -match '(?i)\.png(?:\?|$)') { ".png" } else { ".jpg" }
                    $downloadedArtworkFile = Join-Path $env:TEMP ("am-preview-artwork-" + [guid]::NewGuid().ToString() + $extension)
                    [System.IO.File]::WriteAllBytes($downloadedArtworkFile, $bytes)
                    $coverState.AutoData = [System.Convert]::ToBase64String($bytes)
                    $coverState.AutoFile = $downloadedArtworkFile
                    $image = ConvertFrom-PreviewImageBase64 $coverState.AutoData
                    if ($image) {
                        & $setCover $image (& $D "5bCB6Z2i")
                    }
                }
                catch {
                    & $setCover $null (& $D "5bCB6Z2i6L295YWl5aSx6LSl")
                }
            })
            $artworkClient.DownloadDataAsync([uri]$previewArtworkUrl)
        }
        catch {
            & $setCover $null (& $D "5bCB6Z2i6L295YWl5aSx6LSl")
        }
    }
    else {
        & $setCover $null (& $D "5rKh5pyJ5Y+v55So5bCB6Z2i")
    }

    $replaceCoverButton.Add_Click({
        $dialog = New-Object System.Windows.Forms.OpenFileDialog
        $dialog.Title = (& $D "5pu05o2i5LiT6L6R5bCB6Z2i")
        $dialog.Filter = (& $D "5Zu+54mH5paH5Lu2ICgqLmpwZzsqLmpwZWc7Ki5wbmcpfCouanBnOyouanBlZzsqLnBuZw==")
        if ($dialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
            $image = Copy-PreviewImageFromFile $dialog.FileName
            if ($image) {
                & $setCover $image (& $D "5bey6YCJ5oup6Ieq5a6a5LmJ5bCB6Z2i")
                $coverState.Mode = "file"
                $coverState.File = $dialog.FileName
            }
            else {
                [System.Windows.Forms.MessageBox]::Show((& $D "6K+36YCJ5oupIEpQR+OAgUpQRUcg5oiWIFBORyDmoLzlvI/nmoTlsIHpnaLjgII="), $form.Text, "OK", "Warning") | Out-Null
            }
        }
    })
    $removeCoverButton.Add_Click({
        & $setCover $null (& $D "5peg")
        $coverState.Mode = "none"
        $coverState.File = ""
    })
    $restoreCoverButton.Add_Click({
        $image = ConvertFrom-PreviewImageBase64 $coverState.AutoData
        if ($image) {
            & $setCover $image (& $D "5bCB6Z2i")
        }
        else {
            & $setCover $null (& $D "5rKh5pyJ5Y+v55So5bCB6Z2i")
        }
        $coverState.Mode = "auto"
        $coverState.File = ""
    })

    $retryButton = New-Object System.Windows.Forms.Button
    $retryButton.Anchor = "Bottom, Right"
    $retryButton.Location = New-Object System.Drawing.Point(640, 12)
    $retryButton.Size = New-Object System.Drawing.Size(112, 29)
    $retryButton.Text = (& $D "6YeN5paw5p+l6K+i6LWE5paZ")
    $footer.Controls.Add($retryButton)

    $importButton = New-Object System.Windows.Forms.Button
    $importButton.Anchor = "Bottom, Right"
    $importButton.Location = New-Object System.Drawing.Point(764, 12)
    $importButton.Size = New-Object System.Drawing.Size(136, 29)
    $importButton.Text = (& $D "5a+85YWlIEFwcGxlIE11c2lj")
    $footer.Controls.Add($importButton)

    $cancelButton = New-Object System.Windows.Forms.Button
    $cancelButton.Anchor = "Bottom, Right"
    $cancelButton.Location = New-Object System.Drawing.Point(912, 12)
    $cancelButton.Size = New-Object System.Drawing.Size(112, 29)
    $cancelButton.Text = (& $D "5pqC5LiN5a+85YWl")
    $cancelButton.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
    $footer.Controls.Add($cancelButton)
    $form.CancelButton = $cancelButton

    $buildOverrides = {
        $effectiveArtworkMode = $coverState.Mode
        $effectiveArtworkFile = $coverState.File
        if ($effectiveArtworkMode -eq "auto" -and -not [string]::IsNullOrWhiteSpace($coverState.AutoFile) -and (Test-Path -LiteralPath $coverState.AutoFile)) {
            $effectiveArtworkMode = "file"
            $effectiveArtworkFile = $coverState.AutoFile
        }
        return [ordered]@{
            title = $fieldBoxes["title"].Text.Trim()
            artist = $fieldBoxes["artist"].Text.Trim()
            album = $fieldBoxes["album"].Text.Trim()
            album_artist = $fieldBoxes["album_artist"].Text.Trim()
            year = $fieldBoxes["year"].Text.Trim()
            release_date = $fieldBoxes["release_date"].Text.Trim()
            genre = $fieldBoxes["genre"].Text.Trim()
            composer = $fieldBoxes["composer"].Text.Trim()
            lyricist = $fieldBoxes["lyricist"].Text.Trim()
            arranger = $fieldBoxes["arranger"].Text.Trim()
            isrc = $fieldBoxes["isrc"].Text.Trim()
            musicbrainz_recording_id = $fieldBoxes["musicbrainz_recording_id"].Text.Trim()
            track_number = $fieldBoxes["track_number"].Text.Trim()
            track_count = $fieldBoxes["track_count"].Text.Trim()
            disc_number = $fieldBoxes["disc_number"].Text.Trim()
            disc_count = $fieldBoxes["disc_count"].Text.Trim()
            lyrics = $lyricsBox.Text.Trim()
            artwork_mode = $effectiveArtworkMode
            artwork_file = $effectiveArtworkFile
            artwork_url = Get-PreviewValue "artwork_url"
            generated_artwork = Get-PreviewValue "generated_artwork"
        }
    }

    $retryButton.Add_Click({
        if ([string]::IsNullOrWhiteSpace($fieldBoxes["title"].Text)) {
            [System.Windows.Forms.MessageBox]::Show((& $D "6K+36Iez5bCR5aGr5YaZ5q2M5puy5ZCN44CC"), $form.Text, "OK", "Warning") | Out-Null
            $fieldBoxes["title"].Focus()
            return
        }
        $script:MetadataPreviewResult = [PSCustomObject]@{ Cancelled = $false; Retry = $true; Overrides = (& $buildOverrides); TemporaryArtworkFile = $coverState.AutoFile }
        $form.DialogResult = [System.Windows.Forms.DialogResult]::OK
        $form.Close()
    })
    $importButton.Add_Click({
        if ([string]::IsNullOrWhiteSpace($fieldBoxes["title"].Text)) {
            [System.Windows.Forms.MessageBox]::Show((& $D "6K+36Iez5bCR5aGr5YaZ5q2M5puy5ZCN44CC"), $form.Text, "OK", "Warning") | Out-Null
            $fieldBoxes["title"].Focus()
            return
        }
        $script:MetadataPreviewResult = [PSCustomObject]@{ Cancelled = $false; Retry = $false; Overrides = (& $buildOverrides); TemporaryArtworkFile = $coverState.AutoFile }
        $form.DialogResult = [System.Windows.Forms.DialogResult]::OK
        $form.Close()
    })
    $form.Add_FormClosed({
        if ($artworkClient) {
            try { $artworkClient.CancelAsync() } catch {}
            try { $artworkClient.Dispose() } catch {}
        }
        if ($coverBox.Image) {
            $coverBox.Image.Dispose()
        }
    })

    $script:MetadataPreviewResult = $null
    $dialogResult = $form.ShowDialog()
    if ($dialogResult -ne [System.Windows.Forms.DialogResult]::OK -or -not $script:MetadataPreviewResult) {
        if (-not [string]::IsNullOrWhiteSpace([string]$coverState.AutoFile) -and (Test-Path -LiteralPath $coverState.AutoFile)) {
            Remove-Item -LiteralPath $coverState.AutoFile -Force -ErrorAction SilentlyContinue
        }
        return [PSCustomObject]@{ Cancelled = $true; Retry = $false; Overrides = $null; TemporaryArtworkFile = "" }
    }
    $result = $script:MetadataPreviewResult
    $script:MetadataPreviewResult = $null
    return $result
}

function Ask-AlbumBatchInfo {
    param(
        [int]$TrackCount = 0,
        [string]$DefaultAlbum = "",
        [string]$DefaultArtist = "",
        [string]$DefaultYear = ""
    )

    Add-Type -AssemblyName System.Windows.Forms | Out-Null
    Add-Type -AssemblyName System.Drawing | Out-Null
    $D = { param([string]$B64) Decode-Utf8 $B64 }

    $form = New-Object System.Windows.Forms.Form
    $form.Text = (& $D "5om56YeP5a+85YWl5pW05byg5LiT6L6R")
    $form.StartPosition = "CenterScreen"
    $form.FormBorderStyle = "FixedDialog"
    $form.MaximizeBox = $false
    $form.MinimizeBox = $false
    $form.ClientSize = New-Object System.Drawing.Size(560, 360)
    $form.Font = New-Object System.Drawing.Font("Microsoft YaHei UI", 9)

    $note = New-Object System.Windows.Forms.Label
    $note.AutoSize = $false
    $note.Location = New-Object System.Drawing.Point(18, 14)
    $note.Size = New-Object System.Drawing.Size(520, 44)
    $note.Text = (& $D "5qOA5rWL5Yiw5aSa6aaW5q2M44CC5Y+q5aGr5LiA5qyh5YWx55So5L+h5oGv77yM5LmL5ZCO5Lya5oyJ5YiX6KGo6aG65bqP5YaZ5YWl5ZCM5LiA5byg5LiT6L6R44CC")
    $form.Controls.Add($note)

    $countLabel = New-Object System.Windows.Forms.Label
    $countLabel.AutoSize = $false
    $countLabel.Location = New-Object System.Drawing.Point(18, 62)
    $countLabel.Size = New-Object System.Drawing.Size(520, 22)
    $countLabel.Text = (& $D "5q2M5puy5pWw6YeP77ya") + $TrackCount
    $form.Controls.Add($countLabel)

    function Add-Label {
        param([string]$Text, [int]$Y)
        $label = New-Object System.Windows.Forms.Label
        $label.AutoSize = $false
        $label.Location = New-Object System.Drawing.Point(20, $Y)
        $label.Size = New-Object System.Drawing.Size(150, 24)
        $label.Text = $Text
        $form.Controls.Add($label)
        return $label
    }

    function Add-TextBox {
        param([string]$Text, [int]$Y)
        $box = New-Object System.Windows.Forms.TextBox
        $box.Location = New-Object System.Drawing.Point(178, $Y)
        $box.Size = New-Object System.Drawing.Size(360, 25)
        $box.Text = $Text
        $box.ImeMode = [System.Windows.Forms.ImeMode]::On
        $form.Controls.Add($box)
        return $box
    }

    Add-Label (& $D "5LiT6L6R5ZCN") 100 | Out-Null
    $albumBox = Add-TextBox $DefaultAlbum 98
    Add-Label (& $D "5LiT6L6R5q2M5omLIC8g6buY6K6k5q2M5omL") 140 | Out-Null
    $artistBox = Add-TextBox $DefaultArtist 138
    Add-Label (& $D "5bm05Lu977yI5Y+v6YCJ77yJ") 180 | Out-Null
    $yearBox = Add-TextBox $DefaultYear 178

    $liveBox = New-Object System.Windows.Forms.CheckBox
    $liveBox.Location = New-Object System.Drawing.Point(178, 218)
    $liveBox.Size = New-Object System.Drawing.Size(180, 24)
    $liveBox.Text = (& $D "6L+Z5pivIExpdmUgLyDnjrDlnLrniYg=")
    $form.Controls.Add($liveBox)

    $coverBox = New-Object System.Windows.Forms.CheckBox
    $coverBox.Location = New-Object System.Drawing.Point(178, 248)
    $coverBox.Size = New-Object System.Drawing.Size(180, 24)
    $coverBox.Text = (& $D "6L+Z5piv57+75ZSx54mI")
    $form.Controls.Add($coverBox)

    Add-Label (& $D "57+75ZSx6ICFIC8g5b2T5YmN5ryU5ZSx6ICF") 280 | Out-Null
    $coverArtistBox = Add-TextBox "" 278
    $coverArtistBox.Enabled = $false
    $coverBox.Add_CheckedChanged({
        $coverArtistBox.Enabled = $coverBox.Checked
        if ($coverBox.Checked -and [string]::IsNullOrWhiteSpace($coverArtistBox.Text)) {
            $coverArtistBox.Text = $artistBox.Text
        }
    })

    $confirmEachBox = New-Object System.Windows.Forms.CheckBox
    $confirmEachBox.Location = New-Object System.Drawing.Point(20, 316)
    $confirmEachBox.Size = New-Object System.Drawing.Size(270, 24)
    $confirmEachBox.Text = (& $D "5q+P6aaW5q2M5LuN54S26YCQ5Liq56Gu6K6k77yI5pu05oWi77yJ")
    $confirmEachBox.Checked = $false
    $form.Controls.Add($confirmEachBox)

    $okButton = New-Object System.Windows.Forms.Button
    $okButton.Location = New-Object System.Drawing.Point(338, 316)
    $okButton.Size = New-Object System.Drawing.Size(90, 28)
    $okButton.Text = (& $D "56Gu5a6a")
    $form.Controls.Add($okButton)

    $cancelButton = New-Object System.Windows.Forms.Button
    $cancelButton.Location = New-Object System.Drawing.Point(448, 316)
    $cancelButton.Size = New-Object System.Drawing.Size(90, 28)
    $cancelButton.Text = (& $D "5Y+W5raI")
    $cancelButton.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
    $form.Controls.Add($cancelButton)
    $form.CancelButton = $cancelButton

    $script:AskAlbumBatchInfoResult = $null
    $okButton.Add_Click({
        if ([string]::IsNullOrWhiteSpace($albumBox.Text)) {
            $albumBox.Focus()
            return
        }
        $script:AskAlbumBatchInfoResult = [PSCustomObject]@{
            Cancelled = $false
            AlbumName = $albumBox.Text.Trim()
            ArtistName = $artistBox.Text.Trim()
            YearText = $yearBox.Text.Trim()
            IsLive = [bool]$liveBox.Checked
            IsCover = [bool]$coverBox.Checked
            CoverArtist = $coverArtistBox.Text.Trim()
            ConfirmEachTrack = [bool]$confirmEachBox.Checked
        }
        $form.DialogResult = [System.Windows.Forms.DialogResult]::OK
        $form.Close()
    })

    $albumBox.Select()
    $dialogResult = $form.ShowDialog()
    if ($dialogResult -ne [System.Windows.Forms.DialogResult]::OK -or -not $script:AskAlbumBatchInfoResult) {
        return [PSCustomObject]@{ Cancelled = $true }
    }
    $result = $script:AskAlbumBatchInfoResult
    $script:AskAlbumBatchInfoResult = $null
    return $result
}

function Pick-Files {
    Add-Type -AssemblyName System.Windows.Forms | Out-Null
    $dialog = New-Object System.Windows.Forms.OpenFileDialog
    $dialog.Title = "Choose audio file(s)"
    $dialog.Filter = "Audio files (*.m4a;*.mp4;*.aac;*.mp3;*.flac;*.wav;*.webm;*.opus;*.ogg)|*.m4a;*.mp4;*.aac;*.mp3;*.flac;*.wav;*.webm;*.opus;*.ogg|All files (*.*)|*.*"
    $dialog.Multiselect = $true
    if ($dialog.ShowDialog() -ne [System.Windows.Forms.DialogResult]::OK) {
        return @()
    }
    return $dialog.FileNames
}

function Get-ClipboardUrls {
    Add-Type -AssemblyName System.Windows.Forms | Out-Null
    $text = ""
    try {
        if ([System.Windows.Forms.Clipboard]::ContainsText()) {
            $text = [System.Windows.Forms.Clipboard]::GetText()
        }
    }
    catch {
        return @()
    }
    if ([string]::IsNullOrWhiteSpace($text)) {
        return @()
    }
    $matches = [regex]::Matches($text, 'https?://[^\s<>"'']+')
    $urls = New-Object System.Collections.Generic.List[string]
    foreach ($match in $matches) {
        $url = $match.Value.Trim().TrimEnd('.', ',', ';', ')', ']', '}')
        if ($url -and -not $urls.Contains($url)) {
            $urls.Add($url)
        }
    }
    return $urls.ToArray()
}

function Get-UrlQueryValue {
    param([string]$Url, [string]$Name)
    if ([string]::IsNullOrWhiteSpace($Url) -or [string]::IsNullOrWhiteSpace($Name)) {
        return ""
    }
    $pattern = "(?:\?|&)" + [regex]::Escape($Name) + "=([^&#]+)"
    $match = [regex]::Match($Url, $pattern, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
    if (-not $match.Success) {
        return ""
    }
    return [System.Uri]::UnescapeDataString($match.Groups[1].Value)
}

function Test-YouTubeAutoMixUrl {
    param([string]$Url)
    $listId = Get-UrlQueryValue -Url $Url -Name "list"
    if ([string]::IsNullOrWhiteSpace($listId)) {
        return $false
    }
    return ($listId -match '^(?i:RD)')
}

function Get-UrlsFromText {
    param([string]$Text)
    if ([string]::IsNullOrWhiteSpace($Text)) {
        return @()
    }
    return @(
        [regex]::Matches($Text, 'https?://[^\s<>"'']+') |
            ForEach-Object { $_.Value.Trim().TrimEnd('.', ',', ';', ')', ']', '}') } |
            Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
            Select-Object -Unique
    )
}

function Start-UrlPrefetch {
    param([string[]]$Urls)
    if (-not $Urls -or $Urls.Count -ne 1) {
        return $null
    }
    $url = [string]$Urls[0]
    if ((Test-YouTubeAutoMixUrl -Url $url) -or -not [string]::IsNullOrWhiteSpace((Get-UrlQueryValue -Url $url -Name "list"))) {
        return $null
    }

    $shell = (Get-Command powershell.exe -ErrorAction Stop).Source
    $resultFile = Join-Path $env:TEMP ("am-prefetch-result-" + [guid]::NewGuid().ToString() + ".json")
    $arguments = @(
        "-NoProfile",
        "-ExecutionPolicy", "Bypass",
        "-File", $PSCommandPath,
        "-PrefetchResultFile", $resultFile,
        "-PrefetchUrls", $url
    )
    $quote = {
        param([string]$Value)
        $text = [string]$Value
        '"' + $text.Replace('"', '\"') + '"'
    }
    $startInfo = [System.Diagnostics.ProcessStartInfo]::new()
    $startInfo.FileName = $shell
    $startInfo.Arguments = (($arguments | ForEach-Object { & $quote ([string]$_) }) -join " ")
    $startInfo.UseShellExecute = $false
    $startInfo.CreateNoWindow = $true
    $process = [System.Diagnostics.Process]::new()
    $process.StartInfo = $startInfo
    if (-not $process.Start()) {
        throw "Unable to start background download."
    }
    return [PSCustomObject]@{
        Process = $process
        ResultFile = $resultFile
        UrlKey = $url
    }
}

function Stop-UrlPrefetch {
    param([object]$Task)
    if ($Task -and $Task.Process) {
        try {
            if (-not $Task.Process.HasExited) {
                $Task.Process.Kill()
                $Task.Process.WaitForExit()
            }
        }
        catch {
        }
    }
    if ($Task -and $Task.ResultFile -and (Test-Path -LiteralPath $Task.ResultFile)) {
        Remove-Item -LiteralPath $Task.ResultFile -Force -ErrorAction SilentlyContinue
    }
}

function Complete-UrlPrefetch {
    param([object]$Task)
    if (-not $Task -or -not $Task.Process -or [string]::IsNullOrWhiteSpace([string]$Task.ResultFile)) {
        throw "Background download task is unavailable."
    }
    try {
        $Task.Process.WaitForExit()
        if (-not (Test-Path -LiteralPath $Task.ResultFile)) {
            throw "Background download did not return a result."
        }
        $payload = Get-Content -LiteralPath $Task.ResultFile -Raw -Encoding UTF8 | ConvertFrom-Json
        $files = @($payload.files) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
        if ($files.Count -eq 0) {
            $errorText = (($payload.errors | Out-String).Trim())
            if ([string]::IsNullOrWhiteSpace($errorText)) {
                $errorText = "No audio file was downloaded."
            }
            throw $errorText
        }
        return $files
    }
    finally {
        if (Test-Path -LiteralPath $Task.ResultFile) {
            Remove-Item -LiteralPath $Task.ResultFile -Force -ErrorAction SilentlyContinue
        }
    }
}

function Ask-AudioSource {
    param([string[]]$ClipboardUrls = @())

    Add-Type -AssemblyName System.Windows.Forms | Out-Null
    Add-Type -AssemblyName System.Drawing | Out-Null
    $D = { param([string]$B64) [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($B64)) }

    $form = New-Object System.Windows.Forms.Form
    $form.Text = (& $D "6YCJ5oup6Z+z5rqQ5p2l5rqQ")
    $form.StartPosition = "CenterScreen"
    $form.FormBorderStyle = "FixedDialog"
    $form.MaximizeBox = $false
    $form.MinimizeBox = $false
    $form.ClientSize = New-Object System.Drawing.Size(600, 400)
    $form.Font = New-Object System.Drawing.Font("Microsoft YaHei UI", 9)

    $note = New-Object System.Windows.Forms.Label
    $note.AutoSize = $false
    $note.Location = New-Object System.Drawing.Point(18, 14)
    $note.Size = New-Object System.Drawing.Size(560, 42)
    $note.Text = (& $D "5Y+v5Lul57KY6LS0IFlvdVR1YmUgLyBC56uZIC8g572R6aG16KeG6aKR6ZO+5o6l77yb5Lmf5Y+v5Lul57un57ut6YCJ5oup5pys5Zyw6Z+z6aKR5paH5Lu244CC")
    $form.Controls.Add($note)

    if ($ClipboardUrls -and $ClipboardUrls.Count -gt 0) {
        $clipNote = New-Object System.Windows.Forms.Label
        $clipNote.AutoSize = $false
        $clipNote.Location = New-Object System.Drawing.Point(18, 58)
        $clipNote.Size = New-Object System.Drawing.Size(560, 24)
        $clipNote.Text = (& $D "5qOA5rWL5Yiw5Ymq6LS05p2/6ZO+5o6l77yM5bey6Ieq5Yqo5aGr5YWl44CC")
        $form.Controls.Add($clipNote)
    }

    $label = New-Object System.Windows.Forms.Label
    $label.AutoSize = $false
    $label.Location = New-Object System.Drawing.Point(18, 90)
    $label.Size = New-Object System.Drawing.Size(560, 24)
    $label.Text = (& $D "572R6aG16KeG6aKR6ZO+5o6l77yI5LiA6KGM5LiA5Liq77yJ")
    $form.Controls.Add($label)

    $urlBox = New-Object System.Windows.Forms.TextBox
    $urlBox.Location = New-Object System.Drawing.Point(20, 116)
    $urlBox.Size = New-Object System.Drawing.Size(560, 140)
    $urlBox.Multiline = $true
    $urlBox.ScrollBars = "Vertical"
    $urlBox.ImeMode = [System.Windows.Forms.ImeMode]::Off
    if ($ClipboardUrls -and $ClipboardUrls.Count -gt 0) {
        $urlBox.Text = ($ClipboardUrls -join "`r`n")
    }
    $form.Controls.Add($urlBox)

    $maxLabel = New-Object System.Windows.Forms.Label
    $maxLabel.AutoSize = $false
    $maxLabel.Location = New-Object System.Drawing.Point(20, 266)
    $maxLabel.Size = New-Object System.Drawing.Size(400, 24)
    $maxLabel.Text = (& $D "5pyA5aSa5LiL6L296aaW5pWw77yI6Ieq5Yqo5ZCI6L6R5bu66K6uIDE177yM5pmu6YCa5YiX6KGo5Y+v5riF56m677yJ")
    $form.Controls.Add($maxLabel)

    $maxBox = New-Object System.Windows.Forms.TextBox
    $maxBox.Location = New-Object System.Drawing.Point(430, 264)
    $maxBox.Size = New-Object System.Drawing.Size(60, 25)
    $maxBox.Text = "15"
    $maxBox.ImeMode = [System.Windows.Forms.ImeMode]::Off
    $form.Controls.Add($maxBox)

    $prefetchStatus = New-Object System.Windows.Forms.Label
    $prefetchStatus.AutoSize = $false
    $prefetchStatus.Location = New-Object System.Drawing.Point(20, 296)
    $prefetchStatus.Size = New-Object System.Drawing.Size(560, 24)
    $prefetchStatus.ForeColor = [System.Drawing.Color]::FromArgb(45, 95, 155)
    $form.Controls.Add($prefetchStatus)

    $prefetchState = @{ Task = $null; UrlKey = ""; Claimed = $false }
    $prefetchTimer = New-Object System.Windows.Forms.Timer
    $prefetchTimer.Interval = 800
    $stopPrefetch = {
        if ($prefetchState.Task) {
            Stop-UrlPrefetch -Task $prefetchState.Task
        }
        $prefetchState.Task = $null
        $prefetchState.UrlKey = ""
    }
    $prefetchTimer.Add_Tick({
        $prefetchTimer.Stop()
        $urls = @(Get-UrlsFromText -Text $urlBox.Text)
        if ($urls.Count -ne 1 -or -not [string]::IsNullOrWhiteSpace((Get-UrlQueryValue -Url ([string]$urls[0]) -Name "list"))) {
            if ($prefetchState.Task) {
                & $stopPrefetch
            }
            $prefetchStatus.Text = ""
            return
        }
        $urlKey = [string]$urls[0]
        if ($prefetchState.Task -and $prefetchState.UrlKey -eq $urlKey) {
            try {
                $prefetchStatus.Text = if ($prefetchState.Task.Process.HasExited) { (& $D "5ZCO5Y+w6aKE5LiL6L295bey5a6M5oiQ77yM54K55Ye75LiL6L295ZCO5Lya55u05o6l57un57ut44CC") } else { (& $D "5q2j5Zyo5ZCO5Y+w6aKE5LiL6L2977yM5Y+v57un57ut5aGr5YaZ44CC") }
            }
            catch {
                $prefetchStatus.Text = (& $D "5q2j5Zyo5ZCO5Y+w6aKE5LiL6L2977yM5Y+v57un57ut5aGr5YaZ44CC")
            }
            return
        }
        if ($prefetchState.Task) {
            & $stopPrefetch
        }
        try {
            $prefetchState.Task = Start-UrlPrefetch -Urls $urls
            if ($prefetchState.Task) {
                $prefetchState.UrlKey = $urlKey
                $prefetchStatus.Text = (& $D "5q2j5Zyo5ZCO5Y+w6aKE5LiL6L2977yM5Y+v57un57ut5aGr5YaZ44CC")
            }
        }
        catch {
            $prefetchStatus.Text = (& $D "6ZO+5o6l5Lya5Zyo54K55Ye75LiL6L295ZCO5byA5aeL5aSE55CG44CC")
        }
    })
    $urlBox.Add_TextChanged({
        $prefetchTimer.Stop()
        $prefetchTimer.Start()
    })

    $downloadButton = New-Object System.Windows.Forms.Button
    $downloadButton.Location = New-Object System.Drawing.Point(166, 344)
    $downloadButton.Size = New-Object System.Drawing.Size(92, 30)
    $downloadButton.Text = (& $D "5LiL6L295b2T5YmN")
    $form.Controls.Add($downloadButton)

    $playlistButton = New-Object System.Windows.Forms.Button
    $playlistButton.Location = New-Object System.Drawing.Point(268, 344)
    $playlistButton.Size = New-Object System.Drawing.Size(126, 30)
    $playlistButton.Text = (& $D "5LiL6L295pW05bygL+WIl+ihqA==")
    $form.Controls.Add($playlistButton)

    $fileButton = New-Object System.Windows.Forms.Button
    $fileButton.Location = New-Object System.Drawing.Point(404, 344)
    $fileButton.Size = New-Object System.Drawing.Size(110, 30)
    $fileButton.Text = (& $D "6YCJ5oup5pys5Zyw5paH5Lu2")
    $form.Controls.Add($fileButton)

    $cancelButton = New-Object System.Windows.Forms.Button
    $cancelButton.Location = New-Object System.Drawing.Point(524, 344)
    $cancelButton.Size = New-Object System.Drawing.Size(56, 30)
    $cancelButton.Text = (& $D "5Y+W5raI")
    $cancelButton.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
    $form.Controls.Add($cancelButton)
    $form.CancelButton = $cancelButton

    $script:AudioSourceResult = $null
    $downloadButton.Add_Click({
        $urls = @(Get-UrlsFromText -Text $urlBox.Text)
        if (-not $urls -or $urls.Count -eq 0) {
            [System.Windows.Forms.MessageBox]::Show((& $D "5rKh5pyJ5Y+v5LiL6L2955qE6ZO+5o6l44CC"), $form.Text, "OK", "Warning") | Out-Null
            return
        }
        $prefetchTimer.Stop()
        $task = $null
        if ($prefetchState.Task -and $prefetchState.UrlKey -eq [string]$urls[0]) {
            $task = $prefetchState.Task
            $prefetchState.Claimed = $true
        }
        elseif ($prefetchState.Task) {
            & $stopPrefetch
        }
        $script:AudioSourceResult = [PSCustomObject]@{ Mode = "Url"; Urls = @($urls); PlaylistMode = $false; MaxPlaylistItems = 0; PrefetchTask = $task; Cancelled = $false }
        $form.DialogResult = [System.Windows.Forms.DialogResult]::OK
        $form.Close()
    })
    $playlistButton.Add_Click({
        $urls = @(Get-UrlsFromText -Text $urlBox.Text)
        if (-not $urls -or $urls.Count -eq 0) {
            [System.Windows.Forms.MessageBox]::Show((& $D "5rKh5pyJ5Y+v5LiL6L2955qE6ZO+5o6l44CC"), $form.Text, "OK", "Warning") | Out-Null
            return
        }
        $maxItems = 0
        if (-not [string]::IsNullOrWhiteSpace($maxBox.Text)) {
            if (-not [int]::TryParse($maxBox.Text.Trim(), [ref]$maxItems) -or $maxItems -lt 1) {
                [System.Windows.Forms.MessageBox]::Show((& $D "6K+36L6T5YWl5pyJ5pWI5pWw5a2X77yM5oiW55WZ56m644CC"), $form.Text, "OK", "Warning") | Out-Null
                $maxBox.Focus()
                return
            }
        }
        $prefetchTimer.Stop()
        & $stopPrefetch
        $script:AudioSourceResult = [PSCustomObject]@{ Mode = "Url"; Urls = @($urls); PlaylistMode = $true; MaxPlaylistItems = $maxItems; PrefetchTask = $null; Cancelled = $false }
        $form.DialogResult = [System.Windows.Forms.DialogResult]::OK
        $form.Close()
    })
    $fileButton.Add_Click({
        $prefetchTimer.Stop()
        & $stopPrefetch
        $script:AudioSourceResult = [PSCustomObject]@{ Mode = "Files"; Urls = @(); PlaylistMode = $false; MaxPlaylistItems = 0; PrefetchTask = $null; Cancelled = $false }
        $form.DialogResult = [System.Windows.Forms.DialogResult]::OK
        $form.Close()
    })

    $form.Add_FormClosed({
        $prefetchTimer.Stop()
        if (-not $prefetchState.Claimed) {
            & $stopPrefetch
        }
        $prefetchTimer.Dispose()
    })

    $urlBox.Select()
    if (-not [string]::IsNullOrWhiteSpace($urlBox.Text)) {
        $prefetchTimer.Start()
    }
    $dialogResult = $form.ShowDialog()
    if ($dialogResult -ne [System.Windows.Forms.DialogResult]::OK -or -not $script:AudioSourceResult) {
        return [PSCustomObject]@{ Mode = "Cancel"; Urls = @(); PlaylistMode = $false; MaxPlaylistItems = 0; PrefetchTask = $null; Cancelled = $true }
    }
    $result = $script:AudioSourceResult
    $script:AudioSourceResult = $null
    return $result
}

function Invoke-PythonProbe {
    param([string]$PythonExe)
    try {
        # Do not return sys.executable from stdout: Windows PowerShell can
        # decode a Unicode path incorrectly when the tool folder has Chinese text.
        & $PythonExe -c "import sys; sys.exit(0 if sys.version_info >= (3, 10) else 1)" 2>$null | Out-Null
        if ($LASTEXITCODE -eq 0) {
            return $PythonExe
        }
    }
    catch {
    }
    return ""
}

function Resolve-Python {
    $candidates = New-Object System.Collections.Generic.List[string]

    $packagedRuntimeRoot = Join-Path $PSScriptRoot "python"
    $runtimeRoot = Join-Path $Script:StateRoot "python"
    $embeddedPython = Join-Path $packagedRuntimeRoot "python.exe"
    $venvPython = Join-Path $runtimeRoot "Scripts\python.exe"
    $legacyVenvPython = Join-Path $packagedRuntimeRoot "Scripts\python.exe"

    if (Test-Path -LiteralPath $embeddedPython) {
        $candidates.Add($embeddedPython)
    }
    if (Test-Path -LiteralPath $venvPython) {
        $candidates.Add($venvPython)
    }
    if (Test-Path -LiteralPath $legacyVenvPython) {
        $candidates.Add($legacyVenvPython)
    }

    if ($candidates.Count -eq 0) {
        $pyForRuntime = Get-Command py -ErrorAction SilentlyContinue
        if ($pyForRuntime) {
            try {
                & $pyForRuntime.Source -3 -c "import sys; sys.exit(0 if sys.version_info >= (3, 10) else 1)" 2>$null | Out-Null
                if ($LASTEXITCODE -eq 0) {
                    & $pyForRuntime.Source -3 -m venv $runtimeRoot 2>$null
                }
            }
            catch {
            }
        }
        else {
            $pythonForRuntime = Get-Command python -ErrorAction SilentlyContinue
            if ($pythonForRuntime) {
                try {
                    $probedPython = Invoke-PythonProbe -PythonExe $pythonForRuntime.Source
                    if (-not [string]::IsNullOrWhiteSpace($probedPython)) {
                        & $probedPython -m venv $runtimeRoot 2>$null
                    }
                }
                catch {
                }
            }
        }
    }
    if (Test-Path -LiteralPath $venvPython) {
        if (-not $candidates.Contains($venvPython)) {
            $candidates.Add($venvPython)
        }
    }

    $pyLauncher = Get-Command py -ErrorAction SilentlyContinue
    if ($pyLauncher) {
        try {
            $pyPath = & py -3 -c "import sys; print(sys.executable)" 2>$null
            if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace(($pyPath | Select-Object -First 1))) {
                $candidates.Add(($pyPath | Select-Object -First 1))
            }
        }
        catch {
        }
    }

    $pythonCmd = Get-Command python -ErrorAction SilentlyContinue
    if ($pythonCmd) {
        $candidates.Add($pythonCmd.Source)
    }

    foreach ($candidate in $candidates) {
        $resolved = Invoke-PythonProbe -PythonExe $candidate
        if (-not [string]::IsNullOrWhiteSpace($resolved)) {
            return $resolved
        }
    }

    throw (Decode-Utf8 "6ZyA6KaBIFB5dGhvbiAzLjEwIOaIluabtOmrmOeJiOacrOOAgg==")
}

function Ensure-PythonDependencies {
    param(
        [string]$PythonExe,
        [switch]$NonInteractive
    )
    $checkCode = "import importlib.util, importlib.metadata, sys; expected=(('mutagen','mutagen','1.48.1'),('imageio-ffmpeg','imageio_ffmpeg','0.6.0'),('Pillow','PIL','12.3.0'),('yt-dlp','yt_dlp','2026.8.19')); issues=[]; [(issues.append(module) if importlib.util.find_spec(module) is None else issues.append(f'{dist}({importlib.metadata.version(dist)}->{version})') if importlib.metadata.version(dist) != version else None) for dist,module,version in expected]; print(','.join(issues)); sys.exit(1 if issues else 0)"
    $missing = (& $PythonExe -c $checkCode 2>$null | Out-String).Trim()
    if ($LASTEXITCODE -eq 0) {
        return
    }

    if ($NonInteractive) {
        throw ((Decode-Utf8 "57y65bCRIFB5dGhvbiDnu4Tku7bvvJo=") + $missing)
    }

    $runtimeRoot = [System.IO.Path]::GetFullPath((Join-Path $Script:StateRoot "python"))
    $legacyRuntimeRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot "python"))
    $pythonFullPath = [System.IO.Path]::GetFullPath($PythonExe)
    $embeddedPython = [System.IO.Path]::GetFullPath((Join-Path $legacyRuntimeRoot "python.exe"))
    if ($pythonFullPath.Equals($embeddedPython, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw (Decode-Utf8 "5L6/5pC654mI5YaF572u6L+Q6KGM5bqT5LiN5a6M5pW077yM6K+36YeN5paw5LiL6L295bm25a6M5pW06Kej5Y6L44CC")
    }

    Add-Type -AssemblyName System.Windows.Forms | Out-Null
    $answer = [System.Windows.Forms.MessageBox]::Show(
        ((Decode-Utf8 "6L+Z5Y+w55S16ISR57y65bCRIFB5dGhvbiDnu4Tku7bvvJo=") + $missing + "`r`n`r`n" + (Decode-Utf8 "5piv5ZCm56uL5Y2z5a6J6KOF5omA6ZyA57uE5Lu277yf") + "`r`n`r`n" + (Decode-Utf8 "6ZyA6KaB6IGU572R5LiL6L2977yabXV0YWdlbuOAgWltYWdlaW8tZmZtcGVn44CBcGlsbG9344CBeXQtZGxw")),
        "Apple Music Auto Import",
        "YesNo",
        "Question"
    )
    if ($answer -ne [System.Windows.Forms.DialogResult]::Yes) {
        throw ((Decode-Utf8 "57y65bCRIFB5dGhvbiDnu4Tku7bvvJo=") + $missing)
    }

    & $PythonExe -m ensurepip --upgrade | Out-Null
    $pipArgs = @("-m", "pip", "install", "--upgrade")
    $isManagedRuntime = $pythonFullPath.StartsWith($runtimeRoot, [System.StringComparison]::OrdinalIgnoreCase) -or $pythonFullPath.StartsWith($legacyRuntimeRoot, [System.StringComparison]::OrdinalIgnoreCase)
    if (-not $isManagedRuntime) {
        $pipArgs += "--user"
    }
    $requirementsPath = Join-Path $PSScriptRoot "requirements.txt"
    if (Test-Path -LiteralPath $requirementsPath) {
        $pipArgs += @("-r", $requirementsPath)
    }
    else {
        $pipArgs += @("mutagen==1.48.1", "imageio-ffmpeg==0.6.0", "pillow==12.3.0", "yt-dlp==2026.8.19")
    }
    & $PythonExe @pipArgs
    if ($LASTEXITCODE -ne 0) {
        throw (Decode-Utf8 "5a6J6KOF57uE5Lu25aSx6LSl44CC6K+35qOA5p+l572R57uc5ZCO6YeN6K+V44CC")
    }
}

function Get-ConfigPath {
    return (Join-Path $Script:StateRoot "AppleMusic-Auto-Enrich-Import.config.json")
}

function Read-Config {
    $configPath = Get-ConfigPath
    if (Test-Path -LiteralPath $configPath) {
        try {
            return (Get-Content -LiteralPath $configPath -Raw -Encoding UTF8 | ConvertFrom-Json)
        }
        catch {
        }
    }
    $legacyConfigPath = Join-Path $PSScriptRoot "AppleMusic-Auto-Enrich-Import.config.json"
    if (-not $legacyConfigPath.Equals($configPath, [System.StringComparison]::OrdinalIgnoreCase) -and (Test-Path -LiteralPath $legacyConfigPath)) {
        try {
            $legacyConfig = Get-Content -LiteralPath $legacyConfigPath -Raw -Encoding UTF8 | ConvertFrom-Json
            Write-Config -Config $legacyConfig
            return $legacyConfig
        }
        catch {
        }
    }
    return [PSCustomObject]@{}
}

function Write-Config {
    param([object]$Config)
    $configPath = Get-ConfigPath
    $Config | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $configPath -Encoding UTF8
}

function Pick-Folder {
    param([string]$Description)
    Add-Type -AssemblyName System.Windows.Forms | Out-Null
    $dialog = New-Object System.Windows.Forms.FolderBrowserDialog
    $dialog.Description = $Description
    $dialog.ShowNewFolderButton = $false
    if ($dialog.ShowDialog() -ne [System.Windows.Forms.DialogResult]::OK) {
        return ""
    }
    return $dialog.SelectedPath
}

function Get-AppleMusicAutoAddCandidates {
    $music = [Environment]::GetFolderPath("MyMusic")
    return @(
        (Join-Path $music "Apple Music\Media\Automatically Add to Apple Music"),
        (Join-Path $music "Apple Music\Media\Automatically Add to iTunes"),
        (Join-Path $music "iTunes\iTunes Media\Automatically Add to iTunes"),
        (Join-Path $music "iTunes\iTunes Media\Automatically Add to Apple Music")
    )
}

function Resolve-AppleMusicAutoAdd {
    $config = Read-Config
    if ($config.AutoAddFolder -and (Test-Path -LiteralPath $config.AutoAddFolder)) {
        return $config.AutoAddFolder
    }

    foreach ($candidate in (Get-AppleMusicAutoAddCandidates)) {
        if (Test-Path -LiteralPath $candidate) {
            $config | Add-Member -NotePropertyName AutoAddFolder -NotePropertyValue $candidate -Force
            Write-Config -Config $config
            return $candidate
        }
    }

    $picked = Pick-Folder (Decode-Utf8 "5om+5LiN5YiwIEFwcGxlIE11c2ljIOiHquWKqOWvvOWFpeebruW9leOAguivt+mAieaLqSBBdXRvbWF0aWNhbGx5IEFkZCB0byBBcHBsZSBNdXNpYyDmlofku7blpLnjgII=")
    if ([string]::IsNullOrWhiteSpace($picked)) {
        throw (Decode-Utf8 "5rKh5pyJ6YCJ5oupIEFwcGxlIE11c2ljIOiHquWKqOWvvOWFpeebruW9leOAgg==")
    }
    $config | Add-Member -NotePropertyName AutoAddFolder -NotePropertyValue $picked -Force
    Write-Config -Config $config
    return $picked
}

function Test-DirectoryWritable {
    param([string]$Path)
    if ([string]::IsNullOrWhiteSpace($Path) -or -not (Test-Path -LiteralPath $Path -PathType Container)) {
        return $false
    }
    $probePath = Join-Path $Path (".am-write-" + [guid]::NewGuid().ToString("N") + ".tmp")
    try {
        $stream = [System.IO.FileStream]::new(
            $probePath,
            [System.IO.FileMode]::CreateNew,
            [System.IO.FileAccess]::Write,
            [System.IO.FileShare]::None,
            4096,
            [System.IO.FileOptions]::DeleteOnClose
        )
        $stream.Dispose()
        return $true
    }
    catch {
        return $false
    }
}

function Test-MetadataConnectivity {
    $curl = Get-Command curl.exe -ErrorAction SilentlyContinue
    if (-not $curl) {
        return $false
    }
    $urls = @(
        "https://itunes.apple.com/search?term=test&media=music&entity=song&limit=1",
        "https://music.163.com/api/search/get?s=test&type=1&offset=0&total=true&limit=1"
    )
    foreach ($url in $urls) {
        try {
            & $curl.Source --silent --show-error --fail --connect-timeout 3 --max-time 6 --output NUL $url 2>$null
            if ($LASTEXITCODE -eq 0) {
                return $true
            }
        }
        catch {
        }
    }
    return $false
}

function Get-AppleMusicPackageInfo {
    $packageRegistry = "HKCU:\Software\Classes\Local Settings\Software\Microsoft\Windows\CurrentVersion\AppModel\Repository\Packages"
    try {
        $matches = Get-ChildItem -Path $packageRegistry -ErrorAction Stop | ForEach-Object {
            if ($_.PSChildName -match '^AppleInc\.AppleMusicWin_(?<version>[0-9\.]+)_(?<architecture>[^_]+)__') {
                [PSCustomObject]@{
                    Version = [version]$Matches.version
                    Architecture = [string]$Matches.architecture
                }
            }
        }
        $best = $matches | Sort-Object Version -Descending | Select-Object -First 1
        if ($best) {
            return $best
        }
    }
    catch {
    }

    if ($PSVersionTable.PSEdition -eq "Desktop") {
        try {
            $package = Get-AppxPackage -Name AppleInc.AppleMusicWin -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($package) {
                return [PSCustomObject]@{
                    Version = [version]$package.Version
                    Architecture = [string]$package.Architecture
                }
            }
        }
        catch {
        }
    }
    return $null
}

function Invoke-EnvironmentSelfTest {
    param([switch]$AllowDependencyInstall)
    $D = { param([string]$B64) Decode-Utf8 $B64 }
    $checks = New-Object System.Collections.Generic.List[object]

    Write-Log "Self-test: Windows and architecture"
    $runningOnWindows = ($env:OS -eq "Windows_NT")
    $checks.Add([PSCustomObject]@{
        Name = (& $D "V2luZG93cyDns7vnu58=")
        Passed = $runningOnWindows
        Required = $true
        Detail = if ($runningOnWindows) { [Environment]::OSVersion.VersionString } else { [Environment]::OSVersion.Platform.ToString() }
    })

    $isX64 = [Environment]::Is64BitOperatingSystem -and (($env:PROCESSOR_ARCHITECTURE -eq "AMD64") -or ($env:PROCESSOR_ARCHITEW6432 -eq "AMD64"))
    $checks.Add([PSCustomObject]@{
        Name = (& $D "57O757uf5p625p6E")
        Passed = $isX64
        Required = $true
        Detail = if ($isX64) { "x64" } else { (& $D "5b2T5YmN5LuF6aqM6K+BIDY0IOS9jSBXaW5kb3dz77yIeDY077yJ44CC") }
    })

    Write-Log "Self-test: PowerShell UI components"
    $shellReady = ($PSVersionTable.PSVersion -ge [version]"5.1")
    try {
        Add-Type -AssemblyName System.Windows.Forms | Out-Null
        Add-Type -AssemblyName System.Drawing | Out-Null
    }
    catch {
        $shellReady = $false
    }
    $checks.Add([PSCustomObject]@{
        Name = (& $D "UG93ZXJTaGVsbCDkuI7nlYzpnaLnu4Tku7Y=")
        Passed = $shellReady
        Required = $true
        Detail = if ($shellReady) { (& $D "V2luZG93cyBQb3dlclNoZWxsIDUuMSDmiJYgUG93ZXJTaGVsbCA3IOWPr+eUqOOAgg==") } else { (& $D "57y65bCRIFdpbmRvd3Mg5Zu+5b2i55WM6Z2i57uE5Lu244CC") }
    })

    Write-Log "Self-test: writable state and temp folders"
    $storageReady = (Test-DirectoryWritable -Path $Script:StateRoot) -and (Test-DirectoryWritable -Path $env:TEMP)
    $checks.Add([PSCustomObject]@{
        Name = (& $D "6K6+572u5LiO5Li05pe255uu5b2V")
        Passed = $storageReady
        Required = $true
        Detail = if ($storageReady) { (& $D "55uu5b2V5Y+v5YaZ77ya") + $Script:StateRoot + "; " + $env:TEMP } else { (& $D "55uu5b2V5LiN5Y+v5YaZ77ya") + $Script:StateRoot + "; " + $env:TEMP }
    })

    Write-Log "Self-test: Python runtime"
    $pythonPath = ""
    try {
        $pythonPath = Resolve-Python
        $checks.Add([PSCustomObject]@{
            Name = (& $D "UHl0aG9uIDMuMTArIOi/kOihjOeOr+Wigw==")
            Passed = $true
            Required = $true
            Detail = (& $D "5bey5om+5Yiw77ya") + $pythonPath
        })
    }
    catch {
        $checks.Add([PSCustomObject]@{
            Name = (& $D "UHl0aG9uIDMuMTArIOi/kOihjOeOr+Wigw==")
            Passed = $false
            Required = $true
            Detail = (& $D "6ZyA6KaBIFB5dGhvbiAzLjEwIOaIluabtOmrmOeJiOacrOOAgg==")
        })
    }

    if (-not [string]::IsNullOrWhiteSpace($pythonPath)) {
        Write-Log "Self-test: pinned Python dependencies"
        try {
            if ($AllowDependencyInstall) {
                Ensure-PythonDependencies -PythonExe $pythonPath
            }
            else {
                Ensure-PythonDependencies -PythonExe $pythonPath -NonInteractive
            }
            $ffmpegCode = "import imageio_ffmpeg, pathlib, sys; p=pathlib.Path(imageio_ffmpeg.get_ffmpeg_exe()); sys.exit(0 if p.is_file() else 1)"
            & $pythonPath -c $ffmpegCode 2>$null | Out-Null
            if ($LASTEXITCODE -ne 0) {
                throw "ffmpeg"
            }
            $checks.Add([PSCustomObject]@{
                Name = (& $D "UHl0aG9uIOS+nei1lg==")
                Passed = $true
                Required = $true
                Detail = (& $D "57uE5Lu25a6M5pW05LiU54mI5pys5q2j56Gu44CC")
            })
        }
        catch {
            $checks.Add([PSCustomObject]@{
                Name = (& $D "UHl0aG9uIOS+nei1lg==")
                Passed = $false
                Required = $true
                Detail = (& $D "57uE5Lu254mI5pys5LiN56ym5ZCI5Y+R5biD6KaB5rGC77ya") + $_.Exception.Message
            })
        }
    }
    else {
        $checks.Add([PSCustomObject]@{
            Name = (& $D "UHl0aG9uIOS+nei1lg==")
            Passed = $false
            Required = $true
            Detail = (& $D "5peg5rOV5qOA5p+l77ya") + "Python"
        })
    }

    Write-Log "Self-test: Apple Music package"
    try {
        $appleMusic = Get-AppleMusicPackageInfo
        $checks.Add([PSCustomObject]@{
            Name = (& $D "QXBwbGUgTXVzaWMg5bqU55So")
            Passed = ($null -ne $appleMusic)
            Required = $true
            Detail = if ($appleMusic) { (& $D "5bey5a6J6KOF77yM54mI5pys77ya") + $appleMusic.Version } else { (& $D "5pyq5a6J6KOFIEFwcGxlIE11c2ljIGZvciBXaW5kb3dz44CC") }
        })
    }
    catch {
        $checks.Add([PSCustomObject]@{
            Name = (& $D "QXBwbGUgTXVzaWMg5bqU55So")
            Passed = $false
            Required = $true
            Detail = (& $D "5peg5rOV5qOA5p+l77ya") + $_.Exception.Message
        })
    }

    Write-Log "Self-test: Apple Music auto-import folder"
    $autoAddFolder = ""
    $savedConfig = Read-Config
    if ($savedConfig.AutoAddFolder -and (Test-Path -LiteralPath $savedConfig.AutoAddFolder)) {
        $autoAddFolder = [string]$savedConfig.AutoAddFolder
    }
    if ([string]::IsNullOrWhiteSpace($autoAddFolder)) {
        $autoAddFolder = Get-AppleMusicAutoAddCandidates | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
    }
    $autoAddWritable = (-not [string]::IsNullOrWhiteSpace($autoAddFolder)) -and (Test-DirectoryWritable -Path $autoAddFolder)
    $checks.Add([PSCustomObject]@{
        Name = (& $D "6Ieq5Yqo5a+85YWl55uu5b2V")
        Passed = $autoAddWritable
        Required = $true
        Detail = if ($autoAddWritable) { (& $D "6Ieq5Yqo5a+85YWl55uu5b2V77ya") + $autoAddFolder } elseif ($autoAddFolder) { (& $D "6Ieq5Yqo5a+85YWl55uu5b2V5a2Y5Zyo5L2G5LiN5Y+v5YaZ77ya") + $autoAddFolder } else { (& $D "5bCa5pyq5om+5Yiw6Ieq5Yqo5a+85YWl55uu5b2V44CC6K+35YWI5omT5byAIEFwcGxlIE11c2ljIOS4gOasoeOAgg==") }
    })

    Write-Log "Self-test: metadata network"
    $metadataOnline = Test-MetadataConnectivity
    $checks.Add([PSCustomObject]@{
        Name = (& $D "5Zyo57q/6LWE5paZ5pCc57Si")
        Passed = $metadataOnline
        Required = $false
        Detail = if ($metadataOnline) { (& $D "6Iez5bCR5LiA5Liq6LWE5paZ5p2l5rqQ5Y+v6K6/6Zeu44CC") } else { (& $D "5Zyo57q/6LWE5paZ5p2l5rqQ5pqC5pe25LiN5Y+v6K6/6Zeu77yb5pys5Zyw5paH5Lu25LuN5Y+v5omL5Yqo5aGr5YaZ6LWE5paZ5ZCO5a+85YWl44CC") }
    })

    $checks.Add([PSCustomObject]@{
        Name = (& $D "5LqR56uv6LWE5paZ5bqT")
        Passed = $false
        Required = $false
        Detail = (& $D "5peg5rOV6Ieq5Yqo5qOA5p+l77yb55SxIEFwcGxlIE11c2ljIOeZu+W9leOAgeiuoumYheS4juWQjOatpei1hOaWmeW6k+eKtuaAgeWGs+WumuOAgg==")
    })

    $ready = @($checks | Where-Object { $_.Required -and -not $_.Passed }).Count -eq 0
    return [PSCustomObject]@{
        Ready = $ready
        ToolVersion = $Script:AppVersion
        Architecture = $env:PROCESSOR_ARCHITECTURE
        PowerShellVersion = $PSVersionTable.PSVersion.ToString()
        StateRoot = $Script:StateRoot
        Capabilities = [PSCustomObject]@{
            LocalImport = $ready
            OnlineMetadata = $metadataOnline
            CloudSync = $null
        }
        Checks = @($checks | ForEach-Object { $_ })
    }
}

function Show-EnvironmentSelfTest {
    param([object]$Report)
    $D = { param([string]$B64) Decode-Utf8 $B64 }
    $lines = New-Object System.Collections.Generic.List[string]
    if ($Report.Ready) {
        $lines.Add((& $D "546v5aKD5qOA5p+l6YCa6L+H77yM5Y+v5Lul6L+Q6KGM44CC"))
    }
    else {
        $lines.Add((& $D "546v5aKD5qOA5p+l5pyq6YCa6L+H77ya"))
    }
    $lines.Add("")
    foreach ($check in $Report.Checks) {
        $prefix = if ($check.Passed) { "[OK]" } elseif ($check.Required) { "[X]" } else { "[!]" }
        $lines.Add("$prefix $($check.Name)`r`n$($check.Detail)")
        $lines.Add("")
    }
    Show-Message (($lines -join "`r`n").Trim()) "Apple Music Auto Import"
}

function Run-Python {
    param([string]$Code, [string[]]$PyArgs = @())
    $python = Resolve-Python
    Ensure-PythonDependencies -PythonExe $python
    $tmp = Join-Path $env:TEMP ("am-auto-import-" + [guid]::NewGuid().ToString() + ".py")
    $errFile = Join-Path $env:TEMP ("am-auto-import-" + [guid]::NewGuid().ToString() + ".err")
    $outFile = Join-Path $env:TEMP ("am-auto-import-" + [guid]::NewGuid().ToString() + ".out")
    # Native PowerShell command parsing corrupts quoted YouTube descriptions.
    # Pass every value as UTF-8 Base64 so Python receives the original arguments.
    $bootstrap = @'
import base64
import os
import sys

sys.argv = [sys.argv[0]] + [base64.b64decode(value[4:]).decode("utf-8") for value in sys.argv[1:]]
stdout_path = os.environ.get("APPLE_MUSIC_AUTO_IMPORT_STDOUT_FILE", "")
if stdout_path:
    sys.stdout = open(stdout_path, "w", encoding="utf-8", newline="")
'@
    $encodedArgs = @($PyArgs | ForEach-Object {
        "b64_" + [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes([string]$_))
    })
    Set-Content -LiteralPath $tmp -Value ($bootstrap + "`n" + $Code) -Encoding UTF8
    $hadStdoutFile = Test-Path Env:APPLE_MUSIC_AUTO_IMPORT_STDOUT_FILE
    $oldStdoutFile = [string]$env:APPLE_MUSIC_AUTO_IMPORT_STDOUT_FILE
    $env:APPLE_MUSIC_AUTO_IMPORT_STDOUT_FILE = $outFile
    try {
        $oldPreference = $ErrorActionPreference
        $ErrorActionPreference = "Continue"
        $nativeOutput = & $python $tmp @encodedArgs 2> $errFile
        $exitCode = $LASTEXITCODE
        $ErrorActionPreference = $oldPreference
        $output = ""
        if (Test-Path -LiteralPath $outFile) {
            $output = Get-Content -LiteralPath $outFile -Raw -Encoding UTF8
        }
        elseif ($nativeOutput) {
            $output = ($nativeOutput | Out-String)
        }
        $stderr = ""
        if (Test-Path -LiteralPath $errFile) {
            $stderr = (Get-Content -LiteralPath $errFile -Raw -ErrorAction SilentlyContinue)
        }
        if (-not [string]::IsNullOrWhiteSpace($stderr)) {
            Write-Log ("Python stderr: " + $stderr.Trim())
        }
        if ($exitCode -ne 0) {
            $message = (($output | Out-String).Trim() + "`n" + $stderr).Trim()
            if ([string]::IsNullOrWhiteSpace($message)) {
                $message = "Python helper failed with exit code $exitCode"
            }
            throw $message
        }
        return ($output | Out-String)
    }
    finally {
        if ($hadStdoutFile) {
            $env:APPLE_MUSIC_AUTO_IMPORT_STDOUT_FILE = $oldStdoutFile
        }
        else {
            Remove-Item Env:APPLE_MUSIC_AUTO_IMPORT_STDOUT_FILE -ErrorAction SilentlyContinue
        }
        Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue
        Remove-Item -LiteralPath $errFile -Force -ErrorAction SilentlyContinue
        Remove-Item -LiteralPath $outFile -Force -ErrorAction SilentlyContinue
    }
}

function ConvertTo-LyricCacheComparableText {
    param([AllowEmptyString()][string]$Text)

    if ([string]::IsNullOrWhiteSpace($Text)) {
        return ""
    }
    $value = $Text.Normalize([System.Text.NormalizationForm]::FormKC).ToLowerInvariant()
    try {
        Add-Type -AssemblyName Microsoft.VisualBasic -ErrorAction Stop | Out-Null
        $value = [Microsoft.VisualBasic.Strings]::StrConv(
            $value,
            [Microsoft.VisualBasic.VbStrConv]::SimplifiedChinese,
            0x0804
        )
    }
    catch {
        # Exact normalized matching still works on systems without Chinese conversion support.
    }
    return [regex]::Replace($value, "[^\p{L}\p{Nd}]", "")
}

function Restore-PreviewLyricsFromCache {
    param([Parameter(Mandatory = $true)][object]$Metadata)

    $missingFields = @("lyrics", "composer", "lyricist", "arranger") | Where-Object {
        -not ($Metadata.PSObject.Properties.Name -contains $_) -or
        [string]::IsNullOrWhiteSpace([string]$Metadata.$_)
    }
    if ($missingFields.Count -eq 0) {
        return $Metadata
    }

    $titleKey = ConvertTo-LyricCacheComparableText ([string]$Metadata.title)
    $artistKeys = @(
        [string]$Metadata.artist
        [string]$Metadata.original_artist
        [string]$Metadata.album_artist
    ) | ForEach-Object { ConvertTo-LyricCacheComparableText $_ } | Where-Object { $_ } | Select-Object -Unique
    if (-not $titleKey -or $artistKeys.Count -eq 0) {
        return $Metadata
    }

    $cacheRoots = New-Object System.Collections.Generic.List[string]
    $cacheRoots.Add((Join-Path $Script:StateRoot "lyrics-cache"))
    $stableRoot = Join-Path ([Environment]::GetFolderPath("UserProfile")) "AppData\Local\AppleMusicAutoImport\lyrics-cache"
    if (-not [string]::IsNullOrWhiteSpace($stableRoot) -and -not $cacheRoots.Contains($stableRoot)) {
        $cacheRoots.Add($stableRoot)
    }

    foreach ($cacheRoot in $cacheRoots) {
        if (-not (Test-Path -LiteralPath $cacheRoot -PathType Container)) {
            continue
        }
        $cacheFiles = @(Get-ChildItem -LiteralPath $cacheRoot -File -Filter "*.json" -ErrorAction SilentlyContinue |
            Sort-Object LastWriteTime -Descending |
            Select-Object -First 500)
        foreach ($cacheFile in $cacheFiles) {
            try {
                $cached = Get-Content -LiteralPath $cacheFile.FullName -Raw -Encoding UTF8 | ConvertFrom-Json
            }
            catch {
                continue
            }
            if ((ConvertTo-LyricCacheComparableText ([string]$cached.title)) -ne $titleKey) {
                continue
            }
            $cachedArtistKey = ConvertTo-LyricCacheComparableText ([string]$cached.artist)
            if (-not $cachedArtistKey -or $artistKeys -notcontains $cachedArtistKey) {
                continue
            }

            $restored = New-Object System.Collections.Generic.List[string]
            foreach ($field in @("lyrics", "composer", "lyricist", "arranger")) {
                $cachedValue = [string]$cached.$field
                if ([string]::IsNullOrWhiteSpace($cachedValue)) {
                    continue
                }
                $currentValue = if ($Metadata.PSObject.Properties.Name -contains $field) { [string]$Metadata.$field } else { "" }
                if (-not [string]::IsNullOrWhiteSpace($currentValue)) {
                    continue
                }
                if ($Metadata.PSObject.Properties.Name -contains $field) {
                    $Metadata.$field = $cachedValue
                }
                else {
                    $Metadata | Add-Member -NotePropertyName $field -NotePropertyValue $cachedValue
                }
                $restored.Add($field)
            }
            if ($restored.Count -gt 0) {
                Write-Log ("Restored preview cache fields for $($Metadata.title) - $($Metadata.artist): " + ($restored -join ","))
                break
            }
        }
        if (-not [string]::IsNullOrWhiteSpace([string]$Metadata.lyrics)) {
            break
        }
    }
    return $Metadata
}

function Download-VideoUrls {
    param(
        [string[]]$Urls,
        [string]$PythonExe,
        [bool]$PlaylistMode = $false,
        [int]$MaxPlaylistItems = 0
    )

    if (-not $Urls -or $Urls.Count -eq 0) {
        return @()
    }

    $D = { param([string]$B64) [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($B64)) }
    Write-Log (& $D "5q2j5Zyo5LiL6L29572R6aG16Z+z6aKR77yM6K+356iN562JLi4u")

    $downloadRoot = Join-Path $env:TEMP "AppleMusicAutoImportDownloads"
    $resultFile = Join-Path $env:TEMP ("AppleMusicAutoImportDownload-" + [guid]::NewGuid().ToString() + ".json")
    New-Item -ItemType Directory -Path $downloadRoot -Force | Out-Null

    $code = @'
import json
import os
import re
import sys
import urllib.parse
import urllib.request
from pathlib import Path

import yt_dlp

download_root = Path(sys.argv[1])
result_file = Path(sys.argv[2])
download_playlist = sys.argv[3] == "1"
try:
    max_playlist_items = int(sys.argv[4] or "0")
except Exception:
    max_playlist_items = 0
urls = sys.argv[5:]
download_root.mkdir(parents=True, exist_ok=True)
downloaded = []
errors = []
records = []
radio_items_by_id = {}

USER_AGENT = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126 Safari/537.36"

def query_value(url, name):
    try:
        parsed = urllib.parse.urlparse(url)
        values = urllib.parse.parse_qs(parsed.query).get(name) or []
        return values[0] if values else ""
    except Exception:
        return ""

def is_youtube_auto_mix(url):
    list_id = query_value(url, "list")
    return bool(list_id and list_id.upper().startswith("RD"))

def text_value(node):
    if not node:
        return ""
    if isinstance(node, str):
        return node
    if isinstance(node, dict):
        if node.get("simpleText"):
            return node.get("simpleText") or ""
        runs = node.get("runs") or []
        return "".join((run.get("text") or "") for run in runs if isinstance(run, dict))
    return ""

def split_music_byline(byline):
    parts = [part.strip() for part in re.split(r"\s*[\u2022]\s*", byline or "") if part.strip()]
    artist = parts[0] if len(parts) >= 1 else ""
    album = parts[1] if len(parts) >= 2 else ""
    year = ""
    for part in reversed(parts):
        m = re.search(r"(19|20)\d{2}", part)
        if m:
            year = m.group(0)
            break
    return artist, album, year

def find_youtube_api_key():
    for url in ("https://music.youtube.com/", "https://www.youtube.com/"):
        try:
            req = urllib.request.Request(url, headers={"User-Agent": USER_AGENT, "Accept-Language": "zh-CN,zh;q=0.9,en;q=0.8"})
            html = urllib.request.urlopen(req, timeout=20).read().decode("utf-8", "replace")
            m = re.search(r'"INNERTUBE_API_KEY":"([^"]+)"', html)
            if m:
                return m.group(1)
        except Exception:
            pass
    return ""

def collect_playlist_panel_items(data):
    renderers = []
    def walk(obj):
        if isinstance(obj, dict):
            renderer = obj.get("playlistPanelVideoRenderer")
            if renderer:
                renderers.append(renderer)
            for value in obj.values():
                walk(value)
        elif isinstance(obj, list):
            for value in obj:
                walk(value)
    walk(data)

    out = []
    seen = set()
    for index, renderer in enumerate(renderers, 1):
        endpoint = renderer.get("navigationEndpoint") or {}
        watch = endpoint.get("watchEndpoint") or {}
        video_id = renderer.get("videoId") or watch.get("videoId") or ""
        if not video_id or video_id in seen:
            continue
        seen.add(video_id)
        byline = text_value(renderer.get("longBylineText") or renderer.get("shortBylineText"))
        artist, album, year = split_music_byline(byline)
        title = text_value(renderer.get("title")) or video_id
        out.append({
            "id": video_id,
            "title": title,
            "artist": artist,
            "album": album,
            "release_year": year,
            "playlist_index": index,
        })
    return out

def fetch_youtube_auto_mix_items(source_url):
    list_id = query_value(source_url, "list")
    if not list_id:
        return []
    video_id = query_value(source_url, "v")
    api_key = find_youtube_api_key()
    if not api_key:
        return []
    endpoint = "https://www.youtube.com/youtubei/v1/next?key=" + api_key
    attempts = []
    if video_id:
        attempts.append({"videoId": video_id, "playlistId": list_id})
    attempts.append({"playlistId": list_id})
    for extra in attempts:
        payload = {
            "context": {
                "client": {
                    "clientName": "WEB_REMIX",
                    "clientVersion": "1.20260623.01.00",
                    "hl": "zh-CN",
                    "gl": "HK",
                }
            }
        }
        payload.update(extra)
        try:
            req = urllib.request.Request(
                endpoint,
                data=json.dumps(payload).encode("utf-8"),
                headers={
                    "User-Agent": USER_AGENT,
                    "Content-Type": "application/json",
                    "Origin": "https://music.youtube.com",
                    "Referer": "https://music.youtube.com/playlist?list=" + urllib.parse.quote(list_id),
                },
            )
            data = json.loads(urllib.request.urlopen(req, timeout=30).read().decode("utf-8", "replace"))
            items = collect_playlist_panel_items(data)
            if len(items) > 1:
                return items
        except Exception:
            continue
    return []

def compact_info(info, playlist_info=None):
    if not info:
        return {}
    playlist_info = playlist_info or {}
    radio_item = radio_items_by_id.get(info.get("id") or "") or {}
    entries = playlist_info.get("entries") or []
    playlist_count = (
        info.get("playlist_count")
        or info.get("n_entries")
        or playlist_info.get("playlist_count")
        or playlist_info.get("n_entries")
        or radio_item.get("playlist_count")
        or (len(entries) if entries else "")
        or ""
    )
    return {
        "id": info.get("id") or "",
        "title": radio_item.get("title") or info.get("title") or "",
        "fulltitle": info.get("fulltitle") or "",
        "alt_title": info.get("alt_title") or "",
        "uploader": info.get("uploader") or "",
        "channel": info.get("channel") or "",
        "artist": radio_item.get("artist") or info.get("artist") or "",
        "track": radio_item.get("title") or info.get("track") or "",
        "album": radio_item.get("album") or info.get("album") or "",
        "release_year": radio_item.get("release_year") or info.get("release_year") or "",
        "release_date": info.get("release_date") or "",
        "upload_date": info.get("upload_date") or "",
        "webpage_url": info.get("webpage_url") or "",
        "thumbnail": info.get("thumbnail") or "",
        "playlist": radio_item.get("playlist_title") or info.get("playlist") or playlist_info.get("playlist") or playlist_info.get("title") or "",
        "playlist_title": radio_item.get("playlist_title") or info.get("playlist_title") or playlist_info.get("playlist_title") or playlist_info.get("title") or "",
        "playlist_id": radio_item.get("playlist_id") or info.get("playlist_id") or playlist_info.get("id") or "",
        "playlist_uploader": radio_item.get("artist") or info.get("playlist_uploader") or playlist_info.get("uploader") or "",
        "playlist_channel": info.get("playlist_channel") or playlist_info.get("channel") or "",
        "playlist_index": radio_item.get("playlist_index") or info.get("playlist_index") or info.get("playlist_autonumber") or "",
        "playlist_count": playlist_count,
        "playlist_webpage_url": radio_item.get("playlist_webpage_url") or playlist_info.get("webpage_url") or "",
        "description": (info.get("description") or "")[:20000],
    }

def write_sidecar(path, info, playlist_info=None):
    sidecar = Path(str(path) + ".aminfo.json")
    sidecar.write_text(json.dumps(compact_info(info, playlist_info), ensure_ascii=False, indent=2), encoding="utf-8")

def add_download(path, info, playlist_info=None):
    if not path or not Path(path).exists():
        return False
    resolved = str(Path(path).resolve())
    downloaded.append(resolved)
    write_sidecar(resolved, info, playlist_info)
    records.append({"file": resolved, "info": compact_info(info, playlist_info)})
    return True

def browser_cookie_failure(exc):
    message = str(exc or "").lower()
    return any(marker in message for marker in (
        "could not copy chrome cookie database",
        "could not access chrome cookie database",
        "failed to decrypt with dpapi",
        "failed to decrypt cookies",
        "cookie decryption failed",
    ))

expanded_urls = []
force_single_urls = set()
for url in urls:
    if download_playlist and is_youtube_auto_mix(url):
        items = fetch_youtube_auto_mix_items(url)
        if not items:
            errors.append(f"{url}: could not expand YouTube automatic Mix/Radio queue")
            continue
        if max_playlist_items > 0:
            items = items[:max_playlist_items]
        list_id = query_value(url, "list")
        total = len(items)
        for item in items:
            video_id = item.get("id") or ""
            if not video_id:
                continue
            item["playlist_count"] = total
            item["playlist_id"] = list_id
            item["playlist_title"] = "YouTube Auto Mix"
            item["playlist_webpage_url"] = url
            radio_items_by_id[video_id] = item
            single_url = "https://www.youtube.com/watch?v=" + video_id
            expanded_urls.append(single_url)
            force_single_urls.add(single_url)
    else:
        expanded_urls.append(url)

for url in expanded_urls:
    before = {p.resolve() for p in download_root.glob("*") if p.is_file() and not p.name.endswith(".aminfo.json")}
    template = "%(title).180s [%(id)s].%(ext)s"
    if download_playlist and url not in force_single_urls:
        template = "%(playlist_index)03d - %(title).160s [%(id)s].%(ext)s"
    options = {
        "format": "bestaudio/best",
        "outtmpl": str(download_root / template),
        "noplaylist": (not download_playlist) or (url in force_single_urls),
        "quiet": True,
        "no_warnings": True,
        "noprogress": True,
        "windowsfilenames": True,
        "restrictfilenames": False,
        "ignoreerrors": bool(download_playlist),
    }
    # YouTube and Bilibili increasingly reject anonymous download requests.
    # Reuse the user's existing Chrome session when the source is from either site.
    parsed_host = urllib.parse.urlparse(url).netloc.lower()
    if "youtube.com" in parsed_host or "youtu.be" in parsed_host or "bilibili.com" in parsed_host:
        options["cookiesfrombrowser"] = ("chrome",)
    if download_playlist and max_playlist_items > 0 and url not in force_single_urls:
        options["playlistend"] = max_playlist_items
    try:
        try:
            with yt_dlp.YoutubeDL(options) as ydl:
                info = ydl.extract_info(url, download=True)
        except Exception as exc:
            # Chrome can lock its cookie database or Windows can reject DPAPI
            # decryption. Public media should still get an anonymous retry.
            if "cookiesfrombrowser" not in options or not browser_cookie_failure(exc):
                raise
            options.pop("cookiesfrombrowser", None)
            with yt_dlp.YoutubeDL(options) as ydl:
                info = ydl.extract_info(url, download=True)
        if not info:
            continue
        added = 0
        for entry in (info.get("entries") or []):
            if not entry:
                continue
            for item in (entry.get("requested_downloads") or []):
                if add_download(item.get("filepath"), entry, info):
                    added += 1
        requested = info.get("requested_downloads") or []
        for item in requested:
            if add_download(item.get("filepath"), info):
                added += 1
        if added == 0:
            after = {p.resolve() for p in download_root.glob("*") if p.is_file() and not p.name.endswith(".aminfo.json")}
            new_files = sorted(after - before, key=lambda p: p.stat().st_mtime, reverse=True)
            if download_playlist:
                for item_path in reversed(new_files):
                    add_download(str(item_path), info)
            elif new_files:
                add_download(str(new_files[0]), info)
    except Exception as exc:
        errors.append(f"{url}: {exc}")

seen = set()
unique = []
for path in downloaded:
    if path not in seen and Path(path).exists():
        seen.add(path)
        unique.append(path)

result_file.write_text(json.dumps({"files": unique, "records": records, "errors": errors}, ensure_ascii=True), encoding="utf-8")
if errors and not unique:
    sys.exit(1)
'@

    try {
        $playlistFlag = if ($PlaylistMode) { "1" } else { "0" }
        Run-Python -Code $code -PyArgs (@($downloadRoot, $resultFile, $playlistFlag, [string]$MaxPlaylistItems) + $Urls) | Out-Null
        if (-not (Test-Path -LiteralPath $resultFile)) {
            throw "Download helper did not write a result file."
        }
        $json = Get-Content -LiteralPath $resultFile -Raw -Encoding UTF8
        $result = $json | ConvertFrom-Json
        if ($result.errors -and $result.errors.Count -gt 0) {
            Write-Log ("URL download partial errors: " + (($result.errors | Out-String).Trim()))
        }
        $files = @($result.files) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
        if ($files.Count -eq 0) {
            $errorText = (($result.errors | Out-String).Trim())
            if ([string]::IsNullOrWhiteSpace($errorText)) {
                $errorText = "No audio file was downloaded."
            }
            throw $errorText
        }
        $hasListUrl = @($Urls | Where-Object { -not [string]::IsNullOrWhiteSpace((Get-UrlQueryValue -Url $_ -Name "list")) }).Count -gt 0
        if ($PlaylistMode -and $hasListUrl -and $files.Count -le 1) {
            throw (& $D "5pKt5pS+5YiX6KGo5rKh5pyJ5bGV5byA77yM5Y+q5LiL6L295Yiw5LiA6aaW44CC6L+Z5Liq6ZO+5o6l5Y+v6IO95LiN5piv5pmu6YCa5pKt5pS+5YiX6KGo44CC")
        }
        return $files
    }
    catch {
        $downloadError = $_.Exception.Message
        if ($downloadError -match "(?i)(sign in to confirm|HTTP Error 403|Could not copy Chrome cookie database)") {
            $downloadError = (& $D "5bmz5Y+w5ouS57ud5LqG5q2k5qyh5LiL6L2944CC6IulIENocm9tZSDmraPlnKjlvIDlkK/vvIzor7flrozlhajlhbPpl63miYDmnIkgQ2hyb21lIOeql+WPo+WQjumHjeivle+8m+WQpuWImeivt+eojeWQjumHjeivleaIluaUueeUqOacrOWcsOmfs+mikeaWh+S7tuOAgg==")
        }
        throw ((& $D "5LiL6L295aSx6LSl77ya") + $downloadError)
    }
    finally {
        Remove-Item -LiteralPath $resultFile -Force -ErrorAction SilentlyContinue
    }
}

function Get-FirstRegexGroup {
    param([string]$Text, [string[]]$Patterns)
    if ([string]::IsNullOrWhiteSpace($Text)) {
        return ""
    }
    foreach ($pattern in $Patterns) {
        $m = [regex]::Match($Text, $pattern, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase -bor [System.Text.RegularExpressions.RegexOptions]::Multiline)
        if ($m.Success -and $m.Groups.Count -gt 1) {
            $value = $m.Groups[1].Value.Trim()
            if (-not [string]::IsNullOrWhiteSpace($value)) {
                $fullWidthColon = [string][char]0xFF1A
                return ($value -replace '[\r\n]+.*$', '').Trim((" `t-:" + $fullWidthColon + "|"))
            }
        }
    }
    return ""
}

function Clean-VideoMetaText {
    param([string]$Text)
    if ([string]::IsNullOrWhiteSpace($Text)) {
        return ""
    }
    $text = $Text -replace 'https?://\S+', ' '
    $text = $text -replace '#\S+', ' '
    $text = $text -replace '\s+', ' '
    return $text.Trim()
}

function Get-TextBetweenChars {
    param(
        [string]$Text,
        [int]$LeftCode,
        [int]$RightCode
    )
    if ([string]::IsNullOrWhiteSpace($Text)) {
        return ""
    }
    $left = [string][char]$LeftCode
    $right = [string][char]$RightCode
    $start = $Text.IndexOf($left)
    if ($start -lt 0) {
        return ""
    }
    $end = $Text.IndexOf($right, $start + 1)
    if ($end -le $start) {
        return ""
    }
    return $Text.Substring($start + 1, $end - $start - 1).Trim()
}

function Remove-LeadingBracketNote {
    param([string]$Text)
    $value = [string]$Text
    $leftBookBracket = [string][char]0x3010
    $rightBookBracket = [string][char]0x3011
    $changed = $true
    while ($changed) {
        $changed = $false
        $next = ($value -replace '^\s*\[[^\]]*\]\s*', '').TrimStart()
        if ($next -ne $value) {
            $value = $next
            $changed = $true
        }
        if ($value.StartsWith($leftBookBracket) -and $value.Contains($rightBookBracket)) {
            $end = $value.IndexOf($rightBookBracket)
            if ($end -ge 0) {
                $value = $value.Substring($end + 1).TrimStart()
                $changed = $true
            }
        }
    }
    return $value
}

function Clean-VideoTitleForSongName {
    param([string]$Text)
    if ([string]::IsNullOrWhiteSpace($Text)) {
        return ""
    }
    $value = Clean-VideoMetaText $Text
    $bookTitle = Get-TextBetweenChars $value 0x300A 0x300B
    if (-not [string]::IsNullOrWhiteSpace($bookTitle)) {
        return ($bookTitle -replace '\s+', ' ').Trim()
    }
    $value = Remove-LeadingBracketNote $value
    $value = $value -replace '\s*\[[A-Za-z0-9_-]{6,}\]\s*$', ''
    $value = $value -replace '(?i)\b(4k|8k|hd|hq|mv|live|cover|official|audio|video)\b', ' '
    $value = $value -replace '\u9ad8\u6e05|\u4fee\u5fa9|\u4fee\u590d|\u5b98\u651d|\u5b98\u6444|\u73fe\u5834\u7248|\u73b0\u573a\u7248|\u73fe\u5834|\u73b0\u573a|\u6f14\u5531\u6703|\u6f14\u5531\u4f1a|\u53f2\u4e0a\u6700\u5f37|\u53f2\u4e0a\u6700\u5f3a', ' '
    $value = $value -replace '\s+', ' '
    return $value.Trim(" `t-_")
}

function Get-PreferredArtistName {
    param([string]$Text)
    $value = ([string]$Text).Trim()
    if ([string]::IsNullOrWhiteSpace($value)) {
        return ""
    }
    $match = [regex]::Match($value, '^\s*([\u3400-\u9fff]{2,8})(?:\s*[A-Za-z].*)$')
    if ($match.Success) {
        return $match.Groups[1].Value.Trim()
    }
    return $value
}

function Clean-PerformanceArtistName {
    param([string]$Text)
    $value = ([string]$Text).Trim()
    if ([string]::IsNullOrWhiteSpace($value)) {
        return ""
    }
    # Keep the performer while removing venue, tour, and event text that often
    # sits between the artist and a book-title song name.
    $value = $value -replace '(?i)\s*(?:\u4e16\u754c\s*(?:\u5de1\u56de|\u5de1\u8ff4)\s*\u6f14\u5531[\u4f1a\u6703]|(?:\u5de1\u56de|\u5de1\u8ff4)\s*\u6f14\u5531[\u4f1a\u6703]|\u6f14\u5531[\u4f1a\u6703]|\u4e16\u754c\u5de1\u6f14|\u5de1\u6f14|\u97f3\u4e50\u8282|\u97f3\u6a02\u7bc0|\u6b4c\u53cb[\u4f1a\u6703]|world\s+tour|concert|festival|live\s+at).*$',''
    $value = ($value -replace '\s+', ' ').Trim(" `t-_:|,./")
    return Get-PreferredArtistName $value
}

function Get-LikelyArtistFragment {
    param([string]$Text)
    if ([string]::IsNullOrWhiteSpace($Text)) {
        return ""
    }
    $value = Clean-VideoMetaText $Text
    $value = Remove-LeadingBracketNote $value
    $value = $value -replace '\s*\[[A-Za-z0-9_-]{6,}\]\s*$', ''
    $value = $value -replace '^[\s\-\x2013\x2014\|\uFF5C:：_]+|[\s\-\x2013\x2014\|\uFF5C:：_]+$', ''
    $value = $value -replace '^[\s''"‘’“”\(\)\[\]]+|[\s''"‘’“”\(\)\[\]]+$', ''
    $value = Clean-PerformanceArtistName $value
    if ([string]::IsNullOrWhiteSpace($value) -or $value.Length -gt 40) {
        return ""
    }
    if ($value -notmatch '[\p{L}\p{N}]') {
        return ""
    }
    if ($value -match '(?i)(?:official\s*(?:music\s*)?video|lyrics?|\bmv\b|\baudio\b|\bvideo\b|\bcover\b|\blive\b|\u73fe\u5834|\u73b0\u573a|\u6f14\u5531\u6703|\u6f14\u5531\u4f1a|\u9ad8\u6e05|\u7121\u640d|\u65e0\u635f|\u97f3\u8cea|\u97f3\u8d28|\u5b8c\u6574\u7248|\u7d14\u4eab|\u7eaf\u4eab|\u7247\u6bb5|reaction)') {
        return ""
    }
    return $value
}

function Get-DecorativeSongTitle {
    param([string]$Text)
    $value = Get-TextBetweenChars $Text 0x3010 0x3011
    if ([string]::IsNullOrWhiteSpace($value)) {
        return ""
    }
    if ($value -match '(?i)^\s*(?:4k|8k|hd|hq|mv|live|cover|official|audio|video|\u9ad8\u6e05|\u4fee\u5fa9|\u4fee\u590d)\s*$') {
        return ""
    }
    $cjkTitle = [regex]::Match($value, '^\s*([\u3400-\u9fff0-9:：·]{2,})(?=\s+[A-Za-z])')
    if ($cjkTitle.Success) {
        return $cjkTitle.Groups[1].Value.Trim()
    }
    if ($value.Length -le 60) {
        return ($value -replace '\s+', ' ').Trim()
    }
    return ""
}

function Clean-PlaylistAlbumTitle {
    param([string]$Text)
    if ([string]::IsNullOrWhiteSpace($Text)) {
        return ""
    }
    $value = Clean-VideoMetaText $Text
    $value = $value -replace '^\s*(?:\u5408\u8f2f|\u5408\u8f91|playlist|album|mix)\s*[-:\uFF1A]\s*', ''
    $value = $value -replace '\s*-\s*topic\s*$', ''
    $value = $value -replace '\s+', ' '
    return $value.Trim(" `t-_")
}

function Infer-ArtistFromTitle {
    param([string]$Text)
    if ([string]::IsNullOrWhiteSpace($Text)) {
        return ""
    }
    $Text = Remove-LeadingBracketNote $Text
    $prefix = ""
    $leftTitle = [string][char]0x300A
    $rightTitle = [string][char]0x300B
    $leftDecorative = [string][char]0x3010
    $rightDecorative = [string][char]0x3011
    $titleStart = $Text.IndexOf($leftTitle)
    $titleEnd = if ($titleStart -ge 0) { $Text.IndexOf($rightTitle, $titleStart + 1) } else { -1 }
    $decorativeStart = $Text.IndexOf($leftDecorative)
    $decorativeEnd = if ($decorativeStart -ge 0) { $Text.IndexOf($rightDecorative, $decorativeStart + 1) } else { -1 }
    if (($titleStart -lt 0 -or ($decorativeStart -ge 0 -and $decorativeStart -lt $titleStart)) -and $decorativeEnd -gt $decorativeStart) {
        $titleStart = $decorativeStart
        $titleEnd = $decorativeEnd
    }
    if ($titleStart -ge 0 -and $titleEnd -gt $titleStart) {
        $prefix = $Text.Substring(0, $titleStart)
    }
    else {
        $parts = [regex]::Split($Text, '\s*(?:-|\x2013|\x2014|\|)\s*')
        if ($parts.Count -ge 2) {
            $prefix = $parts[0]
        }
    }
    $leftBookBracket = [string][char]0x3010
    $rightBookBracket = [string][char]0x3011
    $leftFullParen = [string][char]0xFF08
    $rightFullParen = [string][char]0xFF09
    $fullWidthColon = [string][char]0xFF1A
    $prefix = Remove-LeadingBracketNote $prefix
    $prefix = $prefix -replace '(?i)\b(4k|hd|hq|mv|live|cover|official|audio|video)\b', ''
    $prefix = $prefix -replace '(?i)\u7ffb\u5531', ''
    $prefix = $prefix -replace '\u9ad8\u6e05|\u4fee\u5fa9|\u4fee\u590d|\u5b98\u651d|\u5b98\u6444', ''
    $prefix = $prefix -replace '[\[\]\(\)]', ' '
    $prefix = $prefix.Replace($leftBookBracket, " ").Replace($rightBookBracket, " ").Replace($leftFullParen, " ").Replace($rightFullParen, " ")
    $prefix = ($prefix -replace '\s+', ' ').Trim((" `t-:" + $fullWidthColon + "|"))
    $prefix = Get-LikelyArtistFragment $prefix
    if (-not [string]::IsNullOrWhiteSpace($prefix)) {
        return $prefix
    }
    if ($titleEnd -gt $titleStart) {
        $suffix = $Text.Substring($titleEnd + 1)
        $segments = [regex]::Split($suffix, '\s*(?:-|\x2013|\x2014|\||\uFF5C)\s*')
        foreach ($segment in $segments) {
            $candidate = Get-LikelyArtistFragment $segment
            if (-not [string]::IsNullOrWhiteSpace($candidate)) {
                return $candidate
            }
        }
    }
    return ""
}

function Get-AttributedPerformanceParts {
    param([string]$Text)
    $empty = [PSCustomObject]@{ Title = ""; Performer = ""; Context = "" }
    if ([string]::IsNullOrWhiteSpace($Text)) {
        return $empty
    }
    $value = Clean-VideoMetaText $Text
    $value = $value -replace '\s*\[[A-Za-z0-9_-]{6,}\]\s*$', ''
    $match = [regex]::Match(
        $value,
        '^\s*(?<title>.+)\s*(?:-|\x2013|\x2014|\|)\s*(?<performer>[^@\r\n]{1,60}?)\s*@\s*(?<context>[^@\r\n]{2,100})\s*$'
    )
    if (-not $match.Success) {
        $match = [regex]::Match(
            $value,
            '^\s*(?<title>.+)\s+(?<performer>[\u3400-\u9fffA-Za-z][^@\r\n]{0,60}(?:&|\uFF06|\+|\x00D7|\u3001|\s+[xX]\s+)[^@\r\n]{1,60})\s*$'
        )
        if (-not $match.Success) {
            return $empty
        }
    }
    $title = Clean-VideoTitleForSongName $match.Groups['title'].Value
    $performer = $match.Groups['performer'].Value
    $performer = $performer -replace '(?i)\b(?:live|cover)\b|\u7ffb\u5531|\u73fe\u5834|\u73b0\u573a', ' '
    $performer = Clean-PerformanceArtistName (($performer -replace '\s+', ' ').Trim(" `t-_"))
    $context = if ($match.Groups['context'].Success) { ($match.Groups['context'].Value -replace '\s+', ' ').Trim() } else { "" }
    if ([string]::IsNullOrWhiteSpace($title) -or [string]::IsNullOrWhiteSpace($performer) -or $performer.Length -gt 40) {
        return $empty
    }
    return [PSCustomObject]@{ Title = $title; Performer = $performer; Context = $context }
}

function Get-TrackDefaultsFromVideoInfo {
    param([string]$AudioFile)

    $defaults = [PSCustomObject]@{
        Title = ""
        Artist = ""
        Album = ""
        Year = ""
        Extra = ""
        PlaylistTitle = ""
        PlaylistIndex = ""
        PlaylistCount = ""
        PlaylistId = ""
        PlaylistUploader = ""
        Thumbnail = ""
        IsLive = $false
        IsCover = $false
        CoverArtist = ""
    }

    $sidecar = "$AudioFile.aminfo.json"
    if (-not (Test-Path -LiteralPath $sidecar)) {
        return $defaults
    }

    try {
        $info = Get-Content -LiteralPath $sidecar -Raw -Encoding UTF8 | ConvertFrom-Json
    }
    catch {
        return $defaults
    }

    $rawTitle = @($info.title, $info.fulltitle, $info.alt_title) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -First 1
    $titleText = Clean-VideoMetaText $rawTitle
    $description = [string]($info.description)
    $combined = (($info.title, $info.fulltitle, $info.alt_title, $description) -join "`n")
    $rawPlaylistTitle = @($info.playlist_title, $info.playlist) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -First 1
    $playlistTitle = Clean-PlaylistAlbumTitle $rawPlaylistTitle
    $attributedPerformance = Get-AttributedPerformanceParts $titleText

    $title = $attributedPerformance.Title
    if ([string]::IsNullOrWhiteSpace($title)) {
        $title = Get-TextBetweenChars $combined 0x300A 0x300B
    }
    if ([string]::IsNullOrWhiteSpace($title)) {
        $title = Get-TextBetweenChars $combined 0x003C 0x003E
    }
    if ([string]::IsNullOrWhiteSpace($title)) {
        $title = Get-DecorativeSongTitle $titleText
    }
    if ([string]::IsNullOrWhiteSpace($title)) {
        $title = Get-FirstRegexGroup $combined @(
            '^\s*(?:\u6b4c\u540d|\u66f2\u540d|\u6b4c\u66f2|\u66f2\u76ee|title|song)\s*[:\uFF1A\-]\s*(.+)$',
            '^\s*(?:track)\s*[:\uFF1A\-]\s*(.+)$'
        )
    }
    if ([string]::IsNullOrWhiteSpace($title) -and -not [string]::IsNullOrWhiteSpace($info.track)) {
        $title = [string]$info.track
    }
    if ([string]::IsNullOrWhiteSpace($title)) {
        $titleParts = [regex]::Split($titleText, '\s*(?:-|\x2013|\x2014)\s*', 2)
        if ($titleParts.Count -eq 2 -and -not [string]::IsNullOrWhiteSpace($titleParts[1])) {
            $title = Clean-VideoTitleForSongName $titleParts[1]
        }
        else {
            $title = Clean-VideoTitleForSongName $titleText
        }
    }

    $artist = Get-FirstRegexGroup $combined @(
        '^\s*(?:\u6b4c\u624b|\u6f14\u5531|\u6f14\u5531\u8005|\u539f\u5531|artist|singer|vocal)\s*[:\uFF1A\-]\s*(.+)$',
        '^\s*(?:performer|performed by)\s*[:\uFF1A\-]\s*(.+)$'
    )
    if ([string]::IsNullOrWhiteSpace($artist) -and -not [string]::IsNullOrWhiteSpace($info.artist)) {
        $artist = [string]$info.artist
    }
    if ([string]::IsNullOrWhiteSpace($artist) -and -not [string]::IsNullOrWhiteSpace($attributedPerformance.Performer)) {
        $artist = $attributedPerformance.Performer
    }
    if ([string]::IsNullOrWhiteSpace($artist)) {
        $artist = Infer-ArtistFromTitle $titleText
    }
    if ([string]::IsNullOrWhiteSpace($artist) -and ([string]$info.channel) -match '(?i)(topic|official|vevo|\u5b98\u65b9)') {
        $artist = ([string]$info.channel) -replace '(?i)\s*-\s*topic$', ''
        $artist = $artist -replace '(?i)\s*official.*$', ''
        $artist = $artist.Trim()
    }
    $artist = Clean-PerformanceArtistName $artist
    if ([string]::IsNullOrWhiteSpace($artist) -and -not [string]::IsNullOrWhiteSpace($info.playlist_uploader)) {
        $artist = ([string]$info.playlist_uploader) -replace '(?i)\s*-\s*topic$', ''
        $artist = $artist -replace '(?i)\s*official.*$', ''
        $artist = $artist.Trim()
    }

    $album = Get-FirstRegexGroup $combined @('^\s*(?:\u4e13\u8f91|\u5c08\u8f2f|album)\s*[:\uFF1A\-]\s*(.+)$')
    if ([string]::IsNullOrWhiteSpace($album) -and -not [string]::IsNullOrWhiteSpace($info.album)) {
        $album = [string]$info.album
    }
    if ([string]::IsNullOrWhiteSpace($album) -and -not [string]::IsNullOrWhiteSpace($playlistTitle)) {
        $album = $playlistTitle
    }

    $year = ""
    $sidecarReleaseDate = [string]$info.release_date
    $sidecarUploadDate = [string]$info.upload_date
    $hasCatalogReleaseIdentity = -not [string]::IsNullOrWhiteSpace([string]$info.track) -or -not [string]::IsNullOrWhiteSpace([string]$info.album)
    $releaseDateDiffersFromUpload = -not [string]::IsNullOrWhiteSpace($sidecarReleaseDate) -and $sidecarReleaseDate -ne $sidecarUploadDate
    # A normal YouTube upload often exposes its publication date as release_year.
    # Trust that field only when the page also carries catalogue identity or a
    # distinct release date; otherwise online song metadata decides the year.
    if ($info.release_year -and ($hasCatalogReleaseIdentity -or $releaseDateDiffersFromUpload)) {
        $year = [string]$info.release_year
    }
    elseif ($releaseDateDiffersFromUpload -and $sidecarReleaseDate -match '^(19|20)\d{2}') {
        $year = $matches[0]
    }
    if ([string]::IsNullOrWhiteSpace($year)) {
        $year = Get-FirstRegexGroup $combined @('^\s*(?:\u5e74\u4efd|\u53d1\u884c|\u767c\u884c|year|release(?: date)?)\s*[:\uFF1A\-]\s*((?:19|20)\d{2})')
    }

    $extraLines = New-Object System.Collections.Generic.List[string]
    if ($info.title) { $extraLines.Add((Decode-Utf8 "6KeG6aKR5qCH6aKYOiA=") + $info.title) }
    if ($info.channel) { $extraLines.Add((Decode-Utf8 "6aKR6YGTOiA=") + $info.channel) }
    if ($info.uploader -and $info.uploader -ne $info.channel) { $extraLines.Add((Decode-Utf8 "5LiK5Lyg6ICFOiA=") + $info.uploader) }
    $lyricist = Get-FirstRegexGroup $combined @('(?:^|[/\uFF0F|])\s*(?:\u4f5c\u8bcd|\u586b\u8bcd|\u8a5e|\u8bcd|lyricist|lyrics by)\s*[:\uFF1A\-]\s*([^/\uFF0F|\r\n]+)')
    $composer = Get-FirstRegexGroup $combined @('(?:^|[/\uFF0F|])\s*(?:\u4f5c\u66f2|\u66f2|composer|music by)\s*[:\uFF1A\-]\s*([^/\uFF0F|\r\n]+)')
    if ($lyricist) { $extraLines.Add((Decode-Utf8 "5L2c6K+NOiA=") + $lyricist) }
    if ($composer) { $extraLines.Add((Decode-Utf8 "5L2c5puyOiA=") + $composer) }
    if ($description) {
        $desc = $description.Trim()
        if ($desc.Length -gt 1800) { $desc = $desc.Substring(0, 1800) }
        $extraLines.Add((Decode-Utf8 "566A5LuLOiA=") + $desc)
    }

    $defaults.Title = $title
    $defaults.Artist = $artist
    $defaults.Album = $album
    $defaults.Year = $year
    $defaults.Extra = ($extraLines -join "`r`n")
    $defaults.PlaylistTitle = $playlistTitle
    $defaults.PlaylistIndex = [string]$info.playlist_index
    $defaults.PlaylistCount = [string]$info.playlist_count
    $defaults.PlaylistId = [string]$info.playlist_id
    $defaults.PlaylistUploader = [string]$info.playlist_uploader
    $defaults.Thumbnail = [string]$info.thumbnail
    # Page-title structure identifies the current performer, not whether that
    # performer is the original artist. The metadata pass makes that comparison.
    $defaults.IsCover = $false
    $defaults.CoverArtist = ""
    $showContext = [string]$attributedPerformance.Context
    $defaults.IsLive = [bool](
        $combined -match '(?i)\blive\b|\u73b0\u573a|\u73fe\u573a|\u73fe\u5834|\u6f14\u5531\u4f1a|\u6f14\u5531\u6703' -or
        $showContext -match '(?i)\b(?:show|concert|festival|session)\b|\u7bc0\u76ee|\u8282\u76ee|\u821e\u53f0|\u591c$'
    )
    return $defaults
}

function Get-MostCommonValue {
    param([string[]]$Values)
    $items = @($Values) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
    if (-not $items -or $items.Count -eq 0) {
        return ""
    }
    return ($items | Group-Object | Sort-Object Count -Descending | Select-Object -First 1).Name
}

function Get-AlbumBatchDefaults {
    param([string[]]$Files)
    $items = New-Object System.Collections.Generic.List[object]
    foreach ($file in @($Files)) {
        if (Test-Path -LiteralPath $file) {
            $items.Add((Get-TrackDefaultsFromVideoInfo -AudioFile $file))
        }
    }
    $album = Get-MostCommonValue (@($items | ForEach-Object { if ($_.PlaylistTitle) { $_.PlaylistTitle } elseif ($_.Album) { $_.Album } }))
    $artist = Get-MostCommonValue (@($items | ForEach-Object { $_.Artist }))
    $year = Get-MostCommonValue (@($items | ForEach-Object { $_.Year }))
    return [PSCustomObject]@{
        Album = $album
        Artist = $artist
        Year = $year
    }
}

$processor = @'
import difflib
import ast
import base64
from concurrent.futures import ThreadPoolExecutor, as_completed
import functools
import html
import hashlib
import json
import os
import re
import shutil
import subprocess
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
import uuid
from io import BytesIO
from pathlib import Path

import imageio_ffmpeg
from mutagen.mp4 import MP4, MP4Cover

USER_AGENT = "CodexAppleMusicAutoImport/1.0 (local personal metadata helper)"
_NETEASE_LYRIC_RAW_CACHE = {}
_NETEASE_SONG_SEARCH_CACHE = {}

def lyric_cache_path(meta, prefer_live=False):
    title = base_lyric_title(meta.get("title") or "").strip()
    artist = (meta.get("artist") or "").strip()
    if not title or not artist or norm(artist) == "unknownartist":
        return None
    state_root = os.environ.get("APPLE_MUSIC_AUTO_IMPORT_STATE_ROOT", "").strip()
    if not state_root:
        state_root = os.path.join(
            os.environ.get("LOCALAPPDATA") or os.environ.get("TEMP") or ".",
            "AppleMusicAutoImport",
        )
    identity = json.dumps(
        [norm(title), norm(artist), "live" if prefer_live else "studio"],
        ensure_ascii=False,
        separators=(",", ":"),
    )
    digest = hashlib.sha256(identity.encode("utf-8")).hexdigest()
    return Path(state_root) / "lyrics-cache" / f"{digest}.json"

def read_lyric_cache(meta, prefer_live=False):
    path = lyric_cache_path(meta, prefer_live)
    if path is None or not path.is_file():
        return {}
    try:
        payload = json.loads(path.read_text(encoding="utf-8"))
    except Exception:
        return {}
    title = base_lyric_title(meta.get("title") or "").strip()
    artist = (meta.get("artist") or "").strip()
    if norm(payload.get("title")) != norm(title) or norm(payload.get("artist")) != norm(artist):
        return {}
    out = {}
    lyrics = usable_verified_lyrics(payload.get("lyrics") or "", title)
    if lyrics:
        out["lyrics"] = lyrics
    for key in ("composer", "lyricist", "arranger"):
        value = str(payload.get(key) or "").strip()
        if value:
            out[key] = value
    return out

def write_lyric_cache(meta, lyrics="", credits=None, prefer_live=False):
    path = lyric_cache_path(meta, prefer_live)
    if path is None:
        return
    credits = credits or {}
    existing = read_lyric_cache(meta, prefer_live)
    cleaned = usable_verified_lyrics(lyrics, meta.get("title") or "") if lyrics else ""
    payload = {
        "title": base_lyric_title(meta.get("title") or "").strip(),
        "artist": (meta.get("artist") or "").strip(),
        "lyrics": cleaned or existing.get("lyrics") or "",
        "composer": str(credits.get("composer") or existing.get("composer") or "").strip(),
        "lyricist": str(credits.get("lyricist") or existing.get("lyricist") or "").strip(),
        "arranger": str(credits.get("arranger") or existing.get("arranger") or "").strip(),
        "updated_at": int(time.time()),
    }
    if not payload["lyrics"] and not any(payload.get(key) for key in ("composer", "lyricist", "arranger")):
        return
    temp_path = path.with_suffix(f".{uuid.uuid4().hex}.tmp")
    try:
        path.parent.mkdir(parents=True, exist_ok=True)
        temp_path.write_text(json.dumps(payload, ensure_ascii=False), encoding="utf-8")
        os.replace(temp_path, path)
    except Exception:
        try:
            temp_path.unlink()
        except OSError:
            pass

def http_json(url, timeout=12):
    req = urllib.request.Request(url, headers={"User-Agent": USER_AGENT, "Accept": "application/json"})
    with urllib.request.urlopen(req, timeout=timeout) as resp:
        return json.loads(resp.read().decode("utf-8", "replace"))

def http_bytes(url, timeout=20):
    req = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    with urllib.request.urlopen(req, timeout=timeout) as resp:
        return resp.headers.get("Content-Type", ""), resp.read()

def clean_name(text):
    text = Path(text).stem
    text = re.sub(r"\.(fixed|converted)$", "", text, flags=re.I)
    m = re.search(r"[\u300a<](.*?)[\u300b>]", text)
    if m and m.group(1).strip():
        return m.group(1).strip()
    text = re.sub(r"^\s*[\u3010\[].*?[\u3011\]]\s*", "", text)
    text = re.sub(r"[_]+", " ", text)
    text = re.sub(r"\s+", " ", text).strip()
    return text

def source_context(source, hint):
    return (Path(source).stem + " " + (hint or "")).lower()

def is_live_context(source, hint):
    ctx = source_context(source, hint)
    if "__force_live__" in ctx:
        return True
    if "__force_studio__" in ctx:
        return False
    return any(token in ctx for token in ("live", "\u73fe\u5834", "\u73b0\u573a", "\u6f14\u5531\u6703", "\u6f14\u5531\u4f1a"))

def extract_book_title(text):
    m = re.search(r"[\u300a<](.*?)[\u300b>]", text or "")
    if m and m.group(1).strip():
        return m.group(1).strip()
    return ""

def extract_labeled_value(text, labels):
    if not text:
        return ""
    label_re = "|".join(re.escape(label) for label in labels)
    pattern = rf"(?im)^\s*(?:{label_re})\s*[:\uFF1A\-]\s*(.+?)\s*$"
    m = re.search(pattern, text)
    if m and m.group(1).strip():
        return m.group(1).strip()
    return ""

def extract_inline_labeled_value(text, labels):
    """Read a useful label embedded in a downloaded page-description line."""
    if not text:
        return ""
    label_re = "|".join(re.escape(label) for label in labels)
    pattern = rf"(?im)(?:^|\s)(?:{label_re})\s*[:\uFF1A]\s*([^\r\n]+)"
    m = re.search(pattern, text)
    if m and m.group(1).strip():
        return m.group(1).strip()
    return ""

def extract_credit_value(text, labels):
    """Read one credit from standalone or slash-separated description text."""
    if not text:
        return ""
    label_re = "|".join(re.escape(label) for label in labels)
    pattern = rf"(?im)(?:^|[/\uff0f|])\s*(?:{label_re})\s*[:\uff1a\-]\s*([^/\uff0f|\r\n]+)"
    match = re.search(pattern, text)
    if not match:
        return ""
    return match.group(1).strip(" -_.,;:")

def trim_hint_fragment(text):
    text = (text or "").strip()
    text = re.split(r"(?i)\b(?:\u89c6\u9891\u6807\u9898|\u983b\u9053|\u9891\u9053|\u4e0a\u4f20\u8005|\u4e0a\u50b3\u8005|\u7b80\u4ecb|\u7c21\u4ecb|description|album|\u4e13\u8f91|\u5c08\u8f2f|year|\u5e74\u4efd)\s*[:\uFF1A]", text, maxsplit=1)[0]
    text = re.sub(r"\[[A-Za-z0-9_-]{6,}\]\s*$", "", text)
    text = re.sub(r"\s+", " ", text).strip(" -_")
    return text

def parse_attributed_performance(text):
    """Parse strong title/current-performer structures before provider lookup."""
    value = trim_hint_fragment(Path(text or "").stem)
    match = re.match(
        r"^\s*(?P<title>.+)\s*(?:-|\u2013|\u2014|\|)\s*(?P<performer>[^@\r\n]{1,60}?)\s*@\s*(?P<context>[^@\r\n]{2,100})\s*$",
        value,
    )
    if not match:
        match = re.match(
            r"^\s*(?P<title>.+)\s+(?P<performer>[\u3400-\u9fffA-Za-z][^@\r\n]{0,60}(?:&|\uff06|\+|\u00d7|\u3001|\s+[xX]\s+)[^@\r\n]{1,60})\s*$",
            value,
        )
        if not match:
            return {}
    title = trim_hint_fragment(match.group("title"))
    performer = clean_performance_artist(match.group("performer"))
    context = re.sub(r"\s+", " ", match.groupdict().get("context") or "").strip()
    if weak_title(title, performer) or not performer or len(norm(performer)) > 40:
        return {}
    return {"title": title, "performer": performer, "context": context}

def extract_artist_near_book_title(text):
    text = (text or "").strip()
    if not text:
        return ""

    def likely_artist_fragment(value):
        value = trim_hint_fragment(value)
        value = re.sub(r"^(?:\s*[\u3010\[].*?[\u3011\]])+\s*", "", value)
        value = re.sub(r"^[\s\-\u2013\u2014|\uff5c:：_]+|[\s\-\u2013\u2014|\uff5c:：_]+$", "", value)
        value = value.strip(" '\"\u2018\u2019\u201c\u201d()[]")
        value = clean_performance_artist(value)
        value = re.sub(r"\s+", " ", value).strip()
        if not value or len(norm(value)) > 40 or not re.search(r"[\w\u3400-\u9fff]", value):
            return ""
        if re.search(
            r"(?i)official\s*(?:music\s*)?video|lyrics?|\bmv\b|\baudio\b|\bvideo\b|"
            r"\bcover\b|\blive\b|\u73fe\u5834|\u73b0\u573a|\u6f14\u5531\u6703|\u6f14\u5531\u4f1a|"
            r"\u9ad8\u6e05|\u7121\u640d|\u65e0\u635f|\u97f3\u8cea|\u97f3\u8d28|\u5b8c\u6574\u7248|"
            r"\u7d14\u4eab|\u7eaf\u4eab|\u7247\u6bb5|reaction",
            value,
        ):
            return ""
        return value

    book_match = re.search(r"[\u300a<](?P<title>[^\u300b>]{1,100})[\u300b>]", text)
    if book_match:
        before = likely_artist_fragment(text[:book_match.start()])
        if before:
            return before
        suffix = text[book_match.end():]
        for part in re.split(r"\s*(?:-|\u2013|\u2014|\||\uff5c)\s*", suffix):
            candidate = likely_artist_fragment(part)
            if candidate:
                return candidate

    parts = [p.strip() for p in re.split(r"\s*(?:-|\u2013|\u2014|\||\uff5c|/)\s*", text, maxsplit=1) if p.strip()]
    if len(parts) == 2:
        candidate = likely_artist_fragment(parts[0])
        if candidate:
            return candidate
    return ""

_COMMON_TRADITIONAL_PAIRS = {
    "\u8aaa": "\u8bf4", "\u98db": "\u98de", "\u6a5f": "\u673a", "\u5834": "\u573a",
    "\u570b": "\u56fd", "\u8a9e": "\u8bed", "\u611b": "\u7231", "\u6703": "\u4f1a",
    "\u9084": "\u8fd8", "\u6c92": "\u6ca1", "\u70ba": "\u4e3a", "\u8207": "\u4e0e",
    "\u96e3": "\u96be", "\u807d": "\u542c", "\u89ba": "\u89c9", "\u8b93": "\u8ba9",
    "\u9019": "\u8fd9", "\u500b": "\u4e2a", "\u6642": "\u65f6", "\u9593": "\u95f4",
    "\u96fb": "\u7535", "\u8eca": "\u8f66", "\u98a8": "\u98ce", "\u8449": "\u53f6",
    "\u6b78": "\u5f52", "\u9f4a": "\u9f50", "\u65bc": "\u4e8e", "\u9f8d": "\u9f99",
    "\u502b": "\u4f26", "\u5091": "\u6770", "\u83ef": "\u534e", "\u9673": "\u9648",
    "\u5f35": "\u5f20", "\u5289": "\u5218", "\u9ec3": "\u9ec4", "\u694a": "\u6768",
    "\u8b1d": "\u8c22", "\u8a31": "\u8bb8", "\u912d": "\u90d1", "\u8607": "\u82cf",
    "\u856d": "\u8427", "\u8d99": "\u8d75", "\u5b6b": "\u5b59", "\u8b8a": "\u53d8",
    "\u5ee3": "\u5e7f", "\u76e7": "\u5362",
    "\u6f64": "\u6da6", "\u6fa4": "\u6cfd", "\u5b78": "\u5b66", "\u9a30": "\u817e",
    "\u8f2f": "\u8f91", "\u767c": "\u53d1", "\u884c": "\u884c", "\u89aa": "\u4eb2",
    "\u975c": "\u9759", "\u50be": "\u503e",
}
_COMMON_TRADITIONAL_TO_SIMPLIFIED = str.maketrans(_COMMON_TRADITIONAL_PAIRS)
_COMMON_SIMPLIFIED_TO_TRADITIONAL = str.maketrans({
    simplified: traditional for traditional, simplified in _COMMON_TRADITIONAL_PAIRS.items()
})

_WINDOWS_LCMAP = None
if os.name == "nt":
    try:
        import ctypes

        _WINDOWS_LCMAP = ctypes.windll.kernel32.LCMapStringEx
        _WINDOWS_LCMAP.argtypes = [
            ctypes.c_wchar_p,
            ctypes.c_uint,
            ctypes.c_wchar_p,
            ctypes.c_int,
            ctypes.POINTER(ctypes.c_wchar),
            ctypes.c_int,
            ctypes.c_void_p,
            ctypes.c_void_p,
            ctypes.c_ssize_t,
        ]
        _WINDOWS_LCMAP.restype = ctypes.c_int
    except Exception:
        _WINDOWS_LCMAP = None

@functools.lru_cache(maxsize=4096)
def windows_chinese_map(text, flags):
    """Use Windows' full Chinese mapping table without adding a dependency."""
    value = str(text or "")
    if not value or _WINDOWS_LCMAP is None:
        return ""
    try:
        required = _WINDOWS_LCMAP("zh-CN", flags, value, len(value), None, 0, None, None, 0)
        if required <= 0:
            return ""
        buffer = ctypes.create_unicode_buffer(required + 1)
        written = _WINDOWS_LCMAP(
            "zh-CN", flags, value, len(value), buffer, len(buffer), None, None, 0
        )
        if written > 0:
            return "".join(buffer[:written]).rstrip("\x00")
    except Exception:
        pass
    return ""

@functools.lru_cache(maxsize=4096)
def simplified_search_text(text):
    value = str(text or "")
    mapped = windows_chinese_map(value, 0x02000000)
    return mapped or value.translate(_COMMON_TRADITIONAL_TO_SIMPLIFIED)

@functools.lru_cache(maxsize=4096)
def traditional_search_text(text):
    value = str(text or "")
    mapped = windows_chinese_map(value, 0x04000000)
    return mapped or value.translate(_COMMON_SIMPLIFIED_TO_TRADITIONAL)

def norm(text):
    value = simplified_search_text(text).lower()
    return re.sub(r"[\W_]+", "", value, flags=re.UNICODE)

def strip_live_marker(text):
    return re.sub(r"\s*\(?\s*(live|\u73fe\u5834|\u73b0\u573a)\s*\)?\s*$", "", text or "", flags=re.I).strip()

def clean_cover_performer(text):
    text = (text or "").strip()
    text = re.sub(r"\s*(?:\u7ffb\u5531\u7248?|cover)\s*$", "", text, flags=re.I)
    bilingual = re.match(r"^([\u3400-\u9fff]{2,8})\s*[A-Za-z].*$", text)
    if bilingual:
        text = bilingual.group(1)
    return text.strip(" -_.,;:()[]")

def clean_performance_artist(text):
    """Remove tour, venue, and event suffixes without changing an artist name."""
    text = (text or "").strip()
    text = re.sub(
        r"\s*(?:\u4e16\u754c\s*(?:\u5de1\u56de|\u5de1\u8ff4)\s*\u6f14\u5531[\u4f1a\u6703]|"
        r"(?:\u5de1\u56de|\u5de1\u8ff4)\s*\u6f14\u5531[\u4f1a\u6703]|\u6f14\u5531[\u4f1a\u6703]|"
        r"\u4e16\u754c\u5de1\u6f14|\u5de1\u6f14|\u97f3\u4e50\u8282|\u97f3\u6a02\u7bc0|\u6b4c\u53cb[\u4f1a\u6703]|"
        r"world\s+tour|concert|festival|live\s+at).*$",
        "",
        text,
        flags=re.I,
    )
    text = re.sub(r"\s+", " ", text).strip(" -_.,;:|/()[]")
    return clean_cover_performer(text)

def has_cjk(text):
    return bool(re.search(r"[\u3400-\u9fff]", text or ""))

def candidates_have_cjk(candidates):
    return any(has_cjk(" ".join([item.get("title", ""), item.get("artist", ""), item.get("query", "")])) for item in candidates)

def artist_matches(expected, actual, min_score=0.48):
    expected_n = norm(expected)
    actual_n = norm(actual)
    if not expected_n:
        return True
    if not actual_n:
        return False
    return expected_n in actual_n or actual_n in expected_n or ratio(expected, actual) >= min_score

def explicit_candidate_artists(candidates):
    artists = []
    seen = set()
    for item in candidates:
        artist = clean_performance_artist(item.get("artist") or "")
        key = norm(artist)
        if artist and key and key not in seen:
            seen.add(key)
            artists.append(artist)
    return artists

def detect_cover_performer(candidates, original_title, original_artist):
    """Bind a performer to the matching title instead of trusting unrelated hints."""
    matches = []
    for index, item in enumerate(candidates):
        candidate_title = (item.get("title") or "").strip()
        candidate_artist = clean_performance_artist(item.get("artist") or "")
        if not candidate_title or not candidate_artist:
            continue
        if canonical_title(candidate_title) != canonical_title(original_title):
            continue
        title_score = 1.0
        if strict_artist_matches(candidate_artist, original_artist):
            continue
        if len(norm(candidate_artist)) > 30 or norm(candidate_artist) == norm(candidate_title):
            continue
        matches.append((title_score, -index, candidate_artist))
    if not matches:
        return ""
    return max(matches, key=lambda item: (item[0], item[1]))[2]

def matches_any_explicit_artist(explicit_artists, actual):
    if not explicit_artists:
        return True
    return any(artist_matches(expected, actual) for expected in explicit_artists)

def ratio(a, b):
    a, b = norm(a), norm(b)
    if not a or not b:
        return 0.0
    return difflib.SequenceMatcher(None, a, b).ratio()

def canonical_title(text):
    """Normalize harmless release labels before comparing recording titles."""
    value = html.unescape(text or "")
    value = strip_live_marker(value)
    value = re.sub(
        r"\s*[\(\[\uFF08\u3010][^\)\]\uFF09\u3011]*(?:live|\u73fe\u5834|\u73b0\u573a|\u6f14\u5531\u6703|\u6f14\u5531\u4f1a|version|ver\.?|\u7248)[^\)\]\uFF09\u3011]*[\)\]\uFF09\u3011]\s*$",
        "",
        value,
        flags=re.I,
    )
    return norm(value)

def title_match_score(expected, actual):
    expected_n = canonical_title(expected)
    actual_n = canonical_title(actual)
    if not expected_n or not actual_n:
        return 0.0
    if expected_n == actual_n:
        return 1.0
    if min(len(expected_n), len(actual_n)) >= 3 and (expected_n in actual_n or actual_n in expected_n):
        return 0.94
    return ratio(expected_n, actual_n)

def artist_match_score(expected, actual):
    expected_n = norm(expected)
    actual_n = norm(actual)
    if not expected_n or not actual_n:
        return 0.0
    if expected_n == actual_n:
        return 1.0
    if min(len(expected_n), len(actual_n)) >= 3 and (expected_n in actual_n or actual_n in expected_n):
        return 0.96
    return ratio(expected_n, actual_n)

def strict_artist_matches(expected, actual):
    """Allow only close artist variants, including short traditional/simplified names."""
    expected_n = norm(expected)
    actual_n = norm(actual)
    if not expected_n:
        return True
    if not actual_n:
        return False
    score = artist_match_score(expected, actual)
    short_cjk_name = has_cjk(expected) and has_cjk(actual) and min(len(expected_n), len(actual_n)) <= 3
    return score >= (0.64 if short_cjk_name else 0.78)

def version_markers(text):
    value = (text or "").lower()
    markers = set()
    marker_patterns = {
        "live": r"\blive\b|\u73fe\u5834|\u73b0\u573a|\u6f14\u5531\u6703|\u6f14\u5531\u4f1a",
        "remix": r"\bremix\b|\bdj\b|\u6df7\u97f3",
        "instrumental": r"\binstrumental\b|\bkalaoke\b|\bkaraoke\b|\u4f34\u594f|\u7eaf\u97f3\u4e50|\u7d14\u97f3\u6a02",
        "cover": r"\bcover\b|\u7ffb\u5531",
    }
    for marker, pattern in marker_patterns.items():
        if re.search(pattern, value, flags=re.I):
            markers.add(marker)
    return markers

def has_unrequested_version(expected_title, actual_title, wants_live=False):
    expected = version_markers(expected_title)
    actual = version_markers(actual_title)
    if wants_live:
        expected.add("live")
    return bool((actual - expected) & {"remix", "instrumental", "cover", "live"})

def metadata_identity_evidence(meta, candidates, wants_live=False):
    """Return evidence that provider metadata is the recording the user asked for."""
    actual_title = meta.get("title") or ""
    actual_artist = meta.get("artist") or ""
    if not actual_title:
        return {"score": 0.0, "title_score": 0.0, "artist_score": 0.0, "paired": False}

    paired_matches = []
    title_only_matches = []
    for cand in candidates:
        expected_title = (cand.get("title") or "").strip()
        expected_artist = (cand.get("artist") or "").strip()
        if not expected_title or weak_title(expected_title, expected_artist):
            continue
        title_score = title_match_score(expected_title, actual_title)
        if title_score < 0.84 or has_unrequested_version(expected_title, actual_title, wants_live):
            continue
        if expected_artist and len(norm(expected_artist)) >= 2:
            artist_score = artist_match_score(expected_artist, actual_artist)
            paired_matches.append((title_score, artist_score, expected_title, expected_artist))
        else:
            title_only_matches.append((title_score, expected_title))

    # When an explicit title/artist pair matches the title, never allow a
    # same-title different-artist result to fall through via a weak title-only hint.
    if paired_matches:
        valid_pairs = [item for item in paired_matches if strict_artist_matches(item[3], actual_artist)]
        if not valid_pairs:
            return {"score": 0.0, "title_score": max(item[0] for item in paired_matches), "artist_score": 0.0, "paired": True}
        title_score, artist_score, _, _ = max(
            valid_pairs,
            key=lambda item: item[0] * 0.72 + item[1] * 0.28,
        )
        return {
            "score": title_score * 0.72 + artist_score * 0.28,
            "title_score": title_score,
            "artist_score": artist_score,
            "paired": True,
        }

    if title_only_matches:
        title_score, _ = max(title_only_matches, key=lambda item: item[0])
        return {
            "score": title_score * 0.90 + 0.02,
            "title_score": title_score,
            "artist_score": 0.0,
            "paired": False,
        }
    return {"score": 0.0, "title_score": 0.0, "artist_score": 0.0, "paired": False}

def metadata_is_trusted(meta, candidates, wants_live=False):
    evidence = metadata_identity_evidence(meta, candidates, wants_live)
    if evidence["paired"]:
        return evidence["score"] >= 0.88 and evidence["title_score"] >= 0.88 and evidence["artist_score"] >= 0.78
    return evidence["score"] >= 0.90 and evidence["title_score"] >= 0.98

def metadata_agrees(left, right):
    if not left or not right:
        return False
    if title_match_score(left.get("title"), right.get("title")) < 0.93:
        return False
    left_artist = left.get("artist") or ""
    right_artist = right.get("artist") or ""
    return bool(left_artist and right_artist and strict_artist_matches(left_artist, right_artist))

def generic_single_album(meta):
    album = norm(meta.get("album") or "")
    title = norm(meta.get("title") or "")
    return not album or album == title or album == (title + "single") or album.endswith("single")

def release_quality(meta):
    """Prefer a full official release over a generated or single fallback."""
    score = 0.0
    if not generic_single_album(meta):
        score += 0.08
    if meta.get("year") or meta.get("release_date"):
        score += 0.03
    if has_artwork(meta):
        score += 0.03
    if int_or_zero(meta.get("track_count")) > 1:
        score += 0.03
    if meta.get("_provider") == "itunes":
        score += 0.025
    return score

def merge_verified_metadata(primary, verified):
    """Keep one verified release intact, only filling genuinely missing fields."""
    result = dict(primary)
    for item in verified:
        if item is primary:
            continue
        for key in ("album", "album_artist", "year", "release_date", "genre", "artwork_url"):
            if not result.get(key) and item.get(key):
                result[key] = item[key]
        for key in ("track_number", "track_count", "disc_number", "disc_count"):
            if not int_or_zero(result.get(key)) and int_or_zero(item.get(key)):
                result[key] = item[key]
        if generic_single_album(result) and not generic_single_album(item):
            for key in ("album", "album_artist", "year", "release_date", "artwork_url", "track_number", "track_count", "disc_number", "disc_count"):
                if item.get(key):
                    result[key] = item[key]
    if not result.get("_netease_song_id"):
        for item in verified:
            if item.get("_netease_song_id"):
                result["_netease_song_id"] = item["_netease_song_id"]
                break
    return result

def weak_title(text, artist=""):
    n = norm(text)
    return (
        not n
        or (len(n) < 2 and len(norm(artist)) < 2)
        or n.isdigit()
        or n in ("videoplayback", "audio", "download", "playback")
        or n.startswith("videoplayback")
        or n.startswith("download")
    )

def parse_candidates(source, hint):
    base = clean_name(source)
    hint = (hint or "").strip()
    labeled_title = extract_labeled_value(hint, ["\u6b4c\u540d", "\u66f2\u540d", "\u6b4c\u66f2", "\u66f2\u76ee", "title", "song", "track"])
    if not labeled_title:
        labeled_title = extract_inline_labeled_value(
            hint,
            ["\u89c6\u9891\u6807\u9898", "\u5f71\u7247\u6a19\u984c", "video title"],
        )
    labeled_artist = clean_performance_artist(extract_labeled_value(hint, ["\u6b4c\u624b", "\u6f14\u5531", "\u6f14\u5531\u8005", "\u539f\u5531", "artist", "singer", "vocal", "performer"]))
    has_structured_title = bool(labeled_title)
    book_title = labeled_title or extract_book_title(Path(source).stem) or extract_book_title(hint)
    book_artist = labeled_artist
    if not book_artist:
        video_title = extract_inline_labeled_value(
            hint,
            ["\u89c6\u9891\u6807\u9898", "\u5f71\u7247\u6a19\u984c", "video title"],
        )
        artist_contexts = [video_title, Path(source).stem]
        if not has_structured_title:
            artist_contexts.append(hint)
        for context in artist_contexts:
            context_title = extract_book_title(context)
            if not context_title or canonical_title(context_title) != canonical_title(book_title):
                continue
            book_artist = clean_performance_artist(extract_artist_near_book_title(context))
            if book_artist:
                break
    candidates = []
    attributed = parse_attributed_performance(Path(source).stem)
    if attributed:
        candidates.append({
            "artist": attributed["performer"],
            "title": attributed["title"],
            "query": f"{attributed['performer']} {attributed['title']}",
        })
    if labeled_title or labeled_artist:
        resolved_artist = labeled_artist or book_artist
        candidates.append({"artist": resolved_artist, "title": labeled_title or book_title, "query": f"{resolved_artist} {labeled_title or book_title}".strip()})
    if book_title:
        if book_artist:
            candidates.append({"artist": book_artist, "title": book_title, "query": f"{book_artist} {book_title}"})
        candidates.append({"artist": "", "title": book_title, "query": f"{hint} {book_title}"})
    if hint and not has_structured_title:
        if len(norm(hint)) <= 80:
            candidates.append({"artist": "", "title": hint, "query": hint})
        else:
            candidates.append({"artist": "", "title": "", "query": hint})
        parts = [p.strip() for p in re.split(r"\s+-\s+| - |-|--|/", hint, maxsplit=1) if p.strip()]
        if len(parts) == 2:
            left = trim_hint_fragment(parts[0])
            right = trim_hint_fragment(parts[1])
            candidates.append({"artist": left, "title": right, "query": f"{left} {right}".strip()})
            if len(norm(left)) <= 40 and len(norm(right)) <= 80:
                candidates.append({"artist": right, "title": left, "query": f"{right} {left}".strip()})
        space_parts = [p.strip() for p in hint.split() if p.strip()]
        if len(space_parts) >= 2:
            candidates.append({"artist": space_parts[0], "title": " ".join(space_parts[1:]), "query": hint})
            candidates.append({"artist": " ".join(space_parts[:-1]), "title": space_parts[-1], "query": hint})
        else:
            if weak_title(base):
                candidates.append({"artist": "", "title": "", "query": hint})
                candidates.append({"artist": "", "title": hint, "query": hint})
            else:
                candidates.append({"artist": "", "title": base, "query": f"{hint} {base}"})
    if not has_structured_title:
        parts = [p.strip() for p in re.split(r"\s+-\s+| - |--", base, maxsplit=1) if p.strip()]
        if len(parts) == 2:
            candidates.append({"title": parts[0], "artist": parts[1], "query": base})
            candidates.append({"artist": parts[0], "title": parts[1], "query": base})
        if not weak_title(base):
            candidates.append({"title": base, "artist": "", "query": base})

    expanded = []
    for item in candidates:
        expanded.append(item)
        alias = dict(item)
        changed = False
        for key in ("title", "query"):
            value = alias.get(key) or ""
            replaced = value.replace("\u5341\u70b9\u534a", "10:30").replace("\u5341\u9ede\u534a", "10:30")
            if replaced != value:
                alias[key] = replaced
                changed = True
        if changed:
            expanded.append(alias)

    seen = set()
    unique = []
    for item in expanded:
        key = (item.get("title", ""), item.get("artist", ""), item.get("query", ""))
        if key not in seen:
            seen.add(key)
            unique.append(item)
    return unique

def with_live_search_variants(candidates):
    out = list(candidates)
    for item in candidates:
        query = (item.get("query") or item.get("title") or "").strip()
        if not query:
            continue
        if not re.search(r"(?i)\blive\b|\u73fe\u5834|\u73b0\u573a|\u6f14\u5531\u6703|\u6f14\u5531\u4f1a", query):
            clone = dict(item)
            clone["query"] = query + " live"
            out.append(clone)
    seen = set()
    unique = []
    for item in out:
        key = (item.get("title", ""), item.get("artist", ""), item.get("query", ""))
        if key not in seen:
            seen.add(key)
            unique.append(item)
    unique.sort(key=lambda item: (
        0 if item.get("artist") and item.get("title") else 1,
        0 if is_live_context("", item.get("query") or "") else 1,
        len(item.get("query") or item.get("title") or ""),
    ))
    return unique[:12]

def original_song_candidates(candidates):
    """For a cover, search the composition by title without constraining it to the performer."""
    out = []
    seen = set()
    for item in candidates:
        title = strip_live_marker(item.get("title") or "")
        title = re.sub(r"\s*\(?\s*(live|\u73fe\u5834|\u73b0\u573a|\u6f14\u5531\u6703|\u6f14\u5531\u4f1a)\s*\)?\s*$", "", title, flags=re.I).strip()
        if not title or weak_title(title):
            continue
        key = norm(title)
        if key in seen:
            continue
        seen.add(key)
        out.append({"artist": "", "title": title, "query": title})
    return out or candidates

def current_performer_candidates(candidates):
    """Keep only strong title/performer pairs for a same-performer recording check."""
    out = []
    seen = set()
    for item in candidates:
        title = strip_live_marker(item.get("title") or "").strip()
        artist = clean_performance_artist(item.get("artist") or "")
        if not title or weak_title(title, artist) or not artist:
            continue
        key = (canonical_title(title), norm(artist))
        if key in seen:
            continue
        seen.add(key)
        live_suffix = " live" if is_live_context("", item.get("query") or "") else ""
        out.append({"artist": artist, "title": title, "query": f"{artist} {title}{live_suffix}"})
    return out

def explicit_cover_context(source, hint):
    context = source_context(source, hint)
    if re.search(r"\bcover\b|\u7ffb\u5531|\u81f4\u656c", context, flags=re.I):
        return True
    # A title such as 'song-singer@show' identifies a guest performance and
    # should be compared with the original recording, not treated as a release.
    return bool(parse_attributed_performance(Path(source).stem))

def with_cover_original_artist_candidates(candidates, title_only_candidates, cover_artist):
    """Retain a manually supplied original artist without reusing the cover performer."""
    target_titles = {canonical_title(item.get("title") or "") for item in title_only_candidates}
    out = []
    for item in candidates:
        title = strip_live_marker(item.get("title") or "")
        artist = (item.get("artist") or "").strip()
        if not title or not artist or canonical_title(title) not in target_titles:
            continue
        if strict_artist_matches(artist, cover_artist):
            continue
        out.append({"artist": artist, "title": title, "query": f"{artist} {title}"})
    out.extend(title_only_candidates)
    seen = set()
    unique = []
    for item in out:
        key = (norm(item.get("artist") or ""), canonical_title(item.get("title") or ""))
        if key not in seen:
            seen.add(key)
            unique.append(item)
    return unique or title_only_candidates

def with_original_artist_context(candidates, source, hint):
    """Prefer an original artist explicitly named in a cover video title."""
    info = load_video_sidecar(source)
    context = "\n".join(str(value or "") for value in (
        hint,
        info.get("title"),
        info.get("fulltitle"),
        info.get("description"),
    ))
    patterns = [
        r"(?:\u81f4\u656c(?:\u4f20\u5947)?(?:\u6b4c\u624b)?|\u539f\u5531\s*[:\uff1a]?)\s*([\u3400-\u9fff]{2,4})",
        r"(?:tribute\s+to|original\s+by)\s*([A-Za-z][A-Za-z .'-]{1,40})",
    ]
    artists = []
    for pattern in patterns:
        for match in re.finditer(pattern, context, flags=re.I):
            artist = match.group(1).strip(" -_.,;:()[]")
            if artist and norm(artist) not in {norm(value) for value in artists}:
                artists.append(artist)
    titles = [item.get("title") or "" for item in candidates if item.get("title")]
    if not artists or not titles:
        return candidates
    out = []
    for artist in artists:
        for title in titles[:2]:
            out.append({"artist": artist, "title": title, "query": f"{artist} {title}"})
    out.extend(candidates)
    seen = set()
    unique = []
    for item in out:
        key = (item.get("artist", ""), item.get("title", ""), item.get("query", ""))
        if key not in seen:
            seen.add(key)
            unique.append(item)
    return unique

def compact_candidates(candidates, limit=3):
    """Keep form previews responsive without discarding strong matches."""
    ordered = sorted(candidates, key=lambda item: (
        0 if item.get("artist") and item.get("title") else 1,
        0 if item.get("title") else 1,
        len(item.get("query") or item.get("title") or ""),
    ))
    return ordered[:limit] or candidates

def known_override(candidates):
    combined = " ".join(
        " ".join([item.get("title", ""), item.get("artist", ""), item.get("query", "")])
        for item in candidates
    ).lower()
    is_hand = (
        "hand in hand" in combined
        or "\u624b\u727d\u624b" in combined
        or "\u624b\u7275\u624b" in combined
    )
    is_artist = (
        "leehom" in combined
        or "wang" in combined
        or "david tao" in combined
        or "tao" in combined
        or "\u738b\u529b\u5b8f" in combined
        or "\u9676\u55c6" in combined
        or "sars" in combined
    )
    if is_hand and is_artist:
        return {
            "title": "\u624b\u727d\u624b",
            "artist": "\u7fa4\u661f",
            "album": "\u624b\u727d\u624b Hand In Hand - Single",
            "album_artist": "\u7fa4\u661f",
            "year": "2003",
            "release_date": "2003",
            "genre": "Mandopop",
            "track_number": 1,
            "track_count": 1,
            "disc_number": 1,
            "disc_count": 1,
            "composer": "\u738b\u529b\u5b8f, \u9676\u5586",
            "lyricist": "\u738b\u529b\u5b8f, \u9676\u5586, \u9673\u93ae\u5ddd",
            "generated_artwork": "hand_in_hand",
            "source": "Built-in verified fallback for Hand In Hand charity single",
        }
    return None

def search_itunes(candidates, fast=False):
    countries = ["CN", "HK", "TW"] if fast else ["CN", "HK", "TW", "US", "JP"]
    deadline = time.monotonic() + 4.0 if fast else None
    explicit_artists = explicit_candidate_artists(candidates)
    best = None
    for cand in candidates:
        if deadline and time.monotonic() >= deadline:
            break
        fast_exact_match = False
        terms = []
        cand_wants_live = is_live_context("", cand.get("query") or "")
        if cand.get("title") and cand.get("artist"):
            live_suffix = " live" if cand_wants_live else ""
            terms.append(f"{cand['title']} {cand['artist']}{live_suffix}")
            terms.append(f"{cand['artist']} {cand['title']}{live_suffix}")
        terms.append(cand.get("query") or cand.get("title") or "")
        for term in [t for t in terms if t.strip()]:
            if deadline and time.monotonic() >= deadline:
                break
            for country in countries:
                remaining = deadline - time.monotonic() if deadline else 6.0
                if deadline and remaining <= 0:
                    break
                qs = urllib.parse.urlencode({"term": term, "media": "music", "entity": "song", "limit": 10, "country": country})
                url = f"https://itunes.apple.com/search?{qs}"
                try:
                    data = http_json(url, timeout=min(6.0, max(0.25, remaining)))
                except Exception:
                    continue
                for result in data.get("results", []):
                    if not matches_any_explicit_artist(explicit_artists, result.get("artistName")):
                        continue
                    title_score = max(
                        ratio(cand.get("title") or term, result.get("trackName")),
                        ratio(cand.get("title") or term, strip_live_marker(result.get("trackName") or "")),
                    )
                    artist_score = ratio(cand.get("artist"), result.get("artistName")) if cand.get("artist") else 0.35
                    if cand.get("artist") and not artist_matches(cand.get("artist"), result.get("artistName")):
                        continue
                    score = title_score * 0.62 + artist_score * 0.38
                    if norm(cand.get("title")) and norm(cand.get("title")) == norm(result.get("trackName")):
                        score += 0.15
                    if norm(cand.get("artist")) and norm(cand.get("artist")) == norm(result.get("artistName")):
                        score += 0.15
                    if is_live_context("", term):
                        result_live_text = " ".join([result.get("trackName") or "", result.get("collectionName") or ""])
                        if is_live_context("", result_live_text):
                            score += 0.35
                        else:
                            score -= 0.25
                    item = {"score": round(score, 4), "country": country, "data": result}
                    if best is None or item["score"] > best["score"]:
                        best = item
                    exact_title = canonical_title(cand.get("title")) == canonical_title(result.get("trackName"))
                    if fast and exact_title and (
                            (cand.get("artist") and item["score"] >= 1.0)
                            or (not cand.get("artist") and item["score"] >= 0.88)):
                        fast_exact_match = True
                        break
                if fast_exact_match or (best and best["score"] >= 1.25):
                    break
            if fast_exact_match or (best and best["score"] >= 1.25):
                break
        if fast_exact_match or (best and best["score"] >= 1.25):
            break
    if not best or best["score"] < 0.66:
        return None
    r = best["data"]
    artwork = normalize_itunes_artwork(r.get("artworkUrl100") or "")
    release_date = r.get("releaseDate") or ""
    meta = {
        "title": r.get("trackName") or "",
        "artist": r.get("artistName") or "",
        "album": r.get("collectionName") or "",
        "album_artist": r.get("collectionArtistName") or r.get("artistName") or "",
        "year": release_date[:4] if release_date else "",
        "release_date": release_date[:10] if release_date else "",
        "genre": r.get("primaryGenreName") or "",
        "track_number": r.get("trackNumber") or 1,
        "track_count": r.get("trackCount") or 1,
        "disc_number": r.get("discNumber") or 1,
        "disc_count": r.get("discCount") or 1,
        "artwork_url": artwork,
        "_provider": "itunes",
        "_provider_score": best["score"],
        "source": f"iTunes Search API {best['country']} score={best['score']}",
    }
    return meta

def search_itunes_release_refinement(meta):
    """Fill release-level fields after another provider has locked the identity."""
    title = (meta.get("title") or "").strip()
    artist = (meta.get("artist") or "").strip()
    if not title or not artist:
        return {}
    release_date = str(meta.get("release_date") or "")[:10]
    year = str(meta.get("year") or release_date[:4])[:4]
    terms = []
    for term in (
        f"{traditional_search_text(artist)} {traditional_search_text(title)}",
        f"{artist} {title}",
    ):
        term = term.strip()
        if term and term not in terms:
            terms.append(term)

    def fetch_release_results(term, country):
        qs = urllib.parse.urlencode({
            "term": term,
            "media": "music",
            "entity": "song",
            "limit": 10,
            "country": country,
        })
        try:
            data = http_json(f"https://itunes.apple.com/search?{qs}", timeout=3.2)
        except Exception:
            return []
        return [(result, country, rank) for rank, result in enumerate(data.get("results", []))]

    rows = []
    requests = [(term, country) for term in terms for country in ("HK", "TW")]
    with ThreadPoolExecutor(max_workers=min(4, len(requests))) as executor:
        futures = [executor.submit(fetch_release_results, term, country) for term, country in requests]
        for future in as_completed(futures):
            try:
                rows.extend(future.result())
            except Exception:
                pass

    matches = []
    for result, country, rank in rows:
        result_title = result.get("trackName") or ""
        result_artist = result.get("artistName") or ""
        result_date = str(result.get("releaseDate") or "")[:10]
        title_score = title_match_score(title, result_title)
        if title_score < 0.93 or has_unrequested_version(title, result_title):
            continue
        if not strict_artist_matches(artist, result_artist):
            continue
        identity_score = title_score * 0.70 + artist_match_score(artist, result_artist) * 0.25
        date_bonus = 0.08 if release_date and result_date == release_date else 0.0
        matches.append((identity_score + date_bonus - rank * 0.01, result_date, result, country, rank))
    if not matches:
        return {}

    top_score = max(item[0] for item in matches)
    finalists = [item for item in matches if item[0] >= top_score - 0.02]
    # Search APIs often return a recent compilation before the original album.
    # Once title and artist are locked, the earliest exact release is safer.
    _, _, result, country, rank = min(
        finalists,
        key=lambda item: (item[1] or "9999-99-99", item[4]),
    )
    result_date = str(result.get("releaseDate") or "")[:10]
    return {
        "album": result.get("collectionName") or "",
        "album_artist": result.get("collectionArtistName") or result.get("artistName") or artist,
        "genre": result.get("primaryGenreName") or "",
        "release_date": result_date,
        "year": result_date[:4] if result_date else year,
        "track_number": result.get("trackNumber") or 1,
        "track_count": result.get("trackCount") or 1,
        "disc_number": result.get("discNumber") or 1,
        "disc_count": result.get("discCount") or 1,
        "artwork_url": normalize_itunes_artwork(result.get("artworkUrl100") or ""),
        "source": f"iTunes release corroboration {country} rank={rank + 1}",
    }

_ALBUM_TRACKLIST_CACHE = {}

def album_name_matches(expected, actual):
    expected_n = norm(expected)
    actual_n = norm(actual)
    if not expected_n or not actual_n:
        return False
    return expected_n == actual_n or expected_n in actual_n or actual_n in expected_n or ratio(expected, actual) >= 0.62

def search_itunes_album_tracklist(album, artist):
    album = (album or "").strip()
    artist = (artist or "").strip()
    cache_key = (norm(album), norm(artist))
    if cache_key in _ALBUM_TRACKLIST_CACHE:
        return _ALBUM_TRACKLIST_CACHE[cache_key]
    if not album:
        _ALBUM_TRACKLIST_CACHE[cache_key] = []
        return []

    countries = ["HK", "TW", "CN", "US", "JP"]
    terms = []
    if artist:
        terms.extend([f"{artist} {album}", f"{album} {artist}"])
    terms.append(album)

    best_album = None
    for term in terms:
        for country in countries:
            qs = urllib.parse.urlencode({"term": term, "media": "music", "entity": "album", "limit": 10, "country": country})
            try:
                data = http_json(f"https://itunes.apple.com/search?{qs}")
            except Exception:
                continue
            for result in data.get("results", []):
                collection = result.get("collectionName") or ""
                result_artist = result.get("artistName") or result.get("collectionArtistName") or ""
                album_score = ratio(album, collection)
                if album_name_matches(album, collection):
                    album_score = max(album_score, 0.86)
                artist_score = ratio(artist, result_artist) if artist else 0.45
                if artist and artist_matches(artist, result_artist):
                    artist_score = max(artist_score, 0.80)
                score = album_score * 0.74 + artist_score * 0.26
                if norm(album) and norm(album) == norm(collection):
                    score += 0.18
                item = {"score": score, "country": country, "data": result}
                if best_album is None or item["score"] > best_album["score"]:
                    best_album = item
            if best_album and best_album["score"] >= 0.88:
                break
        if best_album and best_album["score"] >= 0.88:
            break

    if not best_album or best_album["score"] < 0.58:
        _ALBUM_TRACKLIST_CACHE[cache_key] = []
        return []

    collection_id = best_album["data"].get("collectionId")
    if not collection_id:
        _ALBUM_TRACKLIST_CACHE[cache_key] = []
        return []
    country = best_album["country"]
    qs = urllib.parse.urlencode({"id": collection_id, "entity": "song", "country": country})
    try:
        data = http_json(f"https://itunes.apple.com/lookup?{qs}")
    except Exception:
        _ALBUM_TRACKLIST_CACHE[cache_key] = []
        return []

    tracks = []
    for result in data.get("results", []):
        if result.get("wrapperType") != "track":
            continue
        tracks.append({
            "title": result.get("trackName") or "",
            "artist": result.get("artistName") or "",
            "album": result.get("collectionName") or best_album["data"].get("collectionName") or album,
            "album_artist": result.get("collectionArtistName") or result.get("artistName") or artist,
            "track_number": result.get("trackNumber") or 1,
            "track_count": result.get("trackCount") or len(data.get("results", [])),
            "disc_number": result.get("discNumber") or 1,
            "disc_count": result.get("discCount") or 1,
            "release_date": (result.get("releaseDate") or best_album["data"].get("releaseDate") or "")[:10],
            "genre": result.get("primaryGenreName") or "",
            "artwork_url": normalize_itunes_artwork(result.get("artworkUrl100") or best_album["data"].get("artworkUrl100") or ""),
            "source": f"iTunes album tracklist {country} collection={collection_id} score={best_album['score']:.4f}",
        })
    _ALBUM_TRACKLIST_CACHE[cache_key] = tracks
    return tracks

def find_album_track_order(title, artist, album):
    tracks = search_itunes_album_tracklist(album, artist)
    if not tracks:
        return {}
    best = None
    for track in tracks:
        title_score = ratio(title, track.get("title"))
        if norm(title) and norm(title) == norm(track.get("title")):
            title_score = 1.0
        elif norm(title) and (norm(title) in norm(track.get("title")) or norm(track.get("title")) in norm(title)):
            title_score = max(title_score, 0.88)
        artist_score = ratio(artist, track.get("artist")) if artist else 0.50
        if artist and artist_matches(artist, track.get("artist")):
            artist_score = max(artist_score, 0.78)
        score = title_score * 0.82 + artist_score * 0.18
        item = {"score": score, "track": track}
        if best is None or item["score"] > best["score"]:
            best = item
    if not best or best["score"] < 0.58:
        return {}
    out = dict(best["track"])
    out["match_score"] = best["score"]
    return out

def mb_query_value(text):
    return '"' + (text or "").replace('"', r'\"') + '"'

def search_musicbrainz(meta):
    title = meta.get("title") or ""
    artist = meta.get("artist") or ""
    if not title:
        return {}
    query = f'recording:{mb_query_value(title)}'
    if artist:
        query += f' AND artist:{mb_query_value(artist)}'
    url = "https://musicbrainz.org/ws/2/recording?" + urllib.parse.urlencode({"query": query, "fmt": "json", "limit": 5})
    try:
        data = http_json(url)
    except Exception:
        return {}
    best = None
    for rec in data.get("recordings", []):
        artist_credit = " ".join([a.get("name", "") for a in rec.get("artist-credit", []) if isinstance(a, dict)])
        title_score = title_match_score(title, rec.get("title"))
        artist_score = artist_match_score(artist, artist_credit) if artist else 1.0
        if title_score < 0.90 or (artist and not strict_artist_matches(artist, artist_credit)):
            continue
        score = title_score * 0.65 + artist_score * 0.35
        if best is None or score > best[0]:
            best = (score, rec)
    if not best or best[0] < 0.88:
        return {}

    rec_id = best[1].get("id")
    out = {"musicbrainz_recording_id": rec_id or ""}
    if best[1].get("isrcs"):
        out["isrc"] = best[1]["isrcs"][0]
    if not rec_id:
        return out
    time.sleep(1.0)
    lookup_url = f"https://musicbrainz.org/ws/2/recording/{rec_id}?" + urllib.parse.urlencode({"inc": "artist-rels+work-rels+isrcs", "fmt": "json"})
    try:
        lookup = http_json(lookup_url)
    except Exception:
        return out
    if lookup.get("isrcs") and not out.get("isrc"):
        out["isrc"] = lookup["isrcs"][0]

    composers = set()
    lyricists = set()
    arrangers = set()
    work_ids = []
    for rel in lookup.get("relations", []):
        rtype = (rel.get("type") or "").lower()
        artist_obj = rel.get("artist") or {}
        if rtype in ("composer", "writer"):
            if artist_obj.get("name"):
                composers.add(artist_obj["name"])
        if rtype in ("lyricist", "writer"):
            if artist_obj.get("name"):
                lyricists.add(artist_obj["name"])
        if rtype == "arranger":
            if artist_obj.get("name"):
                arrangers.add(artist_obj["name"])
        work_obj = rel.get("work") or {}
        if work_obj.get("id"):
            work_ids.append(work_obj["id"])

    for work_id in work_ids[:2]:
        time.sleep(1.0)
        work_url = f"https://musicbrainz.org/ws/2/work/{work_id}?" + urllib.parse.urlencode({"inc": "artist-rels", "fmt": "json"})
        try:
            work = http_json(work_url)
        except Exception:
            continue
        for rel in work.get("relations", []):
            rtype = (rel.get("type") or "").lower()
            artist_obj = rel.get("artist") or {}
            name = artist_obj.get("name")
            if not name:
                continue
            if rtype in ("composer", "writer"):
                composers.add(name)
            if rtype in ("lyricist", "writer"):
                lyricists.add(name)
            if rtype == "arranger":
                arrangers.add(name)

    if composers:
        out["composer"] = ", ".join(sorted(composers))
    if lyricists:
        out["lyricist"] = ", ".join(sorted(lyricists))
    if arrangers:
        out["arranger"] = ", ".join(sorted(arrangers))
    return out

def base_lyric_title(title):
    title = title or ""
    title = re.sub(r"\s*\([^)]*(?:live|\u73fe\u5834|\u73b0\u573a|\u53f0\u5317|\u9999\u6e2f|soul\s*power)[^)]*\)\s*$", "", title, flags=re.I)
    title = re.sub(r"\s+", " ", title).strip()
    return title

def lyric_title_aliases(title):
    base = base_lyric_title(title)
    aliases = []
    for value in (
        base,
        simplified_search_text(base),
        traditional_search_text(base),
        base.replace("\u5341\u70b9\u534a", "10:30").replace("\u5341\u9ede\u534a", "10:30"),
        base.replace("10:30", "\u5341\u70b9\u534a"),
        base.replace("10:30", "\u5341\u9ede\u534a"),
    ):
        value = value.strip()
        if value and value not in aliases:
            aliases.append(value)
    return aliases

def lyric_identity_variants(title, artist):
    """Pair equivalent title/artist scripts without issuing every cross product."""
    title_aliases = lyric_title_aliases(title)
    if not title_aliases:
        return []
    base = title_aliases[0]
    pairs = []

    def add(singer, song):
        singer = (singer or "").strip()
        song = (song or "").strip()
        key = (singer, song)
        if song and key not in pairs:
            pairs.append(key)

    add(artist, base)
    add(simplified_search_text(artist), simplified_search_text(base))
    add(traditional_search_text(artist), traditional_search_text(base))
    for alias in title_aliases[1:]:
        add(artist, alias)
    return pairs

_LYRIC_NON_BODY_LABELS = (
    "\u4f5c\u8bcd", "\u4f5c\u8a5e", "\u586b\u8bcd", "\u586b\u8a5e", "\u8bcd", "\u8a5e",
    "\u4f5c\u66f2", "\u66f2", "\u7f16\u66f2", "\u7de8\u66f2", "\u5236\u4f5c\u4eba", "\u88fd\u4f5c\u4eba", "\u539f\u5531",
    "\u51fa\u54c1", "\u51fa\u54c1\u4eba", "\u51fa\u54c1\u516c\u53f8", "\u8054\u5408\u51fa\u54c1", "\u806f\u5408\u51fa\u54c1",
    "\u53d1\u884c", "\u767c\u884c", "\u53d1\u884c\u4eba", "\u767c\u884c\u4eba", "\u7248\u6743", "\u7248\u6b0a",
    "\u5409\u4ed6", "\u6728\u5409\u4ed6", "\u7535\u5409\u4ed6", "\u96fb\u5409\u4ed6", "\u8d1d\u65af", "\u8c9d\u65af",
    "\u9f13", "\u9f13\u624b", "\u952e\u76d8", "\u9375\u76e4", "\u94a2\u7434", "\u92fc\u7434",
    "\u548c\u58f0", "\u548c\u8072", "\u548c\u58f0\u7f16\u5199", "\u548c\u8072\u7de8\u5beb", "\u548c\u58f0\u6f14\u5531", "\u548c\u8072\u6f14\u5531",
    "\u4eba\u58f0", "\u4eba\u8072", "\u4eba\u58f0\u5f55\u97f3\u5e08", "\u4eba\u8072\u9304\u97f3\u5e2b",
    "\u5f55\u97f3", "\u9304\u97f3", "\u5f55\u97f3\u5e08", "\u9304\u97f3\u5e2b", "\u5f55\u97f3\u68da", "\u9304\u97f3\u68da",
    "\u6df7\u97f3", "\u6df7\u97f3\u5e08", "\u6df7\u97f3\u5e2b", "\u6bcd\u5e26", "\u6bcd\u5e36", "\u6bcd\u5e26\u5de5\u7a0b\u5e08", "\u6bcd\u5e36\u5de5\u7a0b\u5e2b",
    "\u5f26\u4e50", "\u5f26\u6a02", "\u5f26\u4e50\u7f16\u5199", "\u5f26\u6a02\u7de8\u5beb", "\u5f26\u4e50\u76d1\u5236", "\u5f26\u6a02\u76e3\u88fd", "\u5f26\u4e50\u5f55\u97f3\u68da", "\u5f26\u6a02\u9304\u97f3\u68da",
    "\u914d\u5531", "\u97f3\u9891\u7f16\u8f91", "\u97f3\u983b\u7de8\u8f2f", "\u97f3\u4e50\u7f16\u8f91", "\u97f3\u6a02\u7de8\u8f2f", "\u6b4c\u8bcd\u7f16\u8f91", "\u6b4c\u8a5e\u7de8\u8f2f", "\u4e50\u624b", "\u6a02\u624b", "\u4e50\u961f", "\u6a02\u968a", "\u4e50\u961f\u961f\u957f", "\u6a02\u968a\u968a\u9577", "\u76d1\u5236", "\u76e3\u88fd",
    "\u97f3\u4e50\u7edf\u7b79", "\u97f3\u6a02\u7d71\u7c4c", "\u6253\u51fb\u4e50", "\u6253\u64ca\u6a02", "\u5f26\u4e50\u56e2", "\u5f26\u6a02\u5718",
    "\u4f01\u5212", "\u4f01\u5283", "\u7b56\u5212", "\u7b56\u5283", "\u8425\u9500", "\u71df\u92b7", "\u8425\u9500\u4f01\u5212", "\u71df\u92b7\u4f01\u5283",
    "\u8425\u9500\u63a8\u5e7f", "\u71df\u92b7\u63a8\u5ee3", "\u603b\u8425\u9500", "\u7e3d\u71df\u92b7", "\u5ba3\u4f20", "\u5ba3\u50b3", "\u63a8\u5e7f", "\u63a8\u5ee3",
    "\u9879\u76ee\u7edf\u7b79", "\u9805\u76ee\u7d71\u7c4c", "\u5236\u4f5c\u7edf\u7b79", "\u88fd\u4f5c\u7d71\u7c4c",
    "\u5c01\u9762", "\u5c01\u9762\u8bbe\u8ba1", "\u5c01\u9762\u8a2d\u8a08", "\u89c6\u89c9\u8bbe\u8ba1", "\u8996\u89ba\u8a2d\u8a08", "\u5e73\u9762\u8bbe\u8ba1", "\u5e73\u9762\u8a2d\u8a08",
    "\u7f8e\u672f", "\u7f8e\u8853", "\u7f8e\u672f\u8bbe\u8ba1", "\u7f8e\u8853\u8a2d\u8a08", "\u6587\u6848",
    "\u827a\u4eba\u7ecf\u7eaa", "\u85dd\u4eba\u7d93\u7d00", "\u7ecf\u7eaa", "\u7d93\u7d00", "\u7ecf\u7eaa\u4eba", "\u7d93\u7d00\u4eba",
    "\u5408\u4f5c\u7edf\u7b79", "\u5408\u4f5c\u7d71\u7c4c", "\u827a\u4eba\u5408\u4f5c\u7edf\u7b79", "\u85dd\u4eba\u5408\u4f5c\u7d71\u7c4c", "\u827a\u4eba\u827a\u4eba\u5408\u4f5c\u7edf\u7b79", "\u85dd\u4eba\u85dd\u4eba\u5408\u4f5c\u7d71\u7c4c",
    "\u9879\u76ee\u603b\u76d1", "\u9805\u76ee\u7e3d\u76e3", "\u9879\u76ee\u76d1\u5236", "\u9805\u76ee\u76e3\u88fd", "\u5236\u4f5c\u603b\u76d1", "\u88fd\u4f5c\u7e3d\u76e3",
    "\u97f3\u4e50\u603b\u76d1", "\u97f3\u6a02\u7e3d\u76e3", "\u603b\u76d1", "\u7e3d\u76e3", "\u7edf\u7b79", "\u7d71\u7c4c",
    "lyric by", "lyrics by", "lyricist", "composer", "music by", "arranger", "arranged by", "arrangement",
    "producer", "vocal producer", "recording engineer", "mixing engineer", "mastering engineer",
    "guitar", "bass", "drums", "keyboard", "piano", "backing vocals", "program", "programming", "publisher", "copyright", "op", "sp",
)
_LYRIC_NON_BODY_LABEL_PATTERN = "|".join(
    re.escape(label) for label in sorted(_LYRIC_NON_BODY_LABELS, key=len, reverse=True)
)
_LYRIC_ENGLISH_NON_BODY_LABEL_PATTERN = "|".join(
    re.escape(label)
    for label in sorted(
        (label for label in _LYRIC_NON_BODY_LABELS if label.isascii()),
        key=len,
        reverse=True,
    )
)
_LYRIC_INLINE_CREDIT_LABEL_PATTERN = "|".join(
    re.escape(label)
    for label in sorted(
        (label for label in _LYRIC_NON_BODY_LABELS if label not in ("\u8bcd", "\u8a5e", "\u66f2")),
        key=len,
        reverse=True,
    )
)
_LYRIC_NON_BODY_LABEL_NORMS = {norm(label) for label in _LYRIC_NON_BODY_LABELS}

def coalesce_lyric_fragments(lines):
    """Join provider-timed CJK fragments without reflowing normal lyric lines."""
    def is_short_cjk_fragment(line):
        cjk = re.findall(r"[\u3400-\u9fff]", line or "")
        return 0 < len(cjk) <= 3 and not re.search(r"[.!?\u3002\uff01\uff1f:：]$", line or "")

    merged = []
    index = 0
    while index < len(lines):
        line = lines[index]
        if not is_short_cjk_fragment(line):
            merged.append(line)
            index += 1
            continue

        group = line
        index += 1
        while index < len(lines) and is_short_cjk_fragment(lines[index]) and len(norm(group)) < 6:
            group += lines[index]
            index += 1
        if index < len(lines) and len(norm(group)) <= 3 and not is_short_cjk_fragment(lines[index]):
            group += lines[index]
            index += 1
        merged.append(group)
    return merged

def clean_lyric_text(text):
    lines = []
    for raw in (text or "").splitlines():
        if re.match(r"^\s*\[(?:ar|ti|al|by|offset|re|ve):", raw, flags=re.I):
            continue
        line = re.sub(r"^\s*(?:\[[0-9:.]+\]\s*)+", "", raw).strip()
        line = re.sub(r"\s+", " ", line)
        line = re.sub(r"(?i)\boh\s+yeh\b", "Oh yeah", line)
        line = re.sub(r"(?i)\byeh\b", "yeah", line)
        if line.lower() == "for my baby":
            line = "For my baby"
        if not line:
            continue
        if re.match(rf"^(?:{_LYRIC_NON_BODY_LABEL_PATTERN})\s*[:\uff1a]", line, flags=re.I):
            continue
        if re.match(rf"^(?:{_LYRIC_ENGLISH_NON_BODY_LABEL_PATTERN})\b(?:\s*[:\uff1a]|\s+)", line, flags=re.I):
            continue
        if re.search(r"(?:\u7279\u522b\u4f01\u5212|\u7279\u5225\u4f01\u5283).*(?:\u51fa\u54c1|\u5236\u4f5c|\u88fd\u4f5c)\s*$", line):
            continue
        inline_credit = re.search(rf"(?:{_LYRIC_INLINE_CREDIT_LABEL_PATTERN})\s*[:\uff1a]", line, flags=re.I)
        if inline_credit and inline_credit.start() > 0:
            line = line[:inline_credit.start()].rstrip()
        if not line or norm(line) in _LYRIC_NON_BODY_LABEL_NORMS:
            continue
        if lines and norm(lines[-1]) == norm(line):
            continue
        lines.append(line)
    return "\n".join(coalesce_lyric_fragments(lines)).strip()

def lyrics_match_title(title, lyrics):
    title_n = norm(base_lyric_title(title))
    lyrics_n = norm(lyrics)
    if not title_n or not lyrics_n:
        return True
    if "1030" in title_n:
        if not any(token in lyrics_n for token in ("1030", "\u5341\u70b9\u534a", "\u5341\u9ede\u534a")):
            return False
    # Compare normalized characters here as well. Provider lyrics are often
    # simplified while Apple Music metadata is traditional (for example,
    # `\u807d\u6d77` versus `\u542c\u6d77`). Comparing the raw scripts rejected a
    # correct lyric after all earlier identity checks had already passed.
    common_chars = set(norm("\u7684\u4e86\u6211\u4f60\u4ed6\u5979\u5b83\u662f\u6709\u5728\u4e0d\u4e00\u548c"))
    title_chars = [
        ch for ch in title_n
        if re.match(r"[\u3400-\u9fff]", ch) and ch not in common_chars
    ]
    if len(title_chars) >= 2:
        matched = sum(1 for ch in set(title_chars) if ch in lyrics_n)
        if matched < 2:
            return False
    return True

def lyrics_match_expected_script(title, text):
    if not title or not has_cjk(base_lyric_title(title)):
        return True
    cjk_chars = len(re.findall(r"[\u3400-\u9fff]", text or ""))
    letter_chars = len(re.findall(r"[A-Za-z]", text or ""))
    return cjk_chars >= 20 or letter_chars < 40

def usable_lyrics(text, title=""):
    cleaned = clean_lyric_text(text)
    if not cleaned:
        return ""
    if title and not lyrics_match_title(title, cleaned):
        return ""
    lines = lyric_lines(cleaned)
    cjk_chars = len(re.findall(r"[\u3400-\u9fff]", cleaned))
    letter_chars = sum(1 for char in cleaned if char.isalpha())
    if len(lines) < 4:
        return ""
    if not lyrics_match_expected_script(title, cleaned):
        # A translated lyric can carry an exact Chinese title and artist in
        # provider metadata. Enforce the expected script at this shared gate so
        # network results, persisted caches, and precomputed previews all obey
        # the same rule.
        return ""
    if cjk_chars and cjk_chars < 20:
        return ""
    if not cjk_chars and letter_chars < 40:
        return ""
    return cleaned

def usable_verified_lyrics(text, title=""):
    """Validate lyrics whose catalogue song identity was already verified."""
    cleaned = usable_lyrics(text, "")
    if not cleaned:
        return ""
    if title and not lyrics_match_expected_script(title, cleaned):
        return ""
    return cleaned

def extract_lyric_credits(raw_lyrics):
    """Read only explicit production-credit lines from a matched lyric source."""
    patterns = {
        "lyricist": r"^(?:\u4f5c\u8bcd|\u4f5c\u8a5e|\u586b\u8bcd|\u586b\u8a5e|lyrics?\s*by|lyricist)\s*[:\uff1a]\s*(.+)$",
        "composer": r"^(?:\u4f5c\u66f2|composer|music\s*by)\s*[:\uff1a]\s*(.+)$",
        "arranger": r"^(?:\u7f16\u66f2|\u7de8\u66f2|arranger|arranged\s*by|arrangement)\s*[:\uff1a]\s*(.+)$",
    }
    credits = {}
    for raw in (raw_lyrics or "").splitlines():
        line = re.sub(r"^\[[0-9:.]+\]\s*", "", raw).strip()
        line = re.sub(r"\s+", " ", line)
        if not line:
            continue
        for key, pattern in patterns.items():
            match = re.match(pattern, line, flags=re.I)
            if not match or key in credits:
                continue
            value = match.group(1).strip(" -\u2013\u2014")
            if 1 < len(value) <= 120 and not re.search(r"(?i)unknown|\u6682\u65e0|\u66ab\u7121", value):
                credits[key] = value
    return credits

def fetch_netease_lyric_raw(song_id):
    cache_key = str(song_id or "").strip()
    if cache_key in _NETEASE_LYRIC_RAW_CACHE:
        return _NETEASE_LYRIC_RAW_CACHE[cache_key]
    raw = ""
    urls = (
        f"https://music.163.com/api/song/lyric?id={song_id}&lv=1&kv=1&tv=-1",
        f"https://music.163.com/api/song/lyric?id={song_id}&lv=-1&kv=-1&tv=-1&os=pc",
        f"https://music.163.com/api/song/media?id={song_id}",
        f"https://interface.music.163.com/api/song/lyric?id={song_id}&lv=-1&kv=-1&tv=-1&os=pc",
    )
    for attempt, url in enumerate(urls):
        try:
            req = urllib.request.Request(
                url,
                headers={"User-Agent": USER_AGENT, "Referer": "https://music.163.com/"},
            )
            with urllib.request.urlopen(req, timeout=5) as resp:
                payload = json.loads(resp.read().decode("utf-8", "replace"))
            raw = (payload.get("lrc") or {}).get("lyric") or payload.get("lyric") or ""
            if raw:
                break
        except Exception:
            pass
        if attempt < len(urls) - 1:
            time.sleep(0.12 * (attempt + 1))
    # Do not cache a transient empty response; a later fallback may retry the
    # same verified song instead of making the failure permanent for the run.
    if raw:
        _NETEASE_LYRIC_RAW_CACHE[cache_key] = raw
    return raw

def search_netease_song_rows(term, limit=10):
    cache_key = norm(term)
    if cache_key in _NETEASE_SONG_SEARCH_CACHE:
        return _NETEASE_SONG_SEARCH_CACHE[cache_key]
    form_data = urllib.parse.urlencode({"s": term, "type": 1, "offset": 0, "total": "true", "limit": limit}).encode("utf-8")
    rows = []
    for attempt in range(2):
        try:
            req = urllib.request.Request(
                "https://music.163.com/api/search/get",
                data=form_data,
                headers={"User-Agent": USER_AGENT, "Referer": "https://music.163.com/"},
            )
            with urllib.request.urlopen(req, timeout=5) as resp:
                payload = json.loads(resp.read().decode("utf-8", "replace"))
            rows = (payload.get("result") or {}).get("songs", [])
            if rows:
                break
        except Exception:
            rows = []
        if attempt == 0:
            time.sleep(0.12)
    # A network failure and a genuine empty search are indistinguishable here.
    # Do not make either result permanent for the rest of the import run.
    if rows:
        _NETEASE_SONG_SEARCH_CACHE[cache_key] = rows
    return rows

def search_lrclib_lyrics(meta):
    title = meta.get("title") or ""
    artist = meta.get("artist") or ""
    if not title:
        return ""
    identities = lyric_identity_variants(title, artist)
    if not identities:
        return ""

    def load_identity(identity):
        singer, alias = identity
        params = {"track_name": alias}
        if singer:
            params["artist_name"] = singer
        url = "https://lrclib.net/api/search?" + urllib.parse.urlencode(params)
        for attempt in range(2):
            try:
                data = http_json(url, timeout=5)
                if isinstance(data, list) and data:
                    return data[:10]
            except Exception:
                pass
            if attempt == 0:
                time.sleep(0.12)
        return []

    all_results = []
    identities = identities[:4]
    with ThreadPoolExecutor(max_workers=min(4, len(identities))) as executor:
        futures = [executor.submit(load_identity, identity) for identity in identities]
        for future in as_completed(futures):
            try:
                all_results.extend(future.result())
            except Exception:
                pass
    expects_cjk_lyrics = has_cjk(base_lyric_title(title))
    best = None
    for item in all_results:
        identity_score = max(ratio(alias, item.get("trackName")) for alias in lyric_title_aliases(title)) * 0.65
        identity_score += ratio(artist, item.get("artistName")) * 0.35
        if meta.get("album"):
            identity_score += ratio(meta.get("album"), item.get("albumName")) * 0.1
        if identity_score < 0.88:
            continue

        variants = (
            (item.get("plainLyrics") or "", 1),
            (item.get("syncedLyrics") or "", 0),
        )
        seen_bodies = set()
        for raw_lyrics, plain_preference in variants:
            lyrics = usable_lyrics(raw_lyrics, title)
            body_key = norm(lyrics)
            if not lyrics or not body_key or body_key in seen_bodies:
                continue
            seen_bodies.add(body_key)

            cjk_chars = len(re.findall(r"[\u3400-\u9fff]", lyrics))
            latin_chars = len(re.findall(r"[A-Za-z]", lyrics))
            if expects_cjk_lyrics and cjk_chars < 20:
                # LRCLIB can return an English translation under a matching
                # Traditional-Chinese artist alias. Never let that translation
                # replace the original-script lyric for a Chinese-titled song.
                continue
            script_score = (
                cjk_chars / max(1, cjk_chars + latin_chars)
                if expects_cjk_lyrics else 0.0
            )
            line_score = min(len(lyric_lines(lyrics)), 120)
            rank = (identity_score, script_score, line_score, plain_preference)
            if best is None or rank > best[0]:
                best = (rank, lyrics)
    return best[1] if best else ""

def fetch_netease_lyrics(song_id, title=""):
    # A verified catalogue song can legitimately omit its title from the lyric
    # body. Keep the script gate, but do not require title characters to appear
    # in the words (for example, the song "绽放").
    return usable_verified_lyrics(fetch_netease_lyric_raw(song_id), title)

def search_netease_lyrics(meta, prefer_live=False):
    title = meta.get("title") or ""
    artist = meta.get("artist") or ""
    if not title:
        return ""
    search_terms = []
    identities = lyric_identity_variants(title, artist)
    terms = []
    if prefer_live:
        for singer, alias in identities:
            terms.extend((
                f"{singer} {alias} live",
                f"{singer} {alias} concert",
            ))
    for singer, alias in identities:
        terms.append(f"{singer} {alias}")
    for singer, alias in identities:
        terms.append(f"{alias} {singer}")
    terms.extend(alias for alias in lyric_title_aliases(title))
    for term in terms:
        term = term.strip()
        if term and term not in search_terms:
            search_terms.append(term)

    selected_terms = search_terms[:3]
    title_only_term_norms = {norm(alias) for alias in lyric_title_aliases(title) if alias}
    for alias in lyric_title_aliases(title):
        if alias and alias not in selected_terms:
            selected_terms.append(alias)
            break
    selected_terms = selected_terms[:4]
    if not selected_terms:
        return ""
    songs_by_term = {}
    with ThreadPoolExecutor(max_workers=min(4, len(selected_terms))) as executor:
        futures = {executor.submit(search_netease_song_rows, term): term for term in selected_terms}
        for future in as_completed(futures):
            songs_by_term[futures[future]] = future.result()

    best_by_id = {}
    for term in selected_terms:
        for rank, song in enumerate(songs_by_term.get(term, [])):
            song_id = song.get("id")
            song_title = song.get("name") or ""
            artists = " ".join(a.get("name", "") for a in song.get("artists", []) if isinstance(a, dict))
            album = (song.get("album") or {}).get("name") or ""
            title_score = max(title_match_score(alias, song_title) for alias in lyric_title_aliases(title))
            if not song_id or title_score < 0.90:
                continue
            strict_artist = not artist or strict_artist_matches(artist, artists)
            if artist and not strict_artist:
                if norm(term) in title_only_term_norms:
                    continue
                # Some catalogues omit the original recording. A highly ranked,
                # exact-title cover can still provide the original lyric text.
                if title_score < 0.98 or rank > 2:
                    continue
            artist_score = artist_match_score(artist, artists) if artist and strict_artist else (0.20 if artist else 0.35)
            score = title_score * 0.68 + artist_score * 0.32 - rank * 0.015
            song_context = " ".join([song_title, album, term])
            if is_live_context("", song_context):
                score += 0.35 if prefer_live else -0.18
            elif prefer_live:
                score -= 0.18
            if prefer_live and re.search(r"(?i)power\s*of\s*live|soul\s*power|live|concert|\u73fe\u5834|\u73b0\u573a|\u6f14\u5531\u6703|\u6f14\u5531\u4f1a", song_context):
                score += 0.12
            item = (score, song_id, song_title, album)
            if song_id not in best_by_id or score > best_by_id[song_id][0]:
                best_by_id[song_id] = item

    best = sorted(best_by_id.values(), reverse=True, key=lambda item: item[0])
    top = [item for item in best[:6] if item[0] >= 0.48]
    raw_by_id = {}
    if top:
        with ThreadPoolExecutor(max_workers=min(4, len(top))) as executor:
            futures = {executor.submit(fetch_netease_lyric_raw, item[1]): item[1] for item in top}
            for future in as_completed(futures):
                raw_by_id[futures[future]] = future.result()

    fallback = ""
    for score, song_id, song_title, album in top:
        if score < 0.48:
            continue
        lyrics = usable_lyrics(raw_by_id.get(song_id, ""), title)
        if lyrics:
            if prefer_live and re.search(r"\u73b0\u5728\u7684\u65f6\u95f4|\u73fe\u5728\u7684\u6642\u9593", lyrics) and re.search(r"\u8fd8\u6ca1\u6709|\u9084\u6c92\u6709", lyrics):
                return lyrics
            if not fallback:
                fallback = lyrics
            if not prefer_live:
                return lyrics
    return fallback

def find_netease_lyric_credits(meta, prefer_live=False, reference_lyrics=""):
    """Extract one coherent credit set from lyrics matching the chosen song."""
    cached = read_lyric_cache(meta, prefer_live)
    cached_credits = {
        key: cached.get(key) or ""
        for key in ("composer", "lyricist", "arranger")
        if cached.get(key)
    }
    if cached_credits.get("composer") and cached_credits.get("lyricist"):
        return cached_credits
    title = meta.get("title") or ""
    artist = meta.get("artist") or ""
    direct_song_id = meta.get("_netease_song_id")
    if direct_song_id:
        try:
            direct_raw = fetch_netease_lyric_raw(direct_song_id)
            direct_lyrics = usable_verified_lyrics(direct_raw, title)
            direct_credits = extract_lyric_credits(direct_raw) if direct_lyrics else {}
        except Exception:
            direct_credits = {}
        if direct_credits.get("composer") or direct_credits.get("lyricist"):
            for key, value in cached_credits.items():
                direct_credits.setdefault(key, value)
            return direct_credits
    if not title or not artist:
        return cached_credits
    candidates = []
    terms = []
    identities = lyric_identity_variants(title, artist)
    for singer, alias in identities:
        term = f"{singer} {alias}".strip()
        if term and term not in terms:
            terms.append(term)
    for singer, alias in identities:
        term = f"{alias} {singer}".strip()
        if term and term not in terms:
            terms.append(term)
    selected_terms = terms[:4]
    if not selected_terms:
        return cached_credits
    songs_by_term = {}
    with ThreadPoolExecutor(max_workers=min(3, len(selected_terms))) as executor:
        futures = {executor.submit(search_netease_song_rows, term): term for term in selected_terms}
        for future in as_completed(futures):
            songs_by_term[futures[future]] = future.result()
    best_by_id = {}
    for term in selected_terms:
        for rank, song in enumerate(songs_by_term.get(term, [])):
            song_id = song.get("id")
            song_title = song.get("name") or ""
            song_artist = " ".join(a.get("name", "") for a in song.get("artists", []) if isinstance(a, dict))
            song_album = (song.get("album") or {}).get("name") or ""
            title_score = title_match_score(title, song_title)
            if not song_id or title_score < 0.90:
                continue
            strict_artist = strict_artist_matches(artist, song_artist)
            if not strict_artist and title_score < 0.98:
                continue
            if strict_artist:
                score = title_score * 0.70 + artist_match_score(artist, song_artist) * 0.30 - rank * 0.01
            else:
                # Only a lyric-similar cover may supply composition credits.
                # This avoids unrelated songs that merely share the same title.
                score = title_score - 0.15 - rank * 0.015
            album_score = ratio(meta.get("album"), song_album) if meta.get("album") else 0.0
            score += album_score * 0.12
            if song_id not in best_by_id or score > best_by_id[song_id][0]:
                best_by_id[song_id] = (score, song_id, strict_artist)

    candidates = sorted(best_by_id.values(), reverse=True)[:8]
    raw_by_id = {}
    with ThreadPoolExecutor(max_workers=min(4, len(candidates) or 1)) as executor:
        futures = {executor.submit(fetch_netease_lyric_raw, item[1]): item[1] for item in candidates}
        for future in as_completed(futures):
            raw_by_id[futures[future]] = future.result()

    reference_norm = norm(reference_lyrics)
    ranked_credits = []
    for score, song_id, strict_artist in candidates:
        raw_lyrics = raw_by_id.get(song_id, "")
        clean_lyrics = usable_lyrics(raw_lyrics, title)
        if not clean_lyrics:
            continue
        similarity = 1.0 if strict_artist else 0.0
        if reference_norm:
            similarity = difflib.SequenceMatcher(None, reference_norm, norm(clean_lyrics)).ratio()
        if not strict_artist and (not reference_norm or similarity < 0.45):
            continue
        credits = extract_lyric_credits(raw_lyrics)
        if not credits.get("composer") and not credits.get("lyricist"):
            continue
        completeness = sum(bool(credits.get(key)) for key in ("composer", "lyricist", "arranger"))
        ranked_credits.append((score + similarity * 0.55 + completeness * 0.04, credits))
    if not ranked_credits:
        return cached_credits
    result = max(ranked_credits, key=lambda item: item[0])[1]
    for key, value in cached_credits.items():
        result.setdefault(key, value)
    return result

def known_video_lyrics(meta, source):
    """Use a verified lyric source for local videos with known live wording."""
    video_id = (load_video_sidecar(source).get("id") or "").strip()
    title = norm(base_lyric_title(meta.get("title") or ""))
    artist = meta.get("artist") or ""
    known = {
        # This Taipei Soul Power upload has an opening line that differs from
        # the studio lyric. Use the matching published live lyric instead of
        # trying to transcribe concert audio.
        "3dW6r8tByOA": {
            "titles": {
                norm("\u98de\u673a\u573a\u768410:30"),
                norm("\u98db\u6a5f\u5834\u768410:30"),
            },
            "artist": "\u9676\u5586",
            "lyric_title": "\u98de\u673a\u573a\u768410:30",
            "song_id": "150404",
        },
    }
    item = known.get(video_id)
    if not item or title not in item["titles"] or not artist_matches(item["artist"], artist):
        return ""
    return fetch_netease_lyrics(item["song_id"], item["lyric_title"])

def find_lyrics(meta, prefer_live=False, source=""):
    known = known_video_lyrics(meta, source)
    if known:
        write_lyric_cache(meta, known, prefer_live=prefer_live)
        return known
    cached = read_lyric_cache(meta, prefer_live)
    if cached.get("lyrics"):
        return cached["lyrics"]
    title = meta.get("title") or ""
    artist = meta.get("artist") or ""
    direct_song_id = meta.get("_netease_song_id")
    if direct_song_id:
        try:
            direct = fetch_netease_lyrics(direct_song_id, title)
        except Exception:
            direct = ""
        if direct:
            write_lyric_cache(meta, direct, prefer_live=prefer_live)
            return direct

    providers = [
        ("netease", lambda: search_netease_lyrics(meta, prefer_live=prefer_live)),
        ("lrclib", lambda: search_lrclib_lyrics(meta)),
    ]
    preferred = ("netease", "lrclib") if has_cjk(title) or has_cjk(artist) else ("lrclib", "netease")
    results = {}
    with ThreadPoolExecutor(max_workers=2) as executor:
        futures = {executor.submit(loader): name for name, loader in providers}
        for future in as_completed(futures):
            try:
                results[futures[future]] = future.result() or ""
            except Exception:
                results[futures[future]] = ""
    for name in preferred:
        lyrics = results.get(name) or ""
        if lyrics:
            write_lyric_cache(meta, lyrics, prefer_live=prefer_live)
            return lyrics
    return ""

def append_visible_lyricist(lyrics, lyricist):
    """Keep lyricist visible in Apple Music even where its field is mistranslated."""
    lyrics = (lyrics or "").rstrip()
    lyricist = (lyricist or "").strip()
    if not lyrics:
        return lyrics
    lines = lyrics.splitlines()
    while lines and not lines[-1].strip():
        lines.pop()
    if lines and re.match(r"^(?:\u4f5c\u8bcd|\u4f5c\u8a5e|\u586b\u8bcd|\u586b\u8a5e)\s*[:\uff1a]", lines[-1].strip(), flags=re.I):
        lines.pop()
        while lines and not lines[-1].strip():
            lines.pop()
    lyrics = "\n".join(lines).rstrip()
    if not lyricist:
        return lyrics
    return lyrics + "\n\n\u4f5c\u8bcd\uff1a" + lyricist

def finalize_visible_lyricist(meta):
    """Rebuild the visible lyric credit after automatic or manual metadata edits."""
    meta = dict(meta)
    meta["lyrics"] = append_visible_lyricist(meta.get("lyrics"), meta.get("lyricist"))
    return meta

def restore_cached_lyric_data(meta, lyric_meta, lyrics="", prefer_live=False):
    """Recover display data on the main thread after a lookup task fails."""
    try:
        cached = read_lyric_cache(lyric_meta, prefer_live)
    except Exception:
        return lyrics
    if not lyrics and cached.get("lyrics"):
        lyrics = cached["lyrics"]
        append_source(meta, "lyrics restored from verified cache")
    restored_credit = False
    for key in ("composer", "lyricist", "arranger"):
        if not meta.get(key) and cached.get(key):
            meta[key] = cached[key]
            restored_credit = True
    if restored_credit:
        append_source(meta, "credits restored from verified cache")
    return lyrics

def extract_hint_credits(hint):
    out = {}
    lyricist = extract_credit_value(hint, ["\u4f5c\u8bcd", "\u586b\u8bcd", "\u8a5e", "\u8bcd", "lyricist", "lyrics by"])
    composer = extract_credit_value(hint, ["\u4f5c\u66f2", "\u66f2", "composer", "music by", "written by"])
    arranger = extract_credit_value(hint, ["\u7f16\u66f2", "\u7de8\u66f2", "arranger", "arranged by", "arrangement"])
    album = extract_labeled_value(hint, ["\u4e13\u8f91", "\u5c08\u8f2f", "album"])
    year = extract_labeled_value(hint, ["\u5e74\u4efd", "\u53d1\u884c", "\u767c\u884c", "year", "release"])
    if lyricist:
        out["lyricist"] = lyricist
    if composer:
        out["composer"] = composer
    if arranger:
        out["arranger"] = arranger
    if album:
        out["album"] = album
    year_match = re.search(r"(19|20)\d{2}", year or "")
    if year_match:
        out["year"] = year_match.group(0)
        out["release_date"] = year_match.group(0)
    return out

def int_or_zero(value):
    try:
        text = str(value or "").strip()
        if not text:
            return 0
        return int(float(text))
    except Exception:
        return 0

def optional_int_arg(args, prefix):
    for arg in args:
        if (arg or "").startswith(prefix):
            return int_or_zero((arg or "")[len(prefix):])
    return 0

def apply_album_batch_adjustment(meta, source, hint, optional_args):
    info = load_video_sidecar(source)
    title = extract_labeled_value(hint, ["\u6b4c\u540d", "\u66f2\u540d", "\u6b4c\u66f2", "\u66f2\u76ee", "title", "song"])
    artist = extract_labeled_value(hint, ["\u6b4c\u624b", "\u6f14\u5531", "\u6f14\u5531\u8005", "\u539f\u5531", "artist", "singer", "vocal", "performer"])
    album = extract_labeled_value(hint, ["\u4e13\u8f91", "\u5c08\u8f2f", "album"])
    year = extract_labeled_value(hint, ["\u5e74\u4efd", "\u53d1\u884c", "\u767c\u884c", "year", "release"])
    track_number = optional_int_arg(optional_args, "__TRACK_NUMBER=") or int_or_zero(info.get("playlist_index"))
    track_count = optional_int_arg(optional_args, "__TRACK_COUNT=") or int_or_zero(info.get("playlist_count"))

    if title:
        meta["title"] = title
    if artist:
        meta["artist"] = artist
        meta["album_artist"] = artist
    if album:
        meta["album"] = album
    year_match = re.search(r"(19|20)\d{2}", year or "")
    if year_match:
        meta["year"] = year_match.group(0)
        meta["release_date"] = year_match.group(0)
    if track_number > 0:
        meta["track_number"] = track_number
    if track_count > 0:
        meta["track_count"] = track_count
    official_track = {}
    if album and (title or meta.get("title")):
        official_track = find_album_track_order(title or meta.get("title"), artist or meta.get("artist"), album)
    if official_track:
        meta["title"] = official_track.get("title") or meta.get("title")
        meta["album"] = official_track.get("album") or meta.get("album")
        if not artist and official_track.get("artist"):
            meta["artist"] = official_track.get("artist")
        meta["album_artist"] = official_track.get("album_artist") or meta.get("album_artist") or meta.get("artist")
        meta["track_number"] = official_track.get("track_number") or meta.get("track_number") or 1
        meta["track_count"] = official_track.get("track_count") or meta.get("track_count") or 1
        meta["disc_number"] = official_track.get("disc_number") or meta.get("disc_number") or 1
        meta["disc_count"] = official_track.get("disc_count") or meta.get("disc_count") or 1
        if official_track.get("release_date") and not year_match:
            meta["release_date"] = official_track["release_date"]
            meta["year"] = official_track["release_date"][:4]
        if official_track.get("genre") and not meta.get("genre"):
            meta["genre"] = official_track["genre"]
        if official_track.get("artwork_url") and not has_artwork(meta):
            meta["artwork_url"] = official_track["artwork_url"]
        append_source(meta, (official_track.get("source") or "album tracklist") + f" match={official_track.get('match_score', 0):.4f}")
    meta["disc_number"] = meta.get("disc_number") or 1
    meta["disc_count"] = meta.get("disc_count") or 1
    append_source(meta, "album batch metadata applied")
    return meta

def lyric_lines(text):
    out = []
    for raw in (text or "").splitlines():
        line = re.sub(r"\[[0-9:.]+\]", "", raw).strip()
        line = re.sub(r"\s+", " ", line)
        if line:
            out.append(line)
    return out

def load_video_sidecar(source):
    sidecar = Path(str(source) + ".aminfo.json")
    if not sidecar.exists():
        return {}
    try:
        return json.loads(sidecar.read_text(encoding="utf-8"))
    except Exception:
        return {}

def local_live_details(source, hint):
    info = load_video_sidecar(source)
    context = "\n".join(
        str(part or "")
        for part in (
            Path(source).stem,
            hint,
            info.get("id"),
            info.get("title"),
            info.get("fulltitle"),
            info.get("description"),
            info.get("webpage_url"),
        )
    )
    details = {"venue": "", "event": "", "year": ""}
    video_id = (info.get("id") or "").strip()
    known = {
        # Officially documented as the Taipei Soul Power tour stop, not the
        # later digital-release year returned by catalogue search.
        "3dW6r8tByOA": {"event": "Soul Power", "venue": "\u53f0\u5317", "year": "2003"},
        "u8Bf5NKwQ00": {"event": "The One", "year": "2002"},
    }
    if video_id in known:
        details.update(known[video_id])

    if not details["venue"]:
        venues = [
            ("\u53f0\u5317", r"\u53f0\u5317|\u81fa\u5317|taipei"),
            ("\u9999\u6e2f", r"\u9999\u6e2f|hong\s*kong|hk\b"),
            ("\u5317\u4eac", r"\u5317\u4eac|beijing"),
            ("\u4e0a\u6d77", r"\u4e0a\u6d77|shanghai"),
            ("\u5e7f\u5dde", r"\u5e7f\u5dde|\u5ee3\u5dde|guangzhou"),
            ("\u6df1\u5733", r"\u6df1\u5733|shenzhen"),
            ("\u65b0\u52a0\u5761", r"\u65b0\u52a0\u5761|singapore"),
            ("\u9a6c\u6765\u897f\u4e9a", r"\u9a6c\u6765\u897f\u4e9a|\u99ac\u4f86\u897f\u4e9e|malaysia"),
        ]
        for name, pattern in venues:
            if re.search(pattern, context, flags=re.I):
                details["venue"] = name
                break

    if re.search(r"(?i)soul\s*power\s*(ii|2)|Soul\s*Power\s*II", context):
        details["event"] = "Soul Power II"
    elif re.search(r"(?i)soul\s*power", context):
        details["event"] = "Soul Power"
    elif re.search(r"(?i)the\s*one", context):
        details["event"] = "The One"

    year_match = re.search(r"(?<!\d)((?:19|20)\d{2})(?!\d)", context)
    if year_match:
        details["year"] = year_match.group(1)
    return details

def local_live_label(details):
    parts = []
    if details.get("event"):
        parts.append(details["event"])
    if details.get("venue"):
        parts.append(details["venue"])
    return " ".join(parts).strip()

def apply_live_adjustment(meta, source, hint):
    if not is_live_context(source, hint):
        return meta
    title = meta.get("title") or clean_name(source)
    title = re.sub(r"\s*\((live|\u73fe\u5834|\u73b0\u573a)\)\s*$", "", title, flags=re.I)
    details = local_live_details(source, hint)
    label = local_live_label(details)
    if label:
        meta["title"] = f"{title} ({label} Live)"
        album_label = f"{label} Live"
    else:
        meta["title"] = f"{title} (Live)"
        album_label = "Local Live"
    is_cover = bool(meta.get("original_artist")) or "cover version" in (meta.get("source") or "")
    has_verified_album = bool(meta.get("online_match") and meta.get("album"))
    if not is_cover and not has_verified_album:
        meta["album"] = f"{title} ({album_label}) - Single"
    if details.get("year"):
        meta["year"] = details["year"]
        meta["release_date"] = details["year"]
    elif meta.get("year"):
        meta["release_date"] = meta["year"]
    elif meta.get("release_date"):
        meta["year"] = str(meta["release_date"])[:4]
        meta["release_date"] = meta["year"]
    if not is_cover and not has_verified_album:
        meta["track_number"] = 1
        meta["track_count"] = 1
    old_source = meta.get("source") or ""
    meta["source"] = (old_source + "; kept as distinct local live recording").strip("; ")
    return meta

def clean_provider_text(text):
    text = html.unescape(text or "")
    text = re.sub(
        r"\\u([0-9a-fA-F]{4})",
        lambda m: chr(int(m.group(1), 16)),
        text,
    )
    text = re.sub(r"<.*?>", "", text)
    text = text.replace("\xa0", " ")
    text = re.sub(r"\s+", " ", text).strip()
    return text

def normalize_itunes_artwork(url):
    if not url:
        return ""
    return re.sub(r"/\d+x\d+bb\.(jpg|jpeg|png)$", r"/1200x1200bb.\1", url, flags=re.I)

def has_artwork(meta):
    if meta.get("artwork_mode") == "none":
        return False
    return bool(meta.get("artwork_file") or meta.get("artwork_url") or meta.get("generated_artwork"))

def append_source(meta, text):
    old_source = meta.get("source") or ""
    if text and text not in old_source:
        meta["source"] = (old_source + "; " + text).strip("; ")

def kuwo_image_url(short_path, kind="album"):
    short_path = (short_path or "").strip()
    if not short_path:
        return ""
    if short_path.startswith("//"):
        return "https:" + short_path
    if short_path.startswith("http://") or short_path.startswith("https://"):
        return short_path
    short_path = short_path.lstrip("/")
    if "/star/albumcover/" in short_path or "/star/starheads/" in short_path:
        return "https://img4.kuwo.cn/star/" + short_path.split("/star/", 1)[1]
    folder = "starheads" if kind == "artist" else "albumcover"
    return f"https://img4.kuwo.cn/star/{folder}/500/{short_path}"

def kuwo_album_artwork(result):
    for key in ("web_albumpic_short", "PICPATH"):
        url = kuwo_image_url(result.get(key), "album")
        if url:
            return url
    return ""

def netease_cover_url(pic_id):
    pic_id = str(pic_id or "").strip()
    if not pic_id or pic_id == "0":
        return ""
    magic = "3go8&$8*3*3h0k(2)2"
    mixed = bytes(ord(ch) ^ ord(magic[i % len(magic)]) for i, ch in enumerate(pic_id))
    digest = base64.b64encode(hashlib.md5(mixed).digest()).decode("ascii")
    digest = digest.replace("/", "_").replace("+", "-")
    return f"https://p1.music.126.net/{digest}/{pic_id}.jpg?param=1200y1200"

def normalize_netease_artwork(url):
    """Use the stable image host; some networks intermittently reset p3/p4."""
    value = (url or "").strip()
    if not value:
        return ""
    return re.sub(r"^https?://p[234]\.music\.126\.net/", "https://p1.music.126.net/", value, flags=re.I)

def search_netease(candidates, fast=False):
    best = None
    seen = set()
    explicit_artists = explicit_candidate_artists(candidates)
    for cand in candidates:
        fast_exact_match = False
        cand_wants_live = is_live_context("", cand.get("query") or "")
        terms = []
        if cand.get("title") and cand.get("artist"):
            terms.append(f"{cand['artist']} {cand['title']}")
            terms.append(f"{cand['title']} {cand['artist']}")
        terms.append(cand.get("query") or cand.get("title") or "")
        for term in [t for t in terms if t.strip() and t not in seen]:
            seen.add(term)
            songs = search_netease_song_rows(term, limit=5 if fast else 10)
            for rank, song in enumerate(songs):
                title = song.get("name") or ""
                artists = " ".join(a.get("name", "") for a in song.get("artists", []) if isinstance(a, dict))
                if not matches_any_explicit_artist(explicit_artists, artists):
                    continue
                album_obj = song.get("album") or {}
                album = album_obj.get("name") or f"{title} - Single"
                if not title:
                    continue
                title_score = title_match_score(cand.get("title") or term, title)
                if canonical_title(cand.get("title")) and canonical_title(cand.get("title")) == canonical_title(title):
                    title_score = max(title_score, 1.0)
                if cand.get("artist"):
                    artist_score = ratio(cand.get("artist"), artists)
                    if norm(cand.get("artist")) and norm(cand.get("artist")) in norm(artists):
                        artist_score = max(artist_score, 0.98)
                    if not artist_matches(cand.get("artist"), artists):
                        continue
                else:
                    artist_score = 0.75 if norm(artists) and norm(artists) in norm(term) else 0.35
                score = title_score * 0.68 + artist_score * 0.32
                if norm(title) and norm(title) in norm(term):
                    score += 0.05
                song_context = " ".join([title, album])
                song_is_live = is_live_context("", song_context)
                if cand_wants_live and song_is_live:
                    score += 0.18
                elif cand_wants_live:
                    score -= 0.12
                elif song_is_live:
                    score -= 0.15
                publish_time = album_obj.get("publishTime") or 0
                year = ""
                release_date = ""
                if publish_time:
                    try:
                        release_date = time.strftime("%Y-%m-%d", time.localtime(int(publish_time) / 1000))
                        year = release_date[:4]
                    except Exception:
                        pass
                artwork = normalize_netease_artwork(album_obj.get("picUrl")) or netease_cover_url(album_obj.get("picId"))
                item = {
                    "score": round(score, 4),
                    "rank": rank,
                    "song_id": song.get("id"),
                    "title": title,
                    "artist": artists,
                    "album": album,
                    "year": year,
                    "release_date": release_date,
                    "artwork_url": artwork,
                    "track_number": song.get("position") or song.get("no") or 1,
                    "track_count": album_obj.get("size") or 1,
                }
                # The provider search order is its popularity ranking. Use it
                # only as a tiebreaker when the title match is otherwise equal.
                if (best is None or item["score"] > best["score"] + 0.015
                        or (abs(item["score"] - best["score"]) <= 0.015 and item["rank"] < best["rank"])):
                    best = item
                exact_title = canonical_title(cand.get("title")) == canonical_title(title)
                if fast and exact_title and (
                        (cand.get("artist") and item["score"] >= 1.0)
                        or (not cand.get("artist") and rank == 0 and item["score"] >= 0.82)):
                    fast_exact_match = True
                    break
            if fast_exact_match:
                break
        if fast_exact_match:
            break
    if not best or best["score"] < 0.66:
        return None
    meta = {
        "title": best["title"],
        "artist": best["artist"] or "Unknown Artist",
        "album": best["album"] or f"{best['title']} - Single",
        "album_artist": best["artist"] or "Unknown Artist",
        "year": best["year"],
        "release_date": best["release_date"],
        "genre": "",
        "track_number": int_or_zero(best.get("track_number")) or 1,
        "track_count": int_or_zero(best.get("track_count")) or 1,
        "disc_number": 1,
        "disc_count": 1,
        "_provider": "netease",
        "_provider_score": best["score"],
        "_search_rank": best["rank"],
        "_netease_song_id": best.get("song_id"),
        "source": f"NetEase Search score={best['score']} rank={best['rank'] + 1}",
    }
    if best.get("artwork_url"):
        meta["artwork_url"] = best["artwork_url"]
    return meta

def find_itunes_artwork(meta, candidates):
    title = meta.get("title") or ""
    artist = meta.get("artist") or ""
    album = meta.get("album") or ""
    terms = []
    for term in (f"{artist} {title}", f"{title} {artist}", f"{artist} {album}", title):
        if term.strip():
            terms.append(term.strip())
    for cand in candidates:
        query = cand.get("query") or " ".join([cand.get("artist", ""), cand.get("title", "")]).strip()
        if query:
            terms.append(query)

    best = None
    seen = set()
    countries = ["CN", "HK", "TW", "US", "JP", "SG"]
    for term in terms:
        if term in seen:
            continue
        seen.add(term)
        for country in countries:
            qs = urllib.parse.urlencode({"term": term, "media": "music", "entity": "song", "limit": 10, "country": country})
            try:
                data = http_json(f"https://itunes.apple.com/search?{qs}")
            except Exception:
                continue
            for result in data.get("results", []):
                artwork = normalize_itunes_artwork(result.get("artworkUrl100") or "")
                if not artwork:
                    continue
                result_title = result.get("trackName") or ""
                result_artist = result.get("artistName") or ""
                title_score = title_match_score(title or term, result_title)
                if title_score < 0.90 or has_unrequested_version(title or term, result_title):
                    continue
                if artist and not strict_artist_matches(artist, result_artist):
                    continue
                score = title_score * 0.62
                score += (artist_match_score(artist, result_artist) if artist else 0.35) * 0.28
                score += (ratio(album, result.get("collectionName")) if album else 0.2) * 0.10
                if canonical_title(title) and canonical_title(title) == canonical_title(result_title):
                    score += 0.16
                if norm(artist) and norm(artist) == norm(result_artist):
                    score += 0.12
                item = {"score": score, "url": artwork, "country": country}
                if best is None or item["score"] > best["score"]:
                    best = item
    if best and best["score"] >= 0.78:
        return best
    return None

def known_video_override(source):
    """Use an exact original-song match for videos that carry enough identity."""
    video_id = (load_video_sidecar(source).get("id") or "").strip()
    known = {
        "BV1MwMc6gEr4": {
            "title": "\u843d\u53f6\u5f52\u6839",
            "artist": "\u738b\u529b\u5b8f",
            "album": "\u6539\u53d8\u81ea\u5df1",
            "album_artist": "\u738b\u529b\u5b8f",
            "year": "2007",
            "release_date": "2007",
            "genre": "Mandopop",
            "track_number": 1,
            "track_count": 1,
            "disc_number": 1,
            "disc_count": 1,
            "composer": "\u738b\u529b\u5b8f",
            "lyricist": "\u738b\u529b\u5b8f",
            "arranger": "\u5434\u5e86\u9686",
            "artwork_url": "https://is1-ssl.mzstatic.com/image/thumb/Music116/v4/d6/d1/bb/d6d1bb74-e2d3-743e-f514-5668390c4d67/gaibianziji_fengmian.jpg/1200x1200bb.jpg",
            "source": "Built-in verified fallback for Wang Leehom - Falling Leaf Returns to Root",
        },
    }
    item = known.get(video_id)
    return dict(item) if item else None

def fill_known_track_credits(meta):
    """Conservative credit fallbacks used only for an exact title-and-artist match."""
    title = norm(meta.get("title") or "")
    artist = meta.get("artist") or ""
    if title == norm("\u627e\u81ea\u5df1") and artist_matches("\u9676\u5586", artist):
        meta.setdefault("composer", "\u9676\u5586")
        meta.setdefault("lyricist", "\u9676\u5586")
        meta.setdefault("arranger", "\u9676\u5586")
        append_source(meta, "verified credit fallback for Tao Zhe - Zhao Zi Ji")
    airport_titles = {
        norm("\u98de\u673a\u573a\u768410:30"),
        norm("\u98db\u6a5f\u5834\u768410:30"),
    }
    if title in airport_titles and artist_matches("\u9676\u5586", artist):
        meta.setdefault("composer", "\u9676\u5586")
        meta.setdefault("lyricist", "\u9676\u5586 / \u5a03\u5a03")
        append_source(meta, "verified credit fallback for Tao Zhe - Airport at 10:30")
    if title == norm("\u9ed1\u8272\u5e7d\u9ed8") and strict_artist_matches("\u5468\u6770\u4f26", artist):
        meta.setdefault("composer", "\u5468\u6770\u4f26")
        meta.setdefault("lyricist", "\u5468\u6770\u4f26")
        meta.setdefault("arranger", "\u949f\u5174\u6c11")
        append_source(meta, "verified credit fallback for Jay Chou - Black Humor")
    return meta

def find_kuwo_artwork(meta, candidates):
    title = meta.get("title") or ""
    artist = meta.get("artist") or ""
    search_candidates = [{"title": title, "artist": artist, "query": f"{artist} {title}".strip()}] + candidates
    best = None
    for cand in search_candidates:
        term = cand.get("query") or " ".join([cand.get("artist", ""), cand.get("title", "")]).strip()
        if not term:
            continue
        qs = urllib.parse.urlencode({
            "all": term,
            "ft": "music",
            "client": "kt",
            "pn": 0,
            "rn": 12,
            "rformat": "json",
            "encoding": "utf8",
        })
        try:
            req = urllib.request.Request(f"http://search.kuwo.cn/r.s?{qs}", headers={"User-Agent": USER_AGENT})
            with urllib.request.urlopen(req, timeout=12) as resp:
                data = ast.literal_eval(resp.read().decode("utf-8", "replace"))
        except Exception:
            continue
        for result in data.get("abslist", []):
            artwork = kuwo_album_artwork(result)
            if not artwork:
                continue
            r_title = clean_provider_text(result.get("NAME") or result.get("SONGNAME"))
            r_artist = clean_provider_text(result.get("ARTIST"))
            expected_title = title or cand.get("title") or term
            expected_artist = artist or cand.get("artist") or ""
            title_score = title_match_score(expected_title, r_title)
            if title_score < 0.90 or has_unrequested_version(expected_title, r_title):
                continue
            if expected_artist and not strict_artist_matches(expected_artist, r_artist):
                continue
            score = title_score * 0.70
            score += (artist_match_score(expected_artist, r_artist) if expected_artist else 0.35) * 0.30
            songname = clean_provider_text(result.get("SONGNAME"))
            if any(x in songname.lower() for x in ("dj", "slowed", "remix", "\u7248")) and norm(songname) != norm(r_title):
                score -= 0.18
            item = {"score": score, "url": artwork}
            if best is None or item["score"] > best["score"]:
                best = item
    if best and best["score"] >= 0.78:
        return best
    return None

def find_netease_artwork(meta, candidates):
    title = meta.get("title") or ""
    artist = meta.get("artist") or ""
    terms = [f"{artist} {title}".strip(), f"{title} {artist}".strip()]
    for cand in candidates:
        if cand.get("query"):
            terms.append(cand["query"])
    best = None
    seen = set()
    for term in [t for t in terms if t and t not in seen]:
        seen.add(term)
        data = urllib.parse.urlencode({"s": term, "type": 1, "offset": 0, "total": "true", "limit": 10}).encode("utf-8")
        try:
            req = urllib.request.Request(
                "https://music.163.com/api/search/get",
                data=data,
                headers={"User-Agent": USER_AGENT, "Referer": "https://music.163.com/"},
            )
            with urllib.request.urlopen(req, timeout=12) as resp:
                payload = json.loads(resp.read().decode("utf-8", "replace"))
        except Exception:
            continue
        for song in (payload.get("result") or {}).get("songs", []):
            album_obj = song.get("album") or {}
            artists = " ".join(a.get("name", "") for a in song.get("artists", []) if isinstance(a, dict))
            artwork = normalize_netease_artwork(album_obj.get("picUrl")) or netease_cover_url(album_obj.get("picId"))
            if not artwork:
                continue
            song_title = song.get("name") or ""
            title_score = title_match_score(title or term, song_title)
            if title_score < 0.90 or has_unrequested_version(title or term, song_title):
                continue
            if artist and not strict_artist_matches(artist, artists):
                continue
            score = title_score * 0.68
            score += (artist_match_score(artist, artists) if artist else 0.35) * 0.32
            if canonical_title(title) and canonical_title(title) == canonical_title(song_title):
                score += 0.12
            if norm(artist) and norm(artist) in norm(artists):
                score += 0.10
            item = {"score": score, "url": artwork}
            if best is None or item["score"] > best["score"]:
                best = item
    if best and best["score"] >= 0.78:
        return best
    return None

def enrich_artwork(meta, candidates):
    if has_artwork(meta):
        return meta
    for provider_name, finder in (
        ("iTunes artwork fallback", find_itunes_artwork),
        ("Kuwo artwork fallback", find_kuwo_artwork),
        ("NetEase artwork fallback", find_netease_artwork),
    ):
        found = finder(meta, candidates)
        if found and found.get("url"):
            meta["artwork_url"] = found["url"]
            append_source(meta, f"{provider_name} score={found.get('score', 0):.4f}")
            return meta
    return meta

def enrich_live_cover_artwork(meta, source, hint, is_cover):
    """Prefer official concert artwork for a known local live recording."""
    if not is_live_context(source, hint):
        return meta
    details = local_live_details(source, hint)
    event = (details.get("event") or "").strip()
    performer = (meta.get("artist") or "").strip()
    if not event or not performer:
        return meta
    query = urllib.parse.urlencode({
        "term": f"{performer} {event}",
        "media": "music",
        "entity": "album",
        "limit": 15,
        "country": "TW",
    })
    try:
        data = http_json(f"https://itunes.apple.com/search?{query}")
    except Exception:
        return meta
    best = None
    for result in data.get("results", []):
        collection = result.get("collectionName") or ""
        artist = result.get("artistName") or result.get("collectionArtistName") or ""
        artwork = normalize_itunes_artwork(result.get("artworkUrl100") or "")
        if not artwork:
            continue
        event_score = ratio(event, collection)
        artist_score = ratio(performer, artist)
        if norm(event) not in norm(collection) and event_score < 0.62:
            continue
        score = event_score * 0.70 + artist_score * 0.30
        item = {"score": score, "url": artwork, "collection": collection}
        if best is None or item["score"] > best["score"]:
            best = item
    if best and best["score"] >= 0.65:
        meta["artwork_url"] = best["url"]
        append_source(meta, f"live concert artwork {best['collection']} score={best['score']:.4f}")
    return meta

def search_kuwo(candidates):
    best = None
    explicit_artists = explicit_candidate_artists(candidates)
    for cand in candidates:
        terms = []
        if cand.get("title") and cand.get("artist"):
            terms.append(f"{cand['artist']} {cand['title']}")
            terms.append(f"{cand['title']} {cand['artist']}")
        terms.append(cand.get("query") or cand.get("title") or "")
        for term in [t for t in terms if t.strip()]:
            qs = urllib.parse.urlencode({
                "all": term,
                "ft": "music",
                "client": "kt",
                "pn": 0,
                "rn": 10,
                "rformat": "json",
                "encoding": "utf8",
            })
            url = f"http://search.kuwo.cn/r.s?{qs}"
            try:
                req = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
                with urllib.request.urlopen(req, timeout=12) as resp:
                    text = resp.read().decode("utf-8", "replace")
                data = ast.literal_eval(text)
            except Exception:
                continue

            for result in data.get("abslist", []):
                title = clean_provider_text(result.get("NAME") or result.get("SONGNAME"))
                artist = clean_provider_text(result.get("ARTIST"))
                if not matches_any_explicit_artist(explicit_artists, artist):
                    continue
                album = clean_provider_text(result.get("ALBUM"))
                if not title:
                    continue
                title_score = ratio(cand.get("title") or term, title)
                if norm(title) and norm(title) in norm(term):
                    title_score = max(title_score, 0.92)
                if cand.get("artist"):
                    artist_score = ratio(cand.get("artist"), artist)
                    if not artist_matches(cand.get("artist"), artist):
                        continue
                else:
                    artist_score = 0.75 if norm(artist) and norm(artist) in norm(term) else 0.35
                score = title_score * 0.66 + artist_score * 0.34
                songname = clean_provider_text(result.get("SONGNAME"))
                if any(x in songname.lower() for x in ("dj", "slowed", "remix", "\u7248")) and norm(songname) != norm(title):
                    score -= 0.08
                item = {
                    "score": round(score, 4),
                    "data": result,
                    "title": title,
                    "artist": artist,
                    "album": album,
                    "artwork_url": kuwo_album_artwork(result),
                }
                if best is None or item["score"] > best["score"]:
                    best = item
    if not best or best["score"] < 0.64:
        return None

    title = best["title"]
    artist = best["artist"] or "Unknown Artist"
    album = best["album"] or f"{title} - Single"
    meta = {
        "title": title,
        "artist": artist,
        "album": album,
        "album_artist": artist,
        "year": "",
        "release_date": "",
        "genre": "",
        "track_number": 1,
        "track_count": 1,
        "disc_number": 1,
        "disc_count": 1,
        "_provider": "kuwo",
        "_provider_score": best["score"],
        "source": f"Kuwo Search score={best['score']}",
    }
    if best.get("artwork_url"):
        meta["artwork_url"] = best["artwork_url"]
    return meta

def lookup_verified_metadata(candidates, wants_live=False, fast=False, allow_unconfirmed_title_only=False):
    """Select metadata only after identity checks and cross-provider corroboration."""
    lookup_candidates = compact_candidates(candidates, limit=3 if fast else 8)
    explicit_artists = explicit_candidate_artists(lookup_candidates)

    # Cover videos commonly provide only the composition title after their
    # performer is removed. For CJK titles, NetEase's exact-title order is a
    # useful popularity signal and avoids letting a later cover from iTunes
    # become the supposed original. The same cached search also feeds lyrics.
    if candidates_have_cjk(lookup_candidates) and not explicit_artists:
        try:
            popularity_anchor = search_netease(lookup_candidates, fast=True)
        except Exception:
            popularity_anchor = None
        if popularity_anchor:
            evidence = metadata_identity_evidence(popularity_anchor, lookup_candidates, wants_live)
            exact_title = evidence["title_score"] >= 0.98
            top_ranked = int_or_zero(popularity_anchor.get("_search_rank")) == 0
            if exact_title and top_ranked and metadata_is_trusted(popularity_anchor, lookup_candidates, wants_live):
                append_source(popularity_anchor, "original selected from top-ranked exact-title result")
                popularity_anchor["_identity_verified"] = True
                return popularity_anchor

    providers = {
        "itunes": lambda: search_itunes(lookup_candidates, fast=fast),
        "netease": lambda: search_netease(lookup_candidates, fast=fast),
    }
    results = []
    with ThreadPoolExecutor(max_workers=len(providers)) as executor:
        futures = {executor.submit(loader): name for name, loader in providers.items()}
        for future in as_completed(futures):
            name = futures[future]
            try:
                meta = future.result()
            except Exception:
                meta = None
            if meta:
                meta = dict(meta)
                meta.setdefault("_provider", name)
                results.append(meta)

    trusted = []
    for meta in results:
        evidence = metadata_identity_evidence(meta, lookup_candidates, wants_live)
        if metadata_is_trusted(meta, lookup_candidates, wants_live):
            trusted.append((meta, evidence))

    # Kuwo remains a fallback. It must never outrank a verified official or
    # NetEase result merely because its search ranking is more aggressive.
    if not trusted:
        try:
            meta = search_kuwo(lookup_candidates)
        except Exception:
            meta = None
        if meta:
            evidence = metadata_identity_evidence(meta, lookup_candidates, wants_live)
            if metadata_is_trusted(meta, lookup_candidates, wants_live):
                trusted.append((meta, evidence))

    if not trusted:
        return None

    if not explicit_artists:
        # A second-or-later title-only result can be an unrelated namesake.
        # Keep it only when another provider independently agrees on artist.
        filtered = []
        for meta, evidence in trusted:
            is_lower_rank_netease = (
                meta.get("_provider") == "netease"
                and int_or_zero(meta.get("_search_rank")) > 0
            )
            corroborated = any(
                other is not meta and metadata_agrees(meta, other)
                for other, _ in trusted
            )
            explicit_cover_fallback = (
                allow_unconfirmed_title_only
                and is_lower_rank_netease
                and evidence["title_score"] >= 0.98
                and bool(meta.get("artist"))
            )
            if explicit_cover_fallback:
                append_source(meta, "original selected from exact-title explicit cover fallback")
            if not is_lower_rank_netease or corroborated or explicit_cover_fallback:
                filtered.append((meta, evidence))
        trusted = filtered

    if not trusted:
        return None

    ranked = []
    for meta, evidence in trusted:
        agreement_count = sum(
            1 for other, _ in trusted
            if metadata_agrees(meta, other)
        )
        provider_bonus = 0.015 if meta.get("_provider") == "itunes" else 0.0
        score = evidence["score"] + release_quality(meta) + provider_bonus
        if agreement_count > 1:
            score += 0.12
        ranked.append((score, meta, evidence, agreement_count))

    _, winner, _, _ = max(ranked, key=lambda item: item[0])
    corroborating = [meta for _, meta, _, _ in ranked if metadata_agrees(winner, meta)]
    primary = max(
        corroborating,
        key=lambda meta: release_quality(meta) + (0.015 if meta.get("_provider") == "itunes" else 0.0),
    )
    result = merge_verified_metadata(primary, corroborating)
    provider_names = sorted({str(meta.get("_provider") or "online") for meta in corroborating})
    if len(provider_names) > 1:
        append_source(result, "identity verified by " + " + ".join(provider_names))
    else:
        append_source(result, "strict title and artist identity match")
    result["_identity_verified"] = True
    return result

def safe_filename(text, max_length=120):
    """Make a human-readable Windows filename without trusting page metadata."""
    text = str(text or "")
    text = re.sub(r"[\x00-\x1f\x7f]+", " ", text)
    text = re.sub(r'[\\/:*?"<>|]+', "_", text)
    text = re.sub(r"\s+", " ", text).strip(" .")
    if max_length and len(text) > max_length:
        text = text[:max_length].rstrip(" .")
    return text or "Imported Track"

def import_output_name(meta, token):
    title = safe_filename(meta.get("title") or "Untitled", max_length=72)
    artist = safe_filename(meta.get("artist") or "Unknown Artist", max_length=44)
    stem = safe_filename(f"{title} - {artist}", max_length=120)
    return f"{stem} [{token[:8]}].m4a"

def ffmpeg_error_text(stderr):
    if isinstance(stderr, bytes):
        stderr = stderr.decode("utf-8", "replace")
    lines = [line.strip() for line in str(stderr or "").splitlines() if line.strip()]
    return "\n".join(lines[-12:]) or "No diagnostic details were returned."

def convert_audio(source, dest, force_encode=False):
    ffmpeg = imageio_ffmpeg.get_ffmpeg_exe()
    if not force_encode:
        copy_cmd = [ffmpeg, "-y", "-i", source, "-map", "0:a:0", "-vn", "-c:a", "copy", "-movflags", "+faststart", dest]
        copy_result = subprocess.run(copy_cmd, stdout=subprocess.DEVNULL, stderr=subprocess.PIPE)
        if copy_result.returncode == 0:
            return "copied"
    encode_cmd = [ffmpeg, "-y", "-i", source, "-map", "0:a:0", "-vn", "-c:a", "aac", "-b:a", "256k", "-movflags", "+faststart", dest]
    encode_result = subprocess.run(encode_cmd, stdout=subprocess.DEVNULL, stderr=subprocess.PIPE)
    if encode_result.returncode != 0:
        raise RuntimeError(
            "Audio conversion failed. "
            + ffmpeg_error_text(encode_result.stderr)
        )
    return "encoded-aac"

def generated_artwork_bytes(kind):
    if kind != "hand_in_hand":
        return "", b""
    try:
        from PIL import Image, ImageDraw, ImageFont
        img = Image.new("RGB", (1200, 1200), "#f7f2e8")
        draw = ImageDraw.Draw(img)
        try:
            title_font = ImageFont.truetype("arial.ttf", 106)
            sub_font = ImageFont.truetype("arial.ttf", 46)
            small_font = ImageFont.truetype("arial.ttf", 36)
        except Exception:
            title_font = sub_font = small_font = ImageFont.load_default()
        draw.rectangle((74, 74, 1126, 1126), outline="#1e4f5f", width=10)
        draw.rectangle((114, 114, 1086, 1086), outline="#c84c31", width=4)
        draw.text((600, 470), "HAND IN HAND", fill="#1e4f5f", font=title_font, anchor="mm")
        draw.text((600, 600), "WANG LEEHOM / DAVID TAO / ALL STARS", fill="#2c2c2c", font=sub_font, anchor="mm")
        draw.text((600, 690), "2003 CHARITY SINGLE", fill="#c84c31", font=small_font, anchor="mm")
        bio = BytesIO()
        img.save(bio, format="JPEG", quality=94)
        return "image/jpeg", bio.getvalue()
    except Exception:
        return "", b""

def artwork_image_format(content_type="", source="", data=b""):
    if data.startswith(b"\x89PNG\r\n\x1a\n"):
        return MP4Cover.FORMAT_PNG
    if data.startswith(b"\xff\xd8\xff"):
        return MP4Cover.FORMAT_JPEG
    if "png" in (content_type or "").lower() or (source or "").lower().endswith(".png"):
        return MP4Cover.FORMAT_PNG
    return MP4Cover.FORMAT_JPEG

def read_local_artwork(path):
    path = (path or "").strip()
    if not path:
        return "", b""
    try:
        return "", Path(path).read_bytes()
    except OSError:
        return "", b""

def preview_artwork(meta):
    """Inline local artwork; remote artwork is loaded by the open preview form."""
    if meta.get("artwork_mode") == "none":
        return "", ""
    content_type = ""
    data = b""
    local_path = meta.get("artwork_file")
    if local_path:
        content_type, data = read_local_artwork(local_path)
    elif meta.get("generated_artwork"):
        content_type, data = generated_artwork_bytes(meta.get("generated_artwork"))
    if not data:
        return "", ""
    return content_type or "image/jpeg", base64.b64encode(data).decode("ascii")

def parse_metadata_overrides(optional_args):
    prefix = "__METADATA_OVERRIDES_B64="
    file_prefix = "__METADATA_OVERRIDES_FILE="
    for arg in optional_args:
        if isinstance(arg, str) and arg.startswith(file_prefix):
            try:
                value = json.loads(Path(arg[len(file_prefix):]).read_text(encoding="utf-8"))
                return value if isinstance(value, dict) else {}
            except Exception:
                return {}
        if not isinstance(arg, str) or not arg.startswith(prefix):
            continue
        try:
            value = json.loads(base64.b64decode(arg[len(prefix):]).decode("utf-8"))
            return value if isinstance(value, dict) else {}
        except Exception:
            return {}
    return {}

def parse_precomputed_metadata(optional_args):
    """Load the exact metadata that was shown in the pre-import preview."""
    prefix = "__PRECOMPUTED_METADATA_FILE="
    for arg in optional_args:
        if not isinstance(arg, str) or not arg.startswith(prefix):
            continue
        try:
            value = json.loads(Path(arg[len(prefix):]).read_text(encoding="utf-8"))
            return value if isinstance(value, dict) else {}
        except Exception:
            return {}
    return {}

def apply_metadata_overrides(meta, overrides):
    """User-entered pre-import values are authoritative over online metadata."""
    if not overrides:
        return meta
    meta = dict(meta)
    text_keys = (
        "title", "artist", "album", "album_artist", "genre", "composer",
        "lyricist", "arranger", "lyrics", "isrc", "musicbrainz_recording_id",
    )
    for key in text_keys:
        if key in overrides:
            meta[key] = str(overrides.get(key) or "").strip()
    for key in ("track_number", "track_count", "disc_number", "disc_count"):
        if key in overrides:
            try:
                meta[key] = int(str(overrides.get(key) or "0").strip())
            except (TypeError, ValueError):
                meta[key] = 0
    if "year" in overrides:
        year = str(overrides.get("year") or "").strip()
        meta["year"] = year
        release_date = str(overrides.get("release_date") or "").strip()
        if not release_date or (year and not release_date.startswith(year)):
            meta["release_date"] = year
        else:
            meta["release_date"] = release_date
    elif "release_date" in overrides:
        meta["release_date"] = str(overrides.get("release_date") or "").strip()

    artwork_mode = str(overrides.get("artwork_mode") or "auto").strip().lower()
    meta["artwork_mode"] = artwork_mode if artwork_mode in ("auto", "file", "none") else "auto"
    if meta["artwork_mode"] == "file":
        meta["artwork_file"] = str(overrides.get("artwork_file") or "").strip()
        meta.pop("artwork_url", None)
        meta.pop("generated_artwork", None)
    elif meta["artwork_mode"] == "none":
        meta.pop("artwork_file", None)
        meta.pop("artwork_url", None)
        meta.pop("generated_artwork", None)
    else:
        if "artwork_url" in overrides:
            meta["artwork_url"] = str(overrides.get("artwork_url") or "").strip()
        if "generated_artwork" in overrides:
            meta["generated_artwork"] = str(overrides.get("generated_artwork") or "").strip()
        meta.pop("artwork_file", None)
    meta["_artwork_locked_by_preview"] = True
    return meta

def metadata_preview_payload(meta):
    preview_lyrics = meta.get("lyrics") or ""
    if not lyrics_match_expected_script(meta.get("title") or "", preview_lyrics):
        preview_lyrics = ""
    preview_lyrics = append_visible_lyricist(preview_lyrics, meta.get("lyricist"))
    artwork_mime, artwork_data = preview_artwork(meta)
    return {
        "title": meta.get("title") or "",
        "artist": meta.get("artist") or "",
        "album": meta.get("album") or "",
        "album_artist": meta.get("album_artist") or meta.get("artist") or "",
        "year": meta.get("year") or meta.get("release_date", "")[:4],
        "release_date": meta.get("release_date") or "",
        "genre": meta.get("genre") or "",
        "composer": meta.get("composer") or "",
        "lyricist": meta.get("lyricist") or "",
        "arranger": meta.get("arranger") or "",
        "isrc": meta.get("isrc") or "",
        "musicbrainz_recording_id": meta.get("musicbrainz_recording_id") or "",
        "track_number": meta.get("track_number") or 1,
        "track_count": meta.get("track_count") or 1,
        "disc_number": meta.get("disc_number") or 1,
        "disc_count": meta.get("disc_count") or 1,
        "lyrics": preview_lyrics,
        "artwork_url": meta.get("artwork_url") or "",
        "generated_artwork": meta.get("generated_artwork") or "",
        "artwork_mime": artwork_mime,
        "artwork_data": artwork_data,
        "original_artist": meta.get("original_artist") or "",
        "original_album": meta.get("original_album") or "",
        "detected_cover": bool(meta.get("detected_cover")),
        "source": meta.get("source") or "",
        "online_match": bool(meta.get("online_match")),
    }

def tag_file(path, meta):
    audio = MP4(path)
    if audio.tags is None:
        audio.add_tags()
    tags = audio.tags
    def put(key, value):
        tags.pop(key, None)
        if value not in (None, ""):
            tags[key] = [str(value)]

    put("\xa9nam", meta.get("title"))
    put("\xa9ART", meta.get("artist"))
    put("aART", meta.get("album_artist") or meta.get("artist"))
    put("\xa9alb", meta.get("album"))
    put("\xa9day", meta.get("release_date") or meta.get("year"))
    put("\xa9gen", meta.get("genre"))
    put("\xa9wrt", meta.get("composer"))
    put("\xa9lyr", meta.get("lyrics"))
    put("\xa9cmt", meta.get("source"))
    tags["trkn"] = [(int(meta.get("track_number") or 1), int(meta.get("track_count") or 1))]
    tags["disk"] = [(int(meta.get("disc_number") or 1), int(meta.get("disc_count") or 1))]

    freeform = {
        "LYRICIST": meta.get("lyricist"),
        "ARRANGER": meta.get("arranger"),
        "ISRC": meta.get("isrc"),
        "MusicBrainz Track Id": meta.get("musicbrainz_recording_id"),
    }
    for name, value in freeform.items():
        tags.pop(f"----:com.apple.iTunes:{name}", None)
        if value:
            tags[f"----:com.apple.iTunes:{name}"] = [str(value).encode("utf-8")]

    tags.pop("covr", None)
    if meta.get("artwork_mode") != "none":
        content_type = ""
        data = b""
        artwork_file = meta.get("artwork_file")
        if artwork_file:
            content_type, data = read_local_artwork(artwork_file)
        elif meta.get("generated_artwork"):
            content_type, data = generated_artwork_bytes(meta.get("generated_artwork"))
        elif meta.get("artwork_url"):
            try:
                content_type, data = http_bytes(meta.get("artwork_url"))
            except Exception:
                pass
        if data:
            tags["covr"] = [MP4Cover(data, imageformat=artwork_image_format(content_type, artwork_file or meta.get("artwork_url") or "", data))]
    audio.save()

def import_to_apple_music(source, auto_add, meta, reused_preview=False):
    job_token = uuid.uuid4().hex
    out_name = import_output_name(meta, job_token)
    # The conversion path must never contain an untrusted title or page description.
    tmp_dest = str(Path(os.environ.get("TEMP", ".")) / f"am-auto-{job_token}.m4a")
    mode = convert_audio(source, tmp_dest)
    try:
        tag_file(tmp_dest, meta)
    except Exception:
        if mode != "copied":
            raise
        try:
            os.remove(tmp_dest)
        except OSError:
            pass
        mode = convert_audio(source, tmp_dest, force_encode=True)
        tag_file(tmp_dest, meta)
    tmp_path = Path(tmp_dest)
    target_dir = Path(auto_add)
    if not tmp_path.is_file():
        raise RuntimeError("Processed audio file was not created before Apple Music import")
    target_dir.mkdir(parents=True, exist_ok=True)
    final_dest = str(target_dir / out_name)
    try:
        shutil.copy2(tmp_dest, final_dest)
    except FileNotFoundError:
        # Apple Music can remove and recreate its watch folder while running.
        target_dir.mkdir(parents=True, exist_ok=True)
        if not tmp_path.is_file():
            mode = convert_audio(source, tmp_dest, force_encode=True)
            tag_file(tmp_dest, meta)
        shutil.copy2(tmp_dest, final_dest)
    try:
        os.remove(tmp_dest)
    except OSError:
        pass

    return {
        "title": meta.get("title"),
        "artist": meta.get("artist"),
        "album": meta.get("album"),
        "year": meta.get("year") or meta.get("release_date", "")[:4],
        "composer": meta.get("composer") or "",
        "lyricist": meta.get("lyricist") or "",
        "arranger": meta.get("arranger") or "",
        "lyrics": bool(meta.get("lyrics")),
        "artwork": has_artwork(meta),
        "mode": mode,
        "dest": final_dest,
        "source": meta.get("source"),
        "reused_preview": bool(reused_preview),
    }

def main():
    source, hint, auto_add = sys.argv[1:4]
    force_live = len(sys.argv) > 4 and sys.argv[4] == "--force-live"
    force_studio = len(sys.argv) > 4 and sys.argv[4] == "--force-studio"
    optional_args = sys.argv[5:]
    album_batch = "--album-batch" in optional_args
    probe_only = "--probe-only" in optional_args
    preview_full = "--preview-full" in optional_args
    fast_probe = "--fast-probe" in optional_args
    detect_cover = "__AUTO_COVER_DETECT__" in optional_args
    metadata_overrides = parse_metadata_overrides(optional_args)
    precomputed_meta = parse_precomputed_metadata(optional_args)
    if precomputed_meta and not probe_only and not preview_full:
        # The user has already reviewed this exact payload. Avoid re-running
        # every network lookup after confirmation, then apply their edits last.
        meta = apply_metadata_overrides(precomputed_meta, metadata_overrides)
        meta = finalize_visible_lyricist(meta)
        print(json.dumps(import_to_apple_music(source, auto_add, meta, reused_preview=True), ensure_ascii=False))
        return
    cover_artist = ""
    for arg in optional_args:
        arg = (arg or "").strip()
        if not arg or arg.startswith("--") or arg.startswith("__") or arg == "__NO_COVER_ARTIST__":
            continue
        cover_artist = clean_cover_performer(arg)
        break
    live_hint = hint
    if force_live:
        live_hint = hint + " __force_live__"
    elif force_studio:
        live_hint = hint + " __force_studio__"
    candidates = parse_candidates(source, hint)
    if force_live:
        candidates = with_live_search_variants(candidates)
    explicit_cover = explicit_cover_context(source, hint)
    performer_metadata_candidates = []
    performer_release_meta = None
    if cover_artist:
        metadata_candidates = with_cover_original_artist_candidates(
            candidates,
            original_song_candidates(candidates),
            cover_artist,
        )
    elif detect_cover:
        performer_metadata_candidates = current_performer_candidates(candidates)
        metadata_candidates = original_song_candidates(candidates)
    else:
        metadata_candidates = candidates
    if cover_artist or detect_cover:
        metadata_candidates = with_original_artist_context(metadata_candidates, source, hint)
    override_meta = known_video_override(source) or known_override(metadata_candidates)
    if override_meta:
        meta = override_meta
    else:
        meta = None
        if performer_metadata_candidates:
            wants_live = is_live_context(source, live_hint)
            fast_lookup = fast_probe or preview_full
            with ThreadPoolExecutor(max_workers=2) as executor:
                performer_future = executor.submit(
                    lookup_verified_metadata,
                    performer_metadata_candidates,
                    wants_live,
                    fast_lookup,
                )
                original_future = executor.submit(
                    lookup_verified_metadata,
                    metadata_candidates,
                    False,
                    fast_lookup,
                    explicit_cover,
                )
                performer_meta = performer_future.result()
                original_meta = original_future.result()
            performer_release_meta = performer_meta
            if (
                performer_meta is not None
                and (
                    original_meta is None
                    or strict_artist_matches(
                        performer_meta.get("artist") or "",
                        original_meta.get("artist") or "",
                    )
                )
            ):
                meta = performer_meta
                metadata_candidates = performer_metadata_candidates
            elif original_meta is not None:
                # A published live cover may exist under the current performer.
                # The independently popular title-only result still identifies
                # the composition's original artist for cover handling.
                meta = original_meta
        if meta is None:
            meta = lookup_verified_metadata(
                metadata_candidates,
                wants_live=False if detect_cover else is_live_context(source, live_hint),
                fast=(fast_probe or preview_full),
                allow_unconfirmed_title_only=explicit_cover,
            )
    fallback = metadata_candidates[0]
    if meta is None:
        meta = {
            "title": fallback.get("title") or clean_name(source),
            "artist": fallback.get("artist") or "Unknown Artist",
            "album": "",
            "album_artist": fallback.get("artist") or "Unknown Artist",
            "track_number": 1,
            "track_count": 1,
            "disc_number": 1,
            "disc_count": 1,
            "source": "No online match; used local filename/hint",
        }
        meta["online_match"] = False
    else:
        meta["online_match"] = True

    detected_cover = False
    if detect_cover and meta.get("online_match"):
        original_artist = meta.get("artist") or ""
        original_title = meta.get("title") or ""
        video_performer = detect_cover_performer(candidates, original_title, original_artist)
        if video_performer and original_artist:
            cover_artist = video_performer
            detected_cover = True

    # Preserve the original recording identity before replacing its artist
    # with a cover performer. Credit and lyric lookups use this identity.
    credit_lookup_meta = dict(meta)

    if cover_artist:
        # Resolve art from the original recording before replacing the artist.
        # Otherwise a cover performer's unrelated release can win the artwork search.
        if not probe_only:
            try:
                meta = enrich_artwork(meta, metadata_candidates)
            except Exception:
                append_source(meta, "original artwork lookup unavailable")
        original_title = meta.get("title") or clean_name(source)
        original_artist = meta.get("artist") or ""
        original_album = meta.get("album") or ""
        meta["artist"] = cover_artist
        meta["album_artist"] = meta.get("album_artist") or original_artist
        meta["album"] = original_album
        old_source = meta.get("source") or ""
        meta["source"] = (old_source + "; artist adjusted as cover version").strip("; ")
        meta["original_artist"] = original_artist
        meta["original_album"] = original_album
        if (
            is_live_context(source, live_hint)
            and performer_release_meta
            and strict_artist_matches(cover_artist, performer_release_meta.get("artist") or "")
            and performer_release_meta.get("artwork_url")
        ):
            meta["_live_performer_artwork_url"] = performer_release_meta["artwork_url"]
            meta["artwork_url"] = performer_release_meta["artwork_url"]
            append_source(meta, "live performer artwork from verified release")

    meta["detected_cover"] = bool(detected_cover)

    if album_batch:
        meta = apply_album_batch_adjustment(meta, source, hint, optional_args)

    if probe_only:
        preview_meta = dict(meta)
        if not album_batch:
            preview_meta = apply_live_adjustment(preview_meta, source, live_hint)
            if not fast_probe:
                preview_meta = enrich_live_cover_artwork(preview_meta, source, live_hint, bool(cover_artist))
        if not fast_probe:
            preview_meta = enrich_artwork(preview_meta, metadata_candidates)
        print(json.dumps({
            "title": preview_meta.get("title"),
            "artist": preview_meta.get("artist"),
            "album": preview_meta.get("album"),
            "year": preview_meta.get("year") or preview_meta.get("release_date", "")[:4],
            "original_artist": preview_meta.get("original_artist") or "",
            "original_album": preview_meta.get("original_album") or "",
            "detected_cover": detected_cover,
            "genre": preview_meta.get("genre") or "",
            "source": preview_meta.get("source"),
            "artwork": bool(preview_meta.get("artwork_url") or preview_meta.get("generated_artwork")),
            "online_match": bool(preview_meta.get("online_match")),
        }, ensure_ascii=False))
        return

    hint_credits = extract_hint_credits(hint)
    for key, value in hint_credits.items():
        if value and not meta.get(key):
            meta[key] = value
    if not album_batch:
        meta = apply_live_adjustment(meta, source, live_hint)
        try:
            meta = enrich_live_cover_artwork(meta, source, live_hint, bool(cover_artist))
        except Exception:
            append_source(meta, "live artwork lookup unavailable")
    lyric_meta = dict(meta)
    if meta.get("original_artist"):
        lyric_meta["artist"] = meta["original_artist"]
        lyric_meta["album"] = meta.get("original_album") or lyric_meta.get("album")
    prefer_live_lyrics = is_live_context(source, live_hint) and not bool(meta.get("original_artist"))
    credit_lookup_meta["artist"] = lyric_meta.get("artist") or credit_lookup_meta.get("artist")
    credit_lookup_meta["album"] = lyric_meta.get("album") or credit_lookup_meta.get("album")
    seeded_credits = fill_known_track_credits(dict(
        credit_lookup_meta,
        composer=meta.get("composer") or "",
        lyricist=meta.get("lyricist") or "",
        arranger=meta.get("arranger") or "",
    ))
    for key in ("composer", "lyricist", "arranger", "isrc", "musicbrainz_recording_id"):
        if seeded_credits.get(key) and not meta.get(key):
            meta[key] = seeded_credits[key]
    if seeded_credits.get("source"):
        meta["source"] = seeded_credits["source"]
    with ThreadPoolExecutor(max_workers=3) as executor:
        lyrics_future = executor.submit(
            find_lyrics,
            lyric_meta,
            prefer_live=prefer_live_lyrics,
            source=source,
        )
        credit_future = None
        release_future = None
        needs_core_credits = not all(meta.get(key) for key in ("composer", "lyricist"))
        cjk_recording = has_cjk(credit_lookup_meta.get("title")) or has_cjk(credit_lookup_meta.get("artist"))
        if meta.get("online_match") and needs_core_credits and not cjk_recording:
            credit_future = executor.submit(search_musicbrainz, credit_lookup_meta)
        needs_release_refinement = bool(meta.get("original_artist")) or not (
            meta.get("album") and (meta.get("year") or meta.get("release_date"))
        )
        if meta.get("online_match") and cjk_recording and needs_release_refinement:
            release_future = executor.submit(search_itunes_release_refinement, dict(credit_lookup_meta))
        try:
            lyrics = lyrics_future.result()
        except Exception as exc:
            lyrics = ""
            append_source(meta, "lyrics lookup unavailable")
        try:
            original_credits = credit_future.result() if credit_future else {}
        except Exception:
            original_credits = {}
            append_source(meta, "credit lookup unavailable")
        try:
            release_refinement = release_future.result() if release_future else {}
        except Exception:
            release_refinement = {}
            append_source(meta, "iTunes release refinement unavailable")
    if release_refinement:
        for key in (
            "album", "album_artist", "genre", "release_date", "year", "artwork_url",
            "track_number", "track_count", "disc_number", "disc_count",
        ):
            if release_refinement.get(key):
                meta[key] = release_refinement[key]
        if meta.get("original_artist") and release_refinement.get("album"):
            meta["original_album"] = release_refinement["album"]
            lyric_meta["album"] = release_refinement["album"]
            credit_lookup_meta["album"] = release_refinement["album"]
        append_source(meta, release_refinement.get("source"))
    if meta.get("_live_performer_artwork_url"):
        meta["artwork_url"] = meta["_live_performer_artwork_url"]
    meta.update({k: v for k, v in original_credits.items() if v})
    known_credit_meta = fill_known_track_credits(dict(credit_lookup_meta, **original_credits))
    for key in ("composer", "lyricist", "arranger", "isrc", "musicbrainz_recording_id"):
        if known_credit_meta.get(key) and not meta.get(key):
            meta[key] = known_credit_meta[key]
    if not lyrics and meta.get("original_artist"):
        # Some providers index a cover's original recording by title only.
        # Use this only after the original-artist lookup has failed.
        fallback_lyric_meta = dict(lyric_meta)
        fallback_lyric_meta["artist"] = ""
        try:
            lyrics = find_lyrics(fallback_lyric_meta, prefer_live=prefer_live_lyrics, source=source)
        except Exception:
            lyrics = ""
            append_source(meta, "fallback lyrics lookup unavailable")
    if meta.get("online_match") and not all(meta.get(key) for key in ("composer", "lyricist", "arranger")):
        try:
            lyric_credits = find_netease_lyric_credits(
                lyric_meta,
                prefer_live=prefer_live_lyrics,
                reference_lyrics=lyrics,
            )
        except Exception:
            lyric_credits = {}
            append_source(meta, "lyric credit lookup unavailable")
        for key in ("composer", "lyricist", "arranger"):
            if lyric_credits.get(key) and not hint_credits.get(key):
                meta[key] = lyric_credits[key]
    lyrics = restore_cached_lyric_data(
        meta,
        lyric_meta,
        lyrics,
        prefer_live=prefer_live_lyrics,
    )
    write_lyric_cache(
        lyric_meta,
        lyrics,
        {key: meta.get(key) or "" for key in ("composer", "lyricist", "arranger")},
        prefer_live=prefer_live_lyrics,
    )
    if lyrics:
        meta["lyrics"] = append_visible_lyricist(lyrics, meta.get("lyricist"))
    try:
        meta = enrich_artwork(meta, metadata_candidates)
    except Exception:
        append_source(meta, "artwork lookup unavailable")
    meta = finalize_visible_lyricist(meta)

    if preview_full:
        print(json.dumps(metadata_preview_payload(meta), ensure_ascii=False))
        return

    meta = apply_metadata_overrides(meta, metadata_overrides)
    meta = finalize_visible_lyricist(meta)

    print(json.dumps(import_to_apple_music(source, auto_add, meta), ensure_ascii=False))

if __name__ == "__main__":
    main()
'@

try {
    Write-Log "Started Apple Music auto import; version=$Script:AppVersion; pid=$PID; stateRoot=$Script:StateRoot; localAppData=$env:LOCALAPPDATA"
    if ($SelfTest -or $SelfTestJson) {
        $selfTestReport = Invoke-EnvironmentSelfTest -AllowDependencyInstall:($SelfTest -and -not $SelfTestJson)
        if ($SelfTestJson) {
            $selfTestReport | ConvertTo-Json -Depth 5
        }
        else {
            Show-EnvironmentSelfTest -Report $selfTestReport
        }
        if ($selfTestReport.Ready) {
            exit 0
        }
        exit 1
    }
    $pythonForCheck = $null
    $albumBatchInfo = $null
    if ($PrefetchUrls -and $PrefetchUrls.Count -gt 0) {
        $prefetchResult = [ordered]@{ files = @(); errors = @() }
        try {
            Write-Log "Background predownload started for $($PrefetchUrls.Count) URL(s)."
            $pythonForCheck = Resolve-Python
            Ensure-PythonDependencies -PythonExe $pythonForCheck -NonInteractive
            $prefetchResult.files = @(
                Download-VideoUrls `
                    -Urls $PrefetchUrls `
                    -PythonExe $pythonForCheck `
                    -PlaylistMode ([bool]$PrefetchPlaylistMode) `
                    -MaxPlaylistItems $PrefetchMaxPlaylistItems
            )
        }
        catch {
            $prefetchResult.errors = @($_.Exception.Message)
            Write-Log "Background predownload failed: $($_.Exception.Message)"
        }
        if (-not [string]::IsNullOrWhiteSpace($PrefetchResultFile)) {
            $prefetchJson = $prefetchResult | ConvertTo-Json -Compress -Depth 4
            [System.IO.File]::WriteAllText($PrefetchResultFile, $prefetchJson, [System.Text.UTF8Encoding]::new($false))
        }
        if ($prefetchResult.errors.Count -gt 0) {
            exit 1
        }
        exit 0
    }
    if (-not $InputFiles -or $InputFiles.Count -eq 0) {
        $source = Ask-AudioSource -ClipboardUrls (Get-ClipboardUrls)
        if ($source.Cancelled) {
            exit 0
        }
        if ($source.Mode -eq "Url") {
            $pythonForCheck = Resolve-Python
            Ensure-PythonDependencies -PythonExe $pythonForCheck
            if ($source.PrefetchTask) {
                Write-Log "Waiting for already-started background predownload."
                try {
                    $InputFiles = Complete-UrlPrefetch -Task $source.PrefetchTask
                }
                catch {
                    Write-Log "Background predownload was unavailable; retrying normally: $($_.Exception.Message)"
                    $InputFiles = Download-VideoUrls -Urls $source.Urls -PythonExe $pythonForCheck -PlaylistMode ([bool]$source.PlaylistMode) -MaxPlaylistItems ([int]$source.MaxPlaylistItems)
                }
            }
            else {
                $InputFiles = Download-VideoUrls -Urls $source.Urls -PythonExe $pythonForCheck -PlaylistMode ([bool]$source.PlaylistMode) -MaxPlaylistItems ([int]$source.MaxPlaylistItems)
            }
            if ([bool]$source.PlaylistMode -and $InputFiles.Count -gt 1) {
                $albumDefaults = Get-AlbumBatchDefaults -Files $InputFiles
                $albumBatchInfo = Ask-AlbumBatchInfo `
                    -TrackCount $InputFiles.Count `
                    -DefaultAlbum $albumDefaults.Album `
                    -DefaultArtist $albumDefaults.Artist `
                    -DefaultYear $albumDefaults.Year
                if ($albumBatchInfo.Cancelled) {
                    exit 0
                }
            }
        }
        else {
            $InputFiles = Pick-Files
        }
    }

    if (-not $InputFiles -or $InputFiles.Count -eq 0) {
        exit 0
    }

    $autoAdd = Resolve-AppleMusicAutoAdd
    if (-not $pythonForCheck) {
        $pythonForCheck = Resolve-Python
        Ensure-PythonDependencies -PythonExe $pythonForCheck
    }

    $done = New-Object System.Collections.Generic.List[string]
    $failed = New-Object System.Collections.Generic.List[string]
    $currentFileIndex = 0
    $Z = { param([string]$B64) [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($B64)) }

    foreach ($file in $InputFiles) {
        $currentFileIndex += 1
        Write-Log "Selected file: $file"
        if (-not (Test-Path -LiteralPath $file)) {
            Write-Log "Skipped missing file: $file"
            continue
        }
        $baseName = [System.IO.Path]::GetFileNameWithoutExtension($file)
        $videoDefaults = Get-TrackDefaultsFromVideoInfo -AudioFile $file
        $defaultSongTitle = $baseName
        if (-not [string]::IsNullOrWhiteSpace($videoDefaults.Title)) {
            $defaultSongTitle = $videoDefaults.Title
        }
        $batchMode = ($null -ne $albumBatchInfo -and -not [bool]$albumBatchInfo.Cancelled)
        $songTitle = $defaultSongTitle
        if ([string]::IsNullOrWhiteSpace($songTitle)) { $songTitle = $baseName }
        $artistName = $videoDefaults.Artist
        $albumName = $videoDefaults.Album
        $yearText = $videoDefaults.Year
        $extraText = $videoDefaults.Extra
        $isLive = [bool]$videoDefaults.IsLive
        $useLiveLyrics = $false
        $isCover = [bool]$videoDefaults.IsCover
        $coverArtist = [string]$videoDefaults.CoverArtist
        if ($batchMode) {
            if (-not [string]::IsNullOrWhiteSpace($albumBatchInfo.ArtistName)) { $artistName = $albumBatchInfo.ArtistName }
            if (-not [string]::IsNullOrWhiteSpace($albumBatchInfo.AlbumName)) { $albumName = $albumBatchInfo.AlbumName }
            if (-not [string]::IsNullOrWhiteSpace($albumBatchInfo.YearText)) { $yearText = $albumBatchInfo.YearText }
            $isLive = [bool]$albumBatchInfo.IsLive
            $isCover = [bool]$albumBatchInfo.IsCover
            if ($isCover) {
                $coverArtist = $albumBatchInfo.CoverArtist
                if ([string]::IsNullOrWhiteSpace($coverArtist)) {
                    $coverArtist = $artistName
                }
            }
        }
        if (-not $batchMode -or [bool]$albumBatchInfo.ConfirmEachTrack) {
            $trackInfo = Ask-TrackInfo `
                -FileName ([System.IO.Path]::GetFileName($file)) `
                -DefaultSongTitle $songTitle `
                -DefaultArtist $artistName `
                -DefaultAlbum $albumName `
                -DefaultYear $yearText `
                -DefaultExtra $extraText `
                -DefaultLive $isLive `
                -DefaultCover $isCover `
                -DefaultCoverArtist $coverArtist
            if ($trackInfo.Cancelled) {
                continue
            }
            $songTitle = $trackInfo.SongTitle
            if ([string]::IsNullOrWhiteSpace($songTitle)) { $songTitle = $baseName }
            $artistName = $trackInfo.ArtistName
            $albumName = $trackInfo.AlbumName
            $yearText = $trackInfo.YearText
            $extraText = $trackInfo.ExtraText
            $isLive = [bool]$trackInfo.IsLive
            $useLiveLyrics = $false
            $isCover = [bool]$trackInfo.IsCover
            $coverArtist = ""
            if ($isCover) {
                $coverArtist = $trackInfo.CoverArtist
                if ([string]::IsNullOrWhiteSpace($coverArtist)) {
                    $coverArtist = $artistName
                }
            }
        }
        $liveArg = if ($isLive) { "--force-live" } else { "--force-studio" }
        $trackNumber = 0
        if (-not [string]::IsNullOrWhiteSpace($videoDefaults.PlaylistIndex)) {
            $parsedTrackNumber = 0
            if ([int]::TryParse($videoDefaults.PlaylistIndex, [ref]$parsedTrackNumber)) {
                $trackNumber = $parsedTrackNumber
            }
        }
        if ($trackNumber -le 0) {
            $trackNumber = $currentFileIndex
        }
        $trackCount = 0
        if (-not [string]::IsNullOrWhiteSpace($videoDefaults.PlaylistCount)) {
            $parsedTrackCount = 0
            if ([int]::TryParse($videoDefaults.PlaylistCount, [ref]$parsedTrackCount)) {
                $trackCount = $parsedTrackCount
            }
        }
        if ($trackCount -le 0 -and $batchMode) {
            $trackCount = $InputFiles.Count
        }
        if ($trackCount -le 0) {
            $trackCount = 1
        }
        $hint = ""
        $confirmed = $false
        $skipFile = $false
        $probe = $null
        $metadataOverrides = $null
        $previewArtworkTemp = ""
        $metadataOverridesFile = ""
        $previewMetadataFile = ""

        if ($batchMode -and -not [bool]$albumBatchInfo.ConfirmEachTrack) {
            $pieces = New-Object System.Collections.Generic.List[string]
            if (-not [string]::IsNullOrWhiteSpace($songTitle)) { $pieces.Add("title: $songTitle") }
            if (-not [string]::IsNullOrWhiteSpace($artistName)) { $pieces.Add("artist: $artistName") }
            if (-not [string]::IsNullOrWhiteSpace($albumName)) { $pieces.Add("album: $albumName") }
            if (-not [string]::IsNullOrWhiteSpace($yearText)) { $pieces.Add("year: $yearText") }
            if (-not [string]::IsNullOrWhiteSpace($extraText)) { $pieces.Add($extraText) }
            $hint = ($pieces -join "`r`n")
            $confirmed = $true
            Write-Log "Album batch hint for $file : $hint"
        }

        for ($attempt = 1; (-not $confirmed) -and $attempt -le 4; $attempt++) {
            $pieces = New-Object System.Collections.Generic.List[string]
            if (-not [string]::IsNullOrWhiteSpace($songTitle)) { $pieces.Add("title: $songTitle") }
            if (-not [string]::IsNullOrWhiteSpace($artistName)) { $pieces.Add("artist: $artistName") }
            if (-not [string]::IsNullOrWhiteSpace($albumName)) { $pieces.Add("album: $albumName") }
            if (-not [string]::IsNullOrWhiteSpace($yearText)) { $pieces.Add("year: $yearText") }
            if (-not [string]::IsNullOrWhiteSpace($extraText)) { $pieces.Add($extraText) }
            $hint = ($pieces -join "`r`n")
            Write-Log "Preparing full preview attempt $attempt for $file : $hint"
            $fallbackArtist = $artistName
            if (-not [string]::IsNullOrWhiteSpace($coverArtist)) {
                $fallbackArtist = $coverArtist
            }
            if ([string]::IsNullOrWhiteSpace($fallbackArtist)) {
                $fallbackArtist = "Unknown Artist"
            }
            $fallbackAlbum = $albumName
            $probe = [PSCustomObject]@{
                title = $songTitle
                artist = $fallbackArtist
                album = $fallbackAlbum
                year = $yearText
                online_match = $false
            }

            $previewCoverArtist = $coverArtist
            if ([string]::IsNullOrWhiteSpace($previewCoverArtist)) {
                $previewCoverArtist = "__NO_COVER_ARTIST__"
            }
            $previewArgs = @($file, $hint, "", $liveArg, $previewCoverArtist, "--preview-full", "--fast-probe")
            if (-not $isCover -and -not $batchMode) {
                $previewArgs += "__AUTO_COVER_DETECT__"
            }
            if ($batchMode) {
                $previewArgs += "--album-batch"
                $previewArgs += ("__TRACK_NUMBER=" + $trackNumber)
                $previewArgs += ("__TRACK_COUNT=" + $trackCount)
            }
            try {
                Write-Log "Building full pre-import preview for $file"
                $previewJson = Run-Python -Code $processor -PyArgs $previewArgs
                $preview = $previewJson | ConvertFrom-Json
            }
            catch {
                Write-Log "Full preview failed for $file : $($_.Exception.Message)"
                $fallbackPreviewArtist = if ($probe -and $probe.artist) { [string]$probe.artist } else { $artistName }
                if ([string]::IsNullOrWhiteSpace($fallbackPreviewArtist)) { $fallbackPreviewArtist = "Unknown Artist" }
                $fallbackPreviewAlbum = if ($probe -and $probe.album) { [string]$probe.album } else { $albumName }
                $preview = [PSCustomObject]@{
                    title = if ($probe -and $probe.title) { [string]$probe.title } else { $songTitle }
                    artist = $fallbackPreviewArtist
                    album = $fallbackPreviewAlbum
                    album_artist = $fallbackPreviewArtist
                    year = if ($probe -and $probe.year) { [string]$probe.year } else { $yearText }
                    release_date = ""
                    genre = ""
                    composer = ""
                    lyricist = ""
                    arranger = ""
                    track_number = $trackNumber
                    track_count = $trackCount
                    disc_number = 1
                    disc_count = 1
                    lyrics = ""
                    artwork_url = ""
                    generated_artwork = ""
                    artwork_data = ""
                    original_artist = ""
                    original_album = ""
                    source = "Metadata lookup failed; no fabricated release data used"
                    online_match = $false
                }
            }
            $preview = Restore-PreviewLyricsFromCache -Metadata $preview
            $previewLyricsLength = ([string]$preview.lyrics).Length
            Write-Log ("Full preview result for $file : version=$Script:AppVersion; title=$($preview.title); artist=$($preview.artist); lyricsChars=$previewLyricsLength; composer=$($preview.composer); lyricist=$($preview.lyricist); arranger=$($preview.arranger); source=$($preview.source)")

            if ([bool]$preview.detected_cover -and -not [string]::IsNullOrWhiteSpace([string]$preview.original_artist)) {
                $isCover = $true
                $coverArtist = [string]$preview.artist
                $artistName = [string]$preview.original_artist
                $albumName = [string]$preview.original_album
                if (-not [string]::IsNullOrWhiteSpace([string]$preview.year)) {
                    $yearText = [string]$preview.year
                }
                Write-Log "Auto-detected cover in full preview: original=$artistName performer=$coverArtist title=$songTitle"
            }

            $previewDecision = Show-MetadataPreview `
                -FileName ([System.IO.Path]::GetFileName($file)) `
                -Metadata $preview `
                -IsLive $isLive `
                -IsCover $isCover
            if ($previewDecision.Cancelled) {
                Write-Log "User skipped pre-import preview for $file"
                $skipFile = $true
                break
            }
            if ($previewDecision.Retry) {
                $previewArtworkTemp = [string]$previewDecision.TemporaryArtworkFile
                if (-not [string]::IsNullOrWhiteSpace($previewArtworkTemp) -and (Test-Path -LiteralPath $previewArtworkTemp)) {
                    Remove-Item -LiteralPath $previewArtworkTemp -Force -ErrorAction SilentlyContinue
                }
                $songTitle = [string]$previewDecision.Overrides.title
                if ([string]::IsNullOrWhiteSpace($songTitle)) { $songTitle = $baseName }
                $artistName = [string]$previewDecision.Overrides.artist
                $albumName = [string]$previewDecision.Overrides.album
                $yearText = [string]$previewDecision.Overrides.year
                if ($isCover) {
                    $coverArtist = [string]$previewDecision.Overrides.artist
                }
                $liveArg = if ($isLive) { "--force-live" } else { "--force-studio" }
                continue
            }
            $metadataOverrides = $previewDecision.Overrides
            $previewArtworkTemp = [string]$previewDecision.TemporaryArtworkFile
            $previewMetadata = [ordered]@{}
            foreach ($property in $preview.PSObject.Properties) {
                if ($property.Name -notin @("artwork_data", "artwork_mime")) {
                    $previewMetadata[$property.Name] = $property.Value
                }
            }
            $previewMetadataFile = Join-Path $env:TEMP ("am-preview-metadata-" + [guid]::NewGuid().ToString() + ".json")
            $previewMetadataJson = $previewMetadata | ConvertTo-Json -Compress -Depth 4
            [System.IO.File]::WriteAllText($previewMetadataFile, $previewMetadataJson, [System.Text.UTF8Encoding]::new($false))
            Write-Log "Cached reviewed preview metadata for fast import: $file"
            $confirmed = $true
            break
        }

        if ($skipFile) {
            continue
        }

        if (-not $confirmed) {
            $failed.Add(([System.IO.Path]::GetFileName($file) + ": " + (& $Z "5rKh5pyJ56Gu6K6k5q2M5puy5L+h5oGv77yM5bey6Lez6L+H44CC")))
            continue
        }

        Write-Log "Confirmed hint for $file : $hint"
        try {
            $liveLyricsArg = "--no-live-lyrics"
            $coverArtistArg = $coverArtist
            if ([string]::IsNullOrWhiteSpace($coverArtistArg)) {
                $coverArtistArg = "__NO_COVER_ARTIST__"
            }
            $processorArgs = @($file, $hint, $autoAdd, $liveArg, $coverArtistArg, $liveLyricsArg)
            if ($batchMode) {
                $processorArgs += "--album-batch"
                $processorArgs += ("__TRACK_NUMBER=" + $trackNumber)
                $processorArgs += ("__TRACK_COUNT=" + $trackCount)
            }
            if ($metadataOverrides) {
                $overrideJson = $metadataOverrides | ConvertTo-Json -Compress -Depth 4
                $metadataOverridesFile = Join-Path $env:TEMP ("am-metadata-overrides-" + [guid]::NewGuid().ToString() + ".json")
                [System.IO.File]::WriteAllText($metadataOverridesFile, $overrideJson, [System.Text.UTF8Encoding]::new($false))
                $processorArgs += ("__METADATA_OVERRIDES_FILE=" + $metadataOverridesFile)
            }
            if (-not [string]::IsNullOrWhiteSpace($previewMetadataFile)) {
                $processorArgs += ("__PRECOMPUTED_METADATA_FILE=" + $previewMetadataFile)
            }
            $json = Run-Python -Code $processor -PyArgs $processorArgs
            Write-Log "Python stdout for $file : $json"
            $result = $json | ConvertFrom-Json
            $parts = @("$($result.title) - $($result.artist)")
            if ($result.album) { $parts += ((& $Z "5LiT6L6R77ya") + $result.album) }
            if ($result.year) { $parts += ((& $Z "5bm05Lu977ya") + $result.year) }
            if ($result.composer) { $parts += ((& $Z "5L2c5puy77ya") + $result.composer) }
            if ($result.lyricist) { $parts += ((& $Z "5L2c6K+N77ya") + $result.lyricist) }
            if ($result.arranger) { $parts += ((& $Z "57yW5puy77ya") + $result.arranger) }
            if ($result.lyrics) { $parts += (& $Z "5q2M6K+N77ya5bey5YaZ5YWl") }
            if ($isLive -and $useLiveLyrics) { $parts += (& $Z "TGl2ZSDmrYzor43vvJrlt7LlsJ3or5XnlJ/miJA=") }
            if ($result.artwork) { $parts += (& $Z "5bCB6Z2i77ya5bey5YaZ5YWl") }
            $done.Add(($parts -join "`r`n  "))
            Write-Log "Imported OK: $($result.title) - $($result.artist)"
        }
        catch {
            $detail = $_.Exception.Message
            if ([string]::IsNullOrWhiteSpace($detail)) {
                $detail = ($_ | Out-String).Trim()
            }
            Write-Log "FAILED $file : $detail"
            $failed.Add(([System.IO.Path]::GetFileName($file) + ": " + $detail))
        }
        finally {
            if (-not [string]::IsNullOrWhiteSpace($previewArtworkTemp) -and (Test-Path -LiteralPath $previewArtworkTemp)) {
                $tempRoot = [System.IO.Path]::GetFullPath($env:TEMP)
                $previewFullPath = [System.IO.Path]::GetFullPath($previewArtworkTemp)
                $previewName = [System.IO.Path]::GetFileName($previewFullPath)
                if ($previewFullPath.StartsWith($tempRoot, [System.StringComparison]::OrdinalIgnoreCase) -and $previewName.StartsWith("am-preview-artwork-", [System.StringComparison]::OrdinalIgnoreCase)) {
                    Remove-Item -LiteralPath $previewFullPath -Force -ErrorAction SilentlyContinue
                }
            }
            if (-not [string]::IsNullOrWhiteSpace($metadataOverridesFile) -and (Test-Path -LiteralPath $metadataOverridesFile)) {
                $tempRoot = [System.IO.Path]::GetFullPath($env:TEMP)
                $overridesFullPath = [System.IO.Path]::GetFullPath($metadataOverridesFile)
                $overridesName = [System.IO.Path]::GetFileName($overridesFullPath)
                if ($overridesFullPath.StartsWith($tempRoot, [System.StringComparison]::OrdinalIgnoreCase) -and $overridesName.StartsWith("am-metadata-overrides-", [System.StringComparison]::OrdinalIgnoreCase)) {
                    Remove-Item -LiteralPath $overridesFullPath -Force -ErrorAction SilentlyContinue
                }
            }
            if (-not [string]::IsNullOrWhiteSpace($previewMetadataFile) -and (Test-Path -LiteralPath $previewMetadataFile)) {
                $tempRoot = [System.IO.Path]::GetFullPath($env:TEMP)
                $previewMetadataFullPath = [System.IO.Path]::GetFullPath($previewMetadataFile)
                $previewMetadataName = [System.IO.Path]::GetFileName($previewMetadataFullPath)
                if ($previewMetadataFullPath.StartsWith($tempRoot, [System.StringComparison]::OrdinalIgnoreCase) -and $previewMetadataName.StartsWith("am-preview-metadata-", [System.StringComparison]::OrdinalIgnoreCase)) {
                    Remove-Item -LiteralPath $previewMetadataFullPath -Force -ErrorAction SilentlyContinue
                }
            }
        }
    }

    $message = ""
    if ($done.Count -gt 0) {
        $message += (& $Z "5bey5a+85YWlIEFwcGxlIE11c2lj77ya") + "`r`n`r`n" + ($done -join "`r`n`r`n")
        $message += "`r`n`r`n" + (& $Z "5omT5byAIEFwcGxlIE11c2lj77yM562J5a6D5a+85YWl5a6M5oiQ5ZCO77yM5oqK5q2M5puy5Yqg5YWl5L2g55qE5q2M5Y2V44CC")
    }
    if ($failed.Count -gt 0) {
        if ($message) { $message += "`r`n`r`n" }
        $message += (& $Z "5aSx6LSlL+i3s+i/h++8mg==") + "`r`n" + ($failed -join "`r`n")
    }
    if (-not $message) {
        $message = (& $Z "5rKh5pyJ5a+85YWl5Lu75L2V5paH5Lu244CC")
    }
    Show-Message $message
}
catch {
    Write-Log ("Fatal error: " + (($_ | Out-String).Trim()))
    if ($SelfTestJson) {
        [PSCustomObject]@{
            Ready = $false
            ToolVersion = $Script:AppVersion
            Error = $_.Exception.Message
        } | ConvertTo-Json -Depth 3
    }
    else {
        Show-Message $_.Exception.Message "Apple Music Auto Import - Error"
    }
    exit 1
}


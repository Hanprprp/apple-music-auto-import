param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$InputFiles
)

$ErrorActionPreference = "Stop"
$Script:LogFile = Join-Path $PSScriptRoot "AppleMusic-Auto-Enrich-Import.log"

function Write-Log {
    param([string]$Text)
    $stamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Add-Content -LiteralPath $Script:LogFile -Value "[$stamp] $Text" -Encoding UTF8
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
    Add-Label (& $D "5Y6f5ZSxIC8g5Y6f5q2M5omL") 128 | Out-Null
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
        $urls = [regex]::Matches($urlBox.Text, 'https?://[^\s<>"'']+') | ForEach-Object { $_.Value.Trim().TrimEnd('.', ',', ';', ')', ']', '}') } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -Unique
        if (-not $urls -or $urls.Count -eq 0) {
            [System.Windows.Forms.MessageBox]::Show((& $D "5rKh5pyJ5Y+v5LiL6L2955qE6ZO+5o6l44CC"), $form.Text, "OK", "Warning") | Out-Null
            return
        }
        $script:AudioSourceResult = [PSCustomObject]@{ Mode = "Url"; Urls = @($urls); PlaylistMode = $false; MaxPlaylistItems = 0; Cancelled = $false }
        $form.DialogResult = [System.Windows.Forms.DialogResult]::OK
        $form.Close()
    })
    $playlistButton.Add_Click({
        $urls = [regex]::Matches($urlBox.Text, 'https?://[^\s<>"'']+') | ForEach-Object { $_.Value.Trim().TrimEnd('.', ',', ';', ')', ']', '}') } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -Unique
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
        $script:AudioSourceResult = [PSCustomObject]@{ Mode = "Url"; Urls = @($urls); PlaylistMode = $true; MaxPlaylistItems = $maxItems; Cancelled = $false }
        $form.DialogResult = [System.Windows.Forms.DialogResult]::OK
        $form.Close()
    })
    $fileButton.Add_Click({
        $script:AudioSourceResult = [PSCustomObject]@{ Mode = "Files"; Urls = @(); PlaylistMode = $false; MaxPlaylistItems = 0; Cancelled = $false }
        $form.DialogResult = [System.Windows.Forms.DialogResult]::OK
        $form.Close()
    })

    $urlBox.Select()
    $dialogResult = $form.ShowDialog()
    if ($dialogResult -ne [System.Windows.Forms.DialogResult]::OK -or -not $script:AudioSourceResult) {
        return [PSCustomObject]@{ Mode = "Cancel"; Urls = @(); PlaylistMode = $false; MaxPlaylistItems = 0; Cancelled = $true }
    }
    $result = $script:AudioSourceResult
    $script:AudioSourceResult = $null
    return $result
}

function Invoke-PythonProbe {
    param([string]$PythonExe)
    try {
        $out = & $PythonExe -c "import sys; print(sys.executable)" 2>$null
        if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace(($out | Select-Object -First 1))) {
            return ($out | Select-Object -First 1)
        }
    }
    catch {
    }
    return ""
}

function Resolve-Python {
    $candidates = New-Object System.Collections.Generic.List[string]

    $localPython = Join-Path $PSScriptRoot "python\python.exe"
    if (Test-Path -LiteralPath $localPython) {
        $candidates.Add($localPython)
    }

    $codexPython = Join-Path $env:USERPROFILE ".cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe"
    if (Test-Path -LiteralPath $codexPython) {
        $candidates.Add($codexPython)
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

    throw "Cannot find Python 3. Install Python 3 from python.org, then run this tool again."
}

function Ensure-PythonDependencies {
    param([string]$PythonExe)
    $checkCode = "import importlib.util, sys; missing=[name for name in ('mutagen','imageio_ffmpeg','PIL','yt_dlp') if importlib.util.find_spec(name) is None]; print(','.join(missing)); sys.exit(1 if missing else 0)"
    $missing = (& $PythonExe -c $checkCode 2>$null | Out-String).Trim()
    if ($LASTEXITCODE -eq 0) {
        return
    }

    Add-Type -AssemblyName System.Windows.Forms | Out-Null
    $answer = [System.Windows.Forms.MessageBox]::Show(
        "This computer is missing Python package(s): $missing`r`n`r`nInstall required packages now?`r`n`r`nRequires internet: mutagen, imageio-ffmpeg, pillow, yt-dlp",
        "Apple Music Auto Import",
        "YesNo",
        "Question"
    )
    if ($answer -ne [System.Windows.Forms.DialogResult]::Yes) {
        throw "Missing Python package(s): $missing"
    }

    & $PythonExe -m ensurepip --upgrade | Out-Null
    & $PythonExe -m pip install --user --upgrade mutagen imageio-ffmpeg pillow yt-dlp
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to install Python packages. Install manually: python -m pip install --user mutagen imageio-ffmpeg pillow yt-dlp"
    }
}

function Get-ConfigPath {
    return (Join-Path $PSScriptRoot "AppleMusic-Auto-Enrich-Import.config.json")
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

function Resolve-AppleMusicAutoAdd {
    $config = Read-Config
    if ($config.AutoAddFolder -and (Test-Path -LiteralPath $config.AutoAddFolder)) {
        return $config.AutoAddFolder
    }

    $music = [Environment]::GetFolderPath("MyMusic")
    $candidates = @(
        (Join-Path $music "Apple Music\Media\Automatically Add to Apple Music"),
        (Join-Path $music "Apple Music\Media\Automatically Add to iTunes"),
        (Join-Path $music "iTunes\iTunes Media\Automatically Add to iTunes"),
        (Join-Path $music "iTunes\iTunes Media\Automatically Add to Apple Music")
    )

    foreach ($candidate in $candidates) {
        if (Test-Path -LiteralPath $candidate) {
            $config | Add-Member -NotePropertyName AutoAddFolder -NotePropertyValue $candidate -Force
            Write-Config -Config $config
            return $candidate
        }
    }

    $picked = Pick-Folder "Cannot find Apple Music auto-import folder. Please choose 'Automatically Add to Apple Music' or 'Automatically Add to iTunes'."
    if ([string]::IsNullOrWhiteSpace($picked)) {
        throw "Apple Music auto-import folder was not selected."
    }
    $config | Add-Member -NotePropertyName AutoAddFolder -NotePropertyValue $picked -Force
    Write-Config -Config $config
    return $picked
}

function Run-Python {
    param([string]$Code, [string[]]$PyArgs = @())
    $python = Resolve-Python
    Ensure-PythonDependencies -PythonExe $python
    $tmp = Join-Path $env:TEMP ("am-auto-import-" + [guid]::NewGuid().ToString() + ".py")
    $errFile = Join-Path $env:TEMP ("am-auto-import-" + [guid]::NewGuid().ToString() + ".err")
    Set-Content -LiteralPath $tmp -Value $Code -Encoding UTF8
    try {
        $oldPreference = $ErrorActionPreference
        $ErrorActionPreference = "Continue"
        $output = & $python $tmp @PyArgs 2> $errFile
        $exitCode = $LASTEXITCODE
        $ErrorActionPreference = $oldPreference
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
        Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue
        Remove-Item -LiteralPath $errFile -Force -ErrorAction SilentlyContinue
    }
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
    if download_playlist and max_playlist_items > 0 and url not in force_single_urls:
        options["playlistend"] = max_playlist_items
    try:
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
        throw ((& $D "5LiL6L295aSx6LSl77ya") + $_.Exception.Message)
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
    $prefix = ""
    $leftTitle = [string][char]0x300A
    $rightTitle = [string][char]0x300B
    $titleStart = $Text.IndexOf($leftTitle)
    $titleEnd = if ($titleStart -ge 0) { $Text.IndexOf($rightTitle, $titleStart + 1) } else { -1 }
    if ($titleStart -ge 0 -and $titleEnd -gt $titleStart) {
        $prefix = $Text.Substring(0, $titleStart)
    }
    else {
        $parts = [regex]::Split($Text, '\s+-\s+| - |--|\|')
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
    $prefix = $prefix -replace '\u9ad8\u6e05|\u4fee\u5fa9|\u4fee\u590d|\u5b98\u651d|\u5b98\u6444', ''
    $prefix = $prefix -replace '[\[\]\(\)]', ' '
    $prefix = $prefix.Replace($leftBookBracket, " ").Replace($rightBookBracket, " ").Replace($leftFullParen, " ").Replace($rightFullParen, " ")
    $prefix = ($prefix -replace '\s+', ' ').Trim((" `t-:" + $fullWidthColon + "|"))
    if ($prefix.Length -gt 0 -and $prefix.Length -le 30) {
        return $prefix
    }
    return ""
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

    $titleText = Clean-VideoMetaText (($info.title, $info.fulltitle, $info.alt_title) -join "`n")
    $description = [string]($info.description)
    $combined = (($info.title, $info.fulltitle, $info.alt_title, $description) -join "`n")
    $rawPlaylistTitle = @($info.playlist_title, $info.playlist) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -First 1
    $playlistTitle = Clean-PlaylistAlbumTitle $rawPlaylistTitle

    $title = Get-TextBetweenChars $combined 0x300A 0x300B
    if ([string]::IsNullOrWhiteSpace($title)) {
        $title = Get-TextBetweenChars $combined 0x003C 0x003E
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
        $title = Clean-VideoTitleForSongName $titleText
    }

    $artist = Get-FirstRegexGroup $combined @(
        '^\s*(?:\u6b4c\u624b|\u6f14\u5531|\u6f14\u5531\u8005|\u539f\u5531|artist|singer|vocal)\s*[:\uFF1A\-]\s*(.+)$',
        '^\s*(?:performer|performed by)\s*[:\uFF1A\-]\s*(.+)$'
    )
    if ([string]::IsNullOrWhiteSpace($artist) -and -not [string]::IsNullOrWhiteSpace($info.artist)) {
        $artist = [string]$info.artist
    }
    if ([string]::IsNullOrWhiteSpace($artist)) {
        $artist = Infer-ArtistFromTitle $titleText
    }
    if ([string]::IsNullOrWhiteSpace($artist) -and ([string]$info.channel) -match '(?i)(topic|official|vevo|\u5b98\u65b9)') {
        $artist = ([string]$info.channel) -replace '(?i)\s*-\s*topic$', ''
        $artist = $artist -replace '(?i)\s*official.*$', ''
        $artist = $artist.Trim()
    }
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
    if ($info.release_year) {
        $year = [string]$info.release_year
    }
    elseif ($info.release_date -and ([string]$info.release_date) -match '^(19|20)\d{2}') {
        $year = $matches[0]
    }
    if ([string]::IsNullOrWhiteSpace($year)) {
        $year = Get-FirstRegexGroup $combined @('^\s*(?:\u5e74\u4efd|\u53d1\u884c|\u767c\u884c|year|release(?: date)?)\s*[:\uFF1A\-]\s*((?:19|20)\d{2})')
    }

    $extraLines = New-Object System.Collections.Generic.List[string]
    if ($info.title) { $extraLines.Add((Decode-Utf8 "6KeG6aKR5qCH6aKYOiA=") + $info.title) }
    if ($info.channel) { $extraLines.Add((Decode-Utf8 "6aKR6YGTOiA=") + $info.channel) }
    if ($info.uploader -and $info.uploader -ne $info.channel) { $extraLines.Add((Decode-Utf8 "5LiK5Lyg6ICFOiA=") + $info.uploader) }
    $lyricist = Get-FirstRegexGroup $combined @('^\s*(?:\u4f5c\u8bcd|\u586b\u8bcd|\u8a5e|lyricist|lyrics by)\s*[:\uFF1A\-]\s*(.+)$')
    $composer = Get-FirstRegexGroup $combined @('^\s*(?:\u4f5c\u66f2|\u66f2|composer|music by)\s*[:\uFF1A\-]\s*(.+)$')
    if ($lyricist) { $extraLines.Add((Decode-Utf8 "5aGr6K+NOiA=") + $lyricist) }
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
from io import BytesIO
from pathlib import Path

import imageio_ffmpeg
from mutagen.mp4 import MP4, MP4Cover

USER_AGENT = "CodexAppleMusicAutoImport/1.0 (local personal metadata helper)"

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

def trim_hint_fragment(text):
    text = (text or "").strip()
    text = re.split(r"(?i)\b(?:\u89c6\u9891\u6807\u9898|\u983b\u9053|\u9891\u9053|\u4e0a\u4f20\u8005|\u4e0a\u50b3\u8005|\u7b80\u4ecb|\u7c21\u4ecb|description|album|\u4e13\u8f91|\u5c08\u8f2f|year|\u5e74\u4efd)\s*[:\uFF1A]", text, maxsplit=1)[0]
    text = re.sub(r"\[[A-Za-z0-9_-]{6,}\]\s*$", "", text)
    text = re.sub(r"\s+", " ", text).strip(" -_")
    return text

def extract_artist_near_book_title(text):
    text = (text or "").strip()
    if not text:
        return ""
    parts = [p.strip() for p in re.split(r"\s+-\s+| - |-|--|/", text, maxsplit=1) if p.strip()]
    if len(parts) == 2 and len(norm(parts[0])) <= 30:
        return parts[0]
    before = re.split(r"[\u300a<]", text, maxsplit=1)[0]
    before = re.sub(r"^\s*[\u3010\[].*?[\u3011\]]\s*", "", before)
    before = re.sub(r"\b(4k|hd|hq|live|cover)\b", "", before, flags=re.I)
    before = re.sub(r"[\[\]\(\)\uFF08\uFF09\u3010\u3011]+", " ", before)
    before = re.sub(r"\s+", " ", before).strip(" -_")
    if before and len(norm(before)) <= 30:
        return before
    return ""

def norm(text):
    return re.sub(r"[\W_]+", "", (text or "").lower(), flags=re.UNICODE)

def strip_live_marker(text):
    return re.sub(r"\s*\(?\s*(live|\u73fe\u5834|\u73b0\u573a)\s*\)?\s*$", "", text or "", flags=re.I).strip()

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
        artist = (item.get("artist") or "").strip()
        key = norm(artist)
        if artist and key and key not in seen:
            seen.add(key)
            artists.append(artist)
    return artists

def matches_any_explicit_artist(explicit_artists, actual):
    if not explicit_artists:
        return True
    return any(artist_matches(expected, actual) for expected in explicit_artists)

def ratio(a, b):
    a, b = norm(a), norm(b)
    if not a or not b:
        return 0.0
    return difflib.SequenceMatcher(None, a, b).ratio()

def weak_title(text):
    n = norm(text)
    return (
        len(n) < 2
        or n.isdigit()
        or n in ("videoplayback", "audio", "download", "playback")
        or n.startswith("videoplayback")
        or n.startswith("download")
    )

def parse_candidates(source, hint):
    base = clean_name(source)
    hint = (hint or "").strip()
    labeled_title = extract_labeled_value(hint, ["\u6b4c\u540d", "\u66f2\u540d", "\u6b4c\u66f2", "\u66f2\u76ee", "title", "song", "track"])
    labeled_artist = extract_labeled_value(hint, ["\u6b4c\u624b", "\u6f14\u5531", "\u6f14\u5531\u8005", "\u539f\u5531", "artist", "singer", "vocal", "performer"])
    book_title = labeled_title or extract_book_title(Path(source).stem) or extract_book_title(hint)
    book_artist = labeled_artist or extract_artist_near_book_title(hint) or extract_artist_near_book_title(Path(source).stem)
    candidates = []
    if labeled_title or labeled_artist:
        candidates.append({"artist": labeled_artist, "title": labeled_title or book_title, "query": f"{labeled_artist} {labeled_title or book_title}".strip()})
    if book_title:
        if book_artist:
            candidates.append({"artist": book_artist, "title": book_title, "query": f"{book_artist} {book_title}"})
        candidates.append({"artist": "", "title": book_title, "query": f"{hint} {book_title}"})
    if hint:
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

def search_itunes(candidates):
    countries = ["CN", "HK", "TW", "US", "JP"]
    explicit_artists = explicit_candidate_artists(candidates)
    best = None
    for cand in candidates:
        terms = []
        cand_wants_live = is_live_context("", cand.get("query") or "")
        if cand.get("title") and cand.get("artist"):
            live_suffix = " live" if cand_wants_live else ""
            terms.append(f"{cand['title']} {cand['artist']}{live_suffix}")
            terms.append(f"{cand['artist']} {cand['title']}{live_suffix}")
        terms.append(cand.get("query") or cand.get("title") or "")
        for term in [t for t in terms if t.strip()]:
            for country in countries:
                qs = urllib.parse.urlencode({"term": term, "media": "music", "entity": "song", "limit": 10, "country": country})
                url = f"https://itunes.apple.com/search?{qs}"
                try:
                    data = http_json(url)
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
                if best and best["score"] >= 1.25:
                    break
            if best and best["score"] >= 1.25:
                break
        if best and best["score"] >= 1.25:
            break
    if not best or best["score"] < 0.55:
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
        "source": f"iTunes Search API {best['country']} score={best['score']}",
    }
    return meta

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
        score = ratio(title, rec.get("title")) * 0.65 + ratio(artist, artist_credit) * 0.35
        if best is None or score > best[0]:
            best = (score, rec)
    if not best or best[0] < 0.45:
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

    if composers:
        out["composer"] = ", ".join(sorted(composers))
    if lyricists:
        out["lyricist"] = ", ".join(sorted(lyricists))
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
        base.replace("\u5341\u70b9\u534a", "10:30").replace("\u5341\u9ede\u534a", "10:30"),
        base.replace("10:30", "\u5341\u70b9\u534a"),
        base.replace("10:30", "\u5341\u9ede\u534a"),
    ):
        value = value.strip()
        if value and value not in aliases:
            aliases.append(value)
    return aliases

def clean_lyric_text(text):
    lines = []
    for raw in (text or "").splitlines():
        line = re.sub(r"^\[[0-9:.]+\]\s*", "", raw).strip()
        line = re.sub(r"\s+", " ", line)
        line = re.sub(r"(?i)\boh\s+yeh\b", "Oh yeah", line)
        line = re.sub(r"(?i)\byeh\b", "yeah", line)
        if line.lower() == "for my baby":
            line = "For my baby"
        if not line:
            continue
        if re.match(r"^(?:\u4f5c\u8bcd|\u4f5c\u8a5e|\u586b\u8bcd|\u586b\u8a5e|\u4f5c\u66f2|\u7f16\u66f2|\u7de8\u66f2|\u5236\u4f5c\u4eba|\u8bcd|\u8a5e|\u66f2)\s*[:\uff1a]", line):
            continue
        if lines and norm(lines[-1]) == norm(line):
            continue
        lines.append(line)
    return "\n".join(lines).strip()

def lyrics_match_title(title, lyrics):
    title_n = norm(base_lyric_title(title))
    lyrics_n = norm(lyrics)
    if not title_n or not lyrics_n:
        return True
    if "1030" in title_n:
        if not any(token in lyrics_n for token in ("1030", "\u5341\u70b9\u534a", "\u5341\u9ede\u534a")):
            return False
    title_chars = [
        ch for ch in base_lyric_title(title)
        if re.match(r"[\u3400-\u9fff]", ch) and ch not in "\u7684\u4e86\u6211\u4f60\u4ed6\u5979\u5b83\u662f\u6709\u5728\u4e0d\u4e00\u548c"
    ]
    if len(title_chars) >= 2:
        matched = sum(1 for ch in set(title_chars) if ch in lyrics)
        if matched < 2:
            return False
    return True

def usable_lyrics(text, title=""):
    cleaned = clean_lyric_text(text)
    if not cleaned:
        return ""
    if title and not lyrics_match_title(title, cleaned):
        return ""
    lines = lyric_lines(cleaned)
    cjk_chars = len(re.findall(r"[\u3400-\u9fff]", cleaned))
    if len(lines) < 5 or cjk_chars < 20:
        return ""
    return cleaned

def search_lrclib_lyrics(meta):
    title = meta.get("title") or ""
    artist = meta.get("artist") or ""
    if not title:
        return ""
    all_results = []
    for alias in lyric_title_aliases(title):
        params = {"track_name": alias}
        if artist:
            params["artist_name"] = artist
        url = "https://lrclib.net/api/search?" + urllib.parse.urlencode(params)
        try:
            data = http_json(url)
        except Exception:
            continue
        if isinstance(data, list):
            all_results.extend(data[:10])
    best = None
    for item in all_results:
        score = max(ratio(alias, item.get("trackName")) for alias in lyric_title_aliases(title)) * 0.65
        score += ratio(artist, item.get("artistName")) * 0.35
        if meta.get("album"):
            score += ratio(meta.get("album"), item.get("albumName")) * 0.1
        if best is None or score > best[0]:
            best = (score, item)
    if not best or best[0] < 0.45:
        return ""
    lyrics = best[1].get("plainLyrics") or ""
    if not lyrics and best[1].get("syncedLyrics"):
        lines = []
        for line in best[1]["syncedLyrics"].splitlines():
            line = re.sub(r"^\[[0-9:.]+\]\s*", "", line).strip()
            if line:
                lines.append(line)
        lyrics = "\n".join(lines)
    return usable_lyrics(lyrics, title)

def fetch_netease_lyrics(song_id, title=""):
    try:
        req = urllib.request.Request(
            f"https://music.163.com/api/song/lyric?id={song_id}&lv=1&kv=1&tv=-1",
            headers={"User-Agent": USER_AGENT, "Referer": "https://music.163.com/"},
        )
        with urllib.request.urlopen(req, timeout=12) as resp:
            payload = json.loads(resp.read().decode("utf-8", "replace"))
    except Exception:
        return ""
    lyric = (payload.get("lrc") or {}).get("lyric") or ""
    return usable_lyrics(lyric, title)

def search_netease_lyrics(meta, prefer_live=False):
    title = meta.get("title") or ""
    artist = meta.get("artist") or ""
    if not title:
        return ""
    search_terms = []
    for alias in lyric_title_aliases(title):
        for term in (
            f"{artist} {alias} Power Of Live",
            f"{artist} {alias} Soul Power Live",
            f"{artist} {alias} live",
            f"{artist} {alias}",
            f"David Tao {alias}",
        ):
            term = term.strip()
            if term and term not in search_terms:
                search_terms.append(term)

    best = []
    for term in search_terms[:8]:
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
            song_id = song.get("id")
            song_title = song.get("name") or ""
            artists = " ".join(a.get("name", "") for a in song.get("artists", []) if isinstance(a, dict))
            album = (song.get("album") or {}).get("name") or ""
            if not song_id or artist and not artist_matches(artist, artists):
                continue
            title_score = max(ratio(alias, song_title) for alias in lyric_title_aliases(title))
            score = title_score * 0.68 + (ratio(artist, artists) if artist else 0.35) * 0.32
            song_context = " ".join([song_title, album, term])
            if is_live_context("", song_context):
                score += 0.35 if prefer_live else 0.12
            elif prefer_live:
                score -= 0.18
            if prefer_live and re.search(r"(?i)power\s*of\s*live|soul\s*power|live|concert|\u73fe\u5834|\u73b0\u573a|\u6f14\u5531\u6703|\u6f14\u5531\u4f1a", song_context):
                score += 0.12
            best.append((score, song_id, song_title, album))
    best.sort(reverse=True, key=lambda item: item[0])
    fallback = ""
    for score, song_id, song_title, album in best[:10]:
        if score < 0.48:
            continue
        lyrics = fetch_netease_lyrics(song_id, title)
        if lyrics:
            if prefer_live and re.search(r"\u73b0\u5728\u7684\u65f6\u95f4|\u73fe\u5728\u7684\u6642\u9593", lyrics) and re.search(r"\u8fd8\u6ca1\u6709|\u9084\u6c92\u6709", lyrics):
                return lyrics
            if not fallback:
                fallback = lyrics
            if not prefer_live:
                return lyrics
    if fallback:
        return fallback
    for score, song_id, song_title, album in best[:10]:
        if score < 0.48:
            continue
        lyrics = fetch_netease_lyrics(song_id, title)
        if lyrics:
            return lyrics
    return ""

def find_lyrics(meta, prefer_live=False):
    title = meta.get("title") or ""
    artist = meta.get("artist") or ""
    if has_cjk(title) or has_cjk(artist):
        lyrics = search_netease_lyrics(meta, prefer_live=prefer_live)
        if lyrics:
            return lyrics
        return search_lrclib_lyrics(meta)
    lyrics = search_lrclib_lyrics(meta)
    if lyrics:
        return lyrics
    return search_netease_lyrics(meta, prefer_live=prefer_live)

def extract_hint_credits(hint):
    out = {}
    lyricist = extract_labeled_value(hint, ["\u4f5c\u8bcd", "\u586b\u8bcd", "\u8a5e", "\u8bcd", "lyricist", "lyrics by"])
    composer = extract_labeled_value(hint, ["\u4f5c\u66f2", "\u66f2", "composer", "music by", "written by"])
    album = extract_labeled_value(hint, ["\u4e13\u8f91", "\u5c08\u8f2f", "album"])
    year = extract_labeled_value(hint, ["\u5e74\u4efd", "\u53d1\u884c", "\u767c\u884c", "year", "release"])
    if lyricist:
        out["lyricist"] = lyricist
    if composer:
        out["composer"] = composer
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
        "3dW6r8tByOA": {"venue": "\u53f0\u5317"},
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
    if "cover version" in (meta.get("source") or ""):
        meta["album"] = f"{title} ({album_label} Cover) - Single"
    else:
        meta["album"] = f"{title} ({album_label}) - Single"
    if details.get("year"):
        meta["year"] = details["year"]
        meta["release_date"] = details["year"]
    elif meta.get("year"):
        meta["release_date"] = meta["year"]
    elif meta.get("release_date"):
        meta["year"] = str(meta["release_date"])[:4]
        meta["release_date"] = meta["year"]
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
    return bool(meta.get("artwork_url") or meta.get("generated_artwork"))

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
    return f"https://p3.music.126.net/{digest}/{pic_id}.jpg?param=1200y1200"

def search_netease(candidates):
    best = None
    seen = set()
    explicit_artists = explicit_candidate_artists(candidates)
    for cand in candidates:
        terms = []
        if cand.get("title") and cand.get("artist"):
            terms.append(f"{cand['artist']} {cand['title']}")
            terms.append(f"{cand['title']} {cand['artist']}")
        terms.append(cand.get("query") or cand.get("title") or "")
        for term in [t for t in terms if t.strip() and t not in seen]:
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
                title = song.get("name") or ""
                artists = " ".join(a.get("name", "") for a in song.get("artists", []) if isinstance(a, dict))
                if not matches_any_explicit_artist(explicit_artists, artists):
                    continue
                album_obj = song.get("album") or {}
                album = album_obj.get("name") or f"{title} - Single"
                if not title:
                    continue
                title_score = ratio(cand.get("title") or term, title)
                if norm(cand.get("title")) and norm(cand.get("title")) == norm(title):
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
                publish_time = album_obj.get("publishTime") or 0
                year = ""
                release_date = ""
                if publish_time:
                    try:
                        release_date = time.strftime("%Y-%m-%d", time.localtime(int(publish_time) / 1000))
                        year = release_date[:4]
                    except Exception:
                        pass
                artwork = album_obj.get("picUrl") or netease_cover_url(album_obj.get("picId"))
                item = {
                    "score": round(score, 4),
                    "title": title,
                    "artist": artists,
                    "album": album,
                    "year": year,
                    "release_date": release_date,
                    "artwork_url": artwork,
                }
                if best is None or item["score"] > best["score"]:
                    best = item
    if not best or best["score"] < 0.60:
        return None
    meta = {
        "title": best["title"],
        "artist": best["artist"] or "Unknown Artist",
        "album": best["album"] or f"{best['title']} - Single",
        "album_artist": best["artist"] or "Unknown Artist",
        "year": best["year"],
        "release_date": best["release_date"],
        "genre": "",
        "track_number": 1,
        "track_count": 1,
        "disc_number": 1,
        "disc_count": 1,
        "source": f"NetEase Search score={best['score']}",
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
                score = ratio(title or term, result.get("trackName")) * 0.62
                score += (ratio(artist, result.get("artistName")) if artist else 0.35) * 0.28
                score += (ratio(album, result.get("collectionName")) if album else 0.2) * 0.10
                if norm(title) and norm(title) == norm(result.get("trackName")):
                    score += 0.16
                if norm(artist) and norm(artist) == norm(result.get("artistName")):
                    score += 0.12
                item = {"score": score, "url": artwork, "country": country}
                if best is None or item["score"] > best["score"]:
                    best = item
    if best and best["score"] >= 0.58:
        return best
    return None

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
            score = ratio(title or cand.get("title") or term, r_title) * 0.70
            score += (ratio(artist or cand.get("artist"), r_artist) if (artist or cand.get("artist")) else 0.35) * 0.30
            songname = clean_provider_text(result.get("SONGNAME"))
            if any(x in songname.lower() for x in ("dj", "slowed", "remix", "\u7248")) and norm(songname) != norm(r_title):
                score -= 0.18
            item = {"score": score, "url": artwork}
            if best is None or item["score"] > best["score"]:
                best = item
    if best and best["score"] >= 0.56:
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
            artwork = album_obj.get("picUrl") or netease_cover_url(album_obj.get("picId"))
            if not artwork:
                continue
            score = ratio(title or term, song.get("name")) * 0.68
            score += (ratio(artist, artists) if artist else 0.35) * 0.32
            if norm(title) and norm(title) == norm(song.get("name")):
                score += 0.12
            if norm(artist) and norm(artist) in norm(artists):
                score += 0.10
            item = {"score": score, "url": artwork}
            if best is None or item["score"] > best["score"]:
                best = item
    if best and best["score"] >= 0.58:
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
    if not best or best["score"] < 0.45:
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
        "source": f"Kuwo Search score={best['score']}",
    }
    if best.get("artwork_url"):
        meta["artwork_url"] = best["artwork_url"]
    return meta

def safe_filename(text):
    text = re.sub(r'[\\/:*?"<>|]+', "_", text or "").strip(" .")
    return text or "Imported Track"

def convert_audio(source, dest, force_encode=False):
    ffmpeg = imageio_ffmpeg.get_ffmpeg_exe()
    if not force_encode:
        copy_cmd = [ffmpeg, "-y", "-i", source, "-map", "0:a:0", "-vn", "-c:a", "copy", "-movflags", "+faststart", dest]
        try:
            subprocess.run(copy_cmd, check=True, stdout=subprocess.DEVNULL, stderr=subprocess.PIPE)
            return "copied"
        except subprocess.CalledProcessError:
            pass
    encode_cmd = [ffmpeg, "-y", "-i", source, "-map", "0:a:0", "-vn", "-c:a", "aac", "-b:a", "256k", "-movflags", "+faststart", dest]
    subprocess.run(encode_cmd, check=True, stdout=subprocess.DEVNULL, stderr=subprocess.PIPE)
    return "encoded-aac"

def tag_file(path, meta):
    audio = MP4(path)
    if audio.tags is None:
        audio.add_tags()
    tags = audio.tags
    def put(key, value):
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
        "ISRC": meta.get("isrc"),
        "MusicBrainz Track Id": meta.get("musicbrainz_recording_id"),
    }
    for name, value in freeform.items():
        if value:
            tags[f"----:com.apple.iTunes:{name}"] = [str(value).encode("utf-8")]

    if meta.get("generated_artwork") == "hand_in_hand":
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
            tags["covr"] = [MP4Cover(bio.getvalue(), imageformat=MP4Cover.FORMAT_JPEG)]
        except Exception:
            pass

    artwork_url = meta.get("artwork_url")
    if artwork_url:
        try:
            ctype, data = http_bytes(artwork_url)
            image_format = MP4Cover.FORMAT_PNG if "png" in ctype.lower() or artwork_url.lower().endswith(".png") else MP4Cover.FORMAT_JPEG
            tags["covr"] = [MP4Cover(data, imageformat=image_format)]
        except Exception:
            pass
    audio.save()

def main():
    source, hint, auto_add = sys.argv[1:4]
    force_live = len(sys.argv) > 4 and sys.argv[4] == "--force-live"
    force_studio = len(sys.argv) > 4 and sys.argv[4] == "--force-studio"
    optional_args = sys.argv[5:]
    album_batch = "--album-batch" in optional_args
    cover_artist = ""
    for arg in optional_args:
        arg = (arg or "").strip()
        if not arg or arg.startswith("--") or arg.startswith("__") or arg == "__NO_COVER_ARTIST__":
            continue
        cover_artist = arg
        break
    live_hint = hint
    if force_live:
        live_hint = hint + " __force_live__"
    elif force_studio:
        live_hint = hint + " __force_studio__"
    candidates = parse_candidates(source, hint)
    if force_live:
        candidates = with_live_search_variants(candidates)
    override_meta = known_override(candidates)
    if override_meta:
        meta = override_meta
    elif force_live:
        meta = search_itunes(candidates) or search_netease(candidates) or search_kuwo(candidates)
    elif candidates_have_cjk(candidates):
        meta = search_netease(candidates) or search_kuwo(candidates) or search_itunes(candidates)
    else:
        meta = search_itunes(candidates) or search_netease(candidates) or search_kuwo(candidates)
    fallback = candidates[0]
    if meta is None:
        meta = {
            "title": fallback.get("title") or clean_name(source),
            "artist": fallback.get("artist") or "Unknown Artist",
            "album": (fallback.get("title") or clean_name(source)) + " - Single",
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

    if cover_artist:
        original_title = meta.get("title") or clean_name(source)
        meta["artist"] = cover_artist
        meta["album_artist"] = cover_artist
        if is_live_context(source, live_hint):
            meta["album"] = f"{original_title} (Live Cover) - Single"
        else:
            meta["album"] = f"{original_title} - Cover"
        meta["track_number"] = 1
        meta["track_count"] = 1
        old_source = meta.get("source") or ""
        meta["source"] = (old_source + "; artist adjusted as cover version").strip("; ")

    if album_batch:
        meta = apply_album_batch_adjustment(meta, source, hint, optional_args)

    if auto_add == "__PROBE__":
        preview_meta = dict(meta)
        if not album_batch:
            preview_meta = apply_live_adjustment(preview_meta, source, live_hint)
        preview_meta = enrich_artwork(preview_meta, candidates)
        print(json.dumps({
            "title": preview_meta.get("title"),
            "artist": preview_meta.get("artist"),
            "album": preview_meta.get("album"),
            "year": preview_meta.get("year") or preview_meta.get("release_date", "")[:4],
            "genre": preview_meta.get("genre") or "",
            "source": preview_meta.get("source"),
            "artwork": bool(preview_meta.get("artwork_url") or preview_meta.get("generated_artwork")),
            "online_match": bool(preview_meta.get("online_match")),
        }, ensure_ascii=False))
        return

    mb = search_musicbrainz(meta)
    meta.update({k: v for k, v in mb.items() if v})
    hint_credits = extract_hint_credits(hint)
    for key, value in hint_credits.items():
        if value and not meta.get(key):
            meta[key] = value
    if not album_batch:
        meta = apply_live_adjustment(meta, source, live_hint)
    lyrics = find_lyrics(meta, prefer_live=is_live_context(source, live_hint))
    if lyrics:
        meta["lyrics"] = lyrics
    meta = enrich_artwork(meta, candidates)

    out_name = safe_filename(f"{meta.get('title')} - {meta.get('artist')}.m4a")
    tmp_dest = str(Path(os.environ.get("TEMP", ".")) / ("am-auto-" + out_name))
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
    final_dest = str(Path(auto_add) / out_name)
    shutil.copy2(tmp_dest, final_dest)
    try:
        os.remove(tmp_dest)
    except OSError:
        pass

    result = {
        "title": meta.get("title"),
        "artist": meta.get("artist"),
        "album": meta.get("album"),
        "year": meta.get("year") or meta.get("release_date", "")[:4],
        "composer": meta.get("composer") or "",
        "lyricist": meta.get("lyricist") or "",
        "lyrics": bool(meta.get("lyrics")),
        "artwork": bool(meta.get("artwork_url") or meta.get("generated_artwork")),
        "mode": mode,
        "dest": final_dest,
        "source": meta.get("source"),
    }
    print(json.dumps(result, ensure_ascii=False))

if __name__ == "__main__":
    main()
'@

try {
    Write-Log "Started Apple Music auto import."
    $pythonForCheck = $null
    $albumBatchInfo = $null
    if (-not $InputFiles -or $InputFiles.Count -eq 0) {
        $source = Ask-AudioSource -ClipboardUrls (Get-ClipboardUrls)
        if ($source.Cancelled) {
            exit 0
        }
        if ($source.Mode -eq "Url") {
            $pythonForCheck = Resolve-Python
            Ensure-PythonDependencies -PythonExe $pythonForCheck
            $InputFiles = Download-VideoUrls -Urls $source.Urls -PythonExe $pythonForCheck -PlaylistMode ([bool]$source.PlaylistMode) -MaxPlaylistItems ([int]$source.MaxPlaylistItems)
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

    foreach ($file in $InputFiles) {
        $currentFileIndex += 1
        Write-Log "Selected file: $file"
        if (-not (Test-Path -LiteralPath $file)) {
            Write-Log "Skipped missing file: $file"
            continue
        }
        $baseName = [System.IO.Path]::GetFileNameWithoutExtension($file)
        $Z = { param([string]$B64) [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($B64)) }
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
        $isLive = $false
        $useLiveLyrics = $false
        $isCover = $false
        $coverArtist = ""
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
        $hint = ""
        $confirmed = $false
        $skipFile = $false
        $probe = $null

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
            if ($batchMode) {
                if (-not [string]::IsNullOrWhiteSpace($songTitle)) { $pieces.Add("title: $songTitle") }
                if (-not [string]::IsNullOrWhiteSpace($artistName)) { $pieces.Add("artist: $artistName") }
                if (-not [string]::IsNullOrWhiteSpace($albumName)) { $pieces.Add("album: $albumName") }
                if (-not [string]::IsNullOrWhiteSpace($yearText)) { $pieces.Add("year: $yearText") }
                if (-not [string]::IsNullOrWhiteSpace($extraText)) { $pieces.Add($extraText) }
            }
            else {
                if (-not [string]::IsNullOrWhiteSpace($artistName) -and -not [string]::IsNullOrWhiteSpace($songTitle)) {
                    $pieces.Add("$artistName - $songTitle")
                }
                else {
                    @($artistName, $songTitle) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | ForEach-Object { $pieces.Add($_) }
                }
                @($albumName, $yearText, $extraText) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | ForEach-Object { $pieces.Add($_) }
            }
            if ($batchMode) {
                $hint = ($pieces -join "`r`n")
            }
            else {
                $hint = ($pieces -join " ")
            }
            Write-Log "Probe attempt $attempt for $file : $hint"
            try {
                $probeJson = Run-Python -Code $processor -PyArgs @($file, $hint, "__PROBE__", $liveArg, $coverArtist)
                Write-Log "Probe stdout for $file : $probeJson"
                $probe = $probeJson | ConvertFrom-Json
            }
            catch {
                Write-Log "Probe failed for $file : $($_.Exception.Message)"
                $fallbackArtist = $artistName
                if (-not [string]::IsNullOrWhiteSpace($coverArtist)) {
                    $fallbackArtist = $coverArtist
                }
                if ([string]::IsNullOrWhiteSpace($fallbackArtist)) {
                    $fallbackArtist = "Unknown Artist"
                }
                $fallbackAlbum = $albumName
                if ([string]::IsNullOrWhiteSpace($fallbackAlbum)) {
                    if (-not [string]::IsNullOrWhiteSpace($coverArtist)) {
                        if ($liveArg -eq "--force-live") {
                            $fallbackAlbum = "$songTitle (Live Cover) - Single"
                        }
                        else {
                            $fallbackAlbum = "$songTitle - Cover"
                        }
                    }
                    elseif ($liveArg -eq "--force-live") {
                        $fallbackAlbum = "$songTitle (Live) - Single"
                    }
                    else {
                        $fallbackAlbum = "$songTitle - Single"
                    }
                }
                $probe = [PSCustomObject]@{
                    title = $songTitle
                    artist = $fallbackArtist
                    album = $fallbackAlbum
                    year = $yearText
                    online_match = $false
                }
            }

            if ($probe -and $probe.online_match) {
                $artworkStatus = (& $Z "5peg")
                if ($probe.artwork) { $artworkStatus = (& $Z "5pyJ") }
                $text = (& $Z "5oiR5om+5Yiw55qE57uT5p6c5piv77ya") + "`r`n`r`n" +
                    (& $Z "5q2M5ZCN77ya") + $probe.title + "`r`n" +
                    (& $Z "5q2M5omL77ya") + $probe.artist + "`r`n" +
                    (& $Z "5LiT6L6R77ya") + $probe.album + "`r`n" +
                    (& $Z "5bm05Lu977ya") + $probe.year + "`r`n" +
                    (& $Z "5bCB6Z2i77ya") + $artworkStatus + "`r`n`r`n" +
                    (& $Z "6L+Z5piv5q2j56Gu55qE5q2M5ZCX77yf")
            }
            elseif ($probe) {
                $artworkStatus = (& $Z "5peg")
                if ($probe.artwork) { $artworkStatus = (& $Z "5pyJ") }
                $text = (& $Z "5pqC5pe25rKh5pyJ5Zyo572R5LiK57K+56Gu5Yy56YWN5Yiw77yM5Y+q6IO95oyJ5L2g5o+Q5L6b55qE5L+h5oGv5a+85YWl77ya") + "`r`n`r`n" +
                    (& $Z "5q2M5ZCN77ya") + $probe.title + "`r`n" +
                    (& $Z "5q2M5omL77ya") + $probe.artist + "`r`n" +
                    (& $Z "5LiT6L6R77ya") + $probe.album + "`r`n" +
                    (& $Z "5bm05Lu977ya") + $probe.year + "`r`n" +
                    (& $Z "5bCB6Z2i77ya") + $artworkStatus + "`r`n`r`n" +
                    (& $Z "6KaB57un57ut5a+85YWl5ZCX77yf")
            }
            else {
                $text = (& $Z "6L+Z5qyh5rKh6IO96K+G5Yir5Ye65q2M5puy44CC6KaB57un57ut6KGl5YWF5L+h5oGv5YaN6K+V5ZCX77yf")
            }

            $answer = Ask-Confirm $text (& $Z "56Gu6K6k5q2M5puy5L+h5oGv")
            if ($answer -eq [System.Windows.Forms.DialogResult]::Yes) {
                $confirmed = $true
                break
            }
            if ($answer -eq [System.Windows.Forms.DialogResult]::Cancel) {
                Write-Log "User cancelled file: $file"
                $skipFile = $true
                break
            }

            $trackInfo = Ask-TrackInfo `
                -FileName ([System.IO.Path]::GetFileName($file)) `
                -DefaultSongTitle $songTitle `
                -DefaultArtist $artistName `
                -DefaultAlbum $albumName `
                -DefaultYear $yearText `
                -DefaultExtra $extraText `
                -DefaultLive $isLive `
                -DefaultCover $isCover `
                -DefaultCoverArtist $coverArtist `
                -Message (& $Z "6KGl5YWF5oiW5L+u5pS55L+h5oGv5ZCO6YeN5paw6K+G5Yir44CC")
            if ($trackInfo.Cancelled) {
                Write-Log "User cancelled file after probe: $file"
                $skipFile = $true
                break
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
            $liveArg = if ($isLive) { "--force-live" } else { "--force-studio" }
            $coverArtist = ""
            if ($isCover) {
                $coverArtist = $trackInfo.CoverArtist
                if ([string]::IsNullOrWhiteSpace($coverArtist)) {
                    $coverArtist = $artistName
                }
            }
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
            $json = Run-Python -Code $processor -PyArgs $processorArgs
            Write-Log "Python stdout for $file : $json"
            $result = $json | ConvertFrom-Json
            $parts = @("$($result.title) - $($result.artist)")
            if ($result.album) { $parts += ((& $Z "5LiT6L6R77ya") + $result.album) }
            if ($result.year) { $parts += ((& $Z "5bm05Lu977ya") + $result.year) }
            if ($result.composer) { $parts += ((& $Z "5L2c5puy77ya") + $result.composer) }
            if ($result.lyricist) { $parts += ((& $Z "5aGr6K+N77ya") + $result.lyricist) }
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
    Write-Log ("Fatal error: " + $_.Exception.Message)
    Show-Message $_.Exception.Message "Apple Music Auto Import - Error"
    exit 1
}


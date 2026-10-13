$ErrorActionPreference = 'Stop'
$raw = Get-Content (Join-Path $PSScriptRoot '../AppleMusic-Auto-Enrich-Import.ps1') -Raw -Encoding UTF8
$tokens = $null; $errors = $null
$ast = [System.Management.Automation.Language.Parser]::ParseInput($raw, [ref]$tokens, [ref]$errors)
if ($errors.Count) { throw ($errors | Out-String) }
# Exercise the exact functions used by Ask-TrackInfo without opening the app.
$functions = $ast.FindAll({ param($node) $node -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $false)
foreach ($fn in $functions) { Invoke-Expression $fn.Extent.Text }
$dir = Join-Path $env:TEMP ('am-title-tests-' + [guid]::NewGuid().ToString('N'))
New-Item $dir -ItemType Directory | Out-Null
$cases = @(
    @{ title='算了吧 - Aioz/刘思达LOFTHESTAR『示例歌词摘句』【動態歌詞】'; expectedTitle=''; expectedArtist='' },
    @{ title='另一首 - 另一位【动态歌词】'; expectedTitle=''; expectedArtist='' },
    @{ title='Artist - Song (Official Music Video)'; expectedTitle=''; expectedArtist='' },
    @{ title='Song - Artist [Lyrics]'; expectedTitle=''; expectedArtist='' },
    @{ title='【Hi-Res无损音质】《示例歌》 - 示例歌手『摘句』'; expectedTitle='示例歌'; expectedArtist='示例歌手' },
    @{ title='示例歌手《示例歌》【動態歌詞】'; expectedTitle='示例歌'; expectedArtist='示例歌手' },
    @{ title='示例歌手【示例歌】[Official Video]'; expectedTitle='示例歌'; expectedArtist='示例歌手' },
    @{ title='【动态歌词】'; expectedTitle=''; expectedArtist='' },
    @{ title='[Lyrics]'; expectedTitle=''; expectedArtist='' },
    @{ title='Promotional upload'; description='推荐大家听《无关的歌》'; expectedTitle=''; expectedArtist='' },
    @{ title='Upload'; channel='Music Official'; playlist_uploader='Music Blogger'; playlist_title='Best Songs'; expectedTitle=''; expectedArtist='' },
    @{ title='Song - Artist'; track='Song'; artist='Artist'; expectedTitle='Song'; expectedArtist='Artist' },
    @{ title='Artist - Song'; track='Song'; artist='Artist'; expectedTitle='Song'; expectedArtist='Artist' },
    @{ title='Song - Artist'; artist='Artist'; expectedTitle='Song'; expectedArtist='Artist' },
    @{ title='Artist - Song'; track='Song'; expectedTitle='Song'; expectedArtist='Artist' },
    @{ title='Upload'; description="歌名：标注歌曲`n歌手：标注歌手"; expectedTitle='标注歌曲'; expectedArtist='标注歌手' },
    @{ title='《错误标题》'; track='目录歌名'; artist='目录歌手'; expectedTitle='目录歌名'; expectedArtist='目录歌手' }
)
try {
    foreach ($case in $cases) {
        $file = Join-Path $dir 'sample.m4a'
        $case | ConvertTo-Json | Set-Content "$file.aminfo.json" -Encoding UTF8
        $result = Get-TrackDefaultsFromVideoInfo $file
        if ($result.Title -ne $case.expectedTitle -or $result.Artist -ne $case.expectedArtist) {
            throw "$($case.title): got title=[$($result.Title)] artist=[$($result.Artist)]"
        }
        if ($case.playlist_title -and $result.Album) { throw 'Playlist was treated as an album' }
    }
    $local = Get-TrackDefaultsFromVideoInfo (Join-Path $dir 'Unknown - Pair [Lyrics].m4a')
    if ($local.Title -or $local.Artist) { throw 'Local filename guessed a direction' }
    if ($raw -match '\$songTitle\s*=\s*\$baseName|\$defaultSongTitle\s*=\s*\$baseName') { throw 'UI restored an unverified filename' }
    Write-Output "Conservative identity defaults: $($cases.Count + 1) cases passed."
}
finally {
    # This is the unique test directory created above, directly under TEMP.
    Remove-Item -LiteralPath $dir -Recurse -Force
}

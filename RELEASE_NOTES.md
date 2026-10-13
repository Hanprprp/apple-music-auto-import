# v0.3.1

正式版：Windows 11 x64 + Apple Music for Windows。

- 修复全新电脑没有 Chrome Cookie 数据库时下载中断的问题；保留 Cookie 故障回退和有限网络重试。
- 改善歌曲字段识别：过滤视频标签及摘句，无法确定时留空；不将上传者、播放列表或未验证搜索候选当成歌曲资料。
- 新增歌词补充来源及来源记录，改善封面下载与预览复用。
- 内置 `Check-Environment.vbs` 环境检测，检查 Python、依赖、Apple Music、自动导入目录及在线资料源等条件。
- 验证：本机和 Windows 11 x64 虚拟机（OS 10.0.26200，Apple Music 1.1540.23042.0）；用户确认虚拟机内下载、导入、播放、封面和歌词均正常。
- 边界：不保证所有歌曲与网络；其他系统/架构及云同步未验证。环境检测通过不等于所有功能和平台均已验证。

以下保留开发阶段变更记录。

# v0.3.1-dev.5 (local testing)

- Fall back to anonymous downloads when Chrome's cookie database does not exist (including a clean Windows installation without Chrome). Preserve terminal errors from the anonymous attempt.
- Add missing-cookie-database regression cases alongside locked and undecryptable cookie databases.

# v0.3.1-dev.4 (local testing)

- Download remote artwork into the preview payload with per-request timeouts and a configured loopback-proxy fallback. Preserve TLS validation and the selected cover identity.
- Reuse the downloaded preview image for import; replace indefinite asynchronous cover loading with an actionable failure message.
- Validate JPEG/PNG response signatures and size, with tests for route failure, image payloads, removal, and unavailable artwork.

# v0.3.1-dev.3 (local testing)

- Parse presentation labels and quoted excerpts separately from song identity. Prefer catalog fields and explicit description labels; do not assume the direction of an unlabelled hyphen pair.
- Keep uncertain initial fields empty, including local files without a sidecar. Remove raw-filename refill, uploader-as-artist, and playlist-as-album defaults.
- Do not promote search candidates or the video-title hint to confirmed metadata after a failed lookup. Preserve explicit user input.
- Add 18 input-default cases and 3 failed-lookup cases; retain existing supported book-title and performance formats.

# v0.3.1-dev.2 (local testing)

- Add Haogeh web lyrics as a last fallback after NetEase and LRCLIB. Require exact song title and matching supplied artists; skip live requests and unavailable pages.
- Preserve the lyric page URL in preview provenance and cache, and fill missing explicit songwriting credits. KKBOX is not yet integrated.
- Add synthetic regression checks for wrong-title/artist rejection, network failures, fallback selection, and source propagation.

# v0.3.1-dev.1 (local testing)

- Preserve terminal downloader errors instead of replacing a later TLS failure with an earlier recovered Chrome-cookie warning.
- Distinguish transient HTTPS/network failures, HTTP 403/login requirements, and browser-cookie access failures; include the diagnostic log location.
- Retry transient connection failures at most twice with short backoff, preserving anonymous mode after cookie recovery. Certificate validation remains enabled.
- Added regressions for cookie-then-TLS failures, recovery, retry limits, non-retryable errors, and PowerShell error presentation.

# v0.3.0

Released on 2026-10-10. Promotes the rc.23 implementation to a regular release; the release preparation changes the version and documentation, not song-processing behavior.

## Highlights

- Full editable pre-import preview for metadata, artwork, lyrics, and songwriting credits.
- Improved performer/original-artist matching, Chinese identity matching, lyric cleanup, and cached lyric recovery.
- Shared per-user settings and cache location for desktop and packaged-app launches.
- Environment checker, pinned dependencies, portable packaging script, and regression tests.

## Known limitations

- Some song-specific tests still fail. Review and correct metadata and lyrics before importing.
- Clean-machine compatibility has not been verified; the documented target is Windows 11 x64 with Apple Music for Windows and Python 3.10 or newer.
- Local import and Apple Music cloud synchronization are separate. End-to-end import and cloud sync have not been revalidated for this release.

# v0.3.0-rc.23

## Validation status

- Development snapshot saved on 2026-10-09; some song-specific tests are still failing.
- Current priority is correctness on the development PC. Clean-machine compatibility and end-to-end import/cloud sync have not been revalidated for this snapshot.
- Offline processor, downloader cookie fallback, and PowerShell defaults regression checks passed on the development PC. These checks do not establish that all songs work correctly.

## Fixed in rc.23

- Stores logs, settings, and lyric caches under `%USERPROFILE%\.apple-music-auto-import`, which is not redirected by Windows packaged-app file virtualization.
- Automatically migrates configuration and verified lyric caches from both legacy Local AppData locations.
- Makes Explorer-launched and Codex-launched runs use the same physical cache instead of two look-alike paths.

# v0.3.0-rc.22

## Fixed in rc.22

- Restores cached lyrics and songwriting credits at the final preview-window boundary, so retry and alternate preview paths cannot bypass recovery.
- Logs the lyric length before and after the final UI-boundary restore for direct diagnosis of the real desktop path.

# v0.3.0-rc.21

## Fixed in rc.21

- Uses one stable per-user state directory for the PowerShell host and every Python helper process.
- Restores missing preview lyrics and songwriting credits from the local cache after an exact normalized title-and-artist match, including Simplified/Traditional Chinese variants.
- Reads Python helper output from an explicit UTF-8 file so Windows console code pages cannot corrupt Chinese metadata.
- Writes startup diagnostics with the resolved state directory and falls back to an emergency log in `%TEMP%` if the primary log cannot be written.

# v0.3.0-rc.20

## Fixed in rc.20

- Restores cached lyrics and composer, lyricist, and arranger fields on the main preview thread when a background lookup task fails.
- Shows the running version in the full-preview window title so stale processes and old copies are immediately identifiable.
- Logs a compact full-preview result with lyric length and credit fields for end-to-end UI diagnosis.

# v0.3.0-rc.19

## Fixed in rc.19

- Preserves verified lyrics in the persistent cache even when the song title is never sung in the lyric body.
- Adds NetEase media and interface endpoints after the two standard lyric endpoints, preventing a temporary endpoint failure from leaving a cold preview blank.
- Reuses cached composer, lyricist, and arranger data during a provider outage.

# v0.3.0-rc.18

## Improved in rc.18

- Runs NetEase and Apple/iTunes metadata checks in parallel for an explicit Chinese title-and-artist identity.
- Uses the Apple/iTunes release date and track order when both providers identify the same recording, while retaining the NetEase song ID for lyrics and credits.
- Retries transient NetEase lyric failures three times and alternates the standard and desktop lyric query parameters.
- Reuses a verified NetEase song ID for both lyrics and credits without requiring the song title to appear in the lyric body.

## Fixed in rc.18

- Prevents a top-ranked NetEase hit from prematurely locking an incorrect album year or track number before Apple/iTunes corroboration.
- Restores lyrics and composer, lyricist, and arranger credits when the first two lyric requests fail transiently.
- Keeps valid lyrics for songs whose title is never sung, while preserving the Chinese-language guard against translated results.
- Removes music-editor and lyric-editor production credits from the visible lyric body.

# v0.3.0-rc.17

## Fixed in rc.17

- Applies the Chinese-lyric language check at the shared lyric validation gate, covering providers, persistent caches, reviewed metadata, and final preview output.
- Ignores previously saved English translations for Chinese-titled songs while retaining valid cached credits.
- Adds a final preview guard so an invalid translated lyric can never be shown or imported even if it enters through legacy precomputed metadata.

# v0.3.0-rc.16

## Improved in rc.16

- Ranks LRCLIB lyric candidates by title, artist, original-script language, and readable line structure instead of relying on response order.
- Evaluates both plain and synchronized lyric bodies so a translated plain lyric cannot hide a correct original-script synchronized lyric.

## Fixed in rc.16

- Prevents English translations returned under Traditional-Chinese artist aliases from replacing the Chinese original lyrics.
- Rejects translation-only results for Chinese-titled songs instead of importing incorrect lyrics.
- Preserves the selected lyric's line breaks in the final preview and Apple Music tag.

# v0.3.0-rc.15

## Improved in rc.15

- Runs NetEase and LRCLIB lyric lookups independently so one provider failure cannot abort the other fallback.
- Retries transient lyric and song-search requests and no longer caches empty search failures for the rest of the run.
- Persists verified lyrics and composer, lyricist, and arranger credits per song in the current Windows user's local data folder.
- Reuses cached verified lyrics during later previews, improving both reliability and preview speed.

## Fixed in rc.15

- Fixed a transient lyric request failure leaving the full preview completely blank even though album and artwork recognition succeeded.
- Removes artwork design, artist management, cooperation coordination, project director, and similar footer credits from visible lyrics.
- Keeps the visible lyric field limited to the lyric body followed by one final `作词：姓名` line.

# v0.3.0-rc.14

## Improved in rc.14

- Recognizes the performer after a book-title song name, including video titles such as `《song》 - artist - caption`.
- Uses the same parsed title and performer in the first confirmation form and every later metadata lookup.
- Uses Windows' complete Simplified/Traditional Chinese conversion table for catalog identity matching, with a built-in fallback for other environments.
- Accepts a one-character song title when it is paired with a reliable artist instead of discarding the recording as an ambiguous query.

## Fixed in rc.14

- Fixed titles where the song name was recognized but the artist field stayed blank, causing the complete preview to lose album, year, credits, artwork, and lyrics.
- Fixed Simplified artist input being rejected when Apple Music or another provider returned the same artist in Traditional Chinese.
- Keeps promotional text after a song title from being mistaken for the performer.

# v0.3.0-rc.13

## Improved in rc.13

- Reuses the verified NetEase song record for lyrics instead of running an unrelated second search after album and artwork recognition.
- Keeps one strict title-only lyric query as a fallback for artist aliases while still rejecting same-title results from the wrong artist.
- Retries a transient lyric request once and no longer caches temporary empty responses for the rest of the run.

## Fixed in rc.13

- Restores lyrics for tracks whose album and artwork were recognized correctly but whose second lyric search previously missed the matching record.
- Accepts valid English and other non-CJK lyric bodies instead of incorrectly requiring at least 20 Chinese characters.

# v0.3.0-rc.12

## Improved in rc.12

- Resolves explicit live covers through two verified identities: the current performer for live artwork and the original artist for release metadata, credits, and lyrics.
- Runs Apple Music release lookups in parallel and prefers the earliest exact title-and-artist release over recent compilations.
- Recognizes additional Traditional and Simplified Chinese title variants during strict identity matching.

## Fixed in rc.12

- Restores complete original-release metadata for well-known covers even when the original is not the first same-title search result.
- Keeps the verified live performer's official artwork while retaining the original album, year, track order, composer, lyricist, arranger, and lyrics.
- Removes English production footer lines such as `Program` and `Lyric by` from the visible lyric body.
- Avoids preferring a live credit block when original studio lyrics are requested.

# v0.3.0-rc.11

## Improved in rc.11

- Joins short timestamped Chinese lyric fragments into natural readable lines instead of showing one or two characters per line.
- Uses a top-ranked exact Chinese title-and-artist match immediately instead of waiting for a duplicate slow metadata provider.
- Skips redundant release refinement when a non-cover recording already has a verified album and release year.
- Limits optional Apple release lookups to a short preview-time budget while retaining them for covers and incomplete releases.
- Reads track position and album track count directly from NetEase results when available.

## Fixed in rc.11

- Keeps an already verified album and track order when marking a recording as live, rather than replacing it with a generated local-live single.

# v0.3.0-rc.10

## Fixed in rc.10

- Keeps the Apple Music lyric field limited to the lyric body plus one final `作词：姓名` line.
- Removes provider promotions, production credits, musicians, backing vocals, recording, mixing, mastering, planning, marketing, publishing, and similar non-lyric lines.
- Handles spaced role labels such as `人声 录音师` without leaving partial words in the lyric body.
- Preserves composer, lyricist, and arranger values in their dedicated metadata fields while cleaning the visible lyrics.

# v0.3.0-rc.9

## Fixed in rc.9

- Restores the editable song-title and current-performer row at the top of the final import preview.
- Fixes the top instruction bar covering the first metadata row and the source filename.
- Keeps manually edited title and performer values authoritative for re-query and import.

# v0.3.0-rc.8

## Fixed in rc.8

- Automatically retries public YouTube and Bilibili downloads without browser cookies when Chrome cookie access fails.
- Handles Windows DPAPI cookie-decryption failures in addition to a locked Chrome cookie database.
- Prevents a browser-cookie problem from aborting an otherwise accessible public-media download.

# v0.3.0-rc.7

## Improved in rc.7

- Removes tour, concert, venue, and show suffixes from a current-performer name before metadata lookup.
- Resolves same-title recordings with the parsed performer and the title-only popular original in parallel, preserving preview speed while still detecting officially released covers.
- Treats Simplified and Traditional variants such as `安静` and `安靜` as the same title during identity verification.

## Fixed in rc.7

- Fixed concert titles such as `周杰伦世界巡回演唱会香港站1205《安静》` saving the entire event description as the artist.
- Fixed a second-ranked unrelated namesake being accepted without corroboration and supplying the wrong artist, album, year, and cover.
- Fixed a published live cover being mistaken for an original merely because the current performer also has an Apple Music release.

# v0.3.0-rc.6

## Fixed in rc.6

- Fixed correct Simplified Chinese lyrics being rejected when the matched Apple Music title used Traditional Chinese, such as `聽海` versus `听海`.
- Lyrics and lyric-credit searches now query matching Simplified and Traditional title/artist pairs instead of relying on only the metadata script.
- Keeps the expanded lyric lookup bounded to one small concurrent batch so the preview does not regress to the earlier long wait.

# v0.3.0-rc.5

## Improved in rc.5

- Separates `song-performer@show` upload titles into song, current performer, and performance context before any metadata search.
- Recognizes performer-first book-title uploads such as `singer cover 《song》`, quality-prefixed live titles, and trailing collaboration names such as `song singer A & singer B`.
- Treats an explicit song-title field as authoritative, so video title, channel, and description lines cannot become extra title/artist candidates.
- Detects a cover by comparing the parsed current performer with the matched original artist; cover metadata keeps the original release while the track artist becomes the current performer.
- Refines a locked title/original-artist pair to the top official Apple Music release even when a provider first returns a later compilation.

## Fixed in rc.5

- Fixed `聽海-曹格@週日狂熱夜` being reversed into artist `聽海` and title `曹格@週日狂熱夜`.
- Removes words such as `翻唱` from the detected current-performer name instead of saving them as part of the artist.
- Fixed later compilations supplying the album and year for a cover instead of the original album release.
- Removes indented and repeated timestamps plus original-artist labels from plain lyrics.

# v0.3.0-rc.4

## Improved in rc.4

- Uses the top-ranked exact-title result to identify the original recording when a Chinese-language cover only provides the song title.
- Confirms the locked original recording against Apple Music HK/TW in parallel, filling the official album name, genre, date, track counts, and artwork without replacing the cover performer.
- Reuses the first metadata search for lyrics and credits, cutting the tested complete preview for `kQr1J2deAwQ` to about four seconds.
- Uses a more reliable NetEase artwork host and detects the image format from the downloaded bytes.

## Fixed in rc.4

- Fixed `刻在我心底的名字` selecting the later Mayday cover instead of Crowd Lu's 2020 original release.
- Never treats an ordinary YouTube upload date as the song's release year.
- No longer invents `- Cover` or `- Single` album names when online metadata fails.
- Keeps verified metadata visible when optional lyric, credit, or artwork requests fail, instead of replacing the entire preview with empty fields.
- Ensures single-track imports show a total track count of one rather than zero.

# v0.3.0-rc.3

## Improved in rc.3

- Performs cover detection inside the complete preview lookup instead of running a duplicate network pass first.
- Opens the preview without waiting for remote artwork; the album cover loads asynchronously in the open window.
- Stops exact-title fast searches early and gives confirmed title and artist fields priority over page-title noise.
- Keeps the original album, album artist, year, track order, artwork, and credits for covers; only the track artist becomes the current performer.

## Fixed in rc.3

- Fixed titles such as `曹格Gary-黑色幽默` and `【黑色幽默 Dark Humor】-Official Music Video` being parsed as page labels.
- Fixed slash-separated credits such as `曲: 周杰伦 / 词: 周杰伦` being merged into the composer field.
- Rejects unrelated same-title lyric credits and questionable MusicBrainz credits for Chinese-language tracks.
- Prevents `Official Music Video`, `Local Live Cover`, and unrelated artists from leaking into imported metadata.

# v0.3.0-rc.2

## Improved in rc.2

- Made the complete pre-import preview use the compact verified-search path and removed one redundant metadata pass.
- Runs lyric sources and credit lookups concurrently, with per-run caches for repeated NetEase requests.
- Allows an exact-title cover recording to supply explicit original-song composer and lyricist credits when the original recording is unavailable from the provider.
- Always displays the lyricist as `作词：姓名` at the end of available lyrics, including after manual preview edits.

## Fixed in rc.2

- Fixed cover imports that had lyrics but lost their composer or lyricist metadata.
- Fixed reviewed preview metadata losing its visible lyricist footer during the final import.

# v0.3.0 Release Candidate

This release focuses on reliable first-run behavior across different Windows PCs while preserving the metadata and batch-import improvements from v0.2.4.

## Added

- Added `Check-Environment.vbs` for a Chinese first-run compatibility report.
- Added exact, tested Python dependency versions in `requirements.txt`.
- Added portable-package build validation so releases cannot accidentally include logs, local configuration, tests, or a developer Python environment.

## Improved

- Resolves each Windows user's Music folder dynamically and remembers custom Apple Music media locations.
- Stores settings, logs, and the isolated Python environment under the current user's Local AppData folder.
- Supports Windows PowerShell 5.1 and PowerShell 7, including Unicode and space-containing extraction paths.
- Separates local-import readiness, online metadata availability, and Apple Music cloud synchronization in the compatibility report.
- Pins dependency versions so two fresh installations receive the same tested processing stack.

## Fixed

- Fixed first-run virtual-environment package installation.
- Fixed PowerShell 7 compatibility in environment detection.
- Fixed configuration and logging failures when the extracted program folder is read-only.
- Prevented a missing optional metadata service from blocking local-file import.

## Release Asset

Attach:

`AppleMusicAutoImportPortable.zip`

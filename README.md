# Apple Music Auto Import

> Development snapshot: `0.3.0-rc.23`. Some song-specific tests are still failing. Validation is focused on the current development PC; clean-machine compatibility is not yet verified. This snapshot is not a stable release.

Windows tool for tagging local audio files and importing them into Apple Music.

Have a favorite live performance, rare cover, YouTube video, or local audio file that Apple Music does not have? Copy the video link or choose a local file, and this tool turns it into a clean Apple Music library item with title, artist, album, year, cover art, credits when available, and lyrics when available.

It can download supported webpage video links through `yt-dlp`, convert the audio to M4A, ask for the song details in one Chinese form, search metadata, write tags and cover art, and drop the processed file into Apple Music's auto-import folder.

## Features

- Paste supported webpage video links, including YouTube-style links, and download best available audio automatically
- Download a whole supported playlist/album link in one pass, then fill shared album details once
- Select local audio files: `.m4a`, `.mp4`, `.aac`, `.mp3`, `.flac`, `.wav`
- One-window Chinese form for title, artist, album, year, extra hints, live version, and cover version
- Automatic cover detection that keeps the current performer while inheriting the verified original release, credits, lyrics, and artwork
- Chinese input mode is enabled in the form fields so Pinyin input stays ready
- Better Chinese metadata matching through NetEase and Kuwo, with iTunes still used for high-confidence matches and artwork fallback
- Handles bad download filenames such as `videoplayback.m4a`
- Live mode: adds `(Live)` to title and uses a live single album name
- Cover mode: uses the current performer as the track artist while keeping the original artist as album artist and inheriting the original release metadata
- Writes title, artist, album, album artist, year, genre, track/disc numbers, artwork, and available lyrics
- Cleans the visible lyric field to lyric lines plus one final lyricist credit, excluding production and promotional credits
- Rejoins over-segmented timestamp lyrics into readable lines before preview and import
- Shows a full pre-import preview with artwork, lyrics, credits, release data, and track/disc details before any file reaches Apple Music
- Lets you edit every displayed metadata field, lyrics, or cover artwork; the final edit always overrides automatic matching
- Performs a second artwork pass when the first metadata result has no cover image
- Imports through Apple Music's `Automatically Add to Apple Music` folder
- Portable folder layout, with no hard-coded Windows username
- Resolves each PC's Windows Music folder dynamically; if Apple Music uses a custom media location, asks once and remembers it

## Download

Use the portable folder zip from the latest GitHub Release:

`AppleMusicAutoImportPortable.zip`

Extract the whole folder, then run:

`Start-AppleMusic-Auto-Import.vbs`

Extract the whole zip first, then double-click `Check-Environment.vbs`. If every check passes, run `Start-AppleMusic-Auto-Import.vbs`.

Do not copy only the `.ps1` file. Keep the `.vbs` launchers and `.ps1` script in the same folder.

## Requirements

- Windows 11 x64 with the current Microsoft Store version of Apple Music
- Apple Music for Windows, opened at least once
- Python 3.10 or newer
- Internet access for link download, metadata search, and first-time dependency installation

The tested Python package versions are recorded in `requirements.txt`. Manual installation is normally unnecessary; for troubleshooting, use:

```powershell
python -m pip install -r requirements.txt
```

The tool creates its own isolated Python environment under the current Windows user's Local AppData folder and offers to install the tested package versions on first launch. It does not rely on Codex's internal runtime or write configuration into a protected application folder.

## First Run

1. Install Apple Music for Windows.
2. Open Apple Music once so it creates its media folders.
3. Install Python 3.10 or newer if needed.
4. Extract this tool's zip.
5. Double-click `Check-Environment.vbs` and confirm every check passes.
6. Double-click `Start-AppleMusic-Auto-Import.vbs`.
7. Paste a webpage video link, paste a playlist/album link, or choose one or more local audio files.
8. If a single video is used, click the current-video download button.
9. If a playlist or album is used, click the whole-playlist download button, then fill the shared album form once.
10. Fill in the Chinese form:
   - song title
   - original artist
   - album and year, if you know them
   - extra hints, if needed
   - live or normal version
   - cover or original version
   - cover artist, if needed
11. Confirm the detected metadata before import.

In playlist/album batch mode, the tool first tries to find the album tracklist from online metadata and writes the official track numbers. If no album tracklist can be matched, it falls back to the playlist order.

YouTube automatic Mix/Radio links whose `list=` value starts with `RD` are not normal playlists. The tool tries a YouTube Music queue fallback for these links, but caps the queue with the "max tracks" field because Mix/Radio can keep adding recommendations. The default is 15 tracks; clear the field for normal playlists if you want the whole list.

If the auto-import folder cannot be found, the tool asks you to choose it manually.

The normal Apple Music location is based on that Windows account's Music folder, not the maintainer's username. Apple Music also allows a custom media location; when one is configured outside the normal Music folder, select its `Automatically Add to Apple Music` folder once and the tool stores that choice locally.

## Compatibility Notes

- The tested release target is Windows 11 x64. ARM64 Windows and older Apple Music builds are not currently claimed as supported.
- The launcher prefers Windows PowerShell 5.1 and falls back to PowerShell 7.
- Windows account names, localized or redirected Music folders, OneDrive folder redirection, and spaces or Chinese characters in the extracted path are supported.
- Settings, logs, and the isolated Python environment are stored per Windows user under `%LOCALAPPDATA%\AppleMusicAutoImport`; they are not shared between Windows accounts.
- Extract the zip before running it. If Windows blocks the downloaded scripts, open the zip file's Properties, select Unblock, and extract it again.
- Enterprise AppLocker or group policies can block unsigned PowerShell/VBScript tools. A normal user-space script cannot bypass those policies.
- Online metadata and video downloads depend on the user's region, proxy, network, and the source website. Local audio can still be imported with manually entered metadata when an optional lookup service is unavailable.
- Login-only, age-restricted, private, member-only, DRM-protected, or region-blocked media is not guaranteed to download.
- Security software can block temporary scripts, Python, or FFmpeg. `Check-Environment.vbs` identifies the common missing or unwritable components, but organization-level policy must be changed by that computer's administrator.
- Local import and Apple Music cloud synchronization are separate. Cloud playlists require a working Apple Account sign-in, subscription, and Sync Library state.

## Live And Cover Behavior

Normal track:

`Song Title` by `Original Artist`

Live track:

`Song Title (Live)` by `Original Artist`

Cover track:

`Song Title` by `Cover Artist`

The album becomes:

`Song Title - Cover`

Live cover:

`Song Title (Live)` by `Cover Artist`

The album becomes:

`Song Title (Live Cover) - Single`

## Metadata Sources

The tool currently uses:

- yt-dlp for supported webpage video/audio downloads
- iTunes Search API
- NetEase public search endpoint for Chinese metadata and artwork
- Kuwo fallback search for Chinese metadata and artwork
- MusicBrainz for extra credits when available
- LRCLIB for plain lyrics when available

Some songs, especially live clips, covers, unreleased songs, and platform-specific tracks, may not have complete public metadata. The tool asks for confirmation before importing.

## Lyrics

The tool writes normal lyrics when available. Apple Music local files do not reliably support official scrolling/synced lyrics from embedded LRC tags, so this project intentionally avoids writing timestamped lyrics into the Apple Music-visible lyric field.

## Disclaimer

This is an unofficial local automation tool. It is not affiliated with Apple, Apple Music, iTunes, MusicBrainz, LRCLIB, NetEase, Kuwo, or any music platform.

Use it only with audio/video you have the right to download and use. This tool does not bypass DRM, paid access, login-only restrictions, or platform protections. Metadata and artwork are fetched from public endpoints where available, and availability/accuracy may vary.

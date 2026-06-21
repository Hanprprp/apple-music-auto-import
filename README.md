# Apple Music Auto Import

Windows tool for tagging local audio files and importing them into Apple Music.

Have a favorite live performance, rare cover, YouTube video, or local audio file that Apple Music does not have? Copy the video link or choose a local file, and this tool turns it into a clean Apple Music library item with title, artist, album, year, cover art, credits when available, and lyrics when available.

It can download supported webpage video links through `yt-dlp`, convert the audio to M4A, ask for the song details in one Chinese form, search metadata, write tags and cover art, and drop the processed file into Apple Music's auto-import folder.

## Features

- Paste supported webpage video links, including YouTube-style links, and download best available audio automatically
- Select local audio files: `.m4a`, `.mp4`, `.aac`, `.mp3`, `.flac`, `.wav`
- One-window Chinese form for title, artist, album, year, extra hints, live version, and cover version
- Chinese input mode is enabled in the form fields so Pinyin input stays ready
- Better Chinese metadata matching through NetEase and Kuwo, with iTunes still used for high-confidence matches and artwork fallback
- Handles bad download filenames such as `videoplayback.m4a`
- Live mode: adds `(Live)` to title and uses a live single album name
- Cover mode: keeps original song metadata but changes artist/album artist to the cover artist
- Writes title, artist, album, album artist, year, genre, track/disc numbers, artwork, and available lyrics
- Performs a second artwork pass when the first metadata result has no cover image
- Imports through Apple Music's `Automatically Add to Apple Music` folder
- Portable folder layout, with no hard-coded Windows username

## Download

Use the portable zip from the latest GitHub Release:

`AppleMusicAutoImportPortable.zip`

Extract the whole folder, then run:

`Start-AppleMusic-Auto-Import.vbs`

Do not copy only the `.ps1` file. Keep the `.vbs` launcher and `.ps1` script in the same folder.

## Requirements

- Windows
- Apple Music for Windows, opened at least once
- Python 3
- Internet access for link download, metadata search, and first-time dependency install

Python packages:

```powershell
python -m pip install --user mutagen imageio-ffmpeg pillow yt-dlp
```

The tool will offer to install these packages automatically if they are missing.

## First Run

1. Install Apple Music for Windows.
2. Open Apple Music once so it creates its media folders.
3. Install Python 3 if needed.
4. Extract this tool's portable zip.
5. Double-click `Start-AppleMusic-Auto-Import.vbs`.
6. Paste a webpage video link, or choose one or more local audio files.
7. If a link is used, the tool downloads the best available audio first.
8. Fill in the Chinese form:
   - song title
   - original artist
   - album and year, if you know them
   - extra hints, if needed
   - live or normal version
   - cover or original version
   - cover artist, if needed
9. Confirm the detected metadata before import.

If the auto-import folder cannot be found, the tool asks you to choose it manually.

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

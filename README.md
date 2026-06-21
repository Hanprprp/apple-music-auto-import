# Apple Music Auto Import

Windows tool for tagging local audio files and importing them into Apple Music.

It asks for the song title, original artist, whether the track is a live version, and whether it is a cover. It then searches metadata, writes tags and cover art into an M4A file, and drops the processed file into Apple Music's auto-import folder.

## Features

- Select local audio files: `.m4a`, `.mp4`, `.aac`, `.mp3`, `.flac`, `.wav`
- Chinese prompt flow for title, artist, live version, and cover version
- iTunes metadata search first, Chinese music fallback search second
- Handles bad download filenames such as `videoplayback.m4a`
- Live mode: adds `(Live)` to title and uses a live single album name
- Cover mode: keeps original song metadata but changes artist/album artist to the cover artist
- Writes title, artist, album, album artist, year, genre, track/disc numbers, artwork, and available lyrics
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
- Internet access for metadata search and first-time dependency install

Python packages:

```powershell
python -m pip install --user mutagen imageio-ffmpeg pillow
```

The tool will offer to install these packages automatically if they are missing.

## First Run

1. Install Apple Music for Windows.
2. Open Apple Music once so it creates its media folders.
3. Install Python 3 if needed.
4. Extract this tool's portable zip.
5. Double-click `Start-AppleMusic-Auto-Import.vbs`.
6. Select one or more audio files.
7. Fill in the Chinese prompts:
   - song title
   - original artist
   - live or normal version
   - cover or original version
   - cover artist, if needed
8. Confirm the detected metadata before import.

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

- iTunes Search API
- Chinese music fallback search
- MusicBrainz for extra credits when available
- LRCLIB for plain lyrics when available

Some songs, especially live clips, covers, unreleased songs, and platform-specific tracks, may not have complete public metadata. The tool asks for confirmation before importing.

## Lyrics

The tool writes normal lyrics when available. Apple Music local files do not reliably support official scrolling/synced lyrics from embedded LRC tags, so this project intentionally avoids writing timestamped lyrics into the Apple Music-visible lyric field.

## Disclaimer

This is an unofficial local automation tool. It is not affiliated with Apple, Apple Music, iTunes, MusicBrainz, LRCLIB, Kuwo, or any music platform.

Use it only with audio files you have the right to use. Metadata and artwork are fetched from public endpoints where available, and availability/accuracy may vary.


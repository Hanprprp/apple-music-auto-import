# v0.2.3

This release focuses on making the tool more stable for real local Apple Music imports.

## Changed

- Removed the experimental live lyric transcription feature.
- Live mode no longer tries to listen to the audio or generate guessed live lyrics.
- Lyrics now come only from normal online lyric sources when available.
- Live tracks are still kept as separate local versions, with live title and album naming.

## Improved

- Better YouTube-style link handling by saving downloaded video metadata beside the audio file.
- Better one-form defaults from video title and description, including title, artist, album, year, and extra hints.
- Cleaner song title detection for noisy video titles with tags, channel text, and bracketed notes.
- More careful handling for live and cover versions so local imports are less likely to become the wrong official Apple Music track.

## Fixed

- Removed a source of inaccurate live lyrics that could overwrite otherwise usable lyrics.
- Fixed release notes text encoding from the previous draft.

## Release Asset

Attach:

`AppleMusicAutoImportPortable.zip`

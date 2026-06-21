# v0.2.0

Web video link download release.

## Added

- New source window at startup.
- Automatically detects supported video links from the clipboard.
- Lets users paste YouTube-style webpage video links, one per line.
- Downloads best available audio with `yt-dlp`, then sends it through the existing Apple Music metadata/import flow.
- Local file selection still works from the same source window.
- Added `.webm`, `.opus`, and `.ogg` to local audio file selection.

## Changed

- Python dependency auto-install now includes `yt-dlp`.
- README and portable instructions now explain the link-download workflow.
- Desktop Chinese instructions were updated for link downloads.

## Notes

- Use link downloads only for audio/video you have the right to download and use.
- This tool does not bypass DRM, paid access, login-only restrictions, or platform protections.

## Release Asset

Attach:

`AppleMusicAutoImportPortable.zip`

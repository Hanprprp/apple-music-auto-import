# v0.2.4

This release improves album and playlist batch importing.

## Added

- Added playlist/album batch mode for supported YouTube-style links.
- Added a shared album form so users can fill album name, album artist, year, live/cover status, and cover artist once.
- Added a max-tracks field for playlist downloads. It defaults to 15 tracks to avoid importing a long automatic recommendation queue.
- Added YouTube automatic Mix/Radio fallback through the YouTube Music queue API for `RD` / `RDEM` links.
- Added album tracklist matching through online metadata so batch imports can write official track numbers.

## Improved

- Batch mode now prefers official album track order instead of trusting YouTube Mix order.
- If no album tracklist can be matched, the tool falls back to playlist order.
- Playlist downloads save per-track sidecar metadata including title, artist, album, year, playlist index, and playlist count.
- Documentation now explains the difference between normal playlists and YouTube automatic Mix/Radio queues.

## Fixed

- Prevented YouTube automatic Mix links from importing 50+ recommendation tracks by default.
- Reduced wrong ordering for album imports, including My Little Airport album batches.

## Release Asset

Attach:

`AppleMusicAutoImportPortable.zip`

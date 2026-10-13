"""A failed catalog lookup must not promote search guesses into metadata."""
import contextlib
import io
import json
import sys
from test_processor_regressions import load_processor

p = load_processor()
for name in ('known_video_override', 'known_override', 'lookup_verified_metadata'):
    p[name] = lambda *args, **kwargs: None
p['enrich_live_cover_artwork'] = lambda meta, *args, **kwargs: meta
p['apply_live_adjustment'] = lambda meta, *args, **kwargs: meta
for hint, title, artist in [
    ('video title: Left - Right [Lyrics]', '', ''),
    ('title: Confirmed Song\nartist: Confirmed Singer', 'Confirmed Song', 'Confirmed Singer'),
    ('title: Confirmed Song', 'Confirmed Song', ''),
]:
    sys.argv = ['processor', 'Left - Right [Lyrics].m4a', hint, '', '--force-studio', '--probe-only', '--fast-probe']
    output = io.StringIO()
    with contextlib.redirect_stdout(output):
        p['main']()
    result = json.loads(output.getvalue())
    assert result['title'] == title, result
    assert result['artist'] == artist, result
    assert result['online_match'] is False
print('Unverified identity fallback: 3 cases passed.')

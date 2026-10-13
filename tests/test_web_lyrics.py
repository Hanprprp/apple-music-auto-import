"""Synthetic lyrics only: fallback identity, failures, and provenance."""
from test_processor_regressions import load_processor


def run():
    p = load_processor()
    Page = p["WebLyricPage"]
    search = Page()
    search.feed('<a href="/song/123">result</a>')
    page = Page()
    page.feed('''<h1>Test Song - Test Artist</h1>
      <div class="field--name-field-geshou"><div>Test Artist</div></div>
      <div class="field--name-body"><p>
      Synthetic morning over fictional mountains<br>
      Invented rivers under imaginary skies<br>
      Testing words across a made up meadow<br>
      Sample music for an automated check</p></div>
      <footer>Do not include navigation</footer>''')
    p["fetch_web_lyric_page"] = lambda url: search if "search/node" in url else page
    meta = {"title": "Test Song", "artist": "Test Artist"}
    result = p["search_web_lyrics"](meta)
    assert result["lyric_source"].endswith("/123")
    assert "navigation" not in result["lyrics"]
    assert not p["search_web_lyrics"](dict(meta, artist="Other Artist"))
    assert not p["search_web_lyrics"](dict(meta, artist="Artist"))
    assert not p["search_web_lyrics"](dict(meta, title="Different Song"))
    assert not p["search_web_lyrics"](dict(meta, artist=""))
    assert not p["search_web_lyrics"](meta, prefer_live=True)
    p["known_video_lyrics"] = lambda *a: ""
    p["read_lyric_cache"] = lambda *a: {}
    p["search_netease_lyrics"] = lambda *a, **kw: ""
    p["search_lrclib_lyrics"] = lambda *a: ""
    saved = []
    p["write_lyric_cache"] = lambda *a, **kw: saved.append(a)
    assert p["find_lyrics"](meta) == result["lyrics"]
    assert saved[-1][2]["lyric_source"] == result["lyric_source"]
    output = {}
    p["restore_cached_lyric_data"](output, meta, result["lyrics"])
    assert result["lyric_source"] in output["source"]
    def failed(url):
        raise TimeoutError("unavailable")
    p["fetch_web_lyric_page"] = failed
    assert not p["search_web_lyrics"](meta)
    print("web lyric fallback: PASS")


if __name__ == "__main__":
    run()

"""Offline regression coverage for the embedded metadata processor."""

import contextlib
import io
import json
import os
import shutil
import sys
import tempfile
import urllib.parse
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "AppleMusic-Auto-Enrich-Import.ps1"


def load_processor():
    raw = SCRIPT.read_text(encoding="utf-8")
    marker = "$processor = @'"
    start = raw.index(marker) + len(marker)
    end = raw.index("\n'@", start)
    code = raw[start:end]
    code = code.replace('if __name__ == "__main__":\n    main()', "")
    namespace = {"__name__": "processor_regression_test"}
    exec(compile(code, str(SCRIPT), "exec"), namespace)
    return namespace


def write_sidecar(path, video_id, title):
    Path(str(path) + ".aminfo.json").write_text(
        json.dumps({"id": video_id, "title": title}, ensure_ascii=True),
        encoding="utf-8",
    )


def test_cover_title_context(processor, source):
    hint = "\u6c64\u4ee4\u5c71\u7ffb\u5531\u300a\u843d\u53f6\u5f52\u6839\u300b\u81f4\u656c\u4f20\u5947\u6b4c\u624b\u738b\u529b\u5b8f"
    candidates = processor["parse_candidates"](str(source), hint)
    assert processor["explicit_candidate_artists"](candidates)[0] == "\u6c64\u4ee4\u5c71"
    originals = processor["with_original_artist_context"](
        processor["original_song_candidates"](candidates), str(source), hint
    )
    assert originals[0]["artist"] == "\u738b\u529b\u5b8f"
    assert originals[0]["title"] == "\u843d\u53f6\u5f52\u6839"


def test_song_performer_at_show_title_is_split_before_lookup(processor, source):
    show_source = source.parent / "\u807d\u6d77-\u66f9\u683c@\u9031\u65e5\u72c2\u71b1\u591c [ZCdd9uOUVqw].webm"
    hint = (
        "title: \u807d\u6d77\n"
        "\u89c6\u9891\u6807\u9898: \u807d\u6d77-\u66f9\u683c@\u9031\u65e5\u72c2\u71b1\u591c\n"
        "\u9891\u9053: Fooly Cooly\n"
        "\u7b80\u4ecb: \u9031\u65e5\u72c2\u71b1\u591c \u7b2c60\u96c6"
    )
    parsed = processor["parse_attributed_performance"](show_source.stem)
    assert parsed == {
        "title": "\u807d\u6d77",
        "performer": "\u66f9\u683c",
        "context": "\u9031\u65e5\u72c2\u71b1\u591c",
    }
    candidates = processor["parse_candidates"](str(show_source), hint)
    assert candidates[0]["title"] == "\u807d\u6d77"
    assert candidates[0]["artist"] == "\u66f9\u683c"
    assert {item["title"] for item in candidates} == {"\u807d\u6d77"}
    assert {item["artist"] for item in candidates} <= {"", "\u66f9\u683c"}
    originals = processor["original_song_candidates"](candidates)
    assert originals[0] == {"artist": "", "title": "\u807d\u6d77", "query": "\u807d\u6d77"}
    performer = processor["detect_cover_performer"](
        candidates, "\u542c\u6d77", "\u5f20\u60e0\u59b9"
    )
    assert performer == "\u66f9\u683c"


def test_tour_context_is_removed_from_current_performer(processor, source):
    full_title = (
        "\u3010\u4f20\u4e16\u7ecf\u5178\u3011\u3010\u75af\u72c2\u53d8\u8c03\u3011"
        "\u5468\u6770\u4f26\u4e16\u754c\u5de1\u56de\u6f14\u5531\u4f1a\u9999\u6e2f\u7ad91205"
        "\u300a\u5b89\u9759\u300b\u73b0\u573a\u7248\u97f3\u9ad8\u6d4b\u91cf\u53ca\u7edf\u8ba1"
    )
    assert processor["clean_performance_artist"](
        "\u5468\u6770\u4f26\u4e16\u754c\u5de1\u56de\u6f14\u5531\u4f1a\u9999\u6e2f\u7ad91205"
    ) == "\u5468\u6770\u4f26"
    assert processor["extract_artist_near_book_title"](full_title) == "\u5468\u6770\u4f26"

    hint = f"title: \u5b89\u9759\nartist: \u5468\u6770\u4f26\u4e16\u754c\u5de1\u56de\u6f14\u5531\u4f1a\u9999\u6e2f\u7ad91205\n\u89c6\u9891\u6807\u9898: {full_title}"
    candidates = processor["parse_candidates"](str(source), hint)
    assert candidates[0]["title"] == "\u5b89\u9759"
    assert candidates[0]["artist"] == "\u5468\u6770\u4f26"
    assert not any("\u6f14\u5531\u4f1a" in item.get("artist", "") for item in candidates)


def test_artist_after_book_title_is_used_by_all_parsers(processor, source):
    full_title = (
        "\u3010\U0001d407\U0001d422-\U0001d411\U0001d41e\U0001d42c\u65e0\u635f\u97f3\u8d28\u3011\uff5c"
        "\u300a\u77ac\u300b- \u90d1\u6da6\u6cfd -\u2018\u8bf4\u8fc7\u8981\u4e00\u8d77\u770b\u7684\u6d77  "
        "\u73b0\u5728\u6211\u72ec\u81ea\u7b49\u5f85\u2019"
    )
    assert processor["extract_artist_near_book_title"](full_title) == "\u90d1\u6da6\u6cfd"
    candidates = processor["parse_candidates"](
        str(source),
        f"title: \u77ac\n\u89c6\u9891\u6807\u9898: {full_title}",
    )
    assert candidates[0]["title"] == "\u77ac"
    assert candidates[0]["artist"] == "\u90d1\u6da6\u6cfd"


def test_windows_chinese_mapping_keeps_catalog_artist_identity(processor):
    pairs = [
        ("\u90d1\u6da6\u6cfd", "\u912d\u6f64\u6fa4"),
        ("\u5f20\u5b66\u53cb", "\u5f35\u5b78\u53cb"),
        ("\u8427\u656c\u817e", "\u856d\u656c\u9a30"),
    ]
    for simplified, traditional in pairs:
        assert processor["norm"](simplified) == processor["norm"](traditional)
        assert processor["strict_artist_matches"](simplified, traditional)

    candidates = [{"title": "\u77ac", "artist": "\u90d1\u6da6\u6cfd", "query": "\u90d1\u6da6\u6cfd \u77ac"}]
    catalog_meta = {"title": "\u77ac", "artist": "\u912d\u6f64\u6fa4"}
    assert processor["metadata_is_trusted"](catalog_meta, candidates)


def test_bilingual_cover_performer_and_matching_title_pair(processor):
    candidates = [
        {"artist": "Wrong Hint", "title": "Different Song", "query": "Wrong Hint Different Song"},
        {"artist": "\u66f9\u683cGary", "title": "\u9ed1\u8272\u5e7d\u9ed8", "query": "\u66f9\u683cGary \u9ed1\u8272\u5e7d\u9ed8"},
    ]
    performer = processor["detect_cover_performer"](
        candidates, "\u9ed1\u8272\u5e7d\u9ed8", "\u5468\u6770\u4f26"
    )
    assert performer == "\u66f9\u683c"


def test_real_performer_original_comparisons(processor):
    cases = [
        ("\u807d\u6d77", "\u66f9\u683c", "\u5f35\u60e0\u59b9", "\u66f9\u683c"),
        ("\u627e\u81ea\u5df1", "\u5468\u6770\u4f26", "\u9676\u5586", "\u5468\u6770\u4f26"),
        ("\u98de\u673a\u573a\u7684\u5341\u70b9\u534a", "\u9676\u5586", "\u9676\u5586", ""),
        (
            "\u523b\u5728\u6211\u5fc3\u5e95\u7684\u540d\u5b57",
            "\u6c64\u4ee4\u5c71&Tyson Yoshi",
            "\u76e7\u5ee3\u4ef2",
            "\u6c64\u4ee4\u5c71&Tyson Yoshi",
        ),
        ("\u843d\u53f6\u5f52\u6839", "\u6c64\u4ee4\u5c71", "\u738b\u529b\u5b8f", "\u6c64\u4ee4\u5c71"),
    ]
    for title, performer, original_artist, expected in cases:
        candidates = [{"artist": performer, "title": title, "query": f"{performer} {title}"}]
        assert processor["detect_cover_performer"](candidates, title, original_artist) == expected


def test_slash_separated_hint_credits(processor):
    credits = processor["extract_hint_credits"](
        "\u66f2: \u5468\u6770\u4f26 / \u8bcd: \u5468\u6770\u4f26 / \u7f16\u66f2: \u949f\u5174\u6c11"
    )
    assert credits == {
        "composer": "\u5468\u6770\u4f26",
        "lyricist": "\u5468\u6770\u4f26",
        "arranger": "\u949f\u5174\u6c11",
    }


def test_structured_identity_ignores_video_title_noise(processor, source):
    hint = (
        "title: \u9ed1\u8272\u5e7d\u9ed8\n"
        "artist: \u5468\u6770\u4f26\n"
        "video title: \u5468\u6770\u4f26 Jay Chou[\u9ed1\u8272\u5e7d\u9ed8 Dark Humor]-Official Music Video"
    )
    candidates = processor["parse_candidates"](str(source), hint)
    assert candidates[0]["title"] == "\u9ed1\u8272\u5e7d\u9ed8"
    assert candidates[0]["artist"] == "\u5468\u6770\u4f26"
    assert not any(item.get("artist") == "Official Music Video" for item in candidates)
    assert processor["detect_cover_performer"](
        candidates, "\u9ed1\u8272\u5e7d\u9ed8", "\u5468\u6770\u4f26"
    ) == ""


def test_live_cover_preserves_original_release(processor):
    meta = {
        "title": "Same Song",
        "artist": "Cover Singer",
        "album": "Original Album",
        "album_artist": "Original Singer",
        "year": "2001",
        "release_date": "2001-02-03",
        "track_number": 4,
        "track_count": 10,
        "original_artist": "Original Singer",
        "source": "artist adjusted as cover version",
    }
    result = processor["apply_live_adjustment"](meta, "input.m4a", "__force_live__")
    assert result["title"] == "Same Song (Live)"
    assert result["album"] == "Original Album"
    assert result["album_artist"] == "Original Singer"
    assert result["track_number"] == 4
    assert result["track_count"] == 10


def test_embedded_video_title_beats_page_description(processor, source):
    hint = (
        "\u756a\u8304\u82b1 \u756a\u8304\u82b1 \u89c6\u9891\u6807\u9898: \u756a\u8304\u82b1\n"
        "\u4e0a\u4f20\u8005: _\u7f2a\u65afMuse\n"
        "\u7b80\u4ecb: \u6211\u770b\u7740\u4f60\u7684\u773c\u89d2\u6389\u773c\u6cea"
    )
    candidates = processor["parse_candidates"](str(source), hint)
    assert candidates[0]["title"] == "\u756a\u8304\u82b1"
    assert "\n" not in candidates[0]["title"]


def test_known_live_mapping(processor, source):
    write_sidecar(source, "3dW6r8tByOA", "")
    details = processor["local_live_details"](str(source), "")
    assert details == {"venue": "\u53f0\u5317", "event": "Soul Power", "year": "2003"}


def test_visible_lyricist(processor):
    lyrics = processor["append_visible_lyricist"]("A lyric line", "Lyric Writer")
    assert lyrics == "A lyric line\n\n\u4f5c\u8bcd\uff1aLyric Writer"
    replaced = processor["append_visible_lyricist"](
        "A lyric line\n\n\u586b\u8bcd\uff1aOld Writer", "New Writer"
    )
    assert replaced == "A lyric line\n\n\u4f5c\u8bcd\uff1aNew Writer"


def test_lyric_cleanup_removes_indented_timestamps_and_original_artist_label(processor):
    cleaned = processor["clean_lyric_text"](
        "  [00:01.00][00:02.00]First lyric\n"
        "[00:03.00]\u539f\u5531\uff1aOriginal Artist\n"
        "[00:04.00]Second lyric"
    )
    assert cleaned == "First lyric\nSecond lyric"


def test_lyric_cleanup_keeps_only_body_and_visible_lyricist(processor):
    raw = (
        "[00:00.00] \u4f5c\u8bcd : \u90d1\u6da6\u6cfd\n"
        "[00:01.00] \u4f5c\u66f2 : \u90d1\u6da6\u6cfd\n"
        "[00:02.00] \u7f16\u66f2 : \u8d75\u5efa\u98de\n"
        "[00:03.00] \u5236\u4f5c\u4eba : Producer\n"
        "[00:09.07]\u51fa\u54c1\uff1aProvider\n"
        "[00:34.10]\u770b\n"
        "[00:35.74]\u5e7b\u60f3\u4e2d\u7684\u884c\u661f\n"
        "[00:38.06]\u5e73\u884c\u4e0e\u5929\u9645\n"
        "[03:58.62]\u7f16\u66f2 : \u8d75\u5efa\u98de\n"
        "[03:59.36]\u5409\u4ed6\uff1aPlayer\n"
        "[03:59.46]\u548c\u58f0\u7f16\u5199\uff1aSinger\n"
        "[04:02.04]\u4eba\u58f0 \u5f55\u97f3\u5e08\uff1aEngineer\n"
        "[04:03.67]\u5f26\u4e50\u7f16\u5199\uff1aArranger\n"
        "[04:07.56]\u6df7\u97f3\u5e08\uff1aMixer\n"
        "[04:08.48]\u4f01\u5212\uff1aPlanner\n"
        "[04:09.45]\u8425\u9500\u4f01\u5212\uff1aMarketing\n"
        "[04:12.53]\u51fa\u54c1\u4eba\uff1aPublisher\n"
        "[04:12.80]\u4e50\u961f\u961f\u957f\uff1aBand Leader\n"
        "[04:13.00]Program: Programmer\n"
        "[04:13.20]Lyric by Writer\n"
        "[04:13.53] Provider \u7279\u522b\u4f01\u5212\u51fa\u54c1\n"
    )
    credits = processor["extract_lyric_credits"](raw)
    cleaned = processor["clean_lyric_text"](raw)
    visible = processor["append_visible_lyricist"](cleaned, credits["lyricist"])

    assert visible == (
        "\u770b\u5e7b\u60f3\u4e2d\u7684\u884c\u661f\n"
        "\u5e73\u884c\u4e0e\u5929\u9645\n\n"
        "\u4f5c\u8bcd\uff1a\u90d1\u6da6\u6cfd"
    )
    for label in (
        "\u51fa\u54c1", "\u5236\u4f5c\u4eba", "\u7f16\u66f2", "\u5409\u4ed6", "\u548c\u58f0",
        "\u5f55\u97f3", "\u5f26\u4e50", "\u6df7\u97f3", "\u4f01\u5212", "\u8425\u9500", "\u4e50\u961f", "Program", "Lyric by",
    ):
        assert label not in cleaned


def test_lyric_cleanup_removes_artwork_management_and_project_footer(processor):
    raw = "\n".join([
        "\u7b2c\u4e00\u53e5\u662f\u6b63\u5e38\u7684\u6b4c\u8bcd\u6b63\u6587",
        "\u7b2c\u4e8c\u53e5\u662f\u6b63\u5e38\u7684\u6b4c\u8bcd\u6b63\u6587",
        "\u7b2c\u4e09\u53e5\u662f\u6b63\u5e38\u7684\u6b4c\u8bcd\u6b63\u6587",
        "\u7b2c\u56db\u53e5\u662f\u6b63\u5e38\u7684\u6b4c\u8bcd\u6b63\u6587",
        "\u5c01\u9762\u8bbe\u8ba1 : ELANUS",
        "\u827a\u4eba\u7ecf\u7eaa : \u9752\u5c0f\u6854@\u9752\u6854\u5a31\u4e50",
        "\u827a\u4eba\u827a\u4eba\u5408\u4f5c\u7edf\u7b79\uff1a\u59da\u6167\u4f73@\u94f6\u6cb3\u65b9\u821f",
        "\u9879\u76ee\u603b\u76d1\uff1a\u5bab\u5c39\u7433@\u94f6\u6cb3\u65b9\u821f",
    ])
    cleaned = processor["clean_lyric_text"](raw)
    assert "ELANUS" not in cleaned
    assert "\u9752\u5c0f\u6854" not in cleaned
    assert "\u59da\u6167\u4f73" not in cleaned
    assert "\u5bab\u5c39\u7433" not in cleaned
    assert cleaned.splitlines()[-1].startswith("\u7b2c\u56db\u53e5")


def test_lyric_cleanup_removes_music_and_lyric_editor_credits(processor):
    raw = (
        "[00:10.00]\u4f60\u6e34\u671b\u5f97\u5f88\u7b80\u5355\n"
        "[00:20.00]\u662f\u4e24\u4eba\u7684\u753b\u9762\u800c\u6211\u5374\u65e0\u6cd5\u5b9e\u73b0\n"
        "[00:30.00]\u4ece\u90a3\u5929\u6c14\u6c1b\u5728\u74e6\u89e3\n"
        "[00:40.00]\u552f\u72ec\u7528\u8c0e\u8a00\u6765\u7f13\u89e3\n"
        "[00:50.00]\u97f3\u4e50\u7f16\u8f91\uff1a\u90d1\u6da6\u6cfd/\u8c2d\u7389\u5802\n"
        "[00:51.00]\u6b4c\u8a5e\u7de8\u8f2f\uff1aCatalog Editor"
    )
    cleaned = processor["clean_lyric_text"](raw)
    assert "\u97f3\u4e50\u7f16\u8f91" not in cleaned
    assert "\u6b4c\u8a5e\u7de8\u8f2f" not in cleaned
    assert cleaned.splitlines()[-1] == "\u552f\u72ec\u7528\u8c0e\u8a00\u6765\u7f13\u89e3"


def test_lyric_cleanup_joins_timed_cjk_fragments_into_natural_lines(processor):
    cleaned = processor["clean_lyric_text"](
        "[00:34.10]\u770b\n"
        "[00:35.74]\u5e7b\u60f3\u4e2d\u7684\u884c\u661f\n"
        "[00:38.06]\u5e73\u884c\u4e0e\u5929\u9645\n"
        "[00:41.83]\u542c\n"
        "[00:43.44]\u4f60\u8bf4\u8fc7\u7684\u8bdd\u8bed\n"
        "[00:45.61]\u662f\u90a3\u4e48\u5e73\u9759\n"
        "[03:43.48]\u4e5f\u8bb8\n"
        "[03:45.46]\u4f1a\u597d\n"
        "[03:47.51]\u6bd4\u8f83"
    )
    assert cleaned == (
        "\u770b\u5e7b\u60f3\u4e2d\u7684\u884c\u661f\n"
        "\u5e73\u884c\u4e0e\u5929\u9645\n"
        "\u542c\u4f60\u8bf4\u8fc7\u7684\u8bdd\u8bed\n"
        "\u662f\u90a3\u4e48\u5e73\u9759\n"
        "\u4e5f\u8bb8\u4f1a\u597d\u6bd4\u8f83"
    )


def test_usable_lyrics_accepts_non_cjk_body(processor):
    raw = (
        "[00:01.00]I remember every word you said that night\n"
        "[00:05.00]We were driving slowly underneath the city lights\n"
        "[00:09.00]Nothing lasts forever but I still remember you\n"
        "[00:13.00]Every road I follow brings me back to something true\n"
        "[00:17.00]Now the morning comes and I can finally see"
    )
    cleaned = processor["usable_lyrics"](raw, "A Song")
    assert cleaned.startswith("I remember every word")
    assert len(cleaned.splitlines()) == 5


def test_usable_lyrics_rejects_translation_for_cjk_title(processor):
    translation = "\n".join([
        "I thought that maybe someday you would be coming back",
        "But there are too many memories forcing the clock to continue",
        "I keep moving in the middle of the night",
        "The fragmented feelings remain with me",
        "This translated lyric must not replace the original",
    ])
    assert processor["usable_lyrics"](translation, "\u77ac") == ""


def test_old_translation_cache_is_ignored_for_cjk_title(processor):
    meta = {"title": "\u77ac", "artist": "\u90d1\u6da6\u6cfd"}
    path = processor["lyric_cache_path"](meta, False)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps({
        "title": "\u77ac",
        "artist": "\u90d1\u6da6\u6cfd",
        "lyrics": "\n".join([
            "I thought that maybe someday you would be coming back",
            "But there are too many memories forcing the clock to continue",
            "I keep moving in the middle of the night",
            "The fragmented feelings remain with me",
            "This translated lyric must not replace the original",
        ]),
        "lyricist": "\u90d1\u6da6\u6cfd",
    }, ensure_ascii=False), encoding="utf-8")
    cached = processor["read_lyric_cache"](meta, False)
    assert "lyrics" not in cached
    assert cached["lyricist"] == "\u90d1\u6da6\u6cfd"


def test_preview_payload_cannot_expose_translation_for_cjk_title(processor):
    meta = {
        "title": "\u77ac",
        "artist": "\u90d1\u6da6\u6cfd",
        "lyricist": "\u90d1\u6da6\u6cfd",
        "lyrics": "\n".join([
            "I thought that maybe someday you would be coming back",
            "But there are too many memories forcing the clock to continue",
            "I keep moving in the middle of the night",
            "The fragmented feelings remain with me",
            "This translated lyric must not replace the original",
        ]),
    }
    payload = processor["metadata_preview_payload"](meta)
    assert payload["lyrics"] == ""


def test_verified_netease_song_id_supplies_lyrics_without_research(processor):
    saved = {name: processor[name] for name in (
        "fetch_netease_lyric_raw", "search_netease_lyrics", "search_lrclib_lyrics",
    )}
    raw = (
        "[00:01.00]\u4f60\u6e34\u671b\u5f97\u5f88\u7b80\u5355\n"
        "[00:05.00]\u662f\u4e24\u4eba\u7684\u753b\u9762\u800c\u6211\u5374\u65e0\u6cd5\u5b9e\u73b0\n"
        "[00:09.00]\u4ece\u90a3\u5929\u6c14\u6c1b\u5728\u74e6\u89e3\n"
        "[00:13.00]\u552f\u72ec\u7528\u8c0e\u8a00\u6765\u7f13\u89e3"
    )
    calls = []
    try:
        processor["fetch_netease_lyric_raw"] = lambda song_id: calls.append(song_id) or raw
        unavailable = lambda *_args, **_kwargs: (_ for _ in ()).throw(
            AssertionError("verified song should not be searched again")
        )
        processor["search_netease_lyrics"] = unavailable
        processor["search_lrclib_lyrics"] = unavailable
        lyrics = processor["find_lyrics"]({
            "title": "\u7efd\u653e",
            "artist": "\u90d1\u6da6\u6cfd",
            "_netease_song_id": 12345,
        })
    finally:
        for name, value in saved.items():
            processor[name] = value
    assert calls == [12345]
    assert "\u552f\u72ec\u7528\u8c0e\u8a00" in lyrics


def test_verified_netease_song_id_supplies_credits_without_research(processor):
    original_fetch = processor["fetch_netease_lyric_raw"]
    original_search = processor["search_netease_song_rows"]
    raw = (
        "[00:00.00]\u4f5c\u8bcd : \u90d1\u6da6\u6cfd\n"
        "[00:01.00]\u4f5c\u66f2 : \u90d1\u6da6\u6cfd\n"
        "[00:02.00]\u7f16\u66f2 : Leezidi\n"
        "[00:27.74]\u4f60\u6e34\u671b\u5f97\u5f88\u7b80\u5355\n"
        "[00:31.92]\u662f\u4e24\u4eba\u7684\u753b\u9762\u800c\u6211\u5374\u65e0\u6cd5\u5b9e\u73b0\n"
        "[00:39.18]\u4ece\u90a3\u5929\u6c14\u6c1b\u5728\u74e6\u89e3\n"
        "[00:44.17]\u552f\u72ec\u7528\u8c0e\u8a00\u6765\u7f13\u89e3"
    )
    try:
        processor["fetch_netease_lyric_raw"] = lambda song_id: raw if song_id == 12345 else ""
        processor["search_netease_song_rows"] = lambda *_args, **_kwargs: (_ for _ in ()).throw(
            AssertionError("verified song credits should not be searched again")
        )
        credits = processor["find_netease_lyric_credits"]({
            "title": "\u7efd\u653e",
            "artist": "\u90d1\u6da6\u6cfd",
            "_netease_song_id": 12345,
        })
    finally:
        processor["fetch_netease_lyric_raw"] = original_fetch
        processor["search_netease_song_rows"] = original_search
    assert credits == {
        "lyricist": "\u90d1\u6da6\u6cfd",
        "composer": "\u90d1\u6da6\u6cfd",
        "arranger": "Leezidi",
    }


def test_lyrics_fall_back_when_preferred_provider_raises(processor):
    saved = {name: processor[name] for name in (
        "search_netease_lyrics", "search_lrclib_lyrics",
    )}
    meta = {"title": "\u540e\u5907\u6b4c\u8bcd\u6d4b\u8bd5", "artist": "\u540e\u5907\u6b4c\u624b"}
    fallback = "\n".join([
        "\u7b2c\u4e00\u53e5\u540e\u5907\u6b4c\u8bcd\u5df2\u7ecf\u6062\u590d",
        "\u7b2c\u4e8c\u53e5\u540e\u5907\u6b4c\u8bcd\u4ecd\u7136\u53ef\u7528",
        "\u7b2c\u4e09\u53e5\u4e0d\u4f1a\u88ab\u4e3b\u6765\u6e90\u62d6\u7d2f",
        "\u7b2c\u56db\u53e5\u4f1a\u6b63\u5e38\u663e\u793a\u5728\u9884\u89c8",
    ])
    try:
        processor["search_netease_lyrics"] = lambda *_args, **_kwargs: (_ for _ in ()).throw(
            OSError("primary provider unavailable")
        )
        processor["search_lrclib_lyrics"] = lambda *_args, **_kwargs: fallback
        assert processor["find_lyrics"](meta) == fallback
    finally:
        for name, value in saved.items():
            processor[name] = value


def test_persistent_lyric_cache_survives_provider_outage(processor):
    saved = {name: processor[name] for name in (
        "search_netease_lyrics", "search_lrclib_lyrics", "search_netease_song_rows",
    )}
    meta = {"title": "\u6301\u4e45\u6b4c\u8bcd\u6d4b\u8bd5", "artist": "\u6301\u4e45\u6b4c\u624b"}
    lyrics = "\n".join([
        "\u7b2c\u4e00\u53e5\u6301\u4e45\u6b4c\u8bcd\u6b63\u5728\u4fdd\u5b58",
        "\u7b2c\u4e8c\u53e5\u65ad\u7f51\u4ee5\u540e\u4ecd\u7136\u53ef\u7528",
        "\u7b2c\u4e09\u53e5\u4e0d\u9700\u8981\u518d\u6b21\u8bf7\u6c42",
        "\u7b2c\u56db\u53e5\u4f1a\u7ee7\u7eed\u663e\u793a\u5728\u9884\u89c8",
    ])
    credits = {"composer": "\u6d4b\u8bd5\u4f5c\u66f2", "lyricist": "\u6d4b\u8bd5\u4f5c\u8bcd", "arranger": "\u6d4b\u8bd5\u7f16\u66f2"}
    try:
        processor["write_lyric_cache"](meta, lyrics, credits)
        unavailable = lambda *_args, **_kwargs: (_ for _ in ()).throw(
            OSError("all providers unavailable")
        )
        processor["search_netease_lyrics"] = unavailable
        processor["search_lrclib_lyrics"] = unavailable
        processor["search_netease_song_rows"] = unavailable
        assert processor["find_lyrics"](meta) == lyrics
        assert processor["find_netease_lyric_credits"](meta) == credits
    finally:
        for name, value in saved.items():
            processor[name] = value


def test_verified_cache_keeps_lyrics_that_do_not_contain_title(processor):
    meta = {"title": "\u7efd\u653e", "artist": "\u90d1\u6da6\u6cfd"}
    lyrics = "\n".join([
        "\u4f60\u6e34\u671b\u5f97\u5f88\u7b80\u5355",
        "\u662f\u4e24\u4eba\u7684\u753b\u9762\u800c\u6211\u5374\u65e0\u6cd5\u5b9e\u73b0",
        "\u4ece\u90a3\u5929\u6c14\u6c1b\u5728\u74e6\u89e3",
        "\u552f\u72ec\u7528\u8c0e\u8a00\u6765\u7f13\u89e3",
    ])
    credits = {"composer": "\u90d1\u6da6\u6cfd", "lyricist": "\u90d1\u6da6\u6cfd", "arranger": "Leezidi"}
    processor["write_lyric_cache"](meta, lyrics, credits)
    cached = processor["read_lyric_cache"](meta)
    assert cached["lyrics"] == lyrics
    assert cached["composer"] == "\u90d1\u6da6\u6cfd"
    assert cached["lyricist"] == "\u90d1\u6da6\u6cfd"
    assert cached["arranger"] == "Leezidi"


def test_main_thread_restores_cached_lyrics_and_credits(processor):
    cached_lyrics = "\n".join([
        "\u4f60\u6e34\u671b\u5f97\u5f88\u7b80\u5355",
        "\u662f\u4e24\u4eba\u7684\u753b\u9762\u800c\u6211\u5374\u65e0\u6cd5\u5b9e\u73b0",
        "\u4ece\u90a3\u5929\u6c14\u6c1b\u5728\u74e6\u89e3",
        "\u552f\u72ec\u7528\u8c0e\u8a00\u6765\u7f13\u89e3",
    ])
    cached_credits = {"composer": "\u90d1\u6da6\u6cfd", "lyricist": "\u90d1\u6da6\u6cfd", "arranger": "Leezidi"}
    processor["write_lyric_cache"](
        {"title": "\u7efd\u653e", "artist": "\u90d1\u6da6\u6cfd"},
        cached_lyrics,
        cached_credits,
    )
    meta = {
        "title": "\u7dbb\u653e",
        "artist": "\u912d\u6f64\u6fa4",
        "source": "lyrics lookup unavailable",
    }
    lyric_meta = {"title": "\u7efd\u653e", "artist": "\u90d1\u6da6\u6cfd"}
    lyrics = processor["restore_cached_lyric_data"](meta, lyric_meta, "")
    assert "\u4f60\u6e34\u671b\u5f97\u5f88\u7b80\u5355" in lyrics
    assert meta["composer"] == "\u90d1\u6da6\u6cfd"
    assert meta["lyricist"] == "\u90d1\u6da6\u6cfd"
    assert meta["arranger"] == "Leezidi"
    assert "lyrics restored from verified cache" in meta["source"]
    assert "credits restored from verified cache" in meta["source"]


def test_netease_lyric_fetch_retries_transient_failure(processor):
    original_urlopen = processor["urllib"].request.urlopen
    original_sleep = processor["time"].sleep
    song_id = "retry-test-song"
    processor["_NETEASE_LYRIC_RAW_CACHE"].pop(song_id, None)
    calls = []

    class FakeResponse:
        def __enter__(self):
            return self

        def __exit__(self, *_args):
            return False

        def read(self):
            return json.dumps({"lrc": {"lyric": "[00:01.00]Recovered lyric line"}}).encode("utf-8")

    def flaky_urlopen(_request, timeout=5):
        calls.append((_request.full_url, timeout))
        if len(calls) <= 3:
            raise OSError("temporary network failure")
        return FakeResponse()

    try:
        processor["urllib"].request.urlopen = flaky_urlopen
        processor["time"].sleep = lambda _seconds: None
        raw = processor["fetch_netease_lyric_raw"](song_id)
    finally:
        processor["urllib"].request.urlopen = original_urlopen
        processor["time"].sleep = original_sleep
        processor["_NETEASE_LYRIC_RAW_CACHE"].pop(song_id, None)

    assert len(calls) == 4
    assert "lv=1" in calls[0][0]
    assert "lv=-1" in calls[1][0]
    assert "/api/song/media" in calls[2][0]
    assert "interface.music.163.com" in calls[3][0]
    assert "Recovered lyric line" in raw


def test_netease_lyrics_keeps_a_strict_title_only_fallback(processor):
    original_search = processor["search_netease_song_rows"]
    original_fetch = processor["fetch_netease_lyric_raw"]
    title = "\u8fd9\u9996\u6b4c"
    artist = "\u6b63\u786e\u6b4c\u624b"
    searched = []
    raw = (
        "[00:01.00]\u7b2c\u4e00\u53e5\u662f\u8fd9\u9996\u6b4c\u7684\u6b63\u786e\u6b4c\u8bcd\n"
        "[00:05.00]\u7b2c\u4e8c\u53e5\u662f\u8fd9\u9996\u6b4c\u7684\u6b63\u786e\u6b4c\u8bcd\n"
        "[00:09.00]\u7b2c\u4e09\u53e5\u662f\u8fd9\u9996\u6b4c\u7684\u6b63\u786e\u6b4c\u8bcd\n"
        "[00:13.00]\u7b2c\u56db\u53e5\u662f\u8fd9\u9996\u6b4c\u7684\u6b63\u786e\u6b4c\u8bcd"
    )
    try:
        def fake_search(term, limit=10):
            searched.append(term)
            if processor["norm"](term) != processor["norm"](title):
                return []
            return [{
                "id": 67890,
                "name": title,
                "artists": [{"name": artist}],
                "album": {"name": "\u6b63\u786e\u4e13\u8f91"},
            }]
        processor["search_netease_song_rows"] = fake_search
        processor["fetch_netease_lyric_raw"] = lambda song_id: raw if song_id == 67890 else ""
        lyrics = processor["search_netease_lyrics"]({"title": title, "artist": artist})
    finally:
        processor["search_netease_song_rows"] = original_search
        processor["fetch_netease_lyric_raw"] = original_fetch
    assert any(processor["norm"](term) == processor["norm"](title) for term in searched)
    assert "\u7b2c\u56db\u53e5" in lyrics


def test_lyric_title_check_accepts_traditional_title_with_simplified_lyrics(processor):
    lyrics = (
        "听海哭的声音\n"
        "叹惜着谁又被伤了心\n"
        "却还不清醒\n"
        "一定不是我至少我很冷静\n"
        "可是泪水就连泪水也都不相信"
    )
    assert processor["usable_lyrics"](lyrics, "\u807d\u6d77") == lyrics


def test_lyric_search_queries_matching_simplified_identity(processor):
    meta = {"title": "\u807d\u6d77", "artist": "\u5f35\u60e0\u59b9", "album": "BAD BOY"}
    netease_terms = []
    lrclib_queries = []
    original_search = processor["search_netease_song_rows"]
    original_http_json = processor["http_json"]

    def fake_netease(term, limit=10):
        netease_terms.append(term)
        return []

    def fake_http_json(url, timeout=12):
        lrclib_queries.append(urllib.parse.parse_qs(urllib.parse.urlparse(url).query))
        return []

    try:
        processor["search_netease_song_rows"] = fake_netease
        processor["http_json"] = fake_http_json
        assert processor["search_netease_lyrics"](meta) == ""
        assert processor["search_lrclib_lyrics"](meta) == ""
    finally:
        processor["search_netease_song_rows"] = original_search
        processor["http_json"] = original_http_json

    assert "\u5f20\u60e0\u59b9 \u542c\u6d77" in netease_terms
    assert any(
        query.get("track_name") == ["\u542c\u6d77"]
        and query.get("artist_name") == ["\u5f20\u60e0\u59b9"]
        for query in lrclib_queries
    )


def test_lrclib_prefers_original_script_over_english_translation(processor):
    original_http_json = processor["http_json"]
    english = "\n".join([
        "I thought that maybe someday you would be coming back",
        "But there are too many memories forcing the clock to continue",
        "I keep moving in the middle of the night",
        "The fragmented feelings remain with me",
        "This translated lyric must not replace the original",
    ])
    chinese = "\n".join([
        "\u6211\u60f3 \u8bf4\u4e0d\u6e05\u54ea\u5929 \u4f60\u5c31\u4f1a\u56de\u6765",
        "\u53ef\u592a\u591a\u7684\u601d\u5ff5 \u5374\u538b\u7740\u65f6\u949f\u8f6c",
        "\u6211\u559c\u6b22\u5728\u6df1\u591c\u91cc\u7b49\u5f85",
        "\u7b49\u4f60\u7684\u8eab\u5f71\u518d\u4e00\u6b21\u51fa\u73b0",
        "\u8fd9\u624d\u662f\u5e94\u8be5\u88ab\u9009\u4e2d\u7684\u4e2d\u6587\u539f\u8bcd",
    ])
    rows = [
        {"id": 1, "trackName": "\u77ac", "artistName": "\u912d\u6f64\u6fa4", "plainLyrics": english},
        {"id": 2, "trackName": "\u77ac", "artistName": "\u90d1\u6da6\u6cfd", "plainLyrics": chinese},
    ]
    try:
        processor["http_json"] = lambda *_args, **_kwargs: rows
        lyrics = processor["search_lrclib_lyrics"]({"title": "\u77ac", "artist": "\u90d1\u6da6\u6cfd"})
    finally:
        processor["http_json"] = original_http_json
    assert lyrics == chinese
    assert "\n" in lyrics
    assert "I thought" not in lyrics


def test_lrclib_rejects_translation_only_for_cjk_title(processor):
    original_http_json = processor["http_json"]
    english = "\n".join([
        "I thought that maybe someday you would be coming back",
        "But there are too many memories forcing the clock to continue",
        "I keep moving in the middle of the night",
        "The fragmented feelings remain with me",
        "This translated lyric must not replace the original",
    ])
    try:
        processor["http_json"] = lambda *_args, **_kwargs: [{
            "id": 1,
            "trackName": "\u77ac",
            "artistName": "\u912d\u6f64\u6fa4",
            "plainLyrics": english,
        }]
        lyrics = processor["search_lrclib_lyrics"]({"title": "\u77ac", "artist": "\u90d1\u6da6\u6cfd"})
    finally:
        processor["http_json"] = original_http_json
    assert lyrics == ""


def test_lrclib_uses_original_script_synced_lyrics_when_plain_is_translated(processor):
    original_http_json = processor["http_json"]
    english = "\n".join([
        "I thought that maybe someday you would be coming back",
        "But there are too many memories forcing the clock to continue",
        "I keep moving in the middle of the night",
        "The fragmented feelings remain with me",
        "This translated lyric must not replace the original",
    ])
    chinese_lines = [
        "\u6211\u60f3 \u8bf4\u4e0d\u6e05\u54ea\u5929 \u4f60\u5c31\u4f1a\u56de\u6765",
        "\u53ef\u592a\u591a\u7684\u601d\u5ff5 \u5374\u538b\u7740\u65f6\u949f\u8f6c",
        "\u6211\u559c\u6b22\u5728\u6df1\u591c\u91cc\u7b49\u5f85",
        "\u7b49\u4f60\u7684\u8eab\u5f71\u518d\u4e00\u6b21\u51fa\u73b0",
        "\u8fd9\u624d\u662f\u5e94\u8be5\u88ab\u9009\u4e2d\u7684\u4e2d\u6587\u539f\u8bcd",
    ]
    synced = "\n".join(f"[00:{index:02d}.00] {line}" for index, line in enumerate(chinese_lines, 1))
    try:
        processor["http_json"] = lambda *_args, **_kwargs: [{
            "id": 1,
            "trackName": "\u77ac",
            "artistName": "\u90d1\u6da6\u6cfd",
            "plainLyrics": english,
            "syncedLyrics": synced,
        }]
        lyrics = processor["search_lrclib_lyrics"]({"title": "\u77ac", "artist": "\u90d1\u6da6\u6cfd"})
    finally:
        processor["http_json"] = original_http_json
    assert lyrics == "\n".join(chinese_lines)
    assert "[00:" not in lyrics


def test_studio_lyric_lookup_does_not_prefer_live_credit_block(processor):
    original_search = processor["search_netease_song_rows"]
    original_fetch = processor["fetch_netease_lyric_raw"]
    live_body = "\n".join([
        "\u503e\u57ce\u73b0\u573a\u6b4c\u8bcd\u7b2c\u4e00\u53e5",
        "\u503e\u57ce\u73b0\u573a\u6b4c\u8bcd\u7b2c\u4e8c\u53e5",
        "\u503e\u57ce\u73b0\u573a\u6b4c\u8bcd\u7b2c\u4e09\u53e5",
        "\u503e\u57ce\u73b0\u573a\u6b4c\u8bcd\u7b2c\u56db\u53e5",
        "\u503e\u57ce\u73b0\u573a\u6b4c\u8bcd\u7b2c\u4e94\u53e5",
    ])
    studio_body = "\n".join([
        "\u503e\u57ce\u539f\u7248\u6b4c\u8bcd\u7b2c\u4e00\u53e5",
        "\u503e\u57ce\u539f\u7248\u6b4c\u8bcd\u7b2c\u4e8c\u53e5",
        "\u503e\u57ce\u539f\u7248\u6b4c\u8bcd\u7b2c\u4e09\u53e5",
        "\u503e\u57ce\u539f\u7248\u6b4c\u8bcd\u7b2c\u56db\u53e5",
        "\u503e\u57ce\u539f\u7248\u6b4c\u8bcd\u7b2c\u4e94\u53e5",
    ])
    try:
        processor["search_netease_song_rows"] = lambda _term, limit=10: [
            {
                "id": 1,
                "name": "\u503e\u57ce (Live)",
                "artists": [{"name": "\u8bb8\u7f8e\u9759"}],
                "album": {"name": "Live Album"},
            },
            {
                "id": 2,
                "name": "\u503e\u57ce",
                "artists": [{"name": "\u8bb8\u7f8e\u9759"}],
                "album": {"name": "Studio Album"},
            },
        ]
        processor["fetch_netease_lyric_raw"] = lambda song_id: (
            live_body if song_id == 1 else studio_body
        )
        lyrics = processor["search_netease_lyrics"]({
            "title": "\u503e\u57ce",
            "artist": "\u8bb8\u7f8e\u9759",
        }, prefer_live=False)
    finally:
        processor["search_netease_song_rows"] = original_search
        processor["fetch_netease_lyric_raw"] = original_fetch

    assert "\u539f\u7248\u6b4c\u8bcd" in lyrics
    assert "\u73b0\u573a\u6b4c\u8bcd" not in lyrics


def test_netease_artwork_host_and_content_signature(processor):
    original = "https://p3.music.126.net/hash/cover.jpg?param=1200y1200"
    assert processor["normalize_netease_artwork"](original).startswith("https://p1.music.126.net/")
    assert processor["artwork_image_format"]("image/jpg", original, b"\x89PNG\r\n\x1a\nrest") == processor["MP4Cover"].FORMAT_PNG


def test_identity_gate_rejects_same_title_wrong_artist_and_version(processor):
    candidates = [{"title": "Same Song", "artist": "Exact Artist", "query": "Exact Artist Same Song"}]
    wrong_artist = {"title": "Same Song", "artist": "Different Artist", "album": "Wrong Album"}
    wrong_version = {"title": "Same Song (DJ Remix)", "artist": "Exact Artist", "album": "Wrong Version"}
    correct = {"title": "Same Song", "artist": "Exact Artist", "album": "Official Album"}

    assert not processor["metadata_is_trusted"](wrong_artist, candidates)
    assert not processor["metadata_is_trusted"](wrong_version, candidates)
    assert processor["metadata_is_trusted"](correct, candidates)


def test_traditional_and_simplified_identity_match(processor):
    assert processor["title_match_score"]("\u8aaa\u8d70\u5c31\u8d70", "\u8bf4\u8d70\u5c31\u8d70") == 1.0
    assert processor["title_match_score"]("\u5b89\u9759", "\u5b89\u975c") == 1.0
    assert processor["title_match_score"]("\u503e\u57ce", "\u50be\u57ce") == 1.0
    assert processor["strict_artist_matches"]("\u5468\u6770\u4f26", "\u5468\u6770\u502b")
    assert processor["strict_artist_matches"]("\u5362\u5e7f\u4ef2", "\u76e7\u5ee3\u4ef2")


def test_itunes_release_refinement_accepts_traditional_exact_release(processor):
    original_http_json = processor["http_json"]
    requested = []

    def fake_http_json(url, timeout=20, headers=None):
        requested.append(url)
        return {"results": [{
            "trackName": "\u523b\u5728\u6211\u5fc3\u5e95\u7684\u540d\u5b57 (\u96fb\u5f71\u300a\u523b\u5728\u4f60\u5fc3\u5e95\u7684\u540d\u5b57\u300b\u4e3b\u984c\u66f2)",
            "artistName": "\u76e7\u5ee3\u4ef2",
            "collectionName": "\u523b\u5728\u6211\u5fc3\u5e95\u7684\u540d\u5b57 (\u96fb\u5f71\u300a\u523b\u5728\u4f60\u5fc3\u5e95\u7684\u540d\u5b57\u300b\u4e3b\u984c\u66f2) - Single",
            "releaseDate": "2020-08-25T12:00:00Z",
            "primaryGenreName": "\u570b\u8a9e\u6d41\u884c\u6a02",
            "trackNumber": 1,
            "trackCount": 1,
            "discNumber": 1,
            "discCount": 1,
            "artworkUrl100": "https://is1-ssl.mzstatic.com/image/thumb/test/100x100bb.jpg",
        }]}

    try:
        processor["http_json"] = fake_http_json
        result = processor["search_itunes_release_refinement"]({
            "title": "\u523b\u5728\u6211\u5fc3\u5e95\u7684\u540d\u5b57",
            "artist": "\u5362\u5e7f\u4ef2",
            "year": "2099",
            "release_date": "2099",
        })
    finally:
        processor["http_json"] = original_http_json

    query = urllib.parse.parse_qs(urllib.parse.urlparse(requested[0]).query)
    assert "\u76e7\u5ee3\u4ef2" in query["term"][0]
    assert result["album"].endswith("- Single")
    assert result["genre"] == "\u570b\u8a9e\u6d41\u884c\u6a02"
    assert result["release_date"] == "2020-08-25"
    assert result["artwork_url"].endswith("/1200x1200bb.jpg")


def test_title_only_cjk_uses_top_ranked_original(processor):
    candidates = [{
        "title": "\u523b\u5728\u6211\u5fc3\u5e95\u7684\u540d\u5b57",
        "artist": "",
        "query": "\u523b\u5728\u6211\u5fc3\u5e95\u7684\u540d\u5b57",
    }]
    original_itunes = processor["search_itunes"]
    original_netease = processor["search_netease"]
    original_kuwo = processor["search_kuwo"]
    try:
        processor["search_netease"] = lambda _candidates, fast=False: {
            "title": "\u523b\u5728\u6211\u5fc3\u5e95\u7684\u540d\u5b57",
            "artist": "\u5362\u5e7f\u4ef2",
            "album": "\u523b\u5728\u6211\u5fc3\u5e95\u7684\u540d\u5b57",
            "album_artist": "\u5362\u5e7f\u4ef2",
            "year": "2020",
            "release_date": "2020-08-25",
            "track_number": 1,
            "track_count": 1,
            "disc_number": 1,
            "disc_count": 1,
            "_provider": "netease",
            "_search_rank": 0,
            "source": "NetEase test",
        }
        processor["search_itunes"] = lambda *_args, **_kwargs: (_ for _ in ()).throw(
            AssertionError("top-ranked CJK title should not wait for iTunes")
        )
        processor["search_kuwo"] = lambda *_args, **_kwargs: None
        result = processor["lookup_verified_metadata"](candidates, fast=True)
    finally:
        processor["search_itunes"] = original_itunes
        processor["search_netease"] = original_netease
        processor["search_kuwo"] = original_kuwo

    assert result["artist"] == "\u5362\u5e7f\u4ef2"
    assert result["album"] == "\u523b\u5728\u6211\u5fc3\u5e95\u7684\u540d\u5b57"
    assert result["year"] == "2020"
    assert "top-ranked exact-title" in result["source"]


def test_explicit_cjk_identity_merges_itunes_release_precision(processor):
    candidates = [{
        "title": "\u7efd\u653e",
        "artist": "\u90d1\u6da6\u6cfd",
        "query": "\u90d1\u6da6\u6cfd \u7efd\u653e",
    }]
    original_itunes = processor["search_itunes"]
    original_netease = processor["search_netease"]
    original_kuwo = processor["search_kuwo"]
    itunes_calls = []
    try:
        processor["search_netease"] = lambda _candidates, fast=False: {
            "title": "\u7efd\u653e",
            "artist": "\u90d1\u6da6\u6cfd",
            "album": "\u68a6\u6e38",
            "album_artist": "\u90d1\u6da6\u6cfd",
            "year": "2023",
            "release_date": "2023-02-25",
            "track_number": 1,
            "track_count": 25,
            "disc_number": 1,
            "disc_count": 1,
            "artwork_url": "https://example.invalid/cover.jpg",
            "_provider": "netease",
            "_search_rank": 0,
            "_netease_song_id": 2025186889,
            "source": "NetEase exact performer test",
        }
        def fake_itunes(*_args, **_kwargs):
            itunes_calls.append(True)
            return {
                "title": "\u7dbb\u653e",
                "artist": "\u912d\u6f64\u6fa4",
                "album": "\u5922\u904a",
                "album_artist": "\u912d\u6f64\u6fa4",
                "year": "2022",
                "release_date": "2022-02-25",
                "track_number": 4,
                "track_count": 25,
                "disc_number": 1,
                "disc_count": 1,
                "artwork_url": "https://example.invalid/apple-cover.jpg",
                "_provider": "itunes",
                "source": "iTunes exact performer test",
            }
        processor["search_itunes"] = fake_itunes
        processor["search_kuwo"] = lambda *_args, **_kwargs: None
        result = processor["lookup_verified_metadata"](candidates, fast=True)
    finally:
        processor["search_itunes"] = original_itunes
        processor["search_netease"] = original_netease
        processor["search_kuwo"] = original_kuwo

    assert processor["strict_artist_matches"](result["artist"], "\u90d1\u6da6\u6cfd")
    assert processor["norm"](result["album"]) == processor["norm"]("\u68a6\u6e38")
    assert result["year"] == "2022"
    assert result["release_date"] == "2022-02-25"
    assert result["track_number"] == 4
    assert result["track_count"] == 25
    assert result["_netease_song_id"] == 2025186889
    assert itunes_calls == [True]
    assert "identity verified by" in result["source"]


def test_explicit_cover_accepts_exact_lower_rank_title_only_original(processor):
    candidates = [{"title": "\u503e\u57ce", "artist": "", "query": "\u503e\u57ce"}]
    original_itunes = processor["search_itunes"]
    original_netease = processor["search_netease"]
    original_kuwo = processor["search_kuwo"]
    try:
        processor["search_netease"] = lambda _candidates, fast=False: {
            "title": "\u503e\u57ce",
            "artist": "\u8bb8\u7f8e\u9759",
            "album": "Compilation",
            "album_artist": "\u8bb8\u7f8e\u9759",
            "year": "2023",
            "release_date": "2023-05-08",
            "track_number": 1,
            "track_count": 22,
            "disc_number": 1,
            "disc_count": 1,
            "_provider": "netease",
            "_search_rank": 1,
            "source": "NetEase exact lower-rank original",
        }
        processor["search_itunes"] = lambda *_args, **_kwargs: None
        processor["search_kuwo"] = lambda *_args, **_kwargs: None
        result = processor["lookup_verified_metadata"](
            candidates,
            fast=True,
            allow_unconfirmed_title_only=True,
        )
    finally:
        processor["search_itunes"] = original_itunes
        processor["search_netease"] = original_netease
        processor["search_kuwo"] = original_kuwo

    assert result["artist"] == "\u8bb8\u7f8e\u9759"
    assert result["title"] == "\u503e\u57ce"
    assert "explicit cover" in result["source"]


def test_current_performer_candidates_preserve_live_search_context(processor):
    result = processor["current_performer_candidates"]([{
        "artist": "\u9648\u5955\u8fc5",
        "title": "\u503e\u57ce",
        "query": "\u9648\u5955\u8fc5 \u503e\u57ce live",
    }])
    assert result == [{
        "artist": "\u9648\u5955\u8fc5",
        "title": "\u503e\u57ce",
        "query": "\u9648\u5955\u8fc5 \u503e\u57ce live",
    }]


def test_title_only_cjk_does_not_accept_second_ranked_namesake(processor):
    candidates = [{"title": "\u5b89\u9759", "artist": "", "query": "\u5b89\u9759"}]
    original_itunes = processor["search_itunes"]
    original_netease = processor["search_netease"]
    original_kuwo = processor["search_kuwo"]
    try:
        processor["search_netease"] = lambda _candidates, fast=False: {
            "title": "\u5b89\u9759",
            "artist": "\u63d0\u7c73FM",
            "album": "\u5b89\u9759",
            "album_artist": "\u63d0\u7c73FM",
            "year": "2026",
            "release_date": "2026",
            "track_number": 1,
            "track_count": 1,
            "disc_number": 1,
            "disc_count": 1,
            "_provider": "netease",
            "_search_rank": 1,
            "source": "NetEase wrong namesake",
        }
        processor["search_itunes"] = lambda _candidates, fast=False: {
            "title": "\u5b89\u9759",
            "artist": "\u5468\u6770\u502b",
            "album": "\u6770\u502b",
            "album_artist": "\u5468\u6770\u502b",
            "year": "2001",
            "release_date": "2001-09-14",
            "track_number": 10,
            "track_count": 10,
            "disc_number": 1,
            "disc_count": 1,
            "artwork_url": "https://example.invalid/jay.jpg",
            "_provider": "itunes",
            "source": "iTunes official album",
        }
        processor["search_kuwo"] = lambda *_args, **_kwargs: None
        result = processor["lookup_verified_metadata"](candidates, fast=True)
    finally:
        processor["search_itunes"] = original_itunes
        processor["search_netease"] = original_netease
        processor["search_kuwo"] = original_kuwo

    assert result["artist"] == "\u5468\u6770\u502b"
    assert result["album"] == "\u6770\u502b"
    assert result["year"] == "2001"


def test_title_only_cjk_rejects_uncorroborated_lower_rank_namesake(processor):
    candidates = [{"title": "\u5b89\u9759", "artist": "", "query": "\u5b89\u9759"}]
    original_itunes = processor["search_itunes"]
    original_netease = processor["search_netease"]
    original_kuwo = processor["search_kuwo"]
    try:
        processor["search_netease"] = lambda _candidates, fast=False: {
            "title": "\u5b89\u9759",
            "artist": "\u63d0\u7c73FM",
            "album": "\u5b89\u9759",
            "album_artist": "\u63d0\u7c73FM",
            "year": "2026",
            "release_date": "2026",
            "track_number": 1,
            "track_count": 1,
            "disc_number": 1,
            "disc_count": 1,
            "_provider": "netease",
            "_search_rank": 1,
            "source": "NetEase wrong namesake",
        }
        processor["search_itunes"] = lambda *_args, **_kwargs: None
        processor["search_kuwo"] = lambda *_args, **_kwargs: None
        result = processor["lookup_verified_metadata"](candidates, fast=True)
    finally:
        processor["search_itunes"] = original_itunes
        processor["search_netease"] = original_netease
        processor["search_kuwo"] = original_kuwo

    assert result is None


def test_verified_lookup_prefers_corrobated_full_release(processor):
    candidates = [{"title": "Same Song", "artist": "Exact Artist", "query": "Exact Artist Same Song"}]
    original_itunes = processor["search_itunes"]
    original_netease = processor["search_netease"]
    original_kuwo = processor["search_kuwo"]
    try:
        processor["search_itunes"] = lambda _candidates, fast=False: {
            "title": "Same Song",
            "artist": "Exact Artist",
            "album": "Official Album",
            "album_artist": "Exact Artist",
            "year": "2007",
            "release_date": "2007-01-01",
            "genre": "Pop",
            "track_number": 3,
            "track_count": 12,
            "disc_number": 1,
            "disc_count": 1,
            "artwork_url": "https://example.invalid/official.jpg",
            "source": "iTunes test",
        }
        processor["search_netease"] = lambda _candidates, fast=False: {
            "title": "Same Song",
            "artist": "Exact Artist",
            "album": "Same Song - Single",
            "album_artist": "Exact Artist",
            "year": "2007",
            "release_date": "2007-01-01",
            "track_number": 1,
            "track_count": 1,
            "disc_number": 1,
            "disc_count": 1,
            "source": "NetEase test",
        }
        processor["search_kuwo"] = lambda _candidates: None
        result = processor["lookup_verified_metadata"](candidates)
    finally:
        processor["search_itunes"] = original_itunes
        processor["search_netease"] = original_netease
        processor["search_kuwo"] = original_kuwo

    assert result["album"] == "Official Album"
    assert result["track_number"] == 3
    assert result["track_count"] == 12
    assert result["artwork_url"] == "https://example.invalid/official.jpg"
    assert "identity verified by itunes + netease" in result["source"]


def test_verified_merge_preserves_netease_song_id(processor):
    primary = {
        "title": "Same Song",
        "artist": "Same Artist",
        "album": "Official Album",
        "_provider": "itunes",
    }
    netease = {
        "title": "Same Song",
        "artist": "Same Artist",
        "album": "Official Album",
        "_provider": "netease",
        "_netease_song_id": 24680,
    }
    result = processor["merge_verified_metadata"](primary, [primary, netease])
    assert result["_netease_song_id"] == 24680


def test_verified_lookup_drops_untrusted_provider_result(processor):
    candidates = [{"title": "Same Song", "artist": "Exact Artist", "query": "Exact Artist Same Song"}]
    original_itunes = processor["search_itunes"]
    original_netease = processor["search_netease"]
    original_kuwo = processor["search_kuwo"]
    try:
        processor["search_itunes"] = lambda _candidates, fast=False: {
            "title": "Same Song",
            "artist": "Different Artist",
            "album": "Popular But Wrong Album",
            "track_count": 20,
            "source": "wrong iTunes test",
        }
        processor["search_netease"] = lambda _candidates, fast=False: None
        processor["search_kuwo"] = lambda _candidates: None
        result = processor["lookup_verified_metadata"](candidates)
    finally:
        processor["search_itunes"] = original_itunes
        processor["search_netease"] = original_netease
        processor["search_kuwo"] = original_kuwo

    assert result is None


def test_manual_original_artist_stays_in_cover_lookup(processor):
    candidates = processor["parse_candidates"]("input.m4a", "Original Artist - Same Song")
    originals = processor["with_cover_original_artist_candidates"](
        candidates,
        processor["original_song_candidates"](candidates),
        "Cover Singer",
    )
    assert any(
        item["artist"] == "Original Artist" and item["title"] == "Same Song"
        for item in originals
    )


def test_artwork_and_credit_lookups_reject_identity_mismatches(processor):
    original_http_json = processor["http_json"]
    try:
        processor["http_json"] = lambda _url: {
            "results": [{
                "trackName": "Same Song",
                "artistName": "Different Artist",
                "collectionName": "Wrong Album",
                "artworkUrl100": "https://example.invalid/wrong.jpg",
            }]
        }
        artwork = processor["find_itunes_artwork"](
            {"title": "Same Song", "artist": "Exact Artist", "album": "Official Album"},
            [],
        )
        assert artwork is None

        processor["http_json"] = lambda _url: {
            "recordings": [{
                "id": "wrong-recording",
                "title": "Same Song",
                "artist-credit": [{"name": "Different Artist"}],
            }]
        }
        assert processor["search_musicbrainz"]({"title": "Same Song", "artist": "Exact Artist"}) == {}
    finally:
        processor["http_json"] = original_http_json


def test_explicit_lyric_credit_parser(processor):
    credits = processor["extract_lyric_credits"](
        "[00:01.00]\u4f5c\u8bcd\uff1aLyric Writer\n"
        "[00:02.00]\u4f5c\u66f2\uff1aComposer Name\n"
        "[00:03.00]\u7f16\u66f2\uff1aArranger Name\n"
        "[00:04.00]A normal lyric line"
    )
    assert credits == {
        "lyricist": "Lyric Writer",
        "composer": "Composer Name",
        "arranger": "Arranger Name",
    }


def test_cover_lyrics_can_supply_explicit_original_credits(processor):
    processor["_NETEASE_SONG_SEARCH_CACHE"].clear()
    processor["_NETEASE_LYRIC_RAW_CACHE"].clear()
    original_search = processor["search_netease_song_rows"]
    original_fetch = processor["fetch_netease_lyric_raw"]
    try:
        processor["search_netease_song_rows"] = lambda _term, limit=10: [
            {"id": 999, "name": "Same Song", "artists": [{"name": "Different Singer"}]},
            {"id": 123, "name": "Same Song (Live)", "artists": [{"name": "Cover Singer"}]},
        ]
        matching_lyrics = (
            "\u8fd9是正确的第一句歌词\n这是正确的第二句歌词\n"
            "\u8fd9是正确的第三句歌词\n这是正确的第四句歌词\n这是正确的第五句歌词"
        )
        wrong_lyrics = (
            "\u5b8c全无关的其他文字一\n完全无关的其他文字二\n"
            "\u5b8c全无关的其他文字三\n完全无关的其他文字四\n"
            "\u5b8c全无关的其他文字五"
        )
        processor["fetch_netease_lyric_raw"] = lambda song_id: (
            "[00:00.00]\u4f5c\u8bcd\uff1aOriginal Writer\n"
            "[00:01.00]\u4f5c\u66f2\uff1aOriginal Composer\n" + matching_lyrics
            if song_id == 123 else
            "[00:00.00]\u4f5c\u8bcd\uff1aWrong Writer\n"
            "[00:01.00]\u4f5c\u66f2\uff1aWrong Composer\n" + wrong_lyrics
        )
        credits = processor["find_netease_lyric_credits"]({
            "title": "Same Song",
            "artist": "Original Singer",
        }, reference_lyrics=matching_lyrics)
    finally:
        processor["search_netease_song_rows"] = original_search
        processor["fetch_netease_lyric_raw"] = original_fetch
    assert credits["lyricist"] == "Original Writer"
    assert credits["composer"] == "Original Composer"


def test_credit_selection_prefers_original_album_and_complete_set(processor):
    original_search = processor["search_netease_song_rows"]
    original_fetch = processor["fetch_netease_lyric_raw"]
    lyric_body = "\n".join([
        "[00:10.00]\u542c\u6d77\u54ed\u7684\u58f0\u97f3",
        "[00:20.00]\u5199\u4fe1\u544a\u8bc9\u6211\u4eca\u5929\u6d77\u662f\u4ec0\u4e48\u989c\u8272",
        "[00:30.00]\u591c\u591c\u966a\u7740\u4f60\u7684\u6d77\u5fc3\u60c5\u53c8\u5982\u4f55",
        "[00:40.00]\u7070\u8272\u662f\u4e0d\u60f3\u8bf4\u84dd\u8272\u662f\u5fe7\u90c1",
        "[00:50.00]\u800c\u6f02\u6cca\u7684\u4f60\u72c2\u6d6a\u7684\u5fc3\u505c\u5728\u54ea\u91cc",
    ])
    rows = [
        {"id": 1, "name": "\u542c\u6d77", "artists": [{"name": "\u5f20\u60e0\u59b9"}], "album": {"name": "Later Compilation"}},
        {"id": 2, "name": "\u542c\u6d77", "artists": [{"name": "\u5f20\u60e0\u59b9"}], "album": {"name": "BAD BOY"}},
    ]
    raw = {
        1: "[00:00.00]\u4f5c\u66f2\uff1aComposer\n" + lyric_body,
        2: (
            "[00:00.00]\u4f5c\u8bcd\uff1aLyricist\n"
            "[00:01.00]\u4f5c\u66f2\uff1aComposer\n"
            "[00:02.00]\u7f16\u66f2\uff1aArranger\n" + lyric_body
        ),
    }
    try:
        processor["search_netease_song_rows"] = lambda _term, limit=10: rows
        processor["fetch_netease_lyric_raw"] = lambda song_id: raw[song_id]
        credits = processor["find_netease_lyric_credits"]({
            "title": "\u542c\u6d77",
            "artist": "\u5f20\u60e0\u59b9",
            "album": "BAD BOY",
        })
    finally:
        processor["search_netease_song_rows"] = original_search
        processor["fetch_netease_lyric_raw"] = original_fetch
    assert credits == {
        "lyricist": "Lyricist",
        "composer": "Composer",
        "arranger": "Arranger",
    }


def test_full_preview_contains_all_editable_metadata(processor, source):
    fast_modes = []

    def fake_search(_candidates, fast=False):
        fast_modes.append(fast)
        return {
            "title": "Preview Song",
            "artist": "Preview Artist",
            "album": "Preview Album",
            "album_artist": "Preview Artist",
            "year": "2001",
            "release_date": "2001-02-03",
            "genre": "Pop",
            "track_number": 2,
            "track_count": 8,
            "disc_number": 1,
            "disc_count": 2,
            "source": "test search",
        }

    processor["search_netease"] = fake_search
    processor["search_itunes"] = lambda _candidates, fast=False: None
    processor["search_kuwo"] = lambda _candidates: None
    processor["search_musicbrainz"] = lambda _meta: {
        "composer": "Preview Composer",
        "lyricist": "Preview Lyricist",
        "arranger": "Preview Arranger",
        "isrc": "PREVIEWISRC",
        "musicbrainz_recording_id": "preview-recording-id",
    }
    processor["fill_known_track_credits"] = lambda meta: meta
    processor["find_lyrics"] = lambda *_args, **_kwargs: "Preview lyric"
    processor["enrich_artwork"] = lambda meta, _candidates: dict(meta, artwork_url="https://example.invalid/cover.jpg")
    processor["preview_artwork"] = lambda _meta: ("image/jpeg", "YWJj")

    old_argv = sys.argv
    sys.argv = ["processor", str(source), "Preview Artist - Preview Song", "", "--force-studio", "__NO_COVER_ARTIST__", "--preview-full"]
    try:
        with contextlib.redirect_stdout(io.StringIO()) as output:
            processor["main"]()
    finally:
        sys.argv = old_argv
    payload = json.loads(output.getvalue().strip())
    assert payload["title"] == "Preview Song"
    assert payload["composer"] == "Preview Composer"
    assert payload["lyricist"] == "Preview Lyricist"
    assert payload["arranger"] == "Preview Arranger"
    assert payload["isrc"] == "PREVIEWISRC"
    assert payload["musicbrainz_recording_id"] == "preview-recording-id"
    assert payload["lyrics"] == "Preview lyric\n\n\u4f5c\u8bcd\uff1aPreview Lyricist"
    assert payload["artwork_data"] == "YWJj"
    assert fast_modes == [True]


def test_auto_detected_cover_inherits_top_ranked_original(processor, source):
    write_sidecar(source, "generic-cover", "")
    saved = {name: processor[name] for name in (
        "search_netease", "search_itunes", "search_kuwo", "find_lyrics",
        "find_netease_lyric_credits", "enrich_artwork", "preview_artwork",
        "search_itunes_release_refinement", "enrich_live_cover_artwork",
    )}
    title = "\u523b\u5728\u6211\u5fc3\u5e95\u7684\u540d\u5b57"
    original = "\u5362\u5e7f\u4ef2"
    performer = "\u6c64\u4ee4\u5c71 & Tyson Yoshi"
    try:
        processor["search_netease"] = lambda _candidates, fast=False: {
            "title": title,
            "artist": original,
            "album": title,
            "album_artist": original,
            "year": "2020",
            "release_date": "2020-08-25",
            "track_number": 1,
            "track_count": 1,
            "disc_number": 1,
            "disc_count": 1,
            "_provider": "netease",
            "_search_rank": 0,
            "source": "NetEase test",
        }
        processor["search_itunes"] = lambda *_args, **_kwargs: None
        processor["search_kuwo"] = lambda *_args, **_kwargs: None
        lyric_modes = []
        def fake_lyrics(meta, **kwargs):
            lyric_modes.append(kwargs.get("prefer_live"))
            return "Original lyric line" if meta.get("artist") == original else ""
        processor["find_lyrics"] = fake_lyrics
        processor["find_netease_lyric_credits"] = lambda *_args, **_kwargs: {
            "composer": "Original Composer",
            "lyricist": "Original Lyricist",
            "arranger": "Original Arranger",
        }
        processor["enrich_artwork"] = lambda meta, _candidates: (
            meta if meta.get("artwork_url") else
            dict(meta, artwork_url="https://example.invalid/original.jpg")
        )
        processor["search_itunes_release_refinement"] = lambda _meta: {
            "album": title + " (Official) - Single",
            "genre": "Mandopop",
            "release_date": "2020-08-25",
            "year": "2020",
            "track_number": 1,
            "track_count": 1,
            "disc_number": 1,
            "disc_count": 1,
            "artwork_url": "https://example.invalid/official.jpg",
            "source": "iTunes release corroboration test",
        }
        processor["enrich_live_cover_artwork"] = lambda meta, *_args, **_kwargs: meta
        processor["preview_artwork"] = lambda _meta: ("", "")

        old_argv = sys.argv
        sys.argv = [
            "processor", str(source), f"title: {title}\nartist: {performer}", "",
            "--force-live", "__NO_COVER_ARTIST__", "--preview-full",
            "--fast-probe", "__AUTO_COVER_DETECT__",
        ]
        try:
            with contextlib.redirect_stdout(io.StringIO()) as output:
                processor["main"]()
        finally:
            sys.argv = old_argv
    finally:
        for name, value in saved.items():
            processor[name] = value

    payload = json.loads(output.getvalue().strip())
    assert payload["title"] == title + " (Live)"
    assert payload["artist"] == performer
    assert payload["original_artist"] == original
    assert payload["album"] == title + " (Official) - Single"
    assert payload["original_album"] == title + " (Official) - Single"
    assert payload["album_artist"] == original
    assert payload["genre"] == "Mandopop"
    assert payload["year"] == "2020"
    assert payload["composer"] == "Original Composer"
    assert payload["lyricist"] == "Original Lyricist"
    assert payload["arranger"] == "Original Arranger"
    assert payload["lyrics"].endswith("\u4f5c\u8bcd\uff1aOriginal Lyricist")
    assert payload["artwork_url"] == "https://example.invalid/official.jpg"
    assert payload["detected_cover"] is True
    assert lyric_modes == [False]


def test_explicit_live_cover_recovers_original_release_and_live_artwork(processor, source):
    write_sidecar(source, "explicit-live-cover", "")
    saved = {name: processor[name] for name in (
        "search_netease", "search_itunes", "search_kuwo", "find_lyrics",
        "find_netease_lyric_credits", "enrich_artwork", "preview_artwork",
        "search_itunes_release_refinement", "enrich_live_cover_artwork",
    )}
    title = "\u503e\u57ce"
    performer = "\u9648\u5955\u8fc5"
    original = "\u8bb8\u7f8e\u9759"
    live_artwork = "https://example.invalid/eason-live.jpg"
    try:
        def fake_netease(candidates, fast=False):
            artists = processor["explicit_candidate_artists"](candidates)
            if any(processor["strict_artist_matches"](performer, artist) for artist in artists):
                return {
                    "title": title + " (Live)",
                    "artist": performer,
                    "album": "Concert YY",
                    "album_artist": performer,
                    "year": "2012",
                    "release_date": "2012",
                    "track_number": 1,
                    "track_count": 20,
                    "disc_number": 1,
                    "disc_count": 2,
                    "artwork_url": live_artwork,
                    "_provider": "netease",
                    "_search_rank": 0,
                    "source": "verified live performer release",
                }
            return {
                "title": title,
                "artist": original,
                "album": "Recent Compilation",
                "album_artist": original,
                "year": "2023",
                "release_date": "2023-01-01",
                "track_number": 1,
                "track_count": 22,
                "disc_number": 1,
                "disc_count": 1,
                "artwork_url": "https://example.invalid/compilation.jpg",
                "_provider": "netease",
                "_search_rank": 1,
                "source": "exact lower-rank original",
            }

        processor["search_netease"] = fake_netease
        processor["search_itunes"] = lambda *_args, **_kwargs: None
        processor["search_kuwo"] = lambda *_args, **_kwargs: None
        processor["find_lyrics"] = lambda meta, **_kwargs: (
            "Original lyric line" if meta.get("artist") == original else ""
        )
        processor["find_netease_lyric_credits"] = lambda *_args, **_kwargs: {
            "composer": "\u9648\u4f73\u660e",
            "lyricist": "\u9ec4\u4f1f\u6587",
            "arranger": "\u5434\u5e86\u9686",
        }
        processor["enrich_artwork"] = lambda meta, _candidates: meta
        processor["search_itunes_release_refinement"] = lambda _meta: {
            "album": "\u9759\u542c\u7cbe\u5f69\u5341\u4e09\u9996",
            "album_artist": original,
            "genre": "\u56fd\u8bed\u6d41\u884c\u4e50",
            "release_date": "1997-01-01",
            "year": "1997",
            "track_number": 2,
            "track_count": 13,
            "disc_number": 1,
            "disc_count": 1,
            "artwork_url": "https://example.invalid/original.jpg",
            "source": "official original release refinement",
        }
        processor["enrich_live_cover_artwork"] = lambda meta, *_args, **_kwargs: meta
        processor["preview_artwork"] = lambda _meta: ("", "")

        old_argv = sys.argv
        sys.argv = [
            "processor", str(source),
            f"title: {title}\nartist: {performer}\n\u89c6\u9891\u6807\u9898: {performer}\u300a{title}\u300b\u7ffb\u5531\u73b0\u573a",
            "", "--force-live", "__NO_COVER_ARTIST__", "--preview-full",
            "--fast-probe", "__AUTO_COVER_DETECT__",
        ]
        try:
            with contextlib.redirect_stdout(io.StringIO()) as output:
                processor["main"]()
        finally:
            sys.argv = old_argv
    finally:
        for name, value in saved.items():
            processor[name] = value

    payload = json.loads(output.getvalue().strip())
    assert payload["title"] == title + " (Live)"
    assert payload["artist"] == performer
    assert payload["original_artist"] == original
    assert payload["album"] == "\u9759\u542c\u7cbe\u5f69\u5341\u4e09\u9996"
    assert payload["album_artist"] == original
    assert payload["year"] == "1997"
    assert payload["track_number"] == 2
    assert payload["track_count"] == 13
    assert payload["composer"] == "\u9648\u4f73\u660e"
    assert payload["lyricist"] == "\u9ec4\u4f1f\u6587"
    assert payload["arranger"] == "\u5434\u5e86\u9686"
    assert payload["lyrics"] == "Original lyric line\n\n\u4f5c\u8bcd\uff1a\u9ec4\u4f1f\u6587"
    assert payload["artwork_url"] == live_artwork
    assert payload["detected_cover"] is True


def test_auto_detect_checks_current_performer_before_title_only(processor, source):
    write_sidecar(source, "same-performer-live", "")
    saved = {name: processor[name] for name in (
        "search_netease", "search_itunes", "search_kuwo", "find_lyrics",
        "find_netease_lyric_credits", "enrich_artwork", "preview_artwork",
        "search_itunes_release_refinement", "enrich_live_cover_artwork",
    )}
    calls = []
    release_calls = []
    try:
        def fake_netease(candidates, fast=False):
            artists = processor["explicit_candidate_artists"](candidates)
            calls.append(artists)
            if any(processor["strict_artist_matches"]("\u5468\u6770\u4f26", artist) for artist in artists):
                return {
                    "title": "\u5b89\u9759",
                    "artist": "\u5468\u6770\u4f26",
                    "album": "\u8303\u7279\u897f",
                    "album_artist": "\u5468\u6770\u4f26",
                    "year": "2001",
                    "release_date": "2001-09-14",
                    "track_number": 10,
                    "track_count": 10,
                    "disc_number": 1,
                    "disc_count": 1,
                    "_provider": "netease",
                    "_search_rank": 0,
                    "source": "exact performer test",
                }
            return {
                "title": "\u5b89\u9759",
                "artist": "\u63d0\u7c73FM",
                "album": "\u5b89\u9759",
                "album_artist": "\u63d0\u7c73FM",
                "year": "2026",
                "release_date": "2026",
                "track_number": 1,
                "track_count": 1,
                "disc_number": 1,
                "disc_count": 1,
                "_provider": "netease",
                "_search_rank": 1,
                "source": "wrong title-only test",
            }

        processor["search_netease"] = fake_netease
        processor["search_itunes"] = lambda *_args, **_kwargs: None
        processor["search_kuwo"] = lambda *_args, **_kwargs: None
        processor["find_lyrics"] = lambda *_args, **_kwargs: "Correct lyric line"
        processor["find_netease_lyric_credits"] = lambda *_args, **_kwargs: {}
        processor["enrich_artwork"] = lambda meta, _candidates: dict(meta, artwork_url="https://example.invalid/fantasy.jpg")
        processor["search_itunes_release_refinement"] = lambda _meta: release_calls.append(True) or {
            "album": "\u8303\u7279\u897f",
            "year": "2001",
            "release_date": "2001-09-14",
            "track_number": 10,
            "track_count": 10,
            "disc_number": 1,
            "disc_count": 1,
            "source": "official release refinement test",
        }
        processor["enrich_live_cover_artwork"] = lambda meta, *_args, **_kwargs: meta
        processor["preview_artwork"] = lambda _meta: ("", "")

        old_argv = sys.argv
        sys.argv = [
            "processor", str(source), "title: \u5b89\u9759\nartist: \u5468\u6770\u4f26", "",
            "--force-live", "__NO_COVER_ARTIST__", "--preview-full",
            "--fast-probe", "__AUTO_COVER_DETECT__",
        ]
        try:
            with contextlib.redirect_stdout(io.StringIO()) as output:
                processor["main"]()
        finally:
            sys.argv = old_argv
    finally:
        for name, value in saved.items():
            processor[name] = value

    payload = json.loads(output.getvalue().strip())
    assert payload["artist"] == "\u5468\u6770\u4f26"
    assert payload["album"] == "\u8303\u7279\u897f", payload
    assert payload["year"] == "2001"
    assert payload["detected_cover"] is False
    assert payload["original_artist"] == ""
    assert any(artists for artists in calls)
    assert any(not artists for artists in calls)
    assert release_calls == []


def test_published_live_cover_still_inherits_original_recording(processor, source):
    write_sidecar(source, "published-live-cover", "")
    saved = {name: processor[name] for name in (
        "search_netease", "search_itunes", "search_kuwo", "find_lyrics",
        "find_netease_lyric_credits", "enrich_artwork", "preview_artwork",
        "search_itunes_release_refinement", "enrich_live_cover_artwork",
    )}
    try:
        def fake_netease(candidates, fast=False):
            artists = processor["explicit_candidate_artists"](candidates)
            if artists:
                return {
                    "title": "\u627e\u81ea\u5df1 (Live)",
                    "artist": "\u5468\u6770\u4f26",
                    "album": "The One Live",
                    "album_artist": "\u5468\u6770\u4f26",
                    "year": "2002",
                    "release_date": "2002",
                    "track_number": 1,
                    "track_count": 9,
                    "disc_number": 2,
                    "disc_count": 2,
                    "_provider": "netease",
                    "_search_rank": 0,
                    "source": "published cover test",
                }
            return {
                "title": "\u627e\u81ea\u5df1",
                "artist": "\u9676\u5586",
                "album": "I'm OK",
                "album_artist": "\u9676\u5586",
                "year": "1999",
                "release_date": "1999-12-10",
                "track_number": 1,
                "track_count": 12,
                "disc_number": 1,
                "disc_count": 1,
                "_provider": "netease",
                "_search_rank": 0,
                "source": "popular original test",
            }

        processor["search_netease"] = fake_netease
        processor["search_itunes"] = lambda *_args, **_kwargs: None
        processor["search_kuwo"] = lambda *_args, **_kwargs: None
        processor["find_lyrics"] = lambda *_args, **_kwargs: "Correct original lyric"
        processor["find_netease_lyric_credits"] = lambda *_args, **_kwargs: {}
        processor["enrich_artwork"] = lambda meta, _candidates: dict(meta, artwork_url="https://example.invalid/im-ok.jpg")
        processor["search_itunes_release_refinement"] = lambda _meta: {
            "album": "I'm OK",
            "year": "1999",
            "release_date": "1999-12-10",
            "track_number": 1,
            "track_count": 12,
            "disc_number": 1,
            "disc_count": 1,
            "source": "original release refinement test",
        }
        processor["enrich_live_cover_artwork"] = lambda meta, *_args, **_kwargs: meta
        processor["preview_artwork"] = lambda _meta: ("", "")

        old_argv = sys.argv
        sys.argv = [
            "processor", str(source), "title: \u627e\u81ea\u5df1\nartist: \u5468\u6770\u4f26", "",
            "--force-live", "__NO_COVER_ARTIST__", "--preview-full",
            "--fast-probe", "__AUTO_COVER_DETECT__",
        ]
        try:
            with contextlib.redirect_stdout(io.StringIO()) as output:
                processor["main"]()
        finally:
            sys.argv = old_argv
    finally:
        for name, value in saved.items():
            processor[name] = value

    payload = json.loads(output.getvalue().strip())
    assert payload["artist"] == "\u5468\u6770\u4f26"
    assert payload["original_artist"] == "\u9676\u5586"
    assert payload["album"] == "I'm OK"
    assert payload["year"] == "1999"
    assert payload["detected_cover"] is True


def test_preview_survives_optional_enrichment_failures(processor, source):
    saved = {name: processor[name] for name in (
        "search_netease", "search_itunes", "search_kuwo", "find_lyrics",
        "find_netease_lyric_credits", "enrich_artwork",
        "enrich_live_cover_artwork", "preview_artwork",
        "search_itunes_release_refinement",
    )}
    title = "\u6d4b\u8bd5\u6b4c\u66f2"
    artist = "\u6d4b\u8bd5\u6b4c\u624b"

    def unavailable(*_args, **_kwargs):
        raise RuntimeError("provider unavailable")

    try:
        processor["search_netease"] = lambda _candidates, fast=False: {
            "title": title,
            "artist": artist,
            "album": "Verified Album",
            "album_artist": artist,
            "year": "2019",
            "release_date": "2019",
            "track_number": 1,
            "track_count": 1,
            "disc_number": 1,
            "disc_count": 1,
            "_provider": "netease",
            "source": "NetEase test",
        }
        processor["search_itunes"] = lambda *_args, **_kwargs: None
        processor["search_kuwo"] = lambda *_args, **_kwargs: None
        processor["find_lyrics"] = unavailable
        processor["find_netease_lyric_credits"] = unavailable
        processor["enrich_artwork"] = unavailable
        processor["enrich_live_cover_artwork"] = unavailable
        processor["search_itunes_release_refinement"] = unavailable
        processor["preview_artwork"] = lambda _meta: ("", "")

        old_argv = sys.argv
        sys.argv = [
            "processor", str(source), f"title: {title}\nartist: {artist}", "",
            "--force-studio", "__NO_COVER_ARTIST__", "--preview-full", "--fast-probe",
        ]
        try:
            with contextlib.redirect_stdout(io.StringIO()) as output:
                processor["main"]()
        finally:
            sys.argv = old_argv
    finally:
        for name, value in saved.items():
            processor[name] = value

    payload = json.loads(output.getvalue().strip())
    assert payload["title"] == title
    assert payload["artist"] == artist
    assert payload["album"] == "Verified Album"
    assert payload["year"] == "2019"
    assert payload["lyrics"] == ""
    assert "lookup unavailable" in payload["source"]


def test_user_overrides_are_authoritative(processor):
    automatic = {
        "title": "Automatic Song",
        "artist": "Automatic Artist",
        "album": "Automatic Album",
        "album_artist": "Automatic Artist",
        "year": "2001",
        "release_date": "2001-02-03",
        "genre": "Automatic Genre",
        "composer": "Automatic Composer",
        "lyricist": "Automatic Lyricist",
        "arranger": "Automatic Arranger",
        "lyrics": "Automatic lyric",
        "track_number": 1,
        "track_count": 1,
        "disc_number": 1,
        "disc_count": 1,
        "artwork_url": "https://example.invalid/automatic.jpg",
    }
    overrides = {
        "title": "Manual Song",
        "artist": "Manual Artist",
        "album": "Manual Album",
        "album_artist": "Manual Album Artist",
        "year": "2099",
        "release_date": "2099-01-02",
        "genre": "Manual Genre",
        "composer": "Manual Composer",
        "lyricist": "Manual Lyricist",
        "arranger": "Manual Arranger",
        "isrc": "MANUALISRC",
        "musicbrainz_recording_id": "manual-recording-id",
        "lyrics": "Manual lyric",
        "track_number": "7",
        "track_count": "8",
        "disc_number": "2",
        "disc_count": "3",
        "artwork_mode": "none",
        "artwork_file": "",
        "artwork_url": "https://example.invalid/ignored.jpg",
    }
    result = processor["apply_metadata_overrides"](automatic, overrides)
    for key in ("title", "artist", "album", "album_artist", "genre", "composer", "lyricist", "arranger", "isrc", "musicbrainz_recording_id", "lyrics"):
        assert result[key] == overrides[key]
    assert result["year"] == "2099"
    assert result["release_date"] == "2099-01-02"
    assert result["track_number"] == 7
    assert result["track_count"] == 8
    assert result["disc_number"] == 2
    assert result["disc_count"] == 3
    assert result["artwork_mode"] == "none"
    assert "artwork_url" not in result


def test_override_file_supports_long_lyrics(processor, source):
    lyrics = "long lyric line\n" * 4000
    override_file = source.parent / "metadata-overrides.json"
    override_file.write_text(
        json.dumps({"title": "Long Lyrics", "lyrics": lyrics}),
        encoding="utf-8",
    )
    parsed = processor["parse_metadata_overrides"](
        ["__METADATA_OVERRIDES_FILE=" + str(override_file)]
    )
    assert parsed["title"] == "Long Lyrics"
    assert parsed["lyrics"] == lyrics


def test_reviewed_preview_is_reused_without_network(processor, source, auto_add):
    captured = {}
    preview_file = source.parent / "reviewed-preview.json"
    override_file = source.parent / "reviewed-preview-overrides.json"
    preview_file.write_text(
        json.dumps({
            "title": "Cached Song",
            "artist": "Cached Artist",
            "album": "Cached Album",
            "album_artist": "Cached Artist",
            "year": "2001",
            "release_date": "2001-01-02",
            "composer": "Cached Composer",
            "lyricist": "Cached Lyricist",
            "arranger": "Cached Arranger",
            "lyrics": "Cached lyric",
            "track_number": 1,
            "track_count": 1,
            "disc_number": 1,
            "disc_count": 1,
            "source": "Reviewed preview cache",
            "online_match": True,
        }),
        encoding="utf-8",
    )
    override_file.write_text(
        json.dumps({
            "title": "Manual Cached Song",
            "artist": "Manual Cached Artist",
            "album": "Manual Cached Album",
            "album_artist": "Manual Cached Artist",
            "year": "2002",
            "release_date": "2002",
            "genre": "",
            "composer": "Cached Composer",
            "lyricist": "Cached Lyricist",
            "arranger": "Cached Arranger",
            "isrc": "",
            "musicbrainz_recording_id": "",
            "track_number": "1",
            "track_count": "1",
            "disc_number": "1",
            "disc_count": "1",
            "lyrics": "Cached lyric",
            "artwork_mode": "none",
        }),
        encoding="utf-8",
    )

    def unexpected(*_args, **_kwargs):
        raise AssertionError("reviewed preview should not start another network lookup")

    def fake_convert(input_path, output_path, force_encode=False):
        shutil.copy2(input_path, output_path)
        return "copied"

    def fake_tag(_path, meta):
        captured["meta"] = dict(meta)

    processor["lookup_verified_metadata"] = unexpected
    processor["search_musicbrainz"] = unexpected
    processor["find_lyrics"] = unexpected
    processor["enrich_artwork"] = unexpected
    processor["convert_audio"] = fake_convert
    processor["tag_file"] = fake_tag

    old_argv = sys.argv
    sys.argv = [
        "processor", str(source), "ignored", str(auto_add), "--force-studio",
        "__NO_COVER_ARTIST__",
        "__PRECOMPUTED_METADATA_FILE=" + str(preview_file),
        "__METADATA_OVERRIDES_FILE=" + str(override_file),
    ]
    try:
        with contextlib.redirect_stdout(io.StringIO()) as output:
            processor["main"]()
    finally:
        sys.argv = old_argv
    result = json.loads(output.getvalue().strip())
    assert result["reused_preview"] is True
    assert result["title"] == "Manual Cached Song"
    assert result["artist"] == "Manual Cached Artist"
    assert captured["meta"]["composer"] == "Cached Composer"
    assert captured["meta"]["lyrics"] == "Cached lyric\n\n\u4f5c\u8bcd\uff1aCached Lyricist"


def test_import_filename_and_temp_path_ignore_multiline_metadata(processor):
    unsafe = "\u756a\u8304\u82b1 \u89c6\u9891\u6807\u9898: \u756a\u8304\u82b1\n\u4e0a\u4f20\u8005: _\u7f2a\u65afMuse"
    clean = processor["safe_filename"](unsafe, max_length=80)
    assert "\n" not in clean
    assert "\r" not in clean
    assert len(clean) <= 80
    output = processor["import_output_name"](
        {"title": unsafe, "artist": "Unknown Artist"}, "0123456789abcdef"
    )
    assert output.endswith("[01234567].m4a")
    assert "\n" not in output
    assert "\r" not in output


def test_generic_cover_keeps_original_artwork(processor, source, auto_add):
    captured = {}

    def fake_search(_candidates, fast=False):
        return {
            "title": "Same Song",
            "artist": "Original Artist",
            "album": "Original Album",
            "album_artist": "Original Artist",
            "year": "2001",
            "release_date": "2001",
            "track_number": 1,
            "track_count": 1,
            "disc_number": 1,
            "disc_count": 1,
            "lyricist": "Original Writer",
            "source": "test search",
        }

    def fake_artwork(meta, _candidates):
        if meta.get("artwork_url"):
            return meta
        assert meta["artist"] == "Original Artist"
        meta = dict(meta)
        meta["artwork_url"] = "https://example.invalid/original.jpg"
        return meta

    def fake_convert(input_path, output_path, force_encode=False):
        shutil.copy2(input_path, output_path)
        return "copied"

    def fake_tag(_path, meta):
        captured["meta"] = dict(meta)

    def fake_lyrics(meta, *args, **kwargs):
        captured.setdefault("lyric_artists", []).append(meta["artist"])
        return "Fallback lyric" if not meta["artist"] else ""

    processor["search_netease"] = fake_search
    processor["search_itunes"] = lambda _candidates, fast=False: None
    processor["search_kuwo"] = lambda _candidates: None
    processor["search_musicbrainz"] = lambda _meta: {}
    processor["enrich_artwork"] = fake_artwork
    processor["find_lyrics"] = fake_lyrics
    processor["find_netease_lyric_credits"] = lambda *_args, **_kwargs: {}
    processor["convert_audio"] = fake_convert
    processor["tag_file"] = fake_tag

    old_argv = sys.argv
    sys.argv = ["processor", str(source), "Cover Singer - Same Song", str(auto_add), "--force-studio", "Cover Singer Cover"]
    try:
        with contextlib.redirect_stdout(io.StringIO()) as output:
            processor["main"]()
    finally:
        sys.argv = old_argv
    result = json.loads(output.getvalue().strip())
    assert result["artist"] == "Cover Singer"
    assert result["album"] == "Original Album"
    assert captured["meta"]["album_artist"] == "Original Artist"
    assert "Cover" not in result["album"]
    assert captured["meta"]["artwork_url"] == "https://example.invalid/original.jpg"
    assert captured["lyric_artists"] == ["Original Artist", ""]
    assert captured["meta"]["lyrics"] == "Fallback lyric\n\n\u4f5c\u8bcd\uff1aOriginal Writer"


def main():
    processor = load_processor()
    old_state_root = os.environ.get("APPLE_MUSIC_AUTO_IMPORT_STATE_ROOT")
    with tempfile.TemporaryDirectory() as directory:
        temp = Path(directory)
        os.environ["APPLE_MUSIC_AUTO_IMPORT_STATE_ROOT"] = str(temp / "state")
        source = temp / "input.m4a"
        source.write_bytes(b"test-audio")
        write_sidecar(source, "generic-cover", "")
        test_cover_title_context(processor, source)
        test_song_performer_at_show_title_is_split_before_lookup(processor, source)
        test_tour_context_is_removed_from_current_performer(processor, source)
        test_artist_after_book_title_is_used_by_all_parsers(processor, source)
        test_windows_chinese_mapping_keeps_catalog_artist_identity(processor)
        test_bilingual_cover_performer_and_matching_title_pair(processor)
        test_real_performer_original_comparisons(processor)
        test_slash_separated_hint_credits(processor)
        test_structured_identity_ignores_video_title_noise(processor, source)
        test_live_cover_preserves_original_release(processor)
        test_known_live_mapping(processor, source)
        test_visible_lyricist(processor)
        test_lyric_cleanup_removes_indented_timestamps_and_original_artist_label(processor)
        test_lyric_cleanup_keeps_only_body_and_visible_lyricist(processor)
        test_lyric_cleanup_removes_artwork_management_and_project_footer(processor)
        test_lyric_cleanup_removes_music_and_lyric_editor_credits(processor)
        test_lyric_cleanup_joins_timed_cjk_fragments_into_natural_lines(processor)
        test_usable_lyrics_accepts_non_cjk_body(processor)
        test_usable_lyrics_rejects_translation_for_cjk_title(processor)
        test_old_translation_cache_is_ignored_for_cjk_title(processor)
        test_preview_payload_cannot_expose_translation_for_cjk_title(processor)
        test_verified_netease_song_id_supplies_lyrics_without_research(processor)
        test_verified_netease_song_id_supplies_credits_without_research(processor)
        test_lyrics_fall_back_when_preferred_provider_raises(processor)
        test_persistent_lyric_cache_survives_provider_outage(processor)
        test_verified_cache_keeps_lyrics_that_do_not_contain_title(processor)
        test_main_thread_restores_cached_lyrics_and_credits(processor)
        test_netease_lyric_fetch_retries_transient_failure(processor)
        test_netease_lyrics_keeps_a_strict_title_only_fallback(processor)
        test_lyric_title_check_accepts_traditional_title_with_simplified_lyrics(processor)
        test_lyric_search_queries_matching_simplified_identity(processor)
        test_lrclib_prefers_original_script_over_english_translation(processor)
        test_lrclib_rejects_translation_only_for_cjk_title(processor)
        test_lrclib_uses_original_script_synced_lyrics_when_plain_is_translated(processor)
        test_studio_lyric_lookup_does_not_prefer_live_credit_block(processor)
        test_netease_artwork_host_and_content_signature(processor)
        test_identity_gate_rejects_same_title_wrong_artist_and_version(processor)
        test_traditional_and_simplified_identity_match(processor)
        test_itunes_release_refinement_accepts_traditional_exact_release(processor)
        test_title_only_cjk_uses_top_ranked_original(processor)
        test_explicit_cjk_identity_merges_itunes_release_precision(processor)
        test_explicit_cover_accepts_exact_lower_rank_title_only_original(processor)
        test_current_performer_candidates_preserve_live_search_context(processor)
        test_title_only_cjk_does_not_accept_second_ranked_namesake(processor)
        test_title_only_cjk_rejects_uncorroborated_lower_rank_namesake(processor)
        test_verified_lookup_prefers_corrobated_full_release(processor)
        test_verified_merge_preserves_netease_song_id(processor)
        test_verified_lookup_drops_untrusted_provider_result(processor)
        test_manual_original_artist_stays_in_cover_lookup(processor)
        test_artwork_and_credit_lookups_reject_identity_mismatches(processor)
        test_explicit_lyric_credit_parser(processor)
        test_cover_lyrics_can_supply_explicit_original_credits(processor)
        test_credit_selection_prefers_original_album_and_complete_set(processor)
        test_full_preview_contains_all_editable_metadata(processor, source)
        test_auto_detected_cover_inherits_top_ranked_original(processor, source)
        test_explicit_live_cover_recovers_original_release_and_live_artwork(processor, source)
        test_auto_detect_checks_current_performer_before_title_only(processor, source)
        test_published_live_cover_still_inherits_original_recording(processor, source)
        test_preview_survives_optional_enrichment_failures(processor, source)
        test_user_overrides_are_authoritative(processor)
        test_override_file_supports_long_lyrics(processor, source)
        write_sidecar(source, "generic-cover", "")
        auto_add = temp / "auto-add"
        auto_add.mkdir()
        test_generic_cover_keeps_original_artwork(processor, source, auto_add)
        cached_auto_add = temp / "cached-auto-add"
        cached_auto_add.mkdir()
        test_reviewed_preview_is_reused_without_network(processor, source, cached_auto_add)
    if old_state_root is None:
        os.environ.pop("APPLE_MUSIC_AUTO_IMPORT_STATE_ROOT", None)
    else:
        os.environ["APPLE_MUSIC_AUTO_IMPORT_STATE_ROOT"] = old_state_root
    print("Processor regression tests passed.")


if __name__ == "__main__":
    main()

"""Regression coverage for browser-cookie failures in the embedded downloader."""

import json
import sys
import tempfile
import types
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "AppleMusic-Auto-Enrich-Import.ps1"


def load_downloader_code():
    raw = SCRIPT.read_text(encoding="utf-8")
    function_start = raw.index("function Download-VideoUrls")
    marker = "$code = @'"
    start = raw.index(marker, function_start) + len(marker)
    end = raw.index("\n'@", start)
    return raw[start:end]


def main(error="ERROR: Failed to decrypt with DPAPI."):
    attempts = []

    class FakeYoutubeDL:
        def __init__(self, options):
            self.options = dict(options)
            attempts.append(self.options)

        def __enter__(self):
            return self

        def __exit__(self, *_args):
            return False

        def extract_info(self, _url, download=True):
            assert download is True
            if "cookiesfrombrowser" in self.options:
                raise RuntimeError(error)
            output = Path(self.options["outtmpl"].replace("%(title).180s", "Song").replace("%(id)s", "abc123").replace("%(ext)s", "m4a"))
            output.parent.mkdir(parents=True, exist_ok=True)
            output.write_bytes(b"audio")
            return {
                "id": "abc123",
                "title": "Song",
                "requested_downloads": [{"filepath": str(output)}],
            }

    original_module = sys.modules.get("yt_dlp")
    sys.modules["yt_dlp"] = types.SimpleNamespace(YoutubeDL=FakeYoutubeDL)
    old_argv = sys.argv
    embedded_exit = 0
    try:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            result_file = root / "result.json"
            sys.argv = [
                "downloader",
                str(root / "downloads"),
                str(result_file),
                "0",
                "0",
                "https://www.youtube.com/watch?v=abc123",
            ]
            try:
                exec(compile(load_downloader_code(), str(SCRIPT), "exec"), {"__name__": "cookie_fallback_test"})
            except SystemExit as exc:
                embedded_exit = int(exc.code or 0)
            payload = json.loads(result_file.read_text(encoding="utf-8"))
    finally:
        sys.argv = old_argv
        if original_module is None:
            sys.modules.pop("yt_dlp", None)
        else:
            sys.modules["yt_dlp"] = original_module

    assert embedded_exit == 0, payload
    assert len(attempts) == 2
    assert attempts[0]["cookiesfrombrowser"] == ("chrome",)
    assert "cookiesfrombrowser" not in attempts[1]
    assert len(payload["files"]) == 1
    assert payload["errors"] == []
    print("Downloader cookie fallback regression test passed.")


if __name__ == "__main__":
    for error in (
        "ERROR: Failed to decrypt with DPAPI.",
        "ERROR: Could not copy Chrome cookie database.",
        'ERROR: could not find chrome cookies database in "C:\\Users\\han\\AppData\\Local\\Google\\Chrome\\User Data"',
        "ERROR: could not find chrome cookie database",
        "ERROR: could not find cookies database",
    ):
        main(error)

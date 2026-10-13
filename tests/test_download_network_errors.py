"""Exercise terminal failures after cookie recovery, and bounded TLS retries."""
import json
import sys
import tempfile
import types
from pathlib import Path
from unittest.mock import patch

from test_download_cookie_fallback import load_downloader_code


def run_case(failures):
    attempts = []

    class FakeYoutubeDL:
        def __init__(self, options):
            self.options = dict(options)
            attempts.append(self.options)

        def __enter__(self):
            return self

        def __exit__(self, *args):
            return False

        def extract_info(self, url, download=True):
            index = len(attempts) - 1
            if index < len(failures):
                raise RuntimeError(failures[index])
            output = Path(self.options['outtmpl']).parent / 'song.m4a'
            output.write_bytes(b'audio')
            return {'id': 'test', 'title': 'Song',
                    'requested_downloads': [{'filepath': str(output)}]}

    with tempfile.TemporaryDirectory() as directory:
        result = Path(directory) / 'result.json'
        argv = ['downloader', directory, str(result), '0', '0',
                'https://www.bilibili.com/video/BV1334BzCEMo']
        with patch.dict(sys.modules, {'yt_dlp': types.SimpleNamespace(YoutubeDL=FakeYoutubeDL)}), \
                patch.object(sys, 'argv', argv), patch('time.sleep') as sleep:
            exit_code = 0
            try:
                exec(compile(load_downloader_code(), 'downloader', 'exec'), {'__name__': '__main__'})
            except SystemExit as exc:
                exit_code = int(exc.code or 0)
            payload = json.loads(result.read_text(encoding='utf-8'))
            delays = [call.args[0] for call in sleep.call_args_list]
    return attempts, exit_code, payload, delays


def main():
    cookie = 'Could not copy Chrome cookie database'
    tls = '[SSL: UNEXPECTED_EOF_WHILE_READING] EOF occurred in violation of protocol'
    attempts, code, result, delays = run_case([cookie, tls])
    assert code == 0 and len(result['files']) == 1 and not result['errors']
    assert len(attempts) == 3 and delays == [1]
    assert all('cookiesfrombrowser' not in attempt for attempt in attempts[1:])

    attempts, code, result, delays = run_case([cookie, tls, tls, tls])
    assert code == 1 and not result['files'] and len(attempts) == 4
    assert delays == [1, 2]
    assert tls in result['errors'][0] and cookie not in result['errors'][0]

    attempts, code, result, delays = run_case(['HTTP Error 403: Forbidden'])
    assert code == 1 and len(attempts) == 1 and not delays
    assert '403' in result['errors'][0]

    attempts, code, result, delays = run_case(['CERTIFICATE_VERIFY_FAILED'])
    assert code == 1 and len(attempts) == 1 and not delays
    assert not any(attempt.get('nocheckcertificate') for attempt in attempts)
    print('Downloader network error regression tests passed.')


if __name__ == '__main__':
    main()

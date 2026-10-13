import base64
from unittest.mock import patch, Mock
from test_processor_regressions import load_processor

p = load_processor()
image = b'\xff\xd8\xff' + b'test image bytes'
class Response:
    def __enter__(self): return self
    def __exit__(self, *args): pass
    def read(self, limit): return image

p['local_artwork_proxy'] = lambda: 'http://127.0.0.1:12345'
fallback = Mock()
fallback.open.return_value = Response()
with patch('urllib.request.urlopen', side_effect=TimeoutError), patch('urllib.request.build_opener', return_value=fallback):
    mime, data = p['fetch_artwork_bytes']('https://example.com/1200x1200bb.jpg')
    assert mime == 'image/jpeg' and data == image
    assert fallback.open.call_args.args[0].full_url.endswith('/600x600bb.jpg')

p['fetch_artwork_bytes'] = lambda url: ('image/jpeg', image)
assert base64.b64decode(p['preview_artwork']({'artwork_url':'https://example.com/a.jpg'})[1]) == image
assert p['preview_artwork']({'artwork_url':'https://example.com/a.jpg', 'artwork_mode':'none'}) == ('', '')
def failure(url): raise TimeoutError('test')
p['fetch_artwork_bytes'] = failure
meta = {'artwork_url':'https://example.com/a.jpg'}
assert p['preview_artwork'](meta) == ('', '')
assert 'artwork download failed' in meta['source']
print('Artwork route fallback, inline bytes, removal and failure tests passed.')

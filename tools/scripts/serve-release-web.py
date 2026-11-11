from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path


class NoCacheHandler(SimpleHTTPRequestHandler):
    def end_headers(self):
        self.send_header('Cache-Control', 'no-store, no-cache, must-revalidate')
        super().end_headers()


web = Path(__file__).resolve().parents[2] / 'build' / 'web'
ThreadingHTTPServer(('127.0.0.1', 8080), partial(NoCacheHandler, directory=str(web))).serve_forever()

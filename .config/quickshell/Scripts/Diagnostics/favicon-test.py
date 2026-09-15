#!/usr/bin/env python3
"""Exercise favicon downloads against a local HTTP server, without desktop state."""

import base64
from concurrent.futures import ThreadPoolExecutor
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
import subprocess
import sys
import tempfile
import threading
import unittest
from unittest.mock import patch
from urllib.parse import parse_qs, urlsplit


IMAGES = Path(__file__).resolve().parents[1] / "Images"
sys.path.insert(0, str(IMAGES))
import favicon


PNG = base64.b64decode(
    "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aD1sAAAAASUVORK5CYII="
)
CLI = "import sys; sys.path.insert(0, sys.argv.pop(1)); import favicon; favicon.ENDPOINT = sys.argv.pop(1); sys.exit(favicon.main())"


class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        state = self.server.state
        state["requests"].append((parse_qs(urlsplit(self.path).query), self.headers.get("User-Agent")))
        state["started"].set()
        state["release"].wait(5)
        self.send_response(state.get("status", 200))
        self.send_header("Content-Type", state.get("type", "image/png"))
        body = state.get("body", PNG)
        self.send_header("Content-Length", state.get("length", len(body)))
        self.end_headers()
        try:
            self.wfile.write(body)
        except (BrokenPipeError, ConnectionResetError):
            pass

    def log_message(self, *args):
        pass


class FaviconTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.server = ThreadingHTTPServer(("127.0.0.1", 0), Handler)
        cls.thread = threading.Thread(target=cls.server.serve_forever, daemon=True)
        cls.thread.start()
        cls.endpoint = f"http://127.0.0.1:{cls.server.server_port}/favicon"

    @classmethod
    def tearDownClass(cls):
        cls.server.shutdown()
        cls.server.server_close()
        cls.thread.join()

    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="carbon-favicon-test.")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.cache = self.root / "cache with 'quotes' $() `ticks` # % ü"
        self.state = {"requests": [], "started": threading.Event(), "release": threading.Event()}
        self.state["release"].set()
        self.server.state = self.state

    def command(self, domain="example.org", agent="Carbon test"):
        return [sys.executable, "-B", "-c", CLI, str(IMAGES), self.endpoint,
                "--", domain, str(self.cache), agent]

    def run_download(self, domain="example.org", agent="Carbon test"):
        return subprocess.run(self.command(domain, agent), cwd=self.root, text=True,
                              capture_output=True, timeout=10)

    def assert_cached(self, result):
        self.assertEqual(result.returncode, 0, result.stderr)
        files = list(self.cache.iterdir())
        self.assertEqual(len(files), 1)
        self.assertRegex(files[0].name, r"^[0-9a-f]{64}\.ico$")
        self.assertEqual(files[0].read_bytes(), PNG)
        self.assertEqual(result.stdout, files[0].as_uri() + "\n")
        return files[0]

    def test_success_and_cache_reuse(self):
        cached = self.assert_cached(self.run_download())
        before = cached.stat().st_mtime_ns
        self.state["status"] = 503
        self.assert_cached(self.run_download())
        self.assertEqual(cached.stat().st_mtime_ns, before)
        self.assertEqual(len(self.state["requests"]), 1)

    def test_runtime_values_remain_data(self):
        domain = "--example.org';touch${IFS}injected;$(touch${IFS}injected)&sz=999#../"
        agent = "Carbon ' ; $(touch injected) `touch injected`"
        self.assert_cached(self.run_download(domain, agent))
        self.assertEqual(self.state["requests"], [({"domain": [domain], "sz": ["32"]}, agent)])
        self.assertEqual(list(self.root.iterdir()), [self.cache])

    def test_failures_publish_nothing(self):
        for response in (
            {"status": 404}, {"status": 503}, {"status": 206},
            {"type": "text/html"}, {"body": b""},
            {"body": b"partial", "length": 100},
            {"length": "invalid"}, {"body": b"x" * (favicon.MAX_BYTES + 1)},
        ):
            with self.subTest(response={k: v for k, v in response.items() if k != "body"}):
                self.state.update(response)
                result = self.run_download()
                self.assertNotEqual(result.returncode, 0)
                self.assertEqual(result.stdout, "")
                self.assertFalse(self.cache.exists())
                for key in response:
                    del self.state[key]

    def test_failed_atomic_publish_cleans_staging(self):
        with patch.object(favicon, "ENDPOINT", self.endpoint), \
             patch.object(Path, "replace", side_effect=OSError("simulated write failure")):
            with self.assertRaises(OSError):
                favicon.fetch("example.org", self.cache, "Carbon test")
        self.assertEqual(list(self.cache.iterdir()), [])

    def test_concurrent_requests_publish_complete_files(self):
        with ThreadPoolExecutor(max_workers=6) as pool:
            results = list(pool.map(lambda _: self.run_download(), range(6)))
        for result in results:
            self.assert_cached(result)

    def test_interrupted_download_can_retry(self):
        self.state["release"].clear()
        process = subprocess.Popen(self.command(), cwd=self.root, text=True,
                                   stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        try:
            self.assertTrue(self.state["started"].wait(3))
            process.terminate()
            stdout, stderr = process.communicate(timeout=3)
            self.assertNotEqual(process.returncode, 0, stderr)
            self.assertEqual(stdout, "")
            self.assertFalse(self.cache.exists())
        finally:
            self.state["release"].set()
            if process.poll() is None:
                process.kill()
                process.communicate()
        self.assert_cached(self.run_download())

    def test_empty_cache_file_is_refetched(self):
        cached = self.assert_cached(self.run_download())
        cached.write_bytes(b"")
        self.assert_cached(self.run_download())
        self.assertEqual(len(self.state["requests"]), 2)


if __name__ == "__main__":
    unittest.main(verbosity=2)

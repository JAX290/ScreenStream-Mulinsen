import tempfile
import threading
import unittest
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path

import server


class DownloadGateTest(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        root = Path(self.temporary.name)
        server.APK_ROOT = root / "apk"
        server.STATE_FILE = root / "data" / "state.json"
        (server.APK_ROOT / "latest").mkdir(parents=True)
        (server.APK_ROOT / "latest" / "test.apk").write_bytes(b"test-apk")
        self.httpd = server.ThreadingHTTPServer(("127.0.0.1", 0), server.Handler)
        self.thread = threading.Thread(target=self.httpd.serve_forever, daemon=True)
        self.thread.start()
        self.base = f"http://127.0.0.1:{self.httpd.server_port}"

    def tearDown(self):
        self.httpd.shutdown()
        self.httpd.server_close()
        self.temporary.cleanup()

    def post(self, data, origin=server.ADMIN_ORIGIN):
        request = urllib.request.Request(
            self.base + "/download-control",
            data=urllib.parse.urlencode(data).encode(),
            headers={"Origin": origin},
        )
        return urllib.request.urlopen(request)

    def assert_http_error(self, status, url):
        with self.assertRaises(urllib.error.HTTPError) as caught:
            urllib.request.urlopen(url)
        self.assertEqual(caught.exception.code, status)
        caught.exception.close()

    def test_count_gate_closes_after_exact_download_count(self):
        download = self.base + "/apk1/latest/test.apk"
        self.assert_http_error(403, download)
        with self.post({"action": "count", "count": "2"}) as response:
            self.assertEqual(response.status, 200)
        for _ in range(2):
            with urllib.request.urlopen(download) as response:
                self.assertEqual(response.read(), b"test-apk")
        self.assert_http_error(403, download)

    def test_rejects_cross_origin_control_request(self):
        with self.assertRaises(urllib.error.HTTPError) as caught:
            self.post({"action": "permanent"}, origin="https://example.com")
        self.assertEqual(caught.exception.code, 403)
        caught.exception.close()
        self.assertEqual(server.state_snapshot()["mode"], "closed")


if __name__ == "__main__":
    unittest.main()

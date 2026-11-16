"""Tests for tools/sync_hosted_audio.py (no network)."""
from __future__ import annotations

import contextlib
import hashlib
import io
import json
import pathlib
import sys
import tempfile
import unittest
import urllib.request
from unittest import mock

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import sync_hosted_audio as sync  # noqa: E402

BODY = b"abcdef"
SHA = hashlib.sha256(BODY).hexdigest()
URL = "https://example.test/audio/t/a.m4a"


class FakeResponse:
    def __init__(self, headers=None, status=200, body=b""):
        self.headers = headers or {}
        self.status = status
        self._body = body
        self._pos = 0

    def read(self, n=-1):
        end = len(self._body) if n < 0 else self._pos + n
        chunk = self._body[self._pos:end]
        self._pos += len(chunk)
        return chunk

    def __enter__(self):
        return self

    def __exit__(self, *exc):
        return False


class Base(unittest.TestCase):
    def setUp(self):
        self._tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self._tmp.cleanup)
        self.root = pathlib.Path(self._tmp.name)
        content = self.root / "assets" / "content"
        content.mkdir(parents=True)
        data = {"schema": 1, "categories": [{"id": "c", "readings": [
            {"id": "r1", "audio": {"path": "audio/t/a.m4a", "bytes": 6, "sha256": SHA}},
            {"id": "r2", "audio": None}]}]}
        (content / "x.json").write_text(json.dumps(data), encoding="utf-8")
        self.file = self.root / "hosted" / "audio" / "t" / "a.m4a"
        self.file.parent.mkdir(parents=True)
        self.file.write_bytes(BODY)


class RecordingsTest(Base):
    def test_recordings_lists_in_order(self):
        self.assertEqual(sync.recordings(self.root),
                         [{"path": "audio/t/a.m4a", "bytes": 6, "sha256": SHA, "reading": "r1"}])

    def test_recordings_rejects_bad_sha(self):
        p = self.root / "assets" / "content" / "x.json"
        p.write_text(p.read_text(encoding="utf-8").replace(SHA, "zz"), encoding="utf-8")
        with self.assertRaises(sync.SyncError):
            sync.recordings(self.root)


class CheckTest(Base):
    def test_check_passes(self):
        self.assertIsNone(sync.check(self.root))

    def test_check_missing_file(self):
        self.file.unlink()
        self.assertEqual(sync.check(self.root), "missing: hosted/audio/t/a.m4a")

    def test_check_wrong_size(self):
        self.file.write_bytes(b"abc")
        self.assertEqual(sync.check(self.root), "audio/t/a.m4a is 3 bytes, expected 6")

    def test_check_wrong_checksum(self):
        self.file.write_bytes(b"abcdeX")
        bad = hashlib.sha256(b"abcdeX").hexdigest()
        self.assertEqual(sync.check(self.root),
                         f"audio/t/a.m4a has checksum {bad}, expected {SHA}")

    def test_check_extra_file(self):
        (self.root / "hosted" / "stray.txt").write_text("x")
        self.assertIn("stray.txt", sync.check(self.root))

    def test_check_allows_readme(self):
        (self.root / "hosted" / "README.md").write_text("x")
        self.assertIsNone(sync.check(self.root))


class PlanUploadTest(Base):
    def test_plan_command_has_headers(self):
        self.assertEqual(sync.plan(self.root), [[
            "npx", "wrangler", "r2", "object", "put", "namo-audio/audio/t/a.m4a",
            "--file", "hosted/audio/t/a.m4a", "--content-type", "audio/mp4",
            "--cache-control", "public, max-age=31536000, immutable", "--remote"]])

    def test_upload_runs_each_command(self):
        calls = []
        with mock.patch.object(sync.shutil, "which", return_value="/bin/npx"):
            sync.upload(self.root, run=lambda argv, **kw: calls.append((argv, kw)))
        self.assertEqual(len(calls), 1)
        argv, kwargs = calls[0]
        self.assertTrue(argv[0].endswith(("npx", "npx.cmd")))
        self.assertEqual(argv[1:], sync.plan(self.root)[0][1:])
        self.assertTrue(kwargs.get("check"))
        self.assertEqual(kwargs.get("cwd"), self.root)

    def test_upload_without_npx(self):
        with mock.patch.object(sync.shutil, "which", return_value=None):
            with self.assertRaises(sync.SyncError):
                sync.upload(self.root, run=lambda *a, **k: None)


class VerifyTest(Base):
    def test_verify_head_ok(self):
        seen = []

        def opener(req, timeout=None):
            seen.append(req)
            timeouts.append(timeout)
            return FakeResponse({"Content-Length": "6", "Content-Type": "audio/mp4"})

        timeouts = []
        self.assertEqual(sync.verify(self.root, "https://example.test", opener), [])
        self.assertEqual(timeouts, [60])
        req = seen[0]
        self.assertIsInstance(req, urllib.request.Request)
        self.assertEqual(req.method, "HEAD")
        self.assertEqual(req.full_url, URL)
        self.assertEqual(req.get_header("User-agent"), "namo-app-build/1.0")

    def test_verify_reports_length_type_and_status(self):
        def opener(req, timeout=None):
            return FakeResponse({"Content-Length": "5", "Content-Type": "text/html"})

        self.assertEqual(sync.verify(self.root, "https://example.test/", opener), [
            f"{URL}: Content-Length 5, expected 6",
            f"{URL}: Content-Type text/html, expected audio/mp4"])

        def bad(req, timeout=None):
            return FakeResponse({}, status=404)

        self.assertEqual(sync.verify(self.root, "https://example.test", bad), [f"{URL}: HTTP 404"])

    def test_verify_full_hashes_the_download(self):
        good = lambda req, timeout=None: FakeResponse(body=BODY)
        self.assertEqual(sync.verify_full(self.root, "https://example.test", good), [])
        bad = lambda req, timeout=None: FakeResponse(body=b"abcdeX")
        other = hashlib.sha256(b"abcdeX").hexdigest()
        self.assertEqual(sync.verify_full(self.root, "https://example.test", bad),
                         [f"{URL}: checksum {other}, expected {SHA}"])


class VerifyRobustnessTest(Base):
    def setUp(self):
        super().setUp()
        p = self.root / "assets" / "content" / "x.json"
        data = json.loads(p.read_text(encoding="utf-8"))
        data["categories"][0]["readings"].append(
            {"id": "r3", "audio": {"path": "audio/t/b.m4a", "bytes": 6, "sha256": SHA}})
        p.write_text(json.dumps(data), encoding="utf-8")
        self.urls = ["https://example.test/audio/t/a.m4a", "https://example.test/audio/t/b.m4a"]

    def _failing_then_ok(self, error, ok_response):
        seen = []

        def opener(req, timeout=None):
            seen.append(req)
            if len(seen) == 1:
                raise error
            return ok_response

        return opener, seen

    def test_verify_goes_on_after_http_error_and_os_error(self):
        err = urllib.error.HTTPError(self.urls[0], 403, "Forbidden", {}, None)
        opener, seen = self._failing_then_ok(
            err, FakeResponse({"Content-Length": "6", "Content-Type": "audio/mp4"}))
        self.assertEqual(sync.verify(self.root, "https://example.test", opener),
                         [f"{self.urls[0]}: HTTP 403"])
        self.assertEqual(len(seen), 2)
        opener, seen = self._failing_then_ok(
            OSError("boom"), FakeResponse({"Content-Length": "6", "Content-Type": "audio/mp4"}))
        self.assertEqual(sync.verify(self.root, "https://example.test", opener),
                         [f"{self.urls[0]}: boom"])
        self.assertEqual(len(seen), 2)

    def test_verify_full_goes_on_after_errors(self):
        err = urllib.error.HTTPError(self.urls[0], 500, "Err", {}, None)
        opener, seen = self._failing_then_ok(err, FakeResponse(body=BODY))
        self.assertEqual(sync.verify_full(self.root, "https://example.test", opener),
                         [f"{self.urls[0]}: HTTP 500"])
        self.assertEqual(len(seen), 2)
        opener, seen = self._failing_then_ok(OSError("boom"), FakeResponse(body=BODY))
        self.assertEqual(sync.verify_full(self.root, "https://example.test", opener),
                         [f"{self.urls[0]}: boom"])
        self.assertEqual(len(seen), 2)

    def _run_full(self, opener):
        made = []
        real = tempfile.mkdtemp

        def spy(*a, **k):
            made.append(pathlib.Path(real(*a, **k)))
            return str(made[-1])

        with mock.patch.object(sync.tempfile, "mkdtemp", spy):
            try:
                result = sync.verify_full(self.root, "https://example.test", opener)
            except Exception:
                result = None
        self.assertEqual(len(made), 1)
        self.assertFalse(made[0].exists())
        return result

    def test_verify_full_request_and_cleanup(self):
        seen = []

        def opener(req, timeout=None):
            seen.append(req)
            return FakeResponse(body=BODY)

        self.assertEqual(self._run_full(opener), [])
        self.assertEqual({r.method for r in seen}, {"GET"})
        self.assertEqual({r.get_header("User-agent") for r in seen}, {"namo-app-build/1.0"})

    def test_verify_full_cleans_up_after_failure(self):
        def opener(req, timeout=None):
            raise OSError("down")

        self.assertEqual(len(self._run_full(opener)), 2)

    def test_verify_full_cleans_up_after_unexpected_exception(self):
        def opener(req, timeout=None):
            raise RuntimeError("bug")

        self.assertIsNone(self._run_full(opener))


class CliTest(Base):
    def test_cli(self):
        out, err = io.StringIO(), io.StringIO()
        with contextlib.redirect_stdout(out), contextlib.redirect_stderr(err):
            self.assertEqual(sync.main([str(self.root), "--check"]), 0)
        self.assertEqual(out.getvalue().strip(), "hosted audio is up to date")
        out, err = io.StringIO(), io.StringIO()
        with contextlib.redirect_stdout(out), contextlib.redirect_stderr(err):
            self.assertEqual(sync.main([str(self.root)]), 2)
        self.assertIn("usage", err.getvalue())


if __name__ == "__main__":
    unittest.main()

#!/usr/bin/env python3
"""Standard-library tests for ZIP-to-repository capture staging."""
from __future__ import annotations
import hashlib
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from zipfile import ZipFile

SCRIPT = Path(__file__).with_name("import_capture.py")


class CaptureImportTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.dest = self.root / "raw"
        self.zippath = self.root / "capture.zip"

    def writezip(self, entries):
        with ZipFile(self.zippath, "w") as zipped:
            for name, content in entries.items():
                zipped.writestr(name, content)

    def run_cli(self, *extra):
        return subprocess.run([
            sys.executable, str(SCRIPT), str(self.zippath),
            "--target", str(self.dest), *extra,
        ], capture_output=True, text=True)

    def test_preserves_bytes_and_idempotent(self):
        data = b'{"kind": "weight", "environment": {"tdbVersion": 83}}\n'
        self.writezip({"source/weight.json": data})
        r = self.run_cli("--keep-zip")
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertEqual((self.dest / "weight.json").read_bytes(), data)
        source_hash = hashlib.sha256(self.zippath.read_bytes()).hexdigest()
        manifest = json.loads(
            (self.dest / f"IMPORT_{source_hash[:12]}.json").read_text()
        )
        self.assertEqual(
            manifest["captureFiles"][0]["sha256"],
            hashlib.sha256(data).hexdigest(),
        )
        self.assertEqual(self.run_cli("--keep-zip").returncode, 0)

    def test_refuses_conflict_without_overwriting(self):
        self.writezip({"weight.json": '{"kind":"weight"}'})
        self.dest.mkdir()
        (self.dest / "weight.json").write_text("original")
        self.assertEqual(self.run_cli().returncode, 2)
        self.assertEqual((self.dest / "weight.json").read_text(), "original")

    def test_dry_run_does_not_write(self):
        self.writezip({"weight.json": '{"kind":"weight"}'})
        self.assertEqual(self.run_cli("--dry-run").returncode, 0)
        self.assertFalse(self.dest.exists())

    def test_rejects_path_traversal(self):
        self.writezip({"../bad.json": "{}"})
        self.assertEqual(self.run_cli().returncode, 2)
        self.assertFalse(self.dest.exists())

    def test_rejects_duplicate_basenames(self):
        self.writezip({"a/weight.json": "{}", "b/weight.json": "{}"})
        self.assertEqual(self.run_cli().returncode, 2)
        self.assertFalse(self.dest.exists())

    def test_rejects_non_json(self):
        self.writezip({"bad.txt": "foo"})
        self.assertEqual(self.run_cli().returncode, 2)
        self.assertFalse(self.dest.exists())


if __name__ == "__main__":
    unittest.main()

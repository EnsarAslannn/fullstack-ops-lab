import contextlib
import importlib.util
import io
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from datetime import datetime, timedelta, timezone
from unittest.mock import patch


SCRIPT = Path(__file__).resolve().parents[1] / "infrastructure/deployment/backup/daily-backup.py"


class DockerFixture:
    """Only the Docker boundary is simulated; files, promotion and locks are real."""

    def __init__(self):
        self.fail = None
        self.container_file = None
        self.server_version = b"18.6\n"
        self.inspect = {
            "id": "a" * 64, "image": "sha256:" + "b" * 64,
            "project": "fullstackops-deploy-lab", "service": "postgres",
            "state": "running", "health": "healthy", "ports": {},
            "mounts": [{"Type": "volume", "Name": "fullstackops-deploy-lab-postgres",
                        "Destination": "/var/lib/postgresql", "RW": True}],
        }

    def run(self, command, **kwargs):
        args = command[3:]
        out = b""
        phase = "inspect"
        if args[0] == "inspect":
            out = json.dumps(self.inspect).encode()
        elif args[0] == "cp":
            phase = "copy"
            Path(args[2]).write_bytes(self.container_file)
        elif "--version" in args:
            out = b"pg tool (PostgreSQL) 18.6\n"
        elif any("SHOW server_version" in arg for arg in args):
            out = self.server_version
        elif "mkdir" in args:
            pass
        elif any("exec timeout 180 pg_dump" in arg for arg in args):
            phase = "dump"
            self.container_file = b"PGDMP-fixture-archive"
        elif "sha256sum" in args:
            import hashlib
            out = (hashlib.sha256(self.container_file).hexdigest() + "  file\n").encode()
        elif "pg_restore" in args:
            phase = "archive"
            out = (b"1; TABLE DATA public tasks role\n"
                   b"2; TABLE DATA public __EFMigrationsHistory role\n"
                   b"3; SEQUENCE SET public tasks_id_seq role\n")
        elif any("rm -f" in arg for arg in args):
            phase = "cleanup"
            self.container_file = None
        else:
            raise AssertionError("Unexpected Docker fixture command")
        if self.fail == phase:
            return subprocess.CompletedProcess(command, 7, out, b"fixture-private-canary")
        if self.fail == phase + "-timeout":
            raise subprocess.TimeoutExpired(command, 1, stderr=b"fixture-private-canary")
        if self.fail == "warning" and phase == "dump":
            return subprocess.CompletedProcess(command, 0, out, b"fixture-private-canary")
        if self.fail == "checksum" and "sha256sum" in args:
            out = b"0" * 64 + b"  file\n"
        return subprocess.CompletedProcess(command, 0, out, b"")


class DailyBackupTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        if not SCRIPT.is_file():
            return
        spec = importlib.util.spec_from_file_location("daily_backup", SCRIPT)
        cls.backup = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(cls.backup)

    def setUp(self):
        self.assertTrue(SCRIPT.is_file(), "Daily backup script is not implemented")
        self.temp = tempfile.TemporaryDirectory(prefix="fullstackops-daily-fixture-")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name) / "daily"
        self.docker = DockerFixture()
        self.now = datetime(2026, 10, 1, 2, tzinfo=timezone(timedelta(hours=3)))

    def run_backup(self):
        output = io.StringIO()
        with patch.object(self.backup.subprocess, "run", self.docker.run), contextlib.redirect_stdout(output):
            code = self.backup.run_backup(self.root, lambda: self.now)
        self.assertNotIn("fixture-private-canary", output.getvalue())
        return code

    def sets(self):
        return sorted(p.name for p in self.root.iterdir() if p.name.startswith("20"))

    def test_success_promotes_checked_archive_and_preserves_same_day_set(self):
        self.assertEqual(self.run_backup(), 0)
        target = self.root / "2026-10-01"
        original = (target / "manifest.json").read_bytes()
        success = (self.root / "last-success.json").read_bytes()
        self.assertEqual((target / "database.pgdump").read_bytes(), b"PGDMP-fixture-archive")
        self.assertIsNone(self.docker.container_file)
        self.now += timedelta(hours=4)
        self.docker.fail = "dump"
        self.assertEqual(self.run_backup(), 0, "Same day must skip, not dump or replace")
        self.assertEqual((target / "manifest.json").read_bytes(), original)
        self.assertEqual((self.root / "last-success.json").read_bytes(), success)
        self.assertEqual(json.loads((self.root / "last-attempt.json").read_text())["result"], "already-complete")
        if os.name != "nt":
            self.assertEqual(self.root.stat().st_mode & 0o777, 0o700)
            self.assertEqual((target / "database.pgdump").stat().st_mode & 0o777, 0o600)

    def test_dump_archive_copy_and_timeout_failures_never_promote_or_prune(self):
        self.assertEqual(self.run_backup(), 0)
        success = (self.root / "last-success.json").read_bytes()
        self.now += timedelta(days=1)
        for phase in ("dump", "copy", "archive", "cleanup", "dump-timeout", "warning", "checksum"):
            with self.subTest(phase=phase):
                self.docker.fail = phase
                self.assertNotEqual(self.run_backup(), 0)
                self.assertEqual(self.sets(), ["2026-10-01"])
                self.assertEqual((self.root / "last-success.json").read_bytes(), success)
                self.assertNotIn(b"fixture-private-canary", (self.root / "last-attempt.json").read_bytes())

    def test_same_day_retry_cannot_hide_retention_failure(self):
        for day in range(1, 8):
            self.now = self.now.replace(day=day)
            self.assertEqual(self.run_backup(), 0)
        (self.root / "2026-10-03" / "database.pgdump").write_bytes(b"corrupt")
        self.now = self.now.replace(day=8)
        self.assertEqual(self.run_backup(), 1)
        self.assertEqual(self.run_backup(), 1, "Same-day skip must not clear a retention error")
        self.assertTrue((self.root / "2026-10-01").is_dir())

    def test_corrupted_same_day_archive_is_not_overwritten(self):
        self.assertEqual(self.run_backup(), 0)
        archive = self.root / "2026-10-01" / "database.pgdump"
        archive.write_bytes(b"corrupt")
        self.assertEqual(self.run_backup(), 1)
        self.assertEqual(archive.read_bytes(), b"corrupt")

    def test_foreign_file_in_owned_set_blocks_any_retention_deletion(self):
        for day in range(1, 8):
            self.now = self.now.replace(day=day)
            self.assertEqual(self.run_backup(), 0)
        (self.root / "2026-10-01" / "foreign.txt").write_text("keep")
        self.now = self.now.replace(day=8)
        self.assertEqual(self.run_backup(), 1)
        self.assertTrue((self.root / "2026-10-01" / "database.pgdump").is_file())
        self.assertTrue((self.root / "2026-10-01" / "foreign.txt").is_file())

    def test_missing_status_is_read_only(self):
        with contextlib.redirect_stdout(io.StringIO()):
            self.assertEqual(self.backup.show_status(self.root, lambda: self.now), 2)
        self.assertFalse(self.root.exists())

    def test_retention_keeps_seven_distinct_successful_days_and_foreign_files(self):
        self.assertEqual(self.run_backup(), 0)
        manual = self.root.parent / "backups-private" / "4756810b5b43"
        manual.mkdir(parents=True)
        (manual / "database.pgdump").write_bytes(b"manual-acceptance")
        foreign = self.root / "2025-01-01"
        foreign.mkdir()
        (foreign / "keep.txt").write_text("unowned")
        partial = self.root / ".partial-interrupted-fixture"
        partial.mkdir()
        (partial / "database.pgdump").write_bytes(b"incomplete")
        for day in range(2, 11):
            self.now = self.now.replace(day=day)
            self.assertEqual(self.run_backup(), 0)
        self.assertEqual(self.sets(), ["2025-01-01"] + [f"2026-10-{day:02}" for day in range(4, 11)])
        self.assertEqual((manual / "database.pgdump").read_bytes(), b"manual-acceptance")
        self.assertEqual((foreign / "keep.txt").read_text(), "unowned")
        self.assertEqual((partial / "database.pgdump").read_bytes(), b"incomplete")

    def test_interrupted_success_pointer_is_repaired_without_taking_another_dump(self):
        original = self.backup.atomic_json

        def interrupted(path, value):
            if path.name == "last-success.json":
                raise OSError("fixture-private-canary")
            original(path, value)

        with patch.object(self.backup, "atomic_json", interrupted):
            self.assertEqual(self.run_backup(), 1)
        self.assertFalse((self.root / "last-success.json").exists())
        manifest = (self.root / "2026-10-01" / "manifest.json").read_bytes()
        self.now += timedelta(hours=3)
        self.docker.fail = "dump"
        self.assertEqual(self.run_backup(), 0)
        self.assertEqual((self.root / "last-success.json").read_bytes(), manifest)

    def test_corrupt_owned_set_blocks_retention_without_deleting_older_success(self):
        for day in range(1, 8):
            self.now = self.now.replace(day=day)
            self.assertEqual(self.run_backup(), 0)
        (self.root / "2026-10-03" / "database.pgdump").write_bytes(b"corrupt")
        self.now = self.now.replace(day=8)
        self.assertNotEqual(self.run_backup(), 0)
        self.assertTrue((self.root / "2026-10-01" / "database.pgdump").is_file())

    def test_wrong_source_mount_or_project_fails_before_dump(self):
        for key, value in (("project", "development"), ("mounts", []), ("health", "unhealthy")):
            with self.subTest(key=key):
                original = self.docker.inspect[key]
                self.docker.inspect[key] = value
                self.assertNotEqual(self.run_backup(), 0)
                self.assertIsNone(self.docker.container_file)
                self.assertEqual(self.sets(), [])
                self.docker.inspect[key] = original

    def test_server_tool_version_mismatch_prevents_dump(self):
        self.docker.server_version = b"17.9\n"
        self.assertNotEqual(self.run_backup(), 0)
        self.assertEqual(self.sets(), [])
        self.assertIsNone(self.docker.container_file)

    def test_concurrent_process_cannot_acquire_lock_and_lock_releases(self):
        self.assertEqual(self.run_backup(), 0)
        code = ("import importlib.util, pathlib, sys; "
                "s=importlib.util.spec_from_file_location('daily',sys.argv[1]); "
                "m=importlib.util.module_from_spec(s); s.loader.exec_module(m); "
                "sys.exit(m.run_backup(pathlib.Path(sys.argv[2])))")
        with self.backup.backup_lock(self.root):
            result = subprocess.run([sys.executable, "-B", "-c", code, str(SCRIPT), str(self.root)],
                                    capture_output=True, timeout=10)
        self.assertEqual(result.returncode, 75, result.stdout.decode(errors="replace"))
        self.assertEqual(self.run_backup(), 0)

    def test_status_reports_fresh_stale_and_last_failure_without_docker(self):
        self.assertEqual(self.run_backup(), 0)
        with contextlib.redirect_stdout(io.StringIO()):
            self.assertEqual(self.backup.show_status(self.root, lambda: self.now), 0)
            self.assertEqual(self.backup.show_status(self.root, lambda: self.now + timedelta(hours=25)), 2)
        self.now += timedelta(days=1)
        self.docker.fail = "dump"
        self.assertEqual(self.run_backup(), 1)
        with contextlib.redirect_stdout(io.StringIO()):
            self.assertEqual(self.backup.show_status(self.root, lambda: self.now), 2)

    def test_nonempty_unowned_root_is_never_adopted(self):
        self.root.mkdir()
        (self.root / "manual.pgdump").write_bytes(b"keep")
        self.assertNotEqual(self.run_backup(), 0)
        self.assertEqual((self.root / "manual.pgdump").read_bytes(), b"keep")
        self.assertFalse((self.root / ".owner").exists())


if __name__ == "__main__":
    unittest.main()

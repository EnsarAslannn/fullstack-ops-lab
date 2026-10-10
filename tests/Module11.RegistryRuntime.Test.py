"""Offline safety checks for registry acceptance; Docker is replaced at its subprocess boundary."""

import importlib.util
import contextlib
import io
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch
import uuid

sys.dont_write_bytecode = True
spec = importlib.util.spec_from_file_location("compose_acceptance", Path(__file__).with_name("Module11.Compose.Smoke.py"))
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)

API = "ghcr.io/example/lab-api@sha256:" + "a" * 64
FRONTEND = "ghcr.io/example/lab-frontend@sha256:" + "b" * 64
SHA = "c" * 40


class RegistryAcceptanceTests(unittest.TestCase):
    def setUp(self):
        self.directory = Path(tempfile.gettempdir()) / ("fullstackops-ci-fixture-" + uuid.uuid4().hex)
        self.lab = module.Lab(self.directory)
        self.calls = []
        self.wrong_revision = False
        self.wrong_container = False
        self.dirty_sources = ""
        self.addCleanup(self.remove_fixture)

    def remove_fixture(self):
        if self.directory.exists():
            import shutil
            shutil.rmtree(self.directory)

    def command(self, args, **options):
        self.calls.append(args)
        output = ""
        if args[:3] == ["git", "rev-parse", "HEAD"]:
            output = SHA
        elif args[:2] == ["git", "status"] and "src/backend/FullStackOpsLab.Api" in args:
            output = self.dirty_sources
        elif args[:3] == ["docker", "image", "inspect"]:
            ref = args[-1]
            output = json.dumps({"id": "sha256:" + ("a" if ref == API else "b") * 64,
                                 "revision": "d" * 40 if self.wrong_revision else SHA, "digests": [ref]})
        elif args[:2] == ["docker", "inspect"]:
            output = "sha256:" + ("e" if self.wrong_container else ("a" if args[-1] == "1" * 64 else "b")) * 64
        elif args[:2] == ["docker", "compose"]:
            if "ps" in args and "-q" in args:
                output = ("1" if args[-1] == "api" else "2") * 64
            elif "ps" in args:
                output = "\n".join(service + "|running|healthy" for service in sorted(module.SERVICES))
            elif "exec" in args and "postgres" in args:
                if options.get("input", b"").startswith(b"SELECT count"):
                    output = "1\n0"
        elif args[:3] == ["dotnet", "ef", "migrations"]:
            Path(args[-1]).write_text('CREATE TABLE tasks; __EFMigrationsHistory; ' + module.MIGRATION, encoding="utf-8")
        return subprocess.CompletedProcess(args, 0, output.encode(), b"")

    def prepare(self, **kwargs):
        stdout, stderr = io.StringIO(), io.StringIO()
        try:
            with patch.object(module.subprocess, "run", side_effect=self.command), \
                    contextlib.redirect_stdout(stdout), contextlib.redirect_stderr(stderr):
                self.lab.prepare(api_image=API, frontend_image=FRONTEND, source_sha=SHA, **kwargs)
        finally:
            output = stdout.getvalue() + stderr.getvalue()
            for value in (self.lab.state or {}).get("credentials", []):
                self.assertFalse(value in output, "Generated credential leaked; value withheld")

    def test_registry_start_pulls_both_digests_and_cannot_build(self):
        self.prepare()
        self.assertIn(["docker", "pull", API], self.calls)
        self.assertIn(["docker", "pull", FRONTEND], self.calls)
        starts = [args for args in self.calls if args[:2] == ["docker", "compose"] and "up" in args and "postgres" not in args]
        self.assertEqual(len(starts), 1)
        self.assertIn("--no-build", starts[0])
        self.assertNotIn("--build", starts[0])
        self.assertEqual(starts[0][starts[0].index("--pull") + 1], "never")
        override = (self.directory / "override.yaml").read_text(encoding="utf-8")
        self.assertEqual(override.count("build: !reset null"), 2)
        self.assertIn(API, override)
        self.assertIn(FRONTEND, override)

    def test_mutable_tag_is_rejected_before_resources_exist(self):
        with self.assertRaises(module.AcceptanceError):
            self.lab.prepare(api_image="ghcr.io/example/lab-api:latest", frontend_image=FRONTEND, source_sha=SHA)
        self.assertFalse(self.directory.exists())

    def test_incomplete_registry_inputs_are_rejected(self):
        with self.assertRaises(module.AcceptanceError):
            self.lab.prepare(api_image=API)
        self.assertFalse(self.directory.exists())

    def test_wrong_source_revision_prevents_volume_creation(self):
        self.wrong_revision = True
        with self.assertRaises(module.AcceptanceError):
            self.prepare()
        self.assertFalse(any(args[:3] == ["docker", "volume", "create"] for args in self.calls))
        self.assertFalse(self.directory.exists(), "Identity failure left partial preparation state")

    def test_uncommitted_migration_change_cannot_use_published_sha(self):
        self.dirty_sources = " M src/backend/FullStackOpsLab.Api/Migrations/AppDbContextModelSnapshot.cs"
        with self.assertRaises(module.AcceptanceError):
            self.prepare()
        self.assertFalse(self.directory.exists())
        self.assertFalse(any(args[:2] == ["docker", "pull"] for args in self.calls))

    def test_untracked_backend_source_cannot_use_published_sha(self):
        self.dirty_sources = "?? src/backend/FullStackOpsLab.Api/Migrations/Uncommitted.cs"
        with self.assertRaises(module.AcceptanceError):
            self.prepare()
        self.assertFalse(self.directory.exists())
        self.assertFalse(any(args[:2] == ["docker", "pull"] for args in self.calls))

    def test_running_container_must_use_selected_image_id(self):
        self.prepare()
        with patch.object(module.subprocess, "run", side_effect=self.command):
            self.lab.registry_identity()
            self.wrong_container = True
            with self.assertRaises(module.AcceptanceError):
                self.lab.registry_identity()

    def test_existing_ci_prepare_still_builds(self):
        with patch.object(module.subprocess, "run", side_effect=self.command):
            self.lab.prepare()
        starts = [args for args in self.calls if args[:2] == ["docker", "compose"] and "up" in args and "postgres" not in args]
        self.assertIn("--build", starts[0])

    def test_command_failure_with_secret_has_safe_error(self):
        self.prepare()
        canary = self.lab.state["credentials"][0]
        result = subprocess.CompletedProcess(["docker"], 1, canary.encode(), canary.encode())
        with patch.object(module.subprocess, "run", return_value=result):
            with self.assertRaises(module.AcceptanceError) as failure:
                self.lab.registry_identity()
        self.assertFalse(canary in str(failure.exception), "Generated credential leaked; value withheld")


if __name__ == "__main__":
    unittest.main()

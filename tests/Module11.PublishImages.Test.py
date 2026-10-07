"""Offline checks of the publisher's Docker boundary; no real credentials or registry calls."""
import contextlib
import importlib.util
import io
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch
import uuid

sys.dont_write_bytecode = True

MODULE_PATH = Path(__file__).resolve().parents[1] / "scripts/Module11.PublishImages.py"
spec = importlib.util.spec_from_file_location("publisher", MODULE_PATH)
publisher = importlib.util.module_from_spec(spec)
spec.loader.exec_module(publisher)


class PublishingTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="ghcr-fixture-")
        self.addCleanup(self.temp.cleanup)
        self.canary = uuid.uuid4().hex
        self.sha = "a" * 40
        self.digest = "sha256:" + "b" * 64
        self.image_id = "sha256:" + "c" * 64
        self.env = {
            **os.environ,
            "GITHUB_EVENT_NAME": "push",
            "GITHUB_REF": "refs/heads/main",
            "GITHUB_SHA": self.sha,
            "GITHUB_REPOSITORY": "ExampleOwner/fullstack-ops-lab",
            "GITHUB_ACTOR": "fixture-actor",
            "GHCR_TOKEN": self.canary,
            "RUNNER_TEMP": self.temp.name,
        }
        self.env.pop("GITHUB_STEP_SUMMARY", None)
        self.calls = []
        self.fail_at = None
        self.wrong_revision = False
        self.wrong_image_id = False
        self.no_digest = False

    def docker(self, args, **kwargs):
        self.calls.append((args, kwargs))
        command = args[1]
        if command == self.fail_at:
            # Deliberately unsafe external output must never be forwarded by the real publisher.
            return subprocess.CompletedProcess(args, 9, self.canary, self.canary)
        output = ""
        if command == "login":
            self.assertEqual(self.canary, kwargs.get("input"))
            self.assertFalse(self.canary in " ".join(args), "Token appeared in process arguments; value withheld.")
        elif command == "image":
            if args[-1] == "{{.Id}}":
                output = "sha256:" + "e" * 64 if self.wrong_image_id and "@" in args[3] else self.image_id
            elif "RepoDigests" in args[-1]:
                output = "" if self.no_digest else "ghcr.io/exampleowner/fullstack-ops-lab-" + self.component + "@" + self.digest
            elif "image.revision" in args[-1]:
                output = "d" * 40 if self.wrong_revision else self.sha
            else:
                raise AssertionError("Unexpected inspect operation")
        self.assertNotIn("GHCR_TOKEN", kwargs["env"])
        return subprocess.CompletedProcess(args, 0, output, "")

    def invoke(self, component="api"):
        self.component = component
        stdout, stderr = io.StringIO(), io.StringIO()
        with patch.object(publisher.subprocess, "run", side_effect=self.docker), \
                contextlib.redirect_stdout(stdout), contextlib.redirect_stderr(stderr):
            result = publisher.main([component], self.env)
        output = stdout.getvalue() + stderr.getvalue()
        self.assertFalse(self.canary in output, "Canary leaked into output; value withheld.")
        self.assertEqual([], list(Path(self.temp.name).glob("fullstack-ops-ghcr-*")))
        return result, output

    def test_api_and_frontend_publish_sha_and_latest_only_after_digest_verification(self):
        for component, context in (("api", "src/backend/FullStackOpsLab.Api"), ("frontend", "src/frontend")):
            with self.subTest(component=component):
                self.calls.clear()
                result, output = self.invoke(component)
                self.assertEqual(0, result)
                ref = "ghcr.io/exampleowner/fullstack-ops-lab-" + component
                pushes = [args[2] for args, _ in self.calls if args[1] == "push"]
                self.assertEqual([ref + ":sha-" + self.sha, ref + ":latest"], pushes)
                build = next(args for args, _ in self.calls if args[1] == "build")
                self.assertEqual(context, build[-1])
                self.assertIn("org.opencontainers.image.source=https://github.com/ExampleOwner/fullstack-ops-lab", build)
                self.assertIn("org.opencontainers.image.revision=" + self.sha, build)
                pull = next(args for args, _ in self.calls if args[1] == "pull")
                self.assertEqual(ref + "@" + self.digest, pull[2])
                commands = [args[1] for args, _ in self.calls]
                self.assertLess(commands.index("pull"), commands.index("tag"))
                self.assertIn(self.digest, output)
                self.assertEqual("logout", commands[-1])

    def test_untrusted_event_and_branch_cannot_publish(self):
        for key, value in (("GITHUB_EVENT_NAME", "pull_request"), ("GITHUB_EVENT_NAME", "pull_request_target"), ("GITHUB_REF", "refs/heads/feature")):
            with self.subTest(key=key, value=value):
                original = self.env[key]
                self.env[key] = value
                self.calls.clear()
                self.assertNotEqual(0, self.invoke()[0])
                self.assertEqual([], self.calls)
                self.env[key] = original

    def test_missing_token_invalid_sha_or_component_cannot_publish(self):
        self.env.pop("GHCR_TOKEN")
        self.assertNotEqual(0, self.invoke()[0])
        self.env["GHCR_TOKEN"] = self.canary
        self.env["GITHUB_SHA"] = "invalid"
        self.assertNotEqual(0, self.invoke()[0])
        self.env["GITHUB_SHA"] = self.sha
        self.assertNotEqual(0, self.invoke("unexpected")[0])
        self.assertEqual([], self.calls)

    def test_external_failure_returns_nonzero_without_leaking_output_and_logs_out(self):
        for operation in ("login", "build", "push", "pull", "image", "tag"):
            with self.subTest(operation=operation):
                self.calls.clear()
                self.fail_at = operation
                result, output = self.invoke()
                self.assertNotEqual(0, result)
                self.assertIn("failed", output)
                self.assertEqual("logout", self.calls[-1][0][1])

    def test_wrong_revision_never_advances_latest(self):
        self.wrong_revision = True
        self.assertNotEqual(0, self.invoke()[0])
        self.assertFalse(any(args[1] == "tag" for args, _ in self.calls))

    def test_missing_digest_or_wrong_image_id_never_advances_latest(self):
        for attribute in ("no_digest", "wrong_image_id"):
            with self.subTest(attribute=attribute):
                self.calls.clear()
                setattr(self, attribute, True)
                self.assertNotEqual(0, self.invoke()[0])
                self.assertFalse(any(args[1] == "tag" for args, _ in self.calls))
                setattr(self, attribute, False)

    def test_timeout_fails_without_forwarding_exception_text(self):
        def timeout(args, **kwargs):
            raise subprocess.TimeoutExpired(self.canary, 1)
        self.docker = timeout
        self.assertNotEqual(0, self.invoke()[0])


if __name__ == "__main__":
    unittest.main(verbosity=2)

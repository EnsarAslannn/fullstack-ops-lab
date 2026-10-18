"""Parse only the isolated restore model; never contact an Engine or database."""

import json
import os
from pathlib import Path
import secrets
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
DEPLOYMENT = ROOT / "infrastructure/deployment"


class RestoreConfigurationTests(unittest.TestCase):
    def model(self, run_id="012345abcdef", missing=None):
        config = DEPLOYMENT / "compose.restore.yaml"
        self.assertTrue(config.is_file(), "Isolated restore Compose file is missing")
        credential = "fixture-" + secrets.token_hex(24)
        settings = {
            "RESTORE_RUN_ID": run_id,
            "RESTORE_POSTGRES_IMAGE": "sha256:" + "a" * 64,
            "RESTORE_USER": "restore_lab",
            "RESTORE_DB": "restore_lab",
            "RESTORE_PASSWORD": credential,
        }
        environment = dict(os.environ)
        for key in settings:
            environment.pop(key, None)
        for key in ("COMPOSE_FILE", "COMPOSE_PROJECT_NAME", "COMPOSE_ENV_FILES"):
            environment.pop(key, None)
        environment["COMPOSE_DISABLE_ENV_FILE"] = "1"
        if missing:
            settings.pop(missing)
        with tempfile.TemporaryDirectory(prefix="fullstackops-restore-static-") as directory:
            fixture = Path(directory) / ".env.restore"
            fixture.write_text("".join(f"{key}={value}\n" for key, value in settings.items()),
                               encoding="utf-8")
            command = ["docker", "compose", "--env-file", str(fixture), "-f", str(config)]
            try:
                quiet = subprocess.run(command + ["config", "-q"], cwd=ROOT, env=environment,
                                       capture_output=True, timeout=30)
                if credential.encode() in quiet.stdout + quiet.stderr:
                    self.fail("Credential appeared in quiet output; content withheld")
                if missing:
                    self.assertNotEqual(quiet.returncode, 0, "Missing setting was accepted")
                    return
                if quiet.returncode:
                    self.fail("Restore config failed; external output withheld")
                result = subprocess.run(command + ["config", "--format", "json"], cwd=ROOT,
                                        env=environment, capture_output=True, timeout=30)
            except (OSError, subprocess.TimeoutExpired):
                self.fail("Compose unavailable or timed out; external output withheld")
            if result.returncode or credential.encode() in result.stderr:
                self.fail("Model failed or diagnostic leaked credential; output withheld")
            try:
                return json.loads(result.stdout)
            except (ValueError, UnicodeError):
                self.fail("Invalid model JSON; output withheld")

    def test_restore_cannot_build_publish_ports_or_mount_deployment_data(self):
        model = self.model()
        self.assertEqual(set(model["services"]), {"restore-postgres"})
        service = model["services"]["restore-postgres"]
        self.assertNotIn("build", service)
        self.assertFalse(service.get("ports"))
        self.assertEqual(service["image"], "sha256:" + "a" * 64)
        self.assertEqual(service["pull_policy"], "never")
        self.assertEqual(set(service["networks"]), {"restore"})
        self.assertEqual(len(service["volumes"]), 1)
        mount = service["volumes"][0]
        self.assertEqual((mount["type"], mount["source"], mount["target"]),
                         ("volume", "restore-data", "/var/lib/postgresql"))
        self.assertEqual(set(model["volumes"]), {"restore-data"})
        self.assertFalse(model["volumes"]["restore-data"].get("external"))
        self.assertTrue(model["networks"]["restore"]["internal"])

    def test_each_restore_run_owns_distinct_container_network_and_volume(self):
        models = [self.model(run_id) for run_id in ("012345abcdef", "fedcba543210")]
        names = []
        for model, run_id in zip(models, ("012345abcdef", "fedcba543210")):
            service = model["services"]["restore-postgres"]
            network = model["networks"]["restore"]
            volume = model["volumes"]["restore-data"]
            self.assertEqual(model["name"], "fullstackops-restore-" + run_id)
            for resource in (service, network, volume):
                self.assertEqual(resource["labels"]["io.fullstackops.lab"], "postgres-restore")
                self.assertEqual(resource["labels"]["io.fullstackops.restore-run"], run_id)
            owned = (service["container_name"], network["name"], volume["name"])
            self.assertTrue(all(name.startswith("fullstackops-restore-" + run_id + "-")
                                for name in owned), "Resource escaped restore namespace")
            names.append(set(owned))
        self.assertTrue(names[0].isdisjoint(names[1]), "Restore runs share resources")

    def test_required_identity_image_and_credentials_cannot_be_omitted(self):
        for key in ("RESTORE_RUN_ID", "RESTORE_POSTGRES_IMAGE", "RESTORE_USER",
                    "RESTORE_DB", "RESTORE_PASSWORD"):
            with self.subTest(setting=key):
                self.model(missing=key)

    def test_backup_material_is_ignored_and_restore_example_remains_trackable(self):
        paths = ["infrastructure/deployment/backups-private/snapshot.json",
                 "backup.pgdump", "backup.dump", "backup.backup", ".env.restore"]
        example = "infrastructure/deployment/restore.env.example"
        result = subprocess.run(["git", "check-ignore", "--no-index", "--stdin", "-z"],
                                cwd=ROOT, input=("\0".join(paths + [example]) + "\0").encode(),
                                capture_output=True, timeout=10)
        self.assertIn(result.returncode, (0, 1), "Ignore check failed")
        self.assertEqual({item.decode() for item in result.stdout.split(b"\0") if item}, set(paths))


if __name__ == "__main__":
    unittest.main()

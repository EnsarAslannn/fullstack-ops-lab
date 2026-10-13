"""Real Compose model checks; no Engine, registry pull or development env required."""

import json
import os
from pathlib import Path
import secrets
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
DEPLOYMENT = ROOT / "infrastructure/deployment"


class DeploymentConfigurationTests(unittest.TestCase):
    def model(self, deployment):
        if deployment:
            self.assertTrue((DEPLOYMENT / "compose.deploy.yaml").is_file(), "Deployment override is missing")
        credentials = ["fixture-" + secrets.token_hex(24) for _ in range(2)]
        settings = dict([
            ("POSTGRES_USER", "fixture_user"), ("POSTGRES_DB", "fixture_db"),
            ("POSTGRES_PASSWORD", credentials[0]),
            ("ASPNETCORE_ENVIRONMENT", "Production"), ("Cache__TasksTtlSeconds", "60"),
            ("GF_SECURITY_ADMIN_USER", "fixture_admin"),
            ("GF_SECURITY_ADMIN_PASSWORD", credentials[1]),
        ])
        environment = dict(os.environ)
        for key in settings:
            environment.pop(key, None)
        environment.pop("COMPOSE_PROJECT_NAME", None)
        environment.pop("COMPOSE_FILE", None)
        environment["COMPOSE_DISABLE_ENV_FILE"] = "1"
        with tempfile.TemporaryDirectory(prefix="fullstackops-deploy-config-") as directory:
            fixture = Path(directory) / "fixture.env"
            fixture.write_text("".join(f"{key}={value}\n" for key, value in settings.items()), encoding="utf-8")
            command = ["docker", "compose", "--env-file", str(fixture), "-f", str(ROOT / "compose.yaml")]
            if deployment:
                command += ["-f", str(DEPLOYMENT / "compose.deploy.yaml")]
            else:
                command += ["--project-name", "development-fixture"]
            try:
                quiet = subprocess.run(command + ["config", "-q"], cwd=ROOT,
                                       env=environment, capture_output=True, timeout=30)
                if any(value.encode() in quiet.stdout + quiet.stderr for value in credentials):
                    self.fail("Canary appeared in quiet configuration output; content withheld")
                if quiet.returncode:
                    self.fail("Compose config -q failed; external output withheld")
                result = subprocess.run(command + ["config", "--format", "json"], cwd=ROOT,
                                        env=environment, capture_output=True, timeout=30)
            except (OSError, subprocess.TimeoutExpired):
                self.fail("Compose could not run; external output withheld")
            if result.returncode:
                self.fail("Compose model validation failed; external output withheld")
            if any(value.encode() in result.stderr for value in credentials):
                self.fail("Canary appeared in configuration diagnostics; content withheld")
            try:
                return json.loads(result.stdout)
            except (ValueError, UnicodeError):
                self.fail("Compose did not return valid JSON; external output withheld")

    def test_deployment_cannot_build_share_development_volumes_or_publish_internal_ports(self):
        model = self.model(True)
        self.assertEqual(model["name"], "fullstackops-deploy-lab")
        self.assertEqual(model["networks"]["app"]["name"], "fullstackops-deploy-lab_app")
        services = model["services"]
        self.assertEqual(set(services), {"api", "frontend", "postgres", "redis", "prometheus", "grafana"})
        release = json.loads((DEPLOYMENT / "release.json").read_text(encoding="utf-8"))
        self.assertRegex(release["source_sha"], r"^[0-9a-f]{40}$")
        for name in ("api", "frontend"):
            self.assertNotIn("build", services[name])
            reference = services[name]["image"]
            self.assertRegex(reference, rf"^ghcr\.io/ensaraslannn/fullstack-ops-lab-{name}@sha256:[0-9a-f]{{64}}$")
            self.assertEqual(reference, release["images"][name]["reference"])
            self.assertEqual(release["images"][name]["revision"], release["source_sha"])
        for name in ("api", "postgres", "redis"):
            self.assertFalse(services[name].get("ports"), "Internal service has a host port: " + name)
        for name, host, internal in (("frontend", "18081", 80), ("prometheus", "19090", 9090), ("grafana", "13000", 3000)):
            ports = services[name]["ports"]
            self.assertEqual(len(ports), 1)
            self.assertEqual((ports[0]["host_ip"], str(ports[0]["published"]), ports[0]["target"]), ("127.0.0.1", host, internal))
        for key, name in (("postgres-data", "fullstackops-deploy-lab-postgres"),
                          ("prometheus_data", "fullstackops-deploy-lab-prometheus"),
                          ("grafana_data", "fullstackops-deploy-lab-grafana")):
            self.assertEqual(model["volumes"][key]["name"], name)
        self.assertTrue(model["volumes"]["postgres-data"]["external"])
        for service in services.values():
            self.assertEqual(service["networks"], {"app": None})
            for mount in service.get("volumes", []):
                if mount["type"] == "bind":
                    self.assertTrue(mount["read_only"], "Provisioning mount must be read-only")
                    self.assertTrue(Path(mount["source"]).exists(), "Provisioning source missing")

    def test_base_development_model_still_builds_and_uses_its_original_volume(self):
        model = self.model(False)
        for name in ("api", "frontend"):
            self.assertIn("build", model["services"][name])
        self.assertEqual(model["volumes"]["postgres-data"]["name"], "fullstack-ops-postgres-data")


if __name__ == "__main__":
    unittest.main()

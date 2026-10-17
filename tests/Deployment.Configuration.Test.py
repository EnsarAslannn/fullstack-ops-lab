"""Real Compose model checks; no Engine, registry pull or development env required."""

import copy
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
    def setUp(self):
        self.credentials = ["fixture-" + secrets.token_hex(24) for _ in range(2)]

    def model(self, deployment, *, https=False, tls_directory="fixture", expect_failure=False,
              selection=None):
        if deployment:
            self.assertTrue((DEPLOYMENT / "compose.deploy.yaml").is_file(), "Deployment override is missing")
        if https:
            self.assertTrue((DEPLOYMENT / "compose.https.yaml").is_file(), "HTTPS override is missing")
        if selection:
            selector = DEPLOYMENT / "releases" / f"compose.version-{selection}.yaml"
            self.assertTrue(selector.is_file(), "Release selection override is missing: " + selection)
        credentials = self.credentials
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
        environment.pop("DEPLOYMENT_TLS_DIR", None)
        environment["COMPOSE_DISABLE_ENV_FILE"] = "1"
        with tempfile.TemporaryDirectory(prefix="fullstackops-deploy-config-") as directory:
            fixture = Path(directory) / "fixture.env"
            fixture.write_text("".join(f"{key}={value}\n" for key, value in settings.items()), encoding="utf-8")
            command = ["docker", "compose", "--env-file", str(fixture)]
            if https:
                tls_fixture = Path(directory) / "https.env"
                if tls_directory == "fixture":
                    tls_directory = (Path(directory) / "missing-tls").as_posix()
                tls_fixture.write_text("" if tls_directory is None else
                                       "DEPLOYMENT_TLS_DIR=" + tls_directory + "\n", encoding="utf-8")
                command += ["--env-file", str(tls_fixture)]
            command += ["-f", str(ROOT / "compose.yaml")]
            if deployment:
                command += ["-f", str(DEPLOYMENT / "compose.deploy.yaml")]
            else:
                command += ["--project-name", "development-fixture"]
            if https:
                command += ["-f", str(DEPLOYMENT / "compose.https.yaml")]
            if selection:
                command += ["-f", str(selector)]
            try:
                quiet = subprocess.run(command + ["config", "-q"], cwd=ROOT,
                                       env=environment, capture_output=True, timeout=30)
                if any(value.encode() in quiet.stdout + quiet.stderr for value in credentials):
                    self.fail("Canary appeared in quiet configuration output; content withheld")
                if expect_failure:
                    self.assertNotEqual(quiet.returncode, 0, "Missing TLS path was accepted")
                    self.assertIn(b"DEPLOYMENT_TLS_DIR", quiet.stderr, "Expected safe missing-key diagnostic")
                    return
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
            if https:
                self.assertFalse(Path(tls_directory).exists(), "Static parsing created a TLS source directory")
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

    def test_https_adds_only_frontend_loopback_tls_and_readonly_file_mounts(self):
        plain = self.model(True)
        secured = self.model(True, https=True)
        for key in ("name", "networks", "volumes"):
            self.assertEqual(secured[key], plain[key])
        self.assertEqual(set(secured["services"]), set(plain["services"]))
        for name in ("api", "postgres", "redis", "prometheus", "grafana"):
            self.assertTrue(secured["services"][name] == plain["services"][name],
                            name + " changed; model values withheld")
        frontend = secured["services"]["frontend"]
        self.assertNotIn("build", frontend)
        self.assertEqual(frontend["image"], plain["services"]["frontend"]["image"])
        ports = {(item["host_ip"], str(item["published"]), item["target"]) for item in frontend["ports"]}
        self.assertEqual(ports, {("127.0.0.1", "18081", 80), ("127.0.0.1", "18443", 443)})
        mounts = {item["target"]: item for item in frontend["volumes"]}
        self.assertEqual(set(mounts), {"/etc/nginx/conf.d/default.conf",
                                     "/etc/nginx/deployment-tls/server.crt",
                                     "/etc/nginx/deployment-tls/server.key"})
        for mount in mounts.values():
            self.assertEqual(mount["type"], "bind")
            self.assertTrue(mount["read_only"])
            self.assertFalse(mount["bind"]["create_host_path"])
        config = Path(mounts["/etc/nginx/conf.d/default.conf"]["source"])
        self.assertEqual(config.resolve(), (DEPLOYMENT / "nginx/https.conf").resolve())
        self.assertTrue(config.is_file())
        for target, name in (("/etc/nginx/deployment-tls/server.crt", "server.crt"),
                             ("/etc/nginx/deployment-tls/server.key", "server.key")):
            source = Path(mounts[target]["source"])
            self.assertEqual(source.name, name)
            self.assertFalse(source.resolve().is_relative_to(ROOT.resolve()), "TLS material points inside repository")
        expected = dict(plain["services"]["frontend"])
        expected.pop("ports")
        actual = dict(frontend)
        actual.pop("ports")
        actual.pop("volumes")
        self.assertEqual(actual, expected, "Frontend healthcheck/runtime settings changed")

    def test_https_refuses_missing_or_empty_certificate_directory(self):
        for value in (None, ""):
            with self.subTest(tls_directory=value):
                self.model(True, https=True, tls_directory=value, expect_failure=True)

    def test_version_a_selector_preserves_the_entire_https_deployment_model(self):
        with tempfile.TemporaryDirectory(prefix="fullstackops-release-config-") as directory:
            tls_directory = (Path(directory) / "missing-tls").as_posix()
            baseline = self.model(True, https=True, tls_directory=tls_directory)
            selected = self.model(True, https=True, tls_directory=tls_directory, selection="a")
            self.assertTrue(selected == baseline, "Version A changes the deployment model; values withheld")

    def test_version_b_selector_changes_only_both_images_and_a_restores_the_model(self):
        with tempfile.TemporaryDirectory(prefix="fullstackops-release-config-") as directory:
            tls_directory = (Path(directory) / "missing-tls").as_posix()
            baseline = self.model(True, https=True, tls_directory=tls_directory)
            candidate = self.model(True, https=True, tls_directory=tls_directory, selection="b")
            record = json.loads((DEPLOYMENT / "releases/update-rollback.json").read_text(encoding="utf-8"))
            expected = copy.deepcopy(baseline)
            for name in ("api", "frontend"):
                reference = record["versions"]["B"]["images"][name]["reference"]
                self.assertRegex(reference, rf"^ghcr\.io/ensaraslannn/fullstack-ops-lab-{name}@sha256:[0-9a-f]{{64}}$")
                self.assertNotEqual(reference, baseline["services"][name]["image"])
                expected["services"][name]["image"] = reference
                self.assertEqual(record["versions"]["A"]["images"][name]["reference"],
                                 baseline["services"][name]["image"])
            self.assertTrue(candidate == expected,
                            "Version B changes more than the two images; model values withheld")
            restored = self.model(True, https=True, tls_directory=tls_directory, selection="a")
            self.assertTrue(restored == baseline, "Version A does not restore the model; values withheld")

    def test_local_tls_material_is_ignored_but_https_example_is_trackable(self):
        paths = ["infrastructure/deployment/tls-private/notes.txt",
                 ".env.https", "infrastructure/deployment/.env.https"]
        paths += ["infrastructure/deployment/server." + extension
                  for extension in ("key", "pem", "crt", "cer", "pfx", "p12", "csr", "der", "srl")]
        example = "infrastructure/deployment/https.env.example"
        result = subprocess.run(["git", "check-ignore", "--no-index", "--stdin", "-z"], cwd=ROOT,
                                input=("\0".join(paths + [example]) + "\0").encode(),
                                capture_output=True, timeout=10)
        self.assertIn(result.returncode, (0, 1), "Git ignore check could not run")
        self.assertEqual({item.decode() for item in result.stdout.split(b"\0") if item}, set(paths))


if __name__ == "__main__":
    unittest.main()

"""Isolated Compose CI acceptance. No development configuration is read.

Run prepare, test, then cleanup with the same --state directory. Cleanup also
runs from the workflow's always() step if a command or acceptance test fails.
"""

import argparse
import json
import os
from pathlib import Path
import re
import secrets
import shutil
import subprocess
import sys
import tempfile
import time
import urllib.error
import urllib.request
import uuid

ROOT = Path(__file__).resolve().parents[1]
SERVICES = {"api", "frontend", "postgres", "redis", "prometheus", "grafana"}
FIELDS = {"id", "title", "description", "isCompleted", "createdAt", "updatedAt"}
CACHE_KEY = "fullstack-ops:tasks:all:v1"
MIGRATION = "20260928113912_InitialCreate"


class AcceptanceError(Exception):
    pass


class Lab:
    def __init__(self, directory):
        self.directory = Path(directory).resolve()
        temporary_roots = {Path(tempfile.gettempdir()).resolve()}
        if os.environ.get("RUNNER_TEMP"):
            temporary_roots.add(Path(os.environ["RUNNER_TEMP"]).resolve())
        if (not self.directory.name.startswith("fullstackops-ci-") or self.directory.parent not in temporary_roots
                or self.directory == ROOT or ROOT in self.directory.parents):
            raise AcceptanceError("State directory must be a direct fullstackops-ci-* child of the system/runner temporary directory, outside the repository")
        self.state_file = self.directory / "state.json"
        self.state = json.loads(self.state_file.read_text(encoding="utf-8")) if self.state_file.exists() else None
        # Do not let inherited local configuration replace the explicit fake fixture.
        self.environment = {key: value for key, value in os.environ.items()
                            if not key.startswith(("COMPOSE_", "ConnectionStrings__", "Cache__", "POSTGRES_", "GF_SECURITY_ADMIN_"))}

    def save(self):
        self.state_file.write_text(json.dumps(self.state), encoding="utf-8")
        self.state_file.chmod(0o600)

    def run(self, arguments, *, timeout=120, data=None, environment=None, show=False):
        try:
            result = subprocess.run(arguments, cwd=ROOT, env=environment or self.environment,
                                    input=data, stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=timeout)
        except (OSError, subprocess.TimeoutExpired):
            raise AcceptanceError(f"Command could not complete: {arguments[0]}") from None
        output = result.stdout.decode("utf-8", errors="replace")
        errors = result.stderr.decode("utf-8", errors="replace")
        for canary in (self.state or {}).get("credentials", []):
            if canary in output or canary in errors:
                raise AcceptanceError("Generated credential appeared in captured command output (content withheld)")
        if result.returncode:
            # Never forward raw native stderr, HTTP bodies, config, logs or exceptions.
            raise AcceptanceError(f"Command failed: {arguments[0]}, exit={result.returncode}")
        if show:
            print(output.strip())
        return output.strip()

    def compose(self, *arguments, **options):
        return self.run(["docker", "compose", "--project-name", self.state["project"],
                         "--env-file", str(self.directory / "fixture.env"),
                         "-f", str(ROOT / "compose.yaml"), "-f", str(self.directory / "override.yaml"),
                         *arguments], **options)

    def container(self, service):
        identifier = self.compose("ps", "-a", "-q", service)
        if not re.fullmatch(r"[a-f0-9]{64}", identifier):
            raise AcceptanceError(f"Container missing: {service}")
        return identifier

    def sql(self, content):
        return self.compose("exec", "-T", "postgres", "sh", "-c",
                            'export PGPASSWORD="$POSTGRES_PASSWORD"; exec psql -h 127.0.0.1 -U "$POSTGRES_USER" -d "$POSTGRES_DB" -X -w -v ON_ERROR_STOP=1 -At -f /dev/stdin',
                            data=content.encode("utf-8"))

    def healthy(self, timeout=180):
        deadline = time.monotonic() + timeout
        while time.monotonic() < deadline:
            states = self.compose("ps", "--format", "{{.Service}}|{{.State}}|{{.Health}}")
            rows = [line.split("|") for line in states.splitlines()]
            if {row[0] for row in rows} == SERVICES and all(row[1:] == ["running", "healthy"] for row in rows):
                print("PASS six Compose services running/healthy")
                return
            time.sleep(2)
        raise AcceptanceError("Six services did not become healthy within the deadline")

    def prepare(self):
        if self.state is not None or self.directory.exists():
            raise AcceptanceError("Refusing to reuse an existing state directory")
        self.directory.mkdir(mode=0o700)
        project = "fullstackops-ci-" + uuid.uuid4().hex
        self.state = {"project": project, "volume": project + "-postgres", "volume_created": False,
                      "credentials": ["fixture-" + secrets.token_hex(24), "fixture-" + secrets.token_hex(24)]}
        self.save()
        if os.environ.get("GITHUB_ACTIONS") == "true":
            for credential in self.state["credentials"]:
                print("::add-mask::" + credential, flush=True)
        fixture = self.directory / "fixture.env"
        settings = [("POSTGRES_USER", "ci_user"), ("POSTGRES_DB", "ci_db"),
                    ("POSTGRES_PASSWORD", self.state["credentials"][0]),
                    ("ASPNETCORE_ENVIRONMENT", "Production"), ("Cache__TasksTtlSeconds", "10"),
                    ("GF_SECURITY_ADMIN_USER", "ci_admin"), ("GF_SECURITY_ADMIN_PASSWORD", self.state["credentials"][1])]
        fixture.write_text("".join(f"{key}={value}\n" for key, value in settings), encoding="utf-8")
        fixture.chmod(0o600)
        (self.directory / "override.yaml").write_text(
            'services:\n  frontend:\n    ports: !override ["127.0.0.1::80"]\n'
            '  prometheus:\n    ports: !reset []\n  grafana:\n    ports: !reset []\n'
            'volumes:\n  postgres-data:\n    name: ' + self.state["volume"] + '\n', encoding="utf-8")
        self.compose("config", "-q")
        names = self.run(["docker", "volume", "ls", "--format", "{{.Name}}"])
        if self.state["volume"] in names.splitlines():
            raise AcceptanceError("Refusing to reuse an existing PostgreSQL volume")
        # Record ownership intent first so cancellation after create cannot orphan it.
        self.state["volume_created"] = True
        self.save()
        self.run(["docker", "volume", "create", "--label", "fullstackops.ci.owner=" + project, self.state["volume"]])
        self.compose("up", "-d", "--wait", "--wait-timeout", "120", "postgres", timeout=240)
        self.run(["dotnet", "tool", "restore"])
        self.run(["dotnet", "restore", "FullStackOpsLab.slnx"], timeout=240)
        self.run(["dotnet", "build", "FullStackOpsLab.slnx", "-c", "Release", "--no-restore"], timeout=240, show=True)
        design_environment = self.environment | {
            "ASPNETCORE_ENVIRONMENT": "Production", "DOTNET_ENVIRONMENT": "Production",
            "ConnectionStrings__Postgres": "Host=127.0.0.1;Port=1;Database=preview;Username=preview",
            "ConnectionStrings__Redis": "127.0.0.1:1", "Cache__TasksTtlSeconds": "10",
            "Logging__EventLog__LogLevel__Default": "None"}
        sql_path = self.directory / "InitialCreate.sql"
        api = "src/backend/FullStackOpsLab.Api"
        self.run(["dotnet", "ef", "migrations", "script", "0", "InitialCreate", "--idempotent",
                  "--project", api, "--startup-project", api, "--configuration", "Release", "--no-build",
                  "--output", str(sql_path)], environment=design_environment)
        sql = sql_path.read_text(encoding="utf-8-sig")
        if MIGRATION not in sql or 'CREATE TABLE tasks' not in sql or '__EFMigrationsHistory' not in sql:
            raise AcceptanceError("Generated SQL does not contain the expected InitialCreate schema/history")
        self.sql(sql)
        # The same script must safely skip an already applied migration.
        self.sql(sql)
        if self.sql('SELECT count(*) FROM "__EFMigrationsHistory"; SELECT count(*) FROM tasks;') != "1\n0":
            raise AcceptanceError("Expected one applied migration and an empty isolated tasks table")
        print("PASS InitialCreate SQL reviewed, applied with ON_ERROR_STOP, idempotent reapplication and empty database verified")
        self.compose("up", "-d", "--build", "--wait", "--wait-timeout", "180", timeout=900)
        self.healthy()
        print("PASS isolated preparation; no development env, user-secrets or existing PostgreSQL volume used")

    def http(self, method, path, body=None):
        data = json.dumps(body).encode() if body is not None else None
        request = urllib.request.Request(self.state["base_url"] + path, data=data, method=method,
                                         headers={"Content-Type": "application/json"} if data else {})
        try:
            response = urllib.request.urlopen(request, timeout=20)
        except urllib.error.HTTPError as error:
            response = error
        except (OSError, TimeoutError):
            raise AcceptanceError("Nginx request failed before an HTTP response") from None
        with response:
            content = response.read().decode("utf-8")
            for credential in self.state["credentials"]:
                if credential in content:
                    raise AcceptanceError("Credential appeared in HTTP response (content withheld)")
            return response.status, json.loads(content) if content else None, response.headers

    def test(self, pwsh):
        address = self.compose("port", "frontend", "80")
        if not re.fullmatch(r"127\.0\.0\.1:\d+", address):
            raise AcceptanceError("Only an ephemeral localhost frontend port should be published")
        self.state["base_url"] = "http://" + address
        self.save()
        for service in SERVICES - {"frontend"}:
            ports = self.run(["docker", "inspect", "--format", "{{json .HostConfig.PortBindings}}", self.container(service)])
            if ports not in ("null", "{}"):
                raise AcceptanceError(f"Unexpected published host port: {service}")
        self.run([pwsh, "-NoProfile", "-File", "tests/Phase0B.Tasks.Smoke.ps1", "-BaseUrl", self.state["base_url"]], show=True)
        self.run([pwsh, "-NoProfile", "-File", "tests/Module5.Cache.Smoke.ps1", "-BaseUrl", self.state["base_url"],
                  "-RedisContainer", self.container("redis"), "-PostgresContainer", self.container("postgres"),
                  "-PostgresUser", "ci_user", "-PostgresDatabase", "ci_db"], timeout=180, show=True)
        self.run([pwsh, "-NoProfile", "-File", "tests/Module8.Readiness.Smoke.ps1",
                  "-EnvFile", str(self.directory / "fixture.env"), "-ProjectName", self.state["project"],
                  "-ComposeFile", str(ROOT / "compose.yaml"), "-OverrideFile", str(self.directory / "override.yaml"),
                  "-Dependencies", "redis"], timeout=240, show=True)
        self.healthy()
        task_id = None
        try:
            status, task, headers = self.http("POST", "/api/tasks", {"title": "CI persistence " + uuid.uuid4().hex})
            if status != 201 or set(task) != FIELDS or task["description"] is not None or not task["updatedAt"] or not task["createdAt"]:
                raise AcceptanceError("POST nullable/six-field JSON contract failed")
            task_id = task["id"]
            if headers.get("Location") != f"/api/tasks/{task_id}":
                raise AcceptanceError("POST Location contract failed")
            status, updated, _ = self.http("PUT", f"/api/tasks/{task_id}", {"title": task["title"], "description": None, "isCompleted": True})
            if status != 200 or set(updated) != FIELDS or updated["description"] is not None or not updated["isCompleted"]:
                raise AcceptanceError("PUT nullable/six-field JSON contract failed")
            api_id = self.container("api")
            self.compose("restart", "api")
            self.healthy()
            status, restored, _ = self.http("GET", f"/api/tasks/{task_id}")
            if status != 200 or restored != updated or self.container("api") != api_id:
                raise AcceptanceError("API restart did not preserve all six PostgreSQL-backed fields")
            print("PASS exact six JSON fields, nullable description, non-null timestamp contract and API restart persistence")
        finally:
            if task_id is not None and self.http("DELETE", f"/api/tasks/{task_id}")[0] != 204:
                raise AcceptanceError("Could not delete the owned persistence test task")
        if self.sql('SELECT count(*) FROM tasks; SELECT count(*) FROM "__EFMigrationsHistory";') != "0\n1":
            raise AcceptanceError("Test tasks were not cleaned or migration history changed")
        self.compose("exec", "-T", "redis", "redis-cli", "DEL", CACHE_KEY)
        metrics = self.compose("exec", "-T", "frontend", "curl", "-fsS", "http://api:8080/metrics")
        if "http_server_request_duration_seconds" not in metrics:
            raise AcceptanceError("Internal metrics unavailable")
        deadline = time.monotonic() + 60
        while time.monotonic() < deadline:
            targets = json.loads(self.compose("exec", "-T", "prometheus", "wget", "-q", "-O", "-", "http://127.0.0.1:9090/api/v1/targets"))
            if any(target["health"] == "up" and target["scrapeUrl"] == "http://api:8080/metrics" for target in targets["data"]["activeTargets"]):
                break
            time.sleep(2)
        else:
            raise AcceptanceError("Prometheus API target did not become UP")
        datasource = (ROOT / "monitoring/grafana/provisioning/datasources/prometheus.yml").read_text(encoding="utf-8")
        dashboard = (ROOT / "monitoring/grafana/dashboards/overview.json").read_text(encoding="utf-8")
        # Authenticate inside the container; credentials never appear in command arguments.
        grafana = self.compose("exec", "-T", "grafana", "sh", "-c",
                               'wget -q -O - --header="Authorization: Basic $(printf "%s:%s" "$GF_SECURITY_ADMIN_USER" "$GF_SECURITY_ADMIN_PASSWORD" | base64 | tr -d "\\n")" http://127.0.0.1:3000/api/datasources/uid/fullstack-ops-prometheus')
        if json.loads(grafana)["url"] != "http://prometheus:9090" or "fullstack-ops-prometheus" not in datasource:
            raise AcceptanceError("Grafana provisioned datasource failed")
        uid = json.loads(dashboard)["uid"]
        grafana_dashboard = self.compose("exec", "-T", "grafana", "sh", "-c",
                                         'wget -q -O - --header="Authorization: Basic $(printf "%s:%s" "$GF_SECURITY_ADMIN_USER" "$GF_SECURITY_ADMIN_PASSWORD" | base64 | tr -d "\\n")" http://127.0.0.1:3000/api/dashboards/uid/' + uid)
        if not json.loads(grafana_dashboard)["meta"]["provisioned"]:
            raise AcceptanceError("Grafana dashboard not provisioned")
        print("PASS internal metrics, Prometheus target UP, Grafana datasource/dashboard provisioning; test rows/cache cleaned")

    def diagnostics(self):
        if self.state is None:
            return
        # Allowlisted fields only: no environment, probe output, raw logs or config.
        for service in sorted(SERVICES):
            try:
                state = self.run(["docker", "inspect", "--format",
                                  '{{.State.Status}}|{{if .State.Health}}{{.State.Health.Status}}{{end}}|{{.State.ExitCode}}|{{.RestartCount}}',
                                  self.container(service)])
                print(f"DIAGNOSTIC {service}: state|health|exit|restarts={state}")
                logs = self.compose("logs", "--no-color", "--tail", "80", service)
                # Keep only known safe cache events and method/route/status lines.
                for event in re.findall(r'\[CACHE (?:HIT|MISS|INVALIDATE)\]|HTTP (?:GET|POST|PUT|DELETE) /api/tasks(?:/\{id[^}]*\})? -> \d{3}', logs):
                    print(f"DIAGNOSTIC {service}: {event}")
            except AcceptanceError:
                print(f"DIAGNOSTIC {service}: unavailable (details withheld)")

    def cleanup(self):
        if self.state is None:
            print("Cleanup: no owned state/resources")
            return
        project = self.state["project"]
        if not re.fullmatch(r"fullstackops-ci-[a-f0-9]{32}", project) or self.state["volume"] != project + "-postgres":
            raise AcceptanceError("Invalid cleanup ownership metadata")
        self.compose("down", "--timeout", "15", timeout=180)
        volumes = self.run(["docker", "volume", "ls", "--filter", "label=com.docker.compose.project=" + project, "--format", "{{.Name}}"])
        for volume in volumes.splitlines():
            if volume not in (project + "_grafana_data", project + "_prometheus_data"):
                raise AcceptanceError("Unexpected project-labelled volume; refusing deletion")
            self.run(["docker", "volume", "rm", volume])
        names = self.run(["docker", "volume", "ls", "--format", "{{.Name}}"])
        if self.state["volume_created"] and self.state["volume"] in names.splitlines():
            owner = self.run(["docker", "volume", "inspect", "--format", '{{index .Labels "fullstackops.ci.owner"}}', self.state["volume"]])
            if owner != project:
                raise AcceptanceError("PostgreSQL volume ownership mismatch; refusing deletion")
            self.run(["docker", "volume", "rm", self.state["volume"]])
        if self.run(["docker", "ps", "-a", "--filter", "label=com.docker.compose.project=" + project, "-q"]):
            raise AcceptanceError("Owned containers remain after cleanup")
        if self.run(["docker", "network", "ls", "--filter", "label=com.docker.compose.project=" + project, "-q"]):
            raise AcceptanceError("Owned network remains after cleanup")
        if self.run(["docker", "volume", "ls", "--filter", "label=com.docker.compose.project=" + project, "-q"]):
            raise AcceptanceError("Owned Compose volumes remain after cleanup")
        if self.state["volume"] in self.run(["docker", "volume", "ls", "--format", "{{.Name}}"]).splitlines():
            raise AcceptanceError("Owned PostgreSQL volume remains after cleanup")
        shutil.rmtree(self.directory)
        print("PASS cleanup: owned containers/network/three volumes and temporary configuration/SQL removed; no prune/development resources")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("action", choices=("prepare", "test", "diagnostics", "cleanup"))
    parser.add_argument("--state", required=True)
    parser.add_argument("--pwsh", default="pwsh")
    arguments = parser.parse_args()
    try:
        lab = Lab(arguments.state)
        if arguments.action == "test":
            lab.test(arguments.pwsh)
        else:
            getattr(lab, arguments.action)()
    except AcceptanceError as error:
        print("FAIL " + str(error), file=sys.stderr)
        return 1
    except Exception:
        print("FAIL unexpected acceptance error (details withheld)", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())

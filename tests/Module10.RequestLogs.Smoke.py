"""Safe API request log acceptance on the existing Compose stack; no raw errors."""
import argparse
import importlib.util
import json
import re
import sys
import time
import uuid
from datetime import datetime, timezone
from pathlib import Path

sys.dont_write_bytecode = True
spec = importlib.util.spec_from_file_location("dashboard_helpers", Path(__file__).with_name("Module10.Dashboard.Smoke.py"))
helpers = importlib.util.module_from_spec(spec)
spec.loader.exec_module(helpers)
check, docker, request, wait_for = helpers.check, helpers.docker, helpers.request, helpers.wait_for
COMPOSE = helpers.COMPOSE
LOG_PATTERN = re.compile(r"HTTP (GET|POST|PUT|DELETE|OTHER) (\S+) -> (\d{3}) in ([\d.,]+) ms")


def run(options):
    since = datetime.now(timezone.utc).isoformat()
    marker = "module10-private-" + uuid.uuid4().hex
    def logs():
        return docker(*COMPOSE, "logs", "--no-color", "--since", since, "api")
    def observed(method, route, status):
        return any((m, r, int(s)) == (method, route, status) for m, r, s, _ in LOG_PATTERN.findall(logs()))
    check(request(options.frontend, "/api/tasks", "POST", {"title": ""})[0] == 400, "Validation warmup failed")
    wait_for(lambda: observed("POST", "/api/tasks/", 400), "Safe method/template/status/duration request log is missing", 8)
    print("PASS: safe POST/400 method, template, status and duration log")
    if options.validation_only:
        return

    created_id, stopped = None, False
    try:
        code, text, headers = request(options.frontend, "/api/tasks", "POST", {"title": marker, "description": None})
        check(code == 201, "POST failed")
        created_id = json.loads(text)["id"]
        check(headers["Location"].endswith("/api/tasks/" + str(created_id)), "Location changed")
        check(set(json.loads(text)) == {"id", "title", "description", "isCompleted", "createdAt", "updatedAt"}, "Six-field contract changed")
        check(json.loads(text)["description"] is None, "Nullable description changed")
        check(request(options.frontend, "/api/tasks")[0] == 200, "List failed")
        check(request(options.frontend, f"/api/tasks/{created_id}")[0] == 200, "ID GET failed")
        check(request(options.frontend, f"/api/tasks/{created_id}", "PUT",
                      {"title": marker, "description": None, "isCompleted": True})[0] == 200, "PUT failed")
        check(request(options.frontend, f"/api/tasks/{created_id}", "DELETE")[0] == 204, "DELETE failed")
        created_id = None
        check(request(options.frontend, "/api/tasks/2147483647")[0] == 404, "Missing-ID GET failed")
        def internal(path, method="GET", body=None, private=False):
            args = ["exec", "fullstack-ops-lab-frontend-1", "curl", "-s", "--max-time", "20", "-o", "/dev/null", "-w", "%{http_code}", "-X", method]
            if private:
                args += ["-H", "Authorization: Bearer " + marker, "-H", "Cookie: lab=" + marker]
            if body is not None:
                args += ["-H", "Content-Type: application/json", "--data-binary", json.dumps(body)]
            return int(docker(*args, "http://api:8080" + path))
        check(internal("/api/tasks?private=" + marker, "POST", {"title": "", "description": marker}, True) == 400, "Private validation request failed")
        check(internal("/" + marker, private=True) == 404, "Unknown route failed")
        check(internal("/" + marker, "X" + uuid.uuid4().hex) == 404, "Unknown method failed")
        for path in ("/health", "/health/live", "/health/ready", "/metrics"):
            check(internal(path) == 200, "Normal probe failed")
        docker(*COMPOSE, "stop", "postgres")
        stopped = True
        check(internal("/api/tasks/2147483647?private=" + marker, private=True) == 500, "Controlled DB error must be 500")
        wait_for(lambda: observed("GET", "/api/tasks/{id:int}", 500), "Controlled 500 not logged accurately", 10)
        docker(*COMPOSE, "start", "postgres")
        stopped = False
        wait_for(lambda: internal("/health/ready") == 200, "Dependency did not recover", 90)
        expected = [("GET", "/api/tasks/", 200), ("POST", "/api/tasks/", 201),
                    ("GET", "/api/tasks/{id:int}", 200), ("PUT", "/api/tasks/{id:int}", 200),
                    ("DELETE", "/api/tasks/{id:int}", 204), ("POST", "/api/tasks/", 400),
                    ("GET", "/api/tasks/{id:int}", 404), ("GET", "unmatched", 404),
                    ("OTHER", "unmatched", 404), ("GET", "/api/tasks/{id:int}", 500)]
        wait_for(lambda: all(observed(*item) for item in expected), "A required request log scenario is absent", 10)
        captured = logs()
        check(marker not in captured, "Body/query/header/path canary in API logs (value withheld)")
        records = LOG_PATTERN.findall(captured)
        check(all(route in ("/api/tasks/", "/api/tasks/{id:int}", "unmatched") for _, route, _, _ in records), "Unexpected raw path or probe in request log")
        check(all(float(duration.replace(",", ".")) >= 0 for _, _, _, duration in records), "Invalid request duration")
        envs = dict(entry.split("=", 1) for entry in json.loads(docker("inspect", "--format", "{{json .Config.Env}}", "fullstack-ops-lab-api-1")))
        check(envs["ConnectionStrings__Postgres"] not in captured, "Complete connection string in API logs (value withheld)")
        print("PASS: CRUD 200/201/200/204, six-field/null/Location, 400/404/500 logs; route templates/unmatched, OTHER, nonnegative ms; probes excluded and canary absent")
    finally:
        if stopped:
            docker(*COMPOSE, "start", "postgres")
        if created_id is not None:
            check(request(options.frontend, f"/api/tasks/{created_id}", "DELETE")[0] == 204, "Own Task cleanup failed")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--frontend", default="http://127.0.0.1:18081")
    parser.add_argument("--validation-only", action="store_true")
    try:
        run(parser.parse_args())
    except AssertionError as error:
        print("FAIL: " + str(error)); sys.exit(1)
    except Exception:
        print("FAIL: request log acceptance could not complete (details withheld)"); sys.exit(1)

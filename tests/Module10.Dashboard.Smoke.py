"""Provisioned dashboard acceptance; Playwright is a separate test dependency.

Requires an isolated, healthy existing stack. Changes only its own Tasks and stops
PostgreSQL temporarily; always restores it. Never prints credentials or raw errors.
"""
import argparse
import base64
import json
import math
import subprocess
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
import uuid
from pathlib import Path


UID = "fullstack-ops-overview"
TITLE = "FullStack Ops Lab Overview"
DS_UID = "fullstack-ops-prometheus"
COMPOSE = ["compose", "--env-file", ".env"]


def check(condition, message):
    if not condition:
        raise AssertionError(message)


def docker(*args):
    result = subprocess.run(["docker", *args], capture_output=True, text=True,
                            timeout=75, creationflags=getattr(subprocess, "CREATE_NO_WINDOW", 0))
    check(result.returncode == 0, "Docker command failed (details withheld)")
    return result.stdout.strip()


def request(base, path, method="GET", body=None, headers=None):
    encoded = None if body is None else json.dumps(body).encode()
    req = urllib.request.Request(base + path, data=encoded, method=method,
                                 headers={"Content-Type": "application/json", **(headers or {})})
    try:
        response = urllib.request.urlopen(req, timeout=30)
    except urllib.error.HTTPError as error:
        response = error
    with response:
        text = response.read().decode()
        return response.status, text, response.headers


def wait_for(action, message, timeout=75):
    end = time.monotonic() + timeout
    while time.monotonic() < end:
        if action():
            return
        time.sleep(3)
    raise AssertionError(message)


def run(options):
    grafana, prometheus, frontend = options.grafana, options.prometheus, options.frontend
    envs = dict(item.split("=", 1) for item in json.loads(
        docker("inspect", "--format", "{{json .Config.Env}}", "fullstack-ops-lab-grafana-1")))
    user = envs["GF_SECURITY_ADMIN_USER"]
    admin_credential = envs["GF_SECURITY_ADMIN_PASSWORD"]
    encoded_auth = base64.b64encode((user + ":" + admin_credential).encode()).decode()
    auth = {"Authorization": "Basic " + encoded_auth}
    results = {}

    def graf(path):
        status, text, _ = request(grafana, path, headers=auth)
        check(status == 200, "Grafana authenticated API failed (details withheld)")
        check(admin_credential not in text, "Credential in Grafana response (value withheld)")
        return json.loads(text)

    status, _, _ = request(grafana, "/api/dashboards/uid/" + UID, headers=auth)
    check(status == 200, "Overview dashboard is not automatically provisioned")
    response = graf("/api/dashboards/uid/" + UID)
    dashboard = response["dashboard"]
    panels = {panel["id"]: panel for panel in dashboard["panels"]}
    check(dashboard["title"] == TITLE and response["meta"]["provisioned"], "Dashboard provisioning contract failed")
    check(len(panels) == 9 and dashboard["refresh"] == "15s", "Expected nine panels and scrape-aware refresh")
    check(all(target["datasource"]["uid"] == DS_UID for panel in panels.values()
              for target in panel["targets"]), "Panel datasource binding failed")
    print("PASS: automatic Overview dashboard, fixed UID, nine panels, datasource binding")
    if options.provisioning_only:
        return

    def query(expr):
        status, text, _ = request(prometheus, "/api/v1/query?" + urllib.parse.urlencode({"query": expr}))
        check(status == 200, "PromQL execution failed (details withheld)")
        data = json.loads(text)
        check(data["status"] == "success", "PromQL query error")
        return [float(sample["value"][1]) for sample in data["data"]["result"]]

    def panel_values(panel_id):
        return [number for target in panels[panel_id]["targets"] for number in query(target["expr"])]

    def positive(panel_id):
        return any(math.isfinite(value) and value > 0 for value in panel_values(panel_id))

    def browser(require_traffic=False):
        from playwright.sync_api import sync_playwright
        # Provisioning polling can update metadata between traffic and idle observations.
        rendered_panels = graf("/api/dashboards/uid/" + UID)["dashboard"]["panels"]
        with sync_playwright() as playwright:
            browser_instance = playwright.chromium.launch(channel="msedge", headless=True)
            context = browser_instance.new_context()
            page = context.new_page()
            errors, bad_responses, consoles = [], [], []
            page.on("pageerror", lambda error: errors.append(str(error)))
            page.on("response", lambda resp: bad_responses.append(resp.url)
                    if resp.status >= 400 and not (resp.status == 404 and
                       "/user-storage/advisor-redirect-notice" in resp.url) else None)
            page.on("console", lambda msg: consoles.append((msg.type, msg.text, msg.location.get("url", ""))))
            try:
                page.goto(grafana + "/login")
                page.wait_for_load_state("networkidle")
                page.locator('input[name="user"]').wait_for(state="visible")
                page.locator('input[name="user"]').fill(user)
                page.locator('input[name="password"]').fill(admin_credential)
                page.get_by_role("button", name="Log in", exact=True).click()
                page.wait_for_url(lambda url: "/login" not in url)
                page.goto(grafana + "/d/" + UID + "/fullstack-ops-lab-overview")
                page.wait_for_load_state("networkidle")
                for panel in rendered_panels:
                    page.get_by_text(panel["title"], exact=True).first.wait_for(state="visible")
                # Query actual provisioned expressions through Grafana's plugin, not only Prometheus.
                for panel in rendered_panels:
                    targets = [{"refId": target["refId"], "expr": target["expr"],
                                "datasource": target["datasource"], "instant": True,
                                "range": False, "format": "table"} for target in panel["targets"]]
                    plugin = context.request.post(grafana + "/api/ds/query", data={
                        "from": str(int((time.time() - 600) * 1000)), "to": str(int(time.time() * 1000)),
                        "queries": targets})
                    check(plugin.status == 200, "Dashboard datasource plugin request failed")
                    check(all(not value.get("error") for value in plugin.json()["results"].values()),
                          "Dashboard datasource plugin returned an error")
                    if require_traffic:
                        numbers = [number for value in plugin.json()["results"].values()
                                   for frame in value.get("frames", [])
                                   for field, column in zip(frame["schema"]["fields"], frame["data"]["values"])
                                   if field["type"] == "number" for number in column]
                        check(any(isinstance(number, (int, float)) and math.isfinite(number) for number in numbers),
                              "Traffic panel has no measured Grafana values")
                check(not errors and not bad_responses, "Unexpected browser or dashboard request error")
                check(all(kind != "error" or ("404" in text and
                          "/user-storage/advisor-redirect-notice:" in url) for kind, text, url in consoles),
                      "Unexpected browser console error")
                check(all(admin_credential not in text for _, text, _ in consoles), "Credential in browser console")
                print("PASS: real Edge login, all nine rendered panels and all Grafana plugin queries")
            finally:
                context.close()
                browser_instance.close()

    if options.browser_only:
        browser()
        return

    created_id = None
    postgres_stopped = False
    cache_owned = False
    status, original_text, _ = request(frontend, "/api/tasks")
    check(status == 200, "Initial Task list failed")
    original_tasks = json.loads(original_text)
    try:
        # Existing list cache is not deleted. TTL expiration naturally supplies a miss.
        wait_for(lambda: docker("exec", "fullstack-ops-lab-redis-1", "redis-cli", "--raw", "EXISTS",
                                "fullstack-ops:tasks:all:v1") == "0", "Existing cache did not expire", 180)
        cache_owned = True
        request(frontend, "/api/tasks")
        request(frontend, "/api/tasks")
        # Zero 5xx with successful traffic is a measured zero, not missing-data padding.
        title = "module10-dashboard-" + uuid.uuid4().hex
        code, text, headers = request(frontend, "/api/tasks", "POST", {"title": title, "description": None})
        check(code == 201, "Test Task POST failed")
        created_id = json.loads(text)["id"]
        check(headers["Location"].endswith("/api/tasks/" + str(created_id)), "POST Location changed")
        # New counters need a scraped baseline before later events can produce rate().
        time.sleep(17)
        for _ in range(5):
            check(request(frontend, "/api/tasks")[0] == 200, "List traffic failed")
        check(request(frontend, f"/api/tasks/{created_id}", "PUT",
                      {"title": title, "description": None, "isCompleted": True})[0] == 200, "PUT failed")
        request(frontend, "/api/tasks")
        request(frontend, "/api/tasks")
        check(request(frontend, f"/api/tasks/{created_id}", "DELETE")[0] == 204, "DELETE failed")
        created_id = None
        check(request(frontend, "/api/tasks", "POST", {"title": " "})[0] == 400, "Validation changed")
        check(request(frontend, "/api/tasks/2147483647")[0] == 404, "Missing-ID contract changed")
        wait_for(lambda: all(positive(panel_id) for panel_id in (2, 4, 5, 6, 7, 8, 9)),
                 "Traffic did not reach dashboard query results")
        check(panel_values(1) == [1.0], "API scrape is not UP")
        check(panel_values(3) == [0.0], "400/404 should not count as 5xx")
        results["traffic"] = {str(panel_id): panel_values(panel_id) for panel_id in panels}
        print("PASS: CRUD/400/404, request/p95/CPU/memory/cache rates positive, 5xx=0")
        browser(require_traffic=True)

        docker(*COMPOSE, "stop", "postgres")
        postgres_stopped = True
        api_id = docker(*COMPOSE, "ps", "-q", "api")
        for index in range(3):
            # ID GET reads the database directly; cache cannot hide this failure.
            check(request(frontend, "/api/tasks/2147483647")[0] == 500, "Expected controlled database 5xx")
            if index == 0:
                # The 5xx label series can be new after API restart; establish its baseline.
                time.sleep(17)
        wait_for(lambda: positive(3), "5xx did not reach error panel", 90)
        wait_for(lambda: docker("inspect", "--format", "{{.State.Health.Status}}", api_id) == "unhealthy",
                 "API did not become unhealthy", 90)
        check(docker("inspect", "--format", "{{.State.Status}}", api_id) == "running", "API process stopped")
        check(docker("exec", "fullstack-ops-lab-frontend-1", "curl", "-s", "-o", "/dev/null", "-w", "%{http_code}",
                     "http://api:8080/health/live") == "200", "Liveness should remain 200")
        check(docker("exec", "fullstack-ops-lab-frontend-1", "curl", "-s", "-o", "/dev/null", "-w", "%{http_code}",
                     "http://api:8080/health/ready") == "503", "Readiness should be 503 during outage")
        check(panel_values(1) == [1.0], "Scrape UP must remain independent from readiness")
        results["outage_5xx_percent"] = panel_values(3)
        print("PASS: PostgreSQL outage gives three HTTP 500s, 5xx panel >0, API running/unhealthy, scrape UP=1")
        docker(*COMPOSE, "start", "postgres")
        postgres_stopped = False
        wait_for(lambda: docker("inspect", "--format", "{{.State.Health.Status}}", api_id) == "healthy",
                 "API readiness did not recover", 90)
        check(request(frontend, "/api/tasks/2147483647")[0] == 404, "Direct database read did not recover")
        print("PASS: dependency recovered; same API healthy and direct DB GET 404")

        # No API user traffic for >2m; Docker health and Prometheus scrape continue.
        print("Observing a 150-second traffic-free window (health/scrape probes remain)...", flush=True)
        idle_end = time.monotonic() + 150
        while time.monotonic() < idle_end:
            time.sleep(min(15, max(0, idle_end - time.monotonic())))
        for panel_id in (3, 4, 8):
            values = panel_values(panel_id)
            check(not values or all(not math.isfinite(value) for value in values),
                  "Idle ratio/p95 must remain missing/NaN rather than false zero")
        check(panel_values(2) == [0.0], "Idle request rate must be zero; probes must be excluded")
        results["idle"] = {str(panel_id): [value if math.isfinite(value) else None
                                           for value in panel_values(panel_id)] for panel_id in panels}
        print("PASS: idle request rate=0; 5xx/p95/cache ratio empty or NaN; no fake zero")
        browser()
        check(json.loads(request(frontend, "/api/tasks")[1]) == original_tasks, "Existing Task records changed")
        logs = docker(*COMPOSE, "logs", "--no-color", "grafana", "api")
        check(admin_credential not in logs and encoded_auth not in logs, "Credential in service logs (value withheld)")
        if options.results_file:
            Path(options.results_file).write_text(json.dumps(results, indent=2, allow_nan=False), encoding="utf-8")
    finally:
        if postgres_stopped:
            docker(*COMPOSE, "start", "postgres")
        if created_id is not None:
            check(request(frontend, f"/api/tasks/{created_id}", "DELETE")[0] == 204, "Own Task cleanup failed")
        if cache_owned:
            docker("exec", "fullstack-ops-lab-redis-1", "redis-cli", "DEL", "fullstack-ops:tasks:all:v1")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--grafana", default="http://127.0.0.1:3000")
    parser.add_argument("--prometheus", default="http://127.0.0.1:9090")
    parser.add_argument("--frontend", default="http://127.0.0.1:18081")
    parser.add_argument("--provisioning-only", action="store_true")
    parser.add_argument("--browser-only", action="store_true")
    parser.add_argument("--results-file")
    try:
        run(parser.parse_args())
    except AssertionError as error:
        print("FAIL: " + str(error))
        sys.exit(1)
    except Exception:
        print("FAIL: dashboard acceptance could not complete (details withheld)")
        sys.exit(1)

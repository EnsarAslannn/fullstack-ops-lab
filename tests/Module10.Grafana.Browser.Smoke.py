"""Real-browser acceptance. Install Playwright outside project dependencies; never print credentials."""
import argparse
import json
import math
import subprocess
import sys
import time
import uuid

from playwright.sync_api import sync_playwright


def docker(*args):
    result = subprocess.run(["docker", *args], capture_output=True, text=True, timeout=30,
                            creationflags=getattr(subprocess, "CREATE_NO_WINDOW", 0))
    if result.returncode:
        raise RuntimeError("Docker check failed; details withheld")
    return result.stdout.strip()


def check(condition, message):
    if not condition:
        raise AssertionError(message)


def run(options):
    values = dict(entry.split("=", 1) for entry in json.loads(
        docker("inspect", "--format", "{{json .Config.Env}}", options.container)))
    user = values["GF_SECURITY_ADMIN_USER"]
    admin_credential = values["GF_SECURITY_ADMIN_PASSWORD"]
    errors, failed_requests, console_messages = [], [], []
    task_id, cache_owned = None, False
    with sync_playwright() as playwright:
        browser = playwright.chromium.launch(channel="msedge", headless=True)
        context = browser.new_context()
        page = context.new_page()
        page.on("pageerror", lambda error: errors.append(str(error)))
        page.on("requestfailed", lambda request: failed_requests.append((request.url, request.failure)))
        page.on("console", lambda message: console_messages.append((message.type, message.text, message.location.get("url", ""))))
        try:
            page.goto(options.url + "/login")
            page.wait_for_load_state("networkidle")
            page.locator('input[name="user"]').wait_for(state="visible")
            page.locator('input[name="user"]').fill(user)
            page.locator('input[name="password"]').fill(admin_credential)
            page.get_by_role("button", name="Log in", exact=True).click()
            page.wait_for_url(lambda url: "/login" not in url, timeout=30000)
            page.wait_for_load_state("networkidle")
            account = context.request.get(options.url + "/api/user")
            check(account.status == 200 and account.json()["isGrafanaAdmin"], "Browser admin login failed")
            check(account.json()["login"] == user, "Unexpected browser account")
            print("PASS: real Edge browser admin login (credentials hidden)")

            page.goto(options.url + "/connections/datasources")
            page.wait_for_load_state("networkidle")
            page.get_by_text("Prometheus", exact=True).first.wait_for(state="visible")
            sources = context.request.get(options.url + "/api/datasources")
            check(sources.status == 200 and len(sources.json()) == 1, "Datasource was not provisioned")
            source = sources.json()[0]
            check(source["uid"] == "fullstack-ops-prometheus" and source["url"] == "http://prometheus:9090"
                  and source["isDefault"] and source["readOnly"], "Datasource contract failed")
            print("PASS: provisioned Prometheus visible in browser; stable UID/default/read-only")

            if options.seed_test_metrics:
                key = "fullstack-ops:tasks:all:v1"
                check(docker("exec", options.redis_container, "redis-cli", "--raw", "EXISTS", key) == "0",
                      "Use an isolated stack without an existing list cache")
                cache_owned = True
                for _ in range(2):
                    check(context.request.get(options.frontend_url + "/api/tasks").status == 200, "List request failed")
                created = context.request.post(options.frontend_url + "/api/tasks",
                                               data={"title": "module10-grafana-" + uuid.uuid4().hex,
                                                     "description": None})
                check(created.status == 201, "Test Task creation failed")
                task_id = created.json()["id"]
                check(context.request.delete(options.frontend_url + f"/api/tasks/{task_id}").status == 204,
                      "Test Task deletion failed")
                task_id = None
                time.sleep(17)

            for metric in ("http_server_request_duration_seconds_count",
                           "dotnet_process_memory_working_set_bytes",
                           "fullstackops_cache_hits_total", "fullstackops_cache_misses_total",
                           "fullstackops_cache_invalidations_total"):
                expression = metric + '{job="fullstack-ops-api"}'
                response = context.request.post(options.url + "/api/ds/query", data={
                    "from": str(int((time.time() - 300) * 1000)), "to": str(int(time.time() * 1000)),
                    "queries": [{"refId": "A", "datasource": {"type": "prometheus", "uid": "fullstack-ops-prometheus"},
                                 "expr": expression, "instant": True, "range": False, "format": "table",
                                 "intervalMs": 15000, "maxDataPoints": 100}]})
                check(response.status == 200, "Grafana datasource plugin query failed")
                result = response.json()["results"]["A"]
                check(not result.get("error") and result.get("frames"), "Datasource query has no frames")
                numeric = [column for frame in result["frames"] for field, column in
                           zip(frame["schema"]["fields"], frame["data"]["values"]) if field["type"] == "number"]
                check(any(isinstance(value, (int, float)) and math.isfinite(value)
                          for column in numeric for value in column), "Datasource query has no finite measured values")
                check(admin_credential not in response.text() and user not in response.text(), "Credential leak in query response")
                print(f"PASS: Grafana /api/ds/query {metric}; numeric columns={len(numeric)}")

            expected_aborts = [(url, reason) for url, reason in failed_requests
                               if url == options.url + "/public/build/img/icons/unicons/sort-amount-up.svg"
                               and reason == "net::ERR_ABORTED"]
            check(not errors and len(expected_aborts) == len(failed_requests), "Unexpected browser script or network failure")
            expected_console = [(kind, text, url) for kind, text, url in console_messages
                                if kind == "error" and "404" in text
                                and "/user-storage/advisor-redirect-notice:" in url]
            check(sum(kind == "error" for kind, _, _ in console_messages) == len(expected_console),
                  "Unexpected browser console error")
            for _, text, _ in console_messages:
                check(user not in text and admin_credential not in text, "Credential leak in browser console")
            print(f"PASS: zero unexpected browser errors; navigation SVG aborts={len(expected_aborts)}, "
                  f"expected missing advisor preferences={len(expected_console)}; credentials absent from console")
        finally:
            if task_id is not None:
                check(context.request.delete(options.frontend_url + f"/api/tasks/{task_id}").status == 204,
                      "Test Task cleanup failed")
            if cache_owned:
                docker("exec", options.redis_container, "redis-cli", "--raw", "DEL", "fullstack-ops:tasks:all:v1")
            context.close()
            browser.close()


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--url", default="http://127.0.0.1:3000")
    parser.add_argument("--frontend-url", default="http://127.0.0.1:18081")
    parser.add_argument("--container", default="fullstack-ops-lab-grafana-1")
    parser.add_argument("--redis-container", default="fullstack-ops-lab-redis-1")
    parser.add_argument("--seed-test-metrics", action="store_true")
    try:
        run(parser.parse_args())
    except AssertionError as error:
        print("FAIL: " + str(error))
        sys.exit(1)
    except Exception:
        print("FAIL: browser acceptance could not complete (details withheld)")
        sys.exit(1)

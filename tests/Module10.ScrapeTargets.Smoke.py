"""Exercise wrong DNS, port and path on a disposable internal Prometheus instance."""
import argparse
import importlib.util
import json
import shutil
import sys
import tempfile
import time
import uuid
from urllib.parse import urlencode
from pathlib import Path

sys.dont_write_bytecode = True # Test helpers must not leave binary artifacts in the repository.
spec = importlib.util.spec_from_file_location("dashboard_helpers", Path(__file__).with_name("Module10.Dashboard.Smoke.py"))
helpers = importlib.util.module_from_spec(spec)
spec.loader.exec_module(helpers)
check, docker, wait_for = helpers.check, helpers.docker, helpers.wait_for


def run(options):
    folder = Path(tempfile.mkdtemp(prefix="fullstackops-scrape-")).resolve()
    # Docker accepts longer names, but one DNS label must fit in 63 characters.
    name = "fullstackops-scrape-lab-" + uuid.uuid4().hex[:12]
    running = False
    observations = []
    api_id = docker(*helpers.COMPOSE, "ps", "-q", "api")
    network = next(iter(json.loads(docker("inspect", "--format", "{{json .NetworkSettings.Networks}}", api_id))))
    image = docker("inspect", "--format", "{{.Image}}", "fullstack-ops-lab-prometheus-1")

    def configure(target="api:8080", path="/metrics"):
        (folder / "prometheus.yml").write_text(
            'global:\n  scrape_interval: 15s\n  scrape_timeout: 10s\nscrape_configs:\n'
            '  - job_name: fullstack-ops-api\n    metrics_path: ' + path + '\n'
            '    static_configs:\n      - targets: ["' + target + '"]\n', encoding="utf-8")
        if running:
            docker("exec", name, "/bin/promtool", "check", "config", "/lab/prometheus.yml")
            docker("kill", "--signal", "HUP", name)

    def endpoint(path):
        return json.loads(docker("exec", "fullstack-ops-lab-frontend-1", "curl", "-s", "--max-time", "15", "http://" + name + ":9090" + path))

    def target():
        data = endpoint("/api/v1/targets")
        check(data["status"] == "success" and len(data["data"]["activeTargets"]) == 1, "Expected one diagnostic target")
        return data["data"]["activeTargets"][0]

    def state(expected, url, error=""):
        try:
            t = target()
            return t["health"] == expected and t["scrapeUrl"] == url and (not error or error in t["lastError"].lower())
        except (AssertionError, ValueError):
            return False

    def up(instance):
        # A reloaded target can coexist with its previous series until staleness is recorded.
        query = 'up{job="fullstack-ops-api",instance="' + instance + '"}'
        data = endpoint('/api/v1/query?' + urlencode({"query": query}))
        check(data["status"] == "success" and len(data["data"]["result"]) == 1, "Expected diagnostic up sample")
        return float(data["data"]["result"][0]["value"][1])

    try:
        configure()
        docker("run", "-d", "--rm", "--name", name, "--network", network,
               "--mount", "type=bind,source=" + str(folder) + ",target=/lab,readonly",
               "--memory", "256m", "--cpus", "1", image,
               "--config.file=/lab/prometheus.yml", "--storage.tsdb.path=/prometheus",
               "--storage.tsdb.retention.time=1h")
        running = True
        wait_for(lambda: state("up", "http://api:8080/metrics"), "Diagnostic baseline scrape not UP", 75)
        for scenario, destination, path, fragment in (
            ("service-name", "module10-api-missing-" + uuid.uuid4().hex[:8] + ":8080", "/metrics", "lookup"),
            ("port", "api:18080", "/metrics", "connection refused"),
            ("metrics-path", "api:8080", "/module10-metrics-missing", "404")):
            configure(destination, path)
            url = "http://" + destination + path
            wait_for(lambda: state("down", url, fragment), "Wrong target did not produce expected scrape failure", 75)
            failed = target()
            check(up(destination) == 0, "Bad diagnostic target must have up=0")
            check(docker("inspect", "--format", "{{.State.Status}}", api_id) == "running", "API must stay running")
            live = docker("exec", "fullstack-ops-lab-frontend-1", "curl", "-s", "-o", "/dev/null", "-w", "%{http_code}", "http://api:8080/health/live")
            check(live == "200", "API live must stay 200 despite wrong scrape target")
            observations.append({"scenario": scenario, "url": url, "up": 0, "last_error": failed["lastError"], "failed_scrape": failed["lastScrape"]})
            print("PASS: " + scenario + ": API running/live=200, diagnostic target DOWN/up=0; lastError=" + failed["lastError"], flush=True)
            configure()
            wait_for(lambda: state("up", "http://api:8080/metrics"), "Restored target did not recover", 75)
            check(up("api:8080") == 1, "Restored diagnostic up must be 1")
            observations[-1]["recovered_scrape"] = target()["lastScrape"]
            print("PASS: restored api:8080/metrics -> UP/up=1", flush=True)
        check(docker(*helpers.COMPOSE, "ps", "-q", "api") == api_id, "API was replaced")
        if options.results_file:
            Path(options.results_file).write_text(json.dumps(observations, indent=2), encoding="utf-8")
    finally:
        if running:
            docker("stop", name) # --rm removes only this container and its own anonymous image volume, if any.
        check(folder.parent == Path(tempfile.gettempdir()).resolve() and folder.name.startswith("fullstackops-scrape-"), "Unsafe temporary cleanup path")
        shutil.rmtree(folder)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--results-file")
    try:
        run(parser.parse_args())
    except AssertionError as error:
        print("FAIL: " + str(error)); sys.exit(1)
    except Exception:
        print("FAIL: diagnostic scrape acceptance could not complete (details withheld)"); sys.exit(1)

# Project Status

## Status

Module 10 — Completed; Module 11 — Completed (mandatory CI acceptance verified; fork/hard-timeout/production limits documented)

## Current Phase

Troubleshooting Labs — PROJECT_SPEC.md section 11

## Current Step

Troubleshooting 1 — Wrong Localhost completed; current Compose failure/fix verified with unchanged API image and preserved data/configuration/resources

## Completed

- GitHub repository created
- Local repository connected
- Project specification added
- Agent instructions added

- .NET solution and ASP.NET Core API skeleton created

- `GET /health` and development OpenAPI document verified

- React + TypeScript + Vite skeleton created

- Backend and frontend builds verified

- Root README, Git ignore rules, and API smoke check added

- In-memory Task CRUD endpoints implemented and verified with real HTTP requests

- Title validation, 404 responses, and process-restart data loss verified

- Task API HTTP examples and smoke check added

- React frontend connected to the Task API through the Vite development proxy

- Task list, create, complete/reopen, and delete flows verified in a browser

- Loading, empty, validation, error, and disabled-button states verified

- Phase 0 final acceptance verified: clean baseline, builds, API smoke checks, browser flows, health, and OpenAPI

- Module 1A verified with the official Nginx image: pull, run, HTTP, logs, inspect, exec, stop, start, restart, and remove

- `fullstack-ops-nginx-lab` removed after the lab; `nginx:stable-alpine` retained locally

- Module 2A single-stage .NET 10 SDK Dockerfile and context-specific `.dockerignore` created

- `fullstack-ops-api:baseline` built twice and measured; cache, image history, health, and Development OpenAPI verified

- `fullstack-ops-api-baseline` container removed after verification; baseline image retained for comparison

- Module 2B backend Dockerfile split into SDK build and ASP.NET runtime stages

- Baseline and multi-stage images measured; multi-stage content size fell by 236,911 MB (71,11%)

- Health, OpenAPI, and Task CRUD smoke checks passed on both images; SDK and source absent from final runtime image

- Both test containers removed; both comparison images retained locally

- Module 2C frontend image built with a Node.js build stage and Nginx runtime stage

- Frontend image measured twice; HTTP assets, desktop/mobile layout, and expected standalone `/api` error state verified

- Frontend test container removed; frontend image and both backend comparison images retained locally

- Module 2 final acceptance verified: local builds, cached image builds, backend health/OpenAPI/CRUD, frontend assets, and expected standalone `/api` 404

- Backend and frontend test containers removed; all three Module 2 images retained for comparison

- Module 3A PostgreSQL 18 Alpine container lifecycle tested with an automatically created anonymous volume

- `lab_tasks` row survived stop/start; remove/recreate attached a different anonymous volume and the table was absent

- Both Module 3A anonymous volumes and the test container removed; the PostgreSQL image retained locally

- Module 3B named volume `fullstack-ops-postgres-data` created and mounted at `/var/lib/postgresql`

- `lab_tasks` row survived container remove/recreate when the same named volume was explicitly remounted

- Module 3B test container removed; named volume and PostgreSQL image retained locally

- Module 3C backend contract, schema, credentials, migrations, verification, and phased integration plan documented without changing application code or PostgreSQL data

- Module 3D development PostgreSQL credential renewed and verified with SCRAM TCP authentication; real connection string stored only in local user-secrets

- EF Core 10 design-time support, Npgsql provider, local dotnet-ef tool, TaskEntity, and AppDbContext added without migrations or persistent CRUD

- Release build, EF model SQL generation, health/OpenAPI, and existing in-memory Task smoke tests passed; `tasks` table remains absent

- Module 3D PostgreSQL container removed; named volume and image retained locally

- Module 3E `InitialCreate` migration reviewed and explicitly applied; `tasks` and `__EFMigrationsHistory` created while `lab_tasks` was preserved

- All five Task endpoints use async EF Core and preserve the existing HTTP contract; in-memory task list, counter, and lock removed

- Persistence test failed with 404 before conversion, then passed after API restart; PostgreSQL stop/start also preserved the task

- Release build and existing smoke tests passed; test tasks and PostgreSQL test container removed, named volume and image retained

- Module 3F final acceptance verified migration state, Release build, health/OpenAPI, CRUD, API restart, PostgreSQL stop/start, outage/recovery, and concurrent database-generated IDs

- Module 3F test tasks and acceptance container removed; Module 3B lab row, migration history, named volume, and PostgreSQL image retained

- Module 4A user-defined bridge and container DNS verified with a freshly built backend image and existing PostgreSQL named volume

- Backend health, OpenAPI, Task CRUD, validation, and missing-ID responses passed through container-name PostgreSQL access; host PostgreSQL port stayed closed

- Module 4A test tasks, containers, network, and temporary external env file removed; named volume, PostgreSQL image, and networking backend image retained

- Module 4 critical localhost error observed with the same backend image: health 200, Task GET 500, connection refused at backend loopback while PostgreSQL was ready

- Correct container DNS host restored Task CRUD, OpenAPI, validation, and 404 responses; test task, containers, network, and temporary env files removed

- Module 4 DNS and diagnostic tools verified Docker embedded DNS, successful and failed name resolution, open and closed TCP ports, PostgreSQL readiness, and real Task SQL flow

- Diagnostic containers, network, temporary env file, test task, and lab-only BusyBox image removed; PostgreSQL named volume and application images retained

- Module 5 Redis lab verified PING, SET, GET, TTL expiry, and DEL on a localhost-only disposable cache container

- `GET /api/tasks` now uses a 60-second configurable cache-aside list key; POST, PUT, and DELETE invalidate after successful PostgreSQL writes

- Real Redis/PostgreSQL smoke verified empty and populated hits, expiration, 400/404 non-invalidation, CRUD, Redis outage/recovery, and preserved PostgreSQL data

- Module 6 frontend Nginx serves React assets and preserves `/api/tasks` when proxying to the backend over a user-defined Docker network

- Only frontend `127.0.0.1:18081:80` was published; API, PostgreSQL, and Redis communicated on the internal network

- Nginx CRUD, validation, Redis cache behavior, real browser flows, 390 px layout, backend outage/recovery, and wrong-hostname 502 were verified

- Module 6 test tasks, Redis key, diagnostic and application containers, test network, and temporary files removed; PostgreSQL named volume retained

- Module 7 four-service Compose application plan documented without creating a Compose file or starting services

- The plan covers DNS naming, localhost-only frontend port, external PostgreSQL volume, explicit migrations, health/dependency checks, configuration safety, Redis cache limits, and acceptance tests

- Module 7 first Compose definition added for `frontend`, `api`, `postgres`, and `redis`, with a single bridge network and existing external PostgreSQL volume

- Nginx upstream changed to Compose service DNS `api:8080`; placeholder configuration and static Compose validation completed without starting services or running migrations

- Module 7 runtime acceptance passed: four healthy Compose services, single localhost frontend port, service DNS, Nginx assets and CRUD, Redis cache invalidation, and API/Redis/PostgreSQL restarts

- Compose down/up preserved the Task through the existing external PostgreSQL volume; acceptance tasks and Redis key were removed, `lab_tasks` and `InitialCreate` were preserved, and final Compose containers/network were removed

- Chrome flows, real empty state, loading, disabled controls, error/retry, and 390 px layout were verified; a Chrome DELETE abort event occurred despite confirmed HTTP 204 and successful deletion

- Module 8 baseline showed the API stayed running and Docker-healthy with `/health` 200 while Redis or PostgreSQL was stopped and an uncached Task GET returned 500

- `/health/live` preserves process-only liveness; `/health/ready` checks PostgreSQL and Redis and drives the Compose API healthcheck without changing the existing `/health` contract

- Redis and PostgreSQL outages each produced readiness 503 and Docker unhealthy; both recovered to 200 and healthy on the same API container

- Module 8 smoke, Release build, Phase 0A/0B and EF foundation smoke checks passed; Task test data/cache were cleaned and the Module 3B row and migration history were preserved

- Module 9 configuration and secret key sources, precedence, local/Compose flows, exposure surfaces, onboarding gaps, and prioritized risks documented without implementation changes

- Module 9 configuration contract validates PostgreSQL, Redis and cache TTL at API startup with secret-safe errors; 20 isolated scenarios, Compose CRUD/cache/readiness regression, real 60-second Redis TTL and cleanup passed

- Module 9 local .env preflight checks Git exclusion, required Compose values, silent Compose configuration and existing external volume; seven isolated fixtures and the local read-only check passed without changing secret sources

- Module 9 secret leakage regression check scans tracked and non-ignored new text files without printing values; 15 isolated fixture cases and the current repository scan passed

- Module 9 initial clean-machine documentation step covered volume, credentials, PostgreSQL-first startup, reviewed InitialCreate SQL, four-service acceptance and host flow; only secret-free SQL generation was executed at that step

- Module 9 production secret approach documented without vault, file-provider or Compose secrets integration

- Module 9 isolated bootstrap on the same host used a committed clone, separate fake configuration, a new empty external volume and unique Compose project; PostgreSQL TCP authentication, first/repeated InitialCreate SQL and deliberate SQL-error exit 3 passed

- Module 9 final acceptance passed four healthy services, Nginx CRUD and six-field contract, 59-second remaining Redis TTL for a 60-second configuration, invalidation, health and down/up persistence; configuration 20/20, preflight 10/10 and secret fixtures 15/15 passed with Release build 0 warnings/errors

- Module 9 test containers/network/volume/images and temporary files removed; real .env and user-secrets hashes unchanged, development volume unused, original containers/volumes/images and project networks preserved; built-in bridge network ID changed for an unconfirmed reason during the experiment

- Module 9 completed; separate clean-machine/VM and production deployment remain outside the verified scope

- Module 10 first step verified existing Docker/Compose logs, safe state/health/probe/restart/network inspect and a timestamped four-service resource snapshot without adding monitoring components

- Module 10 Nginx test Task CRUD passed; controlled API logs showed 2 misses, 1 hit and 3 invalidations; Module 8 Redis/PostgreSQL outages and recovery passed on the same running API container, with HTTP readiness 503 distinguished from Docker probe timeouts

- Module 10 test Task/cache cleaned, initially absent stack removed and external PostgreSQL volume preserved; existing Task/lab/migration rows and secret hashes unchanged, original 12 containers/7 networks/19 volumes retained including unchanged default bridge ID

- Module 10 backend metrics use .NET built-in HTTP/Kestrel/runtime meters and custom cache counters through OpenTelemetry; internal Prometheus text endpoint verified without publishing an API port or changing Nginx

- Module 10 metrics smoke verified histogram count/status/template/buckets, cache hit/miss/empty-hit/invalidation and failed-operation accounting, real 60-second TTL expiration, process-restart reset and secret/canary absence

- Module 10 Nginx CRUD, six-field/nullable contract, Module 8 dependency outage/recovery and 20 isolated configuration scenarios passed; Release build had 0 warnings/errors; test data/cache/containers cleaned, external volume and secret hashes preserved

- Module 10 Prometheus v3.13.4 LTS configured with a version-controlled 15-second api:8080/metrics scrape, localhost-only UI, named TSDB volume, retention and resource limits; promtool/preflight/Compose configuration passed and five services were healthy

- Module 10 Prometheus smoke passed successive UP scrapes, query API HTTP/runtime/cache series, scraped CRUD counter increases, finite rate/p95/cache-ratio queries, API DOWN/up=0 and recovery, and Redis outage with live 200/ready 503/API unhealthy while metrics remained UP

- Module 10 TSDB historical sample survived down/up; test rows/cache and newly created monitoring test volume cleaned, original 12 containers/7 networks/19 volumes and external PostgreSQL/secret sources preserved; initial Engine versus pre-stack bridge ID differed for an unconfirmed reason, saved snapshot and cleanup IDs matched

- Module 10 Grafana 13.2.3 added with localhost-only UI, verified image health tooling, read-only YAML Prometheus datasource UID fullstack-ops-prometheus and Compose-managed grafana_data; six services healthy, anonymous datasource access 401, no dashboard added

- Module 10 Grafana admin placeholders/preflight updated; 19 isolated fixtures passed including separate ignored Grafana env support, original .env/user-secrets untouched; scoped INFO logger filters stopped observed admin-username logging without disabling WARN/ERROR

- Module 10 real Edge login, finite HTTP/runtime/cache queries through Grafana plugin and datasource proxy, restart and down/up provisioning/account persistence passed; only observed SVG cancellation and missing advisor-preference 404 were classified as expected browser behavior

- Module 10 Grafana test rows/cache/containers/network and newly created monitoring test volumes cleaned; existing PostgreSQL data/volume and original 12 containers/19 volumes preserved; only built-in bridge ID changed for an unconfirmed reason

- Module 10 Grafana local admin keys subsequently prepared by the user outside Git; normal .env preflight and silent Compose config passed at final review. User reported successful local login and datasource API test, then shut down the stack with compose down; secret scan and diff check passed

- Module 10 Overview dashboard provisioned through read-only provider/JSON mounts with stable dashboard and datasource UIDs; nine Turkish panels use real HTTP histogram, process CPU/working set and cache metrics, 2-minute rate windows and 15-second refresh

- Module 10 dashboard browser/plugin and controlled CRUD/cache acceptance passed; PostgreSQL outage produced real Task HTTP 500s and positive 5xx percentage while the same API remained running/unhealthy and scrape UP=1; live 200/ready 503 and dependency recovery verified

- Module 10 traffic-free observation preserved zero event/request rates and empty/NaN ratios/p95 without fake zeros; Grafana restart and Compose down/up automatically restored the Overview dashboard in a new container with existing volumes preserved

- Module 10 dashboard test Tasks/cache cleaned; original Task/lab/migration rows, .env/user-secrets hashes, 12 unrelated containers, seven network IDs and 21 existing volumes preserved; stack returned to its initially stopped state, no pruning or volume deletion

- Module 10 final review: Release build 0 warnings/errors, configuration 20/20, env preflight 19/19, secret fixtures 15/15, silent Compose config and promtool passed; six-service health, internal metrics, real Edge dashboard/plugin queries and controlled CRUD/cache traffic verified

- Final review PostgreSQL outage: three HTTP 500s, live 200, ready 503, API running/unhealthy and Prometheus up=1; same API recovered. Idle rates were zero while ratios/p95 remained NaN; observed HTTP counter reset 21 to 7 with resets=1 and rate matched raw-sample reset correction

- The 3 October final review identified four gaps; the 4 October acceptance below closed them without changing API/cache/metrics contracts or moving to Module 11

- Module 10 cumulative hit/miss/invalidation count panels added without changing the original nine panels; actual counters 6/5/6 and all twelve Grafana browser/plugin queries passed

- Safe request summaries use the existing ILogger pipeline: standard method, route template/unmatched, final status and duration; real CRUD, 400/404/500, private canary absence and probe exclusions verified

- Separate temporary Prometheus tests verified wrong service-name, port and metrics path DOWN/up=0 while the same API stayed running/live200; each correct api:8080/metrics target recovered UP/up=1

- Three visually reviewed real browser PNGs retained as Module 10 documentation evidence; exact-path PNG safety checks and four fixtures added without weakening credential rules

- Gap closure Release build 0 warnings/errors, configuration 20/20, preflight 19/19, secret fixtures 19/19, normal preflight/config/promtool/internal metrics and six-service health passed

- Test Task/cache and temporary resources cleaned; original Task/lab/migration rows and .env/user-secrets hashes preserved; initially absent stack removed, all original 12 unrelated container states, 7 network IDs and 21 volume names unchanged

- Module 10 completed; known runtime/short-sample/secret-scanner limitations documented, no Module 11 implementation started

- Module 11 planning completed: specification minimum mapped to Linux backend/frontend/Docker/config checks and Windows configuration/secret fixture checks; test portability, isolated future Compose smoke prerequisites, permissions, tools and cache decisions documented. No CI workflow created or executed; Module 11 implementation and hosted-runner acceptance not started

- Module 11A baseline workflow added with push/pull_request, contents:read and full official action SHAs. Run 37196281851 on commit 4b81604db117fd7adf80c637126e79f0ea475655 succeeded: Linux backend/frontend/Docker/config/promtool and Windows repository secret check, 19 secret fixtures and 20 configuration cases; both Release builds 0 warnings/errors. Module 11 overall remains in progress; no Compose runtime integration started

- Module 11B isolated Compose runtime CI completed: run 37198834372 passed unchanged Linux/Windows baseline jobs plus Ubuntu six-service runtime. InitialCreate application/idempotent reapply, Nginx CRUD/Location/six-field nullable contract/400/404, Redis miss/hit/TTL10/invalidation, Redis outage same-container readiness recovery, API restart persistence and monitoring provisioning passed. Owned container/network/three volume/temp cleanup passed; real development config/data preserved. Module 11 final acceptance not started

- Module 11 final acceptance completed on 5 October 2026: existing push runs matched their commit SHAs; draft same-repository PR #2 triggered pull_request run 37290500053 with all three jobs successful. Head 3749afa5c07e103ae54e3a9d7c44bb11eec00d05, actual merge checkout b25c5967f90b6c19b4ea0d4fb7f50dc67cfa43c0. Mandatory backend/frontend/Docker/config/promtool plus 20 configuration, 19 secret fixtures and isolated migration/CRUD/cache/readiness/restart/provisioning/cleanup accepted. Temporary PR closed without merge and both branches deleted; main unchanged. Only final acceptance documentation changed, no new commit/main push or local runtime experiment

- Troubleshooting 1 Wrong Localhost evidence and documentation review completed: existing Module 4 connection-refused/fix/CRUD evidence mapped to the required nine-section standalone scenario; current postgres:5432 target and Module 8 liveness/readiness/cache distinctions documented. Initial runtime confirmation was blocked by unavailable Docker Engine; the continuation below resolved this blocker

- Troubleshooting 1 current Compose runtime completed on 5 October 2026 UTC10:22:20–10:23:28: PostgreSQL ready/healthy, temporary localhost:5432 API running/unhealthy, health/live200, ready503, uncached single-Task GET500, loopback5432/connection-refused/safe request log verified. Restored postgres:5432 without override on identical image sha256:5730b7c36af841167b20ad1733694d6f6253da989ccef04a4179de229ca1511c: ready200/healthy/GET404. No mutations or list GET; DB row snapshots unchanged, Redis DBSIZE0/0, protected file hashes and all original 12 container states/7 network IDs/21 volume names unchanged. Initially absent stack and temporary files cleaned; no commit/push or second scenario

## Next Goal

On explicit request: review the three Wrong Localhost documentation files before committing. Do not proceed to Troubleshooting 2 automatically.

## Blockers

None for Troubleshooting 1 mandatory acceptance: Docker Engine/Compose and normal preflight restored; actual wrong-host and recovery evidence passed. Cache-hit masking under wrong localhost was intentionally not exercised; direct-DB single GET was used to preserve cache. Historical Module 4 DNS/CRUD evidence reused, no claim that every diagnostic command was rerun.

None for mandatory Module 11 acceptance. Limits: real fork PR, main-target PR/synchronize, branch protection, deliberate failing hosted job/failure diagnostics and runner-loss/hard-timeout cleanup remain NOT VERIFIED. Same-repository temporary-base PR and cleanup after the two observed cancellations passed. No unit-test coverage, comprehensive secret detection or production CD is claimed. GHCR publishing is optional and not implemented.

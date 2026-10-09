# Project Status

## Status

Mandatory technical final acceptance — Completed (6 October 2026, same-host clean remote clone and isolated data); manual learning assessment — NOT VERIFIED. Module 10/11 and mandatory troubleshooting acceptance remain Completed. Overall learning/closure is not automatically Completed.

## Current Phase

Final acceptance — technical section30/31/37 acceptance completed; manual section32 learning review pending

## Current Step

Optional GHCR registry runtime acceptance completed (9 October 2026): published source4606fa2358ed2f559b96b2cd89f1801ef9c5e733/run37755926772, API/frontend digest pull and running image identities PASS; six isolated services healthy, explicit InitialCreate, API health/readiness, frontend assets and Nginx CRUD/Location/JSON/400/404 PASS. Existing-identity and anonymous digest pulls PASS; package visibility/repository metadata API NOT VERIFIED. Historical mandatory acceptance and pending manual learning review remain separate. No application/Compose/publishing workflow/development-secret changes, deployment/tag/release or commit/push.

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

- Troubleshooting 2 Lost PostgreSQL Data documented and mandatory scope accepted from existing evidence: Module 3A different anonymous mount/table absent while old volume remained, Module 3B same named mount/row preserved, Module 7 actual API Task preserved after Compose down/up. Standard nine-section scenario distinguishes wrong target, missing schema and missing record. Negative API wrong-volume, old-volume recovery/transfer and backup restore remain NOT VERIFIED extra scope. No Docker, migration, env/user-secrets or development-volume operations

- Troubleshooting 3 Redis Connection Failure completed on 5 October 2026 using temporary Compose inheritance/override and separate tmpfs Redis: live200/ready503/list500, running-unhealthy API, ready Redis/PONG, Redis CLI DNS exit1 and explicit name-resolution error. Recovery used redis:6379 mapped only inside the diagnostic API to the test Redis, same API image, ready200/healthy/list200 twice, CACHE MISS/HIT and TTL60. No Task writes; DB row/configuration hashes, original container ID/state/RestartCount, network IDs and volume names unchanged, main Redis DBSIZE0/0; all original six services left healthy/running. Only own cache key and diagnostic resources cleaned. Separate network/closed-port tests and supplementary final500 request-log matcher not claimed; no application/Compose edits or commit/push

- Troubleshooting 4 Nginx 502 documented and mandatory scope accepted using existing Module 6 diagnostic wrong-hostname GET502/could-not-resolve log, separate backend-stop static200/API504/connecting-timeout and recovery200 evidence, plus Module 7 real api:8080 GET200/POST201 routing. Nine-section scenario separates historical container names from current Compose, status codes from causes, and historical runtime from today's static review. No repeat wrong-target or same-diagnostic-container recovery claimed; no Docker lifecycle/HTTP/Task/cache/configuration changes. Initially running six-service stack preserved

- Troubleshooting 5 completed on 5 October 2026 UTC11:59:06–12:00:35: separate db-startup-da7ba6a694 project/owner-labelled temporary volume/fake credential, existing InitialCreate SQL1059 bytes reviewed/applied before API traffic, schema/history/test row true|1|1. With temporary service_started/gated PostgreSQL: real pg_isready2/no-response before/after measurements, live200/ready503/uncached single-Task GET500, API running/unhealthy, connection-refused/PostgreSQL-unavailable logs, no missing-table error. Gate release recovered same API container live/ready/GET200/healthy. Correct service_healthy kept API created while PostgreSQL not ready, then API StartedAt12:00:15.295005268 after PG success probe12:00:14.826880993; all endpoints200, same API image. All original 18 container ID/state/RestartCount, 8 network IDs, 21 volume names and 38 image/tag entries preserved, six original services running/healthy. Only owned test resources and temporary files cleaned; no development env/user-secrets/volume/cache usage, application/Compose changes or commit/push

- Troubleshooting 6 documented on 5 October 2026 using existing configuration20/20 (16 safe negative exits and 4 valid-start/readiness503 cases), updated preflight19/19, Module 9 bootstrap and Troubleshooting 1/3 wrong-target runtime evidence. Nine-section scenario separates missing/empty/placeholder/malformed from valid-but-wrong host/credential, startup validation from readiness, host user-secrets from Compose substitution/service environment, and ConnectionStrings:Postgres from its double-underscore environment key. Initialized-volume env edits do not rotate role credentials; no intentional wrong-password or production rotation test claimed. Only documentation changed; real env/user-secrets/Docker/data/cache untouched, no repeat runtime/build or commit/push

- Troubleshooting 7 completed on 5 October 2026 using Module 10 wrong-name/port/path evidence and isolated monitor-flow-3cb1cccc2a45 acceptance through the actual Grafana datasource: API running/healthy/live200, target DOWN/up0/HTTP404, datasource OK, historical samples retained; correct target recovered UP/up1 and new POST400 counter3→8/sample1791204947.584 verified through Grafana. Three reviewed browser PNGs retained; narrow exact-path scanner fixtures added. Only own test resources cleaned; original Docker inventory and six healthy services preserved, no development secret/data/configuration changes or general project closure

- Final documentation prepared on 6 October 2026: root README now describes the actual six-service system, staged first-install requirements, local URLs, CI badge and lab/troubleshooting links. docs/architecture.md adds real topology/cache/health/metrics/volume flows, Mermaid diagrams, DoD review and an inline glossary; docs/commands-cheatsheet.md separates routine lifecycle from destructive operations. All eleven lab READMEs map the fourteen section12 headings and include interview/exercise entries; original command blocks and runtime measurements retained. Module9 current onboarding updated for Grafana credentials/six services and existing monitoring-volume deletion risk. Seven troubleshooting nine-section records remain unchanged. No application/Compose/workflow/secret changes or final runtime demo.

## Final Documentation Review

6 October 2026 scope decisions explicitly accepted by the user and recorded in PROJECT_SPEC.md section8. Updated only affected architecture/service lists, prepared-environment startup target, Quick Start, migration preparation and section30/31/37 acceptance requirements. Existing fifteen documentation changes preserved; sixteen documentation files including the specification are in this commit scope. Application code, Compose architecture, .env, user-secrets and volume contents unchanged. Project NOT marked Completed.

Documentation checks PASS (6 October 2026): 329 local links/anchors across the current specification/docs/labs/troubleshooting; 11/11 lab canonical section12 headings, seven unchanged nine-section troubleshooting documents and unchanged original lab command blocks verified. Nineteen PowerShell blocks parsed without executing them. Repository secret scan exit0, git diff check exit0 and ignored/untracked .env verified without reading its values. Exactly sixteen documentation files changed/new. Existing module/CI evidence is historical, not a new final runtime acceptance. Latest previously observed push run 37432761687 on 2df477ccbfbc7b7e2dde8cdeb90965960c9ac0f5 had three successful jobs; the documentation push CI result is reported separately without a repeated run-link commit cycle.

At that documentation review the runtime demo and learning review were pending. The subsequent technical final acceptance below completes the runtime/evidence matrix; learning remains pending. Both scope decisions are resolved; no separate nginx service or zero-preparation installer is required. No production/coverage/fork/restore claims are added. Independent glossary file omitted using section9 repository simplification; terms preserved in architecture.md, not deleted.

## Technical Final Acceptance — 6 October 2026

PASS on remote main 92e98a10d072c4e53dc6223c1cde8c490cfd586d, UTC08:48:24–09:10:34. Fresh HTTPS clone, unique Compose project and three volumes, generated fake credentials, isolated localhost ports. Real first-install env/preflight/empty external PostgreSQL/TCP auth/InitialCreate SQL review/apply/idempotent-reapply preceded six-service healthy startup. Release build0warnings/0errors; Docker builds used cache. Nginx CRUD/Location/exact-six-field nullable contract/400/404, cache miss/hit/TTL60/mutation invalidation passed; PG recreate preserved Task ID4 and all fields on the same test volume. Module8 Redis outage: same API running/live200/ready503/unhealthy/GET500, then ready200/healthy/GET200. Real Edge loading/disabled/empty/create/complete/reopen/delete/reload and API-stop504/error/retry passed. Internal metrics/OpenAPI, Prometheus multiple scrapes and actual Grafana datasource/12 panel queries passed. Wrong scrape path yielded up0/HTTP404 with API ready200 and datasourceOK; Grafana recovery count3→13/sample1791277665.516 after marker1791277652.715152 proves fresh data. One harness log-name expectation and one recovery timeout were explicitly corrected/rechecked without application/config changes.

Only demo Task/cache/container/network/three-volume/two-image/temp resources cleaned. Before/after inventory exactly18containers/8networks/21volumes/38image-tag entries with identical IDs/states/ports; default bridge unchanged. Development .env/user-secrets/volume untouched; captured command/service/frontend-browser canary checks clean. Same-SHA hosted run37436957155 success for all three jobs; no repeated workflow/runtime experiments or new Git operation. Final docs:370 local links/anchors, secret check exit0 and diff check exit0; exactly six documentation files, index untouched. Full PASS/FAIL/NOT VERIFIED matrix, prior evidence links and limits: docs/final-acceptance.md. Manual knowledge answers not evaluated; technical PASS is not learning PASS.

## Backend Integration Tests — 7 October 2026

Added `tests/FullStackOpsLab.Api.IntegrationTests` to the solution with xUnit/WebApplicationFactory and real isolated PostgreSQL 18/Redis 8 Testcontainers. Existing InitialCreate migration applied only inside the fixture's temporary PostgreSQL; tmpfs storage, random localhost DB/Redis ports, generated fake credentials, Production test host, no development .env/user-secrets/volume usage. No API source, frontend, Compose or contract changes. Twenty-one cases PASS, zero FAIL/SKIP: CRUD/Location/exact six JSON fields, nullable description/legacy UpdatedAt, blank title/no mutations, 404, malformed JSON, eight safe configuration failures and one valid disconnected startup. Generated canary/full test connection string absent from captured negative exception chains; test providers disabled, setup/cleanup errors sanitized. This is not production log-redaction or code-coverage acceptance.

Release solution build PASS: zero warnings/errors. The exact Linux CI `dotnet test --no-build --no-restore` command also passed all21 locally. Existing CI jobs/action SHAs/permissions/Compose runtime smoke preserved; one Linux test step added. New hosted CI NOT VERIFIED because no commit/push was requested. Historical final acceptance and manual learning limits remain separate. Repository secret scanner and diff check passed; automatic fixture disposal preserved the original Docker container IDs/states, networks and volumes. Docker Desktop was started for verification; original containers remained stopped. NuGet/Docker sandbox access was resolved through scoped execution permissions; initial test comparison and EF dependency alignment issues fixed only in the test project.

## Optional GHCR Publishing — 7 October 2026

User requested registry publishing after integration test commit/push. Integration commit9e5e2ea2bd4a898fce5a68b6ceedb128cc4571d2 pushed to origin/main; run37593868455 succeeded for Linux build/config, Windows configuration/secrets and isolated Compose runtime; hosted xUnit21 PASS/0 FAIL/0 SKIP. Publishing implementation adds one main-push-only matrix job after all three CI gates, packages:write only on that job, unchanged SHA-pinned checkout, temporary GITHUB_TOKEN login over stdin and isolated Docker auth cleanup. API/frontend images use ghcr.io/ensaraslannn/fullstack-ops-lab-{api,frontend}, full SHA and latest tags; digest pull/image ID/source revision checked before advancing latest. No deployment, package visibility change, app/Compose/secret-source changes or new GitHub secret.

Local checks: seven publishing unittest methods with fake Docker boundary PASS (event/ref/input/failure/timeout/digest/ID/revision/canary/cleanup); actionlint1.7.12 checksum verified and workflow passed (shellcheck unavailable); repository secret/diff checks passed. Initial Windows sandbox fixture cleanup issue resolved with scoped execution permissions, six own fixtures removed. No real registry call performed locally. After authorized commit/push, https://github.com/EnsarAslannn/fullstack-ops-lab/actions/runs/37597426324 completed success for all five runner jobs on1a9d57400e920263d227ed6383301bf72940aa25. Both images uploaded with SHA/latest and authenticated registry digest pull/image ID/revision verification passed; exact digest evidence is in the Module11 README. Existing CLI could not read package metadata; visibility/repository metadata and anonymous pull NOT VERIFIED, no permission/credential changes made. Prior Module11/final acceptance remains historical. Test/build publishing uses the same source commit but rebuilds images; mutable base tags and non-atomic two-component publication are documented limitations.

## Comment Cleanup — 8 October 2026

Removed explanatory comments from39 tracked application, configuration, ignore, workflow and test/script files. Preserved C# compiler directives and generated-code markers, HTTP request separators, string literals and Python docstrings (several CLI help descriptions use __doc__). Configuration keys/values, action SHAs, API/Compose behavior and documentation content are unchanged apart from this verification record. Real .env/user-secrets were not read or modified; no commit/push.

Verification PASS: Release solution build0warnings/0errors; TypeScript/Vite frontend build; publishing safety7/7; secret fixtures23/23; isolated configuration startup20/20 with safe negative messages and no canary output; Compose config -q using only .env.example placeholders; repository secret scan and diff check. PowerShell14 files preserved non-comment executable tokens, Python7 files preserved exact ASTs, TypeScript4 files preserved tokens and3 tsconfigs preserved parsed settings, C#14 files changed only comment-only lines, and test project XML settings were equivalent. Initial sandbox child-process build restrictions were resolved through scoped execution permissions. Docker Engine was unavailable; container integration/Compose runtime and volume-dependent env preflight smoke were not rerun or claimed as PASS. Only owned temporary verification files were created and removed; no Docker lifecycle/resource changes.

## GHCR Registry Runtime Acceptance — 9 October 2026

Verified successful existing main publish run37755926772 on source4606fa2358ed2f559b96b2cd89f1801ef9c5e733, without creating a new workflow/run/publication. API digest062314cb87f6a727a7a9fc271005862e7e750b220a58a53ed9afc3c39183d43e and frontend digeste72f4795363d30e613cc2192c3073895d7b2d037d31c04c2e11f78b4b3f74901 pulled by exact reference; both revision labels and running container image IDs matched. Existing Docker identity and separate empty-auth anonymous pulls passed; current CLI package metadata access failed, so the visibility setting itself remains NOT VERIFIED. No PAT/login/visibility change.

Existing Compose acceptance script gained optional digest inputs and registry-test while its CI default build/test mode remains unchanged. Generated fixture credentials, unique project/empty PostgreSQL external test volume and separate monitoring volumes were used; no development env/user-secrets/data source accessed. Host migration-only Release build0warnings/0errors, explicit InitialCreate SQL reviewed/applied twice idempotently, six services healthy, internal health/live/ready200, frontend HTML/JS/CSS200 with correct MIME types, reused Phase0B CRUD/Location/400/404 and additional exact six-field/null-description POST/PUT/GET passed. API/frontend Docker build was disabled both in override and with --no-build; exact refs were verified. Publishing safety7/7, registry safety7/7, secret fixtures23/23, repository scanner and diff check passed; no credential/canary values printed.

Owned records/cache cleaned (tasks0/history1), six containers/one network/three volumes and temporary configuration/SQL/auth/inventory removed. Only the two newly pulled digest references were removed locally after identity checks; published registry images unchanged. Initial18 exited containers,8 networks with same IDs,21 volumes and38 image-list entries restored; external development volume and unrelated resources preserved. Docker Engine was initially off, started hidden for the authorized acceptance and left reachable. Same-host/cache-bearing acceptance; no renewed full browser/monitoring/outage/production acceptance. Details and commands: [Module11 GHCR registry runtime record](labs/11-github-actions/README.md#registry-image-runtime-kabulü--9-ekim-2026).

## Next Goal

Manual learning review remains pending: user answers the specification's learning questions and explains the existing exercises. Optional registry runtime acceptance is complete; package metadata inspection remains an access limitation, while anonymous pulls are verified. Do not implement deployment or create a release/tag automatically.

## Blockers

None for mandatory technical final acceptance. Manual learning answers remain NOT VERIFIED. Same-host clean-clone acceptance does not establish clean VM/empty-cache/production/unit-test coverage/real fork/main-target PR/backup-restore or performance guarantees. A recovery browser timeout passed the affected recheck; its precise transient cause was not established. No application/Compose change was required.

None for Troubleshooting 7 mandatory acceptance: 5 October 2026 UTC12:54:27–12:55:56 isolated monitor-flow-3cb1cccc2a45 six-service/new-three-volume/fake-credential experiment passed. Wrong path kept same API running/healthy/live200; Prometheus DOWN/up0/HTTP404 while actual Grafana datasource OK and all12 panel queries error-free, two historical samples and old graphs/counts retained. Correct api:8080/metrics recovered at12:55:47.584503431; after12:55:34.836735 controlled POST400 counter3→8 and new sample1791204947.584 verified through Grafana. Three visually reviewed PNGs, exact-path scanner checks and fixtures; initial18 containers/8 networks/21 volumes/38 image-tag entries and six healthy services preserved, only own test resources/tooling cleaned. Limits: no separate datasource transport outage, long retention/outage/load or comprehensive OCR/secret assurance; general closure not started.

None for Troubleshooting 6 mandatory acceptance using existing Module 9 runtime and current source evidence. Limits: no new intentional wrong-password/rotation experiment, exhaustive placeholder/provider-option or all-runtime-log redaction acceptance; syntax validation and preflight cannot prove authentication/readiness. No live resources or secret sources used or changed.

None for Troubleshooting 5 mandatory acceptance. Controlled startup (not an outage of a running API) and same-API recovery verified; service_healthy waits initially and does not promise automatic later outage recovery or migration readiness. Limits: deterministic entrypoint gate, not natural initialization/crash-recovery/load testing. Original stack and development sources preserved, all owned test resources removed.

None for Troubleshooting 4 mandatory acceptance using existing Module 6/7 evidence. Limits: no repeated wrong-hostname experiment in today's Compose, no claim of fixing/retesting the same diagnostic Nginx container, and no tests of other possible 502/504 causes. Main config remains api:8080; existing runtime routing evidence is sufficient, and initial stack state is preserved.

None for Troubleshooting 3 mandatory hostname acceptance. Wrong hostname: Redis PONG/healthy, explicit DNS failure, API running/unhealthy, live200, ready503, list500. Correct redis:6379 in diagnostic override: same image, recreated diagnostic API healthy/ready200, list200 twice, MISS/HIT and TTL60. Separate wrong-network/closed-port and an extra final500 request-log matcher remain NOT VERIFIED; the specification's hostname alternative is satisfied. Existing six services/data/cache/configuration and Docker resources preserved; temporary test resources removed.

None for Troubleshooting 2 mandatory acceptance using existing Module 3A/3B/7 evidence. Limits: negative API wrong-volume, old anonymous-volume recovery/transfer and backup restore were not tested and are not claimed as PASS; no new runtime acceptance required by this scenario's specification.

None for Troubleshooting 1 mandatory acceptance: Docker Engine/Compose and normal preflight restored; actual wrong-host and recovery evidence passed. Cache-hit masking under wrong localhost was intentionally not exercised; direct-DB single GET was used to preserve cache. Historical Module 4 DNS/CRUD evidence reused, no claim that every diagnostic command was rerun.

None for mandatory Module 11 acceptance. Limits: real fork PR, main-target PR/synchronize, branch protection, deliberate failing hosted job/failure diagnostics and runner-loss/hard-timeout cleanup remain NOT VERIFIED. Same-repository temporary-base PR and cleanup after the two observed cancellations passed. No code-coverage measurement, comprehensive secret detection or production CD is claimed. Optional GHCR publishing and registry runtime have separate PASS evidence above; anonymous digest access PASS on9October, package metadata API access NOT VERIFIED.

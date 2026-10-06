# FullStack Ops Lab — Genel Final Kabul

## Sonuç ve test edilen sürüm

**Teknik final kabul: PASS — 6 Ekim 2026.** Manuel öğrenme değerlendirmesi **NOT VERIFIED**; geliştiricinin cevapları henüz alınmadı. Projenin bütün kapanış maddeleri Completed sayılmaz.

- Remote `main`, HTTPS üzerinden ayrı temiz klasöre clone edildi; başlangıç Git durumu temizdi.
- Test edilen commit: `92e98a10d072c4e53dc6223c1cde8c490cfd586d` (`docs: finalize architecture scope and setup requirements`).
- Deney/cleanup aralığı: **08:48:24–09:10:34 UTC / 11:48:24–12:10:34 Europe/Istanbul**.
- Ana çalışma alanı başlangıçta temizdi. Test clone'undaki tracked dosyalar deney boyunca değişmedi. Yalnız ignored test `.env`, override ve Prometheus fixture'ı eklendi.
- Bu rapor ve ana belgelerdeki sonraki düzeltmeler yalnız dokümantasyondur; uygulama, Compose, instrumentation ve API sözleşmesi değiştirilmedi. Yeni bir uygulama sürümüne eski SHA'nın kanıtı aktarılmadı.

Otorite: [şartname başarı kriterleri](../PROJECT_SPEC.md#30-başarı-kriterleri), [final demo](../PROJECT_SPEC.md#31-final-demo-senaryosu), [final checklist](../PROJECT_SPEC.md#37-final-checklist), [kabul edilen kapsam](../PROJECT_SPEC.md#final-kapsam-kararları--6-ekim-2026).

## İzolasyon ve başlangıç

Docker CLI 29.6.1 / Compose 5.3.0 kurulu, Engine başlangıçta kapalıydı. `docker version` pipe bulunamadı hatası verdi; sandbox dışında da aynı sonuç görüldü. `docker desktop start` ile Engine başlatıldı. Envanter ancak Engine erişimi sağlandıktan sonra alınabildi; Engine kapalıyken container durumu varsayılmadı.

| Kaynak | Demo değeri / koruma |
| --- | --- |
| Compose project | `fullstackops-ci-de6945e9c25d460d9490d33b17d5dc3c` — yalnız bu demo için UUID |
| Boş external PostgreSQL volume | `fullstackops-ci-de6945e9c25d460d9490d33b17d5dc3c-postgres`; owner label doğrulandı |
| Prometheus volume | `fullstackops-ci-de6945e9c25d460d9490d33b17d5dc3c_prometheus_data` |
| Grafana volume | `fullstackops-ci-de6945e9c25d460d9490d33b17d5dc3c_grafana_data` |
| Geçici frontend | `127.0.0.1:54430:80` |
| Geçici Prometheus | `127.0.0.1:55112:9090` |
| Geçici Grafana | `127.0.0.1:55113:3000` |
| API / PostgreSQL / Redis host yayını | Yok; container portları 8080 / 5432 / 6379 |
| Credential | Yalnız çalışma anında üretilen sahte test değerleri; **[REDACTED]** |

Override, yalnız clone'da external volume adını, üç localhost portunu ve geçici Prometheus config mount'unu değiştirdi. Servis adları, datasource UID, API/cache sözleşmesi ve altı servisli mimari korundu. Ana stack durdurulmadı; development volume'una bağlanılmadı. Test portları cleanup sonrasında kullanım adresleri değildir.

## İlk kurulum — gerçekten yürütülen sıra

[Module 9 rehberi](../labs/09-environment-configuration/README.md#13-temiz-bilgisayar-kurulum-rehberi) izlendi; izolasyon için açık volume/override parametreleri kullanıldı.

| Adım | Gerçek sonuç |
| --- | --- |
| Araçlar, remote clone | Git, Engine/Compose, host .NET SDK10.0.401; local dotnet-ef10.0.12 restore edildi; temiz remote SHA kaydedildi |
| Env hazırlığı | `.env.example` içeriğinden yeni ignored `.env` hazırlandı; Compose placeholder'ları sahte değerlerle dolduruldu, mevcut dosya ezilmedi; host connection placeholder'ları kullanılmadı |
| External volume | İsmin başlangıç volume listesinde olmadığı kontrol edildi; yalnız benzersiz test volume'u oluşturuldu |
| Statik kapı | Normal env preflight, quiet Compose config ve clone repository secret kontrolü exit0; preflight volume/override parametreleriyle çalıştı |
| Yalnız PostgreSQL | `up --no-deps --wait` ile yalnız postgres çalıştı; API/frontend trafiği açılmadı; pg_isready bağlantı kabul etti |
| Boş veri ve credential | Container içinden TCP psql SELECT1 başarılı; public tablo sayısı0; henüz schema yoktu |
| SQL üretimi | Mevcut InitialCreate'dan idempotent SQL üretildi; yalnız design-time process Production + credential içermeyen preview ayarları kullandı; user-secrets yüklenmedi/değişmedi |
| SQL inceleme ve uygulama | tasks'ın altı alanı, primary key, timestamp türleri, migration history ve koşullu transaction incelendi; ilgisiz DROP yok; UTF-8 stdin + ON_ERROR_STOP ile uygulandı |
| İkinci SQL uygulaması | İdempotent tekrar başarılı; tek `20260928113912_InitialCreate` history kaydı ve tasks0 doğrulandı |
| Build / normal start | Backend Release build **0 warning, 0 error**; iki multi-stage image Compose build ile üretildi; frontend npm ci/TypeScript/Vite layer'ları cached; altı servis healthy |
| Prometheus syntax | Container içindeki promtool check config başarılı |

İlk kurulumda atlanan zorunlu adım veya uygulama/config düzeltmesi gerekmedi. Cache kullanıldı: bu sonuç boş image/package cache deneyi değildir. InitialCreate yeniden oluşturulmadı ve API startup'a migration eklenmedi.

### Önemli komutlar ve amaçları

Gerçek komut ailesi aşağıdadır; `$demoProject`, `$demoVolume`, `$override`, `$sqlPath` yalnız bu deneyin yollarını/adlarını temsil eder. Secret değerleri ve tamamlanmış connection string verilmez.

| Komut | Amaç / gözlem |
| --- | --- |
| `git clone --branch main --single-branch --depth 1 <remote-url> <ayrı-klasör>`; `git rev-parse HEAD` | Remote temiz sürüm ve tam SHA |
| `docker ps -a`, `docker network ls`, `docker volume ls`, `docker image ls` (seçilmiş formatlar) | Secret environment göstermeden önce/sonra envanter |
| `docker volume create --label <demo-owner> $demoVolume` | Yokluğu doğrulanmış boş external test volume'u |
| `powershell -File scripts/Module9.EnvPreflight.ps1 -VolumeName $demoVolume -ComposeOverrideFile .env.final-override.yaml` | Gerçek clone env, ignored/untracked durumu, placeholder/config/volume kapısı |
| `docker compose --project-name $demoProject --env-file .env -f compose.yaml -f $override config -q` | Çözümlenmiş credential yazmadan Compose modeli |
| Aynı Compose prefix'iyle `up -d --no-deps --wait --wait-timeout 120 postgres` | Migration'dan önce yalnız DB |
| `dotnet tool restore`; `dotnet restore FullStackOpsLab.slnx` | Host EF CLI ve backend bağımlılıkları |
| `dotnet ef migrations script 0 InitialCreate --idempotent --project src/backend/FullStackOpsLab.Api/FullStackOpsLab.Api.csproj --startup-project src/backend/FullStackOpsLab.Api/FullStackOpsLab.Api.csproj --output $sqlPath` | İzole design-time configuration ile mevcut migration SQL'i |
| `psql -h 127.0.0.1 -X -w -v ON_ERROR_STOP=1 -f /dev/stdin` (test postgres içinde) | Container environment'dan credential, UTF-8 stdin; ilk/tekrar migration ve SELECT kontrolleri |
| `dotnet build FullStackOpsLab.slnx -c Release --no-restore` | Gerçek Release build |
| Compose prefix'iyle `up --build -d --wait --wait-timeout 180` | Hazırlanmış altı servisli sistem |
| `tests/Phase0B.Tasks.Smoke.ps1 -BaseUrl <demo-frontend>` | Mevcut gerçek HTTP CRUD/400/404 smoke'u yeniden kullanıldı |
| `tests/Module8.Readiness.Smoke.ps1` (demo env/project/override, Dependencies redis) | Mevcut altı servis uyumlu kesinti/same-container recovery testi |
| `promtool check config`; yalnız demo Prometheus'a `docker kill --signal HUP <demo-prometheus>` | Geçici yanlış path/doğru path syntax ve reload |
| `docker compose ... down --timeout 15` | Yalnız demo container/ağlarını kaldırma; `-v` kullanılmadı |
| `docker volume rm <doğrulanmış-üç-demo-volume>`; `docker image rm <iki-demo-image-tag>` | Owner/isim kontrolüyle demo kaynakları; prune yok |

Geçici Python harness'i mevcut CI helper'larını kullandı; özel kabul komutlarının nonzero/timeout/canary kapıları vardı. Headless Edge için Playwright yalnız geçici venv'e kuruldu, frontend package dosyalarına eklenmedi. Test SQL/env/harness/venv/clone görev sonunda temizlendi.

## Gerçek bütünleşik sonuçlar

### HTTP, browser ve cache

- GET200, POST201 + `/api/tasks/{id}` Location, PUT200, DELETE204, boş başlık400 ve bulunmayan ID404 geçti. Gerçek JSON alanları: id/title/description/isCompleted/createdAt/updatedAt; description null kabul edildi, iki timestamp null değildi.
- Browser'da gerçek GET kısa süre tutulurken loading ve disabled form gözlendi; gerçek POST tutulurken mutation disabled kontrolü yapıldı. Yanıtlar mock edilmedi, aynı API'ye iletildi.
- Gerçek Edge: empty → oluştur → tamamla → reload → yeniden aç → sil → empty başarılı. Boş başlık arayüzde engellendi. Normal akışta console error, başarısız HTTP ve page exception sayısı0.
- Yalnız demo API durdurulduğunda frontend liste isteği Nginx **504** aldı, anlaşılır error/retry gösterdi; aynı API yeniden başlatılıp healthy olduktan sonra retry empty listeyi getirdi. Bu tek deneyde gözlenen 504, bütün Nginx arızaları için evrensel neden değildir.
- Cache ilk GET miss/key oluşması, ikinci GET hit, başarılı POST/PUT/DELETE sonrası key yokluğu, 400/404 sonrasında key korunması ve boş liste cache'i doğrulandı. Gerçek TTL **60 saniye**, configuration60 ile uyumlu. `[CACHE MISS]`, `[CACHE HIT]`, `[CACHE INVALIDATED]` gözlendi. TTL sona erme ve DB kapalıyken cache-hit deneyleri bu görevde tekrar edilmedi; önceki Module5/CI kanıtı kullanılır.

### PostgreSQL, health ve runtime

Görev **ID4**, description null ve completed true dahil altı alanı kaydedildi. PostgreSQL container ID'si `e7e9c78b0484…` → `6872de4595d8…` değişti; aynı test volume'u `/var/lib/postgresql` hedefine bağlı kaldı. Tekil GET200 döndü ve alanlar birebir eşitti. Liste cache'i bu kalıcılık kanıtının yerine kullanılmadı.

| Durum | API process | /health ve live | ready | Docker API health | Liste GET |
| --- | --- | --- | --- | --- | --- |
| Bağımlılıklar hazır | running | 200 | 200 | healthy | 200 |
| Redis kontrollü stop | aynı container running | 200 | 503 | unhealthy | 500 |
| Redis start/recovery | aynı container running | 200 | 200 | healthy | 200 |

Internal `/metrics` HTTP/runtime/cache serilerini, Development OpenAPI tasks yollarını verdi. API final image'ında `dotnet --list-sdks` boş; frontend final image'ında Node/npm ve uygulama build kaynakları yoktu. Health başarıları şema doğrulamasının yerine konmadı.

### Prometheus → gerçek Grafana datasource → dashboard

- İki ayrı başarılı scrape, target UP/up1 ve gerçek HTTP/runtime/cache serileri doğrulandı.
- Sabit datasource UID `fullstack-ops-prometheus`, URL `http://prometheus:9090`; Overview UID `fullstack-ops-overview`, provisioned=true, **12 panel**.
- Edge login ve dashboard açılışı baseline, arıza ve recovery'de başarılı. Her panelin gerçek sorgusu authenticated browser üzerinden Grafana plugin'ine gönderildi; datasource/query hatası yok. Kısa/trafiksiz rate/p95/oran boşluğu sıfırla doldurulmadı.
- Geçici config aynı Prometheus'un path'ini `/final-metrics-missing` yaptı. API running/ready200 kaldı; target DOWN/up0, lastError **server returned HTTP status 404 Not Found**, başarısız scrape **08:55:59.053788745 UTC**.
- Grafana datasource health **OK** kaldı. Önceki POST400 counter3 ve scrape zamanı `1791276949.46` Grafana'da görünmeye devam etti. Target DOWN, datasource bağlantı hatası ve boş sorgu aynı sonuç değildir; geçmiş veri hemen silinmedi.
- Doğru `api:8080/metrics` geri yüklendi. Yeni kontrollü POST400 trafiği ardından Grafana counter **3 → 8 → 13** değerini gösterdi. Son marker zamanı `1791277652.715152`; Grafana üzerinden `timestamp(...)` ile alınan yeni scrape örneği **1791277665.516** idi. Örnek marker'dan sonradır; cached/eski yanıt recovery kanıtı sayılmadı. Recovery scrape **09:07:45.516421940 UTC**, up1.

Counter sorgusu gerçek `http_server_request_duration_seconds_count` serisini `job="fullstack-ops-api"`, `http_request_method="POST"`, `http_response_status_code="400"` ile filtreledi; `sum(...)` counter'ı, `max(timestamp(...))` gerçek örnek zamanını verdi. Panel rate/histogram sorguları [Module10 tablosuyla](../labs/10-prometheus-grafana/README.md#panel-promql-birim-ve-anlam) eşleşir. 400 marker'ları 5xx metriği olarak sunulmadı.

### Deneyde karşılaşılan sorunlar

1. Geçici harness önce gerçek `[CACHE INVALIDATED]` yerine `[CACHE INVALIDATE]` bekledi. Bu test beklentisi hatasıydı; yalnız kendi görev kaydı temizlendi, beklenti düzeltildi ve etkilenen core kabulü yeniden geçti. Uygulama değişmedi.
2. İlk recovery'nin son kontrolü TimeoutError verdi; o girişim PASS sayılmadı. Ardından altı servis healthy ve doğru config kontrol edildi, beş yeni400 marker üretildi; yeni örnek/counter ve gerçek browser/plugin kontrolü yeniden başarılı oldu. İlk timeout'un kesin kaynağı belirlenmedi; kalıcı application/config hatası gösterilmedi. Bu gözlem sıfır flaky test/performance garantisi değildir.

## Şartname kabul matrisi

**PASS (bu demo)** güncel SHA'nın yeni gerçek kanıtıdır. **PASS (mevcut kanıt)** tarihli modül/CI kabulü veya güncel kaynak incelemesidir; yeniden çalıştırılmış gibi sunulmaz.

| Bölüm30/37 gereksinimi | Durum | Somut kanıt |
| --- | --- | --- |
| Baseline .NET + React / application çalışır | PASS (bu demo) | Edge frontend ve Nginx API; Phase0B gerçek smoke |
| Backend Dockerfile | PASS (bu demo) | Compose API image build ve runtime |
| Frontend Dockerfile | PASS (bu demo) | Compose image build, statik UI; npm/TS/Vite cache layer'ları |
| Multi-stage builds | PASS (bu demo) | İki stage source/build; final API SDK ve frontend Node/npm yok |
| .dockerignore | PASS (mevcut kanıt) | [İki context ve env/build dışlama](architecture.md#build-ve-runtime), güncel Dockerfile/context incelemesi |
| PostgreSQL API integration | PASS (bu demo) | Migration, tekil DB GET, CRUD |
| PostgreSQL persistence lab | PASS (mevcut kanıt) | [Module3](../labs/03-postgresql/README.md), anonymous/named ayrımı |
| Named volume | PASS (bu demo) | Boş unique external volume, inspect mount, recreate birebir ID/alan |
| Custom network | PASS (bu demo) | Altı servis unique project app bridge; internal DNS hedefleri |
| Wrong localhost lab | PASS (mevcut kanıt) | [Troubleshooting1](../troubleshooting/01-wrong-localhost/README.md#verification) |
| Redis integration | PASS (bu demo) | Gerçek cache key/logs ve readiness |
| Cache hit/miss | PASS (bu demo) | Miss ilk GET, hit ikinci GET, gerçek counter serileri |
| Cache TTL | PASS (bu demo) | TTL60/config60; expiration ayrıntısı [Module5](../labs/05-redis/README.md) |
| Cache invalidation | PASS (bu demo) | POST/PUT/DELETE; 400/404 key korunur |
| Nginx frontend static/reverse proxy | PASS (bu demo) | Edge UI, Nginx HTTP contract |
| 502 troubleshooting | PASS (mevcut kanıt) | [Troubleshooting4](../troubleshooting/04-nginx-502/README.md#verification); evrensel 502/504 iddiası yok |
| Six-service Compose | PASS (bu demo) | Altı running/healthy; yalnız üç localhost yayını |
| Health checks | PASS (bu demo) | Altı healthy; internal self/live/ready |
| Readiness scenario | PASS (bu demo) | Module8 Redis kesinti/same-API recovery |
| .env.example | PASS (bu demo) | Clone'da güvenli test env hazırlığının gerçek kaynağı |
| Secrets Git dışında | PASS (bu demo) | Ignored env, secret scan, captured stdout/stderr/log/browser canary kontrolleri |
| Logs/troubleshooting docs | PASS (mevcut kanıt + demo) | Güvenli cache logları, [yedili teşhis kanıtları](../README.md#repository-ve-belgeler) |
| Internal /metrics | PASS (bu demo) | Frontend container'dan gerçek metrics; Nginx API routing'ine /metrics eklenmedi |
| Low-cardinality cache metrics | PASS (bu demo + kaynak) | Üç mevcut counter; [TaskCacheMetrics](../src/backend/FullStackOpsLab.Api/Telemetry/TaskCacheMetrics.cs) |
| Prometheus config/service | PASS (bu demo) | Quiet Compose config + promtool; 15s interval |
| Prometheus target UP | PASS (bu demo) | İki scrape ve fresh-sample recovery |
| Prometheus named volume | PASS (bu demo + mevcut kanıt) | Unique managed mount; history/down-up kabulü [Module10](../labs/10-prometheus-grafana/README.md#prometheus--internal-scrape-kabulü) |
| Monitoring health checks | PASS (bu demo) | Prometheus/Grafana healthy |
| Grafana service | PASS (bu demo) | Gerçek Edge login ve authenticated query |
| Datasource provisioned | PASS (bu demo) | Sabit UID, doğru internal URL, healthOK; manuel ekleme yok |
| Dashboard provisioned | PASS (bu demo) | Provisioned metadata, 12 rendered panel; manuel import yok |
| HTTP/error/duration/cache panels | PASS (bu demo + mevcut kanıt) | 12 hatasız plugin sorgusu; yeni HTTP/cache örnekleri; kontrollü5xx ve finite panel kabulü [Module10](../labs/10-prometheus-grafana/README.md#şartname-farklarının-kapatılması--4-ekim-2026) |
| Monitoring no-data troubleshooting | PASS (mevcut kanıt + demo) | [Troubleshooting7](../troubleshooting/07-monitoring-no-data/README.md#verification) + aynı datasource üzerinde yeni wrong-path/recovery |
| Backend tests | PASS (bu demo + CI) | Gerçek smoke scriptleri; unit-test projesi/coverage veya dotnet test sonucu iddiası yok |
| Actions workflow | PASS (aynı SHA hosted) | [Run37436957155](https://github.com/EnsarAslannn/fullstack-ops-lab/actions/runs/37436957155), üç job success |
| CI Docker builds | PASS (aynı SHA hosted) | Linux build/config ve isolated runtime job'ları |
| Ana README | PASS (dokümantasyon) | Güncel altı servis/ilk kurulum/normal up; [README](../README.md) |
| Architecture | PASS (dokümantasyon) | [Servis/ağ/cache/volume/health ilişkileri](architecture.md) |
| Command cheat sheet | PASS (dokümantasyon) | [Güvenli ve yıkıcı işlemler ayrımı](commands-cheatsheet.md) |
| Troubleshooting labs | PASS (mevcut kanıt) | Yedi zorunlu senaryo, dokuz başlık ve sınırlar; aşağıdaki bağlantılar |
| First-install env/volume/migration | PASS (bu demo) | Boş DB, preflight, SQL review/apply/reapply, history1/tasks0 |
| Prepared-environment up | PASS (bu demo) | İlk hazırlıktan sonra altı servis up/build/healthy |
| Clean-clone final demo | PASS (bu demo) | Remote SHA92e98a1, isolated resources, browser/CRUD/cache/DB/monitoring/CI; aynı host sınırı |
| Responsiveness | PASS (mevcut kanıt + kaynak) | [Module6](../labs/06-nginx/README.md) ve [Module7](../labs/07-docker-compose/README.md) gerçek390px kabulü; frontend layout değişmedi. Bu demoda1200px Edge kullanıldı,390px yeniden ölçülmedi |
| Modül DoD | PASS (mevcut teknik/dokümantasyon kanıtı) | [11 lab eşlemesi](architecture.md#dokümantasyon-standardı-ve-definition-of-done); açıklama/soru varlığı öğrenme cevabının kanıtı değil |

### Önceki kanıtların kullanımı

[1 Wrong Localhost](../troubleshooting/01-wrong-localhost/README.md), [2 Lost PostgreSQL Data](../troubleshooting/02-lost-database/README.md), [3 Redis Connection Failure](../troubleshooting/03-redis-connection/README.md), [4 Nginx502](../troubleshooting/04-nginx-502/README.md), [5 Database Not Ready](../troubleshooting/05-database-not-ready/README.md), [6 Environment Misconfiguration](../troubleshooting/06-env-misconfiguration/README.md), [7 Prometheus Target Down / Grafana No Data](../troubleshooting/07-monitoring-no-data/README.md) kabul tabloları korunur. Yanlış DNS/port, başlangıç gate'i, bütün configuration fixture'ları, ayrı datasource arızası veya backup restore bu görevde yeniden çalıştırılmadı.

Monitoring restart/down-up provisioning/persistence, counter reset/rate ve kontrollü5xx kanıtları [Module10 final kabulünde](../labs/10-prometheus-grafana/README.md#şartname-farklarının-kapatılması--4-ekim-2026); runner/fork/cache/cleanup sınırları [Module11 final kabulünde](../labs/11-github-actions/README.md#module-11--final-kabul-ve-öğrenme-değerlendirmesi) kalır. Güncel SHA'nın [hosted run'ı](https://github.com/EnsarAslannn/fullstack-ops-lab/actions/runs/37436957155) Linux build/config, Windows configuration/secret ve Linux isolated runtime job'larında success; mevcut workflow tekrar başlatılmadı.

## Cleanup ve güvenlik

Test görevleri silindi; yalnız izole list-cache key'i temizlendi; test DB'de tasks0/history1 cleanup öncesi doğrulandı. Demo down, isim/owner doğrulanmış üç volume rm, iki own image tag rm gerçekleştirildi. External test volume down ile otomatik kaldırılmış varsayılmadı; ayrıca kaldırıldığı kontrol edildi.

| Envanter | Başlangıç | Bitiş | Karşılaştırma |
| --- | ---: | ---: | --- |
| Container | 18 | 18 | Aynı ID/ad/state/port |
| Network | 8 | 8 | Aynı ID/ad; default bridge ID değişmedi |
| Volume | 21 | 21 | Aynı adlar; development volume korundu |
| Image/tag girdisi | 38 | 38 | Aynı ID/tag; yalnız demo tag'leri kaldırıldı |

İlişkisiz kaynaklarda stop/start/rm/exec yoktu. Ana `.env`/user-secrets okunmadı veya değiştirilmedi. Repository taraması, yakalanan command stdout/stderr, bütün servis logları ve frontend browser console kontrolünde sahte parola canary'si yoktu. Grafana browser'da page exception/request/datasource sonuçları kontrol edildi; bu harness bütün Grafana console mesajlarını ayrıca toplamadı, eksiksiz console taraması iddia edilmez. Geçici clone/env/SQL/test-tool klasörleri ayrıca temizlendi. Docker Desktop Engine açık bırakıldı; deney dışında bir stack başlatılmadı. Build cache temizlenmedi/prune yapılmadı; eşit image/tag envanteri bütün cache byte'larının eşitliği değildir.

Son ana repository kontrolleri: **370 yerel bağlantı/anchor PASS**, secret leakage regression check exit0, git diff check exit0. Yalnız altı dokümantasyon dosyası değişti/yeni; index'e dosya eklenmedi. Ana `.env` ignored ve untracked olarak doğrulandı; değeri okunmadı.

## Sınırlar ve kalan işler

| Madde | Durum / sınır |
| --- | --- |
| Zorunlu teknik kriterler | PASS; FAIL veya kalan teknik blocker yok |
| Kullanıcının öğrenme yeterliliği | NOT VERIFIED; kendi cevapları ve açıklamaları beklenir |
| Temiz VM / farklı bilgisayar | NOT VERIFIED; aynı host temiz remote clone + boş izole veri ortamı |
| Boş Docker/NuGet/npm cache | NOT VERIFIED; mevcut image/build/package cache kullanıldı |
| Production deployment/hardening | NOT VERIFIED; lab çalışma durumu production garantisi değildir |
| Unit-test coverage | NOT VERIFIED; gerçek smoke kapsamı vardır, unit-test suite yok |
| Gerçek fork/main-target PR | NOT VERIFIED; Module11'in önceki açık sınırı korunur |
| Backup restore, uzun retention/outage/load | NOT VERIFIED; şartname dışı garantiler eklenmez |
| Kesintisiz/flaky olmayan test garantisi | NOT VERIFIED; bir recovery timeout'u tekrar kontrolle geçti |
| Release/tag/commit/push | Bu görevde yapılmadı; kapanış için kendiliğinden oluşturulmaz |

Kabul yalnız test edilen SHA ve açık kapsam içindir. Trafik kısa/sentetiktir; benchmark, kapasite veya latency SLA değildir. Scanner bilinen desenleri yakalar; Git geçmişinin tamamı, OCR ve bütün log yolları için eksiksiz sızıntı garantisi verilmez.

## Kullanıcının cevaplaması gereken öğrenme maddeleri

[Şartname bölüm32'nin 46 sorusu](../PROJECT_SPEC.md#32-mülakat-için-öğrenilmesi-gereken-sorular) kendi kelimelerinle cevaplanmalıdır. Aşağıdaki gruplar cevapların kapsamını hatırlatır; cevap verilmediği için PASS değildir:

1. Docker1–9: image/container, Dockerfile/context/layer/cache, multi-stage, exec/lifecycle farkları.
2. Networking10–14: container localhost, servis DNS'i, bridge ağı, host/container portu ve publish farkı.
3. Volume15–17 ve PostgreSQL18–19: anonymous/named/external, recreate kalıcılığı, down-v ve yanlış volume ile veri görünürlüğü.
4. Redis20–24: hit/miss/TTL/invalidation; neden cache ana veri deposu değildir ve failure davranışı.
5. Nginx25–27 ve Compose28–30: static/proxy, somut502/504 teşhisi, declarative orchestration ve başlangıç readiness sınırı.
6. Health31 ve Observability32–42: running/healthy/live/ready/up, log/metric/trace, counter/gauge/histogram/rate, scrape penceresi, provisioning/cardinality ve target/no-data teşhis sırası.
7. CI43–46: CI/CD, workflow/job/step/runner, build ile runtime/smoke farkı, yeşil run'ın kanıtlamadığı alanlar.

Önceki lab alıştırmalarından kendi seçtiğin iki küçük alıştırmayı neden/komut/gözlem/cleanup sırasıyla açıklaman gerekir. Yeni destructive deney önerilmez; öğretici açıklamalar ve AI raporu, senin öğrenme yeterliliğin yerine geçmez.

# FullStack Ops Lab — Komut Rehberi

Repository kökünde **PowerShell** kullanımı. Komutlar mevcut kaynak ve tarihli kabul kanıtlarıyla karşılaştırıldı; bu dokümantasyon görevinde lifecycle/build/migration çalıştırılmadı. Örnekler otomatik bir script değildir; amacına göre seç. Native komut başarısı `$LASTEXITCODE` ile kontrol edilmelidir.

## İlk kurulum kapısı

[Module9 rehberi](../labs/09-environment-configuration/README.md#13-temiz-bilgisayar-kurulum-rehberi) otorite: tools → ezmeden env → external volume → preflight → yalnız PostgreSQL/TCP auth → InitialCreate SQL inceleme/uygulama → altı servis. İlk kurulum normal up ile aynı değildir.

| Komut | Amaç / beklenen gözlem |
| --- | --- |
| `docker version` / `docker compose version` | Engine server erişimi ve Compose; yalnız CLI yeterli değil |
| `git status --short` | Beklenen dosyalar; secret env stage edilmemeli |
| `git check-ignore .env` ve `git ls-files -- .env` | İlkinde ignored yol, ikincisinde çıktı olmamalı |
| `docker volume inspect fullstack-ops-postgres-data --format '{{.Name}}'` | Volume var mı? Engine/izin hatasını yoklukla karıştırma |
| `docker volume create fullstack-ops-postgres-data` | **Yalnız gerçekten yoksa** ilk hazırlık; var olanı silme/sıfırlama |
| `dotnet tool restore` | Kökteki dotnet-tools.json/local EF; runtime image'da çalışmaz |
| `dotnet restore FullStackOpsLab.slnx` | Host paketleri; migration uygulamaz |

Env hazırlama mevcut dosyayı ezmez:

```powershell
if (Test-Path -LiteralPath .env) { throw 'Mevcut .env üzerine yazma.' }
Copy-Item -LiteralPath .env.example -Destination .env
```

Gerçek değerleri yerel editörde doldur; credential'ı argümana/README/screenshot/Git'e koyma. Compose user-secrets okumaz. Initialized PostgreSQL/Grafana volume'unda env değişikliği parola rotate etmez.

## Değerleri göstermeyen kontroller

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/Module9.EnvPreflight.ps1
if ($LASTEXITCODE -ne 0) { throw 'Preflight başarısız.' }
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/Module9.SecretLeakage.Check.ps1
if ($LASTEXITCODE -ne 0) { throw 'Tarama temiz değil veya tamamlanamadı.' }
docker compose --env-file .env config -q
if ($LASTEXITCODE -ne 0) { throw 'Compose model doğrulanamadı.' }
git diff --check
```

Preflight key/placeholder/Git/quiet config/volume kontrolüdür; authentication/readiness kanıtı değildir. Scanner exit0 temiz, exit1 aday bulgu (path/line/rule), exit2 tarama hatası. Ignored kaynakları/Git geçmişini taramaz, eksiksiz secret tespiti değildir.

## Normal başlatma ve lifecycle

Ön koşul: env, doğru external volume ve migration hazırlanmış.

| Komut | Amaç / beklenen gözlem |
| --- | --- |
| `docker compose --env-file .env up --build -d --wait --wait-timeout 180` | İki image build; altı healthy servis; nonzero ise teşhis et |
| `docker compose --env-file .env ps` / `ps -a` | running/healthy/ports; -a duran/created servisleri de gösterir |
| `docker compose --env-file .env build api frontend` | İki uygulama image build; çalışan container'ı kendiliğinden değiştirmez |
| `docker compose --env-file .env stop` | Container'ları durdurur, silmez |
| `docker compose --env-file .env start` | Var olan container'ları başlatır; down sonrası up gerekir |
| `docker compose --env-file .env restart api` | Aynı API restart; yeni image/env dağıtımı değil |
| `docker compose --env-file .env down` | Bu proje container/ağını kaldırır; PG ve monitoring volume'larını korur |

Yalnız project adını değiştirmek sabit external **fullstack-ops-postgres-data** hedefini izole etmez. CI ayrıca unique volume/override/credential kullanır.

## HTTP, cache ve internal health

```powershell
curl.exe -i http://127.0.0.1:18081/api/tasks
docker compose --env-file .env exec -T redis redis-cli PING
docker compose --env-file .env exec -T redis redis-cli TTL fullstack-ops:tasks:all:v1
docker compose --env-file .env exec -T frontend wget -S -O /dev/null http://api:8080/health/live
docker compose --env-file .env exec -T frontend wget -S -O /dev/null http://api:8080/health/ready
docker compose --env-file .env exec -T frontend wget -S -O /dev/null http://api:8080/metrics
```

Liste200 DB/cache akışıdır; PONG Redis bağlantısıdır. GET liste cache'i doldurabileceği için tamamen yan etkisiz değildir. TTL geçen süre kadar config'den küçük olabilir; -2 key yok, -1 expiration yok. Live200 dependency başarısı değildir; ready200/503 SQL1+Redis kontrolüdür. Wget status'u stderr'e yazabilir, 503 nonzero olur. `/dev/null` metrics gövdesini basmaz. Araç frontend image'ındaki wget'tir; curl.exe Windows'tur, Linux'ta curl kullanılır.

OpenAPI yalnız Development'ta internal `http://api:8080/openapi/v1.json`. Nginx health/metrics/OpenAPI'yi proxy etmez; browser'daki frontend SPA200'ünü API kanıtı sayma.

## Gözlem ve güvenli teşhis

| Komut | Amaç / beklenen gözlem |
| --- | --- |
| `docker compose --env-file .env logs --tail 50 --timestamps api frontend` | Cache/request/Nginx zamanları; paylaşmadan önce secret kontrolü/redaksiyon |
| `docker compose --env-file .env logs --tail 50 prometheus` | Scrape/config hatası; Targets lastError ile eşleştir |
| `docker compose --env-file .env stats --no-stream` | Anlık CPU/memory/net/block/PID; trend/benchmark değil |
| `docker compose --env-file .env exec -T frontend nginx -t` | Syntax/upstream çözümü; gerçek CRUD ayrı kontrol |
| `docker compose --env-file .env exec -T prometheus promtool check config /etc/prometheus/prometheus.yml` | Syntax; scrape garantisi değil |
| `docker compose --env-file .env exec -T postgres sh -c 'exec pg_isready -U "$POSTGRES_USER" -d "$POSTGRES_DB"'` | PostgreSQL kabulü; parola/migration testi değil |

Secret environment içermeyen seçilmiş inspect:

```powershell
$apiId = docker compose --env-file .env ps -q api
if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($apiId)) { throw 'API bulunamadı.' }
docker inspect --format '{{.State.Status}}|{{.State.Health.Status}}|{{.RestartCount}}' $apiId
docker inspect --format '{{json .NetworkSettings.Networks}}' $apiId
```

Tam inspect/çözümlenmiş config/user-secrets list/raw log-exception paylaşma: credential gösterebilir. IP'leri sabit config'e kopyalama; service DNS kullan.

Prometheus http://127.0.0.1:9090/ Targets ve query:

```promql
up{job="fullstack-ops-api",instance="api:8080"}
sum(rate(http_server_request_duration_seconds_count{job="fullstack-ops-api",http_route=~"/api/tasks.*"}[2m]))
```

Grafana http://127.0.0.1:3000/ Overview; datasource `http://prometheus:9090`. [Gerçek PromQL/birim tablosu](../labs/10-prometheus-grafana/README.md#panel-promql-birim-ve-anlam). TargetDOWN, datasource hatası ve hatasız boş query farklıdır; eski çizgiler fresh scrape kanıtı değil.

## Build ve fixtures — runtime kabulünden ayrı

```powershell
dotnet build FullStackOpsLab.slnx --configuration Release
npm --prefix src/frontend ci
npm --prefix src/frontend run build
powershell -NoProfile -ExecutionPolicy Bypass -File tests/Module9.SecretLeakage.Smoke.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File tests/Module9.EnvPreflight.Smoke.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File tests/Module9.Configuration.Smoke.ps1 -Configuration Release
```

Her native exit code kontrol edilir. Configuration negatiflerinde güvenli mesaj/canary yokluğu gerekir, yalnız nonzero yetmez. Windows'a özgü harness'i Linux'ta aynı sayma. `dotnet test` unit-test coverage kanıtı değildir. [CI](../.github/workflows/ci.yml) ve [runner uygunluğu](../labs/11-github-actions/README.md#mevcut-kontrollerin-runner-uygunluğu).

Module5/8/dashboard smoke'ları servis durdurabilir, Task/cache değiştirebilir; development stack'te salt okunur kontrol gibi koşma. Sahiplik, başlangıç durumu ve cleanup şartlarını oku. Bu görevde yeniden çalıştırılmadılar.

## Veri silebilen işlemler — normal cleanup değildir

| İşlem | Risk / karar |
| --- | --- |
| docker compose down -v | Managed Prometheus/Grafana geçmiş/state'ini silebilir; external PG korunması diğer kaybı önlemez |
| docker volume rm | Volume verisini kaldırır; sahiplik/backup kararı olmadan kullanma |
| Redis DEL / FLUSHDB / FLUSHALL | Key/kapsam siler; başkasının cache'ini değiştirebilir; toplu silme normal işlem değil |
| Task DELETE / migration SQL | Veri/şema değişir; kendi kayıt/doğru DB doğrulaması gerekir |
| Volume/system prune | İlişkisiz kaynakları hedefleyebilir; rutin cleanup önerisi değil |

Yıkıcı komut zinciri verilmez. Deney cleanup'ı yalnız başlangıçta bulunmayan açık ad/owner-label test kaynaklarına uygulanır. Normal kapatma **down, -v olmadan**. PG volume'unu silmek parola/migration hatasını çözmenin kısa yolu değildir.

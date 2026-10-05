# Scenario

**Wrong Localhost — API container'ından PostgreSQL'e yanlış loopback hedefi.**

**Completed — güncel Compose yanlış hedef/düzeltme deneyi PASS (5 Ekim 2026).** İlk incelemede Docker Engine erişilemediği için runtime kontrolü NOT VERIFIED kalmıştı. Engine erişimi geri geldikten sonra yalnız eksik küçük kontrol tamamlandı: PostgreSQL hazırken loopback bağlantı hatası, live200/ready503/tekil GET500 ve aynı image ile doğru hedefe dönüş doğrulandı. Önceki Module 4 sonuçları tarihsel kanıt olarak ayrı tutulur.

Kaynaklar:

- [Şartname](../../PROJECT_SPEC.md): Troubleshooting 1 ve standart senaryo şablonu.
- [Module 4 gerçek localhost deneyi](../../labs/04-docker-networking/README.md#module-4--kritik-hata-senaryosu-container-içindeki-localhost): yanlış hedef, connection refused ve düzeltme.
- [Module 8 gerçek readiness deneyleri](../../labs/08-health-checks/README.md#gerçek-runtime-sonuçları): PostgreSQL kesintisinde live/ready/Docker health ayrımı.
- [Güncel Compose](../../compose.yaml), [API](../../src/backend/FullStackOpsLab.Api/Program.cs) ve [PostgreSQL readiness check](../../src/backend/FullStackOpsLab.Api/Health/PostgreSqlReadinessCheck.cs): bugünkü hedef, cache ve probe davranışı.

## Symptoms

Module 4'te PostgreSQL hazırken API container'ındaki bağlantı hedefi `Host=localhost`, port `5432` idi. API `running` kaldı, `/health` **200**, `GET /api/tasks` **500** döndü. Loglarda `Connection refused`, `localhost:5432` ve `127.0.0.1:5432` gözlendi. Bu, yanlış hedefte açık bir PostgreSQL dinleyicisi bulunmadığını gösteriyordu; tek başına parola hatası kanıtı değildir.

Bugün startup configuration validation bağlantı dizesinin biçimini kontrol eder; `localhost` sözdizimi geçerli olduğundan PostgreSQL'e ulaşılabildiğini kanıtlamaz. Readiness ayrıca gerçek bağlantı ve `SELECT 1` yapar.

Güncel liste endpoint'i Redis cache kullanır. Cache hit ile dönen **200**, PostgreSQL hedefinin doğru olduğunu kanıtlamayabilir. `/api/tasks/{id:int}` doğrudan PostgreSQL okur; bu küçük deney için mevcut kaydı değiştirmeyen tekil GET daha uygundur. Eksik bir ID için **404** beklenen başarılı database okumasıdır; DB bağlantı hatasındaki **500** ile karıştırılmaz.

## Expected Behaviour

Güncel Compose'ta frontend/Nginx → `api:8080`; API → **`postgres:5432`** ve `redis:6379` kullanır. Ortak ağ `app`, service adı `postgres`, PostgreSQL'in **container portu 5432**'dir. Eski Module 4 container adı bugünkü Compose hostname'i değildir.

API, PostgreSQL ve Redis için host portu yayınlanmaz. Frontend Task istekleri host `http://127.0.0.1:18081/api/tasks` üzerinden Nginx'e gelir. Health uçları Nginx tarafından API'ye yönlendirilmediğinden health kontrolü aynı ağdaki frontend container'ından doğrudan `http://api:8080` hedefiyle yapılır; host Nginx `/health` yanıtı API health kanıtı sayılmaz.

## Investigation

1. API ve PostgreSQL gerçekten çalışıyor mu? State ve Docker health alanlarını ayrı kontrol et.
2. Aynı Compose ağına bağlılar mı? Network üyeliğini kontrol et; IP'yi kalıcı configuration'a yazma.
3. API container'ında `postgres` adı çözümleniyor mu? DNS başarısı henüz port/credential/SQL başarısı değildir.
4. PostgreSQL `pg_isready` ile yanıt veriyor mu? Bu komut tek başına doğru parola veya migration kanıtlamaz.
5. Loglarda connection refused ve loopback hedefi var mı? Tam log, environment veya çözümlenmiş configuration paylaşma.
6. `/health/live`, `/health/ready` ve database kullanan gerçek GET'i ayrı değerlendir. Nginx 502/504 olursa önce API upstream erişimini ayır; bu hatalar PostgreSQL bağlantısının kesin teşhisi değildir.
7. Doğru hedefle aynı image üzerinde SQL kullanan isteklerin düzelmesi, configuration düzeltmesinin etkisini gösterir.

## Useful Commands

Repository kökünde, **çalışan ve doğru configuration kullanan stack** için salt okunur tanı komutları:

```powershell
docker compose --env-file .env config -q
docker compose --env-file .env ps -a
$apiId = docker compose --env-file .env ps -q api
docker inspect --format '{{.State.Status}}|{{if .State.Health}}{{.State.Health.Status}}{{end}}' $apiId
docker inspect --format '{{json .NetworkSettings.Networks}}' $apiId
docker compose --env-file .env exec -T api getent hosts postgres
docker compose --env-file .env exec -T postgres sh -c 'pg_isready -U "$POSTGRES_USER" -d "$POSTGRES_DB"'
docker compose --env-file .env exec -T frontend curl -s --max-time 15 -o /dev/null -w '%{http_code}' http://api:8080/health/live
docker compose --env-file .env exec -T frontend curl -s --max-time 15 -o /dev/null -w '%{http_code}' http://api:8080/health/ready
curl.exe -s --max-time 15 -o NUL -w '%{http_code}' http://127.0.0.1:18081/api/tasks/2147483647
```

`getent` varlığı güncel image'da bu görevde ölçülmedi; Module 4 image'ında çalışmıştı. Araç yoksa bunu DNS başarısızlığı sayma veya runtime image'a araç kurma. HTTP komutları yalnız status kodunu gösterir; native exit code'u da kontrol et. `2147483647` için güncel doğru hedefte **404**, yanlış hedefte **500**, düzeltmeden sonra tekrar **404** ölçüldü. Genel olarak doğru hedefte **200 veya 404**, bu endpoint için DB okumasının yapıldığını gösterir; **404** beklentisi ancak ID gerçekten yoksa geçerlidir.

Log teşhisini değer yazdırmadan yap:

```powershell
$apiLogs = @(docker compose --env-file .env logs --no-color --tail 150 api 2>&1)
if ($LASTEXITCODE -ne 0) { throw 'API logs could not be read; details withheld' }
$captured = $apiLogs -join "`n"
[pscustomobject]@{
    ConnectionRefused = $captured -match 'Connection refused'
    Loopback5432 = $captured -match '(localhost|127\.0\.0\.1|\[::1\]):5432'
    Task500 = $captured -match 'HTTP GET /api/tasks/\{id:int\} -> 500'
}
Remove-Variable apiLogs, captured
```

Bu sınırlı log penceresinde eşleşme bulunmaması, hatanın hiç yaşanmadığını kanıtlamaz. Tam `docker inspect` (`Config.Env`), düz `docker compose config` veya raw log paylaşma; credential içerebilirler.

## Root Cause

Her container kendi network namespace'ine ve loopback arayüzüne sahiptir. API içindeki `localhost`, API container'ının kendisini gösterir. Host bilgisayarı veya ayrı PostgreSQL container'ını göstermez. PostgreSQL o loopback üzerinde dinlemediği için bağlantı reddedilir.

Host üzerinde çalışan API için host'a yayınlanmış PostgreSQL portuyla `localhost` doğru olabilir; container içindeki API için aynı varsayım geçerli değildir. Compose DNS, aynı ağdaki `postgres` service adını PostgreSQL container'ına çözer. İç iletişimde host portu yerine `5432` kullanılır.

## Fix

Mevcut `compose.yaml` zaten doğru `postgres:5432` hedefini tanımlar; bu görevde değiştirilmedi. Credential, database, kullanıcı, Redis ayarı, image ve volume'u değiştirmeden yalnız yanlış Host override'ını kaldırmak gerekir. PostgreSQL volume'unu sıfırlamak bu hatanın çözümü değildir.

Güncel küçük deneyde aşağıdaki yöntem kullanıldı. Yeniden çalıştırmadan önce mevcut kaynakların durumunu kaydet; aynı PostgreSQL volume'unu kullanan başka çalışan container varsa deneye başlama. Doğru stack'te frontend/API/PostgreSQL/Redis hazır olmalıdır; yanlış API health'i nedeniyle frontend'in başlangıcı engellenmesin. Bu görevde stack başlangıçta kapalıydı; mevcut image'larla yalnız bu dört servis başlatıldı. Prometheus/Grafana başlatılmadı.

```powershell
docker compose --project-name fullstack-ops-lab --env-file .env -f compose.yaml up -d --no-build --pull never --wait --wait-timeout 120 postgres redis api frontend
```

Doğru baseline hazır olduktan sonra yalnız API override ile yeniden oluşturuldu. Yanlış readiness için tüm stack'e `up --wait` uygulanmadı; API liveness için 90 saniye, unhealthy durumu için ayrıca 90 saniye üst sınırı kullanıldı.

Repository dışında oluşturulan override, gerçek değerleri içermez; Compose aynı `.env` placeholder'larını çözer:

```yaml
services:
  api:
    environment:
      ConnectionStrings__Postgres: "Host=localhost;Port=5432;Database=${POSTGRES_DB:?Set POSTGRES_DB};Username=${POSTGRES_USER:?Set POSTGRES_USER};Password=${POSTGRES_PASSWORD:?Set POSTGRES_PASSWORD}"
```

Override dosyasının yolu `$wrongOverride` değişkenindeyken, yalnız API'yi yeniden oluştur ve düzeltmeyi `finally` ile ana dosyadan uygula:

```powershell
try {
    docker compose --project-name fullstack-ops-lab --env-file .env -f compose.yaml -f $wrongOverride up -d --no-deps --no-build --pull never --force-recreate api
    if ($LASTEXITCODE -ne 0) { throw 'Temporary API override failed; restore required' }
    # Yukarıdaki tanı komutlarıyla live, ready ve tekil GET'i ölç.
    # API running kalırken unhealthy durumunu en çok 90 saniye gözle.
} finally {
    docker compose --project-name fullstack-ops-lab --env-file .env -f compose.yaml up -d --no-deps --no-build --pull never --force-recreate --wait --wait-timeout 120 api
    if ($LASTEXITCODE -ne 0) { throw 'API restoration failed; do not claim cleanup succeeded' }
    # Doğru hedefte ready200 ve tekil GET 200/404 doğrulanınca,
    # yalnız bu deneyin geçici override dosyasını açık yoluyla kaldır.
}
```

Ana dosya tek başına kullanıldığı için yanlış override final configuration'a taşınmaz. API recreate nedeniyle container ID değişebilir; aynı-container recovery kanıtı olarak sunulmaz. Başlangıçta stack kapalıysa yalnız deneyde başlatılan stack `down` ile kapatılır; önceden açıksa doğru hedefle önceki çalışma durumu korunur. `down -v`, prune, volume silme veya secret değiştirme kullanılmaz.

## Verification

| Şartname / kabul noktası | Sonuç | Kanıt ve kapsam |
| --- | --- | --- |
| Ayrı senaryo klasörü ve dokuz standart başlık | PASS | Bu belge: `troubleshooting/01-wrong-localhost/README.md`. |
| Yanlış localhost nedeniyle bağlantı hatası | PASS — geçmiş deney | Module 4: PostgreSQL hazır, API running, `/health`200, liste500, loopback5432/connection refused. |
| Düzeltme yalnız bağlantı hedefiyle yapılır | PASS — geçmiş deney | Aynı image ID `sha256:9b7e1e6257436f0465245b00d78f5614fc15f9af71058e51fdaca9a547991b26`; doğru container DNS sonrası liste200, POST201, GET200, PUT200, DELETE204; 400/404 korundu. |
| Güncel servis adı, port ve network | PASS — statik inceleme | `compose.yaml`: `postgres:5432`, ortak `app`, API/DB/Redis host portu yok. Static config-q exit0. |
| Liveness/readiness/API isteği ayrımı | PASS — mevcut ayrı deney | Module 8 gerçek PostgreSQL kesintisi: running/live200/ready503/unhealthy/uncached liste500; aynı API bağımlılık geri gelince ready200/healthy/liste200. Bu bir yanlış-host deneyi değildir. |
| Güncel yanlış localhost override'ında live200/ready503/tekil GET500 ve düzeltme sonrası ready200/GET404 | PASS — güncel deney | 5 Ekim UTC10:22:20–10:23:28; PostgreSQL hazır/healthy, API running/unhealthy, loopback5432/connection refused ve güvenli GET500 logu; aynı image ile düzeltme sonrası running/healthy, ready200 ve GET404. |
| Yanlış hedefte cached liste200 ihtimali | Source ile açıklanmış; doğrudan NOT VERIFIED | Program.cs cache hit dalı DB sorgusundan önce döner. Module 8 PostgreSQL kesintisi/cached liste ayrımını açıklar; güncel wrong-localhost cache-hit deneyi yapılmadı. |
| Yerel env güvenliği ve statik preflight | PASS | Engine geri geldikten sonra normal preflight exit0; required keys/config-q/external volume kontrolleri geçti. `.env` ignored ve tracked değil. |
| Güncel cleanup ve veri koruma | PASS — güncel deney | Başlangıçta kapalı dört servisli deney stack'i down ile kaldırıldı, geçici override silindi. Task/lab/migration satır snapshot'ları ve Redis key sayısı değişmedi; env/user-secrets/compose hash'leri, 12 eski container state'i, 7 network ID'si ve 21 volume adı korundu. |

Geçmiş Module 4 deneyinde test görevi, container'lar, lab network'ü ve geçici env dosyaları temizlenmiş; `lab_tasks` ve InitialCreate korunmuştu. İlk dokümantasyon incelemesi Git'te temiz `main...origin/main`, HEAD `403c34e47556348c7c8b325e0a3c022de3b1c962` ile başladı. O incelemede `docker version` exit1 ve `dockerDesktopLinuxEngine` pipe bulunamadı hatası runtime kontrolünü engelledi; bu bulgu volume'un silindiği veya credential'ın yanlış olduğu anlamına gelmiyordu. Devam görevinde önceki üç dokümantasyon değişikliği korundu; client/server `29.6.1`, Compose `v5.3.0` erişimi ve external volume doğrulandı. Hiçbir sistem ayarı veya credential değiştirilmedi.

### Güncel Compose ölçümü ve koruma kanıtı

Ölçüm: **5 Ekim 2026 UTC10:22:20–10:23:28** (Türkiye saati 13:22:20–13:23:28). Deneyin tamamı exit0 ile bitti. Baseline, yanlış hedef ve düzeltme aynı API image'ını kullandı:

`sha256:5730b7c36af841167b20ad1733694d6f6253da989ccef04a4179de229ca1511c`

| Ölçüm | Baseline `postgres:5432` | Geçici `localhost:5432` | Override olmadan `postgres:5432` |
| --- | --- | --- | --- |
| PostgreSQL | ready/healthy | `pg_isready`: accepting connections; healthy | ready |
| API state / Docker health | running / healthy | running / unhealthy | running / healthy |
| `/health` | 200 | 200 | 200 |
| `/health/live` | 200 | 200 | 200 |
| `/health/ready` | 200 | 503 | 200 |
| Nginx tekil GET `/api/tasks/2147483647` | 404 | 500 | 404 |
| API log bulguları | — | Connection refused + loopback5432 + `HTTP GET /api/tasks/{id:int} -> 500` ve ms süre biçimi | Aynı route template için GET404; captured logda loopback/connection-refused yok |

Override kaynak dosyası yalnız placeholder içerdi. Normal ve override Compose configuration'ları bellek içinde karşılaştırıldı: PostgreSQL Host dışındaki tüm alanlar aynıydı; çözümlenmiş değerler yazdırılmadı. Düzeltmede `--no-build --pull never` ile ana Compose dosyası tek başına kullanıldı; gerçek container connection ayarı baseline ile birebir eşleşti. Image ID üç aşamada da aynıydı; API container'ı yeniden oluşturulduğundan bu deney aynı-container recovery iddiası içermez.

Veri endpoint'i yalnız tekil GET idi: POST/PUT/DELETE veya normal liste GET'i yapılmadı. `tasks`, `lab_tasks` ve `__EFMigrationsHistory` satırları salt okunur SQL ile bellek içinde snapshot/hash karşılaştırmasından geçti; satır içerikleri raporlanmadı. Redis başlangıçta yeni/boştu ve `DBSIZE` başta/sonda **0/0** kaldı. Cache key silinmedi/yazılmadı; mevcut ilişkisiz Redis container'larına dokunulmadı. Cache-hit ile hatanın gizlenmesi ayrıca denenmedi.

Captured API loglarında gerçek PostgreSQL parolası ve tam doğru/yanlış connection string bulunmadığı değer göstermeden kontrol edildi. `.env`, user-secrets dosyası ve ana Compose byte hash'leri değişmedi. Geçici override, script ve güvenli sonuç dosyası repository dışında kullanıldı; görev sonunda temizlendi. Başlangıçta bu projenin container'ı yoktu; yalnız oluşturulan frontend/API/PostgreSQL/Redis ve proje ağı `down` ile kaldırıldı, volume silinmedi. Başlangıç/bitiş **12 container, 7 network, 21 volume** eşleşti; yalnız sayılar değil container state'leri, network ID'leri (varsayılan bridge dahil) ve volume adları da birebir aynıydı. PostgreSQL named volume ve mevcut monitoring volume'ları korundu.

## What We Learned

- Aynı `localhost` sözcüğü, komutun çalıştığı host/container'a göre farklı makineyi gösterir.
- Running, live200, ready200, DNS çözümü ve başarılı Task isteği farklı kanıtlardır; biri diğerlerinin tamamını garanti etmez.
- Cache, bozuk DB bağlantısını bazı liste isteklerinde gizleyebilir; salt okunur tekil GET gerçek database erişimini sınar.
- `pg_isready` ile doğru credential ve migration ayrı doğrulanır. Readiness `SELECT 1` de `tasks` şemasını garanti etmez.
- Önce doğru hedefi geri yükle, sonra cleanup başarısını raporla. Connection refused için parola rotate etmek veya volume silmek uygun teşhis değildir.
- Mevcut başarılı deneyi tekrar etmek yerine kanıtı yeniden kullan; yeni topolojide ölçülmeyen sonucu açıkça NOT VERIFIED bırak.

Wrong Localhost zorunlu hata/teşhis/düzeltme kanıtları tamamlandı. Sonraki küçük öneri bu üç dokümantasyon dosyasının commit öncesi incelemesidir. İkinci troubleshooting senaryosuna geçilmedi; commit/push yapılmadı.

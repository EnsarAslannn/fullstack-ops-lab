# Scenario

**Troubleshooting 5 — Database Not Ready.** PostgreSQL bağlantı kabul etmeden başlayan API ile PostgreSQL healthcheck'ini bekleyen API başlangıcını karşılaştırmak.

**Completed — zorunlu kapsam gerçek izole başlangıç deneyiyle PASS (5 Ekim 2026).** Sonradan çalışan PostgreSQL'i durdurma kanıtı bu deneyin yerine kullanılmadı. Mevcut API image'ı, ayrı Compose project, yeni test volume'u ve çalışma anında üretilen sahte credential'lar kullanıldı. Backend/frontend, ana Compose ve readiness implementasyonu değiştirilmedi; retry, otomatik migration veya yeni özellik eklenmedi.

Kaynaklar:

- [Şartname](../../PROJECT_SPEC.md): bölüm 11, Troubleshooting 5 ve dokuz başlıklı şablon.
- [Module 7 — migration hazırlığı](../../labs/07-docker-compose/README.md#4-migration-ilk-kurulumda-açık-adım) ve [başlangıç sırası](../../labs/07-docker-compose/README.md#5-healthcheck-ve-başlangıç-sırası).
- [Module 8 — mevcut kesinti kanıtları](../../labs/08-health-checks/README.md#gerçek-runtime-sonuçları): sonradan bozulan bağımlılık ve aynı API container'ında recovery.
- [Module 11 — izole CI hazırlığı](../../labs/11-github-actions/README.md) ve [mevcut CI smoke script'i](../../tests/Module11.Compose.Smoke.py): sahte fixture, açık migration ve sahiplik kontrolüyle cleanup yaklaşımı.
- [Compose](../../compose.yaml), [PostgreSQL readiness](../../src/backend/FullStackOpsLab.Api/Health/PostgreSqlReadinessCheck.cs), [Redis readiness](../../src/backend/FullStackOpsLab.Api/Health/RedisReadinessCheck.cs), [API](../../src/backend/FullStackOpsLab.Api/Program.cs), [InitialCreate](../../src/backend/FullStackOpsLab.Api/Migrations/20260928113912_InitialCreate.cs).

## Symptoms

API dinlemeye başladı fakat PostgreSQL sunucusu henüz bağlantı kabul etmiyordu. Redis hazırdı. API prosesi ölmedi: `/health` ve `/health/live` **200**, `/health/ready` **503**, PostgreSQL'e doğrudan giden `GET /api/tasks/1` **500** döndü. Docker API health'i periyodik başarısız probe'lar sonrası **unhealthy** oldu.

Loglarda **`PostgreSQL unavailable`**, Npgsql/Socket connection exception'ı ve **`Connection refused`** görüldü. PostgreSQL için HTTP ölçümlerinden **önce ve sonra** `pg_isready -h 127.0.0.1 -p 5432` exit **2**, **`no response`** döndürdü. Bu, yalnız container state'ine veya tahmini sleep süresine dayanmayan bağlantı hazırlığı kanıtıdır.

API startup sırasında zorunlu DB açılışı/migration yapmadığından process'in çöktüğü veya entrypoint'in nonzero exit verdiği iddia edilmez. Buradaki startup-phase connection hatası, erken başlayan API'nin readiness ve gerçek DB isteğinde ortaya çıktı.

## Expected Behaviour

Güncel Compose, API için PostgreSQL ve Redis bağımlılıklarını `condition: service_healthy` ile tanımlar. `postgres` probe'u `pg_isready`, `redis` probe'u PING kullanır. API ancak gerekli dependency healthcheck'leri başarılı olduktan sonra **başlatılır**. `service_started` ise container'ın başlamasını bekler; PostgreSQL bağlantı kabulünü garanti etmez.

API liveness'i process'in HTTP yanıtını gösterir. Readiness PostgreSQL'de `SELECT 1`, Redis'te gerçek bir read yapar; API Docker healthcheck'i `/health/ready` HTTP200 bekler. Bu kontroller farklıdır ve Docker health sonucu probe zamanlaması nedeniyle gecikebilir.

PostgreSQL ready olması, `tasks` tablosunun veya migration history'nin varlığını tek başına kanıtlamaz. Bu nedenle şema API trafiğinden önce açık adımla hazırlandı. API runtime image'ında SDK/EF CLI yoktur; API startup'a migration eklenmedi.

## Investigation

1. **Bu başlangıç arızası mı, sonradan kesinti mi?** API henüz hiç başlamamışken test PostgreSQL container'ı kontrollü bekleme ile yeniden oluşturuldu. Module 8'in çalışan API'deki dependency stop/start kanıtı ayrı tutuldu.
2. **Doğru host/port ve ağ mı?** İzole projenin API hedefi `postgres:5432`, Redis hedefi `redis:6379` idi. Aynı proje ağı kullanıldı; hostname veya port bozulmadı. Ana stack'in ağına bağlanılmadı, host portu yayınlanmadı.
3. **DB gerçekten hazır değil mi?** PostgreSQL container'ı running olsa da `pg_isready` exit2/no-response verdi. Test entrypoint'inin açılmasını beklediği kontrol dosyası yoktu; sunucu dinlemeye başlamamıştı. DNS arızası veya kimlik doğrulama hatası diye sunulmaz.
4. **Şema önceden var mı?** Aynı test volume'unda mevcut InitialCreate önceden uygulanmıştı; `public.tasks` varlığı, history'de tam migration kimliği ve tek test kaydı SQL ile doğrulandı. Öncesi/sonrası sonuç **`true|1|1`** idi.
5. **Hangi API davranışı etkileniyor?** Live200, ready503, running/unhealthy ve tekil DB GET500 birlikte alındı. Liste GET kullanılmadı; Redis cache hit'in DB hazırlık sorununu gizlemesi önlendi.
6. **Gerçek kök neden logda var mı?** Connection-refused ve PostgreSQL unavailable doğrulandı. Loglarda `42P01`/`does not exist` bulunmadı; eksik şema ile bağlantı hazırlığı birbirine karıştırılmadı.

## Useful Commands

Gerçek deney aşağıdaki komut ailelerini kullandı. `$fixtureEnv`, `$override`, `$sqlPath` repository dışındaki geçici dosyalardır; credential değerleri yayınlanmaz. Normal development `.env` ve user-secrets kullanılmaz. Komutların native exit code'ları, HTTP status ve beklenen output ayrıca kontrol edildi; hata halinde raw stderr/connection string gösterilmedi.

```powershell
docker compose --project-name $project --env-file $fixtureEnv -f compose.yaml -f $override config -q
docker volume create --label "fullstackops.lab.owner=$project" $testVolume
docker compose --project-name $project --env-file $fixtureEnv -f compose.yaml -f $override up -d --no-build postgres redis probe
dotnet tool restore
dotnet ef migrations script 0 InitialCreate --idempotent --project src/backend/FullStackOpsLab.Api --startup-project src/backend/FullStackOpsLab.Api --configuration Release --output $sqlPath
```

EF child process'inde yalnız geçici `Production` configuration ve credentialsız, erişilemeyen preview DB/Redis adresleri kullanıldı; host user-secrets yüklenmedi. Local EF tool sürümü root `dotnet-tools.json` manifestindeki **10.0.12**, SDK **10.0.401** idi. SQL **1059 byte**; `CREATE TABLE tasks`, history ve `20260928113912_InitialCreate` kontrol edildi. İncelenmiş SQL, yalnız test PostgreSQL'ine UTF-8 stdin üzerinden `psql -X -w -v ON_ERROR_STOP=1 -At -f /dev/stdin` ile uygulandı. Psql parolayı container environment'tan aldı; host komut argümanına yazılmadı. Sonra yalnız test database'inde tek fixture Task oluşturuldu.

Geçici override'ın deney kısmı:

```yaml
services:
  api:
    image: <existing-api-image-id>
    depends_on:
      postgres:
        condition: service_started # karşılaştırmada service_healthy
  postgres:
    entrypoint: ["/bin/sh", "-c"]
    command:
      - "echo diagnostic-startup-gate-closed; while [ ! -f /tmp/allow-postgres ]; do sleep 0.2; done; exec /usr/local/bin/docker-entrypoint.sh postgres"
volumes:
  postgres-data:
    name: <unique-test-volume-name>
```

Bu gate sabit bir gecikmeyle PostgreSQL'in hazır olduğunu varsaymaz: dışarıdan kontrol dosyası açılana kadar server başlamaz. Kısa `sleep 0.2` yalnız dosya polling aralığıdır; hazır olma koşulu değildir. `pg_isready` gerçek bağlantı kabulü için ölçülür. Volume önceden initialize edildiği için initialization/migration süresi arızanın nedeni değildir.

İzole proje komutları:

```powershell
docker compose --project-name $project --env-file $fixtureEnv -f compose.yaml -f $override exec -T postgres pg_isready -h 127.0.0.1 -p 5432 -U diag_user -d diag_db
docker compose --project-name $project --env-file $fixtureEnv -f compose.yaml -f $override exec -T redis redis-cli PING
docker inspect --format '{{json .State}}' $testApiId
docker compose --project-name $project --env-file $fixtureEnv -f compose.yaml -f $override exec -T probe curl --silent --show-error --max-time 30 --output /dev/null --write-out '%{http_code}' http://api:8080/health/live
docker compose --project-name $project --env-file $fixtureEnv -f compose.yaml -f $override exec -T probe curl --silent --show-error --max-time 30 --output /dev/null --write-out '%{http_code}' http://api:8080/health/ready
docker compose --project-name $project --env-file $fixtureEnv -f compose.yaml -f $override exec -T probe curl --silent --show-error --max-time 30 --output /dev/null --write-out '%{http_code}' http://api:8080/api/tasks/1
docker compose --project-name $project --env-file $fixtureEnv -f compose.yaml -f $override exec -T postgres touch /tmp/allow-postgres
```

`probe`, mevcut frontend image'ındaki curl'ü kullanan yalnız test container'ıdır; Nginx routing veya browser kabulü değildir. API/DB/Redis portları host'a açılmadı. İlk API dinleme, Docker health ve SQL/HTTP recovery kontrolleri sınırlı süreli polling kullandı; sabit sleep'ten başarı çıkarılmadı.

## Root Cause

Geçici `service_started` koşulu PostgreSQL container'ının başlamasını yeterli saydı. Container'ın entrypoint'i gate'te beklerken server 5432'de dinlemiyordu; API buna rağmen başlatıldı. Sonuç **bağlantı reddi** idi, yanlış hostname veya migration/table eksikliği değildi.

Şemanın hazır olması ile server'ın hazır olması ayrı koşullardır. Hazır volume, o anda çalışan PostgreSQL process'inin bağlantı kabulünü garanti etmez. Mevcut API dış bağımlılık arızasında live kalabilir; readiness/API işi başarısız olabilir.

## Fix

Ana Compose zaten doğru `service_healthy` dependency'sini içerir; değiştirilmedi. Karşılaştırmada yalnız geçici override'daki PostgreSQL dependency'si `service_healthy` yapıldı. Aynı önceden hazırlanmış test volume'u ve aynı API image'ı kullanıldı.

Gate kapalıyken PostgreSQL pg_isready2/no-response verdi; `compose up -d --no-build api` beklerken API **created** durumunda kaldı, başlamadı. Gate açılıp PostgreSQL probe'u başarılı olduktan sonra API başladı. Ölçülen ilk başarılı PostgreSQL probe bitişi **12:00:14.826880993 UTC**, API `StartedAt` **12:00:15.295005268 UTC** idi. Readiness, liveness ve tekil DB GET200 doğrulandı.

Erken başlangıç koşusunda ise gate açıldığında **aynı API container'ı** değiştirilmeden healthy/ready200 ve DB GET200 durumuna geldi. İki farklı dependency koşulunu karşılaştırmak için API/PG yalnız izole projede yeniden oluşturuldu; bu karşılaştırma aynı container deneyi diye sunulmaz.

`service_healthy` **başlangıç beklemesini** sağlar. Sonradan duran PostgreSQL'i otomatik onarmaz; çalışan API'nin dependency kesintisini kendiliğinden çözmez veya hazır şemayı garantilemez. Sonraki kesinti/same-container recovery için Module 8 kanıtı geçerlidir. Retry veya startup migration eklenmedi.

## Verification

Deney **5 Ekim 2026 11:59:06–12:00:35 UTC** aralığında (Türkiye saati UTC+3) çalıştı. Docker Engine **29.6.1**, Compose **v5.3.0** idi. Proje **`db-startup-da7ba6a694`**, yalnız bu deneyin volume'u **`db-startup-da7ba6a694-postgres`** idi. API image ID:

`sha256:308cb8d870b05f82a2ce2442618a8a720aeb3453e71ffb6afd02a13ee59d8fce`

| Kriter | Sonuç | Gerçek kanıt / sınır |
| --- | --- | --- |
| İzolasyon ve ayrı test credential | PASS | Ayrı project/ağ/yeni owner-labelled volume; fake fixture repository dışında. Development volume mount edilmedi; `.env`/user-secrets kullanılmadı veya değiştirilmedi. |
| Şema önceden hazır | PASS | Existing InitialCreate SQL incelendi/uygulandı; `tasks` var, history1, fixture task1; önce/sonra `true\|1\|1`. |
| PostgreSQL hazır değilken API başladı | PASS | API ilk kez `service_started` ile başladı; PostgreSQL running fakat pg_isready2/no-response, Redis PONG. |
| Sabit gecikme yerine gerçek DB kontrolü | PASS | Gate, HTTP ölçümlerinden önce/sonra pg_isready exit2; kontrol dosyası açıldıktan sonra exit0/accepting connections. |
| Erken API health/live/ready/DB isteği | PASS | `/health`200, live200, ready503, tekil GET500; API running/unhealthy. |
| Connection error / schema error ayrımı | PASS | PostgreSQL unavailable ve Connection refused + Npgsql/Socket exception; `42P01`/`does not exist` yok. Şema önceden doğrulandı. |
| Dependency hazır olduğunda recovery | PASS | Aynı erken başlayan API container'ında health/live/ready200, tekil GET200 ve fixture alanları doğru; Docker healthy. |
| Doğru service_healthy başlangıç beklemesi | PASS | PG pg_isready2 iken API created ve Compose bekliyor; başarılı PG probe'undan sonra API StartedAt. |
| Doğru başlangıç sonrasında gerçek DB okuması | PASS | Health/live/ready200, tekil GET200, history/task korunmuş; aynı API image ID. |
| Development kaynaklarını koruma / cleanup | PASS | Başlangıç/bitiş **18 container ID/state/RestartCount, 8 network ID/adı, 21 volume adı, 38 image/tag kaydı** aynı. Başlangıçtaki altı servis running/healthy bırakıldı. |
| Canary / secret güvenli çıktı | PASS | Native stdout/stderr ve HTTP/loglar bellekte sahte credential'lara karşı kontrol edildi; değer/çözülmüş connection string yayınlanmadı. |
| Doğal initialization/crash-recovery/yük altında startup yarışı | NOT VERIFIED — ek kapsam | Bu deterministik startup gate deneyidir; production/yük veya bütün PostgreSQL initialization yolları kabulü değildir. |

Mevcut Module 7 hazırlık ve Module 11 izolasyon yaklaşımı yeniden kullanıldı. Module 8'deki sonradan dependency kesintisi yeniden çalıştırılmadı. Yeni deney kaynakları geçici yardımcıyla doğrulandı; helper exit0 ve cleanup PASS verdi. Uygulama source değişmediğinden ayrı uygulama davranışı/build refactoring yapılmadı; EF SQL üretimi gerekli Release hazırlığını kullandı.

Cleanup yalnız bu project'in container/ağlarını `down --remove-orphans` ile kaldırdı. Compose-managed test volume'ları varsa project label ve adları kontrol edilerek, test PostgreSQL volume'u ise **tam adı + owner label** doğrulanarak kaldırıldı. `down -v`, volume/system prune veya development volume silme kullanılmadı. Tek fixture Task, yalnız silinen test volume'undaydı; development Task/cache kayıtlarına işlem yapılmadı. Geçici fixture/SQL/override/helper/sonuç dosyaları temizlendi. Başlangıçta çalışan stack down yapılmadı. Son kontroller PASS: repository secret taraması, ana Compose'nun `.env.example` ile sessiz config kontrolü, 11 göreli bağlantı/anchor, dokuz başlık ve diff/whitespace kontrolleri. Son salt okunur Compose ps de başlangıçtaki altı servisin running/healthy kaldığını doğruladı. Commit/push yapılmadı; altıncı senaryoya geçilmedi.

## What We Learned

- Running PostgreSQL container, bağlantı kabul eden PostgreSQL server demek değildir.
- `service_started` container başlangıcını; `service_healthy` dependency healthcheck başarısını bekler.
- Server readiness, şema/migration hazırlığı ve gerçek DB kaydı ayrı doğrulanır.
- Liveness200 ile readiness503 ve DB GET500 aynı anda mümkündür; API'nin crash etmesi şart değildir.
- Tekil DB GET, liste cache'inin bağlantı sorununu gizlemesini önler.
- Başlangıç sırası düzeltmesi sonraki kesintiler için otomatik recovery sistemi değildir.
- Kontrol edilen gate ve gerçek pg_isready sonucu, tahmini sleep süresinden daha açık bir deney kanıtıdır.

Önerilen commit mesajı: `docs(troubleshooting): verify PostgreSQL startup readiness ordering`. Sonraki adım yalnız bu senaryonun commit öncesi incelemesidir; Environment Misconfiguration senaryosuna otomatik geçilmez.

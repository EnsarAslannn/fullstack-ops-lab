# Modül 10 — Docker-native gözlem, backend metrics, Prometheus ve Grafana

Bu README sırasıyla Docker-native gözlem, backend metrics, Prometheus internal scrape, Grafana datasource ve Overview dashboard adımlarını belgeler. Önceki bölümler kendi kabul tarihindeki snapshot'tır; güncel **altı servisli** topoloji datasource bölümünde, dashboard sorguları **Overview dashboard provisioning** bölümündedir. **4 Ekim 2026 güncel sonuç: COMPLETE.** 3 Ekim final incelemesinde belirlenen dört eksik aşağıdaki **Şartname farklarının kapatılması** bölümünde gerçek kanıtlarla kapatıldı. Kabul matrisi güncellendi; önceki tarihli deneylerin sonuçları tarihsel kayıt olarak korunur.

**İlk adım: 2 Ekim 2026 PASS. Module 10 final kabulü: 4 Ekim 2026 COMPLETE.**

## Amaç ve sınırlar

Mevcut dört servisli uygulama hangi sorulara cevap verebiliyor? Yeni monitoring altyapısı, endpoint, paket, dashboard veya log configuration eklemeden gerçek çalışma, istek ve bağımlılık kesintileri gözlemlendi. Uygulama kodu, Compose, `.env` ve user-secrets değiştirilmedi. Yerel secret değerleri ve çözümlenmiş connection string'ler yayınlanmadı; loglar paylaşılmadan önce geçici gözlem kodunda configuration değerleri redakte edildi. Tam `docker inspect` veya düz çözümlenmiş Compose çıktısı gösterilmedi.

Başlangıç Git durumu temizdi. Docker Engine **29.6.1**, Compose **v5.3.0** erişilebilirdi. Projenin stack'i başlangıçta yoktu. **12 ilişkisiz stopped container, 7 network ve 19 volume** için başlangıç envanteri kaydedildi. Var olan external `fullstack-ops-postgres-data` kullanıldı; başka projelerin kaynakları hedeflenmedi.

## Çalıştırılan komutlar

Komutlar repository kökünde PowerShell ile çalıştırıldı. `--env-file .env` dosyayı okur, değerlerini terminale yazdırmayı gerektirmez. Logların hassas veri içerebileceğini unutma; paylaşmadan önce incele/redakte et.

| Komut | Amaç ve gözlem |
| --- | --- |
| `git status --short`, `git status --branch --short` | Temiz başlangıç ve final dokümantasyon kapsamı. |
| `docker version`, `docker info --format '{{.ServerVersion}}'`, `docker compose version` | Engine ve Compose erişimi. |
| `docker ps -a --no-trunc --format '{{.ID}}\|{{.Names}}\|{{.State}}'` | Command/environment alanlarını göstermeden container envanteri. |
| `docker network ls --no-trunc --format '{{.ID}}\|{{.Name}}'`, `docker volume ls --format '{{.Name}}'` | Başlangıç/bitiş kaynak karşılaştırması. |
| `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/Module9.EnvPreflight.ps1` | Git dışındaki `.env`, zorunlu key'ler, sessiz Compose doğrulaması ve external volume; başarılı. |
| `docker compose --env-file .env config -q` | Çözümlenmiş değerleri göstermeyen statik kontrol; başarılı. |
| `docker compose --env-file .env up -d --wait --wait-timeout 180` | Mevcut image'larla dört servisi başlatma; hepsi running/healthy. |
| `docker compose --env-file .env ps --format '{{.Service}}\|{{.State}}\|{{.Health}}'` | Servis bazında state/health. |
| `docker compose --env-file .env logs --no-color --tail 50 SERVICE` | Dört servisin son log satırları. |
| `docker compose --env-file .env logs --no-color --timestamps --tail 50 SERVICE` | Aynı çıktıda Docker UTC zaman damgası. |
| `docker compose --env-file .env logs --no-color --timestamps --since TIMESTAMP api` | Kontrollü ilk miss/hit penceresini ayırma. |
| `docker logs --tail 30 --timestamps API_CONTAINER_ID` | Aynı API log kaynağına container CLI üzerinden erişme. |
| `docker inspect --format '{{json .State}}' ID` | Yalnız state/health/probe sonuçları; `.Config.Env` alınmadı. Probe output da hassas olabileceğinden paylaşım öncesi redakte edildi. |
| `docker inspect --format '{{.RestartCount}}' ID` | Başlangıçta dört serviste 0. |
| `docker inspect --format '{{json .NetworkSettings.Networks}}' ID` | Yalnız ağ bağlantısı; dört servis `fullstack-ops-lab_app` üzerinde. |
| `docker stats --no-stream --format '{{json .}}' FRONTEND_ID API_ID POSTGRES_ID REDIS_ID` | Yalnız bu dört servisin tek kaynak örneği. |
| `powershell -NoProfile -ExecutionPolicy Bypass -File tests/Module8.Readiness.Smoke.ps1` | Mevcut bağımlılık kesinti/toparlanma testi; DB kaydı yazmaz. |
| `docker inspect --format '{{.HostConfig.LogConfig.Type}}\|{{.HostConfig.Memory}}' API_ID` | Log driver ve API bellek sınırı. |
| `docker compose --env-file .env down` | Başlangıçta kapalı olan bu görev stack'ini kaldırma; external volume korunur. |
| `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/Module9.SecretLeakage.Check.ps1`, `git diff --check`, `git status --short` | Son güvenlik ve değişiklik kapsamı kontrolü. |

Gözlem yardımcıları yalnız benzersiz geçici klasördeydi; yeni kalıcı test/CI script'i eklenmedi. DB karşılaştırması `psql -X -v ON_ERROR_STOP=1 -t -A -f /dev/stdin` ile **salt okunur SELECT** sonuçlarının hash'i üzerinden yapıldı; mevcut kayıtların içeriği yayınlanmadı.

## Logların farklı rolleri

| Kaynak | Gerçek gözlem | Söylemediği bilgi |
| --- | --- | --- |
| Frontend/Nginx | Startup/worker kayıtları; access logunda yöntem, URI, HTTP status, response byte sayısı, istemci ve zaman. GET 200, POST 201, PUT 200, DELETE 204 görüldü. `GET /` Wget kayıtları health probe trafiğidir. | Mevcut access formatında request/upstream süre alanı yok; DB veya cache işlemini açıklamaz. |
| API | `Application started`, port 8080; EF Core SQL/DbCommand süreleri; `[CACHE MISS]`, `[CACHE HIT]`, `[CACHE INVALIDATED]`; kesintilerde health ve exception kayıtları. EF parametre değerleri `?` olarak göründü. | `Microsoft.AspNetCore=Warning` nedeniyle normal başarılı isteklerin kapsamlı request-start/end logları görünmüyor. SQL süresi uçtan uca request süresi değildir. |
| PostgreSQL | Mevcut database bulunduğu için initialization atlandı; dinleme/readiness, shutdown ve yeniden startup olayları. | Bu ayarlarla her SELECT/CRUD sorgusu PostgreSQL loguna yazılmaz; HTTP Task ID'sine bağlı istek zinciri yok. |
| Redis | Startup ve module kayıtları, bağlantı kabulüne hazır olma, kapanma ve yeniden startup. | Uygulamanın her GET/SET/DEL işlemi veya Task-cache hit/miss'i normal server loguna düşmez; uygulama cache olayları API logundadır. |

**Kontrollü HTTP akışı:** İlk iki liste isteği 200; API loglarında ilkinde **1 miss**, ikincisinde **1 hit**. Benzersiz test görevi **ID 37** POST 201 ve doğru Location ile oluşturuldu, listede bulundu, PUT 200 ile tamamlandı, DELETE 204 ile silindi. Bu kısa pencerenin toplamı **2 miss, 1 hit, 3 invalidation** idi: oluşturma sonrası yeniden listeleme ikinci miss'i üretti. Bunlar elle ayrılmış pencere sayımlarıdır, uygulamada kalıcı metric counter olduğu anlamına gelmez.

Güvenli örnek olaylar:

```text
2026-10-02T11:45:15.398601125Z [CACHE INVALIDATED] fullstack-ops:tasks:all:v1
2026-10-02T11:45:15.414989792Z [CACHE MISS] fullstack-ops:tasks:all:v1
2026-10-02T11:45:15.507628313Z [CACHE INVALIDATED] fullstack-ops:tasks:all:v1
2026-10-02T11:45:15.523742332Z Nginx: DELETE /api/tasks/37 -> 204
```

Nginx yöntemi/yolu/zamanı ile API cache/SQL zamanını yaklaşık eşleştirmek mümkün. Ortak uygulama correlation ID'si veya servisler boyunca doğrulanmış trace yok. Yakın zamanlar, özellikle eşzamanlı kullanıcı trafiği ve health probe'ları varken, aynı isteği kesin olarak kanıtlamaz. Framework'ün hata metninde RequestId/TraceId bulunması tek başına distributed tracing değildir.

**Başlangıç uyarıları:** API `libgssapi_krb5.so.2` yüklenemedi mesajı verdi; buna rağmen readiness ve gerçek CRUD başarılıydı. Redis modüllerinde `_FT.DROP`/`_FT.DROPINDEX` command kayıt uyarıları görüldü; servis healthy oldu. Bu mesajlar gizlenmedi, ancak nedenleri bu adımda kapsamlı teşhis edilmedi ve image/paket/config değişikliği yapılmadı.

## Kaynak kullanımı — tek örnek

Ölçüm **2 Ekim 2026, 14:45:16.977–14:45:19.905 Türkiye saati (UTC+03:00)**; Docker UTC karşılığı **11:45:16.977–11:45:19.905Z**. CRUD sonrasında, kontrollü kesintiden önce alındı.

| Servis | CPU | Bellek / limit | Network I/O | Block I/O | PIDs |
| --- | ---: | --- | --- | --- | ---: |
| frontend | 0.00% | 22.89 MiB / 15.23 GiB | 6.22 kB / 6.87 kB | 3.77 MB / 8.19 kB | 25 |
| api | 0.27% | 74.24 MiB / 15.23 GiB | 28.2 kB / 23.3 kB | 131 MB / 0 B | 53 |
| postgres | 0.08% | 50.25 MiB / 15.23 GiB | 13.7 kB / 17.9 kB | 42.2 MB / 631 kB | 10 |
| redis | 0.40% | 11.88 MiB / 15.23 GiB | 10.5 kB / 5.63 kB | 52.4 MB / 0 B | 6 |

Değerler Docker CLI'dan aynen alındı; MB ile MiB farklı birimlerdir. `--no-stream` ilk örneği verir. Bu **benchmark, yük testi, peak, geçmiş trend veya kapasite planı değildir**. Network ve block byte toplamları hız değildir. PIDs süreç **ve thread** sayısını kapsar. Linux Docker CLI memory hesabı cache düşümü içerir ([Docker stats belgesi](https://docs.docker.com/reference/cli/docker/container/stats/)). Compose servis bazında bellek limiti tanımlamıyor; görüntülenen 15.23 GiB'yi bu servis için ayrılmış bellek olarak yorumlama.

## Health, inspect ve kontrollü kesinti

Normal snapshot'ta dört servis running/healthy, RestartCount **0** ve son probe exit code'ları **0** idi. Ağ bağlantıları tek `fullstack-ops-lab_app` ağına aitti: redis `172.22.0.2`, postgres `172.22.0.3`, api `172.22.0.4`, frontend `172.22.0.5`. Bunlar bu çalışmanın geçici IP'leridir; bağlantılarda servis DNS adı kullanılır. PostgreSQL probe'u `accepting connections`, Redis `PONG`; API/HTTP probe'ları başarılı olduğunda boş output verdi. Health history yalnız son birkaç probe'u saklar, kalıcı olay geçmişi değildir.

`tests/Module8.Readiness.Smoke.ps1` **değiştirilmeden** çalıştırıldı; bu Compose topolojisine uygundur. Her dependency'yi ayrı stop/start yaptı, DB kaydı yazmadı. PostgreSQL kesintisi öncesinde yalnız bu testte oluşturulmuş liste cache key'i temizlendi; böylece cache hit DB kesintisini gizlemedi.

| Durum | API state | Docker health | `/health` | `/health/live` | `/health/ready` | Liste |
| --- | --- | --- | ---: | ---: | ---: | ---: |
| Normal | running | healthy | 200 | 200 | 200 | 200 |
| Redis stopped | running | unhealthy | 200 | 200 | 503 | 500 |
| Redis restored | running, aynı ID | healthy | 200 | 200 | 200 | 200 |
| PostgreSQL stopped, cache boş | running | unhealthy | 200 | 200 | 503 | 500 |
| PostgreSQL restored | running, aynı ID | healthy | 200 | 200 | 200 | 200 |

API container ID'si `12ea3400a02b` ve StartedAt değeri değişmedi. Son snapshot'ta dört servis healthy, failing streak **0**, RestartCount yine **0** idi. Readiness'i kaybetmek API prosesinin öldüğü veya Docker'ın otomatik restart yaptığı anlamına gelmedi.

Olayları log ve inspect ile ilişkilendirme (UTC; Türkiye saati için +3 saat):

- **11:46:23.787Z:** Redis logunda SIGTERM; **11:46:23.872Z** shutdown. API `Redis unavailable` check'leri yaklaşık **5.5–5.8 saniye** sürdü; liste GET'inde `RedisConnectionException` görüldü.
- **11:47:01.795Z:** Eşzamanlı inspect'te API running/unhealthy, failing streak **5**. Son beş probe exit **-1**, output `Health check exceeded timeout (3s)`.
- **11:47:08.346Z:** Redis yeniden bağlantı kabul ediyordu; kısa bir geçiş snapshot'ında API Docker health hâlâ unhealthy idi. Health bilgisi sonraki başarılı probe'a kadar gecikebilir.
- **11:47:10.764Z:** PostgreSQL fast shutdown; **11:47:10.791Z** shut down. API `PostgreSQL unavailable` ve SQL bağlantı hatası kaydetti; stopped servisin DNS çözümü için `Name or service not known` mesajı görüldü.
- **11:47:50.571Z:** PostgreSQL durmuşken API running/unhealthy, failing streak **5**; son probe'lar yine 3 saniye timeout, exit **-1**.
- **11:47:54.443Z:** PostgreSQL yeniden ready. Mevcut test aynı API instance'ında ready 200 ve Docker healthy toparlanmasını doğruladı.

Önemli ayrım: HTTP ile beklenerek alınan readiness **503**, Docker probe exit **-1** ile aynı ölçüm değildir. Gerçek dependency check log süreleri PostgreSQL için yaklaşık **4 saniye**, Redis için **5.5–5.8 saniye** oldu; Docker probe sınırı **3 saniye** olduğundan burada HTTP durum satırını görmeden timeout oluştu. Kodda 2 saniye health timeout kayıtlı olması bu deneyde katı bir uçtan uca süre sınırı sağlamadı. Bunun nedenleri/timeout politikası bu gözlem adımında değiştirilmedi; sonraki iyileştirme için ayrı bulgudur. Test, başarısız probe ve HTTP sonucunu ayrı doğruladı.

API inspect'te log driver **`json-file`**, bellek sınırı **0** çıktı. Docker driver container stdout/stderr ve zaman damgalarını yerel container dosyasında tutar; bu merkezi log sistemi değildir ([Docker JSON logging](https://docs.docker.com/engine/logging/drivers/json-file/)). `compose logs --tail` ve `--timestamps` yalnız görünümü seçer ([Compose logs](https://docs.docker.com/reference/cli/docker/compose/logs/)); uygulama log formatını veya retention politikasını değiştirmez. `down` sonrası test container loglarını kalıcı arama geçmişi sayma.

## Kavramlar

| Kavram | Açıklama ve proje örneği |
| --- | --- |
| Log | Belirli olayı kaydeder: bir GET'te CACHE MISS, SQL hatası veya PostgreSQL shutdown. |
| Metric | Sayısal değerin zaman içindeki örnekleri/toplamlarıdır: request counter, gecikme histogramı, bellek gauge. Tek stats çıktısı kalıcı zaman serisi oluşturmaz. |
| Trace | Tek isteğin farklı işlemler/servisler boyunca izlediği yolu ve süreleri gösterir; bu projede toplanmış trace yok. |
| Healthcheck | Belirli anda tanımlanmış koşulu sınar: `/health/ready` DB/Redis erişimini kontrol eder. Başarılı probe tüm iş akışlarını garanti etmez. |
| Monitoring / observability | Monitoring bilinen durumları izler ve gerektiğinde uyarır. Observability, sistemin dış sinyallerinden neden sorusunu araştırmayı sağlar. Log, metric ve trace bu araştırmayı destekler; tek yeşil health sonucu yeterli değildir. |

## Docker-native adımının sonunda eksikler ve sonraki küçük adım — 2 Ekim 2026

| Soru | Mevcut cevap |
| --- | --- |
| Kalıcı metric geçmişi var mı? | Bu uygulama için collector/time-series deposu yok; stats snapshot'ı geçmiş değildir. |
| Request sayısı, hata oranı, süre var mı? | Nginx tekil status kayıtları elle sayılabilir; EF yalnız SQL süreleri verir. Proje request rate/error-rate/p95 ölçümlerini export edip saklamıyor. |
| Cache hit/miss sayısal izleniyor mu? | API logunda olay var; uygulama metric counter/exporter'ı yok. Genel Redis server istatistiği Task-cache metric'i yerine geçmez. |
| Merkezi log deposu var mı? | Compose logs container çıktısını birleştirir; merkezi kalıcı collector/arama altyapısı değildir. |
| Servisler arası trace var mı? | Ortak korelasyon/tracing/exporter kurulmuş değil. |
| Alerting var mı? | Health status var; bu proje için alarm kuralı ve bildirim kanalı yok. |

Şartnameye göre sonraki küçük adım: backend'in `System.Diagnostics.Metrics` / OpenTelemetry Metrics yaklaşımını ve internal `/metrics` sözleşmesini planlayıp uygulamak; request/runtime ve cache hit/miss/invalidation ölçümlerini doğrulamak. Sonraki adımda metric adları ve sınırlı label'lar gerçek çıktıyla eşleştirilmeli; Task ID, request ID, raw URL ve exception metni label olmamalıdır. **Bu görevde uygulanmadı.** Prometheus toplama, Grafana sunum işi daha sonradır; Module 10 bütünü tamamlanmadı.

## Cleanup ve doğrulama sınırları

- Başlangıçta mevcut `tasks` **1**, `lab_tasks` **1**, migration history **1** idi. Yalnız benzersiz test görevi oluşturulup silindi; sonunda yine aynı sayılar ve aynı satır-içerik hash'i görüldü. Sequence sayacı normal INSERT nedeniyle ilerleyebilir; cleanup sırasında reset edilmedi. Migration ve mevcut kullanıcı kaydı korunmuştur.
- Başlangıçta Redis liste key'i yoktu; gözlem/testlerle oluşan `fullstack-ops:tasks:all:v1` key'i Module 8 testi sonunda yoktu. Salt okunur readiness key'i de yoktu. Başka key silinmedi; Redis'in tamamı flush edilmedi.
- Stack başlangıçta yoktu; bu görevde başlatılan stack `down` ile kapatıldı. Başlangıç/bitişte ilişkisiz **12 container aynı ID ve exited state**, **7 network aynı ID**, **19 volume aynı ad** olarak bulundu. Bu deneyde varsayılan `bridge` ID'si **değişmedi**.
- External `fullstack-ops-postgres-data` kaldı; `.env` ve user-secrets SHA256 değerleri başlangıçla aynıydı. Hash/secret değerleri yayınlanmadı. `down -v` ve prune kullanılmadı.
- Geçici redakte loglar, stats/health snapshot'ları, envanter ve yardımcı dosyalar temizlendi. Proje bağımlılığı veya kalıcı script eklenmedi. Yalnız bu README ve `PROJECT_STATUS.md` değişti; final secret leakage check ve `git diff --check` geçti.
- Bu mevcut host/volume üzerinde düşük trafikli gözlemdir; tarayıcı testi, yük testi, production kabulü, sürekli metric toplama veya root-cause çözümü değildir. Health probe ve test HTTP trafiği kaynak kullanımına/loglara dahildir. API başlangıç uyarıları ile timeout davranışı bulgu olarak kalır; monitoring altyapısı veya configuration düzeltmesi uygulanmadı.

Öğrenilecek ayrım: “running”, “healthy”, “bu isteğin başarılı olması” ve “zaman içindeki performans” farklı sorulardır. Bir cache logunu görmek, cache hit oranının zaman serisine sahip olmak anlamına gelmez; `compose logs` ile aynı saatlerde olay görmek de servisler arası trace oluşturmaz.

### Aynı isteğin tekrarında salt okunur kontrol

2 Ekim 2026 tarihinde görev tekrar istendiğinde yalnız önceki iki dokümantasyon değişikliği Git'te bekliyordu; çalışma alanı o anda temiz değildi. Tamamlanan CRUD/kesinti/stats deneyi tekrarlanmadı. Engine 29.6.1, Compose v5.3.0, env preflight, sessiz `config -q`, secret taraması ve diff kontrolü yeniden geçti. Envanter yine 12 container / 7 network / 19 volume, bu projeye ait container sayısı 0 ve external PostgreSQL volume'u mevcut idi.

Önceki deneyin başında ve sonunda bridge ID'si `15ec03a4723c` olarak aynıydı. Bu sonraki salt okunur kontrolde `7b9da9a86ad9` görüldü; değişim önceki envanter ile bu kontrol arasında olmuştu. Nedeni doğrulanmadı; bu tekrar kontrolünde stack başlatılmadı, network create/remove veya Docker configuration değişikliği yapılmadı. İlk deneydeki korunma sonucu ile bu sonraki gözlem birbirinden ayrıdır. Yukarıdaki kaynak tablosu yeni ölçüm değil, 14:45'teki gerçek örnektir.

## Backend metrics — ikinci küçük adım, 3 Ekim 2026

Amaç uygulamanın metrik üretmesidir. Bu adım Prometheus/Grafana servisi, collector, tracing, dashboard veya alarm eklemez. Task API contract'ı, cache key'i, TTL configuration, invalidation politikası, health kontrolleri, Compose/Nginx ve frontend değişmedi. Başlangıç Git durumu temizdi; önceki Docker-native deneyi yeniden yapılmadı.

### Yaklaşım ve kesin paket sürümleri

- `System.Diagnostics.Metrics`: .NET 10'un hazır `Microsoft.AspNetCore.Hosting`, `Microsoft.AspNetCore.Server.Kestrel` ve `System.Runtime` meter'ları ile uygulamanın `FullStackOpsLab.Api.Cache` meter'ı.
- `OpenTelemetry.Extensions.Hosting` **1.19.1**: DI ile tek MeterProvider'ın yaşam döngüsü ve aggregation.
- `OpenTelemetry.Exporter.Prometheus.AspNetCore` **1.19.1-beta.1**: internal scrape endpoint'i. Paketlerin net10.0 asset'leri var ([Hosting NuGet](https://www.nuget.org/packages/OpenTelemetry.Extensions.Hosting/1.19.1), [exporter NuGet](https://www.nuget.org/packages/OpenTelemetry.Exporter.Prometheus.AspNetCore/1.19.1-beta.1)).

Hazır HTTP/runtime metriklerini ikinci bir instrumentation paketi veya custom HTTP middleware ile tekrar üretmiyoruz. Request sayısı hazır süre histogramının `_count` serisinden gelir. Microsoft'un [metrics örneği](https://learn.microsoft.com/en-us/aspnet/core/metrics/overview?view=aspnetcore-10.0) hazır meter'ları exporter'a bağlamayı gösterir; [runtime belgeleri](https://learn.microsoft.com/en-us/dotnet/core/diagnostics/built-in-metrics-runtime) `System.Runtime` kaynağını açıklar. Kesin ad/tipler bu çalışmanın gerçek scrape çıktısından alınmıştır.

Exporter hâlâ beta: API/format değişiklikleri mümkün. Bu öğrenme adımı için şartnamedeki doğrudan `/metrics` yaklaşımı kullanıldı; production uygunluğu burada kanıtlanmadı. [Resmî exporter belgesi](https://github.com/open-telemetry/opentelemetry-dotnet/blob/main/src/OpenTelemetry.Exporter.Prometheus.AspNetCore/README.md) endpoint'in varsayılan olarak authentication sağlamadığını ve beta durumunu açıklar. Scrape response cache'i `0` ms: ardışık kabul testleri eski 300 ms response'u okumaz; bunun toplama maliyeti vardır.

### Gerçek metric isimleri, tipleri ve birimleri

Prometheus isimleri nokta yerine underscore ve gereken unit/type suffix'leri kullanır. Aşağıdaki isimler `Accept: text/plain;version=0.0.4` ile doğrulandı.

| Prometheus serisi / family | .NET instrument | Export tipi | Birim ve anlam |
| --- | --- | --- | --- |
| `http_server_request_duration_seconds_count` | `http.server.request.duration` | Histogram'ın cumulative count serisi | Tamamlanan API HTTP isteklerinin adedi; ayrı, tekrarlayan bir request counter yok. |
| `http_server_request_duration_seconds` (`_bucket`, `_sum`, `_count`) | `http.server.request.duration` | Histogram | Saniye; süre dağılımı, toplam süre ve adet. Status label'ı 400/404/500'ü ayırır. |
| `http_server_active_requests` | `http.server.active_requests` | Gauge | Anlık aktif istek sayısı. |
| `kestrel_active_connections` | `kestrel.active_connections` | Gauge | Anlık açık bağlantı sayısı. |
| `kestrel_connection_duration_seconds` | `kestrel.connection.duration` | Histogram | Bağlantı süresi, saniye. HTTP request süresi ile aynı ölçüm değil. |
| `dotnet_process_cpu_time_seconds_total` | `dotnet.process.cpu.time` | Counter | Prosesin user/system CPU zaman toplamı, saniye; CPU yüzdesi değil. |
| `dotnet_process_memory_working_set_bytes` | `dotnet.process.memory.working_set` | Gauge | Prosesin working set'i, byte; Docker stats memory hesabıyla birebir aynı değildir. |
| `dotnet_gc_heap_total_allocated_bytes_total` | `dotnet.gc.heap.total_allocated` | Counter | Managed heap allocation toplamı, byte. |
| `dotnet_gc_collections_total` | `dotnet.gc.collections` | Counter | GC collection sayısı; generation label'ı sınırlıdır. |
| `dotnet_gc_pause_time_seconds_total` | `dotnet.gc.pause.time` | Counter | GC pause toplam süresi, saniye. |
| `dotnet_thread_pool_thread_count_total` | `dotnet.thread_pool.thread.count` | Counter (bu runtime/exporter çıktısı) | Thread count serisi; farklı runtime sürümlerinden kopyalanan isim/tip yerine gerçek TYPE kullanılır. |
| `fullstackops_cache_hits_total` | `fullstackops.cache.hits` | Counter | Task liste cache'inden okunup deserialize edilen cevap adedi. |
| `fullstackops_cache_misses_total` | `fullstackops.cache.misses` | Counter | Redis okuması başarılı olup değerin bulunmadığı olay adedi. |
| `fullstackops_cache_invalidations_total` | `fullstackops.cache.invalidations` | Counter | Başarılı DB mutation sonrası tamamlanan cache remove işlemi adedi. |

Runtime çıktısında ayrıca assembly, exception, GC heap/committed/fragmentation, JIT, lock, process CPU count, thread-pool queue/work-item ve timer serileri bulundu. Kestrel queued connections serisi de görüldü. Bunlar aynı hazır meter'ların çıktısıdır; ikinci bir runtime collector eklenmedi. Event gerçekleşmeden bazı instrument'ların sample serisi henüz görünmeyebilir; sıfır series yerine absent series bulunması normaldir.

**Runtime tip sınırı:** Thread-pool thread count ve queue length bu .NET 10 çıktısında Counter/`_total` olarak export edildi, ancak anlık değerleri azalabilir. Bu gözlem [.NET runtime #126167](https://github.com/dotnet/runtime/issues/126167) ile uyumludur; bu serilere monoton event counter gibi `rate()` uygulama. HTTP count, allocation/CPU ve uygulama cache event counter'ları bu iki thread-pool tip hatasıyla karıştırılmamalıdır. Upstream düzeltme/runtime yükseltmesi veya ayrı bir workaround bu adımda uygulanmadı.

**Counter:** Olayları toplar; process yaşamı boyunca birikir. **Gauge:** O andaki değeri bildirir; artabilir veya azalabilir. **Histogram:** Her süreyi bucket'lara yerleştirir; count/sum/bucket sunar. Histogram family'yi `p95` diye adlandırmıyoruz. İleride Prometheus ile örneğin aşağıdaki sorgu kullanılabilir; bu görevde Prometheus çalışmadığından sorgu henüz çalıştırılmadı:

```promql
histogram_quantile(0.95,
  sum by (le) (rate(http_server_request_duration_seconds_bucket{http_route="/api/tasks/",http_request_method="GET"}[5m])))
```

Bucket sınırları saniye olarak `0.005, 0.01, 0.025, 0.05, 0.075, 0.1, 0.25, 0.5, 0.75, 1, 2.5, 5, 7.5, 10`; exporter ayrıca `+Inf` bucket'ını verir. Bu dağılımdan hesaplanan p95 yaklaşık bir percentile'dır, doğrudan her request'in logu değildir.

### Label ve probe politikası

Request duration view yalnız `http.request.method`, `http.route`, `http.response.status_code` tag'lerini saklar; exporter isimleri `http_request_method`, `http_route`, `http_response_status_code` olur. Liste template'i gerçekte **`/api/tasks/`**, ID endpoint'leri **`/api/tasks/{id:int}`**. HTTP çağrıları hâlâ `/api/tasks` ve `/api/tasks/ID` kullanır; route contract değişmedi.

Task ID, başlık, raw URL, kullanıcı verisi, connection string ve exception mesajı label değildir. Cache counter'ları custom label içermez. Exporter'ın sabit `otel_scope_name` label'ı meter kaynağını belirtir; histogram bucket'ının `le` label'ı sınırı belirtir. Runtime/Kestrel hazır tag'leri de kendi kaynaklarına aittir (ör. GC generation, CPU mode, exception **tipi**); exception mesajı eklenmez.

`/health`, `/health/live`, `/health/ready` ve `/metrics` mapping'lerinde `DisableHttpMetrics()` kullanılır: request **duration/count** serilerini health/scrape probe'larıyla kirletmezler. Kestrel bağlantı, aktif istek ve runtime kaynak kullanımı probe trafiğinin maliyetini yine içerebilir. Test, HTTP duration label set'ini ve health/metrics route serisi bulunmadığını kontrol eder; karşılaştırmalar ayrıca method/template/status ile filtrelenir. Test sırasında başka API trafiği olmamalıdır.

Cache semantics:

- Cache read exception => hit/miss artırılmaz; mevcut HTTP 500 davranışı korunur.
- Cache değeri deserialize edilmeden hit sayılmaz. Boş `[]` geçerli bir hit'tir.
- Başarılı Redis read'de değer yoksa miss'tir; sonraki DB read'in başarısız olması bunu cache error'a dönüştürmez.
- RemoveAsync başarıyla tamamlandıktan sonra invalidation artırılır. Key zaten yoksa da başarılı remove işlemi sayılır; counter fiziksel silinen key adedi değildir.
- DB write başarılı, invalidation başarısızsa mevcut warning/başarılı mutation response politikası korunur; invalidation counter artmaz. 400/404 mutation'lar invalidation oluşturmaz.
- Cache error için yeni counter/retry/fail-open eklenmedi; hata logları ve HTTP 5xx incelenir.

### Internal erişim ve sınırı

Compose değişmedi: API yalnız **8080 internal**, host'ta API port mapping'i yok. Nginx yalnız `/api/` yolunu proxy eder. Diagnostic container gerçek Compose ağındaki API'ye `http://api:8080/metrics` ile erişir. Test var olan frontend image'ının curl aracını ayrı, benzersiz isimli `--rm` container'da kullanır; yeni image/paket gerektirmez.

Frontend host adresi `http://127.0.0.1:18081/metrics` **200 text/html SPA fallback** döndürür; bu gerçek metrik erişimi değildir. Test, hem Content-Type hem metric family içeriğinin bulunmamasını kontrol eder. Internal endpoint ise **200 text/plain;version=0.0.4** ve histogram TYPE/sample'ları döndürdü.

Internal network authentication değildir: aynı ağa erişen container'lar bu endpoint'i okuyabilir. Host üzerinde API'yi doğrudan geliştirici olarak çalıştırmak da metrics endpoint'ini o prosesin dinlediği adreste açar; burada kanıtlanan dışarı yayınlamama sınırı mevcut Compose/Nginx topolojisidir. Authentication/production erişim kontrolü bu görevde eklenmedi.

### Komutlar ve tekrar çalıştırma

Repository kökünde, mevcut `.env` ve hazırlanmış external PostgreSQL volume'u ile:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/Module9.EnvPreflight.ps1
docker compose --env-file .env config -q
dotnet build src/backend/FullStackOpsLab.Api/FullStackOpsLab.Api.csproj -c Release
docker compose --env-file .env build api
docker compose --env-file .env up -d --wait --wait-timeout 180
powershell -NoProfile -ExecutionPolicy Bypass -File tests/Module10.Metrics.Smoke.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File tests/Phase0B.Tasks.Smoke.ps1 -BaseUrl http://127.0.0.1:18081
powershell -NoProfile -ExecutionPolicy Bypass -File tests/Module8.Readiness.Smoke.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File tests/Module9.Configuration.Smoke.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/Module9.SecretLeakage.Check.ps1
git diff --check
```

Yeni smoke testi hazır/izole trafik alan bir stack bekler; servisleri kendi başlatmaz/kapatmaz. Başlangıç liste cache key'i yok olmalıdır; mevcut cache'i otomatik silerek başlamaz. Fixture yalnız kendi Task kayıtlarını ve sahip olduğu liste key'ini temizler. Gerçek TTL expiration beklemesi **120 saniye** ile sınırlıdır; uzun TTL configuration için bu süre kabul testi sınırlamasıdır, uygulama configuration sınırı değildir. Varsayılan 60 saniye ile doğrulandı. `-EndpointOnly` sadece endpoint/TDD kontrolü içindir; tam kabul yerine geçmez.

Boş liste hit testi mevcut kullanıcı verilerini silmez: ilk miss ile oluşmuş test cache'inin `data` hash field'ına geçici `[]` yazar, GET'in 200/[] ve hit +1 döndürdüğünü kanıtlar, sonra yalnız bu key'i temizler. **Bu, boş veritabanından liste üretme deneyi değildir.** Gerçek DB kayıtları aynı kalır. Cache key'e bu müdahale nedeniyle testi kullanıcı trafiği varken çalıştırma.

Module 5 script'i ilk listenin gerçek DB'de boş olmasını, ayrı lab container adlarını ve farklı host portunu bekler; mevcut dolu development volume'u üzerinde körlemesine çalıştırılmadı. Aynı cache kabul davranışları (miss/hit, boş-hit, TTL, başarılı invalidation, 400/404 non-invalidation, Redis failure) yeni smoke testinde Nginx/Compose üzerinden doğrulandı. Phase 0A script'i Nginx'in proxy etmediği `/health`/OpenAPI host yollarını bekler; bu iki kontrol internal curl ile yapıldı. Module 8 ve Phase 0B script'leri değiştirilmeden doğru topolojiyle çalıştırıldı.

### Gerçek kabul sonucu ve cleanup

**PASS — 3 Ekim 2026.** Son smoke çıktısı **12:30:58–12:32:18 Türkiye saati (+03)** aralığında kaydedildi (geçici output dosyasının oluşturma/son yazma zamanları). SDK **10.0.401**, Release build **0 warning / 0 error**. Compose config/preflight ve secret leakage kontrolü başarılı. İlk Engine sorgusu erişemedi; `docker desktop start --detach` zaten çalıştığını söyledi, sonraki Engine sorgusu **29.6.1**, Compose **v5.3.0** döndürdü. Docker configuration değiştirilmedi.

TDD'de yeni `-EndpointOnly` testi eski image üzerinde **internal /metrics HTTP 200 değil** nedeniyle exit 1 verdi; implementation sonrası geçti. HTTP instrument'ı ilk ölçümden önce series üretmediği için veri yazmayan boş başlık POST warmup'ı kullanıldı. Testteki route/thread-pool isimleri gerçek exporter çıktısıyla eşleştirildi; API URL'si değiştirilmedi.

| Ölçüm | Son kontrollü koşunun gerçek sonucu |
| --- | --- |
| Başlangıç (warmup sonrası, restart edilmiş proses) | HTTP count **1**; cache hit/miss/invalidation **0 / 0 / 0**. |
| İlk iki liste GET'i | HTTP count **+2**, cache miss **+1**, hit **+1**. |
| Boş cache cevabı | GET **200/[]**, hit **+1**, miss **+0**; DB kayıtları silinmedi. |
| Ana CRUD/validation penceresi | HTTP histogram count **+13**; cache misses **+3**, hits **+2**, invalidations **+3**. |
| Liste route histogramı | `+Inf` bucket **+7** (5 GET, 2 POST); `_sum` farkı **0.5489266 saniye**. Bu bir p95 veya benchmark sonucu değil. |
| Status ve template ayrımı | POST **201/400**, ID-template GET **200/404**, PUT **200/404**, DELETE **204/404** için ilgili count serileri ayrı ayrı **+1**. POST Location ve altı alan/nullable description korundu. |
| Redis TTL | İlk ölçüm **60 saniye**, configuration **60 saniye**. Key gerçekten expire oldu; yeniden doldurma/expiration sonrası toplam iki ek miss, hit farkı 0. |
| Başarısız Redis read | Liste **500**, hit/miss/invalidation **+0**; 500 HTTP count **+1**. |
| Başarısız Redis invalidation | DB POST **201**, invalidation **+0**; oluşturulan kayıt Redis geri geldikten sonra silindi. |
| Probe ve cardinality | Health/metrics duration serisi yok; histogram label'ları sadece method/template/status, sabit scope ve bucket sınırı. Ham ID/canary yok. |
| Runtime ve endpoint | CPU/memory/allocation/GC/thread-pool serileri mevcut; internal **200 Prometheus text**; dış `/metrics` **200 HTML, metrik değil**; API host binding yok. |

`Phase0B.Tasks.Smoke.ps1` Nginx URL'siyle **PASS**. Mevcut `Module8.Readiness.Smoke.ps1` **PASS**: normal `/health`, live, ready 200; Redis/PostgreSQL ayrı stopped iken live 200 / ready 503 / API running-unhealthy / liste 500; aynı API container'ında bağımlılık geri gelince ready 200 ve healthy. PostgreSQL deneyi önce test liste key'ini temizleyerek DB cache'in kesintiyi saklamasını önledi. Internal health/live/ready ve Development OpenAPI ayrıca **200** döndü. Configuration smoke **20/20 PASS**; negatif vakalarda güvenli key mesajı ve canary yokluğu doğrulandı, yalnız nonzero exit code yeterli sayılmadı. Test prosesine ait Windows error-mode yöntemi korundu.

Her metric scrape'i Task başlığı canary'si, gerçek PostgreSQL parolası ve tam PostgreSQL connection string'inin bulunmadığını değer göstermeden kontrol etti. Son test stdout/stderr'si paylaşılmadan önce `module10-task-` ve credential assignment deseni açısından otomatik kontrol edildi; bulunmadı. Bu kapsamlı secret detector veya bütün Git geçmişi taraması değildir.

Stack başlangıçta yoktu; yalnız bu görevde başlatılan dört container/network `docker compose --env-file .env down` ile kaldırıldı. Diagnostic `--rm` container'ları kalmadı. Test Task'ları ve yalnız test liste cache key'i temizlendi. Mevcut `tasks`, `lab_tasks` ve migration history satırlarının hash'leri değişmedi (identity sequence normal INSERT nedeniyle ilerleyebilir). External volume ve `.env`/user-secrets dosya hash'leri korundu. Başlangıç/bitiş **12 ilişkisiz container / 7 network / 19 volume** için ID/state/ad karşılaştırması aynı çıktı; bu deneyde default bridge ID değişmedi. Image'lar silinmedi; geçici kanıt dosyaları repository dışında tutulup temizlendi. `down -v`/prune kullanılmadı.

Yalnız backend Program/proje dosyası, yeni `Telemetry/TaskCacheMetrics.cs`, yeni metrics smoke ve iki dokümantasyon dosyası değişti. Compose, frontend, migration, health check implementasyonları ve secret kaynakları değişmedi.

### Ölçüm sınırları ve sonraki adım

Sayaçlar process restart'ında sıfırlanır; henüz event almayan cache instrument'ı scrape'te absent olabilir. API restart'ından önce dolu cache counter'larının, restart sonrasında series olarak henüz bulunmadığı gerçekten doğrulandı. Bunlar persistent DB sayaçları değildir. Scrape çıktısı prosesin cumulative snapshot'ıdır; henüz kalıcı zaman serisi deposu yok. Rate/error ratio/p95 için ileride scrape geçmişi gerekir. Bu smoke trafik deneyi benchmark veya production yük testi değildir; API süresi Nginx dahil uçtan uca kullanıcı gecikmesini ölçmez.

Bu backend kabulünün ardından planlanan küçük adım Prometheus servisi ve 15 saniyelik internal scrape idi; tamamlanması aşağıdaki bölümde belgelenir. Grafana bu backend adımında uygulanmadı.

## Prometheus — internal scrape kabulü

**PASS — 3 Ekim 2026.** Bu bölüm yukarıdaki backend adımından sonraki durumu anlatır: Compose artık beş servislidir. Backend instrumentation, Task JSON/HTTP contract, cache, Nginx, PostgreSQL ve Redis configuration değiştirilmedi. Grafana, alerting, tracing ve merkezi log sistemi henüz yok.

### Image, port ve scrape configuration

Resmî [indirme sayfasında](https://prometheus.io/download/) 3 Ekim 2026 tarihinde listelenen LTS bakım sürümü **3.13.4** (29 Eylül 2026) seçildi. Bu, o tarihteki en yeni feature sürümü olduğu iddiası değildir; LTS hattını kullanır. [Resmî Docker kurulum belgesi](https://prometheus.io/docs/prometheus/latest/installation/) `prom/prometheus` image'ını gösterir.

- Image: `prom/prometheus:v3.13.4`; `latest` kullanılmaz. Sürüm tag'i yine registry'de mutable olabilir.
- Çekilen digest: `sha256:87861b8cf91579109319ebc300f3f1060e6da9c05d6ae8ad15a20c879e84e32e`.
- Image içindeki `prometheus --version` ve `promtool --version`: **3.13.4**, platform `linux/amd64`.
- UI, stack çalışırken: **http://127.0.0.1:9090**. Frontend: http://127.0.0.1:18081. 9090 başlangıçta boştu; başka servis kullanıyorsa onu durdurma.
- API/PG/Redis host portu yayınlanmaz; scrape mevcut `app` ağı üzerinde yapılır.
- `monitoring/prometheus/prometheus.yml`, container'da `/etc/prometheus/prometheus.yml` yoluna **read-only** bind edilir.
- Job: `fullstack-ops-api`; target: `api:8080`; yol: `/metrics`; interval **15s**, timeout **10s**.
- Prometheus API'nin healthy olmasına `depends_on` ile bağlanmaz; API erişilemiyorken de çalışıp bu durumu ölçebilir.
- Prometheus healthcheck'i `/-/ready` kullanır. Image içinde gerçekten `/bin/wget` bulundu; beş servis healthy oldu.

Prometheus pull modeliyle API'nin cumulative metric snapshot'ını alır, timestamp ekleyerek kendi TSDB'sinde saklar. API Prometheus'a metric göndermez. API counter'ları process restart'ında reset olur; Prometheus'un eski örnekleri bundan ayrı saklanır.

### Veri saklama ve kaynak sınırları

Şartnamedeki `prometheus_data` named volume'u `/prometheus` yoluna bağlıdır. Varsayılan proje adıyla gerçek volume **`fullstack-ops-lab_prometheus_data`** olur. External `fullstack-ops-postgres-data` ile ilgisi yoktur.

Retention flag'leri **7d** ve **256MB**; gerçek `/api/v1/status/flags` çıktısı bunları **1w / 256MiB** olarak normalize etti. Dolayısıyla boyut eşiği 268.435.456 byte'tır. İki politika birlikte kullanılır; daha önce sınırına ulaşan politika etkili olur. Bu, dosya sistemi için kesin disk kotası değildir: WAL/head verisi ve compaction geçici alanı ek yer kullanabilir, retention cleanup anlık değildir. [Storage belgesi](https://prometheus.io/docs/prometheus/latest/storage/) bu sınırları açıklar. Yedi gün bekleme veya boyut baskısı deneyi yapılmadı; flag'ler ve veri kalıcılığı doğrulandı.

Prometheus container sınırları **512 MiB RAM / 1 CPU**. Inspect gerçek değerleri **536870912 byte / 1000000000 NanoCPUs** gösterdi. Bunlar yerel öğrenme sınırlarıdır; production kapasite ölçümü değildir. Resmî image kullanıcı kimliği **65534 (nobody)** döndü; bu adımda ek hardening uygulanmadı.

Normal `docker compose down` named volume'u bırakır; yeniden `up` eski metric geçmişini açar. **`down -v` monitoring verisini silebilir**; normal lab temizliğinde kullanma. Bu deneyde down/up sonrasında aynı geçmiş `up=1` örneği, aynı timestamp ile geri alındı (`time=1791022252` için query). Yalnız başlangıçta bulunmadığı ve proje label'ları doğrulandığı için, göreve ait test monitoring volume'u son cleanup'ta açık adıyla kaldırıldı. Bu bir normal kullanım önerisi değildir; sonraki `up` boş monitoring volume'u oluşturur. PostgreSQL volume'u korundu.

### Çalıştırma ve doğrulama komutları

Repository kökünden; Module 9'a göre hazırlanmış `.env`, external PostgreSQL volume'u ve uygulanmış migration gerekir. Mevcut secret'ları değiştirme; çözümlenmiş Compose configuration'ı paylaşma.

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/Module9.EnvPreflight.ps1
docker compose --env-file .env config -q
docker pull prom/prometheus:v3.13.4

$configPath = (Resolve-Path monitoring/prometheus/prometheus.yml).Path
docker run --rm --mount "type=bind,source=$configPath,target=/etc/prometheus/prometheus.yml,readonly" --entrypoint /bin/promtool prom/prometheus:v3.13.4 check config /etc/prometheus/prometheus.yml

# İlk clone'da build gerekir. Bu kabulde değişmeyen, önceki adımda doğrulanmış API/frontend image'ları kullanıldı.
docker compose --env-file .env build api frontend
docker compose --env-file .env up -d --wait --wait-timeout 180
docker compose --env-file .env ps

# İzole trafik, yeni API prosesi ve başlangıçta mevcut liste cache'i olmadan çalıştır.
powershell -NoProfile -ExecutionPolicy Bypass -File tests/Module10.Prometheus.Smoke.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File tests/Module10.Metrics.Smoke.ps1 -EndpointOnly
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/Module9.SecretLeakage.Check.ps1
git diff --check
```

Gerçek kabulde `up -d --no-build --wait --wait-timeout 180` kullanıldı; uygulama kaynakları değişmedi. Promtool **SUCCESS**, env preflight ve Compose config **PASS**. Script servisleri ilk kez başlatmaz; hazır bir stack üzerinde yalnız kontrollü API/Redis stop/start yapar. Başka kullanıcı trafiğiyle aynı anda çalıştırma. API counter'ları önceden kullanılmışsa testi yeni prosesle ve test cache'i bulunmadan hazırla; mevcut kullanıcı cache'ini körlemesine silme.

Yeni test target URL/interval, scrape zamanının ilerlemesi, query API, runtime serileri, HTTP/cache counter'ları, altı JSON alanı/nullable description, POST Location, kesinti/recovery ve dış `/metrics` davranışını doğrular. Başarısız assertion exit 1 verir. Scrape beklemesi 55 saniye, health beklemesi 90 saniye ile sınırlıdır. HTTP/Docker response body ve native stderr terminale aktarılmaz. Task kayıtları ve yalnız testin sahip olduğu cache key'i `finally` ile temizlenir; kesilen servisler geri başlatılır.

Eski `Module8.Readiness.Smoke.ps1` tam **dört** servis bekler; yeni beş servisli topolojide körlemesine çalıştırılmadı. Burada Redis kesintisi, live/ready, running/unhealthy ve recovery aynı kabul kriterleriyle yeni script'te doğrulandı. PostgreSQL kesinti deneyi bu küçük adımda tekrarlanmadı; önceki adımın sonucu yukarıdadır.

### Gerçek scrape ve trafik sonuçları

Son tam smoke koşusu **10:07:47–10:10:03 UTC / 13:07:47–13:10:03 Türkiye saati** aralığındadır. Test öncesi hedef için iki ardışık başarılı scrape beklenip `up=1` doğrulandı; son bir dakikadaki `up` sample sayısı **4** idi. Sample sayısı tek başına bütün sample'ların başarılı olduğunu kanıtlamaz; target health ve `up` ayrıca kontrol edildi.

| Kontrol | Gerçek sonuç |
| --- | --- |
| Target | `http://api:8080/metrics`, interval **15s**, health **up**; son recovery scrape **2026-10-03T10:10:02.403068929Z**. |
| Kontrollü CRUD | GET list/ID **200**, POST **201** ve `/api/tasks/{id}` Location, PUT **200**, DELETE **204**, boş başlık **400**, silinmiş ID **404**. Altı JSON alanı ve nullable description korundu. |
| Trafikten sonraki scrape | HTTP histogram `_count` **+8**; cache miss/hit/invalidation **1 / 1 / 3**. Sonraki miss/hit çifti ayrı scrape'a yansıdı. |
| Runtime query | CPU, working set ve GC allocation serileri query API'den okundu; CPU mode label'ı nedeniyle iki, memory/allocation birer sample vardı. |
| 1m request rate | **0,0724471605048013 istek/s**. |
| 1m GET-list p95 | **0,00475 s**, histogram bucket'larından tahmin. Kesin tekil request ölçümü veya benchmark değil. |
| 1m cache hit oranı | **0,5 (%50)**. |
| Kesinti öncesi 5xx | Seri bulunmadığından sorgu **boş**; ölçülmüş sıfır gibi raporlanmadı. |
| Redis stopped | API **running/unhealthy**, live **200**, ready **503**, iki list GET **500**; iki sonraki metrics scrape başarılı, **up=1**. |
| Kesinti penceresi 5xx oranı | **1 (%100)**; o kısa 1m penceredeki kontrollü hata trafiğinin oranı, production hata oranı değil. |
| Redis recovery | Aynı API container'ında ready **200**, Docker health **healthy**. |
| API stopped / start | Target **DOWN/up=0**, aynı API container'ı tekrar healthy olunca **UP/up=1**. |
| Nginx dış `/metrics` | **200 HTML SPA fallback**, API metrikleri değil. Nginx'e yeni route eklenmedi. |
| TSDB down/up | Eski timestamp'teki `up=1` sample'ı aynı timestamp/değerle geri döndü; volume kalıcılığı kanıtlandı. |

`up`, Prometheus'un target HTTP scrape'ını yapabilmesini anlatır. `ready`, API'nin PostgreSQL/Redis ile iş yapmaya hazır olmasını anlatır. Redis kesintisinde `/metrics` bağımlılıklara sorgu göndermediği için scrape devam ederken kullanıcı isteği 500 verdi. Prometheus `/-/ready` ise Prometheus servisinin kendi hazır oluşudur; API readiness yerine geçmez. Docker health de periyodik probe sonucu olduğundan anlık HTTP readiness ile geçiş sırasında aynı anda değişmeyebilir.

İlk tam koşuda 5xx ratio sorgusu boş kaldı ve test **FAIL** verdi: uzun dependency health beklemesi sırasında ilerlemiş eski scrape zamanı yanlışlıkla yeni scrape sayılmıştı. Yalnız test, her trafik işleminden sonra **güncel lastScrape'tan daha yeni** sample bekleyecek şekilde düzeltildi. Son koşu geçti. Query helper boş, NaN veya sonsuz sonuçları geçerli sayısal ölçüm kabul etmez. Servis configuration veya backend davranışı bu nedenle değiştirilmedi.

### Gerçek isimlerle PromQL

[Query API](https://prometheus.io/docs/prometheus/latest/querying/api/) için `/api/v1/query?query=...` veya UI'daki expression alanı kullanılabilir. Job label Prometheus tarafından eklenir. HTTP labels gerçek exporter adlarıdır: `http_route`, `http_request_method`, `http_response_status_code`; histogram bucket label'ı `le`.

```promql
# Instant vector: en son target durumu (runtime readiness değildir).
up{job="fullstack-ops-api"}

# Range vector'daki counter örneklerinden saniye başına istek; restart reset'lerini rate ele alır.
sum(rate(http_server_request_duration_seconds_count{job="fullstack-ops-api"}[5m]))

# 5xx / tüm istekler. 5xx serisi yoksa boş; payda 0 ise NaN olabilir.
sum(rate(http_server_request_duration_seconds_count{job="fullstack-ops-api",http_response_status_code=~"5.."}[5m]))
/
sum(rate(http_server_request_duration_seconds_count{job="fullstack-ops-api"}[5m]))

# GET liste route template'i gerçekten /api/tasks/ (son slash dahil).
histogram_quantile(0.95,
  sum by (le) (rate(http_server_request_duration_seconds_bucket{job="fullstack-ops-api",http_route="/api/tasks/",http_request_method="GET"}[5m]))
)

sum(rate(fullstackops_cache_hits_total{job="fullstack-ops-api"}[5m]))
/
(
  sum(rate(fullstackops_cache_hits_total{job="fullstack-ops-api"}[5m]))
  + sum(rate(fullstackops_cache_misses_total{job="fullstack-ops-api"}[5m]))
)

# Gauge: son memory örneği; counter değil, rate uygulama.
dotnet_process_memory_working_set_bytes{job="fullstack-ops-api"}

# CPU counter: kullanıcı/sistem mode serilerini sum ile birleştir.
sum(rate(dotnet_process_cpu_time_seconds_total{job="fullstack-ops-api"}[5m]))
```

`sum` seçilen series'leri toplar; `sum by(le)` histogram bucket sınırlarını korur. `rate` cumulative counter için kullanılır; gauge'a uygulanmaz. Üstteki örnekler 5m öğrenme penceresidir; kabul tablosundaki ölçümler aynı sorguların **1m** sürümlerinden alınmıştır. En az iki sample gerekir; yeni counter yalnız ilk event'ten sonra görünür. Trafiksiz p95 NaN, henüz doğmamış seri boş olabilir. Bunları sağlıklı trafik, sıfır hata veya sıfır gecikme kanıtı sayma. Histogram quantile bir bucket tahminidir; Nginx dahil uçtan uca latency değildir. Bu adım için kaydedilmiş yeterli kontrollü sample vardır; uzun dönem trend/yük testi yoktur.

### Güvenlik, cleanup ve kalan adım

Internal metric response, Prometheus series label metadata ve son smoke stdout/stderr'sinde gerçek PostgreSQL parola/connection string ve Task canary bulunmadığı değerleri göstermeden kontrol edildi. Mevcut metrics `-EndpointOnly` kontrolü de **PASS**. Secret leakage regression repository'nin tracked ve yeni ignored olmayan dosyalarında geçti; Git geçmişi taranmadı.

Başlangıçta stack yoktu. Test Task'ları ve test liste key'i temizlendi; mevcut `tasks`, Module 3B `lab_tasks` ve `__EFMigrationsHistory` satır hash'leri aynı kaldı. INSERT nedeniyle identity sequence ilerleyebilir. `.env`/user-secrets hash'leri korundu. Beş container ve `app` network `down` ile kaldırıldı. Normal down/up persistence deneyinden sonra yalnız yeni test monitoring volume'u, başlangıçta bulunmadığı ve Compose ownership label'ları doğrulanarak `docker volume rm fullstack-ops-lab_prometheus_data` ile kaldırıldı. **External PostgreSQL volume'u ve ilişkisiz kaynaklar korundu; `down -v`/prune kullanılmadı.** Image'lar localde bırakıldı.

Kaydedilmiş başlangıç/bitiş envanteri **12 ilişkisiz container / 7 network / 19 volume** için aynı çıktı. İlk Engine erişim kontrolünde görülen built-in bridge ID `f015…`, stack başlamadan kaydedilen snapshot ve cleanup'ta `7f52…` idi. Neden doğrulanmadı; Docker configuration değiştirilmedi. Snapshot ile bitiş arasında network ID farkı yok. Geçici kanıt dosyaları repository dışında tutulup temizlendi.

Bu Prometheus kabulünden sonraki Grafana datasource adımı aşağıda belgelenir. Prometheus adımında dashboard/alerting/tracing uygulanmadı.

## Grafana — YAML datasource provisioning

**PASS — 3 Ekim 2026.** Yalnız Grafana servisi, datasource provisioning ve bunların güvenli local onboarding/kabul kontrolleri eklendi. Dashboard/provider, alert rule, tracing veya merkezi log servisi eklenmedi. Backend/frontend kaynakları, instrumentation, API/cache contract ve PostgreSQL schema değişmedi.

### Image ve Compose kararı

[Resmî OSS Docker indirme sayfasında](https://grafana.com/grafana/download/13.2.3?edition=oss&platform=docker) doğrulanan **29 Eylül 2026 tarihli 13.2.3** bakım sürümü seçildi: `grafana/grafana:13.2.3` (Alpine). İlk arama cache'i 13.2.2 gösterdi; canlı resmî sayfa kontrolüyle 13.2.3 seçildi. Yalnız bu görevde çekilmiş kullanılmayan 13.2.2 tag'i sonunda kaldırıldı; önceden bulunan başka Grafana image/volume'larına dokunulmadı.

- Gerçek digest: `sha256:b28bae15e219c998fb0e0424ed724930cc61b1f61fb404d47c862f9a23f9e572`.
- Image içindeki `grafana --version`: **13.2.3**; `wget`: **/usr/bin/wget**; kullanıcı UID **472**.
- UI, stack çalışırken: **http://127.0.0.1:3000**. 3000 başlangıçta boştu. Binding yalnız **127.0.0.1:3000:3000**; API/PG/Redis host portları kapalı kalır.
- Grafana mevcut `app` ağına katılır. Prometheus adresi **http://prometheus:9090**; Grafana container'ındaki `localhost`, Grafana'nın kendisidir.
- Healthcheck image içinde doğrulanmış `wget` ile **/api/health** HTTP başarısını kontrol eder. Kabulde HTTP **200**, `database=ok` ve altı Docker health durumu **healthy** oldu.
- Kaynak sınırı **512 MiB / 1 CPU**; inspect **536870912 byte / 1000000000 NanoCPUs** gösterdi. Bu bir production kapasite hesabı değildir.

### Datasource YAML ve kalıcılık

`monitoring/grafana/provisioning/datasources/prometheus.yml`, `/etc/grafana/provisioning/datasources` klasörüne **read-only** bağlanır. [Provisioning belgesine](https://grafana.com/docs/grafana/latest/administration/provisioning/) uygun alanlar:

| Alan | Değer / amaç |
| --- | --- |
| `apiVersion` | 1; provisioning dosyası formatı. |
| `name` / `type` | Prometheus / prometheus. |
| `uid` | **fullstack-ops-prometheus**; ileride dashboard'lar aynı sabit UID'yi kullanabilir. |
| `url` / `access` | `http://prometheus:9090` / proxy; sorguyu Grafana server'ı Compose ağı üzerinden yapar. |
| `isDefault` / `editable` | true / false; varsayılan datasource, UI'da read-only. |
| `version` | 1; sonraki provisioning güncellemelerinde bilinçli artırılabilir. |
| `httpMethod` / `timeInterval` | POST / 15s; mevcut Prometheus scrape interval'iyle uyumlu. Bu ayar Prometheus scrape interval'ini değiştirmez. |

UI üzerinden datasource eklenmedi. İlk açılış, restart ve down/up sonrasında **tek** datasource, aynı UID/URL/default/read-only özellikleriyle bulundu. Authenticated datasource health **OK** döndü.

Compose-managed **grafana_data** volume'u `/var/lib/grafana` yolundadır; varsayılan proje adıyla **fullstack-ops-lab_grafana_data** olur. Grafana'nın SQLite çalışma verisi, hesap ve datasource metadata'sı burada kalır. Prometheus metric geçmişi ayrı **prometheus_data** volume'undadır; Grafana bunların yerine zaman serisi deposu değildir. Normal `down` volume'ları korur; `down -v` monitoring verisini silebilir. Volume silmek normal kurulum/credential düzeltme adımı değildir.

### Admin credential ve güvenli local kurulum

Zorunlu anahtarlar **GF_SECURITY_ADMIN_USER** ve **GF_SECURITY_ADMIN_PASSWORD**. `.env.example` yalnız `<set-outside-git>` placeholder'ları içerir. Anonymous access kapalıdır; anonim `/api/datasources` **401** döndü. User-secrets Compose tarafından otomatik okunmaz.

İlk implementation kabulünde mevcut `.env` dosyası değiştirilmedi. O sırada iki yeni anahtar bulunmadığı için yalnız mevcut `.env` ile preflight bu iki **anahtar adını** gösterip exit 1 verdi. Runtime kabulü, mevcut `.env` üzerine yalnız iki Grafana anahtarı sağlayan ayrı, ignored, geçici env dosyasıyla yapıldı. Bu dosya sonunda silindi; test credential'ları raporlanmadı veya local kullanım için bırakılmadı.

Commit öncesi kullanıcı gerçek `.env` dosyasına iki Grafana admin anahtarını kendisi ekledi. Son incelemede **normal `.env` preflight, sessiz Compose config, external volume kontrolü, secret leakage kontrolü ve `git diff --check` PASS** aldı; `.env` ignored ve untracked kaldı. Kullanıcı yerel Grafana girişinin ve datasource testinin **Successfully queried the Prometheus API** sonucunu verdiğini, ardından stack'i `docker compose down` ile kapattığını bildirdi. Bu kullanıcı kabulü önceki otomatik browser/restart/down-up sonuçlarından ayrı kaydedilir; son incelemede runtime deneyleri yeniden çalıştırılmadı. Credential değerleri okunup raporlanmadı veya dosya üzerine yazılmadı.

Sonraki kullanımda iki seçeneğin var:

1. Kendi Git-ignored `.env` dosyana iki alanı güvenli biçimde ekle; mevcut PostgreSQL değerlerini ve dosyanın tamamını değiştirme/ezme.
2. Mevcut `.env` dosyasını koruyup yalnız bu iki alan için **.env.grafana.local** gibi ayrı bir ignored dosya kullan. Dosya mevcutsa üzerine yazma. Placeholder şablonu:

```dotenv
GF_SECURITY_ADMIN_USER=<set-outside-git>
GF_SECURITY_ADMIN_PASSWORD=<set-outside-git>
```

Dosyayı editörde yerel değerlerle doldur; değeri terminal çıktısına, komut argümanına veya Git'e yazma. Compose quoting/interpolation kuralları ve PostgreSQL volume/migration önkoşulları için [Module 9 rehberini](../09-environment-configuration/README.md) izle. İlk clone/eksik `.env` durumunda örnekten hazırlama mevcut dosyayı ezmeden yapılmalıdır.

Grafana admin environment değerleri **boş Grafana veritabanındaki ilk hesabı oluşturur**. Initialized `grafana_data` volume'unda env parolasını değiştirmek mevcut hesabın parolasını otomatik rotate etmez. Bu görev rotation yapmadı; mevcut volume'u silerek parola düzeltmeyi önermiyoruz. Preflight bir authentication veya database readiness testi değildir.

Preflight artık iki Grafana alanını da eksik/boş/placeholder kontrolüne alır. Opsiyonel `-GrafanaEnvFile` primary `.env` dosyasından sonra okunur; Compose'a aynı sıra ile iki `--env-file` verilir, son dosya çakışan key'lerde önceliklidir. İkinci dosyayı yalnız Grafana alanlarına ayır. Her iki dosya repository içinde, ignored ve untracked olmalıdır. Script shell environment'ın eksik dosya değerlerini gizlemesini engeller; Compose'un kendi parser'ını kullanır, dosyayı kod olarak çalıştırmaz ve çözümlenmiş JSON'u yazdırmaz.

İki dosyalı akış (repository kökünden, dosyalar senin tarafından hazırlanmışken):

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/Module9.EnvPreflight.ps1 -GrafanaEnvFile .env.grafana.local
docker compose --env-file .env --env-file .env.grafana.local config -q
docker compose --env-file .env --env-file .env.grafana.local build api frontend
docker compose --env-file .env --env-file .env.grafana.local up -d --wait --wait-timeout 240
docker compose --env-file .env --env-file .env.grafana.local ps
```

Tarayıcıda **http://127.0.0.1:3000/login** aç; hazırladığın kullanıcı/parolayla giriş yap. **Connections → Data sources → Prometheus** altında datasource zaten vardır; manuel Add data source gerekmez. Prometheus UI'sı http://127.0.0.1:9090, uygulama http://127.0.0.1:18081 adresindedir. Tek `.env` seçeneğinde `-GrafanaEnvFile` ve ikinci `--env-file` argümanını kaldır.

### Gerçek kabul testleri ve sonuçlar

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tests/Module9.EnvPreflight.Smoke.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File tests/Module10.Grafana.Smoke.ps1 -GrafanaEnvFile .env.grafana.local
python tests/Module10.Grafana.Browser.Smoke.py --seed-test-metrics
docker compose --env-file .env --env-file .env.grafana.local restart grafana
docker compose --env-file .env --env-file .env.grafana.local up -d --wait --wait-timeout 240
```

Browser testi yalnız test araçları olarak **Python + Playwright + Microsoft Edge** gerektirir; uygulamayı Docker'da çalıştırmak için bu host araçları gerekli değildir. Kabulde **Playwright 1.63.0**, Edge **154.0.4258.48** headless gerçek tarayıcı kullanıldı. Playwright görev geçici klasörüne `pip --target` ile kuruldu ve temizlendi; frontend package/lock dosyaları veya kalıcı Python bağımlılık dosyası değişmedi. Komutları yeniden çalıştırmadan önce Playwright'ı proje bağımlılığına eklemeden ayrı test ortamında hazırla.

`--seed-test-metrics` izole trafik ve başlangıçta liste cache key'inin yokluğunu bekler. İki GET ile miss/hit üretir, benzersiz bir Task oluşturup silerek invalidation üretir; sonraki scrape için bekler. Yalnız kendi Task'ını ve sahip olduğu cache key'ini temizler. Mevcut kullanıcı cache'i varsa testi durdurur. Script login için container environment'ını yalnız bellekte okur; credentials CLI argümanına/stdout'a yazılmaz. Playwright context/browser sonunda kapatılır; screenshot/trace/profile repository'ye kaydedilmez.

| Kabul | Gerçek sonuç |
| --- | --- |
| TDD | Eski preflight eksik Grafana parolasını kabul ettiği için yeni fixture FAIL; düzeltme sonrası PASS. Yeni runtime test servisin yokluğu için FAIL, implementation sonrası PASS. |
| Preflight fixtures | **19/19 PASS**; iki Grafana key'inin missing/empty/placeholder halleri, shell shadow, ayrı ignored dosya, eski PostgreSQL/TTL/override/volume kontrolleri; canary gizli ve gerçek `.env` hash'i aynı. |
| Build/config | Sessiz Compose config ve combined-file preflight PASS; API Docker publish gerçekten çalışıp geçti, frontend build layer'ları cache'ten geçti. App kaynakları değişmedi. |
| Health/network | Altı servis healthy; Grafana `/api/health` **200/database=ok**, API/PG/Redis host binding yok, Grafana yalnız localhost 3000. Read-only datasource mount ve named data mount inspect ile doğrulandı. |
| Gerçek browser | Login formundan authenticated admin girişi; datasource UI'da hazır. Credentials girilen ekranın görüntüsü/logu paylaşılmadı. |
| Native Grafana plugin sorgusu | Browser session'ıyla **POST /api/ds/query**: HTTP histogram count **3 numeric column**, working set **1**, cache hit/miss/invalidation **birer** numeric column; finite değerler gerçekten döndü. |
| Datasource proxy sorgusu | `/api/datasources/proxy/uid/fullstack-ops-prometheus/api/v1/query` üzerinden `up` **1 series**, HTTP count **3**, memory **1**, cache sayaçları birer series. Boş sonuç başarı sayılmadı. |
| Restart | Grafana restart sonrası aynı hesapla browser login ve native/plugin/proxy sorguları PASS; tek datasource ve aynı UID korundu. |
| Down/up | Container kaldırılıp yenisi oluşturuldu; aynı named volume kaldı. Aynı hesapla browser login, tek datasource, plugin/proxy sorguları ve altı healthy servis PASS. |
| Dashboard | `/api/search?type=dash-db` boş; dashboard provider/JSON eklenmedi. |

Son down/up kabul çıktıları **3 Ekim 2026, 11:04:31–11:04:32 UTC / 14:04:31–14:04:32 Türkiye saati** ile kaydedildi. Bunlar stdout dosyalarının yazılma zamanlarıdır; test süresi veya benchmark değildir.

Browser ilk koşuda sayfa geçişinin iptal ettiği `sort-amount-up.svg` isteği yüzünden FAIL verdi. Teşhis sonrası yalnız **bu tam asset yolu + net::ERR_ABORTED** beklenen navigation cancellation olarak ayrılır. Yeni hesapta Grafana'nın `advisor-redirect-notice` user-storage kaydı olmadığı için gelen **404** de yalnız bu endpoint ve 404 console mesajı için dar istisnadır. Son down/up browser koşusunda **1 SVG cancellation / 1 preference 404**, **0 beklenmeyen page/console/network hatası** vardı. Bunlar datasource/metric isteği hataları değildir; bütün 404 veya bütün abort'lar görmezden gelinmez.

PowerShell REST helper'ı ilk koşuda boş JSON array'i tek pipeline nesnesi olarak saydı ve dashboard assertion FAIL verdi. Response array'inin normal enumerate edilmesi düzeltildi; gerçekten boş dashboard listesi ile PASS aldı. Uygulama/datasource davranışı değiştirilmedi.

### Credential log kontrolü ve cleanup

İlk startup/browser deneyinde resmî image parolayı maskeledi fakat kullanıcı adını INFO loglarına yazdı; değer gösterilmeden tespit edildi. `GF_LOG_FILTERS`, yalnız gözlenen **settings / sqlstore / context / plugin.prometheus** logger'larını **warn** seviyesine alır. Böylece final startup/login/query akışlarında admin kullanıcı adı/parola logda görünmedi. WARN/ERROR korunur; bu dört logger'ın INFO teşhis bilgisi azalır. Bu bir bütün log/exception yollarının sızıntısız olduğuna dair garanti değildir; yeni hata yolları ayrıca kontrol edilmelidir.

Secret scanner kuralları gevşetilmedi. Regex/çalışma anında okunan credential referanslarının yanlış pozitifleri, testte açık key/value parsing ve regex key escaping ile çözüldü; gerçek literal değerler allowlist'e alınmadı. Final repository taraması, güncel altı servis logları ve kaydedilmiş browser/API test çıktıları gerçek PostgreSQL parola/connection string ve geçici Grafana user/parola değerlerine karşı **değer göstermeden** kontrol edildi; bulunmadı. `git diff --check` geçti. Git geçmişi taranmadı.

Başlangıçta stack yoktu. Test Task'ları ve test liste cache'i temizlendi. Mevcut `tasks`, Module 3B `lab_tasks` ve migration history satır hash'leri aynı kaldı; identity sequence test INSERT'leri nedeniyle ilerleyebilir. `.env`/user-secrets hash'leri korundu. Normal down/up persistence kanıtından sonra altı test container'ı/network `down` ile kaldırıldı. Yalnız bu görev öncesinde bulunmayan ve Compose ownership label'ları doğrulanan iki **test** volume'u (`fullstack-ops-lab_grafana_data`, `fullstack-ops-lab_prometheus_data`) açık adlarıyla kaldırıldı. Mevcut named volume'lara dokunulmadı; external PostgreSQL volume'u korundu. Normal kullanımda bu monitoring volume'larını kaldırma; `down -v`/prune kullanılmadı.

Orijinal **12 container ID/state / 19 volume adı** aynı kaldı; **7 network adı** korundu. Built-in bridge ID başlangıç snapshot'ındaki `9b3d…` yerine sonunda `bf562…` idi; neden doğrulanmadı, Docker configuration değiştirilmedi. Diğer network ID'leri aynıydı. Geçici credential/env, Playwright araçları, browser screenshot probe ve kanıt dosyaları temizlendi. Seçilen Grafana 13.2.3 image'ı localde bırakıldı.

Bu datasource kabulünden sonraki dashboard adımı aşağıda belgelenir. Datasource adımında dashboard uygulanmadı.

## Overview dashboard provisioning

### Dosyalar, kurulum ve kalıcılık

`monitoring/grafana/provisioning/dashboards/overview.yml`, file provider'ı tanımlar. `monitoring/grafana/dashboards/overview.json`, **FullStack Ops Lab Overview** dashboard'unun repository'deki kaynağıdır. Sabit dashboard UID **fullstack-ops-overview**, folder UID **fullstack-ops-lab**, datasource UID **fullstack-ops-prometheus**. Manuel import veya UI üzerinden datasource ekleme gerekmez.

Compose provider klasörünü `/etc/grafana/provisioning/dashboards`, dashboard klasörünü `/var/lib/grafana/dashboards` yoluna **read-only** bağlar. Mevcut datasource mount'u da read-only kalır; `/var/lib/grafana` named volume'u hesap ve dashboard metadata'sını saklar. Mount'lar inspect ile `RW=false` olarak doğrulandı. Backend instrumentation, secrets, servis adları ve portlar değişmedi.

Provider 30 saniyede dosyaları yeniden tarar; Docker bind mount'larında filesystem event davranışına güvenmez. `allowUiUpdates=false` ve JSON `editable=false`: kalıcı düzenlemeleri repository JSON'unda yap. `disableDeletion=true`: dosyanın yanlışlıkla kaldırılması mevcut dashboard'u otomatik silmez; eski dashboard silme davranışı bu adımda eklenmedi. [Grafana provisioning belgesi](https://grafana.com/docs/grafana/latest/administration/provisioning/#dashboards).

Repository kökünde, mevcut ignored `.env` ve hazırlanmış external PostgreSQL volume/migration ile:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/Module9.EnvPreflight.ps1
docker compose --env-file .env config -q
docker compose --env-file .env up -d --wait --wait-timeout 240
```

Grafana'ya kendi local admin credential'larınla giriş yap. **Dashboards → FullStack Ops Lab → FullStack Ops Lab Overview** yolunu aç veya stack çalışırken **http://127.0.0.1:3000/d/fullstack-ops-overview/fullstack-ops-lab-overview** adresini kullan. Credential'ları komut argümanına, çıktıya veya Git'e yazma.

### Panel, PromQL, birim ve anlam

Aşağıdaki kısaltmalar yalnız tabloyu okunur tutar; dashboard JSON'unda sorgular **tam metin** olarak bulunur. Hepsi `job="fullstack-ops-api"` filtresini taşır:

- `R = sum(rate(http_server_request_duration_seconds_count{job="fullstack-ops-api",http_route=~"/api/tasks.*"}[2m]))`
- `E = sum(rate(http_server_request_duration_seconds_count{job="fullstack-ops-api",http_route=~"/api/tasks.*",http_response_status_code=~"5.."}[2m]))`
- `H = sum(rate(fullstackops_cache_hits_total{job="fullstack-ops-api"}[2m]))`
- `M = sum(rate(fullstackops_cache_misses_total{job="fullstack-ops-api"}[2m]))`

| Panel | PromQL | Grafana birimi | Kısa açıklama |
| --- | --- | --- | --- |
| API scrape durumu | `up{job="fullstack-ops-api"}` | 0/1 mapping | Scrape başarılı/başarısız; readiness ve bütün sistem sağlığı değildir. |
| HTTP request rate | `R` | `reqps` — istek/s | Task endpoint'lerinin bütün HTTP method/status kodları. |
| HTTP 5xx oranı | `100 * (E or (0 * R)) / R` | `percent` — % | Yalnız 5xx; 400/404 hata payına girmez. |
| HTTP istek süresi p95 | `histogram_quantile(0.95, sum by (le) (rate(http_server_request_duration_seconds_bucket{job="fullstack-ops-api",http_route=~"/api/tasks.*"}[2m])))` | `s` — saniye | Bucket dağılımından yaklaşık p95; Nginx/tarayıcı toplam gecikmesi değildir. |
| Process CPU kullanımı | `100 * sum(rate(dotnet_process_cpu_time_seconds_total{job="fullstack-ops-api"}[2m]))` | `percent` — tek çekirdek karşılığı % | User/system CPU zamanını toplar. 100 bir çekirdektir; çok çekirdekte 100 üstü mümkündür. Host toplam CPU yüzdesi değildir. |
| Process working set belleği | `sum(dotnet_process_memory_working_set_bytes{job="fullstack-ops-api"})` | `bytes` | Anlık process gauge; heap ve Docker memory hesabıyla aynı değildir. |
| Cache hit ve miss rate | `H` ve `M` | `ops` — olay/s | İki ayrı çizgi; başarılı cache okuma/deserialize olayları. |
| Cache hit oranı | `100 * H / (H + M)` | `percent` — % | Yalnız cache okuma olaylarının oranı. |
| Cache invalidation rate | `sum(rate(fullstackops_cache_invalidations_total{job="fullstack-ops-api"}[2m]))` | `ops` — işlem/s | Başarılı DB mutation sonrası tamamlanmış cache remove; fiziksel silinen key adedi değildir. |

Gerçek scrape `dotnet_process_cpu_time_seconds_total` için **Counter** ve `cpu_mode=user/system`, working set için **Gauge** gösterdi. HTTP histogram label'ları `http_request_method`, `http_response_status_code`, `http_route`, bucket sınırı `le`. Gerçek route template'leri `/api/tasks/` ve `/api/tasks/{id:int}`. Cache counter adları ve histogram bucket'ları canlı scrape ile tekrar doğrulandı.

### Doğru yorumlama ve trafiksiz görünüm

- Refresh **15s**, bütün rate pencereleri **2m**: pencere sekiz nominal scrape aralığıdır. Rate hesaplamak için en az iki örnek gerekir; yeni counter'ın ilk kez görünmesi artışı tek başına kanıtlamaz. Smoke yeni counter'lara trafik vermeden önce scrape baseline'ı bekler.
- Counter'larda önce her series için `rate()`, sonra `sum()` uygulanır; process restart resetleri rate tarafından ele alınır. Gauge'a rate uygulanmaz. [Prometheus rate ve histogram_quantile](https://prometheus.io/docs/prometheus/latest/querying/functions/).
- `E or (0 * R)` yalnız 5xx series'i hiç oluşmamışken, gerçek request series'i üzerinden hata payını sıfır verir. `R=0` ise oran **0/0 NaN** kalır. Bu bir trafiksiz oranı sıfırla doldurma işlemi değildir.
- p95 ve cache oranı trafik/olay yokken boş veya NaN olabilir. JSON'da `or vector(0)`, denominator clamp veya null-to-zero transformation yok; çizgiler null boşluklarını birleştirmez. Gerçek request/event rate sıfır olabilir; oran ve percentile için sıfır bilgi icat edilmez.
- Varsayılan görünüm son **15 dakika** olduğundan trafiksizken önceki trafik grafikte hâlâ görülebilir; son noktadaki oran/p95 boşluğu normaldir. Yeni process/counter series'i ilk örneklerinde `Veri yok` gösterebilir.
- `/health`, `/health/live`, `/health/ready`, `/metrics` mapping'leri `DisableHttpMetrics()` kullandığından request duration/count histogramına girmez. Canlı histogramda bu route serileri yoktu. CPU, working set, Kestrel ve aktif request ölçümleri probe maliyetini yine içerebilir. Task filtreleri OpenAPI gibi diğer endpoint'leri de dashboard HTTP panellerinden ayırır.
- Bilinen .NET thread-pool count/queue export tip sınırlaması bulunan seriler bu dashboard'da kullanılmaz; onlara rate uygulanmadı.
- Kısa lab trafiği p95 doğruluğu, throughput veya production kapasitesi için benchmark değildir. Scrape/smoothing gecikmesi vardır; oran geçmiş pencerenin oranıdır, son tek isteğin sonucu değildir.

### Kabul script'i

```powershell
python tests/Module10.Dashboard.Smoke.py --help
python -u tests/Module10.Dashboard.Smoke.py
python -u tests/Module10.Dashboard.Smoke.py --provisioning-only
python -u tests/Module10.Dashboard.Smoke.py --browser-only
powershell -NoProfile -ExecutionPolicy Bypass -File tests/Module10.Grafana.Smoke.ps1
```

Tam test Python + ayrı test ortamında Playwright + kurulu Microsoft Edge gerektirir. Proje npm/lock bağımlılıklarına ekleme. Servisleri script başlatmaz; izole ve healthy stack gerekir. Provisioning-only mevcut Grafana API'sinde dashboard'un gerçekten provision edildiğini kontrol eder. Browser-only render ve datasource sorgularını kontrol eder; trafik/5xx kabulünün yerine geçmez.

Tam test yalnız kendi benzersiz Task'ını oluşturur/günceller/siler; mevcut cache'i zorla silmek yerine expiration'ı bekler. Kendi trafik aşamasındaki cache key'ini finally'de temizler. PostgreSQL'i kontrollü durdurur; ID GET'i doğrudan DB okuduğundan liste cache'i 5xx'i gizleyemez. Bağımlılığı finally'de geri getirir. 150 saniye API user trafiği üretmeden bekleyerek trafiksiz sorguları ve tarayıcı görünümünü kontrol eder. Diğer geliştirici trafiği eşzamanlı olmamalıdır. Dashboard kabulü eklendiği için datasource smoke'un eski **zero dashboards** assertion'ı kaldırıldı; datasource/health/query/log kontrolleri korundu.

### Gerçek kabul sonuçları — 3 Ekim 2026

**PASS.** Bu sonuç yalnız dashboard küçük adımı içindir; Module 10 final kabulü yapılmadı. Başlangıç Git durumu temizdi, stack kapalıydı. Docker Engine **29.6.1**, Compose **v5.3.0**, geçici test ortamında Playwright **1.63.0** ve kurulu Edge kullanıldı. JSON/bind-mount configuration değişikliği uygulama image build'i gerektirmedi; backend/frontend kaynakları ve image build tanımları değişmedi.

| Kabul | Gerçek sonuç |
| --- | --- |
| TDD | Eski stack'te yeni test **Overview dashboard is not automatically provisioned** nedeniyle exit 1; provider/JSON sonrası aynı test PASS. |
| Static/config | Normal env preflight ve sessiz Compose config PASS; Python syntax, JSON parse ve UTF-8 metin kontrolü PASS. Üç provisioning/dashboard bind mount'u read-only. |
| Startup | Altı servis healthy. Otomatik dashboard API'sinde `meta.provisioned=true`, sabit UID, dokuz panel ve mevcut datasource bağlantısı. |
| Browser/data | Gerçek Edge login; dokuz panel render edildi. Bütün panel expression'ları `/api/ds/query` ile Grafana Prometheus plugin'i üzerinden hatasız çalıştı; trafik sırasında her panelde gerçek finite numeric değer doğrulandı. Beklenmeyen page/console/datasource response hatası yok. |
| Trafik | POST 201/doğru Location, PUT 200, DELETE 204, listeler 200. Boş başlık 400 ve olmayan ID 404; request/p95/CPU/memory/cache rate serileri pozitif, 5xx oranı **0**. |
| Kontrollü 5xx | PostgreSQL stop sırasında doğrudan DB okuyan ID GET'i **üç kez 500**; error paneli pozitif. API aynı container'da running/unhealthy, live **200**, ready **503**, Prometheus **up=1**. PostgreSQL start sonrası aynı API healthy ve DB GET **404**. |
| Trafiksiz | 150 saniye Task trafiği yok; health/scrape devam etti. Request/hit/miss/invalidation rate **0**, 5xx/cache oranı ve p95 **NaN**; JSON sonuç kaydında bunlar `null` ile ifade edildi. Tarayıcıda sorgu hatası yok; önceki 15 dakika trafiği geçmiş çizgilerde kalabilir. |
| Restart | Grafana restart sonrası otomatik dashboard ve tüm paneller gerçek browser/plugin ile tekrar PASS. |
| Down/up | Yeni Grafana container ID'si, aynı mevcut named volume'lar; dashboard aynı UID ile otomatik yüklendi, browser/plugin tekrar PASS ve altı servis healthy. |
| Datasource regression | Mevcut datasource smoke UID/default/read-only, health, HTTP/runtime/cache query ve log kontrolleriyle PASS; dashboard adımına ait test bunun yerine geçmez. |

Son script sürümünün tam başarılı koşusundan gerçek snapshot'lar (sonuç dosyasının yazılma zamanı **15:26:03 Türkiye / 12:26:03 UTC**; ölçümlerin ayrı ayrı alınma anı veya test süresi değildir):

| Ölçüm | Trafik snapshot'ı | Trafiksiz snapshot |
| --- | ---: | ---: |
| Scrape up | 1 | 1 |
| Task HTTP rate (istek/s) | 0.0849800992 | 0 |
| 5xx (%) | 0 | NaN |
| p95 (s) | 0.3583148326 | NaN |
| Process CPU (tek çekirdek karşılığı %) | 2.0973444104 | 0.4471179854 |
| Working set (byte) | 164921344 | 184774656 |
| Cache hit / miss (olay/s) | 0.0571254750 / 0.0283610344 | 0 / 0 |
| Cache hit (%) | 66.8653782893 | NaN |
| Invalidation (işlem/s) | 0.0279168611 | 0 |

Aynı son koşunun kesinti snapshot'ında 5xx **%22.4331729788** idi; farklı sorgu anlarının/pencerelerin sonuçları karıştırılmamalıdır. Bunlar küçük kontrollü örneklerdir; normal gecikme veya performans garantisi olarak kullanma. İlk kez oluşan 5xx counter'ı için de ilk hatadan sonra bir scrape baseline'ı beklenir; son script yeni API prosesinde doğrulandı ve exit 0 verdi.

İlk JSON üretiminde PowerShell stdin encoding'i Türkçe karakterleri `?` yaptı. UTF-8 patch ile düzeltildi. Koşu sırasında provider bu başlık değişikliğini aldığı için ilk uzun testin son browser kontrolü tamamlanamadı; güncel dashboard metadata'sını yeniden okuyan testle tarayıcı ve tam kabul tekrar PASS aldı. Secret scanner, çalışma anında üretilen auth değişkeninin adını literal token ataması sanınca değişken `encoded_auth` olarak açıkça adlandırıldı; scanner kuralı gevşetilmedi veya gerçek credential allowlist'e alınmadı.

### Güvenlik, cleanup ve sınırlar

- Mevcut `.env` ve user-secrets değiştirilmedi; dosya hash'leri korundu. Credential/complete PostgreSQL connection string değerlerinin repository ve servis loglarında bulunmadığı, değerler gösterilmeden ayrıca kontrol edildi. Secret regression check ve `git diff --check` PASS. Kontrol bütün olası secret formatlarını veya Git geçmişini taramaz.
- Browser credential'ları yalnız bellekte tutuldu. Test CLI/stdout/stderr raw exception, response body veya credential göstermez. Beklenen yeni-account advisor preference 404, yalnız ilgili endpoint/status ile ayrılır; bütün 404'ler ignore edilmez.
- Test Task'ları ve yalnız test tarafından oluşturulan liste cache'i temizlendi. Mevcut `tasks`, Module 3B `lab_tasks` ve migration history satır hash'leri korundu; identity sequence normal test INSERT'leri nedeniyle ilerleyebilir.
- Başlangıçta bulunmayan altı test container'ı ve Compose ağı `down` ile kaldırıldı. **Mevcut 21 volume** (external PostgreSQL, Grafana ve Prometheus dahil) korundu; volume silinmedi. **12 ilişkisiz container ID/state ve yedi network ID** aynı kaldı; default bridge ID bu deneyde değişmedi. Prune veya `down -v` kullanılmadı.
- Geçici Playwright bağımlılıkları/kanıt dosyaları repository dışında tutulup temizlendi; package/lock değişmedi. Stack sonunda başlangıçtaki gibi kapalıdır; dashboard adresi ancak tekrar başlatıldığında erişilebilir.
- Sabit 2m pencere hızlı değişimleri yumuşatır; küçük örneklem, scrape başlangıcı, process reset ve histogram bucket çözünürlüğü sonuçları etkiler. Yeni API prosesinde henüz event almayan serilerin boş olması query hatası değildir. Dashboard/API durumu readiness yerine geçmez.

Sıradaki önerilen küçük adım, yalnız açık talep üzerine **Module 10 final acceptance ve öğrenme değerlendirmesi**. Bu görev final kabulü, dashboard dışı yeni özellik veya başka modül uygulaması yapmadı. Commit/push yapılmadı.

## Module 10 final kabulü ve öğrenme değerlendirmesi — 3 Ekim 2026

**3 Ekim ilk incelemesinin tarihsel sonucu: INCOMPLETE; dört açık madde 4 Ekimde kapatıldı (K7).** Release/configuration, altı servis, metrics/scrape, gerçek tarayıcı, CRUD/cache, bağımlılık recovery ve counter reset kontrolleri PASS. Ancak çalışan sistem ile şartnamenin her maddesini karşılamak aynı sonuç değildir. Toplam cache sayı panelleri, backend request log bilgisi ve kalıcı ekran görüntüsü kanıtı eksik; service-name/port/path hatası oluşturup düzeltme deneyi ayrıca doğrulanmadı. Bu inceleme bunları otomatik uygulamadı; backend, Compose, dashboard ve secret akışları değişmedi.

### Kanıt anahtarı

- **K1 — Statik inceleme:** `Program.cs`, `TaskCacheMetrics.cs`, proje/appsettings dosyaları, Compose, Prometheus YAML, datasource/provider YAML ve dashboard JSON; başlangıç Git temiz, son commit `4eaf46e`.
- **K2 — Bu koşunun kontrolleri:** Release build, configuration smoke **20/20**, normal preflight, preflight fixture **19/19**, secret fixture **15/15**, repository secret check, `config -q`, `promtool check config`.
- **K3 — Bu koşunun gerçek runtime/browse kanıtı:** altı healthy servis; metrics/Prometheus endpoint smoke; tam dashboard smoke ve datasource smoke; Edge login, dokuz panel ve Grafana plugin sorguları; Prometheus Targets/Query UI.
- **K4 — Bu koşunun kontrollü deneyleri:** tek PostgreSQL kesintisi, 150 saniye trafiksiz pencere, API stop/start ve ham counter örnekleriyle reset düzeltmesi. Geçici yardımcılar repository dışında tutuldu.
- **K5 — Önceki değişmeyen kabul:** yukarıdaki Prometheus TSDB, Grafana datasource/account ve Overview restart/down-up sonuçları. Bunlar bu final koşusunda yeniden yapılmış testler olarak raporlanmaz.
- **K7 — 4 Ekim eksik kapatma kabulü:** üç toplam panelinin gerçek counter/plugin/browser sonuçları, güvenli CRUD/400/404/500 logları, ayrı geçici Prometheus DNS/port/path DOWN→UP deneyleri ve üç kalıcı tarayıcı görüntüsü; yeni güvenlik/build/cleanup sonuçları aşağıda. K1–K6 önceki incelemenin kanıtlarıdır.
- **K6 — Bu koşunun güvenlik/temizlik:** gerçek credential değerlerine karşı bellekte karşılaştırma; PostgreSQL satır hash'leri, protected-file hash'leri ve Docker envanteri. Değerler yayınlanmadı.

`PASS` kanıtı olan şartı; `FAIL` mevcut implementasyondaki eksiği; `NOT VERIFIED` çalıştırılmamış özel senaryoyu gösterir. K5 belgelenmiş önceki kabul kanıtıdır; mevcut koşunun bağımsız yeniden ölçümü değildir.

### PROJECT_SPEC.md Module 10 eşleştirmesi — 4 Ekim 2026 güncellemesi

| Şartname maddesi | Sonuç | Kanıt ve sınır |
| --- | --- | --- |
| Monitoring eklenmeden Docker logs/compose logs incelemesi | PASS | K5: Docker-native adımının zamanlı log kayıtları ve komut tablosu. |
| Docker inspect/stats/compose ps incelemesi | PASS | K5 ilk adım; K3/K4 güncel güvenli inspect, altı servis ps ve stats örneği. |
| Backend application startup logu | PASS | K3: `Application started`/dinleme kategorisi mevcut. |
| Backend database connection status | PASS | K4: PostgreSQL unavailable/DB connection failure logları ve gerçek SQL recovery. Her başarılı bağlantı için ayrı connection logu yok. |
| Backend Redis cache hit/miss logu | PASS | K3: gerçek hit/miss ve invalidation olayları mevcut. |
| Backend exception logu | PASS | K4: kontrollü DB kesintisinin exception kayıtları. Ham exception/connection string yayınlanmadı. |
| Backend request bilgisi | PASS | K7: mevcut ILogger ile method, sabit route template/unmatched, final status ve ms; gerçek CRUD/400/404/500, private canary yokluğu ve probe istisnaları. |
| Log/metric/trace ayrımı ve rollerin öğretilmesi | PASS | Bu bölümde örneklerle açıklanır; tracing uygulanmış sayılmaz. |
| System.Diagnostics.Metrics ve OpenTelemetry Metrics | PASS | K1: meter factory/custom counters ve `AddOpenTelemetry().WithMetrics`. |
| ASP.NET Core request metrikleri | PASS | K3/K4: gerçek histogram count/sum/bucket, Task route/method/status serileri. |
| Kestrel/runtime anlamlı hazır metrikler | PASS | K1/K3: Kestrel/runtime meter, CPU counter ve working-set gauge. Thread-pool tip sınırlaması açık; onlara rate yok. |
| Uygulamaya özel cache metrikleri | PASS | K3: hit/miss/invalidation counter'ları Prometheus ve Grafana'dan gerçekten okunabildi. |
| Internal GET /metrics | PASS | K3: 200 Prometheus text; API host binding boş. Nginx `/metrics` yalnız 200 HTML fallback. |
| Cache hit count ölçülebilir | PASS | K1/K3: `fullstackops_cache_hits_total`, counter. |
| Cache miss count ölçülebilir | PASS | K1/K3: `fullstackops_cache_misses_total`, counter. |
| Cache invalidation count ölçülebilir | PASS | K1/K3: `fullstackops_cache_invalidations_total`, counter. Fiziksel silinen key sayısı değil. |
| Metric/label adlarının README ve dashboard ile eşleşmesi | PASS | K3: canlı TYPE/route ve gerçek Grafana plugin sorguları; JSON'daki adlar doğru. |
| Task/user/request ID, raw URL, exception message gibi sınırsız label yok | PASS | K1/K3: HTTP whitelist method/template/status; cache custom label yok; canlı forbidden-label/raw-ID kontrolü temiz. Sabit OpenAPI route template'i de oluşabilir. |
| Resmî Prometheus image'ı ve Compose servisi | PASS | K1: `prom/prometheus:v3.13.4`; yukarıdaki resmî referans/digest kayıtları. Sürüm değişmedi. |
| 15s scrape, gerçek service/port/path ve version-controlled config | PASS | K1/K3: `api:8080/metrics`, 15s/10s timeout, promtool SUCCESS ve target API. |
| Prometheus Targets UI backend UP | PASS | K4: gerçek Edge'de endpoint ve UP; durdurulunca DOWN. |
| Prometheus UI up sorgusu 1 | PASS | K4: Query table'da `up{instance="api:8080",job="fullstack-ops-api"}=1`. |
| Request/cache metrikleri Prometheus UI'da sorgulanabilir | PASS | K3/K4: gerçek Query UI'da HTTP count ve cache hit serisi; ilk scrape beklenerek doğrulandı. |
| Instant vector/range vector uygulaması | PASS | K3/K4: instant query ve aynı evaluation timestamp'te `[2m]` ham range vector. |
| rate/sum/label filter ve counter/gauge farkı uygulaması | PASS | K3/K4: dashboard ve reset deneyi; working set doğrudan gauge olarak sorgulanır. |
| Resmî Grafana image'ı ve Compose servisi | PASS | K1/K3: `grafana/grafana:13.2.3`; health ve gerçek browser. |
| Datasource YAML provisioning | PASS | K3: tek default/read-only datasource; UID `fullstack-ops-prometheus`; manuel ekleme yok. |
| Dashboard provider YAML provisioning | PASS | K1/K3: dosya provider'ı ve API `meta.provisioned=true`. |
| Dashboard JSON repository'de | PASS | K3/K7: sabit UID fullstack-ops-overview; mevcut dokuz panel korunarak üç toplam paneli eklendi, gerçek tarayıcıda 12 panel. |
| Grafana datasource URL service DNS kullanıyor | PASS | K1/K3: `http://prometheus:9090`, container localhost'u değil. |
| Admin environment ile yönetiliyor, gerçek parola Git dışında | PASS | K1/K2/K6: service env referansları, placeholder example, ignored/untracked `.env`, değer göstermeyen tarama. |
| Dashboard adı FullStack Ops Lab Overview | PASS | K3: API ve gerçek tarayıcıda aynı başlık. |
| Dashboard API target up paneli | PASS | K3/K4: panel 1, scrape durumu; readiness etiketi kullanılmaz. |
| Dashboard HTTP request/s paneli | PASS | K3: panel 2, `sum(rate(...count[2m]))`, gerçek trafik artışı. |
| Dashboard HTTP 5xx oranı paneli | PASS | K3/K4: panel 3, yalnız 5xx; 400/404 sıfır payı, DB outage pozitif oran. |
| Dashboard p95 paneli | PASS | K3: panel 4, histogram bucket rate ve `sum by(le)`; birim saniye. |
| Dashboard cache hit sayısı paneli | PASS | K7: panel 10, sum(fullstackops_cache_hits_total{job="fullstack-ops-api"}); gerçek toplam 6, birim sayı. |
| Dashboard cache miss sayısı paneli | PASS | K7: panel 11, sum(fullstackops_cache_misses_total{job="fullstack-ops-api"}); gerçek toplam 5, birim sayı. |
| Dashboard cache hit ratio paneli | PASS | K3: panel 8, `100*H/(H+M)`; trafiksiz NaN korunuyor. |
| Dashboard cache invalidation sayısı paneli | PASS | K7: panel 12, sum(fullstackops_cache_invalidations_total{job="fullstack-ops-api"}); gerçek toplam 6, birim sayı. |
| Trafiksiz sonuçların açıklanması ve kontrollü trafik | PASS | K3/K4: CRUD/cache trafiği; 150s idle, rate 0, ratio/p95 NaN; sahte sıfır yok. |
| Prometheus named volume prometheus_data | PASS | K1/K3: `/prometheus` volume inspect; 7d/256MB retention ve 512MiB/1CPU limit. |
| Grafana datasource/dashboard dosyadan, veri grafana_data'da | PASS | K1/K3/K5: üç bind mount RW=false; data named volume; önceki restart/down-up kabulü. |
| Makul local retention/kaynak sınırları | PASS | K1/K3: explicit sınırlar ve tek stats örneği. Retention süre/kapasite baskısı testi yapılmadı. |
| down -v monitoring verisi kaybı uyarısı | PASS | README açıklaması mevcut; tehlikeli komut bu görevde çalıştırılmadı. |
| API metrics internal; monitoring localhost; DB/Redis host portu yok | PASS | K3: API/PG/Redis `{}`; frontend 127.0.0.1:18081, Prometheus 9090, Grafana 3000. |
| Prometheus /-/ready healthcheck, image içi araç | PASS | K1/K3: gerçek wget probe başarılı, container healthy; promtool çalıştı. |
| Grafana /api/health healthcheck, image içi araç | PASS | K1/K3: gerçek wget probe, 200/database=ok, container healthy. |
| Grafana anonymous access kapalı | PASS | K3: authenticated olmayan datasource API isteği 401. |
| Metrics secret/kişisel veri/user-input label içermez | PASS | K1/K3/K6: whitelist/template; gerçek credential ve canary kontrolleri temiz. Bütün olası secret biçimleri garantisi değil. |
| Güncel resmî kaynaklara dayalı yaklaşım | PASS | Önceki sürüm seçimi referansları; bu incelemede resmî Prometheus functions ve Grafana provisioning belgeleri tekrar okundu. |
| Lab 1–7: gözlem, internal scrape, up UI, cache olayları, panel güncellemesi | PASS | K3/K4; K5 Docker-native inceleme. |
| Lab 8–9: hedefi erişilemez yapma, DOWN/veri kesilmesi | PASS | K4: API stop/start, UI DOWN/up=0; eski counter anlık seri yok/absent. Tarihsel grafik tamamen silinmez. |
| Lab 10: yanlış service-name/port/path ayarını düzeltme | PASS | K7: ayrı geçici Prometheus yapılandırmasında üç hata, DOWN/up=0/lastError ve her seferinde api:8080/metrics UP/up=1; API aynı container ve live200. |
| Completion: metrics endpoint, scrape UP, monitoring readiness/health | PASS | K3/K4: gerçek 200, UP ve altı healthy servis. |
| Completion: otomatik datasource/dashboard ve gerçek trafik | PASS | K3/K7: sabit UID, provisioning metadata, 12 panel gerçek Edge/plugin sorguları ve CRUD/cache trafiği. |
| Completion: monitoring hata teşhis/recovery | PASS | K4/K7: bağımlılık-ready ayrımı, API DOWN/recovery ve ayrı DNS/port/path misconfiguration düzeltmeleri. |
| Completion: README ve PromQL güncel | PASS | Bu kabul matrisi ve gerçek ölçümler; sorgular gerçek adları kullanıyor. |
| Completion: ekran görüntüleri güncel | PASS | K7: repository images klasöründe gerçek Targets, HTTP counter sorgusu ve 12 panelli Overview PNG; aşağıda göreli bağlantılar. |

Opsiyonel task create/update counter'ları zorunlu değildir; yeni metric eklenmedi. CPU/memory panelleri faydalıdır ama zorunlu cache **sayı** panellerinin yerine geçmez. 3 Ekimde rate/count farkı açık bırakılmıştı; 4 Ekimde mevcut rate panellerini değiştirmeden ayrı toplam panelleri eklendi (K7).

### Gerçek komutlar ve sonuçlar

```powershell
dotnet build src/backend/FullStackOpsLab.Api/FullStackOpsLab.Api.csproj -c Release
powershell -NoProfile -ExecutionPolicy Bypass -File tests/Module9.Configuration.Smoke.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/Module9.EnvPreflight.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File tests/Module9.EnvPreflight.Smoke.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File tests/Module9.SecretLeakage.Smoke.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/Module9.SecretLeakage.Check.ps1
docker compose --env-file .env config -q
docker compose --env-file .env up -d --wait --wait-timeout 240
docker compose --env-file .env exec -T prometheus promtool check config /etc/prometheus/prometheus.yml
powershell -NoProfile -ExecutionPolicy Bypass -File tests/Module10.Metrics.Smoke.ps1 -EndpointOnly
powershell -NoProfile -ExecutionPolicy Bypass -File tests/Module10.Prometheus.Smoke.ps1 -EndpointOnly
python -u tests/Module10.Dashboard.Smoke.py
powershell -NoProfile -ExecutionPolicy Bypass -File tests/Module10.Grafana.Smoke.ps1
docker compose --env-file .env ps --format '{{.Service}}|{{.State}}|{{.Health}}'
docker compose --env-file .env down
git diff --check
git status --short
```

Dashboard tam koşusunda ek `--results-file` yalnız repository dışındaki geçici kanıt dosyasını seçti. Ayrı geçici reset/Prometheus UI yardımcıları, yalnız kabulün bu özel kısmını doğruladı; kalıcı test script'i veya dependency eklenmedi. Python test ortamında Playwright **1.63.0**, gerçek kurulu Edge kullanıldı. `dotnet test` çalıştırılmadı; boş test keşfi başarı kanıtı sayılmadı. Mevcut PowerShell/Python smoke sonuçları gerçek test kanıtıdır.

Başlangıç Git temizdi. Engine ilk erişimde kapalıydı; `docker desktop start --detach --timeout 60` sonrası **29.6.1**, Compose **v5.3.0** erişildi. Kaynak envanteri Engine açıldıktan sonra, Compose başlamadan kaydedildi; kapalı Engine'in önceki kaynak durumunu ölçmüş sayılmıyoruz. Configuration negatif testlerinde **0xE0434352** yanında beklenen güvenli stderr mesajı ve canary/tam test connection string yokluğu da doğrulandı. Error-mode yalnız test process kapsamındadır.

Altı servis **running/healthy** oldu; Prometheus config SUCCESS. Internal health/live/ready/OpenAPI/metrics **200**; Grafana health **200/database=ok**; anonymous API **401**. Datasource smoke HTTP için **7**, working set/cache counter'ları için birer gerçek series döndürdü. Prometheus Query UI'da `up=1`, HTTP count ve cache hit görünür; ilk scrape öncesi boş counter başarı diye kabul edilmedi.

| Dashboard ölçümü | Kontrollü trafik | 150s trafiksiz pencere |
| --- | ---: | ---: |
| Scrape up | 1 | 1 |
| Task request rate, istek/s | 0.0925144278 | 0 |
| HTTP 5xx, % | 0 | NaN |
| p95, saniye | 0.3458038238 | NaN |
| Process CPU, tek çekirdek karşılığı % | 2.1643808871 | 0.4994647313 |
| Working set, byte | 160890880 | 180244480 |
| Cache hit/miss, olay/s | 0.052575 / 0.0278133459 | 0 / 0 |
| Cache hit, % | 65.4269584012 | NaN |
| Invalidation, işlem/s | 0.0260711111 | 0 |

Bunlar aynı testin farklı sorgu anlarıdır, tek atomik sistem snapshot'ı değildir. DB kesinti snapshot'ında 5xx **%20.5671548356** idi. POST **201** ve doğru Location, PUT **200**, DELETE **204**, GET **200**, boş başlık **400**, bulunmayan ID **404** geçti. Tek kontrollü PostgreSQL kesintisinde doğrudan DB okuyan üç GET **500** verdi; API aynı ID'de **running/unhealthy**, live **200**, ready **503**, Prometheus **up=1** kaldı. PostgreSQL geri geldiğinde aynı API healthy ve DB GET **404** oldu.

API counter reset kontrolü **14:56:42 UTC / 17:56:42 Türkiye saati**: aynı API container'ını stop/start etmek target DOWN/up=0, sonra healthy/UP yaptı. POST/400 histogram count **21 → 7** oldu. Aynı 2m evaluation penceresinde **6 ham sample**, `resets(...[2m])=1`, reset düzeltmeli olay artışı **27**; `rate()` **0.2369056122772931 istek/s**, ham sample/extrapolation hesabı **0.23690540956025546** çıktı (bağıl tolerans 1e-6). Pencere restart öncesi ve sonrası olayları kapsar; 27 yalnız restart sonrası istek sayısı değildir. Negatif basit fark yerine reset düzeltmesi doğrulandı. Rate önce tekil seriye, sonra sum'a uygulanır ([resmî rate belgesi](https://prometheus.io/docs/prometheus/latest/querying/functions/#rate)).

Tarayıcıda dokuz panel ve bütün `/api/ds/query` ifadeleri trafik ve idle koşullarında geçti; beklenmeyen console/page/datasource hatası yok. Önceki testteki dar advisor preference 404 istisnası korundu. Prometheus'un polling UI'sinde `networkidle` timeout verdi; gerçek rendered target/result öğeleri beklenince UI kontrolü geçti. Yeni cache counter'ının ilk scrape öncesi yokluğu da geçici testte bekleme ile düzeltildi. Reset testi absent sample'ı ilk başta erken failure saydı; yalnız geçici yardımcı düzeltildikten sonra tam reset testi geçti. Bu başarısız araç denemeleri uygulama hatası veya başarılı test olarak sunulmadı.

### Kalıcılık, güvenlik ve cleanup

Önceki Prometheus tarihsel sample down/up, Grafana hesap/datasource restart/down-up ve dashboard yeniden provisioning sonuçları değerlendirildi; aynı kesinti deneyi farklı script'lerde tekrarlanmadı. `Module8.Readiness.Smoke.ps1` tam dört servis beklediğinden altı serviste körlemesine çalıştırılmadı; aynı live/ready/Docker health koşulları dashboard testiyle doğrulandı. Metrics/Prometheus tam smoke'larının ilave Redis kesintileri de gereksiz tekrar edilmedi; endpoint modları kullanıldı.

Son cache UI kontrolündeki scrape zamanlamasını düzeltmek için stack kısa süre yeniden açıldı; yalnız iki salt okunur GET üretildi, scrape beklendi, UI HTTP/cache sorguları geçti, altı servis yeniden healthy görüldü. Yeni kesinti veya ikinci CRUD deneyi yapılmadı. Bu GET çifti sonrası test key'inin kalan TTL'si **60 saniye**ydi; testin oluşturduğu key açık adıyla DEL edildi, EXISTS **0** doğrulandı.

İlk down öncesinde mevcut `tasks`, `lab_tasks`, `__EFMigrationsHistory` satır sayıları/içerik hash'leri başlangıçla aynıydı; yalnız test Task'ı silindi. Son kısa açılış yalnız GET kullandı. Sequence INSERT nedeniyle ilerleyebilir, reset edilmedi. `.env`/user-secrets hash'leri aynı kaldı; credential veya çözülmüş connection string terminal/dokümana yazılmadı. Mevcut servis logları, metrics ve repository dosyaları gerçek credential değerlerine karşı bellekte karşılaştırıldı; sızıntı yok. Configuration/preflight fixture'ları canary çıktısı yokluğunu doğruladı. Git geçmişi ve bütün production hata yolları taranmış değildir.

Son `down` sonrası Compose container/ağı yok; **12 ilişkisiz container ID/state, 7 network ID ve 21 volume adı** başlangıçla aynı. Default bridge ID bu görevde değişmedi. External PostgreSQL, Grafana ve Prometheus volume'ları korundu; image, volume silme/prune/down -v kullanılmadı. Docker Desktop açık bırakıldı; uygulama stack'i kapalı. Geçici browser/test araçları, screenshot ve sonuç dosyaları temizlendi. Yalnız bu README ve `PROJECT_STATUS.md` değişti.

### 3 Ekimde belirlenen eksikler — 4 Ekimde tamamı kapatıldı

1. Şartnamenin toplam cache hit/miss/invalidation panelleri yok; mevcut rate panelleri bunların eşdeğeri değil. Counters/exporter doğru çalışıyor.
2. Backend başarılı request method/path/status log bilgisi gözlemlenemiyor; Nginx access logu mevcut. Logging düzeyi veya middleware bu incelemede değiştirilmedi.
3. Kalıcı, güncel Module 10 screenshot yok. Metin odaklı mevcut secret scanner binary dosyada SCAN_ERROR üretir; PNG ekleme ve uygun dar tarama kapsamı ayrı gözden geçirilmeli. Bu incelemede scanner kuralı gevşetilmedi veya görsel eklenmiş sayılmadı.
4. Yanlış Prometheus service-name/port/path oluşturup düzeltme senaryosu **NOT VERIFIED**. API stop/start erişim kesintisi ve bağımlılık kesintisi bunun yerine yanlış configuration kanıtı olarak sunulmadı.

Thread-pool runtime tip sınırlaması, health probe timeout/readiness zamanlaması ve normal log kaynaklarının sınırları önceki bölümlerde geçerlidir. Histogram yaklaşımı, 2m smoothing ve düşük örnek sayısı nedeniyle performans/kapasite garantisi yok. Load test, production hardening, alerting, tracing, merkezi log ve yedi günlük retention sınırı deneyi yapılmadı; şartname kapsamı dışındaki özellikler eklenmedi.

### Kısa öğrenme değerlendirmesi

| Kavram | Bu projede nasıl yorumlamalısın? |
| --- | --- |
| Log / metric | `[CACHE MISS]` belirli olayın kaydıdır. `rate(...misses_total[2m])` zaman penceresindeki olay/s davranışıdır. Yakın log saatleri tek isteğin servisler arası trace'ı değildir. |
| Counter / gauge / histogram | Hit counter birikir ve restart'ta reset olur; working set gauge anlık artıp azalır; request histogram süreleri bucket/count/sum olarak toplar. Gauge'a rate uygulama. |
| Scrape interval / rate penceresi | Prometheus 15s'de bir örnek alır; 2m rate yaklaşık sekiz aralık içerir, en az iki sample ister. Dashboard refresh15s yeni olayın hemen görünmesini garanti etmez. |
| Request rate / 5xx / p95 | rate istek/s; 5xx oranı yalnız 500–599'un tüm Task isteklerine oranı; 400/404 dahil değil. p95 bucket'lardan yaklaşık değer, browser/Nginx uçtan uca gecikmesi değil. Trafiksiz 0/0 NaN anlamlı bir sıfır değildir. |
| Cache hit/miss/invalidation | Cache value okunup deserialize edilirse hit; başarılı Redis read'de key yoksa miss; başarılı DB mutation sonrası remove tamamlanırsa invalidation. Hit oranı yüksek olması tek başına doğru cache/veri garantisi değildir. |
| up / readiness | PostgreSQL kesintisinde API metrics scrape çalıştığı için up=1, DB ile iş yapamadığı için ready503 oldu. API kapatılınca up=0. Docker health kendi periyodik probe zamanını yansıtır. |
| Label cardinality | Her yeni label kombinasyonu yeni series üretir. `/api/tasks/{id:int}` sınırlı template; gerçek Task ID/başlık/request ID eklemek sınırsız maliyet ve veri sızıntısı riski yaratır. |
| Provisioning / kalıcılık | YAML/JSON tanımı Git'ten tekrar yüklenir; Prometheus TSDB ve Grafana çalışma verisi named volume'da kalır. Normal down volume'u bırakır, down -v monitoring verisini silebilir. Dosyadan tanım geri gelmesi eski metric geçmişinin geri gelmesi değildir. |

Kendi kelimelerinle cevapla: **up=1 iken kullanıcı niçin 500 alabilir?** **Gauge'a rate uygulamak hangi yanlış yorumu doğurur?** **Cache rate paneli ile cache toplam sayısı neden farklıdır?** **Restart'tan önce ve sonra counter'ı doğrudan çıkarmak yerine rate neden kullanılır?** **Provision edilmiş dashboard ile saklanan TSDB verisi arasında ne fark var?**

İki küçük öğrenme alıştırması (bu incelemede uygulanmadı): (1) Aynı hit counter için instant toplam ve 2m rate sorgularının birim/anlam farkını kâğıt üzerinde açıkla. (2) Bir DB kesintisi için live/ready/Docker health/up beklenen değerlerini yaz; hangi gözlemin hangi soruyu cevapladığını belirt.

3 Ekim önerisi bu dört eksiği küçük bir adımda kapatmaktı; 4 Ekimde aşağıdaki kabul ile tamamlandı. Şartnameye göre sonraki modül **Module 11 — GitHub Actions CI**; ilk plan, backend/frontend build, image build, Compose/promtool validation içeren minimum workflow kapsamını belirlemektir. Module 11 veya yeni observability uygulaması başlatılmadı. Önerilen dokümantasyon commit mesajı: `docs(observability): record final acceptance evidence and gaps`. Commit/push yapılmadı.

## Şartname farklarının kapatılması — 4 Ekim 2026

**K7 / Genel sonuç: PASS; Module 10 COMPLETE.** Önceki final kabulden kalan README/PROJECT_STATUS değişiklikleri korundu. Yeni özellik veya Module 11 uygulaması yapılmadı; backend API/cache/instrumentation sözleşmesi, Compose, datasource/provider ve ana Prometheus YAML değiştirilmedi. Yalnız dört eksik ve bunların test/dokümantasyon gereksinimleri tamamlandı.

### 1. Cache toplam sayı panelleri

Mevcut paneller 1–9 ve dashboard ayarları önceki Git sürümüyle JSON olarak eşit; rate panelleri korunuyor. Sabit datasource UID `fullstack-ops-prometheus`, dashboard UID `fullstack-ops-overview`, 15s refresh ve read-only provisioning aynı. Eklenen paneller:

| ID / panel | Gerçek PromQL | Grafana birimi | Kontrollü trafik sonucunda |
| --- | --- | --- | ---: |
| 10 / Cache hit toplamı | `sum(fullstackops_cache_hits_total{job="fullstack-ops-api"})` | `short`: olay sayısı | 6 |
| 11 / Cache miss toplamı | `sum(fullstackops_cache_misses_total{job="fullstack-ops-api"})` | `short`: olay sayısı | 5 |
| 12 / Cache invalidation toplamı | `sum(fullstackops_cache_invalidations_total{job="fullstack-ops-api"})` | `short`: tamamlanan invalidation sayısı | 6 |

Bunlar **API prosesinin başlangıcından beri biriken counter toplamlarıdır**; API yeniden başlayınca reset olabilir. Invalidation silinen fiziksel key veya Task sayısı değildir. Rate panelleri `ops` (olay/s), toplam panelleri `short` (sayı) kullanır. İlk event henüz yoksa seri boş olabilir; sahte sıfır eklenmedi. Cache oranı/p95'in boş/NaN davranışı ve diğer dokuz panel değişmedi. Önceki reset/150s idle kanıtı tekrar edilmeden korundu; yeni toplam sorgularına rate uygulanmaz.

`Module10.Dashboard.Smoke.py --traffic-only` gerçek CRUD/cache trafiği, yeni panellerin counter sorgularıyla eşitliği, 12 panelin Edge'de görünmesi ve tüm Grafana native plugin sorgularını doğruladı. Beklenmeyen console/page/datasource hatası yok; mevcut dar advisor-preference 404 istisnası aynı. Trafik snapshot'ında request rate **0.1417814351 istek/s**, p95 **0.1393155323 s**, cache hit oranı **%60.6967316945** idi. Farklı sorgu anlarının kısa örnekleridir; benchmark/kapasite veya gecikme garantisi değildir.

### 2. Güvenli backend request logu

`Microsoft.AspNetCore=Warning` filtresini genel olarak Information'a açmak Hosting request-start satırlarında raw URL/query görünmesine yol açabilir. Yerleşik [HTTP logging](https://learn.microsoft.com/en-us/aspnet/core/fundamentals/http-logging/?view=aspnetcore-10.0) değerlendirildi; güvenli template seçimi ve mevcut dış exception handling sonrası final status gereksinimi için mevcut `ILogger` altyapısında tek küçük middleware tercih edildi. Yeni paket veya ikinci log pipeline yok.

`UseRouting` sonrasında endpoint'in sabit template'i alınır; eşleşmeyen yol `unmatched`, standart olmayan method `OTHER` olur. `FullStackOpsLab.Api.Requests` Information kategorisi şu alanları yazdırır:

```text
HTTP <method> <route-template-or-unmatched> -> <final-status> in <duration> ms
```

Süre Stopwatch ile middleware girişinden response completion'a kadar ölçülür; network roundtrip veya histogram p95 ile aynı ölçüm değildir. [OnCompleted](https://learn.microsoft.com/en-us/dotnet/api/microsoft.aspnetcore.http.httpresponse.oncompleted?view=aspnetcore-10.0) response tamamlandıktan sonra final status'u gözler; dışarıda ele alınan exception'ın 500 sonucu yanlış 200 diye yazılmaz. Kesilmiş/hiç tamamlanmayan request için log garantisi verilmez.

| Gerçek request senaryosu | HTTP sonucu / güvenli template | Sonuç |
| --- | --- | --- |
| Liste/tek kayıt GET | 200; `/api/tasks/`, `/api/tasks/{id:int}` | PASS |
| POST | 201; `/api/tasks/`; Location ve altı JSON alanı korundu | PASS |
| PUT / DELETE | 200 / 204; `/api/tasks/{id:int}` | PASS |
| Boş başlık / olmayan ID | 400 / 404; aynı sabit template'ler | PASS |
| Bilinmeyen private yol / standart dışı method | `unmatched` / `OTHER`; 404 | PASS |
| PostgreSQL geçici kapalıyken gerçek ID GET | 500; `/api/tasks/{id:int}`; final status logu | PASS |
| PostgreSQL geri geldikten sonra readiness | 200, aynı API container'ı healthy | PASS |

`Module10.RequestLogs.Smoke.py` her beklenen method/template/status logunu, negatif olmayan ms değerini ve private canary yokluğunu kontrol etti. Body, query, Authorization/Cookie ve raw private path içeren sahte istekler API'ye internal yoldan gönderildi; bu değerler backend loglarında yok. Bu deney Nginx'in mevcut access loguna private query göndermedi; Nginx formatı değiştirilmedi. Gerçek connection string'in loglarda bulunmadığı değer göstermeden kontrol edildi.

`/health`, `/health/live`, `/health/ready`, `/metrics` normal request özetlerinden hariçtir; dört probe HTTP200 ile ayrıca doğrulandı. Mevcut health/DB/exception hata logları filtrelenmez. Bu endpoint'lerin HTTP **metrikleri** de zaten `DisableHttpMetrics` ile hariçti; instrumentation değişmedi.

### 3. Yanlış service-name / port / path deneyleri

`Module10.ScrapeTargets.Smoke.py` mevcut internal ağ ve mevcut Prometheus image ID'siyle **ayrı, geçici** bir Prometheus çalıştırır. Host portu, named volume veya custom network oluşturmaz. Ana config/kalıcı TSDB değiştirilmez; geçici YAML read-only bağlanır. Her değişimde promtool kontrolü ve yalnız bu geçici instance'a HUP reload kullanılır; scrape 15s, timeout10s, bekleme en fazla75s.

| Hata | Gerçek hedef | Target / up | Last scrape error özeti | Düzeltilen hedef ve toparlanma |
| --- | --- | --- | --- | --- |
| Service-name | `module10-api-missing-f503ba95:8080/metrics` | DOWN / 0 | `lookup ... on 127.0.0.11:53: no such host` | `api:8080/metrics`, UP / 1 |
| Port | `api:18080/metrics` | DOWN / 0 | `connect: connection refused` | `api:8080/metrics`, UP / 1 |
| Metrics path | `api:8080/module10-metrics-missing` | DOWN / 0 | `server returned HTTP status 404 Not Found` | `api:8080/metrics`, UP / 1 |

Başarısız scrape UTC zamanları sırasıyla **09:40:11**, **09:40:31**, **09:40:44**; ilk doğru toparlanma scrape'ları **09:40:20**, **09:40:35**, **09:40:50**. Her hata sırasında aynı API container'ı **running**, liveness **200** idi. Böylece `up=0` API prosesinin mutlaka durduğu anlamına gelmez; hedef konfigürasyonu da yanlış olabilir. Ana Prometheus target'ı doğru kaldı ve endpoint kabulü PASS verdi.

İlk yardımcı denemeleri başarı sayılmadı: diagnostic container'ın DNS label'ı 63 karakteri aştığı için kısa benzersiz ad kullanıldı. Reload sonrası eski/yeni target serileri kısa süre birlikte bulunabildiğinden `up` doğrulaması yalnız job yerine ilgili `instance` etiketiyle yapılır. Böylece başka hedefin eski başarılı sample'ı yanlış sonuca yol açmaz. Düzeltilen test üç ayrı DOWN/recovery için exit0 verdi.

### 4. Güncel gerçek tarayıcı görüntüleri

4 Ekimde gerçek Edge/Playwright üzerinden alındı; manuel import yok. Login formu, profil/credential, Task başlığı veya kişisel veri gösterilmez. Prometheus sorgusu aşağıdaki gerçek histogram count serilerini gösterir; 200/201/204/400/404/500 ayrımı ve sınırlı template label'ları görünür.

```promql
http_server_request_duration_seconds_count{job="fullstack-ops-api",http_route=~"/api/tasks.*"}
```

- [Prometheus Targets — doğru hedef UP](images/prometheus-targets.png)
- [Prometheus Query — gerçek HTTP counter sonuçları](images/prometheus-query.png)
- [Grafana Overview — 12 provision edilmiş panel](images/grafana-overview.png)

Görsellerin içeriği görsel olarak kontrol edildi. Secret scanner yalnız bu **üç açık PNG yolu** için imza/chunk sınırı/IEND kontrolüyle dar dokümantasyon istisnası kullanır; metin/EXIF/unknown metadata chunk ve trailing payload kabul edilmez. Diğer binary dosyalar hâlâ SCAN_ERROR'dır. PNG pikselleri OCR/secret taramasından geçirilmez; CRC veya kapsamlı PNG doğrulaması iddia edilmez. Görsel kontrol şarttır; bu bütün secret biçimlerini yakalayan bir garanti değildir. Scanner fixture'ları approved PNG, farklı konumdaki PNG, PNG kılığında credential metni ve sonuna credential eklenmiş PNG'yi ayrıca sınar.

### Çalıştırılan kontroller ve cleanup

Komutlar repository kökünde çalıştırıldı. Playwright yalnız repository dışındaki geçici Python dizininde kullanıldı; dependency/lock değişmedi.

| Komut / kontrol | Gerçek sonuç |
| --- | --- |
| `dotnet build src/backend/FullStackOpsLab.Api/FullStackOpsLab.Api.csproj -c Release` | PASS; 0 warning, 0 error |
| `docker compose --env-file .env build api` ve `up -d` | Güncel backend image; altı servis running/healthy |
| `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/Module9.EnvPreflight.ps1` | PASS; `.env` ignored/untracked; external PG volume mevcut |
| `docker compose --env-file .env config -q` | PASS; çözümlenmiş değerler yazdırılmadı |
| `docker compose --env-file .env exec -T prometheus promtool check config /etc/prometheus/prometheus.yml` | SUCCESS; nihai `api:8080/metrics` config aynı |
| `powershell -NoProfile -ExecutionPolicy Bypass -File tests/Module9.Configuration.Smoke.ps1` | 20/20 PASS; negatif exit yanında güvenli stderr ve canary/connection-string yokluğu |
| `powershell -NoProfile -ExecutionPolicy Bypass -File tests/Module9.EnvPreflight.Smoke.ps1` | 19/19 PASS; gerçek env değiştirilmedi |
| `powershell -NoProfile -ExecutionPolicy Bypass -File tests/Module9.SecretLeakage.Smoke.ps1` | 19/19 PASS; dört yeni dar PNG fixture'ı dahil, canary çıktıya sızmadı |
| `python tests/Module10.RequestLogs.Smoke.py` | CRUD/six-field/null/Location, 400/404/500 ve safe logging PASS |
| `python tests/Module10.Dashboard.Smoke.py --traffic-only --screenshots-directory labs/10-prometheus-grafana/images` | 12 panel, gerçek counter eşitliği, plugin/browser/trafik PASS |
| `python tests/Module10.ScrapeTargets.Smoke.py` | Üç ayrı hatalı hedef ve üç doğru hedef recovery PASS |
| `powershell -NoProfile -ExecutionPolicy Bypass -File tests/Module10.Metrics.Smoke.ps1 -EndpointOnly` | Internal `/metrics` HTTP200, histogram/secret kontrolü PASS |
| `powershell -NoProfile -ExecutionPolicy Bypass -File tests/Module10.Prometheus.Smoke.ps1 -EndpointOnly` | Doğru target endpoint PASS |
| `powershell -NoProfile -ExecutionPolicy Bypass -File tests/Module10.Grafana.Smoke.ps1 -EndpointOnly` | Grafana service/health PASS |
| `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/Module9.SecretLeakage.Check.ps1` | Repository text taraması PASS; üç görsel ayrıca kontrol edildi |
| `git diff`, `git diff --check`, `git status --short` | Kapsam incelemesi ve diff check PASS; stage/commit/push yok |
| `docker compose --env-file .env down` | Yalnız görevde başlatılan stack kapatıldı; volume'lar silinmedi |

İlk eksik log/panel/PNG testi beklenen başarısızlığı gösterdi, değişiklikten sonra geçti. Prometheus UI helper'ının ilk metin locator'ı timeout verdi; API/rendered DOM doğrulamasıyla düzeltilip görüntüler başarıyla alındı. Python envanter yardımcısı Windows snapshot encoding'ini okuyamadı; başlangıç/bitiş aynı PowerShell JSON okuyucusuyla karşılaştırılıp PASS doğrulandı. Bunlar başarılı runtime sonucu gibi raporlanmadı veya Docker ayarı değiştirilerek örtülmedi.

Yalnız kendi Task kayıtları temizlendi; başlangıç/bitiş `tasks`, Module 3B `lab_tasks`, `__EFMigrationsHistory` satır sayısı/içerik hash'leri aynı. Test cache key'i EXISTS0; `.env` ve user-secrets hash'leri aynı. Gerçek credential/tam connection string repository text, tüm servis logları ve metrics içinde bulunmadı (karşılaştırma yalnız bellekte, değer göstermeden). Geçici Python araçları/YAML/sonuçlar temizlendi. Başlangıçtaki **12 ilişkisiz container ID/state, 7 network ID, 21 volume adı** aynen korundu; default bridge ID değişmedi. PostgreSQL/Grafana/Prometheus named volume'ları bırakıldı; stack kapalı, prune/volume silme/down-v yok.

Önceki geçerli counter-reset, trafiksiz NaN, Docker unhealthy/readiness ayrımı ve restart/down-up kalıcılık kanıtları yeniden tüm script'lerde tekrarlanmadı. Bu koşuda request logunun 500 doğruluğu için tek PostgreSQL kesintisi yapıldı ve geri getirildi. Thread-pool runtime sınırlaması, küçük örneklem, histogram yaklaşımı, production hardening ve secret scanner sınırlamaları aynı; benchmark, load test, alerting/tracing/merkezi log eklenmedi.

**Öğrenme:** toplam sayı proses ömründeki counter değeridir; rate resetleri dikkate alan olay/s hızıdır. Güvenli request template'i gerçek kullanıcı yolu/query'sinden farklıdır. Response completion final500'ü doğru kaydetmeyi sağlar. Prometheus `up` yalnız scrape başarısını söyler; yanlış DNS/port/path API çalışırken de up0 üretebilir. Provisioning tanımı yeniden yükler, volume geçmiş veriyi korur; bunlar farklı sorumluluklardır.

Şartnameye göre sonraki modül **Module 11 — GitHub Actions CI**. Yalnız öneri: açık talep üzerine mevcut build/smoke/config doğrulamalarını kapsayacak minimum CI planını hazırlamak. Bu görev Module 11'e geçmedi. Önerilen commit mesajı: `fix(observability): close Module 10 acceptance gaps`; commit/push yapılmadı.

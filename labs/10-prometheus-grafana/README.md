# Modül 10 — Docker-native gözlem

Bu bölüm Module 10'un **yalnız ilk küçük adımıdır**. `PROJECT_SPEC.md` önce Docker log/inspect/stats incelemesini, sonra backend metrics instrumentation, Prometheus ve Grafana'yı ister. Sıra ile görev arasında fark yoktur. Şartnamedeki `labs/10-prometheus-grafana/` klasörü kullanılır; klasör adı monitoring bileşenlerinin eklendiği anlamına gelmez.

**Sonuç: 2 Ekim 2026 tarihinde ilk adım PASS. Module 10 bütünü devam ediyor.**

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

## Şimdiki eksikler ve sonraki küçük adım

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

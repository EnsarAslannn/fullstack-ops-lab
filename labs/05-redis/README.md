# Module 5 — Redis Cache: Task listesini cache'leme

## Amaç ve kararlar

`GET /api/tasks` için cache-aside akışı eklendi: önce Redis okunur; **hit** durumunda saklanan Task response DTO listesi döner; **miss** durumunda mevcut `AsNoTracking` PostgreSQL sorgusu çalışır ve sonuç Redis'e yazılır. `GET /api/tasks/{id}` cache'lenmez. PostgreSQL kalıcı veri kaynağıdır; Redis geçici bir kopyadır. Redis verisi kaybolsa bile Task kayıtları PostgreSQL named volume'unda kalır.

`PROJECT_SPEC.md` image tag'ini ve kesin key adını zorunlu kılmıyor. Resmî `redis:8.2.10-alpine` kullanıldı; exact patch tag `latest` kaymasını önler, Alpine tabanı küçük bir laboratuvar image'ı sağlar. `docker pull` digest'i `sha256:b51665e66f00759be7c3152ad5ac3c66fb2f619c13ef62dea7cc1f9914524635` idi. [Resmî Redis image tag'leri](https://hub.docker.com/_/redis/tags) üzerinde bu tag doğrulandı. .NET `net10.0` için [Microsoft.Extensions.Caching.StackExchangeRedis 10.0.12](https://www.nuget.org/packages/Microsoft.Extensions.Caching.StackExchangeRedis/10.0.12) sürümü sabitlendi. İlk `dotnet add package` sırasında NuGet güvenlik veri kaynağına ulaşılamadığı için `NU1900` uyarısı çıktı; paket restore edildi, sonraki açık `dotnet restore` ve Release build uyarısız geçti.

Cache key'i `fullstack-ops:tasks:all:v1`: proje namespace'i, liste türü ve gelecekte değiştirilebilir format sürümünü gösterir. Varsayılan **absolute TTL 60 saniye**; `Cache:TasksTtlSeconds` yapılandırmasından değiştirilebilir ve sıfır/negatif değer reddedilir. Gerçek smoke testinde beklemeyi kısaltmak için yalnızca test API sürecinde `Cache__TasksTtlSeconds=20` kullanıldı. Redis'te `[]` değeri bulunan bir key **hit** sayılır; key'in yokluğu miss'tir. EF entity'leri yerine mevcut API response DTO'ları `System.Text.Json` ile saklanır; görev sırası ID artan olarak kalır.

## Local Redis laboratuvarı ve bağlantı ayarları

Başlangıçta Git çalışma alanında önceki Module 4 dokümantasyonuna ait iki değişiklik vardı; korundu. Docker Engine `29.6.1` idi. Başlangıç envanteri **12 container, 7 network, 19 volume, 27 image**; `fullstack-ops-postgres-data` ve uygulanmış `InitialCreate` migration'ı doğrulandı. `tasks` sayısı `0`, `lab_tasks` satırı `1:Module 3B persistent task` idi.

```powershell
docker pull redis:8.2.10-alpine
docker run -d --name fullstack-ops-redis-lab `
  -p 127.0.0.1:16379:6379 `
  --mount type=tmpfs,destination=/data `
  redis:8.2.10-alpine redis-server --save '' --appendonly no
docker exec fullstack-ops-redis-lab redis-cli PING
docker exec fullstack-ops-redis-lab redis-cli SET fullstack-ops:lab:ttl temporary EX 2
docker exec fullstack-ops-redis-lab redis-cli GET fullstack-ops:lab:ttl
docker exec fullstack-ops-redis-lab redis-cli TTL fullstack-ops:lab:ttl
docker exec fullstack-ops-redis-lab redis-cli DEL fullstack-ops:lab:delete
```

Gerçek sonuçlar: `PING → PONG`, `SET → OK`, `GET → temporary`, `TTL → 2`; üç saniye sonra `EXISTS → 0`. Ayrı silme key'inde `DEL → 1`, sonra `EXISTS → 0`. Resmî Redis image'ının `/data` yolu bu deneyde açık `tmpfs` mount ile kullanıldı; named/anonymous persistence volume'u oluşturulmadı. `--save '' --appendonly no` disk kalıcılığını kapattı. Bu parolasız Redis kurulumu yalnızca localhost'a bağlı local laboratuvar içindir; production güvenlik ayarı olarak önerilmez.

Mevcut PostgreSQL volume'u `fullstack-ops-postgres-cache-lab` container'ında `127.0.0.1:15432:5432` üzerinden geçici yayınlandı. API host'ta `127.0.0.1:15162` adresinde çalıştı. PostgreSQL'in gerçek parolası mevcut .NET user-secrets'ta kaldı. Redis development adresi `ConnectionStrings:Redis` olarak yalnızca user-secrets'a kaydedildi; `.env.example` yalnızca placeholder içerir. Container ortamında eşdeğer anahtar `ConnectionStrings__Redis` olur; container'lar bir Docker ağına bağlandığında hedef bir Redis container/service adı ve `6379` olmalıdır, container içindeki `localhost` değil. Bu görevde backend image'ı yeniden build edilip container bağlantısı test edilmedi; şartname Module 5 için bunu zorunlu kılmıyor. Redis veya PostgreSQL bağlantı dizesi repository'ye yazılmadı.

## Önce başarısız test, sonra uygulama

`tests/Module5.Cache.Smoke.ps1`, temiz Redis key'iyle ilk GET'i çağırıp key'in oluşmasını bekler. Uygulamadan **önce** `GET /api/tasks → 200`, fakat `EXISTS=0` idi; test beklenen `EXISTS=1` koşulunda kırıldı. İlk çalıştırmadaki Docker pipe izin hatası test altyapısıydı; izinli tekrar çalışma gerçek eksik cache davranışını gösterdi. Paket ve minimal API akışı eklendikten sonra aynı test geçti.

Smoke testinin gerçek sonuçları:

| Kontrol | Sonuç |
| --- | --- |
| İlk boş liste GET | `200`, miss, Redis key oluştu, TTL `20` saniye |
| PostgreSQL durdurulmuşken ikinci boş liste GET | `200`, `[]` hit; DB sorgusu gerekmedi |
| Benzersiz Task POST | `201`, doğru `Location`; cache key silindi |
| Tekil Task GET | `200`; liste cache key'i oluşturulmadı |
| POST sonrası ilk/ikinci liste GET | İlk çağrı miss ve güncel görev; ikinci çağrı hit, DTO alanları ve iki tarih değeri aynı |
| Geçersiz POST ve bulunmayan ID PUT/DELETE | `400` / `404` / `404`; mevcut cache key'i korundu |
| Başarılı PUT | `200`, key silindi; sonraki liste güncel açıklama ve `isCompleted=true` döndürdü |
| Başarılı DELETE | `204`, key silindi; sonraki liste `[]` döndürdü |
| Absolute TTL sonu | Redis `EXISTS=0`; sonraki GET `200` ile miss olup key'i yeniden oluşturdu |

Test sırasında PostgreSQL stop/start sonrasındaki ilk bağlantıda Windows Event Log izni ve sonra Npgsql havuzundaki kapanmış bağlantı nedeniyle denemeler başarısız oldu. Yalnızca test API sürecinde `Logging__EventLog__LogLevel__Default=None` ayarlandı; test, yazma öncesi salt okunur GET'in yeniden bağlanmasını bekleyecek şekilde düzeltildi. Bu duraklarda test Task kaydı oluşmadı. Son tam smoke testi geçti.

API loglarında `[CACHE MISS]`, `[CACHE HIT]`, `[CACHE INVALIDATED]` işaretleri görüldü; son incelemede sırasıyla **14**, **4**, **9** satır vardı. Loglarda secret veya Task payload'ı yazdırılmadı. Başarılı Task sorguları DNS/TCP yerine bu local testte PostgreSQL bağlantısı, kimlik doğrulama, SQL ve API JSON sözleşmesini doğruladı. Phase 0A, Phase 0B, Module 3D ve Module 3E mevcut smoke testleri de geçti; `200`, `201` + `Location`, `204`, `400`, `404` sözleşmesi korundu.

## Invalidation, TTL ve Redis kesintisi

POST/PUT/DELETE işlemlerinde cache key'i yalnızca `SaveChangesAsync` başarılı olduktan sonra kaldırılır. Validation `400` ve bulunmayan ID `404` cache'i değiştirmez. PostgreSQL yazması başarılı olup Redis invalidation başarısız olursa API, kalıcı yazmayı başarısızmış gibi raporlamamak için uyarı loglar ve başarılı HTTP yanıtını korur; varsa eski cache değeri TTL bitene kadar **stale data** riski taşır. Bu nedenle TTL sınırlı tutulur. Eşzamanlı miss/yazma yarışları için bu adımda ek koordinasyon eklenmedi.

Redis durdurulmuşken gerçek `GET /api/tasks` **500** döndü; bu sürümde GET için fallback veya retry yoktur. Aynı Redis container'ı yeniden başlatılınca `PING → PONG`, GET **200** ve cache key yeniden oluştu. Bu gözlem gelecekteki resilience kararına girdi sağlar; bu adımda circuit breaker eklenmedi. `/health` hâlâ DB veya Redis readiness testi değildir.

## Doğrulama ve temizlik

`dotnet restore FullStackOpsLab.slnx` ve `dotnet build FullStackOpsLab.slnx -c Release` başarılı; Release build **0 uyarı, 0 hata**. Phase 0A/0B, Module 3D/3E ve yeni Module 5 cache smoke testleri geçti. Son SQL `tasks=0`, `lab_tasks=1:Module 3B persistent task`, migration `20260928113912_InitialCreate` gösterdi. `fullstack-ops:*` test key'leri temizlendi.

Yerel API süreci ve geçici log dosyaları kapatılıp kaldırıldı. Yalnızca `fullstack-ops-redis-lab` ve `fullstack-ops-postgres-cache-lab` container'ları durdurulup kaldırıldı. `fullstack-ops-postgres-data` named volume'u, PostgreSQL ve proje image'ları korundu; Redis image'ı sonraki öğrenme adımları için kalabilir. İlişkisiz Docker kaynağına dokunulmadı. Commit veya push yapılmadı.

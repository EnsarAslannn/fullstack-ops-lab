# Module 3A — PostgreSQL Container Lifecycle ve Anonim Volume

## Amaç ve kapsam

PostgreSQL'i API'ye bağlamadan bağımsız bir container olarak çalıştırıp stop/start ve remove/recreate davranışlarını gözlemlemek. Bu deneyde named volume, bind mount, Compose ve özel Docker network kullanılmadı.

`PROJECT_SPEC.md` ilk deneyi “volume olmadan” tarif eder. Bu image'ın `/var/lib/postgresql` için `VOLUME` tanımı vardır. Dolayısıyla komutta açıkça volume bağlamamak, gerçekte hiç volume oluşmadığı anlamına gelmez: Docker her yeni container için bir **anonim volume** oluşturdu. Buradaki kayıp, eski verinin hemen fiziksel olarak silinmesi değil, yeni container'ın eski anonim volume'u kendiliğinden tekrar bağlamamasıdır.

## Image ve bağlantı

- Resmî image: `postgres:18-alpine`
- Bu deneyde çekilen digest: `postgres@sha256:77f585114c32fbca283dc835b0596f4e52b51b4c6662d7810b2f4084f60a1873`
- Container: `fullstack-ops-postgres-no-volume`
- Port: `127.0.0.1:15432:5432`. Host'taki yalnızca localhost `15432`, container'ın PostgreSQL portu `5432`'ye yönlenir.
- Image'ın `PGDATA` değeri: `/var/lib/postgresql/18/docker`; `VOLUME` yolu: `/var/lib/postgresql`.

`postgres:18-alpine` bir tag'dir ve ileride farklı bir image'a işaret edebilir. Yukarıdaki digest bu deneyde kullanılan image'ı belirler. Image local sistemde bırakıldı.

## Başlatma ve hazırlık

`POSTGRES_USER=fullstackops` ilk açılışta kullanıcıyı, `POSTGRES_DB=fullstackops` veritabanını belirler. `POSTGRES_PASSWORD` ilk açılış için zorunlu lab parolasıdır. Gerçek bir secret kullanılmadı; değer repoya ve bu belgeye yazılmadı. Tek kullanımlık sahte değer repository dışındaki geçici bir env dosyasında tutuldu, iki `docker run` işleminde aynı dosya kullanıldı ve sonunda silindi. Bu ortam değişkenleri mevcut bir veri dizinini yeniden ilklendirmez. Ayrıca Docker erişimi olan kişiler `docker inspect` ile container environment değerlerini görebilir; bu yöntem production secret yönetimi değildir.

Aşağıdaki PowerShell örneği aynı deneyi yeni bir **sahte** parola ile tekrarlar. Komut çıktısına parolayı yazdırmaz:

```powershell
$labEnvPath = Join-Path $env:TEMP ('fullstack-ops-postgres-3a-' + [guid]::NewGuid().ToString('N') + '.env')
$labPassword = 'lab-only-' + [guid]::NewGuid().ToString('N')
@('POSTGRES_USER=fullstackops', 'POSTGRES_DB=fullstackops', ('POSTGRES_PASSWORD=' + $labPassword)) |
  Set-Content -LiteralPath $labEnvPath -Encoding ascii

docker pull postgres:18-alpine
docker image inspect postgres:18-alpine
docker run -d --name fullstack-ops-postgres-no-volume -p 127.0.0.1:15432:5432 --env-file $labEnvPath postgres:18-alpine
docker exec fullstack-ops-postgres-no-volume pg_isready -U fullstackops -d fullstackops
docker logs --tail 12 fullstack-ops-postgres-no-volume
```

`pg_isready` hazır değilse kısa aralıklarla tekrar denenir. Hazır olduğunda `accepting connections` döner. `docker logs` başlangıç ve hazır olma satırlarını gösterir. `psql`, container içindeki PostgreSQL istemcisidir; aşağıdaki komutlar container içinden yerel bağlantı kurar:

```powershell
docker exec fullstack-ops-postgres-no-volume psql -U fullstackops -d fullstackops -v ON_ERROR_STOP=1 -c 'CREATE TABLE lab_tasks (id integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY, title text NOT NULL);'
docker exec fullstack-ops-postgres-no-volume psql -U fullstackops -d fullstackops -v ON_ERROR_STOP=1 -c "INSERT INTO lab_tasks (title) VALUES ('Module 3A test task');"
docker exec fullstack-ops-postgres-no-volume psql -U fullstackops -d fullstackops -v ON_ERROR_STOP=1 -t -A -c 'SELECT id, title FROM lab_tasks ORDER BY id;'
```

## Anonim volume'u tespit etme

`docker image inspect postgres:18-alpine` sonucunda `Config.Volumes` içinde `/var/lib/postgresql` görüldü. `docker inspect fullstack-ops-postgres-no-volume` sonucunda `Mounts` alanındaki `Type=volume`, `Name` ve `Destination=/var/lib/postgresql` değerleri incelendi. Tam `docker inspect` çıktısını paylaşmak parolayı açığa çıkarabilir; yalnızca `Mounts` alanını görüntülemek daha güvenlidir:

```powershell
(docker inspect fullstack-ops-postgres-no-volume | ConvertFrom-Json).Mounts |
  Select-Object Type, Name, Destination, RW
```

| Container | Anonim volume adı | Mount hedefi |
| --- | --- | --- |
| İlk oluşturma | `ba7406c834c78c674038758f166b1ecb7233fc8171e018ac507563740a3b4509` | `/var/lib/postgresql` |
| Yeniden oluşturma | `ea7f584ad2074b9061d7c8e64ede01ba9e94bd8a99a724dcb9d3ed4e230ad5db` | `/var/lib/postgresql` |

Her ikisinin `Type` değeri `volume`, `RW` değeri `True` idi. Volume'lar Docker tarafından otomatik adlandırıldı; bu lab için önceden var olan volume'lardan farklıydılar.

## Stop/start ve remove/recreate sonucu

```powershell
docker stop fullstack-ops-postgres-no-volume
docker start fullstack-ops-postgres-no-volume
docker exec fullstack-ops-postgres-no-volume pg_isready -U fullstackops -d fullstackops
docker exec fullstack-ops-postgres-no-volume psql -U fullstackops -d fullstackops -t -A -c 'SELECT id, title FROM lab_tasks ORDER BY id;'
```

Stop/start aynı container'ı ve ona bağlı anonim volume'u kullandı. `SELECT` sonucu tekrar `1|Module 3A test task` oldu.

İlk `Mounts.Name` değeri kaydedildikten sonra container durdurulup `docker rm` ile kaldırıldı. Eski anonim volume hâlâ `docker volume inspect` ile görülebiliyordu. Aynı isim, port ve environment ile; yine `-v`/`--mount` olmadan yeni container başlatıldı:

```powershell
$oldVolume = ((docker inspect fullstack-ops-postgres-no-volume | ConvertFrom-Json).Mounts |
  Where-Object Destination -eq '/var/lib/postgresql').Name
docker stop fullstack-ops-postgres-no-volume
docker rm fullstack-ops-postgres-no-volume
docker run -d --name fullstack-ops-postgres-no-volume -p 127.0.0.1:15432:5432 --env-file $labEnvPath postgres:18-alpine
docker exec fullstack-ops-postgres-no-volume pg_isready -U fullstackops -d fullstackops
docker exec fullstack-ops-postgres-no-volume psql -U fullstackops -d fullstackops -t -A -c "SELECT CASE WHEN to_regclass('public.lab_tasks') IS NULL THEN 'absent' ELSE 'present' END;"
$newVolume = ((docker inspect fullstack-ops-postgres-no-volume | ConvertFrom-Json).Mounts |
  Where-Object Destination -eq '/var/lib/postgresql').Name
```

Yeni container'ın `Mounts.Name` değeri farklıydı; sorgu `absent` döndürdü. Eski tablo yeni container'da yoktu. Bu sırada ilk volume fiziksel olarak hâlâ mevcuttu, fakat yeni container'a otomatik bağlanmadı.

Anonim volume'u yeniden bağlamak için uzun, otomatik üretilmiş adını ayrıca yönetmek gerekir. Named volume ise önceden seçilen kararlı bir adla tekrar bağlanabilir. Named volume davranışı Module 3B'nin konusudur; bu adımda named volume oluşturulmadı.

## Güvenli temizlik ve gerçek sonuç

Önce container'ın ikinci volume adı `Mounts` üzerinden kaydedildi. Ardından yalnızca bu lab container'ı durdurulup kaldırıldı. İki volume, `docker volume inspect` ile ayrı ayrı doğrulandıktan sonra **tam adlarıyla** silindi. Genel `docker volume prune` veya `docker system prune` kullanılmadı. Aşağıdaki `$oldVolume` ve `$newVolume`, yukarıdaki `Mounts.Name` sorgularıyla elde edilen adlardır; silmeden önce ikisinin de yalnızca bu lab'a ait olduğunu doğrulayın:

```powershell
docker stop fullstack-ops-postgres-no-volume
docker rm fullstack-ops-postgres-no-volume
docker volume inspect $oldVolume $newVolume
docker volume rm $oldVolume $newVolume
Remove-Item -LiteralPath $labEnvPath
```

Bu deneyin sonunda `docker ps -a` içinde lab container'ı yoktu; her iki lab volume'u için `docker volume inspect` başarısız oldu; `postgres:18-alpine` image'ı local sistemde kaldı. Başka Docker kaynaklarına dokunulmadı.

## Öğrenilecek nokta

`docker run` komutunda `-v` olmaması tek başına “veri container writable layer'ında” demek değildir. Önce image'ın `VOLUME` tanımı ve container'ın `Mounts` alanı kontrol edilir. Stop/start aynı mount'u korur. Remove/recreate yeni bir anonim volume üretebilir; eski veri görünmez olur. Eski volume açıkça silinmediği sürece Docker'da kalabilir.

---

# Module 3B — PostgreSQL Named Volume Persistence

## Amaç ve kaynaklar

Module 3A'da yeni container farklı bir anonim volume almıştı. Bu deneyde PostgreSQL veri dizinini kullanıcı tarafından adlandırılmış **aynı volume'a** bağlayıp container kaldırıldıktan sonra kaydın korunmasını doğruladık. Backend ve frontend değiştirilmedi.

| Kaynak | Değer |
| --- | --- |
| Image | `postgres:18-alpine` |
| Local image digest | `postgres@sha256:77f585114c32fbca283dc835b0596f4e52b51b4c6662d7810b2f4084f60a1873` |
| Container | `fullstack-ops-postgres-named-volume` |
| Named volume | `fullstack-ops-postgres-data` |
| Mount hedefi | `/var/lib/postgresql` |
| Port | `127.0.0.1:15432:5432` |
| İlk kurulum | `POSTGRES_USER=fullstackops`, `POSTGRES_DB=fullstackops`, sahte `POSTGRES_PASSWORD` |

Parolanın değeri repository'ye veya bu belgeye yazılmadı. Aynı sahte değer, iki container için repository dışındaki geçici env dosyasından okundu; dosya deney sonunda silindi. Docker erişimi olan kişiler container environment değerlerini görebilir. Bu yöntem production secret yönetimi değildir.

## Volume oluşturma ve ilk container

Başlangıçta Git temizdi, Docker Engine erişilebilirdi, hedef container yoktu, `15432` portu boştu. `docker volume inspect fullstack-ops-postgres-data` beklenen `no such volume` sonucunu verdi. Aynı isimde mevcut bir volume olsaydı deney durdurulacak, içeriğine dokunulmayacaktı.

```powershell
docker volume create fullstack-ops-postgres-data
docker volume inspect fullstack-ops-postgres-data

$labEnvPath = Join-Path $env:TEMP ('fullstack-ops-postgres-3b-' + [guid]::NewGuid().ToString('N') + '.env')
$labPassword = 'lab-only-' + [guid]::NewGuid().ToString('N')
@('POSTGRES_USER=fullstackops', 'POSTGRES_DB=fullstackops', ('POSTGRES_PASSWORD=' + $labPassword)) |
  Set-Content -LiteralPath $labEnvPath -Encoding ascii

docker run -d --name fullstack-ops-postgres-named-volume -p 127.0.0.1:15432:5432 --env-file $labEnvPath --mount type=volume,source=fullstack-ops-postgres-data,target=/var/lib/postgresql postgres:18-alpine
docker exec fullstack-ops-postgres-named-volume pg_isready -U fullstackops -d fullstackops
(docker inspect fullstack-ops-postgres-named-volume | ConvertFrom-Json).Mounts |
  Select-Object Type, Name, Destination, RW
```

`docker volume create` önceden seçilmiş adı oluşturur. `--mount type=volume,source=...,target=...` bu volume'u PostgreSQL veri yoluna bağlar. Image'ın `PGDATA=/var/lib/postgresql/18/docker` değeri mount hedefinin altındadır. Port eşlemesi host üzerinde yalnızca localhost'u yayınlar. `pg_isready` hazır değilse kısa aralıklarla tekrarlanır; deneyde `accepting connections` döndü. Tam `docker inspect` çıktısı parolayı gösterebileceğinden yalnızca `Mounts` alanı paylaşılır.

## Test verisi ve remove/recreate

```powershell
docker exec fullstack-ops-postgres-named-volume psql -U fullstackops -d fullstackops -v ON_ERROR_STOP=1 -c 'CREATE TABLE lab_tasks (id integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY, title text NOT NULL);'
docker exec fullstack-ops-postgres-named-volume psql -U fullstackops -d fullstackops -v ON_ERROR_STOP=1 -c "INSERT INTO lab_tasks (title) VALUES ('Module 3B persistent task');"
docker exec fullstack-ops-postgres-named-volume psql -U fullstackops -d fullstackops -v ON_ERROR_STOP=1 -t -A -c 'SELECT id, title FROM lab_tasks ORDER BY id;'

docker stop fullstack-ops-postgres-named-volume
docker rm fullstack-ops-postgres-named-volume
docker volume inspect fullstack-ops-postgres-data

docker run -d --name fullstack-ops-postgres-named-volume -p 127.0.0.1:15432:5432 --env-file $labEnvPath --mount type=volume,source=fullstack-ops-postgres-data,target=/var/lib/postgresql postgres:18-alpine
docker exec fullstack-ops-postgres-named-volume pg_isready -U fullstackops -d fullstackops
(docker inspect fullstack-ops-postgres-named-volume | ConvertFrom-Json).Mounts |
  Select-Object Type, Name, Destination, RW
docker exec fullstack-ops-postgres-named-volume psql -U fullstackops -d fullstackops -v ON_ERROR_STOP=1 -t -A -c 'SELECT id, title FROM lab_tasks ORDER BY id;'
```

`psql` container içinden yerel bağlantı kurdu. İlk `SELECT` sonucu `1|Module 3B persistent task` idi. İlk container kaldırıldıktan sonra `docker volume inspect` volume'un hâlâ var olduğunu gösterdi. İkinci container'daki gerçek `SELECT` de **`1|Module 3B persistent task`** döndürdü.

| Gözlem | İlk container | Yeniden oluşturulan container |
| --- | --- | --- |
| Container ID | `154d5646ca32dc1009af49ee2284f461eea72229f0d7af8ebbafa93acd5dae3c` | `f0f443382eed0ecbb2bb2aa339384585224595df540d0611ee8630445f04a143` |
| `Mounts.Type` | `volume` | `volume` |
| `Mounts.Name` | `fullstack-ops-postgres-data` | `fullstack-ops-postgres-data` |
| `Mounts.Destination` | `/var/lib/postgresql` | `/var/lib/postgresql` |
| `Mounts.RW` | `True` | `True` |
| Port | `127.0.0.1:15432->5432/tcp` | `127.0.0.1:15432->5432/tcp` |
| `SELECT` | `1|Module 3B persistent task` | `1|Module 3B persistent task` |

Container ID'leri değişti, volume adı ve veri değişmedi. PostgreSQL veri dosyaları container'dan ayrı volume'da kaldı; ikinci container aynı volume'u açıkça bağladı.

## Anonim ve named volume farkı

| Konu | Module 3A: anonim volume | Module 3B: named volume |
| --- | --- | --- |
| Oluşum | Image'ın `VOLUME` tanımıyla Docker otomatik oluşturdu | `docker volume create` ile açıkça oluşturuldu |
| Ad | Docker'ın ürettiği uzun ad | Kullanıcının seçtiği `fullstack-ops-postgres-data` |
| Remove/recreate | Yeni container farklı anonim volume aldı; tablo görünmedi | Yeni container aynı named volume'u bağladı; kayıt kaldı |
| Container kaldırılınca | Eski volume ayrıca silinene kadar durabilir | Bu deneyde açıkça korundu |

Named volume tek başına yedekleme veya mutlak kalıcılık garantisi değildir. Burada veri, yeni container **aynı volume'u aynı veri yoluna bağladığı** için korundu.

## Güvenli cleanup ve son durum

```powershell
docker stop fullstack-ops-postgres-named-volume
docker rm fullstack-ops-postgres-named-volume
docker ps -a --filter name=fullstack-ops-postgres-named-volume
docker volume inspect fullstack-ops-postgres-data
docker image inspect postgres:18-alpine
Remove-Item -LiteralPath $labEnvPath
```

Test container'ı ve geçici env dosyası kaldırıldı. `fullstack-ops-postgres-data` **silinmedi**; sonraki backend persistence çalışması için local sistemde kaldı. `postgres:18-alpine` image'ı da kaldı. İlişkisiz Docker kaynaklarına dokunulmadı; `docker volume prune` ve `docker system prune` kullanılmadı.

---

# Module 3C — Backend Integration Plan

Bu bölüm **uygulama değil, teknik plandır**. `Program.cs`, `Tasks.http`, mevcut smoke testleri, `.gitignore`, `.env.example` ve Module 3 şartnamesi incelendi. Git çalışma alanı temizdi ve `fullstack-ops-postgres-data` volume'u `docker volume inspect` ile bulundu. Bu adımda volume içeriği okunmadı veya değiştirilmedi; PostgreSQL container'ı başlatılmadı.

## Mevcut HTTP sözleşmesi

Minimal API, `Program.cs` içinde `/api/tasks` route grubunu kullanıyor. JSON yanıtları `id`, `title`, `description`, `isCompleted`, `createdAt`, `updatedAt` alanlarını taşır. `id` .NET `int` değeridir; `createdAt` ve `updatedAt` UTC `DateTimeOffset` olarak üretilir. `description` nullable'dır. POST gövdesi `title` ve isteğe bağlı `description`; PUT gövdesi `title`, `description` ve `isCompleted` içerir. PUT'ta `isCompleted` gönderilmezse mevcut `bool` binding davranışı `false` değerini kullanır; `description` gönderilmezse `null` olur.

| İstek | Mevcut davranış |
| --- | --- |
| `GET /api/tasks` | `200`, JSON dizi; başlangıçta `[]` olabilir |
| `GET /api/tasks/{id}` | `200`, tek kayıt; yoksa `404` |
| `POST /api/tasks` | `201`, oluşturulan kayıt ve `/api/tasks/{id}` konumlu `Location` başlığı |
| `PUT /api/tasks/{id}` | `200`, güncellenen kayıt; yoksa `404` |
| `DELETE /api/tasks/{id}` | `204`, boş gövde; yoksa `404` |

POST ve PUT, `title` için `null`, boş veya yalnızca whitespace değerini `400` validation problem olarak reddeder; hata anahtarı `title`, mesajı `Title is required.` olur. Geçerli başlık iki işlemde de `Trim()` ile kaydedilir. Başlık/description için mevcut kodda maksimum uzunluk yoktur; description trim edilmez. POST `isCompleted=false` ve her iki zamanı UTC şimdi olarak atar. PUT `createdAt` değerini korur, `updatedAt` değerini UTC şimdiye taşır. PUT önce başlığı doğruladığı için geçersiz başlıkla birlikte bilinmeyen ID verilirse `400` döner. `{id:int}` route kısıtı da korunmalıdır.

## Mevcut bellek içi davranış ve hedef yapı

`Program.cs` içindeki `List<TaskItem>` ve `nextTaskId` yalnızca API sürecinin belleğinde durur. `tasksLock`, paralel isteklerin listeyi ve ID sayacını aynı anda değiştirerek yarış oluşturmasını önler; liste yanıtında `ToArray()` ile kopya alınır. Süreç yeniden başlayınca liste ve sayaç yeniden oluşturulur; veri kaybolur. PostgreSQL'e geçince ID'yi veritabanı üretir, istek başına scoped `DbContext` kullanılır; bu bellek listesi, sayaç ve lock kalkar. Sırf bu geçiş için repository katmanı eklenmez.

Önerilen küçük dosya yapısı:

- `src/backend/FullStackOpsLab.Api/Data/AppDbContext.cs`: `DbSet<TaskEntity>`, `OnModelCreating` içinde açık tablo/sütun eşlemeleri. Tek entity için ayrı configuration sınıfı gerekmez.
- `src/backend/FullStackOpsLab.Api/Data/TaskEntity.cs`: yalnızca saklanan alanlar. Mevcut API request/response kayıtlarından ayrı tutulur.
- `src/backend/FullStackOpsLab.Api/Program.cs`: `AddDbContext` ve Npgsql kaydı; mevcut route'larda `AppDbContext` ve `CancellationToken` kullanımı. Okumalar `AsNoTracking` ile, işlemler EF Core async metotları ve `SaveChangesAsync` ile yapılır.
- `src/backend/FullStackOpsLab.Api/Migrations/`: initial migration ve model snapshot; migration üretildikten sonra source control'de tutulur.

API modelleriyle veritabanı entity'si aynı tip olmak zorunda değildir. Mevcut `CreateTaskRequest`, `UpdateTaskRequest` ve `TaskItem` JSON biçimi korunur; entity ile `TaskItem` arasında açık mapping yapılır. Böylece EF navigation/tracking ayrıntıları HTTP yanıtına sızmaz. Liste `id` sırasıyla okunarak mevcut ekleme sırasına yakın davranış korunur. POST `Location`, validasyon, 404 ve 204 davranışları aynı kalır. PostgreSQL identity ID'si yeniden başlatmada sıfırlanmaz; bu kalıcılığın beklenen sonucudur.

| `tasks` tablosu | PostgreSQL tipi ve kural | Kaynak |
| --- | --- | --- |
| `id` | `integer`, identity primary key | Mevcut `int Id` |
| `title` | `text NOT NULL` | Başlık zorunlu; mevcut maksimum uzunluk **yok** |
| `description` | `text NULL` | Mevcut nullable description |
| `is_completed` | `boolean NOT NULL`, başlangıç `false` | Mevcut tamamlanma alanı |
| `created_at` | `timestamp with time zone NOT NULL` | UTC oluşturma zamanı |
| `updated_at` | `timestamp with time zone NULL` | UTC güncelleme zamanı; EF temelindeki nullable alanla uyumlu |

Şimdilik `title` için `HasMaxLength` eklenmez: örneğin 200 karakter sınırı, mevcut HTTP sözleşmesini değiştirirdi. İstenirse sonraki ayrı kararda hem API validasyonu hem şema birlikte değişmelidir. PostgreSQL şemasının adı `tasks` seçildi; Module 3B'den kalan iki sütunlu `lab_tasks` deney tablosu ayrı kalır. Initial migration `lab_tasks` tablosunu silmemeli, üzerine yazmamalı veya mevcut kaydı uygulama verisi saymamalıdır. Migration uygulanmadan önce `tasks` ve `__EFMigrationsHistory` tablolarının önceden bulunup bulunmadığı kontrol edilmelidir.

## Paketler, bağlantı ve secret planı

Proje `net10.0` hedefliyor. Uygulama adımında uyumlu **10.x** sürümleri birlikte sabitlenerek `Npgsql.EntityFrameworkCore.PostgreSQL` provider'ı ve design-time için `Microsoft.EntityFrameworkCore.Design` eklenir. `dotnet ef` CLI aracı da aynı ana sürümde kurulur; bu bir NuGet proje paketi değil, ayrı .NET aracıdır. Provider EF Core temel bağımlılıklarını getirir; sırf CLI için `Microsoft.EntityFrameworkCore.Tools` veya ayrı ADO.NET `Npgsql` paketi eklenmez. Kesin patch sürümleri yükleme adımında resmî paket uyumluluğuna göre seçilir. Bu planda hiçbir paket kurulmadı.

`Program.cs`, konfigürasyondan `ConnectionStrings:Postgres` anahtarını okuyup `UseNpgsql` ile scoped context kaydeder. Local host geliştirmesinde bağlantı hedefi `Host=localhost`, `Port=15432` olur. Gelecekte iki container aynı Compose ağına alındığında hedef, PostgreSQL servis adı ve `Port=5432` olur. API container'ındaki `localhost` API container'ının kendisidir; PostgreSQL container'ını göstermez. Bu görevde Compose veya network oluşturulmadı.

Gerçek parola ve tam connection string `appsettings.json` veya `appsettings.Development.json` içine girmez. Local geliştirme için projenin `UserSecretsId` değeri hazırlanıp `dotnet user-secrets` kullanılması önerilir; değer repository dışında tutulur. Container ortamında `ConnectionStrings__Postgres` environment anahtarı kullanılabilir: çift alt çizgi .NET konfigürasyonunda `:` ile aynı hiyerarşiyi belirtir. Environment değeri de Docker erişimi olanlara görünebilir; production ortamında ayrıca uygun secret yönetimi gerekir. `.gitignore` mevcut `.env` ve `.env.*` dosyalarını dışlıyor; `.env.example` ileride yalnızca placeholder ve açıklama içermelidir.

## Silinmiş lab parolası için karar

Module 3B'nin sahte parolası geçici env dosyasıyla birlikte silindi. Initialized volume'a farklı `POSTGRES_PASSWORD` vermek mevcut PostgreSQL rolünün parolasını değiştirmez; bu değişken ilk veri dizini oluşturulurken kullanılır.

| Seçenek | Kazanç | Risk / maliyet |
| --- | --- | --- |
| Volume'u koruyup yetkili yerel PostgreSQL oturumunda `ALTER ROLE` ile yeni development parolası belirlemek | Module 3B kaydı ve kalıcılık deneyi korunur | Rol erişimi doğrulanmalı; yeni değer terminal geçmişine, loglara veya Git'e sızdırılmamalı |
| Yalnızca lab verisi olduğu için volume'u kontrollü yeniden oluşturmak | Temiz bir başlangıç ve yeni ilk kurulum parolası | Var olan test verisi kesin olarak silinir; yanlış volume hedefi ciddi veri kaybı yaratır |

**Tercih:** mevcut named volume'u korumak. Module 3D'de, yalnızca bu volume'a bağlı kontrollü geçici PostgreSQL container'ında yerel yetkili oturum açılabildiği doğrulandıktan sonra interaktif `psql` parola değiştirme akışıyla rol parolası yenilenir; bu, PostgreSQL tarafında `ALTER ROLE` uygular. Değer komut satırına veya belgeye yazılmaz, local API için user-secrets'a aktarılır ve yeni TCP bağlantısıyla sınanır. Yetkili erişim sağlanamazsa volume'u otomatik silmek yerine durup seçenekler yeniden değerlendirilir. **Bu görevde parola ve volume değiştirilmedi.**

## Migration ve doğrulama sırası

1. **Module 3D — Credential ve EF Core temeli:** named volume'u ve mevcut `lab_tasks` şemasını koruma kontrolü; yukarıdaki credential hazırlığı; uyumlu paketler ve araç; `AppDbContext`/entity/eşleme ve konfigürasyon kaydı. Bu alt adımın sonunda Release build ve bağlantı doğrulanır; HTTP CRUD kalıcı depoya henüz geçirilmez.
2. **Module 3E — Migration ve CRUD:** `InitialCreate` migration'ı `Migrations/` içine oluşturulur, üretilen SQL/şema ve `lab_tasks` ile olası çakışmalar incelenir, sonra yerel ortamda geliştirici `dotnet ef database update` çalıştırır. `EnsureCreated` kullanılmaz; migration geçmişini atlayıp sonraki migration'larla uyumsuzluk yaratır. Ardından endpoint'ler async EF işlemlerine ve açık API mapping'ine geçirilir.
3. **Module 3F — Persistence kabul testi:** `dotnet build -c Release`; mevcut health/OpenAPI ve Task CRUD smoke testleri; `200`, `201`, `204`, `400`, `404`, `Location`, trim ve timestamp kontrolleri; API restart sonrasında kayıt; PostgreSQL stop/start sonrasında kayıt; tablo ve migration geçmişi; güvenli test verisi temizliği. Gerekirse mevcut `Phase0B.Tasks.Smoke.ps1` için kalıcı veritabanı varsayımları düzeltilir. Bu script oluşturduğu kaydı zaten siler, ancak hata durumunda kalıntı kontrolü gerekir.

Migration'ı yerel laboratuvarda geliştirici açıkça uygular; API başlangıcında otomatik migration **planlanmaz**. Startup migration kolaylık sağlar, fakat veritabanı hazır değilse API açılışını engelleyebilir, uygulamaya şema değiştirme yetkisi gerektirir ve deployment sırasında SQL incelemesini zorlaştırır. Daha sonraki production aşamasında gözden geçirilmiş SQL script veya migration bundle ayrı bir deployment adımı olabilir. Mevcut `/health` endpoint'i yalnızca mevcut health check kaydını gösterir; PostgreSQL readiness kontrolü yaptığı varsayılmamalıdır.

Özellikle korunacak riskler: API contract değişikliği; secret'ın Git'e girmesi; yanlış volume'un silinmesi; host/container adreslerinin karıştırılması; `lab_tasks` ile migration şema çakışması; PostgreSQL hazır olmadan API bağlantısı. Her uygulama alt adımında önce Git diff, volume adı, konfigürasyon ve beklenen HTTP sonuçları yeniden kontrol edilir.

Resmî başvuru kaynakları: [Npgsql EF Core provider](https://www.npgsql.org/efcore/), [EF CLI ve design paketi](https://learn.microsoft.com/en-us/ef/core/cli/dotnet), [migration uygulama seçenekleri](https://learn.microsoft.com/en-us/ef/core/managing-schemas/migrations/applying), [EnsureCreated sınırları](https://learn.microsoft.com/en-us/ef/core/managing-schemas/ensure-created), [ASP.NET Core user secrets](https://learn.microsoft.com/en-us/aspnet/core/security/app-secrets), [.NET environment key eşlemesi](https://learn.microsoft.com/en-us/aspnet/core/fundamentals/configuration/).

---

# Module 3D — PostgreSQL Credential Preparation and EF Core Foundation

## Yapılan iş ve güvenli parola akışı

`fullstack-ops-postgres-data` named volume'u mevcut haliyle `postgres:18-alpine` image'ına, yalnızca bu deneyin `fullstack-ops-postgres-dev` container'ında `/var/lib/postgresql` yoluna bağlandı. Port `127.0.0.1:15432:5432` idi. `pg_isready` bağlantı kabul edildiğini gösterdi. Başlangıçta `lab_tasks` ve test kaydı vardı; uygulama `tasks` tablosu yoktu.

Volume önceden initialized olduğundan yeni bir `POSTGRES_PASSWORD` environment değeri PostgreSQL rol parolasını **değiştirmez**. Image'ın ilk kurulum adımı yalnızca boş veri dizininde çalışır. Bu nedenle rastgele development parolası PowerShell belleğinde üretildi; `dotnet user-secrets set` komutunun standart girdisi üzerinden yerel secret store'a kaydedildi. Yetkili local socket oturumuna `docker exec -i ... psql` ile standart girdiden `ALTER ROLE` verildi. Parola komut argümanına, terminal çıktısına veya repository dosyasına yazılmadı. Geçici parola/SQL dosyası oluşturulmadı.

Bu deneyin mevcut, initialized volume ile kullandığı güvenli container komutu ve hazır olma kontrolü:

```powershell
docker run -d --name fullstack-ops-postgres-dev -p 127.0.0.1:15432:5432 --mount type=volume,source=fullstack-ops-postgres-data,target=/var/lib/postgresql postgres:18-alpine
docker exec fullstack-ops-postgres-dev pg_isready -U fullstackops -d fullstackops
```

Bu `docker run` komutu boş bir volume'u ilk kez kurmak için örnek değildir: burada mevcut veri dizini kullanıldı. Parola güncelleme komutu, gerçek değerin konsola yazılmasını önlemek için bu belgeye eklenmedi.

Local socket ve container içi `127.0.0.1` bağlantıları bu volume'un `pg_hba.conf` dosyasında `trust` kullanıyor; bunlar parola testi sayılamaz. İlk gerçek doğrulama, container'ın **loopback olmayan IP'sine** TCP üzerinden yapıldı. Bu adres `scram-sha-256` kuralıyla eşleşti. Yeni parola user-secrets'tan belleğe okunup yalnızca test sürecinin `PGPASSWORD` environment değerine aktarıldı; doğru parola ile sorgu `tcp_authenticated` döndürdü. Yanlış parola denemesi reddedildi. Ayrıca geçici bir Npgsql istemcisi, user-secrets'taki değeri yalnızca kendi process environment'ından okuyarak **host `localhost:15432`** üzerinden bağlandı ve `SELECT 1` sorgusunu tamamladı (`HOST_TCP_AUTHENTICATED=True`). Geçici istemci kaynak dosyası silindi. Parola ve tam connection string bu belgeye yazılmadı.

`UserSecretsId` yalnızca yerel secret store kaydının kimliğidir; gerçek secret'ı içermez. ASP.NET Core user-secrets geliştirme sırasında değeri repository dışında tutar, ancak şifreli bir production vault değildir. Dosya sistemine erişebilen aynı kullanıcı değeri okuyabilir. İleride container konfigürasyonunda `ConnectionStrings__Postgres` anahtarı kullanılır; `.env.example` yalnızca placeholder taşır ve gerçek `.env` Git tarafından yok sayılır.

Host'taki API için bağlantı hedefi `localhost:15432` idi. Gelecekte API ve PostgreSQL ayrı container'larda aynı servis ağına alındığında hedef PostgreSQL servis adı ve `5432` olacaktır. API container'ındaki `localhost` PostgreSQL'i değil, API container'ını ifade eder. Bu aşamada Compose veya özel network oluşturulmadı.

## Sürümler ve kod yapısı

| Bileşen | Sabitlenen sürüm | Görevi |
| --- | --- | --- |
| `Npgsql.EntityFrameworkCore.PostgreSQL` | `10.0.3` | EF Core sorgularını PostgreSQL'e bağlayan provider |
| `Microsoft.EntityFrameworkCore.Design` | `10.0.12` | Design-time DbContext keşfi ve ileride migration üretimi; `PrivateAssets=all` ile uygulama tüketicilerine taşınmaz |
| Repository local `dotnet-ef` | `10.0.12` | EF CLI aracı; global kurulum yapılmadı |

Sürümler resmî [Npgsql NuGet](https://www.nuget.org/packages/Npgsql.EntityFrameworkCore.PostgreSQL/10.0.3), [EF Design NuGet](https://www.nuget.org/packages/Microsoft.EntityFrameworkCore.Design/10.0.12) ve [dotnet-ef NuGet](https://www.nuget.org/packages/dotnet-ef/10.0.12) kayıtlarından seçildi. Proje `net10.0` hedefliyor. Design paketinin proje dosyasında `PrivateAssets=all` ve uygun `IncludeAssets` ayarı doğrulandı.

Kurulumda kullanılan, secret içermeyen komutlar:

```powershell
dotnet user-secrets init --project src/backend/FullStackOpsLab.Api/FullStackOpsLab.Api.csproj
dotnet new tool-manifest
dotnet add src/backend/FullStackOpsLab.Api/FullStackOpsLab.Api.csproj package Npgsql.EntityFrameworkCore.PostgreSQL --version 10.0.3
dotnet add src/backend/FullStackOpsLab.Api/FullStackOpsLab.Api.csproj package Microsoft.EntityFrameworkCore.Design --version 10.0.12
dotnet tool install dotnet-ef --local --version 10.0.12
```

Local tool manifest'i repository kökündeki `dotnet-tools.json` dosyasına yazıldı. `UserSecretsId` proje dosyasında, gerçek değer ise yalnızca kullanıcı profilindeki yerel secret store'dadır.

`Data/TaskEntity.cs` ileride saklanacak Task alanlarını taşır. `Id` generated integer, `Title` zorunlu `text`, `Description` nullable `text`, `IsCompleted` boolean, `CreatedAt` UTC ve `UpdatedAt` nullable UTC değeridir. Yeni başlık maksimum uzunluğu eklenmedi. `Data/AppDbContext.cs` bu entity'yi açıkça `tasks` tablosuna ve snake_case sütunlarına eşler; Module 3B'nin `lab_tasks` tablosuna mapping yapmaz. `Program.cs` context'i `AddDbContext`/`UseNpgsql` ile kaydeder ve `ConnectionStrings:Postgres` eksikse değeri göstermeden açık konfigürasyon hatası verir.

API request/response kayıtları ve mevcut in-memory liste, ID sayacı ve lock **yerinde duruyor**. Bu adım yalnızca EF temeli oluşturdu. Endpoint'leri şimdi veritabanına geçirmek, migration henüz yokken `tasks` tablosunu gerektirirdi ve Module 3E sınırını aşardı. API başlangıcında `EnsureCreated`, `EnsureDeleted` veya otomatik migration yok; seed data da eklenmedi.

## Gerçek doğrulama ve cleanup

Repository kökünde `dotnet restore FullStackOpsLab.slnx`, `dotnet build FullStackOpsLab.slnx -c Release --no-restore`, `dotnet tool restore`, `dotnet ef --version` ve `./tests/Module3D.EfFoundation.Smoke.ps1` çalıştırıldı. EF testi önce `AppDbContext` bulunamadığı için başarısız oldu; temel eklendikten sonra design-time keşfi ve model SQL üretimi geçti. `dotnet ef dbcontext script` yalnızca SQL **üretti**, veritabanında tablo veya migration oluşturmadı. Model SQL, `tasks` tablosunu ve beklenen sütunları içerdi; `lab_tasks` oluşturma talimatı içermedi. Release build sonucu **0 uyarı, 0 hata**; local tool sürümü `10.0.12`.

API Development profilinde local user-secrets ile açıldı. `Phase0A.Smoke.ps1` `/health` ve OpenAPI için geçti. `Phase0B.Tasks.Smoke.ps1` GET/POST/PUT/DELETE ile `400` ve `404` senaryolarında geçti. Eksik connection string ile ayrı başlatma denemesi beklenen konfigürasyon hatasıyla durdu. Host `localhost:15432` üzerinden Npgsql authentication ve `SELECT 1` başarılı oldu. PostgreSQL'de gerçek SELECT, `tasks_absent|lab_tasks_present` ve `1|Module 3B persistent task` döndürdü: API işlemleri bu aşamada hâlâ bellek içi.

API süreci ve yalnızca `fullstack-ops-postgres-dev` test container'ı kapatılıp kaldırıldı. `fullstack-ops-postgres-data` named volume'u ve `postgres:18-alpine` image'ı local sistemde kaldı. Parolanın tek kalıcı development kopyası repository dışındaki user-secrets alanındadır; secret değerleri Git diff veya dokümana yazılmadı.

---

# Module 3E — Initial Migration and Persistent Task CRUD

## Migration ve şema

**Migration**, EF Core modelinden üretilen, sürümlenebilir şema değişikliğidir. Repository local `dotnet-ef` aracıyla `InitialCreate` üretildi. Üretilen C# migration ve SQL, uygulanmadan önce incelendi. `Up` yalnızca `tasks` tablosunu oluşturdu; `lab_tasks` için `DROP`, `ALTER` veya `RENAME` yoktu. `Down` yalnızca uygulama `tasks` tablosunu düşürür ve bu deneyde **çalıştırılmadı**.

```powershell
dotnet tool restore
dotnet ef migrations add InitialCreate --project src/backend/FullStackOpsLab.Api/FullStackOpsLab.Api.csproj --startup-project src/backend/FullStackOpsLab.Api/FullStackOpsLab.Api.csproj
dotnet ef migrations script 0 InitialCreate --project src/backend/FullStackOpsLab.Api/FullStackOpsLab.Api.csproj --startup-project src/backend/FullStackOpsLab.Api/FullStackOpsLab.Api.csproj
dotnet ef database update InitialCreate --project src/backend/FullStackOpsLab.Api/FullStackOpsLab.Api.csproj --startup-project src/backend/FullStackOpsLab.Api/FullStackOpsLab.Api.csproj
dotnet ef migrations list --project src/backend/FullStackOpsLab.Api/FullStackOpsLab.Api.csproj --startup-project src/backend/FullStackOpsLab.Api/FullStackOpsLab.Api.csproj
```

`migrations add` dosya üretir; `migrations script` SQL'i gösterir, veritabanına uygulamaz. Yalnızca açık `database update` komutu şemayı değiştirir. `__EFMigrationsHistory`, hangi migration'ların uygulandığını tutar; burada `20260928113912_InitialCreate` kaydı vardır. API başlangıcında otomatik migration veya `EnsureCreated` yoktur. `EnsureCreated`, migration geçmişini atladığı için sonraki sürümlü şema değişiklikleriyle uyumsuz bir başlangıç oluşturabilirdi.

Gerçek SQL şeması: `id integer GENERATED BY DEFAULT AS IDENTITY` primary key; `title text NOT NULL` (maksimum uzunluk yok); `description text NULL`; `is_completed boolean NOT NULL DEFAULT FALSE`; `created_at timestamp with time zone NOT NULL`; `updated_at timestamp with time zone NULL`. PostgreSQL `timestamptz` ile API UTC `DateTimeOffset` değerleri kullanır. `updated_at` veritabanında nullable kalır; mevcut API yeni kayıtta onu `createdAt` ile aynı anda doldurur.

İlk `database update` denemesi Windows Event Log yazma izni yüzünden durdu; şemada değişiklik oluşmadığı kontrol edildi. Yalnızca CLI sürecinde `ASPNETCORE_ENVIRONMENT=Development` ve `Logging__EventLog__LogLevel__Default=None` ayarlanarak komut tekrar çalıştırıldı ve başarılı oldu. İlk kurulumda EF'in henüz bulunmayan `__EFMigrationsHistory` tablosunu sorgulaması hata düzeyinde loglandı, sonra tablo oluşturulup migration uygulandı. Bu log satırı tek başına başarısız güncelleme anlamına gelmez; komutun çıkış kodu ve gerçek tablo durumu kontrol edilmelidir.

## Task API neden ve nasıl değişti?

Eski `List<TaskItem>`, ID sayacı ve lock yalnızca API sürecinin belleğindeydi. `tests/Module3E.Persistence.Smoke.ps1` önce benzersiz bir görevi POST etti, API'yi kapatıp yeniden başlattı ve beklenen **GET 404** sonucuyla kırıldı. Beş endpoint `AppDbContext` üzerinden async EF Core işlemlerine geçirildikten sonra aynı test **GET 200** ile geçti. `AppDbContext`, `AddDbContext` kaydı sayesinde her HTTP isteğinde scoped ömürlüdür; istekler aynı context örneğini eşzamanlı paylaşmaz.

Listeleme ve tekil GET, `AsNoTracking` kullanır: sadece okunacak entity'ler değişiklik takipçisine alınmaz. POST'ta `AddAsync` ve `SaveChangesAsync` veritabanının ürettiği integer ID'yi elde eder. PUT/DELETE önce entity'yi bulur, değiştirir veya siler, ardından `SaveChangesAsync` ile SQL değişikliğini kalıcılaştırır. `CancellationToken`, istek iptalinde async veritabanı işlemlerine iletilir. Veritabanı entity'si doğrudan JSON'a verilmez; mevcut `TaskItem` response kaydına açıkça eşlenir.

HTTP sözleşmesi korundu: GET list/tekil `200`, POST `201` ve `/api/tasks/{id}` `Location`, PUT `200`, DELETE `204`; boş/whitespace başlık `400`, bulunmayan ID `404`. Başlık trim edilir; yeni maksimum uzunluk eklenmedi. `description` nullable, POST `isCompleted=false`; PUT `createdAt` değerini korur ve `updatedAt` değerini UTC olarak yeniler. Önceki davranış gibi PUT başlığı ID sorgusundan önce doğrular: bilinmeyen ID ile geçersiz başlık birlikte verilirse `400`. Response alanları `id`, `title`, `description`, `isCompleted`, `createdAt`, `updatedAt` olarak kaldı. Eski response'daki non-null `updatedAt` davranışı, nullable eski kayıt okunursa `createdAt` değerine dönülerek korunur.

PostgreSQL zaman damgaları mikrosaniye hassasiyetindedir. İlk başarılı veri okumasında oluşturma yanıtındaki yedinci kesir basamağının restart sonrası kaybolduğu testte görüldü. API artık POST ve PUT zamanını kaydetmeden önce mikrosaniyeye hizalar; aynı kaydın ilk yanıtı ile sonradan okunan yanıtı eşleşir.

## Gerçek doğrulama ve cleanup

`dotnet restore FullStackOpsLab.slnx` ve Release build başarılıydı (**0 uyarı, 0 hata**). `tests/Phase0A.Smoke.ps1` health/OpenAPI için; `tests/Phase0B.Tasks.Smoke.ps1` CRUD, validation ve 404 için; `tests/Module3D.EfFoundation.Smoke.ps1` model için; yeni persistence testi API restart için geçti. POST/PUT sonrası aynı ID ve alanlar tekrar okundu. Ayrı deneyde PostgreSQL container'ı stop/start yapıldı, API yeniden başlatıldı ve aynı görev **HTTP 200** döndü; DELETE ile **204** dönerek temizlendi. `tasks` sonunda **0 kayıt** içerdi. `lab_tasks` hâlâ `1|Module 3B persistent task` döndürdü; migration geçmişinde `InitialCreate` vardı.

Veri API sürecinde değil, `fullstack-ops-postgres-data` named volume'una bağlı PostgreSQL dosyalarında tutulduğu için API restart ve veritabanı container stop/start sonrasında korundu. Deneyde `fullstack-ops-postgres-dev` kaldırıldı; named volume ve `postgres:18-alpine` image'ı sonraki adım için bırakıldı. Gerçek parola ve tam connection string yalnızca repository dışındaki user-secrets'ta kaldı; test ve migration dosyalarına yazılmadı.

---

# Module 3F — PostgreSQL Persistence Final Acceptance

## Migration ve temel API kabulü

Git çalışma alanı başlangıçta temizdi. Mevcut `fullstack-ops-postgres-data` volume'u `postgres:18-alpine` image'ına, yalnızca bu deneyin `fullstack-ops-postgres-acceptance` container'ında `/var/lib/postgresql` yoluna bağlandı; host bağlantısı `127.0.0.1:15432:5432` idi. Başlangıçta `lab_tasks`, `tasks` ve `__EFMigrationsHistory` tabloları mevcuttu. `lab_tasks` sorgusu `1|Module 3B persistent task`, `tasks` sayısı `0`, migration geçmişi `20260928113912_InitialCreate` döndürdü.

Repository local `dotnet-ef` sürümü `10.0.12` idi. `dotnet ef migrations list`, `InitialCreate` migration'ını uygulandı olarak gösterdi. `dotnet ef migrations has-pending-model-changes`, model ile snapshot arasında **bekleyen değişiklik yok** sonucunu verdi. `dotnet ef migrations script 0 InitialCreate --idempotent` yalnızca incelendi, uygulanmadı: SQL, `__EFMigrationsHistory` içinde migration kaydı yoksa `tasks` tablosunu oluşturuyor ve geçmiş kaydını ekliyor; `lab_tasks` için komut içermiyor. API başlangıcında `EnsureCreated` veya otomatik `Migrate` çağrısı bulunmuyor.

`dotnet restore FullStackOpsLab.slnx` ve `dotnet build FullStackOpsLab.slnx -c Release --no-restore` geçti: **0 uyarı, 0 hata**. `Phase0A.Smoke.ps1`, `Phase0B.Tasks.Smoke.ps1`, `Module3D.EfFoundation.Smoke.ps1` ve `Module3E.Persistence.Smoke.ps1` geçti. Gerçek HTTP kontrolleri list/tekil GET `200`, POST `201` ve doğru `Location`, PUT `200`, DELETE `204`, geçersiz başlık `400`, eksik kayıt `404` davranışını doğruladı. Yanıt alanları `id`, `title`, `description`, `isCompleted`, `createdAt`, `updatedAt` olarak kaldı.

## API ve PostgreSQL yeniden başlatma

Bu deneye özgü bir görev POST ile oluşturuldu (`id=12`, `201`, `Location=/api/tasks/12`). Altı JSON alanı kaydedildi. API süreci kapatılıp PostgreSQL çalışırken yeniden başlatıldığında GET **200** döndü; ID, başlık, açıklama, tamamlanma durumu ve iki UTC zaman damgası aynıydı. Bu, kaydın API belleğiyle birlikte silinmediğini gösterir.

API kapatıldı; **aynı** `fullstack-ops-postgres-acceptance` container'ına `docker stop` ve `docker start` uygulandı. `pg_isready` yeniden hazır olduğunu gösterdi. `docker inspect`, container ID'sinin ve `volume|fullstack-ops-postgres-data|/var/lib/postgresql` mount'unun aynı kaldığını doğruladı. API yeniden açıldığında görev yine **200** ve aynı alanlarla okundu. Named volume, PostgreSQL veri dosyalarını container lifecycle'ından ayrı tutar; bu deneyde aynı volume bağlantısı korunduğu için veri de korundu.

## Veritabanı erişilemezken davranış ve toparlanma

API açıkken PostgreSQL container'ı kontrollü olarak durduruldu. Varsayılan Windows test sürecinde `GET /api/tasks`, HTTP status göndermeden bağlantıyı kapattı (`curl` HTTP kodu **000**, “Empty reply from server”); aynı sırada `/health` **200 Healthy** döndü. EF CLI'da da görülen Windows Event Log yazma izni sorununun etkisini ayırmak için yalnızca test API sürecinde `Logging__EventLog__LogLevel__Default=None` ayarlandı. Aynı veritabanı kesintisinde GET bu kez **500** döndü. Bu iki gözlem, Event Log izni ile boş yanıt arasındaki ilişkiye işaret eder; uygulama kodu veya HTTP hata sözleşmesi bu görevde değiştirilmedi.

PostgreSQL tekrar başlatılıp `pg_isready` başarılı olduktan sonra **aynı API süreci**, listeyi ve `id=12` görevini **200** ile döndürdü. Kaydın altı alanı değişmemişti. Mevcut `/health` yalnızca kayıtlı temel health check'i çalıştırıyor; PostgreSQL readiness kontrolü içermiyor. Bu nedenle veritabanı kapalıyken de 200 dönebilir ve veritabanı erişimi için tek başına güvence vermez.

## Eşzamanlı ID üretimi ve temizlik

Beş benzersiz başlıkla eşzamanlı POST gönderildi: **5/5 yanıt 201**, ID'ler **13, 14, 15, 16, 17** ve hepsi farklıydı. ID artık uygulama içi sayaçtan değil PostgreSQL identity sütunundan geliyor; eski liste/sayaç lock'u gerekmiyor. Geçici PowerShell temizlik komutunda koleksiyonun yanlış sarmalanması ilk DELETE'i `404` yaptı; gerçek tablo kontrolünde hiçbir görev silinmemişti. Beş kayıt tek tek başlıkları doğrulanarak API üzerinden `204` ile silindi. Ana acceptance görevi de API üzerinden `204` ile silindi ve sonraki GET `404` oldu.

Son `tasks` sayısı **0**. `lab_tasks` hâlâ `1|Module 3B persistent task`, `__EFMigrationsHistory` hâlâ `20260928113912_InitialCreate` döndürdü. Test API süreci ve yalnızca `fullstack-ops-postgres-acceptance` container'ı kaldırıldı. `fullstack-ops-postgres-data` named volume'u ile `postgres:18-alpine` image'ı kaldı. User-secrets repository dışında; gerçek parola veya tam bağlantı değeri dokümantasyona yazılmadı.

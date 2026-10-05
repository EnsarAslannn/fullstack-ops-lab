# Module 4A — User-Defined Bridge Network ve Container DNS

## Amaç ve kapsam

Bu laboratuvarda mevcut ASP.NET Core API ile PostgreSQL, kullanıcı tanımlı bir Docker bridge ağı üzerinde çalıştırıldı. API, veritabanına IP adresi veya host'a açılmış bir PostgreSQL portu yerine `fullstack-ops-postgres-network` container adı ve container içi `5432` portu üzerinden erişti. Backend kodu, Dockerfile'lar ve veritabanı şeması değiştirilmedi. `PROJECT_SPEC.md` içindeki sonraki localhost hata deneyi bu adımın kapsamı dışındadır.

## Temel kavramlar

- **Docker network**, container'ların hangi ağda birbirini görebileceğini belirler. Bu deneyde `fullstack-ops-network-lab` adlı `bridge` network oluşturuldu.
- **Default bridge** Docker'ın varsayılan ağıdır. Bu ağdaki tanı container'ı, kullanıcı tanımlı ağdaki PostgreSQL container adını çözemedi. **User-defined bridge** üzerindeki container adları Docker'ın gömülü DNS hizmetiyle çözümlenir. Tanı container'ı aynı ağa bağlandıktan sonra PostgreSQL ve API adları çözüldü.
- `docker network inspect fullstack-ops-network-lab`, driver, subnet, gateway, bağlı container ve IP bilgilerini gösterir. Bu deneyde driver `bridge`, subnet `172.22.0.0/16`, gateway `172.22.0.1`; PostgreSQL `172.22.0.2`, API `172.22.0.3` idi. Bu IP'ler container yeniden oluşturulduğunda değişebilir; bağlantı ayarına IP yerine container adı yazılır.
- **Container içindeki `localhost`**, o container'ın kendisidir. API container'ındaki `localhost`, PostgreSQL container'ı değildir. Şartnamedeki yanlış `Host=localhost` deneyi sonraki alt adıma bırakılmıştır.
- **Host portu** bilgisayardan container'a erişim için yayınlanır. `127.0.0.1:18080:8080`, host'un yalnızca localhost `18080` portunu API'nin container içi `8080` portuna yönlendirdi. PostgreSQL'in `5432` portu host'a yayınlanmadı; aynı Docker ağındaki API yine de bu container portuna erişti.
- Ağdaki isim çözümleme veya ping, tek başına uygulamanın veritabanı sorgusu yapabildiğini kanıtlamaz. Bu nedenle gerçek Task HTTP istekleri ve PostgreSQL sorguları da çalıştırıldı.
- Aynı user-defined bridge ağına bağlanmayan container bu deneyde PostgreSQL'in container adını çözemedi. Bu, Docker ağ üyeliği ve DNS davranışı gözlemidir; tek başına genel bir güvenlik sınırı garantisi olarak görülmemelidir.

## Deneyde kullanılan komutlar

Komutlar repository kökünden çalıştırıldı. Mevcut `fullstack-ops-postgres-data` named volume'u yeniden oluşturulmadı veya silinmedi.

```powershell
docker network create --driver bridge fullstack-ops-network-lab
docker network inspect fullstack-ops-network-lab

docker run -d --name fullstack-ops-postgres-network `
  --network fullstack-ops-network-lab `
  --mount type=volume,source=fullstack-ops-postgres-data,target=/var/lib/postgresql `
  postgres:18-alpine
docker exec fullstack-ops-postgres-network pg_isready -U fullstackops -d fullstackops

docker build --progress=plain -t fullstack-ops-api:networking src/backend/FullStackOpsLab.Api
docker run -d --name fullstack-ops-api-network `
  --network fullstack-ops-network-lab `
  -p 127.0.0.1:18080:8080 `
  --env-file $temporaryEnvPath `
  -e ASPNETCORE_ENVIRONMENT=Development `
  fullstack-ops-api:networking

docker ps
docker inspect fullstack-ops-postgres-network --format '{{json .HostConfig.PortBindings}}'
docker inspect fullstack-ops-api-network --format '{{json .HostConfig.PortBindings}}'
docker network inspect fullstack-ops-network-lab
docker exec fullstack-ops-api-network getent hosts fullstack-ops-postgres-network
docker image history --no-trunc fullstack-ops-api:networking
```

`docker network create` ağı kurdu; `inspect` yapı ve üyelikleri gösterdi. PostgreSQL `docker run` komutunda `-p` bulunmadığı için host portu açılmadı. `pg_isready` hazır oluşu kontrol etti. `docker build` mevcut iki aşamalı Dockerfile'ı ve backend proje klasörünü build context olarak kullandı; Release publish başarılıydı. API için `-p` yalnızca host `127.0.0.1:18080` erişimini açtı. `Development` ortamı mevcut OpenAPI endpoint'ini etkinleştirdi; otomatik migration uygulanmadı.

`$temporaryEnvPath` repository dışındaki geçici env dosyasının yoludur. `ConnectionStrings__Postgres` değeri yalnızca bu dosyayla verildi. Hedef `Host=fullstack-ops-postgres-network`, `Port=5432`, `Database=fullstackops`, `Username=fullstackops` idi; parola mevcut local user-secrets kaynağından alındı. Parola, tam bağlantı dizesi ve env dosyası repository'ye yazılmadı. Dosya test sonunda silindi. Bu yöntem yalnızca geçici local laboratuvar içindir; production secret yönetimi değildir. `docker inspect` içindeki `Config.Env` değerleri secret içerebildiği için tam çıktı paylaşılmamalıdır.

## Gerçek doğrulama sonuçları

| Kontrol | Gözlenen sonuç |
| --- | --- |
| Başlangıç Git durumu | Temiz (`main...origin/main`) |
| Docker Engine | İstemci ve sunucu `29.6.1` |
| Ağ | `bridge`, `172.22.0.0/16`, gateway `172.22.0.1` |
| Ağ IP'leri | PostgreSQL `172.22.0.2`; API `172.22.0.3` |
| API'den PostgreSQL DNS | `getent hosts` → `172.22.0.2`, çıkış kodu `0` |
| Default bridge'deki tanı container'ından DNS | PostgreSQL adı çözümlenmedi, çıkış kodu `2` |
| Tanı container'ı lab ağına bağlandıktan sonra | PostgreSQL `172.22.0.2`, API `172.22.0.3`; iki DNS komutu da çıkış kodu `0` |
| PostgreSQL hazır oluşu | `pg_isready`: accepting connections |
| PostgreSQL host portu | `docker ps`: yalnızca `5432/tcp`; `docker inspect` port bindings `{}`; host `127.0.0.1:15432` kapalı |
| API host portu | `127.0.0.1:18080->8080/tcp` |
| Backend image build | .NET 10 SDK build stage, başarılı Release publish; ASP.NET 10 runtime final stage |
| Runtime SDK | `dotnet --list-sdks` boş; ASP.NET ve .NET runtime `10.0.12` mevcut |
| Image history | Gerçek parola ve `ConnectionStrings__Postgres` anahtarıyla eşleşme yok |
| `GET /health` | `200`, `Healthy` |
| `GET /openapi/v1.json` | `200`, OpenAPI `3.1.1`, Task path mevcut |
| Task listeleme | `200`; test sonunda yanıt `[]` |
| Task oluşturma | `201`, `Location: /api/tasks/18` |
| Task okuma, güncelleme, silme | Sırasıyla `200`, `200` (`isCompleted=true`), `204` |
| Negatif durumlar | Boş başlık POST `400`; eksik ID GET `404`; silme sonrası GET `404` |
| PostgreSQL veri kontrolü | `tasks` kayıt sayısı `0`; `lab_tasks` kaydı `1:Module 3B persistent task`; migration `20260928113912_InitialCreate` |

Listeleme, oluşturma ve güncelleme istekleri mevcut EF Core koduyla PostgreSQL'e sorgu yazıp okudu. API container'ının bağlantı hedefi Docker DNS adı ve `5432` idi; PostgreSQL host portu kapalıyken bu isteklerin başarıyla sonuçlanması container'lar arası bağlantıyı doğruladı.

## Güvenli temizlik

Yalnızca bu deneyde oluşturulan kaynaklar kaldırıldı:

```powershell
docker stop fullstack-ops-dns-diagnostic
docker rm fullstack-ops-dns-diagnostic
docker stop fullstack-ops-api-network
docker rm fullstack-ops-api-network
docker stop fullstack-ops-postgres-network
docker rm fullstack-ops-postgres-network
docker network rm fullstack-ops-network-lab
```

Resmî PostgreSQL image'ının `VOLUME` tanımı, DNS tanısı için `sleep` ile çalıştırılan container'a da anonim volume ekledi. Son kaynak sayımındaki farkla bu fark edildi. Docker volume olayları, `3ec6ce4e267ab56f188a6a7dc6e3b15fcd7512daad40b1a3d5c6604e853285b2` volume'unun yalnızca `fullstack-ops-dns-diagnostic` container'ına mount edildiğini gösterdi; bağlı container kalmadığı doğrulandıktan sonra yalnızca bu volume açık adıyla `docker volume rm` kullanılarak kaldırıldı.

Repository dışındaki geçici env dosyası da silindi. `fullstack-ops-postgres-data` named volume'u, `postgres:18-alpine` ve `fullstack-ops-api:networking` image'ları yerel sistemde bırakıldı. Başka Docker kaynağına dokunulmadı. Ağı kaldırmadan önce ona bağlı deney container'ları kaldırıldı; `docker network prune` veya `docker system prune` kullanılmadı.

---

# Module 4 — Kritik Hata Senaryosu: Container İçindeki `localhost`

5 Ekim 2026: Bu bölümdeki gerçek deney kanıtı, şartnamenin ayrı klasör/standart başlık gereksinimi için [Troubleshooting 1 — Wrong Localhost](../../troubleshooting/01-wrong-localhost/README.md) belgesinde yeniden kullanıldı. İlk Docker Engine engeli kalktıktan sonra yalnız güncel Compose doğrulaması tamamlandı: PostgreSQL hazırken geçici `localhost:5432` hedefinde live200/ready503/tekil GET500 ve API running/unhealthy; aynı image ile doğru `postgres:5432` hedefi geri yüklenince ready200/GET404/healthy ölçüldü. Yeni belge eski ve güncel sonuçları ayırır; aşağıdaki geçmiş CRUD deneyi yeniden çalıştırılmadı. Veri/cache/secret kaynakları ve eski Docker envanteri korundu.

`PROJECT_SPEC.md` bu alt adımı **Kritik Hata Senaryosu** olarak adlandırır; şartnamede `Module 4B` etiketi yoktur. Amaç, API'nin aynı Docker ağındaki PostgreSQL'e neden `localhost` ile erişemediğini gerçek hata ve düzeltme sonuçlarıyla görmektir. Uygulama kodu, Dockerfile, image, migration ve şema değişmedi.

## Kurulum ve güvenli bağlantı bilgisi

Deney için `fullstack-ops-network-localhost-lab` adlı user-defined `bridge` ağı oluşturuldu. `fullstack-ops-postgres-localhost-lab`, mevcut `fullstack-ops-postgres-data` named volume'u `/var/lib/postgresql` hedefine bağlayarak ve **host portu yayınlamadan** başlatıldı. `pg_isready` hazır olduğunu gösterdi. Başlangıçta `tasks` sayısı `0`, `lab_tasks` satırı `1:Module 3B persistent task`, migration kaydı `20260928113912_InitialCreate` idi.

Parola mevcut local user-secrets kaynağından alındı. Yanlış ve doğru bağlantı için iki ayrı, repository dışı geçici env dosyası sırayla oluşturuldu. İki dosyada da `Database=fullstackops`, `Username=fullstackops`, `Port=5432` ve parola aynıydı; **yalnızca Host değişti**. Değer `ConnectionStrings__Postgres` anahtarıyla container'a verildi. Dosyalar ve gerçek bağlantı dizesi repository'ye, image build argümanına veya image layer'ına yazılmadı. Yanlış env dosyası doğru deneye geçmeden, doğru env dosyası da deney sonunda silindi. Bu yöntem yalnızca local laboratuvar içindir; production secret yönetimi değildir. `docker inspect` içindeki `Config.Env` alanı gerçek secret içerebilir, bu nedenle tam çıktısı paylaşılmamalıdır.

Önemli komutlar (env dosyası değişkenleri repository dışındaki geçici yolları temsil eder):

```powershell
docker network create --driver bridge fullstack-ops-network-localhost-lab
docker run -d --name fullstack-ops-postgres-localhost-lab `
  --network fullstack-ops-network-localhost-lab `
  --mount type=volume,source=fullstack-ops-postgres-data,target=/var/lib/postgresql `
  postgres:18-alpine
docker exec fullstack-ops-postgres-localhost-lab pg_isready -U fullstackops -d fullstackops

docker run -d --name fullstack-ops-api-localhost-lab `
  --network fullstack-ops-network-localhost-lab `
  -p 127.0.0.1:18080:8080 `
  --env-file $wrongEnvPath `
  -e ASPNETCORE_ENVIRONMENT=Development `
  fullstack-ops-api:networking

curl.exe --silent --show-error --output NUL --write-out '%{http_code}' http://127.0.0.1:18080/health
curl.exe --silent --show-error --output NUL --write-out '%{http_code}' http://127.0.0.1:18080/api/tasks
docker exec fullstack-ops-postgres-localhost-lab pg_isready -U fullstackops -d fullstackops
docker stop fullstack-ops-api-localhost-lab
docker rm fullstack-ops-api-localhost-lab

# $wrongEnvPath silinip yalnızca Host düzeltilmiş $correctEnvPath hazırlanır.
docker run -d --name fullstack-ops-api-localhost-lab `
  --network fullstack-ops-network-localhost-lab `
  -p 127.0.0.1:18080:8080 `
  --env-file $correctEnvPath `
  -e ASPNETCORE_ENVIRONMENT=Development `
  fullstack-ops-api:networking
docker network inspect fullstack-ops-network-localhost-lab
docker exec fullstack-ops-api-localhost-lab getent hosts fullstack-ops-postgres-localhost-lab
```

## Yanlış hedef ve düzeltme

| Yapılandırma | Backend'in bağlanmaya çalıştığı yer | Gerçek sonuç |
| --- | --- | --- |
| `Host=localhost;Port=5432` | Backend container'ının kendi loopback adresi | API çalıştı; `/health` **200**, `GET /api/tasks` **500**. Loglarda `localhost:5432`, `127.0.0.1:5432` ve `Connection refused` görüldü. PostgreSQL aynı anda `pg_isready` ile hazırdı. |
| `Host=fullstack-ops-postgres-localhost-lab;Port=5432` | Aynı user-defined ağdaki PostgreSQL container'ı | DNS adı `172.22.0.2` adresine çözüldü; `GET /api/tasks` **200** ve veri işlemleri başarılı. |

Yanlış deneyde backend container'ı `running` durumundaydı ve `8080` portunu dinliyordu. `/health` mevcut temel health check'i çalıştırır; veritabanı readiness kontrolü içermez. Bu yüzden yanlış veritabanı hedefiyle bile `200 Healthy` döndü. Veri endpoint'i EF Core üzerinden gerçek sorgu denediğinde bağlantı reddedildi. PostgreSQL'in aynı anda hazır olması, problemin veritabanının kapalı olması değil yanlış hedef olduğunu gösterdi.

Doğru deneyde `docker network inspect`, PostgreSQL (`172.22.0.2`) ve API (`172.22.0.3`) container'larının aynı ağda olduğunu gösterdi. `getent hosts fullstack-ops-postgres-localhost-lab` backend içinden başarıyla çalıştı. Bu IP'ler dinamik olabilir; bağlantı ayarında IP yerine Docker DNS adı kullanılır.

Host makinedeki `localhost` host'un kendisini; backend container'ındaki `localhost` backend'i; PostgreSQL container'ındaki `localhost` PostgreSQL'i gösterir. Container'lar birbirinin loopback adresini paylaşmaz. Host `127.0.0.1:18080`, API container'ının `8080` portuna yönlendirildi. PostgreSQL container içindeki `5432` portundan aynı ağdaki API'ye erişilebildi; `docker inspect` port bindings `{}`, `docker ps` yalnızca `5432/tcp` gösterdi ve host `127.0.0.1:15432` kapalı kaldı. Ortak ağ, container DNS adının çözülmesini ve container'lar arası doğrudan erişimi sağladı.

## Gerçek HTTP ve veri sonuçları

- Yanlış hedef: `/health` **200**, `GET /api/tasks` **500**; loglarda `Connection refused` ve backend loopback adresindeki `5432` hedefi.
- Doğru hedef: `/health` **200 Healthy**, `/openapi/v1.json` **200** (OpenAPI `3.1.1`), görev listesi **200** ve `[]`.
- Benzersiz test görevi POST ile **201** oluşturuldu; `Location: /api/tasks/19`. Tekil GET **200**, `isCompleted=true` yapan PUT **200**, DELETE **204**, silme sonrası GET **404** döndü.
- Boş başlık POST **400**, bulunmayan ID GET **404** döndü. Son liste yine `[]`, PostgreSQL `tasks` sayısı `0` idi.
- `lab_tasks` satırı ve `InitialCreate` migration kaydı değişmedi. Yanlış ve doğru container'ların image ID'si aynıydı: `sha256:9b7e1e6257436f0465245b00d78f5614fc15f9af71058e51fdaca9a547991b26`. Düzeltme kod veya image değişikliğiyle değil, yalnızca bağlantı hedefiyle sağlandı.

## Temizlik

Test görevi API üzerinden silindi. Backend ve PostgreSQL test container'ları durdurulup kaldırıldı; ardından yalnızca `fullstack-ops-network-localhost-lab` ağı kaldırıldı. İki geçici env dosyası silindi. Deney öncesi ve sonrası container, network ve volume sayıları karşılaştırıldı. `fullstack-ops-postgres-data` named volume'u, `postgres:18-alpine` ve `fullstack-ops-api:networking` image'ları korundu. Başka Docker kaynağına dokunulmadı; prune kullanılmadı.

---

# Module 4 — DNS ve Teşhis Araçları

`PROJECT_SPEC.md` bu bölüme numara vermez. Amaç, bağlantı arızasını **container durumu → ağ üyeliği → DNS → TCP → PostgreSQL readiness → kimlik doğrulama/SQL → API** sırasıyla ayırmaktır. API veya PostgreSQL runtime image'ına araç eklenmedi. Küçük resmî `busybox:1.37.0` image'ı yalnızca geçici `fullstack-ops-net-diagnostics` container'ında `nslookup`, `nc`, `wget` ve dosya incelemesi için kullanıldı. Production image'ını küçük tutmak, yalnızca çalışması için gereken içeriği taşımak açısından yararlıdır. PostgreSQL'e özgü `pg_isready` zaten mevcut PostgreSQL container'ında çalıştırıldı; ikinci bir PostgreSQL tanı container'ı ve anonim volume oluşturulmadı.

## Kurulum, image incelemesi ve gizli bilgi

Başlangıç Git çalışma alanı temizdi. Docker Engine istemci/sunucu sürümü `29.6.1`; envanter **12 container, 7 network, 19 volume, 27 image** idi. `fullstack-ops-postgres-data` named volume'u ve `postgres:18-alpine` ile `fullstack-ops-api:networking` image'ları mevcuttu. Seçilen adlar ve host `18080` portu boştu.

Önceki `docker image inspect` gözlemi yeniden üretildi: `docker image ls --no-trunc`, `fullstack-ops-api:networking` tag'ini ve tam `sha256:9b7e1e6257436f0465245b00d78f5614fc15f9af71058e51fdaca9a547991b26` ID'sini gösterdi. Tag'in PowerShell karakter kodları normal ASCII idi; gizli karakter veya eski değişken saptanmadı. Buna rağmen `docker image inspect --format '{{.Id}}' fullstack-ops-api:networking` **1** (`No such image`), tam ve benzersiz kısa ID ile inspect **0**, `docker.io/library/fullstack-ops-api:networking` ile inspect **0** döndü. Çıplak tag ile `docker run` da başarılıydı. Anomalinin kesin nedeni belirlenmedi; image silinmedi, yeniden tag'lenmedi veya build edilmedi.

`fullstack-ops-network-diagnostics` user-defined bridge oluşturuldu. PostgreSQL mevcut named volume'u `/var/lib/postgresql` hedefine bağlayıp **host portu olmadan** çalıştırıldı. API aynı ağa bağlandı; yalnızca `127.0.0.1:18080:8080` yayınlandı. Bağlantı hedefi `Host=fullstack-ops-postgres-diagnostics`, `Port=5432`, `Database=fullstackops`, `Username=fullstackops` idi. Gerçek parola local user-secrets'tan alınarak repository dışındaki geçici env dosyasında `ConnectionStrings__Postgres` anahtarıyla verildi. Parola ve tam bağlantı dizesi bu belgeye, terminal çıktısına veya image'a konmadı. Env dosyası deney sonunda silindi; bu local yöntem production secret yönetimi değildir.

## DNS ve network kapsamı

`docker network inspect fullstack-ops-network-diagnostics`: driver `bridge`, subnet `172.22.0.0/16`, gateway `172.22.0.1`; PostgreSQL `172.22.0.2`, API `172.22.0.3`, tanı container'ı `172.22.0.4`. IP'ler yeniden oluşturma sırasında değişebilir; uygulama ayarında IP yerine Docker DNS adı kullanılır.

Tanı container'ındaki `/etc/resolv.conf` `nameserver 127.0.0.11` ve `options ndots:0` gösterdi. Bu, user-defined ağdaki Docker embedded DNS adresidir. Gerçek sorgular:

| `nslookup` hedefi | Sonuç | Çıkış kodu |
| --- | --- | ---: |
| `fullstack-ops-postgres-diagnostics` | `172.22.0.2`; network inspect ile aynı | 0 |
| `fullstack-ops-api-diagnostics` | `172.22.0.3`; network inspect ile aynı | 0 |
| `fullstack-ops-no-such-container` | `NXDOMAIN` | 1 |
| Tanı container'ı lab ağından ayrıldıktan sonra iki gerçek ad | İkisi de `SERVFAIL`; adlar artık erişilebilir değildi | 1 / 1 |

Şartnamenin Module 4 bölümünde network alias yer almadığı için alias eklenmedi. Bir alias kullanılsaydı yalnızca eklendiği ağ kapsamında anlamlı olurdu; sonraki Compose service name yaklaşımı da aynı ağ içi isim çözümleme fikrini kullanır. Bu deneyde alias sonucu ölçülmedi.

## DNS, TCP, readiness ve uygulama farkı

Tanı araçları ve gerçek komut örnekleri:

```powershell
docker ps
docker inspect fullstack-ops-postgres-diagnostics --format '{{.State.Status}}|{{json .HostConfig.PortBindings}}'
docker network inspect fullstack-ops-network-diagnostics
docker exec fullstack-ops-net-diagnostics cat /etc/resolv.conf
docker exec fullstack-ops-net-diagnostics nslookup fullstack-ops-postgres-diagnostics
docker exec fullstack-ops-net-diagnostics nc -z -w 2 fullstack-ops-postgres-diagnostics 5432
docker exec fullstack-ops-net-diagnostics nc -z -w 2 fullstack-ops-postgres-diagnostics 5433
docker exec fullstack-ops-postgres-diagnostics pg_isready -h fullstack-ops-postgres-diagnostics -p 5432 -U fullstackops -d fullstackops -t 2
docker exec fullstack-ops-postgres-diagnostics pg_isready -h fullstack-ops-no-such-container -p 5432 -U fullstackops -d fullstackops -t 2
docker exec fullstack-ops-postgres-diagnostics pg_isready -h fullstack-ops-postgres-diagnostics -p 5433 -U fullstackops -d fullstackops -t 2
docker exec fullstack-ops-net-diagnostics wget -q -O - http://fullstack-ops-api-diagnostics:8080/health
docker port fullstack-ops-api-diagnostics
docker port fullstack-ops-postgres-diagnostics
docker logs fullstack-ops-api-diagnostics
```

`docker logs` ve tam `docker inspect` çıktıları yayınlanmadan önce secret açısından gözden geçirilmelidir; özellikle `Config.Env` gerçek bağlantı değerini içerebilir. Bu laboratuvarda yalnızca gerekli log bulguları ve güvenli inspect alanları raporlandı.

| Katman ve hedef | Gerçek sonuç | Çıkış kodu |
| --- | --- | ---: |
| DNS: PostgreSQL adı | `172.22.0.2` olarak çözüldü | 0 |
| TCP: aynı ad, port `5432` | `nc -z -w 2` başarılı | 0 |
| TCP: aynı ad, kapalı port `5433` | `nc -z -w 2` başarısız; DNS hâlâ doğru | 1 |
| PostgreSQL readiness: doğru ad/port | `accepting connections` | 0 |
| PostgreSQL readiness: var olmayan ad | `no response` | 2 |
| PostgreSQL readiness: doğru ad, yanlış port `5433` | `no response` | 2 |
| BusyBox → API `fullstack-ops-api-diagnostics:8080/health` | `Healthy` | 0 |

`nc` açık TCP portunu gösterir; PostgreSQL protokolünü, parolayı veya SQL yetkisini kanıtlamaz. `pg_isready` servis hazır oluşunu gösterir; doğru parolayı ve SQL yetkisini tek başına kanıtlamaz. Ping ve DNS de yalnızca kendi katmanlarını gösterir. Container'ın `running` olması veya `/health` yanıtının **200** olması bu projede veritabanı readiness kanıtı değildir. API'nin başarılı Task sorgusu; DNS, TCP, PostgreSQL hazırlığı, kimlik doğrulama, SQL yürütümü ve API eşlemesini birlikte sınar.

## HTTP ve veri doğrulaması

Host üzerinden `/health` **200**, `/openapi/v1.json` **200**, `GET /api/tasks` **200** döndü. BusyBox aynı ağa bağlıyken API'ye host portu `18080` yerine container portu **8080** üzerinden ulaştı. Benzersiz test görevi POST ile **201** oluşturuldu (`Location: /api/tasks/20`), GET **200**, DELETE **204**, silme sonrası GET **404** döndü. Liste başta ve sonda `[]`; PostgreSQL `tasks` sayısı başta ve sonda **0** idi. `lab_tasks` satırı `1:Module 3B persistent task`, migration kaydı `20260928113912_InitialCreate` olarak korundu. API başlangıç logunda `8080` dinleme bilgisi vardı; bağlantı hatası görülmedi.

`docker port` API için `8080/tcp -> 127.0.0.1:18080` gösterdi; PostgreSQL için host mapping döndürmedi. PostgreSQL `PortBindings={}` ve `docker ps` yalnızca `5432/tcp` gösterdi. Bu Docker ağı içi erişim için PostgreSQL host portunun gerekli olmadığını gösterir.

## Teşhis karar sırası ve temizlik

1. `docker ps` ve güvenli alanlara sınırlanmış `docker inspect`: container çalışıyor mu?
2. `docker network inspect`: iki container aynı network'te mi?
3. `docker exec ... nslookup`: ad doğru IP'ye çözülüyor mu?
4. `docker exec ... nc -z -w 2`: beklenen TCP portu açık mı?
5. `docker exec ... pg_isready -t 2`: PostgreSQL protokolü hazır mı?
6. `psql` veya gerçek `GET /api/tasks`: kimlik doğrulama ve SQL çalışıyor mu?
7. `docker logs`: uygulama hangi hatayı kaydediyor? Secret olabilecek satırları paylaşmadan önce ayır.
8. `docker port` ve `docker inspect` port bindings: host portu gerçekten gerekiyor mu? API için evet, host'tan erişim istendi; PostgreSQL için hayır.

Test kaydı silindi. Tanı, API ve PostgreSQL container'ları; lab network'ü ve geçici env dosyası kaldırıldı. BusyBox image'ı bu deneyde ilk kez çekilmişti; test sonunda yalnızca bu tag kaldırıldı. Son envanter tekrar **12 container, 7 network, 19 volume, 27 image** idi. `fullstack-ops-postgres-data`, `postgres:18-alpine` ve `fullstack-ops-api:networking` korundu. Başka Docker kaynağına dokunulmadı; prune kullanılmadı.

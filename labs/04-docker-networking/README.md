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

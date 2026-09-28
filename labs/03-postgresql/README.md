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

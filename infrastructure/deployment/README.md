# Deployment Lab — image seçimi ve statik Compose hazırlığı

14 Ekim 2026: statik hazırlık, rehberli VM aktarımı/env/digest pull, PostgreSQL
volume/readiness/TCP authentication, InitialCreate SQL uygulama/idempotent tekrar,
altı servisli image-only stack başlangıcı ve Windows SSH/tarayıcı erişimi **PASS**.
Tam deployment runtime/contract/cache/monitoring kabulü, HTTPS ve yedekleme henüz
**NOT VERIFIED**. Bu bir production
deployment veya internet erişimi kabulü değildir.

## Amaç ve dosyalar

[Deployment planının](../../docs/deployment-plan.md) ikinci küçük adımıdır.
Mevcut altı servis `frontend`, `api`, `postgres`, `redis`, `prometheus`, `grafana`
korunur. Nginx frontend image'ının içinde kalır.

- [compose.deploy.yaml](compose.deploy.yaml): kök [Compose](../../compose.yaml)
  üzerine uygulanır; tek başına kullanılmaz.
- [.env.example](.env.example): yalnız placeholder; kullanılabilir credential yok.
- [release.json](release.json): kaynak SHA, run ve iki immutable image kimliği.
- [Statik test](../../tests/Deployment.Configuration.Test.py): gerçek Compose
  parser'ını kullanır; Engine, registry pull, .env veya user-secrets gerekmez.

API/frontend için `build: !reset null` kaynak build alanını siler. Sadece `image`
eklemek build alanını kaldırmaz. `ports: !override` eski ve yeni port listelerinin
birleşmesini engeller. Bu YAML etiketleri için Compose **2.24.4 veya sonrası**
gerekir. Windows CLI 5.3.0 ile birleşim doğrulandı; kullanıcı VM'de 5.6.0 kurulumunu
doğruladı; VM'de gerçek env ile parse/model ve image-only başlangıç/kimlik kontrolleri de PASS. Tam runtime kabulü henüz yapılmadı.
[Docker merge belgesi](https://docs.docker.com/reference/compose-file/merge/).

## Seçilen yayın ve gerçek registry kanıtı

Kaynak: `1b52633776279b1661a7cac53392d385cbf10444`.
[Run 38239884132](https://github.com/EnsarAslannn/fullstack-ops-lab/actions/runs/38239884132)
12 Ekim 2026 tarihinde main push için tamamlandı. 13 Ekim'de run ve üç CI gate'i,
[API publish job](https://github.com/EnsarAslannn/fullstack-ops-lab/actions/runs/38239884132/job/114783166985)
ile [frontend publish job](https://github.com/EnsarAslannn/fullstack-ops-lab/actions/runs/38239884132/job/114783167245)
`success` olarak salt okunur sorgulandı. Başlangıç yerel HEAD bu SHA ile aynıydı.

| Bileşen | Seçilen immutable referans |
| --- | --- |
| API | `ghcr.io/ensaraslannn/fullstack-ops-lab-api@sha256:2ccb0ecce9dc7cbe9da418b4f0a952b8122be336299fd3b888539b5d07a05afd` |
| Frontend | `ghcr.io/ensaraslannn/fullstack-ops-lab-frontend@sha256:e0c77449225c4cd602e8f3b2af43a68ca3ad1578ce6428ba8ddcccf1fa612627` |

Digest'ler eski rapordan alınmadı; bu iki job'ın yayın loglarından çıkarıldı.
GHCR registry HTTP API'sinden anonim manifest/config okumaları yapıldı:
manifest yanıtının SHA256'sı ve `Docker-Content-Digest` seçilen digest ile eşleşti;
config blob SHA256'sı kontrol edildi; iki image'ın
`org.opencontainers.image.revision` değeri kaynak SHA ile aynı ve platform
`linux/amd64`. Config digest'leri release.json içinde kayıtlıdır; bunlar manifest
digest'iyle aynı kavram değildir. Registry erişim token'ı yalnız bellekte kullanıldı,
dosyaya/çıktıya yazılmadı; GitHub PAT veya development credential kullanılmadı.

Bu metadata erişimi bugün anonim okunabilirliği gösterir; package visibility
ayarının API'den incelendiği anlamına gelmez. Sonraki rehberli VM digest pull PASS;
tam runtime kabulü hâlâ bekliyor.
Önceki [registry runtime kabulü](../../labs/11-github-actions/README.md)
farklı SHA/digest çiftine aittir. Bu yeni image'lara otomatik runtime PASS verilmez.
Base image tag'leri mutable ve iki bileşen yayını atomik değildir; bu dosya yalnız
doğrulanmış uygulama image çiftini digest ile sabitler. Diğer dört servis image'ı
kök Compose'dan aynen alınır; tüm dependency image'ları digest ile sabitlenmiş değildir.

Windows PowerShell'de çalıştırılan salt okunur GitHub komutları:

```powershell
gh run list --repo EnsarAslannn/fullstack-ops-lab --workflow ci.yml --limit 6 --json databaseId,headSha,status,conclusion,url,event
gh run view 38239884132 --repo EnsarAslannn/fullstack-ops-lab --json headSha,headBranch,event,conclusion,url,jobs
```

İlki başarılı güncel yayını seçer; ikincisi source/event/job sonuçlarını gösterir.
Publishing logları bellekte yakalanıp yalnız image digest biçimine uyan değerler
çıkarıldı; bütün loglar terminale basılmadı. GHCR manifest/config checksum ve
revision kontrolü Python standart kütüphanesi ile yalnız HTTPS üzerinden yapıldı;
Docker Engine'e image veya başka kaynak eklenmedi.

## İzolasyon, portlar ve volume'lar

Compose project adı: **fullstackops-deploy-lab**. Başka project adına çevirmeden
bu laboratuvarın ayrılmış dosya/kaynak hedefleriyle kullan.

| Kaynak | Deployment hedefi | Davranış |
| --- | --- | --- |
| Ağ | `fullstackops-deploy-lab_app` | Compose-managed; VM Engine'inde ayrı |
| PostgreSQL | `fullstackops-deploy-lab-postgres` | External; VM'de oluşturuldu, yalnız PostgreSQL kullanıyor |
| Prometheus | `fullstackops-deploy-lab-prometheus` | Compose-managed; 7 gün / 256MB retention miras alınır |
| Grafana | `fullstackops-deploy-lab-grafana` | Compose-managed; datasource/dashboard provisioning read-only |

Development `fullstack-ops-postgres-data` volume'u kullanılmaz. İlk statik görevde volume'lar
oluşturulmadı; sonraki VM adımında yalnız deployment PostgreSQL volume'u oluşturuldu.
Gelecekte aynı isim mevcutsa içeriği/sahipliği incelenmeden kullanma
veya silme. Redis mevcut davranışla tmpfs kullanır, kalıcı veri kaynağı değildir.

| Servis | VM host bind | Container port |
| --- | --- | --- |
| frontend | `127.0.0.1:18081` | 80 |
| prometheus | `127.0.0.1:19090` | 9090 |
| grafana | `127.0.0.1:13000` | 3000 |
| api / postgres / redis | Yayın yok | 8080 / 5432 / 6379, yalnız app ağı |

Bu adreslerdeki localhost **VM'nin kendisidir**, Windows bilgisayar değildir.
Windows'tan tarayıcı erişimi aşağıdaki kayıtla doğrulandı: yalnız Windows loopback
28081/29090/23000 SSH tünelleri bu VM portlarına gider. VM hazırlığında üç portun
boş olduğu doğrulandı; güncel altı servisin gerçek port bind kontrolü PASS. Internal servis
DNS adları `api`, `postgres`, `redis`, `prometheus` ve mevcut portları değişmez.

Monitoring bind mount yolları ilk `-f compose.yaml` dosyasına göre çözülür;
`monitoring/` ağacı VM'de kök Compose'un yanında bulunmalıdır.

## Statik doğrulama — şimdi çalıştırılabilir

**Windows PowerShell**, repository kökünde:

```powershell
py -3 tests/Deployment.Configuration.Test.py
if ($LASTEXITCODE -ne 0) { throw 'Deployment static validation failed' }
```

Test yalnız kendi temporary fixture env dosyasına çalışma anında sahte değerler
yazar, process'teki aynı Compose anahtarlarını temizler ve gerçek env'i okumaz.
Hem `config -q` hem `config --format json` gerçek CLI ile çalışır; çözümlenmiş JSON
yalnız bellekte tutulur, exception/terminal çıktısına yazılmaz. Engine erişimi,
volume kontrolü veya kaynak oluşturma yapmaz. Fixture başarı/hata sonunda kaldırılır.

13 Ekim sonuçları: **2/2 PASS**, Compose5.3.0. Deployment'ta altı servis, API/frontend
digest referansları, build alanlarının yokluğu, üç ayrı volume, yalnız üç loopback
portu, app ağı ve mevcut read-only provisioning kaynakları doğrulandı. Base-only
modelde API/frontend build ve development external volume adı korundu.

**Ubuntu SSH terminali**, aktarılan dosyalarla aynı kontrol ayrıca çalıştırılabilir:

```bash
python3 tests/Deployment.Configuration.Test.py
```

Bu Ubuntu komutu henüz çalıştırılmadı; image pull veya VM runtime kabulü değildir.
Statik doğrulama öncesinde negatif test override yokken beklenen nedenle FAIL oldu;
Windows sandbox temp yazma engeli ayrıca görüldü, scoped çalıştırma ile çözüldü.
Kalan yalnız o fixture temizlendi. Uygulama build'i gerekli değildir; kod değişmedi.

Son kontroller: repository secret scanner exit0, `git diff --check` exit0,
38 yerel dosya/anchor bağlantısı PASS. Yeni örnek env ignored değildir; gerçek
`.env`/`.env.deployment` ignored ve `.env` tracked değildir. Testin ilk runtime
fixture yazımı scanner tarafından literal atama adayı olarak işaretlendi;
üretilen değerler değişken referanslarıyla ifade edildi. Scanner/allowlist
değiştirilmedi; gerçek secret bulunmadı veya okunmadı. Sessiz `config -q` çıktısı
ve JSON parse stderr'i üretilen canary'ler için kontrol edilir; çözümlenmiş JSON
terminalde gösterilmez. Yalnız yedi kapsam dosyası değişti, index boş kaldı.

## VM'ye aktarılan dosyalar ve tekrar aktarım

Tamamlanan aktarım aynı source SHA'daki Git archive kaynak ağacını temel aldı;
tekrar aktarımda da aynı kaynak korunmalı:
kök Compose, `monitoring/` ağacı, backend migration/proje ve tool manifest dosyaları
aynı revision'dan gelmeli. Aktarım sırasında yeni dosyalar henüz commit/push edilmediği
için kaynak arşivi ve yerel deployment dosyaları birlikte taşındı. Seçilen source SHA'yı
tek başına clone etmek bu sonradan hazırlanan deployment override'ını getirmez.

Yeni/aktarılan dosyalar açıkça:

1. `infrastructure/deployment/compose.deploy.yaml`
2. `infrastructure/deployment/.env.example`
3. `infrastructure/deployment/release.json`
4. `infrastructure/deployment/README.md`
5. `tests/Deployment.Configuration.Test.py`

Windows'taki gerçek `.env`, `.env.deployment`, user-secrets, build çıktıları veya
development veri dizinleri aktarılmaz. VM'de hedef klasör hazırlandıktan sonra
**Windows PowerShell** üzerinden örnek kopyalama (şimdi çalıştırılmadı):

```powershell
$vmAddress = '172.24.33.96'
scp infrastructure/deployment/compose.deploy.yaml infrastructure/deployment/.env.example infrastructure/deployment/release.json infrastructure/deployment/README.md "labadmin@${vmAddress}:~/fullstack-ops-lab/infrastructure/deployment/"
scp tests/Deployment.Configuration.Test.py "labadmin@${vmAddress}:~/fullstack-ops-lab/tests/"
```

IP DHCP ile değişebilir; önce Ubuntu'da `hostname -I` ile güncel adres öğrenilir.
Bu komutlar yalnız açıkça seçilen public dosyaları kopyalar; recursive secret
klasörü paylaşmaz. `~/fullstack-ops-lab` ayrı VM laboratuvar klasörüdür. Rehberli
aktarımda kaynak arşivi ve yalnız beş yeni dosyanın arşivi taşındı; iki arşivin hash
eşleşmesi doğrulandı. Yukarıdaki scp komutları alternatif dosya aktarım örnekleridir.

## Kurulum sırası — migration ve stack başlangıcı tamamlandı, tam runtime kabulü bekliyor

1. **Ubuntu SSH:** aynı source SHA'da ayrı temiz clone/config ağacını ve deployment
   dosyalarını hazırla. VM Engine/context, kaynak envanteri ve port boşluğunu kontrol et.
2. **Ubuntu SSH:** gerçek deployment env'ini yalnız VM'de, mevcut dosyanın üzerine
   yazmadan örnekten oluştur. Aşağıdaki sonraki-adım komutu yeni dosya yaratır;
   Windows development env'inden değer kopyalamaz:

   ```bash
   (umask 077; cp -n infrastructure/deployment/.env.example .env.deployment)
   ```

   Placeholder'ları yerel editörde doldur; ASPNETCORE_ENVIRONMENT **Production**,
   TTL pozitif tam sayı olmalı (başlangıç önerisi 60). İki ayrı yeni lab parolası
   ve lab kullanıcı/database değerleri belirlenir. Şifreleri shell komutuna veya
   rapora yazma. `.env.deployment` mevcut Git ignore kuralıyla dışlanır; örnek dosya
   takip edilebilir. Host API user-secrets akışı bu Compose ortamında kullanılmaz.
3. **Ubuntu SSH:** aynı key'ler varsa process environment'ın env dosyasını
   ezebileceğini kontrol et; değerleri yazdırma. Güvenli preflight/adaptasyonla eksik,
   boş ve placeholder değerleri kontrol et. Mevcut Windows preflight'ın default
   `.env`/development volume hedefini burada kullanma; Ubuntu PowerShell kabulü
   ve deployment parametreleri ayrı hazırlık gerektirir. Salt config kontrolü:

   ```bash
   sudo docker compose --project-name fullstackops-deploy-lab --env-file .env.deployment -f compose.yaml -f infrastructure/deployment/compose.deploy.yaml config -q
   ```

   `config -q` yapı/substitution denetler; placeholder, credential eşleşmesi,
   volume varlığı veya database readiness'i kanıtlamaz. Çözümlenmiş `config` veya
   `config --environment` çıktısını paylaşma.
4. **Ubuntu SSH:** iki digest'i pull et, OCI revision/local image ID'yi doğrula;
   bu görevdeki anonim metadata okuması VM pull yerine geçmez. Yalnız gerçekten
   yoksa ayrılmış external PostgreSQL volume'unu hazırla; önce sadece PostgreSQL'i
   başlat ve TCP auth/readiness doğrula.
5. **Windows hazırlık terminali veya sonraki kararla Ubuntu SDK ortamı:** aynı
   source SHA'daki mevcut InitialCreate'dan idempotent SQL üret, incele ve checksum
   kaydet. API runtime image'ında SDK/EF CLI yok. VM'de API/frontend image build
   yapılmaz; host SDK ile SQL hazırlığı image build'den farklıdır. Ayrıntı:
   [ilk kurulum rehberi](../../labs/09-environment-configuration/README.md#13-temiz-bilgisayar-kurulum-rehberi).
6. **Ubuntu SSH:** SQL'i sadece deployment DB'ye `psql -X -w -v ON_ERROR_STOP=1`
   ile uygula; tasks/history doğrulamasından sonra altı servisi açık project/env/
   override hedefiyle `up -d --no-build --wait --wait-timeout 180` başlat.
7. **Ubuntu SSH + Windows tarayıcı:** pull/container image identity, health,
   frontend assets, CRUD/cache ve monitoring kabulünü yap. HTTPS, update/rollback
   ve backup/restore ayrı küçük adımlardır.

Rehberli VM adımında 1–5 kaynak/env/model/digest pull/PostgreSQL ve SQL hazırlığı
tamamlandı. Adım6 SQL uygulama/şema ve altı servisin başlangıcı tamamlandı; adım7'nin
image identity/health/tarayıcı erişimi de PASS. Kalan contract/cache/monitoring
runtime kabulü bekliyor. Ubuntu statik unittest komutu ayrıca çalıştırılmış sayılmaz.
Aşağıdaki tarihli kanıt kayıtları bu sınırları korur.
Normal kapatma project/env/override hedefiyle `down` olur; volume silme rutin adım
değildir. External PostgreSQL ve monitoring verilerini koru; `down -v` veya prune
kullanma. Bu statik görevde temizlenecek Docker kaynağı oluşturulmadı.

## Rehberli VM doğrulama kaydı — 13 Ekim 2026

Sonuçlar kullanıcının SSH terminalinde çalıştırdığı komutların paylaşılan güvenli
çıktılarına dayanır; bu commit incelemesi runtime deneylerini tekrarlamaz.

| Kontrol | Gerçek sonuç |
| --- | --- |
| Ubuntu / Docker / Compose | Ubuntu24.04.5, 4vCPU, yaklaşık6GiB RAM; Engine Client+Server ve Compose5.6.0; hello-world başarılı |
| Aktarım | Kaynak1b52633776279b1661a7cac53392d385cbf10444 ve beş yeni deployment/test dosyası ayrı arşivlerle; hash eşleşmesi PASS |
| Env | VM'ye özel `.env.deployment`, izin600/sahip labadmin; farklı lab credential'ları, değerler çıktıya yazılmadı |
| Compose | Gerçek env ile sessiz config/model PASS; API/frontend build yok, digestler eşleşiyor, üç loopback port ve üç ayrı volume adı |
| API/frontend pull | İki digest pull exit0, RepoDigest/OCI source revision/linux-amd64 eşleşmesi PASS |
| PostgreSQL volume | `fullstackops-deploy-lab-postgres`, local driver; Type=volume, Destination=/var/lib/postgresql |
| PostgreSQL container | `fullstackops-deploy-lab-postgres-1`, running/healthy, PublishedPorts={} |
| Readiness | pg_isready: accepting connections, exit0 |
| TCP authentication | postgres:5432 yanlış parolayı authentication hatasıyla reddetti; deployment parolasıyla SELECT1 başarılı; hedef loopback değil |
| Database/role | Beklenen env database ve role eşleşmesi PASS; değerler gösterilmedi |
| Şema | tasks YOK; __EFMigrationsHistory YOK; migration öncesinde beklenen sonuç |
| Diğer servisler | API/frontend/Redis/Prometheus/Grafana başlatılmadı; tam runtime kabulü NOT VERIFIED |

VM'de bildirilen image ID'leri API için
`sha256:2ccb0ecce9dc7cbe9da418b4f0a952b8122be336299fd3b888539b5d07a05afd`, frontend için
`sha256:e0c77449225c4cd602e8f3b2af43a68ca3ad1578ce6428ba8ddcccf1fa612627` oldu.
Manifest digest, config digest ve Engine image ID kavramları evrensel olarak aynı
varsayılmaz; RepoDigest, revision ve platform bağımsız kontrol edildi.
release.json içindeki birleşik vm_pull_and_runtime_acceptance alanı NOT VERIFIED
kalır: pull kanıtı artık mevcut olsa da tam runtime kabulü yapılmadı; kaynak/digestler
bu dokümantasyon commit'i veya sonraki publish run ile otomatik değiştirilmez.

İlk API pull denemesi başarısızdı; nedeni belirlenmedi. Sonraki bounded pull exit0
ile tamamlandı. İlk parola negatif testi loopback trust nedeniyle beklenen reddi
kanıtlamadı. Salt okunur HBA incelemesinde local/127.0.0.1/::1 trust ve genel host
scram-sha-256 görüldü. HBA/parola değiştirilmeden yalnız test hedefi postgres:5432
olarak düzeltildi; yanlış/doğru parola sonuçları ve stdout/stderr canary kontrolü PASS.
`pg_isready` veya healthy tek başına parola/şema doğrulaması değildir.

Son container/volume listesi yalnız healthy PostgreSQL ve deployment PostgreSQL
volume'unu gösterdi; yeni project ağı fullstackops-deploy-lab_app. PostgreSQL migration
adımı için çalışır bırakıldı; cleanup amacıyla volume/container kaldırılmadı.
Development env/user-secrets/volume kaynakları kullanılmadı veya değiştirilmedi.
Migration/test kaydı/HTTPS/backup yapılmadı. Sonraki adım mevcut aynı-revision
InitialCreate'dan SQL üretip incelemek ve açıkça sadece deployment DB'ye uygulamaktır.

## InitialCreate SQL uygulaması — 14 Ekim 2026

Bu bölüm 13 Ekim'in migration öncesi kaydını günceller. Komutları kullanıcı Windows
PowerShell ve Ubuntu SSH terminalinde çalıştırdı; agent yalnız kaynak/SQL dosyasını
ve repository dokümantasyonunu inceledi. VM deneyleri ayrıca tekrar çalıştırılmadı.

### Kaynak ve üretim

- Ayrı geçici Git clone, seçilmiş kaynak SHA'da detached checkout: PASS.
- Windows SDK10.0.401 ve checkout'ın local dotnet-ef10.0.12 aracı: PASS.
- İlk EF üretimi exit1 idi; ham çıktı paylaşılmadı, kesin neden belirlenmedi.
  Ayrı backend Release build exit0 ve ardından --no-build SQL üretimi exit0 geçti.
  Build warning sayısı paylaşılmadı; sıfır warning iddiası yapılmaz.
- Yalnız EF alt sürecine Production, sahte PostgreSQL/Redis hedefleri ve geçerli TTL
  verildi. User-secrets veya development env kullanılmadı; database'e bağlanılmadı.
- VM'ye SDK/EF kurulmadı; API/frontend Docker image build yapılmadı.

Windows'taki çekirdek komutlar (geçici checkout'ta; process config yukarıdaki gibi):

```powershell
dotnet tool restore
dotnet build src/backend/FullStackOpsLab.Api/FullStackOpsLab.Api.csproj --configuration Release --nologo
dotnet ef migrations script 0 20260928113912_InitialCreate --idempotent --no-build --configuration Release --project src/backend/FullStackOpsLab.Api/FullStackOpsLab.Api.csproj --startup-project src/backend/FullStackOpsLab.Api/FullStackOpsLab.Api.csproj --output InitialCreate.idempotent.sql
```

Yeni migration üretilmedi. SQL1059byte; özgün dosya SHA256:
`ce23c018c2000cc8143df02f0fb8d2525de0717385a8c29f84b4888507bd5b53`.
SCP sonrası VM'de sha256sum/wc aynı sonucu verdi; dosya izni600.
Release kaydına yalnız SQL checksum eklendi; source SHA/image digestleri değişmedi.

### SQL incelemesi ve BOM teşhisi

| Alan | Beklenen ve doğrulanan şema |
| --- | --- |
| id | integer, GENERATED BY DEFAULT AS IDENTITY, NOT NULL, primary key |
| title | text, NOT NULL |
| description | text, nullable |
| is_completed | boolean, NOT NULL, DEFAULT FALSE |
| created_at | timestamp with time zone, NOT NULL |
| updated_at | timestamp with time zone, nullable |

History tablosu CREATE IF NOT EXISTS ile transaction dışında hazırlanır. tasks
oluşturma ve `20260928113912_InitialCreate` / EF10.0.12 history kaydı transaction
içindedir. History'de migration varsa koşullu DO blokları onu atlar. Script elle
oluşturulmuş şema/history çelişkilerini çözmez. Ek --single-transaction kullanılmadı.

İlk uygulama psql exit3 ile durdu. Özgün EF SQL dosyası UTF-8 BOM taşıyordu; güvenlik
kontrol SQL'inin dosya önüne eklenmesi BOM'u stdin'in ortasına taşıdı. PostgreSQL
logundan yalnız güvenli sınıflandırma ile BOM syntax error BULUNDU; salt okunur
sorguda tasks/history YOK idi. Bu başarısız girişim migration PASS sayılmadı.

Özgün dosyanın hash'i korunarak yalnız gönderilen payload normalleştirildi:

```python
original = Path("InitialCreate.idempotent.sql").read_bytes()
# Önce özgün dosyanın kayıtlı SHA256'sı doğrulanır.
sql_payload = original.decode("utf-8-sig").encode("utf-8")
```

Bu yalnız başlangıç BOM'unu kaldırır; migration SQL içeriği ve diskteki dosya
değişmez. Dosya/stdin encoding'i, SQL önüne kontrol bloğu eklenirken de dikkate alınır.
[psql exit code ve transaction davranışı](https://www.postgresql.org/docs/18/app-psql.html)
SQL hatasında ON_ERROR_STOP ile exit3 döndüğünü açıklar.

### Gerçek uygulama ve tekrar kanıtı

Uygulama öncesi project/service/running/healthy, external volume/mount ve host portu
yokluğu doğrulandı. Non-loopback postgres:5432 TCP bağlantısıyla beklenen deployment
database/role ve boş şema kontrol edildi. Parola stdin'den shell read ile alınıp
yalnız child PGPASSWORD'a aktarıldı; komut argümanına/dosyaya/çıktıya eklenmedi.
Core psql seçenekleri: `-h postgres -p 5432 -X -w -v ON_ERROR_STOP=1
-v VERBOSITY=sqlstate -f /dev/stdin`; username/database container env'den geldi.
Statement/lock/connect ve subprocess timeout'ları sınırlıydı. stdout/stderr bellekte
yakalandı; parola kontrolü geçti, ham hata/loglar paylaşılmadı.

| Kontrol | Gerçek sonuç |
| --- | --- |
| Düzeltilmiş ilk uygulama | psql exit0, COMMIT PASS |
| Salt okunur şema | Altı sütun/tip/nullability/default/identity/primary key PASS |
| History | Tek InitialCreate kaydı; ProductVersion10.0.12 PASS |
| Task kayıtları | count0; test Task kaydı oluşturulmadı |
| İkinci idempotent uygulama | psql exit0, COMMIT PASS |
| Önce/sonra snapshot | Şema/history/count ve tablo/identity sequence OID'leri aynı |
| Secret kontrolü | Paylaşılan tanı/SQL çıktılarında değer yok; psql stdout/stderr parola kontrolü PASS |

Snapshot SHA256 (aynı database/role ve mevcut objeler için):
`c1219d7a88dd073c257a46ffb039368631cd8120d7394037755c05fa8ade1f49`.
Bu OID'leri içerdiğinden başka yeni database'de aynı hash beklenmez; bu deneyde
ikinci uygulamanın tabloları/sequence'i yeniden oluşturmadığını da gösterir.
History atlandı, şema ve Task count0 korundu; bu tüm gelecekteki migration'ların
veya concurrency senaryolarının testi değildir.

PostgreSQL çalışır bırakıldı. Deployment env, volume ve development kaynakları
korundu; diğer beş servis başlatılmadı. VM SQL dosyası ve Windows geçici checkout
bu rehberli adımda kaldırılmadı; SQL secret içermez, env oraya kopyalanmadı.
Son VM envanteri kullanıcı tarafından doğrulandı: yalnız deployment PostgreSQL
container'ı Up24hours/healthy, 5432/tcp (host publish yok); volume listesinde yalnız
fullstackops-deploy-lab-postgres/local. `.env.deployment` ve özgün SQL dosyasının
izinleri600. PostgreSQL ve volume bilerek korundu; Windows geçici checkout kaldırılmadı.
Full runtime/CRUD/cache/browser/monitoring, recreate persistence,
HTTPS, update/rollback ve backup/restore kabulü hâlâ bekliyor. Sonraki küçük adım
aynı digestlerle image-only stack başlangıcı ve localhost SSH tüneli erişimidir.

Ana repository'de bu kayıt sonrası statik deployment testi2/2 PASS, repository
secret leakage kontrolü exit0, 40 yerel dosya/anchor bağlantısı PASS ve
git diff --check exit0. Yalnız bu README, deployment planı, PROJECT_STATUS ve
release.json SQL checksum kaydı değişti; application/Compose/image seçimi değişmedi.
Commit/push yapılmadı. Bunlar VM'deki tam uygulama runtime kabulü değildir.

## Stack başlangıcı ve SSH erişimi — 14 Ekim 2026

Bu adım yalnız başlangıç ve erişim kabulüdür. Kullanıcı Ubuntu SSH, Windows
PowerShell ve gerçek Windows tarayıcısında kontrolleri yaptı; agent paylaşılan
güvenli sonuçları ve repository dosyalarını inceledi, VM'yi ayrıca yönetmedi.
Önceki dört dosyanın migration değişiklikleri korundu. Source/release image çifti
değişmedi; release.json'daki vm_pull_and_runtime_acceptance alanı tam runtime
kriterleri eksik olduğu için NOT VERIFIED kalır.

### Başlangıç komutu ve gerçek kaynaklar

PostgreSQL project/service/running/healthy, external volume adı/mount/host portu
yokluğu ve tek InitialCreate10.0.12 history kaydı salt okunur yeniden doğrulandı.
Gerçek deployment env ile config -q ve bellekte JSON model kontrolü PASS:
altı servis/aynı app ağı, API/frontend build yok, iki seçilmiş digest, yalnız üç
VM loopback portu, üç ayrı volume ve read-only provisioning kaynakları.
Çözümlenmiş JSON/connection string veya credential terminale basılmadı.

Ubuntu SSH terminalinde çalıştırılan gerçek başlangıç komutu:

```bash
sudo timeout --kill-after=10s 900s docker compose \
  --project-name fullstackops-deploy-lab \
  --env-file .env.deployment \
  -f compose.yaml \
  -f infrastructure/deployment/compose.deploy.yaml \
  up -d --no-build --pull missing --wait --wait-timeout 180
```

Exit0. --no-build ve build alanlarının kaldırılması uygulama image build'ini
engeller; --pull missing yalnız eksik image'ları çeker. Grafana13.2.3/Redis8.2.10-alpine/
Prometheusv3.13.4 için paylaşılan pull süreleri sırasıyla92.9/64.5/71.4s idi.
Bunlar tek seferlik ağ/cache gözlemleridir; benchmark veya genel startup garantisi
değildir. PostgreSQL'in mevcut volume'u korundu; yalnız iki yeni deployment
monitoring volume'u oluşturuldu: fullstackops-deploy-lab-grafana/prometheus.

| Servis | Gerçek durum | Gerçek host yayını |
| --- | --- | --- |
| postgres | running/healthy | Yok; container5432 |
| redis | running/healthy | Yok; container6379 |
| api | running/healthy | Yok; container8080 |
| frontend | running/healthy | 127.0.0.1:18081 -> 80 |
| prometheus | running/healthy | 127.0.0.1:19090 -> 9090 |
| grafana | running/healthy | 127.0.0.1:13000 -> 3000 |

Inspect'te yalnız seçilmiş güvenli alanlar bellekte okundu; environment çıktısı
gösterilmedi. API/frontend Config.Image tam release referansı, RepoDigests,
OCI source revision ve linux/amd64 eşleşti. Container.Image ilgili image inspect
Id ile karşılaştırıldı; bildirilen ID'ler API2ccb0ecce9dc7cbe9da418b4f0a952b8122be336299fd3b888539b5d07a05afd,
frontend e0c77449225c4cd602e8f3b2af43a68ca3ad1578ce6428ba8ddcccf1fa612627
(ikisi sha256 ön ekiyle). Manifest/config digest ve Engine ID evrensel olarak
eşit varsayılmaz. API/PostgreSQL/Redis için gerçek host mapping yoktu.

### Internal health ve Windows tüneli

Frontend container'ındaki mevcut wget ile doğrudan http://api:8080/health,
/health/live ve /health/ready GET istekleri yapıldı. Üçü de HTTP200/bodyHealthy;
frontend SPA fallback HTML'i sağlık kanıtı olarak kullanılmadı. Nginx'te yeni
health/metrics route'u veya internal servis için host portu eklenmedi.

VM eth0 IPv4: 172.24.37.174/20; DHCP olduğu için ileride yeniden doğrulanır.
Windows'ta development portlarından ayrı üç loopback portu kısa TcpListener
bind/close ile kullanılabilir olarak doğrulandı. Tünel komutu **Windows
PowerShell'de**, PS C:\... satırından başlatıldı:

```powershell
ssh -N -T -o ConnectTimeout=10 -o ExitOnForwardFailure=yes -o ServerAliveInterval=30 -o ServerAliveCountMax=3 -L 127.0.0.1:28081:127.0.0.1:18081 -L 127.0.0.1:29090:127.0.0.1:19090 -L 127.0.0.1:23000:127.0.0.1:13000 labadmin@172.24.37.174
```

İlk port kontrolü yanlışlıkla Bash'te çalıştırıldı; syntax hataları port sonucu
sayılmadı. İlk tünel de VM'nin içinde açıldı; Windows frontend curl exit7/HTTP000
ve Windows listener yokluğu görüldü. Kullanıcı yalnız o foreground tüneli Ctrl+C
ile kapatıp Windows'ta yeniden açtı. Stack yeniden başlatılmadı. SSH -L listener'ı
istemcinin çalıştığı hostta açar; sağdaki 127.0.0.1 hedefi SSH sunucusu VM'dir.

Doğru tünelde Get-NetTCPConnection üç Windows127.0.0.1 listener'ı ve aynı owning
process'i gösterdi; Windows curl --noproxy ile frontend root HTTP200. Tünel penceresi
açık tutulur; Ctrl+C/pencere kapatma yalnız tüneli kapatır, detached stack'i durdurmaz.
Yeniden erişimde VM IP ve Windows port boşluğu kontrol edilerek tünel tekrar açılır.

| Windows tarayıcı adresi | Kullanıcı gözlemi |
| --- | --- |
| http://127.0.0.1:28081/ | Frontend açıldı |
| http://127.0.0.1:29090/ | Prometheus arayüzü açıldı |
| http://127.0.0.1:23000/ | Grafana deployment admin ile giriş başarılı |

Grafana bilgileri VM'deki /home/labadmin/fullstack-ops-lab/.env.deployment dosyasında;
dosya salt okunur editörle kullanıcı tarafından incelendi, değerler sohbete/rapora
aktarılmadı. Windows development .env bilgileri deployment için kopyalanmadı.
Grafana Overview görünürlüğü/panel sorguları ve gerçek yeni Prometheus örnekleri
bu adımda ayrıca doğrulanmadı. Public internet erişimi veya HTTPS kabulü yoktur.

### Sınırlar ve bırakılan durum

Kullanıcı frontend'de bir görev oluşturup tamamladı ve sildiğini bildirdi. Bu
manuel gözlem için HTTP status/Location/JSON/nullable/400/404 veya Redis TTL ve
invalidation ölçümü alınmadı; tam CRUD/cache runtime kabulü PASS sayılmaz.
Agent bu adımda CRUD yazma, kesinti, rollback, HTTPS veya backup testi çalıştırmadı.
Migration sonundaki Task count0 önceki adıma aittir; manuel tur sonrası yeni DB
count sorgusu yapılmış gibi sunulmaz.

Stack çalışır bırakıldı; PostgreSQL external volume'u ve iki yeni monitoring
volume'u korunur. Development env/user-secrets/Docker kaynakları değiştirilmedi;
yalnız bu adımın tüneli açıldı, yanlış yerdeki tünel kapatıldı. İlk kurulum SQL'i
ve Windows geçici checkout korunuyor. Sonraki küçük adım planın kalan GHCR runtime
contract/cache kabulüdür; diğer kabul kapıları ayrıca uygulanır. Commit/push yok.

Repository son kontrolleri: secret leakage exit0, 41 yerel dosya/anchor bağlantısı
PASS, git diff --check exit0. Bu adımda README/plan/PROJECT_STATUS güncellendi;
önceki release.json SQL checksum değişikliği korundu. Toplam yalnız dört beklenen
dosya modified; index boş. Seçilmiş SHA/digest çifti ve Compose dosyaları değişmedi.

# Deployment Lab — image seçimi ve statik Compose hazırlığı

13 Ekim 2026: statik hazırlık, rehberli VM aktarımı/env/digest pull ve yalnız PostgreSQL
volume/readiness/TCP authentication **PASS**. Migration, diğer beş servisin başlatılması,
tam deployment runtime kabulü, HTTPS ve yedekleme henüz **NOT VERIFIED**. Bu bir production
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
doğruladı; VM'de gerçek env ile parse/model kontrolü de PASS. Tam runtime kabulü henüz yapılmadı.
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
Windows'tan tarayıcı erişimi sonraki görevde localhost SSH tüneliyle ele alınacak.
VM hazırlığında bu üç portun boş olduğu doğrulandı. Yalnız PostgreSQL başlatıldı ve
host portu açılmadı. Internal servis
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

## Kurulum sırası — ilk dört hazırlık adımı tamamlandı

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

Rehberli VM adımında 1–4 kapsamındaki kaynak/env/model/digest pull ve yalnız PostgreSQL
hazırlığı tamamlandı. Ubuntu statik unittest komutu ayrıca çalıştırılmış sayılmaz.
Adım5 SQL hazırlığı/inceleme ve adım6 migration/tam stack henüz uygulanmadı;
aşağıdaki kanıt kaydı bu sınırı korur.
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

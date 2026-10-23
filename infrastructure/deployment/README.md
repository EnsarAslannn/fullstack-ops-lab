# Deployment Lab — image-only VM kurulumu ve kabul kayıtları

**23 Ekim 2026, günlük saat güncellemesi PASS:** [Kalıcı10:30 ve beş dakikalık timer kabulü](backup/README.md#günlük-saati-1030-yapma-ve-beş-dakikalık-test--23-ekim-2026).
Her gün **10:30 Europe/Istanbul**; VM timer enabled/active/waiting, override yok,
sonraki zaman24 Ekim10:30.07:55:34UTC kısa test ve07:58:25UTC takvime dönüşteki
ayrı iş already-complete/exit0/removed_sets0; yeni dump yok. Altı günlük dosya
hash'i, bugünkü mtime/asıl başarı zamanı, kaynak veri/history/sequence ve altı
container korundu. Doğal10:30 olayı, reboot/uyku catch-up mekanizması, çok günlük
retention ve yeni arşivlerin kopya/restore'u bekliyor;24h RPO garantisi yok.
Aşağıdaki02:00 ve eski timer durumları tarihsel kayıtlardır.

**22 Ekim 2026, sonraki adım:** [Günlük timer enabled/active ve kontrollü kısa tetik PASS](backup/README.md#günlük-timer-etkinleştirme-ve-kontrollü-tetik--22-ekim-2026).
60 saniyelik geçici tetik09:38:49UTC service completed/exit0/removed_sets0 üretti.
Yeni22 Ekim arşivi3477 byte/hash doğrulandı; geçici ayar kaldırıldı, günlük02:00
Europe/Istanbul geri geldi. Kaynak Task0/history/sequence8 ve altı aynı healthy
container, eski VM/Windows kopyaları korundu. Gerçek02:00/reboot-catch-up/çok günlük
retention ve yeni22 Ekim arşivinin Windows kopyası/restore'u henüz doğrulanmadı.
24h RPO ve deployment final kabulü açık; aşağıdaki önceki kabul kayıtları tarihlidir.

**22 Ekim 2026:** [Mevcut günlük yedeğin Windows kopyası ve izole restore kabulü PASS](backup/README.md#günlük-arşivin-windows-kopyası-izole-restore-ve-temizlik--22-ekim-2026).
21 Ekim3477 byte arşiv kullanıldı; yeni dump alınmadı. Boş tasks/hash, InitialCreate
history, şema/ownership ve sequence8 doğrulandı; hedef-only probe ID9 üretti ve
satırı rollback edildi, kaynak sequence8 kaldı. Yalnız yeni restore container/ağ/
volume kaldırıldı. Altı kaynak container healthy ve aynı; kaynak veri ile günlük/
manuel VM/Windows yedekler korundu. Timer disabled/inactive. Gerçek takvim/catch-up,
çok günlük retention,24h RPO ve deployment final kabulü hâlâ açık; SCP manuel.

**21 Ekim 2026:** [Günlük backup VM kurulumu ve iki manuel service çalışması PASS](backup/README.md#rehberli-vm-kurulumu-ve-iki-manuel-çalışma--21-ekim-2026).
Yeni günlük dump3477 byte/checksum/arşiv kontrolü geçti; aynı gün ikinci çalışma
set/hash/mtime ve asıl başarı zamanını korudu. Linux kilit fixture'ı, izinler ve
systemd verify/calendar geçti; timer **disabled/inactive** kaldı. Kaynak veri/altı
container ve eski manuel VM/Windows yedekleri korundu. Gerçek takvim/catch-up/çok
günlük retention, yeni günlük arşivin Windows kopyası/restore'u ve final kabul
bekliyor;24h RPO garantisi yok. Windows ikinci kopyası manuel kalır.

**20 Ekim 2026:** [Kontrollü cleanup ve yedek koruması PASS](BACKUP-RESTORE.md#14-kontrollü-temizlik-ve-yedek-koruması--20-ekim-2026).
Sahipli Task ID8 HTTPS GET/snapshot kapısından sonra DELETE204/GET404 ile silindi;
yalnız restore container/ağ/volume kaldırıldı. Kaynak veri/history baseline ile
aynı; altı container kimliği/image aynı, healthy/RestartCount0. VM/Windows
manifest+11 dosya hash/izinleri korundu. Günlük zamanlama/retention/RPO ve
deployment final kabulü açık; yedek/env/credential/TLS/kanıt dosyaları saklanıyor.

**19 Ekim 2026:** [Mantıksal dump ve Windows ikinci kopyası](BACKUP-RESTORE.md#12-mantıksal-dump-ve-windows-ikinci-kopyası--19-ekim-2026)
ardından [izole restore/veri/şema/history/sequence kabulü PASS](BACKUP-RESTORE.md#13-izole-restore-ve-sequence-kabulü--19-ekim-2026).
Aynı yerel PostgreSQL18.6 image'ıyla yeni volume/internal ağ/no-port hedefte gerçek
pg_restore ve ID8/altı alan/tam hash eşleşti; ID belirtilmeden9 üretildi, probe
satırı rollback edildi, source sequence8 kaldı. **O oturumda ID8, restore
kaynakları ve iki backup seti kullanıcı isteğiyle bırakıldı; cleanup ayrı
20 Ekim kaydındadır.** A çifti, altı kaynak container kimliği/image/health ve kaynak volume
korundu. Günlük job/retention/RPO uygulanmadı; tarihsel kayıtlar aşağıda bırakıldı.

**18 Ekim 2026:** [izole PostgreSQL yedek/restore rehberi](BACKUP-RESTORE.md),
bağımsız restore modeli/örneği ve statik kontroller hazırlandı. Gerçek dump,
Windows ikinci kopyası, restore, sequence ve cleanup kabulü **NOT VERIFIED**;
zamanlama etkinleştirilmedi. Ardından [VM envanteri/public aktarım ön kontrolü](BACKUP-RESTORE.md#11-vm-envanteri-ve-public-aktarım--18-ekim-2026)
PASS: A/altı healthy, PostgreSQL server/araç18.6, yerel image/mount, boş alan ve
dört public dosyanın hash eşleşmesi doğrulandı; restore adları boş. Dump/restore
başlatılmadı. Aşağıdaki 17 Ekim runtime deneyi tekrarlanmış sayılmaz.
Aktif A/release/HTTPS/development kaynakları aynı.

17 Ekim 2026 güncel durum: hazırlık/migration/HTTP-cache ve 15 Ekim asset/monitoring
kabulüne ek olarak **yerel HTTPS etkinleştirme, uyarısız manuel tarayıcı/asset ve
HTTPS CRUD kabulü PASS**. 15–16 Ekim HTTPS kabulünde frontend aynı seçilmiş image
ile yalnız TLS için yeniden oluşturuldu; o adımda diğer beş container korundu.
17 Ekim sürüm geçişlerinin yeni container kimlikleri aşağıda ayrıca kaydedilir.
Windows Schannel iptal kontrolü sınırlaması ve komuta özel best-effort sonucu
[ayrıntılı HTTPS kaydında](HTTPS.md#14-https-etkinleştirme-ve-runtime-kabulü--1516-ekim-2026)
açıklanır. **16 Ekim PostgreSQL recreate kalıcılığı da PASS**: aynı image/volume,
yeni PostgreSQL container ID'si ve HTTPS tekil GET ile test görevinin altı alanı
korundu. Diğer beş ID aynı, altısı healthy; test kaydı temizlendi.
Aktif A kaynak SHA/digestleri aynı. **16 Ekim güncelleme/rollback release seçimi ve
statik hazırlığı tamamlandı**; [A/B kanıtı ve geçiş planı](UPDATE-ROLLBACK.md)
ayrı kayıttadır. **17 Ekim public aktarım/hash, B digest pull/revision/platform,
A image korunması, gerçek env ile model ve izole B Nginx/TLS kontrolü PASS**;
[ayrıntılı VM ön kontrolü](UPDATE-ROLLBACK.md#8-rehberli-vm-aktarımı-b-image-ve-nginx-kontrolü--17-ekim-2026).
İlk Compose run denemesi exit124 verdi; ayrı doğrudan create/start tanısı geçti,
timeout nedeni bilinmiyor; bu ön kontrolde altı servis A'da aynı kimliklerle kaldı.
**Ardından 17 Ekim rehberli A→B→A runtime kabulü PASS:** her yönde yalnız API,
readiness200 sonrası frontend yeniden oluşturuldu. B ve A dönüşünde exact image
kimlikleri, HTTPS HTML/JS/CSS, ayrı CRUD/Location/JSON/400/404 ve değişmeyen ID5
kaydı doğrulandı. Final A aktif/altı healthy, dört altyapı container'ı aynı;
test kayıtları/dosyaları temizlendi, veri/history başlangıçla aynı.
[Güncel geçiş kanıtı](UPDATE-ROLLBACK.md#9-rehberli-aba-runtime-kabulü--17-ekim-2026).
17 Ekim'de sürekli erişim/kesinti süresi ve backup/restore NOT VERIFIED kaldı;
19 Ekim dump/restore sonuçları yukarıda ve sonraki tarihli kayıtlardadır.
Deployment lab bütünüyle tamamlanmadı. Bu bir production
deployment veya internet erişimi kabulü değildir.

## Amaç ve dosyalar

[Deployment planının](../../docs/deployment-plan.md) ikinci küçük adımıdır.
Mevcut altı servis `frontend`, `api`, `postgres`, `redis`, `prometheus`, `grafana`
korunur. Nginx frontend image'ının içinde kalır.

- [compose.deploy.yaml](compose.deploy.yaml): kök [Compose](../../compose.yaml)
  üzerine uygulanır; tek başına kullanılmaz.
- [.env.example](.env.example): yalnız placeholder; kullanılabilir credential yok.
- [release.json](release.json): kaynak SHA, run ve iki immutable image kimliği.
- [Güncelleme/rollback hazırlığı](UPDATE-ROLLBACK.md): aktif A'yı değiştirmeyen
  [A/B release kaydı](releases/update-rollback.json) ve yalnız iki image seçen
  [A](releases/compose.version-a.yaml)/[B](releases/compose.version-b.yaml)
  dördüncü overlay'leri; 17 Ekim rehberli geçiş/dönüş kabulü de aynı rehberde.
- [Statik test](../../tests/Deployment.Configuration.Test.py): gerçek Compose
  parser'ını kullanır; Engine, registry pull, .env veya user-secrets gerekmez.
- [HTTPS hazırlığı ve kurulum komutları](HTTPS.md): isteğe bağlı üçüncü
  [overlay](compose.https.yaml), [Nginx config](nginx/https.conf) ve
  [TLS path örneği](https.env.example); VM'de kullanıcı tarafından etkinleştirildi.
- [Yedek/restore hazırlığı](BACKUP-RESTORE.md): yalnız yeni test hedefi için
  [bağımsız Compose](compose.restore.yaml), [placeholder örneği](restore.env.example)
  ve [statik test](../../tests/Deployment.BackupRestore.Configuration.Test.py).
  Bu Compose deployment overlay'i değildir; kaynak volume'u bağlanmaz.
- [Günlük yedek/retention](backup/README.md): ayrı root-owned hedef, günlük
  [script](backup/daily-backup.py), systemd service/timer ve fixture testleri;
  manuel kabul setlerini/Windows kopyalarını silmez. VM kurulumu ve iki manuel
  çalışma geçti; günlük arşivin Windows kopyası/izole restore/cleanup kabulü22 Ekim'de
  tamamlandı. Timer kapalı, zamanlanmış çalışma ve çok günlük retention bekliyor.

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
image identity/health/tarayıcı erişimi de PASS. HTTP/cache ve 15 Ekim asset/monitoring
kabulü aşağıdaki ayrı kayıtlarda tamamlandı; diğer plan kapıları bekliyor.
Ubuntu statik unittest komutu ayrıca çalıştırılmış sayılmaz.
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

## Nginx HTTP contract ve Redis cache kabulü — 14 Ekim 2026

Bu, önceki manuel browser CRUD gözleminden ayrı, status/JSON/cache assertion'ları
olan rehberli kabul adımıdır. Komutları kullanıcı Windows PowerShell ve Ubuntu SSH
terminalinde çalıştırdı, gerçek sonuçları paylaştı. Agent VM'ye bağlanıp testleri
tekrarlamadı; bu kayıt paylaşılan çıktılar ve uygulama sözleşmesi incelemesine dayanır.
Repository inceleme HEAD'i `7c3f204729deb8e47c8877e955c9aa325db0ce6e`; çalışan
uygulama kaynağı ve image çifti yukarıdaki release kaydının
`1b52633776279b1661a7cac53392d385cbf10444` revision'ına aittir. Yeni main/GHCR
yayınlarına geçilmedi; image kimliği kabulü önceki başlangıç adımından yeniden kullanıldı.

### Erişim ve kullanılan kontroller

SSH pencereleri kapandığında Windows loopback listener yoktu; buna bağlı ikinci
PowerShell process kontrolü de boş ID ile başarısız oldu. Bu, VM stack'inin durmuş
olduğunu kanıtlamaz. Kullanıcı VM eth0 IP'sini `172.24.37.174/20` olarak doğrulayıp
tüneli yeniden Windows'ta açtı. `Get-NetTCPConnection` Windows127.0.0.1:28081
listener'ını (o an PID3660), `curl.exe --noproxy "*"` frontend root HTTP200 sonucunu
gösterdi. Windows development URL'si kullanılmadı.

- Windows frontend adresi `http://127.0.0.1:28081/`; tünel VM127.0.0.1:18081'e gider.
- Python standart kütüphanesi `urllib.request` ile tüm HTTP contract istekleri
  Ubuntu'dan `http://127.0.0.1:18081/api/tasks` Nginx girişine gönderildi; API'ye
  doğrudan istek veya Windows Docker Desktop üzerinden Redis kontrolü yapılmadı.
- Redis salt okunur `EXISTS`, `TTL`, `DUMP` kontrolleri yalnız
  `fullstackops-deploy-lab-redis-1` ve `fullstack-ops:tasks:all:v1` key'ini hedefledi.
  DUMP içeriği yalnız bellekte SHA256 ile karşılaştırıldı, ekrana/dosyaya yazılmadı.
- Etkin `Cache__TasksTtlSeconds` API container'ında shell builtin ile yalnız bu
  non-secret key için okundu: `printf "%s" "$Cache__TasksTtlSeconds"`. Env dosyası
  veya tüm container environment çıktısı okunup paylaşılmadı.
- API `docker logs --since` çıktısı bellekte veya yalnız CACHE MISS/HIT satırlarıyla
  incelendi; request body/credential içeren ham log çıktısı paylaşılmadı.

[CRUD smoke](../../tests/Phase0B.Tasks.Smoke.ps1) ve
[cache smoke](../../tests/Module5.Cache.Smoke.ps1) assertion'ları bu topolojiye
uyarlandı. Bu scriptler doğrudan çalıştırılmadı: cache script'i başlangıçta key'i
siler, boş liste ister ve PostgreSQL'i durdurur; bunlar bu görevde yetkilendirilmedi.
[CI Compose hazırlık/cleanup script'i](../../tests/Module11.Compose.Smoke.py) de
kalıcı deployment ortamında çalıştırılmadı. Yeni test bağımlılığı veya kaynak dosyası
eklenmedi; kullanıcı küçük stdin Python bloklarıyla kontrolleri yürüttü.

### Gerçek kabul sonuçları

| Kontrol | Sonuç ve kanıt |
| --- | --- |
| İlk liste | PASS: GET200, başlangıç EXISTS0/TTL-2; ardından key1/TTL60 |
| Cache miss → hit | PASS: ikinci GET200; zaman sınırlı loglarda önce CACHE MISS, sonra CACHE HIT |
| POST | PASS: 201, Location `/api/tasks/2`; benzersiz lab görevi ID2 |
| Oluşturulan JSON | PASS: id/title/description/isCompleted/createdAt/updatedAt; description null, completion false, iki timestamp mevcut |
| Tekil GET | PASS: 200; tam altı alan, null description ve beklenen test title/createdAt ile sahiplik doğrulandı |
| PUT | PASS: 200; title/description/completion güncellendi, id/createdAt korundu ve updatedAt arttı |
| Güncelleme tekrar okuması | PASS: tekil GET200; yanıt güncellenen DTO ile aynı |
| Başarılı mutation invalidation | PASS: POST/PUT/DELETE öncesi key1; her başarılı mutation sonrası key0 |
| Boş başlık | PASS: whitespace POST400 ve PUT400; key1 ve DUMP checksum değişmedi |
| Bulunmayan ID | PASS: önce ID2147483647 GET404 ile yokluğu doğrulandı; GET/PUT/DELETE404 ve cache içeriği korundu |
| DELETE | PASS: sahipliği doğrulanan ID2 için 204/boş body; key0, sonra tekil GET404 |
| Silme sonrası liste | PASS: GET200; ID2 yok, diğer kayıtların DTO'ları silme öncesi karşılaştırmayla aynı; key1/TTL60 |
| Etkin TTL | PASS: API configuration60 saniye; yeniden oluşturulan Redis key TTL60 |
| Doğal expiration | PASS: başlangıç kalan TTL60, silme komutu olmadan EXISTS0/TTL-2; kalan TTL+10 saniye timeout sınırı kullanıldı |
| Expiration sonrası yeniden oluşturma | PASS: GET200, key1/TTL60 (configuration ile uyumlu), ardından GET200; yeni loglarda MISS → HIT |
| Son liste | PASS: expiration öncesi/sonrası DTO listesi aynı, test ID2 yok |

JSON nullable kontrolü mevcut HTTP sözleşmesindeki `description` alanına aittir.
`updatedAt` oluşturma yanıtında `createdAt` ile aynı non-null değeri taşır;
database'deki nullable sütunu bütün HTTP timestamp'ları nullable gibi sunmak için
kullanılmaz. Title trim veya her nullable kombinasyonu bu adımda test edilmiş sayılmaz.

### Cleanup, öğrenme ve sınırlar

Yalnız benzersiz test ID2 oluşturuldu/güncellendi/silindi; DELETE öncesinde title ve
createdAt eşleştirilerek sahipliği doğrulandı. Diğer liste kayıtları DELETE
öncesi/sonrası aynıydı; tüm görev başlangıcının database snapshot'ı alınmış gibi
sunulmaz. Son listede test ID yok. Mevcut kayıtları silen toplu işlem, FLUSHALL/FLUSHDB,
manuel DEL, secret okuma/değiştirme veya geçici SQL/test dosyası oluşturma yapılmadı.
Test kaydını içeren cache başarılı DELETE ile invalidated oldu; sonunda normal
liste cache'i yeniden oluştu ve kendi TTL'siyle bırakıldı, temizlemek için silinmedi.

Stack durdurulmadı/yeniden oluşturulmadı; .env.deployment, user-secrets ve bütün
volume'lar korundu. Altı servisin health/image/port inspect kabulü bu adımda
tekrarlanmadı. Windows listener yeniden açılması container restart değildir.
HTML root erişimi PASS; ayrı JS/CSS asset status'ları, Grafana datasource/12 panel
ve yeni Prometheus örnekleri bu adımda NOT VERIFIED. Kesinti, persistence recreate,
HTTPS, update/rollback veya backup/restore denenmedi. Bu kısa trafik performans
benchmark'ı ve production deployment kabulü değildir.

Bu deneyde miss PostgreSQL'den okuyup cache oluşturur; hit cache'den döner.
Mutation sonrası invalidation bir sonraki liste isteğinin güncel veriyi okumasını
sağlar; 400/404 başarılı veri değişikliği değildir ve mevcut key'i korur. TTL veri
kaynağındaki Task kaydını değil, yalnız geçici liste cache'ini sona erdirir.
Sonraki küçük kabul: kalan asset erişimi ve VM monitoring/provisioning kontrolleri;
bu görevde başlanmadı. `release.json` tam runtime alanı NOT VERIFIED kalır.

Repository son kontrolleri: Windows'ta statik deployment testi2/2 PASS, secret
leakage kontrolü exit0, 45 yerel dosya/anchor bağlantısı PASS ve git diff --check
exit0. Yalnız bu README, deployment planı ve PROJECT_STATUS değişti; index boş.
Uygulama/config/release dosyaları değişmedi. Commit/push yapılmadı.

## Frontend asset ve VM monitoring kabulü — 15 Ekim 2026

Komutları kullanıcı Ubuntu SSH terminalinde ve Windows PowerShell'de çalıştırdı;
Grafana Overview'u Windows tarayıcısında inceledi. Agent repository dosyalarını ve
paylaşılan gerçek çıktıları değerlendirdi; VM'ye bağlanıp deneyleri tekrarlamadı.
Repository inceleme HEAD'i `aee802e5573c27f65908acea58b341fdc8b2c809`, çalışan
uygulama için seçilmiş source/release çifti hâlâ
`1b52633776279b1661a7cac53392d385cbf10444` ve yukarıdaki iki GHCR digest'idir.
Bu oturumda container image identity inspect tekrarlanmadı; önceki kabul yeniden
kullanıldı, release/config/image seçimi değiştirilmedi.

### Oturum başlangıcı ve erişim

- VM hostname `fullstackopslabvm`; DHCP eth0 IPv4 artık `172.30.249.139`.
  Önceki `172.24.37.174` tarihsel IP'dir; tünel hedefi güncellendi.
- Salt okunur `docker ps -a --filter label=com.docker.compose.project=fullstackops-deploy-lab`
  sonucunda altı servis healthy idi: frontend/API/Redis/Prometheus/Grafana Up23hours,
  PostgreSQL Up47hours. Bu süreler tek gözlemdir; uptime garantisi değildir.
- VM yayınları frontend127.0.0.1:18081, Prometheus127.0.0.1:19090,
  Grafana127.0.0.1:13000; API/PostgreSQL/Redis host portu yok.
- Windows28081/29090/23000 listener kontrolünde üç port boştu. Windows'ta loopback
  SSH tüneli yeni VM IP'sine açıldı. Kullanıcı frontend/Prometheus arayüzlerine ve
  Grafana deployment hesabına erişimi doğruladı. Var olan healthy stack için
  Compose up/build/recreate gerekmemiştir.

Windows PowerShell'de kullanılan tünel; bu pencere açık tutulur:

```powershell
ssh -N -T -o ConnectTimeout=10 -o ExitOnForwardFailure=yes -o ServerAliveInterval=30 -o ServerAliveCountMax=3 -L 127.0.0.1:28081:127.0.0.1:18081 -L 127.0.0.1:29090:127.0.0.1:19090 -L 127.0.0.1:23000:127.0.0.1:13000 labadmin@172.30.249.139
```

Grafana hesabını bulmak için kullanıcı yalnız VM'deki mevcut `.env.deployment`
dosyasını salt okunur editörde inceledi; değerler paylaşılmadı/değiştirilmedi.
Authenticated testlerde yalnız Grafana container'ının iki admin environment alanı
child stdout'tan belleğe alındı; Basic auth token'ı bellekte üretildi. Ham credential,
header veya container environment dökümü yazdırılmadı. Grafana yanıtları parola/token
eşleşmesi için bellekte kontrol edildi; hassas exception ayrıntıları gizlendi.
Bu sınırlı kontrol kapsamlı log/secret audit'i değildir.

[Datasource testi](../../tests/Module10.Grafana.Smoke.ps1),
[Prometheus testi](../../tests/Module10.Prometheus.Smoke.ps1) ve
[dashboard testi](../../tests/Module10.Dashboard.Smoke.py) incelendi; ilgili metadata,
query ve freshness assertion'ları deployment adreslerine uyarlanan stdin Python
bloklarıyla kullanıldı. Scriptlerin tamamı çalıştırılmadı: varsayılan development
hedefleri ve Prometheus/dashboard scriptlerindeki CRUD/kesinti adımları bu görevin
kapsamına taşınmadı. Agent yerelde runtime smoke testleri çalıştırmış gibi sunulmaz.

### Frontend asset sonuçları

Ubuntu `urllib.request` ile VM Nginx root HTML'i okundu; `HTMLParser` gerçek script
src ve stylesheet href'lerini çıkardı. Aynı origin'e ait dosyalar indirilip status,
MIME ve boş olmayan body kontrol edildi. HTML fallback JS/CSS başarısı sayılmadı;
JavaScript bu kontrol tarafından çalıştırılmadı.

| Yol | HTTP | Content-Type | Sonuç |
| --- | --- | --- | --- |
| `/` | 200 | text/html | PASS |
| `/assets/index-6SMY9-rQ.css` | 200 | text/css | PASS |
| `/assets/index-CKhYhs0u.js` | 200 | application/javascript | PASS |

### Prometheus target ve yeni örnek kanıtı

VM127.0.0.1:19090 `/api/v1/targets`: tek API job hedefi
`http://api:8080/metrics`, interval15s, health up, lastError boş. İki farklı başarılı
lastScrape `2026-10-15T09:55:04.960507499Z` ve `09:55:19.960610838Z` gözlendi.
PromQL `up{job="fullstack-ops-api",instance="api:8080"}` değeri1;
`timestamp(up{job="fullstack-ops-api",instance="api:8080"})` gerçek örnek zamanı
`09:55:19.960 UTC` verdi. `up` scrape başarısıdır; dependency readiness testi değildir.

Frontend sekmesi kapatıldı; önceki sayaçların değişmediği tekrar doğrulandıktan
sonra Nginx üzerinden yalnız altı liste GET yapıldı. Altı yanıt HTTP200 ve aynı
JSON listesiydi; Task mutation yapılmadı. Trafik UTC10:00:30.346271–10:00:30.356416
aralığındaydı. Bu kısa zaman aralığı benchmark veya gecikme garantisi olarak kullanılmaz.
Sonraki başarılı scrape için 45 saniye timeout ile beklendi.

| Sayaç / gerçek seri | Önce | Sonra | Fark |
| --- | ---: | ---: | ---: |
| Liste GET / http_server_request_duration_seconds_count | 13 | 19 | +6 |
| fullstackops_cache_hits_total | 2 | 7 | +5 |
| fullstackops_cache_misses_total | 11 | 12 | +1 |
| fullstackops_cache_invalidations_total | 6 | 6 | 0 |

Hepsi `job="fullstack-ops-api",instance="api:8080"` ile sorgulandı. HTTP listesi
ek olarak `http_request_method="GET",http_route=~"/api/tasks/?"` ile sınırlandı;
buradaki13/19 tüm endpoint'lerin genel HTTP toplamı değildir. Her seri için sum
ile değer, min(timestamp(selector)) ile gerçek scrape zamanı alındı; sabit query
evaluation time kullanıldı. Sonuç yokken sıfır uydurulmadı.

| Okuma | Dört sayacın gerçek örnek zamanı (UTC, 15 Ekim) | Kanıt |
| --- | --- | --- |
| Prometheus baseline | 09:58:49.959 | 13 / 2 / 11 / 6 |
| Prometheus trafik sonrası | 10:00:34.960 | 19 / 7 / 12 / 6; örnekler trafik bitişinden sonra |
| Grafana datasource proxy | 10:01:34.960 | Aynı19 / 7 / 12 / 6; örnekler trafik sonrası ve sorgu anında en çok35s yaşında |

Grafana'da `/api/datasources/proxy/uid/fullstack-ops-prometheus/api/v1/query`
üzerinden aynı gerçek selector'lar sorgulandı; yeni counter değerleri ve örnek
zamanları birlikte doğrulandı. Yalnız eski grafiğin görünmesi veya query response
evaluation timestamp'ı recovery/freshness kanıtı sayılmadı. Bu görevde kesinti veya
recovery deneyi yoktur. Sınırlı GET trafiğinin etkisi bir miss/beş hit ve sıfır yeni
invalidation olarak gözlendi; önceki6 invalidation tarihsel sayaç birikimidir.

### Grafana datasource, provisioning ve panel sorguları

- Datasource `fullstack-ops-prometheus`: type prometheus, URL
  `http://prometheus:9090`, default ve readOnly; health status OK: PASS.
- Dashboard `fullstack-ops-overview`, başlık FullStack Ops Lab Overview;
  meta.provisioned true, ID1–12 olmak üzere12 panel, refresh15s ve tüm target'larda
  sabit datasource UID: PASS.
- Provision edilen JSON'daki gerçek expr/refId/datasource alanlarıyla Grafana
  `/api/ds/query` çalıştırıldı. Instant/table sorguları için tüm refId yanıtları,
  HTTP200 ve nested result error/status kontrolleri PASS; hiçbir panelde sorgu hatası yok.

| Panel ID'leri | Gerçek instant sorgu gözlemi |
| --- | --- |
| 1, 2, 5, 6, 9, 10, 11, 12 | Her panelde bir sonlu sayısal örnek |
| 7 (hit ve miss rate) | İki sonlu sayısal örnek |
| 3 (5xx oranı), 4 (p95), 8 (hit oranı) | Her panelde bir null/nonfinite sayısal hücre; sorgu hatası yok |

Rate/p95 panelleri gerçek dashboard'un2m penceresini kullanır. Trafik kesildikten
sonra payda/observed request olmayan pencerede oran/p95 null veya NaN olabilir;
bu datasource hatası değildir. Grafana'nın null döndürdüğü hücrenin tam upstream
NaN biçimi ayrıca sınıflandırılmadı. Sıfıra dönüştürülmedi; sonlu örneğin varlığı da
tek başına pozitif trafik varmış gibi sunulmadı.

Kullanıcı Windows tarayıcısında
`http://127.0.0.1:23000/d/fullstack-ops-overview/fullstack-ops-lab-overview` açıp
API scrape başarısını, hit7/miss12/invalidation6 toplamlarını ve görünür kırmızı
hata olmadığını bildirdi. On iki panelin varlığı ve sorguları API kontrolleriyle
kanıtlandı; otomatik DOM/console/network veya her panelin tarayıcıda ayrı render
ölçümü bu görevde yapılmadı. Ekran görüntüsü veya yeni browser aracı eklenmedi.

### Bırakılan durum ve sınırlar

Yeni Task kaydı, migration, key silme/FLUSH, volume veya container oluşturma/
kaldırma, image build/pull/değiştirme ve uygulama/config değişikliği yapılmadı.
Liste GET normal mevcut cache davranışını kullandı; cache temizlenmedi. Stack
ve Windows tüneli çalışır bırakıldı; development Engine/verileri, .env ve
user-secrets değiştirilmedi. Başlangıç altı healthy kabulü sonrası ayrı bir final
inspect/env dökümü yapılmış gibi sunulmaz.

Bu adım asset ve monitoring kabulünü tamamlar. Önceki migration/HTTP-cache kanıtları
tarihleriyle korunur. Persistence recreate, HTTPS, update/rollback, yedekleme ve
kapanış henüz uygulanmadı. `release.json` birleşik tam-runtime durum alanı bu
dokümantasyon adımında değiştirilmedi; lab bütünüyle Completed işaretlenmez.
Sonraki küçük iş bu sonuçların incelenmesi, ardından ayrı yetkiyle planın yerel
HTTPS hazırlık adımıdır; bu görevde başlanmadı. Commit/push yapılmadı.

Repository son kontrolleri: secret leakage exit0, 49 yerel dosya/anchor bağlantısı
PASS ve git diff --check exit0. Yalnız deployment README, deployment planı ve
PROJECT_STATUS değişti; index boş, config/release/SHA/digest çifti aynı.
Uygulama/config değişmediği için yeni build veya VM runtime tekrarı yapılmadı.

## Yerel HTTPS dosya hazırlığı — 15 Ekim 2026

Bu bölüm ilk statik aşamanın tarihsel kaydıdır; Windows hazırlığının sonraki
sonuçları aşağıdaki ayrı bölümde yer alır.

[Somut yapılandırma ve terminale göre ayrılmış gelecek komutları](HTTPS.md)
incelemeye hazırdır. Önceki host Nginx önerisi yerine aynı frontend image'ında
read-only deployment Nginx config'i TLS sonlandırır. Yeni image/yedinci servis
yok; API/postgres/redis host portu açılmaz, monitoring loopback düzeni korunur.

Statik model5/5 PASS; TLS ancak üçüncü compose.https.yaml açıkça eklendiğinde
modele girer. İki dosyalı mevcut deployment ve development Compose davranışı
korundu. Şu an çalışan VM/frontend/tüneller değiştirilmedi. `nginx -t`, sertifika
üretimi, SAN/süre/key eşleşmesi, Windows CA güveni/hosts ve gerçek HTTPS/browser
kabulü NOT VERIFIED. HTTP→HTTPS redirect yok; HTTP teşhis ve mevcut healthcheck
ayrı kalır. Seçilmiş SHA/digest/release aynıdır; commit/push yapılmadı.

## Windows sertifika ve güven hazırlığı — 15 Ekim 2026

Bu bölüm b0d2fea ile kaydedilen Windows aşamasıdır; sonraki VM hazırlığı aşağıdadır.

Kullanıcı rehberli Windows PowerShell gruplarını uyguladı: mkcert1.4.4 indirme
hash/sürüm kontrolü, repository dışı lab CA/leaf üretimi ve CurrentUser Root
deposunda public CA thumbprint kontrolü PASS. OpenSSL3.5.6 ile tek SAN
tasks.fullstackops.test, lab CA zinciri/hostname/mevcut zamanda geçerlilik ve
leaf public/private key eşleşmesi PASS. Geçerlilik UTC15Ekim2026 10:59:05 →
15Ocak2029 10:59:05. Başlangıçta hosts kaydı yoktu; tek127.0.0.1 eşlemesi eklenip
dosya ve Windows ad çözümlemesiyle doğrulandı. Public hash'ler, kullanılan depo,
kanıt sınırı ve güven/hosts kaldırma yönergeleri [HTTPS kaydında](HTTPS.md#12-windows-ca-leaf-ve-hosts-kabulü--15-ekim-2026).

CA private key Windows'ta kaldı; hiçbir sertifika/key VM'ye aktarılmadı. Agent
private dosya/secret okumadı; kanıt kullanıcı çıktılarıdır. `.env.https`, nginx -t,
frontend recreate,18443 tüneli ve gerçek HTTPS/browser/CRUD kabulü bekliyor.
VM stack'i, mevcut tüneller ve seçilmiş image çifti değişmedi. Bu adım yalnız
Windows hazırlığıdır; deployment runtime bütünüyle Completed değildir.

## VM TLS aktarımı, izinler ve nginx -t — 15 Ekim 2026

Kullanıcı güncel172.30.249.139 IP'sinde SSH erişimini ve altı healthy servisi
doğruladı. Üç public HTTPS config dosyası yalnız mevcut kaynak ağacına eklendi;
Windows→VM checksum'ları üç OK. Yalnız leaf cert/key repository dışındaki
/home/labadmin/.local/share/fullstackops-deploy-lab/tls yoluna aktarıldı;
CA private key Windows'ta kaldı. Üst klasör/tls700, key600, crt644 ve yalnız path
içeren ayrı .env.https600 sahibi labadmin olarak doğrulandı. Mevcut deployment env
ezilmedi. [Hash'ler ve ayrıntılı kabul tablosu](HTTPS.md#13-vm-tls-aktarımı-ve-geçici-nginx--t-kabulü--15-ekim-2026).

Gerçek env ile sessiz config ve JSON model kontrolleri PASS: altı servis, aynı
seçilmiş source/digestler/build yok, aynı ağ/ayrı volume adları, üç read-only
bind/create_host_path false ve yalnız beklenen loopback portları. Mevcut HTTP
healthcheck korundu. Seçilmiş frontend digestinin local image kimliği çalışan
frontend ile eşleşti. Aynı image/model ile geçici nginx -t exit0; iki başarı
mesajı yakalandı, test container'ı temizlendi ve altı container ID'si korundu.

Final gerçek tabloda altı servis healthy; frontend hâlâ127.0.0.1:18081,
monitoring19090/13000 loopback, internal servisler publish edilmemiş durumda.
ss18443 listener yok. Bu, henüz etkinleştirilmemiş TLS modelindeki18443 bind'iyle
karıştırılmaz. Agent VM işlemi/secret okuması yapmadı; kanıt kullanıcı çıktılarıdır.
Stack/tüneller çalışır bırakıldı, source/digest/release değiştirilmedi; yeni build,
migration, CRUD, cache temizleme veya volume işlemi yok. Frontend TLS recreate,
yeni SSH tüneli ve HTTPS/browser/API kabulü bekliyor. Commit/push yapılmadı.

## Yerel HTTPS etkinleştirme ve kabul — 15–16 Ekim 2026

Bu bölüm önceki hazırlık kayıtlarının devamıdır. Kullanıcı gerçek komut sonuçlarını
paylaştı; agent VM'ye bağlanmadı, private key/env okumadı. Başlangıç HEAD a5fb235
ve Git temizdi. [HTTPS kanıt tablosu ve komutlar](HTTPS.md#14-https-etkinleştirme-ve-runtime-kabulü--1516-ekim-2026).

Gerçek env config -q ve geçici nginx -t exit0 sonrasında yalnız frontend,
üç Compose/iki env dosyasıyla `up -d --no-build --no-deps --pull never --wait`
kullanılarak yeniden oluşturuldu. Selected frontend ref/local image/container
Image kimlikleri release.json digest'iyle eşleşti. Üç gerçek bind read-only;
CA private key Windows'ta kaldı. HTTP127.0.0.1:18081 GET200/text/html korunurken
HTTPS yalnız VM127.0.0.1:18443→443 üzerinde açıldı. Kaynak
1b52633776279b1661a7cac53392d385cbf10444 ve iki GHCR digest'i değiştirilmedi.

Windows127.0.0.1:18443 SSH tüneliyle `https://tasks.fullstackops.test:18443/`
erişimi doğrulandı. Pencereler kapandıktan sonra 16 Ekim'de IP172.30.249.139 ve
aynı altı healthy container SSH ile kontrol edilip yalnız tünel tekrar açıldı;
Hyper-V konsolunun yanıt vermemesi için VM/Docker restart yapılmadı, nedeni
belirlenmedi. Tarayıcı sertifika uyarısı vermedi; görülen mkcert CA/leaf ve
geçerlilik tarihleri önceki Windows kaydıyla uyumlu. Gerçek HTTPS JS/CSS200,
manuel Network/Console gözleminde hata/mixed-content yok. Otomatik browser
testi veya HTTPS asset MIME başlıklarının ayrı doğrulaması iddia edilmez.

Varsayılan Schannel curl8.21.0 önce CRYPT_E_NO_REVOCATION_CHECK/exit35/HTTP000
verdi. Public leaf hash'i aynı, CRL/AIA bilgisi yoktu. Yalnız komuta ait
`--ssl-revoke-best-effort` ile HTTP200/VERIFY0/IP127.0.0.1/exit0 alındı;
zincir/hostname/geçerlilik korunur, iptal durumu **NOT VERIFIED**. -k/insecure,
genel güvenlik değişikliği veya browser uyarısı atlama kullanılmadı.

| HTTPS contract kontrolü | Gerçek sonuç |
| --- | --- |
| Liste / tekil GET | 200; liste application/json; charset=utf-8 |
| POST ve Location | 201, test ID3, /api/tasks/3; aynı HTTPS origin/18443'e doğru çözüm |
| JSON ve PUT | Altı alan; null description; PUT200, title/isCompleted güncellendi, createdAt aynı/updatedAt ilerledi; tekrar GET200 |
| Negatif durumlar | Boş title POST400/PUT400; bulunmayan ID GET404; test görevi değişmedi |
| Test temizliği | Benzersiz başlık/ID/createdAt kontrolüyle yalnız ID3 DELETE204/boş gövde; sonra GET404 |

Liste kontrolündeki ilk regex, geçerli charset parametresini yanlış reddetti;
assertion düzeltildi, başarılı HTTP200 uygulama hatası sayılmadı. Başka kayda
silme isteği, elle cache temizleme, FLUSH, migration veya volume işlemi yapılmadı.
Geçici nginx test container'ı ve istemci payload/response/header dosyaları temizlendi.

Son inspect: frontend e401eb7fbff5, api4d572817ca12, postgres e9296c518548,
redis d98d34cc73c5, prometheus84eaf1ceebb5, grafana ed9398e62129; altısı running/healthy.
Diğer beş ID başlangıçla aynı. Frontend18081/18443, Prometheus19090 ve Grafana13000
yalnız VM127.0.0.1; internal üç servis PortBindings={} olarak kaldı. Monitoring
ID/health/port korunması yeni datasource/panel sorgu kabulü değildir; 15 Ekim
kanıtı ayrı kalır. Stack ve HTTPS tüneli açık bırakıldı; development kaynakları,
secret'lar ve seçilmiş release değişmedi. Bu adım yalnız yerel HTTPS kabulüdür;
public domain/internet/production veya deployment lab bütünü için tamamlanma yok.
Sonraki öneri ayrı yetkiyle deployment PostgreSQL recreate kalıcılık kabulüdür;
henüz uygulanmadı. Commit/push yapılmadı.

## PostgreSQL recreate kalıcılık kabulü — 16 Ekim 2026

Bu kayıt, fe8c5b88ac0d98d7d185e9aabb4871d7c562ec20 üzerindeki temiz ana çalışma
alanından başlayan, kullanıcı tarafından yürütülen VM/Windows deneyidir. Agent
VM'ye bağlanmadı veya development/gerçek env/user-secrets/private key okumadı.
Mevcut üç Compose dosyası ve iki env kaynağı korundu; API/frontend için seçilmiş
`1b52633776279b1661a7cac53392d385cbf10444` kaynak SHA'sı ve
[release.json](release.json) digest çifti değişmedi. HTTPS'in Schannel best-effort
iptal kontrolü sınırı [önceki kabuldeki](HTTPS.md#14-https-etkinleştirme-ve-runtime-kabulü--1516-ekim-2026)
gibi geçerlidir; yeni bir sertifika/browser kabulü iddia edilmez.

### Başlangıç, aynı image/volume ve recreate

Başlangıçta altı container running/healthy; yalnız amaçlanan loopback portları
yayındaydı. PostgreSQL project/service etiketleri fullstackops-deploy-lab/postgres,
Type=volume, Name=fullstackops-deploy-lab-postgres ve
Destination=/var/lib/postgresql olarak doğrulandı. Çalışan container Image ve
yerel postgres:18-alpine tag'inin image kimliği aynıydı:
`sha256:77f585114c32fbca283dc835b0596f4e52b51b4c6662d7810b2f4084f60a1873`.
Bu değer PostgreSQL'in yerel runtime image kimliğidir; API/frontend GHCR manifest
digest'leriyle karıştırılmaz. Tag'in mutable olması nedeniyle kimlik, işlemden
hemen önce tekrar kontrol edildi ve pull engellendi.

Salt okunur psql transaction'ında UTC saat dilimiyle altı Task sütununu kapsayan
satır özeti alındı: count=0, ids=[], SHA256
`e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855`.
Tek history kaydı 20260928113912_InitialCreate / EF10.0.12 idi. Socket/trust psql
erişimi yalnız envanter içindi; yeni TCP parola doğrulaması olarak sunulmaz.

Windows HTTPS tünelinin 127.0.0.1:18443 listener'ı ve ssh process sahibi kontrol
edildi. Benzersiz `Deployment persistence 3fac6e980e3e4dbfa8f5ca405e2a8b37` test
görevi POST201 ile ID4 olarak oluşturuldu, Location=/api/tasks/4 doğrulandı.
Altı alanlık yanıt yalnız Windows TEMP altında bu deneye ait JSON snapshot'a
kaydedildi. Recreate öncesi HTTPS tekil GET200 ile her alan bu snapshot'a eşitti.

Container/image/mount başlangıç eşleşmeleri ve sessiz config -q geçtikten sonra
Ubuntu SSH terminalinde yalnız şu servis yeniden oluşturuldu:

```bash
sudo docker compose --project-name fullstackops-deploy-lab \
  --env-file .env.deployment --env-file .env.https \
  -f compose.yaml \
  -f infrastructure/deployment/compose.deploy.yaml \
  -f infrastructure/deployment/compose.https.yaml \
  up -d --no-build --no-deps --force-recreate --pull never \
  --wait --wait-timeout 90 postgres
```

Bu komut gelecekte körlemesine tekrar çalıştırılmaz: önce mevcut container ID,
çalışan/local image kimliği, volume/mount ve env/overlay hedefleri kontrol edilir.
PostgreSQL sağlıklı bekleme sonucu 5.9s idi; bu API kesinti süresi ölçümü değildir.

| Kontrol | Gerçek sonuç |
| --- | --- |
| Eski PostgreSQL ID | e9296c518548626d194cc05ed28afa0e258287cd0e5d5e7acd6a1d5388c36479 |
| Yeni PostgreSQL ID | b67a87f2d83ffc7119262239f0bc48d8b2bf141aca9f84b1f4b55d62e173f7f9 |
| Image | Önce/sonra aynı 77f585114c32... yerel image ID; build/pull yok |
| Mount | Önce/sonra volume/fullstackops-deploy-lab-postgres → /var/lib/postgresql |
| PostgreSQL son durum | running/healthy; PublishedPorts={} |
| API readiness | Frontend container'ından internal http://api:8080/health/ready HTTP200; SPA fallback kullanılmadı |
| API lifecycle | Aynı 4d572817ca12... container, running/healthy, RestartCount=0; API restart yapılmadı |
| Kalıcılık kanıtı | HTTPS GET /api/tasks/4 HTTP200; snapshot ile altı alan birebir aynı |

### Korunan test alanları ve diğer servisler

| JSON alanı | Recreate öncesi ve sonrası |
| --- | --- |
| id | 4 |
| title | Deployment persistence 3fac6e980e3e4dbfa8f5ca405e2a8b37 |
| description | null |
| isCompleted | false |
| createdAt | 2026-10-16T10:42:50.816497+00:00 |
| updatedAt | 2026-10-16T10:42:50.816497+00:00 |

[Tekil GET implementasyonu](../../src/backend/FullStackOpsLab.Api/Program.cs)
AsNoTracking/SingleOrDefaultAsync ile PostgreSQL'den okur. Liste cache hit'i
kalıcılık kanıtı olarak kullanılmadı. Her iki GET'te de tam altı alan ve her
alanın değeri karşılaştırıldı; yalnız HTTP200 veya aynı title yeterli sayılmadı.

| Servis | Korunan container ID başlangıcı | State / health / RestartCount | VM host bind |
| --- | --- | --- | --- |
| frontend | e401eb7fbff5 | running / healthy / 0 | 127.0.0.1:18081→80,127.0.0.1:18443→443 |
| api | 4d572817ca12 | running / healthy / 0 | Yok |
| redis | d98d34cc73c5 | running / healthy / 0 | Yok |
| prometheus | 84eaf1ceebb5 | running / healthy / 0 | 127.0.0.1:19090→9090 |
| grafana | ed9398e62129 | running / healthy / 0 | 127.0.0.1:13000→3000 |

Yeni PostgreSQL de running/healthy/RestartCount=0 idi. RestartCount'un 0 olması
container recreate yapılmadığı anlamına gelmez; PostgreSQL değişimi eski/yeni
container ID'leriyle kanıtlandı. Diğer beşinin ID'leri başlangıçla aynı kaldı.

### Temizlik, kabul sınırı ve öğrenme

Silmeden önce ID/title/createdAt ve snapshot'ın altı alanı tekrar eşleştirildi;
yalnız test Task4 DELETE204/boş gövde ile silindi, tekil GET404 doğrulandı.
Sadece bu testin Windows snapshot/payload/response/header dosyaları temizlendi.
Son READ ONLY sorgusu başlangıçla aynı count=0/ids=[]/SHA256 ve HISTORY_COUNT=1,
aynı InitialCreate/EF10.0.12 sonucunu verdi. **Başlangıçta başka Task yoktu**;
dolu bir başlangıç dataset'inin korunması ayrıca denenmiş gibi sunulmaz.
Satır hash'i fiziksel database, şema veya sequence durumunun byte eşitliği
değildir; ID sayacını geri alma/sıfırlama komutu çalıştırılmadı.

Ölçülen isteklerde hata yoktu: önce/sonra tekil GET200, son readiness200.
Ancak recreate penceresinde sürekli API/liveness/readiness/Docker health takibi
yapılmadı; geçici 5xx/503 veya unhealthy oluşmadığı **NOT VERIFIED**. Aynı API'nin
RestartCount=0 ve sonraki başarılı DB okuması toparlanmanın API restart ile
gizlenmediğini gösterir; sıfır kesinti veya retry politikasının kapsamlı kabulü
değildir. Yeni migration, rollback, backup/restore veya monitoring sorgusu yok.

Named volume container'dan ayrı yaşar: yeni PostgreSQL aynı veri dizinini
bağlayınca şema/history ve test kaydı erişilebilir kaldı. Container recreate,
image sürüm yükseltme ve yedekten restore farklı deneylerdir. Bu görev yalnız
ilkini doğrular. Volume silinmedi/sıfırlanmadı, down -v/prune kullanılmadı;
credential, TLS config, seçilmiş release ve development kaynakları değiştirilmedi.
Stack ve SSH tünelleri çalışır bırakıldı. Plan adım6'nın kalıcılık kısmı PASS;
15 Ekim monitoring kanıtı ayrı tarihle geçerlidir. Sıradaki öneri yalnız ayrıca
istenirse plan adım7'nin güncelleme/rollback hazırlığıdır; henüz başlanmadı.
Deployment final kabulü ve manuel öğrenme kapanışı tamamlanmadı;
release.json içindeki birleşik vm_pull_and_runtime_acceptance durumu bu dar
kabul adımında güncellenmedi. Commit/push yok.

Repository belge kontrolleri: secret leakage kontrolü exit0,67 yerel belge
bağlantısı/anchor ve git diff --check PASS. Yalnız bu README, deployment planı ve
PROJECT_STATUS değişti; index boş, yeni dosya yok. Uygulama/Compose/TLS/release
değişmediğinden build veya yeni runtime deneyi yapılmadı. Kanıtlar kullanıcı
tarafından yürütülen yukarıdaki deneye aittir; development kaynaklarına işlem
gönderilmedi, snapshot ve gerçek env/SQL/key dosyaları repository'ye eklenmedi.

## Güncelleme/rollback release hazırlığı — 16 Ekim 2026

Başlangıç main/69fe741 ve çalışma alanı temizdi. Aktif release.json ve ilk üç
Compose dosyası korunarak [ayrı rehber](UPDATE-ROLLBACK.md) hazırlandı.
A kaynak1b52633776279b1661a7cac53392d385cbf10444/digest çifti dönüş hedefidir.
B kaynak69fe741fba69de8834789cc2e657fedbb5e6c3dd için başarılı run38890534827,
iki publishing job'ı ve registry manifest/config SHA256/revision/source/linux-amd64
salt okunur doğrulandı. Tam iki çift [release kaydında](releases/update-rollback.json).

Backend/frontend source tree, migration/model/paket/API/config/Dockerfile,
ana Compose ve monitoring aynı; yeni şema veya migration gerekmez. Yeni kullanıcı
özelliği yok. Image'lar yalnız metadata farkı değil: layer/rootfs değişmiş;
config'te .NET/ASP.NET10.0.12→10.0.13, Nginx1.30.5→1.30.6 ve NJS1.0.1→1.0.2
doğrulandı. Mutable base tag rebuild farkı runtime kabulünü gerekli kılar;
tam binary/package audit yapılmadı.

Statik testler önce eksik selector dosyalarında beklenen iki hata verdi; ardından
7/7 PASS. Gerçek Compose parser/sahte env ile A modeli korunuyor, B yalnız iki
image'ı değiştiriyor, A tekrar başlangıç modelini sağlıyor. VM B pull/nginx -t,
A→B→A, aynı kaydın korunması ve HTTPS/CRUD kabulü **NOT VERIFIED**. Plan API sonra
frontend recreate içerir; Nginx upstream DNS yenilenir. Diğer dört servise işlem,
migration veya volume temizliği yok. Bu görevde VM/Engine kaynağına erişilmedi;
gerçek env/user-secrets/TLS okunmadı, yeni yayın/commit/push yapılmadı.

## B image aktarımı ve Nginx ön kontrolü — 17 Ekim 2026

Kullanıcı Windows/Ubuntu SSH komutlarıyla [bölüm8'deki ön kontrolü](UPDATE-ROLLBACK.md#8-rehberli-vm-aktarımı-b-image-ve-nginx-kontrolü--17-ekim-2026)
tamamladı. Başlangıç repository9371046/Git temiz; VM172.30.249.139 ve altı
healthy servis/A image kimliği doğrulandı. Yalnız UPDATE-ROLLBACK.md ve üç
releases/ public dosyası mevcut hedeflerin yokluğu kontrolünden sonra SCP ile
aktarıldı; dört Windows/VM SHA256 eşleşti. Bu kayıt eklenince yerel rehber
değişmiştir; kaydedilen hash aktarım anına aittir. Env/TLS/kaynak ağacı ezilmedi.

B API/frontend exact digest pull ve sonraki RepoDigests/source69fe741/linux-amd64
inspect PASS; A source1b52633 çiftinin iki local referansı da korundu. Tam
kimlikler [release kaydında](releases/update-rollback.json). Gerçek deployment/TLS
env ile mevcut HTTPS/A/B config-q PASS; A modeli aynı, B yalnız API/frontend
image'larını değiştiriyor; build yok, port/env/mount/ağ/volume hedefleri aynı.

İlk Compose run nginx-t denemesi 90s/exit124 ile başarısızdı; test container'ı
temizlendi. Aynı B frontend digest'i, üç gerçek read-only bind ve app ağıyla
doğrudan Docker create ve start --attach aşamaları ayrı30s sınırda PASS;
syntax is ok/test is successful mesajları kontrol edildi. Bu farklı tanı başarılı
oldu; ilk timeout'un aşaması/kök nedeni NOT VERIFIED. Geçici iki test container'ı
kalmadı. B API başlatılmadı; çalışan frontend değişmedi ve test port yayınlamadı.

Son altı ID başlangıçla aynı; running/healthy/RestartCount0. API/frontend hâlâ A;
frontend18081/18443, monitoring19090/13000 yalnız VM loopback, internal üç serviste
host portu yok. Stack çalışır bırakıldı; tünellere işlem yapılmadı, Windows
listener'ları yeniden ölçülmedi. Task/SQL/migration/recreate/cache temizliği veya
volume silme yok. Agent VM'ye bağlanmadı/private dosyaları okumadı; development
kaynakları, env/TLS ve seçilmiş A/B kayıtları korunuyor. A→B→A, aynı kaydın
korunması/HTTPS kabulü/kesinti ölçümü ve backup/restore/final lab bekliyor.

## A→B→A runtime kabulü — 17 Ekim 2026

Bu bölüm önceki ön kontrolü izleyen ayrı görevdir. Temiz main/HEAD
`cd11b47c842f524e108c91c9046df165ce847256` ile başladı; kullanıcı komutları
Windows PowerShell/Ubuntu SSH'de çalıştırıp çıktıları paylaştı. Agent VM'ye
bağlanmadı veya gerçek secret dosyalarını okumadı. Seçilmiş A source1b526337 ve
B source69fe741 çiftleri [aynı release kaydında](releases/update-rollback.json);
aktif release.json A kaldı. Bu JSON 16 Ekim hazırlık anının metadata kaydıdır;
güncel runtime sonucu [rehber bölüm9'dadır](UPDATE-ROLLBACK.md#9-rehberli-aba-runtime-kabulü--17-ekim-2026).

- Başlangıç altı healthy/A; read-only count0/IDs[]/boş satır SHA256 ve tek
  InitialCreate/EF10.0.12 history. VM172.30.249.139:18443 loopback LISTEN;
  Windows'ta eksik HTTPS tüneli yalnız localhost18443 için yeniden açıldı,
  listener sahibi ssh ve HTTPS200/VERIFY0 doğrulandı. Diğer tünellere müdahale yok.
- Sahipli kalıcılık görevi ID5 POST201/relative Location; altı alan snapshot'ı
  Windows TEMP'te. A başlangıç, B ve A dönüşünde doğrudan DB tekil GET200 ile aynı
  ID/title/description/isCompleted/createdAt/updatedAt; bu görev güncellenmedi.
- Dört-file Compose, iki env kaynağı, aynı project/HTTPS; her geçişte
  `--no-build --no-deps --force-recreate --pull never --wait --wait-timeout 90`.
  Önce API, internal readiness200 sonrası frontend. A→B API5.966s/frontend6.142s;
  B→A API5.975s/frontend6.103s; hepsi exit0, dış120s timeout False. Bunlar komut
  süreleridir; sürekli probe ve gerçek kesinti süresi ölçülmedi.
- B ve A dönüşünde exact ref/localId/container.Image/revision/linux-amd64,
  altı healthy/RestartCount0 ve internal live/ready200. Frontend içinden API'ye
  gidildi; Nginx SPA health yanıtı veya liste cache'i kanıt sayılmadı.
- İki aşamada HTTPS HTML200/text-html, HTML'in referans verdiği gerçek
  JS200/application-javascript ve CSS200/text-css. Kullanıcı tarayıcıda sertifika
  uyarısı/Console hatası olmadığını bildirdi; otomatik browser testi yapılmadı.
  Schannel best-effort kullanıldı; sertifika iptal durumu kanıtlanmadı.
- Ayrı B CRUD ID6 ve A CRUD ID7: POST201/doğru HTTPS Location, GET/PUT/GET200,
  altı alan/null description, title/completion güncellemesi, createdAt aynı ve
  updatedAt ilerledi. Boş title POST/PUT400, bulunmayan ID GET404; negatif
  kontroller kaydı değiştirmedi. Sahiplik kontrolü sonrası DELETE204/boş body ve
  GET404; her CRUD sonunda ID5'in altı alanı hâlâ aynı.
- Finalde API8b3d9f24f627/frontend15a93fef4000 yeni A container'ları;
  postgres b67a87f2d83f/redis d98d34cc73c5/prometheus84eaf1ceebb5/grafana
  ed9398e62129 başlangıç ID/image'larıyla aynı. Frontend18081/18443,
  Prometheus19090, Grafana13000 yalnız VM127.0.0.1; internal üç serviste bind yok.
- ID5 son kez doğrulanıp DELETE204/GET404 ile temizlendi. Final
  13:52:25.120940 UTC read-only state başlangıçla aynı: count0/IDs[]/boş satır
  SHA256, history count1/aynı InitialCreate/EF10.0.12; aynı PostgreSQL volume/mount.
  Yalnız deneyin Windows/Ubuntu geçici klasörleri kontrollü silindi; kullanıcı
  cleanup PASS çıktılarını paylaştı. Stack ve HTTPS tüneli A'da açık bırakıldı.

Başlangıçta başka Task yoktu; dolu dataset/sequence/physical DB eşitliği veya
backup/restore iddiası yok. Başarılı B'den planlı A dönüşü yapıldı; başarısız
güncelleme enjekte edilmedi. Önceki Compose/nginx-t exit124 nedeni çözülmedi.
Development env/user-secrets/veri, release/digestler, TLS ve volume'lar korundu;
build/pull/yayın/migration/FLUSH/prune yok. Monitoring kabulü yeniden koşulmadı.
Plan adım7 tamamlandı; adım8 yedek/restore ve adım9 kapanış bekliyor. Bu yerel VM
deneyi production/internet/benchmark veya manuel öğrenme PASS değildir.
Commit/push yapılmadı.

## İzole yedek/restore hazırlığı — 18 Ekim 2026

Temiz main/4a11d0c6684b10e4fdf94b21127af9901be21c5f üzerinde yalnız hazırlık.
[Rehber](BACKUP-RESTORE.md) çalışan source container'ın kendi PostgreSQL18
pg_dump aracıyla custom mantıksal yedek, Git dışı700/600 saklama ve Windows'a
ikinci SCP kopyası/SHA256 karşılaştırmasını tarif eder; canlı volume kopyalama yok.
Kaynak PostgreSQL'in runtime'da yeniden doğrulanacak tam yerel ImageID'si restore
için seçilir; mutable tag pull, A uygulama digest değişikliği veya build yok.

Tek başına compose.restore.yaml farklı RUN_ID/project/container/internal network
ve yeni Compose-managed volume kullanır; host portu veya source mount yok.
Yeni restore credential'ı Git dışında; no-owner/no-privileges hedef role ownership
verir, kaynak role parolaları yedeğe/config'e kopyalanmaz. Arşiv Task verisi ve
owner adları içerebilir; hassas kabul edilir. Dump/JSON/env/log Git'e eklenmez.

Kabul boş DB ile geçmez: benzersiz HTTPS sentinel ve altı alan, tam row hash,
şema/identity ve migration history karşılaştırması; hedefte yeni INSERT ile
ID>max/çakışmasız sequence kontrolü, sonra rollback/satır eşitliği planlandı.
Sequence değeri transaction rollback ile geri alınmaz; yalnız geçici hedefte
tüketilir. Restore kaynaklarının label kontrollü temizliği ve deployment'ta
yalnız sahipli sentinel DELETE204/GET404 ayrı adımlar; tamamlanmış backup setleri
korunur. Mevcut Tasks/history ve altı container başlangıç/final karşılaştırılır.

Günlük02:00/son yedi başarılı günlük set önerisi var; job kurulmadı. VM kapalı
veya Windows kopyası eskiyken24h RPO garanti edilmez; aynı host ikinci kopyası
off-site değildir. Runtime dump/restore/sequence/cleanup ve zamanlama NOT VERIFIED.
Yeni statik test4/4 PASS; öncesinde eksik dosya/ignore için beklenen RED görüldü.
VM/development kaynağına bağlanılmadı; veri/credential/TLS/image değişikliği,
yedek alma veya kaynak oluşturma/silme yok. Sonraki görev yalnız ayrıca istenirse
güncel VM envanteri ve public restore dosyalarının aktarım ön kontrolüdür.
Yedek/restore ve final deployment lab kabulü henüz tamamlanmadı; commit/push yok.

## Yedek/restore VM envanteri ve public aktarım — 18 Ekim 2026

Kullanıcının rehberli SSH/PowerShell çıktılarıyla [ön kontrol PASS](BACKUP-RESTORE.md#11-vm-envanteri-ve-public-aktarım--18-ekim-2026).
Başlangıç temiz main/5a00317614354d8c4377918d32d0def4432ee05f. VM172.30.249.139,
Linux Engine ve aktif A exact ref/ImageID/revision doğrulandı. Altı container
başlangıç/finalde aynı kimliklerle healthy; aynı üç volume listesi ve ağ kimlikleri
korundu. Source PostgreSQL18.6/server/pg_dump/pg_restore, linux/amd64 yerel
ImageID77f585114c32..., deployment volume → /var/lib/postgresql eşleşti. Container
ayarlarıyla database/role eşleşmesi salt okunur sorgulandı, isim/parola yazdırılmadı;
bu socket sorgusu TCP parola doğrulaması değildir. Database7976639 byte.

VM Git dışı backups-private kökü henüz yok/43,30 GiB boş; Windows LOCALAPPDATA
Git/OneDrive dışı kök henüz yok/432,09 GiB boş. İzinler ve gerçek dump boyutu/kopyası
henüz doğrulanmadı. Dört yok-hedefe yalnız BACKUP-RESTORE.md, compose.restore.yaml,
restore.env.example ve statik test SCP ile aktarıldı; SHA256 dört OK. Rehberin
aktarılan hash'i bu son kayıt öncesine aittir. Kaynak/env/TLS/release topluca ezilmedi.

RUN_ID4756810b5b43 için ayrı restore project/container/network/volume isimleri ve
project etiketi boş; rezerve edilmedi, uygulama öncesi tekrar kontrol edilmeli.
Kaynak local PG ImageID kullanılacak; deployment volume'u hedef olmayacak.
Restore env, Task, dump, hedef kaynak veya backup klasörü oluşturulmadı; pull/build,
recreate/migration/silme/zamanlama yok. Tünellere işlem yapılmadı; Windows erişimi
yeniden ölçülmedi. Agent VM'ye bağlanmadı/private dosya okumadı. Dump/ikinci kopya,
restore/sequence/cleanup ve final deployment kabulü NOT VERIFIED kalır.

## Mantıksal dump ve Windows ikinci kopyası — 19 Ekim 2026

Başlangıç temiz main/3514d9bd361dbe68ccf4964a607c59405771fbbd. Rehberli kullanıcı
komutlarının [ayrıntılı kanıtı](BACKUP-RESTORE.md#12-mantıksal-dump-ve-windows-ikinci-kopyası--19-ekim-2026)
ayrı kaydedildi. VM172.30.249.139/aktif A exact digest/revision ve source PG mount'u
doğrulandı. Eksik Windows HTTPS tüneli yalnız loopback18443 için yeniden açıldı;
manuel browser uyarısız açıldı. POST201/ID8/relative Location doğru HTTPS originine
çözüldü; tekil DB GET200/JSON ile altı alan/null description/false completion aynı.
Schannel best-effort revocation sınırı değişmedi; yeni otomatik browser kabulü yok.

VM Git dışı backups-private/4756810b5b43 kök/run700, dosyalar600; ayrı güçlü restore
env600 üretildi, tek servis/no-build/pull-never/no-port/ayrı ağ-yeni volume modeli
gerçek env ile parse edildi. Restore servisi/volume/network oluşturulmadı.
Windows LOCALAPPDATA/FullStackOpsLab/backups-private/4756810b5b43 kök/run klasörleri
inheritance kapalı/current-user FullControl; kopya dosyalarının sahibi ve Allow
erişimi yalnız mevcut hesap. İzinler şifreleme veya off-site koruma değildir.

READ ONLY baseline11:34:24.809352UTC count0/IDs[]/tek InitialCreate EF10.0.12.
ID8 sonrası source.before11:39:53.232320 ve source.after11:44:24.411327UTC count1/
IDs[8], tam satır hash/altı alan/history aynı; ayrı snapshot'lar pg_dump ile ortak
transaction değildir. Source18.6 server/pg_dump/pg_restore; custom pg_dump exit0/
boş stdout-stderr; yalnız container /tmp dosyası üretildi, canlı volume kopyalanmadı.
Docker cp/partial600 ve kaynak/VM SHA256; pg_restore --list exit0/tasks-data/history/
sequence kaydı; hash tekrar kontrolü sonrası database.pgdump3578 byte tamamlandı.
SHA256 f4eeadd74cacdf90ec68024117e9d015d8008531865a3b4ad8e5556ef0fcb687.

Manifest SHA2564b29c61a0ea8022f56671f7103cdc92e106c99421820ebfee8baa61c924f38db;
manifest+11 dosya Windows'ta boyut/hash eşleşti. Snapshot zaten aynı olduğundan
korundu,10 dosya SCP ile alındı. Windows kabul11:59:45.3912258UTC ve private
windows-copy-verified.json; env/credential/TLS/CA/ham log Windows'a kopyalanmadı.
İlk genel son kontrol RuntimeError nedeni belirsiz; sınırlı tanı ve ayrı son
kontroller başarılı oldu, dump/stack tekrar çalıştırılmadı. Final12:08:48.906339UTC
READ ONLY ID8/altı alan/history/hash aynı; VM dosyalarının hash/izinleri korundu.
Altı container aynı kimliklerle healthy ve üç volume aynı; restore kaynağı yok.

**ID8 ve iki tamamlanmış backup seti bilerek saklandı; silme/cleanup yapılmadı.**
Kaynak /tmp dump'ı da bu adımda silinmedi. Aktif A/release/HTTPS/env/TLS/development
korundu; yeni image/migration/volume veya zamanlama yok. Restore/şema/history/
sequence/owned cleanup ve final lab sonraki ayrı kabuller; --list/hash gerçek
restore kanıtı değildir. Windows aynı fiziksel hostta, günlük RPO garanti edilmez.
Agent VM/private dosyaları okumadı; yalnız dört belge değişti, commit/push yok.

## İzole restore ve sequence kabulü — 19 Ekim 2026

Temiz main/76bdb2c638967dadd3206cf1103ef9453e1c5667 üzerinden kullanıcı Ubuntu
SSH komutlarını gruplar halinde çalıştırdı; [ayrıntılı kabul tablosu ve korunan
kaynaklar](BACKUP-RESTORE.md#13-izole-restore-ve-sequence-kabulü--19-ekim-2026).
Agent VM'ye bağlanmadı/private dosya okumadı. Kaynak ID8, dump ve Windows
kopyası tekrar üretilmedi; aktif A/release/HTTPS/env/TLS/development aynı kaldı.

RUN_ID4756810b5b43 için ad/etiket yokluk kapısı ve gerçek env/config-q/model
geçti. Kaynakla aynı yerel linux/amd64 PostgreSQL ImageID77f585114c32.../18.6;
yalnız restore servisi no-build/no-deps/pull-never ile başlatıldı, exit0/no timeout,
5.828s. Yeni local volume fullstackops-restore-4756810b5b43-postgres →
/var/lib/postgresql; tek üyeli internal fullstackops-restore-4756810b5b43-net,
host portu yok. Hedef container90c817d6a25b.../healthy; doğru restore_lab role/
database/server ve sıfır public tablo önce salt okunur doğrulandı. Bu sorgu yeni
TCP authentication kabulü değildir.

Kayıtlı hedef/mount/ağ/image ve dump/manifest hash kapısından sonra pg_restore
--exit-on-error --single-transaction --no-owner --no-privileges --no-password,
binary stdin/180s sınır: exit0/no timeout,0.114s, stdout/stderr0 byte. Bu tek
komut süresi RTO veya kaynak deployment kesinti ölçümü değildir.

13:54:27.572348UTC restore count1/IDs[8], tam satır SHA256
2ad79064002470f10e0f42391519d82308a449f4bf5bd7de8825b682aee6fe3d ve tek
InitialCreate/EF10.0.12 history source.before/source.after ile aynı. Altı alan
Windows HTTPS snapshot'ıyla eşit; null ve aware UTC zamanları korundu.
13:55:49.327273UTC kataloglarda Task6 sütun/tip/nullable/default, BY DEFAULT
identity/PK, history sütunları/PK eşit; hedef tablolar restore rolüne ait.
Karşılaştırılan yapı SHA2563fbbbd404decc8ab7908aad214a3ebde5610ec61b4cb068028eeb9b3a95143bc.

13:57:47.837576UTC yalnız restore'da id belirtilmeden9>max8 üretildi. Probe
satırı ROLLBACK, veri/hash/history yine aynı; source sequence8/true, restore9/true.
Sequence tüketimi rollback ile geri alınmaz; kaynakta INSERT/nextval/setval yok.
13:59:00.616526UTC kaynak altı tam container ID/image aynı, healthy/RestartCount0,
A çifti ve kaynak PostgreSQL volume/mount aynı; restore da healthy kaldı.
14:00:06.805475UTC kaynak READ ONLY ID8/altı alan/hash/history/sequence değişmedi;
dump3578/manifest2511/sentinel223 byte hash/600, private klasör700/env600 tekrar PASS.

**Temizlik bu görevde yapılmadı.** Restore project fullstackops-restore-4756810b5b43,
aynı önekli -postgres container/volume ve -net ağ ile kaynak ID8 bırakıldı.
Tamamlanmış VM/Windows backup setleri, source /tmp dump ve private restore
kanıtları korunuyor; Git'e alınmadı. Orijinal manifest'in stage ve tarihsel
restore_status=NOT VERIFIED bilgisi değiştirilmedi; yeni kabul ayrı kayıtlarda. Windows kopyası
bu oturumda yeniden aktarılmadı/ölçülmedi. Yeni API/browser/monitoring testi yok;
mevcut stack/tünellere işlem yapılmadı.

İzole restore ve sequence teknik kapıları geçti; sahipli cleanup ayrıca istenecek.
Günlük timer/retention/failure kontrolü/RPO garantisi ve deployment final kabulü
açık. Aynı host/tek sahte kayıt deneyi off-site veya production kurtarma kabulü
değildir; önceki exit124/RuntimeError nedenleri çözülmüş sayılmaz. Commit/push yok.

## Kontrollü temizlik ve yedek koruması — 20 Ekim 2026

Kullanıcı ayrı cleanup görevi istedi; önceki dört modified belge korundu.
[Gerçek kontrol/komut tablosu ve UTC zamanları](BACKUP-RESTORE.md#14-kontrollü-temizlik-ve-yedek-koruması--20-ekim-2026)
rehberdedir. Ubuntu SSH VM172.30.249.139/hostname ve mevcut yedi container
doğrulandı. Restore etiketleri/mount/ağ kimliği, tek volume kullanıcısı ve tek
internal ağ üyesi doğru; kaynak PostgreSQL volume'undan farklıydı. Windows'ta
boş18443 için yalnız loopback HTTPS SSH tüneli açıldı; kullanıcı URL'yi manuel
uyarısız gördü. Curl verify0/best-effort; iptal durumu hâlâ NOT VERIFIED.

15:26:40.2502233UTC sahipli ID8 GET200/JSON/altı alan, snapshot SHA256 ve özel
Windows klasör ACL kapıları PASS.15:28:30.1881807UTC yalnız ID8 DELETE204/boş
gövde, GET404.15:31:19.306181UTC tam kimlik/etiket/mount ve dump/manifest hash
tekrar kontrolü sonrası restore container stop/rm, boş ağ network rm ve
kullanılmayan volume rm exit0; üçünün yokluğu doğrulandı. Kaldırılan container/
volume fullstackops-restore-4756810b5b43-postgres, ağ fullstackops-restore-4756810b5b43-net.

15:32:45.854736UTC kaynak altı tam ID/image/ref aynı ve healthy/RestartCount0;
A çifti ve PostgreSQL volume/mount korundu. READ ONLY Task0/IDs[]/boş satır hash
e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855 ve tek
InitialCreate/EF10.0.12 history, sentinel-öncesi baseline ile aynı. Sequence8/true
kaldı, sıfırlanmadı.15:34:00.604504UTC VM manifest+11 dosya boyut/hash/600,
klasör700/env600/restore-cleanup kanıtları PASS.15:35:17.6280647UTC Windows
manifest+11 dosya VM ile aynı boyut/hash; iki klasör inheritance kapalı ve
dosyalarda owner/Allow yalnız mevcut kullanıcı; ek kanıtlar korundu.

Dump3578 byte/SHA256f4eeadd74cacdf90ec68024117e9d015d8008531865a3b4ad8e5556ef0fcb687
değişmedi. Kaynakta silinen ID8'in tarihsel yedek/snapshot'ta kalması normaldir.
Yeni hash doğrulaması19 Ekim veri snapshot'ını güncellemez; yeni dump/kopya veya
günlük backup başarısı değildir. Geçici dosya temizliği yapılmadı; yedek/manifest/
snapshot/env/credential/TLS ve acceptance kayıtları korunur. Genel prune/down-v,
image/build/pull/migration/sequence reset ve development işlemi yok.
Agent VM/private dosyaları okumadı; sonuçlar kullanıcının komut çıktılarıdır.
Stack ve HTTPS tüneli açık; cleanup tamamlandı, günlük timer/retention/failure/
RPO ve deployment final kabulü bekliyor. Sürekli kesinti/production/off-site/
manuel öğrenme kabulü eklenmedi. Yalnız dört belge değişti; commit/push yok.

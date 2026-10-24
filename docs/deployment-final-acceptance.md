# Deployment laboratuvarı — final teknik kabul

**Değerlendirme tarihi:** 24 Ekim 2026, Europe/Istanbul.

**Sonuç:** Kabul edilen ayrı Linux VM laboratuvarı kapsamında **PASS**.

**İnceleme başlangıcı:** temiz `main`, `ea3c78c08fde19f8c1e96b26442b4e90b6621758`.

## Kapsam ve kanıtın tarihi

Bu sonuç [PROJECT_SPEC Advanced Lab E](../PROJECT_SPEC.md#advanced-lab-e--deployment)
ve [kullanıcının kabul ettiği deployment planı](deployment-plan.md#1-amaç-ve-kullanıcı-kararları)
içindir: mevcut bilgisayarda, ayrı Ubuntu VM/Engine üzerinde altı servis; satın
alma bütçesi 0 TL, yerel ad/HTTPS ve yalnız loopback SSH erişimi. Mevcut donanım,
elektrik ve internetin maliyetsiz olduğu iddia edilmez. Public domain, internet
deployment'ı veya production SLA bu kabulün kapsamı değildir.

Tablo, kullanıcının küçük komut gruplarını çalıştırıp paylaştığı gerçek sonuçların
repository'deki tarihli kayıtlarını değerlendirir. Bu oturumda VM'ye bağlanılmadı,
runtime deneyi tekrarlanmadı veya private kanıt/secret dosyası okunmadı. Son kaynak
veri ve altı container koruma karşılaştırması **23 Ekim 08:10:13.596772 UTC**;
timer'ın son paylaşılan günlük durumu aynı gün enabled/active/waiting idi.
24 Ekim'de anlık health veya doğal 10:30 sonucu ölçülmüş sayılmaz. Tarihin geçmiş
olması, beklenen olayın gerçekleştiğinin kanıtı değildir.

PASS, belirtilen yöntem ve gözlem aralığı için yeterli kanıttır. FAIL, kabul
ölçütünü karşılamadığı gösterilmiş sonuca; NOT VERIFIED ise eksik kanıta karşılık
gelir. Önceki başarısız tanı denemeleri korunur; sonraki bağımsız başarı onların
nedenini açıklamış sayılmaz. Aşağıdaki final ölçütlerinde açık FAIL yoktur.

## Tek final kabul tablosu

| Madde | Sonuç | Kanıt ve doğrulanan sonuç | Kabul açığı / ek gözlem ve sınır |
| --- | --- | --- | --- |
| GHCR digest/revision ve build yapılmadan deployment | **PASS** | [Registry seçimi](../infrastructure/deployment/README.md#seçilen-yayın-ve-gerçek-registry-kanıtı), [13 Ekim VM pull](../infrastructure/deployment/README.md#rehberli-vm-doğrulama-kaydı--13-ekim-2026), [stack başlangıcı](../infrastructure/deployment/README.md#stack-başlangıcı-ve-ssh-erişimi--14-ekim-2026): aynı A kaynak SHA'sı, iki RepoDigest/revision/linux-amd64 ve çalışan ImageID eşleşti; API/frontend build alanları yok, başlangıç `--no-build` ile. | Zorunlu kapı geçti. Daha yeni main/GHCR yayınları otomatik seçilmedi; tüm dependency image'larının digest ile sabitlendiği iddiası yok. |
| Ayrı secret, Compose project ve volume'lar | **PASS** | [İzolasyon](../infrastructure/deployment/README.md#izolasyon-portlar-ve-volumelar), [gerçek env/TCP kontrolü](../infrastructure/deployment/README.md#rehberli-vm-doğrulama-kaydı--13-ekim-2026): VM'ye özel env 600, farklı credential'lar, project `fullstackops-deploy-lab`, üç ayrı volume; non-loopback `postgres:5432` yanlış parolayı reddetti ve doğru parola ile SELECT 1 geçti. | Zorunlu kapı geçti. Socket/trust veya healthy parola kanıtı sayılmadı. Env düz metindir; vault veya kapsamlı secret audit'i değildir. |
| Açık migration üretimi, incelemesi ve uygulaması | **PASS** | [14 Ekim migration](../infrastructure/deployment/README.md#initialcreate-sql-uygulaması--14-ekim-2026): A SHA'sında ayrı Windows checkout, sahte process config; idempotent InitialCreate SQL checksum/aktarım eşleşti. Düzeltilmiş uygulama ve ikinci uygulama psql exit 0/COMMIT; altı sütun, identity, tek history ve şema/OID koruması geçti. | Zorunlu kapı geçti. VM'de SDK/image build yok, API otomatik migration uygulamıyor. İlk BOM hatası teşhis edildi; diskteki özgün SQL korunarak gönderilen metin düzeltildi. |
| Erişim sınırı ve portlar | **PASS** | [Gerçek TLS/port kontrolü](../infrastructure/deployment/HTTPS.md#14-https-etkinleştirme-ve-runtime-kabulü--1516-ekim-2026), [A dönüşü envanter](../infrastructure/deployment/UPDATE-ROLLBACK.md#final-envanter-veri-ve-temizlik): frontend 18081/18443, Prometheus 19090 ve Grafana 13000 yalnız VM 127.0.0.1; Windows tünelleri loopback. API/PostgreSQL/Redis host portu yok. | Zorunlu yerel erişim kapısı geçti. Public/LAN güvenlik testi veya ayrı firewall kuralı deneyi yapılmış sayılmaz. |
| Yerel HTTPS güveni ve Nginx | **PASS** | [HTTPS gerçek kabulü](../infrastructure/deployment/HTTPS.md#14-https-etkinleştirme-ve-runtime-kabulü--1516-ekim-2026): read-only config/leaf mount, nginx -t, aynı image ile frontend-only recreate; SAN `tasks.fullstackops.test`, Windows CurrentUser\Root güveni, zincir/hostname/geçerlilik ve uyarısız manuel browser erişimi. | Zorunlu yerel TLS kapısı geçti. İlk Schannel exit 35 gizlenmedi; komuta özel `--ssl-revoke-best-effort` kullanıldı, `-k`/`--insecure` yok. CRL/OCSP iptal durumu **NOT VERIFIED**; public CA kabulü değil. |
| Frontend assets ve API HTTP contract | **PASS** | [15 Ekim HTML/JS/CSS](../infrastructure/deployment/README.md#frontend-asset-sonuçları), [HTTPS CRUD](../infrastructure/deployment/HTTPS.md#https-api-contract-ve-test-kaydı-temizliği), [17 Ekim B ve A dönüşü](../infrastructure/deployment/UPDATE-ROLLBACK.md#b-ve-a-dönüşü-kabul-sonuçları): gerçek HTML/JS/CSS 200/uygun MIME; POST 201 ve HTTPS originine çözülen Location, tekil GET/PUT 200, altı JSON alanı/null description, 400/404, DELETE 204/boş gövde ve GET 404. | Zorunlu kapı geçti. Tarayıcı sertifika/Console/mixed-content gözlemleri manueldir; otomatik browser testi değildir. HTTPS asset MIME kanıtı 17 Ekim'e aittir. |
| Redis cache kabulü | **PASS** | [14 Ekim cache sonuçları](../infrastructure/deployment/README.md#gerçek-kabul-sonuçları): liste GET 200; MISS→HIT, key/TTL 60; başarılı POST/PUT/DELETE invalidation; 400/404 cache içeriğini korudu. Doğal expiration EXISTS 0/TTL -2, sonraki GET ile TTL 60 ve yeni MISS→HIT. | Zorunlu kapı geçti. FLUSH/manuel DEL kullanılmadı; bu kabul A sürümüne aittir, B için ayrıca cache regresyonu iddia edilmez. |
| PostgreSQL recreate sonrası veri kalıcılığı | **PASS** | [16 Ekim recreate](../infrastructure/deployment/README.md#postgresql-recreate-kalıcılık-kabulü--16-ekim-2026): PostgreSQL ID `e9296c518548…`→`b67a87f2d83f…`; aynı image ve `fullstackops-deploy-lab-postgres`→`/var/lib/postgresql`. HTTPS tekil GET ile ID 4 ve altı alan aynı; internal readiness 200, API restart edilmedi, diğer beş ID korundu, sahipli test temizlendi. | Zorunlu kapı geçti. Liste cache hit'i kanıt sayılmadı. Sürekli ölçüm yok; sıfır kesinti ve backup/restore kanıtı değildir. |
| Prometheus/Grafana | **PASS** | [15 Ekim monitoring](../infrastructure/deployment/README.md#prometheus-target-ve-yeni-örnek-kanıtı), [12 panel](../infrastructure/deployment/README.md#grafana-datasource-provisioning-ve-panel-sorguları): `api:8080/metrics` UP, iki scrape; datasource OK/provisioned Overview 12 panel. Altı GET sonrası HTTP 13→19, hit 2→7, miss 11→12, invalidation 6→6; Prometheus 10:00:34.960 UTC ve Grafana 10:01:34.960 UTC örnekleri trafik sonrasına ait. | Zorunlu kapı geçti. Tüm panel sorguları hatasız; oran/p95 null/nonfinite sonuçları sıfıra çevrilmedi. Manuel dashboard gözlemi otomatik DOM/Console kabulü değildir. |
| A→B→A güncelleme ve image rollback | **PASS** | [17 Ekim gerçek geçiş](../infrastructure/deployment/UPDATE-ROLLBACK.md#9-rehberli-aba-runtime-kabulü--17-ekim-2026): API sonra frontend; her iki yönde `--no-build --no-deps`, doğru revision/digest/platform. ID 5 altı alanıyla korundu; ayrı ID 6/7 CRUD/HTTPS/asset/readiness geçti. Final A, dört altyapı ID'si aynı, test verisi temizlendi. | Zorunlu kapı geçti. Uygulama/şema aynı; .NET/Nginx runtime patch içerikleri farklı, yalnız metadata farkı değil. Komut süreleri kesinti süresi değildir. Image rollback migration'ı geri almaz. |
| Dolu mantıksal yedek, Windows ikinci kopyası ve gerçek izole restore | **PASS** | [19 Ekim dump/kopya](../infrastructure/deployment/BACKUP-RESTORE.md#12-mantıksal-dump-ve-windows-ikinci-kopyası--19-ekim-2026), [gerçek restore](../infrastructure/deployment/BACKUP-RESTORE.md#13-izole-restore-ve-sequence-kabulü--19-ekim-2026), [20 Ekim cleanup](../infrastructure/deployment/BACKUP-RESTORE.md#14-kontrollü-temizlik-ve-yedek-koruması--20-ekim-2026): pg_dump/pg_restore exit 0; 3578 byte arşiv, VM/Windows manifest+11 dosya hash/boyut/izin eşit. Ayrı project/internal network/yeni volume'da ID 8/altı alan/tam veri hash/şema/history eşit; hedefte yeni ID 9, kaynak sequence 8 kaldı. Sahipli ID 8 ve yalnız deney kaynakları temizlendi, yedekler korundu. | Zorunlu kapı geçti; yalnız --list/checksum ile verilmiş PASS değil. PostgreSQL araçları 18.6; no-owner/no-privileges ile hedef rol sahipliği. Tek sahte kayıt; kaynak volume'a restore veya felaket kurtarma deneyi değil. |
| Günlük servis arşivinin Windows kopyası/restore'u | **PASS** | [21 Ekim arşivinin 22 Ekim kabulü](../infrastructure/deployment/backup/README.md#günlük-arşivin-windows-kopyası-izole-restore-ve-temizlik--22-ekim-2026): 3477 byte/checksum/ACL, gerçek izole pg_restore exit 0; dump dönemini çevreleyen kayıtlara göre Task 0/history/sequence 8; şema ve hedefte ID 9/ROLLBACK, kaynak koruması ve kontrollü cleanup geçti. | Ek doğrulanmış kanıt. **Bu arşiv boş tasks içerir**; önceki dolu restore'dan ayrıdır. Windows kopyası manuel; bu sonuç 22/23 Ekim arşivlerine otomatik aktarılmaz. |
| Günlük timer kurulumu ve kontrollü timer çalışmaları | **PASS** | [21 Ekim service](../infrastructure/deployment/backup/README.md#rehberli-vm-kurulumu-ve-iki-manuel-çalışma--21-ekim-2026), [22 Ekim timer](../infrastructure/deployment/backup/README.md#günlük-timer-etkinleştirme-ve-kontrollü-tetik--22-ekim-2026), [23 Ekim 10:30](../infrastructure/deployment/backup/README.md#günlük-saati-1030-yapma-ve-beş-dakikalık-test--23-ekim-2026): unit/hash/takvim doğrulandı; kontrollü timer kaynaklı completed/exit 0 ve yeni 22 Ekim seti. 23 Ekim 07:55:34 ve takvime dönüşte 07:58:25 UTC ayrı already-complete/exit 0; yeni dump yok. Override kaldırıldı, kalıcı günlük 10:30 Europe/Istanbul, enabled/active/waiting. | Günlük otomasyonun kurulum/çalıştırma yeteneği kapısı geçti. Manuel service start timer kanıtı sayılmadı; iki already-complete olayı başarı tarihini yenilemedi. Sonraki 24 Ekim 07:30 UTC yalnız son paylaşılan beklentidir. |
| Güvenli retention, hata ve aynı gün koruması | **PASS** | [14 fixture testi ve kapsamı](../infrastructure/deployment/backup/README.md#yerel-hazırlık-kabulü--21-ekim-2026), [test kaynağı](../tests/Deployment.DailyBackup.Test.py), [saklama kuralı](../infrastructure/deployment/backup/README.md#saklama-kuralı): yedi farklı başarılı gün, sahipli aday kapıları, yabancı/partial/manuele dokunmama, hata/timeout/corrupt sette terfi veya silme yapmama ve kilit testleri. [VM aynı gün kanıtı](../infrastructure/deployment/backup/README.md#yedek-veri-ve-container-koruması): hash/mtime/asıl başarı korundu; removed_sets 0. | Güvenlik davranışı **fixture düzeyinde**, aynı gün koruması ve Linux kilidi ayrıca VM'de kanıtlıdır. PASS gerçek çok günlük silme gözlemi anlamına gelmez; aşağıdaki ayrı satır açık kalır. |
| Doğal günlük 10:30 tetiklenmesi | **NOT VERIFIED** | [23 Ekim son timer kaydı ve gelecek kontrol](../infrastructure/deployment/backup/README.md#sonraki-doğal-1030-kontrolü): 24 Ekim 10:30 beklentisi var, bu olayın journal/manifest sonucu paylaşılmadı. | Ek operasyonel gözlem. Kontrollü kısa tetik veya tarih ilerlemesi bu boşluğu doldurmaz; çalışmadığına dair FAIL sonucu da çıkarılamaz. |
| Gerçek çok günlük retention gözlemi | **NOT VERIFIED** | [23 Ekim korunma](../infrastructure/deployment/backup/README.md#yedek-veri-ve-container-koruması): yalnız 21/22/23 Ekim setleri ve removed_sets 0; [fixture](../tests/Deployment.DailyBackup.Test.py) günleri simüle eder. | Ek uzun dönem gözlemi. Gerçek yedekleri silerek deney zorunluluğu üretilmedi; fixture PASS'i bu satıra taşınmadı. |
| Reboot/Persistent catch-up veya uyku/VM resume mekanizması | **NOT VERIFIED** | [Gecikmiş 23 Ekim işi](../infrastructure/deployment/backup/README.md#gecikmiş-günlük-çalışma-ve-arşiv-kontrolü--23-ekim-2026): 02:00 hedefi yerine 09:46 İstanbul'da completed; host kapalı veya uykudaydı. [10:30'a dönüşte ek tetik](../infrastructure/deployment/backup/README.md#vm-uygulaması-ve-iki-ayrı-timer-olayı) telafiyle uyumlu, ancak yorumdur. | Ek mekanizma gözlemi. Zamanında eski 02:00 çalışması kanıtlanmadı; tam reboot/uyku ayrımı ve kaçırılmış günlerin işlenmesi denenmedi. |
| 24 saat RPO garantisi ve her yeni arşivin ikinci kopyası/restore'u | **NOT VERIFIED** | [Windows/RPO sınırı](../infrastructure/deployment/backup/README.md#windows-ikinci-kopyası-ve-rpo), [yeni set sınırı](../infrastructure/deployment/backup/README.md#gecikmiş-günlük-çalışma-ve-arşiv-kontrolü--23-ekim-2026): Windows kopyası manuel, 22/23 Ekim arşivlerinin kopya/restore'u kanıtlanmadı. | Günlük yedek veri kaybı hedefidir, garanti değildir. Host/VM kapalıyken veya kopya eskiyken hedef sağlandı denmez. İki kopya aynı fiziksel bilgisayarda; off-site/PITR/SLA eklenmedi. |
| Development ortamının korunması | **PASS** | [Ayrı Engine/volume](../infrastructure/deployment/README.md#rehberli-vm-doğrulama-kaydı--13-ekim-2026), [restore cleanup koruması](../infrastructure/deployment/BACKUP-RESTORE.md#14-kontrollü-temizlik-ve-yedek-koruması--20-ekim-2026), [23 Ekim final karşılaştırma](../infrastructure/deployment/backup/README.md#yedek-veri-ve-container-koruması): yalnız VM lab hedefleri kullanıldı; development env/user-secrets/volume kullanılmadı. Son kaynak altı ID/image/port/mount/restart, Task/history/sequence aynı. | Zorunlu izolasyon kapısı geçti. Windows development diskinin tamamına ait adli hash taraması yapılmadı; tarihli hedef/komut/env izolasyonu ve mevcut koruma kanıtları esas alındı. |

## Release ve korunan son durum

Aktif dönüş hedefi **A**, kaynak `1b52633776279b1661a7cac53392d385cbf10444`;
tam API/frontend digestleri [release.json](../infrastructure/deployment/release.json)
ve [A/B kaydı](../infrastructure/deployment/releases/update-rollback.json) içindedir.
B kaynağı `69fe741fba69de8834789cc2e657fedbb5e6c3dd`; deney sonunda A'ya dönüldü.
Bu değerlendirme hiçbir release alanını veya digest'i değiştirmez.

JSON kaydındaki `vm_pull_and_runtime_acceptance: NOT VERIFIED` ve A/B hazırlık
durumları oluşturuldukları dar hazırlık aşamasına aittir. Sonraki tarihli runtime
kanıtlarının yerine geçmezler; final kararın kaynağı bu tablo ve bağlı kabul
kayıtlarıdır. JSON'u sessizce güncellemek veya yeni image seçmek yerine bu ayrım
açıkça kaydedildi.

Son paylaşılan kaynak durumu altı healthy servis, A API/frontend, ayrı PostgreSQL
volume'u, loopback HTTP/HTTPS/monitoring yayınları; Task 0, tek InitialCreate
history ve sequence 8/true idi. Test kayıtları temizlendi; tamamlanmış VM/Windows
yedekleri, private kanıtlar ve TLS/env korundu. Bu tarihli sonuçlar bugünkü canlı
envanter olarak sunulmaz; stack/tünelleri kapatma işlemi bu final kabulün parçası
değildir ve uygulanmadı.

## Eksikler nasıl sınıflandırıldı?

**Zorunlu kabul açığı:** Kabul edilen yerel VM teknik kapsamındaki ölçütler için
mevcut kanıtlarda yok. Image deployment, açık migration, HTTPS/contract/cache,
recreate kalıcılığı, monitoring, uyumlu image güncelleme/geri dönüş ve dolu
database'in gerçek izole restore'u doğrulanmıştır. Günlük job için kurulum ve
timer kaynaklı gerçek çalışma, retention için güvenlik fixture'ları ve gerçek
aynı gün koruması vardır. Şartname ve kabul edilen plan doğal takvimde yedi gün
beklemeyi, VM reboot deneyi veya RPO garantisini ayrı bir final geçiş koşulu
olarak tanımlamaz; bu değerlendirmede yeni zorunluluk eklenmedi.

**Ek gözlem ve sınırlar:** Tablodaki NOT VERIFIED satırları kapanmış sayılmaz.
Başarısız güncelleme arızasından zorunlu dönüş ayrıca enjekte edilmedi; planlı
B→A başarılı dönüşü bunun yerine yazılmadı. Önceki Compose nginx -t exit 124 ve
genel son kontrol RuntimeError nedenleri hâlâ açıklanmadı; ayrı doğrudan Nginx,
runtime ve restore kontrollerinin başarısı bunları geriye dönük PASS yapmaz.
İlk başarısız EF üretiminin nedeni de doğrulanmadı. Hiçbiri sonraki bağımsız
başarı kanıtını iptal eden gösterilmiş bir son durum arızası değildir.

Teknik laboratuvar kabulü, manuel öğrenme değerlendirmesi veya GitHub issue'su
kapanışı değildir. Public domain/internet kapsamı ayrıca kararlaştırılabilir;
mevcut issue değiştirilmedi. İstenirse sıradaki küçük iş doğal 10:30 olayının
[rehberdeki salt okunur kontrolüdür](../infrastructure/deployment/backup/README.md#sonraki-doğal-1030-kontrolü).
Yeni sonuç gelene kadar bu satır NOT VERIFIED kalır; mevcut kabul deneyleri
tekrarlanmaz, VM veya timer bu değerlendirme için değiştirilmez.

## Bu incelemenin yerel kontrolleri

Yalnız dört belge değişti: bu yeni kayıt, deployment planı, deployment README ve
PROJECT_STATUS. Repository secret leakage kontrolü **exit 0**, bu dört belgede
**191 yerel dosya/başlık bağlantısı PASS** ve `git diff --check` **PASS**.
Yeni belgenin UTF-8 ve satır sonu boşlukları ayrıca kontrol edildi. Index boş;
gerçek env/key/yedek veya başka geçici dosya değişiklik kapsamına eklenmedi.
Uygulama/unit/script/test/Compose/release dosyaları HEAD ile aynı. Yeni build,
fixture veya VM runtime çalışması bu dokümantasyon değerlendirmesi için gerekli
değildir; önceki 14/14 fixture kanıtı kendi tarihiyle kullanıldı.
Gerçek env, sertifika/key, SQL, dump, manifest veya snapshot Git'e eklenmez.
Commit/push ve issue kapatma yapılmadı.

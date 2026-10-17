# Deployment — A → B → A hazırlığı ve kabulü

**17 Ekim 2026: rehberli A→B→A runtime kabulü PASS.** Yalnız API, ardından
frontend her yönde yeniden oluşturuldu; finalde seçilmiş A çifti aktif, altı servis
healthy ve dört altyapı container'ı başlangıçla aynı. HTTPS/gerçek asset/CRUD,
değişmeyen ID5 kaydı ve son veri/history karşılaştırması doğrulandı; yalnız test
kayıtları ve geçici dosyalar temizlendi. [Güncel kanıt bölüm9'dadır](#9-rehberli-aba-runtime-kabulü--17-ekim-2026).
[Aktif release.json](release.json), A/B digestleri, env/TLS ve volume'lar aynı.
Stack ve tüneller açık bırakıldı; yedek/restore ve final lab kabulü bekliyor.

Bölüm1–7, 16 Ekim hazırlığının; bölüm8, 17 Ekim geçiş öncesi kontrolün tarihsel
kaydıdır. Bu bölümlerdeki NOT VERIFIED ve yapılmadı ifadeleri o aşamaya aittir.
İlk Compose run/nginx-t exit124 nedeni hâlâ NOT VERIFIED; sonraki başarılı
doğrudan test veya runtime geçişi o denemenin nedenini açıklamaz. Bu rehber
[deployment planı](../../docs/deployment-plan.md) adım7 kapsamındadır.

## 1. Seçilen çiftler ve yayın kanıtı

Tam referanslar, config digest'leri, job ID'leri ve kontrol sınırları
[update-rollback.json](releases/update-rollback.json) içindedir.

| Sürüm | Kaynak commit | Başarılı yayın | Rol |
| --- | --- | --- | --- |
| A | `1b52633776279b1661a7cac53392d385cbf10444` | [38239884132](https://github.com/EnsarAslannn/fullstack-ops-lab/actions/runs/38239884132) | VM'de kullanılan çift; dönüş hedefi |
| B | `69fe741fba69de8834789cc2e657fedbb5e6c3dd` | [38890534827](https://github.com/EnsarAslannn/fullstack-ops-lab/actions/runs/38890534827) | Seçilmiş güncelleme çifti; güncel VM kabulü bölüm9'da |

| Sürüm / image | Manifest digest |
| --- | --- |
| A / API | `sha256:2ccb0ecce9dc7cbe9da418b4f0a952b8122be336299fd3b888539b5d07a05afd` |
| A / frontend | `sha256:e0c77449225c4cd602e8f3b2af43a68ca3ad1578ce6428ba8ddcccf1fa612627` |
| B / API | `sha256:8174fee9ab9cfd308403425cdf10656a6fe7b92f78d3b32ec6485a71554ba367` |
| B / frontend | `sha256:1e4142e2da1f02ab503ea993c1ddbd9b9723268d51a32862f40a0d53170d19e7` |

Bu görevde GitHub CLI ile iki run'ın source SHA/event/main/success durumu ve iki
publishing job'ı kontrol edildi; job loglarından yalnız public digest referansları
çıkarıldı. GHCR'den anonim HTTPS ile **manifest ve config metadata** okundu:
manifest gövdesi SHA256/header digest, config SHA256, OCI source/revision ve
`linux/amd64` her iki çift için doğrulandı. Token'lar yalnız bellekte tutuldu;
değerleri veya ham job/registry çıktısı yazdırılmadı. Layer indirilmedi, Docker
login/pull veya VM erişimi yapılmadı. Package visibility değiştirilmedi;
metadata erişimi tam anonim layer pull kabulü sayılmaz.

B run'ında üç CI job'ı ve iki publishing job'ı başarılıdır. CI runtime job'ı
kaynaklardan build edilen image'ları sınar; publisher digest/revision kontrolü
yapar. Bunlar B'nin bu VM'de gerçek TLS mount'larıyla çalıştığını kanıtlamaz.

## 2. Uyumluluk kapısı ve gerçek fark

A/B Git karşılaştırmasında `src/backend` ve `src/frontend` ağaçları birebir aynı.
Değişen12 dosya deployment belgeleri/overlay'leri/kayıtları/statik testi ve
`.gitignore` kapsamındadır; iki Docker build context'inin dışındadır.

| Alan | Kaynak karşılaştırması ve sonuç |
| --- | --- |
| Migration / EF model | InitialCreate, Designer, snapshot, AppDbContext ve entity aynı; yeni DDL yok |
| EF paketleri / SQL | Proje/package sürümleri aynı; EF10.0.12, InitialCreate20260928113912; mevcut SQL checksum'u korunur |
| API / cache | Aynı altı JSON alanı, route, Location, nullable davranış, 400/404, cache-aside ve TTL sözleşmesi |
| Configuration | Aynı Postgres/Redis connection key'leri, TTL ve startup validation; credential değişikliği yok |
| Docker / CI | Aynı Dockerfile'lar, kök Compose, monitoring ve yayın akışı |
| HTTPS | Mevcut read-only Nginx/leaf/key mount'ları korunur; API8080 ve frontend80/443 uyumlu; B üzerinde gerçek nginx -t henüz yapılmadı |

**Yeni kullanıcı özelliği yok; image farkı yalnız metadata da değil.** OCI revision
label'ı değişmiş; her iki image'ın layer digest'leri ve rootfs diff ID'leri de
farklı. Registry config'lerinde doğrulanan public runtime değişimleri:

| Runtime | A | B |
| --- | --- | --- |
| .NET / ASP.NET | 10.0.12 | 10.0.13 |
| Nginx | 1.30.5 | 1.30.6 |
| NJS | 1.0.1 | 1.0.2 |

Dockerfile'lardaki `aspnet:10.0-noble` ve `nginx:stable-alpine` gibi mutable
base tag'ler farklı build zamanlarında farklı içerik sağlayabilir. Bu inceleme
tüm binary/package farklarının denetimi değildir. Kaynak ve şema uyumu B'yi
makul aday yapar; patch runtime uyumu aşağıdaki gerçek kabulü gerektirir.

Yerel kaynak kontrolünü tekrar incelemek için **Windows PowerShell, repository
kökü**; salt okunur, VM/build/yayın işlemi yok:

```powershell
git diff --name-only 1b52633776279b1661a7cac53392d385cbf10444 69fe741fba69de8834789cc2e657fedbb5e6c3dd
git diff --exit-code 1b52633776279b1661a7cac53392d385cbf10444 69fe741fba69de8834789cc2e657fedbb5e6c3dd -- src/backend src/frontend compose.yaml monitoring dotnet-tools.json .github/workflows/ci.yml scripts/Module11.PublishImages.py
if ($LASTEXITCODE -ne 0) { throw 'Uyumluluk farki var; gecise baslamayin' }
py -3 tests/Deployment.Configuration.Test.py
if ($LASTEXITCODE -ne 0) { throw 'Statik deployment kontrolu basarisiz' }
```

## 3. Sonraki görevin hazırlık sırası

**Aşağıdaki VM komutları gelecekteki rehberli deney içindir; bu hazırlıkta
çalıştırılmadı.** Grupları sonuç incelemeden peş peşe çalıştırma.

1. Güncel IP/SSH ve Windows HTTPS tünelini doğrula. Development Docker context'i
   kullanılmaz. Altı container ID/ImageID/health, dört altyapı image'ı,
   PostgreSQL mount/history ve mevcut görevlerin ID/alan hash'lerini kaydet.
   Inspect'te yalnız güvenli alanları seç; tam inspect/env/config çıktısı paylaşma.
2. VM'ye yalnız bu rehberi ve `releases/` altındaki üç public dosyayı aktar;
   Windows/VM SHA256'larını karşılaştır. Mevcut VM kaynak ağacını `git pull/reset`
   ile topluca değiştirme. Env, TLS ve aktif `release.json` üzerine yazma.
3. A ve B için config-q ve birleşmiş model kontrolü yap. Altı servis, build yok,
   mevcut readonly mount'lar/portlar/volume'lar aynı; yalnız iki image değişebilir.
   Model JSON'unu yalnız bellekte ayrıştır; çözümlenmiş değerleri yazdırma.
4. Dönüş için A'nın iki digest'ine erişim ve yerel varlığını da doğrula; ardından
   B'yi çek. A doğrulanmadan güncellemeye başlama. Repo secret/PAT gerektiren bir
   engel çıkarsa yeni credential üretmeden dur ve erişim sorununu raporla.
5. B image kimlik/revision/platform kontrolü ve geçici nginx -t geçsin; ancak sonra
   A başlangıç HTTP kabulü ve aşağıdaki sahipli test kayıtları hazırlanır.

**Ubuntu SSH, `~/fullstack-ops-lab`**: bu yardımcı yalnız verilen `a` veya `b`
seçimini dördüncü overlay olarak en sona ekler. Kendi başına işlem başlatmaz.
Seçim dosyaları tek başına Compose dosyası değildir.

```bash
cd ~/fullstack-ops-lab
deployment() {
  case "${1:-}" in
    a|b) local version="$1"; shift ;;
    *) printf '%s\n' 'FAIL: Yalniz a veya b secin'; return 1 ;;
  esac
  sudo docker compose --project-name fullstackops-deploy-lab \
    --env-file .env.deployment --env-file .env.https \
    -f compose.yaml \
    -f infrastructure/deployment/compose.deploy.yaml \
    -f infrastructure/deployment/compose.https.yaml \
    -f "infrastructure/deployment/releases/compose.version-${version}.yaml" "$@"
}
```

**Ubuntu SSH, sonraki hazırlık grubu**: config-q başarılıysa çıktı vermez.
Pull yalnız iki uygulama image'ını indirir; container/volume oluşturmaz.

```bash
deployment a config -q && deployment b config -q
```

Sonuçlar ve model kontrolü incelendikten sonra ayrı grup:

```bash
deployment a pull api frontend
```

A erişimi/kimliği doğrulanınca:

```bash
deployment b pull api frontend
```

Her çiftte `docker image inspect` ile seçilen **tam referans** local image'ının
`Id`, `Os`, `Architecture`, `RepoDigests` ve OCI revision alanlarını kaydet;
metadata kaydıyla karşılaştır. Config digest, manifest digest ve Engine'in local
ImageID'si farklı kimlik türleridir; eşit olduklarını varsayma. Çalışan container'ın
`.Config.Image` değeri tam seçilmiş ref, `.Image` değeri o ref'in local `.Id`
değeri olmalı. Her iki revision aynı seçilen SHA ve platform linux/amd64 olmalı.
Eksik pull, yanlış ref/platform veya karışık A/B çifti varsa recreate yapılmaz.

**Ubuntu SSH, B için geçici syntax kontrolü**; önce iki image kimliği doğrulanır.
Gerçek TLS mount'ları ve mevcut deployment ağı kullanılır, port yayınlanmaz:

**17 Ekim sonuç notu:** Aşağıdaki Compose run yöntemi 90 saniyelik sınırda
exit124 verdi; bu yöntemin başarılı olduğu iddia edilmez veya otomatik tekrar
önerilmez. Aynı image/gerçek mount'larla başarılı `docker create` ve
`docker start --attach` tanısı bölüm8'de kayıtlıdır.

```bash
tls_check="fullstackops-deploy-lab-b-nginx-check-$(date +%s)-$$"
deployment b run --rm --no-deps --pull never -T \
  --name "$tls_check" --entrypoint nginx frontend -t
```

Exit0, syntax/certificate okuma başarısı ve yalnız bu benzersiz test container'ının
kaldırıldığı doğrulanır. Hata çıktısını secret açısından kontrol etmeden paylaşma;
başarısızlıkta B'ye geçme. Çalışan frontend bu kontrolde değiştirilmez.

## 4. A → B geçişi

Önce A'da HTTPS üzerinden benzersiz bir **kalıcılık test görevi** oluştur; ID,
benzersiz title ve altı alanın tamamını Windows'ta repository dışında snapshot'a
kaydet. Başlangıç tekil GET200 snapshot ile aynı olmalı. Bu görev B ve A dönüş
kontrolleri bitene kadar **güncellenmez veya silinmez**. Normal CRUD için ayrı,
sahipliği doğrulanan geçici görev kullan; PUT updatedAt'i değiştireceği için
kalıcılık snapshot'ının aynılığıyla çelişmesin.

**Ubuntu SSH**, ön kontrollerden sonra yalnız API:

```bash
deployment b up -d --no-build --no-deps --force-recreate --pull never \
  --wait --wait-timeout 90 api
```

Başarılı wait, B kimliği ve internal readiness200 doğrulanmadan devam etme.
Hata varsa bölüm6'ya dön. Ardından **Ubuntu SSH**, yalnız frontend:

```bash
deployment b up -d --no-build --no-deps --force-recreate --pull never \
  --wait --wait-timeout 90 frontend
```

API önce, frontend sonra oluşturulur. Mevcut Nginx config'inde `api:8080` statik
upstream'ı vardır; frontend recreate yeni API IP'sinin yeniden çözülmesini sağlar.
Sadece API'yi recreate edip frontend'in eski upstream IP'siyle çalışacağını
varsayma. Geçiş atomik değildir; kısa 502/503/erişim kesintisi olabilir.
`--no-deps` diğer dört servisi yeniden oluşturmaz; `--pull never` ve `--no-build`
önceden doğrulanan local digest'ler dışında otomatik build/pull yapılmasını önler.
`up --wait` başarısızlığı otomatik rollback yapmaz; HTTP/TLS kabulünün yerine geçmez.

## 5. Her aşamanın kabul kapısı

**A başlangıç → B → A dönüş** için aynı tablo doldurulur; her sonucun UTC zamanını
kaydet. Ubuntu SSH kontrolleri ve Windows HTTPS istekleri ayrı terminaldedir.
[HTTPS rehberi](HTTPS.md) mevcut sertifika/tünel/request yöntemini tarif eder;
[önceki kabul kayıtları](README.md) yeni B kabulü olarak kopyalanmaz.

| Kontrol | Terminal ve beklenen gözlem | 16 Ekim hazırlığında durum |
| --- | --- | --- |
| İki image kimliği | Ubuntu; tam ref/localId/container.Image/revision/platform eşleşir, API ve frontend aynı sürümde | NOT VERIFIED |
| Altyapı koruması | Ubuntu; postgres/redis/prometheus/grafana ID ve image/mount/port'ları başlangıçla aynı; altısı healthy | NOT VERIFIED |
| API process / readiness | Ubuntu frontend içinden api:8080/health/live ve /health/ready200; SPA yanıtı kanıt sayılmaz | NOT VERIFIED |
| TLS / gerçek assets | Windows; HTTPS HTML200 ve HTML'in yeni referans verdiği JS/CSS200, uygun MIME; sabit eski asset adı varsayılmaz | NOT VERIFIED |
| Manuel tarayıcı | Windows; sertifika uyarısı/mixed-content/Console hatası yok, otomatik browser testi diye sunulmaz | NOT VERIFIED |
| HTTP contract | Windows; ayrı owned task POST201, doğru relative Location aynı HTTPS originine çözülür, GET/PUT200, DELETE204/boş body ve ardından404 | NOT VERIFIED |
| JSON / negatif | Windows; tam altı alan/nullable description, createdAt korunur/PUT updatedAt ilerler; boş title POST/PUT400, bulunmayan ID404 | NOT VERIFIED |
| Aynı kayıt | Windows; kalıcılık görevi /api/tasks/ID tekil GET200 ile tüm altı alan snapshot'a eşit; liste cache'i kanıt değil | NOT VERIFIED |
| Veri/history | Ubuntu; InitialCreate tek kayıt/EF10.0.12 ve başlangıç unrelated Task ID/alanları korunur; migration uygulanmaz | NOT VERIFIED |
| Kesinti | Windows/Ubuntu; başlangıç/bitiş ve zamanlı probe sonuçları kaydedilir; yalnız örnekleme varsa gerçek kesinti süresi NOT VERIFIED kalır | NOT VERIFIED |

Windows Schannel için mevcut komuta özel `--ssl-revoke-best-effort` sınırı geçerli:
zincir/hostname/tarih kontrolü açık, CRL/OCSP iptal durumu kanıtlanmış değil.
`-k`/`--insecure`, revocation'ı bütünüyle kapatma veya global callback kullanılmaz.
HTTPS `https://tasks.fullstackops.test:18443`, HTTP18081 ve monitoring19090/13000
yalnız VM loopback, mevcut Windows tünelleri korunur. API/PostgreSQL/Redis host
portu açılmaz. Key/header/body/env/connection string loglanmaz; sadece bu labın
sahte Task payload'ı yerel snapshot'ta tutulur.

## 6. B → A dönüşü ve başarısız güncelleme

B kabulü başarılıysa planlı dönüş; herhangi bir B kapısı başarısızsa kontrollü
geri dönüş yapılır. Önce başarısız step/UTC/exit code ve yalnız güvenli health/log
alanlarını kaydet. `config` veya tam `inspect` çıktısını paylaşma. Env/TLS/schema
beklenmedik biçimde değişmişse image dönüşünün bunu düzelteceğini varsayma.

**Ubuntu SSH**, A digest'lerinin local doğrulaması ve mevcut config-q sonrası:

```bash
deployment a up -d --no-build --no-deps --force-recreate --pull never \
  --wait --wait-timeout 90 api
```

A API kimliği/readiness başarılı olduğunda ayrı grup, **Ubuntu SSH**:

```bash
deployment a up -d --no-build --no-deps --force-recreate --pull never \
  --wait --wait-timeout 90 frontend
```

Kısmi güncellemede frontend zaten A olsa bile API recreate sonrası Nginx DNS
yenilemesi için frontend yeniden oluşturulur. Dönüşte de bölüm5'in tamamı ve aynı
kalıcılık görevi doğrulanır; yalnız healthy veya eski grafiklerin görünmesi yetmez.
A'ya dönüş başarısızsa diğer servisleri restart/down etmeye geçme; güvenli tanıyla
dur. PostgreSQL volume'u, env/credential, TLS ve aktif release kaydı korunur.

**Image rollback database migration'ını geri almaz.** Bu çiftte migration yoktur;
InitialCreate SQL'ini yeniden uygulamak veya Down çalıştırmak geçişin parçası
değildir. InitialCreate.Down `tasks` tablosunu siler. Şema değişen başka bir çift
için bu planın uyumluluk kararı geçerli değildir; yedek/restore ayrı kabul bekler.

## 7. Temizlik ve statik doğrulama kaydı

Bu bölümün hazırlık/test sonuçları **16 Ekim** tarihine aittir. Sonraki VM pull
ve Nginx sonuçları bölüm8'dedir; aşağıdaki tarihsel NOT VERIFIED kayıtları güncel
VM ön kontrolünün yerine kullanılmaz.

Gelecekteki deney sonunda yalnız bu görevin benzersiz kalıcılık/CRUD kayıtlarını
ID/title/createdAt ile sahiplik kontrolünden sonra sil; DELETE204 ve GET404
doğrula. Başlangıç kayıtlarının alanları/history korunsun; kimlik sequence'i geri
sarılmaz. Yalnız kendi snapshot/payload/geçici nginx container'ını temizle.
FLUSH, down, volume/image prune veya başka container temizliği yok. Son envanteri
başlangıçla karşılaştır; A'da altı servis ve tüneller çalışır bırakılır.

Hazırlığın statik testi gerçek Compose parser'ını sahte env/TLS path fixture'ıyla
kullanır; Docker Engine/VM gerekmez. Önce eksik iki selector nedeniyle beklenen
iki test FAIL; dosyalar eklenince **7/7 PASS**. A overlay'i HTTPS modelini tamamen
korur; B yalnız iki image'ı değiştirir; A tekrar seçilince model aynıdır. Bu model
karşılaştırması çalışma zamanı rollback'i veya sertifika okuma testi değildir.
Test geçici fixture'ları context manager ile temizlenir; canary diagnostic çıktısı
kontrol edilir. Gerçek env/user-secrets/TLS dosyaları okunmaz.

Repository secret leakage kontrolü exit0, değişen/yeni dört Markdown belgede101
yerel dosya/anchor bağlantısı, bir PowerShell ve dokuz Bash komut bloğunun yalnız
sözdizimi kontrolü PASS. `git diff --check` PASS; sekiz hazırlık dosyası dışında
değişiklik ve staged dosya yok. Mevcut release/Compose/HTTPS/Nginx/CI dosyaları
Git HEAD ile aynı; gerçek env, sertifika veya key eklenmedi.

Bu hazırlıkta doğrulananlar: başarılı yayın/registry metadata ve kaynak uyumu,
schema değişikliği gerekmemesi, statik A/B/A Compose birleşimi. **VM B pull,
nginx -t, A→B→A, HTTPS kabulü, kayıt korunması ve kesinti ölçümü yapılmadı.**
Yeni image yayınlanmadı; commit/push yok. Sonraki en küçük adım bu public dosyaları
VM'ye aktarmak, model/kimlik kontrolü ve yalnız digest pull hazırlığını rehberli
yapmaktır; recreate ayrıca sonuçlar incelendikten sonra başlatılır.

## 8. Rehberli VM aktarımı, B image ve Nginx kontrolü — 17 Ekim 2026

Başlangıç repository HEAD `9371046e7f4e9f0ec2b99461d08937cd59272be1`, Git temiz.
Komutları kullanıcı Windows PowerShell ve Ubuntu SSH terminalinde çalıştırıp
sonuçları paylaştı; agent VM'ye bağlanmadı veya private dosyaları okumadı.
Hyper-V konsolu girişe yanıt vermedi; Windows kontrolünde VM Running, IP listesi
boştu. Son bilinen IP ile SSH çalıştı; hostname fullstackopslabvm ve eth0
172.30.249.139/20 UP doğrulandı. Konsol sorununun kök nedeni belirlenmedi;
VM/Docker restart, ağ veya Hyper-V ayarı değişikliği yapılmadı.

### Aktarım ve image kimlikleri

Hedefte dört dosyanın da bulunmadığı kontrol edildi. Windows'tan yalnız rehber
ve üç releases/ dosyası SCP ile aktarıldı; mevcut VM kaynak ağacı/env/TLS üzerine
yazılmadı. Ubuntu `sha256sum --check` dört dosyada OK verdi:

| Aktarılan dosya | Windows/VM SHA256 |
| --- | --- |
| UPDATE-ROLLBACK.md | FE93E1D5CAFC9AAA10598CC981DFCFB7E969E2DC4FCA04A4E8FC7B5A020F44A3 |
| releases/update-rollback.json | 4ADEB162DEE0EAB959B8EFD8250E998E244894FFF9246A93F4369FF7345E9F9B |
| releases/compose.version-a.yaml | 83D417068F414F91B2A665F6558C6A614172D2AD81D7330DE3425EDB30F76793 |
| releases/compose.version-b.yaml | 06FAB3986E630DAF48350C5BEFDA23CAA95CE6462085F1AE928DB2B7CA0A1EF5 |

Hash'ler bu kabul kaydı eklenmeden **önce aktarılan dosya byte'larına** aittir.
Windows çalışma kopyasının satır sonlarını da kapsar; Git blob kimliği değildir.
Bu sonuç dokümantasyonu eklendiğinde yerel rehber değişti; VM'deki rehber yeniden
aktarılmadı. Diğer üç release dosyası ve aktif release.json değiştirilmedi.

İlk inspect çalışan API/frontend'in bölüm1'deki tam A referanslarını, local image
kimliklerini ve source1b52633776279b1661a7cac53392d385cbf10444 etiketini doğruladı.
Ardından yalnız B API/frontend için `timeout 180s sudo docker pull IMAGE@DIGEST`
çalıştırıldı; build yapılmadı. API çıktısı Downloaded/digest sonucunu gösterdi,
API pull exit code'u ayrıca paylaşılmadı; sonraki inspect kimliği doğruladı.
Frontend pull son PASS satırıyla tamamlandı. İki B image'ının RepoDigests alanı
bölüm1'deki tam referansla, revision69fe741fba69de8834789cc2e657fedbb5e6c3dd ve
linux/amd64 ile eşleşti. Bu Engine'de local ImageID'ler de ilgili manifest
digest'lerine eşitti; bunun tüm Engine/storage türlerinde zorunlu olduğu iddia
edilmez. A'nın iki exact digest referansı ayrıca inspect edildi: yerelde mevcut,
doğru A revision ve linux/amd64; image silme/prune veya yeni yayın yapılmadı.

### Gerçek env ile model kontrolü

Ubuntu'da Python subprocess stdout/stderr'i yalnız bellekte yakalayarak iki env
dosyası ve ilk üç Compose dosyasıyla mevcut HTTPS modelini; dördüncü A/B
overlay'leriyle iki seçim modelini okudu. Üçünde de config-q başarılı:

- A modeli mevcut HTTPS modeliyle tamamen aynı; aynı project ve altı servis.
- Her iki seçimde API/frontend build alanları yok; image'lar release kaydıyla aynı.
- A modelinin yalnız iki image alanı B'ye çevrilince model B ile tamamen eşit.
- HTTPS mount'ları, portlar, env, ağ, diğer dört servis ve volume hedefleri aynı.

Çözümlenmiş configuration paylaşılmadı veya dosyaya yazılmadı. Bu statik model
karşılaştırmasıdır; B servislerinin başlatıldığı veya readiness/CRUD kabulünün
yapıldığı anlamına gelmez.

### Nginx denemeleri ve ayrılan sonuçlar

| Deneme | Gerçek sonuç | Kabul sınırı |
| --- | --- | --- |
| Dördüncü B overlay ile Compose run, no-deps/pull never/gerçek TLS, 90s sınır | FAIL: exit124; fullstackops-deploy-lab-b-check-41c59847b851 temizlendi, altı başlangıç container'ı aynı/healthy | Hangi aşamada beklediği ve kök neden NOT VERIFIED; ham çıktı korunmadı/paylaşılmadı |
| Doğrudan Docker create, B frontend exact digest/pull never, 30s sınır | PASS; fullstackops-deploy-lab-b-diag-d4d520b5a025 oluşturuldu | Container oluşturma aşaması bu ayrı denemede başarılı |
| Aynı geçici container'da Docker start --attach, nginx -t, 30s sınır | PASS; exit0 dalı ve hem syntax is ok hem test is successful mesajları doğrulandı | B Nginx gerçek config/certificate/key dosyalarını okuyabildi; HTTP sunucusu olarak servis kabulü değil |
| Son temizlik | PASS; doğrudan test container'ı kaldırıldı, b- test prefix'li ps yalnız başlık verdi | İki denemenin container'ları kalmadı; yalnız bu test kaynakları kaldırıldı |

Başarılı tanıda önce `docker create --pull never --network
fullstackops-deploy-lab_app --entrypoint nginx ... B_FRONTEND@DIGEST -t`, ardından
`docker start --attach TEST_NAME` çalıştırıldı; her aşamanın çıktısı bellekte
yakalandı, başarısızlıkta raw çıktı gösterilmeden aşama/exit code raporlandı.
Bu doğrudan tanı sırasında ek image build/pull veya çalışan frontend recreate
yapılmadı; önceden çekilip doğrulanmış aynı B image kullanıldı.
Kullanılan üç bind çalışan A frontend'inden salt okunur inspect ile doğrulandı:

| VM kaynak | Container hedefi | Erişim |
| --- | --- | --- |
| ~/fullstack-ops-lab/infrastructure/deployment/nginx/https.conf | /etc/nginx/conf.d/default.conf | read-only |
| ~/.local/share/fullstackops-deploy-lab/tls/server.crt | /etc/nginx/deployment-tls/server.crt | read-only |
| ~/.local/share/fullstackops-deploy-lab/tls/server.key | /etc/nginx/deployment-tls/server.key | read-only |

Test container'ı port yayınlamadı; mevcut app ağına bağlandı. CA/private key
aktarımı veya key içeriği gösterimi yapılmadı. Doğrudan testin geçmesi, önceki
Compose timeout'unun nedenini kanıtlamaz veya o denemeyi PASS yapmaz.

### Son envanter, korunma ve bekleyen kabul

| Servis | Başlangıç ve son container ID başlangıcı | Son state/health/RestartCount | Son VM host bind |
| --- | --- | --- | --- |
| postgres | b67a87f2d83f | running/healthy/0 | Yok |
| frontend | e401eb7fbff5 | running/healthy/0 | 127.0.0.1:18081→80,127.0.0.1:18443→443 |
| api | 4d572817ca12 | running/healthy/0 | Yok |
| prometheus | 84eaf1ceebb5 | running/healthy/0 | 127.0.0.1:19090→9090 |
| redis | d98d34cc73c5 | running/healthy/0 | Yok |
| grafana | ed9398e62129 | running/healthy/0 | 127.0.0.1:13000→3000 |

Son inspect API/frontend ImageID'lerinin hâlâ **A** olduğunu gösterdi. Diğer dört
serviste recreate/restart/image değişikliği komutu çalıştırılmadı. Tüm container
kimlikleri başlangıçla aynı; başlangıç RestartCount ayrıca ölçülmediği için son0
değeri geçmişin sürekli takibi olarak sunulmaz. İstek/kesinti süresi ölçülmedi.

Mevcut stack çalışır bırakıldı; SSH tünellerini açma/kapama/değiştirme işlemi yok.
Windows tünel listener'ları bu adımda yeniden ölçülmedi. Development Docker
Desktop/env/user-secrets/volume'ları kullanılmadı. Yeni Task/SQL/migration,
recreate, veri silme veya cache temizleme komutu yok; PostgreSQL veri/history
hash'i bu adımda yeniden sorgulanmadı. Mevcut env/TLS ve volume hedefleri korundu.

Bu küçük adım **B image/TLS ön kontrolü** olarak tamamlandı. B API servis
container'ı çalıştırılmadı, frontend B yalnız nginx-t için geçici çalıştı.
A→B→A, her aşamanın HTTPS asset/CRUD/readiness kabulü, aynı test kaydının korunması,
kesinti ölçümü, backup/restore ve final lab kabulü NOT VERIFIED. Bölüm5 tablosu
bu nedenle henüz PASS yapılmaz. release kaydındaki birleşik B pull/container
identity durumunun NOT VERIFIED olması B servislerinin henüz oluşturulmamasıyla
ilgilidir; bu bölümde doğrulanan image metadata/pull sonucu ayrı kanıttır.
Commit/push yapılmadı; sonraki geçiş ayrıca kullanıcı isteğiyle başlatılacak.

Yerel dokümantasyon kontrolleri: repository secret leakage exit0, dört değişen
Markdown belgede107 yerel dosya/anchor bağlantısı ve git diff --check PASS.
Yalnız dört Markdown değişti, index boş; aktif release, A/B JSON/overlay'ler ve
mevcut Compose/HTTPS/Nginx kaynakları HEAD ile aynı. Üç public release dosyasının
byte hash'i aktarım kanıtıyla aynı. Uygulama/config değişmediği için build veya
başka runtime deneyi agent tarafından çalıştırılmadı.

## 9. Rehberli A→B→A runtime kabulü — 17 Ekim 2026

### Ortam, başlangıç ve kanıtın kaynağı

Repository temiz `main`, HEAD `cd11b47c842f524e108c91c9046df165ce847256` ile başladı.
Kullanıcı komutları Ubuntu SSH ve Windows PowerShell'de çalıştırıp sonuçları
paylaştı; agent VM'ye bağlanmadı, gerçek env/TLS/private key okumadı. Test edilen
uygulamalar bölüm1'deki A/source1b52633776279b1661a7cac53392d385cbf10444 ve
B/source69fe741fba69de8834789cc2e657fedbb5e6c3dd digest çiftleridir; repository
HEAD'i bu image'ların kaynak revision'ı olarak sunulmaz. Yeni pull/build/yayın yok.

VM eth0 `172.30.249.139/20`, loopback18443 LISTEN. İlk Windows kontrolünde HTTPS
tüneli bulunmadı; veri veya container işlemi yapılmadan duruldu. Ayrı PowerShell
penceresinde yalnız HTTPS tüneli yeniden açıldı:

```powershell
ssh -N -T -o ExitOnForwardFailure=yes -o ConnectTimeout=10 -o ServerAliveInterval=30 -o ServerAliveCountMax=3 -L 127.0.0.1:18443:127.0.0.1:18443 labadmin@172.30.249.139
```

Windows listener127.0.0.1:18443/ssh, curl HTTP200/VERIFY0/IP127.0.0.1/exit0 PASS.
Mevcut diğer tüneller kapatılmadı/değiştirilmedi; onların bağlantıları bu deneyde
yeniden sınanmadı. Komuta özel `--ssl-revoke-best-effort` kullanıldı; zincir,
hostname ve tarih kontrolü açık, CRL/OCSP iptal durumu NOT VERIFIED. `-k`,
`--insecure`, global callback veya trust/hosts değişikliği kullanılmadı.

Başlangıç altı container running/healthy/RestartCount0 ve A exact ref/localId/
revision eşleşmesi PASS. PostgreSQL başlangıç container'ı ve
`fullstackops-deploy-lab-postgres` → `/var/lib/postgresql` volume'u doğrulandı.
13:15:36.532088 UTC `BEGIN READ ONLY`: Task count0/IDs[], boş satır SHA256
`e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855`, tek
`20260928113912_InitialCreate`/EF10.0.12 history. Sorgu kullanıcı/database adını
container env'den aldı; değerleri veya parola yazdırılmadı. Socket sorgusu bu
adımda yalnız envanterdir, TCP authentication'ın yeni kanıtı değildir.

HTTPS POST201 ile sahipli kalıcılık görevi ID5 oluşturuldu; relative Location
`/api/tasks/5` aynı HTTPS originine çözüldü. Altı alan Windows TEMP'te snapshot'a
kaydedildi. 13:23:22.1474788 UTC POST ve 13:27:40.6049296 UTC tekil GET200/altı
alan eşleşmesi başlangıç kanıtıdır. İlk A'da bu deneyde root HTTPS200 ve sentinel
POST/GET yeniden ölçüldü; önceki [A HTTP/cache](README.md#nginx-http-contract-ve-redis-cache-kabulü--14-ekim-2026)
ve [HTTPS kabulü](HTTPS.md#14-https-etkinleştirme-ve-runtime-kabulü--1516-ekim-2026)
kendi tarihleriyle ayrı kanıttır. B ve A dönüşünde aşağıdaki kabul yeniden yapıldı.

### Geçiş komutları ve ölçülen süreler

Bölüm3'teki `deployment` seçimiyle eşdeğer dört-file Compose komutları kullanıldı:
her çağrıda project `fullstackops-deploy-lab`, iki env kaynağı ve sırasıyla
kök/deploy/HTTPS/seçilen A veya B overlay'i. Öncesinde config-q ve seçilmiş yerel
image revision/platform kontrol edildi. Her native komutun exit code'u yakalandı;
stdout/stderr paylaşılmadı. `up --wait-timeout 90` ayrıca Python subprocess120s
sınırıyla çevrelendi; güvenli zaman/exit kayıtları 600 izinli geçici dosyalara yazıldı.

```bash
deployment b up -d --no-build --no-deps --force-recreate --pull never --wait --wait-timeout 90 api
# B API kimligi ve internal readiness200 sonucundan sonra:
deployment b up -d --no-build --no-deps --force-recreate --pull never --wait --wait-timeout 90 frontend
# B kabulunun ardindan A'ya donus; arada A API readiness200 kontrolu:
deployment a up -d --no-build --no-deps --force-recreate --pull never --wait --wait-timeout 90 api
deployment a up -d --no-build --no-deps --force-recreate --pull never --wait --wait-timeout 90 frontend
```

| Aşama | Başlangıç UTC | Bitiş UTC | Komut süresi | Exit / dış timeout |
| --- | --- | --- | --- | --- |
| A→B API | 13:28:55.795959 | 13:29:01.762290 | 5.966 s | 0 / False |
| A→B frontend | 13:32:07.705403 | 13:32:13.847114 | 6.142 s | 0 / False |
| B→A API | 13:43:36.862939 | 13:43:42.838211 | 5.975 s | 0 / False |
| B→A frontend | 13:45:16.574215 | 13:45:22.676756 | 6.103 s | 0 / False |

B API live/ready200 13:30:34.977802 UTC; A API live/ready200
13:44:32.567745 UTC. Bu kapılardan sonra frontend recreate edildi; böylece statik
`api:8080` Nginx upstream'ı yeniden çözüldü. Health istekleri frontend container'ı
içinden doğrudan `http://api:8080/health/live` ve `/health/ready` adreslerine gitti;
SPA fallback kullanılmadı. Süreler recreate/health bekleme komutunun süreleridir;
geçişler arasında sürekli HTTP örneklemesi yok, gerçek kesinti süresi ölçülmedi.

### B ve A dönüşü kabul sonuçları

| Kontrol | B kanıtı (UTC) | A dönüşü kanıtı (UTC) | Sonuç |
| --- | --- | --- | --- |
| Exact ref, local ImageID, revision, linux/amd64 | 13:33:03.498946; iki B image'ı eşleşti | 13:46:55.795997; iki A image'ı eşleşti | PASS |
| Altı healthy; dört altyapı ID/image koruması | Aynı B stack kontrolü; RestartCount0 | Aynı A stack kontrolü ve final13:52:25.120940; RestartCount0 | PASS |
| Internal liveness/readiness | Her ikisi200; API ve stack kapıları | Her ikisi200; API, stack ve final kapıları | PASS |
| ID5 tekil GET/altı alan | 13:34:09.1024135; JSON200, ilk snapshot ile aynı | 13:47:37.5997261; JSON200, ilk snapshot ile aynı | PASS |
| HTTPS HTML ve HTML'den bulunan JS/CSS | 13:34:52.4106283; 200, text/html, application/javascript, text/css | 13:47:37.5997261; aynı kontroller200 | PASS |
| Manuel tarayıcı | Kullanıcı: sertifika uyarısı/Console hata veya uyarısı yok | Kullanıcı: sertifika uyarısı/Console hatası yok | PASS — yalnız manuel gözlem |
| Ayrı CRUD görevi, POST/Location | ID6,13:39:17.9679444;201, /api/tasks/6, doğru HTTPS origin | ID7,13:49:11.4456415;201, /api/tasks/7, doğru HTTPS origin | PASS |
| GET/PUT/tekrar GET | 13:40:23.6107181; hepsi200, altı alan, null description, title/completion değişti, createdAt aynı/updatedAt ilerledi | 13:49:39.8956990; aynı kontroller | PASS |
| Negatif ve sahipli cleanup | 13:41:46.9492978; boş title POST/PUT400, eksik2147483647 GET404, ID6 DELETE204/boş body ve GET404 | 13:50:11.8171575; aynı kontroller, ID7 temizlendi | PASS |
| ID5 CRUD'dan etkilenmedi | B CRUD sonrası altı alan aynı | A CRUD sonrası altı alan aynı | PASS |
| Son veri/history ve test dosyaları | A'ya dönüş sonrası aşağıdaki karşılaştırma/temizlik | Kullanıcı iki geçici klasörün temizliğini doğruladı | PASS |
| Kesintisiz erişim, tam kesinti süresi | Sürekli probe yapılmadı | Sürekli probe yapılmadı | NOT VERIFIED |
| Başarısız güncellemeden zorunlu dönüş | Başarılı B'den planlı A dönüşü yapıldı | Gerçek güncelleme başarısızlığı enjekte edilmedi | NOT VERIFIED — ayrı arıza deneyi yapılmadı |

Gerçek asset yolları iki aşamada `/assets/index-6SMY9-rQ.css` ve
`/assets/index-CKhYhs0u.js` idi; HTML'den dinamik çıkarıldı, eski adlar başarı
beklentisi yapılmadı. Browser kontrolü otomatik console/network testi değildir.
ID5 tekil GET'i PostgreSQL'den okur; liste cache hit'i kalıcılık kanıtı sayılmadı.
Kalıcılık görevi hiç PUT almadı. Sadece ID6/7 CRUD sırasında güncellendi/silindi.

### Final envanter, veri ve temizlik

| Servis | Başlangıç ID başlangıcı | B ID başlangıcı | Final A ID başlangıcı |
| --- | --- | --- | --- |
| api | 4d572817ca12 | 4e463cb7e2dd | 8b3d9f24f627 |
| frontend | e401eb7fbff5 | 1f21e9185842 | 15a93fef4000 |
| postgres | b67a87f2d83f | b67a87f2d83f | b67a87f2d83f |
| redis | d98d34cc73c5 | d98d34cc73c5 | d98d34cc73c5 |
| prometheus | 84eaf1ceebb5 | 84eaf1ceebb5 | 84eaf1ceebb5 |
| grafana | ed9398e62129 | ed9398e62129 | ed9398e62129 |

Tam ID'ler ve image kimlikleri karşılaştırıldı; tablo okunabilirlik için kısaltır.
API/frontend iki yönde yeni container ama doğru seçilmiş image'lar; altyapı dört
container ve image kimliği değişmedi. Final altısı running/healthy/RestartCount0.
Frontend VM127.0.0.1:18081→80 ve18443→443; Prometheus19090→9090 ve
Grafana13000→3000 yalnız VM127.0.0.1. API/PostgreSQL/Redis host portu yok.

13:51:11.748754 UTC read-only sorguda yalnız ID5/count1, history başlangıçla aynı.
Sahiplik ve ilk altı alan kontrolünün ardından ID5 DELETE204/boş body, GET404
13:51:40.9542080 UTC. Final13:52:25.120940 UTC read-only sorgu başlangıç state'iyle
tam eşleşti: count0/IDs[]/aynı boş satır SHA256, aynı tek InitialCreate/EF10.0.12.
PostgreSQL container'ı ve volume/mount hedefi aynı; internal live/ready200.
Başlangıçta başka Task yoktu; dolu dataset, fiziksel database/sequence eşitliği
veya backup/restore kanıtlanmadı. Sequence geri sarılmadı.

Yalnız bu görevin Windows TEMP `fullstackops-update-rollback-b3520082252448fcb13ba66195b0632c`
snapshot/payload klasörü ve Ubuntu `/tmp/fullstackops-update-rollback-_i2c_qfu`
600 izinli kanıt dosyaları temizlendi. Tam hedef/snapshot sahipliği ve link
kontrolleriyle, Ubuntu'da ayrıca tam dosya listesi/final kanıt doğrulamasıyla
silindi; kullanıcı iki PASS sonucunu paylaştı. Ham kayıtlar kalıcı artifact
olarak repository'ye taşınmadı; bu bölüm paylaşılan komut sonuçlarının kaydıdır.

Stack ve HTTPS tüneli açık, final A aktif. Development verileri/Engine/env/
user-secrets kullanılmadı; TLS, credential, aktif release.json ve A/B kayıtları
değişmedi. Volume silme, migration/SQL uygulama, FLUSH, prune, image build/pull/
yayın yok. Bu başarılı planlı image rollback, database migration rollback'i
değildir. Önceki exit124 nedeni hâlâ açık. Monitoring panelleri/retention yeniden
sınanmadı; kısa deney benchmark, production veya internet kabulü değildir.
Yedek/restore, final lab kabulü ve manuel öğrenme değerlendirmesi açık; sonraki
adım yalnız ayrıca istenirse plan adım8 hazırlığıdır. Commit/push yapılmadı.

### Yerel dokümantasyon doğrulaması

`py -3 tests/Deployment.Configuration.Test.py` **7/7 PASS**; gerçek Compose
parser'ı yalnız sahte fixture env/TLS yollarıyla kullanıldı, Engine/VM kaynağına
işlem yok. İlk sandbox denemesi geçici klasör izinlerinde başarısızdı; test
sandbox dışında geçti. İlk denemenin aynı saniyede oluşmuş dokuz boş fixture
klasörü tek tek tam yol/zaman/link/boşluk kontrolüyle temizlendi; başarılı test
kendi fixture'larını temizledi. Bu izin hatası VM runtime sonucu değildir.

Repository secret leakage exit0; dört değişen belgede116 yerel dosya/anchor
bağlantısı PASS. Bu rehberde iki PowerShell ve on Bash bloğu yalnız parser ile
kontrol edildi; VM komutları yerelde yürütülmedi. Git Bash ilk sandbox signal-pipe
izin hatasından sonra sandbox dışında `bash -n` ile geçti. `git diff --check`
PASS; yalnız dört Markdown belge değişti, index boş. Uygulama/test/Compose/TLS
config, aktif release ve A/B JSON/overlay'leri HEAD ile aynı; build veya runtime
deneyi agent tarafından tekrar çalıştırılmadı. Gerçek env/sertifika/key, SQL veya
geçici fixture dosyası değişiklik kapsamına eklenmedi.

## Kaynak dosyalar

- [Şartname — isteğe bağlı Deployment](../../PROJECT_SPEC.md#advanced-lab-e--deployment)
- [Aktif A](release.json), [A overlay](releases/compose.version-a.yaml),
  [B overlay](releases/compose.version-b.yaml), [release kanıtı](releases/update-rollback.json)
- [Kök Compose](../../compose.yaml), [deployment](compose.deploy.yaml),
  [HTTPS](compose.https.yaml), [Nginx](nginx/https.conf)
- [API](../../src/backend/FullStackOpsLab.Api/Program.cs),
  [configuration](../../src/backend/FullStackOpsLab.Api/Configuration/ApiConfiguration.cs),
  [migration](../../src/backend/FullStackOpsLab.Api/Migrations/20260928113912_InitialCreate.cs)
- [CI](../../.github/workflows/ci.yml), [publisher](../../scripts/Module11.PublishImages.py),
  [GHCR belgesi](../../labs/11-github-actions/README.md),
  [statik Compose testi](../../tests/Deployment.Configuration.Test.py)

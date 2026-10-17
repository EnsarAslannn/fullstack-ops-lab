# Deployment — A → B → A hazırlığı

**16 Ekim 2026: yalnız release seçimi ve statik hazırlık tamamlandı.** Bu rehberdeki
VM pull, recreate ve HTTP yazma komutları henüz çalıştırılmadı. Mevcut VM A'da;
[aktif release.json](release.json), env, TLS, volume ve tüneller değiştirilmedi.
Bu, [deployment planı](../../docs/deployment-plan.md) adım7'nin hazırlığıdır;
runtime, yedek/restore ve final lab kabulü açık kalır.

## 1. Seçilen çiftler ve yayın kanıtı

Tam referanslar, config digest'leri, job ID'leri ve kontrol sınırları
[update-rollback.json](releases/update-rollback.json) içindedir.

| Sürüm | Kaynak commit | Başarılı yayın | Rol |
| --- | --- | --- | --- |
| A | `1b52633776279b1661a7cac53392d385cbf10444` | [38239884132](https://github.com/EnsarAslannn/fullstack-ops-lab/actions/runs/38239884132) | VM'de kullanılan çift; dönüş hedefi |
| B | `69fe741fba69de8834789cc2e657fedbb5e6c3dd` | [38890534827](https://github.com/EnsarAslannn/fullstack-ops-lab/actions/runs/38890534827) | Yalnız aday; VM runtime kabulü yapılmadı |

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

| Kontrol | Terminal ve beklenen gözlem | Bu hazırlıkta durum |
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

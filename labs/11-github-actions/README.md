# Module 11 — GitHub Actions CI: plan ve baseline workflow

Plan ve 11A/11B bölümleri kendi aşamalarının kaydıdır. Zorunlu üç job'lı CI'nin Completed kararı ve denenmemiş fork/main-target sınırları [final kabul bölümündedir](#module-11--final-kabul-ve-öğrenme-değerlendirmesi). Sonradan eklenen integration testleri ve opsiyonel GHCR publishing ayrı kanıtlarla aşağıda açıklanır; tarihsel kabul yeni publishing adımını otomatik doğrulamaz.

## Durum ve amaç

4 Ekim 2026: ilk plan dokümante edildi ve commit edildi. Aşağıdaki planlama bölümleri ilk kararları korur; güncel implementasyon ve kabul sonuçları sondaki **11A baseline kabulü** bölümündedir. Module 10'un yerel kabul kanıtları CI üzerinde çalıştırılmış testler değildir.

Amaç her push ve pull request için kodun derlenebilirliğini, image üretimini, yapılandırmayı ve seçilmiş smoke kontrollerini otomatik doğrulamak. Planlama adımı yalnız bu README ve `PROJECT_STATUS.md` dosyasını değiştirdi; 11A implementasyonu `.github/workflows/ci.yml` ekler. Uygulama, Compose, secret kaynakları ve test scriptleri korunur.

## Şartname ile eşleştirme

Otorite: [PROJECT_SPEC.md — Module 11](../../PROJECT_SPEC.md#modül-11--github-actions-ci).

| Şartname maddesi | Planlanan karşılık | Aşama |
| --- | --- | --- |
| Her push ve pull request | `push` ve `pull_request`; ilk sürümde branch/path filtresi yok | 11A |
| Backend restore/build | Gerçek solution üzerinde Release build | 11A, zorunlu minimum |
| Frontend install/build | Lock dosyasına göre `npm ci`, ardından TypeScript/Vite build | 11A, zorunlu minimum |
| Docker image build | Mevcut iki Dockerfile ve gerçek context ile Linux image build | 11A, zorunlu minimum |
| Compose config doğrulaması | Yalnız CI için üretilen sahte değerlerle `config -q` | 11A, zorunlu minimum |
| Prometheus config doğrulaması | Compose ile aynı Prometheus image'ından `promtool check config` | 11A, zorunlu minimum |
| Backend testleri, ideal pipeline | Mevcut configuration HTTP/startup smoke ve secret fixture testleri; aşağıdaki kapsam sınırıyla | 11A seçilmiş kontroller; kalıcı CRUD için 11B |
| Docker Compose smoke, ideal pipeline | İzole boş veritabanı, mevcut migration ve kontrollü HTTP/cache testi | 11B, ayrı küçük adım |
| GHCR image push, opsiyonel | Temel CI kabulünden sonra ayrı karar | İlk workflow dışında |

**Planlama anındaki test kapsamı (4 Ekim 2026):** `FullStackOpsLab.slnx` yalnız `src/backend/FullStackOpsLab.Api/FullStackOpsLab.Api.csproj` içeriyordu; test projesi/framework'ü yoktu ve `dotnet test` test yürütmüyordu. Frontend'de de `npm test` scripti yok. Build, smoke ve unit test farklı doğrulama türleridir; tarihsel smoke sonuçlarına unit test veya code coverage adı verilmez. **7 Ekim 2026 ek adımı:** solution artık [backend integration test projesini](../../tests/FullStackOpsLab.Api.IntegrationTests/README.md) içerir; Linux build job'ına gerçek `dotnet test` step'i eklendi. [Run 37593868455](https://github.com/EnsarAslannn/fullstack-ops-lab/actions/runs/37593868455), commit `9e5e2ea2bd4a898fce5a68b6ceedb128cc4571d2`: üç job success, hosted integration testleri 21 PASS / 0 FAIL / 0 SKIP. Eski kabul run'ları yeni suite'in kanıtı değildir.

## Repository'den doğrulanan girdiler

- Backend `net10.0`; .NET 10 SDK gerekir. Configuration contract `ConnectionStrings:Postgres`, `ConnectionStrings:Redis`, isteğe bağlı pozitif `Cache:TasksTtlSeconds` kullanır. Restore/build uygulamayı başlatmaz ve database credential gerektirmez.
- Backend Dockerfile: `sdk:10.0` build → `aspnet:10.0-noble` runtime; context `src/backend/FullStackOpsLab.Api`.
- Frontend Dockerfile: `node:24-alpine` build → `nginx:stable-alpine` runtime; context `src/frontend`. `npm run build`, `tsc -b && vite build` çalıştırır.
- `package-lock.json` v3 mevcut; incelenen lock React 19.3.0, TypeScript 6.0.3 ve Vite 8.3.1 çözümlerini içerir. Vite'ın Node koşulu `^20.19.0 || >=22.12.0`; Node 24 bu koşula ve Docker build stage'ine uygundur. Bağımlılıkları CI için güncellemeyeceğiz.
- Root `dotnet-tools.json`, local `dotnet-ef` 10.0.12 tanımlar. İlk minimum job'da migration üretimi gerekmez; sonraki Compose smoke hazırlığında `dotnet tool restore` gerekir.
- Repository'de `global.json` ve NuGet `packages.lock.json` yok. Frontend lock dosyasının varlığı backend bağımlılıklarının kilitlendiği anlamına gelmez.
- Compose altı Linux servisi içerir: frontend, api, postgres, redis, prometheus, grafana. DB/Redis/API host portu yok. Mevcut external PostgreSQL volume adı local makinede hazırlanmış kaynak kabulüdür; hosted runner'da kendiliğinden bulunmaz.
- İki `.dockerignore` environment dosyalarını ve local build çıktılarını dışlar. Frontend API client relative `/api` kullanır; frontend build için development connection string veya API URL secret'ı gerekmez.

## Mevcut kontrollerin runner uygunluğu

Aşağıdaki değerlendirme **kaynak kod incelemesidir**, GitHub üzerinde çalıştırılmış kabul değildir. Hosted job'lar yerel user-secrets, `.env` veya önceden hazırlanmış volume'a sahip kabul edilmeyecek.

| Kontrol / script | Doğrudan çalışabilirlik ve bağımlılık | İlk CI kararı |
| --- | --- | --- |
| Backend restore/Release build | Linux ve Windows; .NET 10 SDK, NuGet erişimi. DB/Redis/user-secrets gerekmez | Her iki job'da; Windows kendi smoke DLL'ini üretir |
| Frontend `npm ci` / build | Linux; Node 24/npm, npm registry erişimi, lock dosyası | Linux job |
| İki Docker build | Linux runner ve Docker Engine; image registry erişimi. Uygulama servisi/secret gerekmez | Linux job |
| Compose `config -q` / promtool | Sahte Compose substitution değerleri; promtool için tek kullanımlık validation container. Stack/PG volume gerekmez | Linux job |
| `scripts/Module9.SecretLeakage.Check.ps1` | Git tracked ve ignored olmayan yeni dosyalar; secret değerlerini yazdırmaz. Linux `pwsh` uyumluluğu henüz kabul edilmedi | Windows job; exit 0 zorunlu |
| `tests/Module9.SecretLeakage.Smoke.ps1` | Child executable `powershell`, Windows temp path davranışı; 19 izole fixture. Docker/.env/user-secrets yok | Windows PowerShell job |
| `tests/Module9.Configuration.Smoke.ps1` | `kernel32.dll` error-mode API'si; Windows gerekir. Release DLL, 20 izole senaryo, sahte process configuration ve kapalı dependency portları. Child Production modu user-secrets yüklemez | Windows PowerShell job; filtresiz 20 senaryo |
| `tests/Phase0A.Smoke.ps1` | Çalışan API ve Development OpenAPI gerekir; BaseUrl ayarlanabilir. Health/OpenAPI için DB şeması gerekmese de startup configuration gerekir | Configuration smoke ile ortak kapsama tekrar eklenmez; OpenAPI kontrolü sonraki runtime adımında |
| `tests/Phase0B.Tasks.Smoke.ps1` | Güncel API için PostgreSQL/Redis ve migration gerekir. `Invoke-WebRequest` negatif HTTP hata yolu Windows PowerShell `WebException` davranışına bağlı | Linux'ta körlemesine çağrılmaz; sonraki Compose HTTP smoke'a kabul kriterleri taşınır |
| `tests/Module3D.EfFoundation.Smoke.ps1` | EF tool restore ve geçerli design-time process configuration gerekir. Context/model SQL kontrolü DB'ye yazmaz; user-secrets zorunlu değildir | Migration hazırlığı adımında değerlendirilir |
| `tests/Module3E.Persistence.Smoke.ps1` | `Start-Process -WindowStyle Hidden`, Windows HTTP hata işleme; çalışan DB/Redis ve şema, host API portu gerekir | İlk CI dışında; Compose container yaklaşımını doğrulamaz |
| `tests/Module5.Cache.Smoke.ps1` | Host API URL'si, lab container adları, boş başlangıç listesi; dependency stop/start ve Windows HTTP hata işleme | İlk CI dışında; izole Compose testi için uyarlama gerekir |
| `scripts/Module9.EnvPreflight.ps1` | Ignored/untracked env dosyası **checkout içinde** olmalı; Engine ve mevcut external volume salt okunur kontrolü gerekir. Linux `pwsh` kabulü yapılmadı | Statik minimumda normal preflight çalıştırılmaz; CI volume'u hazırlandıktan sonra uyarlanarak çalıştırılabilir |
| `tests/Module9.EnvPreflight.Smoke.ps1` | Child `powershell`; olumlu fixture'lar Engine/mevcut volume gerektirir. Parametreler test volume/override seçebilir | Windows job Linux Docker Engine var sayamaz; Linux child-shell uyarlaması sonraki adım |
| `tests/Module8.Readiness.Smoke.ps1` | `.env`, Compose dependency kesintileri ve **tam dört servis** beklentisi var; güncel stack altı servis | Şu haliyle güncel stack/CI için doğrudan uygun değil; ayrıca düzeltilip doğrulanmalı |
| `tests/Module10.Metrics.Smoke.ps1`, `Module10.Prometheus.Smoke.ps1`, `Module10.Grafana.Smoke.ps1` | Hazır Compose stack, env dosyası, migration, HTTP/registry erişimi gerekir. HTTP helper doğrudan `Net.WebRequest` kullanır; Linux PowerShell/CLI davranışı ayrıca doğrulanmalı. Tam modlar kesinti/restart/CRUD içerir | İlk CI dışında; ikinci adımda uygun alt kapsam seçilir |
| `tests/Module10.RequestLogs.Smoke.py`, `Module10.ScrapeTargets.Smoke.py` | Python ve Docker; dashboard helper'ında `.env`, sabit `fullstack-ops-lab-…` container adları. Geçici trafik/kesinti veya Prometheus container'ı kullanır | Ephemeral CI projesine uyarlama ve timeout planı gerekir |
| `tests/Module10.Grafana.Browser.Smoke.py`, `Module10.Dashboard.Smoke.py` | Playwright, kurulu `msedge`, hazır altı servis/migration ve uygun container adları. Edge'in her runner'da bulunduğu varsayılamaz | Daha sonra ayrı browser kabulü; proje npm bağımlılığına test aracı eklenmez |

`-EndpointOnly` sonuçlarını abartmayacağız: Grafana scriptinde service/health kontrolünden sonra çıkar, datasource sorgusu yapmaz; Prometheus scripti ilk target kontrolünden sonra çıkar, tüm scrape/trafik/kesinti kabulünü yapmaz. Metrics endpoint kontrolü de tam cache/CRUD regresyonu değildir.

Configuration smoke'taki başarılı configuration senaryolarının readiness 503 sonucu kasıtlıdır: dependency portları kapalıdır. Negatif senaryoda nonzero exit yanında **beklenen güvenli mesaj** ve stdout/stderr'de canary/tam test connection string yokluğu zorunludur. Windows crash dialog koruması yalnız test process ailesindedir; sistem ayarı değiştirilmez.

## 11A — En küçük yeterli workflow

Planlanan dosya: `.github/workflows/ci.yml`. Planlama evresinde oluşturulmadı; sonraki 11A implementasyonunda eklendi.

| Job | Runner / shell | Sıra ve sorumluluk |
| --- | --- | --- |
| `configuration-and-secrets` | `windows-2025`, `shell: powershell` (mevcut Windows PowerShell scriptleri) | Checkout → repository secret check → 19 secret fixture → .NET setup/SDK seçimi → restore/Release build → 20 configuration smoke |
| `build-and-config` | `ubuntu-24.04`, `bash` | Checkout → .NET/Node setup → restore/Release build → npm ci/build → iki Docker build → sessiz Compose config → promtool |

İki job bağımsız runner üzerinde paralel çalışabilir; workflow başarısı **ikisinin de geçmesine** bağlıdır. Windows job Docker kullanmaz. Linux job SDK tabanlı build ile gerçek Linux image üretimini doğrular. Windows'ta backend'in tekrar derlenmesi smoke'un o runner'da kendi DLL'ini kullanmasını sağlar; artifact paylaşımı veya işletim sistemleri arasında çalışan process/volume taşıma eklemeyiz.

Linux image/container çalıştırması için Linux runner seçiyoruz; sabit OS etiketleri `*-latest` ile işletim sisteminin habersiz değişmesini önler, runner image patch güncellemelerini dondurmaz. Bu etiketler resmî [hosted runner listesinde](https://docs.github.com/en/actions/reference/runners/github-hosted-runners) yer alır.

### Planlanan komutlar ve anlamları

Repository kökünden, ilgili job içinde:

```text
dotnet restore FullStackOpsLab.slnx
dotnet build FullStackOpsLab.slnx --configuration Release --no-restore
```

İlki bağımlılıkları indirir; ikincisi restore'u yinelemeden solution'ı derler. Windows job ayrıca aşağıdakileri çalıştırır; native exit code ve script başarısızlığı workflow'u başarısız yapmalıdır:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/Module9.SecretLeakage.Check.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File tests/Module9.SecretLeakage.Smoke.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File tests/Module9.Configuration.Smoke.ps1 -Configuration Release
```

Linux job'da `working-directory: src/frontend` ile `npm ci` ve `npm run build` çalışır. `npm ci` lock dosyasını esas alır; `npm install` ile sürüm güncellenmez. Docker komutlarının context'leri mevcut dosyalara uygundur:

```bash
docker version
docker compose version
docker build --tag fullstack-ops-api:ci src/backend/FullStackOpsLab.Api
docker build --tag fullstack-ops-frontend:ci src/frontend
docker compose --env-file .env.ci config -q
docker run --rm --entrypoint /bin/promtool \
  --mount "type=bind,source=$PWD/monitoring/prometheus/prometheus.yml,target=/etc/prometheus/prometheus.yml,readonly" \
  prom/prometheus:v3.13.4 check config /etc/prometheus/prometheus.yml
```

`.env.ci` yalnız gelecek CI job'ının ürettiği geçici, ignored sahte dosyadır; mevcut `.env` veya `.env.example` overwrite edilmez. Compose config tüm modeli parse ettiği için aşağıdaki **altı zorunlu anahtar**, yalnız PostgreSQL kullanılacak olsa bile hazırlanır:

`POSTGRES_USER`, `POSTGRES_DB`, `POSTGRES_PASSWORD`, `ASPNETCORE_ENVIRONMENT`, `GF_SECURITY_ADMIN_USER`, `GF_SECURITY_ADMIN_PASSWORD`.

`Cache__TasksTtlSeconds` kontrollü şekilde 60 seçilebilir. Host `ConnectionStrings__Postgres/Redis` placeholder'ları Compose girdisi değildir. Credential'lar çalışma anında üretilmiş sahte değerler olur; gerçek development secret'ları GitHub Secrets'a aktarılmaz. Dosya içeriği, process environment, tam inspect veya çözümlenmiş Compose config yazdırılmaz. Gerekirse fake credential masking uygulanır; mask tek başına sızıntı kontrolü değildir. `config -q` parse/substitution doğrular, volume varlığı/readiness/parola eşleşmesi kanıtlamaz.

Promtool container'ı sadece config denetler ve kaldırılır; Compose stack veya database başlatmaz. Registry login/image push, deployment ve artifact yayını ilk workflow'a dahil değildir.

### Araç sürümleri ve cache

| Araç | Seçim / gerekçe |
| --- | --- |
| .NET SDK | `10.0.x`, kararlı kanal; net10.0 ile uyum. Runner'ın önceden yüklü en yüksek SDK'sına güvenilmez. Setup action'ın çözdüğü **tam** SDK sürümünden job içinde geçici `global.json` üretilecek; `dotnet --version` gerçekten 10.0 ailesi olmalı |
| Node/npm | Node `24.x`; mevcut Dockerfile ve Vite koşuluyla uyum. Birlikte gelen npm kullanılır; `node --version` / `npm --version` raporlanır |
| Actions | 4 Ekim resmî README referansları: checkout v7, setup-dotnet v6, setup-node v7. Implementasyon sırasında seçilen resmî release'in tam commit SHA'sı doğrulanıp pinlenecek; bu planda SHA uydurulmaz |
| Docker/Compose | Ubuntu runner Engine/Compose sürümleri job başında kaydedilir. Erişim yoksa kontrol başarısız olur; hosted ortamda Docker Desktop/Windows Linux-container ayarı beklenmez |
| Promtool | Mevcut Compose image'ı `prom/prometheus:v3.13.4` ile aynı araç; ayrı veya `latest` sürüm seçilmez |
| EF/Python/browser | İlk minimumda gerekli değil; runtime smoke aşamasında mevcut EF 10.0.12 ve gerekli Python/browser kurulumu ayrıca planlanır |

SDK selection ve NuGet cache davranışı [setup-dotnet](https://github.com/actions/setup-dotnet) belgesinden doğrulandı. Repository'de NuGet lock dosyası olmadığından ilk sürümde `cache: true` kullanılmaz ve `--locked-mode` iddia edilmez. NuGet cache daha sonra lock kararıyla değerlendirilir.

Npm cache, `setup-node` üzerinden `cache: npm`, `cache-dependency-path: src/frontend/package-lock.json` ile paket indirmelerini hızlandırır; `npm ci` yine çalışır. `node_modules`, `dist`, build DLL veya secret dosyaları cache'e konmaz. Bu ayrım [setup-node](https://github.com/actions/setup-node) belgesinde açıklanır. Docker'ın aynı job içindeki layer cache'i kullanılabilir; ilk sürümde job'lar arası Docker cache/export eklenmez. CI süresi henüz ölçülmedi; hız kazancı garantisi yok.

### Tetikleyiciler, izinler ve başarısızlık kapıları

- Şartnameye uygun `push` ve `pull_request`; path filtresi nedeniyle config-only değişikliklerin doğrulamadan kaçması önlenir. Feature branch push ve PR aynı değişiklik için iki run oluşturabilir; ilk sürümde bu kabul edilir.
- `permissions: contents: read`; checkout için `persist-credentials: false`. Packages write, deployments, id-token/OIDC veya repository write izni gerekmez. Normal PR olayı kullanılır; fork kodunu privileged `pull_request_target` ile çalıştırmayız.
- Action'lar resmî repository'lerinden doğrulanmış tam SHA ile sabitlenir. PR başlığı/branch gibi kullanıcı girdileri shell içine doğrudan interpolate edilmez. Bu seçimler [GitHub güvenli kullanım rehberine](https://docs.github.com/en/actions/reference/security/secure-use) dayanır.
- Aynı workflow/ref için concurrency ve `cancel-in-progress: true`; eski push doğrulaması yeni commit geldiğinde iptal edilebilir. İlk timeout bütçesi Windows 20, Linux 30 dakika önerisidir; ölçüm değildir, ilk gerçek run'dan sonra değerlendirilir.
- `continue-on-error` ile build/test/config başarısızlığı gizlenmez. PowerShell native komutlarından sonra `$LASTEXITCODE` açıkça kontrol edilir. Beklenen negatif fixture'ı script doğrular; dışarıdan bütün nonzero sonuçlar başarılı sayılmaz.
- 19 secret fixture ve 20 configuration senaryosunun gerçekten çalıştığı logdan kontrol edilir; `-Scenario` ile yanlışlıkla boş kapsam seçilmez. Repo scanner exit 1 bulgu, exit 2 tarama hatasıdır; ikisi de CI'ı durdurur. Scanner Git geçmişini taramaz ve tüm secret türleri için garanti vermez.

## 11B — İzole Compose smoke planı

Bu bölüm 11A sırasında hazırlanan plandır. 11B uygulaması ve gerçek kabul sonuçları aşağıdaki ayrı bölümde kaydedilir.

1. Linux job'a ait benzersiz Compose project adı, geçici ignored `.env.ci` ve yalnız sahte process credential'ları kullan. Test adları parametreli hale getirilmeden sabit `fullstack-ops-lab-…` container bekleyen scriptleri çağırma. Servis DNS adları `api/postgres/redis/prometheus/grafana` ve mevcut internal portlar değişmez.
2. CI-only override ile external PostgreSQL volume adını **job'a ait benzersiz** adla değiştir; yalnız bu boş volume'u oluştur. Development `fullstack-ops-postgres-data`, önceden migration uygulanmış database veya user-secrets'e dayanma. Preflight env dosyasının checkout içinde olması ve CI volume adına parametre verilmesi gerekir; mevcut Windows child-shell kullanımına gerekli küçük Linux uyarlaması ayrı doğrulanır.
3. Önce yalnız PostgreSQL'i başlat, `pg_isready` bekle. Host EF tool restore ile mevcut InitialCreate'dan idempotent SQL üret; yeni migration oluşturma. Design-time startup validation için yalnız komut process'ine sahte PostgreSQL/Redis configuration ve Production ortamı ver.
4. Proje yolu `src/backend/FullStackOpsLab.Api`; planlanan EF komutu `dotnet ef migrations script 0 InitialCreate --idempotent --project src/backend/FullStackOpsLab.Api --startup-project src/backend/FullStackOpsLab.Api --configuration Release --no-build --output <geçici-SQL-yolu>`. Önceden Release build gerekir. SQL'i secret değerleri taşımayan kontrollü dosyada incele; UTF-8 stdin üzerinden PostgreSQL container'ındaki `psql -X -w -v ON_ERROR_STOP=1 -f /dev/stdin` ile uygula. Host PostgreSQL portu açma. Runtime API image'ında SDK/EF tool yoktur.
5. Altı servisi başlat; bounded timeout ile hepsi healthy olsun. Liveness/readiness tek başına `tasks` şemasını kanıtlamaz. Nginx üzerinden GET200/POST201+Location/PUT200/DELETE204, altı alan/nullable davranış, 400/404; internal Redis TTL/hit/miss/invalidation ve `/metrics` kontrollerini küçük bir uygun Compose smoke ile doğrula.
6. Prometheus target ve Grafana provisioning API kontrollerini kapsamlarına göre seç. Browser/bağımlılık kesintisi/restart/down-up uzun deneylerini her scriptte tekrarlama; ayrı küçük kabul adımlarına ayır. İlk minimum CI bu runtime davranışlarını doğrulamaz.
7. `always()` cleanup, **yalnız bu job'ın oluşturduğu** container/network/test volume'larını açık sahiplikle kaldırır; secret değerli raw log/config/inspect artifact'i yüklemez. Development volume veya prune komutu kullanılmaz. Job'lar arasında canlı servis veya kalıcı database paylaşımı varsayılmaz.

Database initialization ile credential eşleşmesi yeni boş CI volume'unda yönetilir. Mevcut initialized development volume'unda env parolasını değiştirmenin rol parolasını değiştirmediği kural aynen geçerlidir; CI için gerçek local kaynaklar kopyalanmaz.

## Planlama sırasında belirlenen belirsizlikler

- Planlama evresinde GitHub-hosted runner çalışması yoktu; baseline run kanıtı aşağıda eklendi. İlk job'lara alınmayan Linux PowerShell scriptleri hâlâ **NOT VERIFIED**.
- Action release SHA doğrulaması aşağıdaki 11A implementasyonunda tamamlandı. SDK/Node patch ailesi ve Docker image tag'leri mutable olabilir. Dockerfile/paket pin politikası değişmedi.
- Repository Actions erişimi ve politikası 11A öncesinde doğrulandı; branch protection required-check ayarı ve fork PR kabulü doğrulanmadı. İlk CI için kullanıcı development secret'ı veya GHCR yetkisi gerekmez.
- Mevcut Windows bağımlılıkları nedeniyle iki job, scriptleri yeniden tasarlamadan kullanılabilecek küçük başlangıçtır. Linux-only hedeflenirse önce portability değişiklikleri ve fixture kabulü gerekir; bu görevde yapılmadı.
- Minimum CI green olması gerçek Compose CRUD/cache/health/provisioning, browser, load test veya production deploy kanıtı değildir. Module 11'in tüm ideal akışı ve final kabulü ayrı değerlendirilecek.

## Bu plan adımının doğrulanması ve ilk uygulama

Planlama evresinde kaynak dosyaları/komut yolları incelendi, mevcut testlerin platform ve veri ihtiyaçları karşılaştırıldı. Son kontroller repository secret leakage check, `git diff --check`, status/diff kapsam incelemesiydi. Planlama evresinde build/container/migration/workflow çalıştırılmadı; local `.env`/user-secrets değerleri okunmadı ya da değiştirilmedi.

**İlk küçük uygulama:** 11A'daki iki job'ı `.github/workflows/ci.yml` olarak eklemek ve ilk gerçek push/PR run'ında beş minimum kapı, 19 secret fixture ve 20 configuration smoke sonucunu doğrulamak. CI green olmadan testler çalışmış sayılmaz. Bunun ardından ayrı talep ile 11B izole Compose smoke hazırlığı yapılır; GHCR yayınlama temel CI kabulünden sonra opsiyoneldir.

**Öğrenme:** runner temiz ve geçici bir makinedir; local bilgisayarındaki hazır volume/secret otomatik taşınmaz. Job'lar kendi process ve kaynaklarına sahiptir. Cache indirmeyi hızlandırır, testin yerini tutmaz. Build kodun derlenmesini, smoke belirli davranışları, config validation yapılandırmanın okunmasını doğrular; bunları aynı kapsam gibi raporlamamalıyız.

Plan ayrı olarak `94963e2f85de5187e6ec22e4aefb5509e2e6bde6` commit'iyle kaydedildi; mesajı `docs(ci): plan GitHub Actions baseline workflow`.

## 11A baseline kabulü

**11A baseline CI: Completed — yerel kontroller ve ilk gerçek hosted run PASS.** Module 11 bütünü tamamlanmış değildir; Compose runtime entegrasyonu başlamadı.

### Gerçek workflow kapsamı

[Baseline CI](../../.github/workflows/ci.yml) iki bağımsız job içerir. Ubuntu 24.04 backend/frontend build, iki Linux Docker image build, sahte değerlerle sessiz Compose model kontrolü ve promtool çalıştırır. Windows 2025 repository scanner, 19 secret fixture, Release build ve 20 izole configuration senaryosunu çalıştırır. Her native PowerShell komutunun exit code'u açıkça kontrol edilir; Bash step'leri [GitHub'ın shell davranışı](https://docs.github.com/en/actions/reference/workflows-and-actions/workflow-syntax#jobsjob_idstepsshell) gereği `-e` ve `-o pipefail` kullanır. `dotnet test` yoktur; unit-test coverage iddiası yoktur.

`push` ve `pull_request` branch/path filtresi olmadan tanımlıdır. İzin yalnız `contents: read`, checkout `persist-credentials: false`; secret input, registry login/push veya `pull_request_target` kullanılmaz. Fork PR kontrolleri gerçek development secret'ı istemez; GitHub'ın fork run approval politikası ayrıca uygulanabilir. İki job'da setup-dotnet çıktısının tam SDK sürümü geçici `global.json` ile seçilir, gerçekten aynı 10.0 SDK kullanıldığı doğrulanır.

Compose için sahte credential çalışma anında üretilir; fixture `RUNNER_TEMP` altında tutulur ve EXIT trap ile silinir. Bu statik kontrol normal env preflight değildir, bu nedenle preflight'in checkout içi fixture gereksinimi burada uygulanmaz. Gerçek `.env` kullanılmaz, çözümlenmiş config yazdırılmaz, external volume hazırlanmaz ve Compose stack başlatılmaz. Tek kullanımlık promtool container'ı `--rm` ile kalkar. Npm download cache yalnız hızlandırır; cache hit olsa da `npm ci` ve tüm build/config/smoke step'leri çalışır. NuGet/Docker için job'lar arası cache eklenmedi.

### Doğrulanmış araç ve action seçimleri

| Action | Resmî release | Tag'den doğrulanan tam commit SHA |
| --- | --- | --- |
| checkout | [v7.0.1](https://github.com/actions/checkout/releases/tag/v7.0.1) | `3d3c42e5aac5ba805825da76410c181273ba90b1` |
| setup-dotnet | [v6.0.0](https://github.com/actions/setup-dotnet/releases/tag/v6.0.0) | `a98b56852c35b8e3190ac28c8c2271da59106c68` |
| setup-node | [v7.0.0](https://github.com/actions/setup-node/releases/tag/v7.0.0) | `820762786026740c76f36085b0efc47a31fe5020` |

Resmî release sayfaları ve `git ls-remote` ile doğrulandı; workflow bu SHA'ları kullanır. [Hosted runner listesi](https://docs.github.com/en/actions/reference/runners/github-hosted-runners) Ubuntu 24.04/Windows 2025 etiketlerini, [Microsoft download sayfası](https://dotnet.microsoft.com/en-us/download/dotnet/10.0) .NET 10 SDK ailesini ve [Node release tablosu](https://nodejs.org/en/about/previous-releases) Node 24 LTS ailesini doğrular. Job'lar kararlı `10.0.x` / `24.x` seçer; çözümlenen patch sürümleri aşağıdaki gerçek run kanıtında kaydedildi. SHA pinning SDK/image tag'lerini immutable yapmaz.

### Yerel kontroller — 4 Ekim 2026

| Kontrol | Gerçek sonuç |
| --- | --- |
| `dotnet restore FullStackOpsLab.slnx` ve Release `--no-restore` build | PASS; SDK 10.0.401, 0 uyarı / 0 hata |
| `npm ci`, `npm run build` | PASS; Node 24.16.0, npm 11.13.0; TypeScript ve Vite 8.3.1 build |
| Repository secret scanner | PASS, exit 0; gerçek ignored `.env` tarama dışında |
| Secret fixture smoke | 19/19 PASS; canary stdout/stderr kontrolü |
| Configuration smoke | 20/20 PASS; 16 negatif senaryoda güvenli stderr ve canary yokluğu, 4 geçerli senaryoda live200/health200/invalid-task400/ready503 |
| İki `docker build ...:ci` | PASS; mevcut local layer cache kullanıldı; temiz hosted build kanıtı değildir |
| Sahte geçici env ile Compose `config -q` | PASS; gerçek env yüklenmedi, fixture temizlendi |
| Mevcut Prometheus image'ından `promtool check config` | SUCCESS; geçici validation container kaldırıldı |
| Geçici actionlint 1.7.12 | PASS; resmî release checksum'u doğrulandı, araç geçici dizini kaldırıldı; shellcheck/pyflakes çalıştırılmadı |

İlk yerel Vite denemesi sandbox child-process EPERM nedeniyle başarısızdı; aynı build normal yetkide geçti. İlk Docker build context metadata dosyası başka process tarafından kilitli olduğu için başarısızdı; aynı komutun tekrarı geçti, Docker ayarı değiştirilmedi. PowerShell 5.1 boş JSON key içeren npm lock dosyasını okuyamadı; salt okunur lock incelemesi Node ile yapıldı. Bu başarısız denemeler PASS olarak sayılmadı. GitHub CLI keyring erişimi sandbox dışında doğrulandı; repository Actions etkin ve erişilebilir.

### İlk gerçek GitHub Actions run'ı

- Workflow commit'i: `4b81604db117fd7adf80c637126e79f0ea475655` — `ci: add baseline GitHub Actions workflow`.
- [Run 37196281851](https://github.com/EnsarAslannn/fullstack-ops-lab/actions/runs/37196281851): `push`, `main`, **completed / success**. Run SHA'sı workflow commit'iyle aynı; yalnız yerel sonuçlardan başarı çıkarılmadı.
- [Linux job](https://github.com/EnsarAslannn/fullstack-ops-lab/actions/runs/37196281851/job/111418726621): **success**, UTC 10:43:20–10:44:20 (**1m00s**).
- [Windows job](https://github.com/EnsarAslannn/fullstack-ops-lab/actions/runs/37196281851/job/111418726727): **success**, UTC 10:43:21–10:45:17 (**1m56s**), 4 Ekim 2026.

| Gerçek hosted kontrol | Sonuç / kanıt |
| --- | --- |
| SDK seçimi ve backend build | İki job'da **10.0.401**; restore/Release build PASS, ikisinde 0 warning / 0 error |
| Frontend kurulumu/build | Node **24.21.0**, npm **11.19.0**; lock tabanlı install ve TypeScript/Vite build step'leri success |
| Docker image build | API ve frontend build step'leri success; Docker Engine **28.0.4**, Compose **v2.38.2** |
| Compose statik kontrol | Sahte geçici fixture ile `config -q` step'i success; stack/volume/database başlatılmadı |
| Prometheus config | promtool SUCCESS ve step success; `api:8080/metrics` config korunur, canlı scrape bu adımın kapsamı değildir |
| Repository secret check | Windows step success; mevcut ignored env/user-secrets gerekmez |
| Secret fixture smoke | Logdan **19 PASS** sayıldı ve final `19 cases` mesajı doğrulandı |
| Configuration startup smoke | Logdan **20 PASS** sayıldı ve final başarı mesajı doğrulandı; 16 güvenli negatif / 4 geçerli senaryo |
| Canary/connection string | Smoke child'ları stdout/stderr'yi denetledi; hosted loglar ayrıca gerçek canary biçimi ve tam test connection string deseni için bellekte kontrol edildi, bulgu yok |
| Cache | İlk run npm download cache **miss**; bütün zorunlu step'ler çalıştı. Node toolcache kullanımı npm dependency cache hit anlamına gelmez |

Gerçek hosted run'da düzeltme/retry gerekmedi; yerel sandbox/context başarısızlıkları yukarıda ayrı kaydedildi. Süreler bu run'a ait gözlemlerdir; CI hız veya performans garantisi değildir.

### Cleanup ve açık kalan kabul

Yerelde fixture/lint geçici dosyaları ve promtool container'ı temizlendi. Başlangıçtaki 12 ilişkisiz container ID'si korundu, hiçbir container running değildi ve görev sonunda da running container yok. Local `fullstack-ops-api:ci` / `fullstack-ops-frontend:ci` build tag'leri kaldı; başka image silinmedi. External PostgreSQL volume, `.env`, user-secrets ve uygulama kaynakları değiştirilmedi. Hosted kaynaklar GitHub'ın geçici job ortamına aittir.

Fork PR run'ı ve uzun Compose CRUD/cache/migration/browser/kesinti kabulü **NOT VERIFIED**; bu görevde çalıştırılmadı. Branch protection ve GHCR publishing eklenmedi. İlk başarılı run kaydı bu dokümantasyon commit'inde sabit tutulur; dokümantasyon push'u aynı workflow'u tekrar tetikler ve sonucu görev raporunda verilir. Her yeni run kimliği için tekrar dokümantasyon commit'i oluşturulmaz.

**11A sırasında önerilen sonraki küçük adım:** CI'a ait izole database/volume ve mevcut migration hazırlığıyla uygun Compose runtime smoke'u eklemek. 11A'da uygulanmadı; aşağıdaki 11B bölümünde tamamlandı.


## 11B runtime entegrasyonu — uygulama ve kabul

**11B Completed — yerel ve gerçek GitHub-hosted kabul PASS.** Module 11 final kabulü yapılmadı.

### Workflow ve izolasyon

Mevcut iki baseline job değiştirilmedi. Üçüncü `compose-runtime` job Ubuntu 24.04 üzerinde 25 dakika timeout ile çalışır; aynı tam checkout/setup-dotnet SHA'ları, `contents: read` ve secret istemeyen push/pull_request yaklaşımı korunur. Yeni action veya registry login yoktur. [Ubuntu runner araç listesi](https://github.com/actions/runner-images/blob/main/images/ubuntu/Ubuntu2404-Readme.md) Python ve PowerShell Core içerir; Windows'a bağımlı testler Windows job'da kalır.

[Module11.Compose.Smoke.py](../../tests/Module11.Compose.Smoke.py) her çalışmaya UUID içeren ayrı Compose project adı, yeni PostgreSQL volume'u ve `fullstackops.ci.owner` etiketi verir. State/fixture/override/SQL repository dışında, system/runner temp altında ayrılmış dizindedir. Credential'lar çalışma anında üretilir, GitHub `add-mask` ile maskelenir; Linux dosya izinleri 0600/dizin 0700 olur. Gerçek `.env`/user-secrets okunmaz; inherited Compose/connection/credential anahtarları child environment'tan çıkarılır.

Planın checkout içinde env fixture önerisi yerine runner temp kullanıldı: gerçek `.env` için Git-ignore/tracked kuralları uygulayan local preflight burada körlemesine çağrılmaz. İzole harness kendi fixture'ını sessiz Compose config, benzersiz boş volume ve sahiplik kontrolleriyle doğrular; mevcut local onboarding script'i değiştirilmedi.

Geçici override yalnız CI volume adını ve host portlarını değiştirir. Nginx localhost'ta Docker'ın seçtiği geçici portu yayınlar; diğer beş servisin host portu yoktur. [Compose merge belgesindeki](https://docs.docker.com/reference/compose-file/merge/) `!override` (Compose 2.24.4+) eski frontend mapping'ini değiştirir; `!reset []` monitoring portlarını kaldırır. Ana Compose, servis DNS adları ve internal portlar korunur.

Altı servis seçildi: frontend, api, postgres, redis, prometheus, grafana. Bu mevcut Module 10 topolojisini ve 11B planını korur; yeni observability özelliği eklemez. Monitoring kabulü internal metrics, bounded Prometheus target UP ve Grafana datasource/dashboard provisioning API kontrolüdür. Browser, tüm panel sorguları ve uzun Module 10 kesinti deneyleri burada tekrarlanmaz.

### Hazırlık ve kabul sırası

1. Compose `config -q`; mevcut olmayan benzersiz volume oluşturma. Yalnız PostgreSQL'i `up -d --wait --wait-timeout 120 postgres` ile başlatma.
2. Host .NET 10 ile `dotnet tool restore`, solution restore ve Release build. Runtime API image'ına SDK/EF CLI eklenmez.
3. Mevcut migration için `dotnet ef migrations script 0 InitialCreate --idempotent --project src/backend/FullStackOpsLab.Api --startup-project src/backend/FullStackOpsLab.Api --configuration Release --no-build --output <temporary-SQL>`. Yalnız komut process'inde Production ve credentialsız/erişilemeyen preview configuration; user-secrets değişmez.
4. SQL'de tasks/history/`20260928113912_InitialCreate` incelemesi; UTF-8 byte stdin ile `psql -X -w -v ON_ERROR_STOP=1 -At -f /dev/stdin` uygulaması. Parola container environment'tan alınır, host argümanına yazılmaz. İdempotent SQL ikinci kez uygulanır: history sayısı 1, Task sayısı 0 olmalıdır. API startup otomatik migration yapmaz.
5. Altı servisi `up -d --build --wait --wait-timeout 180` ile başlatma; tam servis kümesi ve running/healthy durumlarını ayrıca doğrulama.
6. Mevcut CRUD/cache/readiness testleri; altı JSON alanı/nullable sözleşme ve API container restart sonrası PostgreSQL kalıcılığı.
7. Task sayısı 0/history1; yalnız liste cache key'i temizliği, internal metrics/Prometheus/Grafana API kontrolleri.
8. `always()` cleanup: project container/network, açık adla project-labelled Grafana/Prometheus volume'ları ve owner etiketi doğrulanmış CI PostgreSQL volume'u kaldırılır. Geçici state/env/SQL dizini silinir. `down -v`, prune ve development volume silme yoktur. CI image/cache'i disposable runner yaşam döngüsüne bırakılır; local build image'ları kalabilir.

### Yeniden kullanılan testler ve taşınabilirlik

| Test | CI kullanım / değişiklik |
| --- | --- |
| Phase0B.Tasks.Smoke.ps1 | Nginx URL parametresi; PS7 `SkipHttpErrorCheck` ile beklenen 400/404 yanıtları incelenir, PS5.1 WebException yolu korunur. Hatalarda response body yazdırılmaz; HTTP timeout 20s. |
| Module5.Cache.Smoke.ps1 | Container ID ve PostgreSQL user/database parametreleri; eski lab default'ları korunur. PS7 negatif HTTP yanıtları uyarlanır. Empty miss/key/TTL, PostgreSQL kısa süre kapalıyken cache hit, mutation invalidation, 400/404 key korunması ve TTL expiration. CI TTL 10s yalnız fixture ayarıdır; uygulama default'u 60s kalır. |
| Module8.Readiness.Smoke.ps1 | Project/base/override parametreli; expected service adları `config --services` ile alınır. Eski dört servisli lab sabit altı sayısına dönüştürülmez. Default iki dependency deneyi korunur; CI Redis outage seçer. Cache testindeki kısa PostgreSQL durdurması ayrı cache-hit kanıtıdır. |
| Module11.Compose.Smoke.py | Hazırlık/cleanup ve eksik Compose-specific nullable/persistence/monitoring kabulünü bağlar; child nonzero veya timeout job'ı başarısız yapar. |

Windows kernel32/process yönetimine bağlı Module9.Configuration.Smoke.ps1 Ubuntu'ya taşınmadı; 20 senaryo mevcut Windows job'da çalışır. Host API process/user-secrets bekleyen Module3E.Persistence.Smoke.ps1 doğrudan çağrılmaz; kabul kriterleri gerçek container restart ile doğrulanır. `dotnet test`/unit-test coverage iddiası yoktur.

### Güvenli hata ve temizlik

Native stdout/stderr bellekte yakalanır ve üretilen credential'lar için kontrol edilir. Nonzero veya timeout kabulü durdurur. Raw exception, resolved config, full inspect, HTTP error body ve raw log artifact'i paylaşılmaz. `failure()` tanısı yalnız state/health/exit/restart alanlarını ve allowlist ile cache/request olaylarını gösterir. `always()` cleanup başarı/başarısızlıkta çalışır, sahiplik/isim kontrolünden geçmeyen volume'u silmez. Runner'ın zorla kaybı/job hard timeout halinde step çalışması garanti edilemez; explicit cleanup sonucu ayrıca kabul kanıtıdır.

Yerel çalıştırma (repo kökü; .NET 10, Docker/Compose, Python ve PowerShell 7):

```powershell
$ciState = Join-Path ([IO.Path]::GetTempPath()) ('fullstackops-ci-' + [guid]::NewGuid().ToString('N'))
try {
    python tests/Module11.Compose.Smoke.py prepare --state $ciState
    if ($LASTEXITCODE -ne 0) { throw 'CI preparation failed' }
    python tests/Module11.Compose.Smoke.py test --state $ciState
    if ($LASTEXITCODE -ne 0) { throw 'CI runtime acceptance failed' }
} finally {
    python tests/Module11.Compose.Smoke.py cleanup --state $ciState
    if ($LASTEXITCODE -ne 0) { throw 'CI cleanup failed' }
}
```

### Yerel gerçek sonuçlar — 4 Ekim 2026

- Git başlangıçta temiz. Docker 29.6.1, Compose v5.3.0, SDK 10.0.401, Python 3.14.7. Resmî PowerShell 7.6.6 portable ZIP checksum ile doğrulanıp yalnız geçici dizinde kullanıldı.
- Önce eski testler: CRUD PS7'de beklenen HTTP404'ü unhandled hata olarak verdi; Module 8 altı sağlıklı servisi dört servis varsayımıyla reddetti. İkisi exit1; PASS sayılmadı. Minimal uyarlamalar sonrası aşağıdaki regresyon geçti.
- InitialCreate SQL application/reapply ve empty DB PASS; Release build 0 warning/0 error.
- Nginx GET200, POST201+Location, PUT200, DELETE204; empty/whitespace400 ve missing404 PASS. Altı alan, nullable description/non-null timestamps ve restart sonrası birebir JSON korunması PASS.
- Cache miss/key, TTL **10s**, PostgreSQL kapalıyken cached GET200, sonraki hit, POST/PUT/DELETE invalidation, 400/404 key korunması ve TTL expiration PASS.
- Redis kapalı: aynı API running, health/live200, ready503, Docker unhealthy, tasks500. Redis geri gelince aynı API ready200/healthy/tasks200 ve altı servis healthy. PASS.
- Internal metrics, Prometheus target UP ve Grafana provisioned datasource/Overview API kontrolü PASS. Task0/history1/cache temizliği PASS.
- Safe diagnostics ve cleanup PASS: yalnız altı test container'ı/network/üç volume ve geçici dosyalar silindi. Başlangıçtaki 12 unrelated container ID/state ve 21 volume adı korundu. Altı diğer network ID'si aynı; varsayılan bridge `a8ca947b4254` → `32d288b04c50` değişti. Nedeni doğrulanmadı; Docker configuration değiştirilmedi.
- Scanner PASS; fixture kaynak yazımındaki iki false-positive, scanner gevşetilmeden tuple key/value biçimiyle giderildi. Secret fixture **19/19 PASS**, canary output check; diff check PASS.
- Resmî checksum kontrollü actionlint 1.7.12: ilk indirmede yanlış `.tar.gz` uzantısı başarısızdı, doğru Windows `.zip` kullanıldı. Lint job-level `runner` context hatasını yakaladı; state yolu Bash runner env değişkenleriyle düzeltildi. Son lint PASS; shellcheck/pyflakes ayrı çalıştırılmadı.

### İlk gerçek hosted kabul

Commit: `1e70be45b7842f29aa47f0e9514eb6250fb171ab` — `ci: add isolated Compose runtime acceptance`.

[Run 37198834372](https://github.com/EnsarAslannn/fullstack-ops-lab/actions/runs/37198834372), `push/main`, **completed / success**, 4 Ekim 2026. Run SHA'sı implementation commit'iyle eşleşir; hosted kabul local PS7 sonucundan çıkarılmadı.

| Job | Gerçek sonuç | UTC başlangıç–bitiş | Süre |
| --- | --- | --- | --- |
| [Linux build/config](https://github.com/EnsarAslannn/fullstack-ops-lab/actions/runs/37198834372/job/111426147665) | success; unchanged baseline | 11:28:07–11:29:19 | 1m12s |
| [Windows configuration/secrets](https://github.com/EnsarAslannn/fullstack-ops-lab/actions/runs/37198834372/job/111426147711) | success; gerçek 19 secret fixture + 20 configuration PASS satırı sayıldı | 11:28:09–11:29:57 | 1m48s |
| [Linux isolated Compose runtime](https://github.com/EnsarAslannn/fullstack-ops-lab/actions/runs/37198834372/job/111426147578) | success; preparation, acceptance ve cleanup step'leri geçti | 11:28:07–11:30:46 | 2m39s |

Runtime tools: .NET **10.0.401**, Python **3.12.3**, PowerShell **7.6.6**, Compose **v2.38.2**. Runtime Release build **0 warning / 0 error**. Süreler tek run gözlemidir; performans garantisi değildir.

Hosted logdaki gerçek kanıtlar ayrı ayrı kontrol edildi:

- InitialCreate review/application/idempotent reapply ve empty DB; altı servis running/healthy.
- Phase 0B GET200/POST201+Location/PUT200/DELETE204/400/404; Module 5 empty/nonempty miss-hit, Redis key ve **TTL10s**, başarılı mutation invalidation, 400/404 key korunması, TTL expiration.
- Redis outage: aynı API running, health/live200, ready503, Docker unhealthy ve Task500; recovery: aynı API ready200/healthy/Task200.
- Altı JSON alanı, nullable description ve non-null timestamps; API restart sonrası aynı ID ile birebir alan kalıcılığı.
- Internal metrics, Prometheus target UP, Grafana datasource ve provisioned Overview API kontrolü.
- Task0/history1/cache temizliği; cleanup step'i ve final PASS mesajı: owned container/network/üç volume ve temporary config/SQL kaldırıldı.
- Runtime `fixture-` + 48 hex credential deseni hosted logda yok. Windows canary ve tam test connection string desenleri yok; child testler stdout/stderr canary denetimini yaptı. Raw config/inspect/log artifact'i yüklenmedi.

İlk hosted run'da düzeltme/retry gerekmedi. Başarısız runtime step cleanup yolunun yapısal `always()` garantisi ve yerel başarısız test kanıtı var; hosted job interruption/hard timeout deneyi yapılmadı. Bu sonuçları kaydeden documentation push'u workflow'u tekrar tetikler; o run'ın sonucu görev raporunda verilir, yalnız yeni run ID'si için tekrar tekrar commit oluşturulmaz.

### Öğrenme ve kalan kapsam

CI runner local makinenin hazır database/secret'larını taşımaz. Boş CI volume'u ve explicit migration hazırlığı schema sorunlarını görünür yapar. Healthy olmak CRUD sözleşmesini kanıtlamaz; cache hit kanıtı DB kapalıyken de liste alınmasıdır. API restart veriyi korur çünkü PostgreSQL ayrı volume'dadır. Test başarısı ve owned-resource cleanup ayrı kapılardır.

Fork PR execution, temiz bilgisayarda developer onboarding, browser/load/production deploy ve Module 11 final kabulü bu adımda doğrulanmaz. Repository secret kullanmayan trigger/permissions tasarımı korunur; GitHub fork approval politikası ayrıca uygulanabilir. Sonraki küçük adım yalnız öneri: şartnameye göre **Module 11 final kabulü ve öğrenme değerlendirmesi**; GHCR publishing opsiyoneldir ve uygulanmadı.

## Module 11 — Final kabul ve öğrenme değerlendirmesi

**Completed — zorunlu şartname kriterleri PASS (5 Ekim 2026).** Bu kabul CI kapsamındadır; production deployment veya eksiksiz test coverage anlamına gelmez. Aşağıdaki açık sınırlamalar Completed kararından ayrı gösterilir. Önceki 11A/11B bölümlerindeki NOT VERIFIED kayıtları o adımların tarihindeki durumdur; aynı-repository PR kabulü bu bölümde tamamlandı.

Başlangıç `main` çalışma alanı temizdi, local/remote HEAD `3749afa5c07e103ae54e3a9d7c44bb11eec00d05` idi. Workflow/uygulama/test kodu değiştirilmedi. Önceki başarılı push run'ları ve source/step/log kanıtları incelendi; local Compose stack veya aynı eski runtime deneyi yeniden başlatılmadı. Yalnız eksik PR event kanıtını almak için mevcut workflow'un gerçek PR çalışması kullanıldı.

### Kanıtlar ve commit eşleştirmesi

| Kanıt | Event | Run head SHA | Sonuç |
| --- | --- | --- | --- |
| [E1 — ilk baseline](https://github.com/EnsarAslannn/fullstack-ops-lab/actions/runs/37196281851) | push | `4b81604db117fd7adf80c637126e79f0ea475655` | Linux/Windows success; ilk npm cache miss |
| [E2 — baseline kayıt commit'i](https://github.com/EnsarAslannn/fullstack-ops-lab/actions/runs/37196642619) | push | `1d70267f2336f62fbbe397b2cdb56ae47dc1e062` | İki job success; npm cache restore olsa da npm ci/build çalıştı |
| [E3 — runtime implementasyonu](https://github.com/EnsarAslannn/fullstack-ops-lab/actions/runs/37198834372) | push | `1e70be45b7842f29aa47f0e9514eb6250fb171ab` | Üç job ve runtime cleanup success |
| [E4 — son push kabulü](https://github.com/EnsarAslannn/fullstack-ops-lab/actions/runs/37199240476) | push | `3749afa5c07e103ae54e3a9d7c44bb11eec00d05` | Üç job ve runtime cleanup success |
| [E5 — draft PR kabulü](https://github.com/EnsarAslannn/fullstack-ops-lab/actions/runs/37290500053) | pull_request | `3749afa5c07e103ae54e3a9d7c44bb11eec00d05` | Üç job ve runtime cleanup success |

E5, [aynı-repository draft PR #2](https://github.com/EnsarAslannn/fullstack-ops-lab/pull/2) ile tetiklendi. Yeni commit üretmemek için geçici base `ci-acceptance-20261005-base-a4b921` E3 commit'ine, head `ci-acceptance-20261005-head-a4b921` E4 commit'ine bağlandı. PR farkı yalnız mevcut iki CI dokümantasyon dosyasıydı; workflow ve runtime testleri main ile aynıydı. PR hedefi geçici base dalıdır; **main'i hedefleyen gerçek bir PR veya fork testi değildir**.

PR run metadata'sındaki head SHA ile checkout edilen commit ayrıdır: checkout logu ve `refs/pull/2/merge`, gerçek test merge SHA'sını **`b25c5967f90b6c19b4ea0d4fb7f50dc67cfa43c0`** olarak doğruladı. `pull_request` merge ref davranışı [GitHub event belgesinde](https://docs.github.com/en/actions/reference/workflows-and-actions/events-that-trigger-workflows#pull_request) açıklanır. Başarılı head run'ını, farklı bir checkout ağacının kanıtı gibi yorumlamamak gerekir.

| E5 job | Gerçek sonuç | UTC başlangıç–bitiş | Süre |
| --- | --- | --- | --- |
| [Linux build/config](https://github.com/EnsarAslannn/fullstack-ops-lab/actions/runs/37290500053/job/111699508124) | success; sekiz restore/build/config step'i tek tek doğrulandı | 09:30:40–09:31:37 | 57s |
| [Windows configuration/secrets](https://github.com/EnsarAslannn/fullstack-ops-lab/actions/runs/37290500053/job/111699508075) | success; logdan 19 secret fixture ve 20 configuration PASS sayıldı | 09:31:36–09:33:21 | 1m45s |
| [Linux isolated Compose runtime](https://github.com/EnsarAslannn/fullstack-ops-lab/actions/runs/37290500053/job/111699507788) | success; 11 kabul log işareti ve cleanup doğrulandı | 09:30:40–09:33:50 | 3m10s |

### Şartname ve güvenilirlik kabul tablosu

PASS bir test/inceleme kapsamında kanıtı olduğu anlamına gelir. NOT VERIFIED gerçekten çalıştırılmamış kapsamı gösterir; optional veya kapsam dışı satırları zorunlu bir başarının yerine kullanmayız.

| Kriter | Sonuç | Somut kanıt / sınır |
| --- | --- | --- |
| Her push otomatik doğrulama | PASS | E1–E4 gerçek push run'ları; `ci.yml` branch/path filtresi olmadan push içerir. |
| pull_request tetikleyicisi | PASS | E5 event=pull_request, draft PR #2, üç job success. Geçici base hedefiyle aynı-repository deneyidir. |
| Backend restore ve Release build | PASS | E5 Linux restore/build step'leri success; runtime Release logunda 0 warning/0 error. Windows build de success. |
| Frontend locked install ve build | PASS | E5 `Frontend locked install`/`Frontend TypeScript and Vite build` success; `npm ci` lock dosyasını kullanır. |
| Backend ve frontend Docker image build | PASS | E5 iki `Build ... image` step'i success; runtime ayrı runner'da Compose `--build` ile hazırlanır. |
| Compose configuration doğrulaması | PASS | E5 `Validate Compose with isolated fake settings` success; runtime fake env+override için ayrıca config -q. Çözümlenmiş config yazdırılmaz. |
| Prometheus config doğrulaması | PASS | E5 `Validate Prometheus configuration` success; sabit image'dan promtool check config. |
| Backend davranış testleri | PASS | E3–E5 gerçek CRUD/cache/readiness/restart smoke kabulü. Unit-test projesi yok; dotnet test ile coverage iddia edilmez. |
| Configuration ve secret testleri | PASS | E5 gerçek 20/20 configuration ve 19/19 fixture; negatif startup yalnız nonzero ile kabul edilmiyor, güvenli mesaj/canary yokluğu da aranıyor. |
| İzole Compose project/credential/volume | PASS | Harness UUID project, yeni owner-labelled PostgreSQL volume, runner-temp fake env/override; development env/user-secrets/external volume'a bağımlılık yok. E3–E5 başarı kanıtı. |
| Açık migration hazırlığı | PASS | E5 InitialCreate SQL review/apply/reapply marker; ON_ERROR_STOP ve UTF-8 stdin; history1/tasks0 doğrulaması. API startup'a migration eklenmedi. |
| Altı servis bounded healthy | PASS | E5 tam servis kümesi running/healthy; PostgreSQL wait120s, stack wait180s, ek health180s. |
| Nginx CRUD/Location/JSON/400/404 | PASS | E5 Phase0B marker + exact-six-fields/nullable marker; GET200, POST201, PUT200, DELETE204, validation400/missing404. |
| Redis miss/hit/invalidation | PASS | E5 Module5 marker; empty/nonempty cache, gerçek TTL10s/expiration, mutation invalidation ve 400/404 key korunması. PostgreSQL kısa süre kapalıyken cached GET200 hit kanıtıdır. |
| Liveness/readiness ve aynı-container recovery | PASS | E5 Redis kapalıyken running/live200/ready503/unhealthy/tasks500; aynı API geri gelince ready200/healthy/tasks200. |
| API restart sonrası PostgreSQL kalıcılığı | PASS | E5 aynı API container ID ve birebir altı JSON alanı; yalnız test Task'ı temizlenir, history1 korunur. |
| Monitoring runtime kapsamı | PASS | E5 internal metrics, Prometheus api:8080/metrics UP ve Grafana datasource/Overview provisioning API marker. Browser/tüm panel sorguları bu CI kapsamına dahil değil. |
| Başarısız komutların başarısızlık kapıları | PASS | Python nonzero/timeout → AcceptanceError → exit1; PS native LASTEXITCODE kontrolleri; Bash fail-fast. Bu kabulde yerel child exit7 gerçekten reddedildi. Kasıtlı başarısız hosted job ayrıca denenmedi. |
| Timeout ve güvenli tanı | PASS | Job timeout30/20/25min; subprocess timeout; failure() allowlisted state/cache/request tanısı. Yerel timeout ve stdout/stderr canary deneyi güvenli hata verdi; eski yerel diagnostics kanıtı korunur. |
| Başarı ve gözlemlenen iptalde cleanup | PASS | E3–E5 cleanup success. Bu görevde iptal edilen iki hazırlık run'ında da cleanup success/owned-resource final kontrolü. İsim/owner doğrulanmadan volume silinmez. |
| Minimum permissions / full action SHA | PASS | contents:read, checkout persist-credentials:false; checkout/setup-dotnet/setup-node tam 40-hex SHA; yeni yetki/secrets/registry login yok. Image/SDK tag'lerinin mutable olması ayrı sınırdır. |
| Cache zorunlu adımları atlatmıyor | PASS | E1 `npm cache is not found`; E2 cache restored successfully. E2 npm ci ve frontend build step'leri success. Cache node_modules/dist/env yerine npm download cache'tir. |
| Fork için secret gerektirmeyen tasarım | PASS | Normal pull_request, contents:read, workflow'da secrets input'u yok; fake generated credential. Bu statik tasarım sonucu gerçek fork run'ı demek değildir. |
| Gerçek fork PR kabulü | NOT VERIFIED | Yeni fork/hesap oluşturulmadı. Fork approval/token/cache davranışı bu deneyle kanıtlanmadı. |
| Main-target PR / PR synchronize / branch protection | NOT VERIFIED | PR #2 geçici base'e opened olayıydı. Main-target, yeni push ile synchronize ve required-check enforcement ayrıca denenmedi. |
| Runner kaybı/hard timeout altında her durumda cleanup | NOT VERIFIED | always() çalışan runner gerektirir; gözlemlenen cancellation başarısını runner kaybı garantisine genişletemeyiz. |
| Kasıtlı failing hosted job / hosted failure diagnostics | NOT VERIFIED | Mevcut hosted source run'ları green. Yerel native/timeout/canary hataları ve statik failure gate incelendi; yeni kırık workflow commit'i oluşturulmadı. |
| GHCR image publishing / production CD | NOT VERIFIED | Şartnamede opsiyonel; workflow image'ı build eder, publish/deploy etmez. Tamamlanma blocker'ı değildir. |

Zorunlu minimumlar ve mevcut ideal pipeline kapsamı karşılandı; FAIL bulunmadı. GitHub başarı göstergesi yalnız bu kontroller için anlamlıdır, yukarıdaki NOT VERIFIED satırlarını PASS'a dönüştürmez.

### Yerel son kontroller ve PR temizliği

- Salt okunur source/run/step/log incelemesi; yeni local build/stack/migration deneyine ihtiyaç bulunmadı.
- İzole child native exit7, kısa timeout, stdout/stderr canary ve unsafe cleanup path → exit1 kontrolleri geçti. Gerçek env/user-secrets okunmadı; bu kontrol Docker veya fixture dizini oluşturmadı.
- PR için iki geçici dalın push'u [37290421743](https://github.com/EnsarAslannn/fullstack-ops-lab/actions/runs/37290421743) ve [37290421830](https://github.com/EnsarAslannn/fullstack-ops-lab/actions/runs/37290421830) yinelenen push run'larını başlattı. Yalnız bu run'lar bilinçli iptal edildi; sonuçları cancelled, PASS/FAIL kabul run'ı sayılmadı. Her ikisinde preparation cancelled fakat cleanup success ve owned-resource kontrol mesajı vardı. Başka run iptal edilmedi.
- E5 tamamlandıktan sonra PR #2 **CLOSED**, mergedAt=null; 5 Ekim 2026 UTC09:36:57. İki geçici remote dal explicit adları/SHA'ları kontrol edilerek silindi; local dal oluşturulmamıştı. Main/remote SHA değişmedi. PR body temporary dosyası kaldırıldı.
- Repository secret regression check ve git diff --check final dokümantasyon üzerinde çalıştırıldı. Gerçek `.env` ignored/untracked; Git geçmişi bu taramanın kapsamında değil.
- Bu görevde yalnız Module 11 README ve PROJECT_STATUS değişti; index'e ekleme, yeni commit, main push, workflow/test/uygulama değişikliği yapılmadı. Dal push/deletion yalnız izin verilen PR test istisnasıdır.

### Öğrenme değerlendirmesi

**CI ve CD:** CI değişikliğin derlenmesini ve seçili testleri otomatik doğrular. Burada üç job CI yapar. Docker image üretmek tek başına CD değildir; image publishing, deployment ve production'a release adımı yoktur. GHCR şartnamede opsiyoneldir.

**Workflow / job / step / runner:** `ci.yml` tüm workflow'dur. Linux build/config, Windows configuration/secrets ve Linux runtime üç ayrı job'dır; needs olmadığı için paralel ilerleyebilir. Bir job içindeki restore/build/test komutları step'tir. Runner komutları çalıştıran geçici makinedir; job'lar aynı canlı container/volume'u paylaşmaz. [GitHub job belgesi](https://docs.github.com/en/actions/how-tos/write-workflows/choose-what-workflows-do/use-jobs) bu ayrımı açıklar.

**push / pull_request:** Main push E4'ü, draft PR opened E5'i tetikledi. İkisi aynı head değişikliği için ayrı run üretebilir. PR run checkout'u merge ref olabilir; head SHA/checkout SHA eşleştirmesini yap. Fork'ta development secret taşınmaz; approval ve token davranışını gerçek fork deneyi olmadan kanıtlanmış sayma.

**Cache / artifact:** Npm cache daha önce indirilen paketleri tekrar indirmeyi azaltır; cache hit olsa da npm ci/build çalışır. Artifact ise rapor veya build çıktısını run sonrasında paylaşmak/saklamak içindir. Bu workflow artifact upload yapmaz; raw config/env/log artifact'i oluşturmak secret sızıntısı riski getirir. Docker'ın job içindeki layer cache'i ile job'lar arasında npm download cache'i aynı kapsam değildir.

**Build / runtime:** Release/Vite/Docker build başarısı PostgreSQL schema'sını, ağ DNS'ini veya HTTP201 Location'ı kanıtlamaz. Runtime job altı servisi çalıştırıp Nginx üzerinden CRUD, Redis key ve kesinti/recovery ile gerçek davranışı kanıtlar. Buna rağmen browser UX, load/benchmark veya production güvenliği testi değildir.

**Geçici ortam / migration:** CI volume'u sıfırdan oluşturulur; local fullstack-ops-postgres-data kullanılamaz. Önce PostgreSQL, sonra incelenmiş existing InitialCreate SQL, ardından API ve diğer servisler gelir. Health ready200 tek başına tasks tablosunu kanıtlamaz. Production design-time process config'i user-secrets'a bağımlılığı önler; runtime image SDK/EF CLI taşımadığı için migration ayrı bir hazırlık adımıdır.

**Yeşil run'ın sınırı:** Green belirli commit/checkout, araç sürümleri ve senaryoların geçtiğini söyler. Tüm bug'ların yokluğu, unit coverage, fork davranışı, production deployment veya gelecekte mutable image tag'inin aynı kalması sonucu çıkarılmaz. Canary/scanner yalnız bilinen sızıntı biçimlerini yakalayan ek korumadır.

**Başarısız run'ı inceleme:** Önce event/head SHA/checkout ref'i ve ilk başarısız step'i belirle. Build hatası, configuration negatif testi ve dependency outage farklıdır. Beklenen negatif configuration testinde güvenli mesaj + canary yokluğu gerekir; sadece nonzero yeterli değildir. Native exit/job sonucu, bounded safe diagnostics ve cleanup step'ini ayrı kontrol et. İncelemeyi `gh run view <id> --json ...` ile başlat; raw logu terminale/issue'ya taşımadan bellek içinde filtrele. [GitHub shell belgesi](https://docs.github.com/en/actions/reference/workflows-and-actions/workflow-syntax#jobsjob_idstepsshell) fail-fast davranışını açıklar; PowerShell native LASTEXITCODE kontrolünü source ile eşleştir.

Kendi kelimelerinle cevapla:

1. E5 run head SHA'sı ile checkout SHA'sı neden farklıydı?
2. Npm cache hit olsa bile neden npm ci gerekli?
3. API healthy iken InitialCreate uygulanmamışsa hangi kontrol bunu yakalar?
4. Redis kapalıyken live200/ready503 olması neyi ayırır?
5. Green run neden fork kabulü veya production deployment kanıtı değildir?

Küçük alıştırmalar (bu kabulde uygulanmadı):

1. Workflow'daki bir build, bir negatif test ve cleanup step'inin hata yayılımını kağıt üzerinde çiz; hangi exit code job'ı durdurur, hangisi test tarafından beklenir?
2. E5'in step özetinden migration → healthy → CRUD → restart → cleanup kanıtlarını bul; secret içeren raw log/config paylaşmadan kısa bir kanıt listesi yaz.

### Şartnameye göre sonraki adım

Şartnamede Module 11'den sonra **11. Troubleshooting Labs**, ilk senaryo **Wrong Localhost** vardır; bir Module 12 tanımlı değildir. Sonraki küçük öneri: mevcut Wrong Localhost kanıtını troubleshooting şablonundaki Scenario/Symptoms/Expected Behaviour/Investigation/Root Cause/Fix/Verification/What We Learned alanlarıyla eşleştirip belge eksiklerini çıkar. Bu görevde o inceleme/uygulama başlatılmadı; opsiyonel GHCR/CD kendiliğinden eklenmedi.

---

6 Ekim 2026 ortak dokümantasyon dizini: aşağıdaki standart başlıklar tarihsel ayrıntıya bağlanır; yeni deney veya yeni PASS sonucu değildir. Eski container/port/ölçüm değerleri kendi aşamasına aittir. Güncel altı servis ve DoD sınırları [mimari belgesindedir](../../docs/architecture.md#dokümantasyon-standardı-ve-definition-of-done).

## Opsiyonel GHCR image publishing — 7 Ekim 2026

Şartnamenin [Module 11 opsiyonel registry adımı](../../PROJECT_SPEC.md#modül-11--github-actions-ci) ve [Advanced Lab D](../../PROJECT_SPEC.md#advanced-lab-d--container-registry) kapsamında iki uygulama image'ını GHCR'a yayınlayan akış eklendi. Önceki 11A/11B ve final kabul bölümleri tarihsel kanıtlardır; aşağıdaki yeni kapsam onlara otomatik PASS eklemez.

### Tetikleyici, izin ve akış

- Mevcut push/pull_request build/configuration/runtime job'ları korunur. Linux job ayrıca offline publishing güvenlik testlerini çalıştırır.
- `publish-images` yalnız `push` + `refs/heads/main` için çalışır; `needs` üç mevcut job'ın **tamamının** başarısını bekler. PR ve fork PR'de registry login/push yapılmaz; `pull_request_target` yoktur. Script aynı event/ref kontrolünü tekrar yapar.
- API/frontend iki matrix çalışmasıdır; mantıksal job sayısı dört, main push'ta toplam runner çalışması beştir. Yeni action eklenmedi; checkout mevcut doğrulanmış tam SHA ile sabittir, persisted Git credential yoktur.
- `contents: read` global kalır; yalnız publishing job'ında ayrıca `packages: write` vardır. `GITHUB_TOKEN` step environment'ındaki `GHCR_TOKEN` adıyla alınır; PAT/repository secret/development credential eklenmez.
- [Publishing script'i](../../scripts/Module11.PublishImages.py) token'ı yalnız `docker login --password-stdin` girişine verir; Docker child environment'ından kaldırır. Geçici, ayrı `DOCKER_CONFIG` kullanır; build arg/ENV veya build context'e token taşımaz. Logout ve yalnız sahibi olduğu auth dizininin temizliği hata durumunda da denenir. Runner kaybında cleanup garantisi yoktur.
- Mevcut Dockerfile/context ile `linux/amd64` image yeniden build edilir; source/revision OCI label'ları eklenir. Önce SHA tag push edilir, registry digest bulunur, digest ile pull edilir; image ID ve kaynak revision doğrulanır. **Bundan sonra** `latest` push edilir. GitHub step summary image, commit ve digest'i kaydeder.
- Docker hataları nonzero exit üretir; raw stdout/stderr veya exception ayrıntısı credential içerebileceğinden loglanmaz. Build için 600 s, diğer Docker işlemleri için 180 s, job için 20 dakika limit vardır. Aynı kaynak commit'i doğrulanır; önceki CI job'ının image artifact'ı aktarılmaz. Mutable base tag'lerle yeniden build, aynı binary digest garantisi değildir.

### Image adları ve tag'ler

| Image | Tag |
| --- | --- |
| `ghcr.io/ensaraslannn/fullstack-ops-lab-api` | `sha-<tam-40-karakter-commit-sha>` ve `latest` |
| `ghcr.io/ensaraslannn/fullstack-ops-lab-frontend` | `sha-<tam-40-karakter-commit-sha>` ve `latest` |

Namespace Docker kurallarına uygun küçük harfe çevrilir. `latest` hareketli bir alias'tır; commit tag'i izlenebilirlik sağlar ama registry tag'leri teknik olarak üzerine yazılabilir. **Digest**, belirli image içeriğini sabitler. İki component atomik bir yayın değildir; biri başarısızken diğerinin SHA image'ı yayınlanmış olabilir. Workflow başarısı bütün matrix çalışmalarının sonucuna bağlıdır. Release, multi-architecture, signing/SBOM, deployment veya production kabulü eklenmedi.

Yeni GHCR package varsayılan olarak private olabilir; repository public olması anonim pull kabulü değildir. Görünürlük otomatik değiştirilmez. İlk yayın sonrası package'ın repository bağlantısı ve Actions erişimi incelenmelidir; mevcut aynı adlı bağlantısız package varsa `GITHUB_TOKEN` push izni olmayabilir. Production credential'ları veya local development secret'ları bu sorunu çözmek için CI'a taşınmaz.

Package erişimi olan kullanıcı önce `docker login ghcr.io` ile interaktif giriş yapabilir; parolayı/token'ı komut satırına veya `.env` dosyasına koyma. GHCR'a erişim yetkisi hazırsa:

```powershell
docker pull ghcr.io/ensaraslannn/fullstack-ops-lab-api:sha-<commit-sha>
docker pull ghcr.io/ensaraslannn/fullstack-ops-lab-frontend:sha-<commit-sha>
# Daha kesin içerik sabitlemesi: gerçek run summary'deki image@sha256:digest referansını kullan.
```

Bu komutlardaki SHA yer tutucudur, çalıştırılmış registry kanıtı değildir. Compose hâlâ mevcut kaynak Dockerfile'larından build eder; GHCR image yayınlamak Compose'u deploy etmez ve migration/volume hazırlığını kaldırmaz.

### Doğrulama ve sınırlar

| Kontrol | Sonuç / kanıt |
| --- | --- |
| Integration test commit/push | PASS — `9e5e2ea2bd4a898fce5a68b6ceedb128cc4571d2`, [run 37593868455](https://github.com/EnsarAslannn/fullstack-ops-lab/actions/runs/37593868455); üç job success, 21 hosted integration case PASS |
| Publishing logic offline testleri | PASS — [7 unittest metodu](../../tests/Module11.PublishImages.Test.py), component/event/ref/input/CLI failure/timeout/digest/ID/revision alt senaryoları; fake Docker boundary, gerçek login/push yok |
| Canary çıktısı ve auth cleanup | PASS — fixture çıktılarında generated token yok; Docker child argument/environment içinde yok, yalnız login stdin; owned auth dizinleri temiz |
| Workflow syntax / expressions | PASS — official actionlint v1.7.12, indirilen SHA256 doğrulandı; shellcheck aracı kurulu olmadığından devre dışı |
| Repository secret kontrolü / diff check | PASS — değer gösterilmeden; scanner kapsamı/istisnaları değiştirilmedi |
| Gerçek GHCR job / registry roundtrip | PASS — commit `1a9d57400e920263d227ed6383301bf72940aa25`, [run 37597426324](https://github.com/EnsarAslannn/fullstack-ops-lab/actions/runs/37597426324); üç CI gate ve iki publishing job success; SHA/latest push, digest pull, image ID/revision eşleşmesi |
| Package görünürlüğü / repository metadata / anonim pull | NOT VERIFIED — mevcut CLI kimliği package metadata API'sine erişemedi; görünürlük/izin değişikliği veya yeni credential oluşturulmadı. Hosted GITHUB_TOKEN ile push/pull başarılıdır; anonim erişim kanıtı değildir |
| Gerçek fork PR yayın engeli / deliberately failing hosted job | NOT VERIFIED — yerel guard testleri gerçek fork kabulü değildir |

İlk gerçek yayın 7 Ekim 2026 UTC09:02'de tamamlandı. Doğrulanan digest'ler bu kaynak commit'ine aittir; `latest` sonraki main push'larıyla değişebilir:

| Component | Registry digest | Kaynak revision |
| --- | --- | --- |
| API | `ghcr.io/ensaraslannn/fullstack-ops-lab-api@sha256:802b3c29371ea814a69a46163bf0117718b837e766e63936e754c76cb98110fd` | `1a9d57400e920263d227ed6383301bf72940aa25` |
| Frontend | `ghcr.io/ensaraslannn/fullstack-ops-lab-frontend@sha256:2b1afe9210f5b90d8bf49066a2c6756dad01af639628baf2b6cf6ecf196f2214` | `1a9d57400e920263d227ed6383301bf72940aa25` |

Hosted job'ların geçici auth cleanup'ı tamamlandı; yalnız registry image'ları yayınlandı. Development `.env`, user-secrets, PostgreSQL volume'u veya yerel Docker kaynakları bu kabul için kullanılmadı. Bu sonuç dokümantasyon commit'inin yeni run'ı veya package public erişimi için kanıt sayılmaz.

Yerel kontrol:

```powershell
python tests/Module11.PublishImages.Test.py
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/Module9.SecretLeakage.Check.ps1
git diff --check
```

Windows sandbox ilk fixture denemesinin temporary cleanup erişimini engelledi; uygun izinle testler geçti ve yalnız bu denemenin altı fixture dizini temizlendi. Python bytecode üretimi testte kapatıldı; yanlışlıkla oluşmuş yalnız bu modülün bytecode'u kaldırıldı. Scanner Python dinamik token atamalarına başlangıçta false positive verdi; açık `registry_credential` değişken adı kullanıldı, scanner gevşetilmedi. Uygulama/Compose/.env/user-secrets/volume veya mevcut container durumları değiştirilmedi.

Resmî kaynaklar: [GHCR authentication, private visibility, OCI labels ve digest](https://docs.github.com/en/packages/working-with-a-github-packages-registry/working-with-the-container-registry), [Actions publishing permissions](https://docs.github.com/en/packages/managing-github-packages-using-github-actions-workflows/publishing-and-installing-a-package-with-github-actions), [Docker login](https://docs.docker.com/reference/cli/docker/login/).

Öğrenme: registry image dağıtır; CI build/test kaynağı doğrular; deployment çalışan ortamı günceller. Commit SHA kaynak revision'ıdır, image digest içerik kimliğidir. `latest` sürüm sabitlemesi değildir. Job'a özgü write permission ve PR guard, test eden her kodun registry'ye yazabilmesini engeller.

### Registry image runtime kabulü — 9 Ekim 2026

Bu kabul mevcut publishing implementasyonunu korur. Başlangıçta `main` çalışma alanı temizdi; test edilen uygulama kaynağı **`4606fa2358ed2f559b96b2cd89f1801ef9c5e733`** idi. [Run 37755926772](https://github.com/EnsarAslannn/fullstack-ops-lab/actions/runs/37755926772) bu SHA için completed/success; üç CI gate ve iki publishing job success. API yayın kanıtı 8 Ekim UTC09:24:01, frontend kanıtı UTC09:23:40. Bunlar yeni bir yayın çalıştırıldığı anlamına gelmez; mevcut run ve yayın logları salt okunur incelendi.

| Component | Registry'den çekilen değişmez referans | Çalışan container `.Image` |
| --- | --- | --- |
| API | `ghcr.io/ensaraslannn/fullstack-ops-lab-api@sha256:062314cb87f6a727a7a9fc271005862e7e750b220a58a53ed9afc3c39183d43e` | `sha256:062314cb87f6a727a7a9fc271005862e7e750b220a58a53ed9afc3c39183d43e` |
| Frontend | `ghcr.io/ensaraslannn/fullstack-ops-lab-frontend@sha256:e72f4795363d30e613cc2192c3073895d7b2d037d31c04c2e11f78b4b3f74901` | `sha256:e72f4795363d30e613cc2192c3073895d7b2d037d31c04c2e11f78b4b3f74901` |

İki image'ın OCI revision label'ı kaynak SHA ile ve RepoDigests alanı seçilen referansla eşleşti. Bu iki image için yerel Docker Engine'in bildirdiği image ID ile registry digest eşitti; farklı platform/manifest yapılarında bunların her zaman aynı olacağı varsayılmaz. Kabul script'i referansın local image ID'sini container `.Image` ile ayrıca karşılaştırır.

**Package erişimi:** Mevcut Docker kimliğiyle iki digest pull PASS. Ayrıca ayrı, boş geçici `DOCKER_CONFIG` ve token içermeyen process environment ile iki anonim digest pull PASS; yeni credential/PAT veya login oluşturulmadı. Mevcut `gh` kimliği package metadata API'sini okuyamadı: ayardaki `visibility` ve repository bağlantısı **NOT VERIFIED**. Anonim pull bu iki referansa o anda anonim okuma erişimi olduğunu kanıtlar; package ayarının API'den okunduğu iddia edilmez. Ayarlar değiştirilmedi. Önceki 7 Ekim bölümünün erişim sınırları kendi tarihine aittir.

#### İzole hazırlık ve komutlar

[Mevcut Compose kabul script'i](../../tests/Module11.Compose.Smoke.py) opsiyonel registry modu kazanır; CI'nın mevcut parametresiz `prepare`/`test` akışı ve [publishing script'i](../../scripts/Module11.PublishImages.py) korunur. [Yedi offline güvenlik testi](../../tests/Module11.RegistryRuntime.Test.py) digest zorunluluğunu, eksik girdiyi, revision hatasında volume/state oluşmamasını, yanlış container image ID'sini, secret içeren command failure'ın güvenli çıktısını ve mevcut CI build davranışını kontrol eder. Fixture'lar Docker çağrı sınırını taklit eder; gerçek runtime kabulünün yerine geçmez.

Gerçekten yürütülen komutların tekrar kullanılabilir biçimi:

```powershell
$state = Join-Path ([IO.Path]::GetTempPath()) 'fullstackops-ci-ghcr-20261009-4606fa2'
$api = 'ghcr.io/ensaraslannn/fullstack-ops-lab-api@sha256:062314cb87f6a727a7a9fc271005862e7e750b220a58a53ed9afc3c39183d43e'
$frontend = 'ghcr.io/ensaraslannn/fullstack-ops-lab-frontend@sha256:e72f4795363d30e613cc2192c3073895d7b2d037d31c04c2e11f78b4b3f74901'
try {
    python tests/Module11.Compose.Smoke.py prepare --state $state --source-sha 4606fa2358ed2f559b96b2cd89f1801ef9c5e733 --api-image $api --frontend-image $frontend
    if ($LASTEXITCODE -ne 0) { throw 'Registry preparation failed.' }
    python tests/Module11.Compose.Smoke.py registry-test --state $state --pwsh powershell
    if ($LASTEXITCODE -ne 0) { throw 'Registry runtime acceptance failed.' }
} finally {
    python tests/Module11.Compose.Smoke.py cleanup --state $state
    if ($LASTEXITCODE -ne 0) { throw 'Owned resource cleanup failed; inspect safe diagnostics.' }
}
```

Bu komutlar aynı kaynak HEAD üzerinde çalıştırılmalıdır; `--source-sha` ile HEAD eşleşmezse preparation durur. İleride başka bir başarılı yayını test etmek için kaynak SHA ve iki digest birlikte güncellenmelidir. Örnek state dizini önceden varsa üzerine yazılmaz; yeni, benzersiz `fullstackops-ci-*` dizini seç. Linux/PowerShell7'de `--pwsh pwsh` kullanılır; bu kabul Windows PowerShell5.1 üzerinde yürütüldü.

Hazırlık, iki `docker pull image@sha256:...` çağrısından sonra geçici override'da API/frontend `build` alanlarını `!reset null` ile kaldırır ve `image` alanlarını digest referanslarına ayarlar. Son stack komutu **`up -d --no-build --pull never --wait --wait-timeout 180`** kullanır; API/frontend Docker image build veya tag çözümleme yapılmaz. Frontend yalnız rastgele localhost portunu yayınlar; diğer beş servis için host portu yoktur. Ana `compose.yaml` değişmez.

Yalnız fixture env'de üretilen sahte PostgreSQL/Grafana credential'ları kullanılır. Gerçek `.env` ve user-secrets okunmaz/değiştirilmez. Ayrı boş external test volume'u hazırlandı; önce PostgreSQL başlatıldı. Host'ta `dotnet tool restore`, solution restore/Release build ve mevcut `dotnet ef migrations script 0 InitialCreate --idempotent ... --configuration Release --no-build` yürütüldü. Host build yalnız migration SQL hazırlığı içindir; registry'den çekilen uygulama image'ını değiştirmez. Design-time process Production ve sahte, erişilemeyen bağlantı adresleri kullandı. SQL schema/history/migration kimliği incelendi; `psql -X -w -v ON_ERROR_STOP=1 -f /dev/stdin` ile iki kez uygulandı. İlk sorguda history **1**, tasks **0** idi. Yeni migration veya runtime otomatik migration eklenmedi.

#### Gerçek sonuçlar

| Kontrol | Sonuç |
| --- | --- |
| Docker/Compose | PASS — başlangıçta Engine kapalıydı; Docker Desktop hidden başlatıldı, Engine29.6.1/Compose5.3.0 erişilebilir oldu |
| Release build / açık migration | PASS — 0 uyarı/0 hata; `20260928113912_InitialCreate` uygulandı ve idempotent tekrar uygulandı |
| İzole Compose config | PASS — fixture env ile `config -q`; API/frontend digest referansları `config --images` ve container `Config.Image` ile doğrulandı |
| Altı servis | PASS — API/frontend/PostgreSQL/Redis/Prometheus/Grafana running/healthy |
| API image kimliği / health | PASS — digest image ID eşleşmesi; internal `/health`, `/health/live`, `/health/ready` **200** |
| Frontend image / HTML | PASS — digest image ID eşleşmesi; `/` **200**, React root mevcut |
| JavaScript / CSS | PASS — `/assets/index-CKhYhs0u.js` **200 application/javascript**, `/assets/index-6SMY9-rQ.css` **200 text/css**, içerikler boş değil ve HTML fallback değil |
| Nginx Task CRUD | PASS — mevcut [Phase0B smoke](../../tests/Phase0B.Tasks.Smoke.ps1): list/single GET200, POST201, PUT200, DELETE204, boş/whitespace başlık400, eksik/silinmiş ID404, timestamps ve Location |
| JSON / nullable sözleşme | PASS — ek gerçek POST/PUT/GET: tam altı alan; description `null`, createdAt/updatedAt dolu; Location tam `/api/tasks/{id}`; PUT sonrası tekil GET güncel kayıtla eşit |
| Kayıt/cache temizliği | PASS — test sonunda tasks **0**, migration history **1**; yalnız izole Redis instance'ındaki liste test key'i silindi |
| Publishing güvenlik / registry fixture testleri | PASS — mevcut publishing **7/7**, yeni registry kabul **7/7**; canary değerleri test stdout/stderr ve güvenli hata metninde yok |
| Secret regression / repository / diff | PASS — secret fixture **23/23**, repository scanner0, `git diff --check`0; gerçek `.env` ignored ve tracked değil |

Görevin Compose project'i `fullstackops-ci-92d38dc020e346ba8d3f6b0ed6bacc7c`, PostgreSQL volume'u aynı project + `-postgres` idi. Diğer iki yeni volume project'e ait `grafana_data` ve `prometheus_data` idi. Test frontend adresi `http://127.0.0.1:64645` yalnız bu deney sırasında açıktı; cleanup sonrası servis adresi değildir.

**Cleanup PASS:** Altı test container'ı, tek test ağı, üç test volume'u, fixture env/state/override/SQL ve geçici auth/envanter dosyaları kaldırıldı. `down -v`, prune veya development volume bağlantısı kullanılmadı. PostgreSQL volume sahiplik label'ı ve monitoring volume'larının tam project adları kontrol edildi. Yalnız bu görevde yeni çekilen iki digest referansı ayrıca image ID doğrulanarak kaldırıldı; registry'deki image'lar silinmedi. Başlangıç/bitiş aynı **18 container** (hepsi exited), **8 network** (aynı ID'ler), **21 volume**, **38 image liste girdisi**; mevcut development/ilişkisiz kaynaklar korundu. Docker Engine erişilebilir bırakıldı.

Sınırlar: Bu aynı Windows host üzerinde, mevcut dependency image cache'iyle izole registry runtime kabulüdür; temiz VM, production deployment, gerçek fork/PR publishing, retention/performans veya bütün monitoring/kesinti deneylerinin yeniden kabulü değildir. Gerçek tarayıcı/UI davranışı bu adımda yeniden denenmedi; istenen frontend dosya erişimi HTTP ile doğrulandı. Mevcut cache/readiness kesinti scriptleri ek kesinti senaryoları başlatılmadan korundu. Package metadata API erişimi hâlâ doğrulanamadı; anonim digest pull artık gerçek kanıttır. Publishing workflow'u, backend/frontend/Compose davranışı veya secret kaynağı değiştirilmedi; commit/push/image publishing yapılmadı.

Öğrenme: Başarılı push tek başına çalışan uygulama kanıtı değildir. Digest ile pull, OCI kaynak revision'ı, çalışan container image ID'si, açık migration ve gerçek HTTP sözleşmesi birlikte registry artifact'ının test edilen runtime davranışını gösterir. Migration hazırlığı ve credential/volume izolasyonu, image yayınlama işleminden ayrıdır.

## Goal

[Durum ve amaç](#durum-ve-amaç).

## What You Will Learn

[Kavramlar ve nedenleri](#öğrenme-değerlendirmesi).

## Architecture

[Bu aşamanın yapısı](#workflow-ve-izolasyon); [güncel sistem](../../docs/architecture.md#servisler-portlar-ve-ağ).

## Prerequisites

Bu tarihsel deneyin kaynak/port/credential ön koşullarını kendi komut bölümünden kontrol et. Güncel normal kurulum için [Module9 rehberini](../09-environment-configuration/README.md#13-temiz-bilgisayar-kurulum-rehberi) izle; önceki lab komutlarını development kaynaklarında körlemesine tekrarlama.

## Step 1

[Hazırlık ve komutlar](#hazırlık-ve-kabul-sırası).

## Step 2

[Davranışı çalıştırma ve gözlemleme](#şartname-ve-güvenilirlik-kabul-tablosu).

## Verification

[Gerçek sonuçlar](#şartname-ve-güvenilirlik-kabul-tablosu); çalışma, cleanup ve ölçülmeyen kapsam ayrımlarını koru. Bu dizin genel final runtime kabulü değildir.

## Break It

[Belgelenmiş arıza veya eksik davranış](#güvenli-hata-ve-temizlik).

## Diagnose It

[Teşhis ve gözlem](#öğrenme-değerlendirmesi).

## Fix It

[Doğru davranış / düzeltme açıklaması](#güvenli-hata-ve-temizlik).

## What Happened?

[Ölçülen sonuç ve sınırlar](#şartname-ve-güvenilirlik-kabul-tablosu).

## Key Concepts

[Temel ayrımlar](#öğrenme-değerlendirmesi); [kısa sözlük](../../docs/architecture.md#kısa-sözlük).

## Interview Questions

[Mevcut mülakat soruları](#öğrenme-değerlendirmesi).

## Exercises

[Mevcut alıştırma](#öğrenme-değerlendirmesi); uygulamadan önce kaynak sahipliği ve cleanup şartlarını oku.

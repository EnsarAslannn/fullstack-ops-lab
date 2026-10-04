# Module 11 — GitHub Actions CI: uygulama planı

## Durum ve amaç

4 Ekim 2026: **plan hazır; workflow implementasyonu ve GitHub-hosted runner kabulü başlamadı.** Başlangıç çalışma alanı temizdi (`main`, `origin/main` ile aynı). Module 10'un yerel kabul kanıtları mevcut; bunlar CI üzerinde çalıştırılmış testler değildir.

Amaç her push ve pull request için kodun derlenebilirliğini, image üretimini, yapılandırmayı ve seçilmiş smoke kontrollerini otomatik doğrulamak. Bu adım yalnız bu README ve `PROJECT_STATUS.md` dosyasını değiştirir. Uygulama, Compose, secret kaynakları ve test scriptleri korunur.

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

**Test kapsamı:** `FullStackOpsLab.slnx` yalnız `src/backend/FullStackOpsLab.Api/FullStackOpsLab.Api.csproj` içerir. Test projesi/test framework'ü yok. `dotnet test` bu solution'da test yürütmez; başarılı çıkışı test kanıtı olarak kullanmayacağız. Frontend'de de `npm test` scripti yok. Build, smoke ve unit test farklı doğrulama türleridir; mevcut smoke sonuçlarına unit test veya code coverage adı verilmeyecek.

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

Önerilen gelecek dosya: `.github/workflows/ci.yml`. Bu plan adımında dosya oluşturulmadı.

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

## 11B — Sonraki izole Compose smoke hazırlığı

Bu bölüm ideal pipeline için planlanan **ayrı adım**; ilk workflow'un geçmiş olduğuna veya bu adımın uygulandığına dair iddia değildir.

1. Linux job'a ait benzersiz Compose project adı, geçici ignored `.env.ci` ve yalnız sahte process credential'ları kullan. Test adları parametreli hale getirilmeden sabit `fullstack-ops-lab-…` container bekleyen scriptleri çağırma. Servis DNS adları `api/postgres/redis/prometheus/grafana` ve mevcut internal portlar değişmez.
2. CI-only override ile external PostgreSQL volume adını **job'a ait benzersiz** adla değiştir; yalnız bu boş volume'u oluştur. Development `fullstack-ops-postgres-data`, önceden migration uygulanmış database veya user-secrets'e dayanma. Preflight env dosyasının checkout içinde olması ve CI volume adına parametre verilmesi gerekir; mevcut Windows child-shell kullanımına gerekli küçük Linux uyarlaması ayrı doğrulanır.
3. Önce yalnız PostgreSQL'i başlat, `pg_isready` bekle. Host EF tool restore ile mevcut InitialCreate'dan idempotent SQL üret; yeni migration oluşturma. Design-time startup validation için yalnız komut process'ine sahte PostgreSQL/Redis configuration ve Production ortamı ver.
4. Proje yolu `src/backend/FullStackOpsLab.Api`; planlanan EF komutu `dotnet ef migrations script 0 InitialCreate --idempotent --project src/backend/FullStackOpsLab.Api --startup-project src/backend/FullStackOpsLab.Api --configuration Release --no-build --output <geçici-SQL-yolu>`. Önceden Release build gerekir. SQL'i secret değerleri taşımayan kontrollü dosyada incele; UTF-8 stdin üzerinden PostgreSQL container'ındaki `psql -X -w -v ON_ERROR_STOP=1 -f /dev/stdin` ile uygula. Host PostgreSQL portu açma. Runtime API image'ında SDK/EF tool yoktur.
5. Altı servisi başlat; bounded timeout ile hepsi healthy olsun. Liveness/readiness tek başına `tasks` şemasını kanıtlamaz. Nginx üzerinden GET200/POST201+Location/PUT200/DELETE204, altı alan/nullable davranış, 400/404; internal Redis TTL/hit/miss/invalidation ve `/metrics` kontrollerini küçük bir uygun Compose smoke ile doğrula.
6. Prometheus target ve Grafana provisioning API kontrollerini kapsamlarına göre seç. Browser/bağımlılık kesintisi/restart/down-up uzun deneylerini her scriptte tekrarlama; ayrı küçük kabul adımlarına ayır. İlk minimum CI bu runtime davranışlarını doğrulamaz.
7. `always()` cleanup, **yalnız bu job'ın oluşturduğu** container/network/test volume'larını açık sahiplikle kaldırır; secret değerli raw log/config/inspect artifact'i yüklemez. Development volume veya prune komutu kullanılmaz. Job'lar arasında canlı servis veya kalıcı database paylaşımı varsayılmaz.

Database initialization ile credential eşleşmesi yeni boş CI volume'unda yönetilir. Mevcut initialized development volume'unda env parolasını değiştirmenin rol parolasını değiştirmediği kural aynen geçerlidir; CI için gerçek local kaynaklar kopyalanmaz.

## Belirsizlikler ve kabul sınırı

- GitHub-hosted runner'da hiçbir komut bu görevde çalıştırılmadı; Linux PowerShell script uyumluluğu, network/image pull erişimi ve CI süreleri **NOT VERIFIED**.
- Tam action SHA'ları ilk uygulama sırasında resmî release üzerinden doğrulanacak. SDK/Node patch ailesi ve Docker image tag'leri mutable olabilir; çözülmüş sürümler/image ID'leri gerçek run'da kaydedilir. Dockerfile/paket pin politikası bu dokümantasyon görevinde değiştirilmez.
- Actions'ın repository'de etkin olup olmadığı, organizasyon action politikası ve branch protection required-check ayarları henüz doğrulanmadı. İlk CI için kullanıcı development secret'ı veya GHCR yetkisi gerekmez.
- Mevcut Windows bağımlılıkları nedeniyle iki job, scriptleri yeniden tasarlamadan kullanılabilecek küçük başlangıçtır. Linux-only hedeflenirse önce portability değişiklikleri ve fixture kabulü gerekir; bu görevde yapılmadı.
- Minimum CI green olması gerçek Compose CRUD/cache/health/provisioning, browser, load test veya production deploy kanıtı değildir. Module 11'in tüm ideal akışı ve final kabulü ayrı değerlendirilecek.

## Bu plan adımının doğrulanması ve ilk uygulama

Kaynak dosyaları/komut yolları incelendi, mevcut testlerin platform ve veri ihtiyaçları karşılaştırıldı. Son kontroller: repository secret leakage check, `git diff --check`, status/diff kapsam incelemesi. Bu görev build, container, migration veya workflow çalıştırmaz; local `.env`/user-secrets değerleri okunmaz ya da değiştirilmez.

**İlk küçük uygulama:** 11A'daki iki job'ı `.github/workflows/ci.yml` olarak eklemek ve ilk gerçek push/PR run'ında beş minimum kapı, 19 secret fixture ve 20 configuration smoke sonucunu doğrulamak. CI green olmadan testler çalışmış sayılmaz. Bunun ardından ayrı talep ile 11B izole Compose smoke hazırlığı yapılır; GHCR yayınlama temel CI kabulünden sonra opsiyoneldir.

**Öğrenme:** runner temiz ve geçici bir makinedir; local bilgisayarındaki hazır volume/secret otomatik taşınmaz. Job'lar kendi process ve kaynaklarına sahiptir. Cache indirmeyi hızlandırır, testin yerini tutmaz. Build kodun derlenmesini, smoke belirli davranışları, config validation yapılandırmanın okunmasını doğrular; bunları aynı kapsam gibi raporlamamalıyız.

Önerilen dokümantasyon commit mesajı: `docs(ci): plan GitHub Actions build and smoke checks`. Bu görevde commit/push yok.

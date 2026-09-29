# Modül 7 — Docker Compose Orchestration: uygulama planı

**Durum: yalnızca plan.** Bu belgede anlatılan Compose dosyası henüz oluşturulmadı; hiçbir Compose servisi başlatılmadı ve aşağıdaki kabul sonuçları henüz doğrulanmadı. Amaç, Modül 6'da ayrı `docker network create` ve `docker run` komutlarıyla kurulan dört servisli laboratuvarı tekrarlanabilir bir Compose tanımına dönüştürmek. Bu adımda uygulama kodu, Dockerfile, Nginx config, veritabanı ve Docker kaynakları değişmez.

`PROJECT_SPEC.md` nihai hedefte `frontend`, `backend`, `postgres`, `redis`, ayrı `nginx`, `prometheus` ve `grafana` servislerini sayar. Bu plan, kullanıcının istediği **ilk dört servisli Compose uygulama adımı** içindir. Mevcut frontend image'ı React dosyalarını zaten Nginx ile sunduğundan burada ikinci bir Nginx container'ı planlanmaz. Nihai servis ayrımı ve observability sonraki açık adımlarda şartnameyle yeniden karşılaştırılmalıdır. Bu plandaki `api`, şartnamedeki backend rolünü yerine getirir.

## 1. Servis planı

| Servis | Görev; kaynak | Container adı | Container portu → host portu | Config ve veri | Healthcheck; başlangıç bağımlılığı |
| --- | --- | --- | --- | --- | --- |
| `frontend` | React `dist` dosyaları ve Nginx reverse proxy; `./src/frontend` context'inden mevcut iki aşamalı Dockerfile ile build | `container_name` yok | `80` → yalnızca `127.0.0.1:18081:80` | Nginx config image içinde; veri volume'u yok | `GET http://127.0.0.1/` (image içindeki HTTP aracı doğrulanacak); `api: service_healthy` |
| `api` | .NET 10 Task API; `./src/backend/FullStackOpsLab.Api` context'inden mevcut iki aşamalı Dockerfile ile build | Yok | `8080` → host'a yayın yok | PostgreSQL ve Redis connection string, TTL, `ASPNETCORE_ENVIRONMENT`; veri volume'u yok | `GET http://127.0.0.1:8080/health` (probe aracı doğrulanacak); `postgres` ve `redis: service_healthy` |
| `postgres` | Resmî `postgres:18-alpine`; kalıcı ana veri | Yok | `5432` → host'a yayın yok | `POSTGRES_USER`, `POSTGRES_PASSWORD`, `POSTGRES_DB`; `fullstack-ops-postgres-data:/var/lib/postgresql` | `pg_isready`; başka servis bağımlılığı yok |
| `redis` | Resmî `redis:8.2.10-alpine`; yeniden üretilebilir Task liste cache'i | Yok | `6379` → host'a yayın yok | `redis-server --save '' --appendonly no`; `/data` için `tmpfs`, named volume yok | `redis-cli ping`; başka servis bağımlılığı yok |

İki uygulama image'ı için gelecekte `build` ve açık yerel image tag'i birlikte kullanılabilir; tag yalnızca hangi build'in çalıştığını görmeye yarar. `EXPOSE 80` ve `EXPOSE 8080` Dockerfile'ın iç portunu belgeler; host portunu açmaz. Compose `ports` yalnızca `frontend` için kullanılır. Diğer üç serviste `ports` bulunmaması gerekir; aynı ağdaki servisler yine de container portlarına erişebilir. Gerekli olmayan `expose` satırları da eklenmez.

Sabit `container_name` kullanmamak Compose'un proje kapsamında isim üretmesine izin verir. `api`, `postgres` ve `redis` servis adları ağ içindeki kararlı DNS adlarıdır. `container_name` bir servisi birden fazla replica'ya ölçeklemeyi engeller ve farklı Compose projelerinde isim çakışması yaratabilir. [Docker Compose servis başvurusu](https://docs.docker.com/reference/compose-file/services/#container_name) bu ölçekleme sınırlamasını açıkça belirtir.

## 2. Ağ, DNS ve Nginx upstream kararı

Compose, ek ayar olmadan proje kapsamlı tek bir user-defined bridge `default` ağı oluşturur ve servis adlarını bu ağda çözer. Bu proje için dört servisin **tek ortak ağı** yeterlidir; sabit container IP'si, `links` veya ikinci ağ gerekmez. Öğrenme amacıyla ilk `compose.yaml` içinde `app` adlı tek bir bridge ağının açıkça bildirilmesi ve dört servisin buna bağlanması önerilir. Compose bu ağı proje kapsamında yönetir; `internal: true` ayrıca kullanılmaz çünkü bu bayrak egress davranışını değiştirir ve burada istenen yalnızca host portlarının sınırlandırılmasıdır. [Docker'ın Compose ağ açıklaması](https://docs.docker.com/compose/how-tos/networking/) servis adıyla DNS erişimini ve değişebilen container IP'lerini anlatır.

Mevcut `src/frontend/nginx.conf` adresi `fullstack-ops-api-proxy:8080` biçimindedir. Compose uygulamasında seçenekler:

| Seçenek | Değerlendirme |
| --- | --- |
| Nginx upstream'ini `api:8080` yapmak | **Önerilen:** Compose servis adı doğrudan görünür; az ayar, kolay teşhis. Gelecek uygulama adımında config değişir ve frontend image yeniden build edilir. `proxy_pass` sonuna URI `/` eklenmez; `/api/tasks` korunur. |
| `api` servisine `fullstack-ops-api-proxy` network alias vermek | Eski config'i korur, fakat geçici Modül 6 container adını kalıcı Compose mimarisine taşır ve ek adlandırma gerektirir. |
| Nginx template ve environment kullanmak | Ortamlar arasında upstream seçimi sağlar, ancak bu tek ağlı laboratuvar için ek template/render mantığı getirir. |

Nginx'in servis adı çözümlemesi frontend başlarken başarılı olmalıdır; bu nedenle `frontend`, `api` hazır olduktan sonra başlatılır. API container'ı ileride **yeniden oluşturulursa** IP değişebilir. Uygulama testinde canlı Nginx'in yeni IP'yi nasıl gördüğü ayrıca ölçülmeli; gerekirse Nginx reload veya dinamik DNS çözümlemesi tasarlanmalıdır. Bu plan mevcut config'i değiştirmez.

## 3. PostgreSQL volume kararı

| Seçenek | Mevcut veri ve yeni bilgisayar | `down` / `down -v` |
| --- | --- | --- |
| **Mevcut `fullstack-ops-postgres-data` volume'unu `external: true` ve açık `name` ile kullanmak — önerilen** | Modül 3B verisi ve uygulanmış `InitialCreate` migration'ı aynı volume ile kalır. Yeni bilgisayarda volume önceden açıkça oluşturulmalı veya yedekten geri yüklenmeli; boşsa migration uygulanmalı. | Compose volume'un sahibi değildir; `down` da `down -v` de **bu external volume'u silmez**. |
| Compose'un proje kapsamlı yeni named volume'u | Temiz bilgisayarda otomatik yaratılır; mevcut Modül 3B verisini kendiliğinden taşımaz. Proje adı değişirse volume adı da değişir. Boş veritabanı migration ister. | `down` korur; `down -v` Compose'un yönettiği named volume'u siler. |
| Compose-managed volume'a açık `name` vermek | İsim proje prefix'i almaz; mevcut isimle çakışma ve ownership belirsizliği doğurur. Boş volume otomatik yaratılabilir. | `down` korur; `down -v` bu managed volume'u silebilir. |

Önerilen top-level model `postgres-data: { external: true, name: fullstack-ops-postgres-data }` ve mount hedefi `/var/lib/postgresql` olacaktır; bu yazı **Compose dosyası değildir**. External volume yoksa Compose'un hata vermesi, yanlışlıkla boş bir veritabanıyla başlamaktan daha görünürdür. Yeni makinede önce açık `docker volume create fullstack-ops-postgres-data` hazırlığı ve migration prosedürü gerekir; bu nedenle **henüz tek komutla sıfırdan kurulum sağlanmış değildir**. `POSTGRES_USER`, `POSTGRES_DB` ve `POSTGRES_PASSWORD` mevcut dolu veri dizinini yeniden ilklendirmez; `.env` değerleri var olan kullanıcı/parola ile uyumlu olmalıdır. [Docker volume tanımı](https://docs.docker.com/reference/compose-file/volumes/) external sahipliği açıklar; [Compose down başvurusu](https://docs.docker.com/reference/cli/docker/compose/down/) external volume'ların korunmasını ve `-v` riskini belgeler. İleride managed başka volume'lar ekleneceğinden `down -v` yine de genel bir temizlik komutu gibi kullanılmamalıdır.

## 4. Migration: ilk kurulumda açık adım

`Program.cs` API açılışında `Database.Migrate()` çağırmaz. `/health` mevcut hâliyle PostgreSQL tablosunun varlığını da test etmez. Yeni, boş volume üzerinde `tasks` tablosu oluşmadan API Task isteklerini kabul etmek doğru olmaz. Mevcut volume için `__EFMigrationsHistory` içindeki `20260928113912_InitialCreate` ve `tasks` varlığı kontrol edilir; boş volume'da migration **API trafiğinden önce** uygulanır.

| Strateji | Bu laboratuvar için karar |
| --- | --- |
| Açık operatör adımı: `dotnet ef` ile SQL üret, incele, Compose içindeki PostgreSQL'e `psql` ile uygula | **Önerilen.** Host SDK ve repository'deki `dotnet-ef 10.0.12` araç manifesti kullanılır; `docker compose exec -T postgres psql` ağ içindeki veritabanına çalışır. PostgreSQL host portu açılmaz. Hata kodu ve SQL açıkça görülebilir. `api` final image'ında SDK olmadığı için `docker compose exec api dotnet ef` beklenmez. |
| Tek seferlik migration service | Sonradan tek komut hedefini destekleyebilir ve `service_completed_successfully` ile API başlangıcını kapılayabilir; ayrı image/komut ve yetki tasarımı ister. İlk öğrenme adımı için ek karmaşıklık. |
| API başlarken otomatik migration | Her API instance'ı aynı şemayı değiştirmeye çalışabilir; runtime API'ye DDL yetkisi verir, hata görünürlüğünü azaltır. Bu aşamada önerilmez. |
| API image entrypoint'inde migration | Çalıştırma ve şema değişikliğini aynı sürece bağlar; aynı yarış ve yetki sorunları vardır. Bu aşamada önerilmez. |

Gelecekteki ilk kurulum akışı: PostgreSQL ve Redis'i başlatıp health durumlarını bekle; `dotnet ef migrations script 0 InitialCreate --idempotent` ile SQL'i **repository dışındaki geçici dosyaya** üret; SQL'i incele; `docker compose exec -T postgres psql -U fullstackops -d fullstackops -v ON_ERROR_STOP=1` ile stdin üzerinden uygula; migration geçmişini ve `tasks` tablosunu sorgula; ancak sonra API ve frontend'i başlat. Şema zaten uygulanmışsa yeniden yazma adımı atlanır. Bu yerel laboratuvar hâlâ mevcut `fullstackops` rolünü kullanır; migration ve runtime DDL yetkilerinin ayrı rollere bölünmesi gelecekteki güvenlik çalışmasıdır. Burada SQL üretilmedi veya uygulanmadı.

## 5. Healthcheck ve başlangıç sırası

Planlanan zincir: `postgres` + `redis` → ikisi `service_healthy` → migration kontrolü/uygulaması → `api` health → `frontend`. Kısa `depends_on` yalnızca başlangıç sırasını ayarlar; hazır oluşu garanti etmez. `condition: service_healthy` belirtilen dependency'nin healthcheck'inin geçmesini bekletir. Healthcheck'ler sonradan bozulan bağımlılığı kendi başına onarmaz. [Docker başlangıç sırası belgesi](https://docs.docker.com/compose/how-tos/startup-order/) bu ayrımı açıklar.

| Servis | Önerilen probe | Sınır |
| --- | --- | --- |
| `postgres` | `pg_isready -U $$POSTGRES_USER -d $$POSTGRES_DB` | `$$`, Compose interpolation yerine container içindeki environment'ı kullanır. Sunucunun bağlantı kabulünü gösterir; migration veya gerçek API parolasını doğrulamaz. |
| `redis` | `redis-cli ping` sonucunun `PONG` olması | Cache'e ağ içinden gerçek uygulama erişimini tek başına kanıtlamaz. |
| `api` | Container içinden HTTP `GET /health` → 200 | Mevcut ASP.NET runtime image'ında `curl` var diye varsayılmamalı; uygulamada araç kontrol edilmeli veya küçük, açık bir probe yöntemi sağlanmalı. API endpoint'i şu an DB/Redis readiness içermez; bağımlılıklar düşse bile 200 olabilir. Health endpoint kodu bu plan adımında değiştirilmez. |
| `frontend` | Container içinden HTTP `GET /` → 200 (mevcut Alpine araçları doğrulanacak) | Statik sayfanın çalışmasını gösterir; `/api/` upstream'in sağlıklı olduğunu tek başına kanıtlamaz. |

Probe'lar için örnek `interval: 5s`, `timeout: 3s`, `retries: 5`, PostgreSQL'e uygun `start_period` önerilir; kesin değerler gerçek başlangıç ölçümüne göre ayarlanır. [Microsoft'un healthcheck rehberi](https://learn.microsoft.com/en-us/aspnet/core/host-and-deploy/health-checks) .NET Linux image'larında `curl` bulunmayabileceğini belirtir. Modül 8 daha zengin readiness kontrolleri içindir; sırf Compose planı için API health davranışı değiştirilmez.

## 6. Secret ve configuration

Root `.env.example` yalnızca anahtar adları ve placeholder değerler taşıyacak şekilde uygulama adımında genişletilir; gerçek root `.env` Git dışında kalır (`.gitignore` bunu zaten kapsıyor). Yerel `.env` içinde `POSTGRES_USER`, `POSTGRES_DB`, `POSTGRES_PASSWORD` sağlanır. PostgreSQL servisine bu üç değer, API servisine `ConnectionStrings__Postgres` (host `postgres`, iç port `5432`, aynı kullanıcı/veritabanı/parola), `ConnectionStrings__Redis=redis:6379`, `Cache__TasksTtlSeconds=60` ve yerel lab için `ASPNETCORE_ENVIRONMENT=Development` açık `environment` eşlemesiyle verilir. Gerçek parola veya tamamlanmış connection string takip edilen dosyalara yazılmaz. Mevcut volume'un parolasıyla uyum, ilk çalıştırmadan önce kontrol edilmelidir.

Compose'un root `.env` dosyasını okuması **değişken substitution** sağlar; `.env` içindeki her anahtar otomatik olarak her container'a geçmez. Gelecekteki `environment` eşlemesi API için connection string'i `Host=postgres;Port=5432;Database=${POSTGRES_DB:?};Username=${POSTGRES_USER:?};Password=${POSTGRES_PASSWORD:?}` şablonundan kurabilir; şablonda gerçek parola bulunmaz, tamamlanmış değer ise container environment'ında bulunur. Mevcut `.env.example` içindeki `ConnectionStrings__Postgres` placeholder'ı host geliştirmesi için korunabilir; Compose için tek parola kaynağı `POSTGRES_PASSWORD` olmalıdır. `env_file` dosyadaki anahtarları topluca container'a aktarır; burada API'ye PostgreSQL'in init değişkenlerini, PostgreSQL'e API config'ini gereksizce taşımamak için açık `environment` tercih edilir. Aynı anahtar hem `env_file` hem `environment` içinde olursa `environment` önceliklidir. [Docker interpolation](https://docs.docker.com/compose/how-tos/environment-variables/variable-interpolation/) ve [environment önceliği](https://docs.docker.com/compose/how-tos/environment-variables/envvars-precedence/) bu davranışı açıklar.

Bu yerel yöntem production secret yönetimi değildir: Compose config'in çözümlenmiş çıktısı ve container environment secret gösterebilir. Doğrulamada `docker compose config -q` kullanılmalı, düz `config` çıktısı paylaşılmamalıdır. Gerçek secret, Dockerfile, image layer, Git diff veya README'ye girmez. Redis bu yerel ağda cache olarak parolasız planlanmıştır; dış portu yoktur. Production için ayrı secret ve ağ güvenliği tasarımı sonraki kapsamdır.

## 7. Redis cache davranışı

PostgreSQL ana veri kaynağıdır; Redis yalnızca `fullstack-ops:tasks:all:v1` liste cache'ini tutar. Redis restart sonrasında boş cache kabul edilebilir: sonraki GET PostgreSQL'den veriyi yeniden üretir ve key'i TTL ile doldurur. `/data` için `tmpfs` ve `--save '' --appendonly no` Modül 6'daki geçici cache davranışını korur; image'ın varsayılan volume tanımından gereksiz anonim veri volume'u oluşması önlenir. Named Redis volume'u gerekmez.

**Bilinen sınırlama:** Redis kapalıyken mevcut `GET /api/tasks` gerçek testte **500** döndü; fallback, retry veya circuit breaker yok. Redis yeniden hazır olduğunda istek tekrar başarılı olabilir ve cache yeniden dolar. Compose `depends_on`, çalışma anındaki kesintiyi otomatik çözmez. Bu plan uygulama davranışını değiştirmez.

## 8. Önerilen dosyalar ve komut akışı

İlk uygulama adımında repository köküne **tek `compose.yaml`** önerilir. `PROJECT_SPEC.md` örnek ağaçta `docker-compose.yml` ve override gösterse de ağacı sadeleştirmeye izin verir; bir base dosya bu dört servis için yeterlidir. Development override dosyası şimdilik gerekmez. Mevcut `src/frontend/nginx.conf` upstream'i `api:8080` olacak şekilde o adımda değiştirilip frontend image yeniden build edilir. Backend/frontend Dockerfile context yolları yukarıdaki servis tablosundadır. `compose.yaml` içinde `services`, tek `app` network bildirimi ve `external` PostgreSQL volume bildirimi bulunur. Root `.env.example` placeholder'larla güncellenir; gerçek `.env` takip edilmez. Bu dosyaların hiçbiri bu plan görevinde oluşturulmadı/değiştirilmedi.

**Aşağıdaki komutlar ilerideki uygulama içindir; bu görevde çalıştırılmadı.**

| Komut | Amaç |
| --- | --- |
| `docker compose config -q` | Değişkenleri çözüp modeli doğrular, secret içerebilecek tam config'i yazdırmaz. Düz `config` modeli ekrana basar; paylaşırken dikkat gerekir. |
| `docker compose pull postgres redis` | Resmî bağımlılık image'larını çeker/günceller; uygulama image'larını build etmez. |
| `docker compose build` | API ve frontend image'larını kendi build context'lerinden oluşturur. |
| `docker compose up -d postgres redis` | Önce veri ve cache servislerini arka planda başlatır; migration kapısı öncesi hazır oluş kontrolü. |
| `docker compose ps` | Çalışma, health ve host port durumunu gösterir. |
| `docker compose logs postgres redis` | Başlangıç/hata teşhisi; logları paylaşmadan önce secret kontrolü. `logs -f` canlı takip eder. |
| `docker compose exec -T postgres psql ...` | Migration SQL'ini ve doğrulama sorgularını ağ içindeki PostgreSQL'de çalıştırır; host DB portu açılmaz. |
| `docker compose up -d --build api frontend` | Migration doğrulandıktan sonra uygulamayı kurar/başlatır. Sonraki tekrar çalıştırmada `up -d` yeterli olabilir. |
| `docker compose restart api` | API container'ını yeniden başlatıp PostgreSQL veri kalıcılığını gözlemler; image build etmez. Redis restart ayrı cache yenilenme testi içindir. |
| `docker compose stop` | Container'ları durdurur; kaldırmaz. Sonraki `up` ile yeniden kullanılabilirler. |
| `docker compose down` | Compose container'larını ve ağını kaldırır; external PostgreSQL volume'u korur. Sonraki `up` aynı volume'u bağlar. |
| `docker compose down -v` | **Bu planda çalıştırılmayacak riskli komut.** Managed named ve anonymous volume'ları da kaldırabilir. Seçilen external PostgreSQL volume'u korunur, ancak gelecekte eklenen managed volume'lar silinebilir. |

`docker compose up --build -d` şartnamedeki nihai tek komut hedefidir. Bu ilk dört servisli uygulamada **boş volume için migration ve external volume hazırlığı yüzünden henüz tek komut hedefi sağlanmaz**. Daha sonra açık yetkili bir tek-seferlik migration servisi değerlendirilebilir; bu kararı bu plan uygulamaz.

## 9. Gelecek uygulama için kesin kabul kriterleri

Bunlar **planlanan testlerdir, geçmiş sonuçlar değildir**:

1. `docker compose config -q` sıfır çıkış kodu verir.
2. Dört servis başlar.
3. `docker compose ps` tüm önerilen healthcheck'leri başarılı gösterir.
4. Yalnızca frontend `127.0.0.1:18081:80` host binding'ine sahiptir; API/PostgreSQL/Redis'de host binding yoktur.
5. Nginx `api:8080` adını çözer, `/api/tasks` yolunu değiştirmeden iletir; tarayıcıdan gerçek CRUD çalışır.
6. İlk GET cache miss ve ikinci GET hit; POST/PUT/DELETE cache invalidation ile doğrulanır.
7. API restart sonrası aynı PostgreSQL kaydı görünür.
8. Redis restart sonrası cache boşalır ve sonraki GET ile yeniden dolar.
9. `docker compose down` sonrasında `fullstack-ops-postgres-data` yerinde kalır; tekrar `up` ile veri korunur.
10. Yeni boş volume senaryosunda migration açıkça uygulanır, `tasks` ve `__EFMigrationsHistory` doğrulanır; mevcut Modül 3B kaydı yanlışlıkla silinmez.
11. Yeni veya değişen hiçbir takip edilen dosyada gerçek parola, token ya da tamamlanmış connection string bulunmaz; `.env` Git dışında kalır.
12. Test Task kayıtları ve Redis test key'leri temizlenir; ilişkisiz Docker kaynakları değiştirilmez.

## 10. Bu planın açık sınırları

- Mevcut API `/health` yalnızca temel liveness gösterir; PostgreSQL/Redis readiness değildir. Uygulama adımında healthcheck için runtime image'da hangi HTTP aracının bulunduğu doğrulanmalıdır.
- Mevcut `fullstack-ops-postgres-data` external seçimi yerel veriyi korur, fakat yeni bilgisayarda ön hazırlık ister. Şartnamenin tek komutla sıfırdan kurulum hedefi henüz karşılanmaz.
- Şartnamenin nihai ayrı `nginx` ve observability servisleri bu dört servisli başlangıç planında yoktur. Sonraki modüllerde servis ayrımı yeniden karara bağlanmalıdır.
- Bu belgede `compose.yaml`, env dosyası, volume, network veya container oluşturulmadı; migration ve testler çalıştırılmadı. Doğrulama yalnızca mevcut kod/dokümanla planın tutarlılığı ve Git diff kontrolüdür.

# Modül 7 — Docker Compose Orchestration: ilk tanım

**Durum: Compose tanımı ve statik doğrulama tamamlandı; runtime acceptance henüz başlamadı.** Kök `compose.yaml`, Modül 6'da ayrı komutlarla kurulan dört servisi tanımlar. `docker compose up` çalıştırılmadı; Compose servisi, ağı veya volume'u oluşturulmadı. Nginx upstream'i Compose servis adına uyarlandı; uygulama kodu, Dockerfile ve veritabanı değiştirilmedi.

`PROJECT_SPEC.md` nihai hedefte `frontend`, `backend`, `postgres`, `redis`, ayrı `nginx`, `prometheus` ve `grafana` servislerini sayar. Bu ilk adım, kullanıcının istediği **dört servisli Compose tanımıdır**. Mevcut frontend image'ı React dosyalarını zaten Nginx ile sunar. Nihai servis ayrımı ve observability sonraki açık adımlarda şartnameyle yeniden karşılaştırılmalıdır. Buradaki `api`, şartnamedeki backend rolünü yerine getirir.

## 1. Servis tanımı

| Servis | Görev; kaynak | Container adı | Container portu → host portu | Config ve veri | Healthcheck; başlangıç bağımlılığı |
| --- | --- | --- | --- | --- | --- |
| `frontend` | React `dist` dosyaları ve Nginx reverse proxy; `./src/frontend` context'inden mevcut iki aşamalı Dockerfile ile build | `container_name` yok | `80` → yalnızca `127.0.0.1:18081:80` | Nginx config image içinde; veri volume'u yok | `wget` ile `GET http://127.0.0.1/`; `api: service_healthy` |
| `api` | .NET 10 Task API; `./src/backend/FullStackOpsLab.Api` context'inden mevcut iki aşamalı Dockerfile ile build | Yok | `8080` → host'a yayın yok | PostgreSQL ve Redis connection string, TTL, `ASPNETCORE_ENVIRONMENT`; veri volume'u yok | Bash TCP isteğiyle `GET /health` ve HTTP 200; `postgres` ve `redis: service_healthy` |
| `postgres` | Resmî `postgres:18-alpine`; kalıcı ana veri | Yok | `5432` → host'a yayın yok | `POSTGRES_USER`, `POSTGRES_PASSWORD`, `POSTGRES_DB`; `fullstack-ops-postgres-data:/var/lib/postgresql` | `pg_isready`; başka servis bağımlılığı yok |
| `redis` | Resmî `redis:8.2.10-alpine`; yeniden üretilebilir Task liste cache'i | Yok | `6379` → host'a yayın yok | `redis-server --save '' --appendonly no`; `/data` için `tmpfs`, named volume yok | `redis-cli ping`; başka servis bağımlılığı yok |

`EXPOSE 80` ve `EXPOSE 8080` Dockerfile'ın iç portunu belgeler; host portunu açmaz. Compose `ports` yalnızca `frontend` için kullanılır. Diğer üç serviste `ports` bulunmaz; aynı ağdaki servisler yine de container portlarına erişebilir. Gerekli olmayan `expose` satırları eklenmedi.

Sabit `container_name` kullanmamak Compose'un proje kapsamında isim üretmesine izin verir. `api`, `postgres` ve `redis` servis adları ağ içindeki kararlı DNS adlarıdır. `container_name` bir servisi birden fazla replica'ya ölçeklemeyi engeller ve farklı Compose projelerinde isim çakışması yaratabilir. [Docker Compose servis başvurusu](https://docs.docker.com/reference/compose-file/services/#container_name) bu ölçekleme sınırlamasını açıkça belirtir.

## 2. Ağ, DNS ve Nginx upstream kararı

Compose dosyası dört servisi tek `app` user-defined bridge ağına bağlar. Compose ağı proje kapsamında yönetecektir; sabit IP, alias, `links` veya ikinci ağ yoktur. `internal: true` kullanılmaz çünkü istenen host portlarının sınırlandırılmasıdır. [Docker'ın Compose ağ açıklaması](https://docs.docker.com/compose/how-tos/networking/) servis adıyla DNS erişimini ve değişebilen container IP'lerini anlatır.

`src/frontend/nginx.conf` upstream'i `api:8080` oldu. `proxy_pass http://api:8080;` sonunda URI `/` bulunmaz; böylece `/api/tasks` yolu backend'e aynı biçimde gider. Bu yönlendirme ancak servisler çalıştırıldığında uçtan uca doğrulanabilir. Karar seçenekleri:

| Seçenek | Değerlendirme |
| --- | --- |
| Nginx upstream'ini `api:8080` yapmak | **Uygulandı:** Compose servis adı doğrudan görünür; az ayar, kolay teşhis. `proxy_pass` sonuna URI `/` eklenmedi; `/api/tasks` yolu korunur. |
| `api` servisine `fullstack-ops-api-proxy` network alias vermek | Eski config'i korur, fakat geçici Modül 6 container adını kalıcı Compose mimarisine taşır ve ek adlandırma gerektirir. |
| Nginx template ve environment kullanmak | Ortamlar arasında upstream seçimi sağlar, ancak bu tek ağlı laboratuvar için ek template/render mantığı getirir. |

Nginx'in servis adı çözümlemesi frontend başlarken başarılı olmalıdır; bu nedenle `frontend`, `api` healthy olduktan sonra başlatılacak şekilde tanımlandı. API container'ı ileride **yeniden oluşturulursa** IP değişebilir. Runtime acceptance sırasında canlı Nginx'in yeni IP'yi nasıl gördüğü ayrıca ölçülmelidir.

## 3. PostgreSQL volume kararı

| Seçenek | Mevcut veri ve yeni bilgisayar | `down` / `down -v` |
| --- | --- | --- |
| **Mevcut `fullstack-ops-postgres-data` volume'unu `external: true` ve açık `name` ile kullanmak — önerilen** | Modül 3B verisi ve uygulanmış `InitialCreate` migration'ı aynı volume ile kalır. Yeni bilgisayarda volume önceden açıkça oluşturulmalı veya yedekten geri yüklenmeli; boşsa migration uygulanmalı. | Compose volume'un sahibi değildir; `down` da `down -v` de **bu external volume'u silmez**. |
| Compose'un proje kapsamlı yeni named volume'u | Temiz bilgisayarda otomatik yaratılır; mevcut Modül 3B verisini kendiliğinden taşımaz. Proje adı değişirse volume adı da değişir. Boş veritabanı migration ister. | `down` korur; `down -v` Compose'un yönettiği named volume'u siler. |
| Compose-managed volume'a açık `name` vermek | İsim proje prefix'i almaz; mevcut isimle çakışma ve ownership belirsizliği doğurur. Boş volume otomatik yaratılabilir. | `down` korur; `down -v` bu managed volume'u silebilir. |

`compose.yaml` içinde `postgres-data: { external: true, name: fullstack-ops-postgres-data }` tanımlandı ve `/var/lib/postgresql` hedefine bağlandı. Volume'un yerel sistemde zaten bulunduğu `docker volume inspect` ile doğrulandı; Compose bu adımda volume'a dokunmadı. External volume yoksa Compose hata verir. Yeni makinede önce açık `docker volume create fullstack-ops-postgres-data` hazırlığı ve migration prosedürü gerekir; bu nedenle **henüz tek komutla sıfırdan kurulum sağlanmış değildir**. `POSTGRES_USER`, `POSTGRES_DB` ve `POSTGRES_PASSWORD` mevcut dolu veri dizinini yeniden ilklendirmez; `.env` değerleri var olan kullanıcı/parola ile uyumlu olmalıdır. [Docker volume tanımı](https://docs.docker.com/reference/compose-file/volumes/) external sahipliği açıklar; [Compose down başvurusu](https://docs.docker.com/reference/cli/docker/compose/down/) external volume'ların korunmasını ve `-v` riskini belgeler. İleride managed başka volume'lar ekleneceğinden `down -v` yine de genel bir temizlik komutu gibi kullanılmamalıdır.

## 4. Migration: ilk kurulumda açık adım

`Program.cs` API açılışında `Database.Migrate()` çağırmaz. `/health` mevcut hâliyle PostgreSQL tablosunun varlığını da test etmez. Yeni, boş volume üzerinde `tasks` tablosu oluşmadan API Task isteklerini kabul etmek doğru olmaz. Mevcut volume için `__EFMigrationsHistory` içindeki `20260928113912_InitialCreate` ve `tasks` varlığı kontrol edilir; boş volume'da migration **API trafiğinden önce** uygulanır.

| Strateji | Bu laboratuvar için karar |
| --- | --- |
| Açık operatör adımı: `dotnet ef` ile SQL üret, incele, Compose içindeki PostgreSQL'e `psql` ile uygula | **Önerilen.** Host SDK ve repository'deki `dotnet-ef 10.0.12` araç manifesti kullanılır; `docker compose exec -T postgres psql` ağ içindeki veritabanına çalışır. PostgreSQL host portu açılmaz. Hata kodu ve SQL açıkça görülebilir. `api` final image'ında SDK olmadığı için `docker compose exec api dotnet ef` beklenmez. |
| Tek seferlik migration service | Sonradan tek komut hedefini destekleyebilir ve `service_completed_successfully` ile API başlangıcını kapılayabilir; ayrı image/komut ve yetki tasarımı ister. İlk öğrenme adımı için ek karmaşıklık. |
| API başlarken otomatik migration | Her API instance'ı aynı şemayı değiştirmeye çalışabilir; runtime API'ye DDL yetkisi verir, hata görünürlüğünü azaltır. Bu aşamada önerilmez. |
| API image entrypoint'inde migration | Çalıştırma ve şema değişikliğini aynı sürece bağlar; aynı yarış ve yetki sorunları vardır. Bu aşamada önerilmez. |

Gelecekteki ilk kurulum akışı: PostgreSQL ve Redis'i başlatıp health durumlarını bekle; `dotnet ef migrations script 0 InitialCreate --idempotent` ile SQL'i **repository dışındaki geçici dosyaya** üret; SQL'i incele; `docker compose exec -T postgres psql -U fullstackops -d fullstackops -v ON_ERROR_STOP=1` ile stdin üzerinden uygula; migration geçmişini ve `tasks` tablosunu sorgula; ancak sonra API ve frontend'i başlat. Şema zaten uygulanmışsa yeniden yazma adımı atlanır. Bu yerel laboratuvar hâlâ mevcut `fullstackops` rolünü kullanır; migration ve runtime DDL yetkilerinin ayrı rollere bölünmesi gelecekteki güvenlik çalışmasıdır. API runtime image'ında SDK ve `dotnet-ef` bulunmaz. Burada SQL üretilmedi veya uygulanmadı.

## 5. Healthcheck ve başlangıç sırası

Tanımlanan zincir: `postgres` + `redis` → ikisi `service_healthy` → `api` health → `frontend`. **Migration bu zincirde otomatik yapılmaz**; mevcut volume'da `InitialCreate` önceden uygulanmıştır, boş volume için operatörün API trafiğinden önce ayrıca uygulaması gerekir. `condition: service_healthy` belirtilen dependency'nin healthcheck'inin geçmesini bekletir. Healthcheck'ler sonradan bozulan bağımlılığı kendi başına onarmaz. [Docker başlangıç sırası belgesi](https://docs.docker.com/compose/how-tos/startup-order/) bu ayrımı açıklar.

| Servis | Tanımlanan probe | Sınır |
| --- | --- | --- |
| `postgres` | `pg_isready -U <POSTGRES_USER> -d <POSTGRES_DB>` | Değerler `.env` substitution ile sağlanır. Sunucunun bağlantı kabulünü gösterir; migration veya gerçek API parolasını doğrulamaz. |
| `redis` | `redis-cli ping` sonucunun `PONG` olması | Cache'e ağ içinden gerçek uygulama erişimini tek başına kanıtlamaz. |
| `api` | Runtime image'ında bulunan Bash `/dev/tcp`, `head` ve `grep` ile HTTP `GET /health` ve 200 durum satırı | `curl`/`wget` image'da yoktur. `/health` DB/Redis readiness içermez; bağımlılıklar düşse bile 200 olabilir. |
| `frontend` | Image'da bulunan `wget` ile `GET http://127.0.0.1/` | Statik sayfanın çalışmasını gösterir; `/api/` upstream'in sağlıklı olduğunu tek başına kanıtlamaz. |

Tanımda `interval: 5s`, `timeout: 3s`, `retries: 5`, API ve PostgreSQL için `start_period: 15s` kullanıldı. Gerçek health durumları ancak runtime acceptance sırasında ölçülecek. [Microsoft'un healthcheck rehberi](https://learn.microsoft.com/en-us/aspnet/core/host-and-deploy/health-checks) .NET Linux image'larında `curl` bulunmayabileceğini belirtir. Modül 8 daha zengin readiness kontrolleri içindir; API health davranışı değiştirilmedi.

## 6. Secret ve configuration

Root `.env.example` yalnızca örnek/placeholder değerler taşır; gerçek root `.env` Git dışında kalır (`.gitignore` bunu kapsar). Gelecek runtime testinde yerel `.env` içindeki `POSTGRES_USER`, `POSTGRES_DB`, `POSTGRES_PASSWORD` var olan volume kimlik bilgileriyle uyumlu olmalıdır. PostgreSQL servisine bu üç değer, API servisine `ConnectionStrings__Postgres` (host `postgres`, iç port `5432`), `ConnectionStrings__Redis=redis:6379`, `Cache__TasksTtlSeconds=60` ve yerel lab için `ASPNETCORE_ENVIRONMENT=Development` açık `environment` eşlemesiyle verilir. Gerçek parola veya tamamlanmış connection string takip edilen dosyalara yazılmadı.

Compose'un root `.env` dosyasını okuması **değişken substitution** sağlar; `.env` içindeki her anahtar otomatik olarak her container'a geçmez. `compose.yaml`, API connection string'ini `Host=postgres;Port=5432;Database=${POSTGRES_DB};Username=${POSTGRES_USER};Password=${POSTGRES_PASSWORD}` şablonundan kurar; şablonda gerçek parola bulunmaz, tamamlanmış değer container environment'ında bulunur. `.env.example` içindeki `ConnectionStrings__Postgres` ve `ConnectionStrings__Redis` placeholder'ları host geliştirmesi içindir; Compose için parola kaynağı `POSTGRES_PASSWORD` değeridir. `env_file` yerine açık `environment` kullanıldı; böylece PostgreSQL init değerleri gereksiz yere API'ye, API config'i PostgreSQL'e aktarılmaz. [Docker interpolation](https://docs.docker.com/compose/how-tos/environment-variables/variable-interpolation/) ve [environment önceliği](https://docs.docker.com/compose/how-tos/environment-variables/envvars-precedence/) bu davranışı açıklar.

Bu yerel yöntem production secret yönetimi değildir: Compose config'in çözümlenmiş çıktısı ve container environment secret gösterebilir. Doğrulamada `docker compose config -q` kullanılmalı, düz `config` çıktısı paylaşılmamalıdır. Gerçek secret, Dockerfile, image layer, Git diff veya README'ye girmez. Redis bu yerel ağda cache olarak parolasız planlanmıştır; dış portu yoktur. Production için ayrı secret ve ağ güvenliği tasarımı sonraki kapsamdır.

## 7. Redis cache davranışı

PostgreSQL ana veri kaynağıdır; Redis yalnızca `fullstack-ops:tasks:all:v1` liste cache'ini tutar. Redis restart sonrasında boş cache kabul edilebilir: sonraki GET PostgreSQL'den veriyi yeniden üretir ve key'i TTL ile doldurur. `/data` için `tmpfs` ve `--save '' --appendonly no` Modül 6'daki geçici cache davranışını korur; image'ın varsayılan volume tanımından gereksiz anonim veri volume'u oluşması önlenir. Named Redis volume'u gerekmez.

**Bilinen sınırlama:** Redis kapalıyken mevcut `GET /api/tasks` gerçek testte **500** döndü; fallback, retry veya circuit breaker yok. Redis yeniden hazır olduğunda istek tekrar başarılı olabilir ve cache yeniden dolar. Compose `depends_on`, çalışma anındaki kesintiyi otomatik çözmez. Bu tanım uygulama davranışını değiştirmez.

## 8. Oluşturulan dosyalar ve komut akışı

Repository kökünde **tek `compose.yaml`** oluşturuldu. `PROJECT_SPEC.md` örnek ağaçta `docker-compose.yml` ve override gösterse de bir base dosya bu dört servis için yeterlidir. `src/frontend/nginx.conf` upstream'i `api:8080` oldu. Build context'leri frontend için `./src/frontend`, API için `./src/backend/FullStackOpsLab.Api` olarak tanımlandı. Dosyada dört servis, tek `app` ağı ve external PostgreSQL volume bulunur. Root `.env.example` placeholder'larla güncellendi; gerçek `.env` oluşturulmadı.

**Aşağıdaki komutlar runtime acceptance içindir; bu görevde çalıştırılmadı.** Statik doğrulamada gerçek secret içermeyen `docker compose --env-file .env.example config -q` kullanıldı. Düz `config` çıktısı ekrana basılmadı. `docker compose up` çalıştırılmadı.

Bu adımın gerçek doğrulaması:

- `docker compose --env-file .env.example config -q`: çıkış kodu 0. Çözümlenmiş yapı yalnızca bellekte incelendi: tam dört servis, tek `app` bridge ağı, yalnız frontend'de `127.0.0.1:18081:80`, external `fullstack-ops-postgres-data` ve Redis `/data` tmpfs doğrulandı.
- `dotnet build FullStackOpsLab.slnx -c Release`: 0 uyarı, 0 hata. `npm ci` ve `npm run build`: başarılı. İlk frontend build denemesinde Windows sandbox `spawn EPERM` verdi; aynı build izinli ortamda başarılı oldu.
- Mevcut API runtime image'ında Bash, `head` ve `grep`; frontend Nginx image'ında `wget` bulundu. API probe mantığı ağsız geçici container'da kontrollü HTTP 200 yanıtını kabul etti, HTTP 500 yanıtını reddetti. Bu, gerçek Compose API health sonucu değildir.
- Frontend image geçici olarak build edildi; `api` için geçici hosts eşlemesiyle `nginx -t` başarılı oldu. Geçici container kendiliğinden kaldırıldı ve doğrulama image etiketi silindi. Servis DNS yönlendirmesi ve `/api/tasks` akışı henüz runtime test edilmedi.

| Komut | Amaç |
| --- | --- |
| `docker compose --env-file .env.example config -q` | Placeholder değerlerle modeli statik doğrular; secret içerebilecek tam config'i yazdırmaz. Bu adımda çalıştırıldı. |
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
| `docker compose down -v` | **Çalıştırılmayan riskli komut.** Managed named ve anonymous volume'ları da kaldırabilir. Seçilen external PostgreSQL volume'u korunur, ancak gelecekte eklenen managed volume'lar silinebilir. |

`docker compose up --build -d` şartnamedeki nihai tek komut hedefidir. Bu ilk dört servisli tanımda **boş volume için migration ve external volume hazırlığı yüzünden henüz tek komut hedefi sağlanmaz**. Daha sonra açık yetkili bir tek-seferlik migration servisi değerlendirilebilir; bu adım onu uygulamaz.

## 9. Sonraki runtime acceptance için kabul kriterleri

Bunlar **planlanan runtime testleridir, geçmiş sonuçlar değildir**. Bu adımda yalnızca `config -q`, dosya içeriği ve yerel build sonuçları doğrulandı:

1. `docker compose --env-file .env.example config -q` sıfır çıkış kodu verir (bu statik kontrol geçti).
2. Dört servis başlar.
3. `docker compose ps` tanımlanan tüm healthcheck'leri başarılı gösterir.
4. Yalnızca frontend `127.0.0.1:18081:80` host binding'ine sahiptir; API/PostgreSQL/Redis'de host binding yoktur.
5. Nginx `api:8080` adını çözer, `/api/tasks` yolunu değiştirmeden iletir; tarayıcıdan gerçek CRUD çalışır.
6. İlk GET cache miss ve ikinci GET hit; POST/PUT/DELETE cache invalidation ile doğrulanır.
7. API restart sonrası aynı PostgreSQL kaydı görünür.
8. Redis restart sonrası cache boşalır ve sonraki GET ile yeniden dolar.
9. `docker compose down` sonrasında `fullstack-ops-postgres-data` yerinde kalır; tekrar `up` ile veri korunur.
10. Yeni boş volume senaryosunda migration açıkça uygulanır, `tasks` ve `__EFMigrationsHistory` doğrulanır; mevcut Modül 3B kaydı yanlışlıkla silinmez.
11. Yeni veya değişen hiçbir takip edilen dosyada gerçek parola, token ya da tamamlanmış connection string bulunmaz; `.env` Git dışında kalır.
12. Test Task kayıtları ve Redis test key'leri temizlenir; ilişkisiz Docker kaynakları değiştirilmez.

## 10. Bu tanımın açık sınırları

- Mevcut API `/health` yalnızca temel liveness gösterir; PostgreSQL/Redis readiness değildir. API runtime image'ında `bash` var, `curl`/`wget` yok; frontend Nginx image'ında `wget` var. Gerçek Compose health durumları runtime acceptance sırasında doğrulanacaktır.
- Mevcut `fullstack-ops-postgres-data` external seçimi yerel veriyi korur, fakat yeni bilgisayarda ön hazırlık ister. Şartnamenin tek komutla sıfırdan kurulum hedefi henüz karşılanmaz.
- Şartnamenin nihai ayrı `nginx` ve observability servisleri bu dört servisli başlangıç tanımında yoktur. Sonraki modüllerde servis ayrımı yeniden karara bağlanmalıdır.
- `compose.yaml` oluşturuldu; gerçek `.env`, Compose volume'u, network'ü veya servisi oluşturulmadı. Migration uygulanmadı ve runtime kabul testleri çalıştırılmadı. Statik doğrulama runtime başarısı anlamına gelmez.

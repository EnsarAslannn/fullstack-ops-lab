# Modül 7 — Docker Compose Orchestration

Bu belge **30 Eylül 2026 dört servisli aşamanın tarihsel kaydıdır**; aşağıdaki “mevcut” ve “şartname” ifadeleri o aşamayı anlatır. **6 Ekim 2026 kabulü** eski ayrı nginx ve hazırlıksız tek komut beklentilerini günceller: altı servis, frontend içinde Nginx ve api backend rolü korunur; ilk kurulum .env/external volume/açık migration, normal başlatma hazırlanmış ortamda up'tır. Tarihsel eksikler bugünkü zorunluluk gibi okunmamalıdır. [Şartname karar kaydı](../../PROJECT_SPEC.md#final-kapsam-kararları--6-ekim-2026), [güncel mimari ve kalan final kabul](../../docs/architecture.md#şartname-farkları-ve-final-kabul-kararları).

**Durum: dört servisli Compose runtime acceptance tamamlandı.** Kök `compose.yaml`, Modül 6'da ayrı komutlarla kurulan dört servisi tanımlar. Bu kabulde servisler başlatıldı, gerçek akışlar ve `down/up` veri kalıcılığı doğrulandı, ardından Compose container'ları ve ağı kaldırıldı. Nginx upstream'i Compose servis adını kullanır; uygulama kodu, Dockerfile ve migration değiştirilmedi. Sonuçlar 11. bölümde, önceki statik doğrulama ise 8. bölümde ayrı tutulur.

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

`src/frontend/nginx.conf` upstream'i `api:8080` oldu. `proxy_pass http://api:8080;` sonunda URI `/` bulunmaz; böylece `/api/tasks` yolu backend'e aynı biçimde gider. Bu yönlendirme runtime kabulünde `GET /api/tasks → 200` ve `POST → 201` ile uçtan uca doğrulandı. Karar seçenekleri:

| Seçenek | Değerlendirme |
| --- | --- |
| Nginx upstream'ini `api:8080` yapmak | **Uygulandı:** Compose servis adı doğrudan görünür; az ayar, kolay teşhis. `proxy_pass` sonuna URI `/` eklenmedi; `/api/tasks` yolu korunur. |
| `api` servisine `fullstack-ops-api-proxy` network alias vermek | Eski config'i korur, fakat geçici Modül 6 container adını kalıcı Compose mimarisine taşır ve ek adlandırma gerektirir. |
| Nginx template ve environment kullanmak | Ortamlar arasında upstream seçimi sağlar, ancak bu tek ağlı laboratuvar için ek template/render mantığı getirir. |

Nginx'in servis adı çözümlemesi frontend başlarken başarılı olmalıdır; runtime çıktısında `frontend`, `api` healthy olduktan sonra başladı. API container'ı ileride **yeniden oluşturulursa** IP değişebilir; canlı Nginx'in bu durumda yeni IP'yi nasıl gördüğü bu kabulde ayrıca ölçülmedi.

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

Tanımda `interval: 5s`, `timeout: 3s`, `retries: 5`, API ve PostgreSQL için `start_period: 15s` kullanıldı. Runtime kabulünde dört servis `healthy` oldu ve son healthcheck loglarının çıkış kodu 0'dı. [Microsoft'un healthcheck rehberi](https://learn.microsoft.com/en-us/aspnet/core/host-and-deploy/health-checks) .NET Linux image'larında `curl` bulunmayabileceğini belirtir. Modül 8 daha zengin readiness kontrolleri içindir; API health davranışı değiştirilmedi.

## 6. Secret ve configuration

Root `.env.example` yalnızca örnek/placeholder değerler taşır; gerçek root `.env` Git dışında kalır (`.gitignore` bunu kapsar). Gelecek runtime testinde yerel `.env` içindeki `POSTGRES_USER`, `POSTGRES_DB`, `POSTGRES_PASSWORD` var olan volume kimlik bilgileriyle uyumlu olmalıdır. PostgreSQL servisine bu üç değer, API servisine `ConnectionStrings__Postgres` (host `postgres`, iç port `5432`), `ConnectionStrings__Redis=redis:6379`, `Cache__TasksTtlSeconds=60` ve yerel lab için `ASPNETCORE_ENVIRONMENT=Development` açık `environment` eşlemesiyle verilir. Gerçek parola veya tamamlanmış connection string takip edilen dosyalara yazılmadı.

Compose'un root `.env` dosyasını okuması **değişken substitution** sağlar; `.env` içindeki her anahtar otomatik olarak her container'a geçmez. `compose.yaml`, API connection string'ini `Host=postgres;Port=5432;Database=${POSTGRES_DB};Username=${POSTGRES_USER};Password=${POSTGRES_PASSWORD}` şablonundan kurar; şablonda gerçek parola bulunmaz, tamamlanmış değer container environment'ında bulunur. `.env.example` içindeki `ConnectionStrings__Postgres` ve `ConnectionStrings__Redis` placeholder'ları host geliştirmesi içindir; Compose için parola kaynağı `POSTGRES_PASSWORD` değeridir. `env_file` yerine açık `environment` kullanıldı; böylece PostgreSQL init değerleri gereksiz yere API'ye, API config'i PostgreSQL'e aktarılmaz. [Docker interpolation](https://docs.docker.com/compose/how-tos/environment-variables/variable-interpolation/) ve [environment önceliği](https://docs.docker.com/compose/how-tos/environment-variables/envvars-precedence/) bu davranışı açıklar.

Bu yerel yöntem production secret yönetimi değildir: Compose config'in çözümlenmiş çıktısı ve container environment secret gösterebilir. Doğrulamada `docker compose config -q` kullanılmalı, düz `config` çıktısı paylaşılmamalıdır. Gerçek secret, Dockerfile, image layer, Git diff veya README'ye girmez. Redis bu yerel ağda cache olarak parolasız planlanmıştır; dış portu yoktur. Production için ayrı secret ve ağ güvenliği tasarımı sonraki kapsamdır.

## 7. Redis cache davranışı

PostgreSQL ana veri kaynağıdır; Redis yalnızca `fullstack-ops:tasks:all:v1` liste cache'ini tutar. Redis restart sonrasında boş cache kabul edilebilir: sonraki GET PostgreSQL'den veriyi yeniden üretir ve key'i TTL ile doldurur. `/data` için `tmpfs` ve `--save '' --appendonly no` Modül 6'daki geçici cache davranışını korur; image'ın varsayılan volume tanımından gereksiz anonim veri volume'u oluşması önlenir. Named Redis volume'u gerekmez.

**Bilinen sınırlama:** Redis kapalıyken mevcut `GET /api/tasks` gerçek testte **500** döndü; fallback, retry veya circuit breaker yok. Redis yeniden hazır olduğunda istek tekrar başarılı olabilir ve cache yeniden dolar. Compose `depends_on`, çalışma anındaki kesintiyi otomatik çözmez. Bu tanım uygulama davranışını değiştirmez.

## 8. Oluşturulan dosyalar ve komut akışı

Repository kökünde **tek `compose.yaml`** oluşturuldu. `PROJECT_SPEC.md` örnek ağaçta `docker-compose.yml` ve override gösterse de bir base dosya bu dört servis için yeterlidir. `src/frontend/nginx.conf` upstream'i `api:8080` oldu. Build context'leri frontend için `./src/frontend`, API için `./src/backend/FullStackOpsLab.Api` olarak tanımlandı. Dosyada dört servis, tek `app` ağı ve external PostgreSQL volume bulunur. İlk statik tanım adımında root `.env.example` placeholder'larla güncellendi ve henüz gerçek `.env` oluşturulmadı; bu dosya daha sonraki runtime kabulünde hazırlandı.

İlk statik doğrulamada gerçek secret içermeyen `docker compose --env-file .env.example config -q` kullanıldı. Runtime kabulünde repository dışındaki user-secrets değerinden Git tarafından yok sayılan yerel `.env` hazırlandı ve `docker compose --env-file .env config -q`, `build`, `up -d --wait`, `restart` ve `down` komutları çalıştırıldı. Çözümlenmiş `config` çıktısı ekrana basılmadı. Aşağıdaki tablo komutların amacını açıklar; `pull` ve `down -v` bu kabulde çalıştırılmadı.

İlk statik tanım adımının doğrulaması:

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

## 9. Runtime acceptance kriterleri

Aşağıdaki kriterler bu kabulde gerçek servislerle sınandı; ölçülen sonuçlar 11. bölümdedir:

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

- Mevcut API `/health` yalnızca temel liveness gösterir; PostgreSQL/Redis readiness değildir. API runtime image'ında `bash` var, `curl`/`wget` yok; frontend Nginx image'ında `wget` var. Compose health durumları doğrulandı, fakat daha zengin dependency readiness ayrı Modül 8 konusudur.
- Mevcut `fullstack-ops-postgres-data` external seçimi yerel veriyi korur, fakat yeni bilgisayarda ön hazırlık ister. Şartnamenin tek komutla sıfırdan kurulum hedefi henüz karşılanmaz.
- Şartnamenin nihai ayrı `nginx` ve observability servisleri bu dört servisli başlangıç tanımında yoktur. Sonraki modüllerde servis ayrımı yeniden karara bağlanmalıdır.
- Yerel `.env` user-secrets kaynağından hazırlandı ve Git tarafından yok sayılıyor. Compose network/container'ları kabul sırasında oluşturulup sonunda kaldırıldı. External volume korundu; migration uygulanmadı.

## 11. Gerçek runtime acceptance — 30 Eylül 2026

Başlangıçta Git çalışma alanı temizdi. Docker Desktop Engine başlangıçta kapalıydı; arka planda başlatıldıktan sonra Engine `29.6.1`, Compose `v5.3.0` doğrulandı. İlişkisiz Docker kaynaklarının ilk envanteri kaydedildi. Var olan `fullstack-ops-postgres-data` volume'u **yeniden oluşturulmadı veya silinmedi**. Gerçek development parolası repository dışındaki user-secrets kaynağından yalnızca Git'in yok saydığı `.env` dosyasına aktarıldı; burada ve komut çıktılarında gösterilmiyor. `docker compose --env-file .env config -q` sıfır çıkış kodu verdi.

| Kontrol | Gerçek sonuç |
| --- | --- |
| Compose build | `docker compose --env-file .env build` başarılı; `fullstack-ops-lab-api:latest` image ID `0a3ad79e8212`, `fullstack-ops-lab-frontend:latest` image ID `e5fc6d8e1635` |
| Final image araçları | API image'ında .NET SDK yok; frontend image'ında Node ve npm yok; geçici container'da `nginx -t` başarılı. Image history içinde development parolası bulunmadı. |
| Başlangıç ve health | `up -d --wait --wait-timeout 120` başarılı; `postgres`, `redis`, `api`, `frontend` sırayla bağımlılık koşullarına göre başladı ve dördü de `healthy`. Son healthcheck çıkış kodları 0; PostgreSQL `accepting connections`, Redis `PONG` gösterdi. |
| Network ve port | Dört servis tek `fullstack-ops-lab_app` bridge ağında. `frontend`, `api`, `postgres`, `redis` DNS adları container içinden çözüldü; sabit IP tanımı yok. Tek host binding `127.0.0.1:18081->80/tcp`. API/PostgreSQL/Redis host binding'i yok; eski `18080`, `15432`, `16379` ve API `8080` host portları dinlemiyordu. |
| PostgreSQL | Inspect: `Type=volume`, `Name=fullstack-ops-postgres-data`, `Destination=/var/lib/postgresql`. `tasks`, `lab_tasks`, `__EFMigrationsHistory` bulundu; migration kaydı `20260928113912_InitialCreate`. `lab_tasks` satırı `1|Module 3B persistent task` korundu. Başlangıç `tasks` sayısı 0. API açılışında otomatik migration çağrısı yok; bu kabulde migration uygulanmadı. |
| Nginx ve frontend | Yalnız `http://127.0.0.1:18081` üzerinden `/`, JavaScript, CSS, `/favicon.svg` ve SPA fallback **200**. `/api/tasks` **200** döndü. `api:8080` upstream ve `/api/tasks` yolunun korunması gerçek GET/POST ile doğrulandı; Nginx error logunda hata yoktu. |
| CRUD | Benzersiz test görevi POST **201**, `Location: /api/tasks/27`; GET **200**, PUT **200**, boş başlık **400**, bulunmayan ID **404**. Yanıtta `id`, `title`, `description`, `isCompleted`, `createdAt`, `updatedAt` alanları vardı. Görev test boyunca korundu, son temizlikte DELETE **204** ile silindi. |
| Redis | `fullstack-ops:tasks:all:v1` temizlendi; ilk GET sonrası key oluştu ve TTL **60 s**, ikinci GET sonrası API logunda hit vardı. PUT key'i sildi; sonraki GET yeniden oluşturdu. İlk log kontrolünde cache miss 3, hit 2, invalidation 2 görüldü. Redis `/data` mount'u `tmpfs` idi. |
| Restart | API restart sonrası aynı görev tüm alanlarıyla bulundu. Redis restart key'i `1 → 0` yaptı; GET sonrası `1` oldu ve görev korundu. PostgreSQL restart sonrası ilk GET geçici başarısız oldu, kontrollü tekrar başarılıydı; cache temizlenerek gerçek DB listesi ve tekil görev **200** doğrulandı. API `/health` bu sırada dependency readiness ölçmez. |
| Chrome | Kurulu Google Chrome headless modda kullanıldı. Ana görev görüldü; ayrı tarayıcı görevi oluşturulup yenilemede korundu, tamamlandı ve silindi. Loading, disabled buton, hata/retry ve 390 px genişlikte yatay taşma olmaması doğrulandı. Boş liste önce kontrollü boş GET ile, test verisi silindikten sonra ayrıca **gerçek API** ile doğrulandı. Beklenmeyen console hatası yoktu. Kontrollü hata testinde bir beklenen başarısız GET vardı. Chrome bir DELETE isteğinde `net::ERR_ABORTED` olayı bildirdi; aynı isteğin tarayıcı yanıtı ve Nginx access logu **204** idi, UI kaydı kaldırdı. |
| `down/up` | İlk `down` dört container'ı ve ağı kaldırdı, external volume kaldı. Tekrar `up --wait` dört servisi `healthy` yaptı; aynı volume bağlandı, görev aynı ID ve alanlarla bulundu. Redis key'i yeniden oluşturmadan önce yoktu, GET sonrasında oluştu. |
| Final veri ve cleanup | Kabul ve tarayıcı görevleri silindi; `tasks=0`. Redis Task liste key'i temizlendi. Module 3B `lab_tasks` satırı ve `InitialCreate` geçmişi korundu. Final `down` sonrası proje container'ı/ağı yok; external volume ile iki Compose uygulama image'ı localde kaldı. Geçici tarayıcı scriptleri ve araç dizini kaldırıldı. |

Kullanılan temel komutlar: `docker compose --env-file .env config -q`, `build`, `up -d --wait --wait-timeout 120`, `ps`, `exec -T`, `restart api`, `restart redis`, `restart postgres`, `down`; ayrıca `docker inspect`, `docker network inspect`, `docker volume inspect`, `docker image history`, local Release ve Vite build komutları. Host HTTP istekleri yalnız frontend `18081` adresine gönderildi. `down -v`, `system prune`, `volume prune`, migration, commit ve push çalıştırılmadı.

Bu kabul **hazırlanmış local volume** ile geçti. Yeni bilgisayarda external volume önceden oluşturulmalı, PostgreSQL credentials uyumlu olmalı ve boş şema için `InitialCreate` açıkça uygulanmalıdır. Bu dört servisli adım, şartnamedeki nihai ayrı Nginx/observability servislerini ve sıfırdan tek komut kurulum hedefini henüz karşılamaz.

---

6 Ekim 2026 ortak dokümantasyon dizini: aşağıdaki standart başlıklar tarihsel ayrıntıya bağlanır; yeni deney veya yeni PASS sonucu değildir. Eski container/port/ölçüm değerleri kendi aşamasına aittir. Güncel altı servis ve DoD sınırları [mimari belgesindedir](../../docs/architecture.md#dokümantasyon-standardı-ve-definition-of-done).

## Goal

[1. Servis tanımı](#1-servis-tanımı).

## What You Will Learn

[Kavramlar ve nedenleri](#2-ağ-dns-ve-nginx-upstream-kararı).

## Architecture

[Bu aşamanın yapısı](#1-servis-tanımı); [güncel sistem](../../docs/architecture.md#servisler-portlar-ve-ağ).

## Prerequisites

Bu tarihsel deneyin kaynak/port/credential ön koşullarını kendi komut bölümünden kontrol et. Güncel normal kurulum için [Module9 rehberini](../09-environment-configuration/README.md#13-temiz-bilgisayar-kurulum-rehberi) izle; önceki lab komutlarını development kaynaklarında körlemesine tekrarlama.

## Step 1

[Hazırlık ve komutlar](#4-migration-ilk-kurulumda-açık-adım).

## Step 2

[Davranışı çalıştırma ve gözlemleme](#11-gerçek-runtime-acceptance--30-eylül-2026).

## Verification

[Gerçek sonuçlar](#11-gerçek-runtime-acceptance--30-eylül-2026); çalışma, cleanup ve ölçülmeyen kapsam ayrımlarını koru. Bu dizin genel final runtime kabulü değildir.

## Break It

[Belgelenmiş arıza veya eksik davranış](#7-redis-cache-davranışı).

## Diagnose It

[Teşhis ve gözlem](#5-healthcheck-ve-başlangıç-sırası).

## Fix It

[Doğru davranış / düzeltme açıklaması](#11-gerçek-runtime-acceptance--30-eylül-2026).

## What Happened?

[Ölçülen sonuç ve sınırlar](#11-gerçek-runtime-acceptance--30-eylül-2026).

## Key Concepts

[Temel ayrımlar](#2-ağ-dns-ve-nginx-upstream-kararı); [kısa sözlük](../../docs/architecture.md#kısa-sözlük).

## Interview Questions

1. depends_on başlangıç koşulu ile sonraki kesinti nasıl farklıdır?
2. Yalnız project adı değiştirmek external volume'u neden izole etmez?
3. Build, restart ve recreate arasındaki fark nedir?
4. down ile down -v hangi veriler için farklıdır?
5. Healthy servisler neden migration/CRUD başarısı kanıtı değildir?

## Exercises

compose.yaml üzerinden dışarı yayınlanan portları ve volume sahipliklerini listele; down/down-v'nin her kaynağa etkisini açıklayan bir tablo hazırla.

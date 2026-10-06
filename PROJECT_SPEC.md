# FullStack Ops Lab
## AI Development Master Specification

> Bu doküman, projenin yapay zeka destekli geliştirme sürecinde ana referans dosyası olarak kullanılacaktır.
> Amaç yalnızca çalışan bir proje üretmek değil; Docker, container networking, persistence, reverse proxy, caching,
> health checks, Prometheus metrikleri, Grafana dashboard'ları, CI/CD ve troubleshooting konularını gerçek bir full-stack uygulama üzerinden öğretmek ve
> portföyde sergilenebilir bir açık kaynak laboratuvar oluşturmaktır.

---

# 1. Proje Kimliği

## Proje Adı

`FullStack Ops Lab`

## Alt Başlık

`Full-Stack Docker, Infrastructure & Observability Lab`

## Kısa Tanım

FullStack Ops Lab; `.NET Backend`, `React + TypeScript Frontend`, `PostgreSQL`, `Redis`, `Nginx`, `Prometheus`,
`Grafana` ve `Docker` teknolojilerini tek bir gerçekçi full-stack uygulama üzerinde bir araya getiren, modüler, senaryo tabanlı ve
uygulamalı bir öğrenme laboratuvarıdır.

Proje klasik bir “Docker komutları rehberi” olmayacaktır.

Temel hedef:

- çalışan bir uygulama oluşturmak,
- bu uygulamanın altyapısını container'lara taşımak,
- sistemi kasıtlı olarak bozmak,
- hataları teşhis etmek,
- düzeltmek,
- yapılan işlemlerin nedenlerini öğrenmek,
- tüm bu süreci GitHub üzerinde profesyonel şekilde dokümante etmektir.

---

# 2. Projenin Ana Amacı

Bu proje üç ana amaca hizmet eder.

## 2.1 Teknik Öğrenme

Aşağıdaki konular yalnızca teorik olarak değil, uygulamalı olarak öğrenilecektir:

- Docker image ve container mantığı
- Docker CLI
- Dockerfile
- Multi-stage build
- `.dockerignore`
- Container lifecycle
- Docker networking
- Container DNS
- Docker volumes
- Bind mount ve named volume farkı
- PostgreSQL persistence
- Redis caching
- Cache hit / miss
- Cache invalidation
- Nginx reverse proxy
- Docker Compose
- Environment variables
- Health checks
- Service dependencies
- Application startup ordering
- Logs
- Metrics ve observability temelleri
- ASP.NET Core metrik enstrümantasyonu
- Prometheus metric scraping ve PromQL
- Grafana data source ve dashboard provisioning
- Düşük cardinality prensibi
- Container inspection
- Troubleshooting
- GitHub Actions
- CI
- Docker image build automation
- Container smoke test
- Temel production yaklaşımı

## 2.2 Mühendislik Refleksi

Proje yalnızca:

> “Docker Compose yazabiliyorum.”

seviyesinde kalmamalıdır.

Geliştirici şu sorulara cevap verebilir hale gelmelidir:

- Bir container neden diğerine `localhost` üzerinden ulaşamaz?
- Container isimleri neden hostname olarak kullanılabilir?
- PostgreSQL container'ı silindiğinde veri neden kaybolur?
- Named volume bunu nasıl çözer?
- `depends_on` neden servisin gerçekten hazır olduğunu garanti etmez?
- Health check neden gerekir?
- Nginx neden `502 Bad Gateway` döndürür?
- Redis cache neden stale data üretebilir?
- Cache invalidation ne zaman yapılmalıdır?
- Bir Docker image neden gereksiz şekilde büyük olabilir?
- Multi-stage build image boyutunu neden azaltır?
- Build-time ve runtime environment arasındaki fark nedir?
- Container logları nasıl incelenir?
- Bir servisin neden başlamadığını nasıl teşhis ederiz?
- Log, metric ve trace arasındaki fark nedir?
- Prometheus metrikleri neden pull modeliyle toplar?
- Grafana veriyi nereden alır ve neden veri kaynağı değildir?
- Bir Prometheus target neden `DOWN` görünür?
- Metric label cardinality neden kontrol edilmelidir?
- CI pipeline içinde Docker image nasıl doğrulanır?

## 2.3 Portföy Değeri

Proje GitHub üzerinde incelendiğinde ziyaretçi şunları görebilmelidir:

- Gerçek çalışan full-stack uygulama
- Temiz repository yapısı
- Açıklayıcı mimari diyagramı
- Docker Compose orkestrasyonu
- PostgreSQL persistence
- Redis cache
- Nginx reverse proxy
- Health checks
- Prometheus ile uygulama metrikleri
- Kodla provision edilen Grafana dashboard'u
- GitHub Actions
- Troubleshooting laboratuvarları
- Teknik kararların açıklamaları
- Ölçülebilir optimizasyon örnekleri
- Kullanılabilir README dokümantasyonu

---

# 3. Proje Felsefesi

Bu projede aşağıdaki yaklaşım korunmalıdır:

> Teknoloji göstermek için teknoloji ekleme.
> Her teknoloji gerçek bir problemi çözmek için kullanılmalıdır.

Örnek:

Yanlış yaklaşım:

> “Redis kullandım.”

Doğru yaklaşım:

> “Sık okunan endpoint için Redis cache ekledim. İlk istek PostgreSQL'den geldi, sonraki istek cache'den cevaplandı.
> Veri güncellendiğinde cache invalidation uyguladım.”

Yanlış yaklaşım:

> “Docker volume kullandım.”

Doğru yaklaşım:

> “PostgreSQL container'ını sildiğimde verinin kaybolduğunu gösterdim, ardından named volume ekleyerek persistence problemini çözdüm.”

Yanlış yaklaşım:

> “Nginx ekledim.”

Doğru yaklaşım:

> “Frontend ve API trafiğini tek giriş noktası üzerinden yönlendirmek için Nginx reverse proxy kullandım.”

---

# 4. AI Asistanının Rolü

Bu proje yapay zeka ile birlikte geliştirilecektir.

AI'nin görevi yalnızca kod üretmek değildir.

AI aynı zamanda:

- mentor,
- pair programmer,
- code reviewer,
- DevOps rehberi,
- debugging partner

olarak hareket etmelidir.

## AI İçin Temel Kurallar

AI aşağıdaki kurallara uymalıdır.

### 4.1 Projenin tamamını tek seferde üretme

Projeyi modül modül geliştir.

Bir modül tamamlanmadan sonraki modüle geçme.

### 4.2 Her önemli işlemden önce kısa açıklama yap

Örneğin:

> Şimdi PostgreSQL container'ını uygulamaya ekleyeceğiz. Ancak henüz volume eklemeyeceğiz.
> Bunun amacı container silindiğinde verinin neden kaybolduğunu gözlemlemek.

### 4.3 Kullanıcıya yalnızca komut verme

Komutun ne yaptığını açıkla.

Örnek:

```bash
docker ps
```

Açıklama:

- Çalışmakta olan container'ları gösterir.
- `-a` eklendiğinde durmuş container'lar da görünür.

### 4.4 Kritik kavramları özellikle öğret

Aşağıdaki kavramlar geçiştirilmemelidir:

- image vs container
- host vs container
- localhost
- port mapping
- Docker network
- Docker DNS
- volume
- image layer
- multi-stage build
- reverse proxy
- health check
- environment variable
- cache invalidation
- metric, counter ve gauge
- Prometheus scrape ve PromQL
- Grafana provisioning
- metric cardinality
- CI

### 4.5 Kullanıcı adına gereksiz soyutlama yapma

Öğrenme projesi olduğu için bazı altyapı detaylarını gizleyen otomasyonlar ilk aşamada kullanılmamalıdır.

Örneğin:

- İlk Docker deneyimleri CLI ile yapılmalıdır.
- Docker Compose hemen kullanılmamalıdır.
- Önce ayrı container'ların mantığı anlaşılmalıdır.

### 4.6 Her modül sonunda kullanıcıyı test et

Her modülün sonunda:

- 3-5 kısa kavramsal soru
- 1 küçük uygulamalı görev

ver.

### 4.7 Hataları hemen gizlice düzeltme

Bir hata oluştuğunda doğrudan çözümü vermeden önce:

1. hata mesajını incele,
2. muhtemel sebepleri açıkla,
3. teşhis komutlarını göster,
4. kullanıcıya düşünme fırsatı ver,
5. ardından çözümü uygula.

### 4.8 Kod üretirken açıklanabilirliği koru

Kod mümkün olduğunca sade olmalıdır.

Bu proje:

- Clean Architecture gösterisi,
- DDD gösterisi,
- aşırı abstraction gösterisi

olmamalıdır.

Asıl odak altyapıdır.

---

# 5. Uygulama Senaryosu

Laboratuvarın merkezinde küçük ama gerçek bir uygulama bulunacaktır.

## Uygulama Adı

`Sandbox Tasks`

## Uygulama Türü

Basit görev yönetim uygulaması.

## Temel Kullanım

Kullanıcı:

- görevleri listeleyebilir,
- yeni görev oluşturabilir,
- görevi tamamlandı olarak işaretleyebilir,
- görevi silebilir.

Amaç business logic oluşturmak değil, altyapıyı gerçek bir uygulama üzerinde test etmektir.

---

# 6. Fonksiyonel Gereksinimler

## Backend API

Aşağıdaki endpoint'ler yeterlidir.

```http
GET /api/tasks
GET /api/tasks/{id}
POST /api/tasks
PUT /api/tasks/{id}
DELETE /api/tasks/{id}
```

Örnek task modeli:

```text
Id
Title
Description
IsCompleted
CreatedAt
UpdatedAt
```

## Frontend

Frontend aşağıdakileri desteklemelidir:

- görev listesi
- yeni görev oluşturma
- görev tamamlama
- görev silme
- loading state
- hata mesajı
- basit fakat temiz responsive arayüz

Frontend'in amacı görsel tasarım gösterisi değildir.

---

# 7. Teknoloji Stack'i

## Backend

- .NET
- ASP.NET Core Web API
- Entity Framework Core
- PostgreSQL provider

## Frontend

- React
- TypeScript
- Vite

## Database

- PostgreSQL

## Cache

- Redis

## Reverse Proxy

- Nginx

## Containerization

- Docker
- Docker Compose

## Observability

- OpenTelemetry Metrics for .NET
- Prometheus
- Grafana

## CI

- GitHub Actions

---

# 8. Hedef Sistem Mimarisi

Final mimari aşağıdaki gibi olacaktır:

```text
Tarayıcı
   |
   v
frontend:80 [Nginx + React statik dosyaları]
   | /api/*
   v
api:8080 [.NET API / backend]
   |                     |
   v                     v
postgres:5432        redis:6379

prometheus:9090 --scrape /metrics--> api:8080
grafana:3000 ----PromQL-----------> prometheus:9090
```

Observability akışı:

```text
.NET API /metrics
        |
        | scrape
        v
   Prometheus
        |
        | PromQL
        v
     Grafana
```

Şemadaki React statik sunumu ve Nginx reverse proxy aynı `frontend` container'ındadır; ayrı bir `nginx` servisi gerekmez. `api` servisi backend rolünü karşılar. Final Compose servisleri `frontend`, `api`, `postgres`, `redis`, `prometheus` ve `grafana` olmak üzere altıdır.

Prometheus, backend'i Docker network içindeki `api:8080` servis hedefinden scrape etmelidir. Grafana'nın Prometheus data source'u ve dashboard'u dosyalardan otomatik provision edilmelidir.

Routing:

```text
/        -> React frontend
/api/*   -> .NET backend
```

## Final kapsam kararları — 6 Ekim 2026

Kullanıcının açık kabulüyle aşağıdaki iki karar şartnamenin servis, kurulum ve final kabul beklentilerini günceller:

| Konu | Önceki beklenti | Kabul edilen tasarım | Gerekçe |
| --- | --- | --- | --- |
| Servis ayrımı | Module 7 ayrı frontend, backend ve nginx dahil en az yedi servis sayıyordu | Altı servis korunur; frontend içinde Nginx statik sunucu/reverse proxy, api backend rolüdür; ayrı nginx eklenmez | Mevcut tasarım iki routing görevini aynı container'da yerine getirir; ek servis oluşturmadan roller ve internal API erişimi korunur |
| İlk kurulum | Clone/env/up demo sırası external volume ve şema hazırlığını göstermiyordu | İlk kurulumda ignored .env, external PostgreSQL volume'u ve mevcut InitialCreate migration'ının açık uygulanması hazırlanır; sonrasında normal compose up sistemi başlatır | Veri deposunun sahipliği ve migration adımı görünür kalır; hazırlanmış ortamın başlatılması, sıfır hazırlıkla kurulumla karıştırılmaz |

İlk kurulum komutları [Module 9 rehberinde](labs/09-environment-configuration/README.md#13-temiz-bilgisayar-kurulum-rehberi) bulunur. Bu kararlar runtime kabulü değildir; bölüm 30/31/37'nin gerçek final doğrulaması ayrıca yapılmalıdır. Diğer şartname gereksinimleri korunur.

---

# 9. Repository Yapısı

Hedef repository yapısı:

```text
fullstack-ops-lab/
│
├── src/
│   ├── backend/
│   │   ├── FullStackOpsLab.Api/
│   │   └── Dockerfile
│   │
│   └── frontend/
│       ├── src/
│       ├── public/
│       ├── package.json
│       └── Dockerfile
│
├── infrastructure/
│   ├── nginx/
│   │   └── nginx.conf
│   │
│   ├── prometheus/
│   │   └── prometheus.yml
│   ├── grafana/
│   │   ├── provisioning/
│   │   │   ├── datasources/
│   │   │   └── dashboards/
│   │   └── dashboards/
│   └── scripts/
│
├── labs/
│   ├── 01-docker-fundamentals/
│   │   └── README.md
│   ├── 02-dockerfiles/
│   │   └── README.md
│   ├── 03-postgresql-volumes/
│   │   └── README.md
│   ├── 04-docker-networking/
│   │   └── README.md
│   ├── 05-redis-cache/
│   │   └── README.md
│   ├── 06-nginx/
│   │   └── README.md
│   ├── 07-docker-compose/
│   │   └── README.md
│   ├── 08-health-checks/
│   │   └── README.md
│   ├── 09-environment-config/
│   │   └── README.md
│   ├── 10-prometheus-grafana/
│   │   └── README.md
│   └── 11-ci-cd/
│       └── README.md
│
├── troubleshooting/
│   ├── 01-wrong-localhost/
│   ├── 02-lost-database/
│   ├── 03-redis-connection/
│   ├── 04-nginx-502/
│   ├── 05-database-not-ready/
│   ├── 06-env-misconfiguration/
│   └── 07-monitoring-no-data/
│
├── docs/
│   ├── architecture.md
│   ├── commands-cheatsheet.md
│   └── glossary.md
│
├── .github/
│   └── workflows/
│       └── ci.yml
│
├── docker-compose.yml
├── docker-compose.override.yml
├── .env.example
├── .gitignore
└── README.md
```

Bu yapı gerektiğinde sadeleştirilebilir ancak temel ayrım korunmalıdır:

- uygulama kodu
- altyapı
- laboratuvarlar
- troubleshooting
- dokümantasyon

---

# 10. Geliştirme Fazları

Proje aşağıdaki sırayla geliştirilmelidir.

---

# FAZ 0 — Baseline Application

## Amaç

Docker'a geçmeden önce uygulamanın normal şekilde çalıştığını doğrulamak.

## Yapılacaklar

### Backend

- .NET Web API oluştur
- PostgreSQL kullanılmadan ilk aşamada basit mock/in-memory data ile endpoint'leri doğrula
- Swagger/OpenAPI aktif olsun
- `/health` endpoint'i oluştur

### Frontend

- React + TypeScript + Vite oluştur
- API'den görev listesini çek
- CRUD akışını tamamla

## Tamamlanma Kriteri

Docker olmadan:

```text
Frontend -> API
```

akışı çalışmalıdır.

## Öğrenme Noktası

Containerization, çalışan bir sistemi paketleme işidir.

Çalışmayan uygulamayı Docker'a taşımaya çalışma.

---

# MODÜL 1 — Docker Fundamentals

## Amaç

Docker'ın temel çalışma modelini öğrenmek.

## Kavramlar

- Docker Engine
- Image
- Container
- Registry
- Docker Hub
- Container lifecycle
- Port mapping

## Uygulamalar

AI aşağıdaki komutları uygulamalı olarak öğretmelidir:

```bash
docker --version
docker info
docker pull
docker images
docker run
docker ps
docker ps -a
docker stop
docker start
docker restart
docker rm
docker rmi
docker logs
docker exec
docker inspect
```

## Mini Lab

Nginx image'i indir:

```bash
docker pull nginx
```

Container çalıştır:

```bash
docker run -d -p 8080:80 --name sandbox-nginx nginx
```

Browser:

```text
http://localhost:8080
```

## Öğrenme Soruları

- Image ile container arasındaki fark nedir?
- `8080:80` ne anlama gelir?
- Container silinirse image silinir mi?
- `docker exec` ne işe yarar?

---

# MODÜL 2 — Custom Dockerfiles & Multi-Stage Builds

## Amaç

Kendi uygulama image'larımızı üretmek.

## Backend Dockerfile

İlk olarak mümkün olduğunca basit Dockerfile oluştur.

Ardından multi-stage build'e geç.

Örnek mantık:

```text
Stage 1 -> SDK -> build/publish
Stage 2 -> Runtime -> published files
```

## Öğretilecek Konular

- `FROM`
- `WORKDIR`
- `COPY`
- `RUN`
- `EXPOSE`
- `ENTRYPOINT`
- build context
- image layer
- layer cache
- `.dockerignore`

## Multi-Stage Build

Amaç:

.NET SDK'nın production image içinde bulunmaması.

Ölçüm yapılmalıdır.

Örneğin README:

```text
Before optimization : XXX MB
After optimization  : XXX MB
Reduction           : XX %
```

Gerçek değerler build sonrasında ölçülmelidir.

## Frontend Dockerfile

İki aşamalı yapı kullanılabilir:

```text
Node -> npm build
Nginx -> static production files
```

## Production İyileştirmeleri

Mümkünse:

- non-root user
- minimal runtime image
- gereksiz dosyaların image dışında bırakılması

## Tamamlanma Kriteri

Hem frontend hem backend ayrı ayrı Docker image olarak çalışabilmelidir.

---

# MODÜL 3 — PostgreSQL & Persistence

## Amaç

Container filesystem'in geçici yapısını anlamak.

## İlk Deney

PostgreSQL container volume olmadan çalıştır.

Bir test task oluştur.

Ardından container'ı tamamen sil:

```bash
docker rm -f <container>
```

Yeni PostgreSQL container oluştur.

Verinin kaybolduğu gözlemlenmelidir.

## Soru

> Container silindiğinde veri neden kayboldu?

## Çözüm

Named volume ekle.

Örnek:

```bash
docker volume create fullstack-ops-postgres-data
```

## Öğretilecek Konular

- Container writable layer
- Docker volume
- Named volume
- Bind mount
- Persistence

## Test

1. Veri oluştur.
2. Container'ı sil.
3. Aynı volume ile container'ı yeniden oluştur.
4. Verinin hala mevcut olduğunu doğrula.

## README'de Bulunması Gereken Bölüm

```text
Without Volume
Container removed -> Data lost

With Named Volume
Container removed -> Data preserved
```

---

# MODÜL 4 — Docker Networking

## Amaç

Container'ların birbirleriyle nasıl haberleştiğini anlamak.

## Custom Bridge Network

Yeni network oluştur:

```bash
docker network create fullstack-ops-network
```

.NET API ve PostgreSQL aynı network'e bağlanmalıdır.

## Kritik Hata Senaryosu

İlk olarak connection string yanlış ayarlanmalıdır:

```text
Host=localhost
```

API'nin PostgreSQL'e bağlanamadığı görülmelidir.

Daha sonra:

```text
Host=postgres
```

veya gerçek container/service adı kullanılmalıdır.

## Öğretilecek Ana Kavram

Container içindeki:

```text
localhost
```

o container'ın kendisidir.

Host makine veya başka container değildir.

## DNS

Docker network üzerindeki servis isimleri hostname gibi çözümlenir.

Örnek:

```text
postgres:5432
redis:6379
```

## Teşhis Araçları

- `docker network ls`
- `docker network inspect`
- `docker inspect`
- container içinden DNS kontrolü
- container logları

---

# MODÜL 5 — Redis Cache

## Amaç

Redis'i gerçek application cache olarak kullanmak.

## Cache Edilecek Endpoint

```http
GET /api/tasks
```

## Cache Flow

```text
Request
   |
   v
Check Redis
   |
   +-- HIT --> Return cached data
   |
   +-- MISS -> Query PostgreSQL
                  |
                  v
               Cache data
                  |
                  v
               Return response
```

## Cache Key

Örnek:

```text
tasks:all
```

## TTL

Örnek başlangıç değeri:

```text
60 seconds
```

TTL config üzerinden değiştirilebilir olmalıdır.

## Cache Invalidation

Aşağıdaki endpoint'lerden sonra:

```text
POST
PUT
DELETE
```

ilgili cache temizlenmelidir.

## Öğretilecek Konular

- cache hit
- cache miss
- TTL
- stale data
- invalidation
- Redis persistence ile application cache farkı

## Log Örneği

Backend loglarında görünür olmalıdır:

```text
[CACHE MISS] tasks:all
[CACHE HIT] tasks:all
[CACHE INVALIDATED] tasks:all
```

## Lab

1. `GET /api/tasks`
2. Cache MISS gözlemle
3. Tekrar çağır
4. Cache HIT gözlemle
5. Task oluştur
6. Cache invalidation gözlemle
7. Tekrar GET çağır
8. MISS ardından cache yenilenmesini gözlemle

---

# MODÜL 6 — Nginx Reverse Proxy

## Amaç

Tüm uygulamayı tek giriş noktası altında toplamak.

## Routing

Nginx:

```text
/        -> frontend
/api/    -> backend
```

## Öğretilecek Konular

- reverse proxy
- upstream
- proxy_pass
- HTTP headers
- single entry point

## Hedef

Kullanıcının doğrudan backend portunu bilmesine gerek kalmamalıdır.

Örneğin dışarıdan:

```text
http://localhost
```

yeterli olmalıdır.

## Troubleshooting

Kasıtlı olarak yanlış backend hostname kullanılmalıdır.

Sonuç:

```text
502 Bad Gateway
```

Ardından:

- Nginx logs
- container network
- service name
- upstream configuration

kontrol edilerek sorun çözülmelidir.

---

# MODÜL 7 — Docker Compose Orchestration

## Amaç

Tüm servisleri tek bir deklaratif yapı ile yönetmek.

## Servisler

Final compose dosyasında şu altı servis:

```text
frontend
api
postgres
redis
prometheus
grafana
```

bulunmalıdır.

Nginx, `frontend` container'ında React statik dosyalarını sunar ve `/api/*` isteklerini `api:8080` hedefine yönlendirir. `api` backend servisidir; ayrıca `nginx` servisi eklenmesi zorunlu değildir.

## Öğretilecek Konular

- `services`
- `build`
- `image`
- `ports`
- `environment`
- `env_file`
- `volumes`
- `networks`
- `depends_on`

## Temel Komutlar

```bash
docker compose up
docker compose up -d
docker compose up --build
docker compose down
docker compose ps
docker compose logs
docker compose logs -f
docker compose exec
docker compose build
docker compose pull
```

## Tek Komut Hedefi

İlk kurulum ve normal başlatma ayrıdır. İlk kurulumda `.env` placeholder'ları güvenli biçimde doldurulmalı, external `fullstack-ops-postgres-data` volume'u hazırlanmalı ve mevcut `InitialCreate` migration'ı açıkça uygulanıp doğrulanmalıdır. Mevcut volume varsa otomatik silinmemeli veya sıfırlanmamalıdır.

Bu hazırlığı tamamlanmış final sistem:

```bash
docker compose up --build -d
```

ile ayağa kalkmalıdır. Bu komut ilk volume/migration hazırlığının yerine geçmez; hazırlıksız clone/env/up ile sıfırdan kurulum hedeflenmez.

Kapatma:

```bash
docker compose down
```

Veriler varsayılan olarak korunmalıdır.

Normal kapatma dışında, Compose-managed volume'ları da kaldırabilen:

```bash
docker compose down -v
```

kullanımının sonucu özellikle açıklanmalıdır. `-v`, Prometheus/Grafana managed volume'larını silebilir; external PostgreSQL volume'unu kaldırmaz. Volume silme rutin kurulum/cleanup adımı değildir.

---

# MODÜL 8 — Health Checks & Service Readiness

## Amaç

Container'ın çalışması ile servisin hazır olması arasındaki farkı öğrenmek.

## PostgreSQL Health Check

Örnek yaklaşım:

```yaml
healthcheck:
  test: ["CMD-SHELL", "pg_isready -U <user>"]
  interval: 5s
  timeout: 5s
  retries: 5
```

Gerçek değerler proje config'ine göre ayarlanmalıdır.

## Backend Health Endpoint

Backend:

```http
GET /health
```

Temel health check döndürmelidir.

İleri aşamada:

- PostgreSQL
- Redis

bağlantıları da health check sistemine dahil edilebilir.

## Kritik Öğrenme

```yaml
depends_on
```

tek başına:

> dependency tamamen hazır

anlamına gelmez.

Bu davranış deneysel olarak gösterilmelidir.

---

# MODÜL 9 — Environment Configuration & Secrets

## Amaç

Konfigürasyonu koddan ayırmak.

## `.env.example`

Repository'ye:

```text
POSTGRES_DB=
POSTGRES_USER=
POSTGRES_PASSWORD=
REDIS_CONNECTION=
ASPNETCORE_ENVIRONMENT=
GF_SECURITY_ADMIN_USER=
GF_SECURITY_ADMIN_PASSWORD=
```

gibi örnek değişkenler eklenebilir.

Gerçek secret değerler commit edilmemelidir.

## Kurallar

`.env`

```gitignore
.env
```

içinde olmalıdır.

`.env.example` commit edilmelidir.

## Öğretilecek Konular

- configuration
- environment variables
- secrets
- development vs production config
- source control güvenliği

---

# MODÜL 10 — Observability: Logs, Prometheus & Grafana

## Amaç

Bir problem çıktığında sistemi loglar ve metrikler üzerinden incelemeyi; .NET API'nin metrik üretmesini, Prometheus'un bu metrikleri toplamasını ve Grafana'nın anlamlı dashboard'lar sunmasını öğrenmek.

Bu modül final sürümün zorunlu parçasıdır.

## Önce Docker-native İnceleme

Prometheus ve Grafana eklenmeden önce aşağıdaki araçlarla mevcut sistem gözlemlenmelidir:

```bash
docker logs
docker compose logs
docker inspect
docker stats
docker compose ps
```

Backend loglarında en az:

- application startup,
- database connection status,
- Redis cache hit/miss,
- exception,
- request bilgisi

gözlemlenebilmelidir.

## Temel Kavramlar

AI şu ayrımı açıkça öğretmelidir:

| Sinyal | Cevapladığı soru | Bu projedeki örnek |
|---|---|---|
| Log | Belirli bir olayda ne oldu? | `CACHE MISS`, exception |
| Metric | Sistem zaman içinde nasıl davranıyor? | istek hızı, hata oranı, gecikme |
| Trace | Tek bir istek servislerde nereden geçti? | Bu sürümde kapsam dışı |

Ayrıca şu roller karıştırılmamalıdır:

- Uygulama metriği üretir.
- Prometheus metrikleri düzenli aralıklarla scrape eder ve saklar.
- Grafana, Prometheus'u data source olarak sorgular ve görselleştirir.

## .NET Metric Instrumentation

Backend, .NET'in `System.Diagnostics.Metrics` altyapısı ve OpenTelemetry Metrics kullanılarak enstrümante edilmelidir.

En az şu kaynaklar eklenmelidir:

- ASP.NET Core request metrikleri,
- Kestrel/runtime için projede anlamlı hazır metrikler,
- uygulamaya özel cache metrikleri.

Prometheus exporter ile yalnızca internal Docker network üzerinden erişilebilen bir endpoint sunulmalıdır:

```http
GET /metrics
```

Bu endpoint'in Nginx üzerinden public olarak yayınlanması gerekmez.

## Custom Metrics

En az aşağıdaki davranış ölçülebilmelidir:

```text
cache hit count
cache miss count
cache invalidation count
```

Gerekirse task oluşturma/güncelleme sayısı için ek counter kullanılabilir.

Metric ve label adları implementasyon sırasında tek standarda bağlanmalı, README ve dashboard sorguları gerçek `/metrics` çıktısıyla eşleştirilmelidir.

### Cardinality Kuralı

Metric label'larında aşağıdaki gibi sınırsız veya kullanıcıya özel değerler kullanılmamalıdır:

```text
task_id
user_id
request_id
raw URL
exception message
```

Uygun label örnekleri:

```text
cache_result = hit | miss
operation = list | create | update | delete
status_code = 200 | 404 | 500
```

## Prometheus

Compose'a resmi Prometheus image'ı ile `prometheus` servisi eklenmelidir.

Minimum yapılandırma:

```yaml
global:
  scrape_interval: 15s

scrape_configs:
  - job_name: fullstack-ops-api
    static_configs:
      - targets: ["api:8080"]
```

Gerçek internal port ve metrics path proje yapılandırmasından doğrulanmalıdır. `prometheus.yml` repository'de version control altında tutulmalıdır.

Prometheus UI üzerinden şu kontroller yapılmalıdır:

- `Status > Targets` altında backend target `UP`,
- `up{job="fullstack-ops-api"}` sorgusu `1`,
- request ve cache metrikleri sorgulanabilir.

PromQL için en az şu kavramlar uygulamalı gösterilmelidir:

- instant vector,
- range vector,
- `rate()`,
- `sum()`,
- label filter,
- counter ve gauge farkı.

## Grafana

Compose'a resmi Grafana image'ı ile `grafana` servisi eklenmelidir.

Grafana ilk açılışta manuel tıklama gerektirmeden hazır olmalıdır:

- Prometheus data source YAML ile provision edilmeli,
- dashboard provider YAML ile provision edilmeli,
- dashboard JSON repository'de tutulmalı,
- Grafana Prometheus'a `http://prometheus:9090` üzerinden ulaşmalıdır.

Admin bilgileri environment variable ile yönetilmeli; gerçek parola repository'ye commit edilmemelidir.

## Minimum Dashboard

`FullStack Ops Lab Overview` isimli dashboard en az şu panelleri içermelidir:

1. API target durumu (`up`),
2. saniye başına HTTP request sayısı,
3. HTTP 5xx hata oranı,
4. request duration p95,
5. cache hit sayısı,
6. cache miss sayısı,
7. cache hit ratio,
8. cache invalidation sayısı.

Dashboard sorguları kopyalanan örnek isimlere güvenmemelidir. Önce gerçek `/metrics` çıktısı ve Prometheus'taki metric adları doğrulanmalı, sonra PromQL yazılmalıdır.

Trafik olmadığında bazı rate panellerinin boş görünmesinin normal olabileceği açıklanmalıdır. Lab sırasında kontrollü istek üretilmelidir.

## Persistence ve Kaynak Kullanımı

- Prometheus için `prometheus_data` named volume kullanılmalıdır.
- Grafana dashboard ve data source tanımları dosyadan provision edilmelidir.
- Grafana'nın çalışma verisi için `grafana_data` named volume kullanılabilir.
- Yerel öğrenme ortamı için Prometheus retention süresi ve kaynak kullanımı makul tutulmalıdır.

`docker compose down -v` komutunun izleme verilerini de sileceği özellikle gösterilmelidir.

## Network ve Portlar

- Backend `/metrics` endpoint'i internal network'te kalmalıdır.
- Prometheus ve Grafana geliştirme ortamında localhost'a publish edilebilir.
- PostgreSQL ve Redis monitoring amacıyla public port almamalıdır.
- Grafana'nın Prometheus URL'sinde `localhost` değil Docker service name kullanılmalıdır.

Örnek geliştirme URL'leri:

```text
Prometheus -> http://localhost:9090
Grafana    -> http://localhost:3000
```

Port çakışması varsa gerçek değerler değiştirilip dokümante edilmelidir.

## Health Checks

Monitoring servisleri için uygun health check'ler eklenmelidir:

```text
Prometheus -> /-/ready
Grafana    -> /api/health
```

Health check komutları kullanılan resmi image içinde gerçekten mevcut araçlarla çalışmalıdır. Yalnızca container'ın açılması başarı kabul edilmemelidir.

## Güvenlik

- Grafana anonymous access varsayılan olarak kapalı kalmalıdır.
- Admin parolası source control'e yazılmamalıdır.
- Prometheus ve Grafana portları yalnızca yerel geliştirme amacıyla yayınlanmalıdır.
- `/metrics` içinde secret, kişisel veri veya kullanıcı girdisi label olarak bulunmamalıdır.

## Resmi Referanslar

Implementasyon sırasında güncel resmi dokümantasyon esas alınmalıdır:

- [OpenTelemetry ile .NET observability](https://learn.microsoft.com/dotnet/core/diagnostics/observability-with-otel)
- [Prometheus configuration](https://prometheus.io/docs/prometheus/latest/configuration/configuration/)
- [Grafana provisioning](https://grafana.com/docs/grafana/latest/administration/provisioning/)

## Lab Akışı

1. Docker-native log ve stats çıktısını incele.
2. Backend `/metrics` çıktısını internal network üzerinden doğrula.
3. Prometheus target'ın `UP` olduğunu doğrula.
4. Prometheus UI'da `up` sorgusu çalıştır.
5. Task listesini art arda çağırarak cache hit/miss üret.
6. Bir task değiştirerek invalidation üret.
7. Grafana dashboard panellerinin güncellendiğini doğrula.
8. Backend scrape target'ını bilinçli olarak boz.
9. Prometheus target'ın `DOWN` olduğunu ve Grafana'da veri kesildiğini gözlemle.
10. Service name/port/path ayarını düzelterek sistemi geri getir.

## Tamamlanma Kriteri

- Backend metrik endpoint'i çalışıyor.
- Prometheus backend'i scrape ediyor ve target `UP`.
- Prometheus readiness endpoint'i başarılı.
- Grafana health endpoint'i başarılı.
- Grafana data source otomatik provision ediliyor.
- Dashboard otomatik yükleniyor.
- Gerçek trafik request ve cache panellerinde görülüyor.
- Monitoring hata senaryosu teşhis edilip çözülüyor.
- Lab README, PromQL örnekleri ve ekran görüntüleri güncel.

---

# MODÜL 11 — GitHub Actions CI

## Amaç

Her push ve pull request'te projenin otomatik doğrulanması.

## Workflow Trigger

Örnek:

```yaml
on:
  push:
  pull_request:
```

Branch stratejisine göre geliştirilebilir.

## Pipeline

Pipeline ideal olarak:

```text
Checkout
   |
   v
Backend Restore
   |
   v
Backend Build
   |
   v
Backend Tests
   |
   v
Frontend Install
   |
   v
Frontend Build
   |
   v
Docker Image Build
   |
   v
Monitoring Config Validation
   |
   v
Docker Compose Smoke Test
```

## Minimum Gereksinim

CI en az:

- backend build
- frontend build
- Docker image build
- `docker compose config` doğrulaması
- Prometheus config doğrulaması (`promtool check config`)

adımlarını içermelidir.

## Opsiyonel

GitHub Container Registry:

```text
ghcr.io/<username>/fullstack-ops-lab-api
ghcr.io/<username>/fullstack-ops-lab-frontend
```

image push.

Bu adım yalnızca temel CI tamamlandıktan sonra eklenmelidir.

---

# 11. Troubleshooting Labs

Troubleshooting bu projenin temel ayırt edici özelliklerinden biridir.

Her senaryo ayrı klasörde bulunmalıdır.

Standart şablon:

```markdown
# Scenario

## Symptoms

## Expected Behaviour

## Investigation

## Useful Commands

## Root Cause

## Fix

## Verification

## What We Learned
```

---

# TROUBLESHOOTING 1 — Wrong Localhost

## Problem

Backend connection string:

```text
Host=localhost
```

## Belirti

API:

```text
connection refused
```

veya benzeri database connection hatası verir.

## Öğrenilecek Nokta

Container içindeki localhost container'ın kendisidir.

## Çözüm

Docker network DNS'i üzerinden PostgreSQL service name kullanılır.

---

# TROUBLESHOOTING 2 — Lost PostgreSQL Data

## Problem

PostgreSQL volume olmadan çalışmaktadır.

Container silinir.

## Belirti

Task kayıtları kaybolur.

## Öğrenilecek Nokta

Container filesystem persistence sağlamaz.

## Çözüm

Named volume.

---

# TROUBLESHOOTING 3 — Redis Connection Failure

## Problem

Yanlış Redis hostname veya network.

## Belirti

Backend Redis'e bağlanamaz.

## Teşhis

- container status
- logs
- network inspect
- config kontrolü

---

# TROUBLESHOOTING 4 — Nginx 502

## Problem

Nginx upstream yanlış service adına yönlendirilmiştir.

## Belirti

```text
502 Bad Gateway
```

## Teşhis

Nginx logs ve network config.

---

# TROUBLESHOOTING 5 — Database Not Ready

## Problem

Backend PostgreSQL hazır olmadan başlar.

## Belirti

Startup sırasında connection error.

## Çözüm

Health check + dependency readiness stratejisi.

---

# TROUBLESHOOTING 6 — Environment Misconfiguration

## Problem

Environment variable yanlış veya eksik.

## Örnek

```text
POSTGRES_HOST
```

yanlış value.

## Amaç

Config kaynaklı hataların loglardan teşhis edilmesi.

---

# TROUBLESHOOTING 7 — Prometheus Target Down / Grafana No Data

## Problem

Prometheus scrape target'ında yanlış backend service name, port veya metrics path kullanılmıştır.

## Belirti

- Prometheus `Status > Targets` ekranında `fullstack-ops-api` target `DOWN` görünür.
- `up{job="fullstack-ops-api"}` değeri `0` olur.
- Grafana panelleri `No data` gösterebilir.

## Teşhis

- `docker compose ps`
- `docker compose logs prometheus`
- Prometheus target ekranındaki son scrape hatası
- `docker network inspect`
- Prometheus container'ından backend service name ve `/metrics` erişimi
- Grafana data source health kontrolü

## Öğrenilecek Nokta

Grafana'da veri görülmemesi her zaman Grafana sorunu değildir. Veri üretimi, scrape, storage, data source ve PromQL zinciri sırayla kontrol edilmelidir.

## Çözüm

Gerçek backend service name, internal port ve metrics path ile `prometheus.yml` düzeltilir. Prometheus config'i yeniden yüklenir veya servis yeniden başlatılır; target'ın tekrar `UP` ve dashboard'un tekrar veri gösterdiği doğrulanır.

---

# 12. Dokümantasyon Standardı

Her lab README aşağıdaki yapıyı takip etmelidir.

```markdown
# Lab Name

## Goal

## What You Will Learn

## Architecture

## Prerequisites

## Step 1

## Step 2

## Verification

## Break It

## Diagnose It

## Fix It

## What Happened?

## Key Concepts

## Interview Questions

## Exercises
```

---

# 13. Ana README Gereksinimleri

Root `README.md` profesyonel, kısa ve kolay taranabilir olmalıdır.

Ana README bir ders kitabına dönüşmemelidir.

İçermesi gerekenler:

## Başlık

```text
FullStack Ops Lab
Full-Stack Docker, Infrastructure & Observability Lab
```

## Kısa Açıklama

2-4 paragraf.

## Architecture Diagram

ASCII veya Mermaid.

## Tech Stack

- .NET
- React
- TypeScript
- PostgreSQL
- Redis
- Nginx
- Docker
- Docker Compose
- Prometheus
- Grafana
- GitHub Actions

## Features

- full-stack containerization
- multi-stage builds
- persistent PostgreSQL
- Redis caching
- isolated networking
- Nginx reverse proxy
- health checks
- Prometheus metrics
- provisioned Grafana dashboard
- CI
- troubleshooting labs

## Quick Start

```bash
git clone ...
cd fullstack-ops-lab
```

İlk kurulumda `.env`, external PostgreSQL volume'u ve mevcut migration için açık hazırlık rehberi izlenmelidir. Hazırlık tamamlandıktan sonra normal başlatma:

```bash
docker compose up --build -d
```

## Service URLs

Gerçek portlar final config'e göre yazılmalıdır.

## Repository Structure

Kısa tree.

## Labs

Her lab'e bağlantı.

## Troubleshooting

Senaryolara bağlantı.

## CI Badge

GitHub Actions hazır olduğunda.

## Screenshots

Gerekirse:

- frontend
- Swagger
- Docker Desktop containers
- Prometheus target status
- Grafana dashboard
- GitHub Actions success

## Learning Outcomes

Ölçülebilir ve sade.

---

# 14. Kod Kalitesi Kuralları

## Backend

- Gereksiz abstraction oluşturma.
- Endpoint'ler okunabilir olsun.
- Async API kullan.
- Exception handling mantıklı olsun.
- Connection string kod içine gömülmesin.
- Secret commit edilmesin.
- EF Core migration'ları repository'de tutulabilir.

## Frontend

- TypeScript kullanılmalıdır.
- API URL mümkün olduğunca environment/config üzerinden yönetilmelidir.
- Component'ler makul seviyede bölünmelidir.
- Redux gibi ağır state management zorunlu değildir.

## Docker

- `latest` tag'e körü körüne bağımlı kalma.
- Resmi image'ler tercih et.
- `.dockerignore` kullan.
- Multi-stage build kullan.
- Gereksiz port expose etme.
- Development secret commit etme.
- Container içinde gereksiz root kullanımından kaçın.

---

# 15. Güvenlik ve Production Bilinci

Bu proje production-ready sistem olduğunu iddia etmemelidir.

Ancak production bilinci göstermelidir.

Ele alınabilecek konular:

- non-root container
- secrets
- minimal images
- health checks
- internal networking
- yalnızca gerekli portların publish edilmesi
- HTTPS'in production'da gerekli olduğu
- database'in doğrudan internete açılmaması

Ancak:

- Kubernetes
- service mesh
- Vault
- merkezi log toplama platformları

ilk versiyon için gerekli değildir.

---

# 16. Port Mapping Stratejisi

Development sırasında olası portlar:

```text
Nginx      -> 8080
Backend    -> gerekirse debug için ayrı port
Prometheus -> 9090 (yalnızca local development)
Grafana    -> 3000 (yalnızca local development)
PostgreSQL -> tercihen sadece internal network
Redis      -> tercihen sadece internal network
```

Final kullanıcı trafiği mümkünse yalnızca Nginx üzerinden geçmelidir.

Bu konu AI tarafından açıklanmalıdır.

---

# 17. Docker Network Stratejisi

En az bir custom network kullanılmalıdır.

Örnek:

```text
fullstack-ops-network
```

Servisler:

```text
frontend
api
postgres
redis
prometheus
grafana
```

mimariye göre aynı veya ayrılmış network'lerde olabilir.

İleri seviye opsiyon olarak:

```text
frontend-network
backend-network
```

ayrımı tartışılabilir.

Ancak ilk sürüm gereksiz karmaşıklaştırılmamalıdır.

---

# 18. Persistence Stratejisi

PostgreSQL:

Named volume kullanmalıdır.

Örnek:

```text
postgres_data
```

Redis:

Application cache olduğu için persistence zorunlu değildir.

Prometheus:

Öğrenme oturumları arasında metriklerin korunması için `prometheus_data` named volume kullanılmalıdır.

Grafana:

Dashboard ve data source tanımları dosyadan provision edilmelidir. İstenirse çalışma verisi için `grafana_data` named volume kullanılabilir.

Bu fark özellikle açıklanmalıdır.

Frontend/backend source bind mount yalnızca development workflow gerekiyorsa kullanılmalıdır.

---

# 19. Database Migration Stratejisi

EF Core migration kullanılmalıdır.

Migration yaklaşımı dokümante edilmelidir.

Örneğin:

```bash
dotnet ef migrations add InitialCreate
dotnet ef database update
```

Container environment'ta migration'ın:

- manuel,
- startup sırasında,
- ayrı migration container'ıyla

çalıştırılabileceği açıklanabilir.

İlk sürümde en sade ve anlaşılır yöntem seçilmelidir.

Kabul edilen final tasarımda ilk kurulum, repository'deki mevcut `InitialCreate` migration'ından SQL üretip incelemeyi ve PostgreSQL'e açıkça uygulamayı içerir. API startup'ına otomatik migration eklenmesi gerekmez; normal `compose up` migration uygulamaz.

---

# 20. Redis Implementation Detayları

Redis abstraction mümkün olduğunca basit tutulmalıdır.

Örnek service:

```text
ICacheService
RedisCacheService
```

Ancak gereksiz generic cache framework oluşturulmamalıdır.

Minimum operasyonlar:

```text
Get
Set
Remove
```

JSON serialization kullanılabilir.

Loglar:

```text
CACHE HIT
CACHE MISS
CACHE INVALIDATED
```

göstermelidir.

TTL config'den okunmalıdır.

---

# 21. Health Check Detayları

Health endpoint ideal olarak:

```http
GET /health
```

döndürmelidir.

Geliştirme ilerledikçe:

```text
API
PostgreSQL
Redis
```

durumları kontrol edilebilir.

Health check başarısız olduğunda Docker status üzerinden gözlemlenebilmelidir.

---

# 22. Testing Stratejisi

Bu proje test framework gösterisi değildir.

Ancak temel testler bulunmalıdır.

## Backend

En az:

- service veya endpoint için birkaç unit/integration test
- cache behavior için test düşünülebilir

## CI

Testler otomatik çalışmalıdır.

## Smoke Test

Docker Compose ayağa kaldırıldıktan sonra:

```http
GET /health
```

endpoint'i kontrol edilebilir.

---

# 23. Git Stratejisi

Commit'ler öğrenme sürecini gösterecek şekilde anlamlı olmalıdır.

Örnek:

```text
feat: add initial task API
feat: containerize backend with Docker
refactor: convert backend Dockerfile to multi-stage build
feat: add postgres container
feat: persist postgres data with named volume
feat: add redis task cache
feat: configure nginx reverse proxy
feat: orchestrate services with docker compose
feat: add health checks
feat: expose application metrics for prometheus
feat: provision prometheus and grafana monitoring
docs: add monitoring troubleshooting lab
ci: add GitHub Actions build workflow
docs: add networking troubleshooting lab
```

AI tek devasa commit yerine anlamlı checkpoint'ler önermelidir.

---

# 24. Branch Kullanımı

Zorunlu değildir.

Tek geliştirici öğrenme projesi olduğu için:

```text
main
```

yeterli olabilir.

İstenirse modül bazlı branch:

```text
feature/redis-cache
feature/nginx
```

kullanılabilir.

Ama gereksiz Git karmaşıklığı oluşturulmamalıdır.

---

# 25. Her Modül İçin Definition of Done

Bir modül tamamlanmış sayılmadan önce:

- Kod çalışıyor mu?
- Senaryo gerçekten test edildi mi?
- Hata senaryosu varsa yeniden üretildi mi?
- Çözüm doğrulandı mı?
- README güncellendi mi?
- Kullanılan komutlar açıklandı mı?
- “Neden?” sorusu cevaplandı mı?
- Bu modül metrik üretiyorsa gerçek değerler ve dashboard sorguları doğrulandı mı?
- Interview questions eklendi mi?
- Git commit önerildi mi?

---

# 26. AI'nin Her Modül Sonunda Vermesi Gereken Çıktı

Her modül sonunda AI şu formatta özet vermelidir:

```markdown
## Completed

- ...

## What You Learned

- ...

## Important Commands

- ...

## Files Changed

- ...

## Verification

- ...

## Interview Questions

1. ...
2. ...
3. ...

## Mini Exercise

...
```

---

# 27. AI'nin Yapmaması Gerekenler

AI aşağıdakileri yapmamalıdır:

- Projenin tamamını tek promptta bitirmeye çalışma.
- Açıklama yapmadan dosyaları topluca değiştirme.
- Her sorunu yeni bir kütüphane ekleyerek çözme.
- Gereksiz design pattern ekleme.
- Kubernetes'i erkenden projeye dahil etme.
- Microservices mimarisine zorla geçme.
- PostgreSQL/Redis portlarını sebepsiz yere public expose etme.
- Secret'ları source control'e ekleme.
- Hataları gizleyip sadece “düzeltildi” deme.
- Kopyalanan Dockerfile'ları anlamadan kullanma.
- README'yi pazarlama metnine dönüştürme.
- Gerçek olmayan benchmark/image-size sonucu yazma.

---

# 28. Opsiyonel Advanced Labs

Ana proje tamamen bittikten sonra aşağıdaki modüller eklenebilir.

Bunlar MVP'nin parçası değildir.

---

## Advanced Lab A — RabbitMQ

Senaryo:

```text
User creates task
      |
      v
.NET API
      |
      v
RabbitMQ
      |
      v
Worker
      |
      v
Activity log
```

Amaç:

- message broker
- producer
- consumer
- async processing

---

## Advanced Lab B — Hangfire

Senaryo:

Tamamlanmamış task'lar için periyodik reminder job.

Amaç:

- background jobs
- recurring jobs
- persistent jobs

---

## Advanced Lab C — SignalR

Senaryo:

Bir task değiştiğinde açık tarayıcıların gerçek zamanlı güncellenmesi.

Amaç:

- WebSocket
- realtime communication

---

## Advanced Lab D — Container Registry

GitHub Actions ile Docker image:

```text
ghcr.io
```

üzerine push.

---

## Advanced Lab E — Deployment

Basit bir cloud/VPS ortamında:

```text
docker compose pull
docker compose up -d
```

ile deployment.

Bu aşamada:

- HTTPS
- domain
- environment secrets
- firewall

konuları ele alınabilir.

---

# 29. Kapsam Dışı Konular

İlk sürümde aşağıdakiler kapsam dışıdır:

- Kubernetes
- Terraform
- Helm
- Service Mesh
- RabbitMQ
- Kafka
- ELK
- Alertmanager ve production alert routing
- distributed tracing
- microservices
- authentication
- authorization
- complex domain logic

Bunlar ileride ayrı lab olarak eklenebilir.

---

# 30. Başarı Kriterleri

Proje tamamlandığında aşağıdakilerin tamamı sağlanmalıdır.

## Application

- React frontend çalışıyor.
- .NET API çalışıyor.
- CRUD işlemleri çalışıyor.

## PostgreSQL

- API PostgreSQL kullanıyor.
- Named volume ile data persistence sağlanıyor.

## Redis

- GET endpoint cache kullanıyor.
- Hit/miss gözlemlenebiliyor.
- Mutation sonrası invalidation çalışıyor.

## Docker

- Backend containerized.
- Frontend containerized.
- Multi-stage builds mevcut.
- `.dockerignore` mevcut.
- Custom network kullanılıyor.

## Nginx

- Uygulama frontend/API trafiği için tek giriş noktası; Nginx frontend container'ında çalışır, ayrı nginx servisi gerekmez. Prometheus/Grafana'nın localhost arayüzleri bu uygulama routing'inden ayrıdır.
- Frontend ve API routing çalışıyor.

## Compose

Final servisler `frontend`, `api`, `postgres`, `redis`, `prometheus`, `grafana` olmak üzere altıdır; `api` backend rolünü karşılar. İlk kurulumda `.env`, external PostgreSQL volume'u ve mevcut migration hazırlığı açıkça uygulanıp doğrulanır. Bu hazırlığı tamamlanmış ortamda:

```bash
docker compose up --build -d
```

ile tüm sistem ayağa kalkıyor. Hazırlıksız clone/env/up ile sıfırdan kurulum iddia edilmiyor.

## Health

- Health checks mevcut.
- Sistem readiness davranışı dokümante edilmiş.

## Configuration

- `.env.example` mevcut.
- Secret repository'de yok.

## Observability

- Backend `/metrics` endpoint'i internal network'te çalışıyor.
- Prometheus backend target'ını başarıyla scrape ediyor.
- Prometheus verisi named volume ile saklanıyor.
- Grafana Prometheus data source'u otomatik provision ediliyor.
- Grafana dashboard'u otomatik yükleniyor.
- HTTP ve cache metrikleri gerçek trafikle doğrulanıyor.
- Monitoring troubleshooting senaryosu tamamlanmış.

## CI

- GitHub Actions workflow başarılı.
- Backend build/test çalışıyor.
- Frontend build çalışıyor.
- Docker image build doğrulanıyor.

## Documentation

- Ana README tamam.
- Lab README'leri tamam.
- Troubleshooting senaryoları tamam.
- Architecture dokümanı mevcut.

---

# 31. Final Demo Senaryosu

Proje tamamlandıktan sonra aşağıdaki demo baştan sona çalıştırılmalıdır.

## 1

Repository clone:

```bash
git clone <repo-url>
cd fullstack-ops-lab
```

## 2

Environment:

```bash
if [ ! -e .env ]; then cp .env.example .env; fi
```

Windows için uygun alternatif komut dokümante edilmelidir.

Mevcut `.env` dosyası ezilmemeli; placeholder'lar yerel olarak doldurulmalı ve gerçek credential Git'e eklenmemelidir. Compose user-secrets'ı otomatik okumaz.

Start adımından önce [ilk kurulum rehberi](labs/09-environment-configuration/README.md#13-temiz-bilgisayar-kurulum-rehberi) izlenmelidir:

- External `fullstack-ops-postgres-data` volume'unun varlığı kontrol edilir; yalnız yoksa hazırlanır. Mevcut veri otomatik sıfırlanmaz.
- Preflight/secret kontrolleri çalıştırılır; önce yalnız PostgreSQL başlatılıp bağlantı kabul ettiği doğrulanır.
- Mevcut `InitialCreate` migration'ından idempotent SQL üretilir, incelenir ve açıkça uygulanır; `tasks` ve `__EFMigrationsHistory` doğrulanır. Yeni migration oluşturulmaz.
- Yeni volume'un ilk credential hazırlığı ile initialized volume'daki mevcut rol/parola uyumu ayrılır.

Temiz clone final demosu bu belgelenmiş ilk kurulumu da doğrulamalıdır; sıfır hazırlıkla clone/env/up demosu değildir.

## 3

Hazırlanmış ortamı başlatma (ilk kurulumun yerine geçmez):

```bash
docker compose up --build -d
```

## 4

Status:

```bash
docker compose ps
```

Altı servisin (`frontend`, `api`, `postgres`, `redis`, `prometheus`, `grafana`):

```text
running / healthy
```

olduğu doğrulanır.

## 5

Browser üzerinden frontend açılır.

## 6

Yeni task oluşturulur.

## 7

Task listesi çağrılır.

Backend log:

```text
CACHE MISS
```

## 8

Tekrar task listesi çağrılır.

Backend log:

```text
CACHE HIT
```

## 9

Task güncellenir.

Backend log:

```text
CACHE INVALIDATED
```

## 10

PostgreSQL container yeniden oluşturulur.

Data korunmalıdır.

## 11

Nginx üzerinden API request başarılıdır.

## 12

Prometheus target ekranında backend `UP` görünür.

## 13

Grafana dashboard'unda request, error, duration ve cache panelleri veri gösterir.

## 14

Prometheus target ayarı bilinçli olarak bozulur; `DOWN` ve `No data` belirtileri gözlemlenir, ardından sorun giderilir.

## 15

GitHub Actions başarılı görünür.

---

# 32. Mülakat İçin Öğrenilmesi Gereken Sorular

Proje tamamlandığında geliştirici aşağıdaki sorulara kendi kelimeleriyle cevap verebilmelidir.

## Docker

1. Docker image nedir?
2. Container nedir?
3. Image ile container arasındaki fark nedir?
4. Dockerfile nedir?
5. Multi-stage build neden kullanılır?
6. `.dockerignore` neden önemlidir?
7. Docker layer caching nasıl çalışır?
8. `EXPOSE` ile `ports` aynı şey midir?
9. Container neden ephemeral kabul edilir?

## Networking

10. Container içindeki localhost neyi ifade eder?
11. İki container nasıl haberleşir?
12. Custom bridge network neden kullanılır?
13. Docker DNS nasıl çalışır?
14. Port publish etmek ile containerlar arası iletişim arasındaki fark nedir?

## Volume

15. Docker volume neden kullanılır?
16. Named volume ile bind mount arasındaki fark nedir?
17. `docker compose down -v` ne yapar?

## PostgreSQL

18. Database container silinirse veriler neden kaybolabilir?
19. Volume bu problemi nasıl çözer?

## Redis

20. Cache hit nedir?
21. Cache miss nedir?
22. TTL nedir?
23. Cache invalidation neden zordur?
24. Redis neden ana database yerine cache olarak kullanılıyor?

## Nginx

25. Reverse proxy nedir?
26. Nginx bu projede ne işe yarıyor?
27. `502 Bad Gateway` hangi durumlarda oluşabilir?

## Compose

28. Docker Compose ne çözer?
29. `depends_on` ne yapar?
30. `depends_on` neden readiness garantisi değildir?

## Health Check

31. Running container ile healthy container arasındaki fark nedir?

## Observability

32. Log, metric ve trace arasındaki fark nedir?
33. Prometheus bu projede hangi görevi üstleniyor?
34. Prometheus pull modeli nasıl çalışır?
35. `scrape_interval` neyi belirler?
36. Counter ile gauge arasındaki fark nedir?
37. `rate()` hangi tür metriklerde ve neden kullanılır?
38. Grafana bu projede veriyi nereden alır?
39. Grafana provisioning neden faydalıdır?
40. Metric label cardinality nedir ve neden risklidir?
41. Prometheus target `DOWN` ise hangi sırayla teşhis yaparsın?
42. Grafana `No data` gösterdiğinde hangi katmanları kontrol edersin?

## CI/CD

43. CI nedir?
44. GitHub Actions bu projede ne yapıyor?
45. Docker image neden pipeline içinde build edilir?
46. Smoke test nedir?

---

# 33. Öğrenme Metodu

Her modül şu döngüyü takip etmelidir:

```text
Understand
   |
   v
Build
   |
   v
Run
   |
   v
Break
   |
   v
Observe
   |
   v
Diagnose
   |
   v
Fix
   |
   v
Explain
```

Bu proje için en önemli prensip budur.

---

# 34. AI ile Çalışma Şablonu

Yeni bir modüle başlarken AI aşağıdaki yaklaşımı kullanmalıdır.

Örnek:

```text
We are now starting Module 4: Docker Networking.

Before changing any code:

1. Explain the goal of this module.
2. Explain the architecture before and after this module.
3. Show which files will change.
4. Implement the smallest working version.
5. Give the commands I should run.
6. Wait for or inspect the result.
7. Intentionally reproduce the planned failure scenario.
8. Diagnose the failure.
9. Fix it.
10. Update the module README.
11. Summarize what I learned.
12. Give me interview questions and one exercise.
```

---

# 35. İlk Prompt Olarak Kullanılabilecek Talimat

Aşağıdaki metin, bu doküman AI'ye verildikten sonra başlangıç prompt'u olarak kullanılabilir:

```text
Bu PROJECT_SPEC.md dosyasını projenin ana teknik şartnamesi olarak kabul et.

Ben junior full-stack geliştiriciyim ve bu projeyi yalnızca ortaya çalışan bir ürün çıkarmak için değil,
Docker ve altyapı konularını gerçekten öğrenmek için geliştiriyorum.

Projeyi benim yerime tek seferde tamamlamanı istemiyorum.

Her modülü sırayla ilerletmeni, yapacağımız değişikliklerden önce neden yaptığımızı açıklamanı,
kullandığımız Docker komutlarını öğretmeni, önemli mimari kararları anlatmanı ve hata senaryolarını
gerçekten oluşturarak birlikte teşhis etmemizi istiyorum.

Gereksiz abstraction, enterprise pattern veya kapsam dışı teknoloji ekleme.

Bu şartnamedeki sırayı ve hedefleri koru.

Şimdi önce mevcut repository'yi incele.
Ardından yalnızca FAZ 0 için:
- mevcut durumu özetle,
- eksikleri belirle,
- uygulanacak adımları sırala,
- ilk küçük adımı uygula.

Bir sonraki modüle ben ilerlemeden geçme.
```

---

# 36. Son Prensipler

Bu proje bittiğinde amaç:

> “Docker kullanan bir uygulama yaptım.”

demek değildir.

Amaç:

> “Full-stack bir uygulamayı containerize ettim; servisler arası networking'i kurdum, PostgreSQL verisini
> volume ile kalıcı hale getirdim, Redis cache hit/miss ve invalidation davranışını uyguladım, Nginx ile
> reverse proxy kurdum, health checks ile servis readiness problemlerini yönettim, .NET uygulama metriklerini
> Prometheus ile topladım, Grafana dashboard'larıyla görselleştirdim, sistemi Docker Compose ile orkestre ettim,
> failure senaryolarını teşhis ettim ve GitHub Actions ile CI doğrulaması ekledim.”

diyebilecek seviyeye gelmektir.

Projenin değeri kullanılan teknoloji sayısından değil;

- neden kullanıldıklarının anlaşılmasından,
- sistemin nasıl çalıştığının açıklanabilmesinden,
- hata durumlarının teşhis edilebilmesinden

gelmelidir.

---

# 37. Final Checklist

```text
[ ] Baseline .NET + React application works
[ ] Backend Dockerfile created
[ ] Frontend Dockerfile created
[ ] Multi-stage builds implemented
[ ] .dockerignore files created
[ ] PostgreSQL container integrated
[ ] PostgreSQL persistence lab completed
[ ] Named volume configured
[ ] Custom Docker network configured
[ ] Wrong localhost lab completed
[ ] Redis integrated
[ ] Cache hit/miss implemented
[ ] Cache TTL implemented
[ ] Cache invalidation implemented
[ ] Nginx static serving and reverse proxy configured inside frontend
[ ] 502 troubleshooting lab completed
[ ] Six-service Docker Compose configured (frontend, api, postgres, redis, prometheus, grafana)
[ ] Health checks added
[ ] Readiness scenario documented
[ ] .env.example added
[ ] Secrets excluded from Git
[ ] Logs/troubleshooting documentation completed
[ ] Backend /metrics endpoint added
[ ] Low-cardinality custom cache metrics added
[ ] Prometheus service and scrape config added
[ ] Prometheus backend target verified as UP
[ ] Prometheus named volume configured
[ ] Prometheus and Grafana health checks verified
[ ] Grafana service added
[ ] Grafana Prometheus data source provisioned
[ ] Grafana dashboard provisioned from repository
[ ] Request, error, duration and cache panels verified
[ ] Monitoring no-data troubleshooting lab completed
[ ] Backend tests added
[ ] GitHub Actions workflow added
[ ] Docker builds verified in CI
[ ] Main README completed
[ ] Architecture documentation completed
[ ] Command cheat sheet completed
[ ] Troubleshooting labs completed
[ ] First-install .env, external PostgreSQL volume and explicit migration preparation documented and verified
[ ] Prepared environment starts with docker compose up
[ ] Final demo tested from clean clone using documented first-install preparation
```

---

## Project Status

Başlangıç durumu:

```text
Status: Planning
Current Phase: Phase 0
Next Goal: Build and verify the baseline application before Dockerization
```

Bu alan proje ilerledikçe güncellenebilir.

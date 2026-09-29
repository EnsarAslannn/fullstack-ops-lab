# Modül 6 — Nginx Reverse Proxy

## Amaç

React üretim dosyalarını ve Task API'yi tek bir giriş noktasında toplamak. Tarayıcı yalnızca `http://127.0.0.1:18081` adresini kullanır. Nginx statik dosyaları sunar; `/api/` isteklerini aynı Docker ağındaki backend'e iletir. Bu laboratuvarda Docker Compose, TLS veya yeni uygulama özelliği eklenmedi.

## Önceki durum ve çözüm

Vite'ın `vite.config.ts` içindeki `/api` proxy ayarı yalnızca development server çalışırken geçerlidir. Üretim build'i statik HTML, JavaScript ve CSS dosyalarıdır; Vite server image içinde çalışmaz. Önceki `fullstack-ops-frontend:multistage` image'ındaki Nginx'in `/api/` kuralı yoktu: standalone container üzerinde `GET /api/tasks` **404** döndü. API client'ın göreli `/api/tasks` yolu doğruydu; eksik parça üretim yönlendirmesiydi.

`src/frontend/nginx.conf` içindeki `location /` statik dosyaları `/usr/share/nginx/html` dizininden sunar. `try_files $uri $uri/ /index.html` bilinmeyen istemci route'larında SPA giriş dosyasına döner. Daha özel `location /api/`, API isteklerini `http://fullstack-ops-api-proxy:8080` adresine gönderir. Bu ad, `fullstack-ops-proxy-network` adlı kullanıcı tanımlı bridge ağında Docker DNS ile çözülür; sabit container IP'si kullanılmaz.

`proxy_pass http://fullstack-ops-api-proxy:8080;` satırında upstream adresinden sonra `/` veya başka bir URI bulunmaz. Böylece özgün `/api/tasks` yolu backend'e aynen gider. `proxy_pass http://fullstack-ops-api-proxy:8080/;` biçiminde sondaki `/` bir URI belirtir ve `/api/` prefix'ini değiştirerek backend'e `/tasks` gönderebilir. Gerçek POST sonucundaki `Location: /api/tasks/25` ve aynı yol üzerinden GET **200** bu laboratuvarda yolun korunduğunu doğruladı.

`Host` özgün host bilgisini, `X-Real-IP` istemci adresini, `X-Forwarded-For` proxy zincirini, `X-Forwarded-Proto` özgün şemayı taşır. Uygulama şu anda bu başlıklara dayanarak güvenlik kararı vermiyor. `proxy_connect_timeout 3s`, kapalı backend'e bağlanma denemesinin uzun süre asılı kalmasını önler; bu deneyde **504** sonucu verdi. Nginx bir reverse proxy olarak HTTP isteğini iletir; Task listesini kendisi cache'lemez. Cache davranışı backend ile Redis'e aittir.

Frontend Dockerfile'ı Node 24 Alpine build stage ve Nginx stable Alpine runtime stage olarak kaldı. Son stage'e yalnızca `dist` çıktısı ve Nginx config kopyalandı. `EXPOSE 80` image içindeki dinleme portunu belgeler; host'a port açan işlem `docker run -p` komutudur.

## Gerçek çalıştırma komutları

Komutlar repository kökünden çalıştırıldı. PostgreSQL parolası mevcut local user-secrets kaynağından alınıp yalnızca repository dışındaki geçici env dosyasına yazıldı. Aşağıdaki `$temporaryEnvPath` gerçek parola içeren geçici dosyayı temsil eder; örnek diye gerçek connection string verilmez. Bu dosya backend container başladıktan hemen sonra silindi. `docker inspect` içindeki tam `Config.Env` çıktısı parola gösterebileceğinden paylaşılmadı.

```powershell
dotnet restore FullStackOpsLab.slnx
dotnet build FullStackOpsLab.slnx -c Release --no-restore
cd src/frontend
npm ci
npm run build
cd ../..

docker build --progress=plain -t fullstack-ops-api:proxy src/backend/FullStackOpsLab.Api
docker build --progress=plain -t fullstack-ops-frontend:proxy src/frontend
docker network create --driver bridge fullstack-ops-proxy-network
docker run -d --name fullstack-ops-postgres-proxy `
  --network fullstack-ops-proxy-network `
  --mount type=volume,source=fullstack-ops-postgres-data,target=/var/lib/postgresql `
  postgres:18-alpine
docker exec fullstack-ops-postgres-proxy pg_isready -U fullstackops -d fullstackops
docker run -d --name fullstack-ops-redis-proxy `
  --network fullstack-ops-proxy-network `
  --mount type=tmpfs,destination=/data `
  redis:8.2.10-alpine redis-server --save '' --appendonly no
docker exec fullstack-ops-redis-proxy redis-cli PING
docker run -d --name fullstack-ops-api-proxy `
  --network fullstack-ops-proxy-network `
  --env-file $temporaryEnvPath `
  -e ASPNETCORE_ENVIRONMENT=Development `
  fullstack-ops-api:proxy
docker run -d --name fullstack-ops-frontend-proxy `
  --network fullstack-ops-proxy-network `
  -p 127.0.0.1:18081:80 `
  fullstack-ops-frontend:proxy
docker exec fullstack-ops-frontend-proxy nginx -t
```

PostgreSQL ve Redis container'ları host'a publish edilmedi. Backend container'ı da yalnızca ağ içinde `8080` portunda dinledi. `docker ps` çıktısındaki tek host binding `127.0.0.1:18081->80/tcp` idi. Bu localhost laboratuvar erişimi, production TLS veya kimlik doğrulaması anlamına gelmez. `fullstack-ops-postgres-data` named volume'u ve mevcut `InitialCreate` migration'ı kullanıldı; `lab_tasks` kaydı korunurken başlangıç ve bitişte `tasks` sayısı `0` idi.

## Gerçek doğrulama sonuçları

| Kontrol | Sonuç |
| --- | --- |
| Başlangıç Git durumu | Temiz |
| Docker Engine | 29.6.1 |
| Backend Release build | 0 uyarı, 0 hata |
| Frontend `npm ci` | Başarılı; 0 vulnerability |
| Frontend `npm run build` | TypeScript ve Vite başarılı; Vite 8.3.1 |
| İki Docker build | Başarılı; final frontend Nginx, final backend ASP.NET runtime |
| `nginx -t` | Syntax ve yapılandırma başarılı |
| `/`, JavaScript, CSS, favicon | Her biri HTTP 200 |
| SPA fallback `/task-lab/client-route` | HTTP 200, `index.html` |
| API listesi | Nginx üzerinden HTTP 200; başlangıç `[]` |
| CRUD | POST 201 ve `/api/tasks/25` Location; o yolda GET 200; PUT 200; DELETE 204 |
| Validation ve bulunmayan ID | Boş başlık 400; bilinmeyen ID 404 |
| Redis | İlk GET miss ve key oluştu; ikinci GET hit; POST/PUT/DELETE key'i sildi; sonraki GET yeniden oluşturdu |
| Browser | Boş liste, oluşturma, sayfa yenileme, tamamlama, silme, hata ve retry başarılı |
| Mobil 390 px | Belge scroll genişliği 390 px; yatay taşma yok |
| Browser loading | Retry isteği bekletildiğinde loading metni göründü, oluşturma butonu disabled idi |
| Browser console/network | Beklenmeyen console veya başarısız network hatası yok; kesinti deneyindeki beklenen API 504 ayrı kaydedildi |
| Runtime araçları | Frontend final image'da Node, npm, kaynak ve `node_modules` yok; backend final image'da SDK listesi boş |

Backend durdurulunca `/` yine **200**, `/api/tasks` 3 saniye sonra **504 Gateway Timeout** döndü. Nginx error logunda `upstream timed out ... while connecting to upstream` görüldü. Backend yeniden başlatılıp hazır olunca aynı Nginx adresinden istek **200** oldu. İlk teşhiste timeout olmadan 15 saniyelik istemci sınırı doldu ve Nginx erişim logunda **499** görüldü; bu, istemcinin yanıt beklemeden bağlantıyı kapatmasıydı. Kısa `proxy_connect_timeout` bu sorunu laboratuvarda görünür bir HTTP yanıtına dönüştürdü.

Şartnamedeki yanlış hostname teşhisi için host portu açılmayan ayrı, geçici Nginx diagnostic container'ında `fullstack-ops-api-proxy-typo` upstream adı kullanıldı. İçeriden yapılan GET **502 Bad Gateway** döndü; error log `could not be resolved (Host not found)` dedi. Diagnostic container ve geçici config silindi; takip edilen Nginx config doğru Docker DNS adını kullanır. Yanlış hostname ile backend kesintisi farklı arızalardır: ilki DNS çözümleme **502**, bu ağ deneyindeki durmuş backend ise bağlantı timeout **504** üretti.

## Teşhis ve güvenli temizlik

Nginx **502** veya **504** için önce `docker logs fullstack-ops-frontend-proxy`, sonra ağ üyeliği (`docker network inspect fullstack-ops-proxy-network`), backend adı ve portu, son olarak `proxy_pass` yolu kontrol edilir. Statik dosyalar 200 iken API başarısızsa sorun React build'inden çok upstream erişiminde olabilir. Nginx loglarında erişim ve hata satırları incelendi. Backend logları `[CACHE MISS]`, `[CACHE HIT]` ve `[CACHE INVALIDATED]` akışını gösterdi. Backend başlangıcında isteğe bağlı `libgssapi_krb5.so.2` yükleme uyarısı görüldü; gerçek PostgreSQL ve CRUD istekleri başarılıydı. Bu laboratuvarda runtime image değiştirilmedi.

Deney sonundaki güvenli kaldırma sırası (yalnızca bu isimler):

```powershell
docker stop fullstack-ops-frontend-proxy fullstack-ops-api-proxy fullstack-ops-redis-proxy fullstack-ops-postgres-proxy
docker rm fullstack-ops-frontend-proxy fullstack-ops-api-proxy fullstack-ops-redis-proxy fullstack-ops-postgres-proxy
docker network rm fullstack-ops-proxy-network
```

Test Task kaydı API üzerinden silindi, Redis test key'i `DEL` ile kaldırıldı ve repository dışındaki geçici env dosyası silindi. `fullstack-ops-postgres-data` named volume'u, migration ve Module 3B `lab_tasks` kaydı korunur. Proje image'ları local sistemde kalabilir. `docker system prune`, `docker volume prune` veya ilişkisiz kaynağı silme kullanılmaz.

## Kendi kendine kontrol

1. Vite development proxy neden üretim image'ında yoktur?
2. `location /api/` ile `location /` hangi istekleri karşılar?
3. `proxy_pass` sonuna `/` eklemek backend'e giden URI'yi nasıl değiştirebilir?
4. Browser neden backend container portunu bilmek zorunda değildir?
5. Yanlış hostname kaynaklı 502 ile durmuş backend kaynaklı 504 nasıl ayırt edilir?

**Alıştırma:** Nginx logunu ve network inspect çıktısını kullanarak backend container adını, bağlı ağı ve yalnızca localhost'a yayınlanan host portunu belirle. Kaynakları değiştirmeden `/api/tasks` yolunun backend'e nasıl ulaştığını kendi sözlerinle çiz.

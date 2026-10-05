# Scenario

**Troubleshooting 4 — Nginx 502.** Yanlış upstream servis adı nedeniyle Nginx'in API'ye ulaşamamasını log ve network bilgisiyle teşhis etmek.

**Completed — zorunlu kapsam mevcut gerçek kanıtlarla karşılandı (5 Ekim 2026 dokümantasyon incelemesi).** Module 6'nın yanlış hostname/502/DNS logu ve doğru routing kanıtları yeniden kullanıldı. Güncel `api:8080` hedefinin olumlu runtime kanıtı Module 7'de bulunur. Bu görevde yeni HTTP isteği, arıza deneyi, build veya servis lifecycle işlemi yapılmadı; geçmiş sonuçlar bugün tekrar ölçülmüş gibi sunulmaz.

Kaynaklar:

- [Şartname](../../PROJECT_SPEC.md): bölüm 11, Troubleshooting 4 ve dokuz başlıklı senaryo şablonu.
- [Module 6 — gerçek doğrulama sonuçları](../../labs/06-nginx/README.md#gerçek-doğrulama-sonuçları): yanlış upstream 502, DNS error logu, ayrı kesintide 504 ve gerçek API/CRUD sonuçları.
- [Module 6 — teşhis ve güvenli temizlik](../../labs/06-nginx/README.md#teşhis-ve-güvenli-temizlik): network/log incelemesi ve diagnostic kaynakların kaldırılması.
- [Module 7 — runtime kabulü](../../labs/07-docker-compose/README.md#11-gerçek-runtime-acceptance--30-eylül-2026): Compose `api:8080` üzerinden gerçek `/api/tasks` GET/POST ve CRUD.
- [Güncel Nginx config](../../src/frontend/nginx.conf), [Compose](../../compose.yaml), [frontend Dockerfile](../../src/frontend/Dockerfile).

## Symptoms

Module 6'nın ayrı, geçici diagnostic Nginx container'ında yanlış upstream adı **`fullstack-ops-api-proxy-typo`** kullanıldı. İçeriden yapılan gerçek GET **502 Bad Gateway** döndürdü. Nginx error logunda **`could not be resolved (Host not found)`** görüldü. Bu, yanlış adın DNS üzerinden çözülememesinin kanıtıdır; o eski diagnostic container güncel Compose frontend'i değildir.

Statik frontend ve API erişimi farklı akışlardır:

- `/`, JavaScript ve CSS Nginx'in yerel `/usr/share/nginx/html` dosyalarından sunulur.
- `/api/` istekleri backend'e proxy edilir; DNS, ağ, container portu ve backend yanıtına ihtiyaç duyar.
- Dolayısıyla frontend'in açılması API erişimini kanıtlamaz. Module 6'nın **backend kesintisi** deneyinde `/` **200** kalırken `/api/tasks` **504** oldu. Bu ölçüm ayrı yanlış-hostname 502 deneyiyle birleştirilmez.

## Expected Behaviour

Güncel kullanıcı giriş noktası `http://127.0.0.1:18081` adresindeki `frontend` servisidir; aynı container statik React dosyalarını ve Nginx reverse proxy'yi barındırır. Nginx, `location /api/` için **`proxy_pass http://api:8080;`** kullanır. `frontend` ve `api` Compose `app` ağına bağlıdır. `8080` API'nin container portudur; frontend host portu 18081 değildir. API host'a publish edilmez.

`proxy_pass` upstream adresinden sonra URI `/` içermez; `/api/tasks` backend'e aynı yol olarak gider. Vite development proxy üretim Nginx routing'inin yerine geçmez. `location /` içindeki SPA fallback ise istemci route'larına `index.html` döndürür; başarılı SPA yanıtını API JSON başarısı diye yorumlama.

Module 6'nın tarihsel doğru hedefi `fullstack-ops-api-proxy:8080`, ağı `fullstack-ops-proxy-network` idi. Güncel Compose karşılığı **`api:8080`**, proje ağı **`fullstack-ops-lab_app`**'dır. Tarihsel container adını güncel Compose config'ine geri yazmak düzeltme değildir.

## Investigation

1. **Statik dosya mı API isteği mi başarısız?** İstenen yolu, HTTP status ve response türünü ayır. `/` 200 tek başına `/api/tasks` başarısı değildir.
2. **Nginx access/error logları ne söylüyor?** Access logda ilgili istek/status, error logda upstream adı ve `could not be resolved`, bağlantı hatası veya `upstream timed out ... while connecting to upstream` gibi neden bilgisi aranır. Yalnız status'tan kök neden çıkarılmaz.
3. **Upstream doğru servis adı mı?** Takip edilen config ve runtime'da yüklenen Nginx config'i kontrol et; doğru hedef `api:8080`. Güncel frontend Dockerfile `nginx.conf` dosyasını image içine kopyalar; repository dosyasını değiştirmek mevcut container'ın config'ini kendiliğinden güncellemez.
4. **Servisler aynı ağda mı?** Frontend/API state, Docker network üyeliği ve DNS alias'ları kontrol edilir. Container IP'leri geçicidir; kalıcı upstream için servis adı kullanılır. `localhost` frontend container'ının kendisidir.
5. **Port ve backend readiness doğru mu?** API startup logları, container portu 8080 ve readiness değerlendirilir. Frontend Docker healthcheck'i `/` kontrol eder; healthy frontend tüm API iş akışlarını kanıtlamaz.
6. **Düzeltme gerçek API isteğinde çalışıyor mu?** Nginx üzerinden `/api/tasks` JSON yanıtı veya bilinen kayda tekil GET, status ve gerektiğinde alanlarla doğrulanır. Liste GET cache oluşturabilir; sırf tanı için mevcut Redis key'lerini silme. Bu görev mevcut kabul kanıtlarını kullandı, veri/cache trafiği üretmedi.

Loglar query string veya kullanıcı bilgisi içerebilir. Raw logları, `nginx -T` çıktısını veya tam inspect çıktısını kontrolsüz paylaşma; yalnız gerekli güvenli host/route/status/hata bulgularını raporla. Container environment ve tamamlanmış connection string gösterilmez.

## Useful Commands

Aşağıdakiler **tanı örnekleridir**; bu dokümantasyon görevinde yalnız `docker ps -a` ve Compose `ps` ile başlangıç/bitiş durumları okundu. Diğer komutlar bugün yeniden çalıştırılmış sayılmaz. Native exit code'u kontrol et; başarısız komutu başarılı boş sonuç sayma.

```powershell
docker compose --env-file .env ps -a
$frontendId = docker compose --env-file .env ps -q frontend
$apiId = docker compose --env-file .env ps -q api
docker inspect --format '{{json .NetworkSettings.Networks}}' $frontendId $apiId
docker network inspect fullstack-ops-lab_app --format '{{json .Containers}}'
docker compose --env-file .env exec -T frontend nginx -t
```

Log incelemesi için `docker compose --env-file .env logs --tail 50 frontend` ve `logs --tail 50 api` kullanılır; çıktı paylaşılmadan önce hassas içerik açısından incelenir. Yüklenen config gerektiğinde `exec -T frontend nginx -T` ile incelenir; bunun çıktısı da güvenli alanlara sınırlandırılır.

Gerçek API doğrulaması için örnek (bu görevde çalıştırılmadı):

```powershell
curl.exe --silent --show-error --max-time 15 --output NUL --write-out '%{http_code}' http://127.0.0.1:18081/
curl.exe --silent --show-error --max-time 15 --include http://127.0.0.1:18081/api/tasks
```

İkinci yanıt mevcut Task verilerini içerebilir; public çıktılara kopyalama. SQL/veri okumasını cache hit'ten ayrıca ayır; Nginx routing kabulü bütün DB/cache sağlık kriterlerinin yerine geçmez.

## Root Cause

| Geçmiş deney | Gerçek belirti | Kanıtlanan neden |
| --- | --- | --- |
| Module 6: yanlış `fullstack-ops-api-proxy-typo` upstream | HTTP502; `could not be resolved (Host not found)` | Diagnostic Nginx'in yanlış upstream adını çözememesi. |
| Module 6: backend durduruldu | Statik `/`200; API504; `upstream timed out ... while connecting to upstream` | Bu ağ/timeout koşullarında upstream bağlantısının zaman aşımı. |
| Module 6: ilk uzun bekleme | İstemci 15 saniyede vazgeçti; access log499 | İstemci yanıt gelmeden bağlantıyı kapattı; API500 veya DNS502 diye sunulmaz. |

**502 her zaman DNS hatası, 504 her zaman durmuş backend demek değildir.** Buradaki nedenler loglarla belirlenen iki somut deneye aittir. Başka 502'lerde bağlantı reddi veya geçersiz upstream yanıtı; başka 504'lerde yavaş bağlantı/yanıt gibi nedenler ayrıca araştırılmalıdır. Bu diğer arızalar burada deneylenmedi. Aynı şekilde mevcut literal `proxy_pass` satırındaki hostname'i değiştirmekle tarihsel diagnostic deneyin her startup/request davranışının birebir tekrar edeceği iddia edilmez.

## Fix

Yanlış upstream yerine doğru servis adı ve container portunu kullan; Nginx ile API'nin aynı Docker ağına bağlı olduğunu doğrula. Güncel proje için doğru satır:

```nginx
proxy_pass http://api:8080;
```

Config syntax kontrolü tek başına backend erişimini kanıtlamaz. Gerçek Nginx üzerinden API isteği gereklidir. Module 6'nın doğru yapılandırmasında liste GET200, POST201 ve dönen `/api/tasks/25` yolundan GET200/PUT200/DELETE204 vardı. Backend kesintisi giderildikten sonra aynı Nginx adresinden API isteği yeniden **200** oldu. Module 7'de güncel Compose adıyla `/api/tasks` GET200 ve POST201 (`Location: /api/tasks/27`) gerçek routing'i doğruladı.

Bu kanıtlar doğru routing'in çalıştığını gösterir. Yanlış hostname diagnostic container'ının aynı kimlikle düzeltilip tekrar test edildiği iddia edilmez: o container ve geçici config Module 6 sonunda kaldırıldı. Ana Nginx config'i doğru kaldı. Bu görevde reload/restart/rebuild veya configuration değişikliği gerekmedi.

## Verification

| Şartname / kabul kriteri | Sonuç | Kanıt ve sınır |
| --- | --- | --- |
| Ayrı klasör, dokuz başlık | PASS | Bu README. |
| Yanlış upstream servis adı ve gerçek HTTP502 | PASS — mevcut runtime | Module 6 geçici diagnostic Nginx, `fullstack-ops-api-proxy-typo`, GET502. |
| Nginx logundan DNS teşhisi | PASS — mevcut runtime | Module 6 `could not be resolved (Host not found)` error logu. |
| Ağ/servis adı/container portu kontrolü | PASS — kaynak ve mevcut runtime | Module 6 bridge/DNS/8080 kanıtı; Module 7 Compose ağı/`api:8080`; güncel nginx.conf ve compose.yaml eşleştirmesi. |
| Statik frontend ile upstream API ayrımı | PASS — mevcut runtime | Module 6 normal statik asset200; backend kesintisinde `/`200 ve API504. Yanlış DNS deneyiyle aynı ölçüm diye sunulmaz. |
| Gözlenen 502/504 nedenlerinin ayrımı | PASS — mevcut runtime | DNS hata logu ile upstream connecting-timeout logu farklı; evrensel status→neden kuralı çıkarılmadı. |
| Doğru routing / recovery gerçek API isteği | PASS — mevcut runtime | Module 6 doğru hedefte GET/CRUD ve backend recovery GET200; Module 7 güncel `api:8080` üzerinden GET200/POST201. |
| Bugün güncel Compose'da yeniden yanlış hostname deneyi | NOT VERIFIED — tekrar yapılmadı | Yeni zorunlu kanıt eksik bulunmadı; mevcut deney tekrar edilmedi. |
| Aynı yanlış-hostname diagnostic container'ında config düzeltip recovery | NOT VERIFIED — ek sınır | Böyle bir sıra mevcut kanıt olarak ileri sürülmez; zorunlu doğru routing kanıtı yukarıda ayrı gösterildi. |
| Diğer 502/504 kök nedenleri | NOT VERIFIED — ek kapsam | Kapalı port, geçersiz upstream yanıtı veya yük/yavaşlık için yeni deney yapılmadı. |
| Başlangıç stack'i korunması | PASS — salt okunur durum kontrolü | Başlangıç/bitiş aynı altı running/healthy servis; tüm başlangıç container ID/state bilgileri aynı. Hiçbir Docker kaynağı oluşturulmadı, değiştirilmedi veya kaldırılmadı. |

Bu kabul mevcut Module 6/7 dokümante runtime kanıtlarını ve güncel statik configuration incelemesini kullanır. Ham geçmiş loglar bu görevde yeniden üretilmedi; bu belge yük testi veya production erişilebilirlik garantisi değildir. Yanlış-hostname ve backend-stop senaryoları farklı deneyler olarak tutulur.

Başlangıç Git temizdi. Stack zaten çalışıyordu; yalnız ID/state/health alanları okundu. Görev kapsamında Task/cache kaydı, geçici override, container/network/volume veya secret dosyası oluşturulmadı. `.env`, user-secrets ve veritabanı değiştirilmedi; mevcut cache'e istek/DEL gönderilmedi. Temizlenecek yeni kaynak olmadığından mevcut stack down yapılmadı. Secret kontrolü, belge bağlantıları ve diff check bu dokümantasyon görevinin son kontrolleridir. Commit/push yapılmadı; beşinci senaryoya geçilmedi.

## What We Learned

- Statik frontend'in açılması, proxy edilen API'nin erişilebilir olduğunu kanıtlamaz.
- HTTP status teşhisin başlangıcıdır; Nginx error logu ve network/config bilgisi gerçek nedeni ayırır.
- Container iletişiminde doğru servis adı ve container portu kullanılır: `api:8080`.
- `nginx -t` syntax'ı; gerçek Nginx API isteği routing ve upstream yanıtını doğrular.
- Bu deneyde DNS hatası502, bağlantı timeout'u504 oldu; bunlar bütün arızalar için genellenmez.
- Tarihsel kanıt, güncel statik inceleme ve bugün yapılmayan deney açıkça ayrılmalıdır.

Önerilen commit mesajı: `docs(troubleshooting): document Nginx upstream 502 diagnosis`. Sonraki adım yalnız bu senaryonun commit öncesi incelemesidir; Database Not Ready senaryosuna otomatik geçilmez.

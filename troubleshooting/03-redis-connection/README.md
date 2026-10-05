# Scenario

**Troubleshooting 3 — Redis Connection Failure.** Redis hazır olduğu hâlde yanlış hostname nedeniyle API'nin Redis'e bağlanamamasını teşhis etmek ve doğru hedefte liste/cache davranışının toparlandığını göstermek.

**Completed — zorunlu kapsam PASS, 5 Ekim 2026.** Şartname yanlış hostname **veya** network ister; bu kabul yanlış hostname seçeneğini gerçek runtime ile doğrular. Ayrı network ayrıştırma veya tekrar stop/start deneyi yapılmadı. Backend/frontend, ana Compose, configuration contract ve fail-open davranışı değiştirilmedi.

Kaynaklar:

- [Şartname](../../PROJECT_SPEC.md): bölüm 11, Troubleshooting 3 ve dokuz başlıklı şablon.
- [Module 5](../../labs/05-redis/README.md): mevcut cache-aside, Redis kesintisi ve toparlanma kanıtı.
- [Module 8](../../labs/08-health-checks/README.md): live/ready, Docker health ve aynı API container'ında bağımlılık recovery'si.
- [Module 10](../../labs/10-prometheus-grafana/README.md#health-inspect-ve-kontrollü-kesinti): daha önceki Redis stop/start gözlemleri; bu deneyde yeniden çalıştırılmadı.
- [Compose](../../compose.yaml), [configuration validation](../../src/backend/FullStackOpsLab.Api/Configuration/ApiConfiguration.cs), [Redis readiness](../../src/backend/FullStackOpsLab.Api/Health/RedisReadinessCheck.cs), [API cache akışı](../../src/backend/FullStackOpsLab.Api/Program.cs).

## Symptoms

Redis `PONG` verir ve kendi container'ı healthy görünür; API yanlış Redis hostname'ini kullandığı için liste GET başarısız olur. Yeni deneyin yanlış hedefi `redis-typo-fa9b06d1:6379` idi. API loglarında bu hedef ve Redis connection/timeout exception'ı bulundu; sahte hostname için `redis-cli` exit **1**, `Name has no usable address` döndürdü.

| Ölçüm | Yanlış hostname | Düzeltilmiş hedef |
| --- | --- | --- |
| Redis PING / Docker health | PONG / healthy | PONG / healthy |
| Teşhis API prosesi / Docker health | running / unhealthy | running / healthy |
| `/health` | 200 | Bu aşamada yeniden ölçülmedi; önceki live davranışı değiştirilmedi |
| `/health/live` | 200 | Bu aşamada yeniden ölçülmedi |
| `/health/ready` | 503 | 200 |
| `GET /api/tasks` | 500 | 200, ardından 200 |
| Cache | Başarılı liste alınamadı | CACHE MISS → key oluşumu → CACHE HIT |

Bu tablo yalnız teşhis API'sine aittir; başlangıçta çalışan ana API arızalı configuration'a geçirilmedi. HTTP gövdeleri ve mevcut Task içerikleri yayınlanmadı. Liveness başarısı dış bağımlılığa erişim garantisi değildir. Tekil `GET /api/tasks/{id}` PostgreSQL'den doğrudan okur; Redis bağlantısı için kanıt olarak kullanılmadı.

## Expected Behaviour

Ana Compose'da `ConnectionStrings__Redis=redis:6379` kullanılır. `redis` Docker ağı içindeki servis adı, `6379` container portudur. Ana Redis ve API aynı `app` ağına bağlıdır. Host'a Redis portu yayınlamak, container'lar arasındaki bu bağlantının şartı değildir.

Liste endpoint'i önce Redis okur. Redis erişilemezken mevcut sözleşme **500**'dür; bu görev fail-open, retry veya circuit breaker eklemez. Doğru bağlantıda cache yoksa PostgreSQL okunup response cache'e yazılır; sonraki liste GET cache hit olur. Readiness gerçek Redis okuması ve PostgreSQL `SELECT 1` kontrolü yapar; sağlık anahtarına veri yazmaz. Başarılı startup syntax validation, hostname'in runtime'da çözülebildiğini kanıtlamaz.

## Investigation

1. **Servis gerçekten hazır mı?** Container state/health, Redis logları ve `redis-cli PING` birlikte incelenir. Bu deneyde ana Redis ve ayrı test Redis'i PONG verdi; Redis durdurulmadı.
2. **API hangi hedefi kullanıyor?** Configuration kaynağındaki key ve yalnız güvenli host/port bilgisi kontrol edilir. Tam environment veya connection string paylaşılmaz. Yanlış hedef API logunda görüldü.
3. **DNS çözülüyor mu?** Aynı ağdan yanlış hostname'e `redis-cli -h ... -p 6379 PING` denendi. Exit 1 ve `Name has no usable address`, ad çözümleme hatasının gerçek kanıtıdır. Nonzero exit tek başına yeterli sayılmadı.
4. **Ağ üyeliği ve port doğru mu?** Seçilmiş network/alias/IP alanları incelendi. Test Redis'i ve teşhis API'si mevcut `fullstack-ops-lab_app` ağına bağlıydı; ad dışında Redis portu değiştirilmedi.
5. **Hangi iş akışı başarısız?** Live 200, ready 503, gerçek liste GET 500 ve running/unhealthy birlikte kaydedildi. Tekil DB GET veya yalnız PING, liste/cache sözleşmesinin başarı kanıtı değildir.

DNS hatası, **çözülen bir host'taki kapalı porttan gelen connection refused** ile aynı değildir. Servis kesintisi de farklı kök nedendir; onun mevcut kanıtları Module 5/8/10'da bulunur. Bir Redis timeout/connection exception'ı tek başına bu üç nedeni ayırmaz; endpoint, DNS, PING, network ve log kanıtları birlikte kullanılır. Docker health periyodik probe sonucudur ve HTTP ölçümünden sonra değişebilir; probe timeout'u readiness HTTP 503 ile aynı sonuç formatı değildir.

## Useful Commands

Repository kökünde değer göstermeyen kontroller:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/Module9.EnvPreflight.ps1
docker compose --env-file .env config -q
docker compose --env-file .env ps -a
docker compose --env-file .env exec -T redis redis-cli PING
docker compose --env-file .env exec -T redis redis-cli DBSIZE
```

Deneyin geçici Compose dosyası, ana `api` tanımını `extends` ile miras aldı. Aşağıdaki **fragment**, ana dosyaya eklenmedi:

```yaml
services:
  api-probe:
    extends:
      file: <repository-compose-path>
      service: api
    image: <existing-api-image-id>
    depends_on: !reset {}
    environment:
      ConnectionStrings__Redis: <wrong-hostname>:6379
    extra_hosts:
      - "redis:<test-redis-ip>"
  redis-probe:
    image: redis:8.2.10-alpine
    command: ["redis-server", "--save", "", "--appendonly", "no"]
    tmpfs: ["/data"]
    networks: [app]
networks:
  app:
    external: true
    name: fullstack-ops-lab_app
```

Gerçek geçici dosyada ayrıca test Redis'inin PING healthcheck'i vardı. İki teşhis servisi ayrı, benzersiz Compose project adıyla `up -d --no-deps --no-build` kullanılarak başlatıldı; ana servisler yeniden oluşturulmadı. `api-probe` ve `redis-probe` adları ana `api`/`redis` DNS alias'larını çakıştırmaz. Test API'sinin `extra_hosts` kaydı yalnız o container'da doğru `redis` adını ayrı test Redis'ine eşler; ana Redis cache'ine erişmesini engeller. Bu, normal Compose DNS yapılandırması için öneri değil, mevcut cache'i koruyan deney izolasyonudur.

HTTP ölçümleri mevcut frontend container'ındaki curl ile **teşhis API IP'sine** gönderildi; Nginx proxy üzerinden uçtan uca routing kabulü olarak sunulmaz. Yeni host portu, network, volume, migration veya image build oluşturulmadı.

Teşhis kaynaklarına yönelik komut biçimleri (ID/path değişkenleri deneyden alınır; credential içermez):

```powershell
docker inspect --format '{{.State.Status}}|{{.State.Health.Status}}' $probeApiId
docker inspect --format '{{json .NetworkSettings.Networks}}' $probeApiId
docker exec $probeRedisId redis-cli PING
docker exec $probeRedisId redis-cli -h $wrongHost -p 6379 PING
docker exec $frontendId curl --silent --show-error --max-time 35 --output /dev/null --write-out '%{http_code}' "http://${probeApiIp}:8080/health/live"
docker exec $frontendId curl --silent --show-error --max-time 35 --output /dev/null --write-out '%{http_code}' "http://${probeApiIp}:8080/health/ready"
docker exec $frontendId curl --silent --show-error --max-time 35 --output /dev/null --write-out '%{http_code}' "http://${probeApiIp}:8080/api/tasks"
```

API ve Redis logları deneyde bellekte yakalanıp güvenli bulgulara indirgendiler. Raw `docker logs`, tam `docker inspect` veya çözümlenmiş Compose config'i kontrolsüz paylaşma. Her native komutun exit code'unu kontrol et; credential içerebilecek exception satırlarını dokümana kopyalama.

## Root Cause

Yanlış hostname, Redis hazır olsa da Docker ağında bir Redis endpoint'ine çözülemedi. Port 6379 ve çalışan Redis değişmedi; arıza servis kesintisi veya kapalı port diye adlandırılmaz. Configuration parser hostname'i syntax açısından kabul etti; gerçek bağlantı sırasında hata ortaya çıktı.

Şartname hostname **veya** network arızası istediğinden ayrıca ağdan ayırma deneyi zorunlu değildir. Network ayrıştırması yapılmış gibi sunulmaz. Her iki durumda da ilk soru, API'nin doğru endpoint'e gerçekten erişip erişemediğidir.

## Fix

Yalnız geçici dosyanın `ConnectionStrings__Redis` değeri **`redis:6379`** yapıldı. Aynı API image'ıyla `api-probe` yeniden oluşturuldu; PostgreSQL bağlantısı, TTL, uygulama kodu ve ana Compose değişmedi. Readiness ve Docker health toparlandıktan sonra aynı test Redis'inde ilk/ikinci liste GET yapıldı.

Bu deney configuration değişikliği nedeniyle teşhis API container'ını yeniden oluşturdu; aynı container'da bağlantı recovery'si diye sunulmaz. Aynı API container'ında Redis stop/start recovery'sinin mevcut kanıtı Module 8'dedir. Yeni deneyi o kesintinin tekrarı olarak genişletmedik.

## Verification

Başlangıç Git temizdi. Docker Engine **29.6.1**, Compose **v5.3.0** erişilebilirdi. Ana altı servis başlangıçta çalışıyordu ve görev sonunda da **running/healthy** kaldı. Kullanılan API image:

`sha256:308cb8d870b05f82a2ce2442618a8a720aeb3453e71ffb6afd02a13ee59d8fce`

Yanlış hostname kanıtının zaman aralığı **5 Ekim 2026 11:20:48–11:22:02 UTC**, tamamlanan recovery/cleanup koşusu **11:23:49–11:24:07 UTC** idi (Türkiye saati UTC+3). Yanlış hedef kanıtı ikinci yardımcı koşudan alındı; final recovery koşusu onu tekrar üretmedi.

| Kabul kriteri | Sonuç | Gerçek kanıt / sınır |
| --- | --- | --- |
| Dokuz başlıklı ayrı senaryo | PASS | Bu README. |
| Redis hazırken API yanlış hostname yüzünden bağlanamıyor | PASS | Ana/test Redis PONG; test Redis healthy; API logunda yanlış hedef ve Redis connection/timeout exception'ı. |
| DNS hatası, kapalı port ve kesinti ayrımı | PASS | Redis CLI exit1 ve `Name has no usable address`; hiçbir Redis servisi durdurulmadı, port değiştirilmedi. |
| Live / ready / Docker health / liste | PASS | 200 / 503 / running-unhealthy / 500. |
| Doğru hedef ve aynı image ile recovery | PASS | `redis:6379`; ready200, running-healthy, liste200/200; image ID aynı. |
| Cache miss/hit | PASS | İlk GET öncesi test key'i yok; ilk GET key oluşturdu ve MISS loglandı; ikinci GET HIT loglandı. JSON yanıtları eşit, liste bir mevcut kaydı içeriyordu; içerik yayınlanmadı. |
| Gerçek TTL | PASS | Test Redis'inde **60 saniye**; ana Compose varsayılanı 60, bağlantı düzeltmesinde TTL değiştirilmedi. |
| Tekil GET Redis kanıtı olarak kullanılmadı | PASS | Yeni deneyde tekil GET yapılmadı; kaynak incelemesi doğrudan PostgreSQL okuduğunu gösterir. |
| Mevcut veri/configuration/cache korundu | PASS | `tasks`, `lab_tasks`, `__EFMigrationsHistory` salt okunur JSON snapshot hash'leri aynı; `.env`, user-secrets, Program.cs ve compose.yaml dosya hash'leri aynı. Ana Redis DBSIZE **0 → 0**, ana Redis'e DEL/FLUSH yapılmadı. |
| Cleanup ve başlangıç kaynakları | PASS | Yalnız teşhis cache key'i DEL edildi, EXISTS0; test API/Redis kaldırıldı. Başlangıç container ID/state/RestartCount, network ID/adları ve volume adları aynı; altı servis healthy. |
| Ayrı yanlış-network / kapalı-port deneyi | NOT VERIFIED — ek kapsam | Şartnamenin hostname seçeneği karşılandı; bunlar bu görevde deneylenmedi. |
| Ayrı güvenli final500 request-log eşleşmesi | NOT VERIFIED — ek kontrol | Yardımcıdaki dar eşleştirme geçmedi; exception/yanlış hedef ve gerçek HTTP500 kanıtıyla karıştırılmadı. Module 10 request-log kabulü burada yeniden yapılmadı. |

İlk yardımcı DNS hata metninin bu image'daki `Name has no usable address` biçimini tanımadığı için başarısız oldu. Sonraki koşu DNS/HTTP kanıtını aldı fakat ek request-log eşleştirmesinde durdu. Recovery-only yardımcısının ilk denemesinde değişken kapsamı hatası oluştu; düzeltmeden sonra kalan recovery/cache kabulü exit0 ile geçti. Bu araç hataları uygulama crash'i veya başarılı tam test diye sunulmaz; her koşu yalnız kendi container'larını temizledi ve veri/configuration koruma kontrolleri geçti. Backend değişikliği gerekmedi.

Recovery log/HTTP çıktıları gerçek PostgreSQL parolası ve tamamlanmış PostgreSQL connection string'ine karşı bellekte kontrol edildi; eşleşme yoktu, değerler yayınlanmadı. Bu kontrol tüm Git geçmişini veya bütün hata yollarını kapsamaz. Repository secret kontrolü, Compose config ve diff check ayrıca uygulanır.

Geçici Compose dosyaları ve yardımcı/sonuç dosyaları temizlendi. Test Task oluşturulmadı veya silinmedi; sequence/migration çalıştırılmadı. Test Redis'i tmpfs kullandı; named/anonymous volume yaratılmadı. Var olan external PostgreSQL ve monitoring volume'ları korundu. Başlangıçta çalışan stack **down yapılmadı**. Prune, `down -v`, commit/push veya dördüncü senaryo uygulanmadı.

## What We Learned

- Redis'in kendi PING'i başarılı olsa da API yanlış hostname ile ona ulaşamayabilir.
- DNS çözümleme, TCP port erişimi, servis readiness'i ve HTTP endpoint başarısı farklı kanıtlardır.
- Liveness API prosesini; readiness bağımlılık erişimini; Docker health periyodik probe sonucunu gösterir.
- Liste GET Redis'e bağımlıdır; tekil PostgreSQL GET başarısı Redis bağlantısını kanıtlamaz.
- Cache MISS/HIT yalnız doğru bağlantı ve kontrollü key başlangıcıyla doğrulanır. Ayrı Redis instance'ı mevcut cache'i korur.
- Syntax validation erişilebilirliği kanıtlamaz; teşhis için runtime/log/network kanıtları gerekir.

Önerilen commit mesajı: `docs(troubleshooting): verify Redis hostname failure and cache recovery`. Sonraki adım yalnız bu senaryonun commit öncesi incelemesidir; Nginx 502 senaryosuna otomatik geçilmez.

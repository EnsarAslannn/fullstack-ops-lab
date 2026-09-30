# Modül 8 — Health Checks & Service Readiness

**Durum: 30 Eylül 2026 tarihinde gerçek Compose kesinti deneyleriyle doğrulandı.** Bu laboratuvar, çalışan bir container'ın uygulama trafiğine hazır olduğu anlamına gelmediğini gösterir. Dört servisli mevcut Compose yapısı ve Task API sözleşmesi korunmuştur.

## Başlangıç ve kapsam

Başlangıçta Git çalışma alanı temizdi. Docker Engine `29.6.1` ve Compose `v5.3.0` erişilebilirdi. Git'in yok saydığı yerel `.env` ve mevcut dış `fullstack-ops-postgres-data` volume'u doğrulandı; değerleri veya parola yazdırılmadı. Diğer projelerin container, image, network ve volume'larına dokunulmadı. `docker compose --env-file .env config -q` başarılı oldu. Mevcut dört servis `up -d --wait --wait-timeout 120` ile başlatıldı ve tümü `healthy` oldu.

## Kod değişmeden önceki baseline

Mevcut API yalnızca temel `/health` yanıtına bakıyordu; Compose API probe'u da aynı yolu kullanıyordu. Bağımlılıklar ayrı ayrı durdurulup geri başlatıldı. Cache boşken gerçek Task liste isteği yapıldı.

| Durum | API container | API Docker health | `/health` | `GET /api/tasks` |
| --- | --- | --- | ---: | ---: |
| PostgreSQL ve Redis açık | running | healthy | 200 | 200 |
| Redis durdu | running | healthy | 200 | 500 |
| PostgreSQL durdu, liste cache'i boş | running | healthy | 200 | 500 |

Her durdurmadan sonra ilgili servis tekrar başlatıldı. Baseline deneyinde Task kaydı oluşturulmadı. `/health` prosesin yanıt verebildiğini gösteriyordu; PostgreSQL ve Redis'e erişimi kanıtlamıyordu. PostgreSQL dururken liste Redis'te cache hit olursa bazı GET istekleri 200 dönebilir. Bu, veritabanının hazır olduğunu kanıtlamaz.

## Yeni health uçları

| Yol | Çalıştırdığı check | Sağlıklı | Bağımlılık kesintisinde |
| --- | --- | ---: | ---: |
| `/health` | `live` etiketli `self` | 200 `Healthy` | 200 `Healthy` |
| `/health/live` | `live` etiketli `self` | 200 `Healthy` | 200 `Healthy` |
| `/health/ready` | `ready` etiketli PostgreSQL ve Redis | 200 `Healthy` | 503 `Unhealthy` |

`/health` eski Phase 0 sözleşmesini korur. `self` check'i dış servise gitmez. Readiness sırasında PostgreSQL için mevcut bağlantı ayarıyla `SELECT 1` yapılır; migration veya veri yazma yoktur. Redis için mevcut `IDistributedCache` üzerinden var olmayan bir sağlık anahtarı okunur. Okuma gerçek Redis erişimi gerektirir ama anahtar yazmaz; test sonrası `EXISTS fullstack-ops:health:readiness` sonucu `0` oldu. İki check de cancellation token alır ve kayıtlarında 2 saniye timeout bulunur. Ek NuGet paketi eklenmedi. Yanıtlar yalnızca `Healthy` veya `Unhealthy` metnini içerir; 503 gövdesi gerçek HTTP isteğiyle doğrulandı, connection string, parola ve stack trace yoktu.

Compose API healthcheck'i runtime image'ında zaten bulunan Bash `/dev/tcp`, `head` ve `grep` ile artık `GET /health/ready` isteği gönderir. Yalnız HTTP **200** durum satırını kabul eder; 503 başarısızdır. Probe `interval: 5s`, `timeout: 3s`, `retries: 5`, `start_period: 15s` kullanır. `postgres` ve `redis` için `service_healthy` başlangıç koşulları korunmuştur. `depends_on` başlangıç sırasını yönetir; sonradan duran bağımlılık yüzünden çalışan API prosesini otomatik durdurup yeniden başlatmaz.

## Gerçek runtime sonuçları

Release build **0 uyarı, 0 hata** ile geçti. Güncel image'lar `docker compose --env-file .env up -d --build --wait --wait-timeout 120` ile çalıştırıldı; `api`, `frontend`, `postgres`, `redis` `healthy` oldu. Module 8 smoke testi önce eski kod üzerinde `/health/live` için **404** bularak beklentiyi doğruladı, sonra yeni kodla geçti. Kesintilerde API container ID'si değişmedi.

| Durum | API state | Docker health | `/health` | `/health/live` | `/health/ready` | `GET /api/tasks` |
| --- | --- | --- | ---: | ---: | ---: | ---: |
| İki bağımlılık açık | running | healthy | 200 | 200 | 200 | 200 |
| Redis durdu | running | unhealthy | 200 | 200 | 503 | 500 |
| Redis geri geldi | running, aynı container | healthy | 200 | 200 | 200 | 200 |
| PostgreSQL durdu, liste cache'i önce silindi | running | unhealthy | 200 | 200 | 503 | 500 |
| PostgreSQL geri geldi | running, aynı container | healthy | 200 | 200 | 200 | 200 |

Kesintide Docker health, beş başarısız probe ardından `unhealthy` oldu. API prosesi çalışmaya devam etti ve bağımlılık geri geldiğinde aynı container yeniden `healthy` oldu. Redis kapalıyken mevcut Task GET davranışı 500 olarak kaldı; health değişikliği bu API davranışını düzeltmez. Readiness başarılı olsa bile tek bir iş akışının başarısını garanti etmez: şema, sorgu, cache davranışı ve uygulama hataları ayrıca test edilmelidir.

Mevcut `Phase0A.Smoke.ps1` `/health` ile development OpenAPI'yi geçici localhost API container'ında geçti; container kaldırıldı. `Phase0B.Tasks.Smoke.ps1` Nginx üzerinden GET, POST, PUT, DELETE, 400 ve 404 kontrollerini geçti ve oluşturduğu görevi sildi. `Module3D.EfFoundation.Smoke.ps1` tasarım zamanı modeli veri yazmadan doğruladı. Eski Module 3E ve Module 5 scriptleri host'a açılmış ayrı PostgreSQL/Redis laboratuvar container adlarını beklediği için dört servisli Compose topolojisine doğrudan uygulanmadı. Final `tasks` sayısı `0`; `lab_tasks` satırı `1|Module 3B persistent task` ve `20260928113912_InitialCreate` migration kaydı korundu. Task liste cache key'i temizlendi.

## Komutlar ve tekrar

Yerel `.env`, mevcut external volume ve uygulanmış `InitialCreate` migration'ı ön koşuldur. Bu dosyada secret değeri yoktur. Komutlar bu projenin kökünde çalıştırılır:

```powershell
docker compose --env-file .env config -q
dotnet build FullStackOpsLab.slnx -c Release
docker compose --env-file .env build
docker compose --env-file .env up -d --wait --wait-timeout 120
docker compose --env-file .env ps
./tests/Module8.Readiness.Smoke.ps1
docker compose --env-file .env exec -T frontend curl -i http://api:8080/health/live
docker compose --env-file .env exec -T frontend curl -i http://api:8080/health/ready
docker compose --env-file .env down
```

Smoke testi yalnız bu Compose projesinin `redis` ve `postgres` servislerini sırayla durdurur, her kesintiden sonra geri başlatır, readiness ve Docker health toparlanmasını en çok 50 saniye bekler. DB kaydı oluşturmaz veya değiştirmez. PostgreSQL kesintisi öncesi ve sonunda yalnız `fullstack-ops:tasks:all:v1` cache anahtarını temizler. Başka bir laboratuvar aynı servisleri kullanırken çalıştırılmamalıdır. `down -v`, `docker volume prune` ve `docker system prune` kullanılmaz; `down` external PostgreSQL volume'unu korur.

## Kavramlar

| Kavram | Soru | Bu deneyde görülen |
| --- | --- | --- |
| Running | Container prosesi çalışıyor mu? | Bağımlılık kesintilerinde API hâlâ `running` idi. |
| Healthy | Docker healthcheck başarılı mı? | Eski `/health` probe'u kesintiyi kaçırdı; yeni `/health/ready` probe'u `unhealthy` yaptı. |
| Live | Uygulama prosesi cevap veriyor mu? | Kesintilerde `/health/live` 200 verdi. |
| Ready | Uygulama bağımlılıklarıyla trafik almaya hazır mı? | PostgreSQL veya Redis kapalıyken `/health/ready` 503 verdi. |
| Endpoint success | Belirli iş akışı gerçekten tamamlanabiliyor mu? | Cache boşken Task GET kesintide 500, toparlanmada 200 verdi. |

Docker health yalnız tanımlanan probe kadar anlamlıdır. Liveness dış bağımlılığa bağlanırsa geçici DB/cache kesintisi sağlam API prosesini gereksiz yere öldürme döngüsüne sokabilir. Readiness ise trafik kabul kararına yardım etmek için bu bağımlılıkları sorgular. Readiness başarısızlığı tek başına prosesi öldürmeyi gerektirmez: servisler geri geldiğinde aynı API instance'ı toparlanabilir. Bu Compose tanımı health bilgisini gözlemler; otomatik trafik yönlendirme veya iyileştirme sistemi değildir.

## Güvenli temizlik

Test görevi silinir, `tasks=0` doğrulanır ve yalnız Task liste cache anahtarı temizlenir. `docker compose --env-file .env down` proje container ve ağını kaldırır. `fullstack-ops-postgres-data` external volume'u, yerel `.env` ve proje image'ları kalır. Volume'u veya ilişkisiz Docker kaynaklarını silmeyin.

Gerçek final kontrolde dört proje container'ı ve `fullstack-ops-lab_app` ağı yoktu; external PostgreSQL volume'u yerindeydi. Başlangıç ve bitiş envanterindeki ilişkisiz container, network ve volume adları aynı kaldı. `.env` yerelde bulundu ve Git tarafından yok sayılmaya devam etti. `git diff --check` başarılıydı; commit veya push yapılmadı.

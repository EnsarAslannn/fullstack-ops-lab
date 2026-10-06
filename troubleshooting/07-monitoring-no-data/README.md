# Scenario

**Troubleshooting 7 — Prometheus Target Down / Grafana No Data.** Yanlış scrape hedefini, Grafana datasource bağlantı arızasını ve boş PromQL sonucunu ayırarak veri üretimi → scrape → storage → datasource → panel zincirini teşhis etmek.

**Completed — zorunlu kapsam PASS, 5 Ekim 2026.** Module 10'un yanlış service-name/port/path deneyleri yeniden kullanıldı. Eksik Grafana akışı, ayrı altı servisli Compose projesinde yalnız yanlış metrics path ile doğrulandı. Ana stack, gerçek `.env`, user-secrets, PostgreSQL/Grafana/Prometheus development volume'ları ve application/configuration kaynakları değiştirilmedi. Genel proje kapanışına geçilmedi.

Kaynaklar:

- [Şartname](../../PROJECT_SPEC.md): bölüm 11, Troubleshooting 7 ve dokuz başlıklı şablon.
- [Module 10 yanlış hedef deneyleri](../../labs/10-prometheus-grafana/README.md#3-yanlış-service-name--port--path-deneyleri), [scrape akışı](../../labs/10-prometheus-grafana/README.md#gerçek-scrape-ve-trafik-sonuçları), [trafiksiz görünüm](../../labs/10-prometheus-grafana/README.md#doğru-yorumlama-ve-trafiksiz-görünüm).
- [Mevcut yanlış hedef smoke](../../tests/Module10.ScrapeTargets.Smoke.py), [Grafana browser kabulü](../../tests/Module10.Grafana.Browser.Smoke.py), [dashboard kabulü](../../tests/Module10.Dashboard.Smoke.py), [izole hazırlık/cleanup örneği](../../tests/Module11.Compose.Smoke.py).
- [Compose](../../compose.yaml), [Prometheus config](../../monitoring/prometheus/prometheus.yml), [datasource](../../monitoring/grafana/provisioning/datasources/prometheus.yml), [dashboard provider](../../monitoring/grafana/provisioning/dashboards/overview.yml), [Overview JSON](../../monitoring/grafana/dashboards/overview.json).

## Symptoms

İzole Prometheus'un target'ı `http://api:8080/troubleshooting-metrics-missing` olduğu için **DOWN**, `up=0`, last scrape error **`server returned HTTP status 404 Not Found`** oldu. API aynı container'da **running/healthy**, liveness **200** kaldı. API'nin `/metrics` endpoint'i kaldırılmadı; yalnız Prometheus'un geçici hedef yolu bozuldu.

Grafana'nın provision edilmiş datasource health sonucu aynı anda **OK / Successfully queried the Prometheus API.** idi. Overview'un scrape stat paneli **Scrape başarısız** gösterdi; bazı grafikler eski noktaları ve cache toplamları **1 / 1 / 3** değerlerini göstermeye devam etti. Bütün paneller hemen `No data` göstermedi. Tüm 12 panelin datasource plugin sorguları başarılıydı; olmayan bir metric sorgusu ise hata vermeden boş sonuç döndürdü.

| Durum | Anlamı | Bu deneydeki kanıt |
| --- | --- | --- |
| Target DOWN | Prometheus target'tan yeni scrape alamıyor | HTTP404, target DOWN ve up0; API live200 |
| Datasource bağlantı arızası | Grafana, Prometheus query API'sine erişemiyor veya sorgu bağlantısı başarısız | Bu hata oluşturulmadı; burada datasource health OK ve plugin HTTP200 |
| Boş PromQL sonucu | Sorguya uyan series/sample yok; başarılı sorgunun sonucu da boş olabilir | Olmayan metric için Grafana plugin hatasız ve boş numeric sonuç |
| Trafiksiz rate0 / oran-p95 boşluğu | Event artışı yok veya oran/histogram hesabı için veri yetersiz | Module 10 idle kanıtı; bu koşuda cache rate0, oran/p95 plugin JSON null. Bunlar tek başına scrape arızası teşhisi değildir. |

## Expected Behaviour

Prometheus hedefi **`api:8080`**, metrics yolu **`/metrics`**, scrape interval **15 saniye**, timeout **10 saniye** olmalıdır. Grafana datasource UID **`fullstack-ops-prometheus`**, URL **`http://prometheus:9090`**; Overview UID **`fullstack-ops-overview`**. Grafana container'ında localhost, Prometheus container'ını göstermez. API/DB/Redis host portları açılmaz; iletişim Compose `app` ağı içindedir.

`up`, başarılı scrape'ı ölçer; API process'i, dependency readiness veya Prometheus'un kendi health'iyle aynı ölçüm değildir. Grafana datasource health'i Prometheus API bağlantısını sınar; tüm scrape target'larının UP olduğunu garanti etmez.

Scrape kesilince TSDB geçmişi hemen silinmez. Panelin zaman aralığı, son örnek, staleness/lookback ve `rate` penceresi sonucu etkiler. Bir grafikte eski çizgi veya toplam göründüğü için yeni scrape var deneme; bütün paneller hemen No Data olmalıdır diye de varsayma. Mevcut dashboard 15 dakika görünüm, 15 saniye refresh ve 2 dakika rate penceresi kullanır. NaN/boş sonuçlar sahte sıfıra çevrilmez.

## Investigation

1. **Servis durumu:** Compose ps ile API, Prometheus ve Grafana gerçekten running mi? API live/ready ve internal `/metrics` farklı kontrollerdir. Yeni deneyde altı servis başlangıçta healthy idi; scrape arızasında API healthy kaldı.
2. **Hedef ve son hata:** Targets ekranı/API'sinde gerçek scrape URL, `health`, `lastScrape`, `lastError` oku. DNS `lookup/no such host`, TCP `connection refused` ve HTTP404 farklı kök nedenlerdir; hepsini API down diye adlandırma.
3. **Ağ ve erişim:** Seçilmiş inspect alanlarıyla API/Prometheus'un aynı proje ağına bağlı olduğunu ve Prometheus'tan doğru `api:8080/metrics` erişimini kontrol et. Full inspect environment ve çözülmüş Compose config secret gösterebilir; paylaşma. Önceki Module 10 doğru scrape/recovery kanıtı doğru internal erişimi de gösterir.
4. **Prometheus query/storage:** `up` ile target sonucunu eşleştir. Geçmiş metric range sorgusunu, son sample timestamp ve controlled traffic counter artışından ayır. Target konfigürasyonu değişince `instance` etiketiyle sorgula; eski/yeni series'i yanlışlıkla birleştirme.
5. **Grafana datasource:** Provision edilmiş URL/UID ve health'i kontrol et. Datasource health OK iken gerçek dashboard ifadelerini `/api/ds/query` ile çalıştır. Prometheus UI'daki sonuç tek başına Grafana veri akışı kanıtı değildir.
6. **Panel:** Doğru datasource UID, job/instance/route/status label'ları, zaman aralığı ve rate penceresi seçili mi? 12 paneli gerçek Edge browser'da aç; query error ile hatasız boş/NaN sonucunu ayır.
7. **Recovery:** Doğru hedef geri geldikten sonra yeni scrape zamanı ve düzeltme sonrasında üretilmiş trafik örneğini Grafana üzerinden doğrula. Sayfayı yenilemek veya eski toplamın görünmesi tek başına recovery değildir.

## Useful Commands

Komutlar repository kökünden, **ayrı test project ve geçici fake env/override** ile yürütüldü. `$fixtureEnv`, `$override`, `$sqlPath` repository dışında oluşturuldu; gerçek `.env` bu deneye verilmedi. Aşağıdakiler komut aileleridir; değer/credential içermez:

```powershell
docker compose --project-name $project --env-file $fixtureEnv -f compose.yaml -f $override config -q
docker compose --project-name $project --env-file $fixtureEnv -f compose.yaml -f $override up -d --no-build --no-deps --wait --wait-timeout 120 postgres
dotnet tool restore
dotnet ef migrations script 0 InitialCreate --idempotent --project src/backend/FullStackOpsLab.Api --startup-project src/backend/FullStackOpsLab.Api --configuration Release --no-build --output $sqlPath
# İncelenmiş SQL yalnız yeni test PostgreSQL'ine UTF-8 stdin/psql ON_ERROR_STOP ile uygulandı.
docker compose --project-name $project --env-file $fixtureEnv -f compose.yaml -f $override up -d --no-build --wait --wait-timeout 180
docker compose --project-name $project --env-file $fixtureEnv -f compose.yaml -f $override ps
docker compose --project-name $project --env-file $fixtureEnv -f compose.yaml -f $override exec -T prometheus promtool check config /etc/prometheus/prometheus.yml
docker kill --signal HUP $testPrometheusId
# Loglar yalnız test instance'ından yakalanıp bellekte canary kontrolünden geçirildi; raw içerik basılmadı.
docker compose --project-name $project --env-file $fixtureEnv -f compose.yaml -f $override logs --no-color --tail 200 prometheus grafana api
```

EF child process Production ve credentialsız erişilemeyen preview ayarları kullandı; user-secrets okunmadı. Mevcut API/frontend image ID'leri yeniden kullanıldı; uygulama build/pull veya instrumentation değişikliği gerekmedi. API request/cache contract'ı korunarak yalnız izole boş DB'de bir fixture Task oluşturuldu, liste iki kez alındı, güncellendi ve silindi.

Geçici Prometheus YAML'de yalnız `metrics_path` değişti; aynı target instance kaldı. Her değişimde `promtool check config`, ardından yalnız test Prometheus'una **HUP** reload kullanıldı. API, Grafana, TSDB ve dashboard provisioning aynı kaldı.

```promql
up{job="fullstack-ops-api",instance="api:8080"}
http_server_request_duration_seconds_count{job="fullstack-ops-api",http_response_status_code="400"}
timestamp(http_server_request_duration_seconds_count{job="fullstack-ops-api",http_response_status_code="400"})
```

Prometheus `/api/v1/targets` ve `/api/v1/query`, Grafana datasource health `/api/datasources/uid/fullstack-ops-prometheus/health` ve gerçek `/api/ds/query` sonuçları birlikte kullanıldı. Grafana girişinde yalnız yeni test admin credential'ı kullanıldı; değer browser/test çıktısına ve görsellere yazılmadı. `timestamp(metric)`, response'un değerlendirme zamanından farklı olarak seçilmiş **metric sample zamanını** verir.

## Root Cause

Yeni deneyde Prometheus doğru service-name ve portta çalışan API'ye **yanlış metrics path** ile gitti; HTTP404 nedeniyle scrape başarısız oldu. Grafana'nın Prometheus bağlantısı bozulmadığı için datasource health başarılı kaldı. Veri zincirindeki arıza scrape katmanındaydı; API process'i veya Grafana datasource transport'u değildi.

Module 10'un ayrı teşhis instance'ındaki mevcut kanıtları:

| Yanlış hedef | Hata | Doğru hedef sonrası |
| --- | --- | --- |
| `module10-api-missing-f503ba95:8080/metrics` | DNS lookup/no such host; DOWN/up0 | api:8080/metrics UP/up1 |
| `api:18080/metrics` | TCP connection refused; DOWN/up0 | api:8080/metrics UP/up1 |
| `api:8080/module10-metrics-missing` | HTTP404; DOWN/up0 | api:8080/metrics UP/up1 |

Bunlar 4 Ekim 2026'nın gerçek sonuçlarıdır; ana Prometheus hedefi doğru kalmıştı. Ancak o instance Grafana'nın datasource'u değildi. Yeni 5 Ekim deneyi, test Grafana'nın gerçekten bağlandığı **aynı test Prometheus** üzerinden eksik zinciri tamamladı; üç eski arızayı tekrar çalıştırmadı.

## Fix

Yalnız geçici Prometheus YAML'nin yolu **`/metrics`** yapıldı, config doğrulandı ve HUP ile yeniden yüklendi. Ana `monitoring/prometheus/prometheus.yml` tüm görev boyunca doğru `api:8080/metrics` hedefinde kaldı. Datasource veya dashboard URL/UID'si değiştirilmedi; uygulama özelliği, retry veya fallback eklenmedi.

Reload sonrasında beş yeni boş başlıklı Task POST'u **400** döndürdü. Bu güvenli trafik Task kaydı yazmadı; HTTP counter örneği üretti. Aynı API process'i/container'ı kullanıldı; counter400 **3 → 8 (+5)** oldu. Prometheus'un yeni sample timestamp'i, düzeltme/yeni trafik başlangıcından **daha büyük** bulundu. Grafana plugin aynı **8** değerini ve aynı yeni sample timestamp'ini verdi; eski veri veya yalnız sayfa cache'i başarı kanıtı sayılmadı.

## Verification

Başlangıç Git temizdi; HEAD `fd385c35f1dd3eae988f8fbfa12b3b44919c7d49`. Docker Engine **29.6.1**, Compose **v5.3.0**. Başarılı tam koşu **5 Ekim 2026 12:54:27–12:55:56 UTC** (Türkiye saati 15:54:27–15:55:56). Ayrı project **`monitor-flow-3cb1cccc2a45`**, üç yeni Compose-managed PostgreSQL/TSDB/Grafana volume'u, runtime'da üretilmiş fake credential ve yalnız localhost ephemeral frontend/Prometheus/Grafana portları kullanıldı. API/DB/Redis host portu yoktu.

| Ölçüm | Gerçek sonuç |
| --- | --- |
| Başlangıç başarılı scrape | İki ayrı başarılı scrape beklenmiş; son baseline **12:55:17.584587680 UTC**, counter400 **3**, sample Unix **1791204917.584** |
| Yanlış path scrape | **12:55:30.451454554 UTC**, DOWN/up0; `server returned HTTP status 404 Not Found` |
| API / datasource | Aynı API running/healthy, live200; Grafana datasource **OK / Successfully queried the Prometheus API.** |
| Geçmiş | Grafana range sorgusunda counter400 için **2 tarihsel örnek** kaldı; olmayan metric hatasız boş sonuç |
| Yeni trafik sınırı | **12:55:34.836735 UTC**, Unix **1791204934.836735**; bundan sonra beş POST400 |
| Yeni başarılı scrape | **12:55:47.584503431 UTC**, UP/up1, lastError boş |
| Fresh sample / Grafana | Unix **1791204947.584 > 1791204934.836735**; counter400 **8**, delta **5**; Grafana timestamp sorgusu aynı zamanı verdi |
| Browser | Gerçek Edge login, 12 provision edilmiş panel, plugin error0, page error0, beklenmeyen HTTP error0; account advisor preference404 önceki kabuldeki dar istisna |

Kısa panel gözlemleri (instant plugin değerleri ile browser'ın 15 dakikalık range görünümü aynı gösterim değildir):

| Panel grubu | DOWN gözlemi | Recovery gözlemi / sınır |
| --- | --- | --- |
| Scrape stat | 0 / Scrape başarısız | 1 / Scrape başarılı |
| HTTP rate | 0 | **0.05399814814814815 req/s**; kısa kontrollü trafik, benchmark değil |
| 5xx / p95 | Plugin null; grafikte nokta yok | **0% / 0.004940480858344621 s**; yalnız bu kısa ölçümdeki trafik/histogram sonucu |
| CPU / working set | Eski örnekler/çizgiler görünüyordu | Yeni örnekler geldi; toplam makine CPU'su veya performans garantisi değil |
| Cache rate / oran | Hit/miss/invalidation rate0, oran null | Recovery'de de rate0/oran null: yeni trafik POST400 idi, cache işlemi değildi |
| Cache toplamları | 1 hit / 1 miss / 3 invalidation | Aynı toplamlar; tek başına yeni scrape kanıtı sayılmadı |

Görseller gerçek test browser'ından alınmış ve görsel olarak hassas bilgi açısından incelenmiştir. Login/account ekranı, credential, token veya development Task verisi gösterilmez:

- [Prometheus target DOWN ve HTTP404](images/prometheus-target-down.png)
- [Grafana — başarısız scrape, kalan eski grafik/toplamlar](images/grafana-target-down.png)
- [Grafana — doğru hedefte toparlanma](images/grafana-target-recovered.png)

| Şartname / kabul kriteri | Sonuç | Kanıt / sınır |
| --- | --- | --- |
| Yanlış service-name/port/path ve teşhis | PASS — mevcut runtime | Module 10 üç DOWN/error/UP karşılaştırması; API running/live200. |
| Grafana'nın kullandığı scrape zincirinde arıza | PASS — yeni runtime | Aynı test Prometheus'una provision edilmiş datasource, path404, up0, datasource OK, 12 panel sorgusu. |
| Target DOWN / datasource failure / boş sorgu ayrımı | PASS | Target ve datasource eşzamanlı farklı sonuçlar; olmayan metric hatasız boş. Gerçek datasource transport kesintisi ayrıca oluşturulmadı. |
| Geçmişin hemen kaybolmaması / panel davranışı | PASS | İki historical sample, eski CPU/memory çizgileri ve cache toplamları; boşluklar/zero-rate scrape teşhisi yerine kullanılmadı. |
| Doğru hedef ve fresh Grafana recovery | PASS | Yeni lastScrape, sample timestamp sınırı, counter400 +5; Grafana aynı sample ve değeri verdi. |
| Config, provisioning, browser, güvenli görüntüler | PASS | İki config için promtool, sessiz Compose config; UID/URL/read-only/provisioned, gerçek browser ve üç görsel. |
| Secret güvenliği / cleanup | PASS | Sahte credential'lar captured native/HTTP/log/console çıktılarında yok; own Task0/history1, own cache key temizliği; başlangıç envanteri aynı. |
| Ayrı datasource network/authentication arızası, uzun kesinti/retention/load | NOT VERIFIED — ek kapsam | Bu görev yanlış scrape target senaryosudur; her Grafana No Data nedenini veya uzun dönem davranışı test etmez. |

İlk yardımcı koşu yanlış-path/Grafana kanıtını aldı fakat Targets UI için network-idle beklemesinde timeout verdi; recovery PASS sayılmadı. Süreç içindeki geçici araç temizliği de tamamlanamadı. O koşunun Docker kaynakları temizlendi ve başlangıç envanteri aynı bulundu. Geçici klasör, Python çıkışından sonra doğrulanmış açık yoluyla temizlendi. İkinci koşuda Targets rendered DOM üzerinden beklendi; yeni hata/recovery ve son cleanup **exit0/PASS**. Bu yardımcı sorunları uygulama arızası veya başarılı tam koşu diye sunulmaz.

Temizlik yalnız benzersiz project'in container/network'lerine `down --remove-orphans` uyguladı; üç yeni volume'un project label'ı/adı ve başlangıçta yokluğu kontrol edilerek açık adlarıyla kaldırıldı. Development external volume mount edilmedi. `down -v`, prune, ilişkisiz kaynak işlemi yok. Başlangıç/bitiş **18 container ID/state/RestartCount, 8 network ID/adı, 21 volume adı, 38 image/tag kaydı** aynı; default bridge ID **fa040868e5e0** değişmedi. Başlangıçtaki altı servis running/healthy bırakıldı. Temporary fake env/override/SQL, yardımcı/sonuç dosyaları ve repository dışındaki Playwright araçları temizlendi; gerçek `.env`/user-secrets okunmadı veya değiştirilmedi.

Secret scanner'a yalnız yukarıdaki üç **açık PNG yolu** eklendi. Önceki PNG imza/chunk/IEND/trailing-payload koruması, metin kuralları ve diğer binary/okunamayan dosya hataları değişmedi. Bu OCR veya kapsamlı PNG/secret doğrulaması değildir; görsel kontrol ayrıca yapıldı. Üç yeni onaylı-yol fixture'ı ve bir trailing-credential reddi eklendi; mevcut fixture'lar korundu. Repository taraması Git geçmişini/ignored secret kaynaklarını kapsamaz.

Son dokümantasyon kontrolleri (6 Ekim 2026): `Module9.SecretLeakage.Smoke.ps1` **23/23 PASS**, repository `Module9.SecretLeakage.Check.ps1` **exit0/bulgu yok**, `git diff --check` **exit0**. Sessiz `docker compose --env-file .env.example config -q` ve mevcut Prometheus config'inin `promtool check config` kontrolü **exit0**; altı ana servis **running/healthy**. Dokuz başlık, **16 yerel bağlantı/anchor** ve yalnız beklenen **yedi değişen/yeni dosya** doğrulandı. Secret fixture'larında stdout/stderr canary kontrolü otomatik yapıldı. Bu son statik kontroller yeni runtime deneyi olarak sunulmaz; arıza/toparlanma kanıtları yukarıdaki 5 Ekim koşusuna aittir.

## What We Learned

- API çalışırken yanlış scrape hedefi yüzünden `up=0` olabilir; dependency readiness ve scrape başarısı ayrı sinyallerdir.
- Grafana'nın Prometheus API'sine bağlanması, Prometheus'un API'den metric alabilmesi demek değildir.
- Boş PromQL, query error, NaN oran ve trafiksiz rate0 farklı sonuçlardır.
- Storage'daki geçmiş, yeni scrape olmadığı hâlde panelde görünür kalabilir; sample zamanını kontrol et.
- Yeni controlled traffic counter artışı ve sample timestamp, cached/eski yanıtı recovery diye sunmayı önler.
- Provisioning URL'si container DNS adı kullanır; transient override ana configuration'ı bozmadan teşhis sağlar.

Önerilen commit mesajı: `docs(troubleshooting): verify Prometheus and Grafana scrape recovery`. Sonraki adım yalnız bu senaryonun commit öncesi incelemesidir; genel proje kapanışı bu görevde başlatılmadı.

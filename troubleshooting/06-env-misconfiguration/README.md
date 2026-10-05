# Scenario

**Troubleshooting 6 — Environment Misconfiguration.** Eksik veya yanlış configuration nedeniyle API'nin başlamamasını, biçimce geçerli fakat çalışmayan bağlantı ayarlarından ayırarak güvenli hata mesajlarıyla teşhis etmek.

**Completed — zorunlu kapsam mevcut gerçek kanıtlarla PASS (5 Ekim 2026 incelemesi).** Module 9'un 20 izole configuration senaryosu ve sonraki 19 preflight fixture'ı yeniden kullanıldı; aynı negatif testler veya Docker deneyleri tekrarlanmadı. Bu görev dokümantasyondur; uygulama, `.env`, user-secrets, PostgreSQL rolü ve volume'lar değiştirilmedi.

Kanıt kaynakları:

- [Şartname](../../PROJECT_SPEC.md): bölüm 11, Troubleshooting 6 ve dokuz başlıklı şablon. `POSTGRES_HOST` şartnamedeki örnek isimdir; bu projede böyle bir configuration key'i kullanılmaz.
- [Module 9 — startup contract](../../labs/09-environment-configuration/README.md#10-configuration-contract-ve-başlangıç-doğrulaması), [preflight](../../labs/09-environment-configuration/README.md#11-güvenli-yerel-env-hazırlığı-ve-preflight), [kaynak önceliği](../../labs/09-environment-configuration/README.md#2-kaynaklar-ve-öncelik) ve [izole bootstrap](../../labs/09-environment-configuration/README.md#15-yeni-boş-volume-ile-izole-bootstrap-final-kabulü).
- [Module 10 — 4 Ekim tekrar kontrolleri](../../labs/10-prometheus-grafana/README.md#çalıştırılan-kontroller-ve-cleanup): configuration 20/20, güncel preflight 19/19 ve güvenli çıktı kanıtı.
- [Configuration smoke](../../tests/Module9.Configuration.Smoke.ps1), [preflight script](../../scripts/Module9.EnvPreflight.ps1), [preflight smoke](../../tests/Module9.EnvPreflight.Smoke.ps1), [ApiConfiguration](../../src/backend/FullStackOpsLab.Api/Configuration/ApiConfiguration.cs), [Program](../../src/backend/FullStackOpsLab.Api/Program.cs).
- [Compose](../../compose.yaml), [örnek environment](../../.env.example), [PostgreSQL readiness](../../src/backend/FullStackOpsLab.Api/Health/PostgreSqlReadinessCheck.cs), [Redis readiness](../../src/backend/FullStackOpsLab.Api/Health/RedisReadinessCheck.cs).
- [Wrong Localhost](../01-wrong-localhost/README.md) ve [Redis Connection Failure](../03-redis-connection/README.md): parser'dan geçebilen yanlış bağlantı hedeflerinin ayrı runtime kanıtları.
- [Hosted CI run](https://github.com/EnsarAslannn/fullstack-ops-lab/actions/runs/37307851396), commit `489142f4285f59667970053e4c26f115ebc27a64`: Windows configuration/secret job'ı ve configuration smoke step'i başarılı. Bu run preflight fixture'larını yürütmez; onların kanıtı yukarıdaki Module 10 kabulüdür.

## Symptoms

Eksik veya biçimce geçersiz bağlantı ayarında API dinlemeye başlamadan hata verir. Beklenen startup mesajları yalnız sorunlu configuration anahtarını içerir:

```text
ConnectionStrings:Postgres eksik veya geçersiz.
ConnectionStrings:Redis eksik veya geçersiz.
Cache:TasksTtlSeconds pozitif bir tamsayı olmalı.
```

Module 9 negatif testlerinde stdout boştu; stderr'de beklenen güvenli mesaj ve nonzero exit vardı. Windows'ta gözlemlenen `0xE0434352`, bu vakalarda yakalanmamış beklenen startup exception'ına aitti. Bu kod tek başına doğru teşhis veya başarılı test değildir: güvenli mesaj ve canary/tam test connection string yokluğu da doğrulandı. Geçerli configuration ile bir crash beklenen negatif sonuç sayılamaz.

Preflight ise eksik/boş/placeholder alanları veya geçersiz TTL'yi **yalnız anahtar adlarıyla** bildirir. Compose'un `${VAR:?}` kontrolü eksik/boş alanı reddedebilir; dolu bir placeholder veya yanlış parola bu kontrolü geçebilir. Yanlış hostname/parola parser tarafından kabul edilirse API başlayabilir fakat runtime readiness veya ilgili API isteği başarısız olabilir.

## Expected Behaviour

| Ayar durumu | Projedeki davranış / ayrım |
| --- | --- |
| Eksik | Key kaynaklarda yoktur. API PostgreSQL/Redis key'ini zorunlu tutar; TTL key'i yoksa 60 saniye kullanır. |
| Boş / whitespace | Key vardır fakat kullanılabilir değer yoktur. API bağlantılarda ve açıkça verilen TTL'de reddeder. |
| Placeholder | `.env.example` içindeki `<set-outside-git>` gerçek değer değildir. Preflight bilinen placeholder biçimlerini zorunlu Compose alanlarında reddeder. API genel amaçlı placeholder tarayıcısı değildir; bir placeholder parser'ın kabul ettiği host/alan içinde kalırsa startup geçebilir. |
| Biçimce geçersiz | PostgreSQL bilinmeyen option veya gerekli host/database/username eksikliği; Redis geçersiz option değeri veya endpoint yokluğu; TTL tamsayı olmayan, sıfır veya negatif değer. API startup durur. |
| Biçimce geçerli ama yanlış | Yanlış DNS adı, container içinde yanlış localhost, yanlış credential veya kapalı servis. Syntax validation bağlantı açmaz; doğru hedef/kimlik doğrulaması runtime'da ayrıca kanıtlanır. |

`ConnectionStrings:Postgres`, .NET'in hiyerarşik anahtarıdır. Environment içindeki **`ConnectionStrings__Postgres` aynı anahtara eşlenir**; Redis ve `Cache__TasksTtlSeconds` için de `__` → `:` dönüşümü geçerlidir. API, `POSTGRES_PASSWORD` veya şartnamedeki örnek `POSTGRES_HOST` alanını doğrudan okumaz.

Host API, Development ortamında backend projesinin `UserSecretsId` store'unu kullanabilir; daha yüksek öncelikli process environment aynı key'i ezebilir. `.env` host .NET sürecine kendiliğinden yüklenmez. Compose ise user-secrets'ı otomatik okumaz. Compose ağındaki `postgres:5432` ve `redis:6379` adresleri host API için otomatik erişim adresleri değildir; mevcut Compose DB/Redis host portu yayınlamaz.

## Investigation

1. **Hangi süreç ve configuration kaynağı?** Host API mi, Compose API mi? `Program.cs`, `ApiConfiguration.cs`, örnek key'ler ve service `environment` tanımını karşılaştır. Değerleri veya `dotnet user-secrets list` çıktısını paylaşma.
2. **Hangi anahtar okunuyor?** `.NET` tarafında `ConnectionStrings:Postgres`/`Redis`; container process environment'ında çift alt çizgili karşılıkları. Yanlış key adına yazılmış doğru değer, gerekli key'i sağlamaz.
3. **Statik preflight mi, API startup mı başarısız?** Preflight dosyanın Git dışında olduğunu, zorunlu Compose alanlarını, TTL'yi, sessiz config çözümlemesini ve external volume'un varlığını denetler. API ise kendisine ulaşmış connection string'leri provider parser'larıyla ve TTL'yi pozitif tamsayı olarak denetler. Preflight API parser'ını çalıştırmaz, migration/schema veya erişimi doğrulamaz.
4. **API dinlemeye başladı mı?** Startup hatasında güvenli key mesajını ve exit code'u birlikte incele. Dinleyen API için live200/ready503, geçerli syntax ile dependency sorunu olabileceğini gösterir; tek başına yanlış parola teşhisi değildir.
5. **Hedef/DNS/port/authentication ayrımı?** Doğru PostgreSQL `postgres:5432`, Redis `redis:6379` olmalı. Wrong Localhost connection-refused; Redis yanlış hostname deneyi DNS hatasıdır. Authentication failure bunlardan farklıdır. Readiness genel unavailable sonucu verir; kesin nedeni güvenli yerel teşhisle ayır.
6. **Initialized volume mu?** Boş volume ilk `POSTGRES_*` değerleriyle initialize olur. Initialized volume'da `.env` parolasını değiştirmek PostgreSQL rol parolasını değiştirmez. API credential'ının mevcut rolle eşleşmesi gerekir; statik preflight veya parser bu eşleşmeyi kanıtlayamaz.

**Compose'daki iki işlem:** CLI önce `.env`/`--env-file` ile YAML `${...}` substitution yapar; sonra yalnız service `environment` alanları container process'ine aktarılır. Dosyadaki her key otomatik aktarılmaz. `.env.example` içindeki `ConnectionStrings__Postgres`/`Redis` host akışını gösteren kullanılmayan placeholder'lardır; mevcut Compose bunları okumaz. Compose PostgreSQL bağlantısını `POSTGRES_*` alanlarından kurar, Redis hedefini sabit servis adıyla verir. Shell değişkenleri normal substitution'da dosyayı ezebilir; preflight gerekli key'leri kendi child environment'ından çıkararak dosyadaki eksiğin gizlenmesini önler.

**TTL farkı:** API'ye doğrudan boş TTL verilirse startup başarısızdır. Compose `${Cache__TasksTtlSeconds:-60}` ile eksik **veya boş** değeri 60'a çevirebilir. Preflight, dosyada açıkça boş TTL'yi reddederek bu hatayı fallback'ten önce gösterir. Bu farklı kapsamlar çelişki değildir.

## Useful Commands

Aşağıdakiler repository kökündeki mevcut kontrol komutlarıdır; bu dokümantasyon görevinde startup/preflight smoke deneyleri **yeniden çalıştırılmadı**:

```powershell
# API build'inden sonra, yalnız izole Production child process ve sahte credential kullanır:
powershell -NoProfile -ExecutionPolicy Bypass -File tests/Module9.Configuration.Smoke.ps1 -Configuration Release
# Tek fixture seçimi mümkündür; gerçek configuration'ı bozmaz:
powershell -NoProfile -ExecutionPolicy Bypass -File tests/Module9.Configuration.Smoke.ps1 -Scenario 'Postgres missing'

# Ayrı ignored fixture dosyaları; mevcut external volume için yalnız varlık kontrolü:
powershell -NoProfile -ExecutionPolicy Bypass -File tests/Module9.EnvPreflight.Smoke.ps1
# Normal preflight gerçek dosyayı değiştirmez; değer basmaz:
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/Module9.EnvPreflight.ps1

git check-ignore .env
git ls-files -- .env
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/Module9.SecretLeakage.Check.ps1
git diff --check
```

Preflight, `.env` quoting/interpolation için Compose'un kendi parser'ını kullanır; çözülmüş JSON bellekte kalır, container başlatılmaz. `docker compose --env-file .env config -q` sessiz kontrol içindir. `-q` olmadan config, tam inspect, raw log/exception veya user-secrets çıktısı secret gösterebilir; paylaşma. Negatif startup testinin process error-mode ve Event Log ayarı yalnız test/child kapsamındadır; Windows genel güvenlik veya hata penceresi ayarları değiştirilmez.

## Root Cause

Configuration değeri eksik, yanlış anahtara yazılmış, boş, örnek placeholder olarak bırakılmış veya parser'ın kabul etmediği biçimdedir. Diğer hata sınıfında değer biçimce geçerlidir ama yanlış sunucu/credential'a yönelir. Host store'u ile Compose substitution kaynağını karıştırmak veya `.env` içindeki kullanılmayan bir key'in API'ye aktarıldığını varsaymak yanlış değerin kullanılmasına yol açabilir.

`ApiConfiguration.Read`, ağ bağlantısı veya parola karşılaştırması yapmaz; provider hatasını güvenli key mesajıyla değiştirir. PostgreSQL parolası bu syntax contract'ında zorunlu değildir. Bu, mevcut Compose PostgreSQL kurulumu için authentication gerekmediği anlamına gelmez. Initialized volume'daki rolün credential'ı, yeniden verilen environment değeriyle otomatik değişmez.

## Fix

Önce doğru akış/key/kaynağı belirle; gerçek secret'ı Git dışında yetkili yerel kaynakta yönet. Compose alanları için placeholder'ları ve hatalı TTL'yi preflight ile, API bağlantı biçimini startup validation ile denetle. Bu görev gerçek kaynakları değiştirmedi veya otomatik eşitleme/rotation uygulamadı.

Startup validation yüzünden çıkmış süreç, doğru ayarla **yeniden başlatılmalıdır**; ölmüş process'in aynı container'da hazır olduğu iddia edilmez. Container environment değişikliği recreate gerektirir; yalnız `restart` yeni `.env` değerini çalışan container'a uygulamaz. Biçimce geçerli hedef arızasının düzeltmesi ve dependency recovery, ayrı Wrong Localhost/Redis senaryolarında kanıtlanmıştır. Bu senaryoların configuration recreate kanıtı, aynı-container dependency stop/start recovery'siyle karıştırılmaz.

Parola uyuşmazlığı varsa rol sahibi ve doğru credential kaynağı belirlenmeli; volume silmek veya `.env` parolasını rastgele değiştirmek çözüm değildir. Başarılı TCP authentication/SQL kontrolü ayrıca gerekir. Bu görev yanlış parola deneyi, rol parolası değişikliği veya veri silme yapmadı.

## Verification

Başlangıç Git çalışma alanı temizdi; HEAD `489142f4285f59667970053e4c26f115ebc27a64`. Kanıtlar önceki gerçek koşularla aşağıdaki gibi eşleştirildi; bu dokümantasyon güncellemesini yeni runtime koşusu gibi sunmuyoruz.

| Şartname / kabul kriteri | Sonuç | Somut kanıt / sınır |
| --- | --- | --- |
| Yanlış/eksik environment kaynaklı hatanın teşhisi | PASS | Module 9 startup stderr güvenli key mesajları; `ApiConfiguration.Read` ve Production child fixture'ları. Şartnamedeki örnek key yerine projedeki gerçek key'ler kullanılır. |
| Eksik/geçersiz PostgreSQL | PASS — mevcut runtime | 7 vaka: missing, empty, whitespace, malformed, host/database/user eksikliği. Her biri dinlemeden nonzero exit + beklenen güvenli mesaj; canary yok. |
| Eksik/geçersiz Redis | PASS — mevcut runtime | 5 vaka: missing, empty, whitespace, malformed ve endpoint yokluğu; aynı güvenli hata kabulü. |
| TTL ve varsayılan davranışı | PASS — mevcut runtime/source | 4 negatif: empty/noninteger/zero/negative; 3 pozitif: absent/120/max integer. API yoksa60; Compose boş fallback'i/preflight ayrımı source ile açıklandı. |
| Biçim doğrulaması erişilebilirlik değildir | PASS — mevcut runtime | 4 geçerli configuration vakasında health/live200, boş Task POST400, dependency port1 kapalıyken ready503. Bunların biri PostgreSQL password-optional; gerçek password authentication başarısı değildir. Toplam configuration 16 negatif + 4 pozitif = 20/20. |
| Yanlış hostname / hedef | PASS — mevcut runtime | Wrong Localhost: PG hazırken loopback bağlantı reddi, ready503/DB GET500; doğru hedefte DB GET404. Redis senaryosu: yanlış hostname DNS hatası, ready503/liste500; doğru hedefte ready200/liste200 ve miss/hit. |
| Eksik/boş/placeholder ve preflight kapsamı | PASS — mevcut runtime/source | Module 9 başlangıç fixture'ları, Module 10 güncel 19/19 tekrar: required missing/empty/placeholder, optional-empty TTL, interpolation, dosya/Git/volume kontrolleri; canary hidden ve fixture unchanged. Şimdi 6 zorunlu alan: POSTGRES_USER/PASSWORD/DB, ASPNETCORE_ENVIRONMENT, GF_SECURITY_ADMIN_USER/PASSWORD. |
| Güvenli stdout/stderr | PASS — mevcut runtime | Negatif exit0xE0434352 + güvenli stderr; parser ayrıntısı/canary/tam test connection string yokluğu. Geçerli configuration crash'i negatif PASS sayılmaz. |
| Host/Compose ve çift alt çizgi eşlemesi | PASS — source + mevcut test | Program varsayılan configuration, project UserSecretsId, Compose environment, `.env.example`; process fixture double-underscore key'leri başarıyla API'ye ulaştı. |
| Parola doğruluğunun sınırı | PASS — doğru açıklama; kasıtlı yanlış parola runtime NOT VERIFIED | Parser bağlantı açmaz; preflight credentials/readiness doğrulamadığını açıkça söyler. Module 9 bootstrap doğru fake credential ile TCP SELECT1 geçti; buradan yanlış parola deneyi sonucu çıkarılmaz. Yeni yanlış parola deneyi zorunlu değil. |
| Initialized volume credential sınırı | PASS — mevcut dokümantasyon/source incelemesi | Module 9 onboarding/production bölümleri: ilk initialization ile rol credential'ı oluşur; env değişikliği rotation değildir. Rol rotation veya mevcut volume'da yanlış parola deneyi yapılmış sayılmaz. |
| Dokuz başlık / güvenli bağlantılar / son tarama | PASS | Bu README; göreli link/anchor, secret regression ve diff kontrolleri. |

Zorunlu kriterler mevcut gerçek testlerle desteklenir; eksik zorunlu runtime kanıtı bulunmadı. Yeni placeholder biçimleri, her provider option'ı, tüm environment key'leri, production rotation ve bütün runtime exception yollarında redaksiyon **NOT VERIFIED — ek kapsam**. Secret scanner bilinen desenleri tarar; tam Git geçmişini veya ignored `.env`/repository dışındaki user-secrets değerlerini taramaz.

Bu görevde yalnız senaryo README ve PROJECT_STATUS güncellendi. Container/process fixture başlatılmadı; test verisi veya geçici kaynak oluşturulmadı. `.env`/user-secrets okunmadı veya değiştirilmedi; Docker kaynaklarına, mevcut PostgreSQL rol/verilerine ve Redis cache'ine işlem yapılmadı. Mevcut başarılı deneyler korunur; yeni build/test coverage iddiası yoktur.

## What We Learned

- Eksik key, boş değer, placeholder ve biçim hatası aynı durum değildir; doğru kontrol katmanını seç.
- `ConnectionStrings__Postgres`, .NET'in `ConnectionStrings:Postgres` key'ini sağlar; benzer isimli başka key bunu yerine getirmez.
- Startup validation syntax/required-field kontrolüdür; readiness gerçek dependency erişimini sınar. Readiness200 tek başına Task şemasını kanıtlamaz.
- `.env` substitution ve container process environment iki ayrı adımdır; host user-secrets ve Compose kaynakları otomatik eşitlenmez.
- Initialized volume'un parolası yalnız environment değiştirilerek rotate edilmez; parser parola doğruluğunu bilemez.
- Nonzero exit, güvenli beklenen mesaj ve sızıntı yokluğu birlikte test kanıtıdır; raw exception/secret çıktısı paylaşılmaz.

Önerilen commit mesajı: `docs(troubleshooting): document environment configuration diagnosis`. Sonraki adım bu iki dosyanın commit öncesi incelemesidir; yedinci senaryoya otomatik geçilmez.

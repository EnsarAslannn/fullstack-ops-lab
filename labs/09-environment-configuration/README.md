# Modül 9 — Environment Configuration & Secrets

11. bölüm, önceki envanter ve startup validation adımlarının ardından gelen güvenli yerel `.env` onboarding adımıdır. Module 9 bütünü henüz tamamlanmadı.

İlk dokuz bölüm mevcut durum envanteridir. **10. bölümde** configuration contract ve başlangıç doğrulamasının ilk küçük uygulama adımı anlatılır. Envanter sırasında Compose, `.env`, user-secrets ve Docker kaynakları değiştirilmedi. İnceleme öncesinde Git çalışma alanı temizdi. Yerel `.env` vardı, `.gitignore` tarafından yok sayılıyordu ve `git ls-files` içinde değildi. Backend projesinin `UserSecretsId` tanımı ve bu projeye ait yerel user-secrets dosyası vardı; yalnızca anahtar adları incelendi. `dotnet user-secrets list`, düz `docker compose config` ve tam `docker inspect` çıktıları değer gösterebileceğinden çalıştırılmadı.

## 1. Gerçek configuration envanteri

`:` .NET anahtar ayıracıdır; process environment içindeki `__` aynı hiyerarşiye dönüştürülür. **Zorunlu** sütunu mevcut başlatma/Compose tanımı açısından değerlendirilmiştir. “Local” host üzerinde çalıştırılan API'yi; “container” mevcut Compose akışını anlatır. Local `.env` dosyası tek başına .NET host API'sine yüklenmez.

| Key | Kullanan servis | Kaynak | Secret mı? | Zorunlu mu? | Varsayılan var mı? | Local değer kaynağı | Container değer kaynağı |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `ConnectionStrings:Postgres` / `ConnectionStrings__Postgres` | API, PostgreSQL readiness | `Program.cs`, health check | **Evet**, mevcut bağlantı dizesi credential içerir | Evet; eksikse API açılmaz | Yok | Backend user-secrets; daha yüksek öncelikli process environment ezebilir | Compose `environment`, `POSTGRES_*` değişkenlerinden oluşturulur |
| `ConnectionStrings:Redis` / `ConnectionStrings__Redis` | API, Redis cache | `Program.cs` | Compose'da parolasız adres secret değil; local değerin içeriği incelenmedi | Evet; eksikse API açılmaz | Yok | Backend user-secrets; process environment ezebilir | Compose `environment`; `redis` servis adı ve iç portu |
| `Cache:TasksTtlSeconds` / `Cache__TasksTtlSeconds` | API | `Program.cs` | Hayır | Hayır; pozitif olmalı | Kodda `60`; Compose'da da `60` fallback | Kod varsayılanı veya açık process environment; `.env` otomatik yüklenmez | Compose `.env` substitution → API `environment` |
| `ASPNETCORE_ENVIRONMENT` | API host | `launchSettings.json`, Compose | Hayır; ortam davranışını etkiler | Localde hayır; Compose'da `${...:?}` ile evet | .NET host varsayılanı `Production` | `dotnet run` http launch profili `Development` ayarlar; process environment/profil seçimi etkiler | Compose `.env` substitution → API `environment` |
| `ASPNETCORE_HTTP_PORTS` | API host | Backend Dockerfile, Compose | Hayır | Hayır | Dockerfile'da `8080`; Compose aynı değeri açıkça verir | `launchSettings.json` uygulama URL'si kullanılır | Dockerfile `ENV`, Compose `environment` tarafından aynı iç portla ayarlanır |
| `POSTGRES_USER` | PostgreSQL image; Compose interpolation | `compose.yaml` | Genelde hayır; hesap adı altyapı bilgisidir | Compose'da evet | Yok | Host PostgreSQL lab container'ı hazırlanırken açıkça verilir; API bu anahtarı doğrudan okumaz | `.env` → PostgreSQL `environment`, ayrıca API bağlantı dizesinin kullanıcı alanı ve `pg_isready` |
| `POSTGRES_DB` | PostgreSQL image; Compose interpolation | `compose.yaml` | Genelde hayır; veritabanı adı altyapı bilgisidir | Compose'da evet | Yok | Local PG lab hazırlığında verilir | `.env` → PostgreSQL `environment`, ayrıca API bağlantı dizesinin DB alanı ve `pg_isready` |
| `POSTGRES_PASSWORD` | PostgreSQL image; Compose interpolation | `compose.yaml` | **Evet**, development secret | Compose'da evet | Yok | Local PG rolünün credential'ı; host API tam bağlantı dizesini ayrı user-secrets'tan okur | `.env` → PostgreSQL `environment` ve API'nin oluşturulan bağlantı dizesi |
| `Logging:LogLevel:Default` | API logging | İki `appsettings` dosyası | Hayır | Hayır | Her iki dosyada `Information` | JSON; process environment ile ezilebilir | Publish edilen JSON; API environment ile ezilebilir |
| `Logging:LogLevel:Microsoft.AspNetCore` | API logging | İki `appsettings` dosyası | Hayır | Hayır | Her iki dosyada `Warning` | JSON; process environment ile ezilebilir | Publish edilen JSON; API environment ile ezilebilir |
| `AllowedHosts` | ASP.NET Core host filtering | `appsettings.json` | Hayır | Hayır | Mevcut dosyada `*` | JSON | Publish edilen JSON |

Yerel `.env` dosyasında yalnız anahtar adları olarak `ConnectionStrings__Postgres`, `ConnectionStrings__Redis`, `POSTGRES_USER`, `POSTGRES_DB`, `POSTGRES_PASSWORD`, `Cache__TasksTtlSeconds` ve `ASPNETCORE_ENVIRONMENT` bulundu. İlk iki anahtar `.env.example` içinde de bulunur, fakat **mevcut Compose YAML'i bunları okumaz**. Bunların `.env` içinde yazılı olması host API için de otomatik kaynak oluşturmaz. Bu yüzden `.env` ile user-secrets arasında değer ayrışması mümkündür. Anahtarların değerleri ve iki kaynağın eşitliği bu incelemede sınanmadı.

Statik, environment key'i **olmayan** ayarlar da önemlidir:

| Statik ayar | Mevcut davranış |
| --- | --- |
| Frontend API yolu | `src/frontend/src/api/tasks.ts` içinde göreli `/api/tasks`; frontend için API base URL env anahtarı yok. |
| Vite development proxy | `vite.config.ts` içinde `/api` → host API `127.0.0.1:5162`; build-time `VITE_*` kullanımı bulunmadı. |
| Nginx upstream | `nginx.conf` içinde `/api/` → Compose servis DNS'i `api:8080`; image'a statik kopyalanır, env ile değişmez. |
| Local API launch URL | Backend `launchSettings.json` http profilinde `localhost:5162`; Compose API'sinin host portu değildir. |
| Host ve iç portlar | Compose yalnız frontend'i `127.0.0.1:18081:80` olarak yayınlar. API `8080`, PostgreSQL `5432`, Redis `6379` yalnız ağ içindedir. Ayrı eski local lablarda PG `127.0.0.1:15432:5432`, Redis `127.0.0.1:16379:6379` idi. |
| Healthcheck ayarları | Compose'da probe komutları, `interval`, `timeout`, `retries`, `start_period` statiktir. API probe'u `/health/ready` için HTTP 200 arar; PostgreSQL `pg_isready`, Redis `redis-cli ping`, frontend `wget /` kullanır. Backend readiness dependency check'leri kodda 2 saniye timeout ile kayıtlıdır. |
| `UserSecretsId` | Backend proje dosyasında public bir proje kimliği; secret değeri değildir ve kullanıcı profilindeki ilgili store'u seçer. |

Şartnamedeki `REDIS_CONNECTION` ve Grafana örnek anahtarları mevcut dört servisli uygulamada kullanılmıyor; bu nedenle gerçek key envanterine eklenmedi. Eski lab belgelerindeki geçici `Logging__EventLog__LogLevel__Default` ayarı da mevcut Compose veya API konfigürasyonuna ait değil.

## 2. Kaynaklar ve öncelik

Backend `WebApplication.CreateBuilder(args)` varsayılanlarını kullanır; özel configuration provider eklemez. **Application configuration** için yüksekten düşüğe sıra: komut satırı argümanları → `ASPNETCORE_`/`DOTNET_` öneki olmayan process environment değişkenleri → yalnız `Development` ortamındaki user-secrets → `appsettings.{Environment}.json` → `appsettings.json` → host configuration fallback. `ASPNETCORE_ENVIRONMENT` gibi host kurulumu için erken okunan değerler ayrı host configuration davranışına sahiptir; `launchSettings.json` bir `dotnet run` launch profili olarak process ortamı ve URL ayarlar. Bu ayrım ve sıralama [Microsoft'un ASP.NET Core configuration belgesinde](https://learn.microsoft.com/en-us/aspnet/core/fundamentals/configuration/?view=aspnetcore-10.0) açıklanır.

| Kaynak | Bu projedeki rol |
| --- | --- |
| `appsettings.json` | Logging düzeyleri ve `AllowedHosts`; credential içermez. |
| `appsettings.Development.json` | Development logging düzeylerini tanımlar; credential içermez. Aynı key için temel JSON'u ezer. |
| Backend user-secrets | Development modunda local API'nin PostgreSQL ve Redis bağlantı anahtarlarını repository dışında sağlar; JSON'dan önceliklidir, process environment tarafından ezilebilir. |
| Process environment | Host API'de `ConnectionStrings__...` ve `Cache__...` gibi anahtarları sağlayabilir; `__`, `:` olur. Compose API container'ında değerler burada yer alır. |
| Compose `.env` / `--env-file` | `${...}` ifadelerini çözmek için **Compose CLI** tarafından okunur. Shell değişkenleri interpolation'da dosyadan yüksek önceliklidir. Bu dosyadaki her anahtar container'a otomatik aktarılmaz. |
| Compose service `environment` | Çözülmüş değerleri seçilen container process environment'ına geçirir. API ve PostgreSQL için açık alanlar vardır; Redis ve frontend için bu dosyada `environment` bloğu yoktur. |
| `.env.example` | Git'te izlenen örnek ve placeholder sözleşmesi; tek başına API veya container'a değer vermez. Parola ve bağlantı placeholder'ları açıkça `<set-outside-git>` biçimindedir. |
| Dockerfile `ENV` | Yalnız backend final image'ında secretsız `ASPNETCORE_HTTP_PORTS` varsayılanı var. Frontend Dockerfile'ında `ENV` yok; iki Dockerfile'da da `ARG` yok. |
| Vite build-time environment | Projede özel `VITE_*` anahtarı veya `import.meta.env` okuması yok. Bir gün eklenirse `VITE_*` değerleri browser bundle'ına gömülebilir; secret burada tutulmamalı. |
| Nginx statik dosyası | `api:8080` upstream ve port 80 image içine kopyalanır; Compose `.env` tarafından template olarak işlenmez. |

**İki ayrı işlem:** `.env` içindeki `POSTGRES_PASSWORD` önce Compose tarafından YAML'deki `${POSTGRES_PASSWORD}` yerine konur. Yalnız `environment` alanına yazılmış sonuç PostgreSQL/API process environment'ına geçer. `.env` içindeki kullanılmayan `ConnectionStrings__...` anahtarları container'a aktarılmaz. Docker'ın [interpolation](https://docs.docker.com/compose/how-tos/environment-variables/variable-interpolation/) ve [container environment](https://docs.docker.com/compose/how-tos/environment-variables/set-environment-variables/) belgeleri bu farkı doğrular. `docker compose config` çözümlenmiş değeri gösterebilir; değer paylaşmadan yalnız `config -q` kullanılmalıdır.

## 3. Local host ve Compose akışları

**Local host:** `dotnet run` http profili API'yi Development modunda `localhost:5162` adresinde başlatır. Backend proje dosyasının `UserSecretsId` kimliğiyle eşleşen yerel store'da `ConnectionStrings:Postgres` ve `ConnectionStrings:Redis` anahtarları bulunduğu, değerleri gösterilmeden doğrulandı. İlk anahtar geçmiş local lab düzeninde localhost PostgreSQL `15432` hedefine, ikincisi localhost Redis `16379` hedefine yönelir; **mevcut değerlerin hedefleri bu görevde okunup doğrulanmadı**. Bu akış için uygun PostgreSQL ve Redis container'ları ayrı kontrollü lab komutlarıyla, yalnız localhost portlarında çalıştırılmalı; mevcut named volume ve credential uyumu önceden kontrol edilmelidir. Container başlatma bu envanterde yapılmadı. User-secrets Git'e girmez; şifreli production vault değildir. [Microsoft'un Secret Manager belgesi](https://learn.microsoft.com/en-us/aspnet/core/security/app-secrets?view=aspnetcore-10.0) store'un geliştirme amaçlı ve şifresiz olduğunu belirtir.

**Compose:** `.env`, `POSTGRES_USER`, `POSTGRES_DB`, `POSTGRES_PASSWORD`, `ASPNETCORE_ENVIRONMENT` ve isteğe bağlı TTL değişkenlerinin substitution kaynağıdır. PostgreSQL container'ına yalnız üç `POSTGRES_*` anahtarı geçer. API container'ına environment adı, HTTP iç portu, oluşturulan PostgreSQL bağlantı dizesi, Redis servis adresi ve cache TTL geçer. Redis container'ına bu tanımda secret verilmez; Redis iç ağda parolasızdır. API, PostgreSQL'e `postgres:5432`, Redis'e `redis:6379`; frontend Nginx API'ye `api:8080` üzerinden ulaşır. Host'ta yalnız frontend `127.0.0.1:18081` yayınlanır. Boş olmayan mevcut external volume, API başlamadan önce uygulanmış migration ve mevcut rol credential'ıyla uyum gerektirir. `POSTGRES_PASSWORD` değerini `.env` içinde değiştirmek dolu volume içindeki PostgreSQL rolünün parolasını değiştirmez.

## 4. Secret sınıflandırması

| Sınıf | Mevcut örnek ve gerekçe |
| --- | --- |
| Public configuration | Frontend'in göreli `/api/tasks` yolu, health route adları, `UserSecretsId`, örnek dosyadaki key adları; bunlar erişim yetkisi vermez. |
| Environment-specific non-secret configuration | PostgreSQL kullanıcı/veritabanı adları, Redis'in şu anki parolasız adresi, TTL, `ASPNETCORE_ENVIRONMENT`, portlar, Vite proxy hedefi, Nginx upstream, logging/host ayarları. Altyapı topolojisini anlattıkları için yine de gereksiz yere paylaşılmamalıdır. |
| Development secret | Yerel PostgreSQL parolası ve credential taşıyan tam PostgreSQL bağlantı dizesi; user-secrets ile Git dışı `.env` ayrı düz metin kopyalar tutabilir. |
| Production secret adayı | Production PostgreSQL credential'ı; ileride Redis kimlik doğrulaması eklenirse Redis bağlantı dizesinin credential alanı. Bir connection string'in kendisi her zaman secret değildir; içindeki parola ve hassas endpoint bilgisi belirleyicidir. |
| Generated/runtime value | Geçici container ID/IP, Docker health durumu ve Redis key TTL değeri; bunlar uygulama configuration key'i değildir. |

## 5. Olası secret exposure yüzeyleri

| Yüzey | Mevcut koruma | Kalan risk |
| --- | --- | --- |
| Git tracked dosyaları | `.env` ve `.env.*` yok sayılır; `.env.example` placeholder taşır; mevcut taramada gerçek credential adayı bulunmadı. | Zorla `git add -f` veya başka dosyaya kopyalama yine mümkündür. |
| Git geçmişi | Bu görev yalnız güncel çalışma ağacını taradı. | Önceki commit'ler için sızıntı yokluğu ileri sürülemez; tam geçmiş ayrıca taranmadı. |
| Yerel `.env` | Git dışında. | Düz metin; dosya erişimi, yedekleme veya yanlış paylaşım riski sürer. |
| User-secrets ve `appsettings*` | Gerçek user-secrets proje ağacı dışında; mevcut JSON dosyalarında credential yok. | User-secrets şifresizdir; JSON'a gelecekte parola yazılırsa Git ve image'a girebilir. |
| Dockerfile, build context ve image history | `ARG` yok; tek `ENV` port ayarıdır. İki build context'i root `.env` dışında; iki `.dockerignore` da `.env`/`.env.*` dışlar. | `COPY .` içindeki başka secret dosyaları veya gelecekte eklenen `ARG`/`ENV` image katmanlarına/metadata'ya sızabilir. Build context filtresi tek başına tüm secret türlerini tanımaz. |
| Container environment ve `docker inspect` | Compose yalnız gereken servis alanlarını geçirir; PostgreSQL/API host portu yayınlamaz. | Docker erişimi olan kullanıcı çözümlenmiş PostgreSQL parolasını ve API bağlantı dizesini inspect ile görebilir. |
| `docker compose config` | İncelemede düz config basılmadı; `config -q` güvenli statik doğrulama yoludur. | Tam çözülmüş çıktı terminale, CI loguna veya ekran görüntüsüne alınırsa secret açığa çıkabilir. |
| Process list / command arguments | Mevcut Dockerfile ve Compose komutları parola literal'i içermez; scriptler çoğunlukla env veya stdin kullanır. | Secret'ı CLI argümanına geçirmek process listesi ve shell history'de görünebilir. |
| Application logs ve exception mesajları | Health yanıtları genel `Healthy`/`Unhealthy`; mevcut cache logları yalnız key/hit/miss bilgisi verir. | Provider/başlatma/bağlantı hatalarının logları otomatik olarak tamamen redakte edildiği doğrulanmadı; paylaşmadan inceleme gerekir. |
| Test scriptleri, README, CI logu, ekran görüntüsü | Mevcut scriptler secret değeri yazdırmak için tasarlanmamış; README'lerde placeholder/komut şablonu var. | Debug çıktısı, `user-secrets list`, `compose config`, tam inspect veya görüntü yakalama gerçek değeri kaydedebilir. CI akışı bu görevde incelenmedi. |

Docker, secret'ların Dockerfile `ARG`/`ENV` ile build'e geçirilmesini önermez; bunlar image ve metadata'ya sızabilir ([Docker build variables](https://docs.docker.com/build/building/variables/)). Burada yeni secret mekanizması eklenmedi. Runtime environment da production secret vault yerine geçmez.

## 6. Güvenli repository taraması

`git ls-files` ile izlenen dosyalar ve `git ls-files --others --exclude-standard` ile yeni dosyalar listelendi; yeni dosya yoktu. Değerleri yazdırmadan parola ataması, `Password=`, `Pwd=`, tamamlanmış `Host=...;...Password=` ve yaygın API token biçimleri arandı. Eşleşmeler `.env.example` placeholder'ları, `compose.yaml` değişken şablonları, şartnamedeki boş örnek ve lab belgelerindeki değişkenli komutlardı. Gerçek parola/token veya placeholder olmayan tamamlanmış bağlantı dizesi adayı bulunmadı. `Password=` metninin tek başına sızıntı sayılmadığı özellikle kontrol edildi. `.env.example` içindeki secret alanları açık `<set-outside-git>` placeholder'ıdır. Bu, düzenli bir secret scanner veya **tüm Git geçmişi** denetimi yerine geçmez; ignored yerel `.env` değerleri kasıtlı olarak tarama çıktısına alınmadı.

## 7. Temiz bilgisayar / onboarding eksikleri

Yeni geliştirici Docker Engine, .NET 10 SDK ve Node/npm kurmalı; frontend için `npm ci` kullanmalı. Compose için `.env.example` temel alınarak Git dışında gerçek `.env` hazırlanmalı, özellikle PostgreSQL credential'ı var olan volume ile uyumlu olmalı. `fullstack-ops-postgres-data` external volume'u önceden oluşturulmalı veya veri geri yüklenmeli; boş volume için `InitialCreate` migration'ı API Task trafiğinden **önce açıkça** uygulanmalı. Host üzerinde ayrı API çalıştırılacaksa backend proje user-secrets'ında iki bağlantı anahtarı ayrıca ayarlanmalı ve localhost PG/Redis lab portları hazırlanmalı. Yalnız Compose kullanılırsa user-secrets gerekli değildir; Compose bunları okumaz. Hazırlıklardan sonra güvenli statik kontrol `docker compose --env-file .env config -q`, ardından mevcut stack'i başlatma komutu `docker compose --env-file .env up -d --build --wait` olur. Bu komutlar bu görevde çalıştırılmadı.

Tamamen tek komutla temiz kurulum henüz yoktur: external volume yeni makinede bulunmaz, credential oluşturma/rol uyumu ve migration açık operatör adımlarıdır. `.env.example` host bağlantı placeholder'ları ile Compose substitution anahtarlarını birlikte taşıdığı için ayrıca açıklama ister. Önceki Modül 7 belgelerinde bu sınırlar ayrıntılıdır.

## 8. Öncelikli riskler

| Risk | Olasılık | Etki | Mevcut koruma | Önerilen sonraki işlem |
| --- | --- | --- | --- | --- |
| `.env` yanlışlıkla commit edilir | Orta | Yüksek | `.gitignore`, `git ls-files` kontrolü | Düzenli secret leakage kontrolü; stage diff'i inceleme |
| `docker compose config` çıktısı paylaşılır | Orta | Yüksek | `config -q` alışkanlığı | Komut örneklerini ve CI log politikasını açık belgelemek |
| Secret `docker inspect` ile görünür | Orta | Yüksek | İç servis portları yayınlanmaz; bu inspect erişimini engellemez | Production secret yaklaşımını ayrıca tasarlamak; Docker erişimini sınırlamak |
| Gerçek parola `appsettings*` içine yazılır | Orta | Yüksek | Şu an credential yok, user-secrets var | Config contract ve sızıntı regresyon kontrolü |
| Build sırasında secret image'a girer | Düşük | Yüksek | Build context'ler sınırlı, `.dockerignore` env dosyalarını dışlar, secret `ARG` yok | Build girdileri ve image metadata'sı için ayrı denetim planı |
| Connection string loglara düşer | Orta | Yüksek | Health yanıtları genel, mevcut kod değer loglamıyor | Hata/log redaksiyonunu kontrollü senaryoda test etmek |
| Temiz makinede external volume eksik | Yüksek | Orta | Compose açık `external: true` ile eksikliği hata olarak bildirir | Bootstrap rehberi ve migration kapısı hazırlamak |
| User-secrets ve Compose `.env` ayrışır | Orta | Orta | Key adları belgeli; Compose gerekli substitution anahtarlarını kontrol eder | İki akışı ayrı onboarding adımlarıyla tarif etmek, credential eşleşmesini güvenli doğrulamak |
| `.env` parolası değişir ama mevcut PG rolü değişmez | Orta | Yüksek | Module 3 lab belgeleri initialized volume davranışını açıklar | Yetkili ve güvenli rol parola güncelleme prosedürü belgelemek |

Olasılık/etki dereceleri bu yerel eğitim projesi için **nitel tahmindir**; olay veya sızıntı tespiti değildir.

## 9. Küçük Module 9 uygulama planı

1. **İlk küçük adım — configuration contract ve startup validation:** Mevcut bağlantı/TTL kontrollerini temel alarak host ve Compose için zorunlu anahtarları, boş/uygunsuz değer davranışını ve secret göstermeyen hata mesajlarını ayrı testlerle netleştir. Uygulama ve doğrulama 10. bölümde.
2. Güvenli local `.env` onboarding: host user-secrets ve Compose `.env` yollarını ayıran, değer yazdırmayan yönergeleri düzenle.
3. Secret leakage regression check: tracked/yeni dosyalar için placeholder ayıran, değeri loglamayan kontrol ekle.
4. Clean-machine bootstrap dokümantasyonu: external volume, credential uyumu ve `InitialCreate` migration sırasını tekrarlanabilir şekilde anlat.
5. Production secret yaklaşımını yalnız tasarla: runtime secret kaynağı, Docker erişimi, rotasyon ve log sınırları; bu yerel labda yeni çözüm kurma.

Envanter görevi sırasında bu adımlar uygulanmamıştı. Şimdi yalnız ilk küçük adım tamamlandı; Module 9'un diğer adımları açık.

## 10. Configuration contract ve başlangıç doğrulaması

API, `WebApplication.CreateBuilder` sonrasında üç değeri `ApiConfiguration.Read` ile **başlangıçta**, ağa bağlanmadan denetler. `ValidateOnStart` yerine mevcut üç değeri kullanan tek küçük doğrulama nesnesi seçildi; ayrıca options paketi, servis katmanı veya ikinci bir okuma yolu gerekmedi. Değerler yine önceki configuration kaynaklarından ve aynı anahtarlardan gelir. Program bu nesnedeki doğrulanmış değerleri EF Core, Redis cache ve Task listesi TTL ayarına geçirir.

| Anahtar | Kabul edilen değer | Yoksa | Açıkça geçersizse |
| --- | --- | --- | --- |
| `ConnectionStrings:Postgres` | Npgsql parser'ının kabul ettiği bağlantı dizesi; host, database ve username dolu | Başlangıç durur | Boş/whitespace, parser hatası veya gerekli alan eksikliği başlangıcı durdurur |
| `ConnectionStrings:Redis` | StackExchange.Redis parser'ının kabul ettiği ve en az bir endpoint içeren dize; parolasız local adres geçerli | Başlangıç durur | Boş/whitespace, parser hatası veya endpoint eksikliği başlangıcı durdurur |
| `Cache:TasksTtlSeconds` | Pozitif tamsayı | **60 saniye** | Açık boşluk, `abc`, `0` ve negatif değer başlangıcı durdurur; sessiz fallback veya keyfi üst sınır yok |

PostgreSQL parolası veya TLS bu adımda zorunlu kılınmadı. Ayrıştırıcılar biçimi kontrol eder; erişilebilirlik veya credential doğruluğu için bağlantı açmaz. Böylece doğru biçimli ayarlarla PostgreSQL/Redis kapalı olsa da API başlar: `/health/live` **200**, `/health/ready` **503**. Yanlış anahtar veya biçim ise daha önce, startup sırasında hata verir. Bu iki hata türünün çözümleri farklıdır: önce configuration anahtarını düzeltmek ya da çalışan dependency'yi geri getirmek.

Başlangıç hatası yalnız anahtarı söyler: `ConnectionStrings:Postgres eksik veya geçersiz.`, `ConnectionStrings:Redis eksik veya geçersiz.` veya `Cache:TasksTtlSeconds pozitif bir tamsayı olmalı.` Parser'ın exception mesajı ve iç exception dışarı aktarılmaz. Bağlantı dizesi, parola ve token hata metnine eklenmez. Bu kontrol loglama ve Docker ortam değişkenleri gibi diğer secret yüzeylerinin tamamını ortadan kaldırmaz.

`dotnet build src/backend/FullStackOpsLab.Api/FullStackOpsLab.Api.csproj -c Release` sonrasında `powershell -NoProfile -ExecutionPolicy Bypass -File tests/Module9.Configuration.Smoke.ps1` çalıştırılır. Test, gerçek `.env` veya user-secrets değerlerine dokunmadan Production alt süreçleri ve rastgele **sahte** canary kullanır; eksik/boş/bozuk bağlantıları, TTL sınırlarını, başarılı başlangıcı ve kapalı bağımlılıklarda readiness sonucunu sınar. Her negatif vakada nonzero exit code **ve** beklenen güvenli anahtar mesajı birlikte aranır; stdout/stderr içinde canary veya tam test bağlantı dizesi bulunmamalıdır. Windows test hesabında Event Log yazma yetkisi olmadığı için yalnız test alt sürecinin Event Log sağlayıcısı kapatılır. Beklenen yakalanmamış startup exception'ının hata penceresini önlemek için test runner'ın process error mode'u sadece child process başlatılırken ayarlanıp hemen geri alınır; sistem ayarları değişmez.

Gerçek doğrulamada Release build **0 uyarı / 0 hata**, 20 izole startup senaryosu **20/20**, `docker compose --env-file .env config -q` ve Compose runtime regresyonu **başarılı** oldu. Negatif testler `0xE0434352` çıkışıyla kapandı; her birinin stderr'inde beklenen güvenli ayar mesajı bulundu, stdout boştu ve canary iki çıktı akışında da yoktu. İzole geçerli ayarlarda `/health` ve `/health/live` **200**, boş başlıklı Task POST **400**, kapalı bağımlılıklarda `/health/ready` **503** döndü. Windows Event Log izni için yalnız test sürecindeki logging ayarı kullanıldı. `dotnet test` solution'da test projesi olmadığı için test yürütmedi; başarı kanıtı çalışan PowerShell smoke testleri ve gerçek HTTP/Redis sonuçlarıdır.

Compose öncesi projeye ait container yoktu; mevcut external `fullstack-ops-postgres-data` volume'u korundu. `docker compose --env-file .env up -d --build --wait --wait-timeout 180` güncel iki image'ı build etti ve `frontend`, `api`, `postgres`, `redis` servislerinin dördü de **running/healthy** oldu. Test başlangıcında `tasks` tablosu boştu, `lab_tasks` içinde **1** kayıt ve `__EFMigrationsHistory` içinde **1** kayıt vardı. Nginx `127.0.0.1:18081` üzerinden `tests/Phase0B.Tasks.Smoke.ps1 -BaseUrl http://127.0.0.1:18081` GET **200**, POST **201** ve Location, PUT **200**, DELETE **204**, geçersiz başlık **400** ve bulunmayan ID **404** sonuçlarıyla geçti. Ek gerçek HTTP kontrolünde `id`, `title`, `description`, `isCompleted`, `createdAt`, `updatedAt` alanları ve oluşturma/güncellemede nullable `description` korundu; bu kontrolün ilk denemesinde yalnız PowerShell alan karşılaştırması hatalıydı, test Task'ı temizlenip düzeltilen kontrol geçti. Uygulama kodu değişmedi.

Mevcut `tests/Module5.Cache.Smoke.ps1` scripti Compose'a ait container adları ve Nginx URL'si parametre verilerek çalıştırıldı; host lab varsayılanları kullanılmadı. Boş listenin ilk GET'i **miss** ile key oluşturdu, Redis `TTL` **60 saniye** döndürdü; çözümlenmiş Compose yapılandırmasının yalnız TTL alanı bellekte karşılaştırıldı ve **60 saniye** ile eşleşti, secret değerleri yazdırılmadı. PostgreSQL dururken ikinci GET **200** ile cache hit olduğunu kanıtladı. Dolu liste de cache'lendi. POST/PUT/DELETE sonrasında key kaldırıldı; geçersiz POST **400** ve bulunmayan PUT/DELETE **404** key'i kaldırmadı. Gerçek TTL dolunca key kayboldu ve sonraki GET tekrar doldurdu. Script kendi test Task'ını ve cache key'ini temizledi. API loglarında güvenli event sayımı **10 miss**, **3 hit**, **11 invalidation** gösterdi; log içeriği ve connection değerleri dışarı yazdırılmadı.

Mevcut `tests/Module8.Readiness.Smoke.ps1` doğrudan Compose topolojisinde geçti. Normalde `/health`, `/health/live`, `/health/ready` **200** ve Docker API health **healthy** idi. Redis ve PostgreSQL ayrı ayrı durdurulduğunda aynı API container'ı **running** kaldı; live **200**, ready **503**, Docker health **unhealthy** ve Task GET **500** oldu. PostgreSQL kesintisinden önce liste cache'i temizlendi; GET böylece gerçek DB okumasını sınadı. Her bağımlılık geri geldiğinde aynı API container'ı ready **200** ve healthy durumuna döndü. `tests/Module3E.Persistence.Smoke.ps1` host portu ve yerel Development/user-secrets akışı için olduğundan Compose'a körlemesine uygulanmadı.

Son kontrolde `tasks` **0**, `lab_tasks` **1**, migration history **1** ve Task listesi Redis key'i **yok** idi. `docker compose --env-file .env down` yalnız dört test container'ını ve proje ağını kaldırdı; `down -v` kullanılmadı. Sonra bu projeye ait container/ağ sayısı **0**, external volume mevcut ve ilgisiz **12** container yerinde kaldı. `.env` ve user-secrets değiştirilmedi. Module 9'un sonraki küçük adımları henüz uygulanmadı.

Ayrıştırıcı seçimleri: [Npgsql bağlantı parametreleri](https://www.npgsql.org/doc/connection-string-parameters) ve [StackExchange.Redis configuration biçimi](https://github.com/StackExchange/StackExchange.Redis/blob/main/docs/Configuration.md). Test sürecindeki Windows hata modu davranışı [Microsoft SetErrorMode belgesine](https://learn.microsoft.com/en-us/windows/win32/api/errhandlingapi/nf-errhandlingapi-seterrormode) dayanır.

## 11. Güvenli yerel `.env` hazırlığı ve preflight

Bu küçük adım yalnızca Compose başlamadan önce dosyanın **statik** denetimidir. Script uygulamayı, container'ı, ağı veya volume'u başlatmaz; migration uygulamaz; dosyayı değiştirmez. Gereken yazılımlar Git, Docker CLI/Compose ve çalışan Docker Engine'dir. Host üzerinde API çalıştırma yolu ayrıdır.

### Compose için adım adım

1. Repository kökünde `.env.example` dosyasını `.env` olarak kopyala. Var olan `.env` dosyasının üzerine yazma. Örnek dosyadaki `<set-outside-git>` değerlerini kullanma; gerçek yerel değeri yalnız Git dışındaki `.env` içinde ayarla. Bu belge parola örneği vermez.
2. `POSTGRES_USER`, `POSTGRES_DB`, `POSTGRES_PASSWORD` ve `ASPNETCORE_ENVIRONMENT` alanlarını doldur. `Cache__TasksTtlSeconds` isteğe bağlıdır; varsa pozitif tamsayı olmalıdır. `ConnectionStrings__Postgres` ve `ConnectionStrings__Redis` örnekte host geliştirme anahtarlarını göstermek için bulunur; mevcut `compose.yaml` bunları kullanmaz. Compose, API bağlantılarını kendi servis adları ve `POSTGRES_*` alanlarıyla kurar.
3. Git dışı kalma durumunu ve statik ayarları `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/Module9.EnvPreflight.ps1` komutuyla kontrol et. Komut yalnız sonuç ve sorunlu **anahtar adlarını** gösterir. `.env` yoksa örnekten nasıl hazırlanacağını söyler; var olan dosyayı kopyalamaz veya yazmaz. İstersen izole, Git tarafından yok sayılan bir fixture için `-EnvFile .env.fixture` kullanabilirsin.
4. Preflight geçtikten sonra external `fullstack-ops-postgres-data` volume'unun veri durumunu ve credential uyumunu ayrıca değerlendir. Yeni bilgisayarda volume'u ayrıca hazırlamak gerekir. Boş database için `InitialCreate` migration'ı Task trafiğinden önce ayrıca uygulanır. Çalıştırma adımları [Compose laboratuvarında](../07-docker-compose/README.md) anlatılır. Temiz bilgisayarda tek komutla kurulum doğrulanmış değildir.

Preflight, `.env` yolunun repository içinde olmasını, Git tarafından yok sayılmasını ve takip edilmemesini kontrol eder. Gerekli dört alan için eksik/boş/whitespace ve yaygın örnek placeholder biçimlerini reddeder; açıkça verilen geçersiz TTL'yi reddeder. Ardından `docker compose --env-file .env config -q` eşdeğerini **çözülmüş çıktıyı göstermeden** çalıştırır ve `docker volume inspect fullstack-ops-postgres-data` ile yalnız volume varlığını kontrol eder. Secret, connection string, `docker compose config` çıktısı ve Docker hata ayrıntıları terminale basılmaz. Yanlış/eksik anahtar adları gösterilir; bağlantı gerçekten açılmaz.

Script `.env` satırlarını kendi basit ayrıştırıcısıyla okumaz. Önce yalnız gereken anahtarları içeren geçici Compose tanımını **stdin** üzerinden Compose'a verir; Compose'un kendi `.env` quoting/interpolation çözümlemesini bellekte inceler. Bu nedenle tek/çift tırnak, yorum ve `${VAR}` davranışı Compose'un desteklediği kadardır ([Docker env-file sözdizimi](https://docs.docker.com/compose/how-tos/environment-variables/variable-interpolation/)). Destek sınırı Docker Compose'un kabul ettiği `.env` biçimidir; key adları mevcut `compose.yaml` sözleşmesiyle sınırlıdır. Bu bir genel amaçlı secret kalitesi denetleyicisi değildir. Required key'ler ve TTL için aynı isimli process environment değişkenleri kontrol sırasında çıkarılır; aksi halde shell değişkeni `.env` eksiğini gizleyebilirdi. Diğer değişkenlere referans veren Compose interpolation yine Compose tarafından çözümlenir. `config -q` yalnız sözdizimi/çözümlemeyi doğrular ([Docker Compose config](https://docs.docker.com/reference/cli/docker/compose/config/)).

**Parola ve volume sınırı:** Boş PostgreSQL volume'unda `POSTGRES_PASSWORD` ilk kullanıcı parolasını oluşturur. Daha önce initialize edilmiş volume'da `.env` parolasını değiştirmek mevcut PostgreSQL rol parolasını değiştirmez. API'nin kullandığı parola mevcut rol parolasıyla eşleşmelidir. Bu preflight ne parola eşleşmesini ne PostgreSQL/Redis erişilebilirliğini veya database readiness'i kanıtlar. Mevcut `.env` ile user-secrets arasında otomatik eşitleme/rotation yapmaz.

**Host API yolu:** Backend projesinin `dotnet user-secrets` kaynağındaki `ConnectionStrings:Postgres` ve `ConnectionStrings:Redis` anahtarları kullanılır; uygun localhost PostgreSQL ve Redis servisleri ayrıca hazırlanır. `.env` dosyası tek başına host .NET sürecine yüklenmez. **Compose yolu:** Compose `.env` dosyasını önce YAML placeholder'ları için okur, `environment` alanıyla ilgili değerleri container süreçlerine geçirir. Compose user-secrets dosyasını otomatik okumaz. `docker compose config` komutunu `-q` olmadan paylaşma; çözülmüş secret değerlerini gösterebilir.

İzole test komutu: `powershell -NoProfile -ExecutionPolicy Bypass -File tests/Module9.EnvPreflight.Smoke.ps1`. Gerçek testte 7/7 fixture geçti: dosya yokluğu, eksik/boş/placeholder zorunlu alan, geçerli sahte alanlar, çift tırnak içinde Compose interpolation ve boş opsiyonel TTL. Her fixture'ın hash'i aynı kaldı; canary değer test çıktısına sızmadı ve gerçek `.env` dosyasının hash'i değişmedi. Gerçek `.env` için salt okunur preflight geçti: Git dışı durum, dört gerekli alan, `config -q` ve external volume varlığı doğrulandı. Kullanılan Docker Engine erişimi bu ortamda ek izin gerektirdi; script Docker kaynağı değiştirmedi. User-secrets değerleri okunmadı veya değiştirilmedi.

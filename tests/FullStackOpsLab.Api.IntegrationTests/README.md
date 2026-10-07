# Backend integration testleri

Bu küçük suite, şartnamenin [22. bölümündeki](../../PROJECT_SPEC.md#22-testing-stratejisi) endpoint testlerini karşılar. xUnit, gerçek ASP.NET Core pipeline'ını `WebApplicationFactory`/`TestServer` ile çalıştırır. EF Core/Npgsql ve Redis client değiştirilmez; Testcontainers gerçek PostgreSQL ve Redis sağlar. HTTP istekleri TestServer'a gider; Nginx, tarayıcı ve container içindeki API bu suite'in kapsamı değildir.

## Çalıştırma

Repository kökünde .NET 10 SDK, erişilebilir **Linux Docker Engine**, ilk restore için NuGet ve image registry erişimi gerekir. Compose stack'ini başlatmak, `.env` hazırlamak veya user-secrets tanımlamak gerekmez.

```powershell
dotnet test FullStackOpsLab.slnx --configuration Release --blame-hang-timeout 3m --blame-hang-dump-type none
```

Yalnız test projesi veya Docker gerektirmeyen startup alt kümesi:

```powershell
dotnet test tests/FullStackOpsLab.Api.IntegrationTests/FullStackOpsLab.Api.IntegrationTests.csproj --configuration Release
dotnet test tests/FullStackOpsLab.Api.IntegrationTests/FullStackOpsLab.Api.IntegrationTests.csproj --configuration Release --filter FullyQualifiedName~StartupConfigurationTests
```

Çıkış kodu sıfır değilse testler başarısızdır; Docker bulunmadığında endpoint testleri sessizce skip edilmez. İlk image indirmesi birkaç dakika sürebilir. Normal suite için Docker başlangıç limiti 3 dakika, HttpClient timeout'u 15 saniyedir; CI step limiti 8 dakika, test takılma limiti 3 dakikadır. Hang dump kapalıdır; process belleği test artifact'ına yazılmaz.

## İzolasyon ve cleanup

- Fixture, `postgres:18-alpine` ve `redis:8.2.10-alpine` kullanır; isim/host portları Docker tarafından ayrı üretilir. DB/Redis portları yalnız `127.0.0.1` üzerinde yayınlanır.
- PostgreSQL ve Redis dizinleri tmpfs'tir. Development veya external named volume bağlanmaz; veriler kalıcı değildir.
- PostgreSQL parolası her fixture için bellekte üretilir. Değeri dosyaya/rapora yazılmaz. `Production` test ortamı user-secrets yüklemez. Connection string ve TTL, yalnız factory'nin host configuration'ına verilir; process environment veya `.env` değiştirilmez.
- Fixture, uygulama startup'ına dokunmadan mevcut `InitialCreate` migration'ını kendi boş DB'sine açıkça uygular. `EnsureCreated` ile migration atlanmaz.
- Endpoint testleri aynı fixture içinde seri çalışır. Her testten önce yalnız fixture'nin Task tablosu ve liste cache key'i temizlenir. Sabit ID/çalışma sırası beklentisi yoktur.
- Dispose, test hostu ve iki container'ı kaldırır. Testcontainers resource reaper ek cleanup sağlar; reuse kapalıdır. Reaper kendi Docker socket erişimi ve geçici portuna ihtiyaç duyabilir; development kaynaklarını hedeflemez. Docker/host aniden kapanırsa cleanup garantisi yoktur; yalnız test session etiketli kaynaklar incelenmelidir, prune kullanılmamalıdır.
- Factory log provider'larını kaldırır; credential içerebilecek setup/cleanup exception ayrıntıları yerine sabit güvenli hata verilir. Startup testleri yakalanan exception zincirinde beklenen key'i ve canary/tam test connection string yokluğunu kontrol eder. Provider'ları kaldırmak production log redaksiyonunu kanıtlamaz; mevcut Module 9/10 smoke kontrolleri ayrı kalır.

## Test kapsamı — 21 senaryo

| Davranış | Senaryo sayısı | Yakalanan hata |
| --- | ---: | --- |
| CRUD roundtrip, boş/populated liste, trim, Location, 6 JSON alanı, DB'den tekrar okuma, liste invalidation | 1 | Yanlış status/Location/alanlar, yazılmayan değişiklik, eski liste |
| Nullable, boş ve dolu description | 3 | Null'u boş metne dönüştürme veya alanı kaybetme |
| Null/boş/whitespace title, POST ve PUT; yan etki olmaması | 3 | Validation atlama veya başarısız istekte Task değiştirme |
| Olmayan ID: GET/PUT/DELETE | 3 | 404 yerine yanlış status |
| Malformed JSON | 1 | Geçersiz payload ile kayıt oluşturma |
| Eski nullable UpdatedAt → CreatedAt response fallback | 1 | Nullable DB alanından bozuk API response |
| Eksik/boş/bozuk PostgreSQL/Redis ve geçersiz TTL | 8 | Startup'ın kabul etmesi, yanlış hata veya canary sızıntısı |
| Biçimce geçerli ama bağımlılıklara bağlı olmayan startup/liveness | 1 | Startup validation'ın runtime readiness ile karışması |

Cache'in gerçek listesine CRUD sırasında dokunulur; bu ilk adım ayrı TTL, hit/miss counter veya kesinti matrisi sağlamaz. Mevcut cache/readiness/Compose smoke suite'leri bu kapsamı korur. Kod coverage yüzdesi, frontend/browser kabulü veya bütün bug'ların tespiti iddia edilmez.

## Bağımlılıklar ve CI

`Microsoft.AspNetCore.Mvc.Testing` 10.0.12 API ile eşleşir; `Microsoft.EntityFrameworkCore.Relational` 10.0.12, API'nin private Design paketinden gelen EF sürümüyle test runtime'ını hizalar. xUnit 2.9.3, VSTest runner 3.1.5, Test SDK 18.0.1 ve Testcontainers 4.15.0 yalnız test projesindedir. API/frontend paketleri değiştirilmedi.

[CI](../../.github/workflows/ci.yml) Linux build/config job'ı solution restore/build ve Docker kontrolünden sonra gerçek `dotnet test` çalıştırır. Windows job test projesini derler; Docker endpoint suite'i orada çalıştırılmaz. Eski configuration/secret ve izole Compose runtime job'ları korunur. Bu değişiklik henüz commit/push edilmediği için yeni hosted CI sonucu **NOT VERIFIED**; tarihsel yeşil run bu yeni testlerin kanıtı değildir.

7 Ekim 2026 yerel Release suite: **21 PASS, 0 FAIL, 0 SKIP**. İlk çalıştırmanın JsonElement tarih karşılaştırması test hatasıydı; değer karşılaştırması düzeltildi. EF runtime sürüm uyuşmazlığı test projesinde giderildi. Uygulama endpoint/configuration davranışı değiştirilmedi.

Resmî kaynaklar: [ASP.NET Core integration testing](https://learn.microsoft.com/en-us/aspnet/core/test/integration-tests?view=aspnetcore-10.0), [Testcontainers ASP.NET Core örneği](https://dotnet.testcontainers.org/examples/aspnet/), [PostgreSQL modülü](https://dotnet.testcontainers.org/modules/postgres/), [Redis modülü](https://dotnet.testcontainers.org/modules/redis/).

## Öğrenme

Integration test birden fazla gerçek bileşenin birlikte çalışmasını doğrular: HTTP binding → validation → EF → PostgreSQL → response ve Redis listesi. Unit test daha küçük bir davranışı izole sınar; mevcut Compose smoke testi ise Nginx/Docker ağını da içerir. Testler test verisine sahip olduğunda reset ve migration güvenlidir; bunu development DB'ye taşımamalısın.

Alıştırma: yeni bir testte geçerli PUT ile nullable description ve `isCompleted=false` güncellemesini gönder, ardından tekil GET ve liste GET'te aynı sonucu doğrula. Production kodunu sırf test için değiştirme.

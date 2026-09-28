# Module 2A — Backend Dockerfile Baseline

## Amaç

Mevcut ASP.NET Core API için Dockerfile'ın temel komutlarını öğrenmek ve çalışan ilk image'ı üretmek. Module 2A'da bilerek tek aşamalı, SDK tabanlı bir image kullanıldı. Module 2B'de aynı Dockerfile iki aşamaya ayrıldı. API kodu ve HTTP sözleşmesi değişmedi.

## Module 2A baseline Dockerfile (önceki sürüm)

Build context: repository kökünden `src/backend/FullStackOpsLab.Api`. Projenin başka bir projeye `ProjectReference` bağımlılığı yoktur; `.csproj` ve kaynaklar bu klasördedir. `COPY` yalnızca bu context içindeki dosyalara erişebilir.

```dockerfile
FROM mcr.microsoft.com/dotnet/sdk:10.0

WORKDIR /src

COPY FullStackOpsLab.Api.csproj ./
RUN dotnet restore FullStackOpsLab.Api.csproj

COPY . ./
RUN dotnet publish FullStackOpsLab.Api.csproj -c Release -o /app/publish --no-restore

ENV ASPNETCORE_HTTP_PORTS=8080
EXPOSE 8080

WORKDIR /app/publish
ENTRYPOINT ["dotnet", "FullStackOpsLab.Api.dll"]
```

| Komut | Bu dosyadaki görevi |
| --- | --- |
| `FROM` | Resmi Microsoft .NET 10 SDK image'ını başlangıç katmanı yapar. Host'taki proje `net10.0` hedefler. |
| `WORKDIR /src` | Sonraki `COPY` ve `RUN` işlemleri için çalışma dizinini ayarlar. |
| İlk `COPY` | Proje dosyasını kaynaklardan önce kopyalar; kaynak değişince restore cache'i korunabilir. |
| İlk `RUN` | NuGet bağımlılıklarını image build sırasında geri yükler. |
| İkinci `COPY` | Kalan kaynak dosyalarını kopyalar. |
| İkinci `RUN` | Release publish çıktısını `/app/publish` içine üretir. `--no-restore`, önceki restore sonucunu kullanır. |
| `ENV` | ASP.NET Core'un container içinde HTTP 8080 portunu dinlemesini ayarlar. |
| `EXPOSE` | Image'ın beklediği container portunu belgeler; host portu açmaz. |
| İkinci `WORKDIR` | Çalışma dizinini publish çıktısına geçirir. |
| `ENTRYPOINT` | Container başlayınca yayınlanmış API DLL'ini `dotnet` ile çalıştırır. |

SDK image; restore, derleme, publish araçlarını ve uygulamayı çalıştırmak için gereken runtime'ı içerir. ASP.NET runtime image ise SDK araçlarını içermez ve yayınlanmış uygulamayı çalıştırmak içindir. Bu tek aşamalı denemede SDK final image içinde de kaldığından image gereğinden büyüktür. Sonraki multi-stage çalışmasında build SDK ile yapılıp yalnızca publish çıktısının runtime image'a alınması beklenir; bu adımda uygulanmadı.

## Build context ve `.dockerignore`

`.dockerignore`, build context kökü olan `src/backend/FullStackOpsLab.Api` içindedir. `bin/`, `obj/` ve alt klasör eşleşmeleri host işletim sisteminde üretilen çıktıları dışlar. `.git/`, `.vs/`, `.vscode/`, `.idea/`, `*.user` ve `*.suo` kaynak kod olmayan metadata'yı dışlar. `TestResults/`, `*.log`, `*.tmp`, `*.bak`, `*~`, `.DS_Store` geçici çıktıları dışlar. `.env` ve `.env.*` yerel ortam dosyalarının image'a girmesini önler. `*.http`, `Dockerfile` ve `.dockerignore` çalışacak uygulamanın dosyaları değildir. Docker, build talimatlarını okuyabilmek için son iki dosyayı yine builder'a iletebilir; ancak `COPY . ./` ile image'a kopyalanmazlar.

Bir Dockerfile talimatının ürettiği dosya sistemi değişikliği image layer'ı olur. Docker aynı girdileri ve önceki katmanları bulduğunda layer cache kullanabilir. Proje dosyasının kaynaklardan önce kopyalanması, yalnızca bir `.cs` dosyası değiştiğinde restore katmanının yeniden kullanılmasını sağlar. `ENV`, `EXPOSE` ve `ENTRYPOINT` image metadata'sıdır; tek başlarına host portu yayınlamazlar.

## Gerçek komutlar ve ölçümler

Repository kökünde çalıştırıldı:

```powershell
dotnet restore FullStackOpsLab.slnx
dotnet build FullStackOpsLab.slnx -c Release --no-restore
docker build --progress=plain -t fullstack-ops-api:baseline src/backend/FullStackOpsLab.Api
docker build --progress=plain -t fullstack-ops-api:baseline src/backend/FullStackOpsLab.Api
docker image inspect fullstack-ops-api:baseline
docker image ls fullstack-ops-api:baseline
docker image history fullstack-ops-api:baseline
```

| Ölçüm | Gerçek sonuç |
| --- | --- |
| İlk build | 7,960 saniye; başarılı |
| Kaynak değiştirilmeden ikinci build | 0,897 saniye; başarılı |
| Image adı | `fullstack-ops-api:baseline` |
| Image ID, ikinci build sonrası | `sha256:237f84ace753244205956bae7b8529a9e58ad6abd80ed1b0b8d91358e0a01cce` |
| `docker image ls` disk kullanımı | 1,27 GB |
| `docker image ls` content size | 333 MB |
| `docker image inspect` Size | 333.162.223 byte |
| Base image | `mcr.microsoft.com/dotnet/sdk:10.0` |
| Build'de çözümlenen base digest | `sha256:e1fc6e423f543119c406d24e2e687d67c569f18f04a37a8b0005d80ad0dcee80` |

Süreler PowerShell `Stopwatch` ile `docker build` komutunun tamamı için ölçüldü. Base image build öncesinde local sistemde vardı; ilk ölçüm image indirme süresi değildir. İlk build'de restore ve publish gerçekten çalıştı; `WORKDIR /src` önceden cache'deydi. İkinci build çıktısında her Dockerfile build adımı `CACHED` oldu: `WORKDIR`, iki `COPY`, restore, publish ve son `WORKDIR`. BuildKit'in gösterdiği context aktarımı ilk build'de 4,06 kB idi.

`docker image history` çıktısında bu Dockerfile'a ait restore katmanı yaklaşık 4,97 MB, kaynak kopyalama katmanı 28,7 kB, publish katmanı 2,3 MB göründü. `ENTRYPOINT`, `EXPOSE` ve `ENV` satırları 0 B metadata girdileri olarak göründü. Alttaki SDK image'ında `COPY /dotnet` için 544 MB ve PowerShell kurulumu için 53,1 MB gibi büyük katmanlar da vardı. History katman boyutları, `image ls` disk kullanımı ve content size farklı ölçümlerdir; birbirinin yerine kullanılmaz.

## Container ve HTTP doğrulaması

Container içindeki hedef port Dockerfile'daki `ASPNETCORE_HTTP_PORTS=8080` ile belirlendi. Host'ta `18080` portunun boş olduğu kontrol edildi. `-p 127.0.0.1:18080:8080`, yalnızca host'un loopback adresindeki 18080 portunu container'ın 8080 portuna yönlendirir. `EXPOSE 8080` tek başına bunu yapmaz.

```powershell
docker run -d --name fullstack-ops-api-baseline -p 127.0.0.1:18080:8080 -e ASPNETCORE_ENVIRONMENT=Development fullstack-ops-api:baseline
docker ps --filter name=fullstack-ops-api-baseline
docker logs fullstack-ops-api-baseline
docker inspect fullstack-ops-api-baseline
docker exec fullstack-ops-api-baseline pwd
docker exec fullstack-ops-api-baseline ls -la /app/publish
Invoke-WebRequest http://127.0.0.1:18080/health
Invoke-WebRequest http://127.0.0.1:18080/openapi/v1.json
docker stop fullstack-ops-api-baseline
docker rm fullstack-ops-api-baseline
docker ps -a --filter name=fullstack-ops-api-baseline
docker image ls fullstack-ops-api:baseline
```

`docker ps` port mapping'i `127.0.0.1:18080->8080/tcp` olarak gösterdi. Loglarda `Now listening on: http://[::]:8080`, `Hosting environment: Development` ve `Content root path: /app/publish` görüldü. `docker inspect` image'ı `fullstack-ops-api:baseline`, state'i `running`, environment değerlerini `ASPNETCORE_ENVIRONMENT=Development` ve `ASPNETCORE_HTTP_PORTS=8080`, port eşlemesini de loopback `18080` → `8080/tcp` olarak doğruladı. `docker exec` çalışma dizinini `/app/publish` olarak gösterdi; `FullStackOpsLab.Api.dll` ve ilgili publish dosyaları mevcuttu.

| İstek | Sonuç |
| --- | --- |
| `GET http://127.0.0.1:18080/health` | HTTP 200, `Healthy` |
| `GET http://127.0.0.1:18080/openapi/v1.json` | HTTP 200, OpenAPI `3.1.1`; `/api/tasks` yolları mevcut |

OpenAPI mevcut uygulamada yalnızca Development ortamında map edilir. Bu nedenle doğrulama container'ı `-e ASPNETCORE_ENVIRONMENT=Development` ile başlatıldı; uygulama kodu değiştirilmedi. Doğrulama sonunda sadece `fullstack-ops-api-baseline` durdurulup kaldırıldı. `docker ps -a --filter name=fullstack-ops-api-baseline` boş sonuç verdi; `fullstack-ops-api:baseline` image'ı Module 2B karşılaştırması için local sistemde kaldı.

## Sık hatalar ve bu baseline'ın sınırları

- Yanlış klasörden `docker build` çalıştırılırsa `COPY FullStackOpsLab.Api.csproj ./` dosyayı bulamaz. Son argüman build context'tir.
- `EXPOSE` host portunu açmaz; erişim için `docker run -p` gerekir.
- `-p 18080:8080` tüm host arayüzlerinde dinleyebilir; bu deneyde `127.0.0.1:18080:8080` seçildi.
- Container 8080 dinlerken yanlış container portuna yönlendirmek bağlantıyı bozar.
- Production ortamında mevcut OpenAPI endpoint'i map edilmez; bu denemede Development ayarlandı.
- SDK image final image olarak kullanıldığı için build araçları ve restore ile kopyalanan kaynaklar image'da kalır. Bu baseline boyut ve içerik açısından son çözüm değildir. Multi-stage build'in amacı publish çıktısını daha küçük runtime image'a taşımaktır.

## 5 kısa kavramsal soru

1. `FROM` hangi image'ı seçer ve `net10.0` ile neden uyumlu olmalıdır?
2. Build context ile Dockerfile'ın bulunduğu yol aynı şey midir? Bu deneyde neden aynı klasör seçildi?
3. `.csproj` dosyasını kaynaklardan önce kopyalamak cache'e nasıl yardımcı olur?
4. `EXPOSE 8080` ile `-p 127.0.0.1:18080:8080` arasındaki fark nedir?
5. SDK image'ı ile ASP.NET runtime image'ının rolleri nelerdir?

## Uygulamalı alıştırma

Dockerfile'a ek dosya eklemeden bir kaynak `.cs` dosyasında yalnızca yorum değişikliği yapıp build'i tekrar çalıştır. Hangi adımların `CACHED` kaldığını ve hangilerinin yeniden çalıştığını kaydet. Sonra yorum değişikliğini geri al; bu alıştırma için oluşturduğun container varsa yalnızca onu kaldır.

## Module 2B — Backend multi-stage build

### İki aşamanın görevi

Güncel `src/backend/FullStackOpsLab.Api/Dockerfile` iki `FROM` içerir:

```dockerfile
FROM mcr.microsoft.com/dotnet/sdk:10.0 AS build

WORKDIR /src
COPY FullStackOpsLab.Api.csproj ./
RUN dotnet restore FullStackOpsLab.Api.csproj
COPY . ./
RUN dotnet publish FullStackOpsLab.Api.csproj -c Release -o /app/publish --no-restore

FROM mcr.microsoft.com/dotnet/aspnet:10.0-noble

WORKDIR /app
COPY --from=build /app/publish ./
ENV ASPNETCORE_HTTP_PORTS=8080
EXPOSE 8080
ENTRYPOINT ["dotnet", "FullStackOpsLab.Api.dll"]
```

`build` aşamasındaki resmi .NET 10 SDK restore ve publish yapar. Runtime aşamasındaki resmi ASP.NET Core 10 image'ı, baseline SDK image'ıyla aynı Ubuntu 24.04 ailesinin `noble` varyantını kullanır. `COPY --from=build` yalnızca publish çıktısını önceki aşamadan final image'a taşır; proje kaynakları ve SDK araçları taşınmaz. `WORKDIR /app`, DLL'in çalışacağı dizindir. İç port yine 8080'dir; host'a açılması `docker run -p` ile yapılır.

Proje dosyası kaynaklardan önce kopyalandığı için yalnızca `.cs` dosyaları değişirse restore girdisi değişmez ve restore katmanı cache'de kalabilir. Kaynak kopyası ile publish yeniden çalışır. Bağımlılıklar değişirse proje dosyası ve onu izleyen restore/publish katmanları yeniden hesaplanır. Bu build'de SDK aşamasının bütün adımları Module 2A cache'inden kullanıldı; yeni runtime image ilk build sırasında indirildi.

### Gerçek komutlar ve sonuçlar

Repository kökünde uygulandı:

```powershell
dotnet build FullStackOpsLab.slnx -c Release
docker image inspect fullstack-ops-api:baseline
docker build --progress=plain -t fullstack-ops-api:multistage src/backend/FullStackOpsLab.Api
docker build --progress=plain -t fullstack-ops-api:multistage src/backend/FullStackOpsLab.Api
docker image inspect fullstack-ops-api:multistage
docker image ls fullstack-ops-api:multistage
docker image history fullstack-ops-api:multistage
docker run -d --name fullstack-ops-api-multistage -p 127.0.0.1:18080:8080 -e ASPNETCORE_ENVIRONMENT=Development fullstack-ops-api:multistage
docker logs fullstack-ops-api-multistage
docker inspect fullstack-ops-api-multistage
Invoke-WebRequest http://127.0.0.1:18080/health
Invoke-WebRequest http://127.0.0.1:18080/openapi/v1.json
./tests/Phase0B.Tasks.Smoke.ps1 -BaseUrl http://127.0.0.1:18080
docker exec fullstack-ops-api-multistage dotnet --list-sdks
docker exec fullstack-ops-api-multistage dotnet --list-runtimes
docker exec fullstack-ops-api-multistage ls -la /app
docker exec fullstack-ops-api-multistage cat /etc/os-release
docker stop fullstack-ops-api-multistage
docker rm fullstack-ops-api-multistage
```

Build süreleri PowerShell `Stopwatch` ile tam `docker build` komutu için ölçüldü. Baseline süreleri Module 2A ölçümleridir (7,960 ve 0,897 sn); multi-stage süreleri Module 2B ölçümleridir (22,104 ve 0,901 sn). Boyutlar 28 Eylül 2026'da mevcut image'lar üzerinde tekrar ölçüldü; süreler bu kontrolde yeniden ölçülmedi. İlk multi-stage build'in 22,104 saniyesinin yaklaşık 20 saniyesi yeni runtime base image'ının indirilmesi ve açılması sırasında geçti. Bu nedenle ilk build süreleri eşit derecede sıcak cache koşullarında alınmadı; doğrudan Dockerfile performans kıyası sayılmamalı.

| Ölçüm | Baseline | Multi-stage | Fark |
| --- | ---: | ---: | ---: |
| Image content size (`docker image inspect`) | 333.162.223 byte | 96.250.984 byte | −236.911.239 byte |
| Image content size (ondalık MB) | 333,162223 MB | 96,250984 MB | **−236,911239 MB (−%71,11)** |
| Local disk usage (`docker image ls`, yuvarlanmış) | 1,27 GB | 341 MB | Kesin fark bu gösterimden hesaplanmadı |
| First build time | 7,960 sn | 22,104 sn | +14,144 sn |
| Cached build time | 0,897 sn | 0,901 sn | +0,004 sn |
| SDK included | Yes | No | SDK kaldırıldı |
| Health result | HTTP 200, `Healthy` | HTTP 200, `Healthy` | Aynı |
| OpenAPI result (Development) | HTTP 200, 3.1.1 | HTTP 200, 3.1.1 | Aynı |
| CRUD result | GET/POST/PUT/DELETE, 400/404 geçti | GET/POST/PUT/DELETE, 400/404 geçti | Aynı |

Kesin byte hesabı: `333.162.223 − 96.250.984 = 236.911.239` byte = **236,911239 MB** (ondalık). Azalma: `236.911.239 / 333.162.223 × 100 = %71,11`. `docker image ls` ayrıca baseline için **1,27 GB**, multi-stage için **341 MB** disk kullanımı; sırasıyla **333 MB** ve **96,3 MB** content size gösterdi. Disk kullanımı yuvarlanmış ve katman paylaşımından etkilenebilir; yüzde hesabında `docker image inspect` byte değerleri kullanıldı.

| Image | Karşılaştırma sırasında ölçülen image ID | Base |
| --- | --- | --- |
| Baseline | `sha256:d9c8fa150be8e2e789d286fce3b2d9a22f2aa8999e47762e2dda480e6d1d187e` | `mcr.microsoft.com/dotnet/sdk:10.0` |
| Multi-stage | `sha256:f9c82881211199870c1ec30c4c303b343f98b8cc4a2538c76afd0a5781efaeb5` | `mcr.microsoft.com/dotnet/aspnet:10.0-noble` |

Image ID ölçüm anına aittir. BuildKit attestation manifest'i yeniden üretildiğinde, aynı uygulama katmanları cache'den kullanılsa bile tag'in image ID'si değişebilir.

İkinci multi-stage build'de proje dosyası `COPY`, restore, kaynak `COPY`, publish ve runtime'a `COPY --from=build` dahil bütün ilgili adımlar `CACHED` göründü. `docker image history` final image'da yaklaşık 950 kB publish kopyası ve ASP.NET runtime katmanlarını gösterdi; SDK'nın baseline'daki büyük build katmanları final history'de yoktu.

Her iki container aynı `127.0.0.1:18080:8080` eşlemesi ve `ASPNETCORE_ENVIRONMENT=Development` ile ayrı ayrı çalıştırıldı. Loglar ikisinde de `http://[::]:8080` dinlendiğini gösterdi. Her ikisinde `/health` HTTP 200 `Healthy`, `/openapi/v1.json` HTTP 200 OpenAPI 3.1.1 döndü. Mevcut `tests/Phase0B.Tasks.Smoke.ps1` her iki image'da listeleme, oluşturma, okuma, güncelleme, silme, validation 400 ve bulunamayan kayıt 404 kontrollerini geçti. API davranışı aynı kaldı.

Multi-stage container'da `dotnet --list-sdks` boş sonuç verdi; `/usr/share/dotnet/sdk` ve `/src` bulunmadı. `dotnet --list-runtimes` Microsoft.AspNetCore.App ve Microsoft.NETCore.App `10.0.12` gösterdi; `/etc/os-release` Ubuntu 24.04 Noble olduğunu doğruladı. `docker inspect`, `fullstack-ops-api:multistage`, `running` ve `127.0.0.1:18080->8080/tcp` değerlerini gösterdi. Test sonunda yalnızca `fullstack-ops-api-multistage` durdurulup kaldırıldı; iki karşılaştırma image'ı local sistemde kaldı.

### Avantaj ve trade-off'lar

Final image'ın ölçülen content size değeri %71,11 azaldı. SDK ve kaynak kod final image'da olmadığından çalışan container daha dar bir dosya seti içerir. Bunun karşılığı iki aşamayı anlamak ve yönetmek, ayrıca ilk kez kullanılacak runtime base image'ını indirmektir. Ölçülen ilk build süreleri ağ ve mevcut cache durumundan etkilenir; yalnızca bu iki sayıdan her ortamda multi-stage build'in daha yavaş olduğu sonucu çıkarılmaz.

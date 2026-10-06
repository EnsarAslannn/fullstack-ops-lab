# Module 1A — Docker Fundamentals: Nginx Container Lifecycle

## Amaç

Resmi Nginx image'ı ile Docker image, container, registry, port eşleme ve container yaşam döngüsünü öğrenmek. Bu laboratuvar uygulamanın backend veya frontend'ini container'a taşımaz. Başka projelerin Docker kaynaklarını değiştirmez.

## Temel kavramlar

- **Registry:** Image'ların yayımlandığı ve indirildiği hizmet. Bu örnekte kaynak [Docker Hub'daki resmi Nginx image'ı](https://hub.docker.com/_/nginx).
- **Image:** Container oluşturmak için kullanılan, katmanlı ve yerel olarak saklanan paket. `docker pull` image'ı indirir; onu çalıştırmaz.
- **Container:** Bir image'dan oluşturulan çalıştırılabilir örnek. Kendi ID'si, durumu ve ağ adresi vardır. Aynı image'dan birden çok container oluşturulabilir.
- **Detached mode (`-d`):** Container arka planda çalışır; terminal Nginx sürecine bağlı kalmaz. Durumu `docker ps`, çıktısı `docker logs` ile izlenir.
- **Port mapping:** `8080:80`, host portu `8080` üzerinden container portu `80`'e ulaşmak demektir. Bu laboratuvarda `127.0.0.1:8080:80` kullanıldı; host portuna yalnızca yerel makineden erişilir. [Docker port yayımlama açıklaması](https://docs.docker.com/get-started/docker-concepts/running-containers/publishing-ports/).

## Seçilen kaynaklar

| Alan | Değer |
| --- | --- |
| Image | `nginx:stable-alpine` |
| İndirilen digest | `sha256:0985e772fb9f729e6fa0980da05fca5d9c468e870eed43071545afa9d2e27d94` |
| Container adı | `fullstack-ops-nginx-lab` |
| Host → container | `127.0.0.1:8080` → `80/tcp` |
| Ağ | Docker'ın mevcut varsayılan `bridge` ağı |

`stable-alpine`, resmi Nginx stable hattını küçük bir Alpine tabanında sunar. `latest` kullanılmadı. Bu tag zamanla yeni bir image'a işaret edebilir; yukarıdaki digest bu çalışmada gerçekten indirilen içeriği tanımlar. Container içindeki Nginx sürümü `1.30.5` olarak ölçüldü.

## Çalıştırılan komutlar ve amaçları

Komutlar repository kökünde PowerShell'den çalıştırıldı. Başlangıçta `docker version` ve `docker info` ile CLI/Engine erişimi; `docker ps`, `docker ps -a` ve `docker image ls` ile mevcut kaynaklar kontrol edildi. `8080` portu boştu. Başka projelere ait 12 durmuş container ve 23 image vardı.

```powershell
docker version
docker info
docker ps
docker ps -a
docker image ls
```

`docker pull` resmi image'ı Docker Hub'dan indirdi. `docker image ls` image'ın yerelde bulunduğunu, `docker image inspect` OS/architecture ve digest'i gösterdi.

```powershell
docker pull nginx:stable-alpine
docker image ls nginx:stable-alpine
docker image inspect nginx:stable-alpine
```

`docker run -d` image'dan arka planda bir container oluşturdu. `--name` bu laboratuvar kaynağını belirgin kıldı. `-p` host `8080` ile container `80` portunu eşledi. `docker ps` çalışan container'ı gösterdi; gerçek HTTP isteği varsayılan Nginx sayfasını doğruladı.

```powershell
docker run -d --name fullstack-ops-nginx-lab -p 127.0.0.1:8080:80 nginx:stable-alpine
docker ps --filter 'name=^/fullstack-ops-nginx-lab$'
Invoke-WebRequest 'http://127.0.0.1:8080/' -UseBasicParsing
```

`docker logs` Nginx başlangıcını ve `GET /` erişim kaydını gösterdi. `docker inspect` image, çalışma durumu, port ve ağı gösterdi. Bu Docker sürümünde container IP'si `NetworkSettings.Networks.bridge.IPAddress` altında bulundu. `docker exec`, çalışan container içinde yapılandırmayı değiştirmeyen `nginx -v` komutunu çalıştırdı.

```powershell
docker logs --tail 30 fullstack-ops-nginx-lab
docker inspect fullstack-ops-nginx-lab --format 'Image={{.Config.Image}} State={{.State.Status}} Ports={{json .NetworkSettings.Ports}} Network={{.HostConfig.NetworkMode}}'
docker inspect fullstack-ops-nginx-lab --format '{{json .NetworkSettings.Networks}}'
docker exec fullstack-ops-nginx-lab nginx -v
```

`stop` çalışan süreci durdurur ve container'ı saklar. `ps` yalnız çalışanları, `ps -a` durmuş olanları da gösterir. `start` aynı container'ı tekrar başlatır; burada ID değişmedi. `restart` çalışan container'ı durdurup yeniden başlatır. Her başlatmadan sonra HTTP 200 tekrar doğrulandı.

```powershell
docker stop fullstack-ops-nginx-lab
docker ps --filter 'name=^/fullstack-ops-nginx-lab$'
docker ps -a --filter 'name=^/fullstack-ops-nginx-lab$'
docker start fullstack-ops-nginx-lab
Invoke-WebRequest 'http://127.0.0.1:8080/' -UseBasicParsing
docker restart fullstack-ops-nginx-lab
Invoke-WebRequest 'http://127.0.0.1:8080/' -UseBasicParsing
```

Son `stop` ve `rm`, yalnızca bu laboratuvar container'ını kaldırdı. `rm` image'ı kaldırmaz; image ayrı bir Docker kaynağıdır ve tekrar container oluşturmak için kullanılabilir. Bu nedenle `docker rmi` çalıştırılmadı.

```powershell
docker stop fullstack-ops-nginx-lab
docker rm fullstack-ops-nginx-lab
docker ps -a --filter 'name=^/fullstack-ops-nginx-lab$'
docker image ls nginx:stable-alpine
```

## Gerçek doğrulama sonuçları — 27 Eylül 2026

| Kontrol | Gözlem |
| --- | --- |
| Docker CLI / Engine | Docker Desktop Linux Engine `29.6.1` erişilebilir |
| İlk HTTP isteği | `200`, sayfa başlığı `Welcome to nginx!` |
| Log | `GET / HTTP/1.1` için `200` erişim kaydı |
| Inspect | Image `nginx:stable-alpine`; durum `running`; `127.0.0.1:8080` → `80/tcp`; ağ `bridge`; container IP `172.17.0.2` |
| Exec | `nginx version: nginx/1.30.5` |
| Stop | `docker ps` boş; `docker ps -a` aynı ID'yi `Exited (0)` gösterdi; HTTP erişimi kapandı |
| Start / restart | Aynı container ID `a5487b1c3acf…`; her iki işlemden sonra HTTP `200` |
| Remove sonrası | Laboratuvar container'ı listede yok ve HTTP kapalı; image yerelde mevcut |
| Volume | Image `Config.Volumes=null` bildirdi; laboratuvarda volume oluşturulmadı |
| Kaynak sayıları | Önce 12 container / 23 image; sonra 12 container / 24 image. Diğer container ID'leri korundu |

Container IP'si yeni bir container oluşturulduğunda değişebilir; sonraki çalışmalarda bu örnek IP'ye güvenme.

## Sık yapılan hatalar

- `docker ps` içinde durmuş container'ı aramak: `docker ps -a` kullan.
- Host `8080` portu doluyken `docker run` denemek: önce portu kontrol et; bu laboratuvarın portunu açıklama yapmadan değiştirme.
- `localhost` adresinin her yerde aynı yeri gösterdiğini sanmak: container içindeki `localhost` container'ın kendisidir.
- `docker stop` işleminin container'ı sildiğini sanmak: kaldırma işlemi `docker rm` ile yapılır.
- Container silinince image'ın da silineceğini sanmak: image ayrı kalır; `docker image ls` ile doğrula.
- `stable-alpine` tag'inin değişmez olduğunu sanmak: tekrarlanabilirlik için kullanılan digest'i kaydet.
- Eski inspect örneklerindeki `NetworkSettings.IPAddress` alanını varsaymak: bu Engine sürümünde IP, `NetworkSettings.Networks.bridge.IPAddress` içindeydi.

## 5 kısa mülakat sorusu

1. Image ile container arasındaki fark nedir?
2. `-p 127.0.0.1:8080:80` içindeki iki port ve IP neyi ifade eder?
3. `-d` ile başlayan container'ın çıktısını hangi komutla görürsün?
4. `docker ps` ile `docker ps -a` neden farklı sonuç verir?
5. `docker stop`, `start`, `restart` ve `rm` hangi durumda kullanılır?

## Uygulamalı alıştırma

Bu laboratuvarı aynı ad ve portla yeniden kur. Başlangıçta `docker ps -a` ve `docker image ls` çıktısını kaydet; container'ı çalıştır, HTTP 200 ve logdaki erişimi göster, durdur, tekrar başlat, ardından kaldır. Sonunda yalnızca laboratuvar container'ının silindiğini ve image'ın kaldığını doğrula.

---

6 Ekim 2026 ortak dokümantasyon dizini: aşağıdaki standart başlıklar tarihsel ayrıntıya bağlanır; yeni deney veya yeni PASS sonucu değildir. Eski container/port/ölçüm değerleri kendi aşamasına aittir. Güncel altı servis ve DoD sınırları [mimari belgesindedir](../../docs/architecture.md#dokümantasyon-standardı-ve-definition-of-done).

## Goal

[Amaç](#amaç).

## What You Will Learn

[Kavramlar ve nedenleri](#temel-kavramlar).

## Architecture

[Bu aşamanın yapısı](#seçilen-kaynaklar); [güncel sistem](../../docs/architecture.md#servisler-portlar-ve-ağ).

## Prerequisites

Bu tarihsel deneyin kaynak/port/credential ön koşullarını kendi komut bölümünden kontrol et. Güncel normal kurulum için [Module9 rehberini](../09-environment-configuration/README.md#13-temiz-bilgisayar-kurulum-rehberi) izle; önceki lab komutlarını development kaynaklarında körlemesine tekrarlama.

## Step 1

[Hazırlık ve komutlar](#çalıştırılan-komutlar-ve-amaçları).

## Step 2

[Davranışı çalıştırma ve gözlemleme](#gerçek-doğrulama-sonuçları--27-eylül-2026).

## Verification

[Gerçek sonuçlar](#gerçek-doğrulama-sonuçları--27-eylül-2026); çalışma, cleanup ve ölçülmeyen kapsam ayrımlarını koru. Bu dizin genel final runtime kabulü değildir.

## Break It

[Olası hatalar (ayrı arıza deneyi iddiası yok)](#sık-yapılan-hatalar).

## Diagnose It

[Teşhis ve gözlem](#sık-yapılan-hatalar).

## Fix It

[Doğru davranış / düzeltme açıklaması](#sık-yapılan-hatalar).

## What Happened?

[Ölçülen sonuç ve sınırlar](#gerçek-doğrulama-sonuçları--27-eylül-2026).

## Key Concepts

[Temel ayrımlar](#temel-kavramlar); [kısa sözlük](../../docs/architecture.md#kısa-sözlük).

## Interview Questions

[Mevcut mülakat soruları](#5-kısa-mülakat-sorusu).

## Exercises

[Mevcut alıştırma](#uygulamalı-alıştırma); uygulamadan önce kaynak sahipliği ve cleanup şartlarını oku.

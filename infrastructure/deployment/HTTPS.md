# Yerel HTTPS — kurulum ve rehberli kabul

16 Ekim 2026 güncel durum: **frontend TLS etkinleştirmesi, Windows SSH tüneli,
uyarısız tarayıcı/HTTPS asset erişimi ve HTTPS CRUD kabulü PASS**. Yalnız frontend
yeniden oluşturuldu; diğer beş container'ın kimliği korundu, finalde altısı healthy.
Windows hazırlığı bölüm12, VM dosya hazırlığı bölüm13, 15–16 Ekim etkinleştirme
ve kabulü bölüm14'tedir. Önceki tarihli bölümler o aşamanın kanıtını anlatır.
Varsayılan Schannel curl çağrısı iptal kontrolü nedeniyle başarısız oldu; yalnız
komuta ait best-effort seçeneğiyle başarılı kontrolün sınırı bölüm14'te açıklanır.
Agent private dosyaları okumadı veya VM/Windows işlemlerini kullanıcı yerine yapmadı.
Stack ve HTTPS tüneli çalışır bırakıldı; deployment lab bütünüyle tamamlanmadı.
Komut grupları sırayla sonuç incelenerek uygulanacak; bir grup başarısızsa sonraki
gruba geçilmez. Bütün belge tek seferde terminale yapıştırılmaz.

## 1. Karar ve istek yolu

[İlk plandaki](../../docs/deployment-plan.md) host Nginx önerisi, kullanıcının
image build olmadan read-only deployment config isteğiyle değiştirildi: TLS mevcut
frontend container'ındaki Nginx'te sonlanır. Altı servis, aynı GHCR digest çifti,
PostgreSQL volume'u ve monitoring adresleri korunur; host Nginx kurulmaz.

```mermaid
flowchart LR
    B[Windows Edge/Chrome<br/>tasks.fullstackops.test:18443] -->|HTTPS / Windows loopback| S[SSH -L<br/>127.0.0.1:18443]
    S -->|Şifreli SSH bağlantısı| V[VM loopback<br/>127.0.0.1:18443]
    V -->|Docker port mapping| F[frontend:443<br/>Nginx TLS + statik React]
    F -->|HTTP /api/*| A[api:8080]
    A --> P[postgres:5432]
    A --> R[redis:6379]
```

TLS browser ile frontend Nginx arasındadır; SSH yalnız TCP taşır. API bağlantısı
mevcut internal Docker ağında HTTP kalır. Bu uçtan uca tüm servislerin TLS kullandığı
veya internet deployment'ı iddiası değildir. Uygulamaya kullanıcı yetkilendirmesi eklenmez.

| Erişim | Windows loopback | VM loopback → container |
| --- | --- | --- |
| Yeni HTTPS | 18443 | 18443 → frontend443 |
| Mevcut HTTP teşhisi | 28081 | 18081 → frontend80 |
| Prometheus | 29090 | 19090 → prometheus9090 |
| Grafana | 23000 | 13000 → grafana3000 |
| API / PostgreSQL / Redis | Yok | Host publish yok |

VM18443, dosya hazırlığı sırasında boştu. Sonraki etkinleştirmede Windows18443
boşluğu doğrulandı; VM127.0.0.1:18443 listener ve Windows127.0.0.1:18443 SSH
tüneliyle erişim sağlandı. Pencereler kapatılınca 16 Ekim'de IP/altı container
yeniden kontrol edilip yalnız HTTPS tüneli açıldı; container recreate gerekmedi.

## 2. Dosyalar ve davranış

- [compose.https.yaml](compose.https.yaml): üçüncü, isteğe bağlı overlay.
- [nginx/https.conf](nginx/https.conf): yalnız deployment frontend config'i.
- [https.env.example](https.env.example): tek non-secret path placeholder'ı.
- [release.json](release.json): image kaynağı/digestleri; bu görevde değişmedi.
- [Statik test](../../tests/Deployment.Configuration.Test.py): gerçek Compose
  parser/model guard'ları; Docker Engine gerektirmez.

Komut sırası daima `compose.yaml`, `compose.deploy.yaml`, `compose.https.yaml`.
Bind source yolları **ilk dosyanın/repository kökünün** konumuna göre çözülür.
HTTPS overlay'i tek başına kullanılmaz. [Compose merge açıklaması](https://docs.docker.com/compose/how-tos/multiple-compose-files/merge/).

Nginx config, server certificate ve server private key için üç ayrı bind mount
read-only'dir; `create_host_path: false` yanlış/eksik source için sessizce dizin
oluşturmayı engeller. Sertifika yokken `config -q` yine başarılı olabilir: dosyanın
varlığını, PEM içeriğini, SAN'ını veya certificate/key eşleşmesini kanıtlamaz.
[Bind mount uzun biçimi](https://docs.docker.com/reference/compose-file/services/#long-syntax-5).

Nginx80 ve443 dinler; mevcut HTTP80 root healthcheck'i ve statik/API routing korunur.
HTTP otomatik HTTPS'e yönlendirilmez: loopback teşhis erişimi bilerek açık kalır.
HTTPS erişimini kullanmak ile bütün HTTP'yi zorunlu TLS'e geçirmek ayrı kararlardır.
Healthcheck'in çalışması da TLS güven/SAN doğrulaması yerine geçmez.

HTTPS'te `Host $http_host` dış18443 portunu korur; `X-Forwarded-Proto $scheme`
TLS isteğinde https olur. Backend'e yeni forwarded-header middleware eklenmez;
header varlığı API'nin client IP/scheme bilgisine güvendiğini kanıtlamaz.
`absolute_redirect off` Nginx'in kendi redirect'lerini göreli yapar; browser dış
origin/18443'ü korur. API'nin relative POST Location sözleşmesi değişmez.
[Nginx redirect açıklaması](https://nginx.org/en/docs/http/ngx_http_core_module.html#absolute_redirect).

Image'ın EXPOSE80 metadata'sı443 dinlenmesini/publish edilmesini engellemez;
gerçek listener ve Docker mapping ayrıca doğrulanacak. Dockerfile değişmez.

## 3. Sertifika adı, yerleşim ve güven

Tek SAN: **DNS:tasks.fullstackops.test**. DHCP VM IP'si ve localhost SAN değildir;
browser URL'si `https://tasks.fullstackops.test:18443/` olmalıdır. `.test` için public
DNS/domain satın alınmaz; Windows hosts eşlemesi127.0.0.1 olarak doğrulandı.

Önerilen araç Windows'ta [resmî mkcert](https://github.com/FiloSottile/mkcert).
Yerel CA Windows'ta oluşturulur; CA private key **VM'ye veya container'a gönderilmez**.
Nginx'e yalnız leaf `server.crt` ve `server.key` gider. Windows tarayıcısı yerel CA'nın
public sertifikasına güvenmesi için mkcert `-install` uygulandı;
`TRUST_STORES=system` diğer store'lara otomatik işlem yapılmasını sınırlar.
v1.4.4 Windows implementasyonu `CertOpenSystemStoreW("ROOT")` kullanır:
hedef **Geçerli Kullanıcı → Güvenilen Kök Sertifika Yetkilileri**, PowerShell'de
`Cert:\CurrentUser\Root` deposudur; LocalMachine değildir. Kullanıcının public CA
thumbprint'i bu depoda bulundu. Kaynaklar: [mkcert v1.4.4 Windows kodu](https://github.com/FiloSottile/mkcert/blob/v1.4.4/truststore_windows.go),
[Microsoft depo kapsamı](https://learn.microsoft.com/en-us/windows/win32/api/wincrypt/nf-wincrypt-certopensystemstorew#remarks).
Bu depo kontrolü, henüz açılmamış HTTPS adresinin tarayıcı kabulü değildir.

| Dosya | Gelecekte önerilen yer | Git durumu |
| --- | --- | --- |
| CA public/private dosyaları | Windows LOCALAPPDATA/FullStackOpsLab/deployment-tls/ca | Repository dışında; CA private key paylaşılmaz |
| Leaf certificate/private key | Windows aynı lab dizininde ayrı server alt klasörü | Repository dışında, yalnız bu çift VM'ye aktarılır |
| VM leaf dosyaları | /home/labadmin/.local/share/fullstackops-deploy-lab/tls | Repository dışında; server.key izin600 |
| VM path ayarı | VM repository kökünde .env.https | Git ignored; yalnız path, credential içermez |

`.gitignore`, `.env.https` yanında key/pem/crt/cer/pfx/p12/csr/der/srl ve tls-private
dizinlerini dışlar. Bu savunma, ignored bir private key'in güvenli saklandığı veya
zorla eklenemeyeceği anlamına gelmez. Yeni örnek env takip edilebilir; gerçek .env.deployment
ve user-secrets değiştirilmez. Sertifika yenileme ayrı bir işlemdir; güven/hosts
kaldırma yönergeleri bölüm10'dadır ve bu hazırlıkta uygulanmaz.

## 4. Ön kontrol — sonraki uygulama, salt okunur

**Ubuntu SSH:** önce IP/hostname, project durumları ve18443 portunu tekrar kontrol et.

```bash
hostname
ip -4 -brief address show eth0
sudo docker ps -a --filter label=com.docker.compose.project=fullstackops-deploy-lab --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'
sudo ss -ltnp '( sport = :18443 )'
```

**Windows PowerShell:** Ubuntu prompt'unda çalıştırma. Boş portta listener çıkmamalı.

```powershell
Get-NetTCPConnection -State Listen -LocalPort 18443 -ErrorAction SilentlyContinue
$mkcertExe = Join-Path $env:LOCALAPPDATA 'FullStackOpsLab\tools\mkcert\mkcert.exe'
Get-Item -LiteralPath $mkcertExe -ErrorAction Stop | Select-Object FullName
& $mkcertExe -version
if ($LASTEXITCODE -ne 0) { throw 'mkcert kullanilamiyor' }
```

mkcert yoksa burada durulur; resmî Windows release'inin ayrı indirme/kurulum ve
bütünlük incelemesi gerekir. Kullanıcının 15 Ekim'de indirdiği portable v1.4.4 ve
doğruladığı hash bölüm12'de kayıtlıdır. PATH değişikliği gerekmedi; komutlar tam
araç yolunu kullanır. Ücretli hizmet gerekmez.

## 5. Dosya aktarımı — ilk aktarım referansı

Bu aktarım bölüm13'teki hash sonuçlarıyla tamamlandı; komutlar otomatik tekrar
çalıştırılmaz. Mevcut VM kaynak ağacı topluca güncellenmedi.

Yeni repository dosyaları henüz commit edilmediyse clone tek başına getirmez.
Seçilmiş kaynak1b52633776279b1661a7cac53392d385cbf10444 ağacı ve mevcut release çifti
korunur; yalnız üç yeni public HTTPS config dosyası aktarılır. Root compose.yaml,
compose.deploy.yaml, image digestleri ve development dosyaları değiştirilmez.

**Ubuntu SSH**, mevcut VM repository kökü:

```bash
(
  set -eu
  cd ~/fullstack-ops-lab
  test -f compose.yaml
  test -f infrastructure/deployment/compose.deploy.yaml
  test ! -e infrastructure/deployment/compose.https.yaml
  test ! -e infrastructure/deployment/https.env.example
  test ! -e infrastructure/deployment/nginx/https.conf
  install -d -m 755 infrastructure/deployment/nginx
)
```

Kontrollerden biri başarısızsa aktarım durdurulup mevcut dosya incelenir; üzerine
yazılmaz. **Windows PowerShell**, ana repository kökü (IP önce yeniden doğrulanır):

```powershell
& {
$vmAddress = '172.30.249.139'
scp infrastructure/deployment/compose.https.yaml infrastructure/deployment/https.env.example "labadmin@${vmAddress}:~/fullstack-ops-lab/infrastructure/deployment/"
if ($LASTEXITCODE -ne 0) { throw 'HTTPS config aktarimi basarisiz' }
scp infrastructure/deployment/nginx/https.conf "labadmin@${vmAddress}:~/fullstack-ops-lab/infrastructure/deployment/nginx/"
if ($LASTEXITCODE -ne 0) { throw 'Nginx config aktarimi basarisiz' }
Get-FileHash infrastructure/deployment/compose.https.yaml, infrastructure/deployment/nginx/https.conf -Algorithm SHA256
}
```

**Ubuntu SSH:** `sha256sum` ile aynı public dosya hash'leri eşleştirilir.

```bash
sha256sum infrastructure/deployment/compose.https.yaml infrastructure/deployment/nginx/https.conf
```

## 6. Yerel CA ve leaf hazırlığı — ilk kurulum örneği

Bu grup **sertifika ve güven deposu değiştirir; şimdi tekrar çalıştırılmayacak**.
Kullanıcı CA/leaf hazırlığını ayrı küçük komut gruplarıyla tamamladı (bölüm12).
Ayrı yeni PowerShell oturumu kullanılır; aşağıdaki env ayarları yalnız bu oturum
içindir, setx kullanılmaz. Repo dışı bu lab dizini zaten varsa önce içeriği/sahipliği
incelenir; komut mevcut dosyaları sıfırlamak için tekrar çalıştırılmaz.

```powershell
& {
$tlsLab = Join-Path $env:LOCALAPPDATA 'FullStackOpsLab\deployment-tls'
if (Test-Path -LiteralPath $tlsLab) { throw 'TLS lab dizini mevcut; once incele' }
$mkcertExe = Join-Path $env:LOCALAPPDATA 'FullStackOpsLab\tools\mkcert\mkcert.exe'
if (!(Test-Path -LiteralPath $mkcertExe -PathType Leaf)) { throw 'mkcert bulunamadi' }
$env:CAROOT = Join-Path $tlsLab 'ca'
$env:TRUST_STORES = 'system'
$leafDir = Join-Path $tlsLab 'server'
New-Item -ItemType Directory -Path $env:CAROOT, $leafDir -ErrorAction Stop | Out-Null
& $mkcertExe -install
if ($LASTEXITCODE -ne 0) { throw 'Yerel CA guven kurulumu basarisiz' }
& $mkcertExe -cert-file (Join-Path $leafDir 'server.crt') -key-file (Join-Path $leafDir 'server.key') tasks.fullstackops.test
if ($LASTEXITCODE -ne 0) { throw 'Leaf sertifika uretimi basarisiz' }
Get-FileHash (Join-Path $env:CAROOT 'rootCA.pem'), (Join-Path $leafDir 'server.crt') -Algorithm SHA256
}
```

Yalnız public certificate fingerprint'i paylaşılabilir; private key, PFX veya CA
key içeriği paylaşılmaz. Tarayıcı yeniden açılabilir. Bu güven sadece yerel lab
içindir; production CA çözümü değildir. CA private key veya CAROOT klasörünü SCP ile
gönderme. Windows/VM SSH host fingerprint kontrolü TLS sertifika güveninden farklıdır.

## 7. VM leaf yerleşimi ve ayrı path env — ilk hazırlık referansı

Bu hazırlık bölüm13'teki sonuçlarla tamamlandı; mevcut dosyaların üzerine yazmak
veya .env.https dosyasını yeniden oluşturmak için tekrar çalıştırma.

**Ubuntu SSH**, aynı oturumda repository kökünde:

```bash
tls_directory="$HOME/.local/share/fullstackops-deploy-lab/tls"
(
  set -eu
  test ! -e "$tls_directory/server.crt"
  test ! -e "$tls_directory/server.key"
  install -d -m 700 "$tls_directory"
)
```

Hedef zaten varsa aktarımı durdur; otomatik overwrite/rotation yapma. **Windows
PowerShell**, güncel VM IP'siyle yalnız leaf çiftini aktar:

```powershell
& {
$vmAddress = '172.30.249.139'
$leafDir = Join-Path $env:LOCALAPPDATA 'FullStackOpsLab\deployment-tls\server'
scp (Join-Path $leafDir 'server.crt') (Join-Path $leafDir 'server.key') "labadmin@${vmAddress}:~/.local/share/fullstackops-deploy-lab/tls/"
if ($LASTEXITCODE -ne 0) { throw 'Leaf aktarimi basarisiz' }
}
```

**Ubuntu SSH:** dosya izinlerini ayarla; env dosyası mevcutsa noclobber işlemi durdurur.

```bash
(
  set -eu
  cd ~/fullstack-ops-lab
  chmod 600 "$tls_directory/server.key"
  chmod 644 "$tls_directory/server.crt"
  sha256sum "$tls_directory/server.crt"
  umask 077
  set -C
  printf 'DEPLOYMENT_TLS_DIR=%s\n' "$tls_directory" > .env.https
)
```

Public leaf hash'i Windows ile eşleşmeli. Örnek `https.env.example` aynı key'in
placeholder'ını gösterir; gerçek path VM'de belirlenir. Bu key credential değildir.
.env.deployment'a ekleme veya secret kopyalama yapılmaz. VM izinleri ve aynı
image'ın gerçek TLS dosyalarını okuyabilmesi nginx -t ile doğrulandı (bölüm13).

## 8. Sessiz config ve nginx -t — doğrulama komutları

Kullanıcı bu adımı aynı env/-f sırası ve seçilmiş image ile tamamladı (bölüm13).
Gerçek çalışmada Python stdout/stderr'i bellekte yakaladı, 90 saniye timeout,
benzersiz container adı ve cleanup kontrolü ekledi. Aşağıdaki kısa komutlar
mekanizmayı gösterir; başarılı deneyi yeniden çalıştırma zorunluluğu yoktur.

**Ubuntu SSH**, repository kökünde bir yardımcı shell fonksiyonu tanımla:

```bash
deploy_https() {
  (
    set -eu
    cd ~/fullstack-ops-lab
    sudo docker compose --project-name fullstackops-deploy-lab \
      --env-file .env.deployment --env-file .env.https \
      -f compose.yaml -f infrastructure/deployment/compose.deploy.yaml \
      -f infrastructure/deployment/compose.https.yaml "$@"
  )
}
deploy_https config -q
```

İkinci env yalnız TLS path içermeli; process environment dosyaları ezebilir.
Çözümlenmiş config/env çıktısını paylaşma. [Çoklu env dosyası davranışı](https://docs.docker.com/compose/how-tos/environment-variables/variable-interpolation/).

Sertifika/key dosyaları hazır olduktan sonra, stack'i değiştirmeden kendi geçici
frontend test container'ında syntax ve key eşleşmesini kontrol et:

```bash
deploy_https run --rm --no-deps --pull never --entrypoint nginx frontend -t
```

Bu komut geçici container oluşturur; bölüm13'teki gerçek çalışmada test container'ı
kaldırıldı. Image build/pull yapmaz; build alanı modelden kaldırılmış ve seçilmiş image önceden local'dir.
`run` için service-ports kullanılmaz; mevcut frontend portlarına bind olmaz.
nginx -t başarısızsa burada durulur. Bu test certificate trust/hostname süresinin
browser kabulü yerine geçmez. [Nginx HTTPS yapılandırması](https://nginx.org/en/docs/http/configuring_https_servers.html).

## 9. Etkinleştirme ve tünel — ancak sonraki onaylı adımda

**Ubuntu SSH:** yalnız frontend yeni mount/port için yeniden oluşturulur. Diğer
beş servise dokunulmaz; kısa frontend kesintisi beklenir.

```bash
deploy_https up -d --no-deps --no-build --pull never --wait --wait-timeout 90 frontend
```

`deploy_https ps` ve güvenli inspect alanlarıyla yeni mount'lar/loopback portu/image
kimliği/health yeniden kontrol edilir. Doğru deployment env ve üç -f dosyası bundan
sonraki frontend yönetiminde birlikte kullanılır; iki dosyalı up TLS mount'larını
kaldırabilir. TLS private key loglanmaz, nginx -T/full inspect çıktısı paylaşılmaz.

**Windows hosts:** aşağıdaki eşleme 15 Ekim'de kullanıcı tarafından eklendi ve
doğrulandı; tekrar ekleme. İlk kurulumda yönetici olarak yalnız bu satır eklenir;
var olan satırlar silinmez ve VM DHCP IP'si bu satıra yazılmaz:

```text
127.0.0.1 tasks.fullstackops.test
```

Eşleme önceden varsa tekrar ekleme; bu laboratuvarda satır ekleyip eklemediğini
not et. Daha sonraki kaldırma işlemi yalnız kendi eklediğin eşlemeyi hedeflemeli.

Yol `%SystemRoot%\System32\drivers\etc\hosts`. **Ayrı Windows PowerShell** tüneli,
güncel VM IP'siyle; mevcut HTTP/monitoring tünelleri açık kalır:

```powershell
ssh -N -T -o ConnectTimeout=10 -o StrictHostKeyChecking=yes -o ExitOnForwardFailure=yes -o ServerAliveInterval=30 -o ServerAliveCountMax=3 -L 127.0.0.1:18443:127.0.0.1:18443 labadmin@172.30.249.139
```

Browser: `https://tasks.fullstackops.test:18443/`. Uyarıyı geçmek veya curl -k
kullanmak kabul değildir. **Diğer Windows PowerShell** penceresinde ilk GET:

```powershell
& {
    $curlExe = Join-Path $env:SystemRoot 'System32\curl.exe'
    $result = & $curlExe --disable --noproxy "*" --proto "=https" `
        --ssl-revoke-best-effort --connect-timeout 10 --max-time 20 `
        --fail --silent --show-error --output NUL `
        --write-out 'HTTP=%{http_code};VERIFY=%{ssl_verify_result};IP=%{remote_ip}\n' `
        https://tasks.fullstackops.test:18443/
    $exitCode = $LASTEXITCODE
    Write-Output $result
    if ($exitCode -ne 0 -or
        ($result -join "`n").Trim() -ne 'HTTP=200;VERIFY=0;IP=127.0.0.1') {
        throw 'HTTPS dogrulamasi basarisiz'
    }
}
```

Bu komut Windows Schannel curl ve bu yerel mkcert lab'ı içindir. İlk varsayılan
çağrı CRYPT_E_NO_REVOCATION_CHECK/exit35 verdi; public leaf dosyasında CRL ve AIA
uzantıları bulunmadığı kontrol edildi. `--ssl-revoke-best-effort`, yalnız bu
çağrıda eksik/erişilemeyen iptal dağıtım noktalarını tolere eder. Zincir, hostname
ve geçerlilik doğrulaması açık kalır; **iptal durumunun başarıyla kontrol edildiği
iddia edilmez**. `--insecure`, `-k`, `--ssl-no-revoke` veya sistem geneli ayar
değişikliği kullanılmaz. [Resmî curl seçeneği](https://curl.se/docs/manpage.html#--ssl-revoke-best-effort).
`--disable` kişisel curl config'ini atlar; `--noproxy` yerel bağlantıyı proxy'ye
göndermez. DNS için --resolve kullanılmadı; hosts çözümlemesi de gerçek istekte
kullanıldı. Ayrı uyarısız Windows tarayıcı kabulü bölüm14'tedir.

## 10. Windows değişikliklerini kaldırma — gelecekte, gerektiğinde

Bu bölüm **şimdi çalıştırılmayacak**; Windows CA güveni ve hosts eşlemesi
hazırlandı, kaldırma deneyi yapılmadı. İleride lab erişimini kapatmak istersen:

1. Yalnız yeni HTTPS tünelinin çalıştığı PowerShell penceresinde Ctrl+C kullan.
   Mevcut HTTP/Prometheus/Grafana tünellerini ve VM stack'ini değiştirme.
2. Yönetici olarak `%SystemRoot%\System32\drivers\etc\hosts` dosyasını aç.
   Yalnız bu lab için eklediğin `127.0.0.1 tasks.fullstackops.test` eşlemesini
   kaldır. Önceden var olan kayıtları veya aynı satırdaki başka adları silme.
   Tarayıcıyı kapatıp yeniden aç; gerekirse Windows PowerShell'de
   `ipconfig /flushdns` ile resolver önbelleğini yenile.
3. CA güvenini kaldırmak için kurulumdaki **aynı Windows kullanıcı hesabını**,
   aynı CAROOT dizinini ve `TRUST_STORES=system` seçimini kullan. Önce public
   `rootCA.pem` dosyasının SHA256 hash'ini bölüm6'da kaydettiğin değerle eşleştir.
   Dosya yoksa veya hash eşleşmiyorsa dur; varsayılan/başka CA ile deneme yapma.

**Windows PowerShell**, yalnız kaldırma kararı verildiğinde; bu blok sertifika
deposunu değiştirir. İstenecek hash public certificate dosyasının hash'idir,
private key veya credential değildir:

```powershell
& {
$env:CAROOT = Join-Path $env:LOCALAPPDATA 'FullStackOpsLab\deployment-tls\ca'
$env:TRUST_STORES = 'system'
$mkcertExe = Join-Path $env:LOCALAPPDATA 'FullStackOpsLab\tools\mkcert\mkcert.exe'
if (!(Test-Path -LiteralPath $mkcertExe -PathType Leaf)) { throw 'mkcert bulunamadi' }
$publicCA = Join-Path $env:CAROOT 'rootCA.pem'
if (!(Test-Path -LiteralPath $publicCA -PathType Leaf) -or
    !(Test-Path -LiteralPath (Join-Path $env:CAROOT 'rootCA-key.pem') -PathType Leaf)) {
    throw 'Ayni lab CA dosyalari yok; kaldirma durdu'
}
$expectedHash = (Read-Host 'Kurulumda kaydedilen public rootCA.pem SHA256').Trim()
if ($expectedHash -notmatch '^[0-9a-fA-F]{64}$' -or
    (Get-FileHash -LiteralPath $publicCA -Algorithm SHA256 -ErrorAction Stop).Hash -ne $expectedHash) {
    throw 'Public CA hash eslesmedi; kaldirma durdu'
}
& $mkcertExe -uninstall
if ($LASTEXITCODE -ne 0) { throw 'Lab CA guven kaldirma basarisiz; durumu incele' }
}
```

mkcert `-uninstall` CA dosyalarını silmez. Windows implementasyonu yüklenen CA'nın
seri numarasıyla eşleşen güven kayıtlarını kaldırır; genel ada göre tüm mkcert
sertifikalarını silen bir komut kullanılmaz. Kaynak:
[mkcert uninstall davranışı](https://github.com/FiloSottile/mkcert/blob/master/truststore_windows.go).
Kaldırmadan önce CA dizinini silme veya farklı bir CA üretme. Ardından Windows
sertifika yöneticisinde kaydettiğin public CA'nın parmak izi/seri numarasıyla
eşleşen güven kaydının kaldırıldığını kontrol et; başka sertifikaları silme.
Bu işlemler VM leaf dosyalarını, mount'ları veya frontend'i otomatik değiştirmez;
HTTPS listener açık kalsa bile artık tarayıcı güveni kabulü beklenmez.
VM TLS kaldırma/yenileme ve private dosyaların güvenli temizliği ayrı rehberli
işlemlerdir; burada volume veya sertifika dizini silme komutu verilmez.
Windows hazırlığı bölüm12, tarayıcı HTTPS kabulü bölüm14'te **PASS**;
gerçek güven/hosts kaldırma işlemi **NOT VERIFIED** ve şimdi uygulanmaz.

## 11. Statik sonuç ve açık kabul maddeleri

Gerçek Compose parser ile testler: **5/5 PASS**. Önce HTTPS overlay eksikliği ve
ignore eksikleri nedeniyle beklenen RED, dosyalardan sonra GREEN görüldü.
Windows Git stdin newline farkı test taşımasında NUL ayırıcıyla giderildi.

| Madde | Durum |
| --- | --- |
| İki env dosyasıyla sessiz config/model parse | PASS; yerel testte sahte fixture, VM'de gerçek env kullanıcı çıktıları bölüm13–14 |
| Aynı altı servis/network/volume ve seçilmiş image çiftleri; build yok | PASS |
| HTTPS yalnız127.0.0.1:18443; HTTP18081/monitoring aynı; diğer beş servis modeli aynı | PASS |
| Üç read-only bind ve create_host_path false; CA dizini mount edilmez | PASS |
| TLS path eksik/boş ise güvenli anahtar adıyla hata | PASS |
| Sertifika/key/env ignored, örnek takip edilebilir; eski deployment/development testleri | PASS |
| Rehberdeki7 PowerShell ve8 Bash bloğunun yalnız sözdizimi | PASS; statik aşamada yürütülmedi; Windows hazırlık sonuçları bölüm12'de |
| Statik aşamadaki secret leakage,62 yerel belge bağlantısı/anchor ve diff whitespace kontrolü | PASS; b19f620 hazırlık kanıtı |
| Windows hosts/güven yönergeleri | Uygulama PASS, kaldırma NOT VERIFIED; bölüm12 |
| Windows certificate SAN/süre, CA zinciri ve leaf private key eşleşmesi | PASS; kullanıcı OpenSSL çıktıları, bölüm12 |
| VM aktarımı, izinler, gerçek model ve Nginx SSL syntax/certificate-key okuması | PASS; kullanıcı nginx -t exit0 ve iki başarı mesajını doğruladı, bölüm13 |
| VM/Windows18443 ve gerçek HTTPS yayını | PASS; hazırlıkta boş, etkinleştirmede yalnız VM/Windows loopback; bölüm14 |
| Gerçek HTTPS HTML/JS/CSS ve API Location/same-origin davranışı | PASS; manuel tarayıcı/Network ve curl API sonuçları, bölüm14 |
| HTTPS sonrası altı health, frontend image ve diğer beş container kimliği | PASS; gerçek inspect, bölüm14 |
| Monitoring portlarının korunması / yeni monitoring sorguları | Portlar ve healthy PASS; sorgu/browser kabulü bu adımda tekrarlanmadı, 15 Ekim kanıtı ayrı |
| Varsayılan Schannel curl iptal kontrolü / best-effort çağrı | Varsayılan çağrı FAIL exit35; best-effort ile zincir/hostname/geçerlilik PASS, iptal durumu NOT VERIFIED |
| Yenileme/reload, public CA/domain/internet kabulü | NOT VERIFIED |

YAML/static test, Windows sertifika hazırlığı ve nginx -t tek başına başarılı
HTTPS bağlantısı anlamına gelmez. Ayrı etkinleştirme ve runtime kanıtı bölüm14'te
elde edildi; eski aşamalardaki NOT VERIFIED kayıtları tarihsel sınırları korur.

Gerçekte çalıştırılan yerel komut `py -3 tests/Deployment.Configuration.Test.py`;
test kendi sahte env dosyalarıyla `docker compose ... config -q` ve JSON model
kontrolü yapar. Ayrıca secret scanner, git diff --check ve yalnız parser kontrolleri
çalıştırıldı. Git Bash -n ilk sandbox çağrısında signal pipe erişim engeli verdi;
aynı syntax-only kontrol izinli yerel süreçte geçti. Bu bir VM komut hatası değildir.
Statik aşamadaki temporary fixture dosyaları test sonunda kaldırıldı; o aşamada
certificate/key üretilmedi. Bu statik hazırlık daha sonra b19f620 ile commit/push
edildi. Windows hazırlığı aşağıda ayrı kaydedilir; VM/tünel/Docker kaynaklarına
bu hazırlık sırasında hiçbir işlem gönderilmedi.

## 12. Windows CA, leaf ve hosts kabulü — 15 Ekim 2026

Bu bölüm b0d2fea ile kaydedilen Windows hazırlığının tarihsel kapanışıdır;
ondan sonraki VM aktarımı/nginx -t sonucu bölüm13'tedir.

Kanıt kullanıcı tarafından Windows PowerShell'de çalıştırılan grupların paylaşılan
çıktılarıdır; agent private key, gerçek env veya user-secrets içeriğini okumadı.
Başlangıçta mkcert PATH'te bulunmadı, ayrılmış lab dizini/CA/leaf dosyaları ve
CAROOT process ayarı yoktu. Yeni CA yalnız bu ayrılmış lab için oluşturuldu.

| Kontrol | Gerçek sonuç |
| --- | --- |
| Portable mkcert | Resmî GitHub v1.4.4 Windows amd64 dosyası; SHA256 eşleşmesi ve sürüm PASS |
| Araç yeri | `%LOCALAPPDATA%\FullStackOpsLab\tools\mkcert\mkcert.exe`; PATH değiştirilmedi |
| CA yeri | `%LOCALAPPDATA%\FullStackOpsLab\deployment-tls\ca`; repository dışında |
| Windows güveni | `TRUST_STORES=system`, `mkcert -install`; beklenen thumbprint `Cert:\CurrentUser\Root` içinde PASS |
| Leaf yeri | `%LOCALAPPDATA%\FullStackOpsLab\deployment-tls\server\server.crt` ve `server.key`; repository dışında |
| OpenSSL | Git for Windows içindeki OpenSSL3.5.6; çıktı `7 Apr 2026` |
| SAN | Tek DNS adı `tasks.fullstackops.test` PASS |
| Geçerlilik | `notBefore=Oct 15 10:59:05 2026 GMT`, `notAfter=Jan 15 10:59:05 2029 GMT` |
| Zincir/amaç/hostname/zaman | Explicit lab CA ile `openssl verify -purpose sslserver -verify_hostname ...` exit0, PASS |
| Leaf key eşleşmesi | x509 `-pubkey` ile pkey `-pubout` çıktıları bellekte case-sensitive eşit; yalnız PASS yazdırıldı |
| Hosts başlangıcı | İlgili ad için aktif kayıt YOK; kullanıcı gerekli tek satırı ekledi |
| Hosts son kontrol | Tam bir adet `127.0.0.1 tasks.fullstackops.test` kaydı ve Windows DNS çözümlemesi127.0.0.1 PASS |

mkcert binary SHA256:
`D2660B50A9ED59EADA480750561C96ABC2ED4C9A38C6A24D93E30E0977631398`.
Kaynak [resmî v1.4.4 yayını](https://github.com/FiloSottile/mkcert/releases/tag/v1.4.4);
karşılaştırma değeri [Microsoft WinGet manifestinden](https://github.com/microsoft/winget-pkgs/blob/master/manifests/f/FiloSottile/mkcert/1.4.4/FiloSottile.mkcert.installer.yaml)
alındı; ayrı bir yayıncı imzalı checksum doğrulaması iddia edilmez.

Aşağıdaki kimlikler **public sertifika metadata'sıdır**, private key değildir:

- CA thumbprint: `BCEB2EF69B3D6D487495B49F9EDF10F66BD96E49`.
- Public rootCA.pem dosyası SHA256: `A154DBB8BC935F93A50D4FB39212682F9F8C372E30DB5CBD9D3C3B3F72ACDF6E`.
- Public server.crt dosyası SHA256: `356FA31482DCC3BD07BAFBC45A159CD052E392156A2DCA299416209878D8770D`.

Sonraki aktarımda public leaf hash'i eşleştirilir; CA private key Windows'ta kalır.
Güveni kaldırma gerektiğinde bölüm10'daki aynı CA kimliği/dizini kontrolü kullanılır;
hosts için yalnız bu görevde eklenen satır kaldırılır. Şimdi kaldırma yapılmadı.
OpenSSL explicit CA doğrulaması ile Windows depo kaydının varlığı ayrı kontrollerdir;
hiçbiri henüz kurulmamış VM HTTPS listener'ı veya browser TLS kabulü yerine geçmez.
Kullanılan OpenSSL davranışı: [x509](https://docs.openssl.org/3.5/man1/openssl-x509/),
[pkey](https://docs.openssl.org/3.5/man1/openssl-pkey/),
[verify](https://docs.openssl.org/3.5/man1/openssl-verify/).

VM'ye config/leaf aktarımı, `.env.https` hazırlığı, nginx -t, yeni18443 SSH tüneli,
frontend TLS recreate ve HTTPS HTML/asset/API/CRUD/browser kabulü **NOT VERIFIED**.
Bu görevde build, migration, kesinti veya veri işlemi yapılmadı. Seçilmiş
source1b52633776279b1661a7cac53392d385cbf10444/GHCR digest çifti ve release.json
değişmedi; VM stack'i ve mevcut tüneller değişmedi. Commit/push yapılmadı.

Bu Windows hazırlığı kaydının repository kontrolleri: secret leakage exit0,
64 yerel belge bağlantısı/anchor PASS, rehberdeki7 PowerShell bloğu syntax-only
PASS ve git diff --check exit0. Yalnız bu rehber, deployment README/planı ve
PROJECT_STATUS güncellendi; index boş. Windows/VM işlemleri agent tarafından
tekrarlanmadı; private dosyalar Git'e eklenmedi.

## 13. VM TLS aktarımı ve geçici nginx -t kabulü — 15 Ekim 2026

Kullanıcı Windows PowerShell ve Ubuntu SSH gruplarını çalıştırıp sonuçları
paylaştı. Agent VM'ye bağlanmadı, private key veya gerçek env içeriği okumadı.
Başlangıç Git temizdi (HEAD b0d2fea). VM hostname fullstackopslabvm,
IP172.30.249.139/20 ve Windows'tan SSH hostname kontrolü PASS. Altı servis
başlangıçta healthy idi; VM18443 ss çıktısı yalnız başlık içeriyordu.
Public HTTPS config/overlay/örnek, .env.https ve VM leaf dosyalarının hedefte
başlangıçta bulunmadığı kontrol edildi; mevcut dosyalar ezilmedi.

Yalnız üç public config SCP ile mevcut VM kaynak ağacına eklendi; root Compose,
deployment overlay, release.json ve diğer kaynaklar topluca değiştirilmedi.
Windows dosya byte hash'leri VM'de sha256sum --check ile üç kez OK verdi:

| Aktarılan public dosya | SHA256 |
| --- | --- |
| compose.https.yaml | `533F3B78C5D8E86876DAC7DEB61EFDCC11A3D4C10F9B96870211E313848E1F9D` |
| https.env.example | `E2C469AF9062509E4EA491F5C6E14852EEBFB5C6643C46971FAE94D07F2244B1` |
| nginx/https.conf | `1CDEE6ACA92F5FB641972980173F3C67548124E3245928AA826D8588EF5E4628` |

Bu değerler Windows→VM aktarım bütünlüğüdür; Git blob hash'i değildir, checkout
satır sonu dönüşümleriyle karıştırılmaz. Ardından yalnız server.crt/server.key
tekil yollarıyla aktarıldı; CA private key ve development secret'ları aktarılmadı.
Public leaf SHA256 bölüm12'deki356FA314... değeriyle VM'de OK verdi.

| Kontrol | Gerçek sonuç |
| --- | --- |
| VM lab üst klasörü ve tls klasörü | /home/labadmin/.local/share/fullstackops-deploy-lab ve altındaki tls:700, sahibi labadmin |
| Sunucu dosyaları | server.key600, server.crt644; sahibi labadmin, repository dışında |
| Ayrı path dosyası | VM checkout kökünde .env.https600/labadmin; yalnız DEPLOYMENT_TLS_DIR, noclobber ile oluşturuldu; mevcut .env.deployment ezilmedi |
| Sessiz Compose config | Gerçek deployment/TLS env dosyalarıyla config -q exit0; stdout/stderr değerleri paylaşılmadı |
| Birleşmiş model | Altı servis/fullstackops-deploy-lab project/mevcut app ağı PASS |
| Image seçimi | Source1b52633776279b1661a7cac53392d385cbf10444 ve release.json API/frontend digest eşleşmesi; build alanları yok PASS |
| Host portları | API/PostgreSQL/Redis yok; frontend127.0.0.1:18081 ve18443, Prometheus127.0.0.1:19090, Grafana127.0.0.1:13000 yalnız modelde PASS |
| Mount'lar | Tam üç farklı hedef; doğru config/iki leaf dosyası, bind/read-only/create_host_path false PASS; CA mount yok |
| Volume ayarları | Ayrı deployment PostgreSQL/Prometheus/Grafana adları, PostgreSQL external PASS; volume işlemi yok |
| Mevcut frontend probe'u | Modelde HTTP80 wget healthcheck korunuyor PASS |
| Image kimliği | Seçilmiş frontend digestinin local image ID'si mevcut frontend container Image kimliğiyle eşleşiyor PASS |
| Geçici test | Aynı Compose modeliyle run --rm --no-deps --pull never -T --entrypoint nginx frontend -t; benzersiz tls-check adı, 90s timeout |
| nginx -t sonucu | Exit0 ve yakalanan çıktıda hem syntax is ok hem test is successful; yalnız güvenli PASS/status yazdırıldı |
| Cleanup | --rm ve gerekirse yalnız benzersiz test adına rm -f; son name sorgusunda container yok PASS |
| Çalışan stack | Başlangıç/bitiş altı container kimlikleri eşit PASS; final tabloda hepsi running/healthy |
| Etkin HTTPS portu | Final ss18443 listener yok; çalışan frontend yalnız127.0.0.1:18081→80; TLS henüz etkin değil |

Başlangıç ve bitişte korunan container ID'leri:

| Servis | Kısa container ID |
| --- | --- |
| frontend | 469774f333b6 |
| api | 4d572817ca12 |
| prometheus | 84eaf1ceebb5 |
| redis | d98d34cc73c5 |
| grafana | ed9398e62129 |
| postgres | e9296c518548 |

Finalde monitoring yayınları19090→9090 ve13000→3000 loopback olarak kaldı;
API8080/Redis6379/PostgreSQL5432 yalnız container portlarıdır. TLS klasörü700,
crt644, key600 ve .env.https600 final stat çıktısıyla tekrar doğrulandı.
Test host portu yayınlamadı; frontend recreate, build/pull, migration, CRUD,
cache temizleme veya kesinti yapılmadı. Mevcut kaynak ağacı/volume/network
silme veya prune işlemi yoktur;
tüm Docker network/volume ID envanterinin ayrıca tekrar ölçüldüğü iddia edilmez.
Seçilmiş GHCR çifti ve release.json korundu; stack mevcut haliyle çalışır bırakıldı.

Sınır: nginx -t, SSL yönergelerini ve gerçek mount'lardaki cert/key dosyalarının
okunmasını test eder; çalışan bir HTTPS listener, tarayıcı güveni, HTTP/API/CRUD
veya monitoring regresyon kabulü değildir. Yeni18443 tüneli açılmadı, frontend
etkinleştirilmedi; bu kontroller **NOT VERIFIED**. Sonraki küçük adım yalnız ayrı
rehberli frontend TLS etkinleştirmesi ve HTTPS erişim kabulüdür; otomatik başlanmaz.
Bu görevde yalnız dört repository belgesi güncellenir; commit/push yapılmadı.

Repository belge kontrolleri: secret leakage exit0,66 yerel dosya/anchor bağlantısı
PASS,7 PowerShell bloğu syntax-only PASS ve git diff --check exit0. Uygulama,
Compose, release.json ve test kodu değiştirilmedi; index boş, yeni dosya yok.

## 14. HTTPS etkinleştirme ve runtime kabulü — 15–16 Ekim 2026

Başlangıç repository temizdi, HEAD a5fb235. Kullanıcı komutları Windows PowerShell
ve Ubuntu SSH terminallerinde çalıştırıp sonuçlarını paylaştı; agent VM'ye
bağlanmadı, gerçek env/private key okumadı. Etkinleştirme 15 Ekim'de, son erişim,
CRUD ve kimlik/health kontrolleri 16 Ekim'de tamamlandı. Test edilen uygulama
kaynağı değişmedi: `1b52633776279b1661a7cac53392d385cbf10444`; image referansları
[release.json](release.json) içindeki aynı API/frontend digest çiftidir.

### Frontend'e uygulama ve erişim

Başlangıç altı container healthy ve VM18443 boştu. İki env ve üç Compose dosyasıyla
sessiz config -q PASS; aynı frontend image ve gerçek bind'larla geçici nginx -t
exit0. Benzersiz kontrol container'ı temizlendi. Ardından yalnız frontend:

```bash
sudo docker compose --project-name fullstackops-deploy-lab \
  --env-file .env.deployment --env-file .env.https \
  -f compose.yaml \
  -f infrastructure/deployment/compose.deploy.yaml \
  -f infrastructure/deployment/compose.https.yaml \
  up -d --no-build --no-deps --pull never --wait --wait-timeout 90 frontend
```

Health beklemesi başarılıydı. Frontend469774f333b6 yerine e401eb7fbff5 oluştu;
API ve diğer dört bağımlılık yeniden oluşturulmadı. Gerçek frontend image ref'i,
local selected image ve container Image kimliği frontend digest'iyle eşleşti:
`sha256:e0c77449225c4cd602e8f3b2af43a68ca3ad1578ce6428ba8ddcccf1fa612627`.
Nginx config/leaf crt/key için üç bind RW=false; CA mount yok. VM ss yalnız
127.0.0.1:18443 listener gösterdi. Eski HTTP18081 GET200 ve text/html korundu.

Windows18443 boşluğu kontrol edilip güncel VM IP172.30.249.139'e yukarıdaki
SSH tüneli açıldı; Windows listener127.0.0.1:18443 ve sahibi ssh doğrulandı.
16 Ekim'de kullanıcı pencereleri kapattıktan sonra Hyper-V konsolu yanıt vermedi.
SSH erişimi ve altı mevcut container'ın healthy/aynı ID olduğu doğrulandı;
VM veya Docker yeniden başlatılmadı. Port boşken yalnız HTTPS tüneli yeniden
açıldı, tarayıcı erişimi geri geldi. Konsolun yanıt vermeme kök nedeni belirlenmedi.

### Sertifika ve istemci sınırlaması

| Kontrol | Gerçek sonuç |
| --- | --- |
| İlk Schannel curl 8.21.0 | FAIL; CRYPT_E_NO_REVOCATION_CHECK (0x80092012), exit35, HTTP000; VERIFY0 tek başına başarı sayılmadı |
| Public leaf dosyası | Önceden kaydedilmiş SHA256 ile aynı; CRL2.5.29.31 ve AIA1.3.6.1.5.5.7.1.1 uzantıları yok |
| Komuta özel --ssl-revoke-best-effort | HTTP200; VERIFY0; IP127.0.0.1; exit0; zincir/hostname/zaman kontrolleri açık |
| Tarayıcı | Kullanıcı tasks.fullstackops.test:18443 adresinin sertifika uyarısı olmadan açıldığını bildirdi |
| Sertifika bilgisi | mkcert development certificate/CA; 15Ekim2026 13:59:05 → 15Ocak2029 13:59:05 Türkiye saati, önceki UTC kayıtlarıyla uyumlu |
| CN/SAN | Leaf CN boş; önceki OpenSSL SAN tasks.fullstackops.test kontrolü ve URL hostname kabulü geçerli; CN'den isim doğrulama iddiası yok |
| HTML ve asset erişimi | HTTPS root curl200 ve tarayıcı render; gerçek index-6SMY9-rQ.css ve index-CKhYhs0u.js istekleri HTTPS GET200 |
| Console/mixed-content | Kullanıcı F12 Network/Console kontrolünde hata olmadığını bildirdi; otomatik browser/console testi yapılmadı |

CRL/OCSP iptal durumu kanıtlanmadı. Bu yerel CA'nın public/production sertifika
kabulü değildir. Sistem trust/security ayarı, CA, sertifika veya image değiştirilmedi;
uyarı atlama veya TLS doğrulamasını kapatan callback/flag kullanılmadı. HTTPS
asset MIME başlıkları ayrıca paylaşılmadı; 15 Ekim HTTP asset MIME kanıtıyla aynı
ölçüm gibi sunulmaz. Tarayıcı gözlemi manuel ve o kontrol anıyla sınırlıdır.

### HTTPS API contract ve test kaydı temizliği

İstekler Windows curl, aynı best-effort sınırlaması ve aynı HTTPS origin üzerinden
gönderildi. Gövdeler UTF-8 BOM'suz geçici dosyalarla iletildi; credential okunmadı.

| Kontrol | Gerçek sonuç |
| --- | --- |
| Liste GET | HTTP200; application/json; charset=utf-8; curl exit0 |
| POST | HTTP201; yalnız bu teste ait benzersiz görev ID3 |
| Location | /api/tasks/3; https://tasks.fullstackops.test:18443/api/tasks/3 olarak çözüldü; HTTPS host/port korundu |
| İlk JSON ve tekil GET | Tam id/title/description/isCompleted/createdAt/updatedAt; GET200, description null, isCompleted false |
| PUT | HTTP200; başlık güncellendi, isCompleted true, description null; altı alan ve createdAt korundu, updatedAt ilerledi |
| Güncellemenin tekrar okunması | Tekil GET200; güncellenen değerler doğrulandı |
| Boş başlık | POST400 ve test kaydına PUT400 |
| Bulunmayan ID | Tekil GET2147483647 için404 |
| Negatif testlerin etkisi | Önce/sonra tekil GET yanıtları aynı; test görevi değişmedi |
| Temizlik | Benzersiz başlık/ID/createdAt ile sahiplik kontrolünden sonra yalnız ID3 DELETE204, boş gövde; ardından GET404 |

Test kaydı createdAt UTC `2026-10-16T10:16:41.132838+00:00` idi; silme öncesi
aynı değer doğrulandı. Liste yanıtları veya başka görevlerin içerikleri loglanmadı.
Diğer kayıtlara silme isteği gönderilmedi. Normal mutation cache invalidation'ı
korundu; elle cache/key silme, FLUSH veya yeni cache/TTL regresyonu yapılmadı.

İlk liste kontrolünün regex'i geçerli `application/json; charset=utf-8` değerini
yanlış reddetti. HTTP200/exit0 çıktısı incelenip charset'i kabul eden kontrol
düzeltildi; API/config hatası sayılmadı, yeniden POST veya uygulama değişikliği
yapılmadı. İstek başarılı olsa da hatalı assertion PASS gibi saklanmadı.

### Son durum ve açık işler

16 Ekim son salt okunur inspect sonucu aşağıdadır. Kimlikler başlangıçla
karşılaştırıldı; frontend TLS recreate sonrası yeni ID'sini, diğer beş servis
etkinleştirme öncesi ID'lerini korudu.

| Servis | Container ID başlangıcı | State / health | Host bind |
| --- | --- | --- | --- |
| frontend | e401eb7fbff5 | running / healthy | 127.0.0.1:18081→80 ve127.0.0.1:18443→443 |
| api | 4d572817ca12 | running / healthy | Yok |
| postgres | e9296c518548 | running / healthy | Yok |
| redis | d98d34cc73c5 | running / healthy | Yok |
| prometheus | 84eaf1ceebb5 | running / healthy | 127.0.0.1:19090→9090 |
| grafana | ed9398e62129 | running / healthy | 127.0.0.1:13000→3000 |

Test Task3 ve istemci geçici payload/response/header dosyaları temizlendi;
geçici nginx kontrol container'ı kalmadı. Stack ve HTTPS tüneli açık bırakıldı.
Monitoring sorguları bu adımda yeniden çalıştırılmadı; finalde healthy/ID/port
koruması doğrulandı, 15 Ekim datasource/12 panel/yeni örnek kanıtı ayrı kalır.
Development env/user-secrets/volume'ları kullanılmadı; VM TLS env/key/sertifika
dosyaları Git dışında, seçilmiş kaynak/digestler ve release.json değişmedi.

Bu sonuç yerel HTTPS küçük adımını tamamlar. Deployment PostgreSQL recreate
kalıcılığı, sürüm güncelleme/rollback, backup/restore ve lab kapanışı bekliyor.
Yeni kesinti/performans veya public domain/internet/production kabulü yok;
manuel öğrenme değerlendirmesi hâlâ NOT VERIFIED. Commit/push yapılmadı.

16 Ekim repository kontrolleri: `py -3 tests/Deployment.Configuration.Test.py`
5/5 PASS (yalnız sahte fixture/Compose parser, Engine kaynağı oluşturmaz),
repository secret leakage exit0,70 yerel dosya/anchor bağlantısı PASS,
7 PowerShell belge bloğu syntax-only PASS ve git diff --check exit0. İlk statik
test çağrısı sandbox geçici dosya izni nedeniyle çalışamadı; uygun izinle tekrar
geçti, ilk çağrının oluşturduğu yalnız beş boş fixture klasörü tam ad/zaman/yol
kontrolüyle temizlendi. Gerçek env/key dosyaları okunmadı; kök .env ignored ve
untracked kontrolü PASS. Yalnız HTTPS/deployment README, deployment planı ve
PROJECT_STATUS değişti; index boş, yeni dosya veya application/config değişikliği
yok. VM runtime deneyleri agent tarafından tekrarlanmadı.

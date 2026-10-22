# Günlük PostgreSQL yedekleme — kurulum ve kabul kayıtları

**21 Ekim 2026: VM kurulumu ve timer kapalıyken iki manuel service çalışması PASS.**
İlk gerçek günlük dump ve aynı gün üzerine yazmadan doğrulama tamamlandı;
[gerçek sonuçlar aşağıdadır](#rehberli-vm-kurulumu-ve-iki-manuel-çalışma--21-ekim-2026).
Timer **disabled/inactive** kaldı. Zamanlanmış tetik/catch-up, gerçek çok günlük
retention, yeni günlük arşivin Windows kopyası ve restore kabulü **NOT VERIFIED**.
Önceki [manuel dump/restore ve cleanup](../BACKUP-RESTORE.md) kanıtları ayrı kalır.
Deployment A, HTTPS, release digestleri ve development kaynakları korunmuştur.

## Dosyalar ve çalışma şekli

- [daily-backup.py](daily-backup.py): Python 3.11+ standart kütüphanesi; Ubuntu
  24.04'ün Python 3.12/tzdata'sı yeterli. Docker SDK, ek Python paketi veya env
  dosyası gerekmez. `/usr/bin/python3` kullanılır, image build/pull/recreate yok.
- [service](fullstackops-pg-backup.service): root oneshot; yerel Docker socket'ine
  erişmek için root gerekir, labadmin'i docker grubuna eklemez. Credential unit'e
  yazılmaz. Root'a ait script ve unit dosyalarını yalnız yönetici değiştirebilir.
- [timer](fullstackops-pg-backup.timer): her gün **02:00 Europe/Istanbul**
  (bugünkü UTC+03:00 kurallarıyla 23:00 UTC, önceki UTC günü). VM timezone'u UTC
  olsa da takvim ve script'in gün anahtarı İstanbul'dur. UTC zamanlar metadata'dadır.
- [Fixture testleri](../../../tests/Deployment.DailyBackup.Test.py): yalnız Docker
  subprocess sınırı taklit edilir; dosyalar, atomik terfi, hash, retention ve iki
  süreç kilidi gerçektir. Testler gerçek Docker/VM/backup dosyasına erişmez.

Timer `AccuracySec=1min` nedeniyle tam saniye garantisi vermez. `Persistent=true`,
VM/timer yeniden açıldığında kaçırılmış takvim için **bir** telafi çalışması
başlatabilir. Kapalı kalınan her gün için geçmiş veri üretilmez; telafi bugünkü
veriyi bugünün İstanbul klasörüne kaydeder. Aynı gün zaten başarı varsa yeniden
dump almaz. Uyuyan host'u uyandırma veya kapalı VM'yi açma ayarı yoktur.
Boot telafisinde Docker açılmış ama PostgreSQL henüz healthy değilse kaynak
kapısı nonzero ile durur; otomatik retry yoktur. Durum incelenip aynı servis
elle tekrar çalıştırılabilir, aksi halde sonraki takvim tetiki beklenir.
[systemd timer](https://www.freedesktop.org/software/systemd/man/latest/systemd.timer.html),
[timezone takvimi](https://www.freedesktop.org/software/systemd/man/latest/systemd.time.html).

## Dump ve tamamlanmış set

Hedef yalnız `/var/lib/fullstackops-deploy-lab-backup/`, root sahibi/700.
Script `.owner` işaretiyle kendi dizinini tanır; boş olmayan işaretsiz dizini
devralmaz. Git içi, symlink veya `backups-private` yolu reddedilir. Dosyalar600,
gün ve partial dizinleri700; izin/sahiplik uyuşmazlığında durur, mevcut izinleri
sessizce genişletmez. `--root` fixture veya ayrıca incelenmiş başka **ayrı** bir
özel hedef içindir; unit varsayılan yolu kullanır. Elle başka kökle paralel iş
başlatmak kilit korumasını paylaşmaz, desteklenen işletim şekli değildir.

1. Bütün iş boyunca `.lock` dosyasında nonblocking OS kilidi tutulur. Linux'ta
   flock; Windows fixture'ında msvcrt. İkinci süreç **75** ile durur ve çalışan
   işin durum dosyasını ezmez. Kilit process çıkınca OS tarafından bırakılır;
   `.lock` dosyasını silme. Systemd de aktif oneshot'ı tekrar başlatmaz.
2. Kaynak adı `fullstackops-deploy-lab-postgres-1`; exact Compose project/service,
   running/healthy, host portu yokluğu, tek `fullstackops-deploy-lab-postgres`
   volume → `/var/lib/postgresql` mount'u kontrol edilir. Sonraki exec/cp çağrıları
   ad yerine tam container ID kullanır. Server/pg_dump/pg_restore 18.x sürümleri
   eşleşmelidir; araçlar çalışan source image'ındandır. Yanlış hedefte dump yok.
3. Önce kaynak container'da benzersiz `/tmp/fullstackops-daily-<uuid>/`700 ve
   `pg_dump --format=custom --no-privileges --no-password` dosyası hazırlanır.
   Socket hedefi `/var/run/postgresql`, database/role container içindeki mevcut
   ayarlardan alınır; parola okunmaz veya argümana yazılmaz. Bu yeni TCP auth testi
   değildir. Lock beklemesi5s, container dump sınırı180s, Docker çağrısı240s,
   servis üst sınırı15min. Raw stdout/stderr journal'a veya dosyaya kopyalanmaz;
   warning dahil stderr varsa iş başarısızdır. Güvenli log aşama/exit ile sınırlıdır.
4. VM'de yalnız `.partial-<uuid>/database.pgdump` dosyasına kopyalanır. Container
   ve VM SHA256 eşitliği, boyut, aynı araçla `pg_restore --list` exit0 ve
   tasks/history verisi ile sequence kaydının arşiv listesinde bulunması gerekir.
   Kaynak kimliği yeniden kontrol edilir; yalnız oluşturulan container/tmp
   dosyası ve dizini kaldırılır. Temizlik hatası da başarıyı engeller.
5. Manifest owner/gün/timezone, UTC tamamlanma, byte/SHA256, source container/image/
   volume ve araç sürümlerini içerir; credential/env içermez. Dump ve manifest
   hazırsa aynı filesystem üzerinde dizin `YYYY-MM-DD` adına atomik taşınır.
   Sonra `last-success.json` güncellenir ve retention yapılır. Pointer yazımı
   yarıda kalırsa aynı gün yeniden çalışma mevcut seti doğrulayıp asıl tamamlanma
   zamanını koruyarak pointer'ı onarır. Atomik rename, elektrik kesintisine karşı
   tam dayanıklılık garantisi değildir.

Dump/kopya/arşiv hatasında yeni set/son başarı yaratılmaz ve retention başlamaz;
eski sağlam setler korunur. Partial'lar tamamlanmış sayılmaz, otomatik retention'a
girmez. Kesilen işlem private partial/container tmp bırakabilir; sonraki ayrı
tanıda tam isim/sahiplik kontrolüyle ele alınır, genel `/tmp` temizliği yapılmaz.
Systemd işi zorla öldürürse son-attempt eski kalabilir; systemd Result/journal
bu nedenle ayrıca kontrol edilir. `pg_restore --list` veya hash eşitliği gerçek
restore kanıtı değildir; yeni günlük arşivden izole restore kabulü hâlâ bekler.
[pg_dump18](https://www.postgresql.org/docs/18/app-pgdump.html),
[pg_restore18](https://www.postgresql.org/docs/18/app-pgrestore.html).

## Saklama kuralı

**Son yedi farklı başarılı İstanbul günü** tutulur; başarısız/kaçırılmış gün
sayılmaz. İlk başarılı set o günü temsil eder. Aynı gün tekrar çalıştırma hash'i
doğrular, yeni dump almaz, eski seti ezmez ve başarı zamanını tazelemez. Mevcut
aynı-gün seti bozuksa otomatik üzerine yazma yapılmaz; nonzero ile durur.

Retention yalnız yeni/doğrulanmış tamamlanmış set sonrasında, aynı kilit altında
çalışır. Dizin tarihi + exact owner manifest + yalnız beklenen iki normal dosya +
boyut/hash/izin kontrolü gerekir. Önce **bütün** adaylar doğrulanır, sonra en eski
fazlalıkların sadece iki bilinen dosyası ve boş dizini kaldırılır; recursive/prune
yoktur. Bozuk sahipli set, ek dosya veya symlink durdurur; yabancı/işaretsiz setler
atlanır. Gelecek tarihli sahipli set clock hatası olarak durdurur. Retention
I/O hatası nonzero'dur; kalan setler incelenir, körlemesine temizlenmez. Aynı-gün
tekrar denemesi retention hatasını başarı olarak gizlemez.

VM'deki `~/.local/share/fullstackops-deploy-lab/backups-private/4756810b5b43/`
manuel kabul seti ve Windows kopyaları bu ağacın dışındadır; script onlara
erişmez veya silmez. Root ağacına elle dosya/manuel yedek taşımayın.

## Windows ikinci kopyası ve RPO

**Manuel SCP** kalır; timer Windows'a bağlanmaz. VM retention'ı Windows kopyası
onayını beklemez: bu görevde önceki öneri somut olarak bu iki ayrı sorumluluğa
ayrıldı. Güncel ikinci kopya sağlanmazsa VM'deki son7 sete rağmen RPO sağlandı denmez.

Gelecek rehberli kopya adımı: seçili tamamlanmış günlük seti root manifest/hash ile
doğrula; yalnız dump+manifest'i labadmin'e ait Git dışı yeni700 staging dizinine
`sudo install -o labadmin -g labadmin -m600` ile kopyala. Root backup dizininin
izinlerini açma. SCP ile Windows'ta mevcut kullanıcıya özel ACL'li ayrı
`LOCALAPPDATA/FullStackOpsLab/backups-private/daily/YYYY-MM-DD/` hedefine aktar;
boyut/SHA256/ACL ve kopya UTC kontrolü yap. Env/TLS/credential taşıma, manuel
4756810b5b43 kabul klasörünün üzerine yazma. Henüz staging/kopya yapılmadı.
[Mevcut SCP/ACL ilkeleri](../BACKUP-RESTORE.md#5-vm-dışı-ikinci-kopya--windows-powershell).

`last-success.json` dump zamanıdır, Windows kopya zamanı değildir; ayrı manuel
kopya makbuzu korunmalı. Başarı yaşları24h'den küçük olsa bile VM kapalıysa veya
Windows kopyası eskiyse **24 saat RPO garantisi yok**. VM ve Windows kopyası aynı
fiziksel bilgisayarda: host/disk kaybına karşı bağımsız off-site yedek değildir.

## Kurulum komutları ve ayrı timer etkinleştirme adımı

Bu bölüm yeniden kurulum için referanstır; mevcut kurulumun üzerine topluca
uygulanmaz. 21 Ekim'de üç public dosya ayrı staging yolundan kuruldu; sonuçları
aşağıdaki runtime kaydındadır. Timer etkinleştirme komutu çalıştırılmadı.
Her grup ayrı, kullanıcı sonucu görülerek uygulanır. **Windows PowerShell:**
güncel IP/SSH ve stack envanterinden sonra yalnız bu klasördeki üç public script/
unit dosyasını ayrı staging dizinine SCP ile gönder; iki tarafta SHA256 eşleştir.
Unit/script metinlerinin LF/BOM'suz olduğunu doğrula. Kaynak repo/env/TLS/release
dosyalarını topluca güncelleme. Aşağıdaki örnekler **Ubuntu SSH** içindir;
kurulum örnekleri repository kökünü varsayar. Ayrı staging kullanılıyorsa sadece
doğrulanmış üç public dosyanın kaynak yolları buna göre seçilir:

```bash
python3 --version
python3 -c 'from zoneinfo import ZoneInfo; print(ZoneInfo("Europe/Istanbul"))'
systemd-analyze calendar '*-*-* 02:00:00 Europe/Istanbul'
```

Unit verify, ExecStart dosyası kurulunca aşağıdaki grupta yapılır; hata varsa
servisi başlatma. Hedef script/unit/state yolları önceden
varsa ezmeden önce incele. Dosyalar onaylanınca:

```bash
sudo install -d -o root -g root -m755 /usr/local/lib/fullstackops-deploy-lab
sudo install -o root -g root -m644 infrastructure/deployment/backup/daily-backup.py /usr/local/lib/fullstackops-deploy-lab/daily-backup.py
sudo install -o root -g root -m644 infrastructure/deployment/backup/fullstackops-pg-backup.service /etc/systemd/system/fullstackops-pg-backup.service
sudo install -o root -g root -m644 infrastructure/deployment/backup/fullstackops-pg-backup.timer /etc/systemd/system/fullstackops-pg-backup.timer
sudo systemctl daemon-reload
sudo systemd-analyze verify /etc/systemd/system/fullstackops-pg-backup.service /etc/systemd/system/fullstackops-pg-backup.timer
```

Timer etkinleştirmeden önce ayrıca istenen kontrollü ilk gerçek çalışma:

```bash
sudo systemctl start fullstackops-pg-backup.service
sudo systemctl show fullstackops-pg-backup.service -p Result -p ExecMainStatus -p ExecMainStartTimestamp -p ExecMainExitTimestamp
sudo python3 /usr/local/lib/fullstackops-deploy-lab/daily-backup.py --status
sudo journalctl -u fullstackops-pg-backup.service --since today --no-pager
```

Status Docker kullanmaz, dosya yazmaz; son başarı UTC/yaş ve son-attempt exit
gösterir. Exit0: son başarı24h'den genç ve son deneme başarılı; exit2: eski/eksik/
bozuk veya son deneme başarısız. Ana iş exit0: tamamlandı/aynı gün doğrulandı,
exit1: hata, exit75: kilit meşgul. Durum dosyasında güvenli `command_exit` ve
aşama da vardır; arşiv içeriğini, env veya tam Docker inspect'i loglama.

İlk gerçek dump/hash/izin/ikinci kopya ve ayrı restore kontrolleri geçmeden
runtime PASS verilmez. Timer ancak **sonraki ayrı etkinleştirme adımında**:

```bash
sudo systemctl enable --now fullstackops-pg-backup.timer
systemctl list-timers fullstackops-pg-backup.timer --all
```

Linux iki süreç flock fixture'ı 21 Ekim'de geçti; iki gerçek backup işinin aynı
anda çalışması ayrıca denenmedi. Gerçek takvim tetiki ve missed-run catch-up
henüz gözlenmedi. Otomatik retry yok: hata incelenip gerekirse aynı servis elle başlatılır.
Geri alma: `sudo systemctl disable --now fullstackops-pg-backup.timer` yalnız
gelecek tetikleri durdurur; zaten çalışan oneshot'ı durdurmaz. Mevcut işin
bitmesini bekle, dump ortasında servisi öldürme. Script/state/yedek dizinini silme;
Compose/volume/HTTPS değiştirilmez. Unit disable, yedek dosyalarını silmez.

## Yerel hazırlık kabulü — 21 Ekim 2026

`py -3 -B tests/Deployment.DailyBackup.Test.py`: **14/14 PASS**, önce eksik script
nedeniyle FAIL görüldü. Yeni aynı-gün retention ve server/tool sürüm kapısı
regresyonları da düzeltmeden önce FAIL, sonra PASS. Başarı, aynı gün skip, dump/
copy/archive/cleanup hata/timeout/warning/checksum, son sağlam backup koruması,
10 günlük fixture'dan son7 gün, yabancı/manuel/partial koruması, bozuk/ek dosyalı
setlerde silmeyi durdurma, kesilen pointer onarımı, kaynak kimlik/sürüm kapısı,
iki gerçek süreç kilidi ve stale/failure status kontrol edildi. Canary ham çıktıya
ve durum dosyasına sızmadı. İlk sandbox Temp erişim engeli yalnız test çalıştırma
izniyle aşıldı; bu Docker/VM hatası değildir. Sahipli fixture'lar temizlendi.

Windows testleri Linux permission/flock veya systemd yorumlayıcısını çalıştırmaz.
Mevcut deployment7/7 ve restore configuration4/4 testleri, secret fixture23/23,
repository secret scanner ve git diff --check PASS. Beş Markdown dosyasında164
yerel dosya/anchor bağlantısı, Python AST ve LF/BOM, iki unit'in statik parse'ı,
üç embedded shell komutu/dört rehber bloğu için bash -n PASS. Bu kontroller
Compose config parse ve sahte fixture'larla sınırlı; gerçek komut çalıştırma yok.
Bu hazırlık aşamasında unit dosyaları yerelde statik incelendi; VM kurulumu ve
gerçek çalışma henüz yoktu. Sonraki rehberli kurulumun gerçek sonuçları aşağıdadır;
hazırlık fixture sonuçları Linux/systemd runtime kanıtı olarak kullanılmaz.

## Rehberli VM kurulumu ve iki manuel çalışma — 21 Ekim 2026

Bu kayıt, temiz `main/5ab86228b7317dbffe6a7e904b2ba825245044a0` sonrasında
kullanıcının Windows PowerShell ve Ubuntu SSH terminalinde çalıştırdığı komutlar
ve paylaştığı çıktılara dayanır. Agent VM'ye bağlanmadı veya özel yedek/env
dosyalarını okumadı. Bu SHA backup script/unit kaynağıdır; çalışan uygulama
hâlâ [release.json](../release.json) içindeki A revision'ı
`1b52633776279b1661a7cac53392d385cbf10444` ve aynı API/frontend digest çiftidir.

### Aktarım ve kurulum

VM `fullstackopslabvm`, eth0 `172.30.249.139/20`, yerel Docker socket doğrulandı.
Altı kaynak container healthy; üç deployment volume ve PostgreSQL mount'u aynı.
Windows'tan yalnız şu üç public dosya
`/home/labadmin/fullstackops-daily-backup-stage-5ab86228/` dizinine aktarıldı;
iki tarafta SHA256 eşleşti. Mevcut repo/env/TLS/release topluca değiştirilmedi.

| Dosya | Aktarım SHA256 |
| --- | --- |
| daily-backup.py | 37885a8f05e174185309ad48a927fadb744773fccb354e074d1b4f3f31761520 |
| fullstackops-pg-backup.service | a7598cb644dfb634c05e41fc8918c90547f84e19512e36f5c43666f324e5bbca |
| fullstackops-pg-backup.timer | 25f2e41ae5023b63a88a823cb29c21652e9df33b9a15718e91746d28a98c0c7b |

Hedefler başlangıçta yoktu; script ve unit'ler `sudo install` ile kuruldu.
Kaynak public staging dizini labadmin/700; içindeki public dosyalar664 idi.
Kurulu `/usr/local/lib/fullstackops-deploy-lab` root:root/755, script root:root/644;
`/etc/systemd/system/` altındaki iki unit root:root/644. Ayrı otomasyon kökü
`/var/lib/fullstackops-deploy-lab-backup` root:root/700 ve ilk çalışma öncesi boştu.
Service `User=root`, `UMask=0077`, `StateDirectoryMode=0700`; Docker grubu değişmedi.
Kurulu script hash'i, LF/BOM'suz metin ve Python sözdizimi doğrulandı.

| Kontrol | Gerçek sonuç |
| --- | --- |
| Python/Docker | Python3.12.3; fcntl ve hashlib.file_digest mevcut. Docker Client/Server29.9.0; docker.service active/running |
| Linux kilit fixture'ı | Script'in backup_lock kilidi tutulurken bağımsız süreç exit75; bırakıldıktan sonra exit0. Yalnız geçici fixture dosyaları temizlendi; iki gerçek dump işi veya hata enjeksiyonu yapılmadı |
| Unit doğrulama | systemd-analyze verify PASS; daemon-reload sonrası unit'ler loaded |
| Takvim yorumu | systemd-analyze calendar: *-*-* 02:00:00 Europe/Istanbul; sonraki zaman 2026-10-21 23:00UTC = 22 Ekim02:00 İstanbul. Bu bir timer tetiklenme ölçümü değildir |
| Timer | Kurulumdan iki manuel çalışmanın sonuna kadar inactive/dead ve disabled; enable/start yapılmadı |

### İlk gerçek günlük set ve aynı gün tekrar

Her iki çalışmada yalnız **Ubuntu SSH** terminalinde
`sudo systemctl start fullstackops-pg-backup.service` çalıştırıldı. Timer kapalıydı.
`systemctl show`, script `--status`, yalnız güvenli `backup result=` journal
satırları ve bağımsız dosya/arşiv kontrolleri kullanıldı.

| Kontrol | İlk çalışma | Aynı gün ikinci çalışma |
| --- | --- | --- |
| Komut başlangıcı/bitişi UTC | 09:55:36 / 09:55:36 | 10:01:14 / 10:01:14 |
| Service | start exit0; Result=success; ExecMainStatus=0; sonunda inactive/dead | Aynı sonuç |
| Güvenli journal | backup result=completed exit=0 removed_sets=0 | backup result=already-complete exit=0 removed_sets=0 |
| Günlük set | 2026-10-21/database.pgdump ve manifest.json | Tek set; dosya boyut/SHA256/mtime değişmedi, partial veya ek set yok |
| Son başarı | 2026-10-21T09:55:36.710981+00:00 | last-success içeriği/hash ve asıl başarı zamanı aynı; başarı yaşı tazelenmedi |

Komut makbuzundaki `ELAPSED_SECONDS=0` tam saniye çözünürlüğündedir; sıfır
çalışma süresi, benchmark veya kesinti süresi kanıtı değildir. Systemctl'deki
ExecMainStartTimestamp/ExecMainExitTimestamp alanları boş döndü; yukarıdaki UTC
zamanlar komut makbuzu ve başarı metadata'sına dayanır. Başarılı oneshot sonrası
inactive/dead beklenen durumdur; servis sürekli çalışmaz.

Yeni günlük dump **3477 byte**, SHA256
`43e0f6545c2a0f7bbf3fbe205910b8df603e261db3e9203cadfcb09639e8adeb`.
Boyut/hash, günlük manifest ve last-success ile eşleşti. VM'deki gerçek dump
binary stdin ile aynı doğrulanmış PostgreSQL container'ında `pg_restore --list`
komutuna verildi: exit0, tasks/history TABLE DATA ve sequence SET kayıtları mevcut.
Kaynak PostgreSQL18.6 image/volume kimliği korundu. Otomasyon root/gün klasörleri
root:root/700; dump/manifest/last-success/last-attempt ve lock/owner dosyaları600.
İkinci doğrulama `10:02:22.146167UTC` tarihinde dump/manifest mtime dahil
eşleşmeyi teyit etti; last-success dosyasının fiziksel mtime'ı için aynı kalma
iddiası yoktur. İki çalışmada da silinen set sayısı0; gerçek eski yedek silinmedi.

### Kaynak veri ve mevcut manuel kopyaların korunması

Başlangıç `09:44:58.476113UTC`, kapanış `10:04:31.155526UTC` READ ONLY sorguları:
Task0, IDs[], satır SHA256
`e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855`;
tek `20260928113912_InitialCreate`/EF10.0.12 history ve sequence8/is_called=true
birebir aynı. Task yazma/silme, migration veya sequence sıfırlama yapılmadı.

Altı kaynak container'ın tam kimlik/image/port/mount/restart kayıtları başlangıçla
aynı ve hepsi healthy. Kısa ID'ler: api8b3d9f24f627, frontend15a93fef4000,
postgresb67a87f2d83f, redisd98d34cc73c5, prometheus84eaf1ceebb5,
grafanaed9398e62129. PostgreSQL volume'u fullstackops-deploy-lab-postgres ve
mount hedefi /var/lib/postgresql aynı. Bu anlık ölçümler sürekli erişim garantisi
değildir. Stack, HTTPS, tüneller ve development kaynaklarında değişiklik yapılmadı.

Mevcut manuel `backups-private/4756810b5b43` seti yeni günlük arşivden ayrıdır:
dump **3578 byte**, SHA256
`f4eeadd74cacdf90ec68024117e9d015d8008531865a3b4ad8e5556ef0fcb687`;
manifest SHA256 `4b29c61a0ea8022f56671f7103cdc92e106c99421820ebfee8baa61c924f38db`.
VM'de `10:06:17.374026UTC`:44 manuel dosyanın ad/boyut/izin/sahip/mtime bilgileri
aynı; orijinal manifest+11 dosyanın byte hash'leri korundu. Klasörler700,
dosyalar ve korunan restore env600; env içeriği okunmadı.

Windows'ta `10:08:32.8788788UTC`: aynı manifest+11 dosya VM ile byte-size/SHA256
eşleşti. İki klasörün ACL kalıtımı kapalı ve sahibi mevcut kullanıcı; dosyalarda
sahip ve Allow erişimleri yalnız mevcut hesap. Dosya/ACL değiştirilmedi.
Bu kontrol **19 Ekim manuel ikinci kopyasının korunmasıdır**, yeni günlük
3477 byte arşiv Windows'a kopyalanmış sayılmaz; kopya yaşı yenilenmez.

Özel makbuzlar VM'de Git dışındaki
`~/.local/share/fullstackops-deploy-lab/daily-acceptance-5ab86228/` dizininde700,
dosyalar labadmin/600 olarak korundu. Gerçek dump/manifest/snapshot/env/credential
repository'ye alınmadı. Manuel yedekler, staging, kurulu unit/script ve yeni günlük
set korundu; yalnız geçici Linux kilit fixture'ı temizlendi.

### Açık kabul maddeleri

- **PASS:** kurulum/izin/Docker erişimi, Linux kilit fixture'ı, unit/takvim parser'ı,
  iki manuel service sonucu, gerçek dump/checksum/arşiv listesi, aynı gün koruma,
  kaynak veri ve eski VM/Windows manuel yedeklerin korunması.
- **NOT VERIFIED:** gerçek timer tetiki ve Persistent catch-up; Linux'ta iki gerçek
  backup işi/hata enjeksiyonu; gerçek çok günlük retention silmesi. Önceki14 Windows
  fixture testi bu runtime kontrollerinin yerine geçmez.
- **NOT VERIFIED:** yeni günlük arşivin manuel Windows ikinci kopyası ve bu arşivden
  izole restore. Yeni arşiv boş kaynak verisine aittir; önceki ID8 içeren manuel
  restore kabulü bu günlük arşivin kanıtı değildir. --list/hash eşleşmesi restore değildir.
- Timer disabled/inactive kalır. Windows kopyası manuel; VM kapalıyken veya kopya
  eskiyken24h RPO garantisi yok. İki kopya aynı fiziksel host'ta, off-site değildir.
  Deployment final kabulü ve manuel öğrenme değerlendirmesi açık. Önceki
  exit124/RuntimeError nedenleri çözülmüş sayılmaz. Commit/push yapılmadı.

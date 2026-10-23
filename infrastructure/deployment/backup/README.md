# Günlük PostgreSQL yedekleme — kurulum ve kabul kayıtları

**23 Ekim 2026: gecikmiş başarılı çalışma ve mevcut arşiv kontrolü PASS; zamanında
02:00 çalışması doğrulanmadı.** [Gerçek günlük kontrol sonuçları](#gecikmiş-günlük-çalışma-ve-arşiv-kontrolü--23-ekim-2026).
Kullanıcı, Windows bilgisayarının hedef saatte kapalı veya uykuda olduğunu bildirdi.
Başarılı iş 09:46:29 İstanbul'da görüldü; kesin reboot/Persistent catch-up veya
uykudan dönüş mekanizması doğrulanmadı. Timer enabled/active/waiting kaldı.

**22 Ekim 2026, doğal takvim ön kontrolü:** [SSH/saat ve timer bekleme durumu doğrulandı](#doğal-günlük-tetik-için-ön-kontrol--22-ekim-2026).
Hedef 23 Ekim 02:00 İstanbul henüz gelmedi; gerçek günlük tetik kabulü bekliyor.
Bu ön kontrol yeni backup veya catch-up çalışması kanıtı değildir.

**22 Ekim 2026, sonraki adım: günlük timer enabled/active; kontrollü kısa timer
tetiklenmesi PASS.** [Etkinleştirme ve kaynak koruma kaydı](#günlük-timer-etkinleştirme-ve-kontrollü-tetik--22-ekim-2026).
09:38:49UTC timer üzerinden yeni 22 Ekim seti tamamlandı; geçici ayar kaldırıldı,
günlük02:00 Europe/Istanbul takvimi geri geldi. Gerçek02:00 olayı, reboot/catch-up
ve çok günlük retention henüz doğrulanmadı. Bu yeni arşivin Windows kopyası ve
restore'u yapılmadı; aşağıdaki21 Ekim arşivi kabulü ayrı kalır.

**22 Ekim 2026: mevcut günlük arşivin manuel Windows kopyası, izole restore ve
sahiplik kontrollü temizlik PASS.** [Gerçek sonuçlar](#günlük-arşivin-windows-kopyası-izole-restore-ve-temizlik--22-ekim-2026)
21 Ekim setine aittir; yeni dump alınmadı. Günlük arşiv boş `tasks` içerir;
19 Ekim dolu manuel restore kanıtından ayrıdır. Timer **disabled/inactive**,
gerçek takvim/catch-up/çok günlük retention ve deployment final kabulü açık.

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
restore kanıtı değildir. 21 Ekim arşivinin gerçek izole restore kabulü
[22 Ekim kaydında](#günlük-arşivin-windows-kopyası-izole-restore-ve-temizlik--22-ekim-2026) ayrıca doğrulandı;
bu sonuç gelecekteki her arşivin restore edildiği anlamına gelmez.
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

Yeni bir set için rehberli kopya yöntemi: seçili tamamlanmış günlük seti root manifest/hash ile
doğrula; yalnız dump+manifest'i labadmin'e ait Git dışı yeni700 staging dizinine
`sudo install -o labadmin -g labadmin -m600` ile kopyala. Root backup dizininin
izinlerini açma. SCP ile Windows'ta mevcut kullanıcıya özel ACL'li ayrı
`LOCALAPPDATA/FullStackOpsLab/backups-private/daily/YYYY-MM-DD/` hedefine aktar;
boyut/SHA256/ACL ve kopya UTC kontrolü yap. Env/TLS/credential taşıma, manuel
4756810b5b43 kabul klasörünün üzerine yazma. Bu akış 21 Ekim seti için 22 Ekim'de
uygulandı; mevcut staging/kopyanın üzerine tekrar uygulanmaz. Kopya ve restore
makbuzları ayrıdır; dump başarı zamanı Windows kopyasıyla yenilenmez.
[Mevcut SCP/ACL ilkeleri](../BACKUP-RESTORE.md#5-vm-dışı-ikinci-kopya--windows-powershell).

`last-success.json` dump zamanıdır, Windows kopya zamanı değildir; ayrı manuel
kopya makbuzu korunmalı. Başarı yaşları24h'den küçük olsa bile VM kapalıysa veya
Windows kopyası eskiyse **24 saat RPO garantisi yok**. VM ve Windows kopyası aynı
fiziksel bilgisayarda: host/disk kaybına karşı bağımsız off-site yedek değildir.

## Kurulum komutları ve ayrı timer etkinleştirme adımı

Bu bölüm yeniden kurulum için referanstır; mevcut kurulumun üzerine topluca
uygulanmaz. 21 Ekim'de üç public dosya ayrı staging yolundan kuruldu; sonuçları
aşağıdaki runtime kaydındadır. Timer21 Ekim'de kapalıydı;22 Ekim'de ayrı kullanıcı
talebiyle etkinleştirildi ve kontrollü kısa tetik aşağıda kaydedildi.
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
anda çalışması ayrıca denenmedi.22 Ekim kısa timer tetiki geçti; gerçek02:00
takvim olayı ve missed-run catch-up henüz gözlenmedi. Otomatik retry yok:
hata incelenip gerekirse aynı servis elle başlatılır.
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

## Günlük arşivin Windows kopyası, izole restore ve temizlik — 22 Ekim 2026

Temiz `main/e0dd23cbb6bd360e49a7d0f306bf0bffaef9755a` üzerinden kullanıcı,
Windows PowerShell/Ubuntu SSH komutlarını küçük gruplarla çalıştırdı ve sonuçları
paylaştı. Agent VM'ye bağlanmadı veya özel dosyaları okumadı. Backup script/unit
kaynağı hâlâ 5ab86228; uygulama [aktif A](../release.json) revision'ı
`1b52633776279b1661a7cac53392d385cbf10444` ve seçilmiş digest çiftinde kaldı.
21 Ekim kabulü tekrarlanmadı; backup service/timer çalıştırılmadı, yeni dump yok.

### Kullanılan arşiv ve tarihsel referans

| Madde | Doğrulanan değer |
| --- | --- |
| Asıl set | /var/lib/fullstackops-deploy-lab-backup/2026-10-21; root sahibi, klasör700/dosyalar600 |
| Dump | 3477 byte; SHA25643e0f6545c2a0f7bbf3fbe205910b8df603e261db3e9203cadfcb09639e8adeb |
| Manifest | 616 byte; SHA25678f6e8fa1070709ace8b467dd3456eff583963e4f0aa8fb3bc036ad081932f5f |
| Asıl tamamlanma | 2026-10-21T09:55:36.710981+00:00; last-success ve manifest aynı, zaman değiştirilmedi |
| Dump öncesi/sonrası | 21 Ekim09:44:58.476113UTC ve10:04:31.155526UTC; Task0/IDs[]/boş satır hash/history/sequence aynı |
| Tarihsel SQL | source.snapshot.sql901 byte; SHA256551a44bfae8b939e08a6fd104712278b524a4e059ef3e5f153529b3b49f63495; iki snapshot aynı SQL hash'ine bağlı |

Önceki `daily-acceptance-5ab86228` kayıtlarının izin/hash/yapısı ve
first-run/second-run makbuzlarının mevcut manifest ile eşitliği doğrulandı.
Dump tamamlanma zamanı iki SQL ölçümü arasındadır; bunlar pg_dump ile ortak bir
transaction/snapshot kullanmaz. Güncel kaynak verisi otomatik restore referansı
sayılmadı. 22 Ekim07:03:15.868537UTC READ ONLY baseline da aynı boş Task durumu,
tek `20260928113912_InitialCreate`/EF10.0.12 history ve sequence8/true döndürdü.
Yeni oturum baseline'ı yalnız kaynak koruması için ayrıca saklandı.

### Windows ikinci kopyası

RUN_ID `4fd14392436e`; özel VM çalışma dizini
`~/.local/share/fullstackops-deploy-lab/daily-restore-4fd14392436e/`700,
kanıt/env dosyaları600. Asıl root yedek kökünün izinleri açılmadan yalnız dump ve
manifest labadmin/600 olarak yeni `windows-export/`700 dizinine kopyalandı.
Kaynak ve staging byte hash'leri aynı; development/env/TLS/CA aktarılmadı.

Windows hedefi Git/OneDrive dışında
`%LOCALAPPDATA%/FullStackOpsLab/backups-private/daily/2026-10-21/` olarak hazırlandı;
mevcut manuel `4756810b5b43` klasörünün üzerine yazılmadı. SCP iki dosya için
exit0; boyut/hash eşleşti. Root/daily/gün klasörlerinin ACL kalıtımı kapalı,
sahip mevcut hesap; dosyalarda yalnız mevcut hesaba Allow erişimi doğrulandı.
İlk kopya kabulü **2026-10-22T07:08:30.7989435+00:00**; özel
`windows-copy-verified.json` makbuzu saklandı. Bu makbuzdaki restore_status,
kopyalama anında NOT VERIFIED idi ve tarihsel kayıt olarak değiştirilmedi;
sonraki gerçek restore makbuzları VM'de ayrıdır. SCP manuel kaldı.

### Yeni hedef ve gerçek restore

Bağımsız [restore Compose](../compose.restore.yaml) hash'i
3c71d13e1a4c652f4f7ac045d4068e8a84396cc832491ae45f9b4c61c40b9680 eşleşti.
Yeni rastgele restore credential600 dosyaya yazıldı; değerleri gösterilmedi.
`env -i`, `COMPOSE_DISABLE_ENV_FILE=1`, açık project/env-file/tek Compose dosyasıyla
config-q ve bellekte JSON model kontrolü geçti. Yalnız restore-postgres;
build/pull/host portu/source bind/external volume yok. Adlar ve project etiketleri
başlatma öncesinde boştu; deployment volume'u modelde bulunmadı.

| Kaynak | Doğrulanan ad/kimlik |
| --- | --- |
| Project | fullstackops-restore-4fd14392436e |
| Container | fullstackops-restore-4fd14392436e-postgres; ID977552b6406da22b151f41e1c731e0c7347da9d1ad090f633a6cd17c9a34f9d4 |
| Yeni volume | fullstackops-restore-4fd14392436e-postgres → /var/lib/postgresql; local, restore-data etiketi; kaynak deployment volume'undan farklı |
| Internal ağ | fullstackops-restore-4fd14392436e-net; ID6eb48535222c8c7f77cc5b2ecbeff176d8d1f525793d229fb475158d991e2218; başlangıçta yalnız hedef container üye |
| Yerel image | sha256:77f585114c32fbca283dc835b0596f4e52b51b4c6662d7810b2f4084f60a1873; kaynağın mevcut PostgreSQL18.6 image'ı, linux/amd64 |

`up -d --no-build --no-deps --pull never --wait --wait-timeout 90 restore-postgres`
120s dış sınırla **exit0/no timeout/5.841s** döndü. Gerçek target image/ref,
project/service/lab/run etiketleri, tek doğru volume, internal ağ ve host portu
yokluğu tekrar doğrulandı. READ ONLY sorgu beklenen restore role/database,
server18.6, tasks/history yokluğu ve sıfır public tablo gösterdi. Bu socket sorgusu
yeni TCP parola kabulü değildir. Container kimliği ve boşluk kapısı restore'dan
hemen önce yeniden kontrol edildi.

Arşiv VM `windows-export/database.pgdump` kopyasından binary stdin ile yalnız
hedefe verildi; Windows kopyasının byte eşitliği ayrıca kanıtlandı, Windows'tan
geri aktarım yapılmadı. `pg_restore --exit-on-error --single-transaction
--no-owner --no-privileges --no-password --host=/var/run/postgresql` mevcut hedef
role/database'i kullandı; --clean/--create veya kaynak database'e reconnect yok.
**PG_RESTORE_EXIT=0, OUTER_TIMEOUT=False, 0.113s, stdout0/stderr0**. Süreler komut
süreleridir; RTO, performans veya deployment kesinti süresi ölçümü değildir.

### Veri, şema, history ve sequence kabulü

| UTC (22 Ekim) | Gerçek sonuç |
| --- | --- |
| 07:20:12.859694 | READ ONLY restore snapshot exit0: Task0/IDs[]/satır SHA256e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855, history ve sequence8/true; 21 Ekim öncesi/sonrası referanslarıyla aynı |
| 07:21:40.523557 | Şema sorgusu exit0; altı Task sütunu/tip/nullable/false default, identity BY DEFAULT, iki PK ve history varchar150/32 sütunları InitialCreate beklentisine uygun; iki tablo/identity sequence restore rolünün sahipliğinde |
| 07:22:54.982539 | Yalnız restore hedefinde ID belirtilmeyen INSERT9 üretti (mevcut max0); test satırı ROLLBACK. Sonra Task0/hash/history aynı; yalnız restore sequence9/true |
| 07:24:42.127387 | Kaynak READ ONLY sorgusu exit0: Task0/history ve kaynak sequence8/true başlangıçla aynı; altı container kimlik/image/port/mount/restart kayıtları aynı ve healthy; aktif A korundu |

Şema yapısının bu sorguda serileştirilen SHA256 değeri
`20fb7d505d9bdf82013b347158a57013cbceed1d852ab91b07133a69071b96ba`;
bu tüm database'in fiziksel veya eksiksiz katalog hash'i değildir. Sequence
ilerlemesi rollback ile geri alınmaz; kaynakta INSERT/nextval/setval yapılmadı.
Bu günlük arşiv **boş tasks** içerir; altı dolu satır alanı/sentinel kabulü
iddia edilmez. [19 Ekim ID8 içeren manuel restore](../BACKUP-RESTORE.md#13-izole-restore-ve-sequence-kabulü--19-ekim-2026)
ayrı arşiv/deneydir; dolu yeni dump üretmek için kapsam genişletilmedi.

### Kontrollü temizlik ve korunan kopyalar

- **07:26:22.288932UTC:** exact target ID/image/etiket/mount, tek volume kullanıcısı,
  network ID/tek üye ve asıl dump/manifest hash kapıları geçti. Yalnız target
  container stop (20s grace) ve rm exit0; container yokluğu doğrulandı.
- **07:27:45.588770UTC:** kalan volume'un ad/driver/CreatedAt/etiketleri kayıtla
  aynı ve kullanıcısı yok; ağ aynı ID/etiketlerle internal ve boş. Ağ ID ile,
  volume yalnız açık adıyla kaldırıldı; exit0 ve üç kaynağın yokluğu geçti.
  Genel prune, source down-v, image veya dosya silme yok; üç kaynak volume mevcut.
- **07:29:33.229274UTC:** son READ ONLY source sorgusu exit0; Task0/IDs[]/boş
  hash/history ve sequence8/true başlangıçla aynı. Altı container tam kimlik/image/
  port/mount/restart kaydı aynı ve healthy. Timer inactive/disabled; stack/HTTPS/
  tünel/development/release digestlerinde değişiklik yapılmadı. Sürekli erişim ölçülmedi.
- **07:31:04.665193UTC:** VM asıl günlük set ve staging iki dosyasının boyut/hash/
  600 izinleri aynı, asıl manifest/last-success zamanı korundu. Eski manuel
  manifest+11 dosya boyut/hash/600 eşleşti; klasörler700, yeni kabul dosyaları ve
  korunan restore env600. Env/credential içeriği bu koruma kontrolünde okunmadı.
- **07:32:20.1101891UTC:** Windows günlük iki dosya ve eski manuel manifest+11
  dosya boyut/hash/ACL kontrolleri geçti. Klasör kalıtımı kapalı; sahip/Allow
  yalnız mevcut hesap. Asıl kopya makbuzu ve07:08:30.7989435UTC kopya zamanı
  değişmedi; yeni cleanup-windows-verified makbuzu ayrıca saklandı.

Asıl günlük set, VM staging, yeni bağımsız restore env, snapshot/karşılaştırma ve
restore/cleanup kanıtları ile Windows günlük/manuel kopyalar Git dışında korundu.
Kaynak Task oluşturma/silme, yeni dump, migration, image build/pull/değişimi,
timer/service tetikleme, retention silmesi veya development işlemi yapılmadı.

**PASS:** bu belirli günlük arşivin Windows kopyası, gerçek restore/veri/şema/
history/sequence ve sahiplik kontrollü kaynak temizliği. **NOT VERIFIED:** gerçek
timer tetiki/catch-up, çok günlük retention, otomatik Windows kopyası ve günlük
24h RPO garantisi. Kopya yaşı ile backup yaşı ayrıdır; Windows'a kopyalama
21 Ekim dump zamanını yenilemez. Aynı fiziksel host off-site koruma değildir.
Deployment final kabulü ve manuel öğrenme açık; önceki exit124/RuntimeError
nedenleri çözülmüş sayılmaz. Yalnız belgeler güncellendi; commit/push yapılmadı.

Dokümantasyon kapanışında repository secret kontrolü, beş Markdown belgede182
yerel dosya/anchor bağlantısı ve git diff --check PASS. Kod, Compose, script,
unit, test ve release dosyaları değişmedi; ek VM deneyi/build/fixture çalıştırılmadı.

## Günlük timer etkinleştirme ve kontrollü tetik — 22 Ekim 2026

Temiz main/ef7b9353c485de177046bfa6cc75c3d42f935727 sonrasında kullanıcı
Windows PowerShell ve Ubuntu SSH komutlarını küçük gruplarla uyguladı. Agent
VM'ye bağlanmadı; kanıtlar paylaşılan gerçek komut sonuçlarıdır. Kurulu script,
service ve timer SHA256 değerleri21 Ekim kurulum tablosuyla eşleşti. Başlangıçta
timer disabled/inactive, DropInPaths boş, service inactive/dead/Result=success/
ExecMainStatus0; altı kaynak container aynı kimliklerle healthy ve yalnız21 Ekim
günlük seti vardı. Private timer-acceptance-F6gAx4mP klasöründe başlangıç kaydı alındı.

### Takvim, gerçek tetik ve geçici ayarın kaldırılması

- systemd-analyze verify exit0. Sistem timezone Etc/UTC, LocalRTC=no, NTP=yes,
  NTPSynchronized=yes;09:28:34UTC =12:28:34 İstanbul. Saat/timezone değiştirilmedi.
- Takvim parser'ı `*-*-* 02:00:00 Europe/Istanbul` için sonraki iki zamanı
  22 ve23 Ekim23:00UTC olarak yorumladı. Bu, gerçek02:00 tetik kanıtı değildir.
- 09:35:06UTC `sudo systemctl enable --now fullstackops-pg-backup.timer`:
  enabled/active/waiting, Persistent=yes; sonraki günlük zaman22 Ekim23:00UTC
  (23 Ekim02:00 İstanbul). İlk çıktıda LastTriggerUSec boştu.
- Sonraki çıktıda LastTriggerUSec09:35:07 göründü;09:38:34 kontrolünde service
  için eşleşen backup result journal satırı yoktu ve last-success hâlâ21 Ekim'di.
  Bu tek alan başarılı backup veya Persistent catch-up kanıtı sayılmadı; bu erken
  değerin nedeni doğrulanmadı.
- Uzun bekleme yerine yalnız /run/systemd/system/fullstackops-pg-backup.timer.d/
  90-lab-acceptance.conf oluşturuldu: OnActiveSec=60s ve AccuracySec=1s.
  OnCalendar silinmedi; günlük takvim ve Persistent ayarı korundu. Mevcut override
  bulunmadığı ve service inactive olduğu kontrol edildi; dosya hash'i saklandı.
  Unit verify/daemon-reload sonrası yalnız timer restart edildi, service elle
  başlatılmadı.09:37:48UTC kısa test başlangıcı; list-timers09:38:48UTC hedefini gösterdi.
- 09:38:34UTC kontrolü hedef zamandan önceydi; sonuç olmadığı için PASS verilmedi.
  Sonraki09:40:54UTC kontrolünde LastTriggerUSec09:38:49, service Result=success/
  ExecMainStatus0/inactive/dead ve aynı saniyede güvenli journal satırı görüldü:
  `backup result=completed exit=0 removed_sets=0`. Bu, kontrollü timer kaynaklı
  çalışmadır; manuel service start sonucu veya gerçek02:00 olayı değildir.
- Geçici dosya hash kapısı geçti, yalnız o dosya kaldırıldı. daemon-reload/verify
  ve yalnız timer restart sonrasında DropInPaths boş; günlük02:00 Europe/Istanbul,
  AccuracyUSec=1min, Persistent=yes, enabled/active/waiting ve sonraki zaman
  22 Ekim23:00UTC geri geldi. Son kontrol geçici dosyanın yokluğunu doğruladı;
  yalnız21 ve22 Ekim setleri mevcut. Kurulu kalıcı timer dosyası aynı kaldı;
  kısa test ayarını içeren dosya kaldırıldı ve DropInPaths boş döndü.

### Yeni arşiv ve mevcut kaynakların korunması

| Kontrol | Paylaşılan gerçek sonuç |
| --- | --- |
| Yeni set | 2026-10-22;3477 byte; SHA256 ae714637463c8f4821d4b4ba0338cf9ae7fdd38bc52d2002ef235d85fbb6bb56 |
| Tamamlanma | 2026-10-22T09:38:49.770524+00:00; manifest ve last-success eşit; last-attempt completed/exit0/removed_sets0 |
| Dosya kabulü | Root/set700, manifest/dump/state dosyaları600; owner/size/hash kapıları geçti; partial set yok |
| Arşiv okunabilirliği | Aynı kaynak PostgreSQL container'ında binary stdin ile pg_restore --list exit0/stderr boş; tasks/history TABLE DATA ve sequence SET mevcut |
| Kaynak kimliği | Manifest kaynak container/image/volume ile eşleşti; altı container başlangıç ID'leriyle running/healthy/RestartCount0; seçilmiş A API/frontend ImageID'leri aynı |
| Kaynak veri | Aynı hash'i doğrulanmış READ ONLY SQL; psql exit0. Task0/IDs[]/boş satır SHA256 e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855, history ve sequence8/true başlangıçla aynı |
| Eski günlük set | 21 Ekim dump ve manifest başlangıç SHA256 listesiyle OK; yeni22 Ekim seti bunların üzerine yazmadı |
| Eski manuel VM seti | 4756810b5b43 dump/manifest hash'leri aynı; manual ve timer kanıt klasörleri mevcut kullanıcı/700, toplam56 dosya mevcut kullanıcı/600; env içeriği okunmadı |
| Windows eski kopyalar | Manuel dump3578/manifest2511 ve21 Ekim günlük dump3477/manifest616 boyut/hash/ACL PASS; dört klasörde kalıtım kapalı, sahip/Allow yalnız mevcut hesap; dosya/ACL değiştirilmedi |

Yeni arşiv --list/hash kontrolü gerçek restore değildir.22 Ekim arşivinin Windows
ikinci kopyası ve restore'u **NOT VERIFIED**.21 Ekim boş günlük arşiv restore'u
ve19 Ekim dolu manuel arşiv restore'u kendi tarihli kanıtları olarak korunur.
Kaynak önce/sonra SQL ölçümleri pg_dump ile ortak transaction/snapshot değildir.
Bu adımda Task yazma/silme, restore, migration, stack recreate/build/pull, image/
credential/TLS/development değişimi veya backup silme yapılmadı. HTTPS/tünellere
işlem uygulanmadı. Yalnız sahipli geçici timer dosyası kaldırıldı; özel kanıt
dosyaları ve yedekler Git dışında saklanıyor.

**Açık sınırlar:** gerçek02:00 tetiklenmesi, VM reboot/missed-run catch-up, gerçek
çok günlük retention ve iki gerçek backup işiyle eşzamanlılık/hata senaryoları
doğrulanmadı. removed_sets0, retention silme kabulü değildir. Windows kopyası
manuel kalır; yeni setin kopyası otomatik oluşmaz.24h RPO veya kesintisiz çalışma
garantisi yok; VM/Windows aynı fiziksel bilgisayarda, off-site koruma değildir.
Önceki exit124/RuntimeError nedenleri ve deployment final/manuel öğrenme kabulü açık.

### Sonraki doğal takvim kontrolü ve devre dışı bırakma

Bir sonraki doğal hedef **23 Ekim 2026 02:00 İstanbul / 22 Ekim 23:00 UTC**.
AccuracySec=1min nedeniyle tam saniye garantisi verilmez. VM o sırada açık kalırsa
**23:02UTC sonrasında**, Ubuntu SSH terminalinde yalnız okuma:

```bash
systemctl show fullstackops-pg-backup.timer -p LastTriggerUSec -p NextElapseUSecRealtime -p ActiveState -p UnitFileState
sudo journalctl -u fullstackops-pg-backup.service --since '2026-10-22 23:00:00 UTC' --utc --no-pager -o short-iso --grep='backup result='
sudo python3 /usr/local/lib/fullstackops-deploy-lab/daily-backup.py --status
```

Bu gelecek kontrol henüz yapılmadı. Aynı gün set varsa already-complete yeni dump
sayılmaz; sonucu journal/manifest ile ayır. Hata/eksik kayıtta körlemesine yeniden
başlatma. Timer başarı sonunda **enabled/active** bırakıldı. İstenirse Ubuntu SSH:

```bash
sudo systemctl disable --now fullstackops-pg-backup.timer
```

Bu komut gelecekteki tetikleri durdurur; çalışan oneshot'ı durdurmaz, yedekleri silmez.
Bu kabul sırasında çalıştırılmadı. Kalıcı unit/script ve seçilmiş release digestleri
değiştirilmedi; commit/push yapılmadı.

Yerel belge kapanışı: repository secret kontrolü, beş Markdown dosyasında184
yerel dosya/başlık bağlantısı ve git diff --check PASS. Yalnız beş belge değişti;
script/unit/Compose/release/test dosyaları değişmedi, ek VM deneyi veya fixture/build
çalıştırılmadı. Bu yerel kontroller gelecekteki takvim olayının kanıtı değildir.

## Doğal günlük tetik için ön kontrol — 22 Ekim 2026

05f020242c43946556a1e1543f29db57592604e7 sonrasında temiz main üzerinde,
kullanıcının salt okunur SSH sonuçları incelendi. Hostname fullstackopslabvm,
eth0 172.30.249.139/20 ve VM saati 2026-10-22 13:25:13 UTC
(16:25:13 Europe/Istanbul) olarak paylaşıldı. Henüz 22 Ekim 23:00 UTC /
23 Ekim 02:00 İstanbul hedefi gelmedi.

Timer UnitFileState=enabled, ActiveState=active, SubState=waiting ve
DropInPaths boş. NextElapseUSecRealtime=2026-10-22 23:00:00 UTC;
LastTriggerUSec=2026-10-22 09:38:49 UTC önceki kontrollü kısa teste ait.
list-timers aynı sonraki/son zamanı gösterdi. Bu, bekleme durumu kanıtıdır;
doğal 02:00 olayı gerçekleşmiş veya başarılı sayılmadı.

Bu oturumda hedef olayın service journal'ı/sonucu, backup --status ve yeni günlük
setin checksum/arşiv kabulü henüz incelenmedi. Kullanıcıya 23 Ekim 02:02 İstanbul /
22 Ekim 23:02 UTC sonrasında rehberdeki salt okunur kontrollerle devam etmesi
söylendi; uzun süre bekleyen komut çalıştırılmadı. VM'nin hedef saatte açık olup
olmayacağı, reboot veya gecikmiş Persistent catch-up henüz bilinmiyor. Sonradan
oluşacak bir işi zamanında 02:00 çalışması saymadan gerçek UTC journal/boot ve
manifest zamanlarıyla ayırmak gerekiyor.

Manuel service start, yeni dump, timer ayarı, stack/HTTPS/image/volume işlemi veya
yedek silme yapılmadı. Agent VM'ye bağlanmadı; yalnız kullanıcı çıktıları kaydedildi.
Bu ön kontrol için iki belge değişti; commit/push yok. Önceki kısa timer kabulü
ve arşiv kanıtları kendi tarihleriyle korunuyor; yeni günlük kabul PASS değildir.

## Gecikmiş günlük çalışma ve arşiv kontrolü — 23 Ekim 2026

22 Ekim ön kontrolünün devamında, kullanıcı yalnız Ubuntu SSH terminalinde
salt okunur komutları çalıştırdı. Ön kontrolden kalan iki belge değişikliği
korundu. Agent VM'ye bağlanmadı; sonuçlar kullanıcının paylaştığı çıktılardır.

### Zamanında çalışma ile gecikmiş işi ayırma

Hedef **23 Ekim 02:00 Europe/Istanbul / 22 Ekim 23:00 UTC** idi.
İlk kontrol saati 23 Ekim 06:52:04 UTC / 09:52:04 İstanbul:

- Timer enabled/active/waiting, DropInPaths boş. LastTriggerUSec, hedef saat
  yerine **23 Ekim 06:46:29 UTC / 09:46:29 İstanbul** gösterdi. Sonraki günlük
  hedef 23 Ekim 23:00 UTC / 24 Ekim 02:00 İstanbul.
- Service journal'ı 22 Ekim 22:55 UTC'den kontrol anına kadar, yalnız güvenli
  `backup result=` satırlarıyla okundu. Paylaşılan tek sonuç 23 Ekim
  06:46:29 UTC'deki `backup result=completed exit=0 removed_sets=0` idi.
  Hedef 02:00 çevresinde başarılı backup sonucu bulunmadı.
- Kullanıcı, Windows bilgisayarının 02:00 civarında **kapalı veya uykuda**
  olduğunu bildirdi; bu gözlem kapalı ile uyku durumunu ayırmıyor ve VM'nin
  tam durma/uyanma zamanını ölçmüyor. Geç işi zamanında 02:00 kabulü saymadık.
- `uptime -s` çıktısı 2026-10-20 23:03:21 iken journal'ın mevcut boot kaydı
  (737c3586...) ilk girdiyi 12 Ekim 13:06:02 UTC, son girdiyi 23 Ekim
  06:53:18 UTC gösterdi. Bu farklı bilgilerden yeni reboot veya kesin kesinti
  süresi çıkarılmadı. Sistem Etc/UTC ve NTPSynchronized=yes.
- Gecikmiş iş, hostun yeniden kullanılabilir olması sonrası telafiyle uyumlu;
  bu yalnız yorumdur. **Reboot sonrası Persistent catch-up ile uyku/VM duraklama
  sonrası timer davranışı bu kanıtlarla ayrıştırılamadı.** Her ikisi de ayrı
  mekanizma kabulü olarak NOT VERIFIED kalır; önceki kısa test tekrarlanmadı.

### Service, status ve oluşmuş setin salt okunur kabulü

| Kontrol | Paylaşılan gerçek sonuç |
| --- | --- |
| Service | Result=success, ExecMainStatus=0, inactive/dead; tamamlanmış oneshot |
| Backup --status | Exit0; last_attempt_exit0; last_success_utc=2026-10-23T06:46:29.955908+00:00; sorgu anında yaş0.15 saat |
| İkinci kopya durumu | windows_copy=manual-not-verified-by-this-job; otomatik Windows kopyası yok |
| Mevcut set tarihleri | 2026-10-21, 2026-10-22 ve 2026-10-23; bu liste eski dosyaların byte eşitliği kanıtı değildir |
| Yeni set | BACKUP_DAY=2026-10-23; dump3477 byte; SHA25635bdd2fc25b59cc0c8b37ecec2809c3b447cb3b2818d830da980c5be387a4b44 |
| Tamamlanma | 2026-10-23T06:46:29.955908+00:00; manifest ve last-success eşit; completed/exit0/removed_sets0 |
| Dosya güvenliği/bütünlüğü | Kurulu script SHA256 önceki kurulumla eşit; root/set sahiplik700, dump/manifest/state600, boyut/checksum kapıları PASS |
| Arşiv okunabilirliği | Aynı kaynak PostgreSQL container'ında binary stdin ile pg_restore --list exit0/stderr boş; tasks/history TABLE DATA ve sequence SET mevcut |
| Kaynak eşleşmesi | Manifest source container/image/volume değerleri çalışan kaynak PostgreSQL'in doğrulanmış project/service/health/no-port/volume bilgileriyle eşleşti |

Doğrulama kodu backup script'ini import ederken bytecode yazımını kapattı;
backup/retention fonksiyonları çağrılmadı. Yalnız checked_set/inspect ve arşiv
listesi okundu. Manual service start, yeni dump komutu, restore, Task sorgusu/
yazma/silme, timer restart/override/enable/disable, saat/timezone, stack/image/
volume/TLS/development değişikliği veya yedek silme yapılmadı. Yeni23 Ekim seti
komutlarla üretilmedi; mevcut otomatik işin ürünü olarak incelendi.

**Sonuç:** gecikmiş başarılı iş, status ve bu arşivin hash/--list kabulü PASS.
**Zamanında doğal 02:00 çalışması doğrulanmadı.** Kesin reboot/catch-up/uyku
mekanizması, gerçek çok günlük retention silmesi, 22 ve23 Ekim arşivlerinin
Windows kopyaları ve gerçek restore'ları NOT VERIFIED. Üç setin bulunması ve
removed_sets0, son yedi gün retention kabulü değildir. Bu oturumda kaynak Task
verisinin/altı container'ın tam koruma karşılaştırması veya eski VM/Windows
kopyalarının byte/ACL kontrolleri tekrar edilmedi; önceki tarihli kanıtlar ayrı.
Arşiv listesi restore edilmiş veri/şema/sequence kanıtı değildir. Manuel19 Ekim
dolu ve21 Ekim boş günlük restore kabulü bu yeni arşivleri doğrulamaz.

Timer **enabled/active/waiting**, aynı günlük takvimle bırakıldı; bir sonraki
doğal hedef **24 Ekim 02:00 İstanbul / 23 Ekim 23:00 UTC**. Başka değişiklik
yapmadan, kullanıcı ayrıca devam etmek isterse **24 Ekim 02:02 İstanbul**
sonrasında Ubuntu SSH terminalinde:

```bash
date -u '+UTC: %Y-%m-%d %H:%M:%S'
systemctl show fullstackops-pg-backup.timer -p UnitFileState -p ActiveState -p SubState -p LastTriggerUSec -p NextElapseUSecRealtime -p DropInPaths
sudo journalctl -u fullstackops-pg-backup.service --since '2026-10-23 22:55:00 UTC' --utc --no-pager -o short-iso --grep='backup result='
sudo python3 /usr/local/lib/fullstackops-deploy-lab/daily-backup.py --status
```

Bu gelecek kontrol yapılmadı. Zamanında kabul için Windows host ve VM hedef
saatte çalışır durumda olmalı; SSH penceresini açık tutmak gerekmiyor. Host/VM
uykudaysa geç işi yine ayrı kaydet. 24 saat RPO, sürekli erişim, çok günlük
otomasyon veya off-site koruma garantisi yok; VM/Windows aynı fiziksel bilgisayarda.
Yedekler ve private dosyalar Git'e eklenmedi; yalnız iki belge güncellendi,
commit/push yapılmadı. Deployment final ve manuel öğrenme kabulü açık.

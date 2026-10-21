# Günlük PostgreSQL yedekleme — hazırlık

**21 Ekim 2026: dosya hazırlığı ve Windows fixture testleri PASS.** VM'ye kurulum,
gerçek otomatik dump, systemd timer/catch-up ve Linux flock/izin runtime kabulü
**NOT VERIFIED**. Önceki [manuel dump/restore ve cleanup](../BACKUP-RESTORE.md)
kanıtları geçerlidir; bu iş onları tekrarlamadı. Deployment A, HTTPS, Compose,
release digestleri ve development kaynakları değiştirilmedi.

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

## Gelecekte VM'ye kurulum — bu görevde çalıştırılmadı

Her grup ayrı, kullanıcı sonucu görülerek uygulanır. **Windows PowerShell:**
güncel IP/SSH ve stack envanterinden sonra yalnız bu klasördeki üç public script/
unit dosyasını ayrı staging dizinine SCP ile gönder; iki tarafta SHA256 eşleştir.
Unit/script metinlerinin LF/BOM'suz olduğunu doğrula. Kaynak repo/env/TLS/release
dosyalarını topluca güncelleme. Aşağıdakiler **Ubuntu SSH** içindir, gelecekte
onaylı kurulumda repository kökündeki doğrulanmış dosyalardan çalıştırılır:

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

Bir sonraki tetik, missed-run catch-up ve Linux iki süreç flock kabulü ayrıca
gözlenir. Otomatik retry yok: hata incelenip gerekirse aynı servis elle başlatılır.
Geri alma: `sudo systemctl disable --now fullstackops-pg-backup.timer` yalnız
gelecek tetikleri durdurur; zaten çalışan oneshot'ı durdurmaz. Mevcut işin
bitmesini bekle, dump ortasında servisi öldürme. Script/state/yedek dizinini silme;
Compose/volume/HTTPS değiştirilmez. Unit disable, yedek dosyalarını silmez.

## Yerel kabul — 21 Ekim 2026

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
Unit dosyaları yerelde statik incelendi; VM `systemd-analyze verify/calendar`,
gerçek timer, gerçek dump/retention silmesi, güncel Windows ikinci kopyası,
günlük arşiv restore'u ve deployment final kabulü **NOT VERIFIED**. Zamanlama
etkinleştirilmedi; önceki exit124/RuntimeError nedenleri çözülmüş sayılmaz.

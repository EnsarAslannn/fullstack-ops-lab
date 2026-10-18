# Deployment — izole PostgreSQL yedek/restore hazırlığı

**18 Ekim 2026: envanter/public aktarım ön kontrolü PASS; dump/restore runtime
NOT VERIFIED.** Güncel kullanıcı komut kanıtı [bölüm11](#11-vm-envanteri-ve-public-aktarım--18-ekim-2026)
içindedir. İlk statik hazırlıkta temiz
`main/4a11d0c6684b10e4fdf94b21127af9901be21c5f` incelendi; o aşamada VM erişimi,
yedek alma, Task oluşturma, restore, kaynak temizleme veya zamanlama etkinleştirme
yapılmadı. Son [A→B→A kabulü](UPDATE-ROLLBACK.md#9-rehberli-aba-runtime-kabulü--17-ekim-2026)
17 Ekim'e aittir; yeni envanter kontrolü o geçiş deneyini tekrarlamaz.
Aktif A [release kaydı](release.json), digestler, HTTPS ve development korunur.

[Plan adım8](../../docs/deployment-plan.md#8-günlük-yedek-ve-ayrı-restore-pratiği)
için aşağıdaki gruplar daha sonra **rehberli ve sonuç beklenerek** uygulanacak.
Dump/restore komutları henüz çalıştırılmadı; tamamını tek seferde yapıştırma.

## 1. Ne yedeklenir, nereye geri yüklenir?

| Kaynak/hedef | Seçim ve korunma |
| --- | --- |
| Kaynak | Çalışan fullstackops-deploy-lab-postgres-1; Compose project/service, image ve fullstackops-deploy-lab-postgres → /var/lib/postgresql mount'u yeniden doğrulanacak |
| Yedek | VM'de ~/.local/share/fullstackops-deploy-lab/backups-private/RUN_ID/; root/run klasörleri700, dosyalar600; Git/build context dışında |
| İkinci kopya | Windows LOCALAPPDATA/FullStackOpsLab/backups-private/RUN_ID/; mevcut kullanıcıyla sınırlı ACL, repository/OneDrive dışında |
| Restore | Bağımsız compose.restore.yaml; project fullstackops-restore-RUN_ID, container ve volume fullstackops-restore-RUN_ID-postgres, internal ağ fullstackops-restore-RUN_ID-net |
| Restore credential | Yeni, yalnız restore için üretilen parola; Git dışındaki RUN_ID/.env.restore,600; development/deployment parolası kullanılmaz |

Restore dosyası kök/deploy/HTTPS dosyalarıyla **birleştirilmez**. Yalnız bir geçici
PostgreSQL içerir: host portu, build, deployment ağı, bind veya external volume
yok. Kaynak PostgreSQL volume'u restore container'ına hiçbir zaman bağlanmaz.
Kaynak ve restore ayrı ortamdır; deployment altı servisli mimarisi değiştirilmez.

Yedek, Task verilerini ve bazı kaynak database/owner adlarını içerebilir;
secret içermediği veya şifreli olduğu varsayılmaz. Kısıtlı izin şifreleme değildir.
`.gitignore` *.pgdump/*.dump/*.backup ve backups-private/ için ek korumadır;
birincil önlem dosyaları repository dışında tutmaktır. `git add -f` kullanılmaz.

## 2. Araç/image, rol ve ownership kararı

Kaynak yapılandırma PostgreSQL18 (`postgres:18-alpine`). Mutable tag'i yeniden
pull ederek farklı sürüme geçilmez. Runtime ön kontrolünde kaynağın `.Image`
kimliği alınır; aynı yerel **sha256:ImageID** RESTORE_POSTGRES_IMAGE olur.
Son bilinen source ImageID77f585114c32... bugünün kanıtı sayılmaz: Engine'de
varlık, linux/amd64 ve PostgreSQL server/pg_dump/pg_restore major18 yeniden
doğrulanacak. PostgreSQL araçları kendi image'ından gelir; VM'ye SDK/EF/Postgres
paketi kurulmaz. Restore `pull_policy: never`, başlangıç `--no-build --pull never`.

Tek database `pg_dump --format=custom` ile alınır; cluster/global role dump'ı
ve `pg_dumpall --globals-only` kullanılmaz. Restore rolü/database'i ayrı image
initialization'ı oluşturur. Bu küçük lab'de restore_lab yönetici rolüdür; production
least-privilege tasarımı değildir. Kaynak role/parola hedefte yeniden oluşturulmaz.
`pg_restore --no-owner --no-privileges` nesneleri hedef rolün sahipliğinde kurar;
kaynak grant/owner politikasını geri getirme kabulü yoktur. Custom archive'da
pg_dump --no-owner etkisiz olduğundan ownership kararı restore sırasında verilir.
Rol parolaları bu tek-database dump'ıyla taşınmaz; uygulama verisine yazılmış
hassas metinler ise yine taşınabilir. [pg_dump18](https://www.postgresql.org/docs/18/app-pgdump.html),
[pg_restore18](https://www.postgresql.org/docs/18/app-pgrestore.html).

## 3. Ön envanter, sahipli kayıt ve snapshot

Uygulamadaki sıra: (1) salt okunur envanter, RUN_ID ve private çalışma dizinini
hazırla; (2) sentinel oluşturmadan source baseline'ı kaydet; (3) Windows HTTPS
POST/snapshot; (4) sentinel içeren source snapshot, dump ve tekrar snapshot.
Aşağıdaki paragraflar bu kapıların ayrıntılarıdır; baseline atlanmaz.

**Ubuntu SSH:** güncel IP/Engine ve altı deployment container ID/health/image'ı,
PostgreSQL project/service/volume/mount/no-host-port kontrolü. Tam inspect veya
env çıktısı yok. Kaynak varsayılanları doğru değilse dur; development'a yönelme.
Kaynak live/ready ve doğru A image'larını doğrula; stack/recreate/migration yok.

**Windows PowerShell:** mevcut HTTPS tüneli/trust kontrolünden sonra benzersiz
`Backup restore acceptance <random>` Task POST201; ID ve altı JSON alanı ilk
snapshot'a kaydedilir. Description null örneği korunur. Tekil GET200 snapshot
ile eşleşsin; ID sabit kodlanmaz, önceki ID5/6/7 yeniden kullanılmaz. POST timeout
verirse körlemesine tekrar gönderme. Sahipli kayıt hem deployment'ta hem yedekte
kalacak; restore doğrulanmadan silinmeyecek. Önceki [HTTPS yöntemini](HTTPS.md)
kullan; yalnız bu yeni kaydı oluştur, diğer kayıtları değiştirme.

**Ubuntu SSH:** rastgele12 lowercase hex RUN_ID, ayrı700 klasör ve600 kayıt
dosyaları hazırlanır. Var olan çalışma klasörü/container/network/volume varsa
üzerine yazma veya silme; dur. Geçerli örnek değişken hazırlığı (gelecek görev):

```bash
source_container=fullstackops-deploy-lab-postgres-1
run_id=$(python3 -c 'import secrets; print(secrets.token_hex(6))')
restore_project="fullstackops-restore-$run_id"
target_container="$restore_project-postgres"
backup_root="$HOME/.local/share/fullstackops-deploy-lab/backups-private"
run_dir="$backup_root/$run_id"
```

Kimlikleri ve isimleri korumalı manifest'e kaydet: UTC zaman, A kaynak SHA/digest
çifti (public release kaydından), PostgreSQL ImageID/server/araç sürümü, kaynak
project/volume, sentinel ID ve yalnız bu deneyin kaynak adları. Env/config veya
rol parolaları manifest'e kopyalanmaz. RUN_ID regex'i `^[0-9a-f]{12}$` olmalı;
isimler development/deployment isimleriyle eşleşmemeli.

Kaynağın başlangıç Task count/ID/alan hash'i ve history'si sentinel **öncesi**
kaydedilir. Sentinel sonrası, dump öncesi ve dump sonrası da aynı salt okunur
sorgu çalıştırılır. Bu pencere boyunca kullanıcı başka mutation yapmaz; ilgisiz
veri değişirse kaynak snapshot'ını sessizce yeni doğru kabul etme, deneyi durdur.
`pg_dump` kendi tutarlı snapshot'ını alır; ayrı psql ölçümüyle ortak snapshot
kullandığı iddia edilmez. Sakin pencere ve önce/sonra eşleşmesi kabulü okunur kılar.

Örnek karşılaştırma SQL'i Git dışındaki snapshot.sql dosyasına UTF-8 **BOM'suz**
kaydedilir. `psql -X -qAt -v ON_ERROR_STOP=1 -v sentinel_id=ID` ile stdin'den
verilir; JSON korumalı dosyaya yakalanır, diğer Task içerikleri paylaşılmaz.
Sentinel öncesi baseline ve son cleanup karşılaştırmasında `-v sentinel_id=`
ile boş değer verilir; böylece başka kaydın altı alanı yanlışlıkla seçilmez:

```sql
BEGIN TRANSACTION ISOLATION LEVEL REPEATABLE READ READ ONLY;
SET LOCAL TIME ZONE 'UTC';
WITH t AS (
    SELECT id, title, description, is_completed, created_at, updated_at
    FROM public.tasks
)
SELECT json_build_object(
    'count', (SELECT count(*) FROM t),
    'ids', (SELECT COALESCE(json_agg(id ORDER BY id), '[]'::json) FROM t),
    'rows_sha256', (SELECT encode(sha256(convert_to(COALESCE(
        string_agg(row_to_json(t)::text, E'\n' ORDER BY id), ''), 'UTF8')), 'hex') FROM t),
    'sentinel', (SELECT json_build_object(
        'id', id, 'title', title, 'description', description,
        'isCompleted', is_completed, 'createdAt', created_at, 'updatedAt', updated_at
    ) FROM t WHERE id = NULLIF(:'sentinel_id', '')::integer),
    'history', (SELECT COALESCE(json_agg(json_build_object(
        'migrationId', "MigrationId", 'efVersion', "ProductVersion"
    ) ORDER BY "MigrationId"), '[]'::json) FROM public."__EFMigrationsHistory")
);
COMMIT;
```

Sentinel öncesi mevcut olmayan ID için sentinel null olması normaldir. Snapshot
sonrası sentinel mutlaka var ve altı alanı doğru olmalı. SQL ve API timestamp
metin biçimleri farklı olabilir; UTC zaman değeri olarak karşılaştır, null'u
boş metne dönüştürme. Tam satır hash'i aynı SQL/timezone ile kaynak/restore
arasında karşılaştırılır; timestamp string biçim farkı API sözleşmesi hatası değildir.

## 4. Tutarlı dump, dosya bütünlüğü ve güvenli sonuç

**Ubuntu SSH — yalnız gelecekte, yukarıdaki kimlik/snapshot kapıları geçince:**
kaynak container'ın /tmp alanına bu göreve özel dosya yazılır; volume dosyaları
cp/tar/rsync ile kopyalanmaz. Binary stdout Windows PowerShell pipeline'ına girmez.

```bash
container_dump="/tmp/fullstackops-backup-$run_id.pgdump"
partial="$run_dir/database.pgdump.partial"
dump="$run_dir/database.pgdump"
timeout 180s sudo -n docker exec "$source_container" sh -c '
  umask 077
  test ! -e "$1" || exit 1
  exec pg_dump --format=custom --no-privileges --no-password \
    --lock-wait-timeout=5s --file="$1" \
    -U "$POSTGRES_USER" -d "$POSTGRES_DB"
' sh "$container_dump" >"$run_dir/dump.stdout" 2>"$run_dir/dump.stderr"
```

Bu bloktan önce `umask 077`,700 dizinler ve yokluk kontrolleri yapılır. Her grubun
exit code'u hemen yakalanır; timeout/exit!=0 iken sonraki komut yok. Socket rolü
container env'den seçilir; `--no-password` interaktif beklemeyi önler. Bu parola
doğrulama deneyi değildir; kaynak TCP auth ayrı önceki kanıttır. Hata aşama/exit
olarak raporlanır; ham stderr/exception sohbete veya public artifact'e yazılmaz.
Warning varsa özel log yerelde incelenmeden başarı verilmez. [Tutarlı mantıksal
dump ve custom format](https://www.postgresql.org/docs/18/app-pgdump.html).

Yalnız dump exit0 sonrası şu **ayrı grup** hazırlanır:

```bash
test ! -e "$partial" && test ! -e "$dump"
sudo docker cp "$source_container:$container_dump" "$partial"
sudo chown "$(id -u):$(id -g)" "$partial"
chmod 600 "$partial"
test -s "$partial"
```

Her native exit ayrıca kontrol edilir; ilk hata sonraki satırlara geçirmez.
Kaynak /tmp dosyası ile VM partial SHA256 eşleşsin. Aynı18 pg_restore ile
`--list` arşiv okuma kontrolü (stdin, stdout/stderr korumalı dosyada) yapılsın;
arşiv listesi restore kabulü değildir. Başarıdan sonra aynı dizinde son ada
atomik rename; dump SHA256, byte boyutu ve tamamlanma UTC manifest'e yazılır.
Kaynak dosya ancak host kopyası doğrulanınca **yalnız tam container_dump adıyla**
silinir. Hata olursa incomplete dosyayı başarılı yedek adıyla/last-success olarak
işaretleme. Kaynak /tmp ve host partial temizliği sonraki rehberli adımda aynı
RUN_ID/sahiplik doğrulamasıyla yapılır; genel /tmp temizliği yok.

## 5. VM dışı ikinci kopya — Windows PowerShell

LOCALAPPDATA/FullStackOpsLab/backups-private altında yeni RUN_ID klasörü seç.
Önceden varsa üzerine yazma. NTFS ACL inheritance kapatılıp yalnız mevcut
Windows kimliğine erişim verilir; yönetici/owner yetkileri şifreleme sayılmaz:

```powershell
$backupRoot = Join-Path $env:LOCALAPPDATA 'FullStackOpsLab\backups-private'
$runId = '<VM-de-dogrulanan-12-hex-run-id>'
$principal = [Security.Principal.WindowsIdentity]::GetCurrent().Name
$backupDir = Join-Path $backupRoot $runId
New-Item -ItemType Directory -Path $backupDir -ErrorAction Stop | Out-Null
icacls.exe $backupDir /inheritance:r /grant:r "${principal}:(OI)(CI)F"
if ($LASTEXITCODE -ne 0) { throw 'Backup ACL kontrolu basarisiz' }
```

Bu şablonun RUN_ID'si doldurulmadan çalıştırılmaz. `New-Item` mevcut klasörde
başarısız olmalı; `-Force` kullanılmaz. Gerçek VM IP/SSH host key doğrulaması
sonrası SCP ile yalnız database.pgdump, manifest ve karşılaştırma snapshot'ları
aktarılır. `.env.restore`, development/deployment env, TLS/CA/private key yok.

```powershell
$vmAddress = '<guncel-VM-IP>'
$copyPath = Join-Path $backupDir 'database.pgdump'
scp "labadmin@${vmAddress}:/home/labadmin/.local/share/fullstackops-deploy-lab/backups-private/$runId/database.pgdump" $copyPath
if ($LASTEXITCODE -ne 0) { throw 'Ikinci kopya aktarimi basarisiz' }
$actualHash = (Get-FileHash -LiteralPath $copyPath -Algorithm SHA256).Hash
Write-Output "Windows backup SHA256=$actualHash"
```

VM'de kaydedilen hash ile Windows Get-FileHash değeri case-insensitive **eşit**
olmalı. Metadata kopyalarının hash'leri de karşılaştırılır. Hash/parça boyutu ve
kopya UTC kaydedilir; env veya backup içeriği sohbete yapıştırılmaz. İkinci kopya
aynı fiziksel bilgisayardadır: VM disk kaybına karşı yardımcıdır, tüm host disk
kaybı/çalınmasına karşı bağımsız off-site güvence değildir.

## 6. Yeni hedef hazırlığı ve restore

**Ubuntu SSH:** [restore.env.example](restore.env.example) anahtarlarıyla yeni
RUN_ID/.env.restore dışarıda600 hazırlanır. RESTORE_POSTGRES_IMAGE bölüm2'deki
tam yerel image kimliği; restore_lab rol/database ve yeni güçlü rastgele parola.
Parola komut satırına veya stdout'a yazılmaz; Python secrets ile bellekte
üretilip600 dosyaya doğrudan yazılır. Örnek placeholder'larla servis başlatılmaz.
Mevcut `.env.deployment`/`.env.https` okunmaz, kopyalanmaz veya değiştirilmez.
Compose yalnız eksik/boş required ayarı reddeder; placeholder, RUN_ID regex'i,
image'ın gerçekten kaynak ImageID olması ve kaynak sürüm uyumu ayrıca runtime
ön kontrolünde doğrulanır. Statik model testi bu Engine kontrollerinin yerine geçmez.

`RESTORE_*`, COMPOSE_FILE/PROJECT_NAME/ENV_FILES gibi eski exported ortam
override'ları varsa değerlerini göstermeden temiz bir komut ortamı hazırlanır.
`COMPOSE_DISABLE_ENV_FILE=1` ve açık --env-file ile otomatik local .env okuması
engellenir. Gelecek yardımcı sadece tek bağımsız dosyayı kullanır:

```bash
restore_env="$run_dir/.env.restore"
restore_lab() {
  sudo docker compose --project-name "$restore_project" \
    --env-file "$restore_env" \
    -f "$HOME/fullstack-ops-lab/infrastructure/deployment/compose.restore.yaml" "$@"
}
restore_lab config -q
```

Birleşmiş model bellekte kontrol edilir, yazdırılmaz: tek restore-postgres,
exact image/no-build/pull-never, doğru yeni container/network/volume, internal
ağ, sıfır host portu, yalnız yeni volume → /var/lib/postgresql. Her kaynakta
io.fullstackops.lab=postgres-restore ve io.fullstackops.restore-run=RUN_ID.
Üç adın Docker'da **mevcut olmadığını** doğrulamadan up yapılmaz; mevcut volume
boş görünse bile kullanılmaz. Kök/deployment Compose dosyasını bu çağrıya ekleme.

```bash
restore_lab up -d --no-build --pull never --wait --wait-timeout 90 restore-postgres
```

Süre sınırıyla healthy beklenir. Sonra tam container ID/image/labels/ağ/no-port
ve yeni volume/mount doğrulanır. `tasks` ve history henüz yok olmalı; varsa dur.
Kaynak container, deployment volume veya app ağıyla eşleşme varsa restore yok.
Restore rol/database adının env ile eşleşmesi de salt okunur kontrol edilir.

Yalnız bu kapılardan sonra, **Ubuntu SSH** binary stdin ile:

```bash
timeout 180s sudo -n docker exec -i "$target_container" sh -c '
  exec pg_restore --exit-on-error --single-transaction \
    --no-owner --no-privileges --no-password \
    -U "$POSTGRES_USER" -d "$POSTGRES_DB"
' <"$dump" >"$run_dir/restore.stdout" 2>"$run_dir/restore.stderr"
```

TTY, --clean ve --create yok; dump'ın kaynak database adına reconnect edilmez.
Hedef ayrı env'den oluşmuş role/database'dir. Exit code/timeout ve özel log
kontrolü gerekir; hata halinde deployment'a restore ederek deneme yapılmaz.
Arşiv yalnız kendi güvenilir lab database'inden alınır; restore SQL çalıştırır.
[Restore seçenekleri](https://www.postgresql.org/docs/18/app-pgrestore.html).

## 7. Veri, history ve identity sequence kabulü

Restore sonrası bölüm3'teki aynı read-only SQL **yalnız doğrulanmış hedefte**
çalıştırılır. Kaynak dump öncesi/sonrası snapshot'ları ve restore: count, ID listesi,
tüm satır hash'i, tek InitialCreate/EF10.0.12 history eşit olmalı. Bilinen görevin
ID/title/description/isCompleted/createdAt/updatedAt alanları Windows HTTPS
snapshot'ıyla ayrıca karşılaştırılır; null ve UTC zaman eşitliği korunur.
Boş database restore'u, checksum veya pg_restore exit0 tek başına yeterli değil.
Altı sütun/tip/nullable/default ve primary key/identity BY DEFAULT de migration
ve kaynak kataloglarıyla karşılaştırılır; ownership kaynak yerine restore_lab.

Sequence için **yalnız geçici restore database'inde** psql ON_ERROR_STOP=1 ile:

```sql
BEGIN;
DO $probe$
DECLARE
    previous_max integer;
    generated_id integer;
BEGIN
    SELECT COALESCE(max(id), 0) INTO previous_max FROM public.tasks;
    INSERT INTO public.tasks(title, description, is_completed, created_at, updated_at)
    VALUES ('Isolated restore sequence probe', NULL, FALSE, now(), NULL)
    RETURNING id INTO generated_id;
    IF generated_id <= previous_max THEN
        RAISE EXCEPTION 'Restore sequence did not advance beyond existing IDs';
    END IF;
    RAISE NOTICE 'PASS: restored sequence generated a non-colliding ID';
END;
$probe$;
ROLLBACK;
```

INSERT id belirtmez; PK çakışması veya ID<=max kabulü başarısız yapar. Başarılı
probe ROLLBACK ile Task satırını kaldırır; tekrar read-only karşılaştırma satır/
history'nin aynı kaldığını göstermeli. **Sequence nextval rollback ile geri
alınmaz**; yalnız atılacak restore ortamında bir değer tüketilir. Kaynakta SQL
INSERT, sequence reset/setval veya migration yok. [Sequence davranışı](https://www.postgresql.org/docs/18/functions-sequence.html).

## 8. Temizlik — iki ayrı hedef

**A. Restore kaynakları (Ubuntu SSH):** başarı veya başarısızlıkta manifest'teki
tam target container/network/volume adları, project ve iki owner label doğrulanır.
Deployment/dev adlarıyla veya source volume ile eşleşme varsa dur. Yalnız bu
tek dosya/env/project için `restore_lab down --volumes` uygulanır; burada
--volumes **yalnız yeni test volume'unu** silmek içindir. Kaynak deployment için
down/-v, FLUSH, image/volume/system prune veya genel /tmp temizliği yok.
Önce/sonra envanter karşılaştırılır; ilgisiz kaynağa dokunulmaz.

**B. Deployment test kaydı (Windows HTTPS):** snapshot ID/title/createdAt ve altı
alanla sahiplik tekrar kontrol edilir. Yalnız bu deneyde oluşturulan sentinel
DELETE204/boş gövde, GET404; mevcut görevler silinmez. Başarısızlıkta da sahipli
kayıt bu yöntemle temizlenir; erişilemiyorsa temizlendi sayılmaz, ID açık kalır.
Final source read-only count/ID/alan hash ve history sentinel-öncesi baseline'a
eşit olmalı. Eşleşmiyorsa diğer kayıtları silerek sonucu düzeltme.

Kaynak /tmp dump ve restore env/geçici dosyaları yalnız manifest'teki tam adla
temizlenir; VM ve Windows'taki tamamlanmış backup/manifest/snapshot seti öğrenme
kanıtı ve retention için **korunur**. İçinde sentinel bulunması beklenir; backup
değiştirilmez. Böylece kaynakta test kaydı silinmişken eski yedekten geri gelmesi
normaldir. Final deployment altı servis/A/HTTPS/tüneller çalışır, ID/image ve
source volume korunur. Hata halinde de son güvenli durum ayrı raporlanır.

## 9. Günlük hedef, saklama ve başarısızlık kontrolü — öneri

- Gelecek ayrı görevde VM'de günde bir kez02:00 Europe/Istanbul için basit
  systemd oneshot/timer düşünülebilir; kurulum/enable veya credential'lı unit bu
  hazırlıkta yok. Persistent=true açılışta kaçırılmış tetik için yardımcı olur;
  VM kapalı olduğu günlerin tarihsel yedeklerini geriye dönük üretmez.
- Zamanlanan yedek işi Task oluşturmaz; sentinel yalnız rehberli restore
  doğrulaması içindir. Görev zamanlamasının uygulanması bu hazırlıktan ayrıdır.
- [systemd timer](https://www.freedesktop.org/software/systemd/man/latest/systemd.timer.html)
  davranışı çalışma anında VM sürümüyle doğrulanır. Yeni job tek instance çalışır;
  çakışan çalışmayı lock ile reddeder, bounded timeout/nonzero exit uygular.
- Son yedi günlük başarılı tam backup seti ve son doğrulanmış restore seti
  tutulur. Eksik/başarısız yeni dump nedeniyle son iyi set silinmez. Purge ancak
  yeni dump, checksum ve Windows ikinci kopyası doğrulanınca; yalnız backup_root
  altındaki manifest sahibi setlere uygulanır. Bu görevde retention silme komutu yok.
- last_dump_success_utc ile last_off_vm_copy_verified_utc ayrı tutulur. İkisi de
  24 saatten genç değilse günlük veri kaybı hedefi sağlandı denmez. Partial dosya
  veya başarısız işlem last-success'i güncellemez. Özel log yerelde incelenir;
  günlük kontrol nonzero/timeout, dosya boyutu/hash ve son başarı yaşını gösterir.
- Windows kopyası şimdilik rehberli SCP; VM timer'ı tek başına bunu otomatik
  güncel tutmaz. VM/PC kapalıyken veya ikinci kopya eskiyken RPO24h garanti
  edilemez. Bu lab WAL/PITR, remote off-site depolama veya production backup SLA'sı
  değildir. Kurtarma süresi ve düzenli job/restore başarısı runtime'da ölçülecek.

## 10. Kabul tablosu ve yerel kontroller

| Madde | Şimdiki durum | Gelecek runtime kanıtı |
| --- | --- | --- |
| Ayrı restore modeli/isimler/no-port/no-source-volume | Statik PASS | Yokluk kapısı, actual mount/labels/image ve yeni volume |
| Zorunlu env, verilen ImageID'nin modele aktarımı, ignore sınırı | Statik PASS | Placeholder/regex, gerçek local ImageID/private env/izin ve18 server/araç eşleşmesi |
| Mantıksal dump | NOT VERIFIED | Dolu/sentinel içeren source, pg_dump exit0, sakin pencere snapshot eşleşmesi |
| VM+Windows kopyası | NOT VERIFIED | 700/600 ve NTFS ACL, boyut/SHA256 eşit, yeni UTC |
| Restore/sentinel/history/şema | NOT VERIFIED | Ayrı hedefte exit0, altı alan ve tam hash/history/katalog eşleşmesi |
| Sequence | NOT VERIFIED | Hedefte generated ID>max, çakışma yok, probe sonrası aynı Task/history |
| Cleanup ve kaynak koruması | NOT VERIFIED | Yalnız restore kaynakları/sahipli source Task temiz, backup setleri duruyor |
| Günlük job/retention/RPO | Plan; NOT VERIFIED | Job/failure/son başarı yaşı ve güncel ikinci kopya ayrıca uygulanıp doğrulanmalı |

Statik komut **Windows PowerShell, repository kökü**; Engine/VM işlemi yapmaz:

```powershell
py -3 tests/Deployment.BackupRestore.Configuration.Test.py
if ($LASTEXITCODE -ne 0) { throw 'Restore configuration testleri basarisiz' }
py -3 tests/Deployment.Configuration.Test.py
if ($LASTEXITCODE -ne 0) { throw 'Mevcut deployment configuration testleri basarisiz' }
```

Yeni dört test önce eksik config/ignore nedeniyle beklenen FAIL; hazırlık sonrası
gerçek Compose parser'ıyla4/4 PASS. İki run ID'nin kaynakları farklı, sadece yeni
volume kullanılıyor, host portu/build/source bind yok, required ayar yokken config
reddediliyor. Testler yalnız rastgele sahte credential fixture'ı kullanır ve
diagnostic çıktıda canary olmadığını denetler; çözülmüş model yazdırılmaz.
Bu testler pg_dump/SQL/restore veya dosya izinlerinin runtime kanıtı değildir.

Mevcut deployment statik testleri7/7 PASS; yeni rehberde3 PowerShell/6 Bash bloğu
yalnız parser ile ve test Python AST ile kontrol edildi. Dört değişen/yeni
Markdown belgede120 yerel dosya/anchor bağlantısı, repository secret leakage
kontrolü ve git diff --check PASS. SQL blokları mevcut migration/alanlar ve
resmî PostgreSQL18 davranışıyla incelendi; PostgreSQL'e gönderilmedi, runtime
SQL/restore kabulü yapılmış sayılmaz. Test fixture'ları geçici dizinlerde temizlendi.

Kaynaklar: [kök Compose](../../compose.yaml), [deployment](compose.deploy.yaml),
[HTTPS overlay](compose.https.yaml), [migration](../../src/backend/FullStackOpsLab.Api/Migrations/20260928113912_InitialCreate.cs),
[API](../../src/backend/FullStackOpsLab.Api/Program.cs), [restore Compose](compose.restore.yaml),
[örnek](restore.env.example), [statik test](../../tests/Deployment.BackupRestore.Configuration.Test.py),
[deployment planı](../../docs/deployment-plan.md), [şartname](../../PROJECT_SPEC.md#advanced-lab-e--deployment).

## 11. VM envanteri ve public aktarım — 18 Ekim 2026

Bu kayıt, temiz ana repository `main/5a00317614354d8c4377918d32d0def4432ee05f`
üzerinden rehberli olarak kullanıcının çalıştırdığı PowerShell/Ubuntu SSH
komutlarına ve paylaştığı çıktılara dayanır. Agent VM'ye bağlanmadı, gerçek env
veya private key okumadı. Önceki 17 Ekim A→B→A deneyinin tekrarı değildir.

### Kaynak ve saklama konumu ön kontrolü

| Kontrol | Gerçek sonuç |
| --- | --- |
| VM/erişim | Hyper-V Running, hostname fullstackopslabvm; eth0 UP 172.30.249.139/20; SSH başarılı. Hyper-V IP alanı boştu; guest çıktısıyla doğrulandı, ağ/reboot değişikliği yapılmadı |
| Engine | unix:///var/run/docker.sock; VM'nin kendi Linux Engine'i |
| Uygulama | API/frontend exact image referansları, ImageID ve revision aktif A/release.json ile eşleşti: kaynak1b52633776279b1661a7cac53392d385cbf10444; digest çifti değiştirilmedi |
| Kaynak PostgreSQL | Project fullstackops-deploy-lab, service postgres; postgres:18-alpine; yerel ImageID sha256:77f585114c32fbca283dc835b0596f4e52b51b4c6662d7810b2f4084f60a1873; linux/amd64 |
| Araç uyumu | Server18.6, pg_dump18.6 ve pg_restore18.6; ileride restore aynı doğrulanmış yerel ImageID ile, mutable tag pull olmadan yapılacak |
| Kaynak mount | volume/fullstackops-deploy-lab-postgres → /var/lib/postgresql; başlangıçta host portu yok |
| Database/role | psql current_database/current_user, container'ın POSTGRES_DB/POSTGRES_USER ayarlarıyla eşleşti; değerler yazdırılmadı. Socket sorgusu yeni TCP parola kanıtı sayılmadı |
| Boyut | pg_database_size 7976639 byte; pg_size_pretty 7790 kB; gerçek custom dump boyutu henüz bilinmiyor |
| VM yedek kökü | /home/labadmin/.local/share/fullstackops-deploy-lab/backups-private; repository dışında, henüz yok; boş alan46494777344 byte/43,30 GiB |
| Windows ikinci kopya kökü | C:\Users\Ensar\AppData\Local\FullStackOpsLab\backups-private; repository/OneDrive dışında, henüz yok; boş alan463948599296 byte/432,09 GiB |

Boş alanlar ölçüm anına aittir; mevcut küçük database için yeterli başlangıç payı
vardır, gelecekteki veri büyümesi veya gerçek dump boyutu garantisi değildir.
Klasörler oluşturulmadı;700/600/NTFS ACL ve gerçek yedek ikinci kopyası bu adımda
doğrulanmadı. Source sorguları salt okunurdu; Task/history snapshot'ı alınmadı.

### Yalnız public dosyaların aktarımı

VM'de dört hedefin de bulunmadığı doğrulandı. Windows PowerShell Get-FileHash,
yalnız bu dört dosya için SCP, Ubuntu sha256sum --check kullanıldı; dördü de OK.
VM'nin kaynak ağacı topluca güncellenmedi; mevcut env/TLS/release ezilmedi.

| Aktarılan repository yolu | SHA256 (aktarılan byte'lar) |
| --- | --- |
| infrastructure/deployment/BACKUP-RESTORE.md | 554633bea05144ff99738a117411bbbd4ca4c72c86a995a9668e39e65505dd58 |
| infrastructure/deployment/compose.restore.yaml | 3c71d13e1a4c652f4f7ac045d4068e8a84396cc832491ae45f9b4c61c40b9680 |
| infrastructure/deployment/restore.env.example | af8d9f46533a1920dc20fd7ac11de1abb6ca277c3120c4238fe2abb45d09f506 |
| tests/Deployment.BackupRestore.Configuration.Test.py | 6b7a02a9289116adad8d3e7267ef00ffb6c4fc694ab1f274efc8a3524cd728de |

Bu hash'ler aktarım anındaki dosyaları tanımlar. Bu kabul kaydı sonradan ana
repository rehberine eklendiğinden güncel BACKUP-RESTORE.md hash'i farklıdır;
VM'deki rehber bu son dokümantasyon ekini almış sayılmaz. Gerçek env, TLS/CA,
credential, dump veya uygulama build çıktısı aktarılmadı.

### Restore adları ve kapanış karşılaştırması

RUN_ID `4756810b5b43` seçildi. Project fullstackops-restore-4756810b5b43,
container/volume fullstackops-restore-4756810b5b43-postgres ve network
fullstackops-restore-4756810b5b43-net adları mevcut değildi; üç kaynak türünde
Compose project etiketi de kullanılmıyordu. İsimler **rezerve edilmedi**; gerçek
uygulama öncesi yokluk kontrolü tekrarlanmalı. Restore modeli tek başına kullanılır;
deployment volume'u hedef değildir. Restore env/credential veya Docker kaynağı
oluşturulmadı; fiilî restore mount/izolasyon kabulü henüz yapılmadı.

Başlangıç ve kapanışta altı container healthy ve aynı tam kimliklerdeydi:

| Servis | Başlangıç = kapanış container ID |
| --- | --- |
| frontend | 15a93fef4000eaad9d90637dcc50a1e97e8fa1c27efeef4b6d3adb5f764542c6 |
| api | 8b3d9f24f6274bff0dc74fdd366b00f89c896897d0a16da3efbaedcd94ffdff9 |
| postgres | b67a87f2d83ffc7119262239f0bc48d8b2bf141aca9f84b1f4b55d62e173f7f9 |
| prometheus | 84eaf1ceebb5755fecab344c1f094eb6122f6d9ee75f5acc6c79a718c323b33b |
| redis | d98d34cc73c5d0968958ac64a54ad76fbaadce0c78f73d17566da93c1439a582 |
| grafana | ed9398e62129b273e98917346703b6fe1ffccab688114df6fa3800f3fdf53637 |

İki volume listesinde yalnız aynı üç local deployment volume'u vardı: postgres,
prometheus ve grafana. Bu liste volume içeriğinin/hash'inin ölçümü değildir.
Deployment ağının kimliği dc2f465449d7c1546486c1deddd7aadf0f636428ec8e5d4cdff6213b5da9a21e
korundu; bridge/host/none ağ kimlikleri de başlangıçla aynıydı. Restore kaynağı yoktu.
Tüneller değiştirilmedi; Windows listener/HTTPS erişimi bu adımda yeniden ölçülmedi.

**Ön kontrol PASS:** güncel envanter/A, source mount/araç/yerel image, konum/boş
alan, public aktarım bütünlüğü ve isim çakışma kontrolü. **NOT VERIFIED:** gerçek
dump, ikinci yedek kopyası/izinleri, restore/altı alan/history/sequence, deney
cleanup'ı, günlük job ve final lab. Test kaydı/yedek oluşturma, migration, image
pull/build, recreate, kaynak silme veya zamanlama etkinleştirme yapılmadı.
Stack A'da çalışır bırakıldı; development kaynaklarına işlem yapılmadı.

Ana repository'de bu kayıt sonrası restore statik testleri4/4, mevcut deployment
statik testleri7/7, dört belgede125 yerel dosya/anchor bağlantısı, repository secret
kontrolü ve git diff --check PASS. Testler sahte geçici ayarlarla yalnız Compose
parser'ını kullandı; Engine/VM runtime testi değildir. Yalnız dört belge değişti;
Compose/örnek/test/release dosyaları değişmedi, commit/push yapılmadı.

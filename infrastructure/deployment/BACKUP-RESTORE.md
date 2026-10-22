# Deployment — izole PostgreSQL yedek/restore hazırlığı

**21 Ekim 2026:** [VM günlük backup kurulumu ve iki manuel service çalışması](backup/README.md#rehberli-vm-kurulumu-ve-iki-manuel-çalışma--21-ekim-2026)
PASS. Yeni günlük dump3477 byte; ikinci çalışmada set/hash/mtime ve asıl başarı
zamanı korundu. Timer disabled/inactive. Kaynak veri/altı container ve eski manuel
VM/Windows yedekleri korundu; yeni günlük arşivin Windows kopyası/restore'u,
zamanlanmış tetik/catch-up, gerçek çok günlük retention/RPO ve final kabul açık.

**20 Ekim 2026: kontrollü cleanup PASS.** Kaynak sahipli Task ID8 HTTPS DELETE204/
GET404 ile silindi; yalnız restore container/ağ/volume kaldırıldı. Kaynak veri ve
history baseline ile aynı, altı kaynak container aynı image/kimliklerle healthy;
VM/Windows yedekleri hash/izin kontrolleriyle korundu. Günlük zamanlama/retention
ve deployment final kabulü açık. Güncel kanıt [bölüm14](#14-kontrollü-temizlik-ve-yedek-koruması--20-ekim-2026).

**19 Ekim 2026:** mantıksal dump, Windows ikinci kopyası ve izole restore/veri/şema/
history/sequence kabulü PASS. O oturumda ID8 ve restore kaynakları kullanıcı
isteğiyle bırakılmıştı; sonraki temizlik ayrı tarihli kayıttır. Restore kanıtı
[bölüm13](#13-izole-restore-ve-sequence-kabulü--19-ekim-2026), dump kanıtı
[bölüm12](#12-mantıksal-dump-ve-windows-ikinci-kopyası--19-ekim-2026),
18 Ekim ön kontrolü [bölüm11](#11-vm-envanteri-ve-public-aktarım--18-ekim-2026)
içindedir. İlk statik hazırlıkta temiz
`main/4a11d0c6684b10e4fdf94b21127af9901be21c5f` incelendi; o aşamada VM erişimi,
yedek alma, Task oluşturma, restore, kaynak temizleme veya zamanlama etkinleştirme
yapılmadı. Son [A→B→A kabulü](UPDATE-ROLLBACK.md#9-rehberli-aba-runtime-kabulü--17-ekim-2026)
17 Ekim'e aittir; yeni envanter kontrolü o geçiş deneyini tekrarlamaz.
Aktif A [release kaydı](release.json), digestler, HTTPS ve development korunur.

[Plan adım8](../../docs/deployment-plan.md#8-günlük-yedek-ve-ayrı-restore-pratiği)
için aşağıdaki gruplar daha sonra **rehberli ve sonuç beklenerek** uygulanacak.
Dump/ikinci kopya bölüm12'de, gerçek restore bölüm13'te doğrulandı. Aşağıdaki
örnekler mevcut run'ı tekrar yüklemek, yeni sentinel oluşturmak veya dosyaları
ezmek için kullanılmaz. Yeni bir deney ayrıca istenirse yeni RUN_ID ve yokluk
kapıları gerekir; grupları sonuç bekleyerek uygula, topluca çalıştırma.

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

19 Ekim RUN_ID4756810b5b43 için private env/model ve gerçek restore kabulü
[bölüm13'te](#13-izole-restore-ve-sequence-kabulü--19-ekim-2026) tamamlandı.
19 Ekim'de dolu hedef doğrulandı; 20 Ekim'de bölüm14 kapsamında kaldırıldı.
Bu run için aşağıdaki up/restore komutlarını tekrarlama, env veya yedek/test
görevi üretme. Aşağıdaki yokluk/boş database
kapıları başka bir deney ayrıca istendiğinde yeni RUN_ID için uygulanır.

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

**RUN_ID4756810b5b43 temizliği 20 Ekim'de tamamlandı; tekrar çalıştırma.**
19 Ekim restore oturumunda kaynaklar bırakıldı; ardından kullanıcı ayrı temizlik
istedi. Gerçek sıra ve sonuçlar [bölüm14'te](#14-kontrollü-temizlik-ve-yedek-koruması--20-ekim-2026):
önce sahipli ID8 API ile silindi, sonra tam kimlik/etiket/mount kapısıyla restore
container/ağ/volume kaldırıldı. Private kanıt, yedek, credential ve TLS dosyaları
korundu. Aşağıdaki yöntemler gelecekte ayrıca istenen bir deney içindir.

**A. Restore kaynakları (Ubuntu SSH):** başarı veya başarısızlıkta manifest'teki
tam target container/network/volume adları, project ve iki owner label doğrulanır.
Deployment/dev adlarıyla veya source volume ile eşleşme varsa dur. Yalnız bu
tek dosya/env/project için `restore_lab down --volumes` bir yöntemdir; burada
--volumes **yalnız yeni test volume'unu** hedefler. 20 Ekim'de bu yöntem
çalıştırılmadı: tekrar kontrol edilen tam container ID'sine stop/rm, boş ağın
tam ID'sine network rm ve kullanılmayan test volume adına volume rm uygulandı.
Kaynak deployment için down/-v, FLUSH, image/volume/system prune veya genel /tmp temizliği yok.
Önce/sonra envanter karşılaştırılır; ilgisiz kaynağa dokunulmaz.

**B. Deployment test kaydı (Windows HTTPS):** snapshot ID/title/createdAt ve altı
alanla sahiplik tekrar kontrol edilir. Yalnız bu deneyde oluşturulan sentinel
DELETE204/boş gövde, GET404; mevcut görevler silinmez. Başarısızlıkta da sahipli
kayıt bu yöntemle temizlenir; erişilemiyorsa temizlendi sayılmaz, ID açık kalır.
Final source read-only count/ID/alan hash ve history sentinel-öncesi baseline'a
eşit olmalı. Eşleşmiyorsa diğer kayıtları silerek sonucu düzeltme.

Bu temizliğin kapsamı belirtilen Docker hedefleri ve sahipli Task ID8'dir.
Restore env/credential/TLS, private kanıtlar ve tamamlanmış VM/Windows
backup/manifest/snapshot seti **korunur**. 20 Ekim'de geçici dosya temizliği de
yapılmadı; gelecekte gerekirse yalnız ayrı doğrulanmış sahipli tam yollar ele alınır.
Yedekte sentinel bulunması beklenir; backup
değiştirilmez. Böylece kaynakta test kaydı silinmişken eski yedekten geri gelmesi
normaldir. Final deployment altı servis/A/HTTPS/tüneller çalışır, ID/image ve
source volume korunur. Hata halinde de son güvenli durum ayrı raporlanır.

## 9. Günlük hedef, saklama ve başarısızlık kontrolü

21 Ekim'de [ayrıntılı günlük işletim rehberi](backup/README.md), Python script ve
systemd service/timer hazırlandı. Günlük02:00 **Europe/Istanbul**, Persistent=true
ile açılışta bir telafi çalışması; geçmiş günlere tarihsel dump üretme yok.
Kaynak doğrulama/custom dump/checksum/--list ve OS kilidi kullanılır; Task
oluşturulmaz. Sonraki rehberli VM kurulumu ve timer kapalıyken ilk gerçek dump /
aynı gün ikinci service çalışması geçti; [ayrıntılı runtime kaydı](backup/README.md#rehberli-vm-kurulumu-ve-iki-manuel-çalışma--21-ekim-2026).
Timer enable/start ve gerçek çok günlük retention silmesi yapılmadı.

Saklama kararı somutlaştırıldı: ayrı root-owned700
`/var/lib/fullstackops-deploy-lab-backup/` altında son **yedi başarılı farklı gün**;
aynı gün yeni dump yerine mevcut set/hash doğrulanır, son başarı zamanı tazelenmez.
Retention sadece bu otomasyonun owner manifest'li doğrulanmış setlerini hedefler.
Manuel backups-private/4756810b5b43 restore kabul seti ve Windows kopyaları bu
işlemden ayrıdır ve silinmez. Dump/kopya/arşiv hatası retention başlatmaz.

Önceki öneride VM purge için Windows kopya kapısı vardı. Yeni hazırlıkta Windows
kopyası **manuel SCP**, VM retention'ı ise yalnız kendi yedi başarılı günlük setine
bağlıdır; Windows onayı beklemez. Bu fark bilinçli ve günlük RPO garantisi değildir.
`last-success.json` dump zamanı ve `last-attempt.json` güvenli exit/aşama kaydıdır;
Windows kopya UTC/hash/ACL makbuzu ayrıca tutulur. VM/PC kapalı veya ikinci kopya
eskiyse24h RPO garanti edilmez. İki kopya aynı fiziksel host'tadır; off-site/PITR/
production SLA kabulü yok. Linux iki süreç kilit fixture'ı,700/600 izinler ve
systemd verify/calendar gerçek VM'de geçti. Gerçek timer/catch-up, çok günlük
retention, yeni günlük arşivden restore/Windows kopyası ve final lab kabulü
**NOT VERIFIED**;14 Windows fixture testi runtime yerine geçmez.

## 10. Kabul tablosu ve yerel kontroller

| Madde | Şimdiki durum | Kanıt / kalan doğrulama |
| --- | --- | --- |
| Ayrı restore modeli/isimler/no-port/no-source-volume | Statik ve runtime PASS — 19 Ekim, bölüm13 | Yokluk kapısı, yeni volume, exact image/labels/mount, internal ağ/tek üye ve sıfır host portu |
| Zorunlu env, verilen ImageID'nin modele aktarımı, ignore sınırı | Statik PASS; gerçek private env/model/yerel image/izin ve hedef bağlantısı PASS | restore_lab database/role, PostgreSQL18.6 ve başlangıçta sıfır public tablo; yeni TCP parola deneyi değil |
| Mantıksal dump | PASS — 19 Ekim, bölüm12 | ID8 içeren custom dump, pg_dump exit0; dump öncesi/sonrası veri ve history aynı |
| VM+Windows manuel kopyası | PASS — 19 Ekim; koruma tekrar PASS — 20–21 Ekim | Bölüm14 ve [günlük job kaydı](backup/README.md#rehberli-vm-kurulumu-ve-iki-manuel-çalışma--21-ekim-2026): orijinal manifest+11 dosya hash/izinleri korundu; 21 Ekim kontrolü yeni günlük arşivin Windows kopyası değildir |
| Restore/sentinel/history/şema | PASS — 19 Ekim, bölüm13 | pg_restore exit0; ID8/altı alan/tam satır hash/history eşit; sütun/nullable/default/PK/identity ve hedef ownership doğrulandı |
| Sequence | PASS — 19 Ekim, bölüm13 | ID belirtilmeden9>8; probe satırı ROLLBACK; hedef veri/history aynı, kaynak sequence8, restore9 |
| Kaynak koruması | PASS — 19–20 Ekim, bölüm13–14 | Altı kaynak ID/image aynı, healthy/RestartCount0; kaynak volume/mount korundu. Sahipli ID8 silindikten sonra Task verisi/history sentinel-öncesi baseline ile aynı; source sequence8 sıfırlanmadı |
| Cleanup | PASS — 20 Ekim, bölüm14 | Sahipli ID8 DELETE204/GET404; yalnız doğrulanmış restore container/network/volume kaldırıldı, yokluk geçti. Yedek/env/TLS/kanıtlar korundu |
| Günlük job/retention/RPO | Kurulum ve iki manuel service çalışması PASS — 21 Ekim; timer disabled/inactive | [Gerçek dump ve aynı gün koruma](backup/README.md#rehberli-vm-kurulumu-ve-iki-manuel-çalışma--21-ekim-2026); Linux kilit fixture/izin/unit parser PASS. Gerçek takvim/catch-up/çok günlük retention, yeni günlük arşivin restore'u/Windows kopyası ve RPO NOT VERIFIED |

Statik komut **Windows PowerShell, repository kökü**; Engine/VM işlemi yapmaz:

```powershell
py -3 tests/Deployment.BackupRestore.Configuration.Test.py
if ($LASTEXITCODE -ne 0) { throw 'Restore configuration testleri basarisiz' }
py -3 tests/Deployment.Configuration.Test.py
if ($LASTEXITCODE -ne 0) { throw 'Mevcut deployment configuration testleri basarisiz' }
```

18 Ekim statik hazırlık sonuçları (19 Ekim runtime kaydı bölüm12): yeni dört test
önce eksik config/ignore nedeniyle beklenen FAIL; hazırlık sonrası
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

## 12. Mantıksal dump ve Windows ikinci kopyası — 19 Ekim 2026

Başlangıç Git temiz `main/3514d9bd361dbe68ccf4964a607c59405771fbbd`.
Komutları kullanıcı Windows PowerShell ve Ubuntu SSH'de küçük gruplarla
çalıştırıp gerçek sonuçları paylaştı; agent VM'ye bağlanmadı, private dosyaları
okumadı veya deneyi ayrıca çalıştırmadı. Aktif A uygulama kaynağı
1b52633776279b1661a7cac53392d385cbf10444 ve [seçilmiş digest çifti](release.json)
korundu; yeni image seçilmedi/pull edilmedi/build edilmedi.

### Erişim, private çalışma alanı ve model

- VM IP172.30.249.139; altı servis aynı başlangıç kimlikleriyle healthy. PostgreSQL
  project/service ve fullstackops-deploy-lab-postgres → /var/lib/postgresql mount'u
  doğru; API/PostgreSQL/Redis host portu yok, frontend/monitoring yayınları loopback.
- Windows HTTPS tüneli ilk kontrolde yoktu; VM127.0.0.1:18443 LISTEN doğrulandı.
  Yalnız Windows127.0.0.1:18443 → VM127.0.0.1:18443 SSH tüneli açıldı, var olan
  diğer tünellere/servislere işlem yapılmadı. Kullanıcı browser'da uyarısız açılış
  bildirdi; otomatik browser/Console veya yeni JS/CSS kabulü yapılmış sayılmaz.
- HTTPS POST/GET Schannel curl ile VERIFY0/IP127.0.0.1 geçti; komuta özel
  ssl-revoke-best-effort kullanıldı. Zincir/hostname/geçerlilik açık kaldı;
  [iptal kontrolü sınırı](HTTPS.md#14-https-etkinleştirme-ve-runtime-kabulü--1516-ekim-2026)
  değişmedi, revocation NOT VERIFIED.
- RUN_ID4756810b5b43 için VM backup kökü ve run klasörü labadmin/700 oluşturuldu.
  Windows kökü ve run klasöründe inheritance kapalı/current-user FullControl;
  manifest ve11 dosyada sahibi mevcut kullanıcı, Allow erişimi yalnız aynı hesap.
  Bunlar erişim kısıtlamasıdır, şifreleme veya off-site koruma değildir.
- VM'de yeni bağımsız restore credential'ı secrets.token_urlsafe(32) ile üretilip
  yalnız Git dışındaki .env.restore dosyasına600 yazıldı; değerler gösterilmedi.
  Gerçek env ile config-q ve yakalanan JSON model PASS: tek restore servisi,
  doğrulanmış local PG ImageID/pull-never, build/host portu yok, ayrı internal ağ
  ve yalnız yeni restore volume'u, doğru labels. Env/TLS dosyaları ezilmedi.
  Bu parse kabulüdür; restore container/network/volume oluşturulmadı.

### Test kaydı ve sakin veri penceresi

| Aşama | Gerçek sonuç / UTC |
| --- | --- |
| Sentinel öncesi baseline | READ ONLY,0 Task/IDs[], boş satır SHA256 e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855; 11:34:24.809352 |
| History | Tek 20260928113912_InitialCreate, EF10.0.12; baseline/dump öncesi/sonrası/final aynı |
| HTTPS test görevi | POST201, ID8, Location /api/tasks/8; https://tasks.fullstackops.test:18443/api/tasks/8 olarak çözüldü |
| HTTP sözleşmesi | Altı alan, description null/isCompleted false/geçerli zamanlar; doğrudan DB'ye giden tekil GET200/JSON ile POST snapshot'ının altı alanı aynı |
| Snapshot aktarımı | Windows→VM yalnız sentinel.snapshot.json;223 byte, SHA25680f5fbca8aaeb8bc666cb51f15a9e58d355c4921f0bccde5894aca59fc37eba0; VM izin600 |
| Dump öncesi | 1 Task/IDs[8], altı alan HTTPS snapshot ile eşit, history baseline ile aynı; 11:39:53.232320 |
| Dump sonrası | Aynı sayı/ID/tam satır hash/altı alan/history; 11:44:24.411327 |
| Veri hash'i | Önce/sonra/final 2ad79064002470f10e0f42391519d82308a449f4bf5bd7de8825b682aee6fe3d |
| Son READ ONLY kontrol | Yalnız ID8, altı alan/history/hash aynı; 12:08:48.906339 |

Snapshot SQL'i UTF-8 BOM'suz/600, REPEATABLE READ READ ONLY transaction ve UTC
kullandı. SQL/API zamanları UTC zaman değeri olarak karşılaştırıldı. Başka mutation
yapılmayan pencerede önce/sonra eşitlik görüldü; pg_dump kendi tutarlı snapshot'ını
alır, ayrı SQL sorgularıyla ortak transaction snapshot'ı iddia edilmez. Başlangıçta
başka Task yoktu; çok kayıtlı veri seti veya performans kabulü değildir.

### Gerçek dump ve ikinci kopya

| Madde | Kanıt |
| --- | --- |
| Source PostgreSQL | Yerel ImageID sha256:77f585114c32fbca283dc835b0596f4e52b51b4c6662d7810b2f4084f60a1873/linux-amd64; server/pg_dump/pg_restore18.6 |
| Dump yöntemi | Kaynak container'da pg_dump --format=custom --no-privileges --no-password --lock-wait-timeout=5s;180s outer sınır; yalnız /tmp/fullstackops-backup-4756810b5b43.pgdump |
| Sonuç | pg_dump exit0, stdout/stderr boş; canlı volume dosyası kopyalanmadı |
| VM kopyası | Docker cp ile özel run klasörüne database.pgdump.partial; container ve VM SHA256 eşit, labadmin/600 |
| Arşiv listesi | Aynı18.6 pg_restore --list,60s sınır, exit0/stderr boş; tasks TABLE/DATA, migration history DATA ve identity sequence SET kaydı mevcut |
| Tamamlanma | List kontrolü ve tekrar hash eşleşmesi sonrası aynı klasörde database.pgdump adına mv-n; partial kalmadı; izin600 |
| Boyut | 3578 byte |
| Dump SHA256 | f4eeadd74cacdf90ec68024117e9d015d8008531865a3b4ad8e5556ef0fcb687 |
| Manifest | manifest.json2511 byte; SHA2564b29c61a0ea8022f56671f7103cdc92e106c99421820ebfee8baa61c924f38db |
| Windows aktarımı | Önce manifest ayrı SCP/hash kontrolü; sonra10 dosya. Mevcut sentinel.snapshot.json boyut/hash eşit olduğu için korunup tekrar yazılmadı |
| Windows bütünlüğü | Manifest hash'i ve11 dosyanın her birinin byte boyutu/SHA256 eşleşti; ACL kontrolünde bütünlük tekrar doğrulandı |
| Windows kabul zamanı | 2026-10-19T11:59:45.3912258+00:00; windows-copy-verified.json özel Windows klasöründe, ACL kontrolü geçti |

Saklanan konumlar:

- VM: /home/labadmin/.local/share/fullstackops-deploy-lab/backups-private/4756810b5b43/
- Windows: C:\Users\Ensar\AppData\Local\FullStackOpsLab\backups-private\4756810b5b43\

Manifest'teki açık liste: database.pgdump, baseline.json, source.before.json,
source.after.json, sentinel.snapshot.json, snapshot.sql, inventory.json,
pg.versions.txt, dump.started-utc.txt, dump.completed-utc.txt ve
archive.completed-utc.txt. Son üç zaman dosyası saklandı ve hash karşılaştırıldı;
bu raporda çıktısı paylaşılmayan zaman değerleri tahmin edilmez. Manifest'in
kendisi bu11 dosyaya ek olarak kopyalandı. Windows'ta ayrıca asıl HTTPS istek/yanıt
dosyaları ve ikinci kopya kabul kaydı korunuyor. Env/credential/TLS/CA veya ham
arşiv listesi/loglar Windows'a aktarılmadı. VM manifest'i kopyadan önce oluşturulmuş
bir kayıttır; stage alanı korunur, Windows kabul zamanı ayrı receipt'tedir.

### Kapanış, hata kaydı ve kalan işler

İlk genel son kontrol RuntimeError verdi; ham stderr saklı olduğundan nedeni
kesinleşmedi. Ardından sudo-v ve sınırlı tanıda SUDO/FRONTEND_INSPECT exit0/stderr
yok. Ayrı container/volume/network tabloları ve aşaması belirtilen dar son SQL/
dosya kontrolü geçti. Önceki hata geriye dönük PASS veya kesin sudo-cache sorunu
sayılmaz; dump yeniden alınmadı, stack restart edilmedi.

Son envanterde altı container bölüm11'deki tam kimliklerle healthy; A çifti ve
yerel PG image aynı. Üç deployment volume adı korundu, yalnız mevcut ağ isimleri
vardı; restore container/volume/network yok. VM manifest+11 dosya hash/boyut/600,
klasörler700 ve restore env600 finalde tekrar geçti. Başlangıç0 Task'tan farklı
olarak **yalnız sahipli ID8 bilerek bırakıldı**; veri/history korunma iddiası bu
kontrollü eklemeyi kapsar, test kaydı temizlenmiş sayılmaz. Kaynak /tmp dump'ı da
bu adımda silinmedi; ileride yalnız tam sahipli adla temizlik yapılacak.

Tamamlanmış VM/Windows backup setlerini ve ID8'i koru. Sonraki ayrı görev,
yokluk/image/izin kontrollerinden sonra izole hedefe gerçek restore, altı alan/
şema/history/tam hash ve sequence kabulüdür; sonra yalnız hedef kaynakları ve
sahipli ID8 temizlenir. **Restore/sequence/cleanup, günlük job/retention/RPO24h
garantisi ve deployment final kabulü NOT VERIFIED.** Aynı host Windows kopyası
off-site değildir; checksum/--list, gerçekten geri yüklenmiş database kanıtı
yerine geçmez. Migration, mevcut deployment image/credential/TLS değişikliği, build/pull, mevcut
servis recreate/stop, FLUSH/prune veya development kaynaklarına işlem yapılmadı.
Yalnız bu rehber, deployment README, plan ve PROJECT_STATUS güncellendi;
backup/private dosyalar Git'e alınmadı. Commit/push yapılmadı.

Ana repository kapanış kontrolleri: restore statik test4/4 ve mevcut deployment
statik test7/7 PASS; dört belgede133 yerel dosya/anchor bağlantısı, repository
secret kontrolü ve git diff --check PASS. Bunlar sahte geçici ayarlarla Compose
parser/dokümantasyon kontrolleridir; VM dump deneyi ayrıca tekrarlanmadı.

## 13. İzole restore ve sequence kabulü — 19 Ekim 2026

Başlangıç ana repository temiz `main/76bdb2c638967dadd3206cf1103ef9453e1c5667`.
Kanıtlar kullanıcının küçük gruplar halinde Ubuntu SSH terminalinde çalıştırıp
paylaştığı gerçek sonuçlardır. Agent VM'ye bağlanmadı, gerçek env veya private
key okumadı. Mevcut dump kullanıldı; yeni dump/sentinel, uygulama build/pull,
migration, kaynak servis recreate veya zamanlama yapılmadı. Aktif A kaynak SHA
`1b52633776279b1661a7cac53392d385cbf10444` ve [iki digest](release.json) aynı.

### Hedef kapıları ve gerçek restore

| Kontrol | Gerçek sonuç |
| --- | --- |
| Kaynak başlangıcı | 13:41:49.103074 UTC: yalnız ID8, altı alan/tüm satır hash/history dump sonrası kayıtla aynı; source sequence8/is_called=true |
| Dosya/env/model | VM manifest ve11 dosya boyut/SHA256,700/600; mevcut bağımsız env/config-q ve model PASS; credential/model yazdırılmadı |
| Yokluk kapısı | Tam restore container/network/volume adları ve project etiketi boş; beklenmedik mevcut volume kullanılmadı |
| Image/araç | Yerel linux/amd64 sha256:77f585114c32fbca283dc835b0596f4e52b51b4c6662d7810b2f4084f60a1873; PostgreSQL server/pg_restore18.6; build/pull yok |
| Başlatma | Yalnız restore-postgres; up -d --no-deps --no-build --pull never --wait --wait-timeout 90;120s dış sınır, exit0/no timeout,5.828s |
| Container | 90c817d6a25b63b0507da743a0ddfa27a6b8bb6224160f4822a0a7df3c0f6e41; running/healthy, exact image eşleşti |
| Volume | fullstackops-restore-4756810b5b43-postgres → /var/lib/postgresql, RW=true; local, CreatedAt2026-10-19T13:45:11Z |
| Ağ | fullstackops-restore-4756810b5b43-net; ID07540ec9ab226b939b623b6e1b929f33f59f411746e0251ec88a98aa9edef0cd; Internal=true, Members=1 |
| Etiketler/port | Project fullstackops-restore-4756810b5b43, service restore-postgres, lab postgres-restore/run4756810b5b43; host portu yok |
| Boş hedef | PSQL exit0: restore_lab database/role ve server18.6 eşleşti; tasks/history yok, public tablo sayısı0; salt okunur sorgu |
| Yükleme | Kayıtlı hedef ID/image/project/mount/ağ ve dump/manifest hash tekrar kontrolü; binary stdin,180s sınır; pg_restore --exit-on-error --single-transaction --no-owner --no-privileges --no-password |
| Restore sonucu | Exit0, outer_timeout=false,0.114s; stdout/stderr0 byte; dump hash değişmedi |

Restore hedefinin PSQL kontrolleri ve pg_restore yüklemesi kaydedilmiş hedef
container ID'sinde restore_lab database/role ile çalıştı. Kaynak volume hedefe bağlanmadı;
`--clean`, `--create`, TTY veya kaynak database'e reconnect yok. Bağlantı sorgusu
socket üzerinden hedef database/role eşleşmesini kanıtlar; yeni TCP parola
authentication testi değildir. Başlatma/restore süreleri tek komutun süresidir;
uçtan uca kurtarma süresi, RTO/SLA veya deployment kesinti süresi ölçülmedi.

### Veri, şema ve sequence sonuçları

| Kontrol | PASS kanıtı — UTC |
| --- | --- |
| Dolu veri restore | 13:54:27.572348: PSQL exit0, count1/IDs[8], tüm satır hash ve history source.before/source.after ile aynı |
| Altı alan | ID/title/description/isCompleted/createdAt/updatedAt, saklanan Windows HTTPS snapshot'ıyla eşit; description null, completion false, aware UTC zaman karşılaştırması |
| Satır SHA256 | 2ad79064002470f10e0f42391519d82308a449f4bf5bd7de8825b682aee6fe3d |
| History | Tek 20260928113912_InitialCreate; EF10.0.12; dump öncesi/sonrası/restore aynı |
| Şema | 13:55:49.327273: kaynak ve restore katalog sorguları exit0; InitialCreate ve AppDbContext beklentileriyle eşit |
| Şema kapsamı | Task'ın6 sütunu/tip/nullable/default, id identity BY DEFAULT ve PK; history tablosunun iki varchar sütunu/uzunluğu ve PK; restore tabloları restore rolüne ait |
| Yapı SHA256 | 3fbbbd404decc8ab7908aad214a3ebde5610ec61b4cb068028eeb9b3a95143bc; yalnız karşılaştırılan columns/primary_keys JSON yapısının hash'i |
| Sequence başlangıcı | 13:56:47.470084: source ve restore last_value8/is_called=true/max_id8; kaynak önceki kayıtla aynı |
| Sequence probe | 13:57:47.837576: yalnız restore database'inde id belirtilmeden INSERT; önceki max8, üretilen ID9, çakışma yok; probe PSQL exit0 |
| Probe sonrası | ROLLBACK ile probe satırı kalmadı; yalnız ID8/altı alan/full hash/history aynı. Source sequence8, restore sequence9/is_called=true; tüm önce/sonra PSQL kontrolleri exit0 |

Sequence tüketimi ROLLBACK ile geri alınmaz. Bu nedenle hedefte9, kaynakta8
kalması beklenen sonuçtur; kaynakta INSERT/nextval/setval yapılmadı. Şema
karşılaştırması source'un o andaki katalogları ve repository migration/model
beklentisiyle yapıldı; dump öncesinde ayrı bir katalog snapshot'ı alındığı
iddia edilmez. Yapı hash'i tüm database/owner/OID veya fiziksel dosya eşitliği
değildir. Restore ownership kaynak role taşınmadı, hedef role bırakıldı.

### Kaynak koruması ve saklanan kaynaklar

13:59:00.616526 UTC son Docker kontrolünde altı kaynak container'ın **tam ID ve
image kimlikleri** `inventory.json` başlangıcıyla aynı; hepsi running/healthy ve
RestartCount0. API `8b3d9f24f627...`, frontend `15a93fef4000...`, PostgreSQL
`b67a87f2d83f...`, Redis `d98d34cc73c5...`, Prometheus `84eaf1ceebb5...`, Grafana
`ed9398e62129...`; tam başlangıç kimlikleri bölüm11 tablosundadır. A image
kimlikleri aynı; kaynak PostgreSQL fullstackops-deploy-lab-postgres mount'u
/var/lib/postgresql olarak korundu. Restore hedefi de aynı ID/image ile healthy,
ayrı volume/ağda ve host portu olmadan kaldı.

14:00:06.805475 UTC son READ ONLY kontrol: kaynak count1/IDs[8], altı alan,
tam satır hash ve history hem restore.source-before hem source.after ile aynı;
source sequence8/true. VM dump3578 byte, manifest2511 byte ve sentinel snapshot223
byte boyut/SHA256/600 tekrar geçti; kök/run700, restore env600, env içeriği
okunmadı. Dump SHA256 ve manifest SHA256 bölüm12'deki değerlerdir. Bu son
grupta üç dosya yeniden hash'lendi; tüm11 dosyanın eşleşmesi önceki restore
ön kontrolünde geçti. Windows ikinci kopyası bu adımda yeniden aktarılmadı
ve yeniden ACL/hash testi yapılmadı; bölüm12'nin tarihli kanıtı korunur.

**Kullanıcının açık isteğiyle bu oturumda temizlik yapılmadı.** Gelecekte ayrı
temizlik görevi için doğrulanacak tam adlar:

| Kaynak | Korunan ad / hedef |
| --- | --- |
| Restore project | fullstackops-restore-4756810b5b43 |
| Restore container | fullstackops-restore-4756810b5b43-postgres; ID90c817d6a25b63b0507da743a0ddfa27a6b8bb6224160f4822a0a7df3c0f6e41 |
| Restore volume | fullstackops-restore-4756810b5b43-postgres; deployment volume'u değildir |
| Restore network | fullstackops-restore-4756810b5b43-net |
| Kaynak sahipli test kaydı | Deployment Task ID8; bu adımda DELETE yapılmadı |
| Kaynak geçici dump | /tmp/fullstackops-backup-4756810b5b43.pgdump; bu adımda silinmedi |

VM private run klasöründe yeni restore.plan/target/start-attempt/start-result,
apply-attempt/apply-result/snapshot/schema/sequence-before/sequence-attempt/
sequence-result/inventory-after/source-after JSON kayıtları ve özel stdout/stderr
dosyaları saklandı; dosyalar600. Tamamlanmış VM ve Windows backup setleri,
manifest/snapshot ve `.env.restore` korunuyor; Git'e eklenmedi. Orijinal manifest
değiştirilmedi: oluşturulduğu andaki stage ve restore_status=NOT VERIFIED bilgisi
tarihsel kayıt olarak kalır; yeni kabul ayrı dosyalarda ve bu bölümde raporlanır.

Bu kabul tek sahte kayıt içeren, aynı fiziksel hosttaki izole restore içindir.
Kaynak deployment'a felaket kurtarma, çok kayıtlı veri seti, global roller/PITR,
off-site kopya, düzenli timer/retention/başarısız job veya günlük RPO24h garantisi
değildir. Restore sonrası yeni API/HTTPS/browser/monitoring deneyi yapılmadı;
mevcut stack/tünellere işlem yapılmadı. Önceki Compose nginx-t exit124 ve genel
son kontrol RuntimeError nedenleri çözülmüş sayılmaz. Cleanup, zamanlama ve
deployment final kabulü açık; manuel öğrenme kullanıcı yerine PASS yapılmadı.
Yalnız dört belge güncellendi; commit/push yok.

Bu dokümantasyon güncellemesinin yerel kontrolleri: restore statik test4/4,
deployment statik test7/7, dört belgede141 yerel dosya/anchor bağlantısı,
repository secret kontrolü ve git diff --check PASS. İlk sandbox denemeleri
Windows TEMP fixture dosyalarına yazma izninde PermissionError verdi; aynı
parser testleri uygun izinle tekrar geçildi. Bu, önceki VM RuntimeError'ın
nedenini açıklamaz. Testler sahte ayarlar ve Compose parser'ı kullanır;
Engine/VM kaynaklarını başlatmaz veya silmez, runtime deneyi tekrarlanmadı.

## 14. Kontrollü temizlik ve yedek koruması — 20 Ekim 2026

Kullanıcı önceki restore kabulünü izleyen ayrı temizlik görevini istedi.
Ana repository main/76bdb2c638967dadd3206cf1103ef9453e1c5667 üzerinde önceki
dört modified belge korunarak çalışıldı. Kullanıcı PowerShell/Ubuntu SSH
komutlarını küçük gruplarla çalıştırıp sonuçları paylaştı; agent VM'ye bağlanmadı,
private dosya veya secret değeri okumadı. 19 Ekim restore/sequence deneyi ve
başarı kaydı tekrarlanmadı veya geriye dönük değiştirilmedi.

### Ön kapılar ve kaldırılan hedefler

VM hostname fullstackopslabvm, eth0 UP172.30.249.139/20; kaynak altı container ve
restore healthy, kimlikler19 Ekim kayıtlarıyla aynı. Kaynak PostgreSQL volume'u
fullstackops-deploy-lab-postgres → /var/lib/postgresql; restore mount'u farklı
fullstackops-restore-4756810b5b43-postgres → /var/lib/postgresql.
Restore project/service/lab/run etiketleri, volume restore-data anahtarı ve
ağ kimliği doğru; internal ağın tek üyesi ve volume'un tek kullanıcısı aynı
restore container'ı. Host portu yok. Bu kapılar kaldırmadan hemen önce tekrar geçti.

| Hedef | Uygulanan işlem ve kanıt |
| --- | --- |
| Kaynak Task ID8 | Windows snapshot SHA256/özel klasör ACL kapısından sonra HTTPS tekil GET200/JSON; altı alan aynı. Ardından DELETE204/boş gövde ve GET404 |
| Restore container | fullstackops-restore-4756810b5b43-postgres; tam ID90c817d6a25b63b0507da743a0ddfa27a6b8bb6224160f4822a0a7df3c0f6e41; docker stop --time 30 ve rm exit0 |
| Restore ağı | fullstackops-restore-4756810b5b43-net; tam ID07540ec9ab226b939b623b6e1b929f33f59f411746e0251ec88a98aa9edef0cd; etiketler ve boşluk tekrar kontrol edilip network rm exit0 |
| Restore volume | fullstackops-restore-4756810b5b43-postgres; etiketler ve sıfır container kullanımı tekrar kontrol edilip volume rm exit0 |
| Son yokluk | Tam restore container ID/adı, ağ adı ve volume adı artık listelerde yok; kaynak altı container ID'si ve üç deployment volume adı mevcut |

Docker işlemlerinden önce Git dışı VM klasör700/dosya600 ve orijinal dump/manifest
hash kapıları geçti; cleanup attempt/result600 kaydedildi. Genel prune,
deployment down/-v, image silme, build/pull, kaynak recreate, migration veya
sequence reset yok. Credential/env/TLS veya başka dosya silme komutu uygulanmadı.
Compose project adı bir namespace/etikettir; kaldırılan Docker kaynakları tabloda
açıkça belirtilen üç hedeftir.

Windows18443 boştu; yalnız127.0.0.1:18443 → VM127.0.0.1:18443 SSH tüneli açıldı.
Kullanıcı URL'nin sertifika uyarısız açıldığını manuel bildirdi. Curl'de -q,
noproxy, HTTPS-only, süre sınırı ve Schannel revocation best-effort kullanıldı;
verify0/loopback doğrulandı, -k/--insecure yok. İptal durumu yine NOT VERIFIED;
yeni otomatik browser/Console/asset veya tam CRUD kabulü iddia edilmez.

### Gerçek sonuç zamanları ve veri koruması

Tüm saatler20 Ekim2026 UTC'dir:

| Kontrol | Zaman ve sonuç |
| --- | --- |
| Sahipli ID8 | 15:26:40.2502233: GET200/JSON ve altı alan saklanan snapshot ile aynı; Task içeriği yazdırılmadı |
| API temizliği | 15:28:30.1881807: DELETE204/boş gövde, sonraki GET404; yalnız ID8 hedeflendi |
| Docker temizliği | 15:31:19.306181: stop/rm/network rm/volume rm exit0, üç yokluk kontrolü PASS |
| Kaynak son kontrol | 15:32:45.854736: altı kaynak tam ID/image/ref aynı, running/healthy, RestartCount0; A çifti ve PostgreSQL volume/mount korundu |
| Kaynak veri/history | READ ONLY Task count0/IDs[]/sentinel null/tüm satır hash ve tek InitialCreate/EF10.0.12 history baseline.json ile aynı |
| Boş satır SHA256 | e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855 |
| Sequence | Kaynak last_value8/is_called=true, restore sonrası source kaydıyla aynı; tüketilen ID sıfırlanmadı, pre-sentinel sequence eşitliği iddia edilmedi |
| VM yedek koruması | 15:34:00.604504: orijinal manifest+11 dosya boyut/SHA256/600 eşit; root/run700, korunan restore env ve restore/cleanup kanıtları600 |
| Windows yedek koruması | 15:35:17.6280647: manifest+11 dosya boyut/SHA256 VM ile aynı; iki klasör inheritance kapalı, sahip/Allow yalnız mevcut kullanıcı; ek karşılaştırma ve temizlik kanıtları korundu |

Kaynak başlangıcı0 Task idi; yalnız sahipli ID8'in silinmesiyle aynı veri/history
baseline'ına dönüldü. Sequence bu veri hash'ine dahil değildir; DELETE, tüketilen
ID'yi geri almaz. Başlangıçta ilgisiz Task yoktu; çok kayıtlı veri seti kabulü yok.
Sürekli ölçüm yapılmadı; Docker health/RestartCount son ölçümü kesintisiz çalışma
veya tüm zaman aralığında sıfır hata kanıtı değildir.

### Korunan yedekler ve kalan işler

VM /home/labadmin/.local/share/fullstackops-deploy-lab/backups-private/4756810b5b43/
ve Windows LOCALAPPDATA/FullStackOpsLab/backups-private/4756810b5b43/ setleri
korundu. Orijinal manifest ve11 dosya değişmedi; dump3578 byte,
SHA256 f4eeadd74cacdf90ec68024117e9d015d8008531865a3b4ad8e5556ef0fcb687.
Manifest SHA2564b29c61a0ea8022f56671f7103cdc92e106c99421820ebfee8baa61c924f38db.
Yedek/snapshot'larda ID8'in kalması beklenir; kaynak GET404 sonucuna uydurmak
için tarihsel yedek değiştirilmedi. Manifest'in oluşturulduğundaki stage/
restore_status bilgisi de korunur; yeni kabul ayrı receipt'lerdedir.

Windows'ta cleanup.ownership.get/ownership.verified/delete-attempt/delete-result/
deleted.get JSON kayıtları ve delete.body; VM'de cleanup.resources-attempt/
resources-result/source-after/backups-vm-verified JSON kayıtları saklandı.
Windows cleanup.backups-windows-verified.json, yeni kontrol receipt'idir.
Tamamlanmış yedek/manifest/snapshot ve eski restore kanıtları silinmedi;
.env.restore/credential ve TLS dosyaları korundu. Kaynak /tmp dump veya başka
geçici dosya temizliği bu adımda yapılmadı; o dosyanın yeniden hash/varlık
kontrolü bu son kontrollerin kapsamında değildi.

Bu20 Ekim hash kontrolü yeni dump veya güncel kaynak verisinin yeni ikinci
kopyası değildir;19 Ekim snapshot'ını doğrular, günlük backup başarı yaşını
yenilemez. Günlük timer/retention/failure kontrolü ve RPO24h garantisi,
deployment final kabulü, public/production/off-site ve manuel öğrenme açık.
Önceki exit124/RuntimeError nedenleri çözülmüş sayılmaz. Kaynak A/release
digestleri, altı servis, env/TLS/development korunarak stack ve HTTPS tüneli
çalışır bırakıldı. Yalnız dört belge güncellendi; commit/push yapılmadı.

20 Ekim ana repository dokümantasyon kontrolleri: dört belgede148 yerel dosya/
anchor bağlantısı, gerçek temizlik zamanları/kapsam tutarlılığı, repository
secret kontrolü ve git diff --check PASS. Uygulama/Compose/CI/test/release
dosyaları değişmedi; yerel doğrulamalar VM/Engine'e işlem yapmadı. Önceki
19 Ekim statik4/4 ve7/7 sonuçları kendi tarihli kaydında durur; bu belge
güncellemesi için uygulama build veya restore/runtime deneyi tekrarlanmadı.

20 Ekim commit öncesi incelemesinde aynı restore statik testleri4/4 ve deployment
statik testleri7/7 tekrar PASS; yalnız sahte fixture ve Compose parser kullanıldı.
Bu testler VM'ye, yedeklere veya çalışan stack/tünellere işlem yapmadı.

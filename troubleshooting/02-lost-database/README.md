# Scenario

**Troubleshooting 2 — Lost PostgreSQL Data.** Container yeniden oluşturulduktan sonra beklenen PostgreSQL verisinin görünmemesini teşhis etmek.

**Completed — şartnamenin zorunlu kapsamı mevcut deney kanıtlarıyla karşılandı (5 Ekim 2026 dokümantasyon incelemesi).** Bu görev yeni runtime deneyi değildir. Module 3A'daki olumsuz kanıt bağımsız PostgreSQL `lab_tasks` tablosuna; Module 7'deki olumlu kalıcılık kanıtı gerçek API `tasks` kaydına aittir. Birbirinin yerine sunulmazlar. Gerçek API üzerinde yanlış-volume deneyi ve veri kurtarma/backup restore kabulü yapılmış sayılmaz.

Kaynaklar:

- [Şartname](../../PROJECT_SPEC.md): bölüm 11, Troubleshooting 2 ve dokuz başlıklı senaryo şablonu.
- [Module 3A](../../labs/03-postgresql/README.md#module-3a--postgresql-container-lifecycle-ve-anonim-volume): anonim mount değişimi ve görünmeyen eski tablo.
- [Module 3B](../../labs/03-postgresql/README.md#module-3b--postgresql-named-volume-persistence): aynı named volume ile korunmuş kayıt.
- [Module 7 runtime kabulü](../../labs/07-docker-compose/README.md#11-gerçek-runtime-acceptance--30-eylül-2026): gerçek Task'ın Compose down/up sonrasında korunması.
- [Güncel Compose](../../compose.yaml), [API DB mapping](../../src/backend/FullStackOpsLab.Api/Data/AppDbContext.cs) ve [tekil GET](../../src/backend/FullStackOpsLab.Api/Program.cs): doğru veri yolu, tablo ve HTTP davranışı.

## Symptoms

Module 3A'da ilk container'da `lab_tasks` tablosu ve `1|Module 3A test task` kaydı vardı. Stop/start sonrasında aynı SELECT yine aynı kaydı döndürdü. Container kaldırılıp açık volume bağlantısı verilmeden yeniden oluşturulunca `to_regclass('public.lab_tasks')` kontrolü **absent** döndürdü.

Belirti burada boş bir SELECT sonucu değil, **tablonun yeni database'de bulunmamasıydı**. İlk anonim volume o anda hâlâ `docker volume inspect` ile görülebiliyordu. “Container silindiği anda eski veri fiziksel olarak silindi” sonucu çıkarılmaz.

API tarafındaki belirtiler ayrıca ayrılmalıdır:

| Durum | Anlamı | HTTP açısından yorum |
| --- | --- | --- |
| Farklı sunucu/database veya yeni data directory | Beklenen verinin bulunduğu yere bakılmıyor olabilir | Önce hedef ve mount doğrulanır; boş ekran tek başına veri kaybı kanıtı değildir. |
| `tasks` tablosu yok | Şema hazırlanmamış, farklı database/schema veya yanlış volume olabilir | EF sorgusu başarısız olur; mevcut API'de server error/500 beklenir. Başarılı sorgu sonrası 404 değildir. Bu yanlış-volume senaryosunda API üzerinden ayrıca ölçülmedi. |
| `tasks` mevcut, beklenen ID yok | Sorgu çalıştı fakat o kayıt bulunamadı | Mevcut tekil GET mapping'i **404** döndürür; bu tek başına volume hatası kanıtı değildir. Kayıt silinmiş veya ID yanlış olabilir. |
| `tasks` mevcut ve beklenen kayıt var | Veri okunabiliyor | Tekil GET **200**; alanlar önceki kayıtla karşılaştırılır. |

Liste endpoint'i Redis cache kullandığından liste sonucunu tek başına DB kanıtı sayma. SQL veya DB'ye doğrudan giden tekil GET tercih edilir; bu incelemede cache'e dokunulmadı.

## Expected Behaviour

Container kimliği değişse bile PostgreSQL aynı data directory'yi kullanırsa verisi korunmalıdır. Bu projede güncel bağlantı service hedefi `postgres:5432`, mount hedefi **`/var/lib/postgresql`**, gerçek volume adı **`fullstack-ops-postgres-data`**'dır. Compose anahtarı `postgres-data`, fiziksel Docker volume adıyla aynı şey değildir; `external: true` ve açık `name` gerçek volume'u seçer.

Module 3 deneyindeki `postgres:18-alpine` image'ında `PGDATA=/var/lib/postgresql/18/docker`, image `VOLUME` hedefi `/var/lib/postgresql` idi. Dolayısıyla açık `-v`/`--mount` vermemek **hiç volume olmadığı** anlamına gelmedi: Docker anonim volume oluşturdu. Aynı container stop/start'ta aynı mount'u kullandı; ayrı yeniden oluşturma farklı anonim volume aldı.

Doğru çözüm aynı named volume'u doğru veri yoluna açıkça bağlamaktır. Named volume yedekleme veya silinmeye karşı mutlak güvence değildir.

## Investigation

Teşhis sırası:

1. **Doğru PostgreSQL sunucusu ve database mi?** API'nin güvenli hedef bilgilerini (`postgres:5432`) kaynak configuration ile karşılaştır. SQL oturumunda database, server adresi/portu ve schema arama yolunu kontrol et. SQL'i PostgreSQL container'ında çalıştırmak tek başına API'nin aynı database'i seçtiğini kanıtlamaz; ikisini eşleştir. Tam connection string veya container environment'ını paylaşma.
2. **Container `Mounts` bilgisi ne?** Yalnız Type/Name/Source/Destination/RW alanlarını incele. Container adının aynı olması aynı data directory anlamına gelmez.
3. **Önceki volume adı ve mount hedefiyle eşleşiyor mu?** Önceki kayıtlı inspect kanıtıyla karşılaştır. Yeni, boş veya farklı bir volume bağlandıysa eski veri otomatik taşınmaz. Eski volume hâlâ var mı sorusu ayrıca araştırılır; varlığı veri bütünlüğü/kurtarılabilirliği kanıtlamaz.
4. **Beklenen tablo ve migration history var mı?** `public.tasks`, `public.lab_tasks` ve `public."__EFMigrationsHistory"` varlıklarını ayrı kontrol et. `lab_tasks`, Module 3 lab tablosudur; API onu kullanmaz. Migration history varsa beklenen InitialCreate kaydını incele. History kaydı tek başına tablo/veri bütünlüğünün garantisi değildir.
5. **Tablo varsa beklenen kayıt var mı?** Daha önce kaydedilen gerçek ID/alanlarla SELECT veya tekil GET yap. Önce tablo yokken SELECT çalıştırıp hatayı “0 kayıt” olarak yorumlama. Geçmiş Module 7 test ID'si son temizlikte silindi; bugün bulunmasını bekleme.

Yeni/boş database teşhisi tek eksik tabloya dayanmaz: sunucu/database kimliği, mount değişimi, tablo/history durumu birlikte değerlendirilir. Doğru database'de eksik migration da tablo yokluğu yaratabilir. Migration yalnız şemayı oluşturur; kaybolan Task kayıtlarını geri getirmez. `/health`/liveness veya readiness `SELECT 1` başarısı da `tasks` şemasını ve kayıtlarını tek başına kanıtlamaz.

## Useful Commands

Aşağıdakiler **çalışan bir stack için salt okunur tanı örnekleridir; bu görevde çalıştırılmadı**. Stack başlatmaz, migration uygulamaz veya volume'u yeniden bağlamazlar. Native exit code'ları kontrol et; başarısız SQL'i boş sonuç sayma.

```powershell
docker compose --env-file .env ps -a
$postgresId = docker compose --env-file .env ps -a -q postgres
docker inspect --format '{{json .Mounts}}' $postgresId
docker volume inspect fullstack-ops-postgres-data --format '{{.Name}}|{{.Driver}}'
docker compose --env-file .env exec -T postgres sh -c 'exec psql -X -U "$POSTGRES_USER" -d "$POSTGRES_DB" -v ON_ERROR_STOP=1'
```

Son komutun açtığı psql oturumunda yalnız okumalar:

```sql
SELECT current_database(), inet_server_addr(), inet_server_port();
SHOW search_path;
SELECT to_regclass('public.tasks'),
       to_regclass('public.lab_tasks'),
       to_regclass('public."__EFMigrationsHistory"');
```

`__EFMigrationsHistory` mevcutsa:

```sql
SELECT "MigrationId" FROM public."__EFMigrationsHistory" ORDER BY "MigrationId";
```

`tasks` mevcutsa, `beklenen_id` yerine **incelediğin kaydın önceden bilinen ID'sini** psql `\set` ile belirle:

```sql
SELECT EXISTS (SELECT 1 FROM public.tasks WHERE id = :beklenen_id);
```

İlgili kayıt için gerekirse tekil HTTP GET kullan; yanıtı ve SQL sonucunu güvenli şekilde karşılaştır. `inet_server_addr()` Unix socket bağlantısında NULL olabilir; bunu yanlış sunucu kanıtı sayma. Gösterilen `$POSTGRES_USER`/`$POSTGRES_DB` container içindeki environment referanslarıdır; parolayı komut argümanına yazma. Raw inspect, çözümlenmiş Compose config veya application exception çıktıları credential içerebilir; bunları paylaşmadan önce güvenli alanlara sınırla. Bu belge credential veya tamamlanmış connection string içermez.

## Root Cause

Şartname problemi “volume olmadan” diye özetler. Mevcut resmî image ile gözlenen gerçek mekanizma **kalıcı veri volume'unun sonraki container'a yeniden bağlanmaması**dır:

- Module 3A ilk mount: `ba7406c834c78c674038758f166b1ecb7233fc8171e018ac507563740a3b4509`.
- Module 3A yeni mount: `ea7f584ad2074b9061d7c8e64ede01ba9e94bd8a99a724dcb9d3ed4e230ad5db`.
- İki mount'un hedefi `/var/lib/postgresql`, Type değeri `volume` idi; adları farklıydı. Yeni container eski anonim volume'u otomatik yeniden kullanmadı.

Container writable layer'ının container yaşam süresine bağlı olması genel öğrenme noktasıdır; bu deneyde PostgreSQL dosyalarının writable layer'da olduğu iddia edilmez. Eski data volume'unun varlığı ile yeni container'ın onu kullanması ayrı şeylerdir.

## Fix

**Kalıcılık düzeltmesi:** Container yeniden oluşturulurken aynı named volume'u aynı veri yoluna bağla. Güncel Compose bunu zaten yapıyor; bu görevde ana configuration değiştirilmedi. Yanlışlıkla başka sunucu/database seçilmişse önce hedefi düzelt. Şema eksikse önce nedenini araştır; migration uygulanması eski kayıtları kurtarmaz.

| İşlem | Ne yapar? | Mevcut kanıt |
| --- | --- | --- |
| Aynı named volume'u tekrar bağlamak | Aynı PostgreSQL data directory'yi yeniden kullanır; dosyaları başka yere kopyalamaz | **PASS:** Module 3B ve Module 7. |
| Eski anonim/farklı volume'dan veriye yeniden erişmek veya onu başka volume'a taşımak | Eski kaynağın doğrulanmasını, uyumlu PostgreSQL ve ayrı bir erişim/taşıma planını gerektirir | **NOT VERIFIED:** Eski anonim volume yeniden bağlanıp SELECT yapılmadı; taşıma denenmedi. |
| Yedekten restore etmek | Önceden alınmış bir yedeği ayrı hedefe geri yükler; aynı volume'u bağlamaktan farklıdır | **NOT VERIFIED:** Backup/restore deneyi yapılmadı. |

Sırf container adı aynı diye yeni volume'u güvenli kabul etme. Eski veri kaynağını teşhis sırasında silme; iki PostgreSQL prosesi aynı data directory'yi eşzamanlı kullanmamalıdır. Çalışan PostgreSQL dosyalarını körlemesine kopyalamak burada önerilen çözüm değildir. Initialized volume'da environment parolasını değiştirmek rol parolasını değiştirmez; bu senaryo credential rotation istemez.

Normal Compose `down` external PostgreSQL volume'unu korur. `down -v` de bu external volume'u silmez, ancak Compose-managed başka volume'ları silebilir; genel temizlik talimatı olarak kullanılmaz. Bu görevde down, remove, prune veya herhangi bir Docker işlemi yapılmadı.

## Verification

**Kabul kararı:** Zorunlu senaryo kapsamı mevcut gerçek kanıtlarla karşılandı. Şartname ayrı bir yanlış-volume API smoke testi veya veri kurtarma/backup restore testi istemiyor. Bu yüzden aşağıdaki ek sınırlar zorunlu PASS satırlarının yerine kullanılmaz ve yeni runtime deneyine kapsam genişletilmez.

| Kriter | Sonuç | Somut kanıt / sınır |
| --- | --- | --- |
| Ayrı senaryo klasörü, dokuz standart başlık | PASS | Bu belge şartnamedeki şablonu kullanır. |
| Container kaldırılıp yeniden oluşturulduğunda beklenen veri görünmüyor | PASS — Module 3A | İlk SELECT `1\|Module 3A test task`; stop/start aynı sonuç. Remove/recreate farklı mount adı ve `lab_tasks` için absent. Bu, API `tasks` deneyi değildir. |
| Kök neden: container adı veri kalıcılığı sağlamaz; mount yeniden kullanımı gerekir | PASS — Module 3A | Eski anonim volume hâlâ mevcuttu, yeni container farklı volume aldı. Fiziksel silinme iddiası yok. |
| Çözüm: aynı named volume'u tekrar bağlamak | PASS — Module 3B | Container ID'leri değişti; mount adı `fullstack-ops-postgres-data`, hedef `/var/lib/postgresql` aynı kaldı; ikinci SELECT `1\|Module 3B persistent task`. |
| Gerçek API Task'ının yeniden oluşturma sonrasında kalıcılığı | PASS — Module 7 | POST201 ile oluşturulan görev down/up sonrasında aynı ID/alanlarla bulundu. External volume kaldı; test görevi sonradan DELETE204 ile temizlendi. |
| Güncel kalıcılık configuration'ı | PASS — statik inceleme | `compose.yaml` external volume adı ve doğru mount hedefini koruyor; bu görevde runtime mount tekrar okunmadı. |
| Şema yokluğu ile kayıt yokluğu ayrımı | PASS — source/dokümantasyon incelemesi | AppDbContext `tasks` mapping'i; tekil GET başarılı null sonuçta 404 döndürür. Yeni yanlış-volume senaryosunun API 500/404 akışı burada çalıştırılmadı. |
| Gerçek API üzerinde yanlış-volume negatif deneyi | NOT VERIFIED — ek kapsam | Module 3A SQL lab tablosudur; Module 7 aynı-volume olumlu API deneyidir. Birleşimleri ayrı bir negatif API çalışması gibi sunulmaz. |
| Eski anonim volume'u yeniden bağlayarak kurtarma / farklı volume'a taşıma | NOT VERIFIED — ek kapsam | Eski volume varlığı kaydedildi; ardından Module 3A cleanup'ta iki lab volume'u silindi. Bunlar bugün kurtarma hedefi olarak kullanılamaz. |
| Backup/restore ve kurtarılabilirlik garantisi | NOT VERIFIED — ek kapsam | Named volume kanıtı backup/restore yerine geçmez. |

Zorunlu runtime kanıtı eksik bulunmadı; yeni izole deney planı bu kabulün ön koşulu değildir. İleride özellikle negatif API kanıtı istenirse ayrı proje, yeni test volume'ları ve sahte credential ile; mevcut migration'ın açık hazırlanması, tekil DB GET, yeni mount'ta şema yokluğu, migration sonrası kayıt yokluğu ve yalnız sahip olunan kaynakların temizliği değerlendirilebilir. Bu görevde böyle bir ortam hazırlanmadı; development volume'una bağlanılmadı.

İnceleme başlangıcında Git `main...origin/main` temizdi. Mevcut dosyalar okundu; Docker, psql veya migration komutu yürütülmedi. Yeni container/volume/network/cache kaydı veya geçici secret dosyası oluşturulmadı. `.env`, user-secrets ve development database okunmadı/değiştirilmedi. Dokümantasyon bağlantıları, repository secret kontrolü ve Git diff kontrolü bu görevde ayrıca doğrulanır; geçmiş deneyler yeniden çalıştırılmış sayılmaz.

## What We Learned

- “Veri görünmüyor” ile “veri fiziksel olarak silindi” aynı teşhis değildir.
- Container adından önce doğru database ve gerçek mount kimliği kontrol edilir.
- Anonim volume da container'dan ayrı olabilir; yeniden bağlama yönetilmezse yeni container eski veriyi görmez.
- Aynı named volume'u aynı hedefe bağlamak kalıcılıktır; taşıma veya backup restore değildir.
- Eksik tablo bir SQL hatasıdır; mevcut tabloda bulunmayan ID başarılı sorgu sonrası 404 olabilir.
- Şema/migration ve veri kayıtları ayrı kanıtlardır; migration eski Task'ları geri getirmez.
- Bu kabul mevcut deneylere dayanır. İleri kurtarma ve negatif API testlerini yapılmış gibi anlatmadan senaryoyu tamamlamak mümkündür.

Sonraki küçük öneri yalnız bu senaryonun dokümantasyonunu commit öncesinde incelemektir. Üçüncü troubleshooting senaryosuna geçilmedi; commit/push yapılmadı.

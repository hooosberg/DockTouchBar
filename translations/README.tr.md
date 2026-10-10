<p align="center">
  <img src="../assets/icon-256.png" alt="DockTouchBar" width="128" height="128">
</p>

<h1 align="center">DockTouchBar</h1>

<p align="center">
  <strong>Touch Bar'ınızdaki Dock.</strong>
  <br>
  <strong>Basit · Zarif · Verimli</strong>
  <br>
  Dokunarak geçin · çift dokunarak küçültün · uzun basarak çıkın
  <br>
  <a href="https://github.com/hooosberg/DockTouchBar/releases/latest">İndir</a> ·
  <a href="https://hooosberg.com/apps/docktouchbar">Ürün sayfası</a> ·
  <a href="https://hooosberg.com/apps/docktouchbar/diary">Derleme günlüğü</a>
</p>

<p align="center">
  <a href="../README.md">English</a> ·
  <a href="README.zh-CN.md">简体中文</a> ·
  <a href="README.zh-Hant.md">繁體中文</a> ·
  <a href="README.ja.md">日本語</a> ·
  <a href="README.ko.md">한국어</a> ·
  <a href="README.fr.md">Français</a> ·
  <a href="README.de.md">Deutsch</a> ·
  <a href="README.es.md">Español</a> ·
  <a href="README.pt.md">Português</a> ·
  <a href="README.ru.md">Русский</a> ·
  <a href="README.it.md">Italiano</a> ·
  <a href="README.tr.md">Türkçe</a>
</p>

> **Tek uygulama:** DockTouchBar, yapay zekâ kodlama ajanlarınızın durumunu simgelerin üzerinde canlı gösterir (Ayarlar'dan kapatılabilir). Eski «DockTouchBar Vibe» bu uygulamaya dahil edildi. Ayrıntılar ve indirme: [English README](../README.md#one-app).

<p align="center">
  <img src="https://img.shields.io/badge/macOS-13%2B-444.svg" alt="macOS 13+">
  <img src="https://img.shields.io/badge/Apple%20silicon-tested-2e7d32.svg" alt="Apple silicon: tested">
  <img src="https://img.shields.io/badge/Intel-untested-f9a825.svg" alt="Intel: untested">
  <img src="https://img.shields.io/badge/Swift-AppKit-F05138.svg" alt="Swift + AppKit">
  <img src="https://img.shields.io/badge/license-PolyForm%20Noncommercial-1e88e5.svg" alt="PolyForm Noncommercial">
</p>

![Touch Bar'da DockTouchBar](../assets/touchbar-idle.gif)
*Boş durumu: uygulamalar altta hizalanmış, sağ üstte etkin rozet noktası (ön plandaki uygulama için kırmızı); canlı yükselen buharı olan piksel sanatı kahve fincanı.*

![Uzun basarak çıkma: dört mevsim animasyonu](../assets/touchbar-seasons.gif)
*Uzun basarak çıkma: yan kaydırmalı piksel sanatı geri sayım sahneleri dört mevsim içinde (bahar koşan köpek / yaz yelken gemi / sonbahar orman tilkisi / kış kızak turu). Erken bırakarak iptal edin, mevsimsel finale patlaması ile.*

### ⚡ Enerji ve Yerel Performans (Önceki Sürüm Ölçümleri)

24/7 arka plan kalması için olay tabanlı uygulama ve pencere güncellemeleri kullanılarak tasarlandı. Aşağıdaki ölçümler önceki sürümlerdendir; ekran görüntüsü aktivitesi geçici olarak kısa bir işlem kontrolü kullanır:

| Metrik | Ölçülen | Notlar |
|---|---|---|
| **CPU Kullanımı** | **0,0% ~ 0,8%** | Boş 0,0%; uygulama/pencere geçiş olaylarında yalnızca kısa ihmal edilebilir artışlar |
| **Fiziksel Alan Ayaklanı** | **29 MB** | macOS `footprint` aracı ile ölçülen, Electron alternatifleri kadar az |
| **Enerji Etkisi** | **0,0** | En düşük olası macOS Etkinlik İzleyicisi enerji derecelendirmesi, pil üzerinde sıfır etki |
| **Sakin İş Parçacıkları** | **4 iş parçacığı (tümü olaylarda uyuyan)** | Sıfır meşgul bekleme, yüksek frekansı zamanlayıcı yoklaması yok |
| **Ağ erişimi** | **GitHub güncellemeleri kontrolleri ve indirmeleri** | Dock etkileşimleri yerel olarak çalışır; analitik veya hesap yok |
| **İşleme Gecikmesi** | **~2,3 ms / kare** | Anında dokunma tepkisi için yerel CoreAnimation / AppKit işleme ardışık düzeni |

**DockTouchBar size yararlı olduysa, GitHub'da bir ⭐ Yıldız en iyi teşekkür yoludur.**

## Neden

Pock, PockV2 ve benzerleri Dock'u Touch Bar'a koyabilir, ancak çok daha fazlasını yaparlar ve günlük kullanımda çubuk kaybolma veya yanıt vermeme eğilimi gösterir. DockTouchBar bir işte ustalaşır ve onu iyi yapar.

**Basit**

- Bir iş: Touch Bar'ınızda Dock. Pencere öğesi yok, eklenti yok.
- Menü çubuğunda bir avuç anahtar, yapılandırılacak başka bir şey yok.
- Üçüncü taraf bağımlılıkları olmadan yerel Swift ve AppKit. Piksel sanatı sahneleri kaynağa dahil edilmiştir.

**Zarif**

- macOS simgelerini ve sistem Touch Bar kaydırıcısını kullanır. Sabitlenmemiş çalışan uygulamalar solda görünür, en yeniler önce; sabitlenmiş uygulamalar Dock sırasını korur. Bir uygulamayı kapatmak mevcut görünür alanı tutar.
- Yolunuzun dışında duran hareketler: bir dokunuş hemen işler (çift dokunuşun gelip gelmediğini görmek için asla beklemez) ve uzun basma simgenin altında sessiz bir ilerleme çubuğu gösterir, artı Touch Bar'ın sağ kenarında parmağınız asla gizlemez şekilde çizilen "Kapatılıyor ..." geri sayımı, küçük bir piksel sanatı sahnesi olarak dört mevsim arasında geçiş yapabilirsiniz. Erken bırakarak iptal edin.
- Hızlı dokunuşlar doğru hissettirilebilir: son dokunuş her zaman kazanır ve asla sizinle savaşmaz. Sistem bir masaüstü anahtarını düşürürse veya bir şey odağı çalarsa, sessizce işleri düzeltir ve klavye, fare veya trackpad'e dokunmaya başladığın anda durur.
- Dilinizi konuşur (12 dil, İngilizce'den 简体中文 ve 日本語'ye kadar) ve sadece bir isteğe bağlı izin ister.

**Verimli**

- Olay tabanlı uygulama ve pencere güncellemeleri. Dock gösteriliyor ve boş olan bir M1 MacBook Pro'da daha önceki ölçümler: **0,0% CPU**, **0 boş uyandırmalar**, yaklaşık **32 MB** bellek.\*
- Mac'inize uyum sağlar, sabit gecikmeler kullanmak yerine: masaüstü anahtarları sistemin kendi "tamamlandı" sinyalini bekler ve sonucu kontrol eder, böylece animasyonlar yavaş, kapalı veya makine meşgul olsa da doğru kalır.
- Uygulamalar başladığında veya çıktığında, yalnızca değişen güncellenir ve kaydırma konumunuz tutulur. Simgeler bir kez rasterleştirilir ve önbelleğe alınır.
- Kendi kendini onarma: uyku, ekran kilidini açma ve Kontrol Şeridi yeniden başlatmalarından sonra yeniden bağlanır, böylece asla yeniden başlatmanız gerekmez.
- Güvenli başarısız olur: özel API'ler çalışma zamanında çözülür. macOS bir taneyi kaldırırsa, bu özellik kilitlenmek yerine kendini kapatır.
- Gizlilik: analitik veya hesap yok. Dock etkileşimleri yerel olarak çalışır; otomatik güncelleme kontrolleri ve istenen indirmeler GitHub'a bağlanır. Tercihler Mac'inizde kalır.

<sub>\* Sürüm derlemesi. CPU, 2 s arayla beş `top` örneğinden (tümü 0,0%); uyandırmalar, çekirdek başına işlem sayaçlarından 20 s arayla okunur, 1.10'da üç kez (0 boş uyandırmalar ve 0 kesme uyandırmaları her zaman; 1.8'de önceki çalıştırma 0-7 kesme uyandırması gördü, sistem olaylarından); bellek, `footprint`'ten fiziksel ayaklanmadır (32 MB). Kahve fincanının üzerindeki buhar sistem işleme işlemi tarafından çizilir, uygulama tarafından değil.</sub>

## Özellikler

| Hareket | Ne olur |
|---|---|
| Bir simgeye **dokunun** | Uygulamaya geçin veya başlatın. Pencereleri başka bir masaüstüde (Alan) ise o masaüstüne atla |
| **Çift dokunun** | Mevcut pencereyi küçültün, sarı düğmesi gibi. Erişilebilirlik iznine ihtiyaç duyar. Geri yüklemek için tekrar dokunun |
| **Uzun basın** | Uygulamayı kapatın ve her zaman ne olduğunu söyleyin. Tutarken simgenin altında bir ilerleme çubuğu dolar ve sağ kenarında "Kapatılıyor ..." geri sayımı bir piksel sanatı mevsimi üzerinde (menüde seçiminiz) gösterilir; erken bırakarsanız bir dokunuş olarak sayılır. Uygulama her zaman tamamen çıkış yapılır (⌘Q ile aynı), pencereleri sayısından veya küçültülmüş ya da gizlenmiş olup olmadığından bağımsız olarak. Finder kapatılamaz, bu nedenle tüm pencereleri kapatılır (küçültülmüş olanlar da; başka bir masaüstüde ise ilk olarak oraya atlar). Uygulama kapatılamıyorsa çünkü sizi bekliyorsa ("kaydedilmemiş değişiklikler" sayfası) veya kapatmıyorsa, Touch Bar buna masaüstü genelinde geçer ve söyler |
| **Çöp Sepeti** | Dokunarak Çöp Sepeti penceresini Finder'da açın; çift dokunarak küçültün; uzun basarak kapatın. Pencere kapalı olsa bu karartılır (ve "yalnızca çalışan uygulamaları göster" modunda kaybolur) |
| **Kaydır** | Simgeler hepsi sığmadığında kaydırın; bir uygulamayı kapatmak mevcut alanı görüşte tutar |
| **Kahve fincanı** (sağ uç, canlı yükselen buharı ile) | Mola verin: Dock'u bir an gizleyin ve Touch Bar'ı sistem (parlaklık, ses) geri edin. 10-60 s sonra kendi kendine döner |
| **Merkez / maksimize et düğmesi** (en sağ) | Ön plandaki uygulamanın penceresini ortalayın; tekrar maksimize etmek için dokunun (kullanılabilir alanı doldurur, yerel tam ekran değil) ve tekrar ortalamak için. Pencereyi kendiniz hareket ettirdiyseniz veya uygulamaları değiştirdiyseniz, ilk olarak merkezler ve simge pencerenin mevcut durumunu takip eder. Erişilebilirlik iznine ihtiyaç duyar |

Menü çubuğu menüsü günlük anahtarları tutar: Touch Bar'da Dock'u göster, Yalnızca çalışan uygulamaları göster (varsayılan olarak kapalı: sabitlenmiş uygulamalar da gösterilir; solmuş uygulamalar, Finder penceresiz ve kapalı Çöp Sepeti de dahil olmak üzere gizli ve Finder en solda oturur), Simgeleri ortalayın (sığdığında; bir kere taştığında soldan başlar ve kaydırılır), Merkez / maksimize et düğmesini göster ve Girişte Başlat. **Ayarlar...** ayarlar penceresini açar, üç sayfaya sahip:

- **Ayarlar** — simge aralığı; kahve fincanına dokunduktan sonra gizleme süresi (10 / 20 / 30 / 60 s); ortalanmış pencerenin boyutu (ekran yüksekliğinin 60-100%; genişlik yükseklikle aynı veya ekran genişliğinin 50-100%); çift dokunarak küçültme; uzun basarak kapatma (Kapalı / 1 / 2 / 3 / 5 s) ve stilini (Bahar / Yaz / Sonbahar / Kış, Touch Bar'da kısa bir önizleme ile); sistem Touch Bar kontrollerine verim verme (bağımsız ekran görüntüsü / kayıt ve Fn anahtarları, varsayılan olarak açık); dil (Sistemi Takip Et veya 12 dilden biri — Ayarlar sayfasının başında gösterilir; bu aynı zamanda Touch Bar'ın uzun basma mesajlarını çevirir); Erişilebilirlik izni durumu Sistem Ayarları'na bir kısayol ile (başka hiçbir şey izin gerektirmez); ve "neden Dock'u göremiyorum?" tanısı
- **Nasıl kullanılır** — hareketler ve düğmeler
- **Hakkında** — sürüm, güncelleme kontrolü, ürün sayfası ve derleme günlüğü bağlantıları, Yıldız düğmesi

Uygulamanın Dock'ta da bir simgesi vardır, bu nedenle yükledikten sonra oradan başlatabilirsiniz.

Çalışırken Uygulamalar'dan uygulamayı tekrar açmak menüyü açar.

## Gereksinimler ve test edilen ortam

| | |
|---|---|
| Donanım | Touch Bar'lı bir Mac (MacBook Pro 2016–2022) |
| **Test edildi** | **MacBook Pro 13" (M1, `MacBookPro17,1`), macOS 27.0, tek ekran, 3 Alan, Touch Bar "Genişletilmiş Kontrol Şeridi" olarak ayarlanmış, Sahne Yöneticisi açık** |
| Apple silikon (M1) | ✅ Geliştirilen ve kullanılan makinedir |
| Intel | ⚠️ **Bilinmiyor.** İndirme evrensel bir ikilidir ve Intel dilimi bir M1 Mac'te Rosetta altında başlar, ancak gerçek bir Intel Touch Bar Mac'te asla çalışmamıştır. Raporlar açık |
| macOS sürümü | Minimum macOS 13 ile oluşturulmuş, ancak yalnızca macOS 27.0'da test edilmiştir. Eski sürümler test edilmemiştir |

Bilmeniz gerekenler:

- **Özel Apple API'lerini** kullanır, bir arka plan uygulamasından ekranda Touch Bar tutmak için. Bu aynı zamanda neden Mac App Store'da olamayacağı ve gelecek macOS güncellemesi neden bunu bozabileceği nedenidir. Özel arayüzler çalışma zamanında çözülür, bu nedenle biri kaybolursa bu özellik kilitlenmek yerine kendini kapatır; `swift tools/probe-private-api.swift` macOS'unuzun hâlâ hangilerinin olduğunu gösterir.
- Dock, **bütün** Touch Bar'ı alır, bu nedenle sistem Kontrol Şeridi (parlaklık, ses) açık olsa gizlenir. Touch Bar'ın sağındaki küçük kahve fincanına dokunarak Dock'u bir an gizleyin ve Touch Bar'ı sistem geri edin (10-60 saniye sonra kendi kendine döner, varsayılan olarak 20 — veya ekran tüm şekilde indirilirse, parlaklık yükseltilir yükseltilirse hemen). "Touch Bar'da Dock'u göster" seçeneğinin işaretini kaldırabilirsiniz.
- Soldan sağa sıra: sabitlenmemiş çalışan uygulamalar (en yeniler önce) → ayırıcı → Finder → Dock sırasında sabitlenmiş uygulamalar → ayırıcı → Çöp Sepeti. Yeni başlatılan sabitlenmemiş uygulamalar solda görüş alanına girler; açık uygulamalar arasında geçiş sırasını değiştirmez. Çöp Sepeti'ne dokunarak Finder'da açın.
- Sahne Yöneticisi açık iken, macOS pencere değişikliğini canlandırır, bu nedenle pencere ekranda görünmek için yaklaşık yarım saniye alabilir. Dokunulan uygulama yaklaşık 40 ms içinde ön plandaki uygulama olur; geri kalan sistem animasyonudur.

## Yükle

1. [Sürümler](https://github.com/hooosberg/DockTouchBar/releases/latest)'den `DockTouchBar-<version>.dmg` indirin.
2. Açın ve **DockTouchBar**'ı **Uygulamalar**'a sürükleyin, sonra başlatın. Menü çubuğunda ve Touch Bar'da bir Dock simgesi görünür.

> DMG, bir Developer ID sertifikası ile imzalanmıştır ve **Apple tarafından onaylanmıştır**, bu nedenle diğer herhangi bir uygulama gibi açılır. macOS yalnızca ilk başlatışta onaylamanızı ister. Kendiniz derlemesi tercih misiniz? Bkz. [Kaynaktan Derle](#kaynaktan-derle).

### Erişilebilirlik izni (isteğe bağlı)

Erişilebilirlik, masaüstü genelinde pencere geçiş, çift dokunarak küçültme, merkez / maksimize, Finder pencereleri kapatma, onay iletişim kutularını algılama ve Fn verimini sağlar. Olmadan, temel başlatma ve etkinleştirme kalır; bu özellikler sınırlıdır.

1. Menü çubuğu simgesi → **Ayarlar...** → **İzinler** → **Aç...** (verildikten sonra **Erişilebilirlik: açık** olarak okunur)
2. Sistem Ayarları → Gizlilik ve Güvenlik → Erişilebilirlik'te DockTouchBar açın.

Açtıktan sonra hâlâ soruyorsa, eski giriş bayattır (bu uygulama imzası değiştiğinde olur): listede DockTouchBar seçin, **−** tıklayın, sonra tekrar ekleyin. Veya `tccutil reset Accessibility com.maohuhu.docktouchbar` çalıştırın ve adım 1'i tekrarlayın.

### Bir dokunuş masaüstünü değiştiremezse

Hemen sonra, repo'nun klonundan buradan çalıştırın. Yalnızca okunurdur ve uygulamanın bu uygulamanın pencereleri nasıl yargıladığını yazdırır (hangi pencereler var, her birine hangi masaüstü, gerçek pencereler hangisi, hangisi yükselirse):

```bash
tools/diagnose-switch.sh com.google.Chrome
```

## Dock'u Göremiyorum mi?

En yaygın sebep: Sistem Ayarları → Klavye → "Touch Bar Gösterir", "F1, F2, vb. tuşlar" olarak ayarlanmıştır, tüm Touch Bar'ı işlev tuşlarıyla doldurur. 1.16'dan beri uygulama bunu algılar ve ilk başlatışta bunu "Genişletilmiş Kontrol Şeridi"ne değiştirmeyi önerir. Ayrıca menü çubuğu menüsünde "Tanı: neden Dock'u göremiyorum?" tıklayarak her olası nedeni kontrol edebilir ve geri bildirim için bir rapor kopyalayabilirsiniz. Fn tutmak sonra F1-F12 gösterir.

## Kaynaktan Derle

Xcode komut satırı araçlarını gerektirir.

```bash
git clone https://github.com/hooosberg/DockTouchBar.git
cd DockTouchBar
scripts/install.sh      # derle → /Applications'a kopyala → başlat
scripts/make-dmg.sh     # build/DockTouchBar-<version>.dmg
```

Bir imza sertifikası olmadan derleme ad hoc imzalamaya geri döner. Bu işe yarar, ancak macOS her ad hoc yeniden derleyişi yeni bir uygulama olarak kabul eder, bu nedenle her seferinde Erişilebilirlik'i yeniden vermeniz gerekir. `SIGN_IDENTITY="Apple Development: …"` ayarlayın (veya bir Developer ID sertifikası) bir sabit kimliği tutmak için.

## Proje Düzeni

```
Sources/DockTouchBar/   Uygulama kaynağı
Resources/              Info.plist, uygulama simgesi
scripts/                build.sh, install.sh, make-dmg.sh, make-icon.sh
tools/                  Tanılar: özel API kontrolü, Alanlar/pencereler inspektörü, geçiş tanısı, hızlı tıklama stres testi, ekran dışı önizleme ve render-seasons.sh (README ekran görüntüleri)
assets/                 README resimleri
```

Büyük bir macOS güncellemesinden sonra, `swift tools/probe-private-api.swift` çalıştırarak hangi özel API'lerin hâlâ kullanılabilir olduğunu görün.

## Lisans

[PolyForm Noncommercial License 1.0.0](../LICENSE) — **kişisel ve diğer ticari olmayan amaçlar** için ücretsiz olarak kullan, kopyala, değiştir ve paylaş. **Ticari kullanım kapsanmamıştır** ve yazardan ayrı bir lisans gerekir; lütfen [hooosberg.com](https://hooosberg.com/) aracılığıyla iletişime geçin.

Bu, OSI tarafından onaylanan açık kaynak lisansı değil, kaynak-kullanılabilir bir lisanstır. Gerekli bildiri: Telif Hakkı © 2026 hooosberg.

## Yazar

**hooosberg** tarafından yapılmış — [hooosberg.com](https://hooosberg.com/) · [GitHub](https://github.com/hooosberg). Size bu kadar dokunuş tasarrufu sağladıysa, lütfen repo'yu ⭐ yapın.

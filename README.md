# Kaan Kırşan — Portfolyo

Canlı site: **https://kaankirsan.github.io** · Sanal fabrika: **https://kaankirsan.github.io/fabrika/** (ayrı depo: `kaankirsan/fabrika`)

Elektrik Elektronik Mühendisi portfolyosu: endüstriyel otomasyon, robotik ve test sistemleri projeleri; her projeden
sanal fabrikadaki 3B modeline (`/fabrika/?m=<makine>`) geçiş.

## Yapı

```
index.html            Tek sayfa: şablon (<x-dc>) + bileşen mantığı (<script type="text/x-dc">)
                      - PROJECTS: kart listesi (başlık, kategori, kart görseli)
                      - FABRIKA_MAKINELER: sanal fabrikadaki makine kimlikleri
project-details.js    window.PROJECT_DETAILS: proje detay sayfaları (#/p/<slug>)
                      - fabrika: [{ id, ad }]  -> "Sanal fabrikada gez" düğmesi (?m=id)
                      - makineler: [...]        -> Diğer Makineler kataloğu
                      - sim: {...}              -> canlı demo / simülasyon bağlantıları
support.js            Şablon çalışma zamanı (üretilmiş dosya, elle düzenlenmez)
assets/vendor/        React (yerel kopya; CDN'e bağımlı değil)
assets/fonts/         Space Grotesk, IBM Plex Mono (yerel)
assets/*.pdf          CV: Kaan_Kırşan_Detailed_CV.pdf (TR, eski bağlantılar için ad korunur), Kaan_Kirsan_CV_EN.pdf
images/projects/      Orijinal proje fotoğrafları ve videoları
images/web/           Web sürümleri: <ad>-800.webp, <ad>-1600.webp, <ad>-web.mp4 (sayfa bunları yükler)
images/fabrika/       Sanal fabrika ekran görüntüleri ve hero videosu
404.html              Eski /projects/<slug>.html adreslerini #/p/<slug>'a yönlendirir
service-worker.js     Eski önbellek service worker'ını temizleyip kendini kaldıran "kill switch"
tools/optimize-media.py  images/web/ sürümlerini üretir
```

## Yeni görsel / video eklerken

1. Dosyayı `images/projects/` altına koy, `project-details.js` içinde galeriye/videolara ekle.
2. Web sürümlerini üret (görseller WebP 800/1600 px, videolar uzun kenar ≤960 px H.264):
   `python -I tools/optimize-media.py hepsi` (Pillow + ffmpeg gerekir; yalnız eksik/eskimiş sürümleri üretir).
   Web sürümü yoksa sayfa otomatik olarak orijinal dosyayı gösterir, yalnızca daha yavaş yüklenir.

## Yerelde çalıştırma

```
python -m http.server 8080
```
ve `http://localhost:8080/` (bir üst klasördeki `siteyi-baslat.bat` aynısını yapar).

## Yayın

`main` dalına push → GitHub Pages 1–2 dakika içinde yayınlar.

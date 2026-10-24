# Portföyde gösterilen görsel/videoların web sürümlerini üretir (orijinallere dokunmaz).
#   python -I tools/optimize-media.py [gorsel|video|hepsi]   (Pillow + ffmpeg gerekir)
# Çıktı: images/web/<ad>-800.webp, <ad>-1600.webp (galeri/ışık kutusu), <ad>-web.mp4 (uzun kenar ≤960 px H.264)
import os, re, sys, subprocess, json
from PIL import Image
KOK = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))  # depo kökü
WEB = os.path.join(KOK, 'images', 'web'); os.makedirs(WEB, exist_ok=True)
mod = sys.argv[1] if len(sys.argv) > 1 else 'hepsi'
metin = open(os.path.join(KOK, 'project-details.js'), encoding='utf-8').read() + open(os.path.join(KOK, 'index.html'), encoding='utf-8').read()
gorseller = sorted(set(re.findall(r'images/projects/[A-Za-z0-9_.-]+\.(?:jpe?g|png)', metin, re.I)))
videolar = sorted(set(re.findall(r'images/projects/[A-Za-z0-9_.-]+\.mp4', metin)))
kb = lambda f: os.path.getsize(f) // 1024
oncesi = sonrasi = 0
if mod in ('gorsel', 'hepsi'):
    for g in gorseller:
        src = os.path.join(KOK, g.replace('/', os.sep))
        if not os.path.exists(src): print('YOK', g); continue
        ad = os.path.splitext(os.path.basename(g))[0]
        im = None
        for gen, q in ((800, 76), (1600, 82)):
            out = os.path.join(WEB, f'{ad}-{gen}.webp')
            if os.path.exists(out) and os.path.getmtime(out) > os.path.getmtime(src): continue
            if im is None:
                im = Image.open(src); im = im.convert('RGBA' if im.mode in ('RGBA', 'LA', 'P') else 'RGB')
                if im.mode == 'RGBA':
                    bg = Image.new('RGB', im.size, (17, 21, 28)); bg.paste(im, mask=im.split()[3]); im = bg
            k = im if im.width <= gen else im.resize((gen, round(im.height * gen / im.width)), Image.LANCZOS)
            k.save(out, 'WEBP', quality=q, method=6)
        oncesi += kb(src); sonrasi += kb(os.path.join(WEB, f'{ad}-800.webp'))
    print(f'görseller: {len(gorseller)} adet, orijinal {oncesi//1024} MB -> galeri(800) {sonrasi//1024} MB')
if mod in ('video', 'hepsi'):
    vo = vs = 0
    for v in videolar:
        src = os.path.join(KOK, v.replace('/', os.sep))
        if not os.path.exists(src): print('YOK', v); continue
        ad = os.path.splitext(os.path.basename(v))[0]
        out = os.path.join(WEB, f'{ad}-web.mp4')
        if not (os.path.exists(out) and os.path.getmtime(out) > os.path.getmtime(src)):
            subprocess.run(['ffmpeg', '-y', '-loglevel', 'error', '-i', src,
                '-vf', "scale='if(gte(iw,ih),min(960,iw),-2)':'if(gte(iw,ih),-2,min(960,ih))',fps=30",
                '-c:v', 'libx264', '-preset', 'medium', '-crf', '29', '-pix_fmt', 'yuv420p', '-profile:v', 'high',
                '-c:a', 'aac', '-b:a', '96k', '-ac', '2', '-movflags', '+faststart', out], check=True)
        vo += kb(src); vs += kb(out)
        print(f'  {ad}: {kb(src)//1024} MB -> {kb(out)/1024:.1f} MB', flush=True)
    print(f'videolar: {len(videolar)} adet, {vo//1024} MB -> {vs//1024} MB')

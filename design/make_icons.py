"""Generates the original Lumi app icon (crescent orb + spark on a night gradient) for Android & iOS."""
import glob, math, os
from PIL import Image, ImageDraw, ImageFilter

ROOT = os.path.join(os.path.dirname(__file__), '..', 'mobile')
VIOLET, PINK, BG1, BG2 = (124, 92, 255), (255, 92, 168), (24, 14, 52), (11, 8, 22)

def lerp(a, b, t): return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))

def icon(size, transparent_bg=False):
    S = 1024
    img = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    if not transparent_bg:
        bg = Image.new('RGBA', (S, S))
        px = bg.load()
        for y in range(S):
            for x in range(S):
                t = min(1, math.hypot(x - S * 0.3, y - S * 0.2) / (S * 1.1))
                px[x, y] = lerp(BG1, BG2, t) + (255,)
        img.alpha_composite(bg)
    # glow
    glow = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    ImageDraw.Draw(glow).ellipse([S*0.18, S*0.18, S*0.82, S*0.82], fill=PINK + (120,))
    img.alpha_composite(glow.filter(ImageFilter.GaussianBlur(S * 0.08)))
    # gradient orb
    grad = Image.new('RGBA', (S, S))
    gp = grad.load()
    for y in range(S):
        for x in range(S):
            gp[x, y] = lerp(VIOLET, PINK, (x + y) / (2 * S)) + (255,)
    mask = Image.new('L', (S, S), 0)
    md = ImageDraw.Draw(mask)
    c, r = S / 2, S * 0.30
    md.ellipse([c - r, c - r, c + r, c + r], fill=255)
    cx, cy, r2 = c + r * 0.45, c - r * 0.35, r * 0.78
    md.ellipse([cx - r2, cy - r2, cx + r2, cy + r2], fill=0)
    img.paste(grad, (0, 0), mask)
    # spark
    sx, sy, L = c + r * 0.55, c - r * 0.45, S * 0.10
    pts = []
    for i in range(8):
        a = i * math.pi / 4
        d = L if i % 2 == 0 else L * 0.22
        pts.append((sx + math.cos(a) * d, sy + math.sin(a) * d))
    ImageDraw.Draw(img).polygon(pts, fill=(255, 255, 255, 255))
    return img.resize((size, size), Image.LANCZOS)

base = icon(1024)
for d, s in {'mdpi': 48, 'hdpi': 72, 'xhdpi': 96, 'xxhdpi': 144, 'xxxhdpi': 192}.items():
    base.resize((s, s), Image.LANCZOS).save(f'{ROOT}/android/app/src/main/res/mipmap-{d}/ic_launcher.png')
for f in glob.glob(f'{ROOT}/ios/Runner/Assets.xcassets/AppIcon.appiconset/*.png'):
    w = Image.open(f).size[0]
    base.resize((w, w), Image.LANCZOS).convert('RGB').save(f)  # iOS icons must be opaque
icon(288, transparent_bg=True).save(f'{ROOT}/android/app/src/main/res/drawable/splash_logo.png')
for f in glob.glob(f'{ROOT}/ios/Runner/Assets.xcassets/LaunchImage.imageset/*.png'):
    w = Image.open(f).size[0]
    icon(max(w, 1) * 1, transparent_bg=True).save(f) if w > 1 else None
base.save(os.path.join(os.path.dirname(__file__), 'lumi-icon-1024.png'))
print('icons ok')

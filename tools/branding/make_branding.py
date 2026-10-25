"""Composes launcher icons, splash screen and logo from Blender renders.
python make_branding.py <renders_dir> <project_dir>
"""
import sys, os, math
from PIL import Image, ImageDraw, ImageFont, ImageFilter

src, proj = sys.argv[1], sys.argv[2]
icons = os.path.join(proj, 'assets', 'icons')
ui = os.path.join(proj, 'assets', 'ui')
os.makedirs(icons, exist_ok=True)
os.makedirs(ui, exist_ok=True)
FONT = os.path.join(proj, 'assets', 'fonts', 'LilitaOne.woff')
SKY_TOP, SKY_BOT = (111, 182, 255), (21, 91, 181)
SUN, RED, NAVY = (255, 210, 46), (232, 52, 44), (10, 44, 99)


def gradient(w, h, top, bot):
    im = Image.new('RGB', (w, h))
    d = ImageDraw.Draw(im)
    for y in range(h):
        t = y / max(1, h - 1)
        d.line([(0, y), (w, y)], fill=tuple(int(top[i] + (bot[i] - top[i]) * t) for i in range(3)))
    return im


def burst(size, color, n=16, inner=0.35):
    im = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    c = size / 2
    pts = []
    for i in range(n * 2):
        a = math.pi * i / n
        r = c if i % 2 == 0 else c * (inner + 0.45)
        pts.append((c + r * math.cos(a), c + r * math.sin(a)))
    d.polygon(pts, fill=color)
    return im


face = Image.open(os.path.join(src, 'icon_face.png')).convert('RGBA')
bbox = face.getbbox()
face = face.crop(bbox)

# --- adaptive icon background + foreground (432 px, safe zone = central 66%)
bg = gradient(432, 432, SKY_TOP, SKY_BOT).convert('RGBA')
b = burst(600, (255, 255, 255, 40), 18)
bg.alpha_composite(b, (-84, -84))
bg.convert('RGB').save(os.path.join(icons, 'icon_bg_432.png'))
fg = Image.new('RGBA', (432, 432), (0, 0, 0, 0))
f = face.copy()
f.thumbnail((330, 330), Image.LANCZOS)
fg.alpha_composite(f, ((432 - f.width) // 2, (432 - f.height) // 2 + 6))
fg.save(os.path.join(icons, 'icon_fg_432.png'))
mono = Image.new('RGBA', (432, 432), (0, 0, 0, 0))
mono.paste((255, 255, 255, 255), (0, 0), fg.split()[3])
mono.save(os.path.join(icons, 'icon_mono_432.png'))

# --- legacy / main icon 192 + project icon 256 (rounded square)
for size, name in ((192, 'icon_192.png'), (256, 'icon.png'), (512, 'icon_512.png')):
    base = Image.alpha_composite(bg, fg).resize((size, size), Image.LANCZOS)
    mask = Image.new('L', (size, size), 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, size - 1, size - 1), radius=size // 5, fill=255)
    out = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    out.paste(base, (0, 0), mask)
    out.save(os.path.join(icons, name) if name != 'icon.png' else os.path.join(proj, 'icon.png'))


# --- logo (transparent) used on menu + splash
def logo(width):
    big = ImageFont.truetype(FONT, int(width * 0.26))
    small = ImageFont.truetype(FONT, int(width * 0.05))
    W, H = width, int(width * 0.52)
    im = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    text = 'R.I.L.E.Y.'
    tw = d.textlength(text, font=big)
    x, y = (W - tw) / 2, H * 0.04
    for dy, col in ((int(width * 0.03), NAVY), (int(width * 0.015), RED)):
        d.text((x, y + dy), text, font=big, fill=col, stroke_width=int(width * 0.012), stroke_fill=NAVY)
    d.text((x, y), text, font=big, fill=SUN, stroke_width=int(width * 0.012), stroke_fill=NAVY)
    sub = 'Really Impossible Landing Experiments, Yay!'
    sw = d.textlength(sub, font=small)
    pad = width * 0.03
    by = H * 0.72
    d.rounded_rectangle(((W - sw) / 2 - pad, by - pad * 0.5, (W + sw) / 2 + pad, by + small.size + pad * 0.7),
                        radius=int(pad), fill=(255, 255, 255), outline=NAVY, width=max(2, int(width * 0.006)))
    d.text(((W - sw) / 2, by), sub, font=small, fill=NAVY)
    return im


lg = logo(1200)
lg.save(os.path.join(ui, 'logo.png'))

# --- splash 1920x1080
sp = gradient(1920, 1080, SKY_TOP, SKY_BOT).convert('RGBA')
sp.alpha_composite(burst(1700, (255, 255, 255, 30), 22), (1100 - 850, 540 - 850))
riley = Image.open(os.path.join(src, 'splash_riley.png')).convert('RGBA')
riley = riley.crop(riley.getbbox())
riley.thumbnail((900, 980), Image.LANCZOS)
sp.alpha_composite(riley, (1920 - riley.width - 140, 1080 - riley.height - 60))
l2 = lg.copy()
l2.thumbnail((1000, 600), Image.LANCZOS)
sp.alpha_composite(l2, (110, 300))
sp.convert('RGB').save(os.path.join(ui, 'splash.png'))
print('BRANDING DONE')

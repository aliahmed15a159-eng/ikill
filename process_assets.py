from pathlib import Path
from PIL import Image, ImageFilter
import numpy as np
root = Path('/home/user/uploads')
out = root/'img'
out.mkdir(exist_ok=True)

# Remove the white/gray capture background from iKILL's original logo.
im = Image.open(root/'ikill-logo.png').convert('RGBA')
a = np.asarray(im).copy()
rgb = a[..., :3].astype(np.float32)
mx = rgb.max(axis=2); mn = rgb.min(axis=2); sat = mx-mn
lum = (.2126*rgb[...,0] + .7152*rgb[...,1] + .0722*rgb[...,2])
# Content is green and near-black, while the supplied canvas is white/gray.
# Preserve saturated brand green and dark wordmark/silhouette.
mask = ((sat > 30) & (lum < 245)) | (lum < 95)
# Find content bounds. A small padding gives the wordmark antialiased room.
ys,xs = np.where(mask)
x0,x1 = max(0,xs.min()-12), min(im.width,xs.max()+13)
y0,y1 = max(0,ys.min()-12), min(im.height,ys.max()+13)
# exact alpha: background is transparent; soft edges from mask expansion are kept by transparency ramp
alpha = np.zeros_like(lum, dtype=np.uint8)
alpha[mask] = 255
# Expand the content mask subtly for anti-aliased boundary pixels using Gaussian blur.
soft = Image.fromarray(alpha).filter(ImageFilter.GaussianBlur(1.1))
soft_a = np.asarray(soft)
# foreground pixels remain fully opaque, blurred halo only retains colour on close edge pixels
near = (soft_a > 12) & (lum < 235)
alpha[near] = np.maximum(alpha[near], (soft_a[near] * 0.85).astype(np.uint8))
a[...,3] = alpha
result = Image.fromarray(a, 'RGBA').crop((x0,y0,x1,y1))
result.save(out/'ikill-logo.png', optimize=True)
result.save(out/'ikill-logo-transparent.png', optimize=True)

# Keep source partner images reachable by existing paths. Their supplied screenshot-style
# backgrounds are retained as client-provided artwork; CSS will show them on clean light cards.
for p in root.glob('Gemini_Generated_Image_*.png'):
    target=out/p.name
    if not target.exists():
        target.write_bytes(p.read_bytes())
print('Created', out/'ikill-logo.png', result.size, 'content alpha', result.getchannel('A').getextrema())

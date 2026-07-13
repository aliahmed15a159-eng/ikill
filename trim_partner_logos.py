from pathlib import Path
from PIL import Image
import numpy as np
folder=Path('/home/user/uploads/img/partners-clean')
for p in sorted(folder.glob('*.png')):
    im=Image.open(p).convert('RGBA')
    a=np.array(im.getchannel('A'))
    # Antialiased pixels are part of the artwork. Trim only transparent/near-transparent canvas.
    ys,xs=np.where(a>16)
    if xs.size:
        pad=3
        left=max(0,xs.min()-pad); top=max(0,ys.min()-pad)
        right=min(im.width,xs.max()+pad+1); bottom=min(im.height,ys.max()+pad+1)
        im.crop((left,top,right,bottom)).save(p,optimize=True)
        print(p.name, '=>', (right-left,bottom-top))

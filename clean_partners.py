from pathlib import Path
from PIL import Image, ImageFilter
import numpy as np
from collections import Counter
root=Path('/home/user/uploads')
out=root/'img'/'partners-clean'
out.mkdir(exist_ok=True)

def background_palette(a):
    h,w,_=a.shape
    s=36
    samples=np.concatenate([
      a[:s,:s,:3].reshape(-1,3), a[:s,w-s:,:3].reshape(-1,3),
      a[h-s:,:s,:3].reshape(-1,3), a[h-s:,w-s:,:3].reshape(-1,3),
      a[:s,:,:3].reshape(-1,3), a[h-s:,:,:3].reshape(-1,3)
    ])
    # quantize samples, then actual palette centers by average per clustered color
    q=(samples//16)*16
    tops=Counter(map(tuple,q)).most_common(6)
    cols=[]
    for qcol,_ in tops:
        qarr=np.array(qcol)
        close=np.abs(samples-qarr).max(axis=1)<16
        cols.append(samples[close].mean(axis=0))
    return np.array(cols)

def smooth(v,n=23):
    return np.convolve(v,np.ones(n)/n,mode='same')
def best_range(scores,lo,hi,threshold):
    yes=scores>threshold
    yes[:lo]=False; yes[hi:]=False
    best=None; st=None
    for i,x in enumerate(yes):
      if x and st is None: st=i
      if st is not None and (not x or i==len(yes)-1):
        e=i if not x else i+1
        score=scores[st:e].sum()
        if best is None or score>best[0]: best=(score,st,e)
        st=None
    return best[1:] if best else (lo,hi)

for p in sorted(root.glob('Gemini_Generated_Image_*.png')):
    im=Image.open(p).convert('RGBA'); a=np.asarray(im).copy(); h,w=a.shape[:2]
    rgb=a[...,:3].astype(float)
    bg=background_palette(a)
    dist=np.sqrt(((rgb[:,:,None,:]-bg[None,None,:,:])**2).sum(axis=3)).min(axis=2)
    lum=.2126*rgb[...,0]+.7152*rgb[...,1]+.0722*rgb[...,2]
    sat=rgb.max(axis=2)-rgb.min(axis=2)
    dark=lum[0:30,0:30].mean()<130
    if dark:
      cand=(dist>34)&((sat>20)|(lum>140))
    else:
      cand=(dist>35)&((sat>20)|(lum<160))
    # Work in centre field — it excludes mobile viewer bars in a few supplied images.
    cand[:260]=False; cand[1285:]=False
    rows=smooth(cand.sum(axis=1),27)
    y0,y1=best_range(rows,260,1285,12)
    cols=smooth(cand[y0:y1].sum(axis=0),23)
    x0,x1=best_range(cols,0,w,10)
    # protect against accidental selection of an edge artifact
    x0=max(0,x0-14); x1=min(w,x1+14); y0=max(0,y0-14); y1=min(h,y1+14)
    # Build transparency. only within the content region; background palette stays transparent.
    alpha=np.zeros((h,w),dtype=np.uint8)
    content=(dist>24)
    # rasterized logos can have neutral black/gray; retain sufficiently dark pixels in selected frame
    content |= (lum<150)
    region=np.zeros((h,w),bool); region[y0:y1,x0:x1]=True
    alpha[content & region]=255
    # soften boundary just enough, but don't resurrect background checkerboard.
    soft=np.asarray(Image.fromarray(alpha).filter(ImageFilter.GaussianBlur(.65)))
    edge=(soft>20)&(region)&(dist>12)
    alpha[edge]=np.maximum(alpha[edge], (soft[edge]*.72).astype(np.uint8))
    a[...,3]=alpha
    res=Image.fromarray(a,'RGBA').crop((x0,y0,x1,y1))
    res.save(out/p.name,optimize=True)
    print(p.name, 'dark' if dark else 'light', 'bbox',res.size,'from',x0,y0,x1,y1)

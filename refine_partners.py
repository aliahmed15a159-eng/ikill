from pathlib import Path
from PIL import Image, ImageFilter
import numpy as np
from collections import Counter
root=Path('/home/user/uploads'); out=root/'img'/'partners-clean'
manual={
 'Gemini_Generated_Image_etmov0etmov0etmo.png':(35,500,655,1050),
 'Gemini_Generated_Image_nloezonloezonloe.png':(45,600,645,1050),
 'Gemini_Generated_Image_wljzufwljzufwljz.png':(0,720,688,1150),
 'Gemini_Generated_Image_yprav4yprav4ypra.png':(25,620,670,1080),
 'Gemini_Generated_Image_r6z331r6z331r6z3.png':(15,500,670,1040),
}
dark_special={'Gemini_Generated_Image_6iehnd6iehnd6ieh.png','Gemini_Generated_Image_c0m5wsc0m5wsc0m5.png'}
def palette(a):
 h,w,_=a.shape; s=38
 samples=np.concatenate([a[:s,:s,:3].reshape(-1,3),a[:s,w-s:,:3].reshape(-1,3),a[h-s:,:s,:3].reshape(-1,3),a[h-s:,w-s:,:3].reshape(-1,3)])
 q=(samples//16)*16; top=Counter(map(tuple,q)).most_common(8)
 cs=[]
 for c,_ in top:
  c=np.asarray(c); z=samples[np.abs(samples-c).max(axis=1)<18]
  cs.append(z.mean(axis=0))
 return np.asarray(cs)
for name,box in manual.items():
 p=root/name; im=Image.open(p).convert('RGBA');a=np.asarray(im).copy();rgb=a[:,:,:3].astype(float)
 bg=palette(a);dist=np.sqrt(((rgb[:,:,None,:]-bg[None,None,:,:])**2).sum(axis=3)).min(axis=2)
 lum=.2126*rgb[...,0]+.7152*rgb[...,1]+.0722*rgb[...,2];sat=rgb.max(axis=2)-rgb.min(axis=2)
 content=(dist>25)|(lum<150)
 alpha=np.zeros(lum.shape,dtype=np.uint8); region=np.zeros(lum.shape,dtype=bool);x0,y0,x1,y1=box;region[y0:y1,x0:x1]=True;alpha[content&region]=255
 soft=np.asarray(Image.fromarray(alpha).filter(ImageFilter.GaussianBlur(.65)));edge=(soft>22)&region&(dist>12);alpha[edge]=np.maximum(alpha[edge],(soft[edge]*.72).astype(np.uint8));a[:,:,3]=alpha
 Image.fromarray(a,'RGBA').crop(box).save(out/name,optimize=True)
# Special dark checker screenshot images: preserve coloured and white logo, drop every neutral dark tile.
for name in dark_special:
 p=out/name; im=Image.open(p).convert('RGBA');a=np.asarray(im).copy();rgb=a[:,:,:3].astype(float);lum=.2126*rgb[...,0]+.7152*rgb[...,1]+.0722*rgb[...,2];sat=rgb.max(axis=2)-rgb.min(axis=2)
 alpha=np.zeros(lum.shape,dtype=np.uint8);alpha[(sat>20)|(lum>165)]=255
 soft=np.asarray(Image.fromarray(alpha).filter(ImageFilter.GaussianBlur(.7)));edge=(soft>18)&((sat>10)|(lum>145));alpha[edge]=np.maximum(alpha[edge],(soft[edge]*.76).astype(np.uint8));a[:,:,3]=alpha
 Image.fromarray(a,'RGBA').save(p,optimize=True)

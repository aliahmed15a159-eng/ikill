from PIL import Image
from pathlib import Path
for source,target in [
    (Path('/home/user/uploads/img/ikill-logo.png'),Path('/home/user/uploads/img/ikill-logo-dark.png')),
    (Path('/home/user/uploads/ikill-logo.png'),Path('/home/user/uploads/ikill-logo-dark.png')),
]:
    im=Image.open(source).convert('RGBA')
    pix=im.load()
    for y in range(im.height):
        for x in range(im.width):
            r,g,b,a=pix[x,y]
            if a == 0: continue
            # Preserve the green wordmark; turn the achromatic black text/silhouette
            # and its antialiased edge pixels white for dark surfaces and the favicon.
            if max(r,g,b)-min(r,g,b) < 22 and (r+g+b)/3 < 205:
                pix[x,y]=(255,255,255,a)
    im.save(target,optimize=True)
    print(target,im.size)

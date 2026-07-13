from pathlib import Path
import re
root=Path('/home/user/uploads')
email='''
            <a href="mailto:info@ikill.com.eg" style="display:flex;align-items:center;gap:0.4rem;color:inherit;text-decoration:none;">
                <i class="fas fa-envelope" style="color:var(--green-300);font-size:0.75rem;"></i>
                <span data-contact="email">info@ikill.com.eg</span>
            </a>'''
for name in ['about.html','services.html','sectors.html','contact.html']:
 p=root/name;s=p.read_text()
 # First topbar phone anchor followed by closing div.
 pattern=r'(<a href="tel:01020019042"[^>]*>.*?</a>)(\s*</div>\s*<div style="display:flex;align-items:center;gap:1rem;font-size:0\.72rem;">)'
 s2,n=re.subn(pattern, lambda m:m.group(1)+email+m.group(2), s, count=1, flags=re.S)
 if n!=1: raise SystemExit('topbar target missing '+name)
 p.write_text(s2)
 print(name)

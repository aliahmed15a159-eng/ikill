from pathlib import Path
root=Path('/home/user/uploads')
# Landing stat id/data. Use the IDs expected by the central settings loader.
p=root/'index.html'; s=p.read_text()
s=s.replace('id="stat1-val-bar" data-counter="90">90</div>', 'id="stat1-val" data-counter="15">15</div>')
s=s.replace('id="stat3-val-bar" data-counter="240">240k</div>', 'id="stat3-val" data-counter="240k">240k</div>')
old='''        <div id="locations-teaser-container" class="animate-stagger" style="display:grid;grid-template-columns:repeat(auto-fill,minmax(200px,1fr));gap:1rem;">
            <div style="grid-column:1/-1;text-align:center;padding:2.5rem;color:var(--text-muted);"><i class="fas fa-circle-notch fa-spin text-xl" style="color:var(--green-500);"></i></div>
        </div>'''
new='''        <div class="animate-fade-up" style="max-width:760px;margin:0 auto;">
            <a href="locations.html" class="home-branch-card" aria-label="عرض بيانات الفرع الرئيسي">
                <div class="home-branch-address">
                    <div class="home-branch-icon"><i class="fas fa-map-marker-alt"></i></div>
                    <div>
                        <span>العنوان</span>
                        <strong>شارع الملك فيصل، الجيزة، مصر</strong>
                    </div>
                </div>
                <div class="home-branch-details">
                    <div><i class="fas fa-building"></i><span><b>الفرع الرئيسي</b> القاهرة والجيزة</span></div>
                    <div><i class="fas fa-phone-alt"></i><span data-contact="phone">01020019042</span></div>
                    <div><i class="fas fa-envelope"></i><span data-contact="email">info@ikill.com.eg</span></div>
                </div>
                <i class="fas fa-arrow-left home-branch-arrow" aria-hidden="true"></i>
            </a>
        </div>'''
if old not in s: raise SystemExit('home loader block missing')
s=s.replace(old,new)
p.write_text(s)
# About page experience stat
p=root/'about.html';s=p.read_text();s=s.replace('>90</div>\n                            <div style="font-size:0.82rem;color:var(--text-muted);font-weight:500;" data-i18n="about.stat1_lbl">', '>15</div>\n                            <div style="font-size:0.82rem;color:var(--text-muted);font-weight:500;" data-i18n="about.stat1_lbl">',1);p.write_text(s)
# Admin dashboard must show 15 in the configured default and save 15 despite stale old cloud data.
p=root/'admin.html';s=p.read_text();s=s.replace('id="set-stat1-value" placeholder="90"', 'id="set-stat1-value" value="15" placeholder="15"')
s=s.replace("document.getElementById('set-stat1-value').value = data.stat1Value || '90';", "document.getElementById('set-stat1-value').value = '15';")
s=s.replace("const stat1Value = document.getElementById('set-stat1-value').value.trim();", "const stat1Value = '15';")
# Enforce official communication email in dashboard settings in case old Firestore settings are present.
s=s.replace("const settingsForm = document.getElementById('site-settings-form');", "const settingsForm = document.getElementById('site-settings-form');\n        const OFFICIAL_COMPANY_EMAIL = 'info@ikill.com.eg';")
s=s.replace("document.getElementById('set-email').value = data.email || '';", "document.getElementById('set-email').value = OFFICIAL_COMPANY_EMAIL;")
s=s.replace("const email = document.getElementById('set-email').value.trim();", "const email = OFFICIAL_COMPANY_EMAIL;\n            document.getElementById('set-email').value = OFFICIAL_COMPANY_EMAIL;")
p.write_text(s)
# Any plain historical 90 stat text not part of CSS token names follows the requested 15-year metric.
# (Other 90 values do not exist in public content.)
print('public content and admin stats updated')

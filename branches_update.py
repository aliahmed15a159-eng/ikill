from pathlib import Path
p=Path('/home/user/uploads/locations.html');s=p.read_text()
# Make the address first, before status/name/country information.
needle='''                <div style="display:flex;flex-wrap:wrap;justify-content:space-between;align-items:flex-start;gap:1.5rem;margin-bottom:1.5rem;">'''
priority='''                <a href="https://maps.google.com/?q=شارع+الملك+فيصل+الجيزة+مصر" target="_blank" rel="noopener" class="branch-address-priority">
                    <div class="branch-contact-icon"><i class="fas fa-map-marker-alt"></i></div>
                    <div>
                        <small data-i18n="branch.address_label">العنوان</small>
                        <strong data-i18n="footer.address">شارع الملك فيصل، الجيزة، مصر</strong>
                    </div>
                </a>

                <div style="display:flex;flex-wrap:wrap;justify-content:space-between;align-items:flex-start;gap:1.5rem;margin-bottom:1.5rem;">'''
if needle not in s: raise SystemExit('Branch header target missing')
s=s.replace(needle,priority,1)
# Address is now prominently first; remove its duplicate in the information rows.
old='''                        <a href="https://maps.google.com/?q=شارع+الملك+فيصل+الجيزة+مصر" target="_blank" class="branch-contact-row">
                            <div class="branch-contact-icon"><i class="fas fa-map-marker-alt"></i></div>
                            <div>
                                <div style="font-size:0.75rem;color:var(--text-muted);margin-bottom:0.15rem;" data-i18n="branch.address_label">العنوان</div>
                                <div style="font-weight:600;" data-i18n="footer.address">شارع الملك فيصل الجيزة</div>
                            </div>
                        </a>
'''
if old not in s: raise SystemExit('Duplicate address target missing')
s=s.replace(old,'',1)
# Remove the public Firebase branch collection/loading placeholder; the main official branch card remains fully visible.
start='''        <!-- Dynamic branches from Firebase -->'''
end='''

    </div>
</section>'''
i=s.find(start)
if i<0: raise SystemExit('dynamic section start missing')
j=s.find(end,i)
if j<0: raise SystemExit('dynamic section end missing')
s=s[:i]+'        <!-- Additional branches will be listed here once officially announced. -->'+s[j:]
p.write_text(s)
print('locations branch page updated')

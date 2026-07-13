from pathlib import Path
p=Path('/home/user/uploads/app.js')
s=p.read_text()
# Add canonical company identity just before the translations object.
needle='''/* =============================================
   TRANSLATIONS (i18n)
   ============================================= */
const TRANSLATIONS = {'''
repl='''/* =============================================
   COMPANY IDENTITY (single source of truth)
   ============================================= */
const COMPANY_EMAIL = 'info@ikill.com.eg';
const COMPANY_DOMAIN = 'https://ikill.net';

function applyCompanyEmail() {
  document.querySelectorAll('[data-contact="email"]').forEach(el => {
    el.textContent = COMPANY_EMAIL;
  });
  document.querySelectorAll('a[href^="mailto:"]').forEach(link => {
    link.href = `mailto:${COMPANY_EMAIL}`;
    const textNode = [...link.querySelectorAll('span, div')].find(el => el.textContent.includes('@'));
    if (textNode) textNode.textContent = COMPANY_EMAIL;
  });
}

/* =============================================
   TRANSLATIONS (i18n)
   ============================================= */
const TRANSLATIONS = {'''
if needle not in s: raise SystemExit('translations needle missing')
s=s.replace(needle,repl,1)
# Exact stats updates in AR / English translations
s=s.replace("'stat1.value': '90', 'stat1.label': 'عام من الخبرة',", "'stat1.value': '15', 'stat1.label': 'عام من الخبرة',")
s=s.replace("'stat1.value': '90', 'stat1.label': 'Years of Experience',", "'stat1.value': '15', 'stat1.label': 'Years of Experience',")
# Replace settings block stat contact processing
old='''      // Stats
      const fields = ['stat1', 'stat2', 'stat3', 'stat4'];
      fields.forEach((f, i) => {
        const valEl = document.getElementById(`${f}-val`);
        const lblEl = document.getElementById(`${f}-lbl`);
        if (valEl && data[`${f}Value`]) {
          valEl.setAttribute('data-counter', data[`${f}Value`]);
          valEl.textContent = data[`${f}Value`];
        }
        if (lblEl && data[`${f}Label`]) lblEl.textContent = data[`${f}Label`];
      });

      // Contact info
      ['phone', 'email', 'address'].forEach(field => {
        if (!data[field]) return;
        document.querySelectorAll(`[data-contact="${field}"]`).forEach(el => {
          el.textContent = data[field];
          if (field === 'phone' && el.tagName === 'A') {
            el.href = `tel:${data[field].replace(/\\s+/g, '')}`;
          }
        });
      });'''
new='''      // Stats. The business experience figure is set to 15 years site-wide.
      const fields = ['stat1', 'stat2', 'stat3', 'stat4'];
      fields.forEach(f => {
        const valEl = document.getElementById(`${f}-val`);
        const lblEl = document.getElementById(`${f}-lbl`);
        const value = f === 'stat1' ? '15' : data[`${f}Value`];
        if (valEl && value) {
          valEl.setAttribute('data-counter', value);
          valEl.textContent = value;
        }
        if (lblEl && data[`${f}Label`]) lblEl.textContent = data[`${f}Label`];
      });

      // Contact info. The published company email is always info@ikill.com.eg.
      ['phone', 'address'].forEach(field => {
        if (!data[field]) return;
        document.querySelectorAll(`[data-contact="${field}"]`).forEach(el => {
          el.textContent = data[field];
          if (field === 'phone') {
            const anchor = el.closest('a') || (el.tagName === 'A' ? el : null);
            if (anchor) anchor.href = `tel:${data[field].replace(/\\s+/g, '')}`;
          }
        });
      });
      applyCompanyEmail();'''
if old not in s: raise SystemExit('Settings block missing')
s=s.replace(old,new,1)
s=s.replace("ADMIN_EMAILS: ['info@ikill.com.eg'],", 'ADMIN_EMAILS: [COMPANY_EMAIL],')
# apply email immediately during general DOM initialisation (before Firebase connection resolution)
needle2='''  // Core systems
  ThemeManager.init();'''
repl2='''  // Core systems
  applyCompanyEmail();
  ThemeManager.init();'''
if needle2 not in s: raise SystemExit('DOM needle missing')
s=s.replace(needle2,repl2,1)
p.write_text(s)
print('app.js updated')

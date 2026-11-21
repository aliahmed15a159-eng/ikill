// Node-only syntax and existing-screen integration checks; no network requests.
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const root = path.resolve(__dirname, '../..');
let checks = 0;
for (const name of fs.readdirSync(root)) {
  const file = path.join(root, name);
  if (name.endsWith('.js')) { new vm.Script(fs.readFileSync(file, 'utf8'), { filename: name }); checks++; }
  if (name.endsWith('.html')) {
    const html = fs.readFileSync(file, 'utf8');
    for (const match of html.matchAll(/<script([^>]*)>([\s\S]*?)<\/script>/gi)) {
      if (/application\/ld\+json/.test(match[1])) continue;
      const source = /src="([^"]+)"/.exec(match[1]);
      if (source) {
        if (!/^https?:/.test(source[1])) assert.ok(fs.existsSync(path.resolve(root,source[1])), source[1]);
      } else new vm.Script(match[2], { filename: name });
      checks++;
    }
  }
}
function bridge(profile) {
  const calls = [];
  const client = {
    async rpc(name, params) {
      calls.push({ name, params });
      return { data: name === 'get_my_profile' ? profile : name === 'get_public_brand' ? { branding: { phone: '123' } }
        : name === 'get_public_branches' ? [{ id: 'b', name_ar: 'فرع', name_en: 'Branch' }] : null, error: null };
    },
    auth: {
      async signInWithPassword() { return { data: {}, error: null }; },
      async signOut() { calls.push({ name: 'signOut' }); return { data: {}, error: null }; },
      async getUser() { return { data: { user: { email: 'test@example.com' } }, error: null }; },
      async getSession() { return { data: { session: null }, error: null }; }
    }
  };
  const window = { IKILL_SUPABASE_ENV: { SUPABASE_URL: 'https://example.supabase.co', SUPABASE_ANON_KEY: 'public' },
    supabase: { createClient: () => client }, dispatchEvent() {}, addEventListener() {} };
  vm.runInNewContext(fs.readFileSync(path.join(root,'supabase-backend.js'),'utf8'), {
    window, console, Event: class {}, setTimeout, setInterval: () => 1, clearInterval() {}, document: { getElementById: () => null }
  });
  return { window, calls };
}
(async () => {
  let fixture = bridge(null);
  const settings = await fixture.window.db.table('brand_settings').record('global').get();
  assert.equal(settings.data().phone, '123'); checks++;
  const branches = await fixture.window.db.table('company_branches').where('status','==','active').get();
  assert.equal(branches.docs[0].data().nameAr, 'فرع'); checks++;
  await fixture.window.db.table('requests').add({ name:'Name',phone:'',email:'test@example.com',address:'Address',service:'Pest',message:'Message' });
  assert.equal(fixture.calls.at(-1).name,'submit_contact_request'); checks++;
  fixture = bridge({ role:'client',portal_enabled:false,is_active:true,tenant_active:true });
  await assert.rejects(() => fixture.window.auth.signIn('test@example.com','not-real'), /بوابة العميل/); checks++;
  assert.equal(fixture.calls.at(-1).name,'signOut'); checks++;
  fixture = bridge({ role:'technician',portal_enabled:false,is_active:true,tenant_active:true });
  await assert.rejects(() => fixture.window.auth.signIn('test@example.com','not-real'), /للإدارة/); checks++;
  fixture = bridge({ role:'admin',portal_enabled:false,is_active:true,tenant_active:true });
  await fixture.window.auth.signIn('test@example.com','not-real');
  assert.equal(fixture.window.auth.currentUser.email,'test@example.com'); checks++;
  console.log(`PASS: ${checks} website script/asset and Supabase view-model checks (mocked SDK).`);
})().catch(error => { console.error(error); process.exitCode=1; });

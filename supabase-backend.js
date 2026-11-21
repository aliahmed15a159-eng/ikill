/* Existing website view-model bridge backed ONLY by official Supabase JS.
   No database credentials or privileged client; all admin calls are RLS scoped.
   Polling preserves the existing listener UI without enabling DB Realtime. */
(() => {
  'use strict';
  const env = window.IKILL_SUPABASE_ENV;
  if (!env?.SUPABASE_URL || !env?.SUPABASE_ANON_KEY) return;
  const client = window.supabase.createClient(env.SUPABASE_URL, env.SUPABASE_ANON_KEY, {
    auth: { storage: window.sessionStorage, persistSession: true, autoRefreshToken: true, detectSessionInUrl: false }
  });
  window.supabaseClient = client;
  const slug = env.BRAND_SLUG || 'ikill';
  const unwrap = ({ data, error }) => { if (error) throw error; return data; };
  const rpc = async (name, params = {}) => unwrap(await client.rpc(name, params));
  const branch = r => ({ ...r, nameAr: r.name_ar, nameEn: r.name_en, countryAr: r.country_ar, countryEn: r.country_en });
  const branchRow = r => ({ name_ar: r.nameAr, name_en: r.nameEn, country_ar: r.countryAr, country_en: r.countryEn, phone: r.phone || '', status: r.status });
  const request = r => ({ ...r, name: r.display_name, address: r.billing_address, service: r.requested_service, message: r.request_message, timestamp: r.created_at });
  const account = async () => {
    const p = await rpc('get_my_profile');
    if (!p) throw new Error('لم تُنشأ صلاحيات حسابك بعد. تواصل مع الإدارة.');
    if (!p.is_active || !p.tenant_active) throw new Error('الحساب أو الشركة غير مفعّل.');
    if (p.role === 'client' && !p.portal_enabled) throw new Error('بوابة العميل غير مفعّلة لحسابك. تواصل مع الإدارة.');
    if (p.role !== 'admin') throw new Error('هذه الشاشة للإدارة فقط.');
    return p;
  };
  window.auth = {
    get currentUser() { return this.user || null; },
    user: null,
    async signIn(email, password) {
      unwrap(await client.auth.signInWithPassword({ email, password }));
      try { await account(); }
      catch (e) { await client.auth.signOut({ scope: 'local' }); throw e; }
      this.user = unwrap(await client.auth.getUser()).user;
    },
    async signOut() { unwrap(await client.auth.signOut()); this.user = null; },
    onSessionChanged(callback) {
      let stopped = false;
      const update = async () => {
        try {
          const { session } = unwrap(await client.auth.getSession());
          if (!session) { this.user = null; if (!stopped) callback(null); return; }
          await account();
          this.user = session.user;
          if (!stopped) callback(session.user);
        } catch (e) {
          this.user = null;
          const errorNode = document.getElementById('error-message') || document.getElementById('error-text');
          if (errorNode) errorNode.textContent = e.message;
          if (!stopped) callback(null);
        }
      };
      const { data: { subscription } } = client.auth.onAuthStateChange(() => { setTimeout(update, 0); });
      update();
      return () => { stopped = true; subscription.unsubscribe(); };
    },
    async changePassword(current, next) {
      await account();
      const user = unwrap(await client.auth.getUser()).user;
      unwrap(await client.auth.signInWithPassword({ email: user.email, password: current }));
      unwrap(await client.auth.updateUser({ password: next }));
    }
  };
  class DataQuery {
    constructor(name, id = null, filter = null, sort = null) { Object.assign(this, { name, id, filter, sort }); }
    record(id) { return new DataQuery(this.name, id, this.filter, this.sort); }
    where(field, op, value) { if (op !== '==') throw new Error('Unsupported filter'); return new DataQuery(this.name, this.id, [field, value], this.sort); }
    order(field, direction) { return new DataQuery(this.name, this.id, this.filter, [field, direction]); }
    async get() {
      if (this.name === 'brand_settings') {
        let settings;
        const { session } = unwrap(await client.auth.getSession());
        if (session) {
          const p = await account();
          settings = unwrap(await client.from('tenants').select('branding').eq('id', p.tenant_id).single()).branding;
        } else settings = (await rpc('get_public_brand', { brand_slug: slug }))?.branding;
        return { exists: !!settings, data: () => settings || {} };
      }
      let rows;
      if (this.name === 'company_branches' && this.filter?.[1] === 'active') {
        rows = (await rpc('get_public_branches', { brand_slug: slug })).map(branch);
      } else {
        const p = await account();
        const table = this.name === 'requests' ? 'clients' : this.name;
        if (!['clients', 'company_branches', 'page_events'].includes(table)) throw new Error('Unsupported table');
        let q = client.from(table).select('*').eq('tenant_id', p.tenant_id).order('created_at', { ascending: false });
        if (this.id) q = q.eq('id', this.id);
        rows = unwrap(await q).map(r => table === 'clients' ? request(r) : table === 'company_branches' ? branch(r) : ({ ...r, timestamp: r.created_at }));
      }
      const docs = rows.map(r => ({ id: r.id, data: () => r }));
      return { docs, size: docs.length, empty: !docs.length, forEach: f => docs.forEach(f) };
    }
    subscribe(callback, onError = console.warn) {
      let stopped = false;
      const refresh = async () => { try { const value = await this.get(); if (!stopped) callback(value); } catch (e) { if (!stopped) onError(e); } };
      refresh();
      const timer = setInterval(refresh, 20000);
      const stop = () => { stopped = true; clearInterval(timer); };
      window.addEventListener('pagehide', stop, { once: true });
      return stop;
    }
    async add(values) {
      if (this.name === 'requests') return rpc('submit_contact_request', {
        brand_slug: slug, contact_name: values.name, contact_phone: values.phone || '', contact_email: values.email,
        contact_address: values.address, contact_service: values.service, contact_message: values.message
      });
      if (this.name === 'page_events') return rpc('record_page_view', { brand_slug: slug, page_name: values.page, source: values.referrer });
      if (this.name !== 'company_branches') throw new Error('Unsupported table');
      const p = await account();
      return unwrap(await client.from('company_branches').insert({ ...branchRow(values), tenant_id: p.tenant_id }));
    }
    async delete() {
      const p = await account();
      const table = this.name === 'requests' ? 'clients' : this.name;
      if (!['clients', 'company_branches', 'page_events'].includes(table)) throw new Error('Unsupported table');
      return unwrap(await client.from(table).delete().eq('tenant_id', p.tenant_id).eq('id', this.id));
    }
    async set(values) {
      if (this.name !== 'brand_settings') throw new Error('Unsupported settings');
      const p = await account();
      const old = unwrap(await client.from('tenants').select('branding').eq('id', p.tenant_id).single()).branding;
      return unwrap(await client.from('tenants').update({ branding: { ...old, ...values }, updated_at: new Date().toISOString() }).eq('id', p.tenant_id));
    }
  }
  window.db = { table: name => new DataQuery(name) };
  window.dispatchEvent(new Event('supabase-ready'));
})();

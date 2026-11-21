// Local PostgreSQL tests ONLY. Never connects to a remote Supabase project.
const { PGlite } = require('@electric-sql/pglite');
const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');
const u = n => `00000000-0000-0000-0000-${String(n).padStart(12, '0')}`;
let checks = 0;
(async () => {
  const db = new PGlite();
  const sql = fs.readFileSync(path.join(__dirname, '../phase1_schema.sql'), 'utf8');
  await db.exec(`CREATE ROLE anon; CREATE ROLE authenticated; CREATE ROLE service_role BYPASSRLS;
    CREATE SCHEMA auth; CREATE TABLE auth.users(id uuid PRIMARY KEY);
    CREATE FUNCTION auth.uid() RETURNS uuid LANGUAGE sql STABLE AS $$
      SELECT nullif(current_setting('request.jwt.claim.sub',true),'')::uuid; $$;
    GRANT USAGE ON SCHEMA public,auth TO authenticated,anon;
    GRANT EXECUTE ON FUNCTION auth.uid() TO authenticated,anon;`);
  await db.exec(sql); checks++;
  const count = async table => Number((await db.query(`SELECT count(*) AS n FROM public.${table}`)).rows[0].n);
  const expectCount = async (table, n) => { assert.equal(await count(table), n, table); checks++; };
  const denied = async command => {
    await assert.rejects(() => db.exec(command)); checks++;
  };
  const asUser = async (id, fn) => {
    await db.exec(`SET ROLE authenticated; SELECT set_config('request.jwt.claim.sub','${u(id)}',false);`);
    try { await fn(); } finally { await db.exec("RESET ROLE; SELECT set_config('request.jwt.claim.sub','',false);"); }
  };
  await db.exec(`
    INSERT INTO public.tenants(id,slug,name) VALUES ('${u(1)}','tenant-a','A'),('${u(2)}','tenant-b','B');
    INSERT INTO auth.users(id) VALUES ${[101,102,103,104,105,106,201,202,203,999].map(n => `('${u(n)}')`).join(',')};
    INSERT INTO public.clients(id,tenant_id,client_code,display_name) VALUES
      ('${u(301)}','${u(1)}','a1','Client A'),('${u(302)}','${u(1)}','a2','Other A'),('${u(401)}','${u(2)}','b1','Client B');
    INSERT INTO public.profiles(id,tenant_id,role,full_name,client_id,portal_enabled) VALUES
      ('${u(101)}','${u(1)}','admin','Admin A',NULL,false),
      ('${u(102)}','${u(1)}','technician','Tech A',NULL,false),
      ('${u(106)}','${u(1)}','technician','Other Tech A',NULL,false),
      ('${u(103)}','${u(1)}','client','Portal A','${u(301)}',true),
      ('${u(104)}','${u(1)}','client','Disabled Portal','${u(301)}',false),
      ('${u(105)}','${u(1)}','client','Other Portal','${u(302)}',true),
      ('${u(201)}','${u(2)}','admin','Admin B',NULL,false),
      ('${u(202)}','${u(2)}','technician','Tech B',NULL,false),
      ('${u(203)}','${u(2)}','client','Portal B','${u(401)}',true);
    INSERT INTO public.client_sites(id,tenant_id,client_id,name,sector,address) VALUES
      ('${u(501)}','${u(1)}','${u(301)}','Site A','residential','A address'),
      ('${u(502)}','${u(1)}','${u(302)}','Other A','food','Other address'),
      ('${u(601)}','${u(2)}','${u(401)}','Site B','healthcare','B address');
    INSERT INTO public.visits(id,tenant_id,client_id,site_id,technician_id,scheduled_start,scheduled_end) VALUES
      ('${u(701)}','${u(1)}','${u(301)}','${u(501)}','${u(102)}',now(),now()+interval '1 hour'),
      ('${u(702)}','${u(1)}','${u(302)}','${u(502)}','${u(106)}',now(),now()+interval '1 hour'),
      ('${u(703)}','${u(1)}','${u(301)}','${u(501)}','${u(102)}',now(),now()+interval '2 hours'),
      ('${u(801)}','${u(2)}','${u(401)}','${u(601)}','${u(202)}',now(),now()+interval '1 hour');
    INSERT INTO public.visit_reports(id,tenant_id,visit_id,technician_id,status) VALUES
      ('${u(901)}','${u(1)}','${u(701)}','${u(102)}','submitted'),
      ('${u(902)}','${u(1)}','${u(702)}','${u(106)}','draft'),
      ('${u(903)}','${u(2)}','${u(801)}','${u(202)}','submitted');
    INSERT INTO public.invoices(tenant_id,client_id,invoice_number,due_on,subtotal,status) VALUES
      ('${u(1)}','${u(301)}','A-issued',current_date,100,'issued'),
      ('${u(1)}','${u(301)}','A-draft',current_date,100,'draft'),
      ('${u(2)}','${u(401)}','B-issued',current_date,200,'issued');
  `);
  await asUser(101, async () => {
    await expectCount('clients',2); await expectCount('visits',3); await expectCount('profiles',6);
    await expectCount('invoices',2);
    const result = await db.query(`UPDATE public.clients SET display_name='Admin changed' WHERE id='${u(401)}' RETURNING id`);
    assert.equal(result.rows.length,0); checks++;
    await denied(`INSERT INTO public.client_sites(tenant_id,client_id,name,sector,address)
      VALUES ('${u(1)}','${u(401)}','bad','residential','bad')`);
    await denied(`UPDATE public.visits SET tenant_id='${u(2)}' WHERE id='${u(701)}'`);
    await denied(`UPDATE public.visits SET site_id='${u(502)}' WHERE id='${u(701)}'`);
    await denied(`UPDATE public.visits SET technician_id='${u(103)}' WHERE id='${u(701)}'`);
  });
  await asUser(102, async () => {
    await expectCount('visits',2); await expectCount('client_sites',1); await expectCount('visit_reports',1);
    await expectCount('clients',0); await expectCount('invoices',0); await expectCount('surveys',0);
    await expectCount('profiles',1);
    assert.equal((await db.query(`UPDATE public.profiles SET role='admin' WHERE id='${u(102)}' RETURNING id`)).rows.length,0); checks++;
    assert.equal((await db.query(`UPDATE public.visits SET status='cancelled' WHERE id='${u(701)}' RETURNING id`)).rows.length,0); checks++;
    assert.equal((await db.query(`UPDATE public.visit_reports SET findings='tamper' WHERE id='${u(901)}' RETURNING id`)).rows.length,0); checks++;
    await denied(`INSERT INTO public.visit_reports(tenant_id,visit_id,technician_id) VALUES ('${u(1)}','${u(702)}','${u(102)}')`);
    await db.exec(`INSERT INTO public.visit_reports(id,tenant_id,visit_id,technician_id,findings)
      VALUES ('${u(904)}','${u(1)}','${u(703)}','${u(102)}','draft finding')`); checks++;
    await db.exec(`UPDATE public.visit_reports SET findings='ready',status='submitted' WHERE id='${u(904)}'`); checks++;
    assert.equal((await db.query(`SELECT submitted_at IS NOT NULL AS ok FROM public.visit_reports WHERE id='${u(904)}'`)).rows[0].ok,true); checks++;
    assert.equal((await db.query(`DELETE FROM public.visit_reports WHERE id='${u(904)}' RETURNING id`)).rows.length,0); checks++;
  });
  await asUser(103, async () => {
    await expectCount('clients',1); await expectCount('client_sites',1); await expectCount('visit_reports',2);
    await expectCount('visits',2); await expectCount('invoices',1); await expectCount('profiles',1);
    await expectCount('surveys',0); await expectCount('pricing_matrix',0);
    assert.equal((await db.query(`UPDATE public.profiles SET role='admin',client_id=NULL,portal_enabled=false WHERE id='${u(103)}' RETURNING id`)).rows.length,0); checks++;
    await denied(`INSERT INTO public.profiles(id,tenant_id,role,full_name) VALUES ('${u(999)}','${u(1)}','admin','Escalation')`);
  });
  await asUser(104, async () => {
    for (const table of ['profiles','clients','client_sites','visits','visit_reports','contracts','invoices']) await expectCount(table,0);
  });
  await asUser(105, async () => { await expectCount('visit_reports',0); await expectCount('visits',1); });
  await asUser(201, async () => { await expectCount('clients',1); await expectCount('visits',1); });
  await asUser(203, async () => { await expectCount('clients',1); await expectCount('visit_reports',1); });
  await asUser(999, async () => { await expectCount('profiles',0); await expectCount('clients',0); });
  await db.exec(`UPDATE public.profiles SET portal_enabled=false WHERE id='${u(103)}'`);
  await asUser(103, async () => { await expectCount('visit_reports',0); await expectCount('clients',0); });
  await db.exec(`UPDATE public.tenants SET is_active=false WHERE id='${u(1)}'`);
  await asUser(101, async () => { await expectCount('clients',0); });
  await asUser(102, async () => { await expectCount('visits',0); });
  await db.exec('SET ROLE anon');
  await denied('SELECT * FROM public.clients');
  await denied('SELECT * FROM public.visit_reports');
  await db.exec('RESET ROLE');
  assert.equal((await db.query(`SELECT count(*)::int AS n FROM pg_class c JOIN pg_namespace n ON c.relnamespace=n.oid
    WHERE n.nspname='public' AND c.relkind='r' AND c.relrowsecurity AND c.relforcerowsecurity`)).rows[0].n,11); checks++;
  console.log(`PASS: ${checks} local PostgreSQL schema/RLS assertions. Supabase auth.uid() is mocked; no remote DB touched.`);
  await db.close();
})().catch(error => { console.error(error); process.exitCode = 1; });

// Local PostgreSQL tests with mocked Auth/Storage schemas. No network.
const { PGlite } = require('@electric-sql/pglite');
const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');
const u = n => `00000000-0000-0000-0000-${String(n).padStart(12, '0')}`;
(async () => {
  const db = new PGlite();
  let checks = 0;
  await db.exec(`CREATE ROLE anon; CREATE ROLE authenticated; CREATE ROLE service_role BYPASSRLS;
    CREATE SCHEMA auth; CREATE TABLE auth.users(id uuid PRIMARY KEY);
    CREATE FUNCTION auth.uid() RETURNS uuid LANGUAGE sql STABLE AS $$ SELECT nullif(current_setting('request.jwt.claim.sub',true),'')::uuid $$;
    GRANT USAGE ON SCHEMA public,auth TO anon,authenticated; GRANT EXECUTE ON FUNCTION auth.uid() TO anon,authenticated;
    CREATE SCHEMA storage;
    CREATE TABLE storage.buckets(id text PRIMARY KEY,name text,public boolean,file_size_limit bigint,allowed_mime_types text[]);
    CREATE TABLE storage.objects(id uuid PRIMARY KEY DEFAULT gen_random_uuid(),bucket_id text,name text);
    ALTER TABLE storage.objects ENABLE ROW LEVEL SECURITY;
    GRANT USAGE ON SCHEMA storage TO authenticated,anon;
    GRANT SELECT,INSERT,UPDATE,DELETE ON storage.objects TO authenticated;`);
  for (const file of ['phase1_schema.sql','phase2_integration.sql']) {
    await db.exec(fs.readFileSync(path.join(__dirname, '..', file), 'utf8')); checks++;
  }
  const company = (await db.query("SELECT id FROM public.tenants WHERE slug='ikill'")).rows[0].id;
  await db.exec(`INSERT INTO auth.users(id) VALUES ('${u(1)}'),('${u(2)}'),('${u(3)}'),('${u(4)}');
    INSERT INTO public.clients(id,tenant_id,client_code,display_name) VALUES ('${u(10)}','${company}','customer','Customer');
    INSERT INTO public.profiles(id,tenant_id,role,full_name,client_id,portal_enabled) VALUES
    ('${u(1)}','${company}','admin','Admin',NULL,false),
    ('${u(2)}','${company}','technician','Tech',NULL,false),
    ('${u(3)}','${company}','client','Portal','${u(10)}',true),
    ('${u(4)}','${company}','client','Disabled','${u(10)}',false);
    INSERT INTO public.client_sites(id,tenant_id,client_id,name,sector,address) VALUES ('${u(20)}','${company}','${u(10)}','Site','food','Address');
    INSERT INTO public.visits(id,tenant_id,client_id,site_id,technician_id,scheduled_start,scheduled_end) VALUES
    ('${u(30)}','${company}','${u(10)}','${u(20)}','${u(2)}',now(),now()+interval '1 hour');`);
  const image = `${company}/${u(30)}/photo.png`;
  const check = async (query, expected) => { assert.equal((await db.query(query)).rows[0].ok, expected); checks++; };
  const user = async (id, fn) => {
    await db.exec(`SET ROLE authenticated; SELECT set_config('request.jwt.claim.sub','${u(id)}',false)`);
    try { await fn(); } finally { await db.exec("RESET ROLE; SELECT set_config('request.jwt.claim.sub','',false)"); }
  };
  await user(2, async () => {
    await check(`SELECT app_private.can_write_file('visit-images','${image}') AS ok`, true);
    await check(`SELECT app_private.can_write_file('visit-images','${u(999)}/${u(30)}/photo.png') AS ok`, false);
    await db.exec(`INSERT INTO storage.objects(bucket_id,name) VALUES ('visit-images','${image}')`); checks++;
  });
  await user(3, async () => {
    await check(`SELECT app_private.can_read_file('visit-images','${image}') AS ok`, false);
    await check(`SELECT app_private.can_write_file('visit-images','${image}') AS ok`, false);
  });
  await db.exec(`INSERT INTO public.visit_reports(tenant_id,visit_id,technician_id,status,photo_paths)
    VALUES ('${company}','${u(30)}','${u(2)}','submitted',ARRAY['${image}'])`);
  await user(2, async () => {
    await check(`SELECT app_private.can_write_file('visit-images','${image}') AS ok`, false);
    assert.equal((await db.query(`DELETE FROM storage.objects WHERE name='${image}' RETURNING id`)).rows.length,0); checks++;
  });
  await user(3, async () => {
    await check(`SELECT app_private.can_read_file('visit-images','${image}') AS ok`, true);
    await check(`SELECT app_private.can_read_file('visit-images','${company}/${u(30)}/unpublished.png') AS ok`, false);
  });
  await user(4, async () => {
    await check("SELECT (public.get_my_profile()->>'portal_enabled')::boolean AS ok", false);
    await check(`SELECT app_private.can_read_file('visit-images','${image}') AS ok`, false);
    assert.equal((await db.query('SELECT * FROM public.profiles')).rows.length,0); checks++;
  });
  await user(1, async () => {
    await check(`SELECT app_private.can_write_file('visit-images','${image}') AS ok`, true);
  });
  await db.exec('SET ROLE anon');
  await check("SELECT public.get_public_brand('ikill')->>'name'='iKILL' AS ok", true);
  for (let i=0;i<5;i++) {
    await db.exec("SELECT public.submit_contact_request('ikill','Test','','test@example.com','Address','Pest control','Message')"); checks++;
  }
  await assert.rejects(() => db.exec("SELECT public.submit_contact_request('ikill','Test','','test@example.com','Address','Pest control','Message')")); checks++;
  await assert.rejects(() => db.exec('SELECT * FROM public.clients')); checks++;
  await assert.rejects(() => db.exec('SELECT public.get_my_profile()')); checks++;
  await db.exec('RESET ROLE');
  await check('SELECT bool_and(NOT public) AS ok FROM storage.buckets', true);
  await db.close();
  console.log(`PASS: ${checks} phase2 local schema, portal, contact quota and private Storage assertions.`);
})().catch(e => { console.error(e); process.exitCode=1; });

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
  for (const file of ['phase1_schema.sql','phase2_integration.sql','phase3_requests.sql','phase4_instapay_qr.sql']) {
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

  const rpc = async (name,args) => (await db.query(`SELECT public.${name}(${args.map((_,i)=>'$'+(i+1)).join(',')}) result`,args)).rows[0].result;
  const role = async (name,id,fn) => {await db.exec(`SET ROLE ${name};SELECT set_config('request.jwt.claim.sub','${id||''}',false)`);try{return await fn()}finally{await db.exec("RESET ROLE;SELECT set_config('request.jwt.claim.sub','',false)")}};
  const fail=async fn=>{await assert.rejects(fn);checks++};
  const current=company+'/current.png', replacement=company+'/replacement.jpg';
  await role('anon',null,async()=>{assert.equal(await rpc('get_instapay_settings',['ikill']),null);checks++;
    await fail(()=>rpc('save_instapay_settings',[current,'Receiver',true]));
    await fail(()=>db.query('SELECT * FROM app_payment_settings'));
    await fail(()=>db.query("INSERT INTO storage.objects(bucket_id,name) VALUES ('instapay-qr',$1)",[current]));
  });
  await role('authenticated',u(2),()=>fail(()=>rpc('save_instapay_settings',[current,'Receiver',true])));
  await role('authenticated',u(1),async()=>{
    await fail(()=>rpc('save_instapay_settings',[null,'Receiver',true]));
    await fail(()=>rpc('save_instapay_settings',[current,'Receiver',true]));
    await db.query("INSERT INTO storage.objects(bucket_id,name) VALUES ('instapay-qr',$1),('instapay-qr',$2)",[current,replacement]);checks++;
    await fail(()=>rpc('save_instapay_settings',[current,'',true]));
    await fail(()=>rpc('save_instapay_settings',[u(999)+'/foreign.png','Receiver',true]));
    await rpc('save_instapay_settings',[current,'Receiver',true]);checks++;
  });
  await role('anon',null,async()=>{
    assert.equal((await rpc('get_instapay_settings',['ikill'])).qr_path,current);checks++;
    assert.equal((await db.query("SELECT * FROM storage.objects WHERE bucket_id='instapay-qr'")).rows.length,1);checks++;
    assert.equal(await rpc('can_read_instapay_qr',[replacement]),false);checks++;
  });
  await role('authenticated',u(1),async()=>{
    assert.equal((await db.query("DELETE FROM storage.objects WHERE name=$1 RETURNING id",[current])).rows.length,0);checks++;
    await rpc('save_instapay_settings',[replacement,'Receiver',true]);checks++;
    assert.equal((await db.query("DELETE FROM storage.objects WHERE name=$1 RETURNING id",[current])).rows.length,1);checks++;
    await rpc('save_instapay_settings',[replacement,'Receiver',false]);checks++;
  });
  await role('anon',null,async()=>{assert.equal(await rpc('get_instapay_settings',['ikill']),null);checks++;
    assert.equal((await db.query("SELECT * FROM storage.objects WHERE bucket_id='instapay-qr'")).rows.length,0);checks++;
  });
  console.log(`Phase4 QR: ${checks} assertions passed`);await db.close();
})().catch(e=>{console.error(e);process.exit(1)});

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
  for (const file of ['phase1_schema.sql','phase2_integration.sql','phase3_requests.sql','phase4_instapay_qr.sql','phase5_client_contract_lifecycle.sql']) {
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


  const rpc=async(name,args)=>(await db.query(`SELECT public.${name}(${args.map((_,i)=>'$'+(i+1)).join(',')}) result`,args)).rows[0].result;
  const role=async(id,fn)=>{await db.exec(`SET ROLE authenticated;SELECT set_config('request.jwt.claim.sub','${u(id)}',false)`);try{return await fn()}finally{await db.exec("RESET ROLE;SELECT set_config('request.jwt.claim.sub','',false)")}};
  const fail=async fn=>{await assert.rejects(fn);checks++};
  await db.exec(`UPDATE clients SET client_type='contract',status='survey_pending' WHERE id='${u(10)}';
    INSERT INTO client_sites(id,tenant_id,client_id,name,sector,address,contact_phone) VALUES('${u(21)}','${company}','${u(10)}','Site two','factory','Address','01020019042');
    INSERT INTO surveys(tenant_id,client_id,site_id,status,proposed_total) VALUES('${company}','${u(10)}','${u(20)}','completed',100),('${company}','${u(10)}','${u(21)}','completed',200);`);
  const plans=[{site_id:u(20),visits_per_month:1},{site_id:u(21),visits_per_month:2}];
  await role(2,()=>fail(()=>rpc('save_client_contract',[u(100),u(10),'2028-01-15','2028-03-20',1000,'monthly',plans])));
  await role(1,async()=>{
    await fail(()=>rpc('save_client_contract',[u(100),u(10),'2028-01-15','2028-03-20',-1,'monthly',plans]));
    await fail(()=>rpc('save_client_contract',[u(100),u(10),'2028-01-15','2028-03-20',1000,'monthly',[...plans,plans[0]]]));
    await rpc('save_client_contract',[u(100),u(10),'2028-01-15','2028-03-20',1000,'monthly',plans]);checks++;
    await fail(()=>rpc('activate_client_contract',[u(100),'','ref']));
    assert.equal(await rpc('activate_client_contract',[u(100),'Representative','Signed paper 123']),9);checks++;
    assert.equal(await rpc('activate_client_contract',[u(100),'Representative','Signed paper 123']),9);checks++;
    await fail(()=>rpc('save_client_contract',[u(100),u(10),'2028-01-15','2028-03-20',1000,'monthly',plans]));
    await fail(()=>db.query("UPDATE contracts SET status='draft' WHERE id=$1",[u(100)]));
    await fail(()=>db.query('UPDATE contracts SET billing_amount=5 WHERE id=$1',[u(100)]));
    await rpc('save_client_contract',[u(101),u(10),'2028-03-01','2028-04-30',1000,'quarterly',plans]);
    await fail(()=>rpc('activate_client_contract',[u(101),'Rep','Ref']));
  });
  const visits=(await db.query('SELECT * FROM visits WHERE contract_id=$1 ORDER BY scheduled_start',[u(100)])).rows;
  assert.equal(visits.length,9);checks++;
  assert.equal((await db.query('SELECT status FROM clients WHERE id=$1',[u(10)])).rows[0].status,'active');checks++;
  assert.equal(visits.filter(v=>v.site_id===u(20)).length,3);checks++;
  assert.equal(visits.filter(v=>v.site_id===u(21)).length,6);checks++;
  assert.ok(visits.every(v=>new Date(v.scheduled_start)>=new Date('2028-01-15')&&new Date(v.scheduled_start)<new Date('2028-03-21')));checks++;
  await role(1,async()=>{
    await rpc('reschedule_contract_visit',[visits[0].id,'2028-01-16T12:00:00Z','2028-01-16T13:00:00Z',u(2)]);checks++;
    await fail(()=>rpc('reschedule_contract_visit',[visits[0].id,'2029-01-16T12:00:00Z','2029-01-16T13:00:00Z',u(2)]));
    await fail(()=>rpc('reschedule_contract_visit',[visits[0].id,'2028-01-16T12:00:00Z','2028-01-16T13:00:00Z',u(1)]));
    await fail(()=>rpc('reschedule_contract_visit',[u(30),'2028-01-16T12:00:00Z','2028-01-16T13:00:00Z',u(2)]));
    await rpc('save_client_contract',[u(102),u(10),'2028-05-31','2028-05-31',1000,'annual',plans]);
    await fail(()=>rpc('activate_client_contract',[u(102),'Rep','Ref']));
  });
  assert.equal((await db.query('SELECT count(*)::int n FROM visits WHERE contract_id=$1',[u(102)])).rows[0].n,0);checks++;
  assert.equal((await db.query('SELECT status FROM contracts WHERE id=$1',[u(102)])).rows[0].status,'draft');checks++;
  await role(2,()=>fail(()=>rpc('activate_client_contract',[u(100),'Rep','Ref'])));
  await role(3,async()=>{assert.equal((await db.query('SELECT * FROM contract_site_plans')).rows.length,0);checks++;});
  await db.exec(`INSERT INTO tenants(id,slug,name) VALUES('${u(900)}','foreign','Foreign');INSERT INTO clients(id,tenant_id,client_code,display_name,client_type) VALUES('${u(901)}','${u(900)}','foreign','Foreign','contract');`);
  await role(1,()=>fail(()=>rpc('save_client_contract',[u(110),u(901),'2028-01-01','2028-12-31',1000,'annual',plans])));
  assert.ok((await db.query("SELECT extract(hour FROM scheduled_start AT TIME ZONE 'Africa/Cairo')::int h FROM visits WHERE contract_id=$1 AND id<>$2",[u(100),visits[0].id])).rows.every(r=>r.h===10));checks++;
  await db.exec(`INSERT INTO client_sites(id,tenant_id,client_id,name,sector,address) VALUES('${u(22)}','${company}','${u(10)}','Unsurveyed','factory','Address');`);
  await role(1,async()=>{
    await rpc('save_client_contract',[u(103),u(10),'2029-01-01','2029-01-31',1000,'annual',plans]);
    await fail(()=>rpc('activate_client_contract',[u(103),'Rep','Ref']));
    await rpc('save_client_contract',[u(103),u(10),'2029-01-01','2029-01-31',1000,'annual',[...plans,{site_id:u(22),visits_per_month:1}]]);
    await fail(()=>rpc('activate_client_contract',[u(103),'Rep','Ref']));
  });
  assert.equal((await db.query('SELECT count(*)::int n FROM visits WHERE contract_id=$1',[u(103)])).rows[0].n,0);checks++;
  await db.exec('SET ROLE anon');
  await fail(()=>rpc('activate_client_contract',[u(100),'Rep','Ref']));
  await db.exec('RESET ROLE');
  console.log(`Lifecycle: ${checks} assertions passed`);await db.close();
})().catch(e=>{console.error(e);process.exit(1)});

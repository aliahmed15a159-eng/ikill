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
  for (const file of ['phase1_schema.sql','phase2_integration.sql','phase3_requests.sql','phase4_instapay_qr.sql','phase5_client_contract_lifecycle.sql','phase6_operations.sql','phase7_field_reports.sql']) {
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



  const role=async(id,fn)=>{await db.exec(`SET ROLE authenticated;SELECT set_config('request.jwt.claim.sub','${u(id)}',false)`);try{return await fn()}finally{await db.exec("RESET ROLE;SELECT set_config('request.jwt.claim.sub','',false)")}};
  const fail=async fn=>{await assert.rejects(fn);checks++};
  const scalar=async(name,args=[])=>(await db.query(`SELECT public.${name}(${args.map((_,i)=>'$'+(i+1)).join(',')}) result`,args)).rows[0]?.result;
  const key='a'.repeat(32), prefix=`${company}/${u(30)}/${key}/`;
  const payload=[u(30),key,JSON.stringify({pest:'rodents',severity:'low',actions:['inspection'],signature_consent:true}),'None','Notes',[prefix+'photo-1.jpg'],prefix+'signature.png','Site rep'];
  await role(1,()=>fail(()=>scalar('get_my_field_visits',[0])));
  await role(3,()=>fail(()=>scalar('get_my_field_visits',[0])));
  await role(2,async()=>{
    assert.equal((await db.query('SELECT * FROM get_my_field_visits(0)')).rows.length,1);checks++;
    await fail(()=>scalar('submit_field_report',payload));
    await scalar('set_my_visit_state',[u(30),'in_progress']);checks++;
    await fail(()=>scalar('set_my_visit_state',[u(30),'completed']));
    await fail(()=>db.query('INSERT INTO visit_reports(tenant_id,visit_id,technician_id) VALUES($1,$2,$3)',[company,u(30),u(2)]));
    await fail(()=>scalar('submit_field_report',payload));
  });
  assert.equal((await db.query('SELECT status FROM visits WHERE id=$1',[u(30)])).rows[0].status,'in_progress');checks++;
  assert.equal((await db.query('SELECT count(*) n FROM visit_reports')).rows[0].n,0);checks++;
  await db.query("INSERT INTO storage.objects(bucket_id,name) VALUES('visit-images',$1),('visit-signatures',$2)",[prefix+'photo-1.jpg',prefix+'signature.png']);
  await role(2,async()=>{
    await fail(()=>scalar('submit_field_report',[...payload.slice(0,2),JSON.stringify({pest:'invalid',severity:'low',actions:['inspection'],signature_consent:true}),...payload.slice(3)]));
    await fail(()=>scalar('submit_field_report',[...payload.slice(0,5),['other-tenant/photo.jpg'],...payload.slice(6)]));
    const id=await scalar('submit_field_report',payload);assert.ok(id);checks++;
    assert.equal(await scalar('submit_field_report',payload),id);checks++;
    assert.equal(await scalar('my_field_report_receipt',[u(30),key]),id);checks++;
    await fail(()=>scalar('submit_field_report',[u(30),'b'.repeat(32),...payload.slice(2)]));
    assert.equal(await scalar('my_field_report_receipt',[u(30),'b'.repeat(32)]),null);checks++;
    assert.equal((await db.query('SELECT * FROM get_my_field_visits(0)')).rows.length,0);checks++;
    assert.equal((await db.query('SELECT app_private.can_write_file($1,$2) allowed',['visit-signatures',prefix+'signature.png'])).rows[0].allowed,false);checks++;
    const changed=await db.query("UPDATE visit_reports SET findings='tampered' RETURNING id");assert.equal(changed.rows.length,0);checks++;
    assert.equal((await db.query("UPDATE storage.objects SET name=name WHERE name=$1 RETURNING id",[prefix+'signature.png'])).rows.length,0);checks++;
  });
  assert.equal((await db.query('SELECT status FROM visits WHERE id=$1',[u(30)])).rows[0].status,'completed');checks++;
  const report=(await db.query('SELECT * FROM visit_reports')).rows[0];assert.ok(report.signed_at);assert.ok(report.submitted_at);checks+=2;
  await role(3,async()=>{assert.equal(await scalar('my_field_report_receipt',[u(30),key]),null);checks++;await fail(()=>scalar('submit_field_report',payload));});
  await db.exec('SET ROLE anon');await fail(()=>scalar('get_my_field_visits',[0]));await db.exec('RESET ROLE');
  console.log(`Field reports: ${checks} assertions passed`);await db.close();
})().catch(e=>{console.error(e);process.exit(1)});

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
  for (const file of ['phase1_schema.sql','phase2_integration.sql','phase3_requests.sql','phase4_instapay_qr.sql','phase5_client_contract_lifecycle.sql','phase6_operations.sql']) {
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



  const rpc=async(name,args=[])=>(await db.query(`SELECT public.${name}(${args.map((_,i)=>'$'+(i+1)).join(',')}) result`,args)).rows;
  const role=async(id,fn)=>{await db.exec(`SET ROLE authenticated;SELECT set_config('request.jwt.claim.sub','${u(id)}',false)`);try{return await fn()}finally{await db.exec("RESET ROLE;SELECT set_config('request.jwt.claim.sub','',false)")}};
  const fail=async fn=>{await assert.rejects(fn);checks++};
  const scalar=async(name,args=[])=>(await rpc(name,args))[0].result;
  await db.exec(`INSERT INTO auth.users(id) VALUES('${u(5)}');INSERT INTO profiles(id,tenant_id,role,full_name) VALUES('${u(5)}','${company}','technician','Tech Two');
    INSERT INTO visits(id,tenant_id,client_id,site_id,status) VALUES('${u(40)}','${company}','${u(10)}','${u(20)}','pending_schedule');
    INSERT INTO visits(id,tenant_id,client_id,site_id,status,scheduled_start,scheduled_end) VALUES
    ('${u(41)}','${company}','${u(10)}','${u(20)}','scheduled',now()+interval '2 days',now()+interval '2 days 1 hour'),
    ('${u(42)}','${company}','${u(10)}','${u(20)}','scheduled',now()+interval '3 days',now()+interval '3 days 1 hour');
    INSERT INTO surveys(tenant_id,client_id,site_id,status) VALUES('${company}','${u(10)}','${u(20)}','survey_pending');
    INSERT INTO invoices(tenant_id,client_id,invoice_number,issued_on,due_on,subtotal,amount_paid,status) VALUES
    ('${company}','${u(10)}','issued',current_date,current_date,100,25,'issued'),
    ('${company}','${u(10)}','draft',current_date,current_date,100,0,'draft'),
    ('${company}','${u(10)}','void',current_date,current_date,100,0,'void');`);
  await role(1,async()=>{
    const summary=await scalar('get_operations_summary');assert.equal(summary.new_surveys,1);assert.equal(summary.pending_schedule,1);assert.equal(summary.unpaid_invoices,1);checks+=3;
    const context=await scalar('get_operations_context');assert.equal(context.technicians.length,2);checks++;
    const first=summary.today,last=(new Date(new Date(first).getTime()+7*86400000)).toISOString().slice(0,10);
    assert.equal((await rpc('get_operations_visits',[first,last,null,null,null,0])).length,3);checks++;
    assert.equal((await rpc('get_operations_visits',[first,last,u(999),null,null,0])).length,0);checks++;
    await fail(()=>rpc('get_operations_visits',[first,first,null,null,null,0]));
    await fail(()=>rpc('assign_operations_technician',[u(41),u(1)]));
    await scalar('assign_operations_technician',[u(41),u(2)]);checks++;
    assert.equal(await scalar('assign_site_technician',[u(20),u(5)]),3);checks++;
  });
  assert.equal((await db.query('SELECT technician_id FROM visits WHERE id=$1',[u(30)])).rows[0].technician_id,u(2));checks++;
  await db.exec(`INSERT INTO visits(id,tenant_id,client_id,site_id,status,scheduled_start,scheduled_end) VALUES('${u(43)}','${company}','${u(10)}','${u(20)}','scheduled',now()+interval '4 days',now()+interval '4 days 1 hour')`);
  assert.equal((await db.query('SELECT technician_id FROM visits WHERE id=$1',[u(43)])).rows[0].technician_id,u(5));checks++;
  await role(2,async()=>{
    await fail(()=>rpc('get_operations_summary'));
    await fail(()=>rpc('assign_site_technician',[u(20),u(2)]));
    await fail(()=>rpc('set_my_visit_state',[u(41),'in_progress']));
    await scalar('set_my_visit_state',[u(30),'in_progress']);checks++;
    await scalar('set_my_visit_state',[u(30),'in_progress']);checks++;
  });
  await role(1,async()=>{
    assert.equal((await scalar('get_operations_summary')).in_progress,1);checks++;
    await fail(()=>rpc('assign_operations_technician',[u(30),u(5)]));
    await fail(()=>rpc('set_my_visit_state',[u(30),'completed']));
  });
  await role(2,async()=>{await scalar('set_my_visit_state',[u(30),'completed']);await scalar('set_my_visit_state',[u(30),'completed']);checks+=2;});
  await role(1,async()=>{
    assert.equal((await scalar('get_operations_summary')).completed,1);checks++;
    await scalar('assign_operations_technician',[u(41),null]);checks++;
  });
  await role(5,()=>fail(()=>rpc('set_my_visit_state',[u(42),'in_progress'])));
  await role(3,()=>fail(()=>rpc('get_operations_context')));
  await db.exec(`INSERT INTO tenants(id,slug,name) VALUES('${u(900)}','other','Other');INSERT INTO client_sites(id,tenant_id,client_id,name,sector,address) SELECT '${u(901)}',tenant_id,client_id,'Other site','food','Address' FROM client_sites WHERE false;`);
  await role(1,()=>fail(()=>rpc('assign_site_technician',[u(999),u(2)])));
  await db.exec('SET ROLE anon');await fail(()=>rpc('get_operations_summary'));await fail(()=>rpc('set_my_visit_state',[u(30),'completed']));await db.exec('RESET ROLE');
  assert.ok((await db.query("SELECT tablename FROM pg_publication_tables WHERE pubname='supabase_realtime'")).rows.some(r=>r.tablename==='visits'));checks++;
  console.log(`Operations: ${checks} assertions passed`);await db.close();
})().catch(e=>{console.error(e);process.exit(1)});

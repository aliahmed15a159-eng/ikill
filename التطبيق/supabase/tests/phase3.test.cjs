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
  for (const file of ['phase1_schema.sql','phase2_integration.sql','phase3_requests.sql']) {
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

  const rpc = async (name, args) => (await db.query(`SELECT public.${name}(${args.map((_,i)=>'$'+(i+1)).join(',')}) AS result`,args)).rows[0].result;
  const role = async (name,id,fn) => { await db.exec(`SET ROLE ${name}; SELECT set_config('request.jwt.claim.sub','${id || ''}',false)`); try { return await fn(); } finally { await db.exec("RESET ROLE; SELECT set_config('request.jwt.claim.sub','',false)"); } };
  const fail = async fn => { await assert.rejects(fn); checks++; };
  await role('authenticated',u(2),()=>fail(()=>rpc('save_residential_price',['house','rodents',100,true])));
  await role('authenticated',u(1),async()=>{
    for(const property of ['apartment','villa','house']) for(const problem of ['cockroaches','rodents','bed_bugs','general_pests']) {
      await rpc('save_residential_price',[property,problem,250,true]);checks++;
    }
    await fail(()=>rpc('save_residential_price',['house','rodents',0,true]));
    await fail(()=>rpc('save_residential_price',['house','rodents',1.234,true]));
  });
  await role('anon',null,async()=>{
    const quote=await rpc('get_residential_quote',['ikill','house','rodents']);assert.equal(quote.amount,250);checks++;
    const payload={kind:'residential',name:'Customer',phone:'01020019042',email:'test@example.com',address:'Assiut address',message:'',consent:true,property:'house',problem:'rodents',price_id:quote.price_id,expected_amount:quote.amount,expected_currency:quote.currency,payment_reference:'Transfer reference 123'};
    const result=await rpc('submit_app_request',['ikill',u(100),payload]);assert.equal(result.status,'pending_schedule');assert.equal(result.payment_status,'pending_review');checks+=2;
    assert.deepEqual(await rpc('submit_app_request',['ikill',u(100),payload]),result);checks++;
    await fail(()=>rpc('submit_app_request',['ikill',u(100),{...payload,name:'Different'}]));
    await fail(()=>rpc('submit_app_request',['ikill',u(101),{...payload,expected_amount:1}]));
    await fail(()=>rpc('submit_app_request',['ikill',u(102),{...payload,payment_review:'verified'}]));
    await fail(()=>rpc('submit_app_request',['ikill',u(103),{...payload,consent:false}]));
    const business={kind:'contract',name:'Contact',phone:'01020019042',email:'business@example.com',address:'Factory address',facility:'Factory',sector:'factory',message:'Please call',consent:true};
    assert.equal((await rpc('submit_app_request',['ikill',u(104),business])).status,'survey_pending');checks++;
    await fail(()=>db.query('SELECT * FROM public.clients'));
    await fail(()=>db.query('SELECT * FROM public.app_request_receipts'));
    await fail(()=>rpc('review_residential_payment',[u(30),true]));
  });
  const visit=(await db.query("SELECT * FROM public.visits WHERE status='pending_schedule'")).rows[0];
  assert.equal(visit.scheduled_start,null);assert.equal(visit.quoted_amount,'250.00');checks+=2;
  assert.equal((await db.query("SELECT count(*)::int n FROM public.clients WHERE email='test@example.com'")).rows[0].n,1);checks++;
  assert.equal((await db.query("SELECT client_type FROM public.clients WHERE email='business@example.com'")).rows[0].client_type,'contract');checks++;
  await role('authenticated',u(2),()=>fail(()=>rpc('review_residential_payment',[visit.id,true])));
  await role('authenticated',u(1),async()=>{
    const start=new Date(Date.now()+86400000).toISOString(), end=new Date(Date.now()+90000000).toISOString();
    await fail(()=>rpc('schedule_app_visit',[visit.id,start,end,u(2)]));
    await rpc('review_residential_payment',[visit.id,true]);checks++;
    await rpc('schedule_app_visit',[visit.id,start,end,u(2)]);checks++;
    await fail(()=>rpc('review_residential_payment',[visit.id,true]));
  });
  assert.equal((await db.query('SELECT status FROM public.visits WHERE id=$1',[visit.id])).rows[0].status,'scheduled');checks++;
  console.log(`Phase3: ${checks} assertions passed`);await db.close();
})().catch(e=>{console.error(e);process.exit(1)});

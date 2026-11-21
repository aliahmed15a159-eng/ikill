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
  for (const file of ['phase1_schema.sql','phase2_integration.sql','phase3_requests.sql','phase4_instapay_qr.sql','phase5_client_contract_lifecycle.sql','phase6_operations.sql','phase7_field_reports.sql','phase8_billing_documents_portal.sql','phase8b_document_integrity.sql','phase8c_legacy_documents.sql','phase9_notifications_payments.sql']) {
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
  const eq=(a,b)=>{assert.deepEqual(a,b);checks++};
  await db.exec(fs.readFileSync(path.join(__dirname,'../phase10_fcm_transport.sql'),'utf8'));
  await db.exec(fs.readFileSync(path.join(__dirname,'../phase10a_fcm_webhook_timeout.sql'),'utf8'));
  await db.exec("ALTER TABLE auth.users ADD COLUMN raw_user_meta_data jsonb DEFAULT '{}'::jsonb; ALTER TABLE auth.users ADD COLUMN email text;");
  await db.exec(fs.readFileSync(path.join(__dirname,'../phase11_customer_auth.sql'),'utf8'));
  eq((await role(1,()=>scalar('get_my_profile'))).role,'admin');
  eq((await role(2,()=>scalar('get_my_profile'))).role,'technician');
  eq((await role(3,()=>scalar('get_my_profile'))).role,'client');
  await db.query("INSERT INTO auth.users(id,email,raw_user_meta_data) VALUES($1,'new@example.invalid',$2)",[u(50),JSON.stringify({full_name:'Google Customer',role:'admin',tenant_id:u(999),portal_enabled:true,client_id:u(10),phone:'+201020019042',phone_completed_at:'2026-01-01'})]);
  let profile=(await db.query('SELECT * FROM profiles WHERE id=$1',[u(50)])).rows[0];
  eq(profile.role,'customer');eq(profile.tenant_id,company);eq(profile.client_id,null);eq(profile.portal_enabled,false);eq(profile.phone,null);eq(profile.phone_completed_at,null);
  await role(50,async()=>{
    eq((await scalar('get_my_profile')).profile_incomplete,true);
    eq((await db.query('SELECT * FROM profiles')).rows.length,1);
    eq((await db.query("UPDATE profiles SET role='admin' WHERE id=$1 RETURNING id",[u(50)])).rows.length,0);
    eq((await db.query('SELECT * FROM clients')).rows.length,0);eq((await db.query('SELECT * FROM invoices')).rows.length,0);eq((await db.query('SELECT * FROM contracts')).rows.length,0);eq((await db.query('SELECT * FROM visits')).rows.length,0);
    await fail(()=>scalar('attach_portal_profile',[company,u(10),u(50)]));
    await fail(()=>scalar('complete_customer_profile',['A','123']));
    await fail(()=>scalar('register_my_fcm',['bad-token','a'.repeat(64)]));
    await fail(()=>scalar('submit_app_request',['ikill',u(70),'{}']));
    await scalar('complete_customer_profile',['Google Customer','٠١٠٢٠٠١٩٠٤٢']);
    const me=await scalar('get_my_profile');eq(me.phone,'+201020019042');eq(me.profile_incomplete,false);eq(me.role,'customer');
  });
  const stamp=(await db.query('SELECT phone_completed_at FROM profiles WHERE id=$1',[u(50)])).rows[0].phone_completed_at;
  await role(50,()=>scalar('complete_customer_profile',['Google Customer','+20 1020019042']));
  eq((await db.query('SELECT phone_completed_at FROM profiles WHERE id=$1',[u(50)])).rows[0].phone_completed_at,stamp);
  await db.query('UPDATE auth.users SET raw_user_meta_data=$1 WHERE id=$2',[JSON.stringify({role:'admin',portal_enabled:true}),u(50)]);
  eq((await db.query('SELECT role FROM profiles WHERE id=$1',[u(50)])).rows[0].role,'customer');
  const payload={kind:'contract',name:'Customer',phone:'01020019042',email:'new@example.invalid',address:'Assiut',message:'Survey',consent:true,facility:'Factory',sector:'factory'};
  const receipt=await role(50,()=>scalar('submit_app_request',['ikill',u(70),JSON.stringify(payload)]));eq(receipt.status,'survey_pending');
  await db.query('UPDATE profiles SET is_active=false WHERE id=$1',[u(50)]);
  await role(50,()=>fail(()=>scalar('complete_customer_profile',['Other','+201020019042'])));
  await role(50,()=>fail(()=>scalar('submit_app_request',['ikill',u(71),JSON.stringify(payload)])));
  await db.query('UPDATE profiles SET is_active=true WHERE id=$1',[u(50)]);
  await db.exec("SET ROLE anon");
  eq(Object.keys(await scalar('get_auth_brand',['ikill'])).sort(),['company_name','logo_path','primary_hex']);
  await fail(()=>scalar('complete_customer_profile',['Attacker','+201020019042']));
  await fail(()=>db.query('SELECT * FROM app_private.signup_tenant'));
  await db.exec('RESET ROLE');
  // Admin's existing account provisioning promotes only a default customer, service-only.
  await db.query("INSERT INTO clients(id,tenant_id,client_code,display_name) VALUES($1,$2,'auth-test-client','Contract client')",[u(80),company]);
  await db.query("INSERT INTO auth.users(id,email) VALUES($1,'portal@example.invalid')",[u(81)]);
  eq((await db.query('SELECT role FROM profiles WHERE id=$1',[u(81)])).rows[0].role,'customer');
  await scalar('attach_portal_profile',[company,u(80),u(81)]);
  eq((await role(81,()=>scalar('get_my_profile'))).role,'client');eq((await role(81,()=>scalar('get_my_profile'))).portal_enabled,false);
  await fail(()=>scalar('attach_portal_profile',[company,u(10),u(1)]));
  eq((await role(1,()=>scalar('get_my_profile'))).role,'admin');
  console.log(`PASS: ${checks} signup/onboarding/role security/auth branding assertions`);await db.close();
})().catch(e=>{console.error(e);process.exit(1)});

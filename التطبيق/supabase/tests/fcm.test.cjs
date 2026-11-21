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
  const token='fcm_test:device_'+'a'.repeat(140),other='fcm_other:device_'+'b'.repeat(140);
  await role(1,()=>scalar('set_client_portal',[u(10),true]));
  await db.query('UPDATE profiles SET portal_enabled=false WHERE id=$1',[u(4)]);
  await role(2,async()=>{
    const settings=await scalar('get_notification_settings');eq(settings.provider,'fcm');eq(settings.project_id,'ikill-4e337');eq(settings.push_enabled,false);eq(settings.app_id,undefined);
    await scalar('register_my_fcm',[token,'a'.repeat(64)]);
    await scalar('register_my_fcm',[token,'a'.repeat(64)]);
    await fail(()=>scalar('register_my_fcm',['short','a'.repeat(64)]));
    await fail(()=>scalar('set_notification_push_settings',[true]));
    await fail(()=>scalar('claim_push_delivery',[u(30),u(1)]));
  });
  eq((await db.query('SELECT fcm_token FROM profiles WHERE id=$1',[u(2)])).rows[0].fcm_token,token);
  await role(3,()=>fail(()=>scalar('register_my_fcm',[token,'b'.repeat(64)])));
  await role(4,()=>fail(()=>scalar('register_my_fcm',[other,'b'.repeat(64)])));
  await role(3,async()=>eq((await db.query('UPDATE profiles SET fcm_token=$1 WHERE id=$2 RETURNING id',[token,u(3)])).rows.length,0));
  await role(1,()=>scalar('set_notification_push_settings',[true]));
  const delivery=(await db.query("SELECT d.* FROM app_private.push_deliveries d JOIN notifications n ON n.id=d.notification_id WHERE n.user_id=$1 LIMIT 1",[u(2)])).rows[0];
  const claimed=await scalar('claim_push_delivery',[delivery.notification_id,delivery.token]);
  eq(claimed.fcm_token,token);eq(claimed.project_id,'ikill-4e337');eq(claimed.reference_id,u(30));eq(claimed.type,'visit_assigned');eq(claimed.subscription_id,undefined);
  eq((await scalar('claim_push_delivery',[delivery.notification_id,delivery.token])).skip,true);
  await role(2,()=>scalar('register_my_fcm',[other,'a'.repeat(64)]));
  // An old provider response must never clear a newly refreshed token.
  await scalar('invalidate_fcm_token',[delivery.notification_id,delivery.token,token]);
  eq((await db.query('SELECT fcm_token FROM profiles WHERE id=$1',[u(2)])).rows[0].fcm_token,other);
  await scalar('invalidate_fcm_token',[delivery.notification_id,delivery.token,other]);
  eq((await db.query('SELECT fcm_token FROM profiles WHERE id=$1',[u(2)])).rows[0].fcm_token,null);
  await scalar('finish_push_delivery',[delivery.notification_id,delivery.token,'no_device',null]);
  await role(2,()=>scalar('register_my_fcm',[other,'a'.repeat(64)]));
  await role(2,()=>scalar('unregister_my_fcm',[token]));
  eq((await db.query('SELECT fcm_token FROM profiles WHERE id=$1',[u(2)])).rows[0].fcm_token,other);
  await role(2,()=>scalar('unregister_my_fcm',[other]));
  eq((await db.query('SELECT fcm_token FROM profiles WHERE id=$1',[u(2)])).rows[0].fcm_token,null);
  // Same installation switching accounts is allowed and clears previous recipient.
  await role(3,()=>scalar('register_my_fcm',[other,'a'.repeat(64)]));
  eq((await db.query('SELECT fcm_token FROM profiles WHERE id=$1',[u(3)])).rows[0].fcm_token,other);
  await role(3,()=>scalar('unregister_my_fcm'));
  eq((await db.query('SELECT fcm_token FROM profiles WHERE id=$1',[u(3)])).rows[0].fcm_token,null);
  eq((await db.query("SELECT count(*)::int n FROM information_schema.columns WHERE table_schema='public' AND column_name IN ('push_subscription_id','onesignal_app_id')")).rows[0].n,0);
  eq((await db.query("SELECT to_regprocedure('public.register_my_push(text,text)') f")).rows[0].f,null);
  console.log(`PASS: ${checks} FCM migration/token/role/refresh/logout checks`);await db.close();
})().catch(e=>{console.error(e);process.exit(1)});

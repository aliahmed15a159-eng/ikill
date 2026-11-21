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
  await role(1,()=>scalar('set_client_portal',[u(10),true]));
  await db.query('UPDATE profiles SET portal_enabled=false WHERE id=$1',[u(4)]);
  eq((await db.query("SELECT count(*)::int n FROM notifications WHERE user_id=$1",[u(2)])).rows[0].n,1);
  await role(2,async()=>{
    const rows=(await db.query('SELECT * FROM notifications')).rows;
    eq(rows.length,1);eq(rows[0].reference_id,u(30));
    await fail(()=>db.query("UPDATE notifications SET title='tamper'"));
    await fail(()=>db.query("INSERT INTO notifications(tenant_id) VALUES($1)",[company]));
    await scalar('mark_notifications_read');eq((await db.query('SELECT is_read FROM notifications')).rows[0].is_read,true);
    await db.query('UPDATE notifications SET is_read=false');eq((await db.query('SELECT is_read FROM notifications')).rows[0].is_read,false);
    await fail(()=>scalar('claim_push_delivery',[u(30),u(1)]));
    await fail(()=>scalar('set_notification_push_settings',[u(99),true]));
    await scalar('register_my_push',[u(500),'a'.repeat(64)]);
  });
  await role(3,()=>fail(()=>scalar('register_my_push',[u(500),'b'.repeat(64)])));
  await role(4,()=>fail(()=>scalar('get_notification_settings')));
  await db.query("UPDATE visits SET scheduled_start=scheduled_start+interval '1 day',scheduled_end=scheduled_end+interval '1 day' WHERE id=$1",[u(30)]);
  eq((await db.query("SELECT count(*)::int n FROM notifications WHERE type='visit_rescheduled' AND user_id=$1",[u(2)])).rows[0].n,1);
  await role(3,async()=>{eq((await db.query('SELECT * FROM notifications')).rows.length,1);await scalar('mark_notifications_read');});
  await role(4,async()=>{eq((await db.query('SELECT * FROM notifications')).rows.length,0);await fail(()=>scalar('register_my_push',[u(501),'c'.repeat(64)]));});
  // Direct one-off order fixture; no contract or billing side effects.
  await db.query("INSERT INTO visits(id,tenant_id,client_id,site_id,status,quoted_amount,quoted_currency,payment_review,payment_reference) VALUES($1,$2,$3,$4,'pending_schedule',300,'EGP','pending_review','ref-123')",[u(31),company,u(10),u(20)]);
  eq((await db.query("SELECT count(*)::int n FROM notifications WHERE reference_id=$1 AND user_id=$2",[u(31),u(1)])).rows[0].n,2);
  const proof=`${company}/${u(31)}/${u(3)}/proof.png`;
  await db.query("INSERT INTO storage.objects(bucket_id,name) VALUES('payment-proofs',$1)",[proof]);
  await role(2,()=>fail(()=>scalar('submit_payment_proof',[u(31),'visit',proof,'reference'])));
  await role(3,()=>scalar('submit_payment_proof',[u(31),'visit',proof,'reference']));
  eq((await db.query('SELECT payment_status FROM visits WHERE id=$1',[u(31)])).rows[0].payment_status,'pending_confirmation');
  await role(1,()=>scalar('review_residential_payment',[u(31),false]));
  eq((await db.query("SELECT count(*)::int n FROM notifications WHERE user_id=$1 AND type='payment_rejected'",[u(3)])).rows[0].n,1);
  await role(3,()=>scalar('submit_payment_proof',[u(31),'visit',proof+'missing','reference']).then(()=>{throw new Error('expected missing object failure')},()=>{checks++}));
  await role(3,()=>scalar('submit_payment_proof',[u(31),'visit',proof,'reference']));
  await role(1,()=>scalar('review_residential_payment',[u(31),true]));
  eq((await db.query('SELECT payment_status FROM visits WHERE id=$1',[u(31)])).rows[0].payment_status,'paid');
  await role(3,()=>fail(()=>scalar('review_residential_payment',[u(31),true])));
  // Delivery guards use role + current recipient state; no notification text is sent to transport.
  const delivery=(await db.query('SELECT * FROM app_private.push_deliveries LIMIT 1')).rows[0];
  await fail(()=>scalar('claim_push_delivery',[delivery.notification_id,u(999)]));
  const claimed=await scalar('claim_push_delivery',[delivery.notification_id,delivery.token]);eq(claimed.skip,true);
  eq((await db.query('SELECT status FROM app_private.push_deliveries WHERE notification_id=$1',[delivery.notification_id])).rows[0].status,'not_configured');
  await role(2,()=>scalar('unregister_my_push',[u(500)]));
  eq((await db.query('SELECT push_subscription_id FROM profiles WHERE id=$1',[u(2)])).rows[0].push_subscription_id,null);
  // Extension defaults must not expose webhook tokens through the pg_net queue.
  await db.exec('CREATE SCHEMA net; CREATE TABLE net.http_request_queue(id bigint,body jsonb); CREATE TABLE net._http_response(id bigint,content text); GRANT ALL ON net.http_request_queue,net._http_response TO PUBLIC;');
  await db.exec(fs.readFileSync(path.join(__dirname,'../phase9b_protect_webhook_queue.sql'),'utf8'));
  eq((await db.query("SELECT has_table_privilege('authenticated','net.http_request_queue','SELECT') result")).rows[0].result,false);
  eq((await db.query("SELECT has_table_privilege('anon','net.http_request_queue','SELECT') result")).rows[0].result,false);
  // An administrator of a different tenant sees neither recipients nor receipts.
  await db.query("INSERT INTO tenants(id,slug,name) VALUES($1,'notification-other','Other')",[u(900)]);
  await db.query('INSERT INTO auth.users(id) VALUES($1)',[u(901)]);
  await db.query("INSERT INTO profiles(id,tenant_id,role,full_name) VALUES($1,$2,'admin','Other admin')",[u(901),u(900)]);
  await role(901,async()=>{
    eq((await db.query('SELECT * FROM notifications')).rows.length,0);
    eq((await db.query('SELECT * FROM payment_confirmations')).rows.length,0);
    await scalar('mark_notifications_read');
    await fail(()=>scalar('submit_payment_proof',[u(31),'visit',proof,'cross-tenant']));
    await fail(()=>db.query("SELECT * FROM app_private.push_deliveries"));
  });
  // Financial partial balance is preserved until an administrator verifies receipt.
  await db.query("INSERT INTO invoices(id,tenant_id,client_id,invoice_number,due_on,subtotal,amount_paid,status) VALUES($1,$2,$3,'proof-test',current_date+7,1000,250,'issued')",[u(600),company,u(10)]);
  const invoiceProof=`${company}/${u(600)}/${u(3)}/proof.png`;
  await db.query("INSERT INTO storage.objects(bucket_id,name) VALUES('payment-proofs',$1)",[invoiceProof]);
  await role(3,()=>scalar('submit_payment_proof',[u(600),'invoice',invoiceProof,'invoice-ref']));
  eq((await db.query('SELECT payment_status FROM invoices WHERE id=$1',[u(600)])).rows[0].payment_status,'partial');
  let confirmation=(await db.query('SELECT * FROM payment_confirmations WHERE invoice_id=$1',[u(600)])).rows[0];
  eq(Number(confirmation.amount),750);
  await role(2,()=>fail(()=>scalar('review_invoice_payment',[confirmation.id,true])));
  await role(3,()=>fail(()=>scalar('review_invoice_payment',[confirmation.id,true])));
  await role(1,()=>scalar('review_invoice_payment',[confirmation.id,false]));
  eq((await db.query('SELECT payment_confirmation_status FROM invoices WHERE id=$1',[u(600)])).rows[0].payment_confirmation_status,'rejected');
  await role(3,()=>scalar('submit_payment_proof',[u(600),'invoice',invoiceProof,'invoice-ref']));
  confirmation=(await db.query("SELECT * FROM payment_confirmations WHERE invoice_id=$1 AND payment_status='pending_confirmation'",[u(600)])).rows[0];
  await role(1,()=>scalar('review_invoice_payment',[confirmation.id,true]));
  const paid=(await db.query('SELECT * FROM invoices WHERE id=$1',[u(600)])).rows[0];
  eq(paid.payment_status,'paid');eq(paid.payment_confirmation_status,'paid');eq(Number(paid.amount_paid),1000);
  await role(1,()=>fail(()=>scalar('review_invoice_payment',[confirmation.id,true])));
  await role(3,()=>fail(()=>scalar('submit_payment_proof',[u(600),'invoice',invoiceProof,'invoice-ref'])));
  eq((await db.query("SELECT count(*)::int n FROM notifications WHERE reference_id=$1 AND type='payment_confirmed'",[u(600)])).rows[0].n,1);
  // A configured delivery contains no transaction text and cannot be replayed while leased/sent.
  await role(1,()=>scalar('set_notification_push_settings',[u(700),true]));
  await role(2,()=>scalar('register_my_push',[u(500),'a'.repeat(64)]));
  const techDelivery=(await db.query("SELECT d.* FROM app_private.push_deliveries d JOIN notifications n ON n.id=d.notification_id WHERE n.user_id=$1 LIMIT 1",[u(2)])).rows[0];
  const payload=await scalar('claim_push_delivery',[techDelivery.notification_id,techDelivery.token]);
  eq(payload.subscription_id,u(500));eq(payload.notification_id,techDelivery.notification_id);eq(payload.body,undefined);
  eq((await scalar('claim_push_delivery',[techDelivery.notification_id,techDelivery.token])).skip,true);
  await scalar('finish_push_delivery',[techDelivery.notification_id,techDelivery.token,'sent',u(800)]);
  eq((await scalar('claim_push_delivery',[techDelivery.notification_id,techDelivery.token])).skip,true);
  console.log(`PASS: ${checks} notification/payment migration and isolation checks`);await db.close();
})().catch(e=>{console.error(e);process.exit(1)});

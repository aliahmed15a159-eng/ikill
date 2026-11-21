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
  for (const file of ['phase1_schema.sql','phase2_integration.sql','phase3_requests.sql','phase4_instapay_qr.sql','phase5_client_contract_lifecycle.sql','phase6_operations.sql','phase7_field_reports.sql','phase8_billing_documents_portal.sql','phase8b_document_integrity.sql','phase8c_legacy_documents.sql']) {
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
  const count=async(table)=>(await db.query(`SELECT count(*) n FROM ${table}`)).rows[0].n;
  const key='a'.repeat(32);
  async function submit(n){
    const prefix=`${company}/${u(n)}/${key}/`;
    await db.query("INSERT INTO storage.objects(bucket_id,name) VALUES('visit-signatures',$1)",[prefix+'signature.png']);
    return role(2,async()=>{await scalar('set_my_visit_state',[u(n),'in_progress']);return scalar('submit_field_report',[u(n),key,JSON.stringify({pest:'none',severity:'none',actions:['inspection'],signature_consent:true,materials:'None'}),'None','Notes',[],prefix+'signature.png','Site rep']);});
  }
  await fail(()=>submit(30));
  assert.equal(await count('invoices'),0);assert.equal(await count('visit_reports'),0);checks+=2;
  await db.exec(`UPDATE visits SET quoted_amount=300,quoted_currency='EGP',payment_review='verified',payment_verified_by='${u(1)}',payment_verified_at=now() WHERE id='${u(30)}';DELETE FROM storage.objects;`);
  const report=await submit(30);
  const one=(await db.query('SELECT * FROM invoices')).rows[0];assert.equal(one.payment_status,'paid');assert.equal(Number(one.total),300);checks+=2;
  assert.equal(await count('report_invoices'),1);assert.equal(await count('document_jobs'),1);checks+=2;
  await role(2,()=>fail(()=>scalar('record_invoice_paid',[one.id,'receipt'])));
  await role(3,async()=>{assert.equal((await db.query('SELECT * FROM invoices')).rows.length,0);checks++;await fail(()=>scalar('claim_document_job',[report]));});
  await role(1,()=>scalar('set_client_portal',[u(10),true]));
  await role(3,async()=>{assert.equal((await db.query('SELECT * FROM invoices')).rows.length,1);assert.equal((await db.query('SELECT * FROM visit_reports')).rows.length,1);checks+=2;await fail(()=>scalar('record_invoice_paid',[one.id,'receipt']));assert.equal((await db.query("UPDATE brand_config SET company_name='tamper' RETURNING tenant_id")).rows.length,0);checks++;});
  async function contract(n,cycle,start,end,amount){await db.query("INSERT INTO contracts(id,tenant_id,client_id,contract_number,starts_on,ends_on,visits_per_month,billing_cycle,billing_amount,status) VALUES($1,$2,$3,$4,$5,$6,2,$7,$8,'active')",[u(n),company,u(10),'C'+n,start,end,cycle,amount]);}
  async function visit(n,c,day){await db.query("INSERT INTO visits(id,tenant_id,client_id,site_id,contract_id,technician_id,scheduled_start,scheduled_end) VALUES($1,$2,$3,$4,$5,$6,$7::timestamptz,$7::timestamptz+interval '1 hour')",[u(n),company,u(10),u(20),u(c),u(2),day]);return submit(n);}
  await contract(70,'monthly','2026-01-01','2027-12-31',1000);
  const r1=await visit(71,70,'2026-02-02T10:00:00Z'),r2=await visit(72,70,'2026-02-20T10:00:00Z');
  assert.equal((await db.query('SELECT * FROM invoices WHERE contract_id=$1',[u(70)])).rows.length,1);checks++;
  const monthly=(await db.query('SELECT * FROM invoices WHERE contract_id=$1',[u(70)])).rows[0];assert.equal(Number(monthly.total),1000);assert.equal(monthly.payment_status,'unpaid');checks+=2;
  assert.equal((await db.query('SELECT * FROM report_invoices WHERE invoice_id=$1',[monthly.id])).rows.length,2);checks++;
  await visit(73,70,'2026-03-02T10:00:00Z');assert.equal((await db.query('SELECT * FROM invoices WHERE contract_id=$1',[u(70)])).rows.length,2);checks++;
  await contract(80,'quarterly','2026-02-15','2027-12-31',2100);
  await visit(81,80,'2026-03-03T10:00:00Z');await visit(82,80,'2026-04-03T10:00:00Z');await visit(83,80,'2026-05-03T10:00:00Z');
  const quarters=(await db.query('SELECT * FROM invoices WHERE contract_id=$1 ORDER BY billing_period',[u(80)])).rows;assert.equal(quarters.length,2);assert.equal(Number(quarters[0].total),2100);checks+=2;
  await contract(90,'annual','2025-02-15','2027-12-31',9000);
  await visit(91,90,'2025-05-03T10:00:00Z');await visit(92,90,'2026-01-03T10:00:00Z');await visit(93,90,'2026-03-03T10:00:00Z');
  assert.equal((await db.query('SELECT * FROM invoices WHERE contract_id=$1',[u(90)])).rows.length,2);checks++;
  await db.query("INSERT INTO contracts(id,tenant_id,client_id,contract_number,starts_on,ends_on,visits_per_month,billing_cycle,billing_amount,status,app_managed) VALUES($1,$2,$3,'native-total','2026-01-01','2026-03-31',1,'monthly',100,'draft',true)",[u(100),company,u(10)]);
  await visit(101,100,'2026-01-02T10:00:00Z');await visit(102,100,'2026-02-02T10:00:00Z');await visit(103,100,'2026-03-02T10:00:00Z');
  const allocations=(await db.query('SELECT subtotal FROM invoices WHERE contract_id=$1 ORDER BY billing_period',[u(100)])).rows.map(i=>Number(i.subtotal));
  assert.deepEqual(allocations,[33.33,33.33,33.34]);assert.equal(allocations.reduce((a,b)=>a+b,0),100);checks+=2;
  await fail(()=>db.query("UPDATE contracts SET billing_amount=.01 WHERE id=$1",[u(100)]));
  await role(1,()=>fail(()=>db.query("UPDATE brand_config SET logo_path='other-tenant/logo.png' WHERE tenant_id=$1",[company])));
  await db.exec(`INSERT INTO auth.users(id) VALUES('${u(5)}'),('${u(6)}');INSERT INTO clients(id,tenant_id,client_code,display_name) VALUES('${u(11)}','${company}','new','New customer');`);
  await role(1,()=>fail(()=>scalar('attach_portal_profile',[company,u(11),u(5)])));
  await scalar('attach_portal_profile',[company,u(11),u(5)]);checks++;
  const provisioned=(await db.query('SELECT * FROM profiles WHERE id=$1',[u(5)])).rows[0];assert.equal(provisioned.role,'client');assert.equal(provisioned.portal_enabled,false);checks+=2;
  await fail(()=>scalar('attach_portal_profile',[company,u(11),u(6)]));
  await role(5,async()=>{assert.equal((await db.query('SELECT * FROM invoices')).rows.length,0);checks++;await fail(()=>scalar('claim_document_job',[r1]));});
  let job=await role(2,()=>scalar('claim_document_job',[r1]));assert.ok(job.lease);checks++;
  await role(2,()=>fail(()=>scalar('claim_document_job',[r1])));
  await role(2,()=>fail(()=>scalar('finish_document_job',[r1,job.lease,'bad','bad',null])));
  const reportPath=`${company}/${u(71)}/${job.lease}.pdf`,ipath=`${company}/${monthly.id}/${job.lease}.pdf`;
  await db.query("INSERT INTO storage.objects(bucket_id,name) VALUES('report-pdfs',$1),('invoice-pdfs',$2)",[reportPath,ipath]);
  await scalar('finish_document_job',[r1,job.lease,reportPath,ipath,null]);
  assert.equal((await role(2,()=>scalar('claim_document_job',[r1]))).ready,true);checks++;
  await role(3,async()=>{assert.equal((await db.query("SELECT * FROM storage.objects WHERE bucket_id='report-pdfs' AND name=$1",[reportPath])).rows.length,1);checks++;});
  await role(1,async()=>{await scalar('record_invoice_paid',[monthly.id,'Bank receipt 123']);await scalar('record_invoice_paid',[monthly.id,'Retry receipt']);});
  assert.equal(await count('invoice_collections'),1);checks++;
  const paid=(await db.query('SELECT * FROM invoices WHERE id=$1',[monthly.id])).rows[0];assert.equal(paid.payment_status,'paid');assert.equal(paid.pdf_path,null);checks+=2;
  await fail(()=>scalar('finish_document_job',[r1,job.lease,reportPath,ipath,null]));
  assert.equal((await db.query('SELECT status FROM document_jobs WHERE report_id=$1',[r2])).rows[0].status,'pending');checks++;
  await db.exec(`INSERT INTO visits(id,tenant_id,client_id,site_id,technician_id,status,scheduled_start,scheduled_end,started_at,completed_at,quoted_amount,quoted_currency,payment_review,payment_verified_by,payment_verified_at) VALUES('${u(200)}','${company}','${u(10)}','${u(20)}','${u(2)}','completed',now()-interval '2 hours',now()-interval '1 hour',now()-interval '2 hours',now(),500,'EGP','verified','${u(1)}',now());
    ALTER TABLE visit_reports DISABLE TRIGGER issue_report_invoice;
    INSERT INTO visit_reports(id,tenant_id,visit_id,technician_id,status) VALUES('${u(201)}','${company}','${u(200)}','${u(2)}','submitted');
    ALTER TABLE visit_reports ENABLE TRIGGER issue_report_invoice;`);
  await role(2,()=>fail(()=>scalar('prepare_legacy_report',[u(201)])));
  const beforeLegacy=await count('invoices');
  await role(1,async()=>{await scalar('prepare_legacy_report',[u(201)]);await scalar('prepare_legacy_report',[u(201)]);});
  assert.equal(await count('invoices'),beforeLegacy+1);checks++;
  assert.equal((await db.query('SELECT * FROM document_jobs WHERE report_id=$1',[u(201)])).rows.length,1);checks++;
  await role(1,()=>scalar('set_client_portal',[u(10),false]));
  await role(3,async()=>{assert.equal((await db.query('SELECT * FROM invoices')).rows.length,0);assert.equal((await db.query("SELECT * FROM storage.objects WHERE bucket_id='report-pdfs' AND name=$1",[reportPath])).rows.length,0);checks+=2;await fail(()=>scalar('claim_document_job',[r1]));});
  await db.exec('SET ROLE anon');await fail(()=>scalar('claim_document_job',[r1]));await db.exec('RESET ROLE');
  console.log(`Billing/documents/portal: ${checks} assertions passed`);await db.close();
})().catch(e=>{console.error(e);process.exit(1)});

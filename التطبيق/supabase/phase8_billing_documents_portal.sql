-- Product phase seven: one invoice per anchored contract billing cycle.
ALTER TABLE public.clients ADD COLUMN portal_enabled boolean NOT NULL DEFAULT false;
UPDATE public.clients c SET portal_enabled=true WHERE EXISTS(SELECT 1 FROM public.profiles p WHERE p.tenant_id=c.tenant_id AND p.client_id=c.id AND p.role='client' AND p.portal_enabled AND p.is_active);
CREATE OR REPLACE FUNCTION app_private.client_access(t uuid,c uuid) RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $$
 SELECT EXISTS(SELECT 1 FROM public.profiles p JOIN public.tenants n ON n.id=p.tenant_id JOIN public.clients k ON k.tenant_id=p.tenant_id AND k.id=p.client_id WHERE p.id=(SELECT auth.uid()) AND p.tenant_id=t AND p.client_id=c AND p.role='client' AND p.portal_enabled AND k.portal_enabled AND p.is_active AND n.is_active);
$$;
CREATE TABLE public.brand_config (
 tenant_id uuid PRIMARY KEY REFERENCES public.tenants(id),company_name text NOT NULL CHECK(length(trim(company_name)) BETWEEN 1 AND 160),
 address text NOT NULL DEFAULT '' CHECK(length(address)<=600),phone text NOT NULL DEFAULT '' CHECK(length(phone)<=40),email text NOT NULL DEFAULT '' CHECK(length(email)<=254),
 tax_number text NOT NULL DEFAULT '' CHECK(length(tax_number)<=80),logo_path text CHECK(logo_path IS NULL OR (logo_path LIKE tenant_id::text||'/%' AND position('..' in logo_path)=0 AND position('%' in logo_path)=0 AND length(logo_path)<=250)),primary_hex text NOT NULL DEFAULT '15803D' CHECK(primary_hex ~ '^[0-9a-fA-F]{6}$')
);
INSERT INTO public.brand_config(tenant_id,company_name,phone,email,logo_path) SELECT id,name,CASE WHEN slug='ikill' THEN '01020019042' ELSE '' END,CASE WHEN slug='ikill' THEN 'info@ikill.net' ELSE '' END,CASE WHEN slug='ikill' THEN id::text||'/logo.png' ELSE NULL END FROM public.tenants;
ALTER TABLE public.brand_config ENABLE ROW LEVEL SECURITY; ALTER TABLE public.brand_config FORCE ROW LEVEL SECURITY;
GRANT SELECT,INSERT,UPDATE ON public.brand_config TO authenticated;GRANT ALL ON public.brand_config TO service_role;
CREATE POLICY brand_member_read ON public.brand_config FOR SELECT TO authenticated USING(app_private.is_admin(tenant_id) OR app_private.has_role(tenant_id,'technician') OR EXISTS(SELECT 1 FROM public.profiles p WHERE p.id=(SELECT auth.uid()) AND app_private.client_access(p.tenant_id,p.client_id) AND p.tenant_id=brand_config.tenant_id));
CREATE POLICY brand_admin_insert ON public.brand_config FOR INSERT TO authenticated WITH CHECK(app_private.is_admin(tenant_id));
CREATE POLICY brand_admin_update ON public.brand_config FOR UPDATE TO authenticated USING(app_private.is_admin(tenant_id)) WITH CHECK(app_private.is_admin(tenant_id));
ALTER TABLE public.invoices ADD COLUMN billing_period date;
ALTER TABLE public.invoices ADD COLUMN period_end date;
ALTER TABLE public.invoices ADD COLUMN pdf_path text;
CREATE UNIQUE INDEX invoice_contract_cycle ON public.invoices(contract_id,billing_period) WHERE contract_id IS NOT NULL AND billing_period IS NOT NULL;
CREATE UNIQUE INDEX invoice_oneoff_visit ON public.invoices(visit_id) WHERE contract_id IS NULL AND visit_id IS NOT NULL AND status<>'void';
CREATE TABLE public.report_invoices (
 tenant_id uuid NOT NULL,report_id uuid PRIMARY KEY,invoice_id uuid NOT NULL,
 FOREIGN KEY(tenant_id,report_id) REFERENCES public.visit_reports(tenant_id,id),FOREIGN KEY(tenant_id,invoice_id) REFERENCES public.invoices(tenant_id,id)
);
CREATE TABLE public.document_jobs (
 report_id uuid PRIMARY KEY REFERENCES public.visit_reports(id),tenant_id uuid NOT NULL REFERENCES public.tenants(id),invoice_id uuid NOT NULL REFERENCES public.invoices(id),
 status text NOT NULL DEFAULT 'pending' CHECK(status IN ('pending','processing','ready','failed')),
 attempts integer NOT NULL DEFAULT 0,lease uuid,leased_at timestamptz,last_error text,report_path text,updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE public.invoice_collections (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),tenant_id uuid NOT NULL,invoice_id uuid NOT NULL,amount numeric(12,2) NOT NULL CHECK(amount>0),reference text NOT NULL,recorded_by uuid NOT NULL,recorded_at timestamptz NOT NULL DEFAULT now(),
 FOREIGN KEY(tenant_id,invoice_id) REFERENCES public.invoices(tenant_id,id),FOREIGN KEY(tenant_id,recorded_by) REFERENCES public.profiles(tenant_id,id)
);
DO $$ DECLARE tab text;BEGIN FOREACH tab IN ARRAY ARRAY['report_invoices','document_jobs','invoice_collections'] LOOP
 EXECUTE format('ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY',tab);EXECUTE format('ALTER TABLE public.%I FORCE ROW LEVEL SECURITY',tab);
 EXECUTE format('GRANT SELECT ON public.%I TO authenticated',tab);EXECUTE format('GRANT ALL ON public.%I TO service_role',tab);
 EXECUTE format('CREATE POLICY admin_read ON public.%I FOR SELECT TO authenticated USING(app_private.is_admin(tenant_id))',tab);
END LOOP;END $$;
CREATE POLICY portal_links ON public.report_invoices FOR SELECT TO authenticated USING(EXISTS(SELECT 1 FROM public.visit_reports r WHERE r.id=report_id AND r.tenant_id=report_invoices.tenant_id));
CREATE POLICY document_read ON public.document_jobs FOR SELECT TO authenticated USING(EXISTS(SELECT 1 FROM public.visit_reports r WHERE r.id=report_id AND r.tenant_id=document_jobs.tenant_id AND r.status='submitted'));
CREATE FUNCTION app_private.bill_submitted_report() RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE v public.visits%ROWTYPE;c public.contracts%ROWTYPE;i public.invoices%ROWTYPE;zone text;day date;period date;finish date;span integer;delta integer;cycles integer;cycle_index integer;charge numeric(12,2);
BEGIN
 IF NEW.status<>'submitted' THEN RETURN NEW;END IF;
 IF TG_OP='UPDATE' THEN IF OLD.status='submitted' THEN RETURN NEW;END IF;END IF;
 SELECT * INTO v FROM public.visits WHERE id=NEW.visit_id FOR UPDATE;
 SELECT timezone INTO zone FROM public.tenants WHERE id=v.tenant_id;day:=(now() AT TIME ZONE zone)::date;
 IF v.contract_id IS NULL THEN
  IF v.payment_review<>'verified' OR v.quoted_amount IS NULL OR v.quoted_amount<=0 THEN RAISE EXCEPTION 'VERIFIED_ONEOFF_PAYMENT_REQUIRED';END IF;
  SELECT * INTO i FROM public.invoices WHERE tenant_id=v.tenant_id AND visit_id=v.id AND contract_id IS NULL AND status<>'void' FOR UPDATE;
  IF FOUND THEN
   IF i.status<>'issued' OR i.payment_status<>'paid' OR i.total<>v.quoted_amount OR i.currency<>v.quoted_currency THEN RAISE EXCEPTION 'PAID_INVOICE_MISMATCH';END IF;
  ELSE
   INSERT INTO public.invoices(tenant_id,client_id,site_id,visit_id,invoice_number,issued_on,due_on,subtotal,amount_paid,status,currency,line_items)
   VALUES(v.tenant_id,v.client_id,v.site_id,v.id,'INV-'||gen_random_uuid()::text,day,day,v.quoted_amount,v.quoted_amount,'issued',v.quoted_currency,jsonb_build_array(jsonb_build_object('description','One-off service','amount',v.quoted_amount))) RETURNING * INTO i;
  END IF;
 ELSE
  SELECT * INTO c FROM public.contracts WHERE id=v.contract_id FOR UPDATE;
  span:=CASE c.billing_cycle WHEN 'monthly' THEN 1 WHEN 'quarterly' THEN 3 WHEN 'semiannual' THEN 6 WHEN 'annual' THEN 12 WHEN 'one_time' THEN 1200 END;
  period:=date_trunc('month',coalesce(v.recurrence_month,(v.scheduled_start AT TIME ZONE zone)::date))::date;
  delta:=(extract(year FROM period)::integer-extract(year FROM c.starts_on)::integer)*12+extract(month FROM period)::integer-extract(month FROM c.starts_on)::integer;
  IF delta<0 OR span IS NULL OR c.billing_amount<=0 THEN RAISE EXCEPTION 'INVALID_BILLING_CYCLE';END IF;
  period:=(date_trunc('month',c.starts_on)+make_interval(months=>delta/span*span))::date;
  cycle_index:=delta/span;
  cycles:=((extract(year FROM c.ends_on)::integer-extract(year FROM c.starts_on)::integer)*12+extract(month FROM c.ends_on)::integer-extract(month FROM c.starts_on)::integer)/span+1;
  IF cycle_index>=cycles THEN RAISE EXCEPTION 'VISIT_OUTSIDE_CONTRACT_CYCLES';END IF;
  charge:=c.billing_amount;
  -- Native signed contracts store TOTAL contract value, not cycle price.
  IF c.app_managed THEN
   charge:=trunc(c.billing_amount*100/cycles)/100;
   IF cycle_index=cycles-1 THEN charge:=c.billing_amount-charge*(cycles-1);END IF;
   IF charge<=0 THEN RAISE EXCEPTION 'CONTRACT_TOTAL_TOO_SMALL';END IF;
  END IF;
  finish:=least(c.ends_on,(period+make_interval(months=>span)-interval '1 day')::date);
  INSERT INTO public.invoices(tenant_id,client_id,contract_id,invoice_number,issued_on,due_on,subtotal,status,currency,billing_period,period_end,line_items)
  VALUES(v.tenant_id,v.client_id,c.id,'INV-'||gen_random_uuid()::text,day,day+14,charge,'issued',c.currency,period,finish,jsonb_build_array(jsonb_build_object('description','Contract billing cycle','amount',charge)))
  ON CONFLICT(contract_id,billing_period) WHERE contract_id IS NOT NULL AND billing_period IS NOT NULL DO NOTHING;
  SELECT * INTO i FROM public.invoices WHERE contract_id=c.id AND billing_period=period FOR UPDATE;
  IF i.status='void' THEN RAISE EXCEPTION 'VOID_CYCLE_REQUIRES_ADMIN';END IF;
 END IF;
 INSERT INTO public.report_invoices VALUES(v.tenant_id,NEW.id,i.id);
 INSERT INTO public.document_jobs(report_id,tenant_id,invoice_id) VALUES(NEW.id,v.tenant_id,i.id);
 RETURN NEW;
END; $$;
CREATE TRIGGER issue_report_invoice AFTER INSERT OR UPDATE OF status ON public.visit_reports FOR EACH ROW EXECUTE FUNCTION app_private.bill_submitted_report();
CREATE FUNCTION public.set_client_portal(customer uuid,enabled boolean) RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE company uuid:=app_private.ops_admin_tenant();BEGIN
 IF enabled IS NULL THEN RAISE EXCEPTION 'FLAG_REQUIRED';END IF;
 UPDATE public.clients SET portal_enabled=enabled WHERE tenant_id=company AND id=customer;
 IF NOT FOUND THEN RAISE EXCEPTION 'CLIENT_REQUIRED';END IF;
 UPDATE public.profiles SET portal_enabled=enabled WHERE tenant_id=company AND client_id=customer AND role='client';END; $$;
CREATE FUNCTION public.record_invoice_paid(target_invoice uuid,reference text) RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE company uuid:=app_private.ops_admin_tenant();i public.invoices%ROWTYPE;BEGIN
 IF reference IS NULL OR length(trim(reference)) NOT BETWEEN 3 AND 200 THEN RAISE EXCEPTION 'COLLECTION_REFERENCE_REQUIRED';END IF;
 SELECT * INTO i FROM public.invoices WHERE tenant_id=company AND id=target_invoice FOR UPDATE;
 IF NOT FOUND OR i.status<>'issued' THEN RAISE EXCEPTION 'ISSUED_INVOICE_REQUIRED';END IF;
 IF i.payment_status='paid' THEN RETURN;END IF;
 INSERT INTO public.invoice_collections(tenant_id,invoice_id,amount,reference,recorded_by) VALUES(company,i.id,i.total-i.amount_paid,trim(reference),(SELECT auth.uid()));
 UPDATE public.invoices SET amount_paid=total,pdf_path=NULL WHERE id=i.id;
 UPDATE public.document_jobs SET status='pending',lease=NULL,last_error=NULL,updated_at=now() WHERE invoice_id=i.id;
END; $$;
CREATE FUNCTION public.claim_document_job(target_report uuid) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE r public.visit_reports%ROWTYPE;v public.visits%ROWTYPE;j public.document_jobs%ROWTYPE;token uuid;BEGIN
 SELECT * INTO r FROM public.visit_reports WHERE id=target_report AND status='submitted';SELECT * INTO v FROM public.visits WHERE id=r.visit_id;
 IF r.id IS NULL OR NOT (app_private.is_admin(r.tenant_id) OR app_private.assigned_visit(r.tenant_id,r.visit_id) OR app_private.client_access(r.tenant_id,v.client_id)) THEN RAISE EXCEPTION 'DOCUMENT_ACCESS_DENIED';END IF;
 SELECT * INTO j FROM public.document_jobs WHERE report_id=r.id FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'NO_DOCUMENT_JOB';END IF;
 IF j.status='ready' AND EXISTS(SELECT 1 FROM public.invoices WHERE id=j.invoice_id AND pdf_path IS NOT NULL) THEN RETURN jsonb_build_object('ready',true);END IF;
 IF j.status='processing' AND j.leased_at>now()-interval '3 minutes' THEN RAISE EXCEPTION 'DOCUMENT_BUSY';END IF;
 token:=gen_random_uuid();UPDATE public.document_jobs SET status='processing',lease=token,leased_at=now(),attempts=attempts+1,last_error=NULL WHERE report_id=r.id;
 RETURN jsonb_build_object('lease',token,'tenant_id',r.tenant_id,'report',to_jsonb(r),'invoice',(SELECT to_jsonb(i) FROM public.invoices i WHERE i.id=j.invoice_id),
 'brand',(SELECT to_jsonb(b) FROM public.brand_config b WHERE b.tenant_id=r.tenant_id),'client',(SELECT jsonb_build_object('display_name',c.display_name,'email',c.email,'phone',c.phone) FROM public.clients c WHERE c.id=v.client_id),
 'site',(SELECT jsonb_build_object('name',s.name,'address',s.address) FROM public.client_sites s WHERE s.id=v.site_id),'visit',jsonb_build_object('id',v.id,'started_at',v.started_at,'completed_at',v.completed_at,'scheduled_start',v.scheduled_start));
END; $$;
-- These two functions are service-only: clients cannot publish arbitrary PDFs.
CREATE FUNCTION public.finish_document_job(target_report uuid,token uuid,report_file text,invoice_file text,failure text DEFAULT NULL) RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE j public.document_jobs%ROWTYPE;v uuid;BEGIN
 SELECT * INTO j FROM public.document_jobs WHERE report_id=target_report FOR UPDATE;
 IF NOT FOUND OR j.lease IS DISTINCT FROM token OR j.status<>'processing' THEN RAISE EXCEPTION 'STALE_JOB';END IF;
 IF failure IS NOT NULL THEN UPDATE public.document_jobs SET status='failed',last_error=left(failure,200),updated_at=now() WHERE report_id=target_report;RETURN;END IF;
 SELECT visit_id INTO v FROM public.visit_reports WHERE id=target_report;
 IF report_file<>j.tenant_id::text||'/'||v::text||'/'||token::text||'.pdf' OR invoice_file<>j.tenant_id::text||'/'||j.invoice_id::text||'/'||token::text||'.pdf'
 OR NOT EXISTS(SELECT 1 FROM storage.objects WHERE bucket_id='report-pdfs' AND name=report_file) OR NOT EXISTS(SELECT 1 FROM storage.objects WHERE bucket_id='invoice-pdfs' AND name=invoice_file) THEN RAISE EXCEPTION 'UPLOADED_PDFS_REQUIRED';END IF;
 UPDATE public.invoices SET pdf_path=invoice_file WHERE id=j.invoice_id;
 UPDATE public.document_jobs SET status='ready',report_path=report_file,last_error=NULL,updated_at=now() WHERE report_id=target_report;
END; $$;
INSERT INTO storage.buckets(id,name,public,file_size_limit,allowed_mime_types) VALUES('report-pdfs','report-pdfs',false,20971520,ARRAY['application/pdf']),('brand-assets','brand-assets',false,2097152,ARRAY['image/png','image/jpeg']),('document-assets','document-assets',false,2097152,ARRAY['font/ttf','application/octet-stream']);
CREATE POLICY report_pdf_read ON storage.objects FOR SELECT TO authenticated USING(bucket_id='report-pdfs' AND EXISTS(SELECT 1 FROM public.document_jobs j JOIN public.visit_reports r ON r.id=j.report_id WHERE j.report_path=name AND j.tenant_id::text=split_part(name,'/',1) AND (app_private.is_admin(j.tenant_id) OR app_private.assigned_visit(j.tenant_id,r.visit_id) OR EXISTS(SELECT 1 FROM public.visits v WHERE v.id=r.visit_id AND app_private.client_access(v.tenant_id,v.client_id)))));
CREATE POLICY brand_asset_read ON storage.objects FOR SELECT TO authenticated USING(bucket_id='brand-assets' AND EXISTS(SELECT 1 FROM public.brand_config b WHERE b.tenant_id::text=split_part(name,'/',1)));
CREATE POLICY brand_asset_insert ON storage.objects FOR INSERT TO authenticated WITH CHECK(bucket_id='brand-assets' AND EXISTS(SELECT 1 FROM public.brand_config b WHERE b.tenant_id::text=split_part(name,'/',1) AND app_private.is_admin(b.tenant_id)));
CREATE POLICY brand_asset_update ON storage.objects FOR UPDATE TO authenticated USING(bucket_id='brand-assets' AND EXISTS(SELECT 1 FROM public.brand_config b WHERE b.tenant_id::text=split_part(name,'/',1) AND app_private.is_admin(b.tenant_id))) WITH CHECK(bucket_id='brand-assets' AND EXISTS(SELECT 1 FROM public.brand_config b WHERE b.tenant_id::text=split_part(name,'/',1) AND app_private.is_admin(b.tenant_id)));
REVOKE ALL ON FUNCTION public.set_client_portal(uuid,boolean),public.record_invoice_paid(uuid,text),public.claim_document_job(uuid) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.set_client_portal(uuid,boolean),public.record_invoice_paid(uuid,text),public.claim_document_job(uuid) TO authenticated;
REVOKE ALL ON FUNCTION public.finish_document_job(uuid,uuid,text,text,text) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.finish_document_job(uuid,uuid,text,text,text) TO service_role;
DO $$ DECLARE tab text;BEGIN FOREACH tab IN ARRAY ARRAY['document_jobs','visit_reports','report_invoices'] LOOP IF NOT EXISTS(SELECT 1 FROM pg_publication_tables WHERE pubname='supabase_realtime' AND schemaname='public' AND tablename=tab) THEN EXECUTE format('ALTER PUBLICATION supabase_realtime ADD TABLE public.%I',tab);END IF;END LOOP;END $$;

CREATE FUNCTION public.attach_portal_profile(company uuid,customer uuid,account uuid) RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE c public.clients%ROWTYPE;BEGIN
 PERFORM pg_advisory_xact_lock(hashtextextended(customer::text,0));
 SELECT * INTO c FROM public.clients WHERE id=customer AND tenant_id=company;
 IF NOT FOUND OR EXISTS(SELECT 1 FROM public.profiles WHERE tenant_id=company AND client_id=customer AND role='client') THEN RAISE EXCEPTION 'CLIENT_ALREADY_HAS_ACCOUNT_OR_MISSING';END IF;
 INSERT INTO public.profiles(id,tenant_id,client_id,role,full_name,portal_enabled,is_active) VALUES(account,company,customer,'client',c.display_name,c.portal_enabled,true);
END; $$;
REVOKE ALL ON FUNCTION public.attach_portal_profile(uuid,uuid,uuid) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.attach_portal_profile(uuid,uuid,uuid) TO service_role;

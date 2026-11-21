-- Align document publication locks with collection (invoice, then job).
CREATE OR REPLACE FUNCTION public.finish_document_job(target_report uuid,token uuid,report_file text,invoice_file text,failure text DEFAULT NULL) RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE j public.document_jobs%ROWTYPE;v uuid;invoice uuid;BEGIN
 SELECT invoice_id INTO invoice FROM public.document_jobs WHERE report_id=target_report;
 PERFORM 1 FROM public.invoices WHERE id=invoice FOR UPDATE;
 SELECT * INTO j FROM public.document_jobs WHERE report_id=target_report FOR UPDATE;
 IF NOT FOUND OR j.lease IS DISTINCT FROM token OR j.status<>'processing' THEN RAISE EXCEPTION 'STALE_JOB';END IF;
 IF failure IS NOT NULL THEN UPDATE public.document_jobs SET status='failed',last_error=left(failure,200),updated_at=now() WHERE report_id=target_report;RETURN;END IF;
 SELECT visit_id INTO v FROM public.visit_reports WHERE id=target_report;
 IF report_file<>j.tenant_id::text||'/'||v::text||'/'||token::text||'.pdf' OR invoice_file<>j.tenant_id::text||'/'||j.invoice_id::text||'/'||token::text||'.pdf'
 OR NOT EXISTS(SELECT 1 FROM storage.objects WHERE bucket_id='report-pdfs' AND name=report_file) OR NOT EXISTS(SELECT 1 FROM storage.objects WHERE bucket_id='invoice-pdfs' AND name=invoice_file) THEN RAISE EXCEPTION 'UPLOADED_PDFS_REQUIRED';END IF;
 UPDATE public.invoices SET pdf_path=invoice_file WHERE id=j.invoice_id;
 UPDATE public.document_jobs SET status='ready',report_path=report_file,last_error=NULL,updated_at=now() WHERE report_id=target_report;
END; $$;
CREATE INDEX document_jobs_invoice ON public.document_jobs(invoice_id);
CREATE FUNCTION app_private.validate_contract_billable_total() RETURNS trigger LANGUAGE plpgsql SET search_path='' AS $$
DECLARE months integer;span integer;cycles integer;BEGIN
 IF NEW.app_managed THEN
 span:=CASE NEW.billing_cycle WHEN 'monthly' THEN 1 WHEN 'quarterly' THEN 3 WHEN 'annual' THEN 12 END;
 months:=(extract(year FROM NEW.ends_on)::integer-extract(year FROM NEW.starts_on)::integer)*12+extract(month FROM NEW.ends_on)::integer-extract(month FROM NEW.starts_on)::integer;
 cycles:=months/span+1;
 IF span IS NULL OR NEW.billing_amount*100<cycles THEN RAISE EXCEPTION 'TOTAL_MUST_COVER_AT_LEAST_ONE_CENT_PER_CYCLE';END IF;
 END IF;RETURN NEW;
END; $$;
CREATE TRIGGER contract_billable_total BEFORE INSERT OR UPDATE OF billing_amount,starts_on,ends_on,billing_cycle,app_managed ON public.contracts FOR EACH ROW EXECUTE FUNCTION app_private.validate_contract_billable_total();

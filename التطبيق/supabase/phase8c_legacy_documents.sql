-- Explicit opt-in for historical reports; never silently backfill debt.
CREATE FUNCTION app_private.ensure_report_billing(target_report uuid) RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE r public.visit_reports%ROWTYPE;v public.visits%ROWTYPE;c public.contracts%ROWTYPE;i public.invoices%ROWTYPE;zone text;day date;period date;finish date;span integer;delta integer;cycles integer;cycle_index integer;charge numeric(12,2);
BEGIN
 SELECT * INTO r FROM public.visit_reports WHERE id=target_report AND status='submitted' FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'SUBMITTED_REPORT_REQUIRED';END IF;
 IF EXISTS(SELECT 1 FROM public.report_invoices WHERE report_id=r.id) THEN RETURN;END IF;
 SELECT * INTO v FROM public.visits WHERE id=r.visit_id FOR UPDATE;
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
 INSERT INTO public.report_invoices VALUES(v.tenant_id,r.id,i.id);
 INSERT INTO public.document_jobs(report_id,tenant_id,invoice_id) VALUES(r.id,v.tenant_id,i.id);
 RETURN;
END; $$;
CREATE OR REPLACE FUNCTION app_private.bill_submitted_report() RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
 IF NEW.status<>'submitted' THEN RETURN NEW;END IF;
 IF TG_OP='UPDATE' THEN IF OLD.status='submitted' THEN RETURN NEW;END IF;END IF;
 PERFORM app_private.ensure_report_billing(NEW.id);RETURN NEW;
END; $$;
CREATE FUNCTION public.prepare_legacy_report(target_report uuid) RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE company uuid:=app_private.ops_admin_tenant();BEGIN
 IF NOT EXISTS(SELECT 1 FROM public.visit_reports WHERE id=target_report AND tenant_id=company AND status='submitted') THEN RAISE EXCEPTION 'REPORT_REQUIRED';END IF;
 PERFORM app_private.ensure_report_billing(target_report);
END; $$;
REVOKE ALL ON FUNCTION app_private.ensure_report_billing(uuid) FROM PUBLIC,anon,authenticated;
REVOKE ALL ON FUNCTION public.prepare_legacy_report(uuid) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.prepare_legacy_report(uuid) TO authenticated;

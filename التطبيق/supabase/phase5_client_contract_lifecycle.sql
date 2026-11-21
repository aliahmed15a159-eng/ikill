-- Product phase four; migration numbered five because phase4_instapay_qr exists.
ALTER TABLE public.client_sites ADD COLUMN contact_phone text CHECK(length(contact_phone)<=30);
ALTER TABLE public.contracts DROP CONSTRAINT contracts_visits_per_month_check;
ALTER TABLE public.contracts ADD CONSTRAINT contracts_visits_per_month_check CHECK(visits_per_month BETWEEN 1 AND 600);
ALTER TABLE public.contracts ADD COLUMN app_managed boolean NOT NULL DEFAULT false;
ALTER TABLE public.contracts ADD COLUMN signed_by_name text;
ALTER TABLE public.contracts ADD COLUMN signature_reference text;
ALTER TABLE public.contracts ADD COLUMN signed_at timestamptz;
ALTER TABLE public.contracts ADD COLUMN activated_by uuid;
ALTER TABLE public.contracts ADD COLUMN generated_visit_count integer;
ALTER TABLE public.contracts ADD FOREIGN KEY(tenant_id,activated_by) REFERENCES public.profiles(tenant_id,id);
ALTER TABLE public.visits ADD COLUMN recurrence_month date;
ALTER TABLE public.visits ADD COLUMN recurrence_index integer CHECK(recurrence_index>0);
CREATE UNIQUE INDEX contract_visit_occurrence ON public.visits(contract_id,site_id,recurrence_month,recurrence_index) WHERE recurrence_month IS NOT NULL;
CREATE TABLE public.contract_site_plans (
 tenant_id uuid NOT NULL, client_id uuid NOT NULL, contract_id uuid NOT NULL, site_id uuid NOT NULL,
 visits_per_month integer NOT NULL CHECK(visits_per_month BETWEEN 1 AND 12),
 PRIMARY KEY(contract_id,site_id),
 FOREIGN KEY(tenant_id,client_id,contract_id) REFERENCES public.contracts(tenant_id,client_id,id),
 FOREIGN KEY(tenant_id,client_id,site_id) REFERENCES public.client_sites(tenant_id,client_id,id)
);
ALTER TABLE public.contract_site_plans ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.contract_site_plans FORCE ROW LEVEL SECURITY;
REVOKE ALL ON public.contract_site_plans FROM PUBLIC,anon,authenticated;
GRANT SELECT ON public.contract_site_plans TO authenticated;
GRANT ALL ON public.contract_site_plans TO service_role;
CREATE POLICY contract_plan_admin_read ON public.contract_site_plans FOR SELECT TO authenticated USING(app_private.is_admin(tenant_id));
CREATE FUNCTION app_private.guard_app_contract() RETURNS trigger LANGUAGE plpgsql SET search_path='' AS $$
BEGIN
 IF TG_OP='DELETE' THEN
 IF OLD.app_managed AND OLD.status<>'draft' THEN RAISE EXCEPTION 'SIGNED_CONTRACT_IMMUTABLE'; END IF; RETURN OLD;
 END IF;
 IF TG_OP='UPDATE' AND OLD.app_managed AND OLD.signed_at IS NOT NULL AND NEW.status='draft' THEN RAISE EXCEPTION 'SIGNED_CONTRACT_IMMUTABLE'; END IF;
 IF TG_OP='UPDATE' AND OLD.app_managed AND OLD.status<>'draft' AND
 (to_jsonb(NEW)-ARRAY['updated_at','status']) IS DISTINCT FROM (to_jsonb(OLD)-ARRAY['updated_at','status'])
 THEN RAISE EXCEPTION 'SIGNED_CONTRACT_IMMUTABLE'; END IF;
 IF NEW.app_managed AND NEW.status='active' AND (NEW.signed_at IS NULL OR NEW.activated_by IS NULL
 OR length(btrim(coalesce(NEW.signed_by_name,'')))=0 OR length(btrim(coalesce(NEW.signature_reference,'')))=0
 OR coalesce(NEW.generated_visit_count,0)<=0) THEN RAISE EXCEPTION 'ACTIVATION_REQUIRED'; END IF;
 RETURN NEW;
END; $$;
CREATE TRIGGER app_contract_guard BEFORE INSERT OR UPDATE OR DELETE ON public.contracts FOR EACH ROW EXECUTE FUNCTION app_private.guard_app_contract();
CREATE FUNCTION public.save_client_contract(contract_id uuid,customer_id uuid,starts date,ends date,total numeric,cycle text,plans jsonb) RETURNS uuid
 LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE company uuid; item public.contracts%ROWTYPE; plan jsonb; site uuid; frequency integer; sum_frequency integer:=0; zone text;
BEGIN
 SELECT p.tenant_id,t.timezone INTO company,zone FROM public.profiles p JOIN public.tenants t ON t.id=p.tenant_id WHERE p.id=(SELECT auth.uid()) AND app_private.is_admin(p.tenant_id);
 IF company IS NULL THEN RAISE EXCEPTION 'ADMIN_REQUIRED'; END IF;
 IF NOT EXISTS(SELECT 1 FROM public.clients WHERE tenant_id=company AND id=customer_id AND client_type='contract') THEN RAISE EXCEPTION 'CONTRACT_CLIENT_REQUIRED'; END IF;
 IF contract_id IS NULL OR starts IS NULL OR ends IS NULL OR ends<starts OR ends>=starts+interval '36 months'
 OR total IS NULL OR total<=0 OR total<>round(total,2) OR cycle IS NULL OR cycle NOT IN ('monthly','quarterly','annual')
 OR plans IS NULL OR jsonb_typeof(plans)<>'array' OR jsonb_array_length(plans) NOT BETWEEN 1 AND 50
 THEN RAISE EXCEPTION 'INVALID_CONTRACT'; END IF;
 PERFORM pg_advisory_xact_lock(hashtextextended(contract_id::text,0));
 SELECT * INTO item FROM public.contracts WHERE id=contract_id FOR UPDATE;
 IF FOUND AND (item.tenant_id<>company OR item.client_id<>customer_id OR item.status<>'draft' OR NOT item.app_managed) THEN RAISE EXCEPTION 'CONTRACT_NOT_EDITABLE'; END IF;
 INSERT INTO public.contracts(id,tenant_id,client_id,contract_number,starts_on,ends_on,visits_per_month,billing_cycle,billing_amount,currency,app_managed)
 SELECT contract_id,company,customer_id,contract_id::text,starts,ends,1,cycle,total,currency,true FROM public.tenants WHERE id=company
 ON CONFLICT(id) DO UPDATE SET starts_on=excluded.starts_on,ends_on=excluded.ends_on,billing_cycle=excluded.billing_cycle,billing_amount=excluded.billing_amount;
 DELETE FROM public.contract_site_plans WHERE contract_site_plans.contract_id=save_client_contract.contract_id;
 FOR plan IN SELECT value FROM jsonb_array_elements(plans) LOOP
 site:=(plan->>'site_id')::uuid; frequency:=(plan->>'visits_per_month')::integer;
 IF frequency IS NULL OR frequency NOT BETWEEN 1 AND 12 OR NOT EXISTS(SELECT 1 FROM public.client_sites WHERE tenant_id=company AND client_id=customer_id AND id=site AND is_active)
 THEN RAISE EXCEPTION 'INVALID_SITE_PLAN'; END IF;
 INSERT INTO public.contract_site_plans VALUES(company,customer_id,contract_id,site,frequency);
 sum_frequency:=sum_frequency+frequency;
 END LOOP;
 UPDATE public.contracts SET visits_per_month=sum_frequency WHERE id=contract_id;
 RETURN contract_id;
END; $$;
CREATE FUNCTION public.activate_client_contract(contract_id uuid,signer text,reference text) RETURNS integer
 LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE item public.contracts%ROWTYPE; plan record; month_start date; first_day date; last_day date; day_count integer;
 occurrence integer; start_time timestamptz; total_count integer:=0; zone text;
BEGIN
 SELECT * INTO item FROM public.contracts WHERE id=contract_id FOR UPDATE;
 IF NOT FOUND OR NOT app_private.is_admin(item.tenant_id) THEN RAISE EXCEPTION 'ADMIN_REQUIRED'; END IF;
 IF NOT item.app_managed THEN RAISE EXCEPTION 'APP_CONTRACT_REQUIRED'; END IF;
 IF item.status='active' THEN RETURN item.generated_visit_count; END IF;
 IF item.status<>'draft' OR NOT coalesce(length(btrim(signer)) BETWEEN 1 AND 150,false)
 OR NOT coalesce(length(btrim(reference)) BETWEEN 1 AND 300,false) THEN RAISE EXCEPTION 'SIGNATURE_REQUIRED'; END IF;
 SELECT timezone INTO zone FROM public.tenants WHERE id=item.tenant_id;
 IF item.starts_on<=(now() AT TIME ZONE zone)::date THEN RAISE EXCEPTION 'START_MUST_BE_FUTURE_DATE'; END IF;
 PERFORM 1 FROM public.clients WHERE tenant_id=item.tenant_id AND id=item.client_id AND client_type='contract' FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'CONTRACT_CLIENT_REQUIRED'; END IF;
 IF EXISTS(SELECT 1 FROM public.contracts WHERE tenant_id=item.tenant_id AND client_id=item.client_id AND id<>item.id AND status='active'
 AND starts_on<=item.ends_on AND ends_on>=item.starts_on) THEN RAISE EXCEPTION 'OVERLAPPING_CONTRACT'; END IF;
 IF NOT EXISTS(SELECT 1 FROM public.contract_site_plans WHERE contract_site_plans.contract_id=item.id) THEN RAISE EXCEPTION 'SITES_REQUIRED'; END IF;
 IF EXISTS(SELECT 1 FROM public.client_sites s WHERE s.tenant_id=item.tenant_id AND s.client_id=item.client_id AND s.is_active AND NOT EXISTS(SELECT 1 FROM public.contract_site_plans p WHERE p.contract_id=item.id AND p.site_id=s.id)) THEN RAISE EXCEPTION 'ALL_ACTIVE_SITES_REQUIRED'; END IF;
 FOR plan IN SELECT p.* FROM public.contract_site_plans p WHERE p.contract_id=item.id ORDER BY p.site_id LOOP
 PERFORM 1 FROM public.client_sites WHERE tenant_id=item.tenant_id AND client_id=item.client_id AND id=plan.site_id AND is_active FOR SHARE;
 IF NOT FOUND THEN RAISE EXCEPTION 'INACTIVE_SITE'; END IF;
 IF NOT EXISTS(SELECT 1 FROM public.surveys WHERE tenant_id=item.tenant_id AND client_id=item.client_id AND site_id=plan.site_id AND status='completed' AND proposed_total IS NOT NULL)
 THEN RAISE EXCEPTION 'COMPLETE_SITE_SURVEY_FIRST'; END IF;
 month_start:=date_trunc('month',item.starts_on)::date;
 WHILE month_start<=item.ends_on LOOP
 first_day:=greatest(month_start,item.starts_on); last_day:=least((month_start+interval '1 month - 1 day')::date,item.ends_on);
 day_count:=last_day-first_day+1;
 IF day_count<plan.visits_per_month THEN RAISE EXCEPTION 'PARTIAL_MONTH_TOO_SHORT'; END IF;
 FOR occurrence IN 1..plan.visits_per_month LOOP
 start_time:=((first_day+floor((occurrence-1)*day_count::numeric/plan.visits_per_month)::integer)+time '10:00') AT TIME ZONE zone;
 INSERT INTO public.visits(tenant_id,client_id,site_id,contract_id,status,scheduled_start,scheduled_end,recurrence_month,recurrence_index,instructions)
 VALUES(item.tenant_id,item.client_id,plan.site_id,item.id,'scheduled',start_time,start_time+interval '1 hour',month_start,occurrence,'Auto-generated contract visit; confirm appointment with site contact');
 total_count:=total_count+1;
 IF total_count>5000 THEN RAISE EXCEPTION 'TOO_MANY_VISITS'; END IF;
 END LOOP;
 month_start:=(month_start+interval '1 month')::date;
 END LOOP;
 END LOOP;
 UPDATE public.contracts SET status='active',signed_by_name=btrim(signer),signature_reference=btrim(reference),signed_at=now(),activated_by=(SELECT auth.uid()),generated_visit_count=total_count WHERE id=item.id;
 UPDATE public.clients SET status='active' WHERE id=item.client_id AND tenant_id=item.tenant_id;
 RETURN total_count;
END; $$;
CREATE FUNCTION public.reschedule_contract_visit(visit_id uuid,starts timestamptz,ends timestamptz,technician uuid) RETURNS void
 LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE item public.visits%ROWTYPE; agreement public.contracts%ROWTYPE; zone text;
BEGIN
 SELECT * INTO item FROM public.visits WHERE id=visit_id FOR UPDATE;
 IF NOT FOUND OR NOT app_private.is_admin(item.tenant_id) THEN RAISE EXCEPTION 'ADMIN_REQUIRED'; END IF;
 SELECT * INTO agreement FROM public.contracts WHERE id=item.contract_id AND tenant_id=item.tenant_id;
 SELECT timezone INTO zone FROM public.tenants WHERE id=item.tenant_id;
 IF agreement.id IS NULL OR agreement.status<>'active' OR agreement.app_managed IS NOT TRUE OR item.status NOT IN ('scheduled','confirmed')
 OR starts IS NULL OR ends IS NULL OR starts<=now() OR ends<=starts
 OR (starts AT TIME ZONE zone)::date<agreement.starts_on OR (ends AT TIME ZONE zone)::date>agreement.ends_on
 THEN RAISE EXCEPTION 'INVALID_RESCHEDULE'; END IF;
 UPDATE public.visits SET scheduled_start=starts,scheduled_end=ends,technician_id=technician WHERE id=item.id;
END; $$;
REVOKE ALL ON FUNCTION public.save_client_contract(uuid,uuid,date,date,numeric,text,jsonb),public.activate_client_contract(uuid,text,text),public.reschedule_contract_visit(uuid,timestamptz,timestamptz,uuid) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.save_client_contract(uuid,uuid,date,date,numeric,text,jsonb),public.activate_client_contract(uuid,text,text),public.reschedule_contract_visit(uuid,timestamptz,timestamptz,uuid) TO authenticated;

-- App-only request workflow. Existing website RPCs and data are unchanged.
ALTER TABLE public.pricing_matrix DROP CONSTRAINT pricing_matrix_property_type_check;
ALTER TABLE public.pricing_matrix ADD CONSTRAINT pricing_matrix_property_type_check CHECK
 (property_type IN ('studio','apartment','villa','house','townhouse','residential_building','other_residential'));
ALTER TABLE public.surveys DROP CONSTRAINT surveys_status_check;
ALTER TABLE public.surveys ADD CONSTRAINT surveys_status_check CHECK
 (status IN ('draft','survey_pending','scheduled','completed','cancelled'));
ALTER TABLE public.visits ALTER COLUMN scheduled_start DROP NOT NULL;
ALTER TABLE public.visits ALTER COLUMN scheduled_end DROP NOT NULL;
ALTER TABLE public.visits DROP CONSTRAINT visits_status_check;
ALTER TABLE public.visits ADD CONSTRAINT visits_status_check CHECK
 (status IN ('pending_schedule','scheduled','confirmed','in_progress','completed','cancelled','no_access'));
ALTER TABLE public.visits ADD CONSTRAINT visits_schedule_required CHECK (
 (status='pending_schedule' AND scheduled_start IS NULL AND scheduled_end IS NULL)
 OR (status='cancelled' AND ((scheduled_start IS NULL AND scheduled_end IS NULL)
 OR (scheduled_start IS NOT NULL AND scheduled_end IS NOT NULL AND scheduled_end>scheduled_start)))
 OR (status NOT IN ('pending_schedule','cancelled') AND scheduled_start IS NOT NULL
 AND scheduled_end IS NOT NULL AND scheduled_end>scheduled_start));
ALTER TABLE public.visits ADD COLUMN property_type text;
ALTER TABLE public.visits ADD COLUMN problem_code text;
ALTER TABLE public.visits ADD COLUMN quoted_amount numeric(12,2) CHECK(quoted_amount>=0);
ALTER TABLE public.visits ADD COLUMN quoted_currency text CHECK(quoted_currency ~ '^[A-Z]{3}$');
ALTER TABLE public.visits ADD COLUMN payment_reference text;
ALTER TABLE public.visits ADD COLUMN payment_review text NOT NULL DEFAULT 'not_required'
 CHECK(payment_review IN ('not_required','pending_review','verified','rejected'));
ALTER TABLE public.visits ADD COLUMN payment_verified_by uuid;
ALTER TABLE public.visits ADD COLUMN payment_verified_at timestamptz;
ALTER TABLE public.visits ADD FOREIGN KEY(tenant_id,payment_verified_by) REFERENCES public.profiles(tenant_id,id);
ALTER TABLE public.visits ADD CONSTRAINT visit_verification_consistent CHECK
 ((payment_review='verified' AND payment_verified_by IS NOT NULL AND payment_verified_at IS NOT NULL)
 OR (payment_review<>'verified' AND payment_verified_by IS NULL AND payment_verified_at IS NULL));

CREATE TABLE public.app_request_receipts (
 id uuid PRIMARY KEY,
 tenant_id uuid NOT NULL REFERENCES public.tenants(id),
 payload_hash text NOT NULL,
 client_id uuid NOT NULL,
 site_id uuid NOT NULL,
 visit_id uuid,
 survey_id uuid,
 receipt jsonb NOT NULL,
 created_at timestamptz NOT NULL DEFAULT now(),
 FOREIGN KEY(tenant_id,client_id,site_id) REFERENCES public.client_sites(tenant_id,client_id,id),
 FOREIGN KEY(tenant_id,client_id,visit_id) REFERENCES public.visits(tenant_id,client_id,id),
 FOREIGN KEY(tenant_id,client_id,survey_id) REFERENCES public.surveys(tenant_id,client_id,id),
 CHECK((visit_id IS NULL)<>(survey_id IS NULL))
);
ALTER TABLE public.app_request_receipts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.app_request_receipts FORCE ROW LEVEL SECURITY;
REVOKE ALL ON public.app_request_receipts FROM PUBLIC,anon,authenticated;
GRANT SELECT ON public.app_request_receipts TO authenticated;
GRANT ALL ON public.app_request_receipts TO service_role;
CREATE POLICY receipt_admin_read ON public.app_request_receipts FOR SELECT TO authenticated
 USING(app_private.is_admin(tenant_id));
CREATE INDEX ON public.app_request_receipts(tenant_id,created_at);

-- No prices are seeded: the company must configure its real prices first.
INSERT INTO public.services_catalog(tenant_id,code,name_ar,name_en)
 SELECT id,'residential_pest','مكافحة الآفات السكنية','Residential pest control'
 FROM public.tenants ON CONFLICT(tenant_id,code) DO NOTHING;

CREATE FUNCTION public.get_residential_quote(brand_slug text,property text,problem text) RETURNS jsonb
 LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $$
 SELECT jsonb_build_object('price_id',p.id,'amount',p.fixed_price,'currency',p.currency)
 FROM public.pricing_matrix p JOIN public.services_catalog s ON s.tenant_id=p.tenant_id AND s.id=p.service_id
 JOIN public.tenants t ON t.id=p.tenant_id
 WHERE t.slug=brand_slug AND t.is_active AND s.code='residential_pest' AND s.is_active AND p.is_active
 AND p.property_type=property AND p.problem_code=problem AND p.fixed_price>0 AND p.currency=t.currency
 AND property IN ('apartment','villa','house') AND problem IN ('cockroaches','rodents','bed_bugs','general_pests');
$$;
CREATE FUNCTION public.save_residential_price(property text,problem text,amount numeric,enabled boolean) RETURNS void
 LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
 DECLARE company uuid; service uuid; money text;
 BEGIN
 SELECT p.tenant_id,t.currency INTO company,money FROM public.profiles p JOIN public.tenants t ON t.id=p.tenant_id
 WHERE p.id=(SELECT auth.uid()) AND app_private.is_admin(p.tenant_id);
 IF company IS NULL THEN RAISE EXCEPTION 'ADMIN_REQUIRED'; END IF;
 IF property IS NULL OR property NOT IN ('apartment','villa','house') OR problem IS NULL
 OR problem NOT IN ('cockroaches','rodents','bed_bugs','general_pests') OR amount IS NULL
 OR amount<=0 OR amount>9999999999.99 OR amount<>round(amount,2) OR enabled IS NULL THEN
 RAISE EXCEPTION 'INVALID_PRICE'; END IF;
 INSERT INTO public.services_catalog(tenant_id,code,name_ar,name_en)
 VALUES(company,'residential_pest','مكافحة الآفات السكنية','Residential pest control')
 ON CONFLICT(tenant_id,code) DO NOTHING;
 SELECT id INTO service FROM public.services_catalog WHERE tenant_id=company AND code='residential_pest';
 INSERT INTO public.pricing_matrix(tenant_id,service_id,property_type,problem_code,fixed_price,currency,is_active)
 VALUES(company,service,property,problem,amount,money,enabled)
 ON CONFLICT(tenant_id,service_id,property_type,problem_code) DO UPDATE
 SET fixed_price=excluded.fixed_price,currency=excluded.currency,is_active=excluded.is_active;
 END;
$$;

CREATE FUNCTION public.submit_app_request(brand_slug text,request_id uuid,payload jsonb) RETURNS jsonb
 LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
 DECLARE company uuid; money text; fingerprint text; previous public.app_request_receipts%ROWTYPE;
 price public.pricing_matrix%ROWTYPE; customer uuid; site uuid; visit uuid; survey uuid; answer jsonb;
 kind text:=payload->>'kind'; latitude numeric; longitude numeric;
 BEGIN
 SELECT id,currency INTO company,money FROM public.tenants WHERE slug=brand_slug AND is_active;
 IF company IS NULL OR request_id IS NULL OR payload IS NULL OR jsonb_typeof(payload)<>'object' THEN
 RAISE EXCEPTION 'INVALID_REQUEST'; END IF;
 fingerprint:=encode(sha256(convert_to(payload::text,'UTF8')),'hex');
 PERFORM pg_advisory_xact_lock(hashtextextended(request_id::text,0));
 SELECT * INTO previous FROM public.app_request_receipts WHERE id=request_id;
 IF FOUND THEN
 IF previous.tenant_id<>company OR previous.payload_hash<>fingerprint THEN RAISE EXCEPTION 'IDEMPOTENCY_CONFLICT'; END IF;
 RETURN previous.receipt;
 END IF;
 IF kind IS NULL OR kind NOT IN ('residential','contract')
 OR NOT coalesce(length(btrim(payload->>'name')) BETWEEN 1 AND 100,false)
 OR NOT coalesce(length(payload->>'phone') BETWEEN 7 AND 20 AND (payload->>'phone') ~ '^\+?[0-9 ()-]+$',false)
 OR NOT coalesce(length(payload->>'email') BETWEEN 3 AND 150 AND
 (payload->>'email') ~ '^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$',false)
 OR NOT coalesce(length(btrim(payload->>'address')) BETWEEN 1 AND 200,false)
 OR length(coalesce(payload->>'message',''))>2000 OR payload->>'consent'<>'true'
 OR payload->>'consent' IS NULL THEN RAISE EXCEPTION 'INVALID_CONTACT'; END IF;
 -- Only these fields are accepted. Roles, tenant IDs, statuses, payment flags
 -- and authoritative totals may NEVER be supplied by the caller.
 IF payload - ARRAY['kind','name','phone','email','address','message','consent','property','problem',
 'price_id','expected_amount','expected_currency','payment_reference','facility','sector','latitude','longitude'] <> '{}'::jsonb
 THEN RAISE EXCEPTION 'INVALID_FIELDS'; END IF;
 IF kind='residential' THEN
 SELECT p.* INTO price FROM public.pricing_matrix p JOIN public.services_catalog s ON s.id=p.service_id AND s.tenant_id=p.tenant_id
 WHERE p.tenant_id=company AND p.id=(payload->>'price_id')::uuid AND p.is_active
 AND p.property_type=payload->>'property' AND p.problem_code=payload->>'problem'
 AND p.property_type IN ('apartment','villa','house') AND p.problem_code IN ('cockroaches','rodents','bed_bugs','general_pests')
 AND s.code='residential_pest' AND s.is_active FOR SHARE OF p,s;
 IF NOT FOUND OR price.fixed_price<=0 OR price.currency<>money
 OR price.fixed_price IS DISTINCT FROM (payload->>'expected_amount')::numeric
 OR price.currency IS DISTINCT FROM payload->>'expected_currency' THEN RAISE EXCEPTION 'PRICE_CHANGED'; END IF;
 IF NOT coalesce(length(btrim(payload->>'payment_reference')) BETWEEN 3 AND 100,false) THEN RAISE EXCEPTION 'PAYMENT_REFERENCE_REQUIRED'; END IF;
 ELSE
 IF NOT coalesce(length(btrim(payload->>'facility')) BETWEEN 1 AND 150,false)
 OR NOT coalesce((payload->>'sector') IN ('factory','restaurant','commercial','industrial','other'),false)
 THEN RAISE EXCEPTION 'INVALID_FACILITY'; END IF;
 latitude:=nullif(payload->>'latitude','')::numeric;
 longitude:=nullif(payload->>'longitude','')::numeric;
 IF (latitude IS NULL)<>(longitude IS NULL) OR latitude NOT BETWEEN -90 AND 90 OR longitude NOT BETWEEN -180 AND 180
 THEN RAISE EXCEPTION 'INVALID_LOCATION'; END IF;
 END IF;
 PERFORM pg_advisory_xact_lock(hashtextextended(company::text||lower(payload->>'email'),0));
 IF (SELECT count(*) FROM public.clients WHERE tenant_id=company AND lower(email)=lower(payload->>'email')
 AND created_at>now()-interval '24 hours')>=5 THEN RAISE EXCEPTION 'DAILY_LIMIT'; END IF;
 INSERT INTO public.clients(tenant_id,client_code,display_name,client_type,status,contact_name,phone,email,billing_address,requested_service,request_message)
 VALUES(company,request_id::text,CASE WHEN kind='contract' THEN btrim(payload->>'facility') ELSE btrim(payload->>'name') END,
 CASE WHEN kind='contract' THEN 'contract' ELSE 'one_time' END,'survey_pending',btrim(payload->>'name'),
 payload->>'phone',lower(payload->>'email'),btrim(payload->>'address'),
 CASE WHEN kind='contract' THEN 'Survey request' ELSE 'Residential pest control' END,coalesce(payload->>'message','')) RETURNING id INTO customer;
 -- Residential client is active as an accepted request; payment remains UNVERIFIED.
 IF kind='residential' THEN UPDATE public.clients SET status='active' WHERE id=customer; END IF;
 INSERT INTO public.client_sites(tenant_id,client_id,name,sector,property_type,address,latitude,longitude)
 VALUES(company,customer,CASE WHEN kind='contract' THEN btrim(payload->>'facility') ELSE 'Residential site' END,
 CASE WHEN kind='contract' THEN payload->>'sector' ELSE 'residential' END,
 CASE WHEN kind='residential' THEN payload->>'property' ELSE NULL END,btrim(payload->>'address'),latitude,longitude) RETURNING id INTO site;
 IF kind='residential' THEN
 INSERT INTO public.visits(tenant_id,client_id,site_id,service_id,status,property_type,problem_code,
 quoted_amount,quoted_currency,payment_reference,payment_review,instructions)
 VALUES(company,customer,site,price.service_id,'pending_schedule',payload->>'property',payload->>'problem',
 price.fixed_price,price.currency,btrim(payload->>'payment_reference'),'pending_review',coalesce(payload->>'message','')) RETURNING id INTO visit;
 answer:=jsonb_build_object('request_id',request_id,'kind',kind,'status','pending_schedule','payment_status','pending_review');
 ELSE
 INSERT INTO public.surveys(tenant_id,client_id,site_id,status,assessment,currency)
 VALUES(company,customer,site,'survey_pending',jsonb_build_object('facility',payload->>'facility','sector',payload->>'sector',
 'request_message',coalesce(payload->>'message','')),money) RETURNING id INTO survey;
 answer:=jsonb_build_object('request_id',request_id,'kind',kind,'status','survey_pending');
 END IF;
 INSERT INTO public.app_request_receipts(id,tenant_id,payload_hash,client_id,site_id,visit_id,survey_id,receipt)
 VALUES(request_id,company,fingerprint,customer,site,visit,survey,answer);
 RETURN answer;
 END;
$$;

CREATE FUNCTION public.review_residential_payment(visit_id uuid,approved boolean) RETURNS void
 LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
 DECLARE item public.visits%ROWTYPE;
 BEGIN
 SELECT * INTO item FROM public.visits WHERE id=visit_id FOR UPDATE;
 IF NOT FOUND OR NOT app_private.is_admin(item.tenant_id) THEN RAISE EXCEPTION 'ADMIN_REQUIRED'; END IF;
 IF approved IS NULL OR item.status<>'pending_schedule' OR item.payment_review NOT IN ('pending_review','rejected')
 THEN RAISE EXCEPTION 'INVALID_PAYMENT_REVIEW'; END IF;
 UPDATE public.visits SET payment_review=CASE WHEN approved THEN 'verified' ELSE 'rejected' END,
 payment_verified_by=CASE WHEN approved THEN (SELECT auth.uid()) ELSE NULL END,
 payment_verified_at=CASE WHEN approved THEN now() ELSE NULL END WHERE id=item.id;
 END;
$$;
CREATE FUNCTION public.schedule_app_visit(visit_id uuid,starts_at timestamptz,ends_at timestamptz,assigned_technician uuid) RETURNS void
 LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
 DECLARE item public.visits%ROWTYPE;
 BEGIN
 SELECT * INTO item FROM public.visits WHERE id=visit_id FOR UPDATE;
 IF NOT FOUND OR NOT app_private.is_admin(item.tenant_id) THEN RAISE EXCEPTION 'ADMIN_REQUIRED'; END IF;
 IF item.status<>'pending_schedule' OR item.payment_review<>'verified' THEN RAISE EXCEPTION 'PAYMENT_REVIEW_REQUIRED'; END IF;
 IF starts_at IS NULL OR ends_at IS NULL OR starts_at<=now() OR ends_at<=starts_at OR assigned_technician IS NULL
 THEN RAISE EXCEPTION 'INVALID_SCHEDULE'; END IF;
 UPDATE public.visits SET scheduled_start=starts_at,scheduled_end=ends_at,technician_id=assigned_technician,status='scheduled' WHERE id=item.id;
 END;
$$;
REVOKE ALL ON FUNCTION public.get_residential_quote(text,text,text),public.save_residential_price(text,text,numeric,boolean),
 public.submit_app_request(text,uuid,jsonb),public.review_residential_payment(uuid,boolean),
 public.schedule_app_visit(uuid,timestamptz,timestamptz,uuid) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.get_residential_quote(text,text,text),public.submit_app_request(text,uuid,jsonb) TO anon,authenticated;
GRANT EXECUTE ON FUNCTION public.save_residential_price(text,text,numeric,boolean),public.review_residential_payment(uuid,boolean),
 public.schedule_app_visit(uuid,timestamptz,timestamptz,uuid) TO authenticated;

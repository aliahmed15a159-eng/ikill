-- PHASE 1 PROPOSAL ONLY. Review and apply manually in Supabase SQL Editor.
-- Target: a new/empty Supabase app schema. Existing names cause a rollback.
-- No Firebase access, no data import, no Auth users or admin auto-provisioning.
-- UUIDs and monetary values are server-side; timestamps use timestamptz.
BEGIN;

CREATE SCHEMA IF NOT EXISTS app_private;
REVOKE ALL ON SCHEMA app_private FROM PUBLIC, anon;
GRANT USAGE ON SCHEMA app_private TO authenticated;

CREATE TABLE public.tenants (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  slug text NOT NULL UNIQUE CHECK (slug ~ '^[a-z0-9][a-z0-9_-]{1,62}$'),
  name text NOT NULL CHECK (length(btrim(name)) > 0),
  currency text NOT NULL DEFAULT 'EGP' CHECK (currency ~ '^[A-Z]{3}$'),
  timezone text NOT NULL DEFAULT 'Africa/Cairo',
  branding jsonb NOT NULL DEFAULT '{}'::jsonb CHECK (jsonb_typeof(branding) = 'object'),
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

-- One Auth account belongs to one tenant in phase 1. A future membership table
-- is needed if the SAME account must act in more than one company.
CREATE TABLE public.profiles (
  id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE RESTRICT,
  tenant_id uuid NOT NULL REFERENCES public.tenants(id) ON DELETE RESTRICT,
  role text NOT NULL DEFAULT 'client' CHECK (role IN ('admin','technician','client')),
  full_name text NOT NULL CHECK (length(btrim(full_name)) > 0),
  phone text,
  client_id uuid,
  portal_enabled boolean NOT NULL DEFAULT false,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (tenant_id, id),
  CHECK ((role = 'client' AND client_id IS NOT NULL)
      OR (role IN ('admin','technician') AND client_id IS NULL)),
  CHECK (NOT portal_enabled OR role = 'client')
);

CREATE TABLE public.services_catalog (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES public.tenants(id) ON DELETE RESTRICT,
  code text NOT NULL,
  name_ar text NOT NULL,
  name_en text,
  description text,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (tenant_id, id), UNIQUE (tenant_id, code)
);

CREATE TABLE public.pricing_matrix (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES public.tenants(id) ON DELETE RESTRICT,
  service_id uuid NOT NULL,
  property_type text NOT NULL CHECK (property_type IN
    ('studio','apartment','villa','townhouse','residential_building','other_residential')),
  problem_code text NOT NULL CHECK (length(btrim(problem_code)) > 0),
  fixed_price numeric(12,2) NOT NULL CHECK (fixed_price >= 0),
  currency text NOT NULL DEFAULT 'EGP' CHECK (currency ~ '^[A-Z]{3}$'),
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (tenant_id, id),
  UNIQUE (tenant_id, service_id, property_type, problem_code),
  FOREIGN KEY (tenant_id, service_id) REFERENCES public.services_catalog(tenant_id,id)
);

CREATE TABLE public.clients (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES public.tenants(id) ON DELETE RESTRICT,
  client_code text NOT NULL,
  display_name text NOT NULL,
  client_type text NOT NULL DEFAULT 'one_time' CHECK (client_type IN ('one_time','contract')),
  status text NOT NULL DEFAULT 'lead' CHECK (status IN ('lead','survey_pending','active','inactive')),
  contact_name text,
  phone text,
  email text,
  billing_address text,
  tax_number text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (tenant_id,id), UNIQUE (tenant_id,client_code)
);
ALTER TABLE public.profiles ADD CONSTRAINT profiles_client_tenant_fk
  FOREIGN KEY (tenant_id,client_id) REFERENCES public.clients(tenant_id,id) ON DELETE RESTRICT;

CREATE TABLE public.client_sites (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES public.tenants(id) ON DELETE RESTRICT,
  client_id uuid NOT NULL,
  name text NOT NULL,
  sector text NOT NULL,
  property_type text,
  address text NOT NULL,
  latitude numeric(9,6) CHECK (latitude BETWEEN -90 AND 90),
  longitude numeric(9,6) CHECK (longitude BETWEEN -180 AND 180),
  location_notes text,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CHECK ((latitude IS NULL) = (longitude IS NULL)),
  UNIQUE (tenant_id,id), UNIQUE (tenant_id,client_id,id),
  FOREIGN KEY (tenant_id,client_id) REFERENCES public.clients(tenant_id,id)
);

CREATE TABLE public.surveys (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES public.tenants(id) ON DELETE RESTRICT,
  client_id uuid NOT NULL,
  site_id uuid NOT NULL,
  service_id uuid,
  surveyor_id uuid,
  scheduled_at timestamptz,
  surveyed_at timestamptz,
  status text NOT NULL DEFAULT 'draft' CHECK (status IN ('draft','scheduled','completed','cancelled')),
  assessment jsonb NOT NULL DEFAULT '{}'::jsonb CHECK (jsonb_typeof(assessment) = 'object'),
  proposed_items jsonb NOT NULL DEFAULT '[]'::jsonb CHECK (jsonb_typeof(proposed_items) = 'array'),
  proposed_total numeric(12,2) CHECK (proposed_total >= 0),
  currency text NOT NULL DEFAULT 'EGP' CHECK (currency ~ '^[A-Z]{3}$'),
  internal_notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (tenant_id,id), UNIQUE (tenant_id,client_id,id),
  FOREIGN KEY (tenant_id,client_id,site_id) REFERENCES public.client_sites(tenant_id,client_id,id),
  FOREIGN KEY (tenant_id,surveyor_id) REFERENCES public.profiles(tenant_id,id),
  FOREIGN KEY (tenant_id,service_id) REFERENCES public.services_catalog(tenant_id,id)
);

-- site_id NULL: contract covers this client's sites. Otherwise site-specific.
CREATE TABLE public.contracts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES public.tenants(id) ON DELETE RESTRICT,
  client_id uuid NOT NULL,
  site_id uuid,
  survey_id uuid,
  contract_number text NOT NULL,
  starts_on date NOT NULL,
  ends_on date NOT NULL,
  visits_per_month integer NOT NULL CHECK (visits_per_month BETWEEN 1 AND 100),
  billing_cycle text NOT NULL CHECK (billing_cycle IN ('monthly','quarterly','semiannual','annual','one_time')),
  billing_amount numeric(12,2) NOT NULL CHECK (billing_amount >= 0),
  currency text NOT NULL DEFAULT 'EGP' CHECK (currency ~ '^[A-Z]{3}$'),
  status text NOT NULL DEFAULT 'draft' CHECK (status IN ('draft','active','suspended','expired','cancelled')),
  terms text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CHECK (ends_on >= starts_on),
  UNIQUE (tenant_id,id), UNIQUE (tenant_id,client_id,id), UNIQUE (tenant_id,contract_number),
  FOREIGN KEY (tenant_id,client_id) REFERENCES public.clients(tenant_id,id),
  FOREIGN KEY (tenant_id,client_id,site_id) REFERENCES public.client_sites(tenant_id,client_id,id),
  FOREIGN KEY (tenant_id,client_id,survey_id) REFERENCES public.surveys(tenant_id,client_id,id)
);

CREATE TABLE public.visits (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES public.tenants(id) ON DELETE RESTRICT,
  client_id uuid NOT NULL,
  site_id uuid NOT NULL,
  contract_id uuid,
  service_id uuid,
  technician_id uuid,
  scheduled_start timestamptz NOT NULL,
  scheduled_end timestamptz NOT NULL,
  started_at timestamptz,
  completed_at timestamptz,
  status text NOT NULL DEFAULT 'scheduled' CHECK (status IN
    ('scheduled','confirmed','in_progress','completed','cancelled','no_access')),
  instructions text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CHECK (scheduled_end > scheduled_start),
  CHECK (completed_at IS NULL OR (started_at IS NOT NULL AND completed_at >= started_at)),
  CHECK (status <> 'completed' OR completed_at IS NOT NULL),
  UNIQUE (tenant_id,id), UNIQUE (tenant_id,client_id,id), UNIQUE (tenant_id,id,technician_id),
  FOREIGN KEY (tenant_id,client_id,site_id) REFERENCES public.client_sites(tenant_id,client_id,id),
  FOREIGN KEY (tenant_id,client_id,contract_id) REFERENCES public.contracts(tenant_id,client_id,id),
  FOREIGN KEY (tenant_id,service_id) REFERENCES public.services_catalog(tenant_id,id),
  FOREIGN KEY (tenant_id,technician_id) REFERENCES public.profiles(tenant_id,id)
);

-- Storage is NOT public. These fields store private object PATHS, never signed
-- URLs or file bytes. Bucket creation/object policies are a later phase.
CREATE TABLE public.visit_reports (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES public.tenants(id) ON DELETE RESTRICT,
  visit_id uuid NOT NULL,
  technician_id uuid NOT NULL,
  status text NOT NULL DEFAULT 'draft' CHECK (status IN ('draft','submitted')),
  selections jsonb NOT NULL DEFAULT '{}'::jsonb CHECK (jsonb_typeof(selections) = 'object'),
  findings text,
  actions_taken text,
  recommendations text,
  photo_paths text[] NOT NULL DEFAULT ARRAY[]::text[],
  customer_signature_path text,
  customer_signer_name text,
  signed_at timestamptz,
  submitted_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (tenant_id,id), UNIQUE (tenant_id,visit_id),
  FOREIGN KEY (tenant_id,visit_id,technician_id) REFERENCES public.visits(tenant_id,id,technician_id),
  CHECK ((customer_signature_path IS NULL AND customer_signer_name IS NULL AND signed_at IS NULL)
      OR (customer_signature_path IS NOT NULL AND customer_signer_name IS NOT NULL AND signed_at IS NOT NULL)),
  CHECK ((status = 'draft' AND submitted_at IS NULL) OR (status = 'submitted' AND submitted_at IS NOT NULL))
);

CREATE TABLE public.invoices (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES public.tenants(id) ON DELETE RESTRICT,
  client_id uuid NOT NULL,
  site_id uuid,
  contract_id uuid,
  visit_id uuid,
  invoice_number text NOT NULL,
  issued_on date NOT NULL DEFAULT current_date,
  due_on date NOT NULL,
  currency text NOT NULL DEFAULT 'EGP' CHECK (currency ~ '^[A-Z]{3}$'),
  line_items jsonb NOT NULL DEFAULT '[]'::jsonb CHECK (jsonb_typeof(line_items) = 'array'),
  subtotal numeric(12,2) NOT NULL CHECK (subtotal >= 0),
  tax_amount numeric(12,2) NOT NULL DEFAULT 0 CHECK (tax_amount >= 0),
  discount_amount numeric(12,2) NOT NULL DEFAULT 0 CHECK (discount_amount >= 0),
  total numeric(12,2) GENERATED ALWAYS AS (subtotal + tax_amount - discount_amount) STORED,
  amount_paid numeric(12,2) NOT NULL DEFAULT 0 CHECK (amount_paid >= 0),
  status text NOT NULL DEFAULT 'draft' CHECK (status IN ('draft','issued','void')),
  payment_status text GENERATED ALWAYS AS (
    CASE WHEN amount_paid = subtotal + tax_amount - discount_amount THEN 'paid'
         WHEN amount_paid > 0 THEN 'partial' ELSE 'unpaid' END
  ) STORED,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CHECK (due_on >= issued_on),
  CHECK (subtotal + tax_amount - discount_amount >= 0),
  CHECK (amount_paid <= subtotal + tax_amount - discount_amount),
  UNIQUE (tenant_id,id), UNIQUE (tenant_id,invoice_number),
  FOREIGN KEY (tenant_id,client_id) REFERENCES public.clients(tenant_id,id),
  FOREIGN KEY (tenant_id,client_id,site_id) REFERENCES public.client_sites(tenant_id,client_id,id),
  FOREIGN KEY (tenant_id,client_id,contract_id) REFERENCES public.contracts(tenant_id,client_id,id),
  FOREIGN KEY (tenant_id,client_id,visit_id) REFERENCES public.visits(tenant_id,client_id,id)
);

-- Non-exposed, fixed search_path helpers avoid recursive profiles RLS.
-- Only the actual auth.uid() is used, never JWT user_metadata or a client tenant.
CREATE FUNCTION app_private.has_role(t uuid, r text) RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = '' AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.profiles p JOIN public.tenants n ON n.id = p.tenant_id
    WHERE p.id = (SELECT auth.uid()) AND p.tenant_id = t
      AND p.role = r AND p.is_active AND n.is_active
  );
$$;
CREATE FUNCTION app_private.is_admin(t uuid) RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = '' AS $$
  SELECT app_private.has_role(t, 'admin');
$$;
CREATE FUNCTION app_private.client_access(t uuid, c uuid) RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = '' AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.profiles p JOIN public.tenants n ON n.id = p.tenant_id
    WHERE p.id = (SELECT auth.uid()) AND p.tenant_id = t AND p.client_id = c
      AND p.role = 'client' AND p.portal_enabled AND p.is_active AND n.is_active
  );
$$;
CREATE FUNCTION app_private.assigned_visit(t uuid, v uuid) RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = '' AS $$
  SELECT app_private.has_role(t,'technician') AND EXISTS (
    SELECT 1 FROM public.visits x
    WHERE x.tenant_id = t AND x.id = v AND x.technician_id = (SELECT auth.uid())
  );
$$;
CREATE FUNCTION app_private.client_visit(t uuid, v uuid) RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = '' AS $$
  SELECT EXISTS (SELECT 1 FROM public.visits x WHERE x.tenant_id = t AND x.id = v
    AND app_private.client_access(t,x.client_id));
$$;
CREATE FUNCTION app_private.assigned_site(t uuid, s uuid) RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = '' AS $$
  SELECT app_private.has_role(t,'technician') AND EXISTS (
    SELECT 1 FROM public.visits x WHERE x.tenant_id = t AND x.site_id = s
      AND x.technician_id = (SELECT auth.uid())
  );
$$;

-- Immutable routing keys prevent moves between tenants, identities and owners.
CREATE FUNCTION app_private.guard_routing() RETURNS trigger
LANGUAGE plpgsql SET search_path = '' AS $$
DECLARE k text;
BEGIN
  IF NEW.id IS DISTINCT FROM OLD.id OR NEW.tenant_id IS DISTINCT FROM OLD.tenant_id THEN
    RAISE EXCEPTION 'Identity/tenant cannot be changed' USING ERRCODE = '23514';
  END IF;
  -- Ownership/scope links are immutable, even for administrators. Correct a
  -- mistaken scope with a new document, not a move of existing history.
  -- profiles.client_id remains admin-editable for portal account management.
  IF TG_TABLE_NAME <> 'profiles' THEN
    FOREACH k IN ARRAY ARRAY['client_id','site_id','contract_id','survey_id','visit_id'] LOOP
      IF (to_jsonb(NEW) -> k) IS DISTINCT FROM (to_jsonb(OLD) -> k) THEN
        RAISE EXCEPTION 'Document ownership/scope link % cannot be changed', k USING ERRCODE = '23514';
      END IF;
    END LOOP;
  END IF;
  NEW.updated_at := now();
  RETURN NEW;
END;
$$;

-- Enforce referenced staff roles and cross-document business scope as well as
-- the composite foreign keys. Security definer is only used as a trigger.
CREATE FUNCTION app_private.validate_scope() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE p public.profiles%ROWTYPE; c public.contracts%ROWTYPE;
        s public.surveys%ROWTYPE; v public.visits%ROWTYPE;
BEGIN
  IF TG_TABLE_NAME = 'visits' THEN
    IF NEW.technician_id IS NOT NULL THEN
      SELECT * INTO p FROM public.profiles WHERE tenant_id=NEW.tenant_id AND id=NEW.technician_id;
      IF NOT FOUND OR p.role <> 'technician' OR NOT p.is_active THEN
        RAISE EXCEPTION 'Visit assignee must be an active technician in this tenant';
      END IF;
    END IF;
    IF NEW.contract_id IS NOT NULL THEN
      SELECT * INTO c FROM public.contracts WHERE tenant_id=NEW.tenant_id AND id=NEW.contract_id;
      IF FOUND AND c.site_id IS NOT NULL AND c.site_id <> NEW.site_id THEN
        RAISE EXCEPTION 'Visit site is outside contract scope';
      END IF;
    END IF;
  ELSIF TG_TABLE_NAME = 'surveys' THEN
    IF NEW.surveyor_id IS NOT NULL THEN
      SELECT * INTO p FROM public.profiles WHERE tenant_id=NEW.tenant_id AND id=NEW.surveyor_id;
      IF NOT FOUND OR p.role NOT IN ('admin','technician') OR NOT p.is_active THEN
        RAISE EXCEPTION 'Surveyor must be active staff in this tenant';
      END IF;
    END IF;
  ELSIF TG_TABLE_NAME = 'contracts' THEN
    IF NEW.survey_id IS NOT NULL AND NEW.site_id IS NOT NULL THEN
      SELECT * INTO s FROM public.surveys WHERE tenant_id=NEW.tenant_id AND id=NEW.survey_id;
      IF FOUND AND s.site_id <> NEW.site_id THEN RAISE EXCEPTION 'Survey/contract site mismatch'; END IF;
    END IF;
    IF TG_OP = 'UPDATE' AND NEW.site_id IS DISTINCT FROM OLD.site_id
      AND NEW.site_id IS NOT NULL AND EXISTS (
        SELECT 1 FROM public.visits x WHERE x.tenant_id=NEW.tenant_id AND x.contract_id=NEW.id AND x.site_id<>NEW.site_id
      ) THEN RAISE EXCEPTION 'Existing visits conflict with contract site scope'; END IF;
  ELSIF TG_TABLE_NAME = 'invoices' THEN
    IF NEW.visit_id IS NOT NULL THEN
      SELECT * INTO v FROM public.visits WHERE tenant_id=NEW.tenant_id AND id=NEW.visit_id;
      IF FOUND THEN
        IF NEW.site_id IS NOT NULL AND NEW.site_id <> v.site_id THEN RAISE EXCEPTION 'Invoice/visit site mismatch'; END IF;
        IF NEW.contract_id IS NOT NULL AND NEW.contract_id IS DISTINCT FROM v.contract_id THEN
          RAISE EXCEPTION 'Invoice/visit contract mismatch';
        END IF;
      END IF;
    END IF;
    IF NEW.contract_id IS NOT NULL AND NEW.site_id IS NOT NULL THEN
      SELECT * INTO c FROM public.contracts WHERE tenant_id=NEW.tenant_id AND id=NEW.contract_id;
      IF FOUND AND c.site_id IS NOT NULL AND c.site_id <> NEW.site_id THEN
        RAISE EXCEPTION 'Invoice/contract site mismatch';
      END IF;
    END IF;
  END IF;
  RETURN NEW;
END;
$$;

-- A technician may only author their own assigned visit report. After submit
-- it is immutable to the technician. No assignment or billing edits are allowed.
CREATE FUNCTION app_private.guard_report() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
BEGIN
  -- Trusted SQL/service_role maintenance is allowed; ordinary JWTs are checked.
  IF (SELECT auth.uid()) IS NOT NULL AND NOT app_private.is_admin(NEW.tenant_id) THEN
    IF NOT app_private.assigned_visit(NEW.tenant_id,NEW.visit_id)
      OR NEW.technician_id IS DISTINCT FROM (SELECT auth.uid()) THEN
      RAISE EXCEPTION 'Report requires an assigned technician';
    END IF;
    IF TG_OP = 'UPDATE' THEN
      IF OLD.status <> 'draft' OR NEW.visit_id IS DISTINCT FROM OLD.visit_id
        OR NEW.technician_id IS DISTINCT FROM OLD.technician_id THEN
        RAISE EXCEPTION 'Submitted reports and report assignments are immutable to technicians';
      END IF;
    END IF;
  END IF;
  IF NEW.status = 'submitted' THEN
    IF TG_OP = 'INSERT' THEN NEW.submitted_at := now();
    ELSIF OLD.status = 'draft' THEN NEW.submitted_at := now();
    ELSE NEW.submitted_at := OLD.submitted_at;
    END IF;
  ELSE NEW.submitted_at := NULL;
  END IF;
  RETURN NEW;
END;
$$;

CREATE TRIGGER report_guard BEFORE INSERT OR UPDATE ON public.visit_reports
FOR EACH ROW EXECUTE FUNCTION app_private.guard_report();
CREATE TRIGGER visits_scope BEFORE INSERT OR UPDATE ON public.visits
FOR EACH ROW EXECUTE FUNCTION app_private.validate_scope();
CREATE TRIGGER surveys_scope BEFORE INSERT OR UPDATE ON public.surveys
FOR EACH ROW EXECUTE FUNCTION app_private.validate_scope();
CREATE TRIGGER contracts_scope BEFORE INSERT OR UPDATE ON public.contracts
FOR EACH ROW EXECUTE FUNCTION app_private.validate_scope();
CREATE TRIGGER invoices_scope BEFORE INSERT OR UPDATE ON public.invoices
FOR EACH ROW EXECUTE FUNCTION app_private.validate_scope();

DO $$
DECLARE tbl text;
BEGIN
  FOREACH tbl IN ARRAY ARRAY['profiles','services_catalog','pricing_matrix','clients',
    'client_sites','surveys','contracts','visits','visit_reports','invoices'] LOOP
    EXECUTE format('CREATE TRIGGER immutable_routing BEFORE UPDATE ON public.%I FOR EACH ROW EXECUTE FUNCTION app_private.guard_routing()',tbl);
    EXECUTE format('ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY',tbl);
    EXECUTE format('ALTER TABLE public.%I FORCE ROW LEVEL SECURITY',tbl);
    EXECUTE format('REVOKE ALL ON TABLE public.%I FROM PUBLIC, anon, authenticated',tbl);
    EXECUTE format('GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.%I TO authenticated',tbl);
    EXECUTE format('GRANT ALL ON TABLE public.%I TO service_role',tbl);
    EXECUTE format('CREATE POLICY admin_manage ON public.%I FOR ALL TO authenticated USING (app_private.is_admin(tenant_id)) WITH CHECK (app_private.is_admin(tenant_id))',tbl);
    EXECUTE format('CREATE INDEX ON public.%I (tenant_id)',tbl);
  END LOOP;
END;
$$;

ALTER TABLE public.tenants ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.tenants FORCE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.tenants FROM PUBLIC, anon, authenticated;
GRANT SELECT, UPDATE ON TABLE public.tenants TO authenticated;
GRANT ALL ON TABLE public.tenants TO service_role;
-- No tenant INSERT/DELETE policy. Bootstrap is trusted SQL/server-side only.
CREATE POLICY tenant_admin_read ON public.tenants FOR SELECT TO authenticated
USING (app_private.is_admin(id));
CREATE POLICY tenant_admin_update ON public.tenants FOR UPDATE TO authenticated
USING (app_private.is_admin(id)) WITH CHECK (app_private.is_admin(id));

CREATE POLICY profile_self_read ON public.profiles FOR SELECT TO authenticated
USING (id=(SELECT auth.uid()) AND is_active AND (
  app_private.has_role(tenant_id,'technician') OR app_private.has_role(tenant_id,'admin')
  OR app_private.client_access(tenant_id,client_id)
));
-- No self INSERT/UPDATE. Role, tenant, client mapping and portal flags are
-- managed ONLY by the company admin or trusted server; no metadata trust.

CREATE POLICY client_own_read ON public.clients FOR SELECT TO authenticated
USING (app_private.client_access(tenant_id,id));
CREATE POLICY site_client_read ON public.client_sites FOR SELECT TO authenticated
USING (app_private.client_access(tenant_id,client_id));
-- Operational exception: only sites with this technician's assigned visits.
CREATE POLICY site_technician_read ON public.client_sites FOR SELECT TO authenticated
USING (app_private.assigned_site(tenant_id,id));
CREATE POLICY contract_client_read ON public.contracts FOR SELECT TO authenticated
USING (status <> 'draft' AND app_private.client_access(tenant_id,client_id));
CREATE POLICY visit_technician_read ON public.visits FOR SELECT TO authenticated
USING (technician_id=(SELECT auth.uid()) AND app_private.has_role(tenant_id,'technician'));
CREATE POLICY visit_client_read ON public.visits FOR SELECT TO authenticated
USING (app_private.client_access(tenant_id,client_id));
CREATE POLICY report_technician_read ON public.visit_reports FOR SELECT TO authenticated
USING (app_private.assigned_visit(tenant_id,visit_id));
CREATE POLICY report_client_read ON public.visit_reports FOR SELECT TO authenticated
USING (status='submitted' AND app_private.client_visit(tenant_id,visit_id));
CREATE POLICY report_technician_insert ON public.visit_reports FOR INSERT TO authenticated
WITH CHECK (technician_id=(SELECT auth.uid()) AND app_private.assigned_visit(tenant_id,visit_id));
CREATE POLICY report_technician_update ON public.visit_reports FOR UPDATE TO authenticated
USING (status='draft' AND technician_id=(SELECT auth.uid()) AND app_private.assigned_visit(tenant_id,visit_id))
WITH CHECK (technician_id=(SELECT auth.uid()) AND app_private.assigned_visit(tenant_id,visit_id));
CREATE POLICY invoice_client_read ON public.invoices FOR SELECT TO authenticated
USING (status='issued' AND app_private.client_access(tenant_id,client_id));
-- Surveys/internal quotes, catalog and pricing are admin-only at this stage.
-- Non-admin DELETE is absent everywhere; non-report writes are admin-only.

CREATE INDEX sites_client_idx ON public.client_sites(tenant_id,client_id);
CREATE INDEX profiles_client_idx ON public.profiles(tenant_id,client_id);
CREATE INDEX surveys_site_idx ON public.surveys(tenant_id,client_id,site_id);
CREATE INDEX visits_technician_schedule_idx ON public.visits(tenant_id,technician_id,scheduled_start);
CREATE INDEX visits_site_schedule_idx ON public.visits(tenant_id,site_id,scheduled_start);
CREATE INDEX visits_contract_idx ON public.visits(tenant_id,contract_id);
CREATE INDEX contracts_client_idx ON public.contracts(tenant_id,client_id);
CREATE INDEX invoices_client_due_idx ON public.invoices(tenant_id,client_id,due_on);

-- Remove default PUBLIC execute, including trigger functions. Only predicates
-- required by RLS are callable by authenticated users. app_private must NOT be
-- added to Supabase's exposed API schemas.
REVOKE ALL ON ALL FUNCTIONS IN SCHEMA app_private FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION app_private.has_role(uuid,text),
  app_private.is_admin(uuid), app_private.client_access(uuid,uuid),
  app_private.assigned_visit(uuid,uuid), app_private.client_visit(uuid,uuid),
  app_private.assigned_site(uuid,uuid) TO authenticated;

COMMIT;

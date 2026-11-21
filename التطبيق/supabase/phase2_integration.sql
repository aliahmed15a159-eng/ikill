-- Apply after phase 1. Only compatibility for EXISTING contact/branches/settings
-- and private file storage. No users or admin roles are created.
ALTER TABLE public.clients ADD COLUMN requested_service text;
ALTER TABLE public.clients ADD COLUMN request_message text;
CREATE TABLE public.company_branches (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 tenant_id uuid NOT NULL REFERENCES public.tenants(id),
 name_ar text NOT NULL, name_en text NOT NULL,
 country_ar text NOT NULL, country_en text NOT NULL,
 phone text, status text NOT NULL DEFAULT 'active' CHECK(status IN ('active','inactive')),
 created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.company_branches ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.company_branches FORCE ROW LEVEL SECURITY;
REVOKE ALL ON public.company_branches FROM PUBLIC,anon,authenticated;
GRANT SELECT,INSERT,UPDATE,DELETE ON public.company_branches TO authenticated;
GRANT ALL ON public.company_branches TO service_role;
CREATE POLICY branch_admin ON public.company_branches TO authenticated
 USING(app_private.is_admin(tenant_id)) WITH CHECK(app_private.is_admin(tenant_id));
CREATE TRIGGER immutable_routing BEFORE UPDATE ON public.company_branches
 FOR EACH ROW EXECUTE FUNCTION app_private.guard_routing();
CREATE INDEX ON public.company_branches(tenant_id);
CREATE TABLE public.page_events (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 tenant_id uuid NOT NULL REFERENCES public.tenants(id),
 page text NOT NULL, referrer text NOT NULL CHECK(referrer IN ('direct','referral')),
 created_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.page_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.page_events FORCE ROW LEVEL SECURITY;
REVOKE ALL ON public.page_events FROM PUBLIC,anon,authenticated;
GRANT SELECT,DELETE ON public.page_events TO authenticated;
GRANT ALL ON public.page_events TO service_role;
CREATE POLICY events_admin_read ON public.page_events FOR SELECT TO authenticated USING(app_private.is_admin(tenant_id));
CREATE POLICY events_admin_delete ON public.page_events FOR DELETE TO authenticated USING(app_private.is_admin(tenant_id));
CREATE INDEX ON public.page_events(tenant_id,created_at);

-- Narrow public projections: never expose full tenants rows or clients.
CREATE FUNCTION public.get_public_brand(brand_slug text) RETURNS jsonb
 LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $$
 SELECT jsonb_build_object('name',name,'currency',currency,'branding',
 jsonb_build_object('phone',branding->>'phone','emergency',branding->>'emergency',
 'address',branding->>'address','email',branding->>'email',
 'stat1Value',branding->>'stat1Value','stat1Label',branding->>'stat1Label',
 'stat2Value',branding->>'stat2Value','stat2Label',branding->>'stat2Label',
 'stat3Value',branding->>'stat3Value','stat3Label',branding->>'stat3Label',
 'stat4Value',branding->>'stat4Value','stat4Label',branding->>'stat4Label'))
 FROM public.tenants WHERE slug=brand_slug AND is_active;
$$;
CREATE FUNCTION public.get_public_branches(brand_slug text)
 RETURNS TABLE(id uuid,name_ar text,name_en text,country_ar text,country_en text,phone text,status text)
 LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $$
 SELECT b.id,b.name_ar,b.name_en,b.country_ar,b.country_en,b.phone,b.status
 FROM public.company_branches b JOIN public.tenants t ON t.id=b.tenant_id
 WHERE t.slug=brand_slug AND t.is_active AND b.status='active';
$$;
-- Own account status remains readable even when portal is off, so clients get
-- an explicit denial rather than a generic 'missing profile' message.
CREATE FUNCTION public.get_my_profile() RETURNS jsonb
 LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $$
 SELECT jsonb_build_object('id',p.id,'tenant_id',p.tenant_id,'role',p.role,
 'portal_enabled',p.portal_enabled,'is_active',p.is_active,'tenant_active',t.is_active,
 'client_id',p.client_id,'full_name',p.full_name)
 FROM public.profiles p JOIN public.tenants t ON t.id=p.tenant_id
 WHERE p.id=(SELECT auth.uid());
$$;
CREATE FUNCTION public.submit_contact_request(brand_slug text,contact_name text,contact_phone text,
 contact_email text,contact_address text,contact_service text,contact_message text) RETURNS void
 LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
 DECLARE company uuid;
 BEGIN
 SELECT id INTO company FROM public.tenants WHERE slug=brand_slug AND is_active;
 IF company IS NULL THEN RAISE EXCEPTION 'Unknown company'; END IF;
 IF length(btrim(contact_name)) NOT BETWEEN 1 AND 100
 OR length(contact_phone)>20 OR length(contact_email) NOT BETWEEN 3 AND 150
 OR contact_email !~ '^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$'
 OR length(btrim(contact_address)) NOT BETWEEN 1 AND 200
 OR length(contact_service) NOT BETWEEN 1 AND 100
 OR length(btrim(contact_message)) NOT BETWEEN 1 AND 2000
 OR contact_name IS NULL OR contact_phone IS NULL OR contact_email IS NULL
 OR contact_address IS NULL OR contact_service IS NULL OR contact_message IS NULL
 THEN RAISE EXCEPTION 'Invalid contact request'; END IF;
 -- Serialize per company+email to avoid concurrent quota bypass. This is a
 -- basic per-address quota, not a substitute for edge CAPTCHA/rate limiting.
 PERFORM pg_advisory_xact_lock(hashtextextended(company::text || lower(contact_email),0));
 IF (SELECT count(*) FROM public.clients WHERE tenant_id=company AND lower(email)=lower(contact_email)
 AND created_at>now()-interval '24 hours')>=5 THEN RAISE EXCEPTION 'Daily contact limit reached'; END IF;
 INSERT INTO public.clients(tenant_id,client_code,display_name,contact_name,phone,email,
 billing_address,requested_service,request_message,client_type,status)
 VALUES(company,gen_random_uuid()::text,btrim(contact_name),btrim(contact_name),contact_phone,
 lower(btrim(contact_email)),btrim(contact_address),contact_service,contact_message,'one_time','lead');
 END;
$$;
CREATE FUNCTION public.record_page_view(brand_slug text,page_name text,source text) RETURNS void
 LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
 DECLARE company uuid;
 BEGIN
 IF page_name NOT IN ('index.html','about.html','services.html','sectors.html','locations.html','contact.html','privacy-policy.html','terms.html')
 OR source NOT IN ('direct','referral') THEN RAISE EXCEPTION 'Invalid page event'; END IF;
 SELECT id INTO company FROM public.tenants WHERE slug=brand_slug AND is_active;
 IF company IS NULL THEN RAISE EXCEPTION 'Unknown company'; END IF;
 INSERT INTO public.page_events(tenant_id,page,referrer) VALUES(company,page_name,source);
 END;
$$;
REVOKE ALL ON FUNCTION public.get_public_brand(text),public.get_public_branches(text),
 public.get_my_profile(),public.submit_contact_request(text,text,text,text,text,text,text),
 public.record_page_view(text,text,text) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.get_public_brand(text),public.get_public_branches(text),
 public.submit_contact_request(text,text,text,text,text,text,text),public.record_page_view(text,text,text) TO anon,authenticated;
GRANT EXECUTE ON FUNCTION public.get_my_profile() TO authenticated;

-- Use the requested default brand; no profile/admin is inferred or granted.
INSERT INTO public.tenants(slug,name,currency,branding)
 VALUES('ikill','iKILL','EGP','{"phone":"01020019042","emergency":"01020019042","email":"info@ikill.net","stat1Value":"15"}')
 ON CONFLICT(slug) DO NOTHING;

INSERT INTO storage.buckets(id,name,public,file_size_limit,allowed_mime_types) VALUES
 ('visit-images','visit-images',false,10485760,ARRAY['image/jpeg','image/png','image/webp']),
 ('visit-signatures','visit-signatures',false,2097152,ARRAY['image/png']),
 ('invoice-pdfs','invoice-pdfs',false,20971520,ARRAY['application/pdf']);

-- Object path is <tenant UUID>/<visit OR invoice UUID>/<random filename>.
-- Client reads must ALSO match a published report path, not just a folder.
CREATE FUNCTION app_private.can_read_file(bucket text,path text) RETURNS boolean
 LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $$
 SELECT CASE WHEN bucket='invoice-pdfs' THEN EXISTS (
 SELECT 1 FROM public.invoices i WHERE i.tenant_id::text=split_part(path,'/',1) AND i.id::text=split_part(path,'/',2)
 AND (app_private.is_admin(i.tenant_id) OR (i.status='issued' AND app_private.client_access(i.tenant_id,i.client_id))))
 WHEN bucket IN ('visit-images','visit-signatures') THEN EXISTS (
 SELECT 1 FROM public.visits v WHERE v.tenant_id::text=split_part(path,'/',1) AND v.id::text=split_part(path,'/',2)
 AND (app_private.is_admin(v.tenant_id) OR app_private.assigned_visit(v.tenant_id,v.id)
 OR (app_private.client_access(v.tenant_id,v.client_id) AND EXISTS (
 SELECT 1 FROM public.visit_reports r WHERE r.tenant_id=v.tenant_id AND r.visit_id=v.id AND r.status='submitted'
 AND ((bucket='visit-images' AND path=ANY(r.photo_paths)) OR (bucket='visit-signatures' AND path=r.customer_signature_path))))))
 ELSE false END;
$$;
CREATE FUNCTION app_private.can_write_file(bucket text,path text) RETURNS boolean
 LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $$
 SELECT CASE WHEN bucket='invoice-pdfs' THEN EXISTS (
 SELECT 1 FROM public.invoices i WHERE i.tenant_id::text=split_part(path,'/',1) AND i.id::text=split_part(path,'/',2) AND app_private.is_admin(i.tenant_id))
 WHEN bucket IN ('visit-images','visit-signatures') THEN EXISTS (
 SELECT 1 FROM public.visits v WHERE v.tenant_id::text=split_part(path,'/',1) AND v.id::text=split_part(path,'/',2)
 AND (app_private.is_admin(v.tenant_id) OR (app_private.assigned_visit(v.tenant_id,v.id) AND NOT EXISTS (
 SELECT 1 FROM public.visit_reports r WHERE r.tenant_id=v.tenant_id AND r.visit_id=v.id AND r.status='submitted'))))
 ELSE false END;
$$;
REVOKE ALL ON FUNCTION app_private.can_read_file(text,text),app_private.can_write_file(text,text) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION app_private.can_read_file(text,text),app_private.can_write_file(text,text) TO authenticated;
CREATE POLICY ikill_files_read ON storage.objects FOR SELECT TO authenticated
 USING(bucket_id IN ('visit-images','visit-signatures','invoice-pdfs') AND app_private.can_read_file(bucket_id,name));
CREATE POLICY ikill_files_insert ON storage.objects FOR INSERT TO authenticated
 WITH CHECK(bucket_id IN ('visit-images','visit-signatures','invoice-pdfs') AND app_private.can_write_file(bucket_id,name));
CREATE POLICY ikill_files_update ON storage.objects FOR UPDATE TO authenticated
 USING(bucket_id IN ('visit-images','visit-signatures','invoice-pdfs') AND app_private.can_write_file(bucket_id,name))
 WITH CHECK(bucket_id IN ('visit-images','visit-signatures','invoice-pdfs') AND app_private.can_write_file(bucket_id,name));
CREATE POLICY ikill_files_delete ON storage.objects FOR DELETE TO authenticated
 USING(bucket_id IN ('visit-images','visit-signatures','invoice-pdfs') AND app_private.can_write_file(bucket_id,name));

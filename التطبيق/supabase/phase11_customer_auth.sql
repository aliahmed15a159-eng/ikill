-- Supabase Auth only. Never derive roles/tenant/portal flags from user metadata.
DO $$DECLARE item record;BEGIN
 FOR item IN SELECT conname FROM pg_constraint WHERE conrelid='public.profiles'::regclass AND contype='c' AND pg_get_constraintdef(oid) LIKE '%role%' LOOP
 EXECUTE format('ALTER TABLE public.profiles DROP CONSTRAINT %I',item.conname);END LOOP;
END;$$;
ALTER TABLE public.profiles ALTER COLUMN role SET DEFAULT 'customer';
ALTER TABLE public.profiles ADD CONSTRAINT profiles_role_check CHECK(role IN ('admin','technician','client','customer'));
ALTER TABLE public.profiles ADD CONSTRAINT profiles_role_scope_check CHECK((role='client' AND client_id IS NOT NULL) OR (role IN ('admin','technician','customer') AND client_id IS NULL));
ALTER TABLE public.profiles ADD CONSTRAINT profiles_portal_role_check CHECK(NOT portal_enabled OR role='client');
ALTER TABLE public.profiles ADD COLUMN phone_completed_at timestamptz;
CREATE TABLE app_private.signup_tenant(singleton boolean PRIMARY KEY DEFAULT true CHECK(singleton),tenant_id uuid NOT NULL REFERENCES public.tenants(id));
INSERT INTO app_private.signup_tenant SELECT true,id FROM public.tenants WHERE slug='ikill';
DO $$BEGIN IF NOT EXISTS(SELECT 1 FROM app_private.signup_tenant) THEN RAISE EXCEPTION 'SIGNUP_TENANT_REQUIRED';END IF;END;$$;
REVOKE ALL ON app_private.signup_tenant FROM PUBLIC,anon,authenticated;
CREATE FUNCTION app_private.provision_customer(account uuid,metadata jsonb) RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE company uuid;display text;BEGIN
 SELECT tenant_id INTO company FROM app_private.signup_tenant WHERE singleton;
 IF company IS NULL THEN RAISE EXCEPTION 'SIGNUP_TENANT_REQUIRED';END IF;
 display:=left(coalesce(nullif(trim(metadata->>'full_name'),''),nullif(trim(metadata->>'name'),''),'عميل جديد'),100);
 INSERT INTO public.profiles(id,tenant_id,role,full_name,portal_enabled,client_id) VALUES(account,company,'customer',display,false,NULL) ON CONFLICT(id) DO NOTHING;
END;$$;
CREATE FUNCTION app_private.on_auth_user_created() RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$BEGIN
 PERFORM app_private.provision_customer(NEW.id,NEW.raw_user_meta_data);RETURN NEW;
END;$$;
CREATE TRIGGER app_customer_on_signup AFTER INSERT ON auth.users FOR EACH ROW EXECUTE FUNCTION app_private.on_auth_user_created();
-- Existing staff/client rows are untouched. Only missing profiles are safely backfilled.
DO $$DECLARE item record;BEGIN FOR item IN SELECT u.id,u.raw_user_meta_data FROM auth.users u WHERE NOT EXISTS(SELECT 1 FROM public.profiles p WHERE p.id=u.id) LOOP PERFORM app_private.provision_customer(item.id,item.raw_user_meta_data);END LOOP;END;$$;
REVOKE ALL ON FUNCTION app_private.provision_customer(uuid,jsonb),app_private.on_auth_user_created() FROM PUBLIC,anon,authenticated;
CREATE POLICY customer_self_profile_read ON public.profiles FOR SELECT TO authenticated USING(id=(SELECT auth.uid()) AND app_private.has_role(tenant_id,'customer'));
CREATE OR REPLACE FUNCTION public.get_my_profile() RETURNS jsonb LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $$
 SELECT jsonb_build_object('id',p.id,'tenant_id',p.tenant_id,'role',p.role,'portal_enabled',p.portal_enabled,'is_active',p.is_active,'tenant_active',t.is_active,'client_id',p.client_id,'full_name',p.full_name,'phone',p.phone,'profile_incomplete',p.role='customer' AND p.phone_completed_at IS NULL)
 FROM public.profiles p JOIN public.tenants t ON t.id=p.tenant_id WHERE p.id=(SELECT auth.uid());
$$;
CREATE FUNCTION public.complete_customer_profile(display_name text,whatsapp_phone text) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE p public.profiles%ROWTYPE;normalized_phone text;BEGIN
 SELECT * INTO p FROM public.profiles WHERE id=(SELECT auth.uid()) FOR UPDATE;
 IF p.id IS NULL OR NOT app_private.has_role(p.tenant_id,'customer') THEN RAISE EXCEPTION 'ACTIVE_CUSTOMER_REQUIRED';END IF;
 normalized_phone:=regexp_replace(translate(coalesce(whatsapp_phone,''),'٠١٢٣٤٥٦٧٨٩۰۱۲۳۴۵۶۷۸۹','01234567890123456789'),'[[:space:]()-]','','g');
 IF normalized_phone ~ '^01[0125][0-9]{8}$' THEN normalized_phone:='+2'||normalized_phone;ELSIF normalized_phone LIKE '00%' THEN normalized_phone:='+'||substr(normalized_phone,3);END IF;
 IF normalized_phone !~ '^\+[1-9][0-9]{7,14}$' OR display_name IS NULL OR length(trim(display_name)) NOT BETWEEN 2 AND 100 THEN RAISE EXCEPTION 'VALID_NAME_AND_WHATSAPP_REQUIRED';END IF;
 UPDATE public.profiles SET full_name=trim(display_name),phone=normalized_phone,phone_completed_at=coalesce(phone_completed_at,now()) WHERE id=p.id;
 RETURN public.get_my_profile();
END;$$;
-- Admin-created portal accounts now already have an automatic customer profile.
-- Promotion remains service-only and cannot overwrite existing privileged roles.
CREATE OR REPLACE FUNCTION public.attach_portal_profile(company uuid,customer uuid,account uuid) RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE c public.clients%ROWTYPE;p public.profiles%ROWTYPE;BEGIN
 PERFORM pg_advisory_xact_lock(hashtextextended(customer::text,0));
 SELECT * INTO c FROM public.clients WHERE id=customer AND tenant_id=company;
 IF NOT FOUND OR EXISTS(SELECT 1 FROM public.profiles WHERE tenant_id=company AND client_id=customer AND role='client') THEN RAISE EXCEPTION 'CLIENT_ALREADY_HAS_ACCOUNT_OR_MISSING';END IF;
 SELECT * INTO p FROM public.profiles WHERE id=account FOR UPDATE;
 IF FOUND THEN
  IF p.tenant_id<>company OR p.role<>'customer' OR p.client_id IS NOT NULL THEN RAISE EXCEPTION 'EXISTING_ACCOUNT_CANNOT_BE_REASSIGNED';END IF;
  UPDATE public.profiles SET role='client',client_id=customer,full_name=c.display_name,portal_enabled=c.portal_enabled,is_active=true WHERE id=account;
 ELSE
  INSERT INTO public.profiles(id,tenant_id,client_id,role,full_name,portal_enabled,is_active) VALUES(account,company,customer,'client',c.display_name,c.portal_enabled,true);
 END IF;
END;$$;
CREATE FUNCTION public.get_auth_brand(brand_slug text) RETURNS jsonb LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $$
 SELECT jsonb_build_object('company_name',b.company_name,'logo_path',b.logo_path,'primary_hex',b.primary_hex)
 FROM public.brand_config b JOIN public.tenants t ON t.id=b.tenant_id WHERE t.slug=brand_slug AND t.is_active;
$$;
CREATE FUNCTION public.is_auth_brand_logo(object_name text) RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $$
 SELECT EXISTS(SELECT 1 FROM public.brand_config b JOIN public.tenants t ON t.id=b.tenant_id WHERE t.is_active AND b.logo_path=object_name AND b.logo_path LIKE b.tenant_id::text||'/%');
$$;
CREATE POLICY published_auth_logo ON storage.objects FOR SELECT TO anon,authenticated USING(bucket_id='brand-assets' AND public.is_auth_brand_logo(name));
-- Keep anonymous app requests unchanged; logged-in customers must be active,
-- complete, and confined to their server-assigned tenant. No contract portal access.
ALTER FUNCTION public.submit_app_request(text,uuid,jsonb) SET SCHEMA app_private;
REVOKE ALL ON FUNCTION app_private.submit_app_request(text,uuid,jsonb) FROM PUBLIC,anon,authenticated;
CREATE FUNCTION public.submit_app_request(brand_slug text,request_id uuid,payload jsonb) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE p public.profiles%ROWTYPE;company uuid;BEGIN
 IF (SELECT auth.uid()) IS NOT NULL THEN
  SELECT * INTO p FROM public.profiles WHERE id=(SELECT auth.uid());
  SELECT id INTO company FROM public.tenants WHERE slug=brand_slug AND is_active;
  IF p.id IS NULL OR NOT coalesce(app_private.notification_member(p.tenant_id,p.id,p.role),false) OR p.tenant_id IS DISTINCT FROM company OR (p.role='customer' AND p.phone_completed_at IS NULL) THEN RAISE EXCEPTION 'ACTIVE_COMPLETED_PROFILE_REQUIRED';END IF;
 END IF;
 RETURN app_private.submit_app_request(brand_slug,request_id,payload);
END;$$;
REVOKE ALL ON FUNCTION public.complete_customer_profile(text,text),public.get_auth_brand(text),public.is_auth_brand_logo(text),public.submit_app_request(text,uuid,jsonb) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.complete_customer_profile(text,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_auth_brand(text),public.is_auth_brand_logo(text),public.submit_app_request(text,uuid,jsonb) TO anon,authenticated;
NOTIFY pgrst,'reload schema';

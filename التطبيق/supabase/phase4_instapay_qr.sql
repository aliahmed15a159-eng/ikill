-- App-only payment destination configuration. No QR or receiving account seeded.
CREATE TABLE public.app_payment_settings (
 tenant_id uuid PRIMARY KEY REFERENCES public.tenants(id),
 qr_path text,
 beneficiary_name text NOT NULL DEFAULT '' CHECK(length(beneficiary_name)<=150),
 enabled boolean NOT NULL DEFAULT false,
 updated_at timestamptz NOT NULL DEFAULT now(),
 CHECK(NOT enabled OR (qr_path IS NOT NULL AND length(btrim(beneficiary_name))>0)),
 CHECK(qr_path IS NULL OR split_part(qr_path,'/',1)=tenant_id::text)
);
ALTER TABLE public.app_payment_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.app_payment_settings FORCE ROW LEVEL SECURITY;
REVOKE ALL ON public.app_payment_settings FROM PUBLIC,anon,authenticated;
GRANT SELECT ON public.app_payment_settings TO authenticated;
GRANT ALL ON public.app_payment_settings TO service_role;
CREATE POLICY payment_settings_admin_read ON public.app_payment_settings FOR SELECT TO authenticated
 USING(app_private.is_admin(tenant_id));
INSERT INTO storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
 VALUES('instapay-qr','instapay-qr',false,5242880,ARRAY['image/png','image/jpeg']);

CREATE FUNCTION public.get_instapay_settings(brand_slug text) RETURNS jsonb
 LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $$
 SELECT jsonb_build_object('qr_path',s.qr_path,'beneficiary_name',s.beneficiary_name)
 FROM public.app_payment_settings s JOIN public.tenants t ON t.id=s.tenant_id
 WHERE t.slug=brand_slug AND t.is_active AND s.enabled AND s.qr_path IS NOT NULL;
$$;
-- Only the currently published destination image is readable by customers.
CREATE FUNCTION public.can_read_instapay_qr(object_name text) RETURNS boolean
 LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $$
 SELECT EXISTS(SELECT 1 FROM public.app_payment_settings s JOIN public.tenants t ON t.id=s.tenant_id
 WHERE t.is_active AND s.enabled AND s.qr_path=object_name);
$$;
CREATE POLICY instapay_qr_read ON storage.objects FOR SELECT TO anon,authenticated
 USING(bucket_id='instapay-qr' AND public.can_read_instapay_qr(name));
CREATE POLICY instapay_qr_admin_read ON storage.objects FOR SELECT TO authenticated
 USING(bucket_id='instapay-qr' AND EXISTS(SELECT 1 FROM public.profiles p
 WHERE p.id=(SELECT auth.uid()) AND p.tenant_id::text=split_part(name,'/',1) AND app_private.is_admin(p.tenant_id)));
CREATE POLICY instapay_qr_admin_insert ON storage.objects FOR INSERT TO authenticated
 WITH CHECK(bucket_id='instapay-qr' AND EXISTS(SELECT 1 FROM public.profiles p
 WHERE p.id=(SELECT auth.uid()) AND p.tenant_id::text=split_part(name,'/',1) AND app_private.is_admin(p.tenant_id)));
CREATE POLICY instapay_qr_admin_delete ON storage.objects FOR DELETE TO authenticated
 USING(bucket_id='instapay-qr' AND NOT public.can_read_instapay_qr(name) AND EXISTS(SELECT 1 FROM public.profiles p
 WHERE p.id=(SELECT auth.uid()) AND p.tenant_id::text=split_part(name,'/',1) AND app_private.is_admin(p.tenant_id)));
CREATE FUNCTION public.save_instapay_settings(object_path text,beneficiary text,is_enabled boolean) RETURNS void
 LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
 DECLARE company uuid;
 BEGIN
 SELECT tenant_id INTO company FROM public.profiles WHERE id=(SELECT auth.uid()) AND app_private.is_admin(tenant_id);
 IF company IS NULL THEN RAISE EXCEPTION 'ADMIN_REQUIRED'; END IF;
 IF is_enabled IS NULL OR beneficiary IS NULL OR length(beneficiary)>150
 OR (is_enabled AND (object_path IS NULL OR length(btrim(beneficiary))=0))
 OR (object_path IS NOT NULL AND (split_part(object_path,'/',1)<>company::text OR NOT EXISTS(
 SELECT 1 FROM storage.objects WHERE bucket_id='instapay-qr' AND name=object_path)))
 THEN RAISE EXCEPTION 'INVALID_PAYMENT_SETTINGS'; END IF;
 INSERT INTO public.app_payment_settings(tenant_id,qr_path,beneficiary_name,enabled,updated_at)
 VALUES(company,object_path,btrim(beneficiary),is_enabled,now())
 ON CONFLICT(tenant_id) DO UPDATE SET qr_path=excluded.qr_path,beneficiary_name=excluded.beneficiary_name,
 enabled=excluded.enabled,updated_at=excluded.updated_at;
 END;
$$;
REVOKE ALL ON FUNCTION public.get_instapay_settings(text),public.can_read_instapay_qr(text),
 public.save_instapay_settings(text,text,boolean) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.get_instapay_settings(text),public.can_read_instapay_qr(text) TO anon,authenticated;
GRANT EXECUTE ON FUNCTION public.save_instapay_settings(text,text,boolean) TO authenticated;

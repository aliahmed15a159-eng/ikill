-- FCM is transport only. Supabase Auth/Storage/PostgreSQL/Realtime are unchanged.
DROP FUNCTION public.register_my_push(text,text);
DROP FUNCTION public.unregister_my_push(text);
DROP FUNCTION public.set_notification_push_settings(uuid,boolean);
ALTER TABLE public.profiles RENAME COLUMN push_subscription_id TO fcm_token;
-- Old provider IDs are not FCM tokens; never reuse them.
UPDATE public.profiles SET fcm_token=NULL WHERE fcm_token IS NOT NULL;
DELETE FROM app_private.push_devices;
ALTER TABLE app_private.push_devices RENAME COLUMN subscription_id TO fcm_token;
ALTER TABLE public.brand_config DROP COLUMN onesignal_app_id;
ALTER TABLE public.brand_config ADD COLUMN fcm_project_id text NOT NULL DEFAULT 'ikill-4e337' CHECK(fcm_project_id ~ '^[a-z][a-z0-9-]{4,62}$');
UPDATE public.brand_config SET push_enabled=false;
CREATE OR REPLACE FUNCTION public.get_notification_settings() RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $$
DECLARE p public.profiles%ROWTYPE;BEGIN SELECT * INTO p FROM public.profiles WHERE id=(SELECT auth.uid());
 IF NOT coalesce(app_private.notification_member(p.tenant_id,p.id,p.role),false) THEN RAISE EXCEPTION 'ACTIVE_ACCOUNT_REQUIRED';END IF;
 RETURN (SELECT jsonb_build_object('provider','fcm','project_id',b.fcm_project_id,'push_enabled',b.push_enabled,'webhook_enabled',(SELECT webhook_enabled FROM app_private.notification_transport WHERE singleton),'tenant_id',p.tenant_id) FROM public.brand_config b WHERE b.tenant_id=p.tenant_id);END; $$;
CREATE FUNCTION public.register_my_fcm(device_token text,installation_secret text) RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE p public.profiles%ROWTYPE;d app_private.push_devices%ROWTYPE;hash text;BEGIN
 SELECT * INTO p FROM public.profiles WHERE id=(SELECT auth.uid());
 IF NOT coalesce(app_private.notification_member(p.tenant_id,p.id,p.role),false) THEN RAISE EXCEPTION 'ACTIVE_ACCOUNT_REQUIRED';END IF;
 IF device_token IS NULL OR length(device_token) NOT BETWEEN 40 AND 4096 OR device_token !~ '^[A-Za-z0-9_:.-]+$' OR installation_secret IS NULL OR installation_secret !~ '^[a-f0-9]{64}$' THEN RAISE EXCEPTION 'INVALID_DEVICE';END IF;
 hash:=encode(sha256(convert_to(installation_secret,'UTF8')),'hex');PERFORM pg_advisory_xact_lock(hashtextextended(device_token,0));
 SELECT * INTO d FROM app_private.push_devices WHERE fcm_token=device_token FOR UPDATE;
 IF FOUND AND d.installation_hash<>hash THEN RAISE EXCEPTION 'DEVICE_ALREADY_BOUND';END IF;
 UPDATE public.profiles SET fcm_token=NULL WHERE fcm_token=device_token AND id<>p.id;
 INSERT INTO app_private.push_devices VALUES(device_token,p.id,hash) ON CONFLICT(fcm_token) DO UPDATE SET user_id=excluded.user_id;
 UPDATE public.profiles SET fcm_token=device_token WHERE id=p.id;
END; $$;
CREATE FUNCTION public.unregister_my_fcm(device_token text DEFAULT NULL) RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$BEGIN
 UPDATE public.profiles SET fcm_token=NULL WHERE id=(SELECT auth.uid()) AND (device_token IS NULL OR fcm_token=device_token);
 -- Retain the installation binding to prevent theft/rebinding by another installation.
END; $$;
CREATE FUNCTION public.set_notification_push_settings(enabled boolean) RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$DECLARE company uuid:=app_private.ops_admin_tenant();BEGIN IF enabled IS NULL THEN RAISE EXCEPTION 'ENABLED_REQUIRED';END IF;UPDATE public.brand_config SET push_enabled=enabled WHERE tenant_id=company;END; $$;
CREATE OR REPLACE FUNCTION public.claim_push_delivery(target uuid,secret uuid) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE d app_private.push_deliveries%ROWTYPE;n public.notifications%ROWTYPE;p public.profiles%ROWTYPE;b public.brand_config%ROWTYPE;BEGIN
 SELECT * INTO d FROM app_private.push_deliveries WHERE notification_id=target FOR UPDATE;
 IF NOT FOUND OR d.token IS DISTINCT FROM secret THEN RAISE EXCEPTION 'INVALID_DELIVERY';END IF;
 IF d.status='sent' OR d.next_attempt_at>now() OR (d.status='processing' AND d.leased_at>now()-interval '2 minutes') THEN RETURN jsonb_build_object('skip',true);END IF;
 SELECT * INTO n FROM public.notifications WHERE id=target;SELECT * INTO p FROM public.profiles WHERE id=n.user_id;SELECT * INTO b FROM public.brand_config WHERE tenant_id=n.tenant_id;
 IF NOT p.is_active OR p.role<>n.role OR p.tenant_id<>n.tenant_id OR NOT EXISTS(SELECT 1 FROM public.tenants WHERE id=n.tenant_id AND is_active) OR (p.role='client' AND (NOT p.portal_enabled OR NOT EXISTS(SELECT 1 FROM public.clients WHERE id=p.client_id AND tenant_id=p.tenant_id AND portal_enabled))) THEN
  UPDATE app_private.push_deliveries SET status='disabled',last_error='RECIPIENT_DISABLED' WHERE notification_id=target;RETURN jsonb_build_object('skip',true);END IF;
 IF NOT b.push_enabled THEN UPDATE app_private.push_deliveries SET status='not_configured',last_error='PUSH_DISABLED' WHERE notification_id=target;RETURN jsonb_build_object('skip',true);END IF;
 IF p.fcm_token IS NULL OR NOT EXISTS(SELECT 1 FROM app_private.push_devices WHERE fcm_token=p.fcm_token AND user_id=p.id) THEN UPDATE app_private.push_deliveries SET status='no_device',last_error='NO_DEVICE' WHERE notification_id=target;RETURN jsonb_build_object('skip',true);END IF;
 UPDATE app_private.push_deliveries SET status='processing',attempts=attempts+1,leased_at=now(),last_error=NULL WHERE notification_id=target;
 RETURN jsonb_build_object('fcm_token',p.fcm_token,'project_id',b.fcm_project_id,'company_name',b.company_name,'notification_id',target,'type',n.type,'reference_id',n.reference_id,'reference_kind',n.reference_kind);
END; $$;
CREATE FUNCTION public.invalidate_fcm_token(target uuid,secret uuid,device_token text) RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$BEGIN
 UPDATE public.profiles p SET fcm_token=NULL FROM public.notifications n,app_private.push_deliveries d
 WHERE n.id=target AND d.notification_id=n.id AND d.token=secret AND d.status='processing' AND p.id=n.user_id AND p.fcm_token=device_token;
END; $$;
REVOKE ALL ON FUNCTION public.register_my_fcm(text,text),public.unregister_my_fcm(text),public.set_notification_push_settings(boolean) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.register_my_fcm(text,text),public.unregister_my_fcm(text),public.set_notification_push_settings(boolean) TO authenticated;
REVOKE ALL ON FUNCTION public.invalidate_fcm_token(uuid,uuid,text) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.invalidate_fcm_token(uuid,uuid,text) TO service_role;
NOTIFY pgrst, 'reload schema';

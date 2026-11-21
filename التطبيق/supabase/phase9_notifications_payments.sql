-- Product phase eight. Financial payment_status remains generated/unpaid/partial/paid.
ALTER TABLE public.profiles ADD COLUMN push_subscription_id text;
ALTER TABLE public.brand_config ADD COLUMN onesignal_app_id uuid;
ALTER TABLE public.brand_config ADD COLUMN push_enabled boolean NOT NULL DEFAULT false;
ALTER TABLE public.visits ADD COLUMN payment_status text GENERATED ALWAYS AS (CASE payment_review WHEN 'verified' THEN 'paid' WHEN 'rejected' THEN 'rejected' WHEN 'pending_review' THEN 'pending_confirmation' ELSE NULL END) STORED;
ALTER TABLE public.visits ADD COLUMN payment_proof_url text;
ALTER TABLE public.invoices ADD COLUMN payment_confirmation_status text CHECK(payment_confirmation_status IN ('pending_confirmation','paid','rejected'));
ALTER TABLE public.invoices ADD COLUMN payment_proof_url text;
UPDATE public.invoices SET payment_confirmation_status='paid' WHERE payment_status='paid';
CREATE TABLE public.notifications (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),tenant_id uuid NOT NULL,user_id uuid NOT NULL,role text NOT NULL CHECK(role IN ('admin','technician','client')),
 title text NOT NULL,body text NOT NULL,type text NOT NULL,reference_id uuid NOT NULL,reference_kind text NOT NULL CHECK(reference_kind IN ('visit','survey','invoice','report')),
 is_read boolean NOT NULL DEFAULT false,created_at timestamptz NOT NULL DEFAULT now(),event_key text NOT NULL,
 FOREIGN KEY(tenant_id,user_id) REFERENCES public.profiles(tenant_id,id),UNIQUE(user_id,event_key)
);
CREATE INDEX notifications_recipient_date ON public.notifications(user_id,created_at DESC,id DESC);
CREATE INDEX notifications_unread ON public.notifications(user_id) WHERE NOT is_read;
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;ALTER TABLE public.notifications FORCE ROW LEVEL SECURITY;
REVOKE ALL ON public.notifications FROM PUBLIC,anon,authenticated;GRANT SELECT ON public.notifications TO authenticated;GRANT UPDATE(is_read) ON public.notifications TO authenticated;GRANT ALL ON public.notifications TO service_role;
CREATE FUNCTION app_private.notification_member(t uuid,u uuid,r text) RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $$
 SELECT u=(SELECT auth.uid()) AND app_private.has_role(t,r) AND (r<>'client' OR EXISTS(SELECT 1 FROM public.profiles p WHERE p.id=u AND app_private.client_access(t,p.client_id)));
$$;
CREATE POLICY own_notification_read ON public.notifications FOR SELECT TO authenticated USING(app_private.notification_member(tenant_id,user_id,role));
CREATE POLICY own_notification_seen ON public.notifications FOR UPDATE TO authenticated USING(app_private.notification_member(tenant_id,user_id,role)) WITH CHECK(app_private.notification_member(tenant_id,user_id,role));
CREATE TABLE app_private.push_devices(subscription_id text PRIMARY KEY,user_id uuid NOT NULL REFERENCES public.profiles(id),installation_hash text NOT NULL);
CREATE TABLE app_private.notification_transport(singleton boolean PRIMARY KEY DEFAULT true CHECK(singleton),edge_url text NOT NULL,webhook_enabled boolean NOT NULL DEFAULT false);
INSERT INTO app_private.notification_transport VALUES(true,'https://xflvmcdkxfloiovrrpwa.supabase.co/functions/v1/push-notification',false);
CREATE TABLE app_private.push_deliveries (
 notification_id uuid PRIMARY KEY REFERENCES public.notifications(id),token uuid NOT NULL DEFAULT gen_random_uuid(),idempotency_key uuid NOT NULL DEFAULT gen_random_uuid(),
 status text NOT NULL DEFAULT 'pending' CHECK(status IN ('pending','processing','sent','failed','not_configured','no_device','disabled')),
 attempts integer NOT NULL DEFAULT 0,leased_at timestamptz,next_attempt_at timestamptz NOT NULL DEFAULT now(),last_error text,provider_message_id text,request_id bigint
);
REVOKE ALL ON app_private.push_devices,app_private.notification_transport,app_private.push_deliveries FROM PUBLIC,anon,authenticated;
GRANT ALL ON app_private.push_devices,app_private.notification_transport,app_private.push_deliveries TO service_role;
CREATE FUNCTION app_private.dispatch_push(target uuid) RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE d app_private.push_deliveries%ROWTYPE;c app_private.notification_transport%ROWTYPE;request bigint;BEGIN
 SELECT * INTO c FROM app_private.notification_transport WHERE singleton;
 IF NOT c.webhook_enabled THEN RETURN;END IF;
 SELECT * INTO d FROM app_private.push_deliveries WHERE notification_id=target;
 IF d.status NOT IN ('pending','failed','not_configured') OR d.next_attempt_at>now() THEN RETURN;END IF;
 -- pg_net is installed separately on the hosted project, not in local tests.
 IF EXISTS(SELECT 1 FROM pg_namespace WHERE nspname='net') THEN
  BEGIN
   SELECT net.http_post(url:=c.edge_url,body:=jsonb_build_object('notification_id',d.notification_id,'token',d.token),headers:='{"Content-Type":"application/json"}'::jsonb,timeout_milliseconds:=10000) INTO request;
   UPDATE app_private.push_deliveries SET request_id=request WHERE notification_id=target;
  EXCEPTION WHEN OTHERS THEN UPDATE app_private.push_deliveries SET last_error='WEBHOOK_QUEUE_FAILED' WHERE notification_id=target;END;
 END IF;
END; $$;
CREATE FUNCTION app_private.queue_push() RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$BEGIN
 INSERT INTO app_private.push_deliveries(notification_id) VALUES(NEW.id);PERFORM app_private.dispatch_push(NEW.id);RETURN NEW;END; $$;
CREATE TRIGGER notification_push_webhook AFTER INSERT ON public.notifications FOR EACH ROW EXECUTE FUNCTION app_private.queue_push();
CREATE FUNCTION app_private.notify_event(company uuid,audience text,customer uuid,recipient uuid,event text,kind text,reference uuid,heading text,message text,dedupe text) RETURNS void LANGUAGE sql SECURITY DEFINER SET search_path='' AS $$
 INSERT INTO public.notifications(tenant_id,user_id,role,title,body,type,reference_kind,reference_id,event_key)
 SELECT p.tenant_id,p.id,p.role,heading,message,event,kind,reference,dedupe FROM public.profiles p
 WHERE p.tenant_id=company AND p.is_active AND p.role=audience AND EXISTS(SELECT 1 FROM public.tenants t WHERE t.id=company AND t.is_active)
 AND (recipient IS NULL OR p.id=recipient) AND (audience<>'client' OR (p.client_id=customer AND p.portal_enabled AND EXISTS(SELECT 1 FROM public.clients c WHERE c.id=customer AND c.tenant_id=company AND c.portal_enabled))) ON CONFLICT(user_id,event_key) DO NOTHING;
$$;
CREATE FUNCTION app_private.visit_notifications() RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE version text;BEGIN
 IF TG_OP='INSERT' THEN
  IF NEW.contract_id IS NULL AND NEW.status='pending_schedule' THEN
   PERFORM app_private.notify_event(NEW.tenant_id,'admin',NULL,NULL,'new_order','visit',NEW.id,'طلب خدمة جديد','وصل طلب خدمة مرة واحدة.','order:'||NEW.id);
  END IF;
 END IF;
 IF NEW.payment_review='pending_review' THEN
  IF TG_OP='INSERT' THEN version:=coalesce(NEW.payment_proof_url,'initial');
  ELSIF OLD.payment_review IS DISTINCT FROM NEW.payment_review OR OLD.payment_proof_url IS DISTINCT FROM NEW.payment_proof_url THEN version:=coalesce(NEW.payment_proof_url,'initial');END IF;
  IF version IS NOT NULL THEN PERFORM app_private.notify_event(NEW.tenant_id,'admin',NULL,NULL,'payment_pending','visit',NEW.id,'دفع بانتظار المراجعة','راجع الطلب وإثبات التحويل قبل الاعتماد.','payment_pending:visit:'||NEW.id||':'||md5(version));END IF;
 END IF;
 IF NEW.technician_id IS NOT NULL THEN
  IF TG_OP='INSERT' THEN version:='assigned';
  ELSIF OLD.technician_id IS DISTINCT FROM NEW.technician_id THEN version:='assigned';ELSE version:=NULL;END IF;
  IF version='assigned' THEN PERFORM app_private.notify_event(NEW.tenant_id,'technician',NULL,NEW.technician_id,'visit_assigned','visit',NEW.id,'زيارة جديدة لك','تم تعيين زيارة لك. افتح التفاصيل للاطلاع على الموعد والموقع.','assigned:'||NEW.id||':'||NEW.technician_id||':'||NEW.updated_at);END IF;
 END IF;
 IF TG_OP='UPDATE' THEN
  IF NEW.payment_review='verified' AND OLD.payment_review IS DISTINCT FROM NEW.payment_review THEN
   PERFORM app_private.notify_event(NEW.tenant_id,'client',NEW.client_id,NULL,'payment_confirmed','visit',NEW.id,'تم تأكيد الدفع','اعتمدت الإدارة استلام دفعتك.','paid:visit:'||NEW.id||':'||NEW.payment_verified_at);
  ELSIF NEW.payment_review='rejected' AND OLD.payment_review IS DISTINCT FROM NEW.payment_review THEN
   PERFORM app_private.notify_event(NEW.tenant_id,'client',NEW.client_id,NULL,'payment_rejected','visit',NEW.id,'تحتاج دفعتك مراجعة','لم تعتمد الإدارة تأكيد الدفع. تواصل معها أو أرسل إثباتاً جديداً.','rejected:visit:'||NEW.id||':'||NEW.updated_at);
  END IF;
  IF NEW.scheduled_start IS DISTINCT FROM OLD.scheduled_start OR NEW.scheduled_end IS DISTINCT FROM OLD.scheduled_end THEN
   IF NEW.technician_id IS NOT NULL AND NEW.technician_id IS NOT DISTINCT FROM OLD.technician_id THEN PERFORM app_private.notify_event(NEW.tenant_id,'technician',NULL,NEW.technician_id,'visit_rescheduled','visit',NEW.id,'تحديث موعد زيارة','راجع الموعد المحدّث قبل التحرك.','rescheduled:tech:'||NEW.id||':'||NEW.updated_at);END IF;
   IF NEW.scheduled_start IS NOT NULL THEN PERFORM app_private.notify_event(NEW.tenant_id,'client',NEW.client_id,NULL,'visit_scheduled','visit',NEW.id,'تحديد موعد الزيارة','تم تحديد أو تعديل موعد زيارتك.','scheduled:client:'||NEW.id||':'||NEW.updated_at);END IF;
  END IF;
  IF NEW.status='in_progress' AND OLD.status IS DISTINCT FROM NEW.status THEN
   PERFORM app_private.notify_event(NEW.tenant_id,'admin',NULL,NULL,'visit_started','visit',NEW.id,'بدأت زيارة ميدانية','بدأ الفني تنفيذ زيارة.','started:admin:'||NEW.id);
   PERFORM app_private.notify_event(NEW.tenant_id,'client',NEW.client_id,NULL,'visit_started','visit',NEW.id,'بدأت زيارتك','بدأ الفني تنفيذ الزيارة في موقعك.','started:client:'||NEW.id);
  ELSIF NEW.status='completed' AND OLD.status IS DISTINCT FROM NEW.status THEN
   PERFORM app_private.notify_event(NEW.tenant_id,'admin',NULL,NULL,'visit_completed','visit',NEW.id,'اكتملت زيارة ميدانية','تم إنهاء الزيارة. راجع التقرير والمستندات.','completed:admin:'||NEW.id);
   PERFORM app_private.notify_event(NEW.tenant_id,'client',NEW.client_id,NULL,'visit_completed','visit',NEW.id,'تقرير زيارتك وفاتورتك','اكتملت الزيارة وأصبحت بيانات التقرير والفاتورة متاحة؛ ملفات PDF قد تكون قيد التجهيز.','completed:client:'||NEW.id);
  END IF;
 ELSIF NEW.scheduled_start IS NOT NULL THEN PERFORM app_private.notify_event(NEW.tenant_id,'client',NEW.client_id,NULL,'visit_scheduled','visit',NEW.id,'زيارة قادمة','تم تحديد زيارة قادمة لك.','scheduled:client:'||NEW.id||':'||NEW.updated_at);
 END IF;RETURN NEW;
END; $$;
CREATE TRIGGER notify_visit_events AFTER INSERT OR UPDATE ON public.visits FOR EACH ROW EXECUTE FUNCTION app_private.visit_notifications();
CREATE FUNCTION app_private.survey_notification() RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$BEGIN
 IF NEW.status='survey_pending' THEN PERFORM app_private.notify_event(NEW.tenant_id,'admin',NULL,NULL,'survey_request','survey',NEW.id,'طلب معاينة جديد','وصل طلب معاينة منشأة.','survey:'||NEW.id);END IF;RETURN NEW;END; $$;
CREATE TRIGGER notify_survey_request AFTER INSERT ON public.surveys FOR EACH ROW EXECUTE FUNCTION app_private.survey_notification();
CREATE TABLE public.payment_confirmations (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),tenant_id uuid NOT NULL,invoice_id uuid NOT NULL,client_id uuid NOT NULL,submitted_by uuid NOT NULL,amount numeric(12,2) NOT NULL CHECK(amount>0),
 payment_status text NOT NULL DEFAULT 'pending_confirmation' CHECK(payment_status IN ('pending_confirmation','paid','rejected')),payment_proof_url text NOT NULL,reference text NOT NULL,
 reviewed_by uuid,reviewed_at timestamptz,created_at timestamptz NOT NULL DEFAULT now(),
 FOREIGN KEY(tenant_id,invoice_id) REFERENCES public.invoices(tenant_id,id),FOREIGN KEY(tenant_id,client_id) REFERENCES public.clients(tenant_id,id),FOREIGN KEY(tenant_id,submitted_by) REFERENCES public.profiles(tenant_id,id),FOREIGN KEY(tenant_id,reviewed_by) REFERENCES public.profiles(tenant_id,id)
);
CREATE UNIQUE INDEX one_pending_invoice_payment ON public.payment_confirmations(invoice_id) WHERE payment_status='pending_confirmation';
ALTER TABLE public.payment_confirmations ENABLE ROW LEVEL SECURITY;ALTER TABLE public.payment_confirmations FORCE ROW LEVEL SECURITY;
REVOKE ALL ON public.payment_confirmations FROM PUBLIC,anon,authenticated;GRANT SELECT ON public.payment_confirmations TO authenticated;GRANT ALL ON public.payment_confirmations TO service_role;
CREATE POLICY payment_confirmation_read ON public.payment_confirmations FOR SELECT TO authenticated USING(app_private.is_admin(tenant_id) OR app_private.client_access(tenant_id,client_id));
INSERT INTO storage.buckets(id,name,public,file_size_limit,allowed_mime_types) VALUES('payment-proofs','payment-proofs',false,5242880,ARRAY['image/png','image/jpeg']);
CREATE FUNCTION app_private.proof_access(path text,writing boolean) RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $$
 SELECT position('..' in path)=0 AND position('%' in path)=0 AND (NOT writing OR split_part(path,'/',3)=(SELECT auth.uid())::text) AND (
 EXISTS(SELECT 1 FROM public.invoices i WHERE i.tenant_id::text=split_part(path,'/',1) AND i.id::text=split_part(path,'/',2) AND (app_private.is_admin(i.tenant_id) OR app_private.client_access(i.tenant_id,i.client_id)) AND (NOT writing OR (i.status='issued' AND i.payment_status<>'paid')))
 OR EXISTS(SELECT 1 FROM public.visits v WHERE v.contract_id IS NULL AND v.tenant_id::text=split_part(path,'/',1) AND v.id::text=split_part(path,'/',2) AND (app_private.is_admin(v.tenant_id) OR app_private.client_access(v.tenant_id,v.client_id)) AND (NOT writing OR (v.status='pending_schedule' AND v.payment_review IN ('pending_review','rejected')))));
$$;
CREATE POLICY payment_proof_read ON storage.objects FOR SELECT TO authenticated USING(bucket_id='payment-proofs' AND app_private.proof_access(name,false));
CREATE POLICY payment_proof_insert ON storage.objects FOR INSERT TO authenticated WITH CHECK(bucket_id='payment-proofs' AND app_private.proof_access(name,true));
CREATE FUNCTION public.submit_payment_proof(target uuid,kind text,object_path text,payment_reference text) RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE i public.invoices%ROWTYPE;v public.visits%ROWTYPE;BEGIN
 IF payment_reference IS NULL OR length(trim(payment_reference)) NOT BETWEEN 3 AND 200 OR NOT app_private.proof_access(object_path,true) OR split_part(object_path,'/',2)<>target::text OR NOT EXISTS(SELECT 1 FROM storage.objects WHERE bucket_id='payment-proofs' AND name=object_path) THEN RAISE EXCEPTION 'VALID_SCOPED_PAYMENT_PROOF_REQUIRED';END IF;
 IF kind='invoice' THEN
  SELECT * INTO i FROM public.invoices WHERE id=target FOR UPDATE;
  IF NOT FOUND OR NOT (app_private.is_admin(i.tenant_id) OR app_private.client_access(i.tenant_id,i.client_id)) OR i.status<>'issued' OR i.payment_status='paid' THEN RAISE EXCEPTION 'UNPAID_INVOICE_REQUIRED';END IF;
  IF EXISTS(SELECT 1 FROM public.payment_confirmations WHERE invoice_id=i.id AND payment_proof_url=object_path AND payment_status='pending_confirmation') THEN RETURN;END IF;
  INSERT INTO public.payment_confirmations(tenant_id,invoice_id,client_id,submitted_by,amount,payment_proof_url,reference) VALUES(i.tenant_id,i.id,i.client_id,(SELECT auth.uid()),i.total-i.amount_paid,object_path,trim(payment_reference));
  UPDATE public.invoices SET payment_confirmation_status='pending_confirmation',payment_proof_url=object_path WHERE id=i.id;
  PERFORM app_private.notify_event(i.tenant_id,'admin',NULL,NULL,'payment_pending','invoice',i.id,'إثبات دفع بانتظار التأكيد','راجع الإيصال والمبلغ قبل تسجيل التحصيل.','payment_pending:invoice:'||i.id||':'||md5(object_path));
 ELSIF kind='visit' THEN
  SELECT * INTO v FROM public.visits WHERE id=target FOR UPDATE;
  IF NOT FOUND OR NOT (app_private.is_admin(v.tenant_id) OR app_private.client_access(v.tenant_id,v.client_id)) OR v.contract_id IS NOT NULL OR v.status<>'pending_schedule' OR v.payment_review NOT IN ('pending_review','rejected') THEN RAISE EXCEPTION 'PENDING_ORDER_REQUIRED';END IF;
  IF v.payment_proof_url=object_path AND v.payment_review='pending_review' THEN RETURN;END IF;
  UPDATE public.visits SET payment_proof_url=object_path,payment_reference=trim(submit_payment_proof.payment_reference),payment_review='pending_review',payment_verified_by=NULL,payment_verified_at=NULL WHERE id=v.id;
 ELSE RAISE EXCEPTION 'INVALID_PAYMENT_KIND';END IF;
END; $$;
CREATE FUNCTION public.review_invoice_payment(confirmation uuid,approved boolean) RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE company uuid:=app_private.ops_admin_tenant();p public.payment_confirmations%ROWTYPE;i public.invoices%ROWTYPE;invoice uuid;BEGIN
 SELECT invoice_id INTO invoice FROM public.payment_confirmations WHERE id=confirmation AND tenant_id=company;
 SELECT * INTO i FROM public.invoices WHERE id=invoice FOR UPDATE;
 SELECT * INTO p FROM public.payment_confirmations WHERE id=confirmation AND tenant_id=company FOR UPDATE;
 IF p.id IS NULL OR approved IS NULL OR p.payment_status<>'pending_confirmation' THEN RAISE EXCEPTION 'PENDING_PAYMENT_REQUIRED';END IF;
 IF approved THEN
  IF i.status<>'issued' OR i.total-i.amount_paid<>p.amount THEN RAISE EXCEPTION 'PAYMENT_BALANCE_CHANGED';END IF;
  PERFORM public.record_invoice_paid(i.id,'Proof '||p.id||': '||left(p.reference,150));
 ELSE
  UPDATE public.payment_confirmations SET payment_status='rejected',reviewed_by=(SELECT auth.uid()),reviewed_at=now() WHERE id=p.id;
  UPDATE public.invoices SET payment_confirmation_status=CASE WHEN payment_status='paid' THEN 'paid' ELSE 'rejected' END WHERE id=i.id;
  PERFORM app_private.notify_event(company,'client',i.client_id,NULL,'payment_rejected','invoice',i.id,'مراجعة إثبات الدفع','لم تعتمد الإدارة إثبات التحويل. راجع الفاتورة وتواصل معها.','payment_rejected:invoice:'||p.id);
 END IF;
END; $$;
CREATE FUNCTION app_private.invoice_payment_notification() RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$BEGIN
 IF NEW.payment_status='paid' AND OLD.payment_status IS DISTINCT FROM NEW.payment_status THEN
  UPDATE public.invoices SET payment_confirmation_status='paid' WHERE id=NEW.id AND payment_confirmation_status IS DISTINCT FROM 'paid';
  UPDATE public.payment_confirmations SET payment_status='paid',reviewed_by=(SELECT auth.uid()),reviewed_at=now() WHERE invoice_id=NEW.id AND payment_status='pending_confirmation';
  PERFORM app_private.notify_event(NEW.tenant_id,'client',NEW.client_id,NULL,'payment_confirmed','invoice',NEW.id,'تم تأكيد سداد الفاتورة','تم تسجيل استلام المبلغ المستحق على فاتورتك.','paid:invoice:'||NEW.id);
 END IF;RETURN NEW;END; $$;
CREATE TRIGGER notify_invoice_payment AFTER UPDATE OF amount_paid ON public.invoices FOR EACH ROW EXECUTE FUNCTION app_private.invoice_payment_notification();
CREATE FUNCTION public.mark_notifications_read(target uuid DEFAULT NULL) RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$BEGIN
 UPDATE public.notifications SET is_read=true WHERE user_id=(SELECT auth.uid()) AND NOT is_read AND (target IS NULL OR id=target) AND app_private.notification_member(tenant_id,user_id,role);END; $$;
CREATE FUNCTION public.get_notification_settings() RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $$
DECLARE p public.profiles%ROWTYPE;BEGIN SELECT * INTO p FROM public.profiles WHERE id=(SELECT auth.uid());
 IF NOT coalesce(app_private.notification_member(p.tenant_id,p.id,p.role),false) THEN RAISE EXCEPTION 'ACTIVE_ACCOUNT_REQUIRED';END IF;
 RETURN (SELECT jsonb_build_object('app_id',b.onesignal_app_id,'push_enabled',b.push_enabled,'webhook_enabled',(SELECT webhook_enabled FROM app_private.notification_transport WHERE singleton),'tenant_id',p.tenant_id) FROM public.brand_config b WHERE b.tenant_id=p.tenant_id);END; $$;
CREATE FUNCTION public.register_my_push(subscription text,installation_secret text) RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE p public.profiles%ROWTYPE;d app_private.push_devices%ROWTYPE;hash text;BEGIN
 SELECT * INTO p FROM public.profiles WHERE id=(SELECT auth.uid());
 IF NOT coalesce(app_private.notification_member(p.tenant_id,p.id,p.role),false) THEN RAISE EXCEPTION 'ACTIVE_ACCOUNT_REQUIRED';END IF;
 IF subscription IS NULL OR subscription !~ '^[a-f0-9-]{36}$' OR installation_secret IS NULL OR installation_secret !~ '^[a-f0-9]{64}$' THEN RAISE EXCEPTION 'INVALID_DEVICE';END IF;
 hash:=encode(sha256(convert_to(installation_secret,'UTF8')),'hex');PERFORM pg_advisory_xact_lock(hashtextextended(subscription,0));
 SELECT * INTO d FROM app_private.push_devices WHERE subscription_id=subscription FOR UPDATE;
 IF FOUND AND d.installation_hash<>hash THEN RAISE EXCEPTION 'DEVICE_ALREADY_BOUND';END IF;
 UPDATE public.profiles SET push_subscription_id=NULL WHERE push_subscription_id=subscription AND id<>p.id;
 INSERT INTO app_private.push_devices VALUES(subscription,p.id,hash) ON CONFLICT(subscription_id) DO UPDATE SET user_id=excluded.user_id;
 UPDATE public.profiles SET push_subscription_id=subscription WHERE id=p.id;
END; $$;
CREATE FUNCTION public.unregister_my_push(subscription text) RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$BEGIN UPDATE public.profiles SET push_subscription_id=NULL WHERE id=(SELECT auth.uid()) AND push_subscription_id=subscription;END; $$;
CREATE FUNCTION public.claim_push_delivery(target uuid,secret uuid) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE d app_private.push_deliveries%ROWTYPE;n public.notifications%ROWTYPE;p public.profiles%ROWTYPE;b public.brand_config%ROWTYPE;BEGIN
 SELECT * INTO d FROM app_private.push_deliveries WHERE notification_id=target FOR UPDATE;
 IF NOT FOUND OR d.token IS DISTINCT FROM secret THEN RAISE EXCEPTION 'INVALID_DELIVERY';END IF;
 IF d.status='sent' OR d.next_attempt_at>now() OR (d.status='processing' AND d.leased_at>now()-interval '2 minutes') THEN RETURN jsonb_build_object('skip',true);END IF;
 SELECT * INTO n FROM public.notifications WHERE id=target;SELECT * INTO p FROM public.profiles WHERE id=n.user_id;SELECT * INTO b FROM public.brand_config WHERE tenant_id=n.tenant_id;
 IF NOT p.is_active OR p.role<>n.role OR p.tenant_id<>n.tenant_id OR NOT EXISTS(SELECT 1 FROM public.tenants WHERE id=n.tenant_id AND is_active) OR (p.role='client' AND (NOT p.portal_enabled OR NOT EXISTS(SELECT 1 FROM public.clients WHERE id=p.client_id AND tenant_id=p.tenant_id AND portal_enabled))) THEN
  UPDATE app_private.push_deliveries SET status='disabled',last_error='RECIPIENT_DISABLED' WHERE notification_id=target;RETURN jsonb_build_object('skip',true);END IF;
 IF NOT b.push_enabled OR b.onesignal_app_id IS NULL THEN UPDATE app_private.push_deliveries SET status='not_configured',last_error='PUSH_SETTINGS_MISSING' WHERE notification_id=target;RETURN jsonb_build_object('skip',true);END IF;
 IF p.push_subscription_id IS NULL OR NOT EXISTS(SELECT 1 FROM app_private.push_devices WHERE subscription_id=p.push_subscription_id AND user_id=p.id) THEN UPDATE app_private.push_deliveries SET status='no_device',last_error='NO_DEVICE' WHERE notification_id=target;RETURN jsonb_build_object('skip',true);END IF;
 UPDATE app_private.push_deliveries SET status='processing',attempts=attempts+1,leased_at=now(),last_error=NULL WHERE notification_id=target;
 RETURN jsonb_build_object('idempotency_key',d.idempotency_key,'subscription_id',p.push_subscription_id,'app_id',b.onesignal_app_id,'company_name',b.company_name,'notification_id',target);
END; $$;
CREATE FUNCTION public.finish_push_delivery(target uuid,secret uuid,result text,provider_id text DEFAULT NULL) RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$BEGIN
 IF result NOT IN ('sent','failed','not_configured','no_device') THEN RAISE EXCEPTION 'INVALID_RESULT';END IF;
 UPDATE app_private.push_deliveries SET status=result,provider_message_id=CASE WHEN result='sent' THEN provider_id ELSE NULL END,last_error=CASE WHEN result='sent' THEN NULL ELSE upper(result) END,next_attempt_at=now()+interval '2 minutes' WHERE notification_id=target AND token=secret AND status='processing';END; $$;
CREATE FUNCTION public.retry_notification_pushes() RETURNS integer LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE company uuid:=app_private.ops_admin_tenant();item record;amount integer:=0;BEGIN
 FOR item IN SELECT d.notification_id FROM app_private.push_deliveries d JOIN public.notifications n ON n.id=d.notification_id WHERE n.tenant_id=company AND n.created_at>now()-interval '24 hours' AND (d.status IN ('pending','failed','not_configured','no_device') OR (d.status='processing' AND d.leased_at<now()-interval '2 minutes')) ORDER BY n.created_at LIMIT 100 LOOP
 UPDATE app_private.push_deliveries SET status='pending',next_attempt_at=now() WHERE notification_id=item.notification_id;
 PERFORM app_private.dispatch_push(item.notification_id);amount:=amount+1;END LOOP;RETURN amount;END; $$;
CREATE FUNCTION public.set_notification_push_settings(app_id uuid,enabled boolean) RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$DECLARE company uuid:=app_private.ops_admin_tenant();BEGIN IF enabled IS NULL OR (enabled AND app_id IS NULL) THEN RAISE EXCEPTION 'APP_ID_REQUIRED';END IF;UPDATE public.brand_config SET onesignal_app_id=app_id,push_enabled=enabled WHERE tenant_id=company;END; $$;
REVOKE ALL ON FUNCTION app_private.notification_member(uuid,uuid,text),app_private.proof_access(text,boolean) FROM PUBLIC,anon;GRANT EXECUTE ON FUNCTION app_private.notification_member(uuid,uuid,text),app_private.proof_access(text,boolean) TO authenticated;
REVOKE ALL ON FUNCTION app_private.dispatch_push(uuid),app_private.notify_event(uuid,text,uuid,uuid,text,text,uuid,text,text,text) FROM PUBLIC,anon,authenticated;
REVOKE ALL ON FUNCTION public.mark_notifications_read(uuid),public.get_notification_settings(),public.register_my_push(text,text),public.unregister_my_push(text),public.submit_payment_proof(uuid,text,text,text),public.review_invoice_payment(uuid,boolean),public.retry_notification_pushes(),public.set_notification_push_settings(uuid,boolean) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.mark_notifications_read(uuid),public.get_notification_settings(),public.register_my_push(text,text),public.unregister_my_push(text),public.submit_payment_proof(uuid,text,text,text),public.review_invoice_payment(uuid,boolean),public.retry_notification_pushes(),public.set_notification_push_settings(uuid,boolean) TO authenticated;
REVOKE ALL ON FUNCTION public.claim_push_delivery(uuid,uuid),public.finish_push_delivery(uuid,uuid,text,text) FROM PUBLIC,anon,authenticated;GRANT EXECUTE ON FUNCTION public.claim_push_delivery(uuid,uuid),public.finish_push_delivery(uuid,uuid,text,text) TO service_role;
ALTER PUBLICATION supabase_realtime ADD TABLE public.notifications,public.payment_confirmations;

REVOKE ALL ON FUNCTION app_private.queue_push(),app_private.visit_notifications(),app_private.survey_notification(),app_private.invoice_payment_notification() FROM PUBLIC,anon,authenticated;

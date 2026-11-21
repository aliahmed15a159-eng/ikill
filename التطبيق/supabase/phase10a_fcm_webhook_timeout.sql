-- OAuth + a single HTTP-v1 401 refresh can take longer than the old 10s webhook timeout.
CREATE OR REPLACE FUNCTION app_private.dispatch_push(target uuid) RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE d app_private.push_deliveries%ROWTYPE;c app_private.notification_transport%ROWTYPE;request bigint;BEGIN
 SELECT * INTO c FROM app_private.notification_transport WHERE singleton;
 IF NOT c.webhook_enabled THEN RETURN;END IF;
 SELECT * INTO d FROM app_private.push_deliveries WHERE notification_id=target;
 IF d.status NOT IN ('pending','failed','not_configured') OR d.next_attempt_at>now() THEN RETURN;END IF;
 IF EXISTS(SELECT 1 FROM pg_namespace WHERE nspname='net') THEN
  BEGIN
   SELECT net.http_post(url:=c.edge_url,body:=jsonb_build_object('notification_id',d.notification_id,'token',d.token),headers:='{"Content-Type":"application/json"}'::jsonb,timeout_milliseconds:=60000) INTO request;
   UPDATE app_private.push_deliveries SET request_id=request WHERE notification_id=target;
  EXCEPTION WHEN OTHERS THEN UPDATE app_private.push_deliveries SET last_error='WEBHOOK_QUEUE_FAILED' WHERE notification_id=target;END;
 END IF;
END; $$;

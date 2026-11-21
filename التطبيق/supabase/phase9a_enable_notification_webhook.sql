-- Hosted Supabase only; intentionally excluded from local PGlite tests.
-- Deploy push-notification with verify_jwt=false BEFORE enabling this trigger.
-- Requests are authenticated inside the handler via per-delivery random tokens.
CREATE EXTENSION IF NOT EXISTS pg_net WITH SCHEMA extensions;
UPDATE app_private.notification_transport SET webhook_enabled=true WHERE singleton;
NOTIFY pgrst, 'reload schema';

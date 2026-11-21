-- Best-effort tightening where the migration role owns these extension tables.
-- Managed Supabase may keep supabase_admin-owned PUBLIC grants: verify results.
-- Never expose net through PostgREST; see NOTIFICATIONS_PAYMENTS_STATUS.md.
REVOKE ALL ON TABLE net.http_request_queue,net._http_response FROM PUBLIC,anon,authenticated;
GRANT ALL ON TABLE net.http_request_queue,net._http_response TO service_role;

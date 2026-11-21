-- pg_net defaults grant PUBLIC table access; delivery tokens stay server-only.
REVOKE ALL ON TABLE net.http_request_queue,net._http_response FROM PUBLIC,anon,authenticated;
GRANT ALL ON TABLE net.http_request_queue,net._http_response TO service_role;

-- Product phase five: operational summaries, calendar, assignment and Realtime.
ALTER TABLE public.client_sites ADD COLUMN default_technician_id uuid;
ALTER TABLE public.client_sites ADD FOREIGN KEY(tenant_id,default_technician_id) REFERENCES public.profiles(tenant_id,id);
CREATE FUNCTION app_private.ops_admin_tenant() RETURNS uuid LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $$
DECLARE company uuid;
BEGIN SELECT tenant_id INTO company FROM public.profiles WHERE id=(SELECT auth.uid()) AND app_private.is_admin(tenant_id);
 IF company IS NULL THEN RAISE EXCEPTION 'ADMIN_REQUIRED'; END IF; RETURN company;
END; $$;
CREATE FUNCTION public.get_operations_summary() RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $$
DECLARE company uuid:=app_private.ops_admin_tenant(); zone text; today date; lo timestamptz; hi timestamptz;
BEGIN SELECT timezone INTO zone FROM public.tenants WHERE id=company;
 today:=(now() AT TIME ZONE zone)::date; lo:=today::timestamp AT TIME ZONE zone; hi:=(today+1)::timestamp AT TIME ZONE zone;
 RETURN jsonb_build_object('timezone',zone,'today',today,
 'scheduled',(SELECT count(*) FROM public.visits WHERE tenant_id=company AND scheduled_start>=lo AND scheduled_start<hi AND status IN ('scheduled','confirmed')),
 'in_progress',(SELECT count(*) FROM public.visits WHERE tenant_id=company AND scheduled_start>=lo AND scheduled_start<hi AND status='in_progress'),
 'completed',(SELECT count(*) FROM public.visits WHERE tenant_id=company AND scheduled_start>=lo AND scheduled_start<hi AND status='completed'),
 'new_surveys',(SELECT count(*) FROM public.surveys WHERE tenant_id=company AND status='survey_pending'),
 'pending_schedule',(SELECT count(*) FROM public.visits WHERE tenant_id=company AND status='pending_schedule'),
 'active_contracts',(SELECT count(*) FROM public.contracts WHERE tenant_id=company AND status='active' AND starts_on<=today AND ends_on>=today),
 'unpaid_invoices',(SELECT count(*) FROM public.invoices WHERE tenant_id=company AND status='issued' AND payment_status IN ('unpaid','partial')));
END; $$;
CREATE FUNCTION public.get_operations_context() RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $$
DECLARE company uuid:=app_private.ops_admin_tenant();
BEGIN RETURN jsonb_build_object('tenant_id',company,
 'clients',coalesce((SELECT jsonb_agg(jsonb_build_object('id',id,'name',display_name) ORDER BY display_name) FROM public.clients WHERE tenant_id=company),'[]'::jsonb),
 'sites',coalesce((SELECT jsonb_agg(jsonb_build_object('id',id,'name',name,'client_id',client_id,'default_technician_id',default_technician_id,'is_active',is_active) ORDER BY name) FROM public.client_sites WHERE tenant_id=company),'[]'::jsonb),
 'technicians',coalesce((SELECT jsonb_agg(jsonb_build_object('id',id,'name',full_name,'is_active',is_active) ORDER BY full_name) FROM public.profiles WHERE tenant_id=company AND role='technician'),'[]'::jsonb)); END; $$;
CREATE FUNCTION public.get_operations_visits(first_day date,last_day date,customer uuid DEFAULT NULL,site uuid DEFAULT NULL,technician uuid DEFAULT NULL,page_offset integer DEFAULT 0) RETURNS SETOF jsonb
 LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $$
DECLARE company uuid:=app_private.ops_admin_tenant(); zone text;
BEGIN
 IF first_day IS NULL OR last_day IS NULL OR last_day<=first_day OR last_day-first_day>62 OR page_offset<0 OR page_offset IS NULL THEN RAISE EXCEPTION 'INVALID_CALENDAR_RANGE'; END IF;
 SELECT timezone INTO zone FROM public.tenants WHERE id=company;
 RETURN QUERY SELECT to_jsonb(v)||jsonb_build_object('client_name',c.display_name,'site_name',s.name,'technician_name',p.full_name,
 'local_day',(v.scheduled_start AT TIME ZONE zone)::date,'local_time',to_char(v.scheduled_start AT TIME ZONE zone,'HH24:MI'),'site_contact_phone',s.contact_phone,'site_address',s.address)
 FROM public.visits v JOIN public.clients c ON c.tenant_id=v.tenant_id AND c.id=v.client_id
 JOIN public.client_sites s ON s.tenant_id=v.tenant_id AND s.id=v.site_id LEFT JOIN public.profiles p ON p.tenant_id=v.tenant_id AND p.id=v.technician_id
 WHERE v.tenant_id=company AND v.scheduled_start>=first_day::timestamp AT TIME ZONE zone AND v.scheduled_start<last_day::timestamp AT TIME ZONE zone
 AND (customer IS NULL OR v.client_id=customer) AND (site IS NULL OR v.site_id=site) AND (technician IS NULL OR v.technician_id=technician)
 ORDER BY v.scheduled_start,v.id LIMIT 250 OFFSET page_offset;
END; $$;
CREATE FUNCTION app_private.apply_site_technician() RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
 IF NEW.technician_id IS NULL THEN
 SELECT p.id INTO NEW.technician_id FROM public.client_sites s JOIN public.profiles p ON p.tenant_id=s.tenant_id AND p.id=s.default_technician_id
 WHERE s.tenant_id=NEW.tenant_id AND s.client_id=NEW.client_id AND s.id=NEW.site_id AND p.is_active AND p.role='technician';
 END IF; RETURN NEW;
END; $$;
CREATE TRIGGER apply_site_technician BEFORE INSERT ON public.visits FOR EACH ROW EXECUTE FUNCTION app_private.apply_site_technician();
CREATE FUNCTION app_private.check_site_technician() RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
 IF NEW.default_technician_id IS NOT NULL AND NOT EXISTS(SELECT 1 FROM public.profiles WHERE tenant_id=NEW.tenant_id AND id=NEW.default_technician_id AND is_active AND role='technician')
 THEN RAISE EXCEPTION 'ACTIVE_TECHNICIAN_REQUIRED'; END IF; RETURN NEW;
END; $$;
CREATE TRIGGER check_site_technician BEFORE INSERT OR UPDATE OF default_technician_id ON public.client_sites FOR EACH ROW EXECUTE FUNCTION app_private.check_site_technician();
CREATE FUNCTION public.assign_operations_technician(visit_id uuid,technician uuid) RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE company uuid:=app_private.ops_admin_tenant(); item public.visits%ROWTYPE;
BEGIN
 SELECT * INTO item FROM public.visits WHERE id=visit_id AND tenant_id=company FOR UPDATE;
 IF NOT FOUND OR item.status NOT IN ('pending_schedule','scheduled','confirmed') OR (item.scheduled_start IS NOT NULL AND item.scheduled_start<now()) THEN RAISE EXCEPTION 'VISIT_NOT_ASSIGNABLE'; END IF;
 IF technician IS NOT NULL AND NOT EXISTS(SELECT 1 FROM public.profiles WHERE tenant_id=company AND id=technician AND role='technician' AND is_active) THEN RAISE EXCEPTION 'ACTIVE_TECHNICIAN_REQUIRED'; END IF;
 UPDATE public.visits SET technician_id=technician WHERE id=item.id;
END; $$;
CREATE FUNCTION public.assign_site_technician(site_id uuid,technician uuid) RETURNS integer LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE company uuid:=app_private.ops_admin_tenant(); affected integer;
BEGIN
 IF technician IS NOT NULL AND NOT EXISTS(SELECT 1 FROM public.profiles WHERE tenant_id=company AND id=technician AND role='technician' AND is_active) THEN RAISE EXCEPTION 'ACTIVE_TECHNICIAN_REQUIRED'; END IF;
 PERFORM 1 FROM public.client_sites WHERE tenant_id=company AND id=site_id AND is_active FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'SITE_REQUIRED'; END IF;
 UPDATE public.client_sites SET default_technician_id=technician WHERE id=site_id AND tenant_id=company;
 UPDATE public.visits SET technician_id=technician WHERE tenant_id=company AND visits.site_id=assign_site_technician.site_id
 AND status IN ('pending_schedule','scheduled','confirmed') AND (scheduled_start IS NULL OR scheduled_start>=now());
 GET DIAGNOSTICS affected=ROW_COUNT; RETURN affected;
END; $$;
-- Technicians cannot edit schedules, ownership, pricing or assignment. Only the
-- authenticated assigned active technician can transition their own visit.
CREATE FUNCTION public.set_my_visit_state(visit_id uuid,next_state text) RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE item public.visits%ROWTYPE;
BEGIN
 SELECT * INTO item FROM public.visits WHERE id=visit_id FOR UPDATE;
 IF NOT FOUND OR item.technician_id IS DISTINCT FROM (SELECT auth.uid()) OR NOT app_private.has_role(item.tenant_id,'technician') THEN RAISE EXCEPTION 'ASSIGNED_TECHNICIAN_REQUIRED'; END IF;
 IF item.status=next_state AND next_state IN ('in_progress','completed') THEN RETURN; END IF;
 IF next_state='in_progress' AND item.status IN ('scheduled','confirmed') AND item.scheduled_start<=now() THEN
 UPDATE public.visits SET status='in_progress',started_at=coalesce(started_at,now()) WHERE id=item.id;
 ELSIF next_state='completed' AND item.status='in_progress' THEN
 UPDATE public.visits SET status='completed',completed_at=now() WHERE id=item.id;
 ELSE RAISE EXCEPTION 'INVALID_VISIT_TRANSITION'; END IF;
END; $$;
REVOKE ALL ON FUNCTION public.get_operations_summary(),public.get_operations_context(),public.get_operations_visits(date,date,uuid,uuid,uuid,integer),public.assign_operations_technician(uuid,uuid),public.assign_site_technician(uuid,uuid),public.set_my_visit_state(uuid,text) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.get_operations_summary(),public.get_operations_context(),public.get_operations_visits(date,date,uuid,uuid,uuid,integer),public.assign_operations_technician(uuid,uuid),public.assign_site_technician(uuid,uuid),public.set_my_visit_state(uuid,text) TO authenticated;
-- No REPLICA IDENTITY FULL: updates are re-fetched under RLS, not trusted from
-- arbitrary client payloads. Default primary keys suffice for invalidation.
DO $$ DECLARE table_name text; BEGIN
 IF NOT EXISTS(SELECT 1 FROM pg_publication WHERE pubname='supabase_realtime') THEN CREATE PUBLICATION supabase_realtime; END IF;
 FOREACH table_name IN ARRAY ARRAY['visits','surveys','contracts','invoices','clients','client_sites','profiles'] LOOP
 IF NOT EXISTS(SELECT 1 FROM pg_publication_tables WHERE pubname='supabase_realtime' AND schemaname='public' AND tablename=table_name) THEN
 EXECUTE format('ALTER PUBLICATION supabase_realtime ADD TABLE public.%I',table_name);
 END IF;
 END LOOP;
END; $$;

-- Native field reports. No customer data is created by this migration.
ALTER TABLE public.visit_reports ADD COLUMN submission_key text;
-- Report submission is only through the transactional RPC, never a partial
-- client-side insert followed by a separate completion request.
DROP POLICY report_technician_insert ON public.visit_reports;
DROP POLICY report_technician_update ON public.visit_reports;
CREATE OR REPLACE FUNCTION public.set_my_visit_state(visit_id uuid,next_state text) RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE item public.visits%ROWTYPE;
BEGIN
 SELECT * INTO item FROM public.visits WHERE id=visit_id FOR UPDATE;
 IF NOT FOUND OR item.technician_id IS DISTINCT FROM (SELECT auth.uid()) OR NOT app_private.has_role(item.tenant_id,'technician') THEN RAISE EXCEPTION 'ASSIGNED_TECHNICIAN_REQUIRED'; END IF;
 IF next_state='in_progress' AND item.status='in_progress' THEN RETURN; END IF;
 IF next_state='in_progress' AND item.status IN ('scheduled','confirmed') AND item.scheduled_start<=now() THEN
 UPDATE public.visits SET status='in_progress',started_at=coalesce(started_at,now()) WHERE id=item.id;
 ELSE RAISE EXCEPTION 'SUBMIT_REPORT_TO_COMPLETE'; END IF;
END; $$;
CREATE FUNCTION public.get_my_field_visits(page_offset integer DEFAULT 0) RETURNS SETOF jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $$
DECLARE company uuid; zone text;
BEGIN
 SELECT p.tenant_id,t.timezone INTO company,zone FROM public.profiles p JOIN public.tenants t ON t.id=p.tenant_id WHERE p.id=(SELECT auth.uid()) AND app_private.has_role(p.tenant_id,'technician');
 IF company IS NULL THEN RAISE EXCEPTION 'TECHNICIAN_REQUIRED'; END IF;
 IF page_offset IS NULL OR page_offset<0 THEN RAISE EXCEPTION 'INVALID_PAGE'; END IF;
 RETURN QUERY SELECT to_jsonb(v)||jsonb_build_object('client_name',c.display_name,'timezone',zone,'local_day',(v.scheduled_start AT TIME ZONE zone)::date,'today',(now() AT TIME ZONE zone)::date,'site',jsonb_build_object('name',s.name,'address',s.address,'contact_name',c.contact_name,'contact_phone',s.contact_phone,'latitude',s.latitude,'longitude',s.longitude))
 FROM public.visits v JOIN public.clients c ON c.tenant_id=v.tenant_id AND c.id=v.client_id JOIN public.client_sites s ON s.tenant_id=v.tenant_id AND s.id=v.site_id
 WHERE v.tenant_id=company AND v.technician_id=(SELECT auth.uid()) AND (v.status='in_progress' OR (v.status IN ('scheduled','confirmed') AND v.scheduled_start>=((now() AT TIME ZONE zone)::date::timestamp AT TIME ZONE zone)))
 ORDER BY v.scheduled_start,v.id LIMIT 250 OFFSET page_offset;
END; $$;
CREATE FUNCTION public.submit_field_report(target_visit uuid,submission text,checklist jsonb,materials text,notes text,photos text[],signature_path text,signer text) RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE item public.visits%ROWTYPE; existing public.visit_reports%ROWTYPE; report_id uuid; prefix text; object_path text;
BEGIN
 SELECT * INTO item FROM public.visits WHERE id=target_visit FOR UPDATE;
 IF NOT FOUND OR item.technician_id IS DISTINCT FROM (SELECT auth.uid()) OR NOT app_private.has_role(item.tenant_id,'technician') THEN RAISE EXCEPTION 'ASSIGNED_TECHNICIAN_REQUIRED'; END IF;
 SELECT * INTO existing FROM public.visit_reports WHERE tenant_id=item.tenant_id AND visit_id=item.id;
 IF FOUND AND existing.status='submitted' THEN
 IF existing.submission_key=submission AND item.status='completed' THEN RETURN existing.id; END IF;
 RAISE EXCEPTION 'REPORT_ALREADY_SUBMITTED'; END IF;
 IF item.status<>'in_progress' THEN RAISE EXCEPTION 'START_VISIT_FIRST'; END IF;
 IF submission IS NULL OR submission !~ '^[a-f0-9]{32}$' OR checklist IS NULL OR jsonb_typeof(checklist)<>'object'
 OR coalesce(checklist->>'pest','') NOT IN ('rodents','cockroaches','ants','flies','mosquitoes','bedbugs','other','none')
 OR coalesce(checklist->>'severity','') NOT IN ('none','low','medium','high')
 OR jsonb_typeof(checklist->'actions') IS DISTINCT FROM 'array' OR jsonb_array_length(checklist->'actions') NOT BETWEEN 1 AND 8
 OR EXISTS(SELECT 1 FROM jsonb_array_elements_text(checklist->'actions') a WHERE a NOT IN ('inspection','spraying','baiting','traps','sealing','sanitation','monitoring','advice'))
 OR materials IS NULL OR length(trim(materials)) NOT BETWEEN 1 AND 4000 OR length(coalesce(notes,''))>8000
 OR checklist->'signature_consent' IS DISTINCT FROM 'true'::jsonb
 OR signer IS NULL OR length(trim(signer)) NOT BETWEEN 2 AND 160 OR signature_path IS NULL
 OR photos IS NULL OR cardinality(photos)>6 OR array_position(photos,NULL) IS NOT NULL THEN RAISE EXCEPTION 'INVALID_REPORT'; END IF;
 prefix:=item.tenant_id::text||'/'||item.id::text||'/'||submission||'/';
 IF signature_path<>prefix||'signature.png' OR NOT EXISTS(SELECT 1 FROM storage.objects WHERE bucket_id='visit-signatures' AND name=signature_path) THEN RAISE EXCEPTION 'SIGNATURE_REQUIRED'; END IF;
 FOREACH object_path IN ARRAY photos LOOP
 IF object_path NOT LIKE prefix||'photo-%.jpg' OR NOT EXISTS(SELECT 1 FROM storage.objects WHERE bucket_id='visit-images' AND name=object_path) THEN RAISE EXCEPTION 'PHOTO_NOT_UPLOADED'; END IF;
 END LOOP;
 IF existing.id IS NOT NULL THEN
 UPDATE public.visit_reports SET status='submitted',selections=checklist,findings=notes,actions_taken=materials,photo_paths=photos,customer_signature_path=signature_path,customer_signer_name=trim(signer),signed_at=now(),submission_key=submission WHERE id=existing.id RETURNING id INTO report_id;
 ELSE
 INSERT INTO public.visit_reports(tenant_id,visit_id,technician_id,status,selections,findings,actions_taken,photo_paths,customer_signature_path,customer_signer_name,signed_at,submission_key)
 VALUES(item.tenant_id,item.id,item.technician_id,'submitted',checklist,notes,materials,photos,signature_path,trim(signer),now(),submission) RETURNING id INTO report_id;
 END IF;
 UPDATE public.visits SET status='completed',completed_at=now() WHERE id=item.id;
 RETURN report_id;
END; $$;
-- Narrow status lookup allows safe retry after an ambiguous network response,
-- before attempting uploads to now-immutable submitted media.
CREATE FUNCTION public.my_field_report_receipt(target_visit uuid,submission text) RETURNS uuid LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $$
BEGIN
 RETURN (SELECT r.id FROM public.visit_reports r JOIN public.visits v ON v.tenant_id=r.tenant_id AND v.id=r.visit_id WHERE v.id=target_visit AND v.technician_id=(SELECT auth.uid()) AND app_private.has_role(v.tenant_id,'technician') AND r.status='submitted' AND r.submission_key=submission);
END; $$;
REVOKE ALL ON FUNCTION public.get_my_field_visits(integer),public.submit_field_report(uuid,text,jsonb,text,text,text[],text,text),public.my_field_report_receipt(uuid,text) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.get_my_field_visits(integer),public.submit_field_report(uuid,text,jsonb,text,text,text[],text,text),public.my_field_report_receipt(uuid,text) TO authenticated;

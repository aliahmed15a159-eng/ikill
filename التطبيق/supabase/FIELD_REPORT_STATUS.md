# Field technician and digital report — user phase six

## Scope
Native app plus supporting Supabase only. No website changes in this phase. No automatic invoicing/payment or certified-signature integration.

## Field workflow
- Own assigned open visits only: scheduled/confirmed visits today and upcoming in the tenant timezone, plus older in-progress visits so unfinished reports remain reachable. RPC pagination in batches of 250, no previous 500-task truncation.
- Client and site names, address, stored site phone/call button, Google Maps external link using coordinates when available, otherwise the stored address. Opening Maps/calls depends on installed apps/device/network. No invented GPS coordinates.
- Starting requires internet, an active assigned technician and scheduled time reached. Server records started_at; report opens after start. Previously started report can be reopened offline using cached tasks/profile on an existing signed-in session.
- Pest/severity choices, action checkboxes, materials/quantities text, notes, up to six camera photos (10 MB each), representative name, drawn signature and explicit consent.
- Signature is a drawn electronic acknowledgement, NOT a certified digital-signature service. Server signed_at is submission time, not independently verified time of offline handwriting.

## Offline storage and retries
- Report JSON is flushed to a temporary file then atomically renamed; writes are serialized and the latest save status is shown. Photos are copied out of camera cache into persistent app-private storage. Signature strokes are stored in the same draft.
- Drafts and cached tasks are scoped by tenant/user/visit. An account cannot open another account's drafts through the UI. Server rechecks active role/assignment before upload/submission; cached access grants no server permissions.
- Local files rely on the OS app sandbox/device protections; no separate application-level encryption is claimed. Android automatic backup is disabled. Protect device access. Clearing app data/uninstalling or losing the device destroys local-only drafts; they do not sync to another phone before submission.
- Camera recovery on Android is tied to the original visit. Reopen that visit's report after process death to recover a pending camera result. Actual OS camera/process-death behavior still needs physical-device testing.
- Submission is explicit, not background auto-sync. After confirmation, the snapshot is locked to avoid conflicting edits during ambiguous retries. Retry the same snapshot when connectivity returns.
- Evidence uploads use private existing visit-images/visit-signatures buckets and stable paths scoped to tenant/visit/submission. A failed upload/commit retains the local draft. Partial server uploads can remain private until a successful retry; no automatic orphan-file cleanup is introduced.
- A receipt lookup handles an acknowledged-on-server/lost-on-network result without duplicate reports or rewriting immutable evidence. A local confirmed receipt is saved before removing the draft/photos, protecting against stale offline task caches.

## Backend
Migration phase7_field_reports deployed as **20261121123423** on existing project xflvmcdkxfloiovrrpwa.
- get_my_field_visits(integer)
- submit_field_report(uuid,text,jsonb,text,text,text[],text,text)
- my_field_report_receipt(uuid,text)
- set_my_visit_state now starts/resumes only. Completion requires report submission. Older phase-five APKs cannot complete a visit with the old standalone finish button; use the phase-six APK.
- Atomic locked-visit transaction validates role, assignment, state, checklist, consent, representative and scoped uploaded-object existence; writes report + server timestamps and completes visit together.
- Direct technician INSERT/UPDATE policies on visit_reports removed; submitted reports/evidence remain immutable to technicians. Clients/admin keep existing read rules. No live test customers/visits/reports/photos were created.
- Read-only production verification: RPCs installed, anon execution false, authenticated execution true with internal authorization, old write policies absent, both evidence buckets private.

## Verification
Local PostgreSQL: **258 assertions** (218 existing + 40 field-report assertions), including injected completion failure rolling report insertion back, unassigned/inactive/client denial, signature/photo scope, idempotent retry and immutable submitted records.
Flutter tests include persistent filesystem photo/draft restoration, account directory isolation, report validation and a narrow-phone restore/edit/autosave widget test. Strict analyze, full Flutter tests, Android debug APK build and dependency checks all passed in CI run **44904986239**, code **73a629f**.

APK ZIP: https://github.com/aliahmed15a159-eng/ikill/actions/runs/44904986239/artifacts/14707472449 — extract and install app-debug.apk. ZIP SHA256: `03a20280d7165ec5dc2567a4ae64b460b4e605827448d88fe293598c565edba8`.
No physical-device camera, Android process-kill, Google Maps/call intent, live authenticated Storage upload or iOS build validation was performed here.

## تجربة القبول
1. ادخل بحساب فني نشط، وتأكد أن الزيارات المعروضة تخصه فقط، مع اسم العميل والموقع ورقم الاتصال وفتح Maps.
2. ابدأ زيارة حان موعدها أثناء الاتصال؛ تحقق من ظهور in_progress لدى الأدمن وفتح التقرير.
3. املأ الاختيارات والمواد والملاحظات. التقط صورة بعد إذن الموقع، ثم اطلب اسم مسؤول الموقع وتوقيعه وموافقته.
4. انتظر ظهور «المسودة محفوظة على الهاتف»، ثم افصل الإنترنت، غادر التقرير وافتحه ثانية. جرّب إغلاق التطبيق وإعادة فتحه على نفس الحساب؛ يجب بقاء النص والصور والتوقيع.
5. اضغط إنهاء وإرسال أثناء انقطاع الشبكة: لا تعتبر الزيارة منتهية، ولا تمسح بيانات التطبيق. أعد الاتصال وأعد إرسال نفس المسودة.
6. تحقق من اكتمال الزيارة لدى الأدمن ووجود سجل واحد للتقرير وملفاته الخاصة. جرّب الضغط/إعادة المحاولة بعد استجابة شبكة غير واضحة للتأكد من عدم التكرار.
7. جرّب رفض إذن الكاميرا، وعدم وجود إحداثيات/رقم اتصال، وتغيير تعيين الزيارة قبل الإرسال؛ يجب رفض العمليات غير المسموحة دون حذف المسودة.

Stop after handoff for user testing. No merge without request.

# User phase seven — billing, server PDFs and selective portal

## Decisions confirmed by user
- One consolidated invoice per contract billing cycle, issued on that cycle's first completed visit; subsequent reports link the same invoice without repeating the charge.
- Quarterly/annual contracts use their actual cycles, not a monthly reinterpretation.
- Native contracts (`app_managed=true`) already store **TOTAL contract value**. This total is divided in integer cents across the number of touched billing cycles, with remainder in the final cycle (100 / 3 -> 33.33, 33.33, 33.34). Partial cycles count as cycles, without day-based proration. Legacy externally managed contracts retain their stored per-cycle billing amount. Cycle anchor is the contract's start month; original recurrence month survives rescheduling.
- No invoice is silently created for a cycle with no completed visit. No bank integration or automatic payment approval.

## Implemented
- New tenant-scoped `brand_config`: company name, logo Storage path, address, phone, email, tax number and HEX color. Admin app tab edits these and uploads PNG/JPG logos. No invented tax data. Default original logo is bootstrapped for the existing original tenant only; another tenant must configure its own logo.
- Edge function `app-documents` renders Arabic/Latin PDF visit reports (checklist, materials, notes, photos, drawn acknowledgement/signature) and invoices (cycle, totals, amounts received, balance and payment state). Mixed-direction text, font embedding, multi-page content and image proportions are handled. Arabic/Latin sample PDFs were rendered locally and visually reviewed; samples contain synthetic data only and are not committed.
- Private `report-pdfs` and existing `invoice-pdfs` buckets. Worker, not Flutter, publishes PDF paths; server validates uploaded objects, lease and exact document scope. Fonts are cached privately in `document-assets` after fetching a pinned public OFL font revision. Font license is under functions/app-documents/FONT_LICENSE.txt; local test font fixtures are included.
- Report submission remains a database transaction, now also linking/issuing the invoice and queuing PDF work. One-off completion requires admin-verified payment and a matching paid invoice, or creates the paid invoice from that already verified quote. It NEVER approves unverified payments. Contract completion creates an unpaid invoice for the allocated cycle charge.
- Technician submission goes through the authenticated Edge endpoint. After DB commit it queues generation using EdgeRuntime.waitUntil so work can continue after the HTTP response. Raw report/invoice become portal-readable immediately; PDF buttons become available after rendering/upload completes (not instant at commit).
- Durable document_jobs with leases and failure state. If background execution/network/quota/font/media fails, invoice/report remain intact. Opening the admin/client archive retries pending jobs in batches; manual retry is available. No perpetual unattended cron retries are claimed. Expired processing leases can be reclaimed after three minutes.
- Admin collection action requires explicit confirmation/reference, records remaining balance only with actor/time/amount audit, is idempotent, and invalidates PDFs so the paid version is regenerated. Collection and publication use consistent lock order and stale leases cannot publish an obsolete unpaid invoice after collection.
- Reports predating this phase are not silently invoiced. An admin-only confirmed preparation action creates their document links/jobs using the same rules. Admin must check for separately issued historical invoices before confirming, especially legacy invoices without a billing-period key. Repeating preparation does not duplicate an invoice/job.
- Native admin archive/client detail: report/invoice downloads, collection, WhatsApp and Email actions. Message includes both signed PDF links and client contact information; sending requires the external app/user confirmation, not WhatsApp Business API or SMTP automation.
- Download links expire in one hour; explicitly shared links in 24 hours. Anyone receiving a forwarded signed link can read it until expiry, even after portal access is subsequently disabled. UI warns before sharing; PDFs are NOT public bucket objects.
- Selective client portal flag on client details plus admin-provisioned email/password account. Password min 12 characters; no public auto-provisioning, existing-account takeover/reset, credential persistence or service keys in Flutter. Server checks the caller's live admin role/tenant, creates Auth account, and attaches a fixed-role client profile under a per-client lock. Failed attachment attempts compensating deletion of the newly created Auth user.
- Existing enabled client accounts preserved during migration. New clients default disabled. Disabling client portal also disables profile flags and server RLS blocks new data/file authorization, independent of JWT metadata.
- Client entry in native drawer; sees only own sites, upcoming schedule, submitted report archive and issued invoices/payment state under RLS. Realtime invalidations, reconnect/resume refresh, minute fallback and explicit refresh.

## Deployment
Existing Supabase project xflvmcdkxfloiovrrpwa:
- 20261121132609 phase8_billing_documents_portal
- 20261121133021 phase8b_document_integrity
- 20261121133244 phase8c_legacy_documents
- app-documents Edge function: ACTIVE, version 1. Gateway verify_jwt=false is intentional; every POST authenticates the bearer token with Auth getUser, then caller-scoped SQL authorization. Administrative service credentials come only from built-in Edge environment, never app/chat/repository.
- Read-only checks confirmed brand/RPC installation, four private document/branding/font buckets, anonymous job claim denied, member publication/provisioning denied and service publication allowed.
- No live sample customer, account, contract, visit, invoice, collection or document was created for testing. No production passwords changed.

## Verification and SDK audit
- **322 local PostgreSQL assertions** (258 existing + 64 billing/documents/portal), including cycle uniqueness, monthly/quarterly/annual, exact cents, one-off payment rejection/rollback, active second-client isolation, disabled portal denial, service-only publication/provisioning, stale leases, collection idempotency and confirmed legacy preparation.
- **8 PDF worker assertions** exercise actual deployed renderer source with real fonts: syntax, PDF parsing/pagination, images/signature, brand/paid variants, method and unauthenticated rejection. These tests and SQL tests now also run in Android CI.
- Flutter tests added for phone normalization, PostgREST job shapes, reference confirmation and password validation, in addition to all existing tests. Final CI/APK recorded at handoff.
- Full tracked runtime/build source audit across repository found no removed backend SDK/config/dependency/call. Historical Markdown and old SQL comments still describe earlier phases; one existing website CSS comment mentions the former backend but contains no executable integration. Website files were NOT modified. The expanded guard runs before and after build, including resolved Flutter dependencies.
- Not verified on a physical device: live authenticated complete report -> server Storage PDFs -> client account -> external WhatsApp/email; actual account provisioning UI against Auth; iOS build. Local rendering/SQL mocks and deployed metadata are not a substitute for this acceptance test.
- Debug APK signing can differ across CI runs. If Android requires removing an old build, **send all offline drafts first**: uninstalling/clearing app data destroys local-only evidence. No release signing or app-store publication is claimed.

## Arabic acceptance checklist
1. من الإدارة اختر «هوية الشركة للمستندات» وراجع الاسم والشعار والهاتف والعنوان/الرقم الضريبي إن لزم. احفظ البيانات؛ تغييرات الهوية تُستخدم عند توليد ملفات جديدة، لا تعيد كتابة الملفات المنشورة فوراً.
2. افتح تفاصيل عميل مهم، فعّل البوابة وأنشئ حساب Email وكلمة مرور قوية. سلّم بياناته بقناة آمنة منفصلة عن رسائل المستندات.
3. أنهِ تقرير زيارة مرة واحدة مع دفع معتمد مسبقاً: تحقق من زيارة مكتملة، فاتورة paid، وتقرير/فاتورة PDF جاهزين بعد التجهيز.
4. أنهِ زيارتين لنفس دورة تعاقد: يجب أن ترتبطا بفاتورة واحدة unpaid بنفس المبلغ، دون تكرار المديونية. جرّب دورة جديدة، وعقداً ربع سنوي/سنوي. إجمالي تخصيصات العقد الأصلي لا يتجاوز قيمته.
5. سجّل دخول العميل على جهاز ثانٍ؛ راجع فروعه وزياراته وتقاريره وفواتيره فقط. اختبر تعطيل البوابة وتأكد من منع الوصول الجديد، مع مراعاة صلاحية روابط المشاركة الصادرة سابقاً.
6. افتح PDF العربي، خصوصاً الأرقام والنصوص الطويلة والصور والتوقيع. سجل التحصيل بمرجع ثم تحقق من paid وتجهيز نسخة الفاتورة المحدّثة.
7. جرّب WhatsApp وEmail: راجع المستلم، الرسالة والرابطين ثم أكّد الإرسال بنفسك. اختبر فتح الروابط قبل انتهاء 24 ساعة.
8. جرّب انقطاع الاتصال بعد إرسال التقرير وإغلاق التطبيق؛ المستندات الخام يجب أن تبقى، وملفات PDF إمّا جاهزة أو قابلة لإعادة التجهيز من الأرشيف. لا تعِد إنشاء فاتورة يدوياً بسبب فشل PDF.
9. للتقارير السابقة، استخدم التهيئة المؤكدة بعد مراجعة الفواتير القديمة؛ عدم وجود اعتماد دفع صحيح يمنع تحويل تقرير مرة واحدة إلى paid.

Stop for user testing; no merge without request.

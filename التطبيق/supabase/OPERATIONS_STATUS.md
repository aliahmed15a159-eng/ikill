# Operations dashboard — user phase five

Scope: native Flutter app plus supporting Supabase only. No website files changed.

## Delivered
- Admin opens on Operations and calendar, without changing existing tab indexes.
- Tenant-local today statistics: scheduled/confirmed, in progress, completed; pending surveys and pending-schedule one-off visits; active in-term contracts; issued unpaid/partial invoices.
- Monday-first 42-day calendar, status colors and explicit labels, customer/site/technician filters; contract and one-off visits. Calendar uses tenant timezone and pages all results in batches of 250. Unscheduled visits remain in existing scheduling queue, not a fictitious calendar date.
- Individual assignment; confirmed site bulk assignment also saves default for future inserts. Replaces existing assignments only for future scheduled/confirmed or unscheduled pending visits, never past/started/completed visits. Clearing default also clears eligible assignments. No automatic conflict detection, payment changes or rescheduling.
- Technician menu/login and own open-task list, with confirmed start/finish RPC transitions. Start disallowed before scheduled time. Task list currently limited to 500 open tasks ordered by scheduled start; admin calendar is paginated without that cap.
- Tenant-filtered Realtime invalidations with debouncing, subscription cleanup, reconnect refresh, resume refresh and one-minute fallback refresh. Connection status shown on admin screen.

## Verification
- Local PostgreSQL tests: 218 assertions across schema/RLS, existing features and operations (36 new operations assertions). No live sample customers/contracts/visits inserted.
- Supabase migration `phase6_operations_dashboard_realtime` deployed successfully to existing project xflvmcdkxfloiovrrpwa. Read-only checks confirmed RPCs installed, anonymous execution denied, authenticated execution enabled and seven required tables published. RPCs perform their own active tenant/role authorization.
- Flutter CI run 44902936056: strict analyze, full test suite, Android debug APK build and dependency checks all passed (code 97e5f1e).
- APK ZIP: https://github.com/aliahmed15a159-eng/ikill/actions/runs/44902936056/artifacts/14707260378 — extract and install app-debug.apk. ZIP SHA256: fb908554034f47b605c50e3560dc4a4446cb8bfa3b95c1d4675d547fff021a57.
- Physical Android/iOS and two-device authenticated Realtime delivery have not been tested here.

## Arabic acceptance checklist
1. افتح الإدارة: تأكد من الإحصائيات وتوقيت الشركة، ثم انتقل بين الشهور واختر يوماً.
2. جرّب فلاتر العميل والموقع والفني؛ الإحصائيات لا تتأثر بالفلاتر.
3. عيّن فنياً لزيارة مستقبلية وتأكد من بقائها بنفس الموعد وحالة الدفع.
4. اختر موقعاً واضغط التعيين الجماعي واقرأ التأكيد: سيستبدل الفني الحالي للزيارات المؤهلة ويحفظ افتراضياً للزيارات الجديدة.
5. على جهاز ثانٍ افتح مهام الفني بحساب فني نشط؛ ابدأ زيارة حان موعدها ثم أنهها. راقب تغير الحالة والإحصائيات لدى الأدمن دون تحديث يدوي.
6. افصل الشبكة وأعدها، ثم جرّب العودة من خلفية التطبيق والتحديث اليدوي.
7. راجع الشاشات السابقة للعملاء والتعاقدات والجدولة وQR للتأكد من عدم تأثرها.

Stop after handoff for user testing; do not merge without request.

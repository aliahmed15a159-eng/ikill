# Product phase eight — notifications and manual payment review

## Scope

App-only Flutter changes in `التطبيق` plus supporting Supabase. No website edits, no merge. Supabase remains the sole application backend and identity/authorization source. OneSignal 5.4.0 is an optional mobile transport, not a new database/authentication backend. Its Android native transport uses FCM; no corresponding application backend SDK is added.

## Implemented

- Own-recipient, tenant/role/active-account-aware notifications, unread indexes, realtime bell in admin/technician/client shells, read/unread list, mark-all-read, paginated list, foreground/reconnect refresh and unread-count polling fallback.
- Server-generated events: new one-off order/survey, submitted payment proof, payment verified/rejected, technician assignment/reschedule, client schedule/start/completion, admin visit start/completion.
- Exact reference navigation reloads the referenced visit/survey/invoice/report under current RLS. Visits link to exact reports, reports to invoices, invoices/reports to private PDFs. Technician deep links filter the existing field workflow to the exact visit. Pending admin order/survey references open the exact existing scheduling workflow.
- Private `payment-proofs` bucket: authenticated scoped PNG/JPEG uploads, maximum 5MB, no public URLs, signed-in recipient/admin downloads. `payment_proof_url` stores an object path, not a permanent public URL.
- Client payment page (receipt icon in notification center) and invoice payment buttons; published InstaPay QR only. Existing anonymous request creation remains available without requiring authenticated uploads. Anonymous customers need a provisioned/enabled portal account before uploading proof in this flow.
- Admin proof preview, explicit confirmation of actual funds received or rejection, immediate transactional client notification. Invoice `payment_status` remains generated `unpaid/partial/paid`; separate `payment_confirmation_status` tracks proof review. Only the verified remaining balance is collected. One pending confirmation per invoice, row locks, idempotent submission, rejected proof can be resubmitted. No automatic bank verification or payment gateway.
- Durable push delivery outbox, private per-delivery token, service-only claim/finish RPCs, retryable lease, stable provider idempotency key, disabled-account checks before sending. Actual push contains only white-label company name, generic text and opaque notification ID — never invoice/report/customer/payment details on lock screen.
- Device subscription registration on session restore/login and SDK changes; account switching binding, local opt-out and unregister at logout. Device permission requested from the notification center button. A per-installation random secret prevents another installation from replacing a known binding. Only the latest subscription on a profile is targeted.
- Admin setup screen accepts the **public App ID only**, with an explicit warning that the transport toggle is not proof of delivery. Retry button requeues up to 100 unsent notifications from the last 24 hours. No automatic retry scheduler is installed.

## Live deployment

Project: `xflvmcdkxfloiovrrpwa`.

- `phase9_notifications_payments.sql`: applied as `20261121141433`.
- `phase9a_enable_notification_webhook.sql`: applied as `20261121141446`; `pg_net` 0.20.4 installed and insert webhook enabled.
- `phase9b_protect_webhook_queue.sql`: recorded as `20261121141648`, but follow-up privilege inspection showed its REVOKEs did **not** remove platform-owned PUBLIC grants on managed `net` tables. Do not treat this as an enforced SQL-level boundary on this host. The live REST API exposes only `public, graphql_public`: an anonymous publishable-key probe requesting `Accept-Profile: net` returned HTTP 406 `PGRST106` / `Invalid schema: net`. Thus app/API users cannot fetch the queue through PostgREST; direct SQL/database administrators remain trusted. Never expose `net` or add user-callable RPCs that return its queue. The private outbox and service-only claim/finish RPC ACLs were independently verified denied to authenticated users. Local tests verify REVOKEs when the migration role owns the tables, which is different from this managed-extension ownership.
- `push-notification` Edge Function: ACTIVE v1, ID `a5b50cee-dcf2-4682-a1d3-3f18bc9cd081`, `verify_jwt=false` deliberately; token-validated service-only delivery claim provides authentication.
- A real `pg_net` probe with empty JSON reached the deployed handler and returned HTTP 400 `INVALID_REQUEST`, without timeout. This verifies connectivity and invalid-input rejection, **not a real mobile push**. No sample users/orders/payments were created or marked paid.
- `notifications` and `payment_confirmations` in realtime publication. Existing paid invoices only receive the derived confirmation-state backfill.
- **OneSignal is NOT configured/enabled on the live tenant**. No OneSignal app/REST key or Android/iOS provider credentials have been supplied. No fake secrets were created and no external push success is claimed.

## One-time external setup (account owner)

1. Create an app in OneSignal for package/bundle `net.ikill.app`. Configure Android push credentials in OneSignal's Android platform settings. Native mobile transport only; no application Auth/Firestore migration.
2. In **Supabase → Edge Functions → Secrets**, set `ONESIGNAL_APP_ID` and `ONESIGNAL_REST_API_KEY` using the real OneSignal App ID and app API key. Never put the private key in chat, Dart, SQL, GitHub source or the app settings screen.
3. In the app, sign in as admin → bell → settings → enter the same public App ID → enable transport → save. Restart the app if changing App ID. Sign in on a physical phone → bell → device-notification button → grant permission.
4. Trigger a real authorized event and test receiving/tapping notifications with the app foregrounded, backgrounded and terminated. Confirm exact-reference navigation and no cross-account access after logout/login. Provider acceptance is not proof the OS displayed a notification.
5. iOS additionally needs Apple Developer provisioning with Push Notifications capability and APNs credentials configured in OneSignal. Background remote notifications and debug/production APS entitlement settings are prepared; no iOS signing, archive or physical-iOS delivery test has been performed. Rich-media service extension is not included (generic text notifications only).

## Verification and limitations

- Local PostgreSQL suite: existing 322 assertions plus **59 notification/payment/security checks**; PDF worker 8 assertions; mocked push-handler checks for validation, authentication, no-configuration, privacy payload, success and failure.
- New Flutter tests cover the reference-kind allowlist and paid/pending invoice upload restrictions. Full Flutter analyze/tests/APK: **SUCCESS** on commit `401a47df943f05653d58f155c72ad6cc80d78dfd`, run [44913228392](https://github.com/aliahmed15a159-eng/ikill/actions/runs/44913228392).
- No physical device or real provider delivery test yet. No test accounts or financial records changed on the live project.
- Server-side pending/retry status is not delivery-to-device confirmation. Failed dispatch can be retried by admin; there is no cron retry job. Offline auth/session validity and RLS still govern deep linking.
- PDFs may still be generating when a completion notification arrives; the in-app copy explicitly says so. Historical events are not backfilled.
- Before reinstall/uninstall, submit any offline field-report drafts; clearing app data deletes local drafts and installation credentials.

## Android test artifact

- [Download phase-eight APK artifact ZIP](https://github.com/aliahmed15a159-eng/ikill/actions/runs/44913228392/artifacts/14710807740)
- Artifact: `ikill-android-supabase-debug`, 90,615,542 bytes.
- Artifact ZIP SHA256 (GitHub metadata): `b57842be39977b49e3bc8205efcbdd55bba881d90d452d94098244032e87f0d9`.
- Extract ZIP and install `app-debug.apk`. GitHub sign-in may be required and the artifact is subject to GitHub retention.
- Sandbox download/log archive retrieval was blocked by outbound-host restrictions to GitHub artifact storage; no local APK checksum/device install is claimed. CI job/step success and artifact metadata were verified through the GitHub API.
- Stop here for user testing; no merge performed.

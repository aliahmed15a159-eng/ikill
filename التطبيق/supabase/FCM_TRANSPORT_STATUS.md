# FCM-only external push transport

## Backend boundary (strict)

Supabase remains the only PostgreSQL, Auth, Storage and in-app notification/Realtime backend. The only direct Flutter Firebase dependencies are **firebase_core 3.12.1** and **firebase_messaging 15.2.4**. No Firebase Auth, Firestore, Firebase Storage, realtime database or analytics SDK/API was added. Native Messaging brings required installation/encoding/data-transport/interoperability components; these are narrowly allowlisted by the resolved-Android dependency audit, not extra application backends.

The previous external provider SDK, runtime API requests, app settings and live database registration/settings functions have been removed. Historical applied SQL migrations and their historical regression tests remain for reproducibility; `phase10_fcm_transport.sql` removes the old column/settings and invalidates incompatible old device IDs. Historical documentation is marked superseded.

## Android configuration

The user-supplied `google-services.json` is installed at `android/app/google-services.json` and was verified to match package **net.ikill.app**, project **ikill-4e337**. Google Services Gradle plugin 4.4.2 is applied when that file exists. The file contains client configuration/public API identification only, **not** a service-account private key. Its standard storage-bucket metadata is unused; no Firebase object-storage SDK or storage operation exists.

Android 13+ notification permission is declared and requested through Messaging at sign-in/session restore. Auto-initialization is disabled in native configuration until an authorized Supabase account grants notification permission. Missing/invalid native config is caught without preventing Supabase login or other app features.

## Device lifecycle and reference navigation

- On login/restore: validate the active Supabase profile through its existing RLS-backed RPC, check configured project matches the native project, request notification permission, obtain FCM token and register via `register_my_fcm` into **profiles.fcm_token**. Registration does not require the admin sending toggle to be on.
- `onTokenRefresh` registers the refreshed token. Installation-secret binding prevents another installation from replacing a known token. Current schema intentionally targets the latest device token per profile, not a multi-device token array.
- Sign-out unregisters the last successfully registered token **before** losing the Supabase session, disables FCM auto-init and attempts token deletion. Supabase logout still works when offline; remote token removal cannot be guaranteed without connectivity. Native token deletion is best-effort offline. All push content is generic and every reference is reauthorized in Supabase.
- Foreground: `FirebaseMessaging.onMessage` shows an in-app snackbar with an Open action; existing Supabase Realtime bell/count remain independent. No third notification/local-notification SDK was added.
- Background: top-level `@pragma('vm:entry-point')` handler initializes Core only, without UI/Auth/DB work. Android/iOS display the notification payload. `onMessageOpenedApp` handles taps.
- Terminated: `getInitialMessage` queues the notification ID and routes when the navigator and an authenticated account are ready. Force-stop/OS permission restrictions still apply.
- Payload carries `notification_id`, `type`, `reference_id`, `reference_kind`. Navigation **never trusts payload routing/role claims**: it reloads the exact canonical notification under current recipient RLS, then opens its canonical reference kind/ID. Wrong-account, disabled or deleted references fail closed.

## Visible readiness indicators

The notification center distinguishes native configuration missing/invalid, permission denied, waiting for iOS APNs, token registration failure, registered device with server sending disabled, and device ready. It does not equate registration with delivered push.

Admin bell → settings separately checks the protected Edge `status` action: server JSON/private-key format and project match, webhook enabled, and admin sending toggle. A valid key format does **not** prove OAuth permissions or physical-device receipt. Server secrets are never shown or edited in the app. Admin may retry up to 100 unsent notifications from the last 24h; no automatic retry cron is installed.

## Supabase migration and sender

- `phase10_fcm_transport.sql`: live migration applied. Renames `profiles.push_subscription_id` to `fcm_token`, clears incompatible old IDs, renames private device-binding token column, drops previous-provider App ID/settings/RPCs, installs FCM registration and cleanup RPCs, preserves notification/payment tables and RLS. Sets external sending **off** until server credentials are configured.
- `phase10a_fcm_webhook_timeout.sql`: live migration applied; raises database webhook timeout to 60s for OAuth/signing and one 401 token refresh.
- Existing `push-notification` Edge Function updated to **FCM HTTP v1**, ACTIVE v2. Same notifications-insert database webhook/outbox, per-delivery random token and service-only claim/finish. No legacy FCM API/server-key endpoint.
- Reads **FIREBASE_SERVICE_ACCOUNT** only from Supabase Edge Secrets. Validates service-account type, expected project, key and pinned Google OAuth URL. Signs RS256 JWT with messaging-only scope, exchanges it at Google's OAuth endpoint, caches the short-lived access token and refreshes once after 401.
- Sends to `https://fcm.googleapis.com/v1/projects/{project_id}/messages:send`. Uses brand_config company name and generic notification text, never private customer/payment/report details. Canonical type/reference IDs accompany the opaque notification ID in data.
- Handles `UNREGISTERED` by clearing only the still-matching recipient token, never a newly refreshed token. Disabled-account checks remain at delivery time.
- FCM has **no provider idempotency-key API**. Outbox leasing/sent-state suppress routine duplicates; an ambiguous network/provider timeout can still result in duplicate delivery on retry. Android notification tags and APNs collapse IDs reduce duplicate presentation but are not exactly-once guarantees.
- The managed `net` schema remains outside PostgREST exposure (`public, graphql_public` only); see the previous phase's documented managed-extension ACL limitation. Never expose `net` or queue-returning RPCs.

## External setup still required — do not send private keys in chat

Supabase secret metadata was checked: **FIREBASE_SERVICE_ACCOUNT is not present**. No fake/placeholder secret was created. Client configuration alone is insufficient for server sending.

1. In the existing Firebase/Google Cloud project **ikill-4e337**, enable the Firebase Cloud Messaging HTTP v1 API and use a service account authorized for sending messages (least privilege: Firebase Cloud Messaging API Admin role on this project, not a broad Owner/Editor grant).
2. In a trusted browser, obtain its service-account JSON and paste the **whole JSON directly** into **Supabase → project xflvmcdkxfloiovrrpwa → Edge Functions → Secrets**, name **FIREBASE_SERVICE_ACCOUNT**. Never commit/upload it to the app or send it in the conversation. Remove any local downloaded private-key file safely after storing it according to your credential policy.
3. App admin → bell → settings → refresh. Confirm server credentials status is valid, then enable external sending and save. Sign in on a physical device, grant permission, and confirm device-token registration. Trigger a real authorized event and test all three app states and exact-reference navigation.
4. iOS additionally needs its real **GoogleService-Info.plist** for the matching iOS app, added to the Runner target/resources, Apple provisioning with Push Notifications capability, and APNs key/certificate uploaded to the Firebase project's Cloud Messaging settings. The iOS file/APNs credentials were **not supplied**; no iOS push readiness is claimed. Existing APS entitlements/background capability are prepared. No iOS archive/signing/device test was performed.

## Verification

- Local SQL regression suite: previous 381 assertions plus **36 FCM migration/token/role/refresh/logout checks**.
- Sender tests: **81 assertions**, including real ephemeral RSA JWT signing/verification, messaging-only scope, pinned OAuth audience/URL, access-token caching and 401 refresh, HTTP-v1 payload, status authentication, project mismatch, no-configuration, UNREGISTERED cleanup and failure handling. All external services are mocked; no real push is sent by tests.
- Flutter tests added for push readiness and canonical-ID validation, alongside existing notification/payment tests. Final analyze/tests/APK result: pending final CI.
- No real service-account OAuth exchange or Android/iOS physical-device push has been tested. No live test accounts, notifications, orders or payments are created by this work.
- No website edits. No merge. Submit offline field-report drafts before reinstall/uninstall/clearing app data.

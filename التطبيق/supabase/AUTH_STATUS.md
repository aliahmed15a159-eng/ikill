# Mobile Supabase authentication — 2026-11-21

Scope: Flutter app and supporting Supabase only. No website files modified; no merge performed.

## Implemented
- Unified account entry from drawer and existing admin / technician / client entries.
- Supabase email/password signup/login; external-browser Google OAuth via PKCE, no Google secret or Firebase Auth in app.
- Password recovery email, exact mobile callback allowlist, cold/warm callback handling and new-password screen; persisted recovery guard and sign-out after update.
- Company name, colour and published logo from `brand_config`, with packaged iKILL logo fallback; animated form resizing, Google mark, password visibility, email validation, strength and confirmation.
- Arabic/English friendly auth errors without echoing raw provider/database errors.
- New accounts are `customer`, never admin, technician or contracted client. Auth metadata cannot select role, tenant, client mapping, portal flag or completion status.
- Required mobile/WhatsApp completion for new customers; Google names prefilled, number is collected once and completion is server-persisted. This is contact collection, **not WhatsApp ownership verification**.
- Limited customer landing page: one-off service and site survey requests; no contracts/invoices portal grant. Existing manual InstaPay flow unchanged.
- Existing staff and contracted clients preserved. Disabled contracted portals show a clear denial.
- Service-only customer-to-client promotion preserves admin account provisioning compatibility.

## Live deployment evidence
- `phase11_customer_auth`: migration `20261121151128`, applied successfully.
- Verified default role `customer`, auth.users insert trigger present, existing role counts still admin=1.
- Verified anonymous completion denied; authenticated execution of private request implementation and portal-account attachment denied.
- Allowed redirects appended to previously empty redirect allowlist:
  - `net.ikill.app://auth/callback`
  - `net.ikill.app://auth/recovery`
- Site URL and existing provider credentials left unchanged. Confirm Email remains disabled as previously configured by owner.

## Owner configuration blockers
- Live configuration reports Google provider **disabled**, despite stored provider credentials. Enable **Authentication → Sign In / Providers → Google → Enable Google provider** in Supabase and save. The connected tool cannot change provider enablement. Never copy Google Client Secret into the app or chat.
- No custom SMTP configured. Configure production SMTP securely in Supabase; default email delivery/rate restrictions may prevent recovery emails reaching arbitrary users. No delivery test has been claimed.
- Mobile PKCE confirmation/recovery links must be opened in the app on the device that initiated the operation.
- Custom-scheme callbacks require installed app. Android/iOS universal links are not configured.
- iOS callback registration added but iOS signing/build/device testing remains outstanding.

## Test evidence and acceptance checklist
- Complete local backend suite passed, including 47 new customer provisioning, metadata privilege escalation, onboarding, phone normalization, RLS isolation and provisioning-compatibility assertions.
- New Flutter tests cover callback allowlist, email/password/phone normalization, role/access semantics, sign-in validation and neutral forgot-password UI. See final CI result before installing.
- No real Google consent, email delivery, password recovery or physical-device acceptance test performed by agent.

After enabling Google and preparing email delivery, test on Android:
1. Email signup → customer account → one-off service / survey; no portal access.
2. Sign out → email login; wrong password displays polite Arabic error.
3. Google first login → WhatsApp completion; later Google login skips completion.
4. Cancel Google consent and retry; app remains usable.
5. Forgot password → email → installed app (warm and cold) → update password → sign in with new password; old password rejected.
6. Expired/reused links fail safely; request a new link.
7. Existing admin and technician logins still route correctly; disabled client gets explicit denial and enabled client keeps portal access.
8. Logout/relaunch does not retain another user's screen or recovery state.
9. Check branding, RTL, small display and keyboard layout on device.

Do not merge until owner acceptance testing is complete.

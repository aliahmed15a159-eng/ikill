# Narrow website admin authentication exception — user bug report

The user reported successful website admin login followed by a redirect after about five seconds and a generic invalid-credentials message. This is a specific exception to the standing app-only scope: only website administrator authentication/session handling was changed; no public pages, design, payment, or content features were changed.

Read-only Supabase checks: the expected administrator is active, email-confirmed, not banned, and belongs to an active tenant. No password, Auth configuration, or authorization rules were modified. No real-password sign-in was attempted.

Identified and regression-tested failure modes:
- A temporary profile RPC failure was treated as signed-out by the session listener, redirecting the dashboard to login.
- A temporary profile verification error after successful authentication destroyed the local session.
- Login UI mapped most failures (including connection/service errors) to a generic credential-failure message.
- Overlapping session checks could apply stale signed-out results after a new auth event.

Changes: preserve stored session on transient failures, gate dashboard access while verification retries, distinguish denied authorization/invalid credentials/rate limiting/service failures, discard stale session checks, avoid duplicate dashboard data-listener initialization, and make deliberate website sign-out local to avoid revoking app sessions.

Validation: `node التطبيق/tool/web_backend.test.cjs` (35 checks), `node التطبيق/tool/web_auth_session.test.cjs` (8 regression scenarios), `git diff --check` pass. Tests mock the SDK; they do not prove the cause of the user's live incident or validate their password/browser/network.

Deployment: patch is on the current work branch only. No main merge or website hosting deployment was performed. Need the actual login URL and deployment of this patch to verify the live behavior. Never request passwords, access tokens or OTPs. After resolving this specific incident, future feature changes remain app-only.

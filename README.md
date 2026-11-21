# iKILL website and native Flutter app

- Public website: static HTML/CSS/JavaScript in the repository root.
- Native Android/iOS app: `التطبيق/` (Flutter/Dart, not a WebView).
- Backend: Supabase Auth, PostgreSQL and private Storage.

## Website local preview

Serve this directory with any static server; do not open authenticated pages via file://.

```sh
python3 -m http.server 3000 --bind 0.0.0.0
```

`supabase-config.js` contains PUBLIC browser connection settings. Override
`window.IKILL_SUPABASE_ENV` before loading it for another deployment. Never use a
service key. `supabase-backend.js` exposes a view-model bridge for the existing
pages using the official, locally vendored Supabase JS SDK (2.49.4). Its license
is in `vendor/supabase/LICENSE`. Public pages load it after interaction/idle;
admin pages load it before their existing controllers.

## Current data mapping

- Contact requests → clients (lead), through a validated RPC only.
- Company branches → company_branches; these are NOT private client_sites.
- Site settings → tenants.branding, with a narrow public projection.
- Existing website page analytics → page_events.
- Company/profile/business records → the phase-1 tenant-scoped schema.

No historical users or data are automatically imported. There is no public
sign-up-to-admin path. Create a Supabase Auth account and deliberately provision
an admin profile using `التطبيق/supabase/BOOTSTRAP.md`.

## Native app

See `التطبيق/README.md` for environment configuration, test/build commands and
private Storage rules. SQL migrations and deployment records are in
`التطبيق/supabase/`.

## Hosting / security

This phase removes the old hosting-specific configuration; it does not publish
or move the production domain. Deploy the static website with your chosen host.
Do NOT publish `التطبيق/`, `.git/`, test folders, local environment JSON, build
artifacts, or deployment tooling in the public website. Configure CSP to allow
only the actual Supabase HTTPS/WSS endpoint used by this deployment, plus the
site's existing fonts/icons/maps providers. Auth and sensitive tables remain
protected by RLS; a browser key is intentionally public.

Full schema creation must not be rerun on the connected project. Apply future
changes as separate migrations and check `التطبيق/supabase/PHASE2_STATUS.md`.

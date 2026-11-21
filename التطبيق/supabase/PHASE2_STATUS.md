# Phase 2 — Supabase-only integration

Date: 2026-11-21 UTC. Project: `xflvmcdkxfloiovrrpwa`.

## Scope

Removed the former backend runtime SDK/dependencies/configuration from Flutter
AND the static website. Existing backend data was not deleted or imported.
No new UI features were added. Old generator scripts that reintroduced removed
SDK initialization were deleted. Historical phase-1 reports remain as audit
records, not active setup instructions.

Official clients: supabase_flutter 2.8.4 and locally vendored supabase-js 2.49.4.
Central Flutter client reads SUPABASE_URL/SUPABASE_ANON_KEY at build time. Only a
publishable/anon client key is used; no service key is stored in app/repository.

## Live database changes

Migration: `phase2_supabase_integration_storage` (applied via Supabase connector).

- Added requested_service/request_message to clients for the existing form.
- Added tenant-scoped company_branches and page_events for existing website/app
  screens; company offices are deliberately separate from private client_sites.
- Existing settings use tenants.branding with a narrow public RPC projection.
- get_my_profile returns only the caller's own status, including a disabled
  portal flag; RLS remains restrictive on all business data.
- Public contact form uses a validated RPC with per-company/email daily quota;
  no anonymous access to clients tables. Edge anti-abuse remains a production task.
- Default iKILL tenant was created. No admin/profile/Auth identity was created.
- visit-images, visit-signatures, invoice-pdfs created PRIVATE with MIME/size
  restrictions and four RLS policies on storage.objects.
- Private file service uses random object names and 60-second signed URLs.

Live verification confirmed public brand projection, buckets private, policy
count=4, and profile_count=0. User identity must be provisioned deliberately using
BOOTSTRAP.md before a real admin can sign in. Existing Auth identities from the
former provider do not authenticate automatically with Supabase.

## Checks

- Local PostgreSQL/PGlite: 57 phase-1 + 25 phase-2 assertions passed.
- Website: 35 syntax/asset/view-model assertions passed with mocked SDK.
- Flutter role/portal/public-key unit tests added.
- Flutter analyze/test/Android build: CI result will be recorded after completion.
- No live mobile Auth, real user binary uploads, or iOS build tested yet.

The existing screens have no upload/report editing UI. Storage methods/policies
are implemented without adding such a feature. No claim of an actual file
upload from a phone is made.

## Hosting and cutover

Production domain hosting was NOT changed or deployed. The obsolete
hosting-specific config was removed from source per request. Review the PR and
hosting publish directory/CSP before deploying the website; never expose the
Flutter source, local environment files, .git or test tooling as static assets.
The former backend project's cloud data/resources and unrelated provider keys
were not deleted. Its unused repository secret may still exist; the build no
longer references it. Removal of remote provider resources is a separate,
explicitly approved destructive operation.

## Stop gate

After clean Android build, stop for user verification. Do not add workflows,
features, data imports or privileged identities without further approval.

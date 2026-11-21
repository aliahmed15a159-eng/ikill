# Phase 1 — Supabase deployment record

Date: 2026-11-21 (UTC).

## Applied with explicit user authorization

- Project ref: `xflvmcdkxfloiovrrpwa`.
- Project status observed before deployment: `ACTIVE_HEALTHY`.
- Preflight: no application tables existed in `public` or `app_private`.
- Migration: `phase1_multitenant_schema_rls`.
- Recorded Supabase migration version: `20261121101041`.
- Applied through the Supabase connector's transactional `create_migration` tool.
- SQL matches the reviewed phase-1 design; comments/whitespace and the manual
  BEGIN/COMMIT wrapper were omitted because the migration tool manages execution.

## Post-deployment verification (live read-only metadata queries)

- All 11 application tables exist: tenants, profiles, services_catalog,
  pricing_matrix, clients, client_sites, surveys, contracts, visits,
  visit_reports, invoices.
- RLS is enabled AND forced on every table.
- 24 RLS policies and 29 foreign keys observed across these tables.
- anon has neither SELECT nor INSERT table privileges on any of them.
- Nine app_private functions exist, each with a fixed empty search_path.
- anon cannot execute any of these functions.
- authenticated can execute only the six RLS predicates, not the three trigger functions.
- Migration history confirms the applied name/version above.
- tenants and profiles are both empty; no company, user, or admin identity was invented.

## Not performed

- No Firebase changes, screen changes, connection switch, or data import.
- No Supabase Auth users or privileged profiles provisioned.
- No secrets/keys retrieved, created, rotated, or placed in Flutter.
- No Storage buckets or object policies created.
- No live end-user JWT/RLS tests, client submissions, or mobile integration tests.
  The 57 local PGlite checks in PHASE1_PLAN.md are separate from these live
  metadata checks and are not a claim of end-to-end Supabase authentication testing.

## Next gate

Provision the first company/admin using BOOTSTRAP.md after confirming the intended
Supabase Auth identity. Then obtain explicit approval for phase 2 before wiring
Supabase into the app. Existing APK/site still use Firebase.

PHASE1_PLAN.md and the header in phase1_schema.sql document the earlier proposal
state; this record supersedes their statement that the schema has not yet been
applied. Do not re-run the initial schema against this project: its objects now exist.

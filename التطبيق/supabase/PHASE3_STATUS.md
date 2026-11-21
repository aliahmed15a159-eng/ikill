# Phase 3 — app requests and administrator queues

Scope: native Flutter app, its administration, and supporting Supabase migration only. No website files changed.

## Deployed database

Project `xflvmcdkxfloiovrrpwa`: migration `20261121104719` / `phase3_app_requests_pricing` applied successfully on 2026-11-21. Source: `phase3_requests.sql` (do not rerun). Read-only live checks confirmed forced RLS on receipts, anonymous submission permitted, and anonymous payment review denied.

No production prices or customer requests were inserted for testing. Live checks found **0 configured prices and 0 active administrators**. Provision your own Auth administrator using BOOTSTRAP.md before administration testing; also provision an active technician before scheduling. Do not share account passwords or OTPs in chat.

## Workflows

- Administrator dropdown: Residential prices / Pending scheduling / Business survey requests.
- Configure all 12 apartment/villa/house × cockroaches/rodents/bed bugs/general pest prices. Each combination can be disabled. Positive monetary amounts with at most two decimal places; company currency.
- Residential: contact + property/problem/address → current server quote → payment confirmation/reference → transactional client (`one_time`) + site + visit (`pending_schedule`). Amount is rechecked and snapshotted server-side. Client confirmation is **pending_review**, never automatically paid. Independently check funds before approval. Rejection requires follow-up with customer. Scheduling is blocked until verified.
- Business: facility/sector/address → transactional contract-type client and survey, both `survey_pending`. No fixed quote, payment request, invoice, or signed contract is created. Administrator views contact/site/details and can assign a technician and survey appointment.
- Visit scheduling chooses technician/date/time in **device local timezone**, stores UTC, and reserves one hour. Business survey scheduling stores the appointment time.
- Same-session network retries use the same UUID and frozen payload; server deduplicates atomically. Starting a new request or restarting the app does not recover the old pending form: first confirm with administration whether it was recorded.

## Payment and security boundaries

No payment gateway is configured; no cards, OTPs, actual charge, refund, payment webhook, or automatic invoice settlement. The confirmation text must refer to an arrangement with administration, not sensitive payment credentials.

Public submission RPC accepts only whitelisted fields, validates tenant/price/consent, and creates all related records in one transaction. No public direct writes to business tables or receipts. Price updates/review/scheduling require active tenant administrator. Existing tenant RLS/staff-role triggers remain. Five new client requests per email per tenant per 24h is a basic quota, not full abuse prevention; production public launch should add upstream CAPTCHA/rate limits and monitoring.

## Test checklist — stop here after build

1. Sign in as provisioned administrator; configure a real apartment/cockroaches price and enable it.
2. Residential: view quote, enter agreed payment confirmation and submit. Confirm one client/site/unscheduled visit; no verified payment.
3. Retry a submission after interrupted connection without altering payload: no duplicate records.
4. Review funds manually; reject or verify. Only verification enables scheduling. Assign active technician and future time.
5. Disable a price: quote unavailable. Change price after quote: submission must fail rather than silently charge another amount.
6. Business: select survey path; enter facility/sector/contact/address; no fixed price or payment step. Confirm survey_pending client/survey in administrator queue, then schedule survey.
7. Confirm non-admin login cannot open administration and cross-tenant data remains inaccessible.

Local automated results: 57 phase1 + 25 phase2 + 40 phase3 PostgreSQL/PGlite assertions passed (mock Auth/Storage). Flutter analysis/tests/APK run through Android CI; see linked build in handoff. Real-device Supabase/Auth/payment operations and iOS builds are not represented by local mocks.

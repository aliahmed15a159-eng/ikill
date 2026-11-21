# Product phase four — multi-site contract lifecycle

Scope: native Flutter application/admin and supporting Supabase only. No website source changes or website deployment in this increment. Existing app stability fixes on this working branch remain included.

## Delivered

- Administrator's first tab is **إدارة العملاء / Client management**: search existing clients and create a contract-type customer with contact name, phone and email. Newly created customers start `survey_pending`.
- Customer detail shows original request notes and allows adding/editing multiple `client_sites`: name, address, latitude/longitude (manual coordinates), sector and site contact telephone. No map SDK or geocoding dependency.
- Each site has survey results, site/service details and proposed price. Saving marks the site's survey completed, recording administrator and time. The incoming survey queue links directly to the customer file and refreshes after returning.
- Contract draft: start/end dates, **total contract value** in company currency, monthly/quarterly/annual billing metadata, and 1–12 visits per month **for each active site**. `billing_amount` stores the total value for these app-managed contracts; no invoices or automatic installments are generated.
- **توقيع وتفعيل العقد** records signing representative name, reference to an externally signed agreement, administrator ID and timestamp after explicit confirmation. This is administrative recording of an external signature, not handwritten/electronic signature capture, document upload, a legal signing service or a payment action.
- Activation atomically changes the contract and customer to active and inserts recurring visits for each site. The contract row lock and unique occurrence index prevent duplicate generation on retries; a retry on an active contract returns its original generated count. Invalid activation rolls back all inserted visits and leaves the draft/customer unchanged.
- Client visit schedule is paginated in 100-row pages. Administrator may move scheduled/confirmed visits to a future time within the active contract's term and optionally assign an active technician. The UI uses one-hour visits and device-local date/time, storing UTC.

## Recurrence rules — explicit test behavior

- Every **calendar month intersecting the inclusive contract dates** receives the configured monthly count per site. This includes partial first/last months. For example Jan 15–Mar 20 with two sites at 1 and 2 visits/month generates **9 visits** (3 × (1+2)).
- Dates are spread evenly over the in-term days of each month, starting with its first covered day, at **10:00 AM in the tenant/company timezone**, one hour long. UTC offsets follow that timezone (default Africa/Cairo). No automatic weekend/holiday adjustment or resource capacity/double-booking optimizer is included; administrator confirms/changes appointments manually.
- A partial month must contain at least as many days as its frequency; otherwise activation fails rather than placing multiple visits on the same day for a site.
- Start must be **tomorrow or later in company timezone**. End is inclusive, must be >= start, and less than start + 36 months. Up to 50 sites, 12 visits/site/month, and 5,000 generated visits per contract (transaction rejects excess).
- All active sites must be in the draft and have a completed, priced survey before activation. Overlapping active contracts for the same customer are rejected. Existing inactive sites are excluded.
- Signed contracts cannot be edited back into drafts or have signed terms silently overwritten. New sites added after activation do not silently rewrite a signed plan or generate retroactive visits: include them in an appropriate future contract. Contract amendments/renewal automation and automatic expiry jobs are not implemented.
- Auto-created visits have `status=scheduled`, no technician initially, `payment_review=not_required`, and retain contract/site/month/occurrence links. Manual rescheduling does not change occurrence identity or regenerate the series.

## Database deployment

Applied migration **20261121115125 / phase5_client_contract_lifecycle** to `xflvmcdkxfloiovrrpwa`. Filename `phase5_client_contract_lifecycle.sql` is numbered five only because the earlier QR increment already used a phase4 migration filename; this is the user's product phase four.

Adds site contact phone, contract activation audit fields, `contract_site_plans` with composite tenant/customer foreign keys and forced RLS, visit occurrence keys, signed-term guard, administrator-only save/activate/reschedule RPCs. Only active company administrators may use the RPCs; anonymous execution is revoked and staff/client calls are denied inside the RPCs. Existing tenant isolation/technician-assignment triggers remain in force.

Live read-only verification confirmed table/forced RLS, anonymous activation denied, and **zero app-managed contracts** after deployment. No real contract was activated, no customer created, no visit schedule generated, and no Auth/price/payment destination data was modified by deployment/testing.

## Verification and manual acceptance

Local SQL/PGlite: **182 assertions** across schema/integration/QR/lifecycle suites, including **36 lifecycle checks** for permissions, cross-tenant scope, multi-site frequencies, partial-month distribution, company-time generation, idempotence, overlap, signed-term immutability, incomplete/missing-site survey rejection, rollback and manual rescheduling bounds. Auth/Storage are mocked locally.

Flutter tests add validators and the native site → survey → draft → sign/activate screen flow against an in-memory repository. Existing price-dialog reverse-transition/small-phone regressions remain. CI strict analysis/tests/debug APK must pass; final handoff below. No real-device authenticated Supabase workflow or iOS build is claimed by mocked tests.

Manual test:
1. Sign into app administration; create a test contract client (or open a survey request's customer).
2. Add two sites with distinct names, address, coordinates, sector and responsible telephone.
3. Record completed survey findings/details and a price for **each** site.
4. Save a Jan 1–Mar 31 future-year draft, one site at 1 and the other at 2 visits/month; select billing cycle and total contract value.
5. Confirm actual external signature, enter representative/reference, activate. Expect active client/contract and **9 visits**; retry must not duplicate.
6. Open visit schedule and move a visit inside the term; verify after refresh. Out-of-term/past edits and non-technician assignment must fail.
7. Try unsigned/incomplete survey/overlapping contracts: no partial activation or orphan generated series.

Customer list currently loads the newest 1,000 records with local search. Large-volume server-side search/pagination for that list is not included; generated-visit browsing is paginated.

Stop after completion for user acceptance; no merge, website deployment or next-stage features authorized/performed.

## Successful Android handoff

CI [44901443088](https://github.com/aliahmed15a159-eng/ikill/actions/runs/44901443088) passed strict Flutter analysis, full Flutter tests, dependency checks and Supabase-configured debug APK for code commit `1fb9120`.

[Download phase-four APK](https://github.com/aliahmed15a159-eng/ikill/actions/runs/44901443088/artifacts/14706138407). Extract ZIP and install `app-debug.apk`. ZIP SHA-256: `69d010cb3bc0de19cfa6950a2dab761402f395e0da7725cfe9de2497ca0c5cc9`.

Implementation paused for user testing. Working branch not merged; no real contract was signed or activated for testing.

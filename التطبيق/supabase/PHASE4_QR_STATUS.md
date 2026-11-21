# Administrator-managed InstaPay QR

Standing scope: **all future product changes are app-only plus necessary Supabase support. Do not change the website.** Administrator activation was performed in the shared database at the user's explicit request; no website files were edited.

## Implemented

Native administrator dropdown → **إعداد QR إنستا باي / InstaPay QR settings**:

1. Upload a QR image from the receiving InstaPay account (PNG/JPEG, max 5 MB).
2. Preview it and enter the beneficiary name customers should verify.
3. Enable and save/publish. Administrator can replace it or disable customer display later.

No receiving account, QR image, or payment destination is seeded. No QR generation from arbitrary bank/account data: administrator supplies the original QR. The app validates image decoding/type/size, **not** the encoded destination. Administrator must scan/check it independently before publishing.

Customer residential price/payment step loads the currently enabled destination and displays its QR and beneficiary. Missing/disabled destination blocks that payment step with an explanatory message. Business survey requests are unchanged. No automatic debit or payment verification.

## Security and deployment

`phase4_instapay_qr.sql` applied using the Supabase connector as `phase4_app_instapay_qr`. Private `instapay-qr` bucket, 5 MB limit, PNG/JPEG only. Only active administrators in the matching tenant can upload/configure. Customers can read only the currently published image; unpublished/replaced paths are not customer-readable. Published images cannot be overwritten (no UPDATE policy) or deleted while published. Replacements use new random paths. Retained old/orphan files are admin-only; automatic garbage collection is not implemented.

Live read-only verification: one active administrator, no published destination, bucket private, anonymous save denied, Storage SELECT permission available subject to object RLS.

The previous account activation is separate from the migration: no Auth users, passwords, or privileged keys are seeded in Git.

## Tests and limitations

Local mocked PostgreSQL: 57 phase1 + 25 phase2 + 40 phase3 + 24 QR assertions pass. QR tests cover permissions, missing QR, unknown/cross-tenant paths, publish/replace/disable visibility, and protection of the published image. Flutter CI covers type/size validation and the missing-destination and displayed-destination payment flows.

**This increment implements QR administration/display only.** The earlier requested sender-phone + transferred-amount + screenshot upload/review flow is not implemented by this increment; the existing text confirmation and manual administrator payment review remain. No live transfer, authenticated real-device gallery upload, iOS build, or end-to-end bank verification has been performed.

Manual acceptance: sign in as administrator, open QR settings, choose original QR, verify beneficiary, enable/save; request a residential price and check QR display. Replace image and repeat; disable it and verify a new payment attempt shows unavailable. Test PNG/JPEG rejection above 5 MB, cancellation and gallery-permission errors. No site changes or merges.

## Verified APK handoff

CI [44897111507](https://github.com/aliahmed15a159-eng/ikill/actions/runs/44897111507) passed strict Flutter analysis, all Flutter tests, dependency checks, and debug APK build for code `284688a`.

[Download QR-settings test APK](https://github.com/aliahmed15a159-eng/ikill/actions/runs/44897111507/artifacts/14704277562), extract ZIP and install `app-debug.apk`. ZIP SHA-256: `f0bd8f51764b837effc3bf14bfe8530ac173f25444c124654062f4e9cad1a6b0`.

Paused for user testing; branch not merged. Real gallery upload/publication should be tested using the user's actual QR, not a fabricated destination.

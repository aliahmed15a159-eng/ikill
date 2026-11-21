# App stability repair — 2026-11-21

Scope: native Flutter application only. No website source, database schema/data, Auth configuration, production price, or payment destination changes. Stage four has not started.

## Report

User supplied a red Flutter screen with `framework.dart:6179`, `_dependents.isEmpty`, while adding an administrator price. That assertion is a widget/inherited-element lifecycle failure; the screenshot alone does not contain the first exception or a complete stack trace and cannot uniquely establish the original trigger.

## Repairs

- Price editor is now a route-owned StatefulWidget: its Form key and TextEditingController remain alive through the route's exit transition and dispose with the route. Previously the caller disposed the text controller immediately after `showDialog` returned, while the dialog could still be animating.
- Price content has an explicit bounded width and is scrollable for small phones/keyboard insets.
- General administrator field editors (branch, settings, password) use the same route-owned lifecycle instead of caller-managed keys/controllers and a fixed 350 ms disposal delay.
- Async editor results check mounted state before saving. Request-admin actions guard against re-entry and disposed State.
- Scheduling has one busy/error owner, not nested actions, and rejects appointments in the past before sending them to the backend. Existing payment-verification and tenant checks are unchanged.
- Request fields have stable ValueKeys so changing service type does not reuse unrelated FormField state.
- Saving existing administrator settings no longer silently overwrites the entered statistic with hardcoded `15` or forces a hardcoded email. This changes the app's save behavior only; no actual settings were edited.

## Automated validation

New Flutter widget regression coverage:
- Add/edit/disable/cancel prices and validate invalid prices in Arabic and English.
- Exercise the dialog reverse transition after Save/Cancel, checking for Flutter exceptions.
- Failed price save returns to a usable dashboard and can be retried.
- Small-phone price editing with keyboard inset.
- General administrator dialog save/cancel lifecycle.
- Small-phone native navigation through services, branches, contact and home; language and theme changes.

Existing Flutter tests cover request validation, residential price/payment configuration, QR type/size, account access and content/navigation. CI strict Flutter analysis and tests passed; final APK handoff below.

Local unchanged-website regression checks also passed (35 integration checks and 8 session scenarios), dependency guard and `git diff --check` passed.

## Manual acceptance and boundaries

Install the new test APK over the previous one, then test administrator prices: add, save, reopen, change, disable and cancel while the keyboard is open. Confirm the saved price remains after refreshing/re-entering administration. Test real Supabase connectivity, QR gallery upload and admin queues on the device.

Automated admin repository tests use a fake in-memory backend; they do not replace a real authenticated-device test. No real administrator credentials were requested or used for automated sign-in. No iOS build or live bank transfer was tested.

Other unspecified reported problems are not proven fixed. Need the screen/action/steps (and first error/stack if available) for remaining failures; do not proceed to stage four until acceptance. Sender-phone + transfer-amount + receipt-image submission remains unimplemented from the previous increment; it is not silently treated as a repaired feature here. Existing manual text confirmation/review remains.

## Verified Android handoff

CI [44899840345](https://github.com/aliahmed15a159-eng/ikill/actions/runs/44899840345) succeeded for app/test code `a7ea28b`: strict analysis, full Flutter tests, Supabase-configured debug APK and dependency checks.

[Download the stability test APK](https://github.com/aliahmed15a159-eng/ikill/actions/runs/44899840345/artifacts/14705368341). Extract the ZIP and install `app-debug.apk`. ZIP SHA-256: `678d7163d598ef0a4429308e3be4643f952223b0eebd6d7cde167f4f0379e32f`.

No website deployment, merge or new phase work was performed. Paused for user/device acceptance testing.

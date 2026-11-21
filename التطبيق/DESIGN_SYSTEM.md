# iKILL Native Design System

## Scope and source audit (2026-11-21)

Read-only reference: repository root `styles.css`, `mobile.css`, `utilities.css`, `index.html`, and `img/ikill-logo*.png`. **No website files were edited.** No new functional screens, schema changes, role changes, payment changes or website deployment are part of this phase.

The important CSS cascade is the later **iKILL 2026 ECO UI** block (`styles.css` around line 1136), not just the original tokens at the start. Later typography rules select Cairo for Arabic and Inter for English. The mobile CSS was studied for spacing and logo sizing, not copied as a WebView.

| Reference token | Effective website value | Native interpretation |
|---|---|---|
| green-950 | `#062F20` | Offline secondary / deep forest identity |
| green-900 | `#075A3C` | Offline primary default |
| green-800 / 700 | `#087149` / `#098653` | Forest/emerald visual family |
| green-600 / 500 | `#13A563` / `#25BC72` | Lighter supporting greens |
| green-400 / 300 | `#55CF80` / `#92E68A` | Decorative highlights, not white-text buttons |
| lime | `#C9F56A` | Accent hue reference; derived relative to primary for other brands |
| bg-secondary / card | `#F5FAF5` / `#FFFFFF` | Light background / surface |
| text-primary / secondary | `#123427` / `#466557` | High-contrast mobile text |
| border | `#DCEEE2` | Quiet card/input separators |
| dark background / surface | `#081C13` / `#102F20` | Dark theme |
| dark text / secondary | `#EFFCF0` / `#B8D7BF` | Dark theme text |

The site's forest-to-emerald gradients, transparent wordmark, 20/28px corners and green-tinted soft shadows are translated into native Material 3 surfaces. Large website hero sections become a compact inset mobile welcome card. Existing content and workflows remain available.

## Architecture

- `lib/config/brand_config.dart`: compile-time, offline white-label defaults. Existing `BRAND_*` defines are preserved.
- `lib/design/brand_controller.dart`: public `get_auth_brand(BRAND_SLUG)` reads only published name, primary hex and logo path from Supabase `brand_config`. Validated remote identity takes precedence. Existing production colours are **not overwritten** by this design update.
- Presentation cache is scoped to project URL + brand slug and contains only name and primary colour. No tokens, roles or permissions are cached by this module. Failed network requests retain last-known identity.
- Logo uses a short-lived Supabase Storage signed URL and local asset fallback. Refresh occurs at startup (non-blocking network fetch), app resume and after saving existing brand settings. No broad public table access or new realtime subscription was added.
- `lib/design/app_theme.dart`: light/dark `ThemeData`, Cairo/Inter text scale, semantic `AppPalette`, spacing, shapes, inputs, buttons, dialogs, sheets, snackbars, nav, list tiles and transitions.
- `lib/design/components.dart`: `LoadingButton`, `AppInput`, `AppCard`, `StatusBadge`, `AppToast`, `SkeletonLoader`, `PageEntrance`.

### Colour and readability

Primary is the exact validated configured brand colour. `onPrimary` is black or white, whichever gives better contrast (AA checked in tests even for yellow/white/black brands). Secondary and accent derive from primary, so a new white-label identity does not require changing screen constants. Semantic success, warning, error and info remain stable and are separate from branding. Background/surface neutrals retain the ECO family.

Hero gradient stops are darkened as needed for white-copy contrast. Status badges include text and icons, never colour alone. Text and form errors use semantic colours. Existing workflow statuses are not changed by a badge.

### Typography

Cairo for Arabic; Inter for English and prominent numeric metrics. Fonts are bundled locally, not fetched at runtime. Variable TTFs are from Google Fonts' `ofl/cairo` and `ofl/inter` directories; SIL Open Font License copies are bundled beside them in `assets/fonts/`.

Native type scale: headlines 30/26/23, title 20/16, body 16/14, supporting 12 logical pixels. Arabic uses generous 1.4–1.7 line height. Device text scaling is not disabled or clamped.

### Interaction and spacing

- 4/8/12/16/24/32 spacing scale; 20–24px page and card insets.
- 48px minimum interactive targets, primary buttons 54px high; keyboard-safe scrollable forms.
- Bottom navigation: Home, Services, Book, Account. Account opens the existing role-aware account route; branches, sectors, legal and staff entries remain in the drawer.
- Safe areas and native back stack retained. Route transitions use Android fade-up and iOS Cupertino conventions.
- In-place page fade honours reduced-motion settings. Skeletons are static, lightweight and announced as loading rather than endlessly shimmering.
- Brand changes rebuild the app theme without reconstructing its navigator or clearing form fields.

## Adoption in existing screens

All existing screens inherit central typography, input, card, button, app bar, snackbar, sheet and dialog themes. Additional explicit adoption:
- Home: compact gradient/image card, native spacing, updated statistic colours/numeric font, shared cards and logo.
- Existing authentication/recovery/profile completion: shared identity, gradient, loading action and custom mobile field.
- Customer requests: reusable loading/disabled button, shared feedback toast; manual payment behaviour unchanged.
- Admin, requests, documents, technician and account router: shared skeleton states.
- Technician visits, invoice payment and admin review: semantic, labelled status badges.
- Admin branding settings: changes refresh app identity after save; wording reflects app + documents.
- Long admin/form dropdowns expand within phone width.

## Testing / Android handoff

`test/design_system_test.dart` checks configurable primary/surface contrast, typography, hex validation, disabled busy action, RTL + 1.6x text at 360px, reusable fields/cards/badges/skeletons and shared snackbar. Existing app tests cover offline home, light/dark, language and bottom-navigation content. Auth, permissions, billing and backend SDK audits remain in CI.

Use `.github/workflows/android-apk.yml` for Flutter analyze/tests and installable debug APK. APK is for sideload acceptance testing, **not a production-signed Play Store release**. Device visual review, TalkBack, keyboards, Android font rendering and field-device regression testing still require human acceptance. No claim of physical-device testing is made.

Before merge, verify on device: Arabic/English, light/dark, small phone + larger font, soft keyboard, bottom nav/back, offline relaunch, branding save + resume, all existing role dashboards, request/manual payment flow and notification navigation. Existing Google-provider/SMTP and FCM server-credential blockers in the prior handoff are unchanged by this visual-only phase.

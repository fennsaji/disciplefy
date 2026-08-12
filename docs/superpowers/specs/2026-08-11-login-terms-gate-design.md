# Terms Acceptance Gate on Login — Design

**Date:** 2026-08-11
**Status:** Approved design, ready for implementation plan

## Background

iOS 1.0.2 was rejected under **Guideline 1.2 — Safety: User-Generated Content**. Apple named three required precautions; the block-user mechanism (previous work, merged to `main`) closed two of them. The third is unaddressed:

> "reply to this message with a screen recording... that demonstrates: The EULA or terms of use agreement presented to users before registering or logging in"

Today `LoginScreen` shows a static, non-tappable "By using this app you agree to our privacy policy" line (`TranslationKeys.loginPrivacyPolicy`). It mentions nothing about Terms of Use, isn't a link, and doesn't require any acknowledgment. This does not satisfy "presented... before registering or logging in" in a way a reviewer will accept on a second pass of the same guideline.

## Scope

In scope: a terms/privacy acceptance gate covering every sign-in path (Google, Apple, Email), enforced in `RouterGuard` and surfaced as a checkbox on `LoginScreen`. A shared constants file for the Terms/Privacy URLs, replacing the independent hardcoded copies in `subscription_legal_links.dart` and `settings_screen.dart`.

Out of scope: the screen recording itself (user's job, on a physical device, after this ships), the China-mainland Guideline 2.1 fix (App Store Connect config, no code), and any change to `settings_screen.dart`'s existing terms/privacy tiles beyond pointing them at the new shared constants.

## Decisions

1. **Explicit checkbox, not passive links.** Given this is a second rejection on the same guideline, the checkbox gate removes any reviewer ambiguity about whether terms were "presented" — sign-in buttons are disabled until checked.
2. **Persisted locally, on sign-in button tap.** Acceptance is written to the existing Hive `app_settings` box at the moment the user taps a sign-in button with the box checked — not on checkbox-tick alone (an abandoned tick shouldn't count), and *not* after `AuthenticatedState`. Writing after authentication would break Google/Apple OAuth: the user leaves the app for the provider and returns to `/auth/callback`, at which point the flag would still be false and the router gate (decision 3) would bounce them back to `/login`, making sign-in impossible. Tapping a sign-in button means "accepted and proceeding," which is the correct semantic and survives the OAuth round-trip.
3. **Enforced in `RouterGuard`, not just on the screen.** `/email-auth` and `/phone-auth` are top-level public routes (`router_guard.dart:535`, plus a `startsWith('/email-auth')` catch-all at :546), directly reachable by URL or deep link without ever rendering `LoginScreen`. Gating only the screen would leave registration reachable without the terms being shown. The guard enforces the rule for every auth route so it cannot be skipped, and covers any auth route added later.
4. **One checkbox UI, in `LoginScreen`.** The guard makes the gate unskippable; `LoginScreen` remains the only place the checkbox is rendered. No duplication into `EmailAuthScreen` or `PhoneNumberInputScreen`.
4. **Hoist the URLs.** `https://www.disciplefy.in/terms` and `/privacy` currently exist verbatim in `subscription_legal_links.dart` and `settings_screen.dart`. A third hardcoded copy for this feature would be the same drift risk this codebase already tracks for Bible book names. New shared constants file; both existing call sites updated to use it.

## Existing code

- Gate location: `frontend/lib/features/auth/presentation/pages/login_screen.dart` — `_buildSignInButtons` (disables via existing `isLoading`-style pattern), `_buildPrivacyText` (replaced), `BlocListener` for `AuthenticatedState` (~line 111, add persistence write).
- Redirect-survival pattern to copy: `Hive.box('app_settings').put('pending_deep_link_redirect', ...)` (lines 636, 650) — same box, same style, for the new `terms_accepted` key.
- URL duplication to fix: `frontend/lib/features/subscription/presentation/widgets/subscription_legal_links.dart` (`termsUrl`/`privacyUrl` static consts) and `frontend/lib/features/settings/presentation/pages/settings_screen.dart` (`_launchPrivacyPolicy`/`_launchTermsOfService`, lines 3085–3094).
- Strings: `frontend/lib/core/i18n/translation_keys.dart` + `app_translations.dart` (settings screen's i18n system — `LoginScreen` uses `context.tr(TranslationKeys...)`, confirmed by its existing `loginWelcome` etc. usage, so new strings go in the same system, not `AppLocalizations`).

## Design

**Shared constants.** New `frontend/lib/core/constants/legal_urls.dart`:
```dart
class LegalUrls {
  static const String terms = 'https://www.disciplefy.in/terms';
  static const String privacy = 'https://www.disciplefy.in/privacy';
}
```
`subscription_legal_links.dart` and `settings_screen.dart` updated to reference `LegalUrls.terms`/`LegalUrls.privacy` instead of their local literals.

**New widget.** `TermsAcceptanceCheckbox` (`frontend/lib/features/auth/presentation/widgets/terms_acceptance_checkbox.dart`): a `Checkbox` + inline `RichText` with two tappable spans ("Terms of Use", "Privacy Policy") wrapping plain text ("I agree to the ... and ..."), using `url_launcher` the same way `SubscriptionLegalLinks` does. Takes `value` and `onChanged` — stateless, parent owns the boolean.

**LoginScreen changes.**
- `initState`: read `Hive.box('app_settings').get('terms_accepted', defaultValue: false)` into `_termsAccepted`.
- When `_termsAccepted` is `false`: render `TermsAcceptanceCheckbox` above the sign-in buttons; `_buildSignInButtons` treats `!_termsAccepted` the same as `isLoading` for each button's `onPressed` (disabled, not hidden — visible-but-disabled communicates the gate rather than a layout jump).
- When `_termsAccepted` is `true`: skip the checkbox row entirely; render a static line with tappable links ("By continuing you agree to our Terms of Use and Privacy Policy") in its place — this is `_buildPrivacyText`'s replacement, always present regardless of gate state, using `LegalUrls`.
- Each of the three sign-in handlers (`_handleGoogleSignIn`, `_handleAppleSignIn`, `_handleEmailSignIn`) writes `Hive.box('app_settings').put('terms_accepted', true)` before dispatching its event / navigating. The write is idempotent, so no conditional is needed. `_handleEmailSignIn` must write before `context.push(AppRoutes.emailAuth)`, otherwise the router gate (below) would immediately bounce the push back to `/login`.

**RouterGuard changes.** In `_handleUnauthenticatedUser` (`router_guard.dart:665`), before the existing `isPublicRoute` early-return: if the route is an auth route *other than* `/login`, `/auth/callback`, or `/password-reset`, and `terms_accepted` is false in the `app_settings` box (already accessed throughout this file as `_hiveBboxName`), redirect to `AppRoutes.login`.

The three exclusions are load-bearing, not incidental:
- `/login` — redirecting it to itself is an infinite loop.
- `/auth/callback` — the OAuth return leg; blocking it breaks Google and Apple sign-in outright.
- `/password-reset` — an existing user resetting a password is not registering, and blocking a reset link from email would strand them.

The guard reads Hive defensively, matching the `Hive.isBoxOpen`-style guards already used elsewhere in this file (see the fallback at :433); if the box isn't open it returns `null` (no redirect) rather than throwing, since a hard failure here would lock users out of auth entirely.

**Error handling.** No new failure modes — this is local state and a Hive write, no network call. If `url_launcher` can't open a link (no browser), `SubscriptionLegalLinks`' existing silent-no-op pattern (`if (await canLaunchUrl(uri))`) is followed rather than introducing new error UI.

**Testing.** Widget tests on `LoginScreen`: (1) fresh state (no Hive flag) → checkbox visible and unchecked → all three sign-in buttons disabled → check the box → buttons enabled → tap Google → `GoogleSignInRequested` added to `AuthBloc` **and** `terms_accepted` is now true in Hive. (2) Hive flag pre-set to `true` → checkbox row absent, static links line present, buttons enabled from first render.

Unit tests on `RouterGuard._handleUnauthenticatedUser`: with `terms_accepted` false, `/email-auth` and `/phone-auth` redirect to `/login`, while `/login`, `/auth/callback`, and `/password-reset` return null (no redirect) — the last three are the regression tests that protect the OAuth and password-reset flows. With the flag true, `/email-auth` returns null.

Existing `test/helpers/mock_translation_provider.dart` is reused for `context.tr(...)`, matching this module's test conventions.

## Note for the App Review recording

Because acceptance is remembered per device, the checkbox only appears on a device that has never signed in. Record the App Review screen capture on a **fresh install** (delete the app first), or the gate will not be on camera — Apple asked specifically to see the terms presented before login.

## Constraints

- Strings need en/hi/ml entries in `translation_keys.dart` + `app_translations.dart`, per this codebase's standing i18n rule.
- No backend, no migration, no deployment — Flutter-only change.
- `flutter analyze` clean, `dart format lib/` applied, `flutter test` passing (existing suite + new widget tests) before this is considered done.

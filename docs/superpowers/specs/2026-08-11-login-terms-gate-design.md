# Terms Acceptance Gate on Login — Design

**Date:** 2026-08-11
**Status:** Approved design, ready for implementation plan

## Background

iOS 1.0.2 was rejected under **Guideline 1.2 — Safety: User-Generated Content**. Apple named three required precautions; the block-user mechanism (previous work, merged to `main`) closed two of them. The third is unaddressed:

> "reply to this message with a screen recording... that demonstrates: The EULA or terms of use agreement presented to users before registering or logging in"

Today `LoginScreen` shows a static, non-tappable "By using this app you agree to our privacy policy" line (`TranslationKeys.loginPrivacyPolicy`). It mentions nothing about Terms of Use, isn't a link, and doesn't require any acknowledgment. This does not satisfy "presented... before registering or logging in" in a way a reviewer will accept on a second pass of the same guideline.

## Scope

In scope: a terms/privacy acceptance gate on `LoginScreen`, covering every sign-in path (Google, Apple, Email — all reached from this one screen; `EmailAuthScreen` is only navigated to via this screen's "Continue with Email" button, so gating here covers it without touching it). A shared constants file for the Terms/Privacy URLs, replacing three independent hardcoded copies.

Out of scope: the screen recording itself (user's job, on a physical device, after this ships), the China-mainland Guideline 2.1 fix (App Store Connect config, no code), and any change to `settings_screen.dart`'s existing terms/privacy tiles beyond pointing them at the new shared constants.

## Decisions

1. **Explicit checkbox, not passive links.** Given this is a second rejection on the same guideline, the checkbox gate removes any reviewer ambiguity about whether terms were "presented" — sign-in buttons are disabled until checked.
2. **Persisted locally, once.** Acceptance is written to the existing Hive `app_settings` box only after a successful sign-in with the box checked (not on checkbox-tap alone, so an abandoned session isn't falsely recorded). Subsequent logins on the same device skip the checkbox but keep a static, always-visible Terms/Privacy link line — still "presented," just not blocking a returning user.
3. **One gate, not one per auth method.** `LoginScreen` is the single choke point for all three sign-in methods; no duplication needed in `EmailAuthScreen`.
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
- When `_termsAccepted` is `true`: skip the checkbox row entirely; render a static, non-interactive-but-tappable-links line ("By continuing you agree to our Terms of Use and Privacy Policy") in its place — this is `_buildPrivacyText`'s replacement, always present regardless of gate state, using `LegalUrls`.
- `AuthenticatedState` branch of the existing `BlocListener` (~line 113): if `_termsAccepted` is true (i.e., the user just passed the gate this session — writing unconditionally on every authenticated event would also re-write for a user who was already `true` from a prior session, which is harmless but pointless), call `Hive.box('app_settings').put('terms_accepted', true)` before the existing redirect logic runs.

**Error handling.** No new failure modes — this is local state and a Hive write, no network call. If `url_launcher` can't open a link (no browser), `SubscriptionLegalLinks`' existing silent-no-op pattern (`if (await canLaunchUrl(uri))`) is followed rather than introducing new error UI.

**Testing.** Widget test on `LoginScreen`: (1) fresh state (no Hive flag) → checkbox visible and unchecked → all three sign-in buttons disabled → check the box → buttons enabled → tap Google → `GoogleSignInRequested` added to `AuthBloc`. (2) Hive flag pre-set to `true` → checkbox row absent, static links line present, buttons enabled from first render. Existing `test/helpers/mock_translation_provider.dart` reused for `context.tr(...)` in tests, matching this feature module's existing test conventions.

## Constraints

- Strings need en/hi/ml entries in `translation_keys.dart` + `app_translations.dart`, per this codebase's standing i18n rule.
- No backend, no migration, no deployment — Flutter-only change.
- `flutter analyze` clean, `dart format lib/` applied, `flutter test` passing (existing suite + new widget tests) before this is considered done.

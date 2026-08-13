# Login Terms Gate Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Require users to explicitly accept the Terms of Use and Privacy Policy before any sign-in path completes, satisfying the last outstanding item of the Apple Guideline 1.2 rejection.

**Architecture:** A single Hive flag (`terms_accepted` in the existing `app_settings` box) is the source of truth. `LoginScreen` renders a checkbox gate that disables the sign-in buttons until ticked, and writes the flag when a sign-in button is tapped. `RouterGuard` independently enforces the flag so the directly-reachable `/email-auth` and `/phone-auth` routes cannot bypass the gate.

**Tech Stack:** Flutter, `flutter_bloc`, `go_router`, Hive, `url_launcher`, `mockito` + `bloc_test` for tests.

## Global Constraints

- Every new user-facing string needs entries in **all three** locale maps (en, hi, ml) in `frontend/lib/core/i18n/app_translations.dart`, plus a key constant in `frontend/lib/core/i18n/translation_keys.dart`. `LoginScreen` uses the `context.tr(TranslationKeys.x)` system — **not** `AppLocalizations`.
- `print()` is banned; use `Logger` from `lib/core/utils/logger.dart` if logging is needed.
- Package imports only inside `lib/` where the file already uses them; `login_screen.dart` currently uses relative imports (`../../../../core/...`) — match the file you are editing rather than converting it.
- After every task: `cd frontend && dart format lib/ test/ && flutter analyze` must be clean, and `flutter test` must pass.
- **Never run `git commit`.** All tasks land as one squashed commit at the end, after the user approves. Steps that say "Stage" mean `git add` and nothing more.
- Work on branch `dev`. No feature branches, no stash/reset/revert of anything you did not create.
- Flutter-only change. No backend, no migration, no deploy commands.

---

### Task 1: Shared legal URL constants

**Files:**
- Create: `frontend/lib/core/constants/legal_urls.dart`
- Modify: `frontend/lib/features/subscription/presentation/widgets/subscription_legal_links.dart:16-17`
- Modify: `frontend/lib/features/settings/presentation/pages/settings_screen.dart:3085-3094`

**Interfaces:**
- Produces: `LegalUrls.terms` and `LegalUrls.privacy` (both `static const String`), imported by Tasks 2 and 3.

The URLs `https://www.disciplefy.in/terms` and `https://www.disciplefy.in/privacy` are currently hardcoded independently in two files. Task 2 would add a third copy; hoist them first.

- [ ] **Step 1: Create the constants file**

Create `frontend/lib/core/constants/legal_urls.dart`:

```dart
/// Canonical URLs for the app's public legal documents.
///
/// These are referenced from the subscription purchase sheet (App Store
/// Guideline 3.1.2(c)), the settings screen, and the login terms gate
/// (Guideline 1.2). Keep them here so the three cannot drift apart.
class LegalUrls {
  const LegalUrls._();

  static const String terms = 'https://www.disciplefy.in/terms';
  static const String privacy = 'https://www.disciplefy.in/privacy';
}
```

- [ ] **Step 2: Point `subscription_legal_links.dart` at it**

In `frontend/lib/features/subscription/presentation/widgets/subscription_legal_links.dart`, add the import alongside the existing ones:

```dart
import '../../../../core/constants/legal_urls.dart';
```

Replace lines 16-17:

```dart
  static const String termsUrl = 'https://www.disciplefy.in/terms';
  static const String privacyUrl = 'https://www.disciplefy.in/privacy';
```

with:

```dart
  static const String termsUrl = LegalUrls.terms;
  static const String privacyUrl = LegalUrls.privacy;
```

Keep the `termsUrl`/`privacyUrl` names — they are referenced elsewhere in the same file and possibly in tests; this change is about removing the duplicated literal, not renaming the API.

- [ ] **Step 3: Point `settings_screen.dart` at it**

In `frontend/lib/features/settings/presentation/pages/settings_screen.dart`, add the import alongside the existing ones:

```dart
import '../../../../core/constants/legal_urls.dart';
```

In `_launchPrivacyPolicy` (line ~3085) replace:

```dart
    final uri = Uri.parse('https://www.disciplefy.in/privacy');
```

with:

```dart
    final uri = Uri.parse(LegalUrls.privacy);
```

In `_launchTermsOfService` (line ~3092) replace:

```dart
    final uri = Uri.parse('https://www.disciplefy.in/terms');
```

with:

```dart
    final uri = Uri.parse(LegalUrls.terms);
```

Leave `_launchRefundPolicy`'s `/refund` URL alone — it has only one call site and is out of scope.

- [ ] **Step 4: Verify**

```bash
cd frontend && dart format lib/ && flutter analyze
```

Expected: `No issues found!`

Confirm no stray literals remain:

```bash
cd frontend && grep -rn "disciplefy.in/terms\|disciplefy.in/privacy" lib/
```

Expected: only `lib/core/constants/legal_urls.dart` matches.

- [ ] **Step 5: Stage (do NOT commit)**

```bash
git add frontend/lib/core/constants/legal_urls.dart frontend/lib/features/subscription/presentation/widgets/subscription_legal_links.dart frontend/lib/features/settings/presentation/pages/settings_screen.dart
```

---

### Task 2: Terms acceptance checkbox widget and strings

**Files:**
- Create: `frontend/lib/features/auth/presentation/widgets/terms_acceptance_checkbox.dart`
- Modify: `frontend/lib/core/i18n/translation_keys.dart:251` (login block)
- Modify: `frontend/lib/core/i18n/app_translations.dart` (three locale maps — en ~line 336, hi ~line 2360, ml ~line 4405)

**Interfaces:**
- Consumes: `LegalUrls.terms`, `LegalUrls.privacy` from Task 1.
- Produces: `TermsAcceptanceCheckbox({required bool value, required ValueChanged<bool> onChanged})` and `LegalLinksLine()`, both used by Task 3. Five new translation keys: `TranslationKeys.loginTermsAgree`, `loginTermsOfUse`, `loginTermsAnd`, `loginPrivacyPolicyLink`, `loginTermsSuffix`.

The existing `TranslationKeys.loginPrivacyPolicy` ("By continuing, you agree to our Terms of Service and Privacy Policy") stays — Task 3 reuses it for the already-accepted state. The new keys are for the checkbox row, which needs the link text as separate tappable spans.

- [ ] **Step 1: Add the key constants**

In `frontend/lib/core/i18n/translation_keys.dart`, directly after line 251 (`static const loginPrivacyPolicy = 'login.privacy_policy';`), add all five:

```dart
  static const loginTermsAgree = 'login.terms_agree';
  static const loginTermsOfUse = 'login.terms_of_use';
  static const loginTermsAnd = 'login.terms_and';
  static const loginPrivacyPolicyLink = 'login.privacy_policy_link';
  static const loginTermsSuffix = 'login.terms_suffix';
```

The sentence is assembled from five spans because the two link texts must be independently tappable. `terms_suffix` exists because Hindi and Malayalam put the verb at the end of the clause — English leaves it empty. The leading and trailing spaces below are deliberate: these are concatenated inline spans in one sentence, not standalone labels.

- [ ] **Step 2: Add the English strings**

In `frontend/lib/core/i18n/app_translations.dart`, in the English `'login'` map, directly after the existing `'privacy_policy':` entry (~line 336-337), add:

```dart
      'terms_agree': 'I agree to the ',
      'terms_of_use': 'Terms of Use',
      'terms_and': ' and ',
      'privacy_policy_link': 'Privacy Policy',
      'terms_suffix': '',
```

Renders as: *I agree to the **Terms of Use** and **Privacy Policy***

- [ ] **Step 3: Add the Hindi strings**

In the Hindi `'login'` map, after its `'privacy_policy':` entry (~line 2360-2362), add:

```dart
      'terms_agree': 'मैं ',
      'terms_of_use': 'सेवा की शर्तों',
      'terms_and': ' और ',
      'privacy_policy_link': 'गोपनीयता नीति',
      'terms_suffix': ' से सहमत हूँ',
```

Renders as: *मैं **सेवा की शर्तों** और **गोपनीयता नीति** से सहमत हूँ*

- [ ] **Step 4: Add the Malayalam strings**

In the Malayalam `'login'` map, after its `'privacy_policy':` entry (~line 4405-4407), add:

```dart
      'terms_agree': 'ഞാൻ ',
      'terms_of_use': 'സേവന നിബന്ധനകളും',
      'terms_and': ' ',
      'privacy_policy_link': 'സ്വകാര്യതാ നീതിയും',
      'terms_suffix': ' അംഗീകരിക്കുന്നു',
```

Renders as: *ഞാൻ **സേവന നിബന്ധനകളും** **സ്വകാര്യതാ നീതിയും** അംഗീകരിക്കുന്നു*

- [ ] **Step 5: Write the widget**

Create `frontend/lib/features/auth/presentation/widgets/terms_acceptance_checkbox.dart`:

```dart
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/constants/app_fonts.dart';
import '../../../../core/constants/legal_urls.dart';
import '../../../../core/extensions/translation_extension.dart';
import '../../../../core/i18n/translation_keys.dart';

/// Opens [url] in the platform browser, silently doing nothing if no handler
/// exists. Mirrors [SubscriptionLegalLinks]'s behaviour.
Future<void> _launchLegalUrl(String url) async {
  final uri = Uri.parse(url);
  if (await canLaunchUrl(uri)) {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

/// The inline "…Terms of Use and Privacy Policy…" sentence with both
/// documents as tappable links.
///
/// Shared by [TermsAcceptanceCheckbox] (first-run gate) and [LegalLinksLine]
/// (returning users) so the link targets cannot diverge.
List<InlineSpan> _legalSpans(BuildContext context, TextStyle linkStyle) => [
      TextSpan(
        text: context.tr(TranslationKeys.loginTermsOfUse),
        style: linkStyle,
        recognizer: TapGestureRecognizer()
          ..onTap = () => _launchLegalUrl(LegalUrls.terms),
      ),
      TextSpan(text: context.tr(TranslationKeys.loginTermsAnd)),
      TextSpan(
        text: context.tr(TranslationKeys.loginPrivacyPolicyLink),
        style: linkStyle,
        recognizer: TapGestureRecognizer()
          ..onTap = () => _launchLegalUrl(LegalUrls.privacy),
      ),
    ];

/// Checkbox gating sign-in on explicit acceptance of the Terms of Use and
/// Privacy Policy.
///
/// Required by App Store Review Guideline 1.2, which mandates that the terms
/// be presented before a user registers or logs in. Stateless — the parent
/// owns the boolean.
class TermsAcceptanceCheckbox extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;

  const TermsAcceptanceCheckbox({
    super.key,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final baseStyle = AppFonts.inter(
      fontSize: 13,
      color: theme.colorScheme.onSurface.withOpacity(0.8),
      height: 1.4,
    );
    final linkStyle = baseStyle.copyWith(
      color: theme.colorScheme.primary,
      fontWeight: FontWeight.w600,
      decoration: TextDecoration.underline,
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 24,
          height: 24,
          child: Checkbox(
            value: value,
            onChanged: (checked) => onChanged(checked ?? false),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: GestureDetector(
            // Tapping the sentence body (but not a link) also toggles, which
            // is the expected affordance for a checkbox label.
            onTap: () => onChanged(!value),
            child: Text.rich(
              TextSpan(
                style: baseStyle,
                children: [
                  TextSpan(text: context.tr(TranslationKeys.loginTermsAgree)),
                  ..._legalSpans(context, linkStyle),
                  TextSpan(text: context.tr(TranslationKeys.loginTermsSuffix)),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Static "By continuing, you agree to our Terms of Use and Privacy Policy"
/// line with tappable links, shown to users who have already accepted.
///
/// The terms stay visible on every visit to the login screen; only the
/// blocking checkbox is first-run.
class LegalLinksLine extends StatelessWidget {
  const LegalLinksLine({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final baseStyle = AppFonts.inter(
      fontSize: 12,
      color: theme.colorScheme.onSurface.withOpacity(0.6),
      height: 1.4,
    );
    final linkStyle = baseStyle.copyWith(
      color: theme.colorScheme.primary,
      fontWeight: FontWeight.w600,
      decoration: TextDecoration.underline,
    );

    return Text.rich(
      TextSpan(
        style: baseStyle,
        children: [
          TextSpan(text: context.tr(TranslationKeys.loginTermsAgree)),
          ..._legalSpans(context, linkStyle),
          TextSpan(text: context.tr(TranslationKeys.loginTermsSuffix)),
        ],
      ),
      textAlign: TextAlign.center,
    );
  }
}
```

- [ ] **Step 6: Verify it compiles**

```bash
cd frontend && dart format lib/ && flutter analyze
```

Expected: `No issues found!`

If `AppFonts` or `translation_extension.dart` are at different relative paths from this new `widgets/` directory, fix the import depth — `login_screen.dart` in `../pages/` uses `../../../../core/...`, and this file is at the same depth, so the same prefix applies.

- [ ] **Step 7: Stage (do NOT commit)**

```bash
git add frontend/lib/features/auth/presentation/widgets/terms_acceptance_checkbox.dart frontend/lib/core/i18n/translation_keys.dart frontend/lib/core/i18n/app_translations.dart
```

---

### Task 3: Wire the gate into LoginScreen

**Files:**
- Modify: `frontend/lib/features/auth/presentation/pages/login_screen.dart`
- Test: `frontend/test/features/auth/login_terms_gate_test.dart` (create)

**Interfaces:**
- Consumes: `TermsAcceptanceCheckbox`, `LegalLinksLine` from Task 2.
- Produces: the Hive key `'terms_accepted'` in box `'app_settings'`, read by Task 4's router guard.

`LoginScreen` already reads and writes this Hive box (lines 54, 71, 636, 650), so the box is open by the time this code runs.

- [ ] **Step 1: Write the failing test**

Create `frontend/test/features/auth/login_terms_gate_test.dart`:

```dart
// Verifies the Apple Guideline 1.2 terms gate: sign-in is blocked until the
// user explicitly accepts the Terms of Use and Privacy Policy, and the
// acceptance is persisted so returning users are not asked again.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'package:disciplefy_bible_study/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:disciplefy_bible_study/features/auth/presentation/bloc/auth_event.dart';
import 'package:disciplefy_bible_study/features/auth/presentation/bloc/auth_state.dart';
import 'package:disciplefy_bible_study/features/auth/presentation/pages/login_screen.dart';
import 'package:disciplefy_bible_study/features/auth/presentation/widgets/terms_acceptance_checkbox.dart';

import 'login_terms_gate_test.mocks.dart';

@GenerateMocks([AuthBloc])
void main() {
  late MockAuthBloc mockAuthBloc;
  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('terms_gate_test');
    Hive.init(tempDir.path);
  });

  tearDownAll(() async {
    await Hive.close();
    await tempDir.delete(recursive: true);
  });

  setUp(() async {
    if (Hive.isBoxOpen('app_settings')) {
      await Hive.box('app_settings').clear();
    } else {
      await Hive.openBox('app_settings');
    }
    mockAuthBloc = MockAuthBloc();
    when(mockAuthBloc.state).thenReturn(const AuthInitialState());
    when(mockAuthBloc.stream)
        .thenAnswer((_) => const Stream<AuthState>.empty());
  });

  Widget harness() => MaterialApp(
        home: BlocProvider<AuthBloc>.value(
          value: mockAuthBloc,
          child: const LoginScreen(),
        ),
      );

  testWidgets('blocks sign-in until the terms checkbox is ticked',
      (tester) async {
    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    // The gate is visible on a device that has never accepted.
    expect(find.byType(TermsAcceptanceCheckbox), findsOneWidget);

    // Every sign-in button is disabled while unaccepted.
    final buttons = tester
        .widgetList<OutlinedButton>(find.byType(OutlinedButton))
        .toList();
    expect(buttons, isNotEmpty);
    for (final button in buttons) {
      expect(button.onPressed, isNull,
          reason: 'sign-in buttons must be disabled before acceptance');
    }

    // Tick the box.
    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();

    final enabled = tester
        .widgetList<OutlinedButton>(find.byType(OutlinedButton))
        .toList();
    for (final button in enabled) {
      expect(button.onPressed, isNotNull,
          reason: 'sign-in buttons must enable once accepted');
    }
  });

  testWidgets('persists acceptance when a sign-in button is tapped',
      (tester) async {
    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();

    // Tap the Google button (first sign-in button on the screen).
    await tester.tap(find.byType(OutlinedButton).first);
    await tester.pumpAndSettle();

    expect(
      Hive.box('app_settings').get('terms_accepted', defaultValue: false),
      isTrue,
      reason: 'acceptance must persist at button-tap time so it survives the '
          'OAuth round-trip to the provider and back',
    );
    verify(mockAuthBloc.add(const GoogleSignInRequested())).called(1);
  });

  testWidgets('skips the checkbox for a user who already accepted',
      (tester) async {
    await Hive.box('app_settings').put('terms_accepted', true);

    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    expect(find.byType(TermsAcceptanceCheckbox), findsNothing);
    expect(find.byType(LegalLinksLine), findsOneWidget);

    final buttons = tester
        .widgetList<OutlinedButton>(find.byType(OutlinedButton))
        .toList();
    for (final button in buttons) {
      expect(button.onPressed, isNotNull,
          reason: 'a returning user must not be re-gated');
    }
  });
}
```

If `AuthInitialState` is not the actual initial-state class name, read `frontend/lib/features/auth/presentation/bloc/auth_state.dart` and use the real one. Do not change the bloc to fit the test.

- [ ] **Step 2: Generate mocks and run the test to verify it fails**

```bash
cd frontend && dart run build_runner build --delete-conflicting-outputs && flutter test test/features/auth/login_terms_gate_test.dart
```

Expected: FAIL — `TermsAcceptanceCheckbox` is not present in the widget tree and the buttons are enabled.

- [ ] **Step 3: Add the state field and read the flag**

In `login_screen.dart`, add the imports:

```dart
import '../widgets/terms_acceptance_checkbox.dart';
```

In `_LoginScreenState`, alongside the existing `_isPhoneAuthInProgress` field (line ~29), add:

```dart
  /// Whether the user has accepted the Terms of Use and Privacy Policy.
  ///
  /// Seeded from Hive so a returning user is not re-gated. Required before
  /// any sign-in method is reachable (App Store Guideline 1.2).
  bool _termsAccepted = false;
```

In `initState` (line ~31), before `_checkAuthenticationStatus()`:

```dart
    _termsAccepted = Hive.box('app_settings')
        .get('terms_accepted', defaultValue: false) as bool;
```

- [ ] **Step 4: Render the gate**

In `build`, replace the privacy text call (line ~246):

```dart
                          // Privacy policy text
                          _buildPrivacyText(context),
```

with:

```dart
                          // Terms gate (first run) or static legal links
                          if (!_termsAccepted)
                            TermsAcceptanceCheckbox(
                              value: _termsAccepted,
                              onChanged: (accepted) =>
                                  setState(() => _termsAccepted = accepted),
                            )
                          else
                            const LegalLinksLine(),
```

Move this block to sit **above** `_buildSignInButtons(context)` when gating, so the checkbox reads before the buttons it controls. Concretely, the children order inside the centred `Column` becomes: logo, welcome text, features section, **gate/links**, sign-in buttons. Adjust the surrounding `SizedBox(height: 32)` spacers so the spacing stays even (one 32px gap between each section).

Delete the now-unused `_buildPrivacyText` method (line ~567-579) and its `TranslationKeys.loginPrivacyPolicy` reference. Leave the `loginPrivacyPolicy` translation key and its three locale entries in place — removing translation entries is out of scope and they are harmless.

- [ ] **Step 5: Disable the buttons until accepted**

In `_buildSignInButtons` (line ~323), the `BlocBuilder` computes `isLoading`. Change it to also account for the gate:

```dart
        builder: (context, state) {
          final isLoading = state is auth_states.AuthLoadingState;
          // Guideline 1.2: no sign-in path is reachable before acceptance.
          final isBlocked = isLoading || !_termsAccepted;

          return Column(
            children: [
              // Google Sign-In Button
              _buildGoogleSignInButton(context, isBlocked),
```

Pass `isBlocked` in place of `isLoading` to all three builders: `_buildGoogleSignInButton`, `_buildAppleSignInButton`, and `_buildEmailSignInButton`. Their existing parameter is already named `isLoading` and already drives both the disabled state and the spinner; renaming the parameter inside those three methods is unnecessary, but if you do rename it for clarity, rename it consistently in all three.

Note the visual consequence: a blocked-but-not-loading button will render its spinner branch in the Google and Apple builders, which is wrong. Fix by giving those two builders an explicit loading flag separate from the disabled flag. Change their signatures to:

```dart
  Widget _buildGoogleSignInButton(
      BuildContext context, bool isDisabled, bool isLoading) {
```

and in the body use `isDisabled` for `onPressed: isDisabled ? null : ...` and for `backgroundColor`, and keep `isLoading` for the `child: isLoading ? SizedBox(...spinner...) : Row(...)` branch. Apply the same split to `_buildAppleSignInButton`. `_buildEmailSignInButton` has no spinner branch, so it only needs the disabled flag. Call sites become:

```dart
              _buildGoogleSignInButton(context, isBlocked, isLoading),
              _buildAppleSignInButton(context, isBlocked, isLoading),
              _buildEmailSignInButton(context, isBlocked),
```

- [ ] **Step 6: Persist on sign-in tap**

In `_handleGoogleSignIn` (line ~642), as the first statement in the method body:

```dart
    Hive.box('app_settings').put('terms_accepted', true);
```

Add the identical line as the first statement of `_handleAppleSignIn` (line ~630) and `_handleEmailSignIn` (line ~656).

In `_handleEmailSignIn` the write **must** precede `context.push(AppRoutes.emailAuth)`, otherwise Task 4's router guard bounces the push straight back to `/login`:

```dart
  void _handleEmailSignIn(BuildContext context) {
    Hive.box('app_settings').put('terms_accepted', true);
    context.push(AppRoutes.emailAuth);
  }
```

The write is idempotent, so no conditional is needed. It happens at tap time rather than after authentication so it survives the OAuth round-trip to Google/Apple and back to `/auth/callback`.

- [ ] **Step 7: Run the test to verify it passes**

```bash
cd frontend && flutter test test/features/auth/login_terms_gate_test.dart
```

Expected: all three tests PASS.

- [ ] **Step 8: Verify nothing else regressed**

```bash
cd frontend && dart format lib/ test/ && flutter analyze && flutter test
```

Expected: `No issues found!` and the full suite passing.

- [ ] **Step 9: Stage (do NOT commit)**

```bash
git add frontend/lib/features/auth/presentation/pages/login_screen.dart frontend/test/features/auth/login_terms_gate_test.dart frontend/test/features/auth/login_terms_gate_test.mocks.dart
```

---

### Task 4: Enforce the gate in RouterGuard

**Files:**
- Modify: `frontend/lib/core/router/router_guard.dart:665` (`_handleUnauthenticatedUser`)
- Test: `frontend/test/core/router/router_guard_terms_gate_test.dart` (create)

**Interfaces:**
- Consumes: the Hive key `'terms_accepted'` in box `'app_settings'`, written by Task 3.
- Produces: nothing consumed by later tasks.

`/email-auth` and `/phone-auth` are public routes (`router_guard.dart:535`, plus `startsWith('/email-auth')` at :546), directly reachable by URL or deep link without rendering `LoginScreen`. Without this task the checkbox is trivially bypassed.

- [ ] **Step 1: Write the failing test**

Create `frontend/test/core/router/router_guard_terms_gate_test.dart`:

```dart
// Verifies that the Apple Guideline 1.2 terms gate cannot be bypassed by
// navigating directly to an auth route. /email-auth and /phone-auth are
// public routes reachable by URL or deep link, so gating only LoginScreen
// would leave registration reachable without the terms being shown.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:disciplefy_bible_study/core/router/app_routes.dart';
import 'package:disciplefy_bible_study/core/router/router_guard.dart';

void main() {
  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('guard_terms_test');
    Hive.init(tempDir.path);
    await Hive.openBox('app_settings');
  });

  tearDownAll(() async {
    await Hive.close();
    await tempDir.delete(recursive: true);
  });

  setUp(() async {
    await Hive.box('app_settings').clear();
  });

  group('terms not yet accepted', () {
    test('redirects /email-auth to /login', () {
      expect(
        RouterGuard.debugTermsGateRedirect(AppRoutes.emailAuth),
        AppRoutes.login,
      );
    });

    test('redirects /phone-auth to /login', () {
      expect(
        RouterGuard.debugTermsGateRedirect(AppRoutes.phoneAuth),
        AppRoutes.login,
      );
    });

    // The three exclusions below are load-bearing, not incidental.

    test('does not redirect /login (would be an infinite loop)', () {
      expect(RouterGuard.debugTermsGateRedirect(AppRoutes.login), isNull);
    });

    test('does not redirect /auth/callback (would break OAuth sign-in)', () {
      expect(
        RouterGuard.debugTermsGateRedirect(AppRoutes.authCallback),
        isNull,
      );
    });

    test('does not redirect /password-reset (would strand a reset link)', () {
      expect(
        RouterGuard.debugTermsGateRedirect(AppRoutes.passwordReset),
        isNull,
      );
    });

    test('does not redirect a non-auth public route', () {
      expect(RouterGuard.debugTermsGateRedirect(AppRoutes.pricing), isNull);
    });
  });

  group('terms already accepted', () {
    setUp(() async {
      await Hive.box('app_settings').put('terms_accepted', true);
    });

    test('allows /email-auth through', () {
      expect(RouterGuard.debugTermsGateRedirect(AppRoutes.emailAuth), isNull);
    });

    test('allows /phone-auth through', () {
      expect(RouterGuard.debugTermsGateRedirect(AppRoutes.phoneAuth), isNull);
    });
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

```bash
cd frontend && flutter test test/core/router/router_guard_terms_gate_test.dart
```

Expected: FAIL — `debugTermsGateRedirect` is not defined on `RouterGuard`.

- [ ] **Step 3: Add the key constant and the gate method**

In `router_guard.dart`, alongside the other key constants at the top of the class (after `_deviceIdKey`, line ~23):

```dart
  static const String _termsAcceptedKey = 'terms_accepted';
```

Add the gate as a method on `RouterGuard`. Place it directly above `_handleUnauthenticatedUser` (line ~665):

```dart
  /// Auth routes that stay reachable before the terms are accepted.
  ///
  /// Each exclusion is load-bearing:
  ///  - [AppRoutes.login] hosts the acceptance checkbox; redirecting it to
  ///    itself would loop forever.
  ///  - `/auth/callback` is the OAuth return leg. The user leaves the app for
  ///    Google/Apple before the flag is written, so blocking it would make
  ///    social sign-in impossible.
  ///  - `/password-reset` is an existing user recovering an account, not a
  ///    registration, and blocking an emailed reset link would strand them.
  static bool _isTermsGateExempt(String path) =>
      path == AppRoutes.login ||
      path.startsWith('/auth/callback') ||
      path.startsWith('/password-reset');

  /// Returns [AppRoutes.login] when [currentPath] is an auth route the user
  /// may not reach before accepting the Terms of Use and Privacy Policy.
  ///
  /// Required by App Store Review Guideline 1.2: `/email-auth` and
  /// `/phone-auth` are public, directly-addressable routes, so gating the
  /// login screen alone would leave registration reachable without the terms
  /// ever being presented.
  static String? _termsGateRedirect(String currentPath) {
    final isAuthRoute = currentPath == AppRoutes.login ||
        currentPath == AppRoutes.phoneAuth ||
        currentPath == AppRoutes.phoneAuthVerify ||
        currentPath == AppRoutes.emailAuth ||
        currentPath == AppRoutes.passwordReset ||
        currentPath.startsWith('/auth/callback') ||
        currentPath.startsWith('/email-auth') ||
        currentPath.startsWith('/phone-auth');

    if (!isAuthRoute || _isTermsGateExempt(currentPath)) return null;

    // Read defensively: a hard failure here would lock users out of auth
    // entirely, which is far worse than letting an ungated request through.
    if (!Hive.isBoxOpen(_hiveBboxName)) {
      Logger.warning(
        'Hive box not open, skipping terms gate',
        tag: 'ROUTER',
      );
      return null;
    }

    final accepted =
        Hive.box(_hiveBboxName).get(_termsAcceptedKey, defaultValue: false)
            as bool;
    if (accepted) return null;

    Logger.info(
      'Terms not accepted - redirecting auth route to login',
      tag: 'ROUTER_SECURITY',
      context: {
        'attempted_route': currentPath,
        'redirect_target': AppRoutes.login,
        'redirect_reason': 'terms_not_accepted',
      },
    );
    return AppRoutes.login;
  }

  /// Test-only entry point for [_termsGateRedirect].
  @visibleForTesting
  static String? debugTermsGateRedirect(String currentPath) =>
      _termsGateRedirect(currentPath);
```

Add the `@visibleForTesting` import at the top of the file:

```dart
import 'package:flutter/foundation.dart';
```

- [ ] **Step 4: Call the gate from the unauthenticated handler**

In `_handleUnauthenticatedUser` (line ~665), insert the check as the **first** statement, before the existing `isPublicRoute` early-return — the auth routes it guards are themselves public, so a later position would never run:

```dart
  static String? _handleUnauthenticatedUser(RouteAnalysis routeAnalysis) {
    // Guideline 1.2: block auth routes until the terms are accepted. This
    // must precede the public-route check below, because the routes being
    // gated are themselves public.
    final termsRedirect = _termsGateRedirect(routeAnalysis.currentPath);
    if (termsRedirect != null) return termsRedirect;

    // Phase 2: Enhanced logging for public routes
    if (routeAnalysis.isPublicRoute) {
```

- [ ] **Step 5: Run the test to verify it passes**

```bash
cd frontend && flutter test test/core/router/router_guard_terms_gate_test.dart
```

Expected: all eight tests PASS.

- [ ] **Step 6: Verify nothing else regressed**

```bash
cd frontend && dart format lib/ test/ && flutter analyze && flutter test
```

Expected: `No issues found!` and the full suite passing.

- [ ] **Step 7: Manual smoke test of the OAuth path**

This is the highest-risk interaction in the plan — an automated test cannot prove the real OAuth round-trip survives the gate.

```bash
cd frontend && sh scripts/run-web-local.sh
```

With browser storage cleared (fresh state):
1. Land on `/login` — the checkbox is visible, all three buttons are disabled.
2. Navigate directly to `/email-auth` in the address bar — you are redirected back to `/login`.
3. Tick the checkbox, click **Continue with Google**, complete the Google flow.
4. Confirm you return through `/auth/callback` and land signed-in, **not** bounced to `/login`.
5. Sign out, return to `/login` — the checkbox is gone, the static links line is present, buttons are enabled.
6. Navigate directly to `/email-auth` — it now loads.

Record the outcome of each step in your report. If step 4 fails, the gate is deadlocking OAuth and must be fixed before this ships.

- [ ] **Step 8: Stage (do NOT commit)**

```bash
git add frontend/lib/core/router/router_guard.dart frontend/test/core/router/router_guard_terms_gate_test.dart
```

---

## After the plan

With this merged, all three Guideline 1.2 precautions are in place (terms gate, content flagging, user blocking). Still outstanding before resubmission, none of it code:

1. **Screen recording on a physical device**, showing: the terms at login, flagging objectionable content, and blocking a user. Must be recorded on a **fresh install** — acceptance is remembered per device, so the checkbox will not appear on a phone that has already signed in. Goes in App Store Connect → App Review Information → Notes.
2. **Remove China mainland** from Pricing and Availability, clearing the separate Guideline 2.1 permit rejection.
3. **Verify the block-user RPC lockdown live** — `supabase db reset` locally, confirm `rpc/block_user` is rejected for a plain authenticated JWT and that `fellowship-blocks` still works via service_role. This was inspected but never exercised against a running database.
4. New build, upload, resubmit.

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:disciplefy_bible_study/core/services/activation_analytics.dart';
import 'package:disciplefy_bible_study/core/constants/app_fonts.dart';
import 'package:disciplefy_bible_study/core/di/injection_container.dart';
import 'package:disciplefy_bible_study/core/extensions/translation_extension.dart';
import 'package:disciplefy_bible_study/core/i18n/translation_keys.dart';
import 'package:disciplefy_bible_study/core/models/app_language.dart';
import 'package:disciplefy_bible_study/core/router/app_routes.dart';
import 'package:disciplefy_bible_study/core/services/language_preference_service.dart';
import 'package:disciplefy_bible_study/core/theme/reader_palette.dart';
import 'package:disciplefy_bible_study/core/utils/logger.dart';
import 'package:disciplefy_bible_study/features/onboarding/presentation/widgets/first_run_choice_row.dart';
import 'package:disciplefy_bible_study/shared/widgets/welcome_chrome.dart';

/// First screen of the new first run: welcome copy over a photo, the three
/// languages in their own script, Continue, and two ways to log in.
///
/// Continue saves the language (so the goal screen renders in it at once)
/// and opens the goal screen.
class FirstRunLanguagePage extends StatefulWidget {
  const FirstRunLanguagePage({super.key});

  @override
  State<FirstRunLanguagePage> createState() => _FirstRunLanguagePageState();
}

class _FirstRunLanguagePageState extends State<FirstRunLanguagePage> {
  final LanguagePreferenceService _languageService =
      sl<LanguagePreferenceService>();

  AppLanguage _selected = AppLanguage.english;
  bool _saving = false;

  /// Set once the person taps a row, so a late read never overrides it.
  bool _picked = false;

  /// Leading glyph of each language row, in its own script.
  static String glyph(AppLanguage language) => switch (language) {
        AppLanguage.english => 'A',
        AppLanguage.hindi => 'अ',
        AppLanguage.malayalam => 'മ',
      };

  /// Line under the native name: the English name for Hindi and Malayalam
  /// (readable before a language is set), the Bible version for English.
  static String subLabel(BuildContext context, AppLanguage language) =>
      switch (language) {
        AppLanguage.english => context.tr(TranslationKeys.firstRunEnglishBible),
        AppLanguage.hindi => 'Hindi',
        AppLanguage.malayalam => 'Malayalam',
      };

  @override
  void initState() {
    super.initState();
    _loadCurrent();
  }

  Future<void> _loadCurrent() async {
    try {
      final current = await _languageService.getSelectedLanguage();
      if (mounted && !_picked) setState(() => _selected = current);
    } catch (e) {
      Logger.warning('First run could not read the language, using English',
          tag: 'FIRST_RUN', context: {'error': e.runtimeType.toString()});
    }
  }

  Future<void> _save() async {
    try {
      await _languageService.saveLanguagePreference(_selected);
    } catch (e) {
      // The goal screen saves it again; never block the first run on it.
      Logger.warning('First run language save failed',
          tag: 'FIRST_RUN', context: {'error': e.runtimeType.toString()});
    }
  }

  Future<void> _continue() async {
    setState(() => _saving = true);
    ActivationAnalytics.maybeTrack(
        NuxEvent.languageSelected, {'language': _selected.code});
    await _save();
    if (!mounted) return;
    setState(() => _saving = false);
    context.go(AppRoutes.welcomeGoal);
  }

  Future<void> _logIn() async {
    await _save();
    if (mounted) context.go(AppRoutes.login);
  }

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    final topInset = MediaQuery.paddingOf(context).top;
    final isNarrow = MediaQuery.sizeOf(context).width < 360;
    final onPhoto =
        palette.isDark ? Colors.white.withValues(alpha: 0.78) : palette.muted;

    return Scaffold(
      backgroundColor: palette.page,
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Stack(
                children: [
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    height: topInset + 290,
                    child: const WelcomePhotoBackdrop(
                      asset: WelcomePhotos.winterSunset,
                    ),
                  ),
                  Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 520),
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(20, topInset + 12, 20, 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                const Expanded(
                                  child: Align(
                                    alignment: Alignment.centerLeft,
                                    child: WelcomeBrandRow(),
                                  ),
                                ),
                                _LogInPill(onPressed: _saving ? null : _logIn),
                              ],
                            ),
                            SizedBox(height: isNarrow ? 72 : 96),
                            WelcomeEyebrow(context
                                .tr(TranslationKeys.firstRunWelcomeEyebrow)),
                            const SizedBox(height: 8),
                            Semantics(
                              header: true,
                              child: WelcomeTitle(
                                context
                                    .tr(TranslationKeys.firstRunWelcomeTitle),
                                fontSize: isNarrow ? 24 : 27,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              context
                                  .tr(TranslationKeys.firstRunWelcomeSubtitle),
                              style: AppFonts.inter(
                                fontSize: 14,
                                height: 1.45,
                                color: onPhoto,
                              ),
                            ),
                            const SizedBox(height: 28),
                            for (final language in AppLanguage.all)
                              FirstRunChoiceRow(
                                key: Key('first_run_language_${language.code}'),
                                leading: (color) => Text(
                                  glyph(language),
                                  style: AppFonts.inter(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: color,
                                  ),
                                ),
                                title: language.displayName,
                                subtitle: subLabel(context, language),
                                isSelected: _selected == language,
                                onTap: _saving
                                    ? null
                                    : () => setState(() {
                                          _picked = true;
                                          _selected = language;
                                        }),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      WelcomePrimaryButton(
                        key: const Key('first_run_language_continue'),
                        label: context.tr(TranslationKeys.firstRunContinue),
                        height: 40,
                        isLoading: _saving,
                        onPressed: _continue,
                      ),
                      const SizedBox(height: 4),
                      _HaveAccountRow(onLogIn: _saving ? null : _logIn),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// "Log in" pill at the top right, over the photo.
class _LogInPill extends StatelessWidget {
  final VoidCallback? onPressed;

  const _LogInPill({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    return TextButton(
      key: const Key('first_run_log_in_top'),
      onPressed: onPressed,
      style: TextButton.styleFrom(
        backgroundColor: palette.isDark
            ? Colors.white.withValues(alpha: 0.12)
            : palette.card.withValues(alpha: 0.85),
        foregroundColor: palette.text,
        minimumSize: const Size(0, 32),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        tapTargetSize: MaterialTapTargetSize.padded,
        shape: const StadiumBorder(),
      ),
      child: Text(
        context.tr(TranslationKeys.firstRunLogIn),
        style: AppFonts.inter(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: palette.text,
        ),
      ),
    );
  }
}

/// "Already have an account? Log in".
class _HaveAccountRow extends StatelessWidget {
  final VoidCallback? onLogIn;

  const _HaveAccountRow({required this.onLogIn});

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          context.tr(TranslationKeys.firstRunHaveAccount),
          style: AppFonts.inter(fontSize: 13, color: palette.muted),
        ),
        TextButton(
          key: const Key('first_run_log_in_bottom'),
          onPressed: onLogIn,
          style: TextButton.styleFrom(
            foregroundColor: palette.gold,
            minimumSize: const Size(0, 36),
            padding: const EdgeInsets.symmetric(horizontal: 6),
          ),
          child: Text(
            context.tr(TranslationKeys.firstRunLogIn),
            style: AppFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: palette.gold,
            ),
          ),
        ),
      ],
    );
  }
}

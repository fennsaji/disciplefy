import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:disciplefy_bible_study/core/constants/app_fonts.dart';
import 'package:disciplefy_bible_study/core/di/injection_container.dart';
import 'package:disciplefy_bible_study/core/extensions/translation_extension.dart';
import 'package:disciplefy_bible_study/core/i18n/translation_keys.dart';
import 'package:disciplefy_bible_study/core/models/app_language.dart';
import 'package:disciplefy_bible_study/core/services/language_preference_service.dart';
import 'package:disciplefy_bible_study/core/theme/app_colors.dart';
import 'package:disciplefy_bible_study/core/theme/reader_palette.dart';
import 'package:disciplefy_bible_study/core/utils/logger.dart';
import 'package:disciplefy_bible_study/features/onboarding/presentation/widgets/language_selection_card.dart';
import 'package:disciplefy_bible_study/shared/widgets/welcome_chrome.dart';

/// Screen for selecting preferred language during onboarding
class LanguageSelectionScreen extends StatefulWidget {
  const LanguageSelectionScreen({super.key});

  @override
  State<LanguageSelectionScreen> createState() =>
      _LanguageSelectionScreenState();
}

class _LanguageSelectionScreenState extends State<LanguageSelectionScreen> {
  AppLanguage? _selectedLanguage;
  bool _isLoading = false;

  final LanguagePreferenceService _languageService =
      sl<LanguagePreferenceService>();

  @override
  void initState() {
    super.initState();
    _loadCurrentLanguage();
  }

  Future<void> _loadCurrentLanguage() async {
    try {
      final currentLanguage = await _languageService.getSelectedLanguage();
      if (mounted) {
        setState(() {
          _selectedLanguage = currentLanguage;
        });
      }
    } catch (e) {
      // Default to English if there's an error
      if (mounted) {
        setState(() {
          _selectedLanguage = AppLanguage.english;
        });
      }
    }
  }

  void _selectLanguage(AppLanguage language) {
    setState(() {
      _selectedLanguage = language;
    });
  }

  Future<void> _continueWithSelection() async {
    if (_selectedLanguage == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // Save language preference - this will update the database AND mark completion
      // The service handles marking completion internally only after successful DB save
      await _languageService.saveLanguagePreference(_selectedLanguage!);

      // Verify that persistence and cache invalidation completed successfully
      final bool persistenceVerified =
          await _languageService.hasCompletedLanguageSelection();

      if (!persistenceVerified) {
        throw Exception(
            'Language preference persistence verification failed. Please try again.');
      }

      // Navigate to home screen only after successful verification
      if (mounted) {
        context.go('/');
      }
    } catch (e) {
      // Show error and do NOT navigate - allow user to retry
      Logger.error('Failed to save language preference', error: e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to save language preference. Please try again.',
              style: AppFonts.inter(),
            ),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _skipSelection() async {
    // For authenticated users, save default English preference instead of skipping
    // For anonymous users, allow skipping
    setState(() {
      _isLoading = true;
    });

    try {
      // Save default English preference - service handles marking completion internally
      await _languageService.saveLanguagePreference(AppLanguage.english);

      // Navigate to home screen
      if (mounted) {
        context.go('/');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.tr(TranslationKeys.onboardingDefaultLanguageSet),
              style: AppFonts.inter(),
            ),
            backgroundColor: AppColors.warning,
          ),
        );
        context.go('/');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    final topInset = MediaQuery.paddingOf(context).top;
    final isNarrow = MediaQuery.sizeOf(context).width < 360;

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
                    height: topInset + 300,
                    child: const WelcomePhotoBackdrop(
                      asset: WelcomePhotos.valleyMist,
                    ),
                  ),
                  Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 520),
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(24, topInset + 150, 24, 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            WelcomeEyebrow(
                              context.tr(
                                  TranslationKeys.onboardingLanguageEyebrow),
                            ),
                            const SizedBox(height: 10),
                            WelcomeTitle(
                              context.tr(TranslationKeys.onboardingWelcome),
                              fontSize: isNarrow ? 26 : 30,
                            ),
                            const SizedBox(height: 10),
                            Text(
                              context.tr(TranslationKeys
                                  .onboardingSelectLanguageSubtitle),
                              style: AppFonts.inter(
                                fontSize: 15.5,
                                height: 1.45,
                                color: palette.isDark
                                    ? Colors.white.withValues(alpha: 0.75)
                                    : palette.muted,
                              ),
                            ),
                            const SizedBox(height: 40),
                            for (final language in AppLanguage.all)
                              LanguageSelectionCard(
                                key: Key('language_option_${language.code}'),
                                language: language,
                                secondaryLabel: language == AppLanguage.english
                                    ? context.tr(TranslationKeys
                                        .onboardingLanguageDefault)
                                    : null,
                                isSelected: _selectedLanguage == language,
                                onTap: () => _selectLanguage(language),
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

          // Continue + Skip
          SafeArea(
            top: false,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 12, 24, 12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      WelcomePrimaryButton(
                        key: const Key('language_continue'),
                        label: context.tr(TranslationKeys.onboardingContinue),
                        isLoading: _isLoading,
                        onPressed: _selectedLanguage != null
                            ? _continueWithSelection
                            : null,
                      ),
                      const SizedBox(height: 4),
                      SizedBox(
                        width: double.infinity,
                        child: TextButton(
                          key: const Key('language_skip'),
                          onPressed: _isLoading ? null : _skipSelection,
                          style: TextButton.styleFrom(
                            foregroundColor: palette.muted,
                            minimumSize: const Size.fromHeight(48),
                            shape: const StadiumBorder(),
                          ),
                          child: Text(
                            context.tr(TranslationKeys.onboardingSkip),
                            textAlign: TextAlign.center,
                            style: AppFonts.inter(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                              color: palette.muted,
                            ),
                          ),
                        ),
                      ),
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
